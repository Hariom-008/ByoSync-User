import SwiftUI
internal import AVFoundation

struct RootView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var scanGate: AppScanGate
    @EnvironmentObject var faceAuthManager: FaceAuthManager
    @EnvironmentObject var enrollmentGate: EnrollmentGate
    @EnvironmentObject var deviceRegistrationVM: DeviceRegistrationViewModel
    
    @StateObject var userDatabyIDVM: UserDataByIdViewModel = UserDataByIdViewModel()

    @Environment(\.hasProcessedPendingNotifications) private var hasProcessedPendingNotifications: Bool

    @State private var presentScan: Bool = false
    @State private var isUpdatingScanState: Bool = false

    // ✅ cached keys
    private let isDeviceRegisteredKey = "isDeviceRegisteredKey"
    private let hasFaceDataKey = "hasFaceDataKey" // same key used by UserSession

    private var cachedIsDeviceRegistered: Bool? {
        guard UserDefaults.standard.object(forKey: isDeviceRegisteredKey) != nil else { return nil }
        return UserDefaults.standard.bool(forKey: isDeviceRegisteredKey)
    }

    private var cachedHasFaceData: Bool? {
        guard UserDefaults.standard.object(forKey: hasFaceDataKey) != nil else { return nil }
        return UserDefaults.standard.bool(forKey: hasFaceDataKey)
    }

    private var hasCameraPermission: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    var body: some View {
        ZStack {
            baseScreen
        }
        .onAppear {
            enrollmentGate.reload()
            scanGate.reloadFromStorage()
            updateScanPresentation()
        }
        .onChange(of: presentScan){ _, _  in
          updateScanPresentation()
        }
        .onChange(of: hasProcessedPendingNotifications) { _, _ in
            updateScanPresentation()
        }
        .onChange(of: userSession.currentUser) { _, _ in
            updateScanPresentation()
        }
        .onChange(of: userSession.hasFaceData) { _, _ in
            updateScanPresentation()
        }
        .onChange(of: scanGate.requireScan) { _, _ in
            updateScanPresentation()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EnrollmentStatusChanged"))) { _ in
            enrollmentGate.reload()
            updateScanPresentation()
        }
        .onChange(of: deviceRegistrationVM.isDeviceRegistered) { _, _ in
            updateScanPresentation()
        }
        .onChange(of: deviceRegistrationVM.hasFaceData) { _, _ in
            updateScanPresentation()
        }
        .fullScreenCover(isPresented: $presentScan) {
            ScanModal(
                mode: faceAuthManager.currentMode,
                onDone: {
                    print("✅ [RootView] Scan completed in mode: \(faceAuthManager.currentMode)")
                    
                    // ✅ If we just completed REGISTRATION successfully, persist that fact locally
                    if faceAuthManager.currentMode == .registration {
                        print("📝 [RootView] Registration scan completed - updating local state")
                        
                        // ✅ Record timestamp for safety check
                        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastRegistrationTimestamp")
                        
                        userSession.setHasFaceData(true)
                        enrollmentGate.markEnrolled()
                        
                        // ✅ CRITICAL: Update deviceRegistrationVM immediately
                        deviceRegistrationVM.hasFaceData = true
                        print("✅ [RootView] Updated deviceRegistrationVM.hasFaceData = true")
                        
                        // ✅ Persist to UserDefaults as backup
                        UserDefaults.standard.set(true, forKey: "hasFaceDataKey")
                    }

                    // ✅ Clear scan requirement after any successful scan
                    print("🔓 [RootView] Clearing scan requirement")
                    scanGate.markScanCompleted()
                    enrollmentGate.reload()
                    
                    // ✅ IMPORTANT: Delay backend fetch to give server time to process
                    // This prevents race condition where backend returns old hasFaceData=false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        print("🔄 [RootView] Fetching updated user data from backend...")
                        userDatabyIDVM.fetch(
                            userId: deviceRegistrationVM.userId,
                            deviceKeyHash: HMACGenerator.generateHMAC(jsonString: DeviceIdentity.resolve())
                        )
                    }
                    
                    // ✅ Dismiss scan modal
                    print("❌ [RootView] Dismissing scan modal")
                    presentScan = false
                    
                    // ✅ Reset debounce flag to allow future updates
                    isUpdatingScanState = false
                }
            )
        }
    }

    @ViewBuilder
    private var baseScreen: some View {
        // If logged in, base is mainTab (scan happens as modal on top)
        if userSession.currentUser != nil {
            MainTabView()
        } else {
              AuthenticationView()
        }
    }
    private func updateScanPresentation() {
        // ✅ Prevent multiple simultaneous updates
        guard !isUpdatingScanState else {
            print("⏭️ [RootView] Skipping scan update - already in progress")
            return
        }
        
        isUpdatingScanState = true
        defer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isUpdatingScanState = false
            }
        }
        
        print("🔍 [RootView] Evaluating scan presentation...")
        print("   - currentUser: \(userSession.currentUser?.userId ?? "nil")")
        print("   - hasFaceData: \(userSession.hasFaceData)")
        print("   - requireScan: \(scanGate.requireScan)")
        print("   - hasProcessedNotifications: \(hasProcessedPendingNotifications)")
        print("   - enrollmentState: \(enrollmentGate.state)")
        print("   - deviceVM.isDeviceRegistered: \(deviceRegistrationVM.isDeviceRegistered)")
        print("   - deviceVM.hasFaceData: \(deviceRegistrationVM.hasFaceData)")
        
        // ✅ Debug: Check registration timestamp
        let lastRegTime = UserDefaults.standard.double(forKey: "lastRegistrationTimestamp")
        let timeSinceReg = Date().timeIntervalSince1970 - lastRegTime
        if lastRegTime > 0 {
            print("   - lastRegistration: \(timeSinceReg)s ago")
        }
        
        // 1) Not logged in - check login flow
        if userSession.currentUser == nil {
            print("📍 [RootView] Decision path: Not logged in")
            
            // ✅ RETURNING USER: Use live deviceRegistrationVM values (works on reinstall)
            if deviceRegistrationVM.isDeviceRegistered && deviceRegistrationVM.hasFaceData {
                print("✅ [RootView] Returning user detected (device registered + has face) -> Auto-verification scan")
                faceAuthManager.setVerificationMode()
                presentScan = true
                return
            }
            
            // ✅ REGISTRATION FLOW: Device registered but needs face enrollment
            if deviceRegistrationVM.isDeviceRegistered && !deviceRegistrationVM.hasFaceData {
                print("✅ [RootView] Not logged in but device registered + no face data -> Registration scan")
                faceAuthManager.setRegistrationMode()
                presentScan = true
                return
            }
            
            print("❌ [RootView] Not logged in - no scan needed (new device or loading)")
            presentScan = false
            return
        }
        
        // 2) Logged in - FOR NEW USERS: Skip notification wait, go straight to registration
        if userSession.hasFaceData == false {
            print("📍 [RootView] Decision path: Logged in + no face data")
            print("✅ [RootView] Logged in + no face data -> Registration scan (NEW USER)")
            faceAuthManager.setRegistrationMode()
            presentScan = true
            return
        }
        
        // 3) Logged in - FOR EXISTING USERS: Wait for notification processing before showing verification scan
        if !hasProcessedPendingNotifications {
            print("📍 [RootView] Decision path: Logged in + has face + waiting for notifications")
            print("⏳ [RootView] Logged in - waiting for notification processing")
            presentScan = false
            return
        }
        
        // 4) Logged in + has face data + scan required -> verification scan
        if scanGate.requireScan {
            print("📍 [RootView] Decision path: Logged in + has face + scan required")
            print("✅ [RootView] Logged in + has face data + scan required -> Verification scan")
            faceAuthManager.setVerificationMode()
            presentScan = true
            return
        }
        
        print("📍 [RootView] Decision path: Default - no scan needed")
        print("❌ [RootView] No scan needed")
        presentScan = false
    }
}

// MARK: - Scan Modal Wrapper (CameraPrep -> MLScan)
private struct ScanModal: View {
    let mode: FaceAuthMode
    let onDone: () -> Void

    @State private var cameraReady: Bool = false

    private var hasCameraPermission: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    var body: some View {
        Group {
            if cameraReady || hasCameraPermission {
                MLScanView(onDone: onDone)
            } else {
                CameraPreparationView(onReady: {
                    cameraReady = true
                })
            }
        }
        .onAppear {
            cameraReady = hasCameraPermission
        }
    }
}

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
    private let hasFaceDataKey = "hasFaceDataKey"

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
            print("📱 [RootView] View appeared")
            enrollmentGate.reload()
            scanGate.reloadFromStorage()
            updateScanPresentation()
        }
        .onChange(of: presentScan){ _, _  in
          updateScanPresentation()
        }
        .onChange(of: hasProcessedPendingNotifications) { _, _ in
            print("🔔 [RootView] hasProcessedPendingNotifications changed")
            updateScanPresentation()
        }
        .onChange(of: userSession.currentUser) { _, newValue in
            print("👤 [RootView] currentUser changed: \(newValue?.userId ?? "nil")")
            updateScanPresentation()
        }
        .onChange(of: userSession.hasFaceData) { _, newValue in
            print("😊 [RootView] hasFaceData changed: \(newValue)")
            updateScanPresentation()
        }
        .onChange(of: scanGate.requireScan) { _, newValue in
            print("🔓 [RootView] requireScan changed: \(newValue)")
            updateScanPresentation()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EnrollmentStatusChanged"))) { _ in
            print("📢 [RootView] EnrollmentStatusChanged notification received")
            enrollmentGate.reload()
            updateScanPresentation()
        }
        .onChange(of: deviceRegistrationVM.isDeviceRegistered) { _, newValue in
            print("📱 [RootView] deviceVM.isDeviceRegistered changed: \(newValue)")
            updateScanPresentation()
        }
        .onChange(of: deviceRegistrationVM.hasFaceData) { _, newValue in
            print("😊 [RootView] deviceVM.hasFaceData changed: \(newValue)")
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
        
        print("🔍 [RootView] ===== EVALUATING SCAN PRESENTATION =====")
        print("   📊 State Snapshot:")
        print("      - currentUser: \(userSession.currentUser?.userId ?? "nil")")
        print("      - userSession.hasFaceData: \(userSession.hasFaceData)")
        print("      - requireScan: \(scanGate.requireScan)")
        print("      - hasProcessedNotifications: \(hasProcessedPendingNotifications)")
        print("      - enrollmentState: \(enrollmentGate.state)")
        print("      - deviceVM.isDeviceRegistered: \(deviceRegistrationVM.isDeviceRegistered)")
        print("      - deviceVM.hasFaceData: \(deviceRegistrationVM.hasFaceData)")
        
        // ✅ Debug: Check registration timestamp
        let lastRegTime = UserDefaults.standard.double(forKey: "lastRegistrationTimestamp")
        let timeSinceReg = Date().timeIntervalSince1970 - lastRegTime
        if lastRegTime > 0 {
            print("      - lastRegistration: \(String(format: "%.1f", timeSinceReg))s ago")
        }
        
        // ========================================
        // DECISION PATH 1: Not Logged In
        // ========================================
        if userSession.currentUser == nil {
            print("📍 [RootView] Path 1: User not logged in")
            
            // ✅ RETURNING USER: Device registered + has face data → Auto-verification
            if deviceRegistrationVM.isDeviceRegistered && deviceRegistrationVM.hasFaceData {
                print("   ✅ Returning user detected (device + face) → Verification scan")
                faceAuthManager.setVerificationMode()
                presentScan = true
                print("🔍 [RootView] ===== DECISION: SHOW VERIFICATION SCAN =====\n")
                return
            }
            
            // ✅ REGISTRATION FLOW: Device registered but needs enrollment
            if deviceRegistrationVM.isDeviceRegistered && !deviceRegistrationVM.hasFaceData {
                print("   ✅ Device registered, no face → Registration scan")
                faceAuthManager.setRegistrationMode()
                presentScan = true
                print("🔍 [RootView] ===== DECISION: SHOW REGISTRATION SCAN =====\n")
                return
            }
            
            print("   ❌ New device or loading → Show auth screen")
            presentScan = false
            print("🔍 [RootView] ===== DECISION: SHOW AUTH SCREEN =====\n")
            return
        }
        
        // ========================================
        // DECISION PATH 2: Logged In + No Face Data
        // ========================================
        if userSession.hasFaceData == false {
            print("📍 [RootView] Path 2: Logged in + no face data")
            print("   ✅ New user needs enrollment → Registration scan")
            faceAuthManager.setRegistrationMode()
            presentScan = true
            print("🔍 [RootView] ===== DECISION: SHOW REGISTRATION SCAN =====\n")
            return
        }
        
        // ========================================
        // DECISION PATH 3: Logged In + Has Face + Waiting for Notifications
        // ========================================
        if !hasProcessedPendingNotifications {
            print("📍 [RootView] Path 3: Logged in + has face + waiting for notifications")
            print("   ⏳ Waiting for notification processing...")
            presentScan = false
            print("🔍 [RootView] ===== DECISION: WAIT FOR NOTIFICATIONS =====\n")
            return
        }
        
        // ========================================
        // DECISION PATH 4: Logged In + Has Face + Scan Required
        // ========================================
        if scanGate.requireScan {
            print("📍 [RootView] Path 4: Logged in + has face + scan required")
            print("   ✅ Scan required → Verification scan")
            faceAuthManager.setVerificationMode()
            presentScan = true
            print("🔍 [RootView] ===== DECISION: SHOW VERIFICATION SCAN =====\n")
            return
        }
        
        // ========================================
        // DECISION PATH 5: Default (No Scan Needed)
        // ========================================
        print("📍 [RootView] Path 5: Default - all conditions satisfied")
        print("   ❌ No scan needed → Show main app")
        presentScan = false
        print("🔍 [RootView] ===== DECISION: SHOW MAIN APP =====\n")
    }
}

// MARK: - Scan Modal Wrapper (CameraPrep → MLScan)
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
                    print("📸 [ScanModal] Camera ready - showing MLScanView")
                    cameraReady = true
                })
            }
        }
        .onAppear {
            print("📱 [ScanModal] ScanModal appeared for mode: \(mode)")
            cameraReady = hasCameraPermission
        }
    }
}

import SwiftUI
internal import AVFoundation

struct RootView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var scanGate: AppScanGate
    @EnvironmentObject var faceAuthManager: FaceAuthManager
    @EnvironmentObject var enrollmentGate: EnrollmentGate
    @EnvironmentObject var deviceRegistrationVM: DeviceRegistrationViewModel

    @Environment(\.hasProcessedPendingNotifications) private var hasProcessedPendingNotifications: Bool

    @State private var presentScan: Bool = false

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
        .fullScreenCover(isPresented: $presentScan) {
            ScanModal(
                mode: faceAuthManager.currentMode,
                onDone: {
                    // ✅ If we just completed REGISTRATION successfully, persist that fact locally
                    if faceAuthManager.currentMode == .registration {
                        userSession.setHasFaceData(true) // writes UserDefaults "hasFaceDataKey" too
                        enrollmentGate.markEnrolled()
                    }

                    // ✅ Verification/Registration both should clear scan requirement
                    scanGate.markScanCompleted()
                    enrollmentGate.reload()

                    presentScan = false
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
        // 1) If logged in, wait for pending notifications processing to finish
        if userSession.currentUser != nil && !hasProcessedPendingNotifications {
            presentScan = false
            return
        }

        // 2) If logged in and hasFaceData=false -> force registration scan
        if userSession.currentUser != nil && userSession.hasFaceData == false {
            faceAuthManager.setRegistrationMode()
            presentScan = true
            return
        }

        // 3) If logged in and scan required -> verification scan
        if userSession.currentUser != nil && userSession.hasFaceData == true && scanGate.requireScan {
            faceAuthManager.setVerificationMode()
            presentScan = true
            return
        }

        // 4) Not logged in:
        //    If device registered but hasFaceData=false -> open scan in registration mode
        if userSession.currentUser == nil,
           cachedIsDeviceRegistered == true,
           cachedHasFaceData == false {
            faceAuthManager.setRegistrationMode()
            presentScan = true
            return
        }

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

import SwiftUI
internal import AVFoundation


private enum AppStep {
    case loading, auth, consent, cameraPrep, mlScan, mainTab
}

private enum LaunchDeviceState {
    case unknown
    case registered
    case notRegistered
}

struct RootView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var scanGate: AppScanGate
    @EnvironmentObject var router: Router
    @EnvironmentObject var faceAuthManager: FaceAuthManager
    @EnvironmentObject var enrollmentGate: EnrollmentGate

    @StateObject private var deviceRegistrationVM = DeviceRegistrationViewModel()

    @State private var step: AppStep = .loading
    @State private var consentAccepted = false
    private let consentKey = "consentAccepted"

    @State private var didRunLaunchDeviceCheck = false
    @State private var launchDeviceState: LaunchDeviceState = .unknown

    // ✅ NEW: device-check routing should only apply during initial launch gating
    @State private var launchRoutingActive = true

    private var hasCameraPermission: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    var body: some View {
        Group {
            switch step {
            case .loading:
                SplashScreenView()

            case .auth:
                AuthenticationView()

            case .consent:
                UserConsentView(onComplete: {
                    consentAccepted = true
                    UserDefaults.standard.set(true, forKey: consentKey)
                    withAnimation(.easeInOut) { step = .cameraPrep }
                })

            case .cameraPrep:
                CameraPreparationView(onReady: {
                    withAnimation(.easeInOut(duration: 0.3)) { step = .mlScan }
                })

            case .mlScan:
                MLScanView(onDone: {
                    #if DEBUG
                    print("✅ ML scan completed")
                    #endif

                    scanGate.markScanCompleted()

                    // Refresh session after verification/enrollment
                    userSession.loadUser()
                    enrollmentGate.reload()

                    // ✅ Release launch routing after scan completes
                    launchRoutingActive = false
                    launchDeviceState = .unknown

                    // ✅ Let normal routing decide where to go next
                    withAnimation(.easeInOut) { step = nextStep() }
                })

            case .mainTab:
                MainTabView()
            }
        }
        .onAppear {
            userSession.loadUser()
            enrollmentGate.reload()
            consentAccepted = UserDefaults.standard.bool(forKey: consentKey)
            scanGate.reloadFromStorage()

            // ✅ Run only once
            guard !didRunLaunchDeviceCheck else { return }
            didRunLaunchDeviceCheck = true

            // 🔍 Device check: if deviceKey missing => treat as not registered
            let deviceKey = DeviceIdentity.resolve()
            if deviceKey.isEmpty {
                launchDeviceState = .notRegistered
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    step = nextStep()
                }
                return
            }

            // ✅ Ask backend
            deviceRegistrationVM.checkDeviceRegistration()
        }
        .onChange(of: deviceRegistrationVM.isLoading) { _, isLoading in
            guard didRunLaunchDeviceCheck else { return }
            guard !isLoading else { return }
            guard launchDeviceState == .unknown else { return }
            guard launchRoutingActive else { return }

            launchDeviceState = deviceRegistrationVM.isDeviceRegistered ? .registered : .notRegistered
            step = nextStep()
        }
        .onChange(of: userSession.currentUser) { _, newUser in
            // ✅ Once user becomes non-nil (login/register), stop forcing launch routing
            if newUser != nil {
                launchRoutingActive = false
                launchDeviceState = .unknown
                enrollmentGate.reload()
            }
            step = nextStep()
        }
        .onChange(of: scanGate.requireScan) { _, _ in
            step = nextStep()
        }
    }

    private func nextStep() -> AppStep {

        // ✅ Launch routing applies ONLY while launchRoutingActive is true
        if launchRoutingActive {
            switch launchDeviceState {
            case .registered:
                faceAuthManager.setVerificationMode()
                return hasCameraPermission ? .mlScan : .cameraPrep

            case .notRegistered:
                return .auth

            case .unknown:
                break
            }
        }

        // ---- Normal logic ----
        guard UserDefaults.standard.string(forKey: "accountType") == "user" else { return .auth }
        guard userSession.currentUser != nil else { return .auth }
        guard consentAccepted else { return .consent }

        if enrollmentGate.needsEnrollment {
            faceAuthManager.setRegistrationMode()
            return hasCameraPermission ? .mlScan : .cameraPrep
        }

        if scanGate.requireScan {
            faceAuthManager.setVerificationMode()
            return hasCameraPermission ? .mlScan : .cameraPrep
        }

        return .mainTab
    }
}
#Preview {
    RootView()
        .environmentObject(UserSession.shared)
}

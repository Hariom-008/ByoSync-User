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
    @State private var launchHasFaceData: Bool? = nil


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
                    scanGate.markScanCompleted()
                    userSession.loadUser()
                    enrollmentGate.reload()

                    // ✅ stop launch routing
                    launchRoutingActive = false
                    launchDeviceState = .unknown
                    launchHasFaceData = nil

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

            guard !didRunLaunchDeviceCheck else { return }
            didRunLaunchDeviceCheck = true

            let deviceKey = DeviceIdentity.resolve()
            if deviceKey.isEmpty {
                launchDeviceState = .notRegistered
                launchHasFaceData = nil
                step = nextStep()
                return
            }

            // ask backend
            launchDeviceState = .unknown
            launchHasFaceData = nil
            deviceRegistrationVM.checkDeviceRegistration()
        }

        .onChange(of: deviceRegistrationVM.isLoading) { _, isLoading in
            guard didRunLaunchDeviceCheck else { return }
            guard !isLoading else { return }
            guard launchRoutingActive else { return }

            if deviceRegistrationVM.isDeviceRegistered {
                launchDeviceState = .registered
                launchHasFaceData = deviceRegistrationVM.hasFaceData
            } else {
                launchDeviceState = .notRegistered
                launchHasFaceData = nil
            }

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
            case .notRegistered:
                return .auth

            case .registered:
                // if API hasn't filled it yet, stay on splash
                guard let hasFaceData = launchHasFaceData else { return .loading }

                if hasFaceData {
                    faceAuthManager.setVerificationMode()
                } else {
                    faceAuthManager.setRegistrationMode()
                }
                return hasCameraPermission ? .mlScan : .cameraPrep

            case .unknown:
                return .loading
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

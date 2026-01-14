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
    
    @Environment(\.hasProcessedPendingNotifications) private var hasProcessedPendingNotifications
    
    @StateObject private var deviceRegistrationVM = DeviceRegistrationViewModel()
    @StateObject private var fetchUserByIdVM = UserDataByIdViewModel()
    
    @State private var step: AppStep = .loading
    @State private var consentAccepted = false
    private let consentKey = "consentAccepted"
    
    @State private var didRunLaunchDeviceCheck = false
    @State private var launchDeviceState: LaunchDeviceState = .unknown
    @State private var launchHasFaceData: Bool? = nil
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
                    
                    if userSession.currentUser == nil {
                        fetchUserByIdVM.fetch(
                            userId: userSession.currentUserID,
                            deviceKeyHash: HMACGenerator.generateHMAC(jsonString: DeviceIdentity.resolve())
                        )
                    }
                    
                    enrollmentGate.reload()
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
            if userSession.currentUser == nil {
                userSession.loadUser()
            }
            
            consentAccepted = UserDefaults.standard.bool(forKey: consentKey)
            scanGate.reloadFromStorage()
            
            // ✅ For logged-in users, wait for notification processing
            if userSession.currentUser != nil {
                launchRoutingActive = false
                
                // Only navigate if notifications are processed
                if hasProcessedPendingNotifications {
                    step = nextStep()
                }
                return
            }
            
            // ✅ For new users, proceed normally without waiting
            guard !didRunLaunchDeviceCheck else {
                step = nextStep()
                return
            }
            didRunLaunchDeviceCheck = true
            
            let deviceKey = DeviceIdentity.resolve()
            if deviceKey.isEmpty {
                launchDeviceState = .notRegistered
                launchHasFaceData = nil
                step = nextStep()
                return
            }
            
            launchDeviceState = .unknown
            launchHasFaceData = nil
            deviceRegistrationVM.checkDeviceRegistration()
        }
        .onChange(of: hasProcessedPendingNotifications) { _, processed in
            // ✅ Only react if user is logged in
            if processed && userSession.currentUser != nil && !launchRoutingActive {
                print("✅ [RootView] Pending notifications processed, navigating...")
                enrollmentGate.reload()
                step = nextStep()
            }
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
            if newUser != nil {
                launchRoutingActive = false
                launchDeviceState = .unknown
                launchHasFaceData = nil
                enrollmentGate.reload()
            }
            
            // ✅ NEW: For new users logging in, always navigate immediately
            // For returning users, wait for notification processing
            if newUser != nil && hasProcessedPendingNotifications {
                step = nextStep()
            }
        }
        .onChange(of: scanGate.requireScan) { _, _ in
            step = nextStep()
        }
        .onChange(of: enrollmentGate.state) { oldState, newState in
            print("📍 [RootView] EnrollmentGate state changed: \(oldState) -> \(newState)")
            
            if userSession.currentUser != nil, !launchRoutingActive, hasProcessedPendingNotifications {
                withAnimation(.easeInOut(duration: 0.3)) {
                    step = nextStep()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EnrollmentStatusChanged"))) { notification in
            print("📡 [RootView] Received EnrollmentStatusChanged notification")
            
            if userSession.currentUser != nil, !launchRoutingActive {
                enrollmentGate.reload()
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    step = nextStep()
                }
            }
        }
    }
    
    private func nextStep() -> AppStep {
        if launchRoutingActive {
            switch launchDeviceState {
            case .notRegistered:
                print("🆕 [RootView] First-time user -> Registration mode")
                faceAuthManager.setRegistrationMode()
               // return hasCameraPermission ? .mlScan : .cameraPrep
                return .auth
                
            case .registered:
               // guard let hasFaceData = launchHasFaceData else { return .loading }
                let hasFaceData = UserSession.shared.hasFaceData
                guard hasFaceData else{
                    return .loading
                }
                if !hasFaceData{
//                    print("✅ [RootView] Device registered with face data -> Verification mode")
//                    faceAuthManager.setVerificationMode()
//                } else {
                    print("📸 [RootView] Device registered without face data -> Registration mode")
                    faceAuthManager.setRegistrationMode()
                }
                return hasCameraPermission ? .mlScan : .cameraPrep
                
            case .unknown:
                return .loading
            }
        }
        
        guard userSession.currentUser != nil else { return .auth }
        
        
        if scanGate.requireScan{
            print("🔐 [RootView] Scan required -> Verification mode")
            faceAuthManager.setVerificationMode()
            return hasCameraPermission ? .mlScan : .cameraPrep
        }
        
        return .mainTab
    }
}


private struct HasProcessedPendingNotificationsKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var hasProcessedPendingNotifications: Bool {
        get { self[HasProcessedPendingNotificationsKey.self] }
        set { self[HasProcessedPendingNotificationsKey.self] = newValue }
    }
}

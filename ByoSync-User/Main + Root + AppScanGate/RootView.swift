import SwiftUI


private enum AppStep {
    case loading, auth, consent, mlScan, mainTab
}

struct RootView: View {
    @EnvironmentObject var userSession: UserSession

    @State private var step: AppStep = .loading
    @State private var consentAccepted = false
    @State private var scanCompleted = false

    // UserDefaults keys
    private let consentKey = "consentAccepted"
    private let scanKey    = "scanCompletedV1"

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
                    withAnimation(.easeInOut) { step = .mlScan }
                })

            case .mlScan:
                // Add your dependencies as needed (e.g., .environmentObject(cryptoManager))
                MLScanView(onDone: {
                    scanCompleted = true
                    UserDefaults.standard.set(true, forKey: scanKey)
                    withAnimation(.easeInOut) { step = .mainTab }
                })

            case .mainTab:
                MainTabView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity.combined(with: .move(edge: .trailing))
                    ))
            }
        }
        .onAppear {
            userSession.loadUser()

            // Load persisted flags
            consentAccepted = UserDefaults.standard.bool(forKey: consentKey)
            scanCompleted   = UserDefaults.standard.bool(forKey: scanKey)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                step = nextStep()
            }
        }
        .onChange(of: userSession.currentUser) { _, _ in
            step = nextStep()
        }
    }

    private func nextStep() -> AppStep {
        guard let accountType = UserDefaults.standard.string(forKey: "accountType"), accountType == "user" else {
            return .auth
        }
        guard userSession.currentUser != nil else {
            return .auth
        }
        if !consentAccepted { return .consent }
        if !scanCompleted   { return .mlScan }
        return .mainTab
    }
}


// Enhanced splash screen with smooth animations
struct SplashScreenView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(UIColor.systemGroupedBackground),
                    Color(UIColor.secondarySystemGroupedBackground)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Animated circle in background
            Circle()
                .fill(Color(hex: "4B548D").opacity(0.08))
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .offset(y: isAnimating ? 20 : -20)
            
            VStack(spacing: 30) {
                // Animated progress indicator
                ProgressView()
                    .scaleEffect(isAnimating ? 1.0 : 0.8, anchor: .center)
                    .padding(.bottom, 40)
            }
            .padding()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(UserSession.shared)
}

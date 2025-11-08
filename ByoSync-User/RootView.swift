import SwiftUI

struct RootView: View {
    @EnvironmentObject var userSession: UserSession
    @State private var consentAccepted = false
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                // Loading state while we check the user and consent status
                SplashScreenView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                // Check for session (either user or merchant)
                if let accountType = UserDefaults.standard.string(forKey: "accountType") {
                     if accountType == "user" {
                        // User logged in
                        if userSession.currentUser == nil {
                            AuthenticationView()
                        } else if !consentAccepted {
                            // User logged in but hasn't accepted consent → go to consent view
                            UserConsentView(onComplete: {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    consentAccepted = true
                                }
                                // Save consent acceptance to UserDefaults
                                UserDefaults.standard.set(true, forKey: "consentAccepted")
                            })
                        } else {
                            // User logged in AND consent accepted → go to main app
                            MainTabView()
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                        }
                    }
                } else {
                    // If no account type found, go directly to authentication
                    AuthenticationView()
                }
            }
        }
        .onAppear {
            userSession.loadUser() // ensures the saved user (if any) is restored
            
            // Check if user exists and consent was previously accepted
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let savedConsentStatus = UserDefaults.standard.bool(forKey: "consentAccepted")
                
                withAnimation(.easeInOut(duration: 0.6)) {
                    if userSession.currentUser != nil && savedConsentStatus {
                        consentAccepted = true
                    }
                    isLoading = false
                }
            }
        }
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

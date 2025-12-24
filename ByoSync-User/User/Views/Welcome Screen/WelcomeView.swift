import SwiftUI

struct WelcomeView: View {
    let onRegisterClick: () -> Void
    
    @State private var showContent = false
    @State private var showPermissionUI = false
    @State private var currentFeature = 0
    @State private var blobOffset1: CGFloat = 0
    @State private var blobOffset2: CGFloat = 0
    
    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("lock.shield.fill", "Secure", "Biometric protection"),
        ("bolt.fill", "Fast", "Instant access"),
        ("checkmark.seal.fill", "Trusted", "Bank-grade security")
    ]
    
    // Colors from the logo gradient
    private let logoBlue = Color(red: 0.0, green: 0.0, blue: 1.0) // Bright blue
    private let logoPurple = Color(red: 0.478, green: 0.0, blue: 1.0) // Purple/violet
    
    var body: some View {
        ZStack {
            // Background gradient matching logo
            LinearGradient(
                colors: [
                    Color(red: 0.972, green: 0.980, blue: 0.988),
                    Color(red: 0.937, green: 0.965, blue: 1.0),
                    Color(red: 0.929, green: 0.929, blue: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Animated background blobs
            AnimatedBackgroundBlobs(visible: showContent, logoBlue: logoBlue, logoPurple: logoPurple)
            
            if showPermissionUI {
                CameraPermissionUI(
                    logoBlue: logoBlue,
                    logoPurple: logoPurple,
                    onDismiss: { showPermissionUI = false },
                    onOpenSettings: {
                        print("🔧 Opening app settings")
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                )
            } else {
                mainContent
            }
        }
        .onAppear {
            print("✨ WelcomeScreen appeared")
            
            // Show content with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    showContent = true
                }
            }
            
            // Start feature rotation
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.6)) {
                    currentFeature = (currentFeature + 1) % features.count
                }
            }
            
            // Start blob animations
            startBlobAnimations()
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 60)
            
            // Logo and title section
            if showContent {
                logoSection
                    .transition(.scale.combined(with: .opacity))
            }
            
            Spacer()
            
            // Bottom button section
            if showContent {
                bottomSection
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
    
    private var logoSection: some View {
        VStack(spacing: 0) {
            // Logo circle
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 140, height: 140)
                    .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
                
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 84)
            }
            
            Spacer().frame(height: 28)
            
            // Title with logo gradient
            Text("ByoSync")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [logoBlue, logoPurple],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            Spacer().frame(height: 8)
            
            Text("Your financial future, secured")
                .font(.system(size: 12, weight: .medium,design: .rounded))
                .foregroundColor(Color(red: 0.392, green: 0.455, blue: 0.545))
            
            Spacer().frame(height: 28)
            
            // Rotating feature pill
            FeaturePill(
                icon: features[currentFeature].icon,
                title: features[currentFeature].title,
                subtitle: features[currentFeature].subtitle,
                logoBlue: logoBlue,
                logoPurple: logoPurple
            )
            .id(currentFeature)
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
        }
        .padding(.horizontal, 16)
    }
    
    private var bottomSection: some View {
        VStack(spacing: 10) {
            
            Spacer().frame(height: 8)
            GlassButton(
                text: "Create Account",
                icon: "person.badge.plus.fill",
                isPrimary: true,
                logoBlue: logoBlue,
                logoPurple: logoPurple
            ) {
                print("🎯 Create Account tapped")
                onRegisterClick()
            }
            
            
            Text("Your data is encrypted and secure")
                .font(.system(size: 10,weight: .regular, design: .rounded))
                .foregroundColor(Color(red: 0.580, green: 0.639, blue: 0.722))
                .multilineTextAlignment(.center)
            HStack{
                Text("powered by")
                    .font(.system(size: 7))
                    .foregroundColor(Color(red: 0.580, green: 0.639, blue: 0.722))
                    .multilineTextAlignment(.center)
                Text("KAVION")
                    .font(.system(size: 10,weight: .bold))
                    .foregroundColor(Color(red: 0.580, green: 0.639, blue: 0.722))
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private func startBlobAnimations() {
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
            blobOffset1 = 50
        }
        
        withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
            blobOffset2 = -40
        }
    }
}

// MARK: - Animated Background Blobs

struct AnimatedBackgroundBlobs: View {
    let visible: Bool
    let logoBlue: Color
    let logoPurple: Color
    
    @State private var offset1: CGFloat = 0
    @State private var offset2: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Blob 1 - Blue
            Circle()
                .fill(logoBlue)
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .opacity(visible ? 0.15 : 0)
                .offset(x: -100 + offset1, y: 100)
            
            // Blob 2 - Purple
            Circle()
                .fill(logoPurple)
                .frame(width: 250, height: 250)
                .blur(radius: 60)
                .opacity(visible ? 0.18 : 0)
                .offset(x: UIScreen.main.bounds.width - 150 + offset2, y: -50)
            
            // Blob 3 - Mid gradient color
            Circle()
                .fill(
                    LinearGradient(
                        colors: [logoBlue, logoPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 200, height: 200)
                .blur(radius: 50)
                .opacity(visible ? 0.12 : 0)
                .offset(x: 50, y: UIScreen.main.bounds.height - 200 + offset1)
        }
        .animation(.easeInOut(duration: 1.0), value: visible)
        .onAppear {
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                offset1 = 50
            }
            
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                offset2 = -40
            }
        }
    }
}

// MARK: - Feature Pill

struct FeaturePill: View {
    let icon: String
    let title: String
    let subtitle: String
    let logoBlue: Color
    let logoPurple: Color
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon circle with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [logoBlue.opacity(0.15), logoPurple.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [logoBlue, logoPurple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.392, green: 0.455, blue: 0.545))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .frame(minWidth: 200)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        )
    }
}

// MARK: - Glass Button

struct GlassButton: View {
    let text: String
    let icon: String
    let isPrimary: Bool
    let logoBlue: Color
    let logoPurple: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            print("🔘 Button tapped: \(text)")
            action()
        }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                
                Text(text)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(isPrimary ? .white : logoBlue)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        isPrimary ?
                        LinearGradient(
                            colors: [logoBlue, logoPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.white, Color.white],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(isPrimary ? 0.15 : 0.08), radius: isPrimary ? 8 : 4, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isPrimary ? Color.clear : Color.white.opacity(0.5), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Camera Permission UI

struct CameraPermissionUI: View {
    let logoBlue: Color
    let logoPurple: Color
    let onDismiss: () -> Void
    let onOpenSettings: () -> Void
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.972, green: 0.980, blue: 0.988),
                    Color(red: 0.937, green: 0.965, blue: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Icon with gradient
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [logoBlue.opacity(0.15), logoPurple.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "lock.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [logoBlue, logoPurple],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                VStack(spacing: 8) {
                    Text("Camera Access Required")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
                    
                    Text("We need camera permission for secure biometric login")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.392, green: 0.455, blue: 0.545))
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 12) {
                    GlassButton(
                        text: "Open Settings",
                        icon: "gearshape.fill",
                        isPrimary: true,
                        logoBlue: logoBlue,
                        logoPurple: logoPurple,
                        action: onOpenSettings
                    )
                    
                    Button(action: {
                        print("↩️ Go Back tapped")
                        onDismiss()
                    }) {
                        Text("Go Back")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [logoBlue, logoPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
            )
            .padding(24)
        }
    }
}

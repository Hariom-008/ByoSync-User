import SwiftUI

struct AuthenticationView: View {
    @State private var openEnterNumber: Bool = false
    @State private var openLoginSheet: Bool = false
    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var enrollment: EnrollmentGate
    @EnvironmentObject var router: Router
    @EnvironmentObject var deviceRegistrationVM: DeviceRegistrationViewModel

    @State private var didTapRegister: Bool = false
    @State private var didTapLogin: Bool = false
    @State private var showDeviceAlert: Bool = false
    @State private var deviceAlertMessage: String = ""
    
    @State private var openTestingView: Bool = false
    
    // ✅ FCM Token state
    @State private var hasFCMToken: Bool = false
    @State private var fcmTokenCheckStarted: Bool = false
    
    // Animation states
    @State private var showContent = false
    @State private var currentFeature = 0

    // Colors from the logo gradient
    private let logoBlue = Color(red: 0.0, green: 0.0, blue: 1.0)
    private let logoPurple = Color(red: 0.478, green: 0.0, blue: 1.0)

    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("lock.shield.fill", "Secure", "Biometric protection"),
        ("bolt.fill", "Fast", "Instant payments"),
        ("checkmark.seal.fill", "Trusted", "Bank-grade security")
    ]

    var body: some View {
        ZStack {
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

            AnimatedBackgroundBlobs(
                visible: showContent,
                logoBlue: logoBlue,
                logoPurple: logoPurple
            )

            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                if showContent {
                    logoSection
                        .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                if showContent {
                    bottomSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)

            // ✅ Loading overlay - shows while waiting for FCM token OR device check
            if !hasFCMToken || deviceRegistrationVM.isLoading {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    ProgressView().scaleEffect(1.2)
                    Text(loadingMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
                )
            }
        }
        .onAppear {
            #if DEBUG
            print("🎬 [AuthView] View appeared")
            print("📱 [AuthView] DeviceKey: \(DeviceIdentity.resolve())")
            #endif
            
            // ✅ Check if we already have FCM token
            checkForExistingFCMToken()
            
            // Start animations
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    showContent = true
                }
            }

            // Feature rotation timer
            Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
                withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                    currentFeature = (currentFeature + 1) % features.count
                }
            }
            
            // ✅ Listen for FCM token
            setupFCMTokenListener()
        }
        .onDisappear {
            // ✅ Remove observer when view disappears
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("FCMTokenReceived"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("FCMTokenFailed"), object: nil)
        }
        .onChange(of: hasFCMToken) { hasToken in
            #if DEBUG
            print("🔄 [AuthView] hasFCMToken changed to: \(hasToken)")
            #endif
            
            // ✅ Once we have FCM token, call device registration
            if hasToken && !fcmTokenCheckStarted {
                fcmTokenCheckStarted = true
                
                #if DEBUG
                print("✅ [AuthView] FCM token ready, calling device registration check")
                #endif
                
                deviceRegistrationVM.checkDeviceRegistration()
            }
        }
        .onChange(of: deviceRegistrationVM.isLoading) { isLoading in
            #if DEBUG
            print("🔄 [AuthView] isLoading changed to: \(isLoading)")
            #endif
            
            // When loading completes
            guard !isLoading else { return }
            
            #if DEBUG
            print("✅ [AuthView] Device check completed")
            print("📊 [AuthView] Results - isRegistered: \(deviceRegistrationVM.isDeviceRegistered), hasFaceData: \(deviceRegistrationVM.hasFaceData)")
            #endif
            
            // Update UserSession with the hasFaceData value from backend
            if deviceRegistrationVM.isDeviceRegistered {
                UserSession.shared.hasFaceData = deviceRegistrationVM.hasFaceData
                #if DEBUG
                print("💾 [AuthView] Updated UserSession.hasFaceData to: \(deviceRegistrationVM.hasFaceData)")
                #endif
            }
            
            // Handle register button flow
            if didTapRegister {
                didTapRegister = false
                
                if deviceRegistrationVM.isDeviceRegistered {
                    deviceAlertMessage = "This device is already registered with an existing ByoSync account. You can't register a new account from this device."
                    showDeviceAlert = true
                    
                    #if DEBUG
                    print("🚫 [AuthView] Register blocked: device already registered")
                    #endif
                } else {
                    #if DEBUG
                    print("✅ [AuthView] Register allowed: opening EnterNumberView")
                    #endif
                    openEnterNumber = true
                }
            }
        }
        .sheet(isPresented: $openLoginSheet) {
            LoginView()
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $openEnterNumber) {
            EnterNumberView()
        }
        .navigationDestination(isPresented: $openTestingView) {
            #if DEBUG
            CameraPreparationView(onReady: { })
            #endif
        }
        .alert(deviceAlertMessage, isPresented: $showDeviceAlert) {
            Button("OK", role: .cancel) {
                #if DEBUG
                print("❌ [AuthView] Device alert dismissed")
                #endif
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var loadingMessage: String {
        if !hasFCMToken {
            return "Initializing app…"
        } else if deviceRegistrationVM.isLoading {
            return "Checking device…"
        }
        return "Loading…"
    }

    // MARK: - FCM Token Helpers
    
    // In AuthenticationView, update checkForExistingFCMToken:

    private func checkForExistingFCMToken() {
        // First try synchronous cached token
        if let existingToken = FCMTokenManager.shared.getToken(), !existingToken.isEmpty {
            #if DEBUG
            print("⚡️ [AuthView] FCM token already cached: \(existingToken)")
            #endif
            
            hasFCMToken = true
            return
        }
        
        // If no cached token, try async fetch (checks UserDefaults + Firebase)
        #if DEBUG
        print("🔄 [AuthView] No cached token, attempting fetch...")
        #endif
        
        FCMTokenManager.shared.getFCMToken { token in
            if let token = token {
                #if DEBUG
                print("✅ [AuthView] FCM token fetched: \(token)")
                #endif
                
                self.hasFCMToken = true
            } else {
                #if DEBUG
                print("⚠️ [AuthView] No FCM token yet, will wait for notification")
                #endif
            }
        }
    }
    
    private func setupFCMTokenListener() {
        // ✅ Listen for successful token
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FCMTokenReceived"),
            object: nil,
            queue: .main
        ) { notification in
            if let token = notification.userInfo?["token"] as? String {
                #if DEBUG
                print("🔔 [AuthView] Received FCM token notification: \(token)")
                #endif
                
                hasFCMToken = true
            }
        }
        
        // ✅ Listen for token failure (so we don't hang forever)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FCMTokenFailed"),
            object: nil,
            queue: .main
        ) { notification in
            let error = notification.userInfo?["error"] as? String ?? "Unknown error"
            
            #if DEBUG
            print("⚠️ [AuthView] FCM token failed: \(error)")
            print("💡 [AuthView] Proceeding anyway to avoid blocking user")
            #endif
            
            // Proceed anyway after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                hasFCMToken = true
            }
        }
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        VStack(spacing: 0) {
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
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color(red: 0.392, green: 0.455, blue: 0.545))

            Spacer().frame(height: 28)

            FeaturePill(
                icon: features[currentFeature].icon,
                title: features[currentFeature].title,
                subtitle: features[currentFeature].subtitle,
                logoBlue: logoBlue,
                logoPurple: logoPurple
            )
            .id(currentFeature)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.9).combined(with: .opacity),
                removal: .scale(scale: 0.9).combined(with: .opacity)
            ))
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentFeature)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 8)
            
            GlassButton(
                text: "Login",
                icon: "",
                isPrimary: true,
                logoBlue: logoBlue,
                logoPurple: logoPurple
            ) {
                handleLoginTap()
            }
            .disabled(!hasFCMToken || deviceRegistrationVM.isLoading || !deviceRegistrationVM.hasFaceData || !deviceRegistrationVM.isDeviceRegistered)
            .opacity((!hasFCMToken || deviceRegistrationVM.isLoading || !deviceRegistrationVM.hasFaceData || !deviceRegistrationVM.isDeviceRegistered) ? 0.6 : 1.0)
            

            GlassButton(
                text: "Create Account",
                icon: "person.badge.plus.fill",
                isPrimary: true,
                logoBlue: logoBlue,
                logoPurple: logoPurple
            ) {
                handleRegisterTap()
            }
            .disabled(!hasFCMToken || deviceRegistrationVM.isLoading)
            .opacity((!hasFCMToken || deviceRegistrationVM.isLoading) ? 0.6 : 1.0)

            HStack {
                Text("Your data is encrypted and secure")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(Color(red: 0.580, green: 0.639, blue: 0.722))
                    .multilineTextAlignment(.center)

                Link(destination: URL(string: "https://www.byosync.com/policy")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 9))
                        Text("Privacy Policy")
                            .font(.system(size: 10, weight: .medium))
                            .underline()
                    }
                    .foregroundStyle(
                        LinearGradient(
                            colors: [logoBlue, logoPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.vertical, 4)
                }
                .onTapGesture {
                    #if DEBUG
                    print("📄 [AuthView] Opening policy")
                    #endif
                }
            }

            HStack {
                Text("powered by")
                    .font(.system(size: 8))
                    .foregroundColor(Color(red: 0.580, green: 0.639, blue: 0.722))
                Text("KAVION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 0.580, green: 0.639, blue: 0.722))
            }
        }
    }

    // MARK: - Actions
    
    private func handleRegisterTap() {
        #if DEBUG
        print("🔘 [AuthView] Register button tapped")
        print("📊 [AuthView] Current state - hasFCMToken: \(hasFCMToken), isLoading: \(deviceRegistrationVM.isLoading), isRegistered: \(deviceRegistrationVM.isDeviceRegistered)")
        #endif
        
        // If still waiting for FCM or loading, ignore tap
        guard hasFCMToken, !deviceRegistrationVM.isLoading else {
            #if DEBUG
            print("⏳ [AuthView] Still initializing, ignoring tap")
            #endif
            return
        }
        
        // If already registered, show alert immediately
        if deviceRegistrationVM.isDeviceRegistered {
            deviceAlertMessage = "This device is already registered with an existing ByoSync account. You can't register a new account from this device."
            showDeviceAlert = true
            
            #if DEBUG
            print("🚫 [AuthView] Device already registered, showing alert")
            #endif
            return
        }
        
        // Device not registered, proceed to registration
        #if DEBUG
        print("✅ [AuthView] Device not registered, opening EnterNumberView")
        #endif
        openEnterNumber = true
    }

    private func handleLoginTap() {
        #if DEBUG
        print("🔘 [AuthView] Login button tapped")
        print("📊 [AuthView] Current state - hasFCMToken: \(hasFCMToken), isRegistered: \(deviceRegistrationVM.isDeviceRegistered), hasFaceData: \(deviceRegistrationVM.hasFaceData)")
        #endif
        
        // Login only allowed if we have FCM token, device is registered AND has face data
        guard hasFCMToken else {
            #if DEBUG
            print("🚫 [AuthView] Login blocked: no FCM token")
            #endif
            return
        }
        
        guard deviceRegistrationVM.isDeviceRegistered else {
            #if DEBUG
            print("🚫 [AuthView] Login blocked: device not registered")
            #endif
            return
        }
        
        guard deviceRegistrationVM.hasFaceData else {
            #if DEBUG
            print("🚫 [AuthView] Login blocked: no face data on device")
            #endif
            return
        }
        
        #if DEBUG
        print("✅ [AuthView] Login allowed, preparing for face verification")
        #endif
        
        // ✅ Set up for verification scan - RootView will handle presenting the modal
        FaceAuthManager.shared.setVerificationMode()
        enrollment.markEnrolled()
        enrollment.reload()
        
        // ✅ Trigger scan requirement - RootView will detect this and present MLScan
        AppScanGate.shared.markRequiredDueToInactive() // This sets requireScan = true
        
        #if DEBUG
        print("🎯 [AuthView] Scan requirement set, RootView will present verification modal")
        #endif
    }
}

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
    @State private var hasCompletedInitialDeviceCheck: Bool = false
    
    // Animation states
    @State private var showContent = false
    @State private var currentFeature = 0

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

            // ✅ Loading overlay - shows until we have both FCM token AND device check is done
            if !hasFCMToken || !hasCompletedInitialDeviceCheck {
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
            print("🎬 [AuthView] View appeared")
            print("📱 [AuthView] DeviceKey: \(DeviceIdentity.resolve())")
            
            // ✅ Step 1: Check if we already have FCM token
            checkForExistingFCMToken()
            
            // ✅ Step 2: Start animations
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    showContent = true
                }
            }

            // ✅ Step 3: Feature rotation timer
            Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
                withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                    currentFeature = (currentFeature + 1) % features.count
                }
            }
            
            // ✅ Step 4: Listen for FCM token updates
            setupFCMTokenListener()
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("FCMTokenReceived"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("FCMTokenFailed"), object: nil)
        }
        .onChange(of: hasFCMToken) { _, hasToken in
            print("🔄 [AuthView] hasFCMToken changed to: \(hasToken)")
            
            // ✅ Once we have FCM token, trigger device registration check
            if hasToken && !hasCompletedInitialDeviceCheck {
                print("🔍 [AuthView] FCM token ready - starting device registration check")
                performDeviceRegistrationCheck()
            }
        }
        .onChange(of: deviceRegistrationVM.isLoading) { _, isLoading in
            print("🔄 [AuthView] deviceRegistrationVM.isLoading changed to: \(isLoading)")
            
            // ✅ When loading completes, mark as done
            if !isLoading && !hasCompletedInitialDeviceCheck {
                print("✅ [AuthView] Device check completed")
                print("📊 [AuthView] Results - isRegistered: \(deviceRegistrationVM.isDeviceRegistered), hasFaceData: \(deviceRegistrationVM.hasFaceData)")
                
                hasCompletedInitialDeviceCheck = true
                
                // ✅ Update UserSession with backend data
                if deviceRegistrationVM.isDeviceRegistered {
                    UserSession.shared.hasFaceData = deviceRegistrationVM.hasFaceData
                    print("💾 [AuthView] Updated UserSession.hasFaceData to: \(deviceRegistrationVM.hasFaceData)")
                }
            }
            
            // ✅ Handle register button flow
            if didTapRegister && !isLoading {
                didTapRegister = false
                
                if deviceRegistrationVM.isDeviceRegistered {
                    deviceAlertMessage = "This device is already registered with an existing ByoSync account. You can't register a new account from this device."
                    showDeviceAlert = true
                    print("🚫 [AuthView] Register blocked: device already registered")
                } else {
                    print("✅ [AuthView] Register allowed: opening EnterNumberView")
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
                print("❌ [AuthView] Device alert dismissed")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var loadingMessage: String {
        if !hasFCMToken {
            return "Initializing app…"
        } else if !hasCompletedInitialDeviceCheck {
            return "Checking device…"
        }
        return "Loading…"
    }

    // MARK: - FCM Token Helpers
    
    private func checkForExistingFCMToken() {
        // ✅ Try synchronous cached token first
        if let existingToken = FCMTokenManager.shared.getToken(), !existingToken.isEmpty {
            print("⚡️ [AuthView] FCM token already cached: \(existingToken)")
            hasFCMToken = true
            return
        }
        
        // ✅ If no cached token, try async fetch
        print("🔄 [AuthView] No cached token, attempting fetch...")
        
        FCMTokenManager.shared.getFCMToken { token in
            if let token = token {
                print("✅ [AuthView] FCM token fetched: \(token)")
                self.hasFCMToken = true
            } else {
                print("⚠️ [AuthView] No FCM token yet, will wait for notification")
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
                print("🔔 [AuthView] Received FCM token notification: \(token)")
                hasFCMToken = true
            }
        }
        
        // ✅ Listen for token failure
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FCMTokenFailed"),
            object: nil,
            queue: .main
        ) { notification in
            let error = notification.userInfo?["error"] as? String ?? "Unknown error"
            print("⚠️ [AuthView] FCM token failed: \(error)")
            print("💡 [AuthView] Proceeding anyway to avoid blocking user")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                hasFCMToken = true
            }
        }
    }
    
    // ✅ NEW: Single place to call device registration check
    private func performDeviceRegistrationCheck() {
        print("🔍 [AuthView] Performing device registration check...")
        
        // ✅ Check if we have a cached value we can use while loading
        if let cachedValue = UserDefaults.standard.object(forKey: "isDeviceRegisteredKey") as? Bool {
            print("📦 [AuthView] Using cached isDeviceRegistered: \(cachedValue)")
            deviceRegistrationVM.isDeviceRegistered = cachedValue
        }
        
        // ✅ Now fetch fresh data from backend
        deviceRegistrationVM.checkDeviceRegistration()
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
            .disabled(!hasCompletedInitialDeviceCheck || !deviceRegistrationVM.isDeviceRegistered || !deviceRegistrationVM.hasFaceData)
            .opacity((!hasCompletedInitialDeviceCheck || !deviceRegistrationVM.isDeviceRegistered || !deviceRegistrationVM.hasFaceData) ? 0.6 : 1.0)
            

            GlassButton(
                text: "Create Account",
                icon: "person.badge.plus.fill",
                isPrimary: true,
                logoBlue: logoBlue,
                logoPurple: logoPurple
            ) {
                handleRegisterTap()
            }
            .disabled(!hasCompletedInitialDeviceCheck)
            .opacity(!hasCompletedInitialDeviceCheck ? 0.6 : 1.0)

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
                    print("📄 [AuthView] Opening policy")
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
        print("🔘 [AuthView] Register button tapped")
        print("📊 [AuthView] Current state - hasCompleted: \(hasCompletedInitialDeviceCheck), isRegistered: \(deviceRegistrationVM.isDeviceRegistered)")
        
        // ✅ If device check not complete yet, ignore
        guard hasCompletedInitialDeviceCheck else {
            print("⏳ [AuthView] Device check not complete, ignoring tap")
            return
        }
        
        // ✅ If already registered, show alert immediately
        if deviceRegistrationVM.isDeviceRegistered {
            deviceAlertMessage = "This device is already registered with an existing ByoSync account. You can't register a new account from this device."
            showDeviceAlert = true
            print("🚫 [AuthView] Device already registered, showing alert")
            return
        }
        
        // ✅ Device not registered, proceed to registration
        print("✅ [AuthView] Device not registered, opening EnterNumberView")
        openEnterNumber = true
    }

//    private func handleLoginTap() {
//        print("🔘 [AuthView] Login button tapped")
//        print("📊 [AuthView] Current state - hasCompleted: \(hasCompletedInitialDeviceCheck), isRegistered: \(deviceRegistrationVM.isDeviceRegistered), hasFaceData: \(deviceRegistrationVM.hasFaceData)")
//        
//        // ✅ Login only allowed if device check is complete, device is registered AND has face data
//        guard hasCompletedInitialDeviceCheck else {
//            print("🚫 [AuthView] Login blocked: device check not complete")
//            return
//        }
//        
//        guard deviceRegistrationVM.isDeviceRegistered else {
//            print("🚫 [AuthView] Login blocked: device not registered")
//            return
//        }
//        
//        guard deviceRegistrationVM.hasFaceData else {
//            print("🚫 [AuthView] Login blocked: no face data on device")
//            return
//        }
//        
//        print("✅ [AuthView] Login allowed, preparing for face verification")
//        
//        // ✅ Set up for verification scan - RootView will handle presenting the modal
//        FaceAuthManager.shared.setVerificationMode()
//        enrollment.markEnrolled()
//        enrollment.reload()
//        
//        // ✅ Trigger scan requirement - RootView will detect this and present MLScan
//        AppScanGate.shared.markRequiredDueToInactive()
//        
//        print("🎯 [AuthView] Scan requirement set, RootView will present verification modal")
//    }
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
        AppScanGate.shared.markRequiredOnTerminate()
        #if DEBUG
        print("🎯 [AuthView] Scan requirement set, RootView will present verification modal")
        #endif
    }
}

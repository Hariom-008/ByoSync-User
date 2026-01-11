import SwiftUI

struct AuthenticationView: View {
    @State private var openEnterNumber: Bool = false
    @State private var openLoginSheet: Bool = false
    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var enrollment: EnrollmentGate
    @EnvironmentObject var router: Router

    @StateObject private var deviceRegistrationVM = DeviceRegistrationViewModel()

    @State private var didTapRegister: Bool = false
    @State private var didTapLogin: Bool = false

    @State private var showDeviceAlert: Bool = false
    @State private var deviceAlertMessage: String = ""

    @State private var openTestingView: Bool = false

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

            if deviceRegistrationVM.isLoading {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    ProgressView().scaleEffect(1.2)
                    Text("Checking device…")
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
        .onAppear{
            deviceRegistrationVM.checkDeviceRegistration()
        }
        .onAppear {
            #if DEBUG
            print("AuthenticationView appeared")
            print("DeviceKey: \(DeviceIdentity.resolve())")
            #endif

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    showContent = true
                }
            }

            Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
                withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                    currentFeature = (currentFeature + 1) % features.count
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
                print("Device alert dismissed")
                #endif
            }
        }
        .onChange(of: deviceRegistrationVM.isLoading) { isLoading in
            // Only the register flow uses this onChange gate
            guard !isLoading, didTapRegister else { return }
            didTapRegister = false

            if deviceRegistrationVM.isDeviceRegistered {
                deviceAlertMessage =
                "This device is already registered with an existing ByoSync account. You can't register a new account from this device."
                showDeviceAlert = true

                #if DEBUG
                print("Register blocked: device already registered")
                #endif
            } else {
                #if DEBUG
                print("Register allowed: opening EnterNumberView")
                #endif
                openEnterNumber = true
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
            .disabled(deviceRegistrationVM.isLoading || !UserSession.shared.hasFaceData || !deviceRegistrationVM.isDeviceRegistered)
            .opacity(deviceRegistrationVM.isLoading ? 0.6 : 1.0)
            

            GlassButton(
                text: "Create Account",
                icon: "person.badge.plus.fill",
                isPrimary: true,
                logoBlue: logoBlue,
                logoPurple: logoPurple
            ) {
                handleRegisterTap()
            }
            .disabled(deviceRegistrationVM.isLoading)
            .opacity(deviceRegistrationVM.isLoading ? 0.6 : 1.0)

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
                    print("Opening policy")
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
        guard !deviceRegistrationVM.isLoading else { return }

        didTapRegister = true

        let deviceKey = DeviceIdentity.resolve()
        if !deviceKey.isEmpty {
            deviceRegistrationVM.checkDeviceRegistration()
        } else {
            #if DEBUG
            print("No deviceKey, opening EnterNumberView")
            #endif
            openEnterNumber = true
        }
    }

    private func handleLoginTap() {
        guard !deviceRegistrationVM.isLoading else { return }

        didTapLogin = true

        let deviceKey = DeviceIdentity.resolve()
        guard !deviceKey.isEmpty else {
            #if DEBUG
            print("Login blocked: empty deviceKey")
            #endif
            return
        }

        guard deviceRegistrationVM.isDeviceRegistered else {
            #if DEBUG
            print("Login blocked: device not registered")
            #endif
            return
        }

        // ✅ IMPORTANT: Use RouterView's fullScreenCover route (no local fullScreenCover here).
        #if DEBUG
        print("Opening MLScan via router")
        #endif
        router.navigate(to: .mlScan, style: .fullScreenCover)
    }
}

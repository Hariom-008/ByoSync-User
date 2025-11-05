//import Foundation
////import FirebaseCore
////import FirebaseAuth
//import Combine
//import SwiftUI
//
//enum AuthStage {
//    case phoneEntry
//    case otpEntry
//    case verified
//}
//
//final class PhoneAuthViewModel: NSObject, ObservableObject {
//    // MARK: - Published State
//    @Published var phoneNumber: String = ""
//    @Published var otpCode: String = ""
//    @Published var isLoading: Bool = false
//    @Published var errorMessage: String = ""
//    @Published var successMessage: String = ""
//    @Published var stage: AuthStage = .phoneEntry
//    @Published var timeRemaining: Int = 0
//    @Published var canResendOTP: Bool = false
//
//    // MARK: - Private
//    private var verificationID: String?
//    private var timerCancellable: AnyCancellable?
//    private let tag = "[PhoneAuthViewModel]"
//
//    override init() {
//        super.init()
//        if FirebaseApp.app() == nil {
//            FirebaseApp.configure()
//            print("\(tag) Firebase configured")
//        }
//    }
//
//    // MARK: - Send OTP
//    func sendOTP() {
//        let trimmed = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard trimmed.count == 10 else {
//            errorMessage = "Enter a valid 10-digit number"
//            return
//        }
//
//        let formatted = "+91" + trimmed
//        print("\(tag) Sending OTP to \(formatted)")
//        isLoading = true
//        errorMessage = ""
//
//        // ✅ ONLY bypass for simulator (not iPad)
//        #if targetEnvironment(simulator)
//        simulateOtpFlow(device: "Simulator")
//        return
//        #endif
//
//        // ✅ Actual Firebase flow (works on ALL real devices including iPad)
//        Task {
//            do {
//                let verificationID = try await PhoneAuthProvider.provider()
//                    .verifyPhoneNumber(formatted, uiDelegate: nil)
//                await MainActor.run {
//                    self.verificationID = verificationID
//                    self.stage = .otpEntry
//                    self.isLoading = false
//                    self.successMessage = "OTP sent successfully"
//                    self.startResendTimer()
//                }
//            } catch {
//                print("\(self.tag) ❌ OTP send failed: \(error.localizedDescription)")
//                await MainActor.run {
//                    self.isLoading = false
//                    self.errorMessage = "OTP send failed: \(error.localizedDescription)"
//                }
//            }
//        }
//    }
//
//    // MARK: - Simulated OTP Flow for Simulator ONLY
//    private func simulateOtpFlow(device: String) {
//        print("\(tag) ⚙️ Simulating OTP flow on \(device)")
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
//            self.isLoading = false
//            self.stage = .otpEntry
//            self.successMessage = "\(device) mode: OTP auto-sent"
//            self.startResendTimer()
//        }
//    }
//
//    // MARK: - Verify OTP
//    @MainActor
//    func verifyOTP() async -> Bool {
//        guard otpCode.count == 6 else {
//            errorMessage = "OTP must be 6 digits"
//            return false
//        }
//
//        // ✅ ONLY simulate for simulator (not iPad)
//        #if targetEnvironment(simulator)
//        print("\(tag) ✅ Simulated verification successful")
//        isLoading = false
//        successMessage = "Simulated verification successful"
//        stage = .verified
//        return true
//        #endif
//
//        guard let verificationID = verificationID else {
//            errorMessage = "Session expired. Request a new OTP."
//            return false
//        }
//
//        isLoading = true
//        errorMessage = ""
//        print("\(tag) Verifying OTP...")
//
//        do {
//            let credential = PhoneAuthProvider.provider()
//                .credential(withVerificationID: verificationID, verificationCode: otpCode)
//            let result = try await Auth.auth().signIn(with: credential)
//            print("\(tag) ✅ Verified user: \(result.user.uid)")
//
//            isLoading = false
//            successMessage = "Phone verified successfully"
//            stage = .verified
//            return true
//        } catch {
//            print("\(tag) ❌ Verification failed: \(error.localizedDescription)")
//            isLoading = false
//            errorMessage = error.localizedDescription
//            return false
//        }
//    }
//
//    // MARK: - Resend OTP
//    func resendOTP() {
//        guard canResendOTP else { return }
//        otpCode = ""
//        canResendOTP = false
//        sendOTP()
//    }
//
//    // MARK: - Timer
//    private func startResendTimer() {
//        timerCancellable?.cancel()
//        timeRemaining = 60
//        canResendOTP = false
//
//        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
//            .autoconnect()
//            .sink { [weak self] _ in
//                guard let self = self else { return }
//                self.timeRemaining -= 1
//                if self.timeRemaining <= 0 {
//                    self.canResendOTP = true
//                    self.timerCancellable?.cancel()
//                }
//            }
//    }
//
//    // MARK: - Reset
//    func resetState() {
//        phoneNumber = ""
//        otpCode = ""
//        verificationID = nil
//        errorMessage = ""
//        successMessage = ""
//        stage = .phoneEntry
//        canResendOTP = false
//        timeRemaining = 0
//        timerCancellable?.cancel()
//    }
//}
//
//import SwiftUI
//import FirebaseAuth
//
//struct PhoneAuthenticationView: View {
//    @StateObject private var vm = PhoneAuthViewModel()
//    @State private var showSuccessAlert = false
//    @State private var navigateNext = false
//    
//    // Brand colors
//    let primary = Color(hex: "4B548D")
//    let accent = Color(hex: "6B75B5")
//    
//    var body: some View {
//        NavigationStack {
//            ZStack {
//                // Background gradient
//                LinearGradient(
//                    gradient: Gradient(colors: [primary.opacity(0.03), primary.opacity(0.1)]),
//                    startPoint: .topLeading,
//                    endPoint: .bottomTrailing
//                )
//                .ignoresSafeArea()
//                
//                VStack(spacing: 0) {
//                    header
//                    
//                    ScrollView(showsIndicators: false) {
//                        VStack(spacing: 32) {
//                            switch vm.stage {
//                            case .phoneEntry:
//                                phoneInput
//                            case .otpEntry:
//                                otpInput
//                            case .verified:
//                                verifiedSection
//                            }
//                        }
//                        .padding(24)
//                    }
//                    
//                    bottomButton
//                }
//            }
//            .alert("Success", isPresented: $showSuccessAlert) {
//                Button("OK") { navigateNext = true }
//            } message: {
//                Text(vm.successMessage)
//            }
//            .navigationDestination(isPresented: $navigateNext) {
//                // Replace with your next authenticated screen
//                Text("✅ Authentication Successful!")
//                    .font(.title2.bold())
//                    .foregroundColor(primary)
//            }
//        }
//    }
//    
//    // MARK: - Header
//    private var header: some View {
//        HStack {
//            VStack(alignment: .leading, spacing: 6) {
//                Text("Phone Verification")
//                    .font(.system(size: 26, weight: .bold))
//                Text("Secure your account with OTP login")
//                    .font(.system(size: 14))
//                    .foregroundColor(.gray)
//            }
//            Spacer()
//            Image(systemName: "phone.fill")
//                .font(.system(size: 30))
//                .foregroundColor(primary)
//                .padding(12)
//                .background(Circle().fill(primary.opacity(0.1)))
//        }
//        .padding(.horizontal, 20)
//        .padding(.top, 32)
//    }
//    
//    // MARK: - Phone Input
//    private var phoneInput: some View {
//        VStack(spacing: 20) {
//            TextField("Enter 10-digit phone number", text: $vm.phoneNumber)
//                .keyboardType(.numberPad)
//                .padding()
//                .background(Color(.systemGray6))
//                .cornerRadius(12)
//                .font(.system(size: 18, weight: .semibold))
//                .foregroundColor(.primary)
//            
//            if !vm.errorMessage.isEmpty {
//                errorBox(vm.errorMessage)
//            }
//        }
//    }
//    
//    // MARK: - OTP Input
//    private var otpInput: some View {
//        VStack(spacing: 20) {
//            Text("Enter 6-digit OTP")
//                .font(.headline)
//            
//            TextField("000000", text: $vm.otpCode)
//                .keyboardType(.numberPad)
//                .multilineTextAlignment(.center)
//                .font(.system(size: 30, weight: .bold, design: .monospaced))
//                .padding()
//                .background(Color(.systemGray6))
//                .cornerRadius(12)
//                .onChange(of: vm.otpCode) { newValue in
//                    vm.otpCode = String(newValue.prefix(6).filter { $0.isNumber })
//                }
//            
//            if !vm.errorMessage.isEmpty {
//                errorBox(vm.errorMessage)
//            }
//            
//            // Resend timer / button
//            HStack {
//                Image(systemName: "clock.fill")
//                    .foregroundColor(.orange)
//                    .font(.system(size: 14))
//                if vm.canResendOTP {
//                    Button("Resend OTP") {
//                        vm.resendOTP()
//                    }
//                    .font(.subheadline.bold())
//                    .foregroundColor(primary)
//                } else {
//                    Text("Resend in \(vm.timeRemaining)s")
//                        .font(.subheadline)
//                        .foregroundColor(.gray)
//                }
//                Spacer()
//            }
//        }
//    }
//    
//    // MARK: - Verified Section
//    private var verifiedSection: some View {
//        VStack(spacing: 16) {
//            Image(systemName: "checkmark.shield.fill")
//                .font(.system(size: 60))
//                .foregroundColor(.green)
//                .padding(.bottom, 8)
//            
//            Text("Phone Verified Successfully")
//                .font(.title3.bold())
//            
//            Text("Proceeding to next step...")
//                .font(.subheadline)
//                .foregroundColor(.gray)
//        }
//        .padding(.top, 40)
//    }
//    
//    // MARK: - Bottom Button
//    private var bottomButton: some View {
//        VStack(spacing: 16) {
//            if vm.stage == .phoneEntry {
//                Button {
//                    vm.sendOTP()
//                } label: {
//                    buttonLabel(
//                        title: vm.isLoading ? "Sending..." : "Send OTP",
//                        showLoader: vm.isLoading
//                    )
//                }
//                .disabled(vm.isLoading || vm.phoneNumber.count != 10)
//                
//            } else if vm.stage == .otpEntry {
//                Button {
//                    Task {
//                        let success = await vm.verifyOTP()
//                        if success { showSuccessAlert = true }
//                    }
//                } label: {
//                    buttonLabel(
//                        title: vm.isLoading ? "Verifying..." : "Verify OTP",
//                        showLoader: vm.isLoading
//                    )
//                }
//                .disabled(vm.isLoading || vm.otpCode.count != 6)
//                
//                Button("Change Phone Number") {
//                    vm.resetState()
//                }
//                .font(.subheadline.bold())
//                .foregroundColor(primary)
//                .padding(.top, 8)
//            }
//        }
//        .padding(20)
//    }
//    
//    // MARK: - Helper Views
//    private func buttonLabel(title: String, showLoader: Bool) -> some View {
//        HStack {
//            if showLoader { ProgressView().tint(.white) }
//            Text(title)
//        }
//        .frame(maxWidth: .infinity)
//        .padding()
//        .foregroundColor(.white)
//        .background(
//            LinearGradient(
//                colors: [primary, accent],
//                startPoint: .topLeading, endPoint: .bottomTrailing
//            )
//        )
//        .cornerRadius(12)
//        .shadow(color: primary.opacity(0.3), radius: 8, x: 0, y: 4)
//    }
//    
//    private func errorBox(_ message: String) -> some View {
//        HStack(spacing: 8) {
//            Image(systemName: "xmark.octagon.fill")
//                .foregroundColor(.red)
//            Text(message)
//                .font(.system(size: 13))
//                .foregroundColor(.red)
//            Spacer()
//        }
//        .padding(12)
//        .background(Color.red.opacity(0.06))
//        .cornerRadius(10)
//    }
//}
//
//#Preview {
//    PhoneAuthenticationView()
//}

import Foundation
import FirebaseAuth
import FirebaseMessaging
import Combine

final class PhoneOTPViewModel: ObservableObject {
    @Published var phoneNumber: String = ""           // 10 digits only
    @Published var selectedCountryCode: String = "+91"
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var otpSent: Bool = false

    @Published var canResend: Bool = false
    @Published var resendCountdown: Int = 30

    @Published var verificationID: String?
    @Published var verificationCode: String = ""
    @Published var isAuthenticated: Bool = false

    private var resendTimer: Timer?

    // MARK: - Computed
    var isValidPhoneNumber: Bool {
        let digits = phoneNumber.filter { $0.isNumber }
        guard digits.count == 10 else { return false }
        guard let first = digits.first else { return false }
        return ["6", "7", "8", "9"].contains(String(first))
    }

    var fullPhoneNumber: String {
        let digits = phoneNumber.filter { $0.isNumber }
        return "\(selectedCountryCode)\(digits)" // +916XXXXXXXXX
    }

    // MARK: - Public API
    func sendOTP() {
        guard isValidPhoneNumber else {
            showErrorMessage("Please enter a valid 10-digit mobile number starting with 6-9")
            return
        }
        isLoading = true
        errorMessage = nil
        sendVerificationCode()
    }

    func resendOTP() {
        guard canResend else { return }
        isLoading = true
        errorMessage = nil
        canResend = false
        sendVerificationCode()
    }

    func verifyOTP(code: String) {
        guard code.count == 6, code.allSatisfy({ $0.isNumber }) else {
            showErrorMessage("Please enter a valid 6-digit OTP")
            return
        }
        verificationCode = code
        isLoading = true
        errorMessage = nil
        verifyCode()
    }

    func updatePhoneNumber(_ newValue: String) {
        let digits = newValue.filter { $0.isNumber }
        phoneNumber = String(digits.prefix(10))
        if !phoneNumber.isEmpty { errorMessage = nil }
    }

    // MARK: - Firebase internals
    private func sendVerificationCode() {
        let phone = fullPhoneNumber

        PhoneAuthProvider.provider()
            .verifyPhoneNumber(phone, uiDelegate: nil) { [weak self] verificationID, error in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        self.handleVerificationError(error)
                        return
                    }
                    guard let verificationID else {
                        self.showErrorMessage("Failed to get verification ID")
                        return
                    }

                    self.verificationID = verificationID
                    self.otpSent = true
                    self.startResendTimer()
                    self.errorMessage = nil
                }
            }
    }

    private func verifyCode() {
        guard let verificationID else {
            isLoading = false
            showErrorMessage("Verification ID is missing. Please request a new code.")
            return
        }

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )

        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    self.handleSignInError(error)
                    return
                }
                guard authResult != nil else {
                    self.showErrorMessage("Authentication failed. Please try again.")
                    return
                }

                self.generateAndSaveFCMToken()
                self.isAuthenticated = true
                self.errorMessage = nil
            }
        }
    }

    // MARK: - FCM
    private func generateAndSaveFCMToken() {
        Messaging.messaging().token { token, _ in
            guard let token else { return }
            UserDefaults.standard.set(token, forKey: "fcmToken")
            UserDefaults.standard.synchronize()
        }
    }

    // MARK: - Errors
    private func handleVerificationError(_ error: Error) {
        let nsError = error as NSError
        if let errorCode = AuthErrorCode(rawValue: nsError.code) {
            switch errorCode {
            case .invalidPhoneNumber:
                showErrorMessage("Invalid phone number format")
            case .missingPhoneNumber:
                showErrorMessage("Phone number is missing")
            case .quotaExceeded:
                showErrorMessage("SMS quota exceeded. Try again later.")
            case .captchaCheckFailed:
                showErrorMessage("reCAPTCHA verification failed")
            case .invalidAppCredential:
                showErrorMessage("Invalid APNs token. Check Firebase configuration.")
            case .missingAppCredential:
                showErrorMessage("Missing APNs configuration")
            case .internalError:
                showErrorMessage("Internal Firebase error. Check your configuration.")
            case .networkError:
                showErrorMessage("Network error. Check your internet connection.")
            default:
                showErrorMessage(error.localizedDescription)
            }
        } else {
            showErrorMessage(error.localizedDescription)
        }
    }

    private func handleSignInError(_ error: Error) {
        let nsError = error as NSError
        if let errorCode = AuthErrorCode(rawValue: nsError.code) {
            switch errorCode {
            case .invalidVerificationCode:
                showErrorMessage("Invalid verification code. Please try again.")
            case .sessionExpired:
                showErrorMessage("Verification code expired. Request a new one.")
            case .invalidVerificationID:
                showErrorMessage("Invalid verification ID. Request a new code.")
            case .userDisabled:
                showErrorMessage("This account has been disabled.")
            case .tooManyRequests:
                showErrorMessage("Too many attempts. Try again later.")
            default:
                showErrorMessage(error.localizedDescription)
            }
        } else {
            showErrorMessage(error.localizedDescription)
        }
    }

    // MARK: - Timer
    private func startResendTimer() {
        canResend = false
        resendCountdown = 30

        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if self.resendCountdown > 0 {
                self.resendCountdown -= 1
            } else {
                self.canResend = true
                timer.invalidate()
            }
        }
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    deinit { resendTimer?.invalidate() }
}

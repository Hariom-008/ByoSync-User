import Foundation
import Combine

final class PhoneOTPViewModel: ObservableObject {
    @Published var phoneNumber: String = ""
    @Published var selectedCountryCode: String = "+91"
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var otpSent: Bool = false
    @Published var canResend: Bool = false
    @Published var resendCountdown: Int = 30
    
    private var cancellables = Set<AnyCancellable>()
    private var resendTimer: Timer?
    private let repository = OTPRepository.shared
    
    // MARK: - Computed Properties
    var isValidPhoneNumber: Bool {
        let digits = phoneNumber.filter { $0.isNumber }
        
        // Must be exactly 10 digits
        guard digits.count == 10 else { return false }
        
        // First digit must be 6, 7, 8, or 9
        guard let firstDigit = digits.first,
              ["6", "7", "8", "9"].contains(String(firstDigit)) else {
            return false
        }
        
        return true
    }
    
    var fullPhoneNumber: String {
        // Returns format: +916XXXXXXXXX
        let digits = phoneNumber.filter { $0.isNumber }
        return "\(selectedCountryCode)\(digits)"
    }
    
    // MARK: - Actions
    func sendOTP() {
        guard isValidPhoneNumber else {
            showErrorMessage("Please enter a valid 10-digit mobile number starting with 6-9")
            return
        }
        
        print("🚀 Sending OTP for: \(fullPhoneNumber)")
        
        isLoading = true
        errorMessage = nil
        
        repository.sendPhoneOTP(
            phoneNumber: fullPhoneNumber
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.handleOTPSendResult(result)
            }
        }
    }
    
    func resendOTP() {
        guard canResend else { return }
        
        isLoading = true
        errorMessage = nil
        
        repository.resendOTP(
            phoneNumber: fullPhoneNumber
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.handleOTPSendResult(result)
            }
        }
    }
    
    func updatePhoneNumber(_ newValue: String) {
        // Only keep digits and limit to 10
        let digits = newValue.filter { $0.isNumber }
        phoneNumber = String(digits.prefix(10))
        
        // Clear error when user starts typing
        if !phoneNumber.isEmpty {
            errorMessage = nil
        }
    }
    
    // MARK: - Private Methods
    private func handleOTPSendResult(_ result: Result<PhoneOTPResponse, APIError>) {
        switch result {
        case .success(let response):
            if response.success {
                otpSent = true
                startResendTimer()
                print("✅ OTP sent successfully: \(response.message)")
            } else {
                showErrorMessage(response.message)
            }
            
        case .failure(let error):
            showErrorMessage(error.localizedDescription)
            print("❌ Failed to send OTP: \(error.localizedDescription)")
        }
    }
    
    private func startResendTimer() {
        canResend = false
        resendCountdown = 30
        
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
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
    
    deinit {
        resendTimer?.invalidate()
    }
}

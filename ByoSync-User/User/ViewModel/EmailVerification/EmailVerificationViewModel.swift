//
//  EmailVerificationViewModel.swift
//  ByoSync
//
//  Updated by Hari's Mac on 22.10.2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class EmailVerificationViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var email: String = ""
    @Published var otp: String = ""
    
    @Published var isLoading: Bool = false
    @Published var isSendingOTP: Bool = false
    @Published var isVerifyingOTP: Bool = false
    
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var alertTitle: String = ""
    
    @Published var otpSent: Bool = false
    @Published var emailVerified: Bool = false
    
    // Timer for resend OTP
    @Published var canResendOTP: Bool = true
    @Published var resendTimer: Int = 0
    private var timer: Timer?
    
    // MARK: - Private Properties
    private let repository = EmailVerificationRepository.shared
    private let userSession = UserSession.shared
    
    // MARK: - Initialization
    init() {
        // Load email from UserSession if available
        if let currentUser = userSession.currentUser {
            self.email = currentUser.email
            print("✅ Loaded email from UserSession: \(currentUser.email)")
        }
    }
    
    // MARK: - Validation
    var isEmailValid: Bool {
        !email.isEmpty && isValidEmail(email)
    }
    
    var isOTPValid: Bool {
        !otp.isEmpty && otp.count == 6  // 6-digit OTP
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    // MARK: - Send Email OTP
    func sendOTP() {
        // Validate email
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            showAlertMessage(title: "Invalid Input", message: "Please enter your email")
            return
        }
        
        guard isValidEmail(email) else {
            showAlertMessage(title: "Invalid Email", message: "Please enter a valid email address")
            return
        }
        
        isSendingOTP = true
        isLoading = true
        
        repository.sendEmailOTP() { [weak self] result in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.isSendingOTP = false
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    self.otpSent = true
                    self.startResendTimer()
                    print("✅ OTP sent successfully: \(response.message)")
                    // Don't show alert for successful OTP send, just start timer
                    
                case .failure(let error):
                    self.otpSent = false
                    self.handleError(error, errorTitle: "Failed to Send OTP")
                }
            }
        }
    }
    
    // MARK: - Verify Email OTP
    func verifyOTP() {
        // Validate OTP
        guard !otp.trimmingCharacters(in: .whitespaces).isEmpty else {
            showAlertMessage(title: "Invalid Input", message: "Please enter the OTP")
            return
        }
        
        guard otp.count == 6 else {
            showAlertMessage(title: "Invalid OTP", message: "OTP must be 6 digits")
            return
        }
        
        isVerifyingOTP = true
        isLoading = true
        
        // ✅ Only send OTP, not email (matching Android implementation)
        repository.verifyEmailOTP(
            otp: otp.trimmingCharacters(in: .whitespaces)
        ) { [weak self] result in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.isVerifyingOTP = false
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    self.emailVerified = true
                    self.stopResendTimer()
                    
                    // ✅ UPDATE EMAIL VERIFICATION STATUS IN USER SESSION
                    self.userSession.setEmailVerified(true)
                    
                    self.showAlertMessage(
                        title: "Email Verified",
                        message: response.message
                    )
                    print("✅ Email verified successfully: \(response.message)")
                    
                case .failure(let error):
                    self.emailVerified = false
                    self.handleError(error, errorTitle: "Verification Failed")
                }
            }
        }
    }
    
    // MARK: - Resend OTP
    func resendOTP() {
        guard canResendOTP else { return }
        otp = "" // Clear previous OTP
        sendOTP()
    }
    
    // MARK: - Timer Management
    private func startResendTimer() {
        canResendOTP = false
        resendTimer = 60 // 60 seconds
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                if self.resendTimer > 0 {
                    self.resendTimer -= 1
                } else {
                    self.stopResendTimer()
                }
            }
        }
    }
    
    private func stopResendTimer() {
        timer?.invalidate()
        timer = nil
        canResendOTP = true
        resendTimer = 0
    }
    
    // MARK: - Helper Methods
    private func handleError(_ error: APIError, errorTitle: String) {
        var message = "Something went wrong"
        
        showAlertMessage(title: errorTitle, message: message)
        print("❌ Error: \(message)")
    }
    
    private func showAlertMessage(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
    
    // MARK: - Reset
    func reset() {
        email = ""
        otp = ""
        otpSent = false
        emailVerified = false
        alertMessage = ""
        alertTitle = ""
        showAlert = false
        stopResendTimer()
    }
    
//    deinit {
//        stopResendTimer()
//    }
}

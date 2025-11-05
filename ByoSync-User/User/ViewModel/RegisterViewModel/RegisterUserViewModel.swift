import Foundation
import Combine
import UIKit

final class RegisterUserViewModel: ObservableObject {
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var email: String = ""
    @Published var phoneNumber: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var registrationSuccess: Bool = false
    @Published var deviceId: String = "12345678"
    @Published var deviceName: String = "iPhone 15"
    
    private let repository = RegisterUserRepository.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var allFieldsFilled: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !email.isEmpty &&
        !phoneNumber.isEmpty
    }
    
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    var canSubmit: Bool {
        allFieldsFilled && isValidEmail
    }
    
    // MARK: - Actions
    func registerUser() {
        guard canSubmit else {
            if !isValidEmail {
                showErrorMessage("Please enter a valid email address")
            } else {
                showErrorMessage("Please fill in all fields")
            }
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        print("🚀 Starting user registration...")
        print("Name: \(firstName) \(lastName)")
        print("Email: \(email)")
        print("Phone: \(phoneNumber)")
        print("📱 Device ID: \(deviceId)")
        print("📱 Device Name: \(deviceName)")
        
        repository.registerUser(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: phoneNumber,
            deviceId: deviceId,
            deviceName: deviceName
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.handleRegistrationResult(result)
            }
        }
    }
    
    // MARK: - Private Methods
    private func handleRegistrationResult(_ result: Result<APIResponse<LoginData>, APIError>) {
        switch result {
        case .success(let response):
            print("✅ Registration successful: \(response.message)")
            
            // Check if we have user data
            if let userData = response.data?.user {
                print("👤 User registered: \(userData.firstName) \(userData.lastName)")
                print("📧 Email: \(userData.email)")
                print("✉️ Email verified: \(userData.emailVerified)")
            }
            
            // Check if we have device data
            if let deviceData = response.data?.device {
                print("📱 Device registered: \(deviceData.deviceName ?? "Unknown")")
                print("🔑 Device Primary: \(deviceData.isPrimary)")
                print("🔒 Token saved: \(deviceData.token != nil)")
            }
            
            registrationSuccess = true
            
        case .failure(let error):
            print("❌ Registration failed: \(error.localizedDescription)")
            
            // Handle specific error types
            switch error {
            case .unauthorized:
                showErrorMessage("Authentication failed. Please try again.")
            case .serverError:
                showErrorMessage("Server error. Please try again later.")
            case .networkError:
                showErrorMessage("Network error. Please check your connection.")
            case .decodingError(let message):
                showErrorMessage("Data error: \(message)")
            case .mismatchedHmac:
                showErrorMessage("Security validation failed. Please try again.")
            case .failedToGenerateHmac:
                showErrorMessage("Failed to generate security key.")
            default:
                showErrorMessage(error.localizedDescription)
            }
        }
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
    // MARK: - Field Validation
    func validateEmail() -> String? {
        guard !email.isEmpty else { return nil }
        return isValidEmail ? nil : "Invalid email format"
    }
    
    func formatPhoneNumber(_ number: String) -> String {
        let digits = number.filter { $0.isNumber }
        let trimmed = String(digits.prefix(10))
        
        var formatted = ""
        for (index, digit) in trimmed.enumerated() {
            if index == 3 || index == 6 {
                formatted += " "
            }
            formatted.append(digit)
        }
        return formatted
    }
    
    // MARK: - Clear Form
    func clearForm() {
        firstName = ""
        lastName = ""
        email = ""
        phoneNumber = ""
        errorMessage = nil
        showError = false
    }
}

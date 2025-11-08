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
    @Published var navigateToMainTab: Bool = false
    @Published var deviceId: String = "123456c"
    @Published var deviceName: String = "iPhone 15"
    
    private let repository = RegisterUserRepository.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var allFieldsFilled: Bool {
        let filled = !firstName.isEmpty &&
                     !lastName.isEmpty &&
                     !email.isEmpty &&
                     !phoneNumber.isEmpty
        print("📋 [VM] All fields filled: \(filled)")
        print("   - First Name: '\(firstName)' (empty: \(firstName.isEmpty))")
        print("   - Last Name: '\(lastName)' (empty: \(lastName.isEmpty))")
        print("   - Email: '\(email)' (empty: \(email.isEmpty))")
        print("   - Phone: '\(phoneNumber)' (empty: \(phoneNumber.isEmpty))")
        return filled
    }
    
    var isValidEmail: Bool {
        guard !email.isEmpty else {
            print("📧 [VM] Email is empty")
            return false
        }
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        let valid = emailPredicate.evaluate(with: email)
        print("📧 [VM] Email '\(email)' is valid: \(valid)")
        return valid
    }
    
    var canSubmit: Bool {
        let can = allFieldsFilled && isValidEmail
        print("✅ [VM] Can submit: \(can)")
        return can
    }
    
    // MARK: - Actions
    func registerUser() {
        print("\n" + String(repeating: "=", count: 50))
        print("🚀 [VM] registerUser() called")
        print(String(repeating: "=", count: 50))
        
        // Force log the validation state
        print("📊 [VM] Validation State:")
        print("   - Can Submit: \(canSubmit)")
        print("   - All Fields Filled: \(allFieldsFilled)")
        print("   - Valid Email: \(isValidEmail)")
        
        guard canSubmit else {
            print("❌ [VM] Validation FAILED - Cannot submit")
            if !isValidEmail && !email.isEmpty {
                print("❌ [VM] Invalid email format")
                showErrorMessage("Please enter a valid email address")
            } else if !allFieldsFilled {
                print("❌ [VM] Missing required fields")
                showErrorMessage("Please fill in all fields")
            }
            return
        }
        
        print("✅ [VM] Validation PASSED - Proceeding with registration")
        
        isLoading = true
        errorMessage = nil
        
        print("🚀 [VM] Starting registration flow...")
        print("📝 [VM] User Details:")
        print("   - First Name: \(firstName)")
        print("   - Last Name: \(lastName)")
        print("   - Email: \(email)")
        print("   - Phone: \(phoneNumber)")
        print("   - Device ID: \(deviceId)")
        print("   - Device Name: \(deviceName)")
        
        print("📞 [VM] Calling repository.registerUser()...")
        
        repository.registerUser(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: phoneNumber,
            deviceId: deviceId,
            deviceName: deviceName
        ) { [weak self] result in
            print("📥 [VM] Repository returned with result")
            
            DispatchQueue.main.async {
                guard let self = self else {
                    print("⚠️ [VM] Self is nil in completion handler")
                    return
                }
                
                print("🔄 [VM] On main thread, handling result...")
                self.isLoading = false
                self.handleRegistrationResult(result)
            }
        }
        
        print("⏳ [VM] Waiting for repository response...")
    }
    
    // MARK: - Private Methods
    private func handleRegistrationResult(_ result: Result<APIResponse<LoginData>, APIError>) {
        print("\n" + String(repeating: "=", count: 50))
        print("📥 [VM] handleRegistrationResult() called")
        print(String(repeating: "=", count: 50))
        
        switch result {
        case .success(let response):
            print("✅ [VM] Registration API call succeeded")
            print("📦 [VM] Response message: \(response.message)")
            print("📦 [VM] Success status: \(response.success ?? false)")
            
            // Validate we have the required data
            guard let userData = response.data?.user else {
                print("⚠️ [VM] Warning: No user data in response")
                print("❌ [VM] Response data is nil: \(response.data == nil)")
                showErrorMessage("Registration succeeded but user data is missing")
                return
            }
            
            print("👤 [VM] User data received:")
            print("   - Name: \(userData.firstName) \(userData.lastName)")
            print("   - Email: \(userData.email)")
            print("   - Email Verified: \(userData.emailVerified)")
            print("   - Phone: \(userData.phoneNumber)")
            
            if let deviceData = response.data?.device {
                // Convert to User model
                let user = User(
                    firstName: userData.firstName,
                    lastName: userData.lastName,
                    email: userData.email,
                    phoneNumber: userData.phoneNumber,
                    deviceKey: deviceData.deviceKey,
                    deviceName: deviceData.deviceName,
                    userId: deviceData.user,
                    userDeviceId: deviceData.id
                )
                print("✅ Saved user with userId : \(deviceData.user)")
                
                // Save to session
                UserSession.shared.saveUser(user)
                UserSession.shared.setEmailVerified(userData.emailVerified)
                UserSession.shared.setProfilePicture(userData.profilePic)
                UserSession.shared.setCurrentDeviceID(deviceData.id)
                UserSession.shared.setThisDevicePrimary(deviceData.isPrimary)
                UserSession.shared.setUserWallet(userData.wallet)
                
                print("📱 [VM] Device data received:")
                print("   - Device Name: \(deviceData.deviceName)")
                print("   - Is Primary: \(deviceData.isPrimary)")
                print("   - Has Token: \(deviceData.token)")
                print("   - Device ID: \(deviceData.id)")
                
            } else {
                print("⚠️ [VM] Warning: No device data in response")
            }
                    
            // Use a small delay to ensure UI is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                print("🔄 [VM] Actually setting navigateToMainTab now")
                self?.navigateToMainTab = true
            }
            
        case .failure(let error):
            print("❌ [VM] Registration FAILED")
            // Handle specific error types
            switch error {
            case .unauthorized:
                print("🔐 [VM] Error type: Unauthorized")
                showErrorMessage("Authentication failed. Please try again.")
                
            case .serverError:
                print("🔥 [VM] Error type: Server Error")
                showErrorMessage("Server error. Please try again later.")
                
            case .networkError:
                print("📡 [VM] Error type: Network Error")
                showErrorMessage("Network error. Please check your connection.")
                
            case .decodingError(let message):
                print("🔍 [VM] Error type: Decoding Error")
                print("🔍 [VM] Decoding message: \(message)")
                showErrorMessage("Data error: \(message)")
                
            case .mismatchedHmac:
                print("🔒 [VM] Error type: HMAC Mismatch")
                showErrorMessage("Security validation failed. Please try again.")
                
            case .failedToGenerateHmac:
                print("🔑 [VM] Error type: Failed to Generate HMAC")
                showErrorMessage("Failed to generate security key.")
                
            default:
                print("❓ [VM] Error type: Unknown")
                print("❓ [VM] Full error: \(error)")
                showErrorMessage(error.localizedDescription)
            }
        }
        
        print(String(repeating: "=", count: 50) + "\n")
    }
    
    private func showErrorMessage(_ message: String) {
        print("⚠️ [VM] Showing error to user: \(message)")
        errorMessage = message
        showError = true
        print("⚠️ [VM] showError set to: \(showError)")
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
        print("🧹 [VM] Clearing form")
        firstName = ""
        lastName = ""
        email = ""
        phoneNumber = ""
        errorMessage = nil
        showError = false
        navigateToMainTab = false
    }
}

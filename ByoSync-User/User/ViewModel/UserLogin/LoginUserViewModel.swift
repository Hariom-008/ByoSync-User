import Foundation
import Combine

// MARK: - Updated User Login ViewModel

final class LoginViewModel: ObservableObject{
    
    @Published var name: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var showError: Bool = false
    @Published var loginSuccess: Bool = false
    @Published var role: String = ""
    @Published var wallet: Int?
    
    private let hardcodedDeviceId = "123456"

    func login() async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your name"
            showError = true
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = ""
            showError = false
        }
        
        LoginUserRepository.shared.loginUser(
            name: name,
            deviceId: hardcodedDeviceId
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    print("✅ Login successful: \(response.message)")
                    
                    // Check if this is actually a USER (not MERCHANT)
                    guard response.data?.user.role == "USER" else {
                        self.errorMessage = "This account is registered as a merchant. Please use merchant login."
                        self.showError = true
                        return
                    }
                    
                    self.updateUserSession(response: response)
                    self.role = response.data?.user.role ?? ""
                    self.loginSuccess = true
                    
                case .failure(let error):
                    print("❌ Login failed: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
    
    private func updateUserSession(response: APIResponse<LoginData>) {
        guard let userData = response.data?.user,
              let deviceData = response.data?.device else {
            print("⚠️ No data found in response")
            return
        }
        
        // Save token
        UserDefaults.standard.set(deviceData.token, forKey: "token")
        print("🔐 Saved auth token in UserDefaults: \(deviceData.token)")
        
        // Convert to User model
        let user = User(
            firstName: userData.firstName,
            lastName: userData.lastName,
            email: userData.email,
            phoneNumber: userData.phoneNumber,
            deviceId: deviceData.deviceId,
            deviceName: deviceData.deviceName
        )
        
        // Save to session
        UserSession.shared.saveUser(user)
        UserSession.shared.setEmailVerified(userData.emailVerified)
        UserSession.shared.setProfilePicture(userData.profilePic)
        UserSession.shared.setCurrentDeviceID(deviceData.id)
        UserSession.shared.setThisDevicePrimary(deviceData.isPrimary)
        UserSession.shared.setUserWallet(userData.wallet)
        // Save Account type
        UserDefaults.standard.set("user", forKey: "accountType")
        
        print("""
              ✅ User Login Complete:
              Name: \(userData.firstName) \(userData.lastName)
              Email: \(userData.email)
              Role: \(userData.role)
              Device: \(deviceData.deviceName)
              Primary: \(deviceData.isPrimary)
              """)
    }
}

import Foundation
import SwiftUI
import Combine

// MARK: - Updated User Login ViewModel

final class LoginViewModel: ObservableObject {
    
    let cryptoManager = CryptoManager()
    
    @Published var name: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var showError: Bool = false
    @Published var loginSuccess: Bool = false
    @Published var role: String = ""
    @Published var wallet: Int?
    @Published var fcmToken:String = ""
    
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
            deviceKey: hardcodedDeviceId,
            fcmToken: fcmToken
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    print("✅ Login successful: \(response.message)")
                    
                    self.updateUserSession(response: response)
                    self.loginSuccess = true
                    SocketIOManager.shared.connect()
                    print("✅ Socket is Connected")
                    UserDefaults.standard.set(response.data?.device.token ?? "", forKey: "token")
                    print("✅ Token Saved in UserDefaults")
                    
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
        
        // Convert to User model
        let user = User(
            firstName: cryptoManager.decrypt(encryptedData:userData.firstName) ?? "nil" ,
            lastName: cryptoManager.decrypt(encryptedData:userData.lastName) ?? "nil",
            email: cryptoManager.decrypt(encryptedData:userData.email) ?? "nil",
            phoneNumber: cryptoManager.decrypt(encryptedData:userData.phoneNumber) ?? "nil",
            deviceKey: deviceData.deviceKey,
            deviceName: deviceData.deviceName,
            userId: userData.id ,
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
        
        // Save Account type
        UserDefaults.standard.set("user", forKey: "accountType")
        
        #if DEBUG
        print("""
              ✅ User Login Complete:
              Name: \(userData.firstName) \(userData.lastName)
              Email: \(userData.email)
              Device: \(deviceData.deviceName)
              Primary: \(deviceData.isPrimary)
              """)
        #endif
    }
}

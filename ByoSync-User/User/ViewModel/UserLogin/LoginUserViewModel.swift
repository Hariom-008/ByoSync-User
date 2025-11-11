import Foundation
import SwiftUI
import Combine

final class LoginViewModel: ObservableObject {
    
    // ✅ Inject crypto service instead of creating instance
    private let cryptoService: any CryptoService
    private let repository: LoginUserRepository
    
    @Published var name: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var showError: Bool = false
    @Published var loginSuccess: Bool = false
    @Published var role: String = ""
    @Published var wallet: Int?
    @Published var fcmToken: String = ""
    
    private let hardcodedDeviceId = "123456"
    
    // ✅ Dependency injection via initializer
    init(cryptoService: any CryptoService) {
        self.cryptoService = cryptoService
        self.repository = LoginUserRepository(cryptoService: cryptoService)
        print("🎯 [VM] LoginViewModel initialized with crypto service")
    }

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
        
        print("🚀 [VM] Starting login for: \(name)")
        
        repository.loginUser(
            name: name,
            deviceKey: hardcodedDeviceId,
            fcmToken: fcmToken
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    print("✅ [VM] Login successful: \(response.message)")
                    
                    self.updateUserSession(response: response)
                    self.loginSuccess = true
                    SocketIOManager.shared.connect()
                    print("✅ [VM] Socket is Connected")
                    UserDefaults.standard.set(response.data?.device.token ?? "", forKey: "token")
                    print("✅ [VM] Token Saved in UserDefaults")
                    
                case .failure(let error):
                    print("❌ [VM] Login failed: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
    
    private func updateUserSession(response: APIResponse<LoginData>) {
        guard let userData = response.data?.user,
              let deviceData = response.data?.device else {
            print("⚠️ [VM] No data found in response")
            return
        }
        
        print("🔓 [VM] Decrypting user data...")
        
        // ✅ Use injected crypto service for decryption
        let user = User(
            firstName: cryptoService.decrypt(encryptedData: userData.firstName) ?? "nil",
            lastName: cryptoService.decrypt(encryptedData: userData.lastName) ?? "nil",
            email: cryptoService.decrypt(encryptedData: userData.email) ?? "nil",
            phoneNumber: cryptoService.decrypt(encryptedData: userData.phoneNumber) ?? "nil",
            deviceKey: deviceData.deviceKey,
            deviceName: deviceData.deviceName,
            userId: userData.id,
            userDeviceId: deviceData.id
        )
        
        print("✅ [VM] User data decrypted successfully")
        print("✅ [VM] Saved user with userId: \(deviceData.user)")
        
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
              ✅ [VM] User Login Complete:
              Name: \(user.firstName) \(user.lastName)
              Email: \(user.email)
              Device: \(deviceData.deviceName)
              Primary: \(deviceData.isPrimary)
              """)
        #endif
    }
}

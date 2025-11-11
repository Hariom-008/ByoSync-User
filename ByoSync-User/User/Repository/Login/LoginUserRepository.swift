import Foundation
import Alamofire
import SwiftUI

final class LoginUserRepository {
    
    // ✅ Remove singleton, use dependency injection
    private let cryptoService: any CryptoService
    private let hmacGenerator = HMACGenerator.self
    
    // ✅ Inject crypto service via initializer
    init(cryptoService: any CryptoService) {
        self.cryptoService = cryptoService
        print("🔐 [REPO] LoginUserRepository initialized with crypto service")
    }

    func login<T: Codable>(
        name: String,
        deviceKey: String,
        fcmToken: String,
        completion: @escaping (Result<APIResponse<T>, APIError>) -> Void
    ) {
        let loginData = LoginRequest(
            name: name,
            deviceKeyHash: hmacGenerator.generateHMAC(jsonString: deviceKey),
            fcmToken: fcmToken
        )
        
        print("📤 [REPO] Logging In:")
        print("   URL: \(UserAPIEndpoint.Auth.logIn)")
        print("   name: \(name)")
        print("   deviceId: \(deviceKey)")
        
        APIClient.shared.request(
            UserAPIEndpoint.Auth.logIn,
            method: .post,
            parameters: loginData.asDictionary(),
            headers: ["Content-Type": "application/json"]
        ) { (result: Result<APIResponse<T>, APIError>) in
            switch result {
            case .success(let response):
                print("✅ [REPO] Login successful")
                print("✅ [REPO] Response: \(response.message)")
                completion(.success(response))
            
            case .failure(let error):
                print("❌ [REPO] Login failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // Convenience method for User Login
    func loginUser(
        name: String,
        deviceKey: String,
        fcmToken: String,
        completion: @escaping (Result<APIResponse<LoginData>, APIError>) -> Void
    ) {
        login(name: name, deviceKey: deviceKey, fcmToken: fcmToken, completion: completion)
    }
}

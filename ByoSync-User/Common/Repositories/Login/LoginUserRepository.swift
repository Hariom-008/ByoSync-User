import Foundation
import Alamofire

final class LoginUserRepository {
    
    static let shared = LoginUserRepository()
    
    private init() {}

    func login<T: Codable>(
        name: String,
        deviceId: String,
        completion: @escaping (Result<APIResponse<T>, APIError>) -> Void
    ) {
        let loginData = LoginRequest(
            name: name,
            deviceId: deviceId
        )
        
        print("📤 Logging In:")
        print("URL: \(UserAPIEndpoint.Auth.logIn)")
        print("name: \(name)")
        print("deviceId: \(deviceId)")
        
        APIClient.shared.request(
            UserAPIEndpoint.Auth.logIn,
            method: .post,
            parameters: loginData.asDictionary(),
            headers: ["Content-Type": "application/json"]
        ) { (result: Result<APIResponse<T>, APIError>) in
            switch result {
            case .success(let response):
                print("✅ Login successful")
                print("✅ Response: \(response.message)")
                completion(.success(response))
                
            case .failure(let error):
                print("❌ Login failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // Convenience method for User Login
    func loginUser(
        name: String,
        deviceId: String,
        completion: @escaping (Result<APIResponse<LoginData>, APIError>) -> Void
    ) {
        login(name: name, deviceId: deviceId, completion: completion)
    }
    
    // Convenience method for Merchant Login
//    func loginMerchant(
//        name: String,
//        deviceId: String,
//        completion: @escaping (Result<APIResponse<MerchantDataWrapper>, APIError>) -> Void
//    ) {
//        login(name: name, deviceId: deviceId, completion: completion)
//    }
}

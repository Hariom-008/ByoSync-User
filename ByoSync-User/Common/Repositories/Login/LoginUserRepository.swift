import Foundation
import Alamofire
import SwiftUI

// MARK: - Root Response
//struct LoginResponse: Codable {
//    let statusCode: Int
//    let data: LoginData
//    let message: String
//    let success: Bool
//}

final class LoginUserRepository {
    
    static let shared = LoginUserRepository()
    
    private init() {}

    func login<T: Codable>(
        name: String,
        deviceKey: String,
        fcmToken: String,
        completion: @escaping (Result<APIResponse<T>, APIError>) -> Void
    ) {
        let loginData = LoginRequest(
            name: name,
            deviceKey: deviceKey,
            fcmToken: fcmToken
        )
        
        print("📤 Logging In:")
        print("URL: \(UserAPIEndpoint.Auth.logIn)")
        print("name: \(name)")
        print("deviceId: \(deviceKey)")
        
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
        deviceKey: String,
        fcmToken : String,
        completion: @escaping (Result<APIResponse<LoginData>, APIError>) -> Void
    ) {
    
        login(name: name, deviceKey: deviceKey,fcmToken: fcmToken ,completion: completion)
    }
}

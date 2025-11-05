import Foundation
import Alamofire

final class LogOutRepository {
    static let shared = LogOutRepository()
    
    func logOut(
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        print("📤 Logging Out User...")
        print("🔗 URL: \(UserAPIEndpoint.Auth.logOut)")
        
        let headers = getHeader.shared.getAuthHeaders() // ✅ include token here
        
        APIClient.shared.requestWithoutResponse(
            UserAPIEndpoint.Auth.logOut,
            method: .post,
            headers: headers
        ) { (result: Result<Void, APIError>) in
            
            switch result {
            case .success(let response):
                print("✅ User logged out successfully")
                // Clear local session
                UserSession.shared.clearUser()
                UserDefaults.standard.removeObject(forKey: "token") // ✅ clear token too
                
                completion(.success(response))
                
            case .failure(let error):
                print("❌ Logout failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}

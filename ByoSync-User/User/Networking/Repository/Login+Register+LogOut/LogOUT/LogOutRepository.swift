import Foundation
import Alamofire

protocol LogOutRepositoryProtocol {
    func logOut(completion: @escaping (Result<Void, APIError>) -> Void)
}

final class LogOutRepository: LogOutRepositoryProtocol {
    
    init() {
        print("🏗️ [REPO] LogOutRepository initialized")
    }
    
    private func getAuthHeaders() -> HTTPHeaders {
        return getHeader.shared.getAuthHeaders()
    }
    
    func logOut(
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        print("📤 [REPO] Logging Out User...")
        print("📍 [REPO] URL: \(UserAPIEndpoint.Auth.logOut)")
        
        let headers = getAuthHeaders()
        
//        if let authHeader = headers.dictionary["Authorization"] {
//            let tokenPreview = String(authHeader.prefix(30))
//            print("🔑 [REPO] Token present: \(tokenPreview)...")
//        } else {
//            print("⚠️ [REPO] No auth token found in headers")
//        }
        
        APIClient.shared.requestWithoutResponse(
            UserAPIEndpoint.Auth.logOut,
            method: .post
           // headers: headers
        ) { (result: Result<Void, APIError>) in
            
            switch result {
            case .success:
                print("✅ [REPO] User logged out successfully on backend")
                
                UserSession.shared.clearUser()
                print("✅ [REPO] UserSession cleared")
                
                UserDefaults.standard.removeObject(forKey: "token")
                UserDefaults.standard.removeObject(forKey: "deviceToken")
                print("✅ [REPO] Tokens removed from UserDefaults")
                
                completion(.success(()))
                
            case .failure(let error):
                print("❌ [REPO] Logout failed: \(error.localizedDescription)")
                
                switch error {
                case .unauthorized:
                    print("⚠️ [REPO] Unauthorized error - clearing local session anyway")
                    UserSession.shared.clearUser()
                    UserDefaults.standard.removeObject(forKey: "token")
                    UserDefaults.standard.removeObject(forKey: "deviceToken")
                    completion(.success(()))
                default:
                    completion(.failure(error))
                }
            }
        }
    }
    
    deinit {
        print("♻️ [REPO] LogOutRepository deallocated")
    }
}

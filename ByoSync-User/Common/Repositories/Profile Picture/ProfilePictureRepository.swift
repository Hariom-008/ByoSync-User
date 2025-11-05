import Foundation
import Alamofire

struct ChangeProfilePicRequest: Codable {
    let profilePicUrl: String
}

struct ChangeProfilePicResponse: Codable {
    let message: String?
}

//struct ProfilePicResponse: Codable {
//    let statusCode: Int
//    let message: String
//    let data: ProfilePicData?
//    
//    struct ProfilePicData: Codable {
//        let profilePic: String
//    }
//}

protocol ProfilePictureRepositoryProtocol {
    func changeProfilePicture(imageUrl: String) async throws -> String
}


final class ProfilePictureRepository: ProfilePictureRepositoryProtocol {
    private let apiClient = APIClient.shared

    func changeProfilePicture(imageUrl: String) async throws -> String {
        let endpoint = UserAPIEndpoint.EditProfile.changeProfilePic
        let request = ChangeProfilePicRequest(profilePicUrl: imageUrl)
        let headers: HTTPHeaders = getHeader.shared.getAuthHeaders()
        
        print("📤 PATCH request to: \(endpoint)")
        print("📦 Body: \(request.profilePicUrl)")
        
        return try await withCheckedThrowingContinuation { continuation in
            apiClient.request(
                endpoint,
                method: .patch,
                parameters: try? request.asDictionary(),
                headers: headers
            ) { (result: Result<ChangeProfilePicResponse, APIError>) in
                switch result {
                case .success(let response):
                    let message = response.message ?? "Profile picture updated successfully!"
                    print("✅ Backend response: \(message)")
                    continuation.resume(returning: message)
                case .failure(let error):
                    print("❌ API Error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

extension Encodable {
    func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        return json as? [String: Any] ?? [:]
    }
}

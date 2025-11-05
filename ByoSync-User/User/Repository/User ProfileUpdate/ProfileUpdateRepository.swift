//
//  ProfileUpdateRepository.swift
//  ByoSync
//
//  Created by Hari's Mac on 22.10.2025.
//

import Foundation
import Alamofire

// For PATCH /change-details (returns user directly in data)
struct MerchantProfileResponse: Codable {
    let statusCode: Int
    let data: MerchantData  // ✅ Direct UserData, not nested
    let message: String
}
 //For GET /get-user-data and POST /login (returns user and device nested)
struct ProfileUpdateResponse: Codable {
    let statusCode: Int
    let data: ProfileUpdateData
    let message: String
}

struct MerchantData: Codable {
    let email: String
    let firstName: String
    let lastName: String
    let phoneNumber: String
    let pattern: [String]
    let salt: String
    let faceToken: String
    let role: String
    let merchantName: String
    let gstNumber: String
    let address: Address
    let profilePic: String
    let devices: [String]
    let emailVerified: Bool
    let id: String
    let faceId: [String]
    let createdAt: String
    let updatedAt: String
    let v: Int
    
    enum CodingKeys: String, CodingKey {
        case email
        case firstName
        case lastName
        case phoneNumber
        case pattern
        case salt
        case faceToken
        case role
        case merchantName
        case gstNumber
        case address
        case profilePic
        case devices
        case emailVerified
        case id = "_id"
        case faceId
        case createdAt
        case updatedAt
        case v = "__v"
    }
}


final class ProfileUpdateRepository {
    static let shared = ProfileUpdateRepository()
    
    private init() {}
    
    // MARK: - Private Helper: Get Auth Headers
    private func getAuthHeaders() -> HTTPHeaders {
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "application/json")
        
        // Retrieve token from UserDefaults
        if let token = UserDefaults.standard.string(forKey: "token"), !token.isEmpty {
            headers.add(name: "Authorization", value: "Bearer \(token)")
            print("🔒 Retrieved auth token from UserDefaults")
            print("🔑 Token: \(token.prefix(30))...")
        } else {
            print("⚠️ No auth token found in UserDefaults")
        }
        return headers
    }
    
    // MARK: - Profile Update (PATCH) - Returns user directly
    func updateProfile(
        firstName: String,
        lastName: String,
        email: String,
        completion: @escaping (Result<MerchantProfileResponse, APIError>) -> Void
    ) {
        let parameters: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName,
            "email": email
        ]
        
        let headers = getAuthHeaders()
        
        print("\n📤 UPDATE PROFILE REQUEST:")
        print("URL: \(UserAPIEndpoint.EditProfile.changeDetails)")
        print("Method: PATCH")
        print("Headers: \(headers)")
        print("Parameters: \(parameters)")
        
        APIClient.shared.request(
            UserAPIEndpoint.EditProfile.changeDetails,
            method: .patch,
            parameters: parameters,
            headers: headers,
            completion: completion
        )
    }
    
    // MARK: - Get Profile (GET) - Returns user and device
    func getProfile(completion: @escaping (Result<ProfileUpdateResponse, APIError>) -> Void) {
        let headers = getAuthHeaders()
        
        print("\n📥 GET PROFILE REQUEST:")
        print("URL: \(UserAPIEndpoint.EditProfile.changeDetails)")
        print("Method: GET")
        print("Headers: \(headers)")
        
        APIClient.shared.request(
            UserAPIEndpoint.EditProfile.changeDetails,
            method: .get,
            headers: headers,
            completion: completion
        )
    }
}

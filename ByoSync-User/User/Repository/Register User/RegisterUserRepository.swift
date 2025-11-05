import Foundation
import Alamofire
import CryptoKit

// MARK: - Response Models
struct RegisterUserResponse: Codable {
    let success: Bool
    let message: String
    let data: User?
}

final class RegisterUserRepository {
    
    static let shared = RegisterUserRepository()
    
    private init() {}
    
    func registerUser(
        firstName: String,
        lastName: String,
        email: String,
        phoneNumber: String,
        deviceId: String,
        deviceName: String,
        completion: @escaping (Result<APIResponse<LoginData>, APIError>) -> Void
    ) {
        // Create User object
        let user = User(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: phoneNumber,
            deviceId: deviceId,
            deviceName: deviceName
        )
        
        // Encode User to JSON string with consistent formatting
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        
        guard let jsonData = try? encoder.encode(user),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            completion(.failure(.failedToGenerateHmac))
            return
        }
        
        print("📤 Registering User:")
        print("URL: \(UserAPIEndpoint.Auth.userRegister)")
        print("JSON Body: \(jsonString)")
        
        // Use the SAME jsonString for both HMAC and request body
        requestWithJSONString(
            url: UserAPIEndpoint.Auth.userRegister,
            method: .post,
            jsonString: jsonString,
            userData: user
        ) { result in
            switch result {
            case .success(let response):
                print("✅ User registered successfully")
                print("✅ Response: \(response.message)")
                
                // Extract user and device data from response
                let userData = response.data?.user
                let deviceData = response.data?.device
                
                // Save token to UserDefaults
                if let token = deviceData?.token, !token.isEmpty {
                    UserDefaults.standard.set(token, forKey: "token")
                    print("🔒 Saved auth token to UserDefaults: \(token)")
                } else {
                    print("⚠️ No token found in response")
                }
                
                // Convert to User model
                let registeredUser = User(
                    firstName: userData?.firstName ?? firstName,
                    lastName: userData?.lastName ?? lastName,
                    email: userData?.email ?? email,
                    phoneNumber: userData?.phoneNumber ?? phoneNumber,
                    deviceId: deviceData?.deviceId ?? deviceId,
                    deviceName: deviceData?.deviceName ?? deviceName
                )
                
                // Save to UserSession
                UserSession.shared.saveUser(registeredUser)
                UserSession.shared.setEmailVerified(userData?.emailVerified ?? false)
                UserSession.shared.setProfilePicture(userData?.profilePic ?? "")
                UserSession.shared.setCurrentDeviceID(deviceData?.id ?? "")
                UserSession.shared.setThisDevicePrimary(deviceData?.isPrimary ?? false)
                
                print("🔑 Registered Device Primary Status: \(deviceData?.isPrimary ?? false)")
                print("👤 User Profile Pic: \(userData?.profilePic ?? "❌ nil ProfilePhoto")")
                
                print("""
                      ✅ Registration Complete:
                      firstName: \(registeredUser.firstName)
                      lastName: \(registeredUser.lastName)
                      email: \(registeredUser.email)
                      phoneNumber: \(registeredUser.phoneNumber ?? "N/A")
                      deviceId: \(registeredUser.deviceId ?? "N/A")
                      deviceName: \(registeredUser.deviceName ?? "N/A")
                      emailVerified: \(userData?.emailVerified ?? false)
                      isPrimary: \(deviceData?.isPrimary ?? false)
                      token saved: \(deviceData?.token != nil)
                      """)
                
                completion(.success(response))
                
            case .failure(let error):
                print("❌ Registration failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    private func requestWithJSONString(
        url: String,
        method: HTTPMethod,
        jsonString: String,
        userData: User,
        completion: @escaping (Result<APIResponse<LoginData>, APIError>) -> Void
    ) {
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        let signature = HMACGenerator.generateHMAC(jsonString: jsonString)
        
        // Create headers
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "x-signature": signature,
            "x-timestamp": timestamp,
            "x-nonce": timestamp,
            "x-idempotency-key": timestamp
        ]
        
        print("📋 Request Headers:")
        print("HMAC Key Generated or x-signature: \(signature)")
        print("x-timestamp: \(timestamp)")
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            completion(.failure(.mismatchedHmac))
            return
        }
        
        guard let requestUrl = URL(string: url) else {
            completion(.failure(.unknown))
            return
        }
        
        var request = URLRequest(url: requestUrl)
        request.httpMethod = method.rawValue
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add all headers to the request
        headers.dictionary.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
            print("\(key): \(value)")
        }
        
        print("📨 Final Request Body: \(jsonString)")
        
        // Use the updated APIClient method that returns LoginData
        APIClient.shared.requestWithCustomBodyAndResponse(request, completion: completion)
    }
}

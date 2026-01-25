//
//  iSDeviceRegisteredRepository.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 10.12.2025.
//

import SwiftUI
import Foundation
import Alamofire

final class DeviceRegistrationRepository {
    
    static let shared = DeviceRegistrationRepository()
    
    private let hmacGenerator = HMACGenerator.self
    
    func isDeviceRegistered(
        deviceKey: String,
        completion: @escaping (Result<DeviceRegistrationResponse, APIError>) -> Void
    ) {
        let deviceKeyHash = hmacGenerator.generateHMAC(jsonString: deviceKey)

        let headers: HTTPHeaders = getHeader.shared.getAuthHeaders()
        var fcmToken = ""
        FCMTokenManager.shared.getFCMToken { token in fcmToken = token ?? "" }
        
        let body: [String: Any] = [
            "deviceKeyHash": deviceKeyHash,
            "fcmToken": fcmToken
        ]
        #if DEBUG
        print("📤 [DeviceRegistrationRepository] isDeviceRegistered -> URL: \(UserAPIEndpoint.UserDeviceManagement.isDeviceRegistered)")
        print("📤 [DeviceRegistrationRepository] Headers: \(headers)")
        print("📤 [DeviceRegistrationRepository] Body: \(body)")
        #endif

        APIClient.shared.request(
            UserAPIEndpoint.UserDeviceManagement.isDeviceRegistered,
            method: .post,
            parameters: body,
            headers: headers
        ) { (result: Result<DeviceRegistrationResponse, APIError>) in
            switch result {
            case .success(let response):
                print("✅ [DeviceRegistrationRepository] statusCode=\(response.statusCode), " +
                      "success=\(response.success), message='\(response.message)'")
                print("✅ [DeviceRegistrationRepository] userId=\(response.data.userId), " +
                      "hasFaceData=\(response.data.hasFaceData)")
                
                UserSession.shared.setCurrentUserId(response.data.userId)
                UserSession.shared.setHasFaceData(response.data.hasFaceData)
                print("UserID :\(response.data.userId)")
                print("[DeviceRegistrationRepository] HasFaceData:\(UserSession.shared.hasFaceData)")
                
                completion(.success(response))
                
            case .failure(let error):
                print("❌ [DeviceRegistrationRepository] Failed to check device registration: \(error)")
                completion(.failure(error))
            }
        }
    }
}

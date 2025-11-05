//
//  GetUserDataRepository.swift
//  ByoSync
//
//  Created by Hari's Mac on 18.10.2025.
//

import Foundation
import Alamofire
import SwiftUI

final class GetUserDataRepository{
    
    static let shared = GetUserDataRepository()
    
    private init() {}
    
    func getUserData(
        completion: @escaping (Result<APIResponse<LoginData>, APIError>) -> Void
    ) {
        
        print("📤 Fetching User Data:")
        APIClient.shared.request(
            UserAPIEndpoint.UserData.getUserData,
            method: .post
        ) { (result: Result<APIResponse<LoginData>, APIError>) in
            switch result {
            case .success(let response):
                print("✅ User fetched successfully")
                print("✅ Response: \(response.message)")
                
                // Extract user and device data from response
                let userData = response.data?.user
                let deviceData = response.data?.device
                
                // Convert to your User model
                let user = User(
                    firstName: userData?.firstName ?? "nil",
                    lastName: userData?.lastName ?? "nil",
                    email: userData?.email ?? "nil email",
                    phoneNumber: userData?.phoneNumber,
                    deviceId: deviceData?.deviceId,
                    deviceName: deviceData?.deviceName
                )
                
                // Save to session
                UserSession.shared.saveUser(user)
                
                // Save device token if needed
                if let token = deviceData?.token {
                    // Save token to UserDefaults or Keychain
                    UserDefaults.standard.set(token, forKey: "deviceToken")
                    print("✅ Device Token saved: \(token)")
                }
                
                print("""
                      ✅ Login Details:
                      firstName: \(user.firstName)
                      lastName: \(user.lastName)
                      email: \(user.email)
                      phoneNumber: \(user.phoneNumber ?? "nil phone")
                      deviceId: \(user.deviceId ?? "nil deviceID")
                      deviceName: \(user.deviceName ?? "nil deviceName")
                      """)
                
                completion(.success(response))
                
            case .failure(let error):
                print("❌ User Fetch failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}

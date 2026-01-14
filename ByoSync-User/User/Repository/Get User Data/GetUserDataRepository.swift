//
//  GetUserDataRepository.swift
//  ByoSync
//
//  Created by Hari's Mac on 18.10.2025.
//

import Foundation
import Alamofire
import SwiftUI

// MARK: - Protocol for Testability
protocol GetUserDataRepositoryProtocol {
    func getUserData(
        completion: @escaping (Result<APIResponse<LoginData>, APIError>) -> Void
    )
}

final class GetUserDataRepository: GetUserDataRepositoryProtocol {
    
    // MARK: - Initialization (No Singleton)
    init() {
        print("🏗️ [REPO] GetUserDataRepository initialized")
    }
    
    func getUserData(
        completion: @escaping (Result<APIResponse<LoginData>, APIError>) -> Void
    ) {
        print("📤 [REPO] Fetching User Data")
        print("📍 [REPO] URL: \(UserAPIEndpoint.UserData.getUserData)")
        
        APIClient.shared.request(
            UserAPIEndpoint.UserData.getUserData,
            method: .post
        ) { (result: Result<APIResponse<LoginData>, APIError>) in
            switch result {
            case .success(let response):
                print("✅ [REPO] User fetched successfully")
                print("💬 [REPO] Response: \(response.message)")
                
                // Extract user and device data from response
                guard let userData = response.data?.user,
                      let deviceData = response.data?.device else {
                    print("❌ [REPO] Invalid response data structure")
                    completion(.failure(.custom("Invalid response data")))
                    return
                }
                
                // Convert to User model
                let user = User(
                    firstName: userData.firstName,
                    lastName: userData.lastName,
                    email: userData.email,
                    phoneNumber: userData.phoneNumber,
                    deviceKey: deviceData.deviceKey,
                    deviceName: deviceData.deviceName,
                    token: userData.token
                )
                
                // Save to session
                UserSession.shared.saveUser(user)
                print("✅ [REPO] User saved to session")
                
                  // Save device information
                 let deviceId = deviceData.deviceKey
                    UserSession.shared.setCurrentDeviceID(deviceId)
                    print("✅ [REPO] Device ID saved: \(deviceId)")
                
                // Update email verification status
                UserSession.shared.setEmailVerified(userData.emailVerified)
                print("✅ [REPO] Email verified status: \(userData.emailVerified)")
                
                // Update profile picture
                if ((userData.profilePic?.isEmpty) == nil) {
                    UserSession.shared.setProfilePicture(userData.profilePic ?? "")
                    print("✅ [REPO] Profile picture URL saved")
                }
                
                // Update device primary status
                UserSession.shared.setThisDevicePrimary(deviceData.isPrimary)
                print("✅ [REPO] Device primary status: \(deviceData.isPrimary)")
                
                // Save device token if available
                let token = deviceData.token
                UserDefaults.standard.set(token, forKey: "deviceToken")
                print("✅ [REPO] Device Token saved")

                print("""
                      ✅ [REPO] User Details Updated:
                      Name: \(user.firstName) \(user.lastName)
                      Email: \(user.email)
                      Phone: \(user.phoneNumber ?? "N/A")
                      Device ID: \(deviceData.deviceKey)
                      Device Name: \(user.deviceName ?? "N/A")
                      Email Verified: \(userData.emailVerified)
                      Is Primary: \(deviceData.isPrimary)
                      """)
                
                completion(.success(response))
                
            case .failure(let error):
                print("❌ [REPO] User Fetch failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    deinit {
        print("♻️ [REPO] GetUserDataRepository deallocated")
    }
}

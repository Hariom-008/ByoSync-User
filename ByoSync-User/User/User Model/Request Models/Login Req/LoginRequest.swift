//
//  LoginRequest.swift
//  ByoSync
//
//  Created by Hari's Mac on 22.10.2025.
//

import Foundation
// MARK: - Login Request Model
struct LoginRequest: Codable {
    let name: String
    let deviceKey: String
    let fcmToken: String
    
    func asDictionary() -> [String: Any] {
        return [
            "name": name,
            "deviceKey" : deviceKey,
            "fcmToken" : fcmToken
        ]
    }
}

//
//  UserData.swift
//  ByoSync
//
//  Created by Hari's Mac on 22.10.2025.
//

import Foundation

// MARK: - User Model
struct User: Codable {
    let firstName: String
    let lastName: String
    let email: String
    let phoneNumber: String?
    let deviceId: String?
    let deviceName: String?
    
    // Convenience initializer
    init(firstName: String, lastName: String, email: String, phoneNumber: String? = nil, deviceId: String? = nil, deviceName: String? = nil) {
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phoneNumber = phoneNumber
        self.deviceId = deviceId
        self.deviceName = deviceName
    }
}
struct Address: Codable {
    var address1: String
    var address2: String
    var city: String
    var state: String
    var pincode: String
}


// UserData
struct UserData: Codable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let phoneNumber: String
    let pattern: [String]
    let salt: String
    let faceToken: String
    let role: String
    let profilePic: String
    let devices: [String]
    let emailVerified: Bool
    let faceId: [String]
    let createdAt: String
    let updatedAt: String
    let v: Int
    let wallet: Double
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case email
        case firstName
        case lastName
        case phoneNumber
        case pattern
        case salt
        case faceToken
        case role
        case profilePic
        case devices
        case emailVerified
        case faceId
        case createdAt
        case updatedAt
        case v = "__v"
        case wallet 
    }
}

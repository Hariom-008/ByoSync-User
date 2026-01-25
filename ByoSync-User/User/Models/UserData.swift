//
//  UserData.swift
//  ByoSync
//
//  Created by Hari's Mac on 22.10.2025.
//

import Foundation

// MARK: - User Model
struct User: Codable,Equatable{
    let firstName: String
    let lastName: String
    let email: String
    let phoneNumber: String?
    let deviceKey: String?
    let deviceName: String?
    let fcmToken: String?
    let refferalCode: String?
    let userId: String?
    let userDeviceId: String?
    let token:Int
    
    
    // Convenience initializer
    init(firstName: String, lastName: String, email: String, phoneNumber: String? = nil, deviceKey: String? = nil, deviceName: String? = nil,fcmToken:String? = nil, refferalCode: String? = nil, userId:String? = nil,userDeviceId:String? = nil,token:Int) {
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phoneNumber = phoneNumber
        self.deviceKey = deviceKey
        self.deviceName = deviceName
        self.fcmToken = fcmToken
        self.refferalCode = refferalCode
        self.userId = userId
        self.userDeviceId = userDeviceId
        self.token = token
    }
}
struct Address: Codable {
    var address1: String
    var address2: String
    var city: String
    var state: String
    var pincode: String
}


// MARK: - User Data
struct UserData: Codable, Identifiable {
    
    // Core User Info
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let phoneNumber: String
    
    let salt: String
    let faceToken: String
    
    // Financial & Activity Data
    let wallet: Double // Changed from Double as the response had '9169'
    
    let referralCode: String
    let transactionCoins: Int
    let noOfTransactions: Int
    let noOfTransactionsReceived: Int
    
    // Profile & Device Info
    let profilePic: String? // Changed to optional String as it might sometimes be null or missing
    let devices: [String]
    let emailVerified: Bool
    let faceId: [FaceIdItem]? // Updated to an array of complex FaceIdItem objects
    
    // Timestamps & Version
    let createdAt: String
    let updatedAt: String
    let v: Int
    
    let token: Int
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case email
        case firstName
        case lastName
        case phoneNumber
        // case pattern
        case salt
        case faceToken
        case wallet
        case referralCode
        case transactionCoins
        case noOfTransactions
        case noOfTransactionsReceived
        case profilePic
        case devices
        case emailVerified
        case faceId
        case createdAt
        case updatedAt
        case token
        case v = "__v"
    }
    
    // Your computed property for initials (remains unchanged)
    var initials: String {
        let firstInitial = firstName.first?.uppercased() ?? ""
        let lastInitial = lastName.first?.uppercased() ?? ""
        return "\(firstInitial)\(lastInitial)"
    }
}

// MARK: - Nested Face ID Item Structure
struct FaceIdItem: Codable,Equatable {
    let ecc: String?
    let helper: String?
    let hashHex: String?
    let r: String?
    let hashBits: String?
    let _id: String?
}

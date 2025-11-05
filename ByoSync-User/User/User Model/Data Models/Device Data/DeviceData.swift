//
//  DeviceData.swift
//  ByoSync
//
//  Created by Hari's Mac on 22.10.2025.
//

import Foundation

struct DeviceData: Codable, Identifiable {
    let id: String
    let deviceId: String
    let deviceName: String
    let user: String?  // Optional because merchant response might not have this
    let merchant: String?
    let isPrimary: Bool
    let createdAt: String
    let updatedAt: String
    let v: Int?
    let token: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case deviceId
        case deviceName
        case isPrimary
        case createdAt
        case token
       
        case user
        case merchant
        
        case updatedAt
        case v = "__v"
    }
}

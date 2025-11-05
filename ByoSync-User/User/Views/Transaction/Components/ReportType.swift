//
//  ReportType.swift
//  ByoSync
//
//  Created by Hari's Mac on 01.11.2025.
//

import Foundation
// MARK: - Enums

enum ReportType: String, CaseIterable {
    case view = "VIEW"
    case email = "EMAIL"
    case download = "DOWNLOAD"
    
    var displayName: String {
        switch self {
        case .view: return "View"
        case .email: return "Email"
        case .download: return "Download"
        }
    }
    
    var buttonText: String {
        switch self {
        case .view: return "Fetch"
        case .email: return "Email"
        case .download: return "Download"
        }
    }
    
    var iconName: String {
        switch self {
        case .view: return "arrow.clockwise"
        case .email: return "envelope"
        case .download: return "arrow.down.circle"
        }
    }
}

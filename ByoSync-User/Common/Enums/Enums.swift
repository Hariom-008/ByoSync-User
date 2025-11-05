//
//  Enums.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 05.11.2025.
//

import Foundation
import SwiftUI

enum PeriodType: String, CaseIterable {
    case daily = "DAILY"
    case monthly = "MONTHLY"
    case custom = "CUSTOM"
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .monthly: return "Monthly"
        case .custom: return "Custom"
        }
    }
    
    var iconName: String {
        switch self {
        case .daily: return "calendar"
        case .monthly: return "calendar.badge.clock"
        case .custom: return "calendar.badge.plus"
        }
    }
}

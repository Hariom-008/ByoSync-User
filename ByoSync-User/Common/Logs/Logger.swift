//
//  Logger.swift
//  ByoSync
//
//  Created by Hari's Mac on 16.10.2025.
//

import Foundation
import os.log

enum LogLevel: String {
    case verbose = "💬 VERBOSE"
    case debug = "🔍 DEBUG"
    case info = "ℹ️ INFO"
    case warning = "⚠️ WARNING"
    case error = "❌ ERROR"
    case critical = "🔥 CRITICAL"
    case success = "✅ SUCCESS"
    case network = "📡 NETWORK"
    case security = "🔐 SECURITY"
}


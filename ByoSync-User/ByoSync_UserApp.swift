//
//  ByoSync_UserApp.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 05.11.2025.
//

import SwiftUI

@main
struct ByoSync_UserApp: App {
    @StateObject private var languageManager = LanguageManager.shared
    
    @StateObject var userSession = UserSession.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(userSession)
                .id(languageManager.currentLanguageCode) // forces view reload when language changes
                .environmentObject(languageManager)
                .environment(\.locale, .init(identifier: languageManager.currentLanguageCode))
                .preferredColorScheme(.light)
            
        }
    }
}

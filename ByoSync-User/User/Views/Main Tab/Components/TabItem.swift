//
//  TabItem.swift
//  ByoSync
//
//  Created by Hari's Mac on 17.10.2025.
//

import Foundation
import SwiftUI
// MARK: - Tab Item Component
struct TabItem: View {
    let systemName: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color(hex: "4B548D") : .gray)
                
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color(hex: "4B548D") : .gray)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(TabItemButtonStyle())
    }
}

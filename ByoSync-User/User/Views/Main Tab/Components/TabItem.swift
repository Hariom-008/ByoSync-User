//
//  TabItem.swift
//  ByoSync
//
//  Created by Hari's Mac on 17.10.2025.
//

import Foundation
import SwiftUI
struct TabItem: View {
    let systemName: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                    VStack(spacing: 4){
                        Image(systemName: systemName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(isSelected ? .black : .gray)
                        Text(title)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(isSelected ? .black : .black)
                    }
            }
            .frame(width: 80, height: 70)
        }
    }
}

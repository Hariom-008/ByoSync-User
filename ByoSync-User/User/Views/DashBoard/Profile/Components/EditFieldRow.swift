//
//  EditFieldRow.swift
//  ByoSync
//
//  Created by Hari's Mac on 22.10.2025.
//

import Foundation
import SwiftUI
// MARK: - Edit Field Row Component
struct EditFieldRow: View {
    let icon: String
    let label: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(Color(hex: "4B548D"))
                    .frame(width: 24)
                
                TextField("", text: $text)
                    .font(.subheadline)
                    .keyboardType(keyboardType)
                    .autocapitalization(keyboardType == .emailAddress ? .none : .words)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Color(hex: "F5F7FA"))
            .cornerRadius(12)
        }
    }
}

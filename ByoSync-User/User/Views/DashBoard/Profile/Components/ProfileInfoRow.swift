//
//  ProfileInfoRow.swift
//  ByoSync
//
//  Created by Hari's Mac on 23.10.2025.
//

import Foundation
import SwiftUI
// MARK: - Profile Info Row Component
struct ProfileInfoRow: View {
    let icon: String
    let label: String
    let value: String
    var iconColor: Color = Color(hex: "4B548D")
    @State private var openEmailOTPView: Bool = false
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(Color(hex: "4B548D"))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // ✅ Show verify button only if email is not verified and this is the email row
            if !UserSession.shared.isEmailVerified && label == "Email Address" {
                Button {
                    openEmailOTPView.toggle()
                } label: {
                    Text("Verify Email")
                        .foregroundStyle(.black)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.black, lineWidth: 1)
                        )
                }
            }
        }
        .sheet(isPresented: $openEmailOTPView) {
            EmailVerificationView()
        }
    }
}


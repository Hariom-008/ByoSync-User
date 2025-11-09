//
//  RewardsView.swift
//  ByoSync
//
//  Created by Hari's Mac on 17.10.2025.
//

import Foundation
import SwiftUI

// MARK: - Rewards + Invite row
 struct RewardsInviteRow: View {
    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 12){
                Image("celebrationPeople")
                    .resizable()
                    .frame(width: 120, height: 120)
                VStack{
                    Text("₹1066")
                        .font(.headline).bold()
                        .foregroundColor(.black)
                    Text("Rewards Earned!")
                        .font(.caption)
                        .foregroundColor(.black.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.05))
            )
            .frame(height: 120)
            
            // Invite friends
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "4B548D"))
                Text("Invite\nfriends")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
            }
            .frame(width: 110, height: 120)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.05))
            )
        }
    }
}

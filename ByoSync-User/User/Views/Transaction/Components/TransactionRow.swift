////
////  TransactionRow.swift
////  ByoSync
////
////  Created by Hari's Mac on 01.11.2025.
////
//
import Foundation
import SwiftUI


struct TransactionRow: View {
    let transaction: Transaction
    var currentUser:Bool {
        return UserSession.shared.currentUser?.userId == transaction.receiverId?.id
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Image
            AsyncImage(url: URL(string: transaction.receiverId?.userProfilePic ?? "")) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Circle()
                    .fill(Color(hex: "4B548D").opacity(0.1))
                    .overlay(
                        Text("\(transaction.receiverId?.firstName.prefix(1) ?? "nil")")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "4B548D"))
                    )
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
            
            // Transaction Details
            VStack(alignment: .leading, spacing: 4) {
                Text("\(transaction.receiverId?.firstName ?? "nil") \(transaction.receiverId?.lastName ?? "nil")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    if currentUser{
                      Text("Recieved")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }else{
                        Text("Sent")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Circle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 3, height: 3)
                    
                    Text(formattedDate(transaction.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Amount & Status
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(currentUser ? "+" : "-")\(transaction.coins ?? 0)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(currentUser ? .green : .red)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(transaction.status.uppercased() == "SUCCESS" ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    
                    Text(transaction.status.capitalized)
                        .font(.caption2)
                        .foregroundColor(transaction.status.uppercased() == "SUCCESS" ? .green : .orange)
                }
            }
        }
        .padding(12)
        .background(Color(hex: "F8F9FD"))
        .cornerRadius(12)
    }
    
    private func formattedDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM dd, h:mm a"
        return displayFormatter.string(from: date)
    }
}

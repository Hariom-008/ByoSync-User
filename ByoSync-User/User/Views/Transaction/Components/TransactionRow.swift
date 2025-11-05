//
//  TransactionRow.swift
//  ByoSync
//
//  Created by Hari's Mac on 01.11.2025.
//

import Foundation
import SwiftUI

struct TransactionRow: View {
    let tx: Transaction
    let discount: Double
    
    private var formattedDate: String {
        let inputFormatter = DateFormatter()
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        inputFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"

        if let date = inputFormatter.date(from: tx.createdAt) {
            let outputFormatter = DateFormatter()
            outputFormatter.locale = Locale.current
            outputFormatter.timeZone = TimeZone.current
            outputFormatter.dateFormat = "MMM dd, yyyy • hh:mm a"

            return outputFormatter.string(from: date)
        } else {
            return tx.createdAt
        }
    }
    
    private var statusColor: Color {
        switch tx.status.uppercased() {
        case "SUCCESS", "COMPLETED":
            return .green
        case "PENDING":
            return .orange
        case "FAILED":
            return .red
        default:
            return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "4B548D").opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    AsyncImage(url: stringToURL(tx.merchantId.merchantProfilePic)) { phase in
                        switch phase {
                        case .empty:
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .foregroundColor(.orange)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                        case .failure:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                
                // Transaction Details
                VStack(alignment: .leading, spacing: 6) {
                    // Amount and status
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Paid to")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.gray)
                            
                            Text("\(tx.merchantId.merchantName)")
                                .font(.subheadline)
                                .foregroundColor(.black)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("₹\(String(format: "%.2f", tx.totalAmount - discount))")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.red)
                            
                            // Status badge
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 4, height: 4)
                                
                                Text(tx.status)
                                    .font(.caption2.weight(.medium))
                                    .foregroundColor(statusColor)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    
                    // Date and time
                    HStack(spacing: 4) {
                        Text(formattedDate)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            
            // MARK: - Discount Row (shown if discount > 0)
            if discount > 0 {
                Divider()
                    .padding(.horizontal, 12)
                
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                        
                        Text("Discount by ByoSync")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.black.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Text("+ ₹\(String(format: "%.2f", discount))")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.08))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
    }
}

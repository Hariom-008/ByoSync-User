////
////  DiscountTransactionRow.swift
////  ByoSync
////
////  Created by Hari's Mac on 01.11.2025.
////
//
//import Foundation
//import SwiftUI
//
//// MARK: - Discount Transaction Row
//struct DiscountTransactionRow: View {
//    let discount: DiscountTransaction
//    
//    var body: some View {
//        HStack(spacing: 14) {
//            // Icon
//            ZStack {
//                Circle()
//                    .fill(Color(hex: "4CAF50").opacity(0.1))
//                    .frame(width: 44, height: 44)
//                
//                Image(systemName: "gift.fill")
//                    .font(.system(size: 14, weight: .semibold))
//                    .foregroundColor(Color(hex: "4CAF50"))
//            }
//            
//            // Discount Details
//            VStack(alignment: .leading, spacing: 6) {
//                // Amount and status
//                HStack {
//                    VStack(alignment: .leading, spacing: 2) {
//                        Text("Discount Earned")
//                            .font(.subheadline.weight(.semibold))
//                            .foregroundColor(.primary)
//                        
//                        Text(discount.merchantName)
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                    }
//                    
//                    Spacer()
//                    
//                    VStack(alignment: .trailing, spacing: 2) {
//                        Text(discount.formattedDiscountAmount)
//                            .font(.subheadline.weight(.bold))
//                            .foregroundColor(Color(hex: "4CAF50"))
//                        
//                        // Discount percentage badge
//                        HStack(spacing: 4) {
//                            Circle()
//                                .fill(Color(hex: "4CAF50"))
//                                .frame(width: 4, height: 4)
//                            
//                            Text("\(Int(discount.discountPercentage))% off")
//                                .font(.caption2.weight(.medium))
//                                .foregroundColor(Color(hex: "4CAF50"))
//                        }
//                        .padding(.horizontal, 8)
//                        .padding(.vertical, 4)
//                        .background(Color(hex: "4CAF50").opacity(0.1))
//                        .cornerRadius(6)
//                    }
//                }
//                
//                // Date and time
//                HStack(spacing: 4) {
//                    Image(systemName: "clock")
//                        .font(.system(size: 10))
//                        .foregroundColor(.secondary)
//                    
//                    Text(discount.formattedDate)
//                        .font(.caption2)
//                        .foregroundColor(.secondary)
//                }
//            }
//        }
//        .padding(12)
//        .background(
//            RoundedRectangle(cornerRadius: 12)
//                .fill(Color(hex: "4CAF50").opacity(0.05))
//                .overlay(
//                    RoundedRectangle(cornerRadius: 12)
//                        .stroke(Color(hex: "4CAF50").opacity(0.2), lineWidth: 1)
//                )
//                .shadow(color: Color(hex: "4CAF50").opacity(0.04), radius: 8, y: 2)
//        )
//    }
//}

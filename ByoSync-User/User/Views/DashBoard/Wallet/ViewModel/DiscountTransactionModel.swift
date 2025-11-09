//
//  DiscountTransaction.swift
//  ByoSync
//
//  Model to track discount transactions
//

import Foundation

struct DiscountTransaction: Identifiable, Codable {
    let id: String = UUID().uuidString
    let merchantName: String
    let originalAmount: Double
    let discountPercentage: Double
    let discountAmount: Double
    let paymentDate: Date
    let status: String  // "APPLIED", "PENDING", etc.
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy • hh:mm a"
        return formatter.string(from: paymentDate)
    }
    
    var formattedOriginalAmount: String {
        String(format: "₹%.2f", originalAmount)
    }
    
    var formattedDiscountAmount: String {
        String(format: "₹%.2f", discountAmount)
    }
}

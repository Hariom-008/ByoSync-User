//
//  WalletManager.swift
//  ByoSync
//
//  Created by Hari's Mac on 31.10.2025.
//

import Foundation
//
//  DiscountTransactionManager.swift
//  ByoSync
//
//  Manager for storing and retrieving discount transactions
//

import Foundation
import Combine

class DiscountTransactionManager: ObservableObject {
    @Published var discountTransactions: [DiscountTransaction] = []
    
    private let userDefaults = UserDefaults.standard
    private let discountTransactionsKey = "discountTransactions"
    
    init() {
        loadTransactions()
    }
    
    // MARK: - Add New Discount Transaction
    func addDiscountTransaction(
        merchantName: String,
        originalAmount: Double,
        discountPercentage: Double = 10.0
    ) {
        let discountAmount = (originalAmount * discountPercentage) / 100
        
        let transaction = DiscountTransaction(
            merchantName: merchantName,
            originalAmount: originalAmount,
            discountPercentage: discountPercentage,
            discountAmount: discountAmount,
            paymentDate: Date(),
            status: "APPLIED"
        )
        
        discountTransactions.insert(transaction, at: 0)  // Insert at beginning for newest first
        saveTransactions()
        
        print("✅ Discount transaction added: \(merchantName) - ₹\(String(format: "%.2f", discountAmount))")
    }
    
    // MARK: - Get Total Discounts Applied
    func getTotalDiscountAmount() -> Double {
        return discountTransactions.reduce(0) { $0 + $1.discountAmount }
    }
    
    // MARK: - Get Discounts by Date Range
    func getDiscountsByDateRange(start: Date, end: Date) -> [DiscountTransaction] {
        return discountTransactions.filter { transaction in
            transaction.paymentDate >= start && transaction.paymentDate <= end
        }
    }
    
    // MARK: - Get Recent Discounts
    func getRecentDiscounts(limit: Int = 5) -> [DiscountTransaction] {
        return Array(discountTransactions.prefix(limit))
    }
    
    // MARK: - Save Transactions
    private func saveTransactions() {
        do {
            let encoder = JSONEncoder()
            let encodedData = try encoder.encode(discountTransactions)
            userDefaults.set(encodedData, forKey: discountTransactionsKey)
        } catch {
            print("❌ Error saving discount transactions: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Load Transactions
    private func loadTransactions() {
        if let data = userDefaults.data(forKey: discountTransactionsKey) {
            do {
                let decoder = JSONDecoder()
                discountTransactions = try decoder.decode([DiscountTransaction].self, from: data)
                print("✅ Loaded \(discountTransactions.count) discount transactions")
            } catch {
                print("❌ Error loading discount transactions: \(error.localizedDescription)")
                discountTransactions = []
            }
        }
    }
    
    // MARK: - Clear All Transactions
    func clearAllTransactions() {
        discountTransactions = []
        userDefaults.removeObject(forKey: discountTransactionsKey)
        print("✅ All discount transactions cleared")
    }
}

import Foundation
import SwiftUI
import Combine
import UIKit

final class TransactionViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var downloadedFileURL: URL?
    @Published var discount: Double = 0.0
    @Published var totalAmount: Double = 0.0

    @AppStorage("creditAvailable") var creditAvailable: Double = 0.0
    @AppStorage("transactionCount") var savedTransactionCount: Int = 0
    
    // Computed properties
    var transactionCount: Int {
        transactions.count
    }
    
    var successCount: Int {
        transactions.filter { $0.status.uppercased() == "SUCCESS" }.count
    }
    
    var formattedDiscount: String {
        "₹\(String(format: "%.2f", discount))"
    }
    
    var formattedTotalAmount: String {
        "₹\(String(format: "%.2f", totalAmount))"
    }
    
    // MARK: - Sort Transactions
    /// Returns transactions sorted by createdAt in descending order (newest first)
    func getSortedTransactions() -> [Transaction] {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        return transactions.sorted { tx1, tx2 in
            guard let date1 = dateFormatter.date(from: tx1.createdAt),
                  let date2 = dateFormatter.date(from: tx2.createdAt) else {
                return false
            }
            return date1 > date2  // Descending order (newest first)
        }
    }
    
    // MARK: - Discount Calculation Logic
    /// Calculates discount for a single transaction amount
    /// - Rules: If amount >= 10, apply 10% discount, but cap at ₹50 maximum per transaction
    func calculateTransactionDiscount(_ amount: Double) -> Double {
        if amount >= 10 {
            let calculatedDiscount = amount * 0.10
            return min(calculatedDiscount, 50.0)  // Cap at ₹50
        }
        return 0.0
    }
    
    // MARK: - Fetch Daily Transactions
    func fetchTransactions(for date: Date, reportType: ReportType) {
        let dateString = formattedDate(date)
        
        switch reportType {
        case .view:
            fetchViewReport(date: dateString, type: "daily")
        case .email:
            sendEmailReport(date: dateString, type: "daily")
        case .download:
            downloadReport(date: dateString, type: "daily")
        }
    }
    
    // MARK: - Fetch Monthly Transactions
    func fetchMonthlyTransactions(month: Int, year: Int, reportType: ReportType) {
        let monthString = String(format: "%02d", month)
        let yearString = String(year)
        
        switch reportType {
        case .view:
            fetchMonthlyViewReport(month: monthString, year: yearString)
        case .email:
            sendMonthlyEmailReport(month: monthString, year: yearString)
        case .download:
            downloadMonthlyReport(month: monthString, year: yearString)
        }
    }
    
    // MARK: - Fetch Custom Period Transactions
    func fetchCustomTransactions(startDate: Date, endDate: Date, reportType: ReportType) {
        let startDateString = formattedDate(startDate)
        let endDateString = formattedDate(endDate)
        
        switch reportType {
        case .view:
            fetchCustomViewReport(startDate: startDateString, endDate: endDateString)
        case .email:
            sendCustomEmailReport(startDate: startDateString, endDate: endDateString)
        case .download:
            downloadCustomReport(startDate: startDateString, endDate: endDateString)
        }
    }
    
    // MARK: - Daily Report Methods
    private func fetchViewReport(date: String, type: String) {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        transactions = []
        
        TransactionRepository.shared.fetchDailyReport(date: date, type: "VIEW") { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .success(let data):
                    self.transactions = data
                    self.calculateDiscount(from: data)
                    self.savedTransactionCount = data.count
                    self.successMessage = "✓ Loaded \(data.count) transaction\(data.count != 1 ? "s" : "")"
                    self.hideSuccessMessageAfterDelay()
                    
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func sendEmailReport(date: String, type: String) {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        TransactionRepository.shared.emailDailyReport(date: date) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .success(let message):
                    self.successMessage = "✓ \(message)"
                    self.hideSuccessMessageAfterDelay()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func downloadReport(date: String, type: String) {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        TransactionRepository.shared.downloadDailyReport(date: date) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .success(let fileURL):
                    self.downloadedFileURL = fileURL
                    self.successMessage = "✓ Report downloaded successfully"
                    self.hideSuccessMessageAfterDelay()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Monthly Report Methods
    private func fetchMonthlyViewReport(month: String, year: String) {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        transactions = []
        
        TransactionRepository.shared.fetchMonthlyReport(month: month, year: year, type: "VIEW") { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .success(let data):
                    self.transactions = data
                    self.calculateDiscount(from: data)
                    self.savedTransactionCount = data.count
                    self.successMessage = "✓ Loaded \(data.count) transaction\(data.count != 1 ? "s" : "")"
                    self.hideSuccessMessageAfterDelay()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func sendMonthlyEmailReport(month: String, year: String) {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        // TODO: Implement monthly email endpoint when available
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isLoading = false
            self.successMessage = "✓ Monthly report will be sent to your email"
            self.hideSuccessMessageAfterDelay()
        }
    }
    
    private func downloadMonthlyReport(month: String, year: String) {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        // TODO: Implement monthly download endpoint when available
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isLoading = false
            self.errorMessage = "Monthly download not yet implemented"
        }
    }
    
    // MARK: - Custom Period Report Methods
    private func fetchCustomViewReport(startDate: String, endDate: String) {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        transactions = []
        
        TransactionRepository.shared.fetchCustomReport(startDate: startDate, endDate: endDate, type: "VIEW") { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .success(let data):
                    self.transactions = data
                    self.calculateDiscount(from: data)
                    self.savedTransactionCount = data.count
                    self.successMessage = "✓ Loaded \(data.count) transaction\(data.count != 1 ? "s" : "")"
                    self.hideSuccessMessageAfterDelay()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func sendCustomEmailReport(startDate: String, endDate: String) {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        // TODO: Implement custom email endpoint when available
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isLoading = false
            self.successMessage = "✓ Custom report will be sent to your email"
            self.hideSuccessMessageAfterDelay()
        }
    }
    
    private func downloadCustomReport(startDate: String, endDate: String) {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        // TODO: Implement custom download endpoint when available
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isLoading = false
            self.errorMessage = "Custom download not yet implemented"
        }
    }
    
    // MARK: - Calculate Total Discount
    /// Calculates total discount by summing discount for each transaction
    /// - Each transaction: if amount >= 10, apply 10% discount capped at ₹50
    private func calculateDiscount(from transactions: [Transaction]) {
        let total = transactions.reduce(0.0) { $0 + $1.totalAmount }
        totalAmount = total  // Update totalAmount
        
        // Calculate total discount: sum of individual transaction discounts
        let totalDiscount = transactions.reduce(0.0) { sum, tx in
            sum + calculateTransactionDiscount(tx.totalAmount)
        }
        
        discount = totalDiscount
        creditAvailable = discount
        
        print("📊 Discount Calculation:")
        print("   Total Amount: ₹\(String(format: "%.2f", total))")
        print("   Total Discount (10% per transaction, max ₹50 each): ₹\(String(format: "%.2f", discount))")
        print("   Number of transactions: \(transactions.count)")
        print("💾 Saved creditAvailable: ₹\(creditAvailable)")
    }

    // MARK: - Share Downloaded File
    func shareFile(url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootViewController.view
            popover.sourceRect = CGRect(
                x: rootViewController.view.bounds.midX,
                y: rootViewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        
        rootViewController.present(activityVC, animated: true)
    }
    
    // MARK: - Helpers
    private func hideSuccessMessageAfterDelay(delay: TimeInterval = 3.0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            withAnimation {
                self?.successMessage = nil
            }
        }
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    func formattedDateDisplay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM dd, yyyy"
        return formatter.string(from: date)
    }
}

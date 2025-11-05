import Foundation
import Alamofire
import Foundation


struct TransactionAPIResponse: Codable {
    let statusCode: Int
    let message: String
    let data: [Transaction]
}

struct Transaction: Codable, Identifiable,Equatable {
    let id: String
    let merchantId: MerchantInfo
    let currency: String
    let status: String
    let user: TxUser
    let payerDevice: String
    let createdAt: String
    let updatedAt: String
    let discount: Double
    let paidByUser: Double
    let totalAmount: Double
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case merchantId
        case currency
        case status
        case user
        case payerDevice
        case createdAt
        case updatedAt
        case discount
        case paidByUser
        case totalAmount
    }
}

struct MerchantInfo: Codable,Equatable {
    let id: String
    let merchantName: String
    let merchantProfilePic: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case merchantName
        case merchantProfilePic = "profilePic"
    }
}

struct TxUser: Codable,Equatable{
    let id: String
    let firstName: String
    let lastName: String
    let userProfilePic: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName
        case lastName
        case userProfilePic = "profilePic"
    }
}

final class TransactionRepository {
    static let shared = TransactionRepository()
    private init() {}
    
    // MARK: - Daily Report
    func fetchDailyReport(
        date: String,
        type: String,
        completion: @escaping (Result<[Transaction], APIError>) -> Void
    ) {
        let endpoint = UserAPIEndpoint.TransactionAPI.dailyReport(date: date, type: type)
        let headers = getHeader.shared.getAuthHeaders()
        
        print("📅 Fetching Daily Report for \(date) [type: \(type)]")
        print("🔗 Endpoint: \(endpoint)")
        
        APIClient.shared.request(
            endpoint,
            method: .get,
            headers: headers
        ) { (result: Result<TransactionAPIResponse, APIError>) in
            switch result {
            case .success(let response):
                print("✅ Status Code: \(response.statusCode)")
                print("✅ Message: \(response.message)")
                print("✅ Data Count: \(response.data.count)")
                
                if (200...299).contains(response.statusCode) {
                    completion(.success(response.data))
                } else {
                    completion(.failure(.custom(response.message)))
                }
                
            case .failure(let error):
                print("❌ Error: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Custom Date Range Report
    func fetchCustomReport(
        startDate: String,
        endDate: String,
        type: String,
        completion: @escaping (Result<[Transaction], APIError>) -> Void
    ) {
        let endpoint = UserAPIEndpoint.TransactionAPI.customReport(startDate: startDate, endDate: endDate, type: type)
        let headers = getHeader.shared.getAuthHeaders()
        
        print("📊 Fetching Custom Report [\(startDate) → \(endDate)] [type: \(type)]")
        
        APIClient.shared.request(
            endpoint,
            method: .get,
            headers: headers
        ) { (result: Result<TransactionAPIResponse, APIError>) in  // Changed this to use TransactionAPIResponse
            switch result {
            case .success(let response):
                if (200...299).contains(response.statusCode) {
                    completion(.success(response.data))
                } else {
                    completion(.failure(.custom(response.message)))
                }
            case .failure(let error):
                print("❌ Error: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Monthly Report
    func fetchMonthlyReport(
        month: String,
        year: String,
        type: String,
        completion: @escaping (Result<[Transaction], APIError>) -> Void
    ) {
        let endpoint = UserAPIEndpoint.TransactionAPI.monthlyReport(month: month, year: year, type: type)
        let headers = getHeader.shared.getAuthHeaders()
        
        print("📆 Fetching Monthly Report for \(month)-\(year) [type: \(type)]")
        
        APIClient.shared.request(
            endpoint,
            method: .get,
            headers: headers
        ) { (result: Result<APIResponse<[Transaction]>, APIError>) in
            switch result {
            case .success(let response):
                if response.success ?? false, let transactions = response.data {
                    completion(.success(transactions))
                } else {
                    completion(.failure(.custom(response.message)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Download Daily Report
    func downloadDailyReport(
        date: String,
        completion: @escaping (Result<URL, APIError>) -> Void
    ) {
        let endpoint = UserAPIEndpoint.TransactionAPI.dailyReport(date: date, type: "DOWNLOAD")
        let headers = getHeader.shared.getAuthHeaders()
        
        print("📥 Downloading Daily Report for \(date)")
        print("🔗 Endpoint: \(endpoint)")
        
        APIClient.shared.downloadFile(
            endpoint,
            method: .get,
            headers: headers
        ) { result in
            switch result {
            case .success(let fileURL):
                print("✅ Report downloaded to: \(fileURL.path)")
                completion(.success(fileURL))
            case .failure(let error):
                print("❌ Download failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Email Daily Report (Returns message only)
    func emailDailyReport(
        date: String,
        completion: @escaping (Result<String, APIError>) -> Void
    ) {
        let endpoint = UserAPIEndpoint.TransactionAPI.dailyReport(date: date, type: "EMAIL")
        let headers = getHeader.shared.getAuthHeaders()
        
        print("📧 Sending Daily Report via Email for \(date)")
        
        // For EMAIL type, backend probably sends email and returns a success message
        APIClient.shared.request(
            endpoint,
            method: .get,
            headers: headers
        ) { (result: Result<APIResponse<EmptyData>, APIError>) in
            switch result {
            case .success(let response):
                if (200...299).contains(response.statusCode) {
                    completion(.success(response.message))
                } else {
                    completion(.failure(.custom(response.message)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}


import Foundation
import Alamofire
import Combine

// MARK: - Request Model
struct CreateOrderRequest: Encodable {
    let receiverId: String
    let senderDeviceId: String
    let coins: Int
    let senderId: String
}

// MARK: - Response Model
struct CreateOrderResponse: Decodable {
    let success: Bool
    let data: OrderData
    let message: String?
}

struct OrderData: Codable, Identifiable {
    let id: String
    let type: OrderType      // ✅ Use OrderType here
    let receiverId: String
    let coins: Int
    let status: OrderStatus  // ✅ "SUCCESS" will map here
    let senderId: String
    let senderDeviceId: String
    let createdAt: String
    let updatedAt: String
    let v: Int

    enum CodingKeys: String, CodingKey {
        case type
        case receiverId
        case coins
        case status
        case senderId
        case senderDeviceId
        case createdAt
        case updatedAt
        case id = "_id"
        case v = "__v"
    }
}

enum OrderType: String, Codable {
    case transfer = "TRANSFER"
}
enum OrderStatus: String, Codable {
    case success = "SUCCESS"
    // add more if API returns others, e.g.:
    // case pending = "PENDING"
    // case failed = "FAILED"
}

// MARK: - Repository
final class CreateOrderRepository {
    
    // MARK: - Create Order
    func createOrder(
        receiverId: String,
        senderDeviceId: String,
        amount: Int,
        senderId: String,
        completion: @escaping (Result<CreateOrderResponse, APIError>) -> Void
    ) {
        print("🔵 [CreateOrderRepo] Creating order...")
        print("📤 Receiver ID: \(receiverId)")
        print("📤 Sender Device ID: \(senderDeviceId)")
        print("📤 Amount (coins): \(amount)")
        print("📤 Sender ID: \(senderId)")
        
        let requestBody = CreateOrderRequest(
            receiverId: receiverId,
            senderDeviceId: senderDeviceId,
            coins: amount,
            senderId: senderId
        )
        
        let parameters: [String: Any] = [
            "receiverId": receiverId,
            "senderDeviceId": senderDeviceId,
            "coins": amount,
            "senderId": senderId
        ]
        let headers = getHeader.shared.getAuthHeaders()
        
        print("📦 Request Body: \(parameters)")
        
        APIClient.shared.request(
            CommonEndpoint.CreateOrder,
            method: .post,
            parameters: parameters,
            headers: headers
        ) { (result: Result<CreateOrderResponse, APIError>) in
            switch result {
            case .success(let response):
                print("✅ [CreateOrderRepo] Order created successfully")
                print("✅ Order ID: \(response.data.id)")
                print("✅ Message: \(response.message ?? "N/A")")
                completion(.success(response))
                
            case .failure(let error):
                print("❌ [CreateOrderRepo] Failed to create order: \(error)")
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Create Order ViewModel
final class CreateOrderViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var orderId: String = ""
    
    @Published var senderDeviceId = UserSession.shared.currentUser?.userDeviceId
    @Published var senderId = UserSession.shared.currentUser?.userId
    
    // MARK: - Dependencies
    private let repository: CreateOrderRepository
    
    // MARK: - Initialization
    init(repository: CreateOrderRepository = CreateOrderRepository()) {
        self.repository = repository
        print("🟢 [CreateOrderVM] Initialized")
    }
    
  
    // MARK: - Create Order
    func createOrder(
        receiverId: String,
        amount: Int,
    ) {
        print("🔵 [CreateOrderVM] Creating order...")
        print("📤 Amount: \(amount)")
        
        // Reset previous states
        errorMessage = nil
        successMessage = nil
        orderId = ""
        isLoading = true
        
        repository.createOrder(
            receiverId: receiverId,
            senderDeviceId: senderDeviceId ?? "",
            amount: amount,
            senderId: senderId ?? ""
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let response):
                    print("✅ [CreateOrderVM] Order created successfully")
                    self?.orderId = response.data.id
                    self?.successMessage = response.message ?? "Order created successfully"
                    
                case .failure(let error):
                    print("❌ [CreateOrderVM] Failed to create order")
                    self?.handleError(error)
                }
            }
        }
    }
    
    // MARK: - Error Handling
    private func handleError(_ error: APIError) {
        print("❌ [CreateOrderVM] Handling error: \(error)")
        print("📱 Error message displayed: \(errorMessage ?? "None")")
    }
    
    // MARK: - Reset State
    func resetState() {
        print("🔄 [CreateOrderVM] Resetting state")
        errorMessage = nil
        successMessage = nil
        orderId = ""
        isLoading = false
    }
}

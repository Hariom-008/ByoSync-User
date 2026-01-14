import Foundation
import Alamofire

// MARK: - Response Models

struct UserDataByIdResponse: Decodable {
    let statusCode: Int
    let data: UserDataByIdPayload
    let message: String
    let success: Bool
}

struct UserDataByIdPayload: Decodable {
    let user: UserByIdDTO
    let device: DeviceByIdDTO
}

struct UserByIdDTO: Decodable, Identifiable, Equatable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let phoneNumber: String
    let salt: String

    // Not in the shared response; keep optional to avoid decode failures
    let faceToken: String?

    let wallet: Double
    let chai: Int
    let referralCode: String
    let transactionCoins: Int
    let noOfTransactions: Int
    let noOfTransactionsReceived: Int
    let profilePic: String?
    let devices: [String]
    let emailVerified: Bool

    let createdAt: String
    let updatedAt: String
    let v: Int
    let token:Int

    // New fields from API response
    let deletedAt: String?
    let isDeleted: Bool
    let todayChaiCount: Int

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case email, firstName, lastName, phoneNumber
        case salt, faceToken
        case wallet, chai
        case referralCode, transactionCoins, noOfTransactions, noOfTransactionsReceived
        case profilePic, devices, emailVerified, createdAt, updatedAt
        case v = "__v"

        case deletedAt, isDeleted, todayChaiCount
        case token
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id = try c.decode(String.self, forKey: .id)
        email = try c.decode(String.self, forKey: .email)
        firstName = try c.decode(String.self, forKey: .firstName)
        lastName = try c.decode(String.self, forKey: .lastName)
        phoneNumber = try c.decode(String.self, forKey: .phoneNumber)
        salt = try c.decode(String.self, forKey: .salt)

        // Optional since it may not exist
        faceToken = try c.decodeIfPresent(String.self, forKey: .faceToken)

        // Wallet can arrive as Int or Double
        if let wDouble = try? c.decode(Double.self, forKey: .wallet) {
            wallet = wDouble
        } else {
            wallet = Double(try c.decode(Int.self, forKey: .wallet))
        }

        chai = try c.decode(Int.self, forKey: .chai)
        referralCode = try c.decode(String.self, forKey: .referralCode)
        transactionCoins = try c.decode(Int.self, forKey: .transactionCoins)
        noOfTransactions = try c.decode(Int.self, forKey: .noOfTransactions)
        noOfTransactionsReceived = try c.decode(Int.self, forKey: .noOfTransactionsReceived)

        profilePic = try c.decodeIfPresent(String.self, forKey: .profilePic)
        devices = try c.decode([String].self, forKey: .devices)
        emailVerified = try c.decode(Bool.self, forKey: .emailVerified)

        createdAt = try c.decode(String.self, forKey: .createdAt)
        updatedAt = try c.decode(String.self, forKey: .updatedAt)
        v = try c.decode(Int.self, forKey: .v)

        // New fields (deletedAt can be null)
        deletedAt = try c.decodeIfPresent(String.self, forKey: .deletedAt)
        isDeleted = try c.decode(Bool.self, forKey: .isDeleted)
        todayChaiCount = try c.decode(Int.self, forKey: .todayChaiCount)
        token = try c.decode(Int.self, forKey: .token)
    }
}
extension UserByIdDTO {

    /// Build a UserByIdDTO from locally cached User.
    /// Fields not available in cache are filled with safe defaults.
    init(fromCached user: User) {
        self.id = user.userId ?? ""
        self.email = user.email
        self.firstName = user.firstName
        self.lastName = user.lastName
        self.phoneNumber = user.phoneNumber ?? ""
        self.salt = ""                 // you don't have it locally
        self.faceToken = nil

        self.wallet = 0
        self.chai = 0
        self.referralCode = user.refferalCode ?? ""
        self.transactionCoins = 0
        self.noOfTransactions = 0
        self.noOfTransactionsReceived = 0

        self.profilePic = nil
        self.devices = user.userDeviceId.map { [$0] } ?? []
        self.emailVerified = false

        self.createdAt = ""
        self.updatedAt = ""
        self.v = 0

        self.deletedAt = nil
        self.isDeleted = false
        self.todayChaiCount = 0
        self.token = 0
    }
}



struct DeviceByIdDTO: Decodable, Identifiable {
    let id: String
    let deviceKey: String
    let deviceName: String
    let user: String
    let isPrimary: Bool
    let createdAt: String
    let updatedAt: String
    let v: Int

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case deviceKey, deviceName, user, isPrimary, createdAt, updatedAt
        case v = "__v"
    }
}

// MARK: - Protocol (completion-only)

protocol UserDataByIdRepositoryProtocol {
    func fetchUserDataById(
        userId: String,
        deviceKeyHash: String,
        completion: @escaping (Result<UserDataByIdResponse, APIError>) -> Void
    )
}

// MARK: - Repository

final class UserDataByIdRepository: UserDataByIdRepositoryProtocol {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func fetchUserDataById(
        userId: String,
        deviceKeyHash: String,
        completion: @escaping (Result<UserDataByIdResponse, APIError>) -> Void
    ) {
        let endpoint = UserAPIEndpoint.UserData.userDataById(
            userId: userId,
            deviceKeyHash: deviceKeyHash
        )

        client.request(
            endpoint,
            method: .get,
            parameters: nil,
            headers: nil,
            completion: completion
        )
    }
}

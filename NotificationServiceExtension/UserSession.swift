import Foundation
import Combine

final class UserSession: ObservableObject {
    static let shared = UserSession()
    
    @Published var currentUser: User?
    @Published var isEmailVerified: Bool = false
    @Published var userProfilePicture: String = ""
    @Published var currentUserDeviceID: String = ""
    @Published var thisDeviceIsPrimary: Bool = false
    @Published var currentUserID:String = ""
    @Published var wallet: Double = 0
    
    @Published var hasFaceData:Bool = false
    
    private let userDefaultsKey = "currentUser"
    private let emailVerifiedKey = "isEmailVerified"
    private let profilePictureKey = "userProfilePicture"
    private let currentUserDeviceIDKey = "currentUserDeviceID"
    private let thisDevicePrimaryKey = "thisDevicePrimaryKey"
    private let walletKey = "walletKey"
    private let currentUserUserIDKey = "userIDKey"
    
    private let hasFaceDataKey = "hasFaceDataKey"
    
    
    private init(){
        loadUser()
        loadEmailVerificationStatus()
        loadProfilePicture()
        loadCurrentDeviceID()
        loadThisDevicePrimary()
        loadWalletBalance()
        loadCurrentUserID()
        loadHasFaceData()
    }
    
    // MARK: - Profile Picture
    func setProfilePicture(_ urlString: String) {
        self.userProfilePicture = urlString
        UserDefaults.standard.set(urlString, forKey: profilePictureKey)
    }
    func setHasFaceData(_ hasFaceData: Bool) {
        DispatchQueue.main.async {
            self.hasFaceData = hasFaceData
            UserDefaults.standard.set(hasFaceData, forKey: self.hasFaceDataKey)
        }
    }

    
    func setCurrentUserId(_ id: String){
        self.currentUserID = id
        UserDefaults.standard.set(id, forKey: currentUserUserIDKey)
    }
    func setUserWallet(_ balance: Double){
        self.wallet = balance
        UserDefaults.standard.set(balance, forKey: walletKey)
    }
    private func loadWalletBalance(){
        self.wallet = UserDefaults.standard.double(forKey: walletKey)
        print("₹ Wallet Balance Fetched : \(wallet)")
    }
    private func loadProfilePicture() {
        self.userProfilePicture = UserDefaults.standard.string(forKey: profilePictureKey) ?? ""
    }
    private func loadHasFaceData() {
        // if key exists, read the bool; else keep default false
        if UserDefaults.standard.object(forKey: hasFaceDataKey) != nil {
            self.hasFaceData = UserDefaults.standard.bool(forKey: hasFaceDataKey)
        } else {
            self.hasFaceData = false
        }
    }

    
    private func loadCurrentUserID(){
    self.currentUserID = UserDefaults.standard.string(forKey: currentUserUserIDKey) ?? ""
}
    // MARK: - Save and Load User
    func saveUser(_ user: User) {
        DispatchQueue.main.async {
            self.currentUser = user
            if let userId = user.userId{
                self.currentUserID = userId
            }

            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(user) {
                UserDefaults.standard.set(encoded, forKey: self.userDefaultsKey)
                UserDefaults.standard.set(self.currentUserID, forKey: self.currentUserUserIDKey)
                print("✅ User saved to session: \(user.firstName) \(user.lastName)")
            }
        }
    }

    
    func loadUser() {
        if let savedUser = UserDefaults.standard.data(forKey: userDefaultsKey) {
            let decoder = JSONDecoder()
            if let loadedUser = try? decoder.decode(User.self, from: savedUser) {
                self.currentUser = loadedUser
                loadWalletBalance()
                loadCurrentUserID()
                loadHasFaceData()
                #if DEBUG
                print("[UserSession] ✅ User loaded from session: \(loadedUser.firstName) \(loadedUser.lastName)")
                print("[UserSession] 👨🏻HasFaceData: \(hasFaceData)")
                #endif
            }
        }
    }
    
    // MARK: - Email Verification Status
    func setEmailVerified(_ verified: Bool) {
        self.isEmailVerified = verified
        UserDefaults.standard.set(verified, forKey: emailVerifiedKey)
    }
    
    private func loadEmailVerificationStatus() {
        self.isEmailVerified = UserDefaults.standard.bool(forKey: emailVerifiedKey)
    }
    
    // MARK: - Current Device ID
    func setCurrentDeviceID(_ deviceID: String) {
        self.currentUserDeviceID = deviceID
        UserDefaults.standard.set(deviceID, forKey: currentUserDeviceIDKey)
    }
    
    private func loadCurrentDeviceID() {
        self.currentUserDeviceID = UserDefaults.standard.string(forKey: currentUserDeviceIDKey) ?? ""
        if !currentUserDeviceID.isEmpty {
            print("✅ Loaded current device ID: \(currentUserDeviceID)")
        } else {
            print("⚠️ No device ID found in UserDefaults yet.")
        }
    }

    // MARK: - This Device Primary
    func setThisDevicePrimary(_ isPrimary: Bool) {
        self.thisDeviceIsPrimary = isPrimary
        UserDefaults.standard.set(isPrimary, forKey: thisDevicePrimaryKey)
    }
    
    private func loadThisDevicePrimary() {
        self.thisDeviceIsPrimary = UserDefaults.standard.bool(forKey: thisDevicePrimaryKey)
    }

    // MARK: - Clear User Session
    func clearUser() {
        self.currentUser = nil
        self.isEmailVerified = false
        self.userProfilePicture = ""
        self.currentUserDeviceID = ""
        self.thisDeviceIsPrimary = false
        self.currentUserID = ""
        
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: emailVerifiedKey)
        UserDefaults.standard.removeObject(forKey: profilePictureKey)
        UserDefaults.standard.removeObject(forKey: currentUserDeviceIDKey)
        UserDefaults.standard.removeObject(forKey: thisDevicePrimaryKey)
        UserDefaults.standard.removeObject(forKey: "token")
        UserDefaults.standard.removeObject(forKey: "accountType")
        UserDefaults.standard.removeObject(forKey: currentUserUserIDKey)
        
        print("[UserSession]🚪 User session cleared")
    }
    
    
    // MARK: - Computed Properties
    var fullName: String {
        guard let user = currentUser else { return "Guest User" }
        return "\(user.firstName) \(user.lastName)"
    }
    
    var email: String {
        currentUser?.email ?? "No email"
    }
    
    var phoneNumber: String {
        currentUser?.phoneNumber ?? "No phone number"
    }
    
    var byoSyncId: String {
        guard let phone = currentUser?.phoneNumber else { return "No ID" }
        return "\(phone)@okbyosync"
    }
    
    var isLoggedIn: Bool {
        currentUser != nil
    }
}



// MARK: - User Model
struct User: Codable,Equatable{
    let firstName: String
    let lastName: String
    let email: String
    let phoneNumber: String?
    let deviceKey: String?
    let deviceName: String?
    let fcmToken: String?
    let refferalCode: String?
    let userId: String?
    let userDeviceId: String?
    let token: Int
    
    
    // Convenience initializer
    init(firstName: String, lastName: String, email: String, phoneNumber: String? = nil, deviceKey: String? = nil, deviceName: String? = nil,fcmToken:String? = nil, refferalCode: String? = nil, userId:String? = nil,userDeviceId:String? = nil, token:Int) {
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phoneNumber = phoneNumber
        self.deviceKey = deviceKey
        self.deviceName = deviceName
        self.fcmToken = fcmToken
        self.refferalCode = refferalCode
        self.userId = userId
        self.userDeviceId = userDeviceId
        self.token = token
    }
}
struct Address: Codable {
    var address1: String
    var address2: String
    var city: String
    var state: String
    var pincode: String
}


// MARK: - User Data
struct UserData: Codable, Identifiable {
    
    // Core User Info
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let phoneNumber: String
    
    let salt: String
    let faceToken: String
    
    // Financial & Activity Data
    let wallet: Double // Changed from Double as the response had '9169'
    
    let referralCode: String
    let transactionCoins: Int
    let noOfTransactions: Int
    let noOfTransactionsReceived: Int
    
    // Profile & Device Info
    let profilePic: String? // Changed to optional String as it might sometimes be null or missing
    let devices: [String]
    let emailVerified: Bool
    let faceId: [FaceIdItem]? // Updated to an array of complex FaceIdItem objects
    
    // Timestamps & Version
    let createdAt: String
    let updatedAt: String
    let v: Int
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case email
        case firstName
        case lastName
        case phoneNumber
        // case pattern
        case salt
        case faceToken
        case wallet
        case referralCode
        case transactionCoins
        case noOfTransactions
        case noOfTransactionsReceived
        case profilePic
        case devices
        case emailVerified
        case faceId
        case createdAt
        case updatedAt
        case v = "__v"
    }
    
    // Your computed property for initials (remains unchanged)
    var initials: String {
        let firstInitial = firstName.first?.uppercased() ?? ""
        let lastInitial = lastName.first?.uppercased() ?? ""
        return "\(firstInitial)\(lastInitial)"
    }
}

// MARK: - Nested Face ID Item Structure
struct FaceIdItem: Codable,Equatable {
    let ecc: String?
    let helper: String?
    let hashHex: String?
    let r: String?
    let hashBits: String?
    let _id: String?
}

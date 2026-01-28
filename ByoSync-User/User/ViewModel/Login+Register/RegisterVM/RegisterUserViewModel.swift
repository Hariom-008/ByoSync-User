import Foundation
import Combine
import UIKit

final class RegisterUserViewModel: ObservableObject {

    // MARK: - Dependencies
    private let cryptoService: any CryptoService
    private let repository: RegisterUserRepository

    // MARK: - Inputs
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var email = ""
    @Published var phoneNumber = ""

    // MARK: - UI State
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var navigateToMainTab = false

    // MARK: - Device Identity
    @Published private(set) var deviceId: String
    @Published private(set) var deviceName: String

    // MARK: - Init
    init(cryptoService: any CryptoService) {
        self.cryptoService = cryptoService
        self.repository = RegisterUserRepository(cryptoService: cryptoService)
        self.deviceId = DeviceIdentity.resolve()
        self.deviceName = UIDevice.current.model

        #if DEBUG
        print("🎯 [VM] RegisterUserViewModel initialized with crypto service")
        #endif

        Logger.shared.d(
            "REGISTER",
            "RegisterUserViewModel init | deviceName=\(deviceName) | deviceIdPresent=\(!deviceId.isEmpty)",
            user: UserSession.shared.currentUser?.userId
        )
    }

    // MARK: - Validation
    private var trimmedFirstName: String { firstName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedLastName: String  { lastName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedEmail: String     { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedPhone: String     { phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines) }

    var allFieldsFilled: Bool {
        !trimmedFirstName.isEmpty &&
        !trimmedLastName.isEmpty &&
        !trimmedEmail.isEmpty &&
        !trimmedPhone.isEmpty
    }

    var isValidEmail: Bool {
        NSPredicate(
            format: "SELF MATCHES %@",
            "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        ).evaluate(with: trimmedEmail)
    }

    var canSubmit: Bool { allFieldsFilled && isValidEmail }

    // MARK: - Register
    func registerUser() {
        // Fail fast if deviceId missing (prevents silent backend weirdness)
        guard !deviceId.isEmpty else {
            showErrorMessage("Device identifier unavailable.")
            Logger.shared.e(
                "REGISTER VM",
                "DeviceIdentity.resolve() returned empty deviceId",
                user: UserSession.shared.currentUser?.userId
            )
            return
        }

        guard canSubmit else {
            showErrorMessage("Please fill all fields correctly.")

            let missing = [
                trimmedFirstName.isEmpty ? "firstName" : nil,
                trimmedLastName.isEmpty ? "lastName" : nil,
                trimmedEmail.isEmpty ? "email" : nil,
                trimmedPhone.isEmpty ? "phoneNumber" : nil
            ].compactMap { $0 }

            Logger.shared.e(
                "REGISTER VM",
                "Validation failed | missing=\(missing) | isValidEmail=\(isValidEmail)",
                user: UserSession.shared.currentUser?.userId
            )
            return
        }

        isLoading = true
        errorMessage = nil
        showError = false

        Logger.shared.i(
            "REGISTER VM",
            "Register start | email=\(trimmedEmail) | deviceName=\(deviceName)",
            user: UserSession.shared.currentUser?.userId
        )

        let startTime = CFAbsoluteTimeGetCurrent()
        let e164Phone = normalizeToE164India(trimmedPhone)
        repository.registerUser(
            firstName: trimmedFirstName,
            lastName: trimmedLastName,
            email: trimmedEmail,
            phoneNumber: e164Phone,
            deviceId: deviceId,
            deviceName: deviceName
        ) { [weak self] result in
            guard let self else { return }

            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)

            DispatchQueue.main.async {
                self.isLoading = false
                self.handleRegistrationResult(result, timeTakenMs: elapsedMs)
            }
        }
    }

    // MARK: - Result Handling
    private func handleRegistrationResult(
        _ result: Result<APIResponse<RegisterUserData>, APIError>,
        timeTakenMs: Int64
    ) {
        switch result {

        case .success(let response):
            guard
                let userData = response.data?.newUser,
                let device = response.data?.newDevice
            else {
                showErrorMessage("Invalid server response.")
                Logger.shared.e(
                    "REGISTER VM",
                    "Missing newUser/newDevice in response payload | msg=\(response.message)",
                    timeTakenMs: timeTakenMs,
                    user: UserSession.shared.currentUser?.userId
                )
                return
            }
            let e164Phone = normalizeToE164India(trimmedPhone)
            
            let user = User(
                firstName: trimmedFirstName,
                lastName: trimmedLastName,
                email: trimmedEmail,
                phoneNumber: e164Phone,
                deviceKey: device.deviceKey,
                deviceName: device.deviceName,
                userId: userData.id,
                userDeviceId: device.id,
                token: userData.token
            )

            // Persist
            UserDefaults.standard.set(device.token, forKey: "token")
            UserDefaults.standard.set("user", forKey: "accountType")

            UserSession.shared.saveUser(user)
            UserSession.shared.setCurrentDeviceID(device.id)
            UserSession.shared.setThisDevicePrimary(device.isPrimary)
            UserSession.shared.setUserWallet(userData.wallet)
            UserSession.shared.setProfilePicture(userData.profilePic ?? "")

            Logger.shared.i(
                "REGISTER",
                "Register success | msg=\(response.message) | primary=\(device.isPrimary) | emailVerified=\(userData.emailVerified)",
                timeTakenMs: timeTakenMs,
                user: userData.id
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.navigateToMainTab = true
                Logger.shared.d(
                    "REGISTER",
                    "Navigation triggered: navigateToMainTab=true",
                    user: userData.id
                )
            }

        case .failure(let error):
            // ✅ Extract actual server message - custom errors show message as-is
            let errorMessage = extractErrorMessage(from: error)
            print("❌ [RegisterUser] API Error: \(errorMessage)")
            
            showErrorMessage(errorMessage)
            Logger.shared.e(
                "REGISTER VM",
                "Register failed | msg=\(errorMessage)",
                error: error,
                timeTakenMs: timeTakenMs,
                user: UserSession.shared.currentUser?.userId
            )
        }
    }

    // MARK: - Error Message Extraction
    /// Extracts the clean error message from APIError
    /// For .custom errors, returns the message directly from the server
    /// For other errors, returns the full localized description
    private func extractErrorMessage(from error: APIError) -> String {
        switch error {
        case .custom(let message):
            // Server sent a custom message - show it directly without any prefix
            return message
            
        case .badRequest(let message):
            // Show bad request message directly
            return message
            
        case .serverError(_, let message):
            // Show server error message directly
            return message
            
        case .networkError(let message):
            // Show network error message directly
            return message
            
        case .decodingError(let message):
            // Show decoding error message directly
            return message
            
        default:
            // For other cases (unauthorized, forbidden, etc.), use localizedDescription
            return error.localizedDescription
        }
    }
    // MARK: - Helpers
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    private func normalizeToE164India(_ raw: String) -> String {
        // Keep digits only
        let digits = raw.filter(\.isNumber)

        // If user already typed country code like 91XXXXXXXXXX
        if digits.count == 12, digits.hasPrefix("91") {
            return "+" + digits
        }

        // If user typed 10-digit Indian mobile number
        if digits.count == 10 {
            return "+91" + digits
        }

        // Fallback: if user typed +<cc>... in the UI, keep it (strip spaces/dashes)
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("+") {
            let afterPlusDigits = trimmed.dropFirst().filter(\.isNumber)
            return "+" + afterPlusDigits
        }

        // Otherwise return digits (or throw/validate)
        return digits
    }

}

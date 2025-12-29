import Foundation
import Combine
import UIKit

final class RegisterUserViewModel: ObservableObject {

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

    private let repository: RegisterUserRepository

    // MARK: - Init
    init(cryptoService: CryptoService) {
        self.repository = RegisterUserRepository(cryptoService: cryptoService)
        self.deviceId = DeviceIdentity.resolve()
        self.deviceName = UIDevice.current.model
    }

    // MARK: - Validation
    var allFieldsFilled: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !email.isEmpty &&
        !phoneNumber.isEmpty
    }

    var isValidEmail: Bool {
        NSPredicate(
            format: "SELF MATCHES %@",
            "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        ).evaluate(with: email)
    }

    var canSubmit: Bool { allFieldsFilled && isValidEmail }

    // MARK: - Register
    func registerUser() {
        let tag = "REGISTER_USER"
        let preAuthUser = "PRE_AUTH"

        guard canSubmit else {
            #if DEBUG
            print("❌ [RegisterUserVM] Validation failed: canSubmit=false")
            #endif
            Logger.shared.e(tag, "Validation failed (canSubmit=false)", user: preAuthUser)
            showErrorMessage("Please fill all fields correctly.")
            return
        }

        guard !deviceId.isEmpty else {
            #if DEBUG
            print("❌ [RegisterUserVM] Missing deviceId")
            #endif
            Logger.shared.e(tag, "Missing deviceId", user: preAuthUser)
            showErrorMessage("Device identifier unavailable.")
            return
        }

        isLoading = true
        errorMessage = nil
        showError = false

        Logger.shared.i(tag, "Register start", user: preAuthUser)
        let startTime = CFAbsoluteTimeGetCurrent()

        repository.registerUser(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: phoneNumber,
            deviceId: deviceId,
            deviceName: deviceName
        ) { [weak self] result in
            guard let self else { return }

            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)

            DispatchQueue.main.async {
                self.isLoading = false
                self.handleRegistrationResult(result, elapsedMs: elapsedMs)
            }
        }
    }

    // MARK: - Result Handling
    private func handleRegistrationResult(
        _ result: Result<APIResponse<RegisterUserData>, APIError>,
        elapsedMs: Int64
    ) {
        let tag = "REGISTER_USER"
        let preAuthUser = "PRE_AUTH"

        switch result {
        case .success(let response):
            guard
                let userData = response.data?.newUser,
                let device = response.data?.newDevice
            else {
                #if DEBUG
                print("❌ [RegisterUserVM] Invalid server response (missing newUser/newDevice)")
                #endif
                Logger.shared.e(tag, "Invalid server response (missing newUser/newDevice)", timeTakenMs: elapsedMs, user: preAuthUser)
                showErrorMessage("Invalid server response.")
                return
            }

            let user = User(
                firstName: firstName,
                lastName: lastName,
                email: email,
                phoneNumber: phoneNumber,
                deviceKey: device.deviceKey,
                deviceName: device.deviceName,
                userId: userData.id,
                userDeviceId: device.id
            )

            UserDefaults.standard.set(device.token, forKey: "token")
            UserDefaults.standard.set("user", forKey: "accountType")

            UserSession.shared.saveUser(user)
            UserSession.shared.setCurrentDeviceID(device.id)
            UserSession.shared.setThisDevicePrimary(device.isPrimary)
            UserSession.shared.setUserWallet(userData.wallet)
            UserSession.shared.setEmailVerified(userData.emailVerified)
            UserSession.shared.setProfilePicture(userData.profilePic ?? "")

            Logger.shared.i(
                tag,
                "Register success | userId=\(userData.id) | deviceId=\(device.id) | isPrimary=\(device.isPrimary)",
                timeTakenMs: elapsedMs,
                user: userData.id
            )

            #if DEBUG
            print("✅ [RegisterUserVM] Registration success userId=\(userData.id) deviceId=\(device.id)")
            #endif

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.navigateToMainTab = true
            }

        case .failure(let error):
            #if DEBUG
            print("❌ [RegisterUserVM] Registration failed: \(error.localizedDescription)")
            #endif

            Logger.shared.e(
                tag,
                "Register failed | msg=\(error.localizedDescription)",
                error: error,
                timeTakenMs: elapsedMs,
                user: preAuthUser
            )

            showErrorMessage(error.localizedDescription)
        }
    }

    // MARK: - Helpers
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
}

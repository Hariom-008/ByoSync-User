import Foundation
import SwiftUI
import Combine

final class UpdateProfileViewModel: ObservableObject {
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var email: String = ""
    @Published var alertTitle: String = ""
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var isLoading: Bool = false
    @Published var isSuccess: Bool = false
    
    // 👇 Store original email to detect change
    private var originalEmail: String = UserSession.shared.currentUser?.email ?? ""
    
    func updateProfile() {
        print("\n" + String(repeating: "=", count: 50))
        print("🧪 Starting Updating UserProfile")
        print(String(repeating: "=", count: 50))
        
        guard let token = UserDefaults.standard.string(forKey: "token") else {
            print("❌ NO TOKEN FOUND - API will fail!")
            alertTitle = "Error"
            alertMessage = "No token found. Please login first."
            showAlert = true
            return
        }
        
        print("✅ Token found: \(token.prefix(20))...")
        isLoading = true
        
        ProfileUpdateRepository.shared.updateProfile(
            firstName: firstName,
            lastName: lastName,
            email: email
        ) { result in
            DispatchQueue.main.async { [self] in
                switch result {
                case .success(let response):
                    print("✅ UPDATE SUCCESS!")
                    print("Status Code: \(response.statusCode)")
                    print("Message: \(response.message)")
                    print("User: \(response.data.firstName) \(response.data.lastName)")
                    print("Email: \(response.data.email)")
                    
                    // ✅ Check if email actually changed
                    let oldEmail = originalEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let newEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    
                    if oldEmail != newEmail {
                        UserSession.shared.setEmailVerified(false)
                        print("📧 Email changed — verification reset to false")
                    }
                    
                    self.alertTitle = "Success ✅"
                    self.alertMessage = """
                       \(response.message)
                       Updated Profile:
                       Name: \(response.data.firstName) \(response.data.lastName)
                       Email: \(response.data.email)
                       """
                    self.showAlert = true
                    self.isSuccess = true
                    
                    // ✅ Update user session
                    UserSession.shared.saveUser(
                        User(
                            firstName: firstName,
                            lastName: lastName,
                            email: email,
                            phoneNumber: UserSession.shared.currentUser?.phoneNumber,
                            deviceId: UserSession.shared.currentUser?.deviceId,
                            deviceName: UserSession.shared.currentUser?.deviceName
                        )
                    )
                    print("✅ Updated the user on backend and UserSession.")
                    
                case .failure(let error):
                    print("❌ UPDATE FAILED!")
                    print("Error: \(error.localizedDescription)")
                    
                    self.alertTitle = "Error ❌"
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                }
                
                self.isLoading = false
            }
        }
    }
}

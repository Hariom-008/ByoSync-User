//import SwiftUI
//import Firebase
//import FirebaseAuth
//import FirebaseMessaging  // Add this import
//
//struct InitialView: View{
//    @State private var userLoggedIn = (Auth.auth().currentUser != nil)
//    var body: some View {
//        VStack{
//            if userLoggedIn{
//                RootView()
//            } else {
//              ContentView()
//            }
//        }
//        .onAppear{
//            Auth.auth().addStateDidChangeListener{auth, user in
//                if (user != nil) {
//                    print("✅ User logged in: \(user?.uid ?? "Unknown")")
//                    userLoggedIn = true
//                } else{
//                    print("❌ No user logged in")
//                    userLoggedIn = false
//                }
//            }
//        }
//    }
//}
//
//import SwiftUI
//import Firebase
//import FirebaseAuth
//import FirebaseMessaging  // Add this import
//
//struct ContentView: View {
//    @State private var phoneNumber: String = ""
//    @State private var verificationID: String?
//    @State private var verificationCode: String = ""
//    @State private var isVerificationSent: Bool = false
//    @State private var isAuthenticated: Bool = false
//    @State private var errorMessage: String?
//    @State private var detailedErrorLog: String = ""
//    
//    var body: some View {
//        VStack {
//            if isAuthenticated {
//               RootView()
//                
//            } else {
//                ScrollView {
//                    VStack(spacing: 20) {
//                        if !isVerificationSent {
//                            TextField("Phone number", text: $phoneNumber)
//                                .textFieldStyle(RoundedBorderTextFieldStyle())
//                                .padding()
//                                .keyboardType(.phonePad)
//                            
//                            Button(action: sendVerificationCode) {
//                                Text("Send Verification Code")
//                                    .padding()
//                                    .background(Color.blue)
//                                    .foregroundColor(.white)
//                                    .cornerRadius(8)
//                            }
//                            .padding()
//                            
//                            if let errorMessage = errorMessage {
//                                Text(errorMessage)
//                                    .foregroundColor(.red)
//                                    .padding()
//                            }
//                        } else {
//                            TextField("Verification code", text: $verificationCode)
//                                .textFieldStyle(RoundedBorderTextFieldStyle())
//                                .padding()
//                            
//                            Button(action: verifyCode) {
//                                Text("Verify Code")
//                                    .padding()
//                                    .background(Color.blue)
//                                    .foregroundColor(.white)
//                                    .cornerRadius(8)
//                            }
//                            .padding()
//                            
//                            if let errorMessage = errorMessage {
//                                Text(errorMessage)
//                                    .foregroundColor(.red)
//                                    .padding()
//                            }
//                        }
//                        
//                        // Detailed error logs display
//                        if !detailedErrorLog.isEmpty {
//                            VStack(alignment: .leading, spacing: 8) {
//                                Text("Detailed Error Log:")
//                                    .font(.headline)
//                                    .foregroundColor(.orange)
//                                
//                                Text(detailedErrorLog)
//                                    .font(.system(size: 12, design: .monospaced))
//                                    .foregroundColor(.red)
//                                    .padding()
//                                    .background(Color.black.opacity(0.1))
//                                    .cornerRadius(8)
//                            }
//                            .padding()
//                        }
//                    }
//                }
//            }
//        }
//        .padding()
//    }
//    
//    private func sendVerificationCode() {
//        let phoneNumber = self.phoneNumber
//        let phoneNumberWithCountryCode = "+91\(phoneNumber)"
//        
//        print("📱 Attempting to send verification code to: \(phoneNumberWithCountryCode)")
//        
//        PhoneAuthProvider.provider()
//            .verifyPhoneNumber(phoneNumberWithCountryCode, uiDelegate: nil) { (verificationID, error) in
//                if let error = error {
//                    let nsError = error as NSError
//                    
//                    // Detailed error logging
//                    print("❌ ERROR SENDING VERIFICATION CODE")
//                    print("Error Code: \(nsError.code)")
//                    print("Error Domain: \(nsError.domain)")
//                    print("Error Description: \(error.localizedDescription)")
//                    print("Error UserInfo: \(nsError.userInfo)")
//                    
//                    // Check for specific Firebase Auth error codes
//                    if let errorCode = AuthErrorCode(rawValue: nsError.code) {
//                        print("Firebase Auth Error Code: \(errorCode)")
//                        
//                        switch errorCode {
//                        case .invalidPhoneNumber:
//                            self.errorMessage = "Invalid phone number format"
//                        case .missingPhoneNumber:
//                            self.errorMessage = "Phone number is missing"
//                        case .quotaExceeded:
//                            self.errorMessage = "SMS quota exceeded. Try again later."
//                        case .captchaCheckFailed:
//                            self.errorMessage = "reCAPTCHA verification failed"
//                        case .invalidAppCredential:
//                            self.errorMessage = "Invalid APNs token or credentials"
//                        case .missingAppCredential:
//                            self.errorMessage = "Missing APNs configuration"
//                        case .internalError:
//                            self.errorMessage = "Internal Firebase error. Check your configuration."
//                        case .networkError:
//                            self.errorMessage = "Network error. Check your internet connection."
//                        default:
//                            self.errorMessage = "Error: \(error.localizedDescription)"
//                        }
//                    } else {
//                        self.errorMessage = "Error: \(error.localizedDescription)"
//                    }
//                    
//                    // Set detailed log for screen display
//                    self.detailedErrorLog = """
//                    Code: \(nsError.code)
//                    Domain: \(nsError.domain)
//                    Description: \(error.localizedDescription)
//                    UserInfo: \(nsError.userInfo)
//                    """
//                    
//                    return
//                }
//                
//                print("✅ Verification code sent successfully")
//                print("Verification ID: \(verificationID ?? "nil")")
//                
//                self.verificationID = verificationID
//                self.isVerificationSent = true
//                self.errorMessage = nil
//                self.detailedErrorLog = ""
//            }
//    }
//    
//    private func verifyCode() {
//        guard let verificationID = self.verificationID else {
//            self.errorMessage = "Verification ID is missing."
//            print("❌ Verification ID is missing")
//            return
//        }
//        
//        print("🔐 Attempting to verify code: \(verificationCode)")
//        
//        let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: verificationCode)
//        
//        Auth.auth().signIn(with: credential) { (authResult, error) in
//            if let error = error {
//                let nsError = error as NSError
//                
//                // Detailed error logging
//                print("❌ ERROR VERIFYING CODE")
//                print("Error Code: \(nsError.code)")
//                print("Error Domain: \(nsError.domain)")
//                print("Error Description: \(error.localizedDescription)")
//                print("Error UserInfo: \(nsError.userInfo)")
//                
//                // Check for specific error codes
//                if let errorCode = AuthErrorCode(rawValue: nsError.code) {
//                    print("Firebase Auth Error Code: \(errorCode)")
//                    
//                    switch errorCode {
//                    case .invalidVerificationCode:
//                        self.errorMessage = "Invalid verification code"
//                    case .sessionExpired:
//                        self.errorMessage = "Verification code expired. Request a new one."
//                    case .invalidVerificationID:
//                        self.errorMessage = "Invalid verification ID"
//                    default:
//                        self.errorMessage = "Error: \(error.localizedDescription)"
//                    }
//                } else {
//                    self.errorMessage = "Error: \(error.localizedDescription)"
//                }
//                
//                // Set detailed log for screen display
//                self.detailedErrorLog = """
//                Code: \(nsError.code)
//                Domain: \(nsError.domain)
//                Description: \(error.localizedDescription)
//                UserInfo: \(nsError.userInfo)
//                """
//                
//                return
//            }
//            
//            print("✅ User signed in successfully")
//            print("User ID: \(authResult?.user.uid ?? "Unknown")")
//            
//            // ✅ Generate and save FCM Token after successful authentication
//            self.generateAndSaveFCMToken()
//            
//            self.isAuthenticated = true
//            self.errorMessage = nil
//            self.detailedErrorLog = ""
//        }
//    }
//    
//    // MARK: - Generate and Save FCM Token
//    private func generateAndSaveFCMToken() {
//        print("🔑 Generating FCM Token...")
//        
//        Messaging.messaging().token { token, error in
//            if let error = error {
//                print("❌ Error fetching FCM token: \(error.localizedDescription)")
//                return
//            }
//            
//            guard let fcmToken = token else {
//                print("❌ FCM Token is nil")
//                return
//            }
//            
//            print("✅ FCM Token generated: \(fcmToken)")
//            
//            // Save to UserDefaults
//            UserDefaults.standard.set(fcmToken, forKey: "fcmToken")
//            UserDefaults.standard.synchronize()
//            
//            print("💾 FCM Token saved to UserDefaults")
//        }
//    }
//}
//
//#Preview {
//    ContentView()
//}

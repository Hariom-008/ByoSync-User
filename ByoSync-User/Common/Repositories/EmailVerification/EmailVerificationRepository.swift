import Foundation
import Alamofire

// Email Verify and Send Repository
final class EmailVerificationRepository {
    
    static let shared = EmailVerificationRepository()
    private init() {}
    
    // MARK: - Send Email OTP
    func sendEmailOTP(
        completion: @escaping (Result<APIResponse<EmptyData>, APIError>) -> Void
    ) {
        let headers = getHeader.shared.getAuthHeaders()
        
        print("📤 Sending Email OTP:")
        print("URL: \(UserAPIEndpoint.Auth.sendEmail)")
        
        APIClient.shared.request(
            UserAPIEndpoint.Auth.sendEmail,
            method: .post,
            headers: headers
        ) { (result: Result<APIResponse<EmptyData>, APIError>) in
            switch result {
            case .success(let response):
                if response.success ?? false {
                    print("✅ Email OTP sent successfully: \(response.message)")
                    completion(.success(response))
                } else {
                    print("❌ Failed to send OTP: \(response.message)")
                    completion(.failure(.custom(response.message)))
                }
            case .failure(let error):
                print("❌ API failure sending email OTP: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Verify Email OTP
    func verifyEmailOTP(
        otp: String,
        completion: @escaping (Result<APIResponse<EmptyData>, APIError>) -> Void
    ) {
        let parameters: [String: Any] = ["otp": otp]
        let headers = getHeader.shared.getAuthHeaders()
        
        print("📤 Verifying Email OTP:")
        print("URL: \(UserAPIEndpoint.Auth.emailOtpVerification)")
        print("OTP: \(otp)")
        
        APIClient.shared.request(
            UserAPIEndpoint.Auth.emailOtpVerification,
            method: .post,
            parameters: parameters,
            headers: headers
        ) { (result: Result<APIResponse<EmptyData>, APIError>) in
            switch result {
            case .success(let response):
                if response.success ?? false {
                    print("✅ Email OTP verified successfully: \(response.message)")
                    
                    if let currentUser = UserSession.shared.currentUser {
                        print("✅ Email verified for user: \(currentUser.email)")
                    }
                    completion(.success(response))
                } else {
                    print("❌ OTP verification failed: \(response.message)")
                    completion(.failure(.custom(response.message)))
                }
                
            case .failure(let error):
                print("❌ Network or decoding error verifying OTP: \(error)")
                completion(.failure(error))
            }
        }
    }
}

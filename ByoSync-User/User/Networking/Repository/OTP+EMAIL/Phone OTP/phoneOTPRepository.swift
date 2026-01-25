import Foundation
import Alamofire

final class OTPRepository {
    static let shared = OTPRepository()
    
    private init() {}
    
    func sendPhoneOTP(
        phoneNumber: String,
        completion: @escaping (Result<PhoneOTPResponse, APIError>) -> Void
    ) {
        print("📤 SENDING OTP REQUEST (BACKEND)")
        print("📱 Phone Number: '\(phoneNumber)'")
        print("📏 Length: \(phoneNumber.count)")
        print("🌐 Endpoint: \(UserAPIEndpoint.Auth.phoneOTP)")
        
        let payload: Parameters = [
            "number": phoneNumber
        ]
        
        print("📦 Payload: \(payload)")
        
        APIClient.shared.request(
            UserAPIEndpoint.Auth.phoneOTP,
            method: .post,
            parameters: payload
        ) { (result: Result<PhoneOTPResponse, APIError>) in
            switch result {
            case .success(let response):
                print("✅ OTP SENT SUCCESSFULLY (BACKEND)")
                print("📥 RESPONSE RECEIVED:")
                print("📊 statusCode: \(response.statusCode ?? 0)")
                print("✔️  success: \(response.success)")
                print("💬 message: \"\(response.message)\"")
                
                if let data = response.data {
                    print("📦 data: {")
                    if let otp = data.otp {
                        print("    🔐 otp: \"\(otp)\"")
                    }
                    if let phoneNumber = data.phoneNumber {
                        print("    📱 phoneNumber: \"\(phoneNumber)\"")
                    }
                    if let otpSentAt = data.otpSentAt {
                        print("    🕐 otpSentAt: \"\(otpSentAt)\"")
                    }
                    if let expiresIn = data.expiresIn {
                        print("    ⏰ expiresIn: \(expiresIn) seconds")
                    }
                    print("}")
                } else {
                    print("📦 data: null")
                }
                print("🎯 FORMATTED RESPONSE:")
                self.printFormattedJSON(response)
                
                completion(.success(response))
                
            case .failure(let error):
                print("❌ OTP SEND FAILED (BACKEND)")
                print("🔴 Error: \(error.localizedDescription)")
                print("💬 Error Message: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Verify OTP (Backend)
    func verifyOTP(
        phoneNumber: String,
        otp: String,
        completion: @escaping (Result<VerifyOTPResponse, APIError>) -> Void
    ) {
        
        print("📤 VERIFYING OTP REQUEST (BACKEND)")
        print("📱 Phone Number: '\(phoneNumber)'")
        print("🔐 OTP: \(otp)")
        print("🌐 Endpoint: \(UserAPIEndpoint.Auth.verifyOTP)")
        
        let payload: Parameters = [
            "number": phoneNumber,
            "otp": otp
        ]
        
        print("📦 Payload: \(payload)")
        
        APIClient.shared.request(
            UserAPIEndpoint.Auth.verifyOTP,
            method: .post,
            parameters: payload
        ) { (result: Result<VerifyOTPResponse, APIError>) in
            switch result {
            case .success(let response):
                print("✅ OTP VERIFIED SUCCESSFULLY (BACKEND)")
                print("📊 statusCode: \(response.statusCode ?? 0)")
                print("✔️  success: \(response.success)")
                print("💬 message: \"\(response.message)\"")
                
                if let data = response.data {
                    print("📦 data: {")
                    if let token = data.token {
                        print("    🎫 token: \"\(token.prefix(20))...\" (truncated)")
                    }
                    if let refreshToken = data.refreshToken {
                        print("    🔄 refreshToken: \"\(refreshToken.prefix(20))...\" (truncated)")
                    }
                    if let isNewUser = data.isNewUser {
                        print("    👤 isNewUser: \(isNewUser)")
                    }
                    print("}")
                } else {
                    print("📦 data: null")
                }
                print("🎯 FORMATTED RESPONSE:")
                self.printFormattedJSON(response)
                
                completion(.success(response))
                
            case .failure(let error):
                print("❌ OTP VERIFICATION FAILED (BACKEND)")
                print("🔴 Error: \(error.localizedDescription)")
                print("💬 Error Message: \(error.localizedDescription)")
                
                completion(.failure(error))
            }
        }
    }
    func resendOTP(
        phoneNumber: String,
        completion: @escaping (Result<PhoneOTPResponse, APIError>) -> Void
    ) {
        print("🔄 RESENDING OTP (BACKEND)")
        sendPhoneOTP(phoneNumber: phoneNumber, completion: completion)
    }
    
    private func printFormattedJSON<T: Encodable>(_ object: T) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        if let jsonData = try? encoder.encode(object),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        } else {
            print("Unable to format JSON")
        }
    }
}

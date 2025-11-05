import SwiftUI

struct OTPVerificationView: View {
    @State var phoneNumber: String
    @ObservedObject var viewModel: PhoneOTPViewModel
    
    @State private var otpCode: [String] = ["", "", "", "", "", ""]
    @State private var isVerifying = false
    @State private var verificationError: String?
    @State private var showError = false
    @State private var navigateToRegister = false
    @FocusState private var focusedField: Int?
    @State var hasError : Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Enter verification code")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("We sent a code to")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(formatDisplayPhoneNumber(phoneNumber))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.indigo)
            }
            .padding(.top, 60)
            .padding(.bottom, 40)
            
            // OTP Input Fields
            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { index in
                    CodeDigitField(
                        text: $otpCode[index],
                        isFocused: focusedField == index,
                        hasError: hasError
                    )
                    .focused($focusedField, equals: index)
                    .onChange(of: otpCode[index]) { oldValue, newValue in
                        handleOTPChange(at: index, oldValue: oldValue, newValue: newValue)
                    }
                }
            }
            .padding(.horizontal, 24)
            
            // Error message
            if let error = verificationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 12)
            }
            
            // Resend Code
            HStack(spacing: 4) {
                Text("Didn't receive the code?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if viewModel.canResend {
                    Button("Resend") {
                        viewModel.resendOTP()
                        clearOTP()
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.indigo)
                } else {
                    Text("Resend in \(viewModel.resendCountdown)s")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 24)
            
            Spacer()
            
            // Verify Button
            Button(action: verifyOTP) {
                HStack(spacing: 8) {
                    if isVerifying {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Verify")
                            .font(.headline)
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isOTPComplete && !isVerifying ? Color.indigo : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!isOTPComplete || isVerifying)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            
            // Back to edit number
            Button(action: { dismiss() }) {
                Text("Change phone number")
                    .font(.subheadline)
                    .foregroundColor(.indigo)
            }
            .padding(.bottom, 40)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                hasError = false
            }
        } message: {
            if let error = verificationError {
                Text(error)
            }
        }
        .navigationDestination(isPresented: $navigateToRegister) {
            RegisterUserView(phoneNumber: $phoneNumber)
        }
        .onAppear {
            focusedField = 0
        }
    }
    
    // MARK: - Computed Properties
    private var isOTPComplete: Bool {
        otpCode.allSatisfy { !$0.isEmpty }
    }
    
    private var otpString: String {
        otpCode.joined()
    }
    
    // MARK: - Methods
    private func handleOTPChange(at index: Int, oldValue: String, newValue: String) {
        // Only allow single digit
        if newValue.count > 1 {
            otpCode[index] = String(newValue.last ?? Character(""))
        }
        
        // Move to next field if digit entered
        if !newValue.isEmpty && index < 5 {
            focusedField = index + 1
        }
        
        // Auto-verify when all digits entered
        if isOTPComplete {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                verifyOTP()
            }
        }
    }
    
    private func verifyOTP() {
        guard isOTPComplete else { return }
        
        isVerifying = true
        verificationError = nil
        hasError = false
        
        print("🔐 Starting OTP verification...")
        print("📱 Phone Number: \(phoneNumber)")
        print("🔢 OTP: \(otpString)")
        
        // phoneNumber is already in format +916XXXXXXXXX
        OTPRepository.shared.verifyOTP(
            phoneNumber: phoneNumber,
            otp: otpString
        ) { [self] result in
            DispatchQueue.main.async {
                isVerifying = false
                
                switch result {
                case .success(let response):
                    print("✅ OTP Verification Response: \(response)")
                    handleVerificationSuccess(response)
                    
                case .failure(let error):
                    print("❌ OTP Verification Error: \(error.localizedDescription)")
                    verificationError = error.localizedDescription
                    hasError = true
                    showError = true
                    clearOTP()
                }
            }
        }
    }
    
    private func handleVerificationSuccess(_ response: VerifyOTPResponse) {
        if response.success {
            print("✅ OTP verified successfully, navigating to registration...")
            navigateToRegister = true
        } else {
            print("❌ Verification failed: \(response.message)")
            verificationError = response.message
            hasError = true
            showError = true
            clearOTP()
        }
    }
    
    private func clearOTP() {
        otpCode = ["", "", "", "", "", ""]
        focusedField = 0
    }
    
    // Format phone number for display: +916234567890 -> +91 6234 567 890
    private func formatDisplayPhoneNumber(_ number: String) -> String {
        // Remove +91 prefix
        let digitsOnly = number.replacingOccurrences(of: "+91", with: "")
        
        // Format as: +91 XXXX XXX XXX
        var formatted = "+91 "
        let digits = Array(digitsOnly)
        
        for (index, digit) in digits.enumerated() {
            if index == 4 || index == 7 {
                formatted += " "
            }
            formatted.append(digit)
        }
        
        return formatted
    }
}

#Preview {
    NavigationStack {
        OTPVerificationView(
            phoneNumber: "+916234567890",
            viewModel: PhoneOTPViewModel()
        )
    }
}

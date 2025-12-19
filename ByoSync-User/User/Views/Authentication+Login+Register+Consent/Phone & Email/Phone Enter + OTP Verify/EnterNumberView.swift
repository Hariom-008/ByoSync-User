import SwiftUI

struct EnterNumberView: View {
    @StateObject private var viewModel = PhoneOTPViewModel()
    @EnvironmentObject var router: Router
    @FocusState private var isPhoneFieldFocused: Bool

    let countryCodes = ["+91"]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Enter your phone number")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("We'll send you a verification code via SMS")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 60)
                .padding(.bottom, 40)

                // Phone Number Input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Phone Number")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        // Country Code Picker
                        Menu {
                            ForEach(countryCodes, id: \.self) { code in
                                Button {
                                    viewModel.selectedCountryCode = code
                                } label: {
                                    HStack {
                                        Text(code)
                                        if viewModel.selectedCountryCode == code {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(viewModel.selectedCountryCode)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }

                        // Phone Number Field
                        TextField("6234567890", text: $viewModel.phoneNumber)
                            .keyboardType(.phonePad)
                            .focused($isPhoneFieldFocused)
                            .font(.body)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .onChange(of: viewModel.phoneNumber) { _, newValue in
                                // Keep digits only + max 10
                                let filtered = newValue.filter { $0.isNumber }
                                let clipped = String(filtered.prefix(10))
                                if viewModel.phoneNumber != clipped {
                                    viewModel.phoneNumber = clipped
                                }
                                viewModel.updatePhoneNumber(clipped)
                            }
                    }

                    Text("Enter 10 digit mobile number starting with 6-9")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Continue Button
                Button {
                    isPhoneFieldFocused = false
                    viewModel.sendOTP() // ✅ Firebase
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Continue")
                                .font(.headline)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        viewModel.isValidPhoneNumber && !viewModel.isLoading
                        ? Color.indigo
                        : Color.gray
                    )
                    .cornerRadius(12)
                }
                .disabled(!viewModel.isValidPhoneNumber || viewModel.isLoading)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .onTapGesture { isPhoneFieldFocused = false }

            if viewModel.isLoading {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { router.pop() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong.")
        }
        .onChange(of: viewModel.otpSent) { _, sent in
            guard sent else { return }

            router.navigate(
                to: .otpVerification(
                    phoneNumber: viewModel.fullPhoneNumber,
                    viewModel: viewModel
                ),
                style: .push
            )
        }
    }
}

#Preview {
    EnterNumberView()
}

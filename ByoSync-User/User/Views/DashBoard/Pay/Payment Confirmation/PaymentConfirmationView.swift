import SwiftUI

struct PaymentConfirmationView: View {
    @State private var isProcessing = false
    @State private var navigateToRecieptView = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) var dismiss
    @Binding var hideTabBar: Bool
    @Binding var selectedUser: UserData

    @StateObject private var createOrderVM = CreateOrderViewModel()

    let amount: String

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "4B548D"), Color(hex: "3A4270")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection

                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.white)
                        .ignoresSafeArea(edges: .bottom)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 28) {
                            paymentDetailsSection
                            termsSection
                            actionButtonsSection
                                .padding(.top, 12)
                                .padding(.bottom, 20)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 40)
                    }
                }
            }

            if isProcessing { processingOverlay }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToRecieptView) {
            ReceiptView(
                hideTabBar: $hideTabBar,
                selectedUser: $selectedUser,
                orderId: $createOrderVM.orderId,
                amount: Int(amount) ?? 0
            )
        }
        .alert("Payment Failed", isPresented: $showErrorAlert) {
            Button("Retry") {
                handleConfirmPayment()
            }
            Button("Cancel", role: .cancel) {
                dismiss()
                hideTabBar = false
            }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            hideTabBar = true
            print("DEBUG: PaymentConfirmationView appeared")
            print("DEBUG: Selected user - \(selectedUser.firstName) \(selectedUser.lastName)")
            print("DEBUG: Amount - \(amount)")
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack {
            Button(action: {
                print("DEBUG: Dismiss payment confirmation")
                dismiss()
                hideTabBar = false
            }) {
                Image(systemName: String(localized: "icon.xmark"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text(String(localized: "payment_confirmation.title"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Payment Details
    private var paymentDetailsSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text(String(localized: "payment_confirmation.amount_to_pay"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)

                Text("\(String(localized: "common.currency_symbol"))\(amount)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.08))
            )

            VStack(spacing: 16) {
                detailRow(
                    label: String(localized: "payment_confirmation.pay_to"),
                    value: "\(selectedUser.firstName) \(selectedUser.lastName)",
                    icon: String(localized: "icon.person_fill")
                )
                Divider().padding(.vertical, 4)
                detailRow(
                    label: String(localized: "payment_confirmation.upi_id"),
                    value: selectedUser.email,
                    icon: "at"
                )
                Divider().padding(.vertical, 4)
                detailRow(
                    label: String(localized: "payment_confirmation.date_time"),
                    value: formattedDateTime,
                    icon: String(localized: "icon.calendar")
                )
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: - Terms Section
    private var termsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: String(localized: "icon.shield_fill"))
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "4CAF50"))
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "payment_confirmation.secure_payment"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(String(localized: "payment_confirmation.payment_encrypted"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(16)
            .background(Color(hex: "4CAF50").opacity(0.08))
            .cornerRadius(12)
        }
    }

    // MARK: - Processing Overlay
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 3)
                        .frame(width: 80, height: 80)
                    ProgressView()
                        .scaleEffect(1.8)
                        .tint(.white)
                }
                VStack(spacing: 8) {
                    Text(String(localized: "payment_confirmation.processing"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text(String(localized: "payment_confirmation.verifying_faceid"))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "4B548D"))
            )
        }
        .transition(.opacity)
    }

    // MARK: - Helper
    private func detailRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
            Spacer()
        }
    }

    private var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = String(localized: "date.format.month_day_time")
        return formatter.string(from: Date())
    }

    // MARK: - Confirm Action
    private func handleConfirmPayment() {
        print("DEBUG: Confirm payment button pressed")
        print("DEBUG: Receiver ID - \(selectedUser.id)")
        
        let senderId = UserDefaults.standard.string(forKey: "user_id") ?? ""
        let senderDeviceId = UserDefaults.standard.string(forKey: "device_id") ?? ""
        
        print("DEBUG: Sender ID - \(senderId)")
        print("DEBUG: Sender Device ID - \(senderDeviceId)")
        print("DEBUG: Amount - \(amount)")

        isProcessing = true
        Task {
            do {
                let order = try await createOrderVM.createOrder(
                    receiverId: selectedUser.id,
                    amount: Int(amount) ?? 0
                )
                
              //  print("✅ Order Created Successfully: \(order.orderId)")
                
                // Only navigate on success
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isProcessing = false
                    }
                    // Small delay for smooth transition
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        navigateToRecieptView = true
                    }
                }
            } catch {
                print("❌ Order Creation Failed: \(error.localizedDescription)")
                
                // Handle different error types
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isProcessing = false
                    }
                    
                    // Set appropriate error message based on error type
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .notConnectedToInternet:
                            errorMessage = "No internet connection. Please check your network and try again."
                        case .timedOut:
                            errorMessage = "Request timed out. Please try again."
                        default:
                            errorMessage = "Network error occurred. Please try again."
                        }
                    } else if error.localizedDescription.contains("insufficient") {
                        errorMessage = "Insufficient balance. Please add funds to your account."
                    } else if error.localizedDescription.contains("Invalid") {
                        errorMessage = "Invalid payment details. Please check and try again."
                    } else {
                        errorMessage = "Payment failed: \(error.localizedDescription)"
                    }
                    
                    showErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Buttons
extension PaymentConfirmationView {
    var actionButtonsSection: some View {
        VStack(spacing: 14) {
            Button(action: handleConfirmPayment) {
                Label(String(localized: "payment_confirmation.confirm_payment"),
                      systemImage: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(.white)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "4B548D"), Color(hex: "5E68A6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: Color(hex: "4B548D").opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .disabled(isProcessing)

            Button(action: {
                print("DEBUG: Cancel payment button pressed")
                dismiss()
                hideTabBar = false
            }) {
                Label(String(localized: "payment_confirmation.cancel_payment"),
                      systemImage: "xmark.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .foregroundColor(.red)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1.5)
                    )
            }
            .disabled(isProcessing)
        }
    }
}

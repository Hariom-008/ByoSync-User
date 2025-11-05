import SwiftUI

struct PaymentConfirmationView: View {
    @State private var isProcessing = false
    @State private var showSuccess = false
    @State private var navigateToUPI = false
    @Environment(\.dismiss) var dismiss
    @Binding var hideTabBar: Bool

    let amount: String
    let merchantName: String = String(localized: "enter_amount.merchant")
    let upiID: String = String(localized: "common.receiver_upi")

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
                // Header
                headerSection

                // Main card
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.white)
                        .ignoresSafeArea(edges: .bottom)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 28) {
                            biometricPromptSection
                                .padding(.top, 40)

                            paymentDetailsSection
                            termsSection
                            actionButtonsSection
                                .padding(.top, 12)
                                .padding(.bottom, 20)
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }

            // Processing overlay
            if isProcessing { processingOverlay }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToUPI) {
            ChooseUPIAppView(hideTabBar: $hideTabBar, amount: amount)
        }
        .onAppear { hideTabBar = true }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack {
            Button(action: {
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

    // MARK: - Biometric Prompt
    private var biometricPromptSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: "4B548D").opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: String(localized: "icon.faceid"))
                    .font(.system(size: 50))
                    .foregroundColor(Color(hex: "4B548D"))
            }

            VStack(spacing: 8) {
                Text(String(localized: "payment_confirmation.verify_faceid"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)

                Text(String(localized: "payment_confirmation.authenticate_message"))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
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
                    value: merchantName,
                    icon: String(localized: "icon.person_fill")
                )

                Divider().padding(.vertical, 4)

                detailRow(
                    label: String(localized: "payment_confirmation.upi_id"),
                    value: upiID,
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

            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                Text(String(localized: "payment_confirmation.agree_terms"))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
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

    private func handleConfirmPayment() {
        isProcessing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.3)) { isProcessing = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                navigateToUPI = true
            }
        }
    }
}

// MARK: - Action Buttons
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

            Button(action: {
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
        }
    }
}

#Preview {
    PaymentConfirmationView(hideTabBar: .constant(false), amount: "450")
}

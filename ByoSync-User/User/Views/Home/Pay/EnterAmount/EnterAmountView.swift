import SwiftUI
import Combine

struct EnterAmountView: View {
    @State private var amount: String = ""
    @State private var isKeyboardVisible: Bool = false
    @FocusState private var isAmountFocused: Bool
    @Environment(\.dismiss) var dismiss
    @Binding var hideTabBar: Bool

    // MARK: - Validation
    private var isValidAmount: Bool {
        guard let amountValue = Double(amount), amountValue > 0 else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(hex: "F8F9FD"), Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: - Top Navigation
                    HStack {
                        Button(action: {
                            dismiss()
                            hideTabBar = false
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 40, height: 40)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        }
                        Spacer()
                        Text(String(localized: "enter_amount.title"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        Color.clear.frame(width: 40, height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 24)

                    ScrollView {
                        VStack(spacing: 32) {
                            // MARK: - Recipient Info Card
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(hex: "4B548D").opacity(0.1),
                                                    Color(hex: "4B548D").opacity(0.05)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 60, height: 60)

                                    Image("merchant_photo")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 60, height: 60)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 3)
                                        )
                                        .shadow(color: Color(hex: "4B548D").opacity(0.25), radius: 12, x: 0, y: 6)
                                }
                                .padding(.top, 12)

                                VStack(spacing: 6) {
                                    Text(String(localized: "enter_amount.merchant"))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.primary)

                                    HStack(spacing: 4) {
                                        Image(systemName: "phone.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                        Text(String(localized: "common.phone_number"))
                                            .font(.system(size: 15))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                // Status badge
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(hex: "4CAF50"))
                                        .frame(width: 8, height: 8)
                                    Text(String(localized: "enter_amount.ready_to_receive"))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(hex: "4CAF50").opacity(0.1))
                                .clipShape(Capsule())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
                            )
                            .padding(.horizontal, 20)

                            // MARK: - Amount Input Section
                            VStack(spacing: 20) {
                                Text(String(localized: "enter_amount.enter_amount"))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)

                                HStack(spacing: 8) {
                                    Text(String(localized: "common.currency_symbol"))
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(amount.isEmpty ? .gray : Color(hex: "4B548D"))

                                    TextField(String(localized: "enter_amount.amount_placeholder"), text: $amount)
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .keyboardType(.decimalPad)
                                        .foregroundColor(amount.isEmpty ? .gray : .black)
                                        .focused($isAmountFocused)
                                        .lineLimit(1)
                                        .multilineTextAlignment(.center)

                                    if !amount.isEmpty {
                                        Button(action: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                amount = ""
                                            }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.gray.opacity(0.4))
                                        }
                                        .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.white)
                                        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
                                )
                                .padding(.horizontal, 20)

                                // Amount display
                                if !amount.isEmpty, let amountValue = Double(amount) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(hex: "4CAF50"))
                                        Text(String(format: String(localized: "enter_amount.amount_format"), amountValue))
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 20)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            }

                            Spacer(minLength: 20)
                        }
                        .padding(.bottom, 120)
                    }

                    // MARK: - Bottom Action Buttons
                    VStack(spacing: 12) {
                        if isKeyboardVisible {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isAmountFocused = false
                                }
                            }) {
                                Label(String(localized: "enter_amount.hide_keyboard"), systemImage: "keyboard.chevron.compact.down")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .foregroundColor(.white)
                                    .background(Color.gray.opacity(0.6))
                                    .cornerRadius(12)
                            }
                        }

                        if isValidAmount {
                            NavigationLink(destination: PaymentConfirmationView(hideTabBar: $hideTabBar, amount: amount)) {
                                Label(String(localized: "enter_amount.continue_payment"), systemImage: "arrow.right")
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
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isKeyboardVisible)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isValidAmount)
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationBarHidden(true)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isAmountFocused = true
                    hideTabBar = true
                }

                // Keyboard observers
                NotificationCenter.default.addObserver(
                    forName: UIResponder.keyboardWillShowNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    withAnimation(.easeOut(duration: 0.25)) {
                        isKeyboardVisible = true
                    }
                }

                NotificationCenter.default.addObserver(
                    forName: UIResponder.keyboardWillHideNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    withAnimation(.easeOut(duration: 0.25)) {
                        isKeyboardVisible = false
                    }
                }
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
                NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
            }
        }
    }
}

#Preview {
    EnterAmountView(hideTabBar: .constant(false))
}

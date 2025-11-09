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
        guard let amountValue = Int(amount), amountValue > 0 else {
            print("DEBUG: Invalid amount - value: \(amount)")
            return false
        }
        print("DEBUG: Valid amount - value: \(amountValue)")
        return true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Simple background
                Color(hex: "F8F9FD")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: - Top Navigation
                    HStack {
                        Button(action: {
                            print("DEBUG: Dismiss button tapped")
                            dismiss()
                            hideTabBar = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Spacer()

                    // MARK: - Amount Input Section (Centered)
                    VStack(spacing: 24) {
                        Text(String(localized: "enter_amount.enter_amount"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)

                        ZStack{
                            // Amount TextField
                            TextField(String(localized: "enter_amount.amount_placeholder"), text: $amount)
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .keyboardType(.numberPad)
                                .foregroundColor(.primary)
                                .focused($isAmountFocused)
                                .multilineTextAlignment(.center)
                                .frame(height: 80)
                                .padding(.horizontal, 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white)
                                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                                )
                                .padding(.horizontal, 40)
                                .onChange(of: amount) { oldValue, newValue in
                                    print("DEBUG: Amount changed from '\(oldValue)' to '\(newValue)'")
                                    // Filter to allow only numbers
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered != newValue {
                                        amount = filtered
                                        print("DEBUG: Amount filtered to '\(filtered)'")
                                    }
                                }
                            
                            VStack{
                                Spacer()
                                // Clear button
                                if !amount.isEmpty {
                                    Button(action: {
                                        HapticManager.impact(style: .light)
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            amount = ""
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 14))
                                            Text("Clear")
                                                .font(.system(size: 15, weight: .medium))
                                        }
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(Color.gray.opacity(0.1))
                                        )
                                    }
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                    }
                    
                    Spacer()

                    // MARK: - Bottom Continue Button
                    VStack(spacing: 0) {
                        if isValidAmount {
                            NavigationLink(destination: SortedUsersView(hideTabBar: $hideTabBar, amount: $amount)) {
                                Text("Continue")
                                    .font(.system(size: 17, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .foregroundColor(.white)
                                    .background(Color(hex: "4B548D"))
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: isValidAmount)
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationBarHidden(true)
            .onAppear {
                print("DEBUG: EnterAmountView appeared")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isAmountFocused = true
                    hideTabBar = true
                    print("DEBUG: Keyboard focused and tab bar hidden")
                }

                // Keyboard observers
                NotificationCenter.default.addObserver(
                    forName: UIResponder.keyboardWillShowNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    print("DEBUG: Keyboard will show")
                    withAnimation(.easeOut(duration: 0.25)) {
                        isKeyboardVisible = true
                    }
                }

                NotificationCenter.default.addObserver(
                    forName: UIResponder.keyboardWillHideNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    print("DEBUG: Keyboard will hide")
                    withAnimation(.easeOut(duration: 0.25)) {
                        isKeyboardVisible = false
                    }
                }
            }
            .onDisappear {
                print("DEBUG: EnterAmountView disappeared")
                NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
                NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
            }
        }
    }
}

#Preview {
    EnterAmountView(hideTabBar: .constant(false))
}

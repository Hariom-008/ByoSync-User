import SwiftUI

struct EnterAmountView: View {
    @State private var amount: String = ""
    @FocusState private var isAmountFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Binding var hideTabBar: Bool
    
    // Animation states
    @State private var showContent: Bool = false
    
    // Simple amount validation
    private var isValidAmount: Bool {
        if let value = Int(amount), value > 0 {
            print("✅ Valid amount entered: \(value)")
            return true
        }
        print("⚠️ Invalid amount: \(amount)")
        return false
    }
    
    // Formatted amount for display
    private var formattedAmount: String {
        if amount.isEmpty { return "0" }
        if let value = Int(amount) {
            return "\(value)"
        }
        return amount
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: - Background Gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "F8F9FD"),
                        Color(hex: "EEF0F8")
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Header
                    HStack {
                        Button {
                            print("🔙 Close button tapped")
                            dismiss()
                            hideTabBar = false
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 40, height: 40)
                                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                                
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -20)

                    Spacer()

                    // MARK: - Amount Input Section
                    VStack(spacing: 32) {
                        // Title with icon
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "4B548D").opacity(0.1))
                                    .frame(width: 56, height: 56)
                                
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            .scaleEffect(showContent ? 1 : 0.5)
                            .opacity(showContent ? 1 : 0)
                            
                            Text("Enter Amount")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        
                        // Amount display
                        VStack(spacing: 16) {
                            HStack(alignment: .top, spacing: 4) {
                                Image("byosync_coin")
                                    .resizable()
                                    .interpolation(.high)  // Better quality interpolation
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                                TextField("0", text: $amount)
                                    .keyboardType(.numberPad)
                                    .focused($isAmountFocused)
                                    .font(.system(size: 64, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.leading)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .onChange(of: amount) { newValue in
                                        let filtered = newValue.filter(\.isNumber)
                                        if filtered != newValue {
                                            print("🔢 Filtered input from '\(newValue)' to '\(filtered)'")
                                        }
                                        amount = filtered
                                    }
                            }
                            .padding(.horizontal, 40)
                            .padding(.vertical, 24)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.white)
                                    .shadow(color: Color(hex: "4B548D").opacity(0.08), radius: 20, x: 0, y: 8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(
                                                isAmountFocused ?
                                                LinearGradient(
                                                    colors: [Color(hex: "4B548D").opacity(0.3), Color(hex: "6B74A8").opacity(0.3)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ) : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom),
                                                lineWidth: 2
                                            )
                                    )
                            )
                            .scaleEffect(showContent ? 1 : 0.9)
                            .opacity(showContent ? 1 : 0)
                            
                            // Quick amount suggestions
                            if amount.isEmpty {
                                HStack(spacing: 12) {
                                    ForEach([50,100,200,500, 1000], id: \.self) { value in
                                        Button {
                                            print("💡 Quick amount selected: \(value)")
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                amount = "\(value)"
                                            }
                                        } label: {
                                            Text("\(value)")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(Color(hex: "4B548D"))
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .background(
                                                    Capsule()
                                                        .fill(Color(hex: "4B548D").opacity(0.08))
                                                )
                                        }
                                    }
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                            
                            // Clear button
                            if !amount.isEmpty {
                                Button {
                                    print("🗑️ Clear button tapped")
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        amount = ""
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                        Text("Clear")
                                            .font(.system(size: 15, weight: .medium))
                                    }
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(Color.gray.opacity(0.1))
                                    )
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: amount.isEmpty)
                    }
                    .padding(.horizontal, 20)

                    Spacer()

                    // MARK: - Continue Button
                    VStack(spacing: 16) {
                        NavigationLink(destination: SortedUsersView(hideTabBar: $hideTabBar, amount: $amount)) {
                            HStack(spacing: 8) {
                                Text("Continue")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .foregroundColor(.white)
                            .background(
                                Group {
                                    if isValidAmount {
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(hex: "4B548D")
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    } else {
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.gray.opacity(0.3),
                                                Color.gray.opacity(0.3)
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    }
                                }
                            )
                            .cornerRadius(16)
                            .shadow(
                                color: isValidAmount ? Color(hex: "4B548D").opacity(0.3) : .clear,
                                radius: 12,
                                x: 0,
                                y: 6
                            )
                            .scaleEffect(isValidAmount ? 1 : 0.98)
                        }
                        .disabled(!isValidAmount)
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                if isValidAmount {
                                    print("➡️ Continue button tapped with amount: \(amount)")
                                }
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isValidAmount)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                print("👁️ EnterAmountView appeared")
                hideTabBar = true
                
                // Staggered animations
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    showContent = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    print("⌨️ Focusing on amount field")
                    isAmountFocused = true
                }
            }
            .onDisappear {
                print("👋 EnterAmountView disappeared")
            }
        }
    }
}
#Preview {
    EnterAmountView(hideTabBar: .constant(false))
}

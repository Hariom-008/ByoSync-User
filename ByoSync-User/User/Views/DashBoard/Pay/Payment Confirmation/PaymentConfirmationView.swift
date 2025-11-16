import SwiftUI

struct PaymentConfirmationView: View {
    // ✅ Get crypto manager from environment
    @EnvironmentObject var cryptoManager: CryptoManager
    
    // ✅ ViewModel will be injected with crypto service
    @StateObject private var createOrderVM: CreateOrderViewModel
    
    @State private var navigateToRecieptView = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showContent = false
    @State private var coinScale: CGFloat = 1.0
    @Environment(\.dismiss) var dismiss
    
    @Binding var hideTabBar: Bool
    @Binding var selectedUser: UserData

    let amount: String
    @Binding var popToHome: Bool

    
    // ✅ Custom initializer to inject crypto service
    init(
        hideTabBar: Binding<Bool>,
        selectedUser: Binding<UserData>,
        amount: String,
        popToHome: Binding<Bool>
    ) {
        self._hideTabBar = hideTabBar
        self._selectedUser = selectedUser
        self._popToHome = popToHome
        self.amount = amount

        let tempCrypto = CryptoManager()
        self._createOrderVM = StateObject(
            wrappedValue: CreateOrderViewModel(cryptoService: tempCrypto)
        )
    }

    var body: some View {
    NavigationStack{
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "4B548D"),
                    Color(hex: "5E68A6"),
                    Color(hex: "3A4270")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                
                ZStack {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(Color.white)
                        .ignoresSafeArea(edges: .bottom)
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: -5)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 32) {
                            paymentDetailsSection
                            recipientSection
                            actionButtonsSection
                                .padding(.bottom, 32)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToRecieptView) {
            ReceiptView(
                hideTabBar: $hideTabBar,
                selectedUser: $selectedUser,
                orderId: $createOrderVM.orderId,
                popToHome: $popToHome, amount: Int(amount) ?? 0
            )
            .environmentObject(cryptoManager)
        }
        
        .alert("Payment Failed", isPresented: $showErrorAlert) {
            Button("Retry") {
                print("🔄 Retry payment button tapped")
                handleConfirmPayment()
            }
            Button("Cancel", role: .cancel) {
                print("❌ Cancel from error alert")
                dismiss()
                hideTabBar = false
            }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            hideTabBar = true
            print("💳 PaymentConfirmationView appeared")
            print("👤 Selected user - \(selectedUser.firstName) \(selectedUser.lastName)")
            print("💰 Amount - \(amount) coins")
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
            
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                coinScale = 1.1
            }
        }
    }
}

    // MARK: - Header
    private var headerSection: some View {
        HStack {
            Button(action: {
                print("🔙 Close payment confirmation")
                dismiss()
                hideTabBar = false
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Payment Review")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Verify details before sending")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -20)
    }

    // MARK: - Payment Details
    private var paymentDetailsSection: some View {
        VStack(spacing: 20) {
            HStack(alignment: .center, spacing: 8) {
                Image("byosync_coin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                
                Text(amount)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "FFD700").opacity(0.1),
                                Color(hex: "FFA500").opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(hex: "FFD700").opacity(0.3),
                                        Color(hex: "FFA500").opacity(0.2)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            )
        }
        .scaleEffect(showContent ? 1 : 0.9)
        .opacity(showContent ? 1 : 0)
    }

    // MARK: - Recipient Section
    private var recipientSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Payment Details")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Group {
                        if let url = URL(string: selectedUser.profilePic) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    profilePlaceholder
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 56, height: 56)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 2
                                                )
                                        )
                                case .failure:
                                    profilePlaceholder
                                @unknown default:
                                    profilePlaceholder
                                }
                            }
                        } else {
                            profilePlaceholder
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sending to")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("\(cryptoManager.decrypt(encryptedData: selectedUser.firstName) ?? "nil") \(cryptoManager.decrypt(encryptedData: selectedUser.lastName) ?? "nil")")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(cryptoManager.decrypt(encryptedData: selectedUser.email) ?? "nil")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(hex: "4B548D").opacity(0.2),
                                            Color(hex: "6B74A8").opacity(0.1)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: Color(hex: "4B548D").opacity(0.08), radius: 12, x: 0, y: 4)
                )
                
                VStack(spacing: 14) {
                    detailRow(
                        icon: "calendar",
                        label: "Date & Time",
                        value: formattedDateTime,
                        iconColor: Color(hex: "4B548D")
                    )
                    
                    Divider()
                    
                    detailRow(
                        icon: "clock",
                        label: "Processing Time",
                        value: "Instant",
                        iconColor: Color(hex: "4CAF50")
                    )
                    
                    Divider()
                    
                    detailRow(
                        icon: "checkmark.shield.fill",
                        label: "Transaction",
                        value: "Secure & Encrypted",
                        iconColor: Color(hex: "4CAF50")
                    )
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(hex: "F8F9FD"))
                )
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
    }
    
    private var profilePlaceholder: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "4B548D").opacity(0.15),
                            Color(hex: "6B74A8").opacity(0.15)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
            
            Text(selectedUser.initials)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    // MARK: - Helper Views
    private func detailRow(icon: String, label: String, value: String, iconColor: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
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
        formatter.dateFormat = "MMM dd, yyyy • hh:mm a"
        return formatter.string(from: Date())
    }

    // MARK: - Confirm Action
    private func handleConfirmPayment() {
        print("✅ [VIEW] Confirm payment button pressed")
        print("👤 Receiver ID - \(selectedUser.id)")
        print("💰 Amount - \(amount) coins")

        // Fire API in background
        createOrderVM.createOrder(
            receiverId: selectedUser.id,
            amount: Int(amount) ?? 0
        )
        
        // Immediately go to ReceiptView
        navigateToRecieptView = true
    }
}

// MARK: - Action Buttons
extension PaymentConfirmationView {
    var actionButtonsSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                print("💳 [VIEW] Confirm payment button tapped")
                handleConfirmPayment()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("Confirm & Pay")
                        .font(.system(size: 17, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .foregroundColor(.white)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "4B548D"),
                            Color(hex: "6B74A8")
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: Color(hex: "4B548D").opacity(0.4), radius: 16, x: 0, y: 8)
            }
            .disabled(createOrderVM.isLoading)
            .opacity(createOrderVM.isLoading ? 0.6 : 1.0)
            .scaleEffect(showContent ? 1 : 0.9)

            Button(action: {
                print("❌ [VIEW] Cancel payment button tapped")
                dismiss()
                hideTabBar = false
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Cancel Payment")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .foregroundColor(Color(hex: "FF3B30"))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "FF3B30").opacity(0.3), lineWidth: 1.5)
                )
            }
            .disabled(createOrderVM.isLoading)
            .opacity(createOrderVM.isLoading ? 0.6 : 1.0)
            .scaleEffect(showContent ? 1 : 0.9)
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: showContent)
    }
}

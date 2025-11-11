import SwiftUI

struct PaymentConfirmationView: View {
    @State private var isProcessing = false
    @State private var navigateToRecieptView = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showContent = false
    @State private var coinScale: CGFloat = 1.0
    @Environment(\.dismiss) var dismiss
    @Binding var hideTabBar: Bool
    @Binding var selectedUser: UserData

    @StateObject private var createOrderVM = CreateOrderViewModel()

    let amount: String

    var body: some View {
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
                            // Coin animation at top
                            coinHeader
                            
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
            
            // Coin pulse animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                coinScale = 1.1
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

    // MARK: - Coin Header
    private var coinHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Image("byosync_coin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .scaleEffect(coinScale)
            }
            
            Text("Sending Coins")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .scaleEffect(showContent ? 1 : 0.8)
        .opacity(showContent ? 1 : 0)
    }

    // MARK: - Payment Details
    private var paymentDetailsSection: some View {
        VStack(spacing: 20) {
            // Amount display with coins
            HStack(alignment: .top, spacing: 8) {
                Image("byosync_coin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                
                Text(amount)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black)
                
                Text("COINS")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                    .offset(y: 8)
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
                // Recipient info with profile
                HStack(spacing: 16) {
                    // Profile image or initials
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
                        
                        Text("\(selectedUser.firstName) \(selectedUser.lastName)")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(selectedUser.email)
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
                
                // Transaction details
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

    // MARK: - Processing Overlay
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .transition(.opacity)
            
            VStack(spacing: 28) {
                ZStack {
                    // Rotating rings
                    ForEach(0..<2) { index in
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "FFD700"),
                                        Color(hex: "FFA500").opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 90 + CGFloat(index * 20), height: 90 + CGFloat(index * 20))
                            .rotationEffect(.degrees(Double(index * 180)))
                            .animation(
                                .linear(duration: 1.5)
                                    .repeatForever(autoreverses: false),
                                value: isProcessing
                            )
                    }
                    
                    // Coin in center
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(hex: "FFD700"),
                                        Color(hex: "FFA500")
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                        
                        Image("byosync_coin")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                    }
                }
                .frame(width: 130, height: 130)
                
                VStack(spacing: 12) {
                    Text("Processing Payment")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Verifying transaction securely...")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    // Progress dots
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                                .opacity(0.3)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: isProcessing
                                )
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(48)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "4B548D"),
                                Color(hex: "3A4270")
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
            )
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
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
        print("✅ Confirm payment button pressed")
        print("👤 Receiver ID - \(selectedUser.id)")
        
        let senderId = UserDefaults.standard.string(forKey: "user_id") ?? ""
        let senderDeviceId = UserDefaults.standard.string(forKey: "device_id") ?? ""
        
        print("👤 Sender ID - \(senderId)")
        print("📱 Sender Device ID - \(senderDeviceId)")
        print("💰 Amount - \(amount) coins")

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isProcessing = true
        }
        
        Task {
            do {
                let order = try await createOrderVM.createOrder(
                    receiverId: selectedUser.id,
                    amount: Int(amount) ?? 0
                )
                
                print("✅ Order Created Successfully!")
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isProcessing = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        print("➡️ Navigating to receipt view")
                        navigateToRecieptView = true
                    }
                }
            } catch {
                print("❌ Order Creation Failed: \(error.localizedDescription)")
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isProcessing = false
                    }
                    
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
                        errorMessage = "Insufficient coin balance. Please earn more coins to continue."
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

// MARK: - Action Buttons
extension PaymentConfirmationView {
    var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // Confirm button
            Button(action: {
                print("💳 Confirm payment button tapped")
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
            .disabled(isProcessing)
            .opacity(isProcessing ? 0.6 : 1.0)
            .scaleEffect(showContent ? 1 : 0.9)

            // Cancel button
            Button(action: {
                print("❌ Cancel payment button tapped")
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
            .disabled(isProcessing)
            .opacity(isProcessing ? 0.6 : 1.0)
            .scaleEffect(showContent ? 1 : 0.9)
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: showContent)
    }
}

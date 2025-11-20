import Foundation
import SwiftUI
import Combine

struct PaymentNotification: Identifiable, Codable {
    let id: String
    let amount: Double
    let currency: String
    let senderName: String
    let timestamp: Date
    let transactionId: String
    let message: String?
    let orderType: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case amount
        case currency
        case senderName = "sender_name"
        case timestamp
        case transactionId = "transaction_id"
        case message
        case orderType = "order_type"
    }
}

struct PaymentReceivedResponse: Codable {
    let message: String
    let order: OrderDetails
    
    struct OrderDetails: Codable {
        let id: String
        let type: String
        let receiverId: String
        let senderId: String
        let senderDeviceId: String
        let coins: Int
        let status: String
        let createdAt: String
        let updatedAt: String
        
        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case type
            case receiverId
            case senderId
            case senderDeviceId
            case coins
            case status
            case createdAt
            case updatedAt
        }
    }
}

struct PaymentNotificationOverlay: View {
    let cryptoManager = CryptoManager.shared
    let notification: PaymentNotification
    @Binding var isShowing: Bool
    var onDismiss: (() -> Void)? = nil
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    // Brand & semantic colors
    private let brandColor = Color(hex: "4B548D")
    private let accentGreen = Color.green
    
    var body: some View {
        VStack {
            notificationCard
                .padding(.horizontal, 16)
                .padding(.top, 44)
                .offset(y: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.height < 0 {
                                isDragging = true
                                dragOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            if value.translation.height < -50 {
                                dismissNotification()
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dragOffset = 0
                                    isDragging = false
                                }
                            }
                        }
                )
            
            Spacer()
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            // 🔔 Auto-dismiss after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if isShowing {       // avoid double-dismiss
                    dismissNotification()
                }
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private var notificationCard: some View {
        let decrypted = cryptoManager.decryptPaymentMessage(notification.message)
        let messageText = decrypted.isEmpty ? (notification.message ?? "") : decrypted
        
        return VStack(alignment: .leading, spacing: 10) {
            // Top row: icon + title + close button
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 34, height: 34)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Payment notification")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Just now")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer(minLength: 12)
                
                Button(action: dismissNotification) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            }
            
            // Message body
            if !messageText.isEmpty {
                Text(messageText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        brandColor,
                        brandColor.opacity(0.9)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Subtle overlay stripe
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.09),
                        Color.clear
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.screen)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: brandColor.opacity(0.35), radius: 22, x: 0, y: 14)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.30),
                            Color.white.opacity(0.06)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
    }
    
    private func dismissNotification() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isShowing = false
        }
        onDismiss?()
    }
}

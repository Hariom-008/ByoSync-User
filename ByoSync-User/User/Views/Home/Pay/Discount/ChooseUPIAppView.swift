//
//  ChooseUPIAppView.swift
//  ByoSync
//
//  Enhanced UI with Smooth Navigation
//

import SwiftUI

struct ChooseUPIAppView: View {
    @State private var selectedApp: String = "Google Pay"
    @State private var selectedAppIcon: String = "googlepay_logo"
    @State private var upiID: String = "brunomars@okbyosync"
    @State private var showAppOptions: Bool = false
    @State private var navigateToReceipt: Bool = false
    @State private var isProcessing: Bool = false
    @Environment(\.dismiss) var dismiss
    @Binding var hideTabBar: Bool
    
    let amount: String
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(hex: "F8F9FD"),
                        Color.white
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Header
                    headerSection
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            // MARK: - Merchant Info
                            merchantInfoCard
                            
                            // MARK: - UPI App Selection
                            upiAppSelectionSection
                            
                            // MARK: - Transaction Details
                            transactionDetailsSection
                            
                            Spacer(minLength: 20)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // MARK: - Bottom Button
                    VStack(spacing: 12) {
                        Button(action: handleProceedToPayment) {
                            HStack(spacing: 10) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Proceed to Pay")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
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
                            Text("Back")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "4B548D"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(hex: "4B548D").opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.white)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToReceipt) {
                ReceiptView(hideTabBar: $hideTabBar, amount: amount)
            }
            .confirmationDialog("Select UPI App", isPresented: $showAppOptions, titleVisibility: .visible) {
                ForEach(upiApps, id: \.name) { app in
                    Button(app.name) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedApp = app.name
                            selectedAppIcon = app.icon
                            upiID = app.upiID
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .overlay(
                isProcessing ? processingOverlay : nil
            )
            .onAppear {
                hideTabBar = true
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Button(action: {
                dismiss()
                hideTabBar = false
            }) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
            Spacer()
            Text("Send Money")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            Spacer()
            Circle()
                .fill(Color.clear)
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }
    
    // MARK: - Merchant Info Card
    private var merchantInfoCard: some View {
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
                    .frame(width: 110, height: 110)
                
                Image("merchant_photo")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(color: Color(hex: "4B548D").opacity(0.2), radius: 10, x: 0, y: 4)
            }
            
            VStack(spacing: 6) {
                Text("Merchant")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("0987654321")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            // Amount display
            HStack(spacing: 4) {
                Text("Amount: ₹\(amount)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: "4B548D"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: "4B548D").opacity(0.1))
            .clipShape(Capsule())
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
        )
        .padding(.top, 8)
    }
    
    // MARK: - UPI App Selection
    private var upiAppSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose Payment App")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Button(action: { showAppOptions.toggle() }) {
                HStack(spacing: 14) {
                    // App Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white)
                            .frame(width: 60, height: 60)
                        
                        Image(selectedAppIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 36, height: 36)
                    }
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                    
                    // App Details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedApp)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Text(upiID)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("Change")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "4B548D"))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "4B548D"))
                    }
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            }
        }
    }
    
    // MARK: - Transaction Details
    private var transactionDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transaction Details")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 14) {
                txnDetailRow(
                    icon: "calendar",
                    label: "Date",
                    value: formattedDate
                )
                
                Divider()
                    .padding(.vertical, 4)
                
                txnDetailRow(
                    icon: "gift.fill",
                    label: "Cashback",
                    value: "Up to 10%",
                    valueColor: Color(hex: "4CAF50")
                )
                
                Divider()
                    .padding(.vertical, 4)
                
                txnDetailRow(
                    icon: "creditcard.fill",
                    label: "Receiver's UPI",
                    value: "receiver@oksbi"
                )
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Processing Overlay
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(Color(hex: "4B548D"))
                
                VStack(spacing: 4) {
                    Text("Processing Payment")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Please wait...")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "4B548D"))
            )
        }
        .transition(.opacity)
    }
    
    // MARK: - Helper Views
    private func txnDetailRow(
        icon: String,
        label: String,
        value: String,
        valueColor: Color = .primary
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(valueColor)
        }
    }
    
    // MARK: - Computed Properties
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM, yyyy"
        return formatter.string(from: Date())
    }
    
    private var upiApps: [UPIApp] {
        [
            UPIApp(name: "Google Pay", icon: "googlepay_logo", upiID: "brunomars@okbyosync"),
            UPIApp(name: "PhonePe", icon: "phonepe_logo", upiID: "brunomars@ybl"),
            UPIApp(name: "Paytm", icon: "paytm_logo", upiID: "brunomars@paytm")
        ]
    }
    
    // MARK: - Action Handlers
    private func handleProceedToPayment() {
        isProcessing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isProcessing = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                navigateToReceipt = true
            }
        }
    }
}

// MARK: - UPI App Model
struct UPIApp {
    let name: String
    let icon: String
    let upiID: String
}

#Preview {
    ChooseUPIAppView(hideTabBar: .constant(false), amount: "450")
}

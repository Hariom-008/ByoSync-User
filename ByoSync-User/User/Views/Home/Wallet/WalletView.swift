import SwiftUI

struct WalletView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("creditAvailable") private var creditAvailable: Double = 0.0
    @StateObject private var discountManager = DiscountTransactionManager()
    @State private var selectedTabIndex: Int = 0
    @StateObject var transactionVM = TransactionViewModel()
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color.indigo.opacity(0.03)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // MARK: - Balance Card
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Text(L("wallet.current_balance"))
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white.opacity(0.8))
                                .textCase(.uppercase)
                                .tracking(1.2)
                            
                            Text("\(L("common.currency_symbol"))\(String(format: "%.2f", UserSession.shared.wallet))")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        // Balance breakdown
                        HStack(spacing: 16) {
                            balanceBreakdownItem(
                                label: L("wallet.total_discounts"),
                                value: "\(L("common.currency_symbol"))\(String(format: "%.2f", 500 - creditAvailable))",
                                icon: "gift.fill",
                                color: .green
                            )
                            
                            balanceBreakdownItem(
                                label: L("wallet.transactions"),
                                value: "\(transactionVM.savedTransactionCount)",
                                icon: "list.bullet",
                                color: .orange
                            )
                        }
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 32)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                    .background(
                        ZStack {
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.indigo.opacity(0.9),
                                    Color.indigo
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 200, height: 200)
                                .offset(x: -80, y: -60)
                                .blur(radius: 40)
                            Circle()
                                .fill(Color.indigo.opacity(0.3))
                                .frame(width: 150, height: 150)
                                .offset(x: 100, y: 80)
                                .blur(radius: 50)
                        }
                    )
                    .cornerRadius(28)
                    .shadow(color: Color.indigo.opacity(0.4), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 24)
                                        
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle(L("wallet.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    
    private func balanceBreakdownItem(
        label: String,
        value: String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }

}

#Preview {
    WalletView()
        .environmentObject(LanguageManager.shared)
}

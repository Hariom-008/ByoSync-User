import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @State var paytoPerson: String = ""
    @State var openProfileView: Bool = false
    @State var openWalletView: Bool = false
    @State var openLeaderboardView: Bool = false
    @State var openTransactionView: Bool = false
    @Binding var hideTabBar: Bool
    @State var profilePic: URL?
    @AppStorage("creditAvailable") private var creditAvailable: Double = 0.0

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(hex: "4B548D")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 20) {

                    avaialableCreditandWallet
                        .padding(.bottom, 12)
                        .padding(.top,8)

                    payFeaturesSection
                }
            }
            .fullScreenCover(isPresented: $openProfileView){
                ProfileView()
            }
            .navigationDestination(isPresented: $openWalletView) {
                WalletView()
            }
            .navigationDestination(isPresented: $openLeaderboardView) {
                LeaderboardView()
            }
            .navigationDestination(isPresented: $openTransactionView) {
                TransactionView(hideTabBar: $hideTabBar)
            }
        }
        .onAppear {
            loadProfilePicture()
            hideTabBar = false
        }
        .environment(\.locale, .init(identifier: languageManager.currentLanguageCode))
    }

    private func loadProfilePicture() {
        if let url = URL(string: UserSession.shared.userProfilePicture),
           !UserSession.shared.userProfilePicture.isEmpty {
            profilePic = url
        } else {
            profilePic = nil
            print("⚠️ No valid profile picture URL found on HOME")
        }
    }

    // MARK: - Credit + Wallet
    private var avaialableCreditandWallet: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "4B548D"))
                    Spacer()
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    HStack{
                        Text("\(String(format: "%.2f", UserSession.shared.wallet))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                    }
                    Text(L("available_credit"))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            .padding(18)
            .frame(width: 140, height: 110)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
            )

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    openWalletView.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.20))
                            .frame(width: 44, height: 44)
                        if #available(iOS 18.0, *) {
                            Image(systemName: "wallet.bifold")
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: "creditcard.fill")
                                .foregroundStyle(.white)
                        }

                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("my_wallet"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .frame(height: 110)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), Color.white.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Main Features Section
    private var payFeaturesSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: -5)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Leaderboard Card
                    leaderboardCard
                        .padding(.top, 28)
                        .padding(.horizontal, 20)

                    // Transaction History Button
                    transactionHistoryButton
                        .padding(.horizontal, 20)

                    // Promotions
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(L("promotions"))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                            
                            Spacer()
                            
                            Text("Limited Time")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.orange.opacity(0.15))
                                )
                        }

                        ScrollView(.horizontal, showsIndicators: false){
                            HStack(spacing: 16){
                                PromotionCard(
                                    Promotiontitle: "Weekend Offers",
                                    promotionDescription: "Pay to new users to earn more discounts",
                                    icon: "gift.fill",
                                    iconColor: Color.orange
                                )
                                
                                PromotionCard(
                                    Promotiontitle: "Transaction Offers",
                                    promotionDescription: "Do more transaction instead of higher transactions",
                                    icon: "chart.line.uptrend.xyaxis",
                                    iconColor: Color.indigo
                                )
                                
                                PromotionCard(
                                    Promotiontitle: "Refer & Earn",
                                    promotionDescription: "Share with your friends and earn 200 Coins",
                                    icon: "person.2.fill",
                                    iconColor: Color.green
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    // MARK: - Leaderboard Card
    private var leaderboardCard: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                openLeaderboardView.toggle()
            }
        } label: {
            VStack(spacing: 16) {
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.yellow, Color.orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Leaderboard")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                            Text("user rankings")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.5))
                }
                
                Divider()
                
                // Top 3 Preview
                HStack(spacing: 12) {
                    // 2nd Place
                    LeaderboardPreviewItem(
                        rank: "2",
                        name: "Sarah",
                        score: "2,450",
                        rankColor: .gray
                    )
                    
                    // 1st Place
                    LeaderboardPreviewItem(
                        rank: "1",
                        name: "You",
                        score: "3,180",
                        rankColor: .yellow,
                        isHighlighted: true
                    )
                    
                    // 3rd Place
                    LeaderboardPreviewItem(
                        rank: "3",
                        name: "Mike",
                        score: "1,890",
                        rankColor: Color(hex: "CD7F32")
                    )
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.yellow.opacity(0.1), radius: 12, x: 0, y: 6)
            )
        }
    }
    
    // MARK: - Transaction History Button
    private var transactionHistoryButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                openTransactionView.toggle()
                hideTabBar.toggle()
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 10,weight: .semibold))
                    .foregroundStyle(.gray)
                    Text("Transaction History")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                Spacer()
                
                Text("view all")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.purple.opacity(0.08), radius: 8, x: 0, y: 4)
            )
        }
    }
}
// MARK: - Leaderboard Preview Item
private struct LeaderboardPreviewItem: View {
    let rank: String
    let name: String
    let score: String
    let rankColor: Color
    var isHighlighted: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: isHighlighted ? 54 : 44, height: isHighlighted ? 54 : 44)
                
                Text(rank)
                    .font(.system(size: isHighlighted ? 20 : 16, weight: .bold))
                    .foregroundColor(rankColor)
            }
            
            VStack(spacing: 2) {
                Text(name)
                    .font(.system(size: 12, weight: isHighlighted ? .bold : .semibold))
                    .foregroundColor(.black)
                
                Text(score)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHighlighted ? rankColor.opacity(0.1) : Color.clear)
        )
    }
}

// MARK: - Promotion Card
private struct PromotionCard: View {
    var Promotiontitle:String
    var promotionDescription:String
    var icon: String
    var iconColor: Color
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [iconColor.opacity(0.2), iconColor.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundColor(iconColor)
                
                
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(Promotiontitle)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)

                Text("\(promotionDescription)")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [iconColor.opacity(0.3), iconColor.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: iconColor.opacity(0.1), radius: 12, x: 0, y: 6)
        )
    }
}



#Preview {
    HomeView(hideTabBar: .constant(false))
        .environmentObject(LanguageManager.shared)
}

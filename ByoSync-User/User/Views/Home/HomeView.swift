import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @State var paytoPerson: String = ""
    @State var openProfileView: Bool = false
    @State var openWalletView: Bool = false
    @State var openPayToMerchant: Bool = false
    @Binding var hideTabBar: Bool
    @State var profilePic: URL?
    @AppStorage("creditAvailable") private var creditAvailable: Double = 0.0

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(hex: "4B548D"), Color(hex: "5A63A0")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 20) {
                    searchBarandProfileImage
                        .padding(.top, 8)

                    avaialableCreditandWallet
                        .padding(.bottom, 12)

                    payFeaturesSection
                }
            }
            .fullScreenCover(isPresented: $openProfileView){
                ProfileView()
            }
            .navigationDestination(isPresented: $openWalletView) {
                WalletView()
            }
            .navigationDestination(isPresented: $openPayToMerchant) {
                EnterAmountView(hideTabBar: $hideTabBar)
            }
        }
        .onAppear {
            loadProfilePicture()
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

    // MARK: - Header
    private var searchBarandProfileImage: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray.opacity(0.5))
                    .font(.system(size: 16))
                TextField(L("search_placeholder"), text: $paytoPerson)
                    .font(.system(size: 15))
                    .foregroundColor(.black)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            )

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    openProfileView.toggle()
                }
            } label: {
                AsyncImage(url: profilePic) { phase in
                    switch phase {
                    case .empty:
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.white)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 50)
                            .clipShape(Circle())
                    case .failure:
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
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
                    Text("₹\(String(format: "%.2f", UserSession.shared.wallet))")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.black)
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
                VStack(alignment: .leading, spacing: 28) {
                    payToMerchantPill
                        .padding(.top, 28)
                        .padding(.horizontal, 20)

                    // Promotions
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L("promotions"))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)

                        PromotionCard()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Pay to Merchant Pill
    private var payToMerchantPill: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                openPayToMerchant.toggle()
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "4B548D"), Color(hex: "5A63A0")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .shadow(color: Color(hex: "4B548D").opacity(0.3), radius: 8, x: 0, y: 4)

                    Image(systemName: "qrcode")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L("pay_to_merchant"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                    Text(L("cashback_subtext"))
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "F5F6FA"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Promotion Card
private struct PromotionCard: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.2), Color.pink.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                Image(systemName: "gift.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L("weekend_offer_title"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)

                Text(L("weekend_offer_subtitle"))
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.3), Color.pink.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.orange.opacity(0.1), radius: 12, x: 0, y: 6)
        )
    }
}

#Preview {
    HomeView(hideTabBar: .constant(false))
        .environmentObject(LanguageManager.shared)
}

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @State private var selected: MainTab = .home
    @State private var showScanner = false
    @State var hideTabBar: Bool = false

    var body: some View {
        ZStack {
            // MARK: - Active content
            Group {
                switch selected {
                case .home:
                    HomeView(hideTabBar: $hideTabBar)
                case .transactions:
                    TransactionView()
                }
            }
            .ignoresSafeArea(.all, edges: .bottom)

            // MARK: - Custom Tab Bar
            if !hideTabBar {
                VStack {
                    Spacer(minLength: 0)

                    ZStack {
                        // Glassmorphic background
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
                            )
                            .frame(height: 72)
                            .shadow(color: .black.opacity(0.12), radius: 12, y: -4)
                            .padding(.horizontal, 20)

                        HStack(spacing: 0) {
                            // Home Tab
                            TabItem(
                                systemName: "house.fill",
                                title: L("tab_home"),
                                isSelected: selected == .home
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selected = .home
                                }
                            }
                            .frame(maxWidth: .infinity)

                            Spacer().frame(width: 80)

                            // Transactions Tab
                            TabItem(
                                systemName: "arrow.clockwise.circle.fill",
                                title: L("tab_transactions"),
                                isSelected: selected == .transactions
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selected = .transactions
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 32)

                        // Center scan button
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showScanner.toggle()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color(hex: "4B548D").opacity(0.3),
                                                Color.clear
                                            ],
                                            center: .center,
                                            startRadius: 34,
                                            endRadius: 44
                                        )
                                    )
                                    .frame(width: 88, height: 88)

                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "5B62A0"),
                                                Color(hex: "4B548D")
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 68, height: 68)
                                    .shadow(color: Color(hex: "4B548D").opacity(0.4), radius: 12, y: 4)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.white.opacity(0.3), .clear],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )

                                Image("bill_logo_image")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                    .foregroundStyle(.white)
                            }
                            .scaleEffect(showScanner ? 0.95 : 1.0)
                        }
                        .offset(y: -28)
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showScanner) {
                            BillScanView()
                        }
                    }
                    .padding(.bottom, 8)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationBarBackButtonHidden(true)
        .environment(\.locale, .init(identifier: languageManager.currentLanguageCode))
    }
}

// MARK: - Custom Button Style
struct TabItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    MainTabView()
        .environmentObject(LanguageManager.shared)
}

// UserDataByIdView.swift

import SwiftUI

// MARK: - Color Palette
private let primaryBlue = Color(red: 0.29, green: 0.33, blue: 0.55) // #4B548D
private let primaryBlueDark = Color(red: 0.23, green: 0.25, blue: 0.44) // #3A4170
private let primaryBlueDeep = Color(red: 0.16, green: 0.19, blue: 0.33) // #2A3155
private let accentGold = Color(red: 1.0, green: 0.72, blue: 0.30) // #FFB74D

struct UserDataByIdView: View {
    enum Mode {
        case live
#if DEBUG
        case mockContent
        case mockLoading
        case mockError
#endif
    }
    
    private let mode: Mode
    
    @StateObject private var viewModel: UserDataByIdViewModel
    @StateObject private var userSession: UserSession = UserSession.shared
    @Environment(\.dismiss) private var dismiss
    let cryptoManager = CryptoManager.shared
    
    @MainActor
    init(mode: Mode = .live, viewModel: UserDataByIdViewModel? = nil) {
        self.mode = mode
        if let vm = viewModel {
            _viewModel = StateObject(wrappedValue: vm)
        } else {
            _viewModel = StateObject(wrappedValue: UserDataByIdViewModel())
        }
    }
    
    var body: some View {
        ZStack {
            // Dark blue gradient background
            LinearGradient(
                colors: [primaryBlue, primaryBlueDark, primaryBlueDeep],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorText {
                errorView(error)
            } else if let user = viewModel.user {
                userContentView(user: user)
            } else {
                emptyStateView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("ByoSync")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            print("👁️ UserDataByIdView appeared")
            
            switch mode {
            case .live:
                fetchUserData()
                
#if DEBUG
            case .mockContent:
                viewModel.loadMock()
            case .mockLoading:
                viewModel.loadMockLoading()
            case .mockError:
                viewModel.loadMockError()
#endif
            }
        }
        .refreshable {
            print("🔄 Pull to refresh triggered")
            await refreshUserData()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Loading your profile...")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    // MARK: - Error View
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            GlassCard {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.red)
                    }
                    
                    Text("Unable to Load Profile")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                    
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
                .padding(32)
            }
            
            Button(action: { fetchUserData() }) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)
        }
        .padding(24)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.5))
            
            Text("No profile data available")
                .font(.headline)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    // MARK: - User Content View
    private func userContentView(user: UserByIdDTO) -> some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    profileHeaderView(user: user)
                    
                    // Chai Balance Card
                    chaiBalanceCard
                    
                    // User Details Card
                    userDetailsCard(user: user)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
            
            // Logout Button at Bottom
            VStack {
                Spacer()
                logoutButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Profile Header
    private func profileHeaderView(user: UserByIdDTO) -> some View {
        VStack(spacing: 12) {
            // Avatar Circle
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 2)
                    .frame(width: 80, height: 80)
                
                if let profilePicUrl = user.profilePic, !profilePicUrl.isEmpty {
                    AsyncImage(url: URL(string: profilePicUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            VStack(spacing: 4) {
                // Name
                Text("\(cryptoManager.decrypt(encryptedData: user.firstName) ?? "User") \(cryptoManager.decrypt(encryptedData: user.lastName) ?? "")")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)
                    .tracking(0.3)
                
                // Member label
                Text("Member")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(1.2)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Chai Balance Card
    private var chaiBalanceCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(accentGold.opacity(0.2))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 28))
                        .foregroundColor(accentGold)
                }
                
                VStack(spacing: 6) {
                    Text("Chai Balance")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .tracking(0.8)
                    
                    Text("\(viewModel.chai)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                        .tracking(-1)
                    
                    Text("out of 5")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(0.5)
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [accentGold, accentGold.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(viewModel.chai) / 5.0, height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(24)
        }
    }
    
    // MARK: - User Details Card
    private func userDetailsCard(user: UserByIdDTO) -> some View {
        GlassCard {
            VStack(spacing: 24) {
                HStack {
                    Text("Account Details")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(0.3)
                    Spacer()
                }
                
                VStack(spacing: 20) {
                    // Email
                    DetailRow(
                        icon: "envelope.fill",
                        label: "Email",
                        value: cryptoManager.decrypt(encryptedData: user.email) ?? "Not available"
                    )
                    
                    // Phone
                    if !user.phoneNumber.isEmpty {
                        DetailRow(
                            icon: "phone.fill",
                            label: "Phone",
                            value: cryptoManager.decrypt(encryptedData: user.phoneNumber) ?? "Not available"
                        )
                    }
                }
            }
            .padding(24)
        }
    }
    
    // MARK: - Detail Row Component
    private func DetailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
                    .tracking(0.8)
                
                Text(value)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white)
                    .tracking(0.2)
                    .lineLimit(1)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Logout Button
    private var logoutButton: some View {
        Button(action: handleLogout) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 20))
                
                Text("Logout")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(0.5)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.red.opacity(0.85))
            .cornerRadius(14)
        }
    }
    
    // MARK: - Glass Card Component
    private struct GlassCard<Content: View>: View {
        let content: Content
        
        init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }
        
        var body: some View {
            content
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                )
        }
    }
    
    // MARK: - Fetch User Data
    private func fetchUserData() {
        print("🔍 Starting to fetch user data...")
        
        let deviceKey = DeviceIdentity.resolve()
        let deviceKeyHash = HMACGenerator.generateHMAC(jsonString: deviceKey)
        print("✅ Device Key Hash resolved: \(deviceKeyHash)")
        
        guard let userId = userSession.currentUser?.userId, !userId.isEmpty else {
            print("❌ No userId found in UserSession")
            return
        }
        print("✅ User ID from session: \(userId)")
        
        Task {
            print("🚀 Calling API to fetch user data...")
            await viewModel.fetch(userId: userId, deviceKeyHash: deviceKeyHash)
            
            if let user = viewModel.user {
                print("✅ Successfully fetched user data")
                updateUserSession(with: user)
            } else {
                print("❌ Failed to fetch user data")
            }
        }
    }
    
    // MARK: - Refresh User Data
    private func refreshUserData() async {
        print("🔄 Refreshing user data...")
        
        let deviceKey = DeviceIdentity.resolve()
        let deviceKeyHash = HMACGenerator.generateHMAC(jsonString: deviceKey)
        
        guard let userId = userSession.currentUser?.userId, !userId.isEmpty else {
            print("❌ No userId found in UserSession")
            return
        }
        
        await viewModel.fetch(userId: userId, deviceKeyHash: deviceKeyHash)
        
        if let user = viewModel.user {
            print("✅ Successfully refreshed user data")
            updateUserSession(with: user)
        }
    }
    
    // MARK: - Update UserSession
    private func updateUserSession(with userData: UserByIdDTO) {
        print("💾 Updating UserSession with fetched data...")
        
        userSession.setUserWallet(userData.wallet)
        print("✅ Wallet updated: \(userData.wallet)")
        
        userSession.setEmailVerified(userData.emailVerified)
        print("✅ Email verification status updated: \(userData.emailVerified)")
        
        if let profilePic = userData.profilePic {
            userSession.setProfilePicture(profilePic)
            print("✅ Profile picture updated: \(profilePic)")
        }
        
        if let device = viewModel.device {
            userSession.setThisDevicePrimary(device.isPrimary)
            print("✅ Device primary status updated: \(device.isPrimary)")
            
            userSession.setCurrentDeviceID(device.id)
            print("✅ Device ID updated: \(device.id)")
        }
        
        let updatedUser = User(
            firstName: userData.firstName,
            lastName: userData.lastName,
            email: userData.email,
            phoneNumber: userData.phoneNumber,
            deviceKey: viewModel.device?.deviceKey,
            deviceName: viewModel.device?.deviceName,
            fcmToken: userSession.currentUser?.fcmToken,
            refferalCode: userData.referralCode,
            userId: userData.id,
            userDeviceId: viewModel.device?.id
        )
        
        userSession.saveUser(updatedUser)
        print("✅ User object saved to UserSession")
        print("🎉 UserSession update complete!")
    }
    
    // MARK: - Handle Logout
    private func handleLogout() {
        print("🚪 Logout button tapped")
        
        // Clear user session
        userSession.clearUser()
        print("✅ User session cleared")
        
        // Navigate back or to login
        dismiss()
        print("✅ Dismissed view")
    }
}

#Preview {
    NavigationStack {
        UserDataByIdView()
    }
}

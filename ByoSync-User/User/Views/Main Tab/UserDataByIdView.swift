// UserDataByIdView.swift

import SwiftUI

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
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
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
                .padding()
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
    }

// MARK: - Loading View
private var loadingView: some View {
    VStack(spacing: 16) {
        ProgressView()
            .scaleEffect(1.5)
            .tint(.blue)
        
        Text("Loading your data...")
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.top, 100)
}

// MARK: - Error View
private func errorView(_ error: String) -> some View {
    VStack(spacing: 16) {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 50))
            .foregroundColor(.red)
        
        Text("Something went wrong")
            .font(.headline)
        
        Text(error)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
        
        Button(action: fetchUserData) {
            Label("Retry", systemImage: "arrow.clockwise")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(10)
        }
    }
    .padding()
}

// MARK: - Empty State
private var emptyStateView: some View {
    VStack(spacing: 16) {
        Image(systemName: "person.crop.circle.badge.questionmark")
            .font(.system(size: 60))
            .foregroundColor(.gray)
        
        Text("No user data available")
            .font(.headline)
            .foregroundColor(.secondary)
    }
    .padding(.top, 100)
}

// MARK: - User Content View
private func userContentView(user: UserByIdDTO) -> some View {
    VStack(spacing: 20) {
        // Profile Header
        profileHeaderView(user: user)
        
        // Chai Highlight Card
        chaiHighlightCard
        
        // Stats Cards
        statsCardsView(user: user)
        
        // Wallet & Transactions
        walletTransactionsView(user: user)
        
        // User Details
        userDetailsCard(user: user)
        
        // Device Info
        if let device = viewModel.device {
            deviceInfoCard(device: device)
        }
    }
}

// MARK: - Profile Header
private func profileHeaderView(user: UserByIdDTO) -> some View {
    VStack(spacing: 12) {
        // Profile Picture
        if let profilePicUrl = user.profilePic, !profilePicUrl.isEmpty {
            AsyncImage(url: URL(string: profilePicUrl)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 4))
            .shadow(radius: 5)
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.gray)
                .overlay(Circle().stroke(Color.white, lineWidth: 4))
                .shadow(radius: 5)
        }
        
        // Name
        Text("\(user.firstName) \(user.lastName)")
            .font(.title2.bold())
        
        // Email with verification badge
        HStack(spacing: 4) {
            Text(user.email)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if user.emailVerified {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        
        // Phone Number
        if !user.phoneNumber.isEmpty {
            Text(user.phoneNumber)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background(Color.white.opacity(0.8))
    .cornerRadius(16)
    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
}

// MARK: - Chai Highlight Card
private var chaiHighlightCard: some View {
    VStack(spacing: 8) {
        HStack {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Chai Claimed")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(viewModel.chai)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.orange)
                
                Text("cups")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background(
        LinearGradient(
            colors: [Color.orange.opacity(0.1), Color.yellow.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
    .cornerRadius(16)
    .overlay(
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color.orange.opacity(0.3), lineWidth: 2)
    )
    .shadow(color: .orange.opacity(0.2), radius: 8, x: 0, y: 4)
}

// MARK: - Stats Cards
private func statsCardsView(user: UserByIdDTO) -> some View {
    HStack(spacing: 12) {
        statCard(
            title: "Wallet",
            value: String(format: "%.2f", viewModel.wallet),
            icon: "dollarsign.circle.fill",
            color: .green
        )
        
        statCard(
            title: "Transactions",
            value: "\(user.noOfTransactions)",
            icon: "arrow.up.circle.fill",
            color: .blue
        )
        
        statCard(
            title: "Received",
            value: "\(user.noOfTransactionsReceived)",
            icon: "arrow.down.circle.fill",
            color: .purple
        )
    }
}

private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
    VStack(spacing: 8) {
        Image(systemName: icon)
            .font(.system(size: 24))
            .foregroundColor(color)
        
        Text(value)
            .font(.title3.bold())
        
        Text(title)
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(Color.white.opacity(0.8))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
}

// MARK: - Wallet & Transactions
private func walletTransactionsView(user: UserByIdDTO) -> some View {
    VStack(spacing: 16) {
        HStack {
            Text("Financial Overview")
                .font(.headline)
            Spacer()
        }
        
        VStack(spacing: 12) {
            infoRow(
                title: "Transaction Coins",
                value: "\(user.transactionCoins)",
                icon: "star.fill",
                color: .yellow
            )
            
            Divider()
            
            infoRow(
                title: "Referral Code",
                value: user.referralCode,
                icon: "person.2.fill",
                color: .indigo
            )
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

// MARK: - User Details Card
private func userDetailsCard(user: UserByIdDTO) -> some View {
    VStack(spacing: 16) {
        HStack {
            Text("Account Information")
                .font(.headline)
            Spacer()
        }
        
        VStack(spacing: 12) {
            infoRow(
                title: "User ID",
                value: user.id,
                icon: "person.text.rectangle",
                color: .blue
            )
            
            Divider()
            
            infoRow(
                title: "Devices",
                value: "\(user.devices.count)",
                icon: "iphone",
                color: .gray
            )
            
            Divider()
            
            infoRow(
                title: "Email Verified",
                value: user.emailVerified ? "Yes" : "No",
                icon: user.emailVerified ? "checkmark.circle.fill" : "xmark.circle.fill",
                color: user.emailVerified ? .green : .red
            )
            
            Divider()
            
            infoRow(
                title: "Member Since",
                value: formatDate(user.createdAt),
                icon: "calendar",
                color: .purple
            )
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Device Info Card
private func deviceInfoCard(device: DeviceByIdDTO) -> some View {
    VStack(spacing: 16) {
        HStack {
            Text("Device Information")
                .font(.headline)
            Spacer()
            
            if device.isPrimary {
                Text("PRIMARY")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .cornerRadius(6)
            }
        }
        
        VStack(spacing: 12) {
            infoRow(
                title: "Device Name",
                value: device.deviceName,
                icon: "iphone",
                color: .blue
            )
            
            Divider()
            
            infoRow(
                title: "Device ID",
                value: device.id,
                icon: "number",
                color: .gray
            )
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Info Row Component
private func infoRow(title: String, value: String, icon: String, color: Color) -> some View {
    HStack(spacing: 12) {
        Image(systemName: icon)
            .font(.system(size: 16))
            .foregroundColor(color)
            .frame(width: 24)
        
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .lineLimit(1)
        }
        
        Spacer()
    }
}

// MARK: - Fetch User Data
private func fetchUserData() {
    print("🔍 Starting to fetch user data...")
    
    // Get deviceKeyHash from keychain
    let deviceKey = DeviceIdentity.resolve()
    let deviceKeyHash = HMACGenerator.generateHMAC(jsonString: deviceKey)
    print("✅ Device Key Hash resolved: \(deviceKeyHash)")
    
    // Get userId from UserSession
    guard let userId = userSession.currentUser?.userId, !userId.isEmpty else {
        print("❌ No userId found in UserSession")
        return
    }
    print("✅ User ID from session: \(userId)")
    
    Task {
        print("🚀 Calling API to fetch user data...")
        await viewModel.fetch(userId: userId, deviceKeyHash: deviceKeyHash)
        
        // Update UserSession after successful fetch
        if let user = viewModel.user {
            print("✅ Successfully fetched user data")
            updateUserSession(with: user)
        } else {
            print("❌ Failed to fetch user data")
        }
    }
}

// MARK: - Update UserSession
private func updateUserSession(with userData: UserByIdDTO) {
    print("💾 Updating UserSession with fetched data...")
    
    // Update wallet
    userSession.setUserWallet(userData.wallet)
    print("✅ Wallet updated: \(userData.wallet)")
    
    // Update email verification status
    userSession.setEmailVerified(userData.emailVerified)
    print("✅ Email verification status updated: \(userData.emailVerified)")
    
    // Update profile picture
    if let profilePic = userData.profilePic {
        userSession.setProfilePicture(profilePic)
        print("✅ Profile picture updated: \(profilePic)")
    }
    
    // Update device primary status if available
    if let device = viewModel.device {
        userSession.setThisDevicePrimary(device.isPrimary)
        print("✅ Device primary status updated: \(device.isPrimary)")
        
        userSession.setCurrentDeviceID(device.id)
        print("✅ Device ID updated: \(device.id)")
    }
    
    // Create updated User object and save
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

// MARK: - Helper Methods
private func formatDate(_ dateString: String) -> String {
    let isoFormatter = ISO8601DateFormatter()
    if let date = isoFormatter.date(from: dateString) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    return dateString
}
}

#Preview {
    UserDataByIdView()
}


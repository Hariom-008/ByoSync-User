import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State var userSession = UserSession.shared
    @State private var isLoadingUserData: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var alertTitle: String = ""
    @State private var showEditProfile: Bool = false
    @State var openTestinLinkedDeviceView = false
    @State var profilePic: URL?
    @State var openEncryptionSHATesting: Bool = false
    @State var openLocationTestingView: Bool = false
    @State var openSettingView: Bool = false
    @State private var hasLoadedProfilePicture = false // Prevent redundant loads
    
    let getUserData = GetUserDataRepository.shared
    @StateObject var EmailVerifyVM = EmailVerificationViewModel()
    let logOutRepo = LogOutRepository.shared
    @EnvironmentObject private var languageManager: LanguageManager
    
    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                colors: [
                    Color(hex: "F5F7FA"),
                    Color(hex: "E8ECF4")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                   // headerSection
                    profileHeaderCard
                    personalInfoCard
                    menuSection
                }
                .padding(.bottom, 100)
            }
            
            // Simplified loading overlay
            if isLoadingUserData {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "4B548D")))
                                .scaleEffect(1.5)
                            
                            Text(L("refreshing_profile"))
                                .foregroundColor(.primary)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                        )
                    )
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar{
            ToolbarItem(placement: .navigationBarTrailing){
                HStack{
                    Button {
                        openTestinLinkedDeviceView.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "iphone.gen3")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Color(hex: "4B548D"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color(hex: "4B548D").opacity(0.1))
                        )
                    }
                    Button {
                        openSettingView.toggle()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(hex: "4B548D"))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color(hex: "4B548D").opacity(0.1))
                            )
                    }
                }

            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
                .onDisappear {
                    // Reload profile picture only after editing
                    loadProfilePicture()
                }
        }
        .sheet(isPresented: $openTestinLinkedDeviceView) {
            LinkedDevicesView()
        }
        .sheet(isPresented: $openEncryptionSHATesting) {
            EncryptDecryptTestView()
        }
        .sheet(isPresented: $openLocationTestingView) {
            LocationTestView()
        }
        .fullScreenCover(isPresented: $openSettingView) {
            SettingsView()
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button(L("ok"), role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            // Only load once per view lifecycle
            if !hasLoadedProfilePicture {
                loadProfilePicture()
                hasLoadedProfilePicture = true
            }
        }
    }
    // MARK: - Profile Header Card
    private var profileHeaderCard: some View {
        VStack(spacing: 20) {
            // Profile Picture with better styling
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: profilePic) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.6), Color.orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                            )
                            .shadow(color: Color(hex: "4B548D").opacity(0.3), radius: 15, y: 8)
                    case .failure:
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }

                // Verified badge
                if UserSession.shared.isEmailVerified {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 36, height: 36)
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                        
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.green, Color.green.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .offset(x: 8, y: 8)
                }
            }
            .padding(.top, 8)
            
            // User Info
            VStack(spacing: 8) {
                Text("\(userSession.currentUser?.firstName ?? "User") \(userSession.currentUser?.lastName ?? "Name")")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("\(userSession.currentUser?.email ?? "email@example.com")")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("\(userSession.currentUser?.phoneNumber ?? "No phone")")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Edit Profile Button
            Button {
                showEditProfile = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 16))
                    Text(L("edit_profile"))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "4B548D"), Color(hex: "5B64A0")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
                .shadow(color: Color(hex: "4B548D").opacity(0.4), radius: 12, y: 6)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 20, y: 8)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Personal Info Card
    private var personalInfoCard: some View {
        VStack(spacing: 24) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text(L("user_section"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            
            VStack(spacing: 16) {
                ProfileInfoRow(
                    icon: "person.fill",
                    label: L("first_name"),
                    value: userSession.currentUser?.firstName ?? "N/A",
                    iconColor: Color(hex: "4B548D")
                )
                
                Divider()
                    .padding(.leading, 60)
                
                ProfileInfoRow(
                    icon: "person.fill",
                    label: L("last_name"),
                    value: userSession.currentUser?.lastName ?? "N/A",
                    iconColor: Color(hex: "6B74A8")
                )
                
                Divider()
                    .padding(.leading, 60)
                
                ProfileInfoRow(
                    icon: "envelope.fill",
                    label: L("email_address"),
                    value: userSession.currentUser?.email ?? "N/A email",
                    iconColor: Color.blue
                )
                
                Divider()
                    .padding(.leading, 60)
                
                ProfileInfoRow(
                    icon: "phone.fill",
                    label: L("phone_number"),
                    value: userSession.currentUser?.phoneNumber ?? "N/A phone",
                    iconColor: Color.green
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 20, y: 8)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Menu Section
    private var menuSection: some View {
        VStack(spacing: 16) {
            // Slide to Logout
            SlideToLogoutButton(
                isDisabled: userSession.thisDeviceIsPrimary
            ) {
                performLogout()
            }
            
            if userSession.thisDeviceIsPrimary {
                HStack{
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 13,weight: .bold))
                        .foregroundStyle(.red)
                    Text("Cannot log out from primary device")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: - Logout Handler (optimized)
    private func performLogout() {
        // Perform logout on background thread
        Task {
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    logOutRepo.logOut { result in
                        switch result {
                        case .success:
                            continuation.resume()
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                }
                
                // Success - update UI on main thread
                await MainActor.run {
                    print("✅ User logged out successfully")
                    UserSession.shared.clearUser()
                    UserDefaults.standard.removeObject(forKey: "token")
                }
            } catch {
                await MainActor.run {
                    print("❌ Logout failed: \(error.localizedDescription)")
                    alertTitle = "Error"
                    alertMessage = "Logout failed: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
    
    // MARK: - Fetch User Data
    private func fetchUserData() {
        isLoadingUserData = true
        
        getUserData.getUserData { result in
            DispatchQueue.main.async {
                isLoadingUserData = false
                
                switch result {
                case .success(let response):
                    alertTitle = L("success")
                    alertMessage = """
                    \(L("profile_refreshed"))

                    Name: \(response.data?.user.firstName ?? "nil") \(response.data?.user.lastName ?? "nil")
                    Email: \(response.data?.user.email ?? "nil email")
                    Phone: \(response.data?.user.phoneNumber ?? "nil phone")
                    """
                    showAlert = true
                    
                    // Reload profile picture after data refresh
                    loadProfilePicture()
                    
                case .failure(let error):
                    alertTitle = L("error_refresh")
                    alertMessage = "\(L("refresh_failed"))\n\(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
    
    private func loadProfilePicture() {
        if let url = URL(string: UserSession.shared.userProfilePicture),
           !UserSession.shared.userProfilePicture.isEmpty {
            profilePic = url
            print("✅ Loaded profile picture URL: \(url)")
        } else {
            profilePic = nil
            print("⚠️ No valid profile picture URL found.")
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}

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
    
    let getUserData = GetUserDataRepository.shared
    @StateObject var EmailVerifyVM = EmailVerificationViewModel()
    let logOutRepo = LogOutRepository.shared
    @EnvironmentObject private var languageManager: LanguageManager
    
    var body: some View {
        ZStack {
            Color(hex: "F5F7FA")
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerSection
                    profileHeaderCard
                    personalInfoCard
                    menuSection
                }
                .padding(.bottom, 100)
            }
            
            // Loading overlay
            if isLoadingUserData {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "4B548D")))
                                .scaleEffect(1.5)
                            
                            Text(L("refreshing_profile"))
                                .foregroundColor(.primary)
                                .font(.system(size: 16, weight: .medium))
                        }
                        .padding(30)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
                        )
                    )
                    .zIndex(100)
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
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
            loadProfilePicture()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                    .padding(10)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            }
            
            Spacer()
            
            Text(L("profile_title"))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Spacer()
            
            Menu {
                Button {
                    openTestinLinkedDeviceView.toggle()
                } label: {
                    Label(L("linked_devices"), systemImage: "iphone")
                }

                Button {
                    openSettingView.toggle()
                } label: {
                    Label(L("settings"), systemImage: "gear")
                }

            } label: {
                Label(L("more"), systemImage: "ellipsis.circle")
                    .font(.headline)
                    .foregroundStyle(.black)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Profile Header Card
    private var profileHeaderCard: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: profilePic) { phase in
                    switch phase {
                    case .empty:
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.orange)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    case .failure:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                }

                if UserSession.shared.isEmailVerified {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                    }
                    .offset(x: 5, y: 5)
                }
            }
            
            VStack(spacing: 6) {
                Text("\(userSession.currentUser?.firstName ?? "Nil") \(userSession.currentUser?.lastName ?? "Nil")")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("\(userSession.currentUser?.email ?? "No email")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(userSession.currentUser?.phoneNumber ?? "No phone")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button {
                showEditProfile = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                        .font(.caption)
                    Text(L("edit_profile"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(Color(hex: "4B548D"))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(hex: "4B548D").opacity(0.1))
                .cornerRadius(20)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Personal Info Card
    private var personalInfoCard: some View {
        VStack(spacing: 16) {
            HStack {
                Label(L("user_section"), systemImage: "person.text.rectangle")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                ProfileInfoRow(
                    icon: "person.fill",
                    label: L("first_name"),
                    value: userSession.currentUser?.firstName ?? "N/A"
                )
                
                Divider()
                
                ProfileInfoRow(
                    icon: "person.fill",
                    label: L("last_name"),
                    value: userSession.currentUser?.lastName ?? "N/A"
                )
                
                Divider()
                
                ProfileInfoRow(
                    icon: "envelope.fill",
                    label: L("email_address"),
                    value: userSession.currentUser?.email ?? "N/A email"
                )
                
                Divider()
                
                ProfileInfoRow(
                    icon: "phone.fill",
                    label: L("phone_number"),
                    value: userSession.currentUser?.phoneNumber ?? "N/A phone"
                )
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Menu Section
    private var menuSection: some View {
        VStack(spacing: 18) {
            VStack(spacing: 12) {
                MenuOptionRow(
                    icon: "info.circle.fill",
                    title: L("testing_encryption"),
                    color: .cyan
                ) {
                    openEncryptionSHATesting.toggle()
                }
                MenuOptionRow(
                    icon: "info.circle.fill",
                    title: L("location_testing"),
                    color: .cyan
                ) {
                    openLocationTestingView.toggle()
                }
            }
            
            Button {
                logOutRepo.logOut { result in
                    switch result {
                    case .success:
                        print("✅ User logged out successfully")
                        DispatchQueue.main.async {
                            UserSession.shared.clearUser()
                            UserDefaults.standard.removeObject(forKey: "token")
                        }
                    case .failure(let error):
                        print("❌ Logout failed: \(error.localizedDescription)")
                    }
                }
            } label: {
                Text(L("log_out"))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.red)
            }
            .foregroundStyle(userSession.thisDeviceIsPrimary ? .gray : .red)
            .disabled(userSession.thisDeviceIsPrimary)
            .padding(.top, 20)
        }
        .padding(.horizontal, 20)
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

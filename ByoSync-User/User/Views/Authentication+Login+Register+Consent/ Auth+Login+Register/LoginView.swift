import SwiftUI
import Foundation

struct LoginView: View {
    @EnvironmentObject var cryptoManager: CryptoManager
    @StateObject private var viewModel: LoginViewModel
    @State private var navigateToNextScreen: NavigationStep?
    @Environment(\.dismiss) var dismiss
    
    // ✅ Make enum conform to Identifiable
    enum NavigationStep: Identifiable {
        case userConsent
        case mainTab
        
        var id: String {
            switch self {
            case .userConsent: return "userConsent"
            case .mainTab: return "mainTab"
            }
        }
    }
    
    init() {
        let tempCrypto = CryptoManager()
        self._viewModel = StateObject(wrappedValue: LoginViewModel(cryptoService: tempCrypto))
    }
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            Circle()
                .fill(Color(hex: "4B548D").opacity(0.03))
                .frame(width: 600, height: 600)
                .blur(radius: 80)
                .offset(y: -200)
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 16) {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 34, height: 34)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(.leading, 20)
                    .padding(.vertical, 20)
                    
                    ZStack {
                        Circle()
                            .fill(Color(hex: "4B548D"))
                            .frame(width: 85, height: 85)
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 42))
                            .foregroundColor(.white)
                    }
                    .shadow(color: Color(hex: "4B548D").opacity(0.25), radius: 16, x: 0, y: 8)
                    .padding(.bottom, 4)
                    
                    Text(L("welcome_back"))
                        .font(.system(size: 32, weight: .bold))
                    Text(L("enter_credentials"))
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 50)
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L("full_name"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(.leading, 4)
                        
                        HStack(spacing: 14) {
                            Image(systemName: "person.fill")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            TextField("", text: $viewModel.name, prompt:
                                Text(L("enter_full_name"))
                                    .foregroundColor(.secondary.opacity(0.5))
                            )
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                    .frame(maxWidth: 340)
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                Button {
                    print("🔘 [VIEW] Login button tapped")
                    Task {
                        FCMTokenManager.shared.getFCMToken { token in
                            guard let token else {
                                print("⚠️ [VIEW] No FCM token available")
                                return
                            }
                            print("🔔 [VIEW] FCM token received")
                            viewModel.fcmToken = token
                        }
                        
                        await viewModel.login()
                    }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Logging in...")
                                .font(.system(size: 17, weight: .semibold))
                        } else {
                            Text(L("continue"))
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: 340, minHeight: 54)
                    .background(Color(hex: "4B548D"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isLoading)
                .padding(.bottom, 32)
                
                HStack(spacing: 6) {
                    Text(L("powered_by"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                    Text("Kavion")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 28)
            }
        }
        .alert(L("login_failed"), isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {
                print("⚠️ [VIEW] Error alert dismissed")
            }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onChange(of: viewModel.loginSuccess) { oldValue, newValue in
            if newValue {
                print("✅ [VIEW] Login successful, navigating to main tab")
                navigateToNextScreen = .mainTab
            }
        }
        // ✅ Now this will work because NavigationStep is Identifiable
        .fullScreenCover(item: $navigateToNextScreen) { step in
            switch step {
            case .userConsent:
                Text("User Consent View")
                    .environmentObject(cryptoManager)
                
            case .mainTab:
                MainTabView()
                    .environmentObject(cryptoManager)
            }
        }
        .onAppear {
            print("👀 [VIEW] LoginView appeared")
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(CryptoManager())
}

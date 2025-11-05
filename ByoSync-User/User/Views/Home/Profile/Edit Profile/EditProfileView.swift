
import Foundation
import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @StateObject private var viewModel = UpdateProfileViewModel()
    @StateObject private var pictureViewModel = ProfilePictureViewModel()
    @State private var selectedItem: PhotosPickerItem? = nil
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    // MARK: - Profile Picture Section
                    Section(L("edit_profile.profile_picture")) {
                        VStack(spacing: 16) {
                            // 1️⃣ Current or selected image
                            if let image = pictureViewModel.selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .shadow(radius: 6)
                            } else if let url = URL(string: UserSession.shared.userProfilePicture),
                                      !UserSession.shared.userProfilePicture.isEmpty {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                    case .failure:
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 120, height: 120)
                                            .foregroundColor(.gray.opacity(0.4))
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 120)
                                    .foregroundColor(.gray.opacity(0.4))
                            }
                            
                            // 2️⃣ Select new photo
                            PhotosPicker(L("edit_profile.choose_photo"), selection: $selectedItem, matching: .images)
                                .onChange(of: selectedItem) { newItem in
                                    Task {
                                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                                           let uiImage = UIImage(data: data) {
                                            pictureViewModel.selectedImage = uiImage
                                        }
                                    }
                                }
                            
                            // 3️⃣ Upload and update backend
                            Button{
                                pictureViewModel.uploadAndSaveProfilePicture()
                                // Update the UserSession
                                UserSession.shared.setProfilePicture(pictureViewModel.uploadedUrl ?? "")
                                print("✅ User Profile Picture is saved in UserSession.\(pictureViewModel.uploadedUrl ?? "")")
                            }label:{
                                Text(L("edit_profile.save_new_picture"))
                                    .padding()
                                    .foregroundStyle(.white)
                                    .font(.caption)
                                    .background(
                                        RoundedRectangle(cornerRadius: 24)
                                            .fill(Color(hex: "4B548D"))
                                    )
                            }
                            .disabled(pictureViewModel.updateState == .updating)
                            
                            // 4️⃣ Feedback
                            switch pictureViewModel.updateState {
                            case .idle:
                                EmptyView()
                            case .updating:
                                ProgressView(L("edit_profile.uploading"))
                            case .success(let message):
                                Text("✅ \(message)").foregroundColor(.green)
                            case .error(let error):
                                Text("❌ \(error)").foregroundColor(.red)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 10)
                    }
                    
                    // MARK: - Personal Information Section
                    Section(L("edit_profile.personal_information")) {
                        EditFieldRow(
                            icon: "person.fill",
                            label: L("edit_profile.first_name"),
                            text: $viewModel.firstName
                        )
                        
                        EditFieldRow(
                            icon: "person.fill",
                            label: L("edit_profile.last_name"),
                            text: $viewModel.lastName
                        )
                        
                        EditFieldRow(
                            icon: "envelope.fill",
                            label: L("edit_profile.email"),
                            text: $viewModel.email,
                            keyboardType: .emailAddress
                        )
                    }
                    
                    // MARK: - Update Button
                    Section {
                        Button(action: {
                            viewModel.updateProfile()
                        }) {
                            HStack {
                                Spacer()
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                } else {
                                    Text(L("edit_profile.save_changes"))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color(hex: "4B548D"))
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .disabled(viewModel.isLoading)
                
                // MARK: - Loading Overlay
                if viewModel.isLoading {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text(L("edit_profile.updating"))
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                    }
                    .padding(24)
                    .background(Color(hex: "4B548D"))
                    .cornerRadius(16)
                }
            }
            .navigationTitle(L("edit_profile.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("edit_profile.cancel")) {
                        dismiss()
                    }
                }
            }
            .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
                Button(L("edit_profile.ok"), role: .cancel) {
                    if viewModel.isSuccess {
                        dismiss()
                    }
                }
            } message: {
                Text(viewModel.alertMessage)
            }
            .onAppear {
                viewModel.firstName = UserSession.shared.currentUser?.firstName ?? "Nil"
                viewModel.lastName = UserSession.shared.currentUser?.lastName ?? "Nil"
                viewModel.email = UserSession.shared.currentUser?.email ?? "Nil Email"
            }
        }
    }
}

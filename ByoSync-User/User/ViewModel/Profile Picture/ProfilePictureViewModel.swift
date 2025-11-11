//
//  ProfilePictureViewModel.swift
//  ByoSync
//
//  Created by Hari's Mac on 23.10.2025.
//

import Foundation
import SwiftUI
import PhotosUI
import Combine

@MainActor
final class ProfilePictureViewModel: ObservableObject {
    @Published var updateState: ProfileUpdateState = .idle
    @Published var selectedImage: UIImage? = nil
    @Published var uploadedUrl : String?
    
    private let repository: ProfilePictureRepositoryProtocol
    private let cloudinary = CloudinaryManager.shared
    
    init(repository: ProfilePictureRepositoryProtocol = ProfilePictureRepository()) {
        self.repository = repository
    }
    func uploadAndSaveProfilePicture() {
        guard let image = selectedImage else {
            updateState = .error("No image selected.")
            return
        }

        updateState = .updating

        Task {
            do {
                // Step 1: Upload to Cloudinary
                uploadedUrl = try await cloudinary.uploadImage(image)
                
                // Step 2: Save URL based on the current session (User or Merchant)
                if let _ = UserSession.shared.currentUser {
                    // For User
                    UserSession.shared.setProfilePicture(uploadedUrl ?? "")
                }
                // Step 3: Update backend with the new URL
                let message = try await repository.changeProfilePicture(imageUrl: uploadedUrl ?? "")

                // Step 4: Update state for UI feedback
                updateState = .success(message)
                print("✅ Profile picture updated and saved: \(uploadedUrl ?? "no profilePicture")")
                
            } catch let error as APIError {
                updateState = .error(error.localizedDescription)
            } catch {
                updateState = .error("Unexpected error: \(error.localizedDescription)")
            }
        }
    }
}

enum ProfileUpdateState:Equatable{
    case idle
    case updating
    case success(String)
    case error(String)
}

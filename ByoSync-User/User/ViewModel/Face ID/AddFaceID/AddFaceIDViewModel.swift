//
//  AddFaceIDViewModel.swift
//  ByoSync-User
//

import Foundation
import Combine

/// ViewModel responsible for managing FaceId upload state
final class FaceIdViewModel: ObservableObject {

    // MARK: - Published UI State
    @Published var isUploading: Bool = false
    @Published var uploadSuccess: Bool = false

    @Published var showError: Bool = false
    @Published var errorMessage: String? = nil

    // Debug info
    @Published var lastSalt: String? = nil
    @Published var lastToken: String? = nil
    @Published var lastUploadedCount: Int = 0

    // MARK: - Dependencies
    private let repository: FaceIdRepository

    // MARK: - Init
    init(repository: FaceIdRepository = .shared) {
        self.repository = repository
    }
}

// MARK: - PUBLIC API
extension FaceIdViewModel {

    /// Upload a **single** FaceId (wraps into array for backend)
    func uploadSingleFaceId(
        helper: String,
        k2: String,
        token: String,
        salt: String
    ) {
        let item = AddFaceIdRequestBody(helper: helper, k2: k2, token: token)

        // Debug fields
        lastToken = token
        lastSalt = salt

        Logger.shared.d("FACEID_UPLOAD", "uploadSingleFaceId invoked", user: UserSession.shared.currentUser?.userId)

        uploadFaceIdList(salt: salt, list: [item])
    }

    /// Upload **multiple** FaceId records (e.g., 80 enrollment frames)
    func uploadFaceIdList(
        salt: String,
        list: [AddFaceIdRequestBody]
    ) {
        guard !isUploading else {
            Logger.shared.d("FACEID_UPLOAD", "Skipped: already uploading", user: UserSession.shared.currentUser?.userId)
            return
        }

        // Reset UI state
        isUploading = true
        uploadSuccess = false
        errorMessage = nil
        showError = false

        lastSalt = salt
        lastUploadedCount = list.count

        let userId = UserSession.shared.currentUser?.userId
        let startTime = CFAbsoluteTimeGetCurrent()

        #if DEBUG
        print("\n📤 [FaceIdViewModel] Uploading FaceId list…")
        print("📤 Count: \(list.count)")
        print("📤 Salt: \(salt)")
        #endif

        Logger.shared.i(
            "FACEID_UPLOAD",
            "Upload start | count=\(list.count)",
            user: userId
        )

        repository.addFaceIds(
            salt: salt,
            records: list
        ) { [weak self] result in
            guard let self else { return }

            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)

            DispatchQueue.main.async {
                self.isUploading = false

                switch result {
                case .success:
                    #if DEBUG
                    print("✅ [FaceIdViewModel] FaceId list upload success")
                    #endif

                    self.uploadSuccess = true

                    Logger.shared.i(
                        "FACEID_UPLOAD",
                        "Upload success | count=\(list.count)",
                        timeTakenMs: elapsedMs,
                        user: userId
                    )

                case .failure(let error):
                    #if DEBUG
                    print("❌ [FaceIdViewModel] Upload failed: \(error)")
                    #endif

                    self.uploadSuccess = false
                    self.errorMessage = Self.mapError(error)
                    self.showError = true

                    Logger.shared.e(
                        "FACEID_UPLOAD",
                        "Upload failed | count=\(list.count) | msg=\(self.errorMessage ?? "unknown")",
                        error: error,
                        timeTakenMs: elapsedMs,
                        user: userId
                    )
                }
            }
        }
    }

    /// Reset flags after UI dismisses banners/alerts
    func resetState() {
        uploadSuccess = false
        showError = false
        errorMessage = nil

        Logger.shared.d("FACEID_UPLOAD", "resetState()", user: UserSession.shared.currentUser?.userId)
    }
}

// MARK: - Helper
extension FaceIdViewModel {
    private static func mapError(_ error: APIError) -> String {
        return "\(error)"
    }
}

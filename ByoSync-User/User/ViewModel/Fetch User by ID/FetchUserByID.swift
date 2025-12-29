import Foundation
import Combine

final class FaceIdFetchViewModel: ObservableObject {

    // MARK: - Published State (for UI)

    /// Full payload from backend (salt + faceData)
    @Published var faceIdData: GetFaceIdData?

    /// Convenience: just the FaceId list (for UI)
    @Published var faceIds: [FaceId] = []

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var hasLoadedOnce: Bool = false

    /// Avoid duplicate parallel requests
    @Published var isRequestInFlight: Bool = false

    // MARK: - Dependencies
    private let repository: FaceIdFetchRepository

    // MARK: - Init
    init(repository: FaceIdFetchRepository = .shared) {
        self.repository = repository
    }

    // MARK: - Public API (UI-driven)

    /// UI-style API (no completion, just updates @Published)
    func fetchFaceIds() {
        let userId = UserSession.shared.currentUser?.userId
        let deviceKey = DeviceIdentity.resolve()

        guard !deviceKey.isEmpty else {
            setError("Missing device key")
            Logger.shared.e("FACEID_FETCH", "Missing device key", user: userId)
            return
        }

        if isRequestInFlight {
            #if DEBUG
            print("⚠️ [FaceIdFetchViewModel] Request already in flight, ignoring duplicate call")
            #endif
            Logger.shared.d("FACEID_FETCH", "Duplicate fetch ignored (in-flight)", user: userId)
            return
        }

        #if DEBUG
        print("🚀 [FaceIdFetchViewModel] Starting fetchFaceIds() for deviceKey length: \(deviceKey.count)")
        #endif

        isLoading = true
        isRequestInFlight = true
        errorMessage = nil
        showError = false

        Logger.shared.i("FACEID_FETCH", "Fetch start", user: userId)
        let startTime = CFAbsoluteTimeGetCurrent()

        repository.getFaceIds(deviceKey: deviceKey) { [weak self] result in
            guard let self else { return }

            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)

            DispatchQueue.main.async {
                self.isLoading = false
                self.isRequestInFlight = false
                self.hasLoadedOnce = true

                switch result {
                case .success(let data):
                    #if DEBUG
                    print("✅ [FaceIdFetchViewModel] Successfully fetched FaceId data")
                    print("   • salt: \(data.salt)")
                    print("   • faceData count: \(data.faceData.count)")
                    #endif

                    self.faceIdData = data
                    self.faceIds = data.faceData

                    Logger.shared.i(
                        "FACEID_FETCH",
                        "Fetch success | count=\(data.faceData.count)",
                        timeTakenMs: elapsedMs,
                        user: userId
                    )

                case .failure(let error):
                    #if DEBUG
                    print("❌ [FaceIdFetchViewModel] Failed: \(error)")
                    #endif

                    let message = (error as? LocalizedError)?.errorDescription
                        ?? error.localizedDescription
                    self.setError(message)

                    Logger.shared.e(
                        "FACEID_FETCH",
                        "Fetch failed | msg=\(message)",
                        error: error,
                        timeTakenMs: elapsedMs,
                        user: userId
                    )
                }
            }
        }
    }

    /// Completion-based API for non-UI callers (e.g. FaceManager)
    func fetchFaceIds(
        completion: @escaping (Result<GetFaceIdData, Error>) -> Void
    ) {
        let userId = UserSession.shared.currentUser?.userId
        let deviceKey = DeviceIdentity.resolve()

        guard !deviceKey.isEmpty else {
            let err = NSError(
                domain: "FaceIdFetchViewModel",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Missing device key"]
            )
            setError("Missing device key")

            Logger.shared.e("FACEID_FETCH", "Missing device key (completion)", error: err, user: userId)
            completion(.failure(err))
            return
        }

        if isRequestInFlight {
            #if DEBUG
            print("⚠️ [FaceIdFetchViewModel] Request already in flight, ignoring duplicate call")
            #endif

            Logger.shared.d("FACEID_FETCH", "Duplicate fetch ignored (completion, in-flight)", user: userId)

            // Return cached value if available
            if let cached = faceIdData {
                completion(.success(cached))
            } else {
                let err = NSError(
                    domain: "FaceIdFetchViewModel",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Request already in flight"]
                )
                Logger.shared.e("FACEID_FETCH", "In-flight and no cache (completion)", error: err, user: userId)
                completion(.failure(err))
            }
            return
        }

        #if DEBUG
        print("🚀 [FaceIdFetchViewModel] (completion) Starting fetchFaceIds() for deviceKey length: \(deviceKey.count)")
        #endif

        isLoading = true
        isRequestInFlight = true
        errorMessage = nil
        showError = false

        Logger.shared.i("FACEID_FETCH", "Fetch start (completion)", user: userId)
        let startTime = CFAbsoluteTimeGetCurrent()

        repository.getFaceIds(deviceKey: deviceKey) { [weak self] result in
            guard let self else { return }

            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)

            DispatchQueue.main.async {
                self.isLoading = false
                self.isRequestInFlight = false
                self.hasLoadedOnce = true

                switch result {
                case .success(let data):
                    #if DEBUG
                    print("✅ [FaceIdFetchViewModel] (completion) Successfully fetched FaceId data")
                    print("   • salt: \(data.salt)")
                    print("   • faceData count: \(data.faceData.count)")
                    #endif

                    self.faceIdData = data
                    self.faceIds = data.faceData

                    Logger.shared.i(
                        "FACEID_FETCH",
                        "Fetch success (completion) | count=\(data.faceData.count)",
                        timeTakenMs: elapsedMs,
                        user: userId
                    )

                    completion(.success(data))

                case .failure(let error):
                    #if DEBUG
                    print("❌ [FaceIdFetchViewModel] (completion) Failed: \(error)")
                    #endif

                    let message = (error as? LocalizedError)?.errorDescription
                        ?? error.localizedDescription
                    self.setError(message)

                    Logger.shared.e(
                        "FACEID_FETCH",
                        "Fetch failed (completion) | msg=\(message)",
                        error: error,
                        timeTakenMs: elapsedMs,
                        user: userId
                    )

                    completion(.failure(error))
                }
            }
        }
    }

    /// Convenience for clearing current state (e.g. on logout)
    func resetState() {
        #if DEBUG
        print("🧹 [FaceIdFetchViewModel] Resetting state")
        #endif

        faceIdData = nil
        faceIds = []
        isLoading = false
        isRequestInFlight = false
        hasLoadedOnce = false
        errorMessage = nil
        showError = false

        Logger.shared.d("FACEID_FETCH", "resetState()", user: UserSession.shared.currentUser?.userId)
    }

    // MARK: - Private

    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

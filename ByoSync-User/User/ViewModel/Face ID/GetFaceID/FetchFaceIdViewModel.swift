import Foundation
import Combine

final class FaceIdFetchViewModel: ObservableObject {
    
        static let shared = FaceIdFetchViewModel()
    
    // MARK: - Published State (for UI)
    
    /// Full payload from backend (salt + faceData)
    @Published var faceIdData: GetFaceIdData?
    
    /// Convenience: just the FaceId list (for UI)
    @Published var faceIds: [FaceId] = []
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var hasLoadedOnce: Bool = false
    
    // Optional: if you want to know that request is in-flight and avoid duplicates
    @Published var isRequestInFlight: Bool = false
    
    // Track if data is from local storage or API
    @Published var isUsingLocalData: Bool = false
    
    // MARK: - Dependencies
    
    private let repository: FaceIdFetchRepository
    private let storageManager: FaceIdStorageManager
    
    // MARK: - Init
    
    init(repository: FaceIdFetchRepository = .shared,
         storageManager: FaceIdStorageManager = .shared) {
        self.repository = repository
        self.storageManager = storageManager
    }
    
    // MARK: - Public API (Smart Fetch with Local Storage)
    
    /// Smart fetch: Check local storage first, only fetch from API if needed
    /// - Parameters:
    ///   - hasFaceData: Flag from backend indicating if user has enrolled face data
    ///   - forceRefresh: Force API call even if local data exists
    func fetchFaceIds(hasFaceData: Bool, forceRefresh: Bool = false) {
        let deviceKey = DeviceIdentity.resolve()
        guard !deviceKey.isEmpty else {
            setError("Missing device key")
            return
        }
        
        print("🔍 [FaceIdFetchViewModel] fetchFaceIds called")
        print("   • hasFaceData: \(hasFaceData)")
        print("   • forceRefresh: \(forceRefresh)")
        print("   • deviceKey length: \(deviceKey.count)")
        
        // CASE 1: hasFaceData is FALSE -> Delete local data and return
        if !hasFaceData {
            print("⚠️ [FaceIdFetchViewModel] hasFaceData=false -> Deleting local storage")
            storageManager.deleteAllFaceData()
            resetState()
            return
        }
        
        // Avoid duplicate requests
        if isRequestInFlight {
            print("⚠️ [FaceIdFetchViewModel] Request already in flight, ignoring duplicate call")
            return
        }
        
        // CASE 2: hasFaceData is TRUE -> Check local storage first
        if !forceRefresh {
            if let localData = storageManager.loadFaceData(for: deviceKey) {
                print("✅ [FaceIdFetchViewModel] Using local FaceId data (skipping API call)")
                print("   • salt: \(localData.salt)")
                print("   • faceData count: \(localData.faceData.count)")
                
                DispatchQueue.main.async { [weak self] in
                    self?.faceIdData = localData
                    self?.faceIds = localData.faceData
                    self?.isUsingLocalData = true
                    self?.hasLoadedOnce = true
                }
                return
            } else {
                print("📭 [FaceIdFetchViewModel] No local data found -> Fetching from API")
            }
        } else {
            print("🔄 [FaceIdFetchViewModel] Force refresh requested -> Fetching from API")
        }
        
        // CASE 3: Fetch from API
        fetchFromAPI(deviceKey: deviceKey)
    }
    
    // MARK: - Completion-based API (for FaceManager)
    
    /// Completion-based fetch with local storage support
    func fetchFaceIds(
        hasFaceData: Bool,
        forceRefresh: Bool = false,
        completion: @escaping (Result<GetFaceIdData, Error>) -> Void
    ) {
        let deviceKey = DeviceIdentity.resolve()
        guard !deviceKey.isEmpty else {
            let err = NSError(
                domain: "FaceIdFetchViewModel",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Missing device key"]
            )
            setError("Missing device key")
            completion(.failure(err))
            return
        }
        
        print("🔍 [FaceIdFetchViewModel] fetchFaceIds (completion) called")
        print("   • hasFaceData: \(hasFaceData)")
        print("   • forceRefresh: \(forceRefresh)")
        print("   • deviceKey length: \(deviceKey.count)")
        
        // CASE 1: hasFaceData is FALSE -> Delete local data and fail
        if !hasFaceData {
            print("⚠️ [FaceIdFetchViewModel] hasFaceData=false -> Deleting local storage")
            storageManager.deleteAllFaceData()
            resetState()
            
            let err = NSError(
                domain: "FaceIdFetchViewModel",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "No face data available - enrollment required"]
            )
            completion(.failure(err))
            return
        }
        
        // Avoid duplicate requests
        if isRequestInFlight {
            print("⚠️ [FaceIdFetchViewModel] Request already in flight")
            if let cached = faceIdData {
                print("📦 [FaceIdFetchViewModel] Returning cached data")
                completion(.success(cached))
            } else {
                let err = NSError(
                    domain: "FaceIdFetchViewModel",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "Request already in flight"]
                )
                completion(.failure(err))
            }
            return
        }
        
        // CASE 2: hasFaceData is TRUE -> Check local storage first
        if !forceRefresh {
            if let localData = storageManager.loadFaceData(for: deviceKey) {
                print("✅ [FaceIdFetchViewModel] Using local FaceId data (skipping API call)")
                print("   • salt: \(localData.salt)")
                print("   • faceData count: \(localData.faceData.count)")
                
                DispatchQueue.main.async { [weak self] in
                    self?.faceIdData = localData
                    self?.faceIds = localData.faceData
                    self?.isUsingLocalData = true
                    self?.hasLoadedOnce = true
                }
                
                completion(.success(localData))
                return
            } else {
                print("📭 [FaceIdFetchViewModel] No local data found -> Fetching from API")
            }
        } else {
            print("🔄 [FaceIdFetchViewModel] Force refresh requested -> Fetching from API")
        }
        
        // CASE 3: Fetch from API
        fetchFromAPI(deviceKey: deviceKey, completion: completion)
    }
    
    // MARK: - Private Fetch Methods
    
    private func fetchFromAPI(deviceKey: String, completion: ((Result<GetFaceIdData, Error>) -> Void)? = nil) {
        print("🌐 [FaceIdFetchViewModel] Fetching FaceId data from API...")
        
        isLoading = true
        isRequestInFlight = true
        isUsingLocalData = false
        errorMessage = nil
        showError = false
        
        repository.getFaceIds(deviceKey: deviceKey) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isLoading = false
                self.isRequestInFlight = false
                self.hasLoadedOnce = true
                
                switch result {
                case .success(let data):
                    print("✅ [FaceIdFetchViewModel] API fetch successful")
                    print("   • salt: \(data.salt)")
                    print("   • faceData count: \(data.faceData.count)")
                    
                    // Update in-memory state
                    self.faceIdData = data
                    self.faceIds = data.faceData
                    
                    // Save to local storage
                    self.storageManager.saveFaceData(data, deviceKey: deviceKey)
                    
                    completion?(.success(data))
                    
                case .failure(let error):
                    print("❌ [FaceIdFetchViewModel] API fetch failed: \(error)")
                    let message = (error as? LocalizedError)?.errorDescription
                        ?? error.localizedDescription
                    self.setError(message)
                    
                    completion?(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Check if local data exists without loading it
    func hasLocalData(for deviceKey: String? = nil) -> Bool {
        let key = deviceKey ?? DeviceIdentity.resolve()
        return storageManager.hasLocalData(for: key)
    }
    
    /// Delete local storage (e.g., on logout or re-enrollment)
    func clearLocalStorage() {
        print("🗑️ [FaceIdFetchViewModel] Clearing local storage")
        storageManager.deleteAllFaceData()
        resetState()
    }
    
    /// Convenience for clearing current state (e.g. on logout)
    func resetState() {
        print("🧹 [FaceIdFetchViewModel] Resetting state")
        faceIdData = nil
        faceIds = []
        isLoading = false
        isRequestInFlight = false
        isUsingLocalData = false
        hasLoadedOnce = false
        errorMessage = nil
        showError = false
    }
    
    // MARK: - Private
    
    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

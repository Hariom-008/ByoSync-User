import Foundation
import SwiftData

// MARK: - FaceId Local Storage Manager
final class FaceIdStorageManager {
    static let shared = FaceIdStorageManager()
    
    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?
    
    private init() {
        setupModelContainer()
    }
    
    private func setupModelContainer() {
        do {
            let schema = Schema([FaceIdLocalStore.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            modelContext = ModelContext(modelContainer!)
            print("✅ [FaceIdStorageManager] Model container initialized")
        } catch {
            print("❌ [FaceIdStorageManager] Failed to setup model container: \(error)")
        }
    }
    
    // MARK: - Save to Local Storage
    func saveFaceData(_ data: GetFaceIdData, deviceKey: String) {
        guard let context = modelContext else {
            print("❌ [FaceIdStorageManager] No model context available")
            return
        }
        
        print("💾 [FaceIdStorageManager] Saving FaceId data to local storage...")
        print("   • salt: \(data.salt)")
        print("   • faceData count: \(data.faceData.count)")
        print("   • deviceKey: \(deviceKey)")
        
        do {
            // Delete existing record first (singleton pattern)
            let descriptor = FetchDescriptor<FaceIdLocalStore>()
            let existing = try context.fetch(descriptor)
            
            for record in existing {
                context.delete(record)
                print("🗑️ [FaceIdStorageManager] Deleted old FaceId record")
            }
            
            // Create new record
            guard let newStore = FaceIdLocalStore.create(from: data, deviceKey: deviceKey) else {
                print("❌ [FaceIdStorageManager] Failed to create FaceIdLocalStore")
                return
            }
            
            context.insert(newStore)
            try context.save()
            
            print("✅ [FaceIdStorageManager] Successfully saved FaceId data locally")
            
        } catch {
            print("❌ [FaceIdStorageManager] Failed to save: \(error)")
        }
    }
    
    // MARK: - Load from Local Storage
    func loadFaceData(for deviceKey: String) -> GetFaceIdData? {
        guard let context = modelContext else {
            print("❌ [FaceIdStorageManager] No model context available")
            return nil
        }
        
        print("📂 [FaceIdStorageManager] Loading FaceId data from local storage...")
        print("   • deviceKey: \(deviceKey)")
        
        do {
            let descriptor = FetchDescriptor<FaceIdLocalStore>()
            let stores = try context.fetch(descriptor)
            
            guard let store = stores.first else {
                print("⚠️ [FaceIdStorageManager] No local FaceId data found")
                return nil
            }
            
            // Check if deviceKey matches
            guard store.deviceKey == deviceKey else {
                print("⚠️ [FaceIdStorageManager] DeviceKey mismatch - stored: \(store.deviceKey), current: \(deviceKey)")
                print("🗑️ [FaceIdStorageManager] Deleting mismatched data")
                deleteAllFaceData()
                return nil
            }
            
            guard let faceData = store.getFaceData() else {
                print("❌ [FaceIdStorageManager] Failed to decode faceData")
                return nil
            }
            
            print("✅ [FaceIdStorageManager] Successfully loaded FaceId data from local storage")
            print("   • salt: \(store.salt)")
            print("   • faceData count: \(faceData.count)")
            print("   • lastUpdated: \(store.lastUpdated)")
            
            return GetFaceIdData(salt: store.salt, faceData: faceData)
            
        } catch {
            print("❌ [FaceIdStorageManager] Failed to load: \(error)")
            return nil
        }
    }
    
    // MARK: - Delete Local Storage
    func deleteAllFaceData() {
        guard let context = modelContext else {
            print("❌ [FaceIdStorageManager] No model context available")
            return
        }
        
        print("🗑️ [FaceIdStorageManager] Deleting all local FaceId data...")
        
        do {
            let descriptor = FetchDescriptor<FaceIdLocalStore>()
            let stores = try context.fetch(descriptor)
            
            for store in stores {
                context.delete(store)
            }
            
            try context.save()
            print("✅ [FaceIdStorageManager] Successfully deleted all FaceId data")
            
        } catch {
            print("❌ [FaceIdStorageManager] Failed to delete: \(error)")
        }
    }
    
    // MARK: - Check if Local Data Exists
    func hasLocalData(for deviceKey: String) -> Bool {
        guard let context = modelContext else {
            print("❌ [FaceIdStorageManager] No model context available")
            return false
        }
        
        do {
            let descriptor = FetchDescriptor<FaceIdLocalStore>()
            let stores = try context.fetch(descriptor)
            
            guard let store = stores.first else {
                print("📭 [FaceIdStorageManager] No local data exists")
                return false
            }
            
            let matches = store.deviceKey == deviceKey
            print("📦 [FaceIdStorageManager] Local data exists: \(matches) (deviceKey match: \(matches))")
            return matches
            
        } catch {
            print("❌ [FaceIdStorageManager] Failed to check: \(error)")
            return false
        }
    }
}

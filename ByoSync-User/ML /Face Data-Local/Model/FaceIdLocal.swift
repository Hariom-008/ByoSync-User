import Foundation
import SwiftData

// MARK: - SwiftData Model for FaceId Storage
@Model
final class FaceIdLocalStore {
    @Attribute(.unique) var id: String = "singleton" // Only one record
    var salt: String
    var faceDataJSON: Data // Store array as JSON
    var lastUpdated: Date
    var deviceKey: String
    
    init(salt: String, faceDataJSON: Data, deviceKey: String) {
        self.salt = salt
        self.faceDataJSON = faceDataJSON
        self.lastUpdated = Date()
        self.deviceKey = deviceKey
    }
    
    // Helper to decode faceData
    func getFaceData() -> [FaceId]? {
        do {
            let decoded = try JSONDecoder().decode([FaceId].self, from: faceDataJSON)
            print("✅ [FaceIdLocalStore] Decoded \(decoded.count) FaceId records from local storage")
            return decoded
        } catch {
            print("❌ [FaceIdLocalStore] Failed to decode faceData: \(error)")
            return nil
        }
    }
    
    // Helper to create from GetFaceIdData
    static func create(from data: GetFaceIdData, deviceKey: String) -> FaceIdLocalStore? {
        do {
            let jsonData = try JSONEncoder().encode(data.faceData)
            print("✅ [FaceIdLocalStore] Encoded \(data.faceData.count) FaceId records for storage")
            return FaceIdLocalStore(salt: data.salt, faceDataJSON: jsonData, deviceKey: deviceKey)
        } catch {
            print("❌ [FaceIdLocalStore] Failed to encode faceData: \(error)")
            return nil
        }
    }
}

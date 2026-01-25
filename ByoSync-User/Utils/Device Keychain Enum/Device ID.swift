import Foundation

enum DeviceIdentity {
    private static let key = "deviceId"

    static func resolve() -> String {
        if let existing = KeychainHelper.shared.read(forKey: key) {
            return existing
        }

        let newId = UUID().uuidString
       //let newId = "1D6DB255-4AFF-4D50-97A7-CF8B72DE30C1"
        KeychainHelper.shared.save(newId, forKey: key)
        return newId
    }
}

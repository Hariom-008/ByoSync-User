import Foundation
import FirebaseMessaging
import UIKit

final class FCMTokenManager {
    static let shared = FCMTokenManager()
    
    private var cachedToken: String?
    
    private init() {
        print("🔧 [FCMTokenManager] Initialized")
    }
    
    // MARK: - Synchronous Token Access
    
    /// Get cached token (returns nil if not yet received)
    func getToken() -> String? {
        if let token = cachedToken {
            print("📦 [FCMTokenManager] Returning cached token: \(token)")
        } else {
            print("⚠️ [FCMTokenManager] No cached token available")
        }
        return cachedToken
    }
    
    /// Store token when received from Firebase
    func setToken(_ token: String) {
        print("💾 [FCMTokenManager] Caching FCM token: \(token)")
        cachedToken = token
        
        // Also persist to UserDefaults as backup
        UserDefaults.standard.set(token, forKey: "FCMToken")
        UserDefaults.standard.synchronize()
        
        print("✅ [FCMTokenManager] Token cached and persisted")
    }
    
    // MARK: - Async Token Retrieval
    
    /// Get token with completion (will return cached or request new one)
    func getFCMToken(completion: @escaping (String?) -> Void) {
        print("🔍 [FCMTokenManager] Getting FCM token...")
        
        // Return cached if available
        if let cached = cachedToken, !cached.isEmpty {
            print("✅ [FCMTokenManager] Returning cached token")
            completion(cached)
            return
        }
        
        // Try to restore from UserDefaults
        if let persisted = UserDefaults.standard.string(forKey: "FCMToken"), !persisted.isEmpty {
            print("📱 [FCMTokenManager] Restored token from UserDefaults")
            cachedToken = persisted
            completion(persisted)
            return
        }
        
        // Check if ready for remote notifications
        guard UIApplication.shared.isRegisteredForRemoteNotifications else {
            print("⚠️ [FCMTokenManager] Not registered for remote notifications - waiting...")
            // Retry after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.getFCMToken(completion: completion)
            }
            return
        }
        
        // Request token from Firebase
        print("📡 [FCMTokenManager] Requesting FCM token from Firebase...")
        Messaging.messaging().token { token, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [FCMTokenManager] FCM token error: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let token = token, !token.isEmpty else {
                    print("⚠️ [FCMTokenManager] FCM token empty")
                    completion(nil)
                    return
                }
                
                print("✅ [FCMTokenManager] FCM Token retrieved: \(token)")
                self.setToken(token)
                completion(token)
            }
        }
    }
    
    // MARK: - Token Management
    
    /// Clear cached token (useful for logout)
    func clearToken() {
        print("🗑️ [FCMTokenManager] Clearing cached token")
        cachedToken = nil
        UserDefaults.standard.removeObject(forKey: "FCMToken")
        UserDefaults.standard.synchronize()
    }
    
    /// Force refresh token from Firebase
    func refreshToken(completion: @escaping (String?) -> Void) {
        print("🔄 [FCMTokenManager] Force refreshing FCM token...")
        
        Messaging.messaging().token { token, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [FCMTokenManager] Refresh error: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let token = token, !token.isEmpty else {
                    print("⚠️ [FCMTokenManager] Refreshed token empty")
                    completion(nil)
                    return
                }
                
                print("✅ [FCMTokenManager] Token refreshed: \(token)")
                self.setToken(token)
                completion(token)
            }
        }
    }
    
    // MARK: - Token Validation
    
    /// Check if we have a valid token
    var hasToken: Bool {
        let hasIt = cachedToken != nil && !(cachedToken?.isEmpty ?? true)
        print("🔍 [FCMTokenManager] hasToken: \(hasIt)")
        return hasIt
    }
}

import UIKit
import Firebase
import FirebaseMessaging
import CommonCrypto
import SwiftUI
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    // Use a normal property, not @StateObject
    private let cryptoManager = CryptoManager.shared

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        print("🚀 App launching...")
        
        FirebaseApp.configure()
        print("✅ Firebase configured")
        
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        print("✅ Delegates set")
        
        requestNotificationPermissions(application)
        
        return true
    }

    private func requestNotificationPermissions(_ application: UIApplication) {
        print("📱 Requesting notification permissions...")
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("❌ Permission error: \(error.localizedDescription)")
                return
            }
            
            print("✅ Permission granted: \(granted)")
            
            if granted {
                DispatchQueue.main.async {
                    print("📲 Registering for remote notifications...")
                    application.registerForRemoteNotifications()
                }
            } else {
                print("⚠️ User denied notification permission")
            }
        }
    }

    // MARK: - APNs Token Registration
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("🔐 Device Token Received: \(tokenString)")
        
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
        print("✅ APNs token set for Firebase Auth")
        
        Messaging.messaging().apnsToken = deviceToken
        print("✅ APNs token set for Firebase Messaging")
        
        print("🔄 Requesting FCM token now that APNs is ready...")
        requestFCMToken()
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
        print("💡 Tip: Make sure you're testing on a real device, not simulator")
    }

    // MARK: - FCM Token Request
    private func requestFCMToken() {
        Messaging.messaging().token { token, error in
            if let error = error {
                print("❌ Error getting FCM token: \(error.localizedDescription)")
                return
            }
            
            guard let token = token else {
                print("⚠️ FCM token is nil")
                return
            }
            
            print("🔑 FCM Token received: \(token)")
            self.handleFCMToken(token)
        }
    }

    // MARK: - MessagingDelegate
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else {
            print("❌ FCM Token is nil in delegate")
            return
        }
        
        print("🔑 FCM Token refreshed: \(fcmToken)")
        handleFCMToken(fcmToken)
    }

    // MARK: - Handle FCM Token
    private func handleFCMToken(_ token: String) {
        print("💾 Processing FCM token...")
        FCMTokenManager.shared.setToken(token)
        uploadFCMToken(token)
        
        NotificationCenter.default.post(
            name: NSNotification.Name("FCMTokenReceived"),
            object: nil,
            userInfo: ["token": token]
        )
    }

    func uploadFCMToken(_ token: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ No user logged in, saving token locally for later upload")
            UserDefaults.standard.set(token, forKey: "pendingFCMToken")
            return
        }
        
        print("📤 Uploading FCM token to Firestore for user: \(userId)")
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "fcmToken": token,
            "tokenUpdatedAt": FieldValue.serverTimestamp(),
            "platform": "iOS"
        ]) { error in
            if let error = error {
                print("❌ Failed to upload FCM token: \(error.localizedDescription)")
            } else {
                print("✅ FCM token uploaded successfully")
                UserDefaults.standard.removeObject(forKey: "pendingFCMToken")
            }
        }
    }

    // MARK: - Remote Notifications
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification notification: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        if Auth.auth().canHandleNotification(notification) {
            completionHandler(.noData)
            return
        }

        
        print("📬 Remote notification: \(notification)")

        if let encryptedPaymentDetails = notification["payment_details"] as? String {
            if let decryptedPaymentDetails = cryptoManager.decrypt(encryptedData: encryptedPaymentDetails) {
                print("Decrypted Payment Details: \(decryptedPaymentDetails)")
            } else {
                print("Failed to decrypt payment details.")
            }
        }
        
        applyHasFaceDataIfPresent(notification, source: "didReceiveRemoteNotification")
        
        completionHandler(.newData)
    }

    func application(_ application: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }
        return false
    }

    // MARK: - Foreground Notifications
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let content = notification.request.content
        let userInfo = content.userInfo

        applyHasFaceDataIfPresent(userInfo, source: "willPresent")
        print("📬 Foreground notification: \(userInfo)")

        let originalBody = content.body
        let originalTitle = content.title

        print("📨 Original title = \(originalTitle)")
        print("📨 Original body  = \(originalBody)")

        let decryptedBody = decryptPaymentBodyIfNeeded(originalBody)

        let newContent = UNMutableNotificationContent()
        newContent.title = originalTitle
        newContent.body  = decryptedBody
        newContent.sound = UNNotificationSound.defaultCritical
        newContent.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: notification.request.identifier + "-decrypted",
            content: newContent,
            trigger: nil
        )


        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to show decrypted foreground notification: \(error.localizedDescription)")
            } else {
                print("✅ Decrypted foreground notification scheduled")
            }
        }

        completionHandler([])
    }

    func userNotificationCenter( 
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        var userInfo = response.notification.request.content.userInfo
        print("👆 Notification tapped: \(userInfo)")

        if let encryptedPaymentDetails = userInfo["payment_details"] as? String {
            if let decryptedPaymentDetails = cryptoManager.decrypt(encryptedData: encryptedPaymentDetails) {
                userInfo["payment_details"] = decryptedPaymentDetails
                print("Decrypted Payment Details: \(decryptedPaymentDetails)")
            } else {
                print("Failed to decrypt payment details.")
            }
        }

        if let type = userInfo["type"] as? String {
            handleNotificationAction(type: type, data: userInfo)
        }

        completionHandler()
    }

    // MARK: - Payment Body Decryption Helper
    private func decryptPaymentBodyIfNeeded(_ body: String) -> String {
        let decrypted = cryptoManager.decryptPaymentMessage(body)
        print("🔍 [AppDelegate] INPUT  = \(body)")
        print("🔍 [AppDelegate] OUTPUT = \(decrypted)")
        return decrypted.isEmpty ? body : decrypted
    }

    private func handleNotificationAction(type: String, data: [AnyHashable: Any]) {
        print("🎯 Notification action: \(type)")

        NotificationCenter.default.post(
            name: NSNotification.Name("NotificationActionReceived"),
            object: nil,
            userInfo: data as? [String: Any]
        )
        
        switch type {
        case "message":
            print("📨 Opening messages")
        case "wallet":
            print("💰 Opening wallet")
        case "task":
            print("✅ Opening task")
        default:
            print("🤷‍♂️ Unknown type: \(type)")
        }
    }
    
    
//MARK: Helper for FaceData Delete Alert via notification

    private func extractHasFaceData(_ userInfo: [AnyHashable: Any]) -> Bool? {
        // ✅ NEW: Check for type field first
        if let type = userInfo["type"] as? String,
           type == "FACE_DATA_DELETED" {
            print("🎯 [AppDelegate] Detected FACE_DATA_DELETED notification")
            return false
        }
        
        // Most common on iOS with FCM data payload: String
        if let s = userInfo["hasFaceData"] as? String {
            let v = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if v == "true" || v == "1" { return true }
            if v == "false" || v == "0" { return false }
        }
        // Sometimes it can come as Bool/NSNumber
        if let b = userInfo["hasFaceData"] as? Bool { return b }
        if let n = userInfo["hasFaceData"] as? NSNumber { return n.boolValue }
        return nil
    }

    private func applyHasFaceDataIfPresent(_ userInfo: [AnyHashable: Any], source: String) {
        guard let v = extractHasFaceData(userInfo) else {
            print("⚠️ [AppDelegate] No hasFaceData found in notification from \(source)")
            return
        }
        print("🧬 hasFaceData=\(v) from=\(source)")

        // Persist + publish
        UserSession.shared.setHasFaceData(v)
        
        // ✅ Clean up local storage when hasFaceData becomes false
        if !v {
            print("🗑️ [AppDelegate] hasFaceData=false -> Cleaning up local data")
            
            DispatchQueue.main.async {
                // Delete local FaceId storage
                FaceIdStorageManager.shared.deleteAllFaceData()
                
                // Reset enrollment gate
                EnrollmentGate.shared.markNotEnrolled()
                
                // Reset scan gate if needed
             AppScanGate.shared.resetScanRequirement()
                
                // Post notification for UI to refresh
                NotificationCenter.default.post(
                    name: NSNotification.Name("FaceDataDeleted"),
                    object: nil
                )
                
                print("✅ [AppDelegate] Local data cleanup complete")
            }
        }
    }
}

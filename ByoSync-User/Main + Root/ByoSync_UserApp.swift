import SwiftUI
import Firebase
import UIKit
import FirebaseAuth
import FirebaseMessaging
import Combine

@main
struct ByoSync_UserApp: App {
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject var userSession = UserSession.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var socketManager = SocketIOManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(userSession)
                    .id(languageManager.currentLanguageCode)
                    .environmentObject(languageManager)
                    .environment(\.locale, .init(identifier: languageManager.currentLanguageCode))
                    .preferredColorScheme(.light)

                GlobalPaymentOverlayView()
            }
            // Initial connect on app launch
            .onAppear {
                socketManager.connect()
            }
            // Scene phase handling for background / inactive / foreground
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .active:
                    print("🌱 App became active — ensure socket connected")
                    socketManager.connectIfNeeded()
                case .inactive:
                    print("💤 App inactive — temporarily disconnecting socket")
                    socketManager.disconnect()
                case .background:
                    print("📦 App in background — disconnect socket but keep manager ready")
                    socketManager.disconnect()
                @unknown default:
                    break
                }
            }
        }
    }
}


class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        print("🚀 App launching...")
        
        // Configure Firebase FIRST
        FirebaseApp.configure()
        print("✅ Firebase configured")
        
        // Set delegates
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        print("✅ Delegates set")
        
        // Request notification permissions
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
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("🔐 Device Token Received: \(tokenString)")
        
        // Set APNs token for Firebase Auth
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
        print("✅ APNs token set for Firebase Auth")
        
        // Set APNs token for Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        print("✅ APNs token set for Firebase Messaging")
        
        // Now request FCM token since APNs is ready
        print("🔄 Requesting FCM token now that APNs is ready...")
        requestFCMToken()
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
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
            
            // Save and upload
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
        
        // Update manager
        Task {
            await FCMTokenManager.shared.setToken(token)
        }
        
        // Upload to Firestore
        uploadFCMToken(token)
        
        // Notify observers
        NotificationCenter.default.post(
            name: NSNotification.Name("FCMTokenReceived"),
            object: nil,
            userInfo: ["token": token]
        )
    }
    
    func uploadFCMToken(_ token: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ No user logged in, saving token locally for later upload")
            // Save for later when user logs in
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
        completionHandler(.newData)
    }
    
    func application(_ application: UIApplication, open url: URL,
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
        let userInfo = notification.request.content.userInfo
        print("📬 Foreground notification: \(userInfo)")
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("👆 Notification tapped: \(userInfo)")
        
        if let type = userInfo["type"] as? String {
            handleNotificationAction(type: type, data: userInfo)
        }
        
        completionHandler()
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
}

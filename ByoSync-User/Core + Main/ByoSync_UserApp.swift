// ByoSync_UserApp.swift

import SwiftUI
import FirebaseAuth
import UIKit
import SwiftData

struct HasProcessedPendingNotificationsKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var hasProcessedPendingNotifications: Bool {
        get { self[HasProcessedPendingNotificationsKey.self] }
        set { self[HasProcessedPendingNotificationsKey.self] = newValue }
    }
}

@main
struct ByoSync_UserApp: App {
    @StateObject private var cryptoManager = CryptoManager()
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject var userSession = UserSession.shared
    @StateObject private var socketManager = SocketIOManager.shared
    @StateObject private var scanGate = AppScanGate.shared
    @StateObject private var faceAuthManager = FaceAuthManager.shared
    @StateObject private var enrollmentGate = EnrollmentGate.shared

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase

    // ✅ Single instance for entire app
    @StateObject private var deviceRegistrationVM = DeviceRegistrationViewModel()

    @State var hasProcessedPendingNotifications = true
    
    // ✅ NEW: Track app initialization state
    @State private var isInitializing = true
    @State private var fcmToken: String?
    @State private var deviceCheckCompleted = false

    // ✅ Persisted keys
    private let didInitialDeviceCheckKey = "didInitialDeviceCheckKey"
    private let isDeviceRegisteredKey = "isDeviceRegisteredKey"

    var body: some Scene {
        WindowGroup {
            ZStack {
                // ✅ Show splash screen while initializing
                if isInitializing || !deviceCheckCompleted {
                    SplashScreenView()
                } else {
                    RouterView { RootView() }
                        .environmentObject(userSession)
                        .environmentObject(languageManager)
                        .environmentObject(faceAuthManager)
                        .environmentObject(cryptoManager)
                        .environmentObject(scanGate)
                        .environmentObject(enrollmentGate)
                        .environmentObject(deviceRegistrationVM)
                        .environment(\.locale, .init(identifier: languageManager.currentLanguageCode))
                        .preferredColorScheme(.light)
                        .modelContainer(for: [FaceIdLocalStore.self])
                        .environment(\.hasProcessedPendingNotifications, hasProcessedPendingNotifications)
                }
            }
            .onOpenURL { url in
                Auth.auth().canHandle(url)
            }
            .onAppear {
                print("🚀 [APP] App launched - starting initialization")
                initializeApp()
            }
            .onChange(of: userSession.currentUser) { oldValue, newValue in
                // ✅ When user logs in for the first time
                if oldValue == nil && newValue != nil {
                    print("🆕 [APP] New login detected - processing notifications")
                    processPendingNotifications()
                }
                
                // ✅ When user logs out
                if oldValue != nil && newValue == nil {
                    print("👋 [APP] Logout detected - resetting notification state")
                    hasProcessedPendingNotifications = true
                }
            }
            .onChange(of: deviceRegistrationVM.hasFaceData) { _, newValue in
                print("📊 [APP] Backend hasFaceData changed -> \(newValue)")
                handleEnrollmentStatusChange(hasFaceData: newValue)
            }
            .onChange(of: deviceRegistrationVM.isDeviceRegistered) { _, newValue in
                print("📱 [APP] Device registration status changed -> \(newValue)")
                UserDefaults.standard.set(newValue, forKey: isDeviceRegisteredKey)
                
                // ✅ Mark device check as completed when we get a response
                if !deviceCheckCompleted {
                    print("✅ [APP] Device check completed with status: \(newValue)")
                    deviceCheckCompleted = true
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                let isLoggedIn = (userSession.currentUser != nil)
                let isUserAccount = (UserDefaults.standard.string(forKey: "accountType") == "user")

                if newPhase == .active {
                    if isLoggedIn && isUserAccount {
                        processPendingNotifications()
                        enrollmentGate.reload()
                    }
                }

                if oldPhase == .active,
                   (newPhase == .inactive || newPhase == .background),
                   isLoggedIn,
                   isUserAccount,
                   enrollmentGate.isEnrolled {
                    scanGate.markRequiredDueToInactive()
                }

                switch newPhase {
                case .active:
                    socketManager.connectIfNeeded()
                case .inactive, .background:
                    socketManager.disconnect()
                @unknown default:
                    break
                }
            }
        }
    }

    // ✅ NEW: Initialize app with proper sequence
    private func initializeApp() {
        print("🔧 [APP] Step 1: Waiting for FCM token...")
        
        // ✅ Wait for FCM token first
        waitForFCMToken { token in
            guard let token = token else {
                print("❌ [APP] Failed to get FCM token - retrying...")
                // Retry after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.initializeApp()
                }
                return
            }
            
            print("✅ [APP] FCM Token received: \(token)")
            self.fcmToken = token
            
            // ✅ Now perform device registration check
            print("🔧 [APP] Step 2: Checking device registration...")
            self.performDeviceCheck()
        }
    }
    
    // ✅ NEW: Wait for FCM token with timeout
    private func waitForFCMToken(completion: @escaping (String?) -> Void) {
        // Check if token is already available
        if let existingToken = FCMTokenManager.shared.getToken(), !existingToken.isEmpty {
            print("✅ [APP] FCM token already available")
            completion(existingToken)
            return
        }
        
        // Request token
        FCMTokenManager.shared.getFCMToken { token in
            if let token = token, !token.isEmpty {
                print("✅ [APP] FCM token retrieved: \(token)")
                completion(token)
            } else {
                print("⚠️ [APP] FCM token not available yet, waiting...")
                // Retry after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.waitForFCMToken(completion: completion)
                }
            }
        }
    }
    
    // ✅ NEW: Perform device registration check
    private func performDeviceCheck() {
        print("📡 [APP] Calling device registration check...")
        
        // Call the device registration check
        deviceRegistrationVM.checkDeviceRegistration()
        
        // ✅ Wait for response with timeout
        var attempts = 0
        let maxAttempts = 30 // 15 seconds timeout (500ms * 30)
        
        func checkForResponse() {
            attempts += 1
            
            // Check if we got a response
            let hasResponse = UserDefaults.standard.object(forKey: isDeviceRegisteredKey) != nil
            
            if hasResponse || deviceCheckCompleted {
                print("✅ [APP] Device check response received")
                print("   - isDeviceRegistered: \(deviceRegistrationVM.isDeviceRegistered)")
                print("   - hasFaceData: \(deviceRegistrationVM.hasFaceData)")
                
                // ✅ Mark initialization as complete
                DispatchQueue.main.async {
                    self.isInitializing = false
                    self.deviceCheckCompleted = true
                    
                    // ✅ Connect socket after initialization
                    self.socketManager.connect()
                    
                    // ✅ Only process pending notifications if user is already logged in
                    if self.userSession.currentUser != nil {
                        self.processPendingNotifications()
                    }
                    
                    print("✅ [APP] Initialization complete - ready to show UI")
                }
                return
            }
            
            // ✅ Check timeout
            if attempts >= maxAttempts {
                print("⚠️ [APP] Device check timeout - proceeding anyway")
                DispatchQueue.main.async {
                    self.isInitializing = false
                    self.deviceCheckCompleted = true
                }
                return
            }
            
            // ✅ Retry after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                checkForResponse()
            }
        }
        
        // Start checking for response
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            checkForResponse()
        }
    }

    private func processPendingNotifications() {
        print("📦 [APP] Processing pending notifications...")
        print("   - Current user: \(userSession.currentUser?.userId ?? "nil")")
        print("   - Current hasFaceData: \(userSession.hasFaceData)")
        
        hasProcessedPendingNotifications = false

        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            print("📬 [APP] Found \(notifications.count) delivered notifications")
            
            // ✅ Check for FACE_DATA_DELETED notification
            for notification in notifications {
                let userInfo = notification.request.content.userInfo

                if let type = userInfo["type"] as? String, type == "FACE_DATA_DELETED" {
                    print("🚨 [APP] Found FACE_DATA_DELETED notification - handling immediately")
                    DispatchQueue.main.async {
                        self.handleEnrollmentStatusChange(hasFaceData: false)
                        self.hasProcessedPendingNotifications = true

                        UNUserNotificationCenter.current().removeDeliveredNotifications(
                            withIdentifiers: [notification.request.identifier]
                        )
                    }
                    return
                }
            }

            // ✅ No critical notifications found - mark as processed
            print("✅ [APP] No critical notifications - marking as processed")
            DispatchQueue.main.async {
                self.hasProcessedPendingNotifications = true
            }
        }
    }

    private func handleEnrollmentStatusChange(hasFaceData: Bool) {
        print("🎯 [APP] handleEnrollmentStatusChange called with hasFaceData: \(hasFaceData)")
        
        // ✅ SAFETY CHECK: Don't downgrade from true to false if we just completed registration
        let currentHasFaceData = userSession.hasFaceData
        if currentHasFaceData == true && hasFaceData == false {
            let lastRegistrationTime = UserDefaults.standard.double(forKey: "lastRegistrationTimestamp")
            let timeSinceRegistration = Date().timeIntervalSince1970 - lastRegistrationTime
            
            // If registration happened in last 5 seconds, ignore backend saying false
            if timeSinceRegistration < 5.0 {
                print("⚠️ [APP] Ignoring hasFaceData=false - registration just completed \(timeSinceRegistration)s ago")
                return
            }
        }
        
        userSession.setHasFaceData(hasFaceData)

        if !hasFaceData {
            print("🗑️ [APP] Cleaning up local data due to hasFaceData=false")
            FaceIdStorageManager.shared.deleteAllFaceData()
            enrollmentGate.markNotEnrolled()
            scanGate.resetScanRequirement()

            NotificationCenter.default.post(
                name: NSNotification.Name("EnrollmentStatusChanged"),
                object: nil,
                userInfo: ["hasFaceData": false]
            )
        } else {
            print("✅ [APP] Marking user as enrolled")
            enrollmentGate.markEnrolled()
            
            // ✅ For new users who just got hasFaceData=true, ensure notifications are marked as processed
            // This prevents them from getting stuck on empty screen
            if hasProcessedPendingNotifications == false {
                print("✅ [APP] New user - setting hasProcessedPendingNotifications=true")
                hasProcessedPendingNotifications = true
            }
        }
    }
}

// ByoSync_UserApp.swift

import SwiftUI
import FirebaseAuth
import UIKit
import SwiftData
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
    
    @StateObject private var deviceRegistrationVM = DeviceRegistrationViewModel()
    
    // ✅ UPDATED: Start as true for new users, only set to false when we need to wait
    @State private var hasProcessedPendingNotifications = true
    
    private static var didLogAppStart = false
    
    init() {
        if !Self.didLogAppStart {
            Self.didLogAppStart = true
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                RouterView { RootView() }
                    .environmentObject(userSession)
                    .environmentObject(languageManager)
                    .environmentObject(faceAuthManager)
                    .environmentObject(cryptoManager)
                    .environmentObject(scanGate)
                    .environmentObject(enrollmentGate)
                    .environment(\.locale, .init(identifier: languageManager.currentLanguageCode))
                    .preferredColorScheme(.light)
                    .modelContainer(for: [FaceIdLocalStore.self])
                    .environment(\.hasProcessedPendingNotifications, hasProcessedPendingNotifications)
            }
            .onOpenURL { url in
                Auth.auth().canHandle(url)
            }
            .onAppear {
                socketManager.connect()
                
                // ✅ Only process pending notifications if user is already logged in
                if userSession.currentUser != nil {
                    processPendingNotifications()
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                print("🔄 [APP] Scene phase changed: \(oldPhase) -> \(newPhase)")
                
                let isLoggedIn = (userSession.currentUser != nil)
                let isUserAccount = (UserDefaults.standard.string(forKey: "accountType") == "user")
                
                if newPhase == .active {
                    print("👀 [APP] App became active")
                    
                    // ✅ Only process pending notifications for logged-in users
                    if isLoggedIn && isUserAccount {
                        processPendingNotifications()
                        checkEnrollmentStatus()
                    }
                }
                
                if oldPhase == .active,
                   (newPhase == .inactive || newPhase == .background),
                   isLoggedIn,
                   isUserAccount,
                   enrollmentGate.isEnrolled
                {
                    print("🔐 [APP] Leaving foreground -> require verification scan on return")
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
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                if userSession.currentUser != nil,
                   UserDefaults.standard.string(forKey: "accountType") == "user" {
                    print("🧨 [APP] willTerminate -> require scan on next launch")
                    scanGate.markRequiredOnTerminate()
                }
            }
            .onChange(of: deviceRegistrationVM.hasFaceData) { oldValue, newValue in
                let newValue = newValue
                print("📊 [APP] Backend hasFaceData changed: \(oldValue) -> \(newValue)")
                handleEnrollmentStatusChange(hasFaceData: newValue)
            }
        }
    }
    
    // ✅ UPDATED: Set flag to false FIRST, then check notifications
    private func processPendingNotifications() {
        print("📦 [APP] Checking for pending notifications...")
        
        // ✅ Block navigation until check completes
        hasProcessedPendingNotifications = false
        
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            print("📦 [APP] Found \(notifications.count) delivered notifications")
            
            for notification in notifications {
                let userInfo = notification.request.content.userInfo
                
                if let type = userInfo["type"] as? String, type == "FACE_DATA_DELETED" {
                    print("🎯 [APP] Processing pending FACE_DATA_DELETED notification")
                    
                    DispatchQueue.main.async {
                        // Process immediately
                        self.handleEnrollmentStatusChange(hasFaceData: false)
                        
                        // Unblock navigation
                        self.hasProcessedPendingNotifications = true
                        
                        // Remove the notification
                        UNUserNotificationCenter.current().removeDeliveredNotifications(
                            withIdentifiers: [notification.request.identifier]
                        )
                    }
                    return
                }
            }
            
            // No pending notifications found - unblock navigation
            DispatchQueue.main.async {
                print("✅ [APP] No pending FACE_DATA_DELETED notifications")
                self.hasProcessedPendingNotifications = true
            }
        }
    }
    
    private func checkEnrollmentStatus() {
        let deviceKey = DeviceIdentity.resolve()
        guard !deviceKey.isEmpty else {
            print("⚠️ [APP] No device key available")
            return
        }
        
        print("🔍 [APP] Checking device registration status...")
        deviceRegistrationVM.checkDeviceRegistration()
    }
    
    private func handleEnrollmentStatusChange(hasFaceData: Bool) {
        print("🎯 [APP] Processing enrollment status: hasFaceData=\(hasFaceData)")
        
        userSession.setHasFaceData(hasFaceData)
        
        if !hasFaceData {
            print("🗑️ [APP] hasFaceData=false -> Cleaning up local data")
            
            FaceIdStorageManager.shared.deleteAllFaceData()
            enrollmentGate.markNotEnrolled()
            scanGate.resetScanRequirement()
            
            NotificationCenter.default.post(
                name: NSNotification.Name("EnrollmentStatusChanged"),
                object: nil,
                userInfo: ["hasFaceData": false]
            )
            
            print("✅ [APP] Local data cleanup complete")
        } else {
            print("✅ [APP] hasFaceData=true -> User is enrolled")
            enrollmentGate.markEnrolled()
        }
    }
}

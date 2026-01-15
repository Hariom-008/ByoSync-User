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

    // ✅ UPDATED: Start as true for new users, only set to false when we need to wait
    @State var hasProcessedPendingNotifications = true

    // ✅ Persisted keys
    private let didInitialDeviceCheckKey = "didInitialDeviceCheckKey"
    private let isDeviceRegisteredKey = "isDeviceRegisteredKey"

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
                    .environmentObject(deviceRegistrationVM) // ✅ inject
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

                // ✅ 1) Do the device check only once ever (first install / first open)
                bootstrapDeviceRegistrationOnce()

                // ✅ 2) Only process pending notifications if user is already logged in
                if userSession.currentUser != nil {
                    processPendingNotifications()
                }
            }
            .onChange(of: deviceRegistrationVM.hasFaceData) { _, newValue in
                print("📊 [APP] Backend hasFaceData changed -> \(newValue)")
                handleEnrollmentStatusChange(hasFaceData: newValue)
            }
            .onChange(of: deviceRegistrationVM.isDeviceRegistered) { _, newValue in
                // ✅ cache isDeviceRegistered
                UserDefaults.standard.set(newValue, forKey: isDeviceRegisteredKey)
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                let isLoggedIn = (userSession.currentUser != nil)
                let isUserAccount = (UserDefaults.standard.string(forKey: "accountType") == "user")

                if newPhase == .active {
                    if isLoggedIn && isUserAccount {
                        processPendingNotifications()
                        // IMPORTANT: do NOT re-run deviceRegistrationVM.check here anymore
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

    private func bootstrapDeviceRegistrationOnce() {
        // If already done once ever, do nothing.
        if UserDefaults.standard.bool(forKey: didInitialDeviceCheckKey) {
            return
        }
        UserDefaults.standard.set(true, forKey: didInitialDeviceCheckKey)

        print("🔍 [APP] Initial device registration check (one-time)")
        deviceRegistrationVM.checkDeviceRegistration()
    }

    private func processPendingNotifications() {
        print("📦 [APP] Checking for pending notifications...")
        hasProcessedPendingNotifications = false

        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            for notification in notifications {
                let userInfo = notification.request.content.userInfo

                if let type = userInfo["type"] as? String, type == "FACE_DATA_DELETED" {
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

            DispatchQueue.main.async {
                self.hasProcessedPendingNotifications = true
            }
        }
    }

    private func handleEnrollmentStatusChange(hasFaceData: Bool) {
        userSession.setHasFaceData(hasFaceData)

        if !hasFaceData {
            FaceIdStorageManager.shared.deleteAllFaceData()
            enrollmentGate.markNotEnrolled()
            scanGate.resetScanRequirement()

            NotificationCenter.default.post(
                name: NSNotification.Name("EnrollmentStatusChanged"),
                object: nil,
                userInfo: ["hasFaceData": false]
            )
        } else {
            enrollmentGate.markEnrolled()
        }
    }
}


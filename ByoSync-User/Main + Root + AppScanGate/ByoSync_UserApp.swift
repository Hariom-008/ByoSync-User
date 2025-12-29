// ByoSync_UserApp.swift

import SwiftUI
import FirebaseAuth
import UIKit

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

    // ✅ guarantees one-time logger init + one-time app-start log
    private static var didInitLogger = false
    private static var didLogAppStart = false

    init() {
        if !Self.didInitLogger {
            Self.didInitLogger = true
            Logger.shared.initialize() // starts timers, crash handling, lifecycle observers :contentReference[oaicite:1]{index=1}
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RouterView { AuthenticationView() }
                    .environmentObject(userSession)
                    .environmentObject(languageManager)
                    .environmentObject(faceAuthManager)
                    .environmentObject(cryptoManager)
                    .environmentObject(scanGate)
                    .environmentObject(enrollmentGate)
                    .environment(\.locale, .init(identifier: languageManager.currentLanguageCode))
                    .preferredColorScheme(.light)
            }
            .onOpenURL { url in
                _ = Auth.auth().canHandle(url)
                Logger.shared.i("DEEPLINK", "onOpenURL: \(url.absoluteString)")
            }
            .onAppear {
                // ✅ log once here (gives Logger.initialize() time to flip isInitialized) :contentReference[oaicite:2]{index=2}
                if !Self.didLogAppStart {
                    Self.didLogAppStart = true
                    let bundle = Bundle.main.bundleIdentifier ?? "unknown"
                    Logger.shared.i("APP", "APP_STARTED bundle=\(bundle)")
                }

                socketManager.connect()
                Logger.shared.i("SOCKET", "connect() requested")
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                Logger.shared.d("APP_LIFECYCLE", "Scene phase: \(String(describing: oldPhase)) -> \(String(describing: newPhase))")

                // Only enforce re-scan if user is already logged in
                let isLoggedIn = (userSession.currentUser != nil)
                let isUserAccount = (UserDefaults.standard.string(forKey: "accountType") == "user")

                // Mark required only when leaving foreground
                if oldPhase == .active,
                   (newPhase == .inactive || newPhase == .background),
                   isLoggedIn,
                   isUserAccount,
                   enrollmentGate.isEnrolled
                {
                    Logger.shared.i("SCAN_GATE", "Leaving foreground -> require verification scan on return")
                    scanGate.markRequiredDueToInactive()
                }

                switch newPhase {
                case .active:
                    socketManager.connectIfNeeded()
                    Logger.shared.i("SOCKET", "connectIfNeeded()")
                case .inactive, .background:
                    socketManager.disconnect()
                    Logger.shared.i("SOCKET", "disconnect()")
                @unknown default:
                    break
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                // Optional: extra safety if app is killed
                if userSession.currentUser != nil,
                   UserDefaults.standard.string(forKey: "accountType") == "user"
                {
                    Logger.shared.i("SCAN_GATE", "willTerminate -> require scan on next launch")
                    scanGate.markRequiredOnTerminate()
                }

                Logger.shared.i("APP_LIFECYCLE", "willTerminate received")
            }
        }
    }
}

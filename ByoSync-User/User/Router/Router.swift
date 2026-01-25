
import SwiftUI
import Combine

enum Route: Hashable, Identifiable {
    // Auth Flow
    case authentication
    case enterNumber
    case otpVerification(phoneNumber: String, viewModel: PhoneOTPViewModel)
    case login
    case registerUser(phoneNumber: String)
    
    // Onboarding Flow
    case userConsent
    case cameraPreparation
    case mlScan
    
    // Main App
    case mainTab
    case profile
    case settings
    
    var id: String {
        switch self {
        case .authentication: return "authentication"
        case .enterNumber: return "enterNumber"
        case .otpVerification: return "otpVerification"
        case .login: return "login"
        case .registerUser: return "registerUser"
        case .userConsent: return "userConsent"
        case .cameraPreparation: return "cameraPreparation"
        case .mlScan: return "mlScan"
        case .mainTab: return "mainTab"
        case .profile: return "profile"
        case .settings: return "settings"
        }
    }
    
    // Implement Hashable for NavigationPath
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Route, rhs: Route) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Presentation Style
enum PresentationStyle {
    case push              // NavigationStack push
    case sheet            // Modal sheet
    case fullScreenCover  // Full screen modal
}

// MARK: - Router Class
final class Router: ObservableObject {
    
    // MARK: - Published Properties
    @Published var path = NavigationPath()
    @Published var presentedSheet: Route?
    @Published var presentedFullScreen: Route?
    
    // MARK: - Navigation Methods
    
    /// Navigate to a route with specified presentation style
    func navigate(to route: Route, style: PresentationStyle = .push) {
        print("🧭 [ROUTER] Navigating to: \(route.id) with style: \(style)")
        
        switch style {
        case .push:
            path.append(route)
            
        case .sheet:
            presentedSheet = route
            
        case .fullScreenCover:
            presentedFullScreen = route
        }
    }
    
    /// Go back one step
    func pop() {
        print("⬅️ [ROUTER] Going back")
        guard !path.isEmpty else {
            print("⚠️ [ROUTER] Path is empty, cannot pop")
            return
        }
        path.removeLast()
    }
    
    /// Go back multiple steps
    func pop(count: Int) {
        print("⬅️ [ROUTER] Going back \(count) steps")
        let actualCount = min(count, path.count)
        path.removeLast(actualCount)
    }
    
    /// Pop to root (clear entire stack)
    func popToRoot() {
        print("🏠 [ROUTER] Popping to root")
        path.removeLast(path.count)
    }
    
    /// Dismiss currently presented sheet
    func dismissSheet() {
        print("❌ [ROUTER] Dismissing sheet")
        presentedSheet = nil
    }
    
    /// Dismiss currently presented full screen cover
    func dismissFullScreen() {
        print("❌ [ROUTER] Dismissing full screen")
        presentedFullScreen = nil
    }
    
    /// Replace current route with new route (useful for authentication flows)
    func replace(with route: Route) {
        print("🔄 [ROUTER] Replacing current route with: \(route.id)")
        if !path.isEmpty {
            path.removeLast()
        }
        path.append(route)
    }
    
    /// Reset entire navigation state (useful for logout)
    func reset() {
        print("🔄 [ROUTER] Resetting all navigation")
        path = NavigationPath()
        presentedSheet = nil
        presentedFullScreen = nil
    }
    
    /// Navigate to a specific path (deep linking support)
    func navigateToPath(_ routes: [Route]) {
        print("🗺️ [ROUTER] Navigating to path with \(routes.count) routes")
        path = NavigationPath()
        for route in routes {
            path.append(route)
        }
    }
    
    /// Get navigation depth
    var navigationDepth: Int {
        path.count
    }
    
    /// Check if can go back
    var canGoBack: Bool {
        !path.isEmpty
    }
}

extension Router {
    
    // MARK: - Auth Flow Helpers
    func navigateToAuth() {
        print("🔑 [ROUTER] Navigating to authentication")
        reset()
        navigate(to: .authentication, style: .push)
    }
    
    func navigateToMainApp() {
        print("🏠 [ROUTER] Navigating to main app")
        navigate(to: .mainTab, style: .push)
    }
    
    func handleLogout() {
        print("🚪 [ROUTER] Handling logout")
        reset()
        navigate(to: .authentication, style: .push)
    }
    
    // MARK: - Registration Flow
    func startRegistrationFlow() {
        print("📝 [ROUTER] Starting registration flow")
        navigate(to: .enterNumber, style: .push)
    }
    
    // MARK: - Onboarding Flow
    func startOnboardingFlow() {
        print("👋 [ROUTER] Starting onboarding flow")
        navigate(to: .userConsent, style: .fullScreenCover)
    }
}

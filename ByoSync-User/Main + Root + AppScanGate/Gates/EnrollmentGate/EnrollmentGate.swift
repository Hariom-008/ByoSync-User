import Foundation
import Combine

enum EnrollmentState: Int {
    case unknown = 0
    case notEnrolled = 1
    case enrolled = 2
}

final class EnrollmentGate: ObservableObject {
    static let shared = EnrollmentGate()

    @Published private(set) var state: EnrollmentState

    private let key = "enrollmentState"

    private init() {
        let raw = UserDefaults.standard.integer(forKey: key)
        self.state = EnrollmentState(rawValue: raw) ?? .unknown
    }

    func reload() {
        let raw = UserDefaults.standard.integer(forKey: key)
        state = EnrollmentState(rawValue: raw) ?? .unknown
        print("🔄 [EnrollmentGate] Reloaded state: \(state)")
    }

    func markNotEnrolled() {
        state = .notEnrolled
        UserDefaults.standard.set(EnrollmentState.notEnrolled.rawValue, forKey: key)
        print("❌ [EnrollmentGate] Marked as NOT enrolled")
    }

    func markEnrolled() {
        state = .enrolled
        UserDefaults.standard.set(EnrollmentState.enrolled.rawValue, forKey: key)
        print("✅ [EnrollmentGate] Marked as enrolled")
    }

    func resetToUnknown() {
        state = .unknown
        UserDefaults.standard.set(EnrollmentState.unknown.rawValue, forKey: key)
        print("❓ [EnrollmentGate] Reset to unknown")
    }

    var isEnrolled: Bool { state == .enrolled }
    var needsEnrollment: Bool { state == .notEnrolled }
}

import Foundation

// MARK: - Report Type
enum ReportType: String, CaseIterable {
    case view = "view"
    
    var displayName: String {
        switch self {
        case .view:
            return "View"
        }
    }
    
    var iconName: String {
        switch self {
        case .view:
            return "eye.fill"
        }
    }
    
    var buttonText: String {
        switch self {
        case .view:
            return "View Report"
        }
    }
}

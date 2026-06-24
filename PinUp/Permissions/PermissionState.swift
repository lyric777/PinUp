import Foundation

enum PermissionState: Equatable {
    case ready
    case missingAccessibility
    case missingScreenRecording
    case missingBoth

    var hasAccessibility: Bool {
        switch self {
        case .ready, .missingScreenRecording:
            return true
        case .missingAccessibility, .missingBoth:
            return false
        }
    }

    var hasScreenRecording: Bool {
        switch self {
        case .ready, .missingAccessibility:
            return true
        case .missingScreenRecording, .missingBoth:
            return false
        }
    }

    var summaryText: String {
        switch self {
        case .ready:
            return "Ready"
        case .missingAccessibility:
            return "Accessibility Needed"
        case .missingScreenRecording:
            return "Screen Recording Needed"
        case .missingBoth:
            return "Accessibility + Screen Recording Needed"
        }
    }
}

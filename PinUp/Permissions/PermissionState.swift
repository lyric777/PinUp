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
            return L10n.tr("ready")
        case .missingAccessibility:
            return L10n.tr("accessibility_needed")
        case .missingScreenRecording:
            return L10n.tr("screen_recording_needed")
        case .missingBoth:
            return L10n.tr("accessibility_screen_recording_needed")
        }
    }

    var debugSummary: String {
        "accessibility=\(hasAccessibility), screenRecording=\(hasScreenRecording), state=\(summaryText)"
    }
}

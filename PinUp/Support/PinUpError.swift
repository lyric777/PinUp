import Foundation

enum PinUpError: LocalizedError {
    case missingPermissions(PermissionState)
    case noFocusedWindow
    case selfCaptureDisallowed
    case windowNotMatchable
    case captureWindowUnavailable
    case captureFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingPermissions(let state):
            return state.summaryText
        case .noFocusedWindow:
            return L10n.tr("missing_focused_window")
        case .selfCaptureDisallowed:
            return L10n.tr("self_capture_disallowed")
        case .windowNotMatchable:
            return L10n.tr("window_not_matchable")
        case .captureWindowUnavailable:
            return L10n.tr("missing_capture_window")
        case .captureFailed(let message):
            return L10n.tr("capture_failed_format", message)
        }
    }
}

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
            return "No focused window could be found."
        case .selfCaptureDisallowed:
            return "PinUp cannot pin its own windows."
        case .windowNotMatchable:
            return "PinUp found the focused app, but could not match a capturable window."
        case .captureWindowUnavailable:
            return "The focused window is not available to ScreenCaptureKit right now."
        case .captureFailed(let message):
            return "Capture failed: \(message)"
        }
    }
}

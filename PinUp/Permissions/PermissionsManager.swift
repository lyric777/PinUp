@preconcurrency import ApplicationServices
import AppKit

@MainActor
final class PermissionsManager {
    func currentPermissionState() -> PermissionState {
        let accessibility = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary)
        let screenRecording = CGPreflightScreenCaptureAccess()

        switch (accessibility, screenRecording) {
        case (true, true):
            return .ready
        case (false, true):
            return .missingAccessibility
        case (true, false):
            return .missingScreenRecording
        case (false, false):
            return .missingBoth
        }
    }

    func requestAccessibilityPrompt() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
    }

    func requestScreenRecordingPrompt() {
        _ = CGRequestScreenCaptureAccess()
    }

    func openSystemSettings(for state: PermissionState) {
        let urlString: String
        switch state {
        case .ready, .missingBoth:
            urlString = "x-apple.systempreferences:com.apple.preference.security"
        case .missingAccessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .missingScreenRecording:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

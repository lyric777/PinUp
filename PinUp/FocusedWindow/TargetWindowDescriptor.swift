import CoreGraphics
import Foundation

struct TargetWindowDescriptor: Identifiable, Equatable {
    let id: String
    let pid: pid_t
    let appName: String
    let windowTitle: String
    let frame: CGRect
    let cgWindowID: CGWindowID

    var displayName: String {
        let trimmed = windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return appName
        }

        return "\(appName) - \(trimmed)"
    }
}

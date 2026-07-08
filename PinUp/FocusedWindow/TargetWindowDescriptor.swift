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

    var debugSummary: String {
        let trimmedTitle = windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmedTitle.isEmpty ? "<empty>" : trimmedTitle
        return "pid=\(pid), app=\(appName), title=\(title), cgWindowID=\(cgWindowID), frame=\(frame.debugSummary)"
    }
}

private extension CGRect {
    var debugSummary: String {
        "x=\(Int(origin.x)), y=\(Int(origin.y)), w=\(Int(width)), h=\(Int(height))"
    }
}

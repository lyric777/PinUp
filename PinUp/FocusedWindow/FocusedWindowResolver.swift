import ApplicationServices
import AppKit
import CoreGraphics

struct FocusedWindowResolver {
    private let matcher = WindowMatcher()

    func resolveFocusedWindow() throws -> TargetWindowDescriptor {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            throw PinUpError.noFocusedWindow
        }

        let pid = app.processIdentifier
        if pid == ProcessInfo.processInfo.processIdentifier {
            throw PinUpError.selfCaptureDisallowed
        }

        let appElement = AXUIElementCreateApplication(pid)
        let focusedWindowElement = try copyFocusedWindow(from: appElement)
        let title = copyStringAttribute(kAXTitleAttribute as CFString, from: focusedWindowElement) ?? ""
        let frame = copyWindowFrame(from: focusedWindowElement)
        let appName = app.localizedName ?? app.bundleIdentifier ?? "Unknown App"

        PinUpDebugLogger.log("Resolved focused AX window: pid=\(pid), app=\(appName), title=\(title.debugLogValue), frame=\(frame.debugSummary)")

        guard let descriptor = matcher.matchWindow(
            pid: pid,
            appName: appName,
            focusedWindowTitle: title,
            focusedWindowFrame: frame
        ) else {
            PinUpDebugLogger.log("No CGWindow match for focused AX window: pid=\(pid), app=\(appName), title=\(title.debugLogValue), frame=\(frame.debugSummary)")
            throw PinUpError.windowNotMatchable
        }

        PinUpDebugLogger.log("Matched target window: \(descriptor.debugSummary)")
        return descriptor
    }

    private func copyFocusedWindow(from appElement: AXUIElement) throws -> AXUIElement {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value)
        guard result == .success, let focusedWindow = value else {
            throw PinUpError.noFocusedWindow
        }

        return unsafeDowncast(focusedWindow as AnyObject, to: AXUIElement.self)
    }

    private func copyStringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }

        return value as? String
    }

    private func copyWindowFrame(from element: AXUIElement) -> CGRect {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        let hasPosition = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success
        let hasSize = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success

        guard
            hasPosition,
            hasSize,
            let positionAX = positionValue,
            let sizeAX = sizeValue
        else {
            return .zero
        }

        var point = CGPoint.zero
        var size = CGSize.zero

        let positionAXValue = positionAX as! AXValue
        if AXValueGetType(positionAXValue) == .cgPoint {
            AXValueGetValue(positionAXValue, .cgPoint, &point)
        }

        let sizeAXValue = sizeAX as! AXValue
        if AXValueGetType(sizeAXValue) == .cgSize {
            AXValueGetValue(sizeAXValue, .cgSize, &size)
        }

        return CGRect(origin: point, size: size)
    }
}

private extension CGRect {
    var debugSummary: String {
        "x=\(Int(origin.x)), y=\(Int(origin.y)), w=\(Int(width)), h=\(Int(height))"
    }
}

private extension String {
    var debugLogValue: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "<empty>" : trimmed
    }
}

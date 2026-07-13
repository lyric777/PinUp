import ApplicationServices
import AppKit
import CoreGraphics

@MainActor
final class WindowInteractionService {
    private var target: TargetWindowDescriptor?
    private var activeDragSession: DragSession?
    private var preparedTargetFrame: CGRect?
    private var restoreMouseEventsWorkItem: DispatchWorkItem?
    weak var overlayWindow: NSWindow?

    func setTarget(_ target: TargetWindowDescriptor) {
        self.target = target
        preparedTargetFrame = nil
    }

    func clearTarget() {
        cancelDrag()
        target = nil
        preparedTargetFrame = nil
        restoreMouseEventsWorkItem?.cancel()
        restoreMouseEventsWorkItem = nil
    }

    func prepareInteraction(force: Bool = false) {
        guard let target else {
            return
        }

        guard force || preparedTargetFrame == nil else {
            return
        }

        focusTargetWindow(target)
        preparedTargetFrame = currentFrame(for: target)
    }

    func click(at normalizedPoint: CGPoint, button: CGMouseButton, clickCount: Int) {
        postMouseSequence(
            [
                MouseEventRequest(phase: .down, normalizedPoint: normalizedPoint),
                MouseEventRequest(phase: .up, normalizedPoint: normalizedPoint),
            ],
            button: button,
            clickCount: clickCount
        )
    }

    func beginDrag(at normalizedPoint: CGPoint, button: CGMouseButton) -> Bool {
        guard let target else {
            PinUpDebugLogger.log("Interaction ignored: missing target for drag begin")
            return false
        }

        if preparedTargetFrame == nil {
            focusTargetWindow(target)
        }

        let targetFrame = preparedTargetFrame ?? currentFrame(for: target)
        guard let targetFrame else {
            PinUpDebugLogger.log("Interaction failed: target window disappeared before drag begin")
            return false
        }

        let session = DragSession(targetFrame: targetFrame, button: button)
        activeDragSession = session

        guard postMouseEvent(phase: .down, normalizedPoint: normalizedPoint, targetFrame: targetFrame, button: button, clickCount: 1) else {
            activeDragSession = nil
            restoreOverlayMouseEvents(after: 0.02)
            return false
        }

        return true
    }

    func continueDrag(at normalizedPoint: CGPoint, button: CGMouseButton) {
        guard let session = activeDragSession else {
            PinUpDebugLogger.log("Interaction ignored: drag update without active drag")
            return
        }

        guard session.button == button else {
            PinUpDebugLogger.log("Interaction ignored: drag button changed during active drag")
            return
        }

        _ = postMouseEvent(phase: .dragged, normalizedPoint: normalizedPoint, targetFrame: session.targetFrame, button: button, clickCount: 1)
    }

    func endDrag(at normalizedPoint: CGPoint, button: CGMouseButton) {
        guard let session = activeDragSession else {
            return
        }

        let endButton = session.button == button ? button : session.button
        _ = postMouseEvent(phase: .up, normalizedPoint: normalizedPoint, targetFrame: session.targetFrame, button: endButton, clickCount: 1)
        activeDragSession = nil
        restoreOverlayMouseEvents(after: 0.04)
    }

    func cancelDrag() {
        guard let session = activeDragSession else {
            return
        }

        _ = postMouseEvent(phase: .up, normalizedPoint: CGPoint(x: 0.5, y: 0.5), targetFrame: session.targetFrame, button: session.button, clickCount: 1)
        activeDragSession = nil
        restoreOverlayMouseEvents(after: 0.04)
    }

    func scroll(at normalizedPoint: CGPoint, deltaX: CGFloat, deltaY: CGFloat) {
        guard let target else {
            PinUpDebugLogger.log("Interaction ignored: missing target for scroll event")
            return
        }

        prepareInteraction()

        guard let targetFrame = preparedTargetFrame ?? currentFrame(for: target) else {
            PinUpDebugLogger.log("Interaction failed: target window disappeared before scroll event")
            return
        }
        preparedTargetFrame = targetFrame

        let location = targetPoint(in: targetFrame, normalizedPoint: normalizedPoint)
        guard
            let event = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 2,
                wheel1: Int32(deltaY.rounded()),
                wheel2: Int32(deltaX.rounded()),
                wheel3: 0
            )
        else {
            PinUpDebugLogger.log("Interaction failed: could not create scroll event")
            return
        }

        event.location = location
        postThroughOverlay([event], restoresCursor: false, restoreDelay: 0.001)
    }

    private func postMouseSequence(_ requests: [MouseEventRequest], button: CGMouseButton, clickCount: Int) {
        guard let target else {
            PinUpDebugLogger.log("Interaction ignored: missing target for mouse event")
            return
        }

        prepareInteraction()

        guard let targetFrame = preparedTargetFrame ?? currentFrame(for: target) else {
            PinUpDebugLogger.log("Interaction failed: target window disappeared before mouse event")
            return
        }
        preparedTargetFrame = targetFrame

        let events = requests.compactMap { request in
            makeMouseEvent(phase: request.phase, normalizedPoint: request.normalizedPoint, targetFrame: targetFrame, button: button, clickCount: clickCount)
        }

        guard events.count == requests.count else {
            return
        }

        postThroughOverlay(events)
    }

    private func postMouseEvent(phase: MousePhase, normalizedPoint: CGPoint, targetFrame: CGRect, button: CGMouseButton, clickCount: Int) -> Bool {
        guard let event = makeMouseEvent(phase: phase, normalizedPoint: normalizedPoint, targetFrame: targetFrame, button: button, clickCount: clickCount) else {
            return false
        }

        postThroughOverlay([event], restoresCursor: true, restoreDelay: 0.001)
        return true
    }

    private func makeMouseEvent(phase: MousePhase, normalizedPoint: CGPoint, targetFrame: CGRect, button: CGMouseButton, clickCount: Int) -> CGEvent? {
        let location = targetPoint(in: targetFrame, normalizedPoint: normalizedPoint)
        guard let event = CGEvent(mouseEventSource: nil, mouseType: phase.eventType(for: button), mouseCursorPosition: location, mouseButton: button) else {
            PinUpDebugLogger.log("Interaction failed: could not create mouse event")
            return nil
        }

        event.setIntegerValueField(.mouseEventClickState, value: Int64(max(clickCount, 1)))
        event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button.rawValue))
        event.location = location
        return event
    }

    private func postThroughOverlay(_ events: [CGEvent], restoresCursor: Bool = true, restoreDelay: TimeInterval = 0.002) {
        let cursorLocationBeforePost = restoresCursor ? CGEvent(source: nil)?.location : nil
        restoreMouseEventsWorkItem?.cancel()
        overlayWindow?.ignoresMouseEvents = true

        for event in events {
            event.post(tap: .cghidEventTap)
        }

        if let cursorLocationBeforePost {
            CGWarpMouseCursorPosition(cursorLocationBeforePost)
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.overlayWindow?.ignoresMouseEvents = false
            self?.restoreMouseEventsWorkItem = nil
        }
        restoreMouseEventsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay, execute: workItem)
    }

    private func restoreOverlayMouseEvents(after delay: TimeInterval) {
        restoreMouseEventsWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.overlayWindow?.ignoresMouseEvents = false
            self?.restoreMouseEventsWorkItem = nil
        }
        restoreMouseEventsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func focusTargetWindow(_ target: TargetWindowDescriptor) {
        guard let app = NSRunningApplication(processIdentifier: target.pid), !app.isTerminated else {
            PinUpDebugLogger.log("Interaction failed: target app is not running, pid=\(target.pid)")
            return
        }

        if !app.activate(options: []) {
            PinUpDebugLogger.log("Interaction warning: could not activate target app, pid=\(target.pid)")
        }

        let appElement = AXUIElementCreateApplication(target.pid)
        guard let window = findAXWindow(for: target, appElement: appElement, referenceFrame: currentFrame(for: target) ?? target.frame) else {
            PinUpDebugLogger.log("Interaction warning: could not find AX window for \(target.debugSummary)")
            return
        }

        let raiseResult = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        if raiseResult != .success {
            PinUpDebugLogger.log("Interaction warning: AX raise failed with \(raiseResult.rawValue)")
        }

        let focusResult = AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, window)
        if focusResult != .success {
            PinUpDebugLogger.log("Interaction warning: AX focus failed with \(focusResult.rawValue)")
        }
    }

    private func findAXWindow(for target: TargetWindowDescriptor, appElement: AXUIElement, referenceFrame: CGRect) -> AXUIElement? {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
            let windows = value as? [AXUIElement]
        else {
            return nil
        }

        let targetTitle = target.windowTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return windows.max { left, right in
            score(window: left, targetTitle: targetTitle, targetFrame: referenceFrame) < score(window: right, targetTitle: targetTitle, targetFrame: referenceFrame)
        }
    }

    private func score(window: AXUIElement, targetTitle: String, targetFrame: CGRect) -> Int {
        var score = 0
        let title = copyStringAttribute(kAXTitleAttribute as CFString, from: window)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""

        if !targetTitle.isEmpty {
            if title == targetTitle {
                score += 120
            } else if title.contains(targetTitle) || targetTitle.contains(title) {
                score += 70
            }
        }

        let frame = copyFrame(from: window)
        if !frame.equalTo(.zero), !targetFrame.equalTo(.zero) {
            let distance = hypot(frame.midX - targetFrame.midX, frame.midY - targetFrame.midY)
            score += max(0, 80 - Int(distance / 12))

            let areaDelta = abs((frame.width * frame.height) - (targetFrame.width * targetFrame.height))
            score += max(0, 40 - Int(areaDelta / 1_000))
        }

        return score
    }

    private func currentFrame(for target: TargetWindowDescriptor) -> CGRect? {
        if
            let rawWindowList = CGWindowListCopyWindowInfo([.optionIncludingWindow], target.cgWindowID) as? [[String: Any]],
            let boundsDictionary = rawWindowList.first?[kCGWindowBounds as String] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: boundsDictionary),
            bounds.width > 0,
            bounds.height > 0
        {
            return bounds
        }

        let appElement = AXUIElementCreateApplication(target.pid)
        return findAXWindow(for: target, appElement: appElement, referenceFrame: target.frame).map(copyFrame(from:))
    }

    private func targetPoint(in targetFrame: CGRect, normalizedPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: targetFrame.minX + targetFrame.width * normalizedPoint.x,
            y: targetFrame.minY + targetFrame.height * (1 - normalizedPoint.y)
        )
    }

    private func copyStringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }

        return value as? String
    }

    private func copyFrame(from element: AXUIElement) -> CGRect {
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

private struct MouseEventRequest {
    let phase: MousePhase
    let normalizedPoint: CGPoint
}

private struct DragSession {
    let targetFrame: CGRect
    let button: CGMouseButton
}

private enum MousePhase {
    case down
    case dragged
    case up

    func eventType(for button: CGMouseButton) -> CGEventType {
        switch (self, button) {
        case (.down, .left):
            return .leftMouseDown
        case (.dragged, .left):
            return .leftMouseDragged
        case (.up, .left):
            return .leftMouseUp
        case (.down, .right):
            return .rightMouseDown
        case (.dragged, .right):
            return .rightMouseDragged
        case (.up, .right):
            return .rightMouseUp
        case (.down, _):
            return .otherMouseDown
        case (.dragged, _):
            return .otherMouseDragged
        case (.up, _):
            return .otherMouseUp
        }
    }
}

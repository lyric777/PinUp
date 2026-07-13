import AppKit
import SwiftUI

struct InteractionCaptureView: NSViewRepresentable {
    let imageSize: CGSize
    let interactionService: WindowInteractionService

    func makeNSView(context: Context) -> InteractionCaptureNSView {
        let view = InteractionCaptureNSView()
        view.interactionService = interactionService
        view.imageSize = imageSize
        return view
    }

    func updateNSView(_ nsView: InteractionCaptureNSView, context: Context) {
        nsView.interactionService = interactionService
        nsView.imageSize = imageSize
    }
}

final class InteractionCaptureNSView: NSView {
    private enum Layout {
        static let dragStartThreshold: CGFloat = 1
    }

    weak var interactionService: WindowInteractionService?
    var imageSize: CGSize = .zero

    private var moveDragStartPoint: NSPoint?
    private var moveDragStartFrame: NSRect?
    private var pendingMouseDown: PendingMouseDown?
    private var isForwardingDrag = false
    private var suppressPendingClick = false
    private var lastForwardedDragPoint: CGPoint?
    private var mouseUpMonitor: Any?

    override var acceptsFirstResponder: Bool {
        false
    }

    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.option) {
            beginOverlayMove(with: event)
            return
        }

        recordMouseDown(event, button: .left)
    }

    override func mouseDragged(with event: NSEvent) {
        if moveDragStartPoint != nil {
            moveOverlay(with: event)
            return
        }

        recordMouseDrag(event)
    }

    override func mouseUp(with event: NSEvent) {
        if moveDragStartPoint != nil {
            endOverlayMove()
            return
        }

        forwardCompletedMouseSequence(event)
    }

    override func rightMouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.option) {
            beginOverlayMove(with: event)
            return
        }

        recordMouseDown(event, button: .right)
    }

    override func rightMouseDragged(with event: NSEvent) {
        if moveDragStartPoint != nil {
            moveOverlay(with: event)
            return
        }

        recordMouseDrag(event)
    }

    override func rightMouseUp(with event: NSEvent) {
        if moveDragStartPoint != nil {
            endOverlayMove()
            return
        }

        forwardCompletedMouseSequence(event)
    }

    override func scrollWheel(with event: NSEvent) {
        guard let point = normalizedImagePoint(for: event) else {
            return
        }

        interactionService?.scroll(at: point, deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY)
    }

    private func recordMouseDown(_ event: NSEvent, button: CGMouseButton) {
        guard let point = imagePoint(for: event, clampsToImage: false) else {
            return
        }

        pendingMouseDown = PendingMouseDown(
            point: point.normalizedPoint,
            localPoint: point.localPoint,
            button: button,
            clickCount: event.clickCount
        )
        isForwardingDrag = false
        suppressPendingClick = false
        lastForwardedDragPoint = nil
        stopMouseUpMonitor()
        interactionService?.prepareInteraction()
    }

    private func recordMouseDrag(_ event: NSEvent) {
        guard
            let pendingMouseDown,
            let dragPoint = imagePoint(for: event, clampsToImage: true)
        else {
            return
        }

        if isForwardingDrag {
            interactionService?.continueDrag(at: dragPoint.normalizedPoint, button: pendingMouseDown.button)
            lastForwardedDragPoint = dragPoint.normalizedPoint
            return
        }

        guard distance(from: pendingMouseDown.localPoint, to: dragPoint.localPoint) >= Layout.dragStartThreshold else {
            return
        }

        guard interactionService?.beginDrag(at: pendingMouseDown.point, button: pendingMouseDown.button) == true else {
            self.pendingMouseDown = nil
            suppressPendingClick = true
            return
        }

        isForwardingDrag = true
        lastForwardedDragPoint = dragPoint.normalizedPoint
        startMouseUpMonitor()
        interactionService?.continueDrag(at: dragPoint.normalizedPoint, button: pendingMouseDown.button)
    }

    private func forwardCompletedMouseSequence(_ event: NSEvent) {
        guard let pendingMouseDown else {
            suppressPendingClick = false
            stopMouseUpMonitor()
            return
        }

        let upPoint = normalizedImagePoint(for: event, clampsToImage: true) ?? pendingMouseDown.point
        let wasForwardingDrag = isForwardingDrag
        let shouldSuppressClick = suppressPendingClick

        self.pendingMouseDown = nil
        isForwardingDrag = false
        suppressPendingClick = false
        lastForwardedDragPoint = nil
        stopMouseUpMonitor()

        if wasForwardingDrag {
            interactionService?.endDrag(at: upPoint, button: pendingMouseDown.button)
        } else if !shouldSuppressClick {
            interactionService?.click(at: pendingMouseDown.point, button: pendingMouseDown.button, clickCount: pendingMouseDown.clickCount)
        }
    }

    private func cancelForwardedDragIfNeeded() {
        if isForwardingDrag {
            interactionService?.cancelDrag()
        }

        pendingMouseDown = nil
        isForwardingDrag = false
        suppressPendingClick = false
        lastForwardedDragPoint = nil
        stopMouseUpMonitor()
    }

    private func finishForwardedDragFromMonitor() {
        guard isForwardingDrag, let pendingMouseDown else {
            return
        }

        let upPoint = lastForwardedDragPoint ?? pendingMouseDown.point
        self.pendingMouseDown = nil
        isForwardingDrag = false
        suppressPendingClick = false
        lastForwardedDragPoint = nil
        stopMouseUpMonitor()
        interactionService?.endDrag(at: upPoint, button: pendingMouseDown.button)
    }

    private func startMouseUpMonitor() {
        guard mouseUpMonitor == nil else {
            return
        }

        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.finishForwardedDragFromMonitor()
            }
        }
    }

    private func stopMouseUpMonitor() {
        if let mouseUpMonitor {
            NSEvent.removeMonitor(mouseUpMonitor)
            self.mouseUpMonitor = nil
        }
    }

    private func beginOverlayMove(with event: NSEvent) {
        guard let window else {
            return
        }

        moveDragStartPoint = window.convertPoint(toScreen: event.locationInWindow)
        moveDragStartFrame = window.frame
    }

    private func moveOverlay(with event: NSEvent) {
        guard
            let window,
            let moveDragStartPoint,
            let moveDragStartFrame
        else {
            return
        }

        let currentPoint = window.convertPoint(toScreen: event.locationInWindow)
        var nextFrame = moveDragStartFrame
        nextFrame.origin.x += currentPoint.x - moveDragStartPoint.x
        nextFrame.origin.y += currentPoint.y - moveDragStartPoint.y
        window.setFrame(nextFrame, display: true)
    }

    private func endOverlayMove() {
        moveDragStartPoint = nil
        moveDragStartFrame = nil
        cancelForwardedDragIfNeeded()
    }

    private func normalizedImagePoint(for event: NSEvent) -> CGPoint? {
        normalizedImagePoint(for: event, clampsToImage: false)
    }

    private func normalizedImagePoint(for event: NSEvent, clampsToImage: Bool) -> CGPoint? {
        imagePoint(for: event, clampsToImage: clampsToImage)?.normalizedPoint
    }

    private func imagePoint(for event: NSEvent, clampsToImage: Bool) -> ImagePoint? {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return nil
        }

        var localPoint = convert(event.locationInWindow, from: nil)
        let imageRect = aspectFitRect(imageSize: imageSize, in: bounds)
        guard imageRect.width > 0, imageRect.height > 0 else {
            return nil
        }

        if clampsToImage {
            localPoint.x = min(max(localPoint.x, imageRect.minX), imageRect.maxX)
            localPoint.y = min(max(localPoint.y, imageRect.minY), imageRect.maxY)
        } else if !imageRect.contains(localPoint) {
            return nil
        }

        return ImagePoint(
            normalizedPoint: CGPoint(
                x: (localPoint.x - imageRect.minX) / imageRect.width,
                y: (localPoint.y - imageRect.minY) / imageRect.height
            ),
            localPoint: localPoint
        )
    }

    private func aspectFitRect(imageSize: CGSize, in bounds: CGRect) -> CGRect {
        let imageAspectRatio = imageSize.width / imageSize.height
        let boundsAspectRatio = bounds.width / bounds.height

        if imageAspectRatio > boundsAspectRatio {
            let height = bounds.width / imageAspectRatio
            return CGRect(
                x: bounds.minX,
                y: bounds.midY - height / 2,
                width: bounds.width,
                height: height
            )
        }

        let width = bounds.height * imageAspectRatio
        return CGRect(
            x: bounds.midX - width / 2,
            y: bounds.minY,
            width: width,
            height: bounds.height
        )
    }

    private func distance(from startPoint: CGPoint, to endPoint: CGPoint) -> CGFloat {
        hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y)
    }
}

private struct ImagePoint {
    let normalizedPoint: CGPoint
    let localPoint: CGPoint
}

private struct PendingMouseDown {
    let point: CGPoint
    let localPoint: CGPoint
    let button: CGMouseButton
    let clickCount: Int
}

import AppKit
import SwiftUI

@MainActor
final class OverlayPanelController: NSObject, NSWindowDelegate {
    let viewModel = OverlayViewModel()
    private let interactionService = WindowInteractionService()

    var onClose: (() -> Void)?

    private var panel: FloatingOverlayPanel?
    private var isWaitingToRevealFirstFrame = false
    private var isCursorInsidePanel = false
    private var target: TargetWindowDescriptor?
    private var followTask: Task<Void, Never>?

    func show(for target: TargetWindowDescriptor) {
        let panel = panel ?? makePanel()
        isWaitingToRevealFirstFrame = true
        self.target = target
        interactionService.setTarget(target)
        interactionService.overlayWindow = panel
        viewModel.titleText = target.displayName
        viewModel.statusText = L10n.tr("starting_live_preview")
        viewModel.showsProgress = true
        panel.title = target.displayName
        panel.contentAspectRatio = target.frame.size
        panel.setFrame(Self.panelFrame(for: target), display: true, animate: false)
        panel.alphaValue = 0
        panel.ignoresMouseEvents = true
        isCursorInsidePanel = false
        panel.orderFrontRegardless()
        self.panel = panel
        startFollowingTarget()
    }

    func update(image: CGImage?) {
        viewModel.image = image
        if image != nil {
            viewModel.statusText = L10n.tr("live")
            viewModel.showsProgress = false
        }

        if let image, let panel {
            panel.contentAspectRatio = NSSize(width: image.width, height: image.height)
            syncPanelToTarget()
            revealPanelIfNeeded(panel)
        }
    }

    func update(status: String, showsProgress: Bool = true) {
        viewModel.statusText = status
        viewModel.showsProgress = showsProgress

        if !showsProgress, let panel {
            revealPanelIfNeeded(panel)
        }
    }

    func close() {
        followTask?.cancel()
        followTask = nil
        target = nil
        isCursorInsidePanel = false
        panel?.close()
        panel = nil
        isWaitingToRevealFirstFrame = false
        interactionService.overlayWindow = nil
        interactionService.clearTarget()
        viewModel.image = nil
        viewModel.showsProgress = true
    }

    private func revealPanelIfNeeded(_ panel: NSPanel) {
        guard isWaitingToRevealFirstFrame else {
            return
        }

        isWaitingToRevealFirstFrame = false
        panel.alphaValue = 1
        panel.ignoresMouseEvents = true
    }

    private func makePanel() -> FloatingOverlayPanel {
        let hostingController = NSHostingController(rootView: PinnedOverlayView(viewModel: viewModel, interactionService: interactionService))
        let panel = FloatingOverlayPanel(
            contentRect: NSRect(x: 220, y: 220, width: 480, height: 320),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.delegate = self
        panel.contentViewController = hostingController
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.center()
        return panel
    }

    private func startFollowingTarget() {
        followTask?.cancel()
        followTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.syncPanelToTarget()
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    private func syncPanelToTarget() {
        guard let panel, let target else {
            return
        }

        let frame = Self.currentPanelFrame(for: target) ?? Self.panelFrame(for: target)
        if !panel.frame.equalTo(frame) {
            panel.setFrame(frame, display: true, animate: false)
        }

        panel.ignoresMouseEvents = true
        activateTargetIfCursorEnteredPanel(panel)
    }

    private func activateTargetIfCursorEnteredPanel(_ panel: NSPanel) {
        let isInside = panel.frame.contains(NSEvent.mouseLocation)
        defer {
            isCursorInsidePanel = isInside
        }

        guard isInside, !isCursorInsidePanel else {
            return
        }

        interactionService.prepareInteraction(force: true)
        panel.orderFrontRegardless()
    }

    private static func currentPanelFrame(for target: TargetWindowDescriptor) -> NSRect? {
        guard
            let rawWindowList = CGWindowListCopyWindowInfo([.optionIncludingWindow], target.cgWindowID) as? [[String: Any]],
            let boundsDictionary = rawWindowList.first?[kCGWindowBounds as String] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: boundsDictionary),
            bounds.width > 0,
            bounds.height > 0
        else {
            return nil
        }

        let screen = screen(containingCGWindowFrame: bounds)
        return appKitFrame(forCGWindowFrame: bounds, on: screen)
    }

    private static func panelFrame(for target: TargetWindowDescriptor) -> NSRect {
        let screen = screen(containingCGWindowFrame: target.frame)
        return appKitFrame(forCGWindowFrame: target.frame, on: screen)
            ?? NSRect(origin: .zero, size: target.frame.size)
    }

    private static func screen(containingCGWindowFrame rect: CGRect) -> NSScreen? {
        let displayID = activeDisplays()
            .max { left, right in
                CGDisplayBounds(left).intersection(rect).area < CGDisplayBounds(right).intersection(rect).area
            }

        guard let displayID else {
            return screen(containing: rect)
        }

        return NSScreen.screens.first { screen in
            screen.displayID == displayID
        } ?? screen(containing: rect)
    }

    private static func appKitFrame(forCGWindowFrame cgFrame: CGRect, on screen: NSScreen?) -> NSRect? {
        guard let screen, let displayID = screen.displayID else {
            return nil
        }

        let displayBounds = CGDisplayBounds(displayID)
        let xOffset = cgFrame.minX - displayBounds.minX
        let yOffsetFromTop = cgFrame.minY - displayBounds.minY
        return NSRect(
            x: screen.frame.minX + xOffset,
            y: screen.frame.maxY - yOffsetFromTop - cgFrame.height,
            width: cgFrame.width,
            height: cgFrame.height
        )
    }

    private static func activeDisplays() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else {
            return []
        }

        var displays = Array(repeating: CGDirectDisplayID(), count: Int(displayCount))
        guard CGGetActiveDisplayList(displayCount, &displays, &displayCount) == .success else {
            return []
        }

        return Array(displays.prefix(Int(displayCount)))
    }

    private static func screen(containing rect: CGRect) -> NSScreen? {
        NSScreen.screens.max { left, right in
            left.frame.intersection(rect).area < right.frame.intersection(rect).area
        }
    }

    func windowWillClose(_ notification: Notification) {
        followTask?.cancel()
        followTask = nil
        target = nil
        panel = nil
        viewModel.image = nil
        onClose?()
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else {
            return 0
        }

        return width * height
    }
}

final class FloatingOverlayPanel: NSPanel {
    override var canBecomeMain: Bool { false }
    override var canBecomeKey: Bool { false }
}

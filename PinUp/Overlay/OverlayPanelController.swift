import AppKit
import SwiftUI

@MainActor
final class OverlayPanelController: NSObject, NSWindowDelegate {
    private enum Layout {
        static let horizontalMargin: CGFloat = 24
        static let topMargin: CGFloat = 48
        static let bottomMargin: CGFloat = 24
        static let minContentWidth: CGFloat = 180
        static let minContentHeight: CGFloat = 160
    }

    let viewModel = OverlayViewModel()

    var onClose: (() -> Void)?

    private var panel: FloatingOverlayPanel?
    private var didFitPanelToFirstFrame = false

    func show(for target: TargetWindowDescriptor) {
        let panel = panel ?? makePanel()
        didFitPanelToFirstFrame = false
        viewModel.titleText = target.displayName
        viewModel.statusText = L10n.tr("starting_live_preview")
        viewModel.showsProgress = true
        panel.title = target.displayName
        panel.contentAspectRatio = target.frame.size
        panel.setFrame(Self.initialPanelFrame(for: target, panel: panel), display: true, animate: false)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func update(image: CGImage?) {
        viewModel.image = image
        if image != nil {
            viewModel.statusText = L10n.tr("live")
            viewModel.showsProgress = false
        }

        if let image, let panel {
            panel.contentAspectRatio = NSSize(width: image.width, height: image.height)
            if !didFitPanelToFirstFrame {
                didFitPanelToFirstFrame = true
                fitPanel(panel, to: image)
            }
        }
    }

    func update(status: String, showsProgress: Bool = true) {
        viewModel.statusText = status
        viewModel.showsProgress = showsProgress
    }

    func close() {
        panel?.close()
        panel = nil
        didFitPanelToFirstFrame = false
        viewModel.image = nil
        viewModel.showsProgress = true
    }

    private func fitPanel(_ panel: NSPanel, to image: CGImage) {
        let visibleFrame = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let scale = panel.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        let targetContentSize = NSSize(
            width: CGFloat(image.width) / scale,
            height: CGFloat(image.height) / scale
        )
        let fittedContentSize = Self.fittedSize(targetContentSize, in: visibleFrame, panel: panel)
        let currentFrame = panel.frame
        let nextFrame = Self.frameKeepingTopLeft(
            currentFrame: currentFrame,
            contentSize: fittedContentSize,
            visibleFrame: visibleFrame,
            panel: panel
        )

        panel.setFrame(nextFrame, display: true, animate: false)
        PinUpDebugLogger.log("Fit overlay to first frame: image=\(image.width)x\(image.height), scale=\(String(format: "%.1f", scale)), targetContent=\(Int(targetContentSize.width))x\(Int(targetContentSize.height)), fittedContent=\(Int(fittedContentSize.width))x\(Int(fittedContentSize.height)), visible=\(Int(visibleFrame.width))x\(Int(visibleFrame.height))")
    }

    private func makePanel() -> FloatingOverlayPanel {
        let hostingController = NSHostingController(rootView: PinnedOverlayView(viewModel: viewModel))
        let panel = FloatingOverlayPanel(
            contentRect: NSRect(x: 220, y: 220, width: 480, height: 320),
            styleMask: [.borderless, .resizable],
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
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.center()
        return panel
    }

    private static func initialPanelFrame(for target: TargetWindowDescriptor, panel: NSPanel) -> NSRect {
        let screen = screen(containingCGWindowFrame: target.frame)
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let targetSize = target.frame.size
        let contentSize = fittedSize(targetSize, in: visibleFrame, panel: panel)

        let windowSize = panel.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
        let targetFrame = appKitFrame(forCGWindowFrame: target.frame, on: screen)
        let origin = targetFrame.map { NSPoint(x: $0.minX, y: $0.maxY - windowSize.height) }
            ?? NSPoint(
                x: visibleFrame.maxX - windowSize.width - Layout.horizontalMargin,
                y: visibleFrame.maxY - windowSize.height - Layout.topMargin
            )

        let frame = NSRect(origin: origin, size: windowSize)
        return visibleFrame.contains(frame) ? frame : centeredFrame(size: frame.size, in: visibleFrame)
    }

    private static func centeredFrame(size: NSSize, in visibleFrame: NSRect) -> NSRect {
        NSRect(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private static func fittedSize(_ size: NSSize, in visibleFrame: NSRect, panel: NSPanel) -> NSSize {
        let availableWindowSize = NSSize(
            width: max(Layout.minContentWidth, visibleFrame.width - Layout.horizontalMargin * 2),
            height: max(Layout.minContentHeight, visibleFrame.height - Layout.topMargin - Layout.bottomMargin)
        )
        let availableContentSize = panel.contentRect(forFrameRect: NSRect(origin: .zero, size: availableWindowSize)).size
        let maxWidth = max(Layout.minContentWidth, availableContentSize.width)
        let maxHeight = max(Layout.minContentHeight, availableContentSize.height)
        let aspectRatio = max(size.width, 1) / max(size.height, 1)

        var width = min(size.width, maxWidth)
        var height = width / aspectRatio

        if height > maxHeight {
            height = maxHeight
            width = height * aspectRatio
        }

        width = max(Layout.minContentWidth, width)
        height = max(Layout.minContentHeight, height)

        return NSSize(width: width, height: height)
    }

    private static func frameKeepingTopLeft(currentFrame: NSRect, contentSize: NSSize, visibleFrame: NSRect, panel: NSPanel) -> NSRect {
        let windowSize = panel.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
        let topLeft = NSPoint(x: currentFrame.minX, y: currentFrame.maxY)
        var frame = NSRect(
            x: topLeft.x,
            y: topLeft.y - windowSize.height,
            width: windowSize.width,
            height: windowSize.height
        )

        if frame.maxX > visibleFrame.maxX {
            frame.origin.x = visibleFrame.maxX - frame.width - Layout.horizontalMargin
        }

        if frame.maxY > visibleFrame.maxY {
            frame.origin.y = visibleFrame.maxY - frame.height - Layout.topMargin
        }

        if frame.minX < visibleFrame.minX {
            frame.origin.x = visibleFrame.minX + Layout.horizontalMargin
        }

        if frame.minY < visibleFrame.minY {
            frame.origin.y = visibleFrame.minY + Layout.bottomMargin
        }

        return frame
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
    override var canBecomeKey: Bool { true }
}

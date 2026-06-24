import AppKit
import SwiftUI

@MainActor
final class OverlayPanelController: NSObject, NSWindowDelegate {
    let viewModel = OverlayViewModel()

    var onClose: (() -> Void)?

    private var panel: FloatingOverlayPanel?

    func show(for target: TargetWindowDescriptor) {
        let panel = panel ?? makePanel()
        viewModel.titleText = target.displayName
        viewModel.statusText = "Starting live preview…"
        viewModel.showsProgress = true
        panel.title = target.displayName
        panel.setFrameAutosaveName("PinUpOverlay")
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func update(image: CGImage?) {
        viewModel.image = image
        if image != nil {
            viewModel.statusText = "Live"
            viewModel.showsProgress = false
        }
    }

    func update(status: String, showsProgress: Bool = true) {
        viewModel.statusText = status
        viewModel.showsProgress = showsProgress
    }

    func close() {
        panel?.close()
        panel = nil
        viewModel.image = nil
        viewModel.showsProgress = true
    }

    private func makePanel() -> FloatingOverlayPanel {
        let hostingController = NSHostingController(rootView: PinnedOverlayView(viewModel: viewModel))
        let panel = FloatingOverlayPanel(
            contentRect: NSRect(x: 220, y: 220, width: 480, height: 320),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
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
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.center()
        return panel
    }

    func windowWillClose(_ notification: Notification) {
        panel = nil
        viewModel.image = nil
        onClose?()
    }
}

final class FloatingOverlayPanel: NSPanel {
    override var canBecomeMain: Bool { false }
    override var canBecomeKey: Bool { true }
}

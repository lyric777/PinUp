import AppKit
import Carbon
import CoreGraphics
import Foundation

@MainActor
final class PinUpAppState: ObservableObject {
    static let shared = PinUpAppState()

    @Published private(set) var permissionState: PermissionState = .missingBoth
    @Published private(set) var pinState: PinSessionState = .idle
    @Published private(set) var currentTarget: TargetWindowDescriptor?
    @Published private(set) var lastErrorMessage: String?

    var isPinned: Bool {
        pinState.isPinned
    }

    var isBusy: Bool {
        pinState.isWorking
    }

    var menuBarIconName: String {
        switch pinState {
        case .idle:
            return "pin"
        case .resolvingTarget, .startingCapture:
            return "pin.circle"
        case .pinned:
            return "pin.fill"
        case .failed:
            return "exclamationmark.circle"
        }
    }

    var statusTitle: String {
        switch pinState {
        case .idle:
            return "Ready to Pin"
        case .resolvingTarget:
            return "Preparing preview…"
        case .startingCapture:
            let name = currentTarget?.appName ?? "window"
            return "Connecting to \(name)…"
        case .pinned:
            return currentTarget.map { "Pinned: \($0.displayName)" } ?? "Pinned"
        case .failed:
            return "Action Needed"
        }
    }

    private let permissionsManager = PermissionsManager()
    private let focusedWindowResolver = FocusedWindowResolver()
    private let captureService = CaptureService()
    private let overlayController = OverlayPanelController()
    private lazy var settingsController = SettingsWindowController(appState: self)
    private lazy var permissionsController = PermissionsWindowController(appState: self)

    private var didStart = false
    private var captureAttemptID = UUID()
    private var hasReceivedFirstFrame = false

    private init() {
        captureService.onFrame = { [weak self] image in
            self?.handleIncomingFrame(image)
        }

        captureService.onFailure = { [weak self] message in
            Task { @MainActor in
                self?.handleCaptureFailure(message: message)
            }
        }

        overlayController.onClose = { [weak self] in
            Task { @MainActor in
                await self?.unpinCurrentWindow()
            }
        }
    }

    func start() {
        guard !didStart else {
            return
        }

        didStart = true
        registerHotkeys()
        refreshPermissions()

        if permissionState != .ready {
            permissionsController.show()
        }
    }

    func refreshPermissions() {
        permissionState = permissionsManager.currentPermissionState()
    }

    func requestAccessibilityPrompt() {
        permissionsManager.requestAccessibilityPrompt()
    }

    func requestScreenRecordingPrompt() {
        permissionsManager.requestScreenRecordingPrompt()
    }

    func openSystemSettingsForPermissions() {
        permissionsManager.openSystemSettings(for: permissionState)
    }

    func showSettings() {
        settingsController.show()
    }

    func pinFocusedWindow() async {
        refreshPermissions()
        guard permissionState == .ready else {
            setFailure(PinUpError.missingPermissions(permissionState))
            permissionsController.show()
            return
        }

        pinState = .resolvingTarget
        lastErrorMessage = nil
        hasReceivedFirstFrame = false
        captureAttemptID = UUID()
        overlayController.update(status: "Preparing preview…", showsProgress: true)

        do {
            let target = try focusedWindowResolver.resolveFocusedWindow()
            currentTarget = target
            overlayController.show(for: target)
            overlayController.update(status: "Connecting to \(target.appName)…", showsProgress: true)

            pinState = .startingCapture
            try await captureService.startCapture(for: target)
            scheduleFirstFrameTimeout(for: captureAttemptID, target: target)
        } catch {
            overlayController.close()
            currentTarget = nil
            setFailure(error)
        }
    }

    func unpinCurrentWindow() async {
        captureAttemptID = UUID()
        hasReceivedFirstFrame = false
        await captureService.stopCapture()
        currentTarget = nil
        pinState = .idle
        lastErrorMessage = nil
        overlayController.close()
    }

    private func registerHotkeys() {
        HotkeyManager.shared.register(
            identifier: 1,
            keyCode: UInt32(kVK_ANSI_P),
            modifiers: UInt32(optionKey) | UInt32(cmdKey)
        ) { [weak self] in
            Task { @MainActor in
                await self?.pinFocusedWindow()
            }
        }

        HotkeyManager.shared.register(
            identifier: 2,
            keyCode: UInt32(kVK_ANSI_U),
            modifiers: UInt32(optionKey) | UInt32(cmdKey)
        ) { [weak self] in
            Task { @MainActor in
                await self?.unpinCurrentWindow()
            }
        }
    }

    private func handleCaptureFailure(message: String) {
        overlayController.close()
        currentTarget = nil
        hasReceivedFirstFrame = false
        pinState = .failed("Capture failed")
        lastErrorMessage = PinUpError.captureFailed(message).localizedDescription
    }

    private func setFailure(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        pinState = .failed(message)
        lastErrorMessage = message
        overlayController.update(status: message, showsProgress: false)
    }

    private func handleIncomingFrame(_ image: CGImage?) {
        overlayController.update(image: image)

        guard image != nil else {
            return
        }

        hasReceivedFirstFrame = true
        if pinState != .pinned {
            pinState = .pinned
            overlayController.update(status: "Pinned", showsProgress: false)
        }
    }

    private func scheduleFirstFrameTimeout(for attemptID: UUID, target: TargetWindowDescriptor) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))

            guard self.captureAttemptID == attemptID else {
                return
            }

            guard !self.hasReceivedFirstFrame else {
                return
            }

            await self.captureService.stopCapture()
            self.currentTarget = target
            self.pinState = .failed("Preview unavailable")
            self.lastErrorMessage = "Connected to \(target.appName), but no preview frames arrived. Try another window or retry."
            self.overlayController.update(status: "Preview unavailable for this window", showsProgress: false)
        }
    }
}

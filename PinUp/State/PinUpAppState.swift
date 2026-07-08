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
    @Published var selectedLanguage: AppLanguage = L10n.appLanguage {
        didSet {
            guard selectedLanguage != oldValue else {
                return
            }

            L10n.appLanguage = selectedLanguage
            settingsController.refreshTitle()
            permissionsController.refreshTitle()
            refreshDisplayedMessages()
        }
    }

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
            return L10n.tr("ready_to_pin")
        case .resolvingTarget:
            return L10n.tr("preparing_preview_status")
        case .startingCapture:
            let name = currentTarget?.appName ?? "window"
            return L10n.tr("connecting_to_format", name)
        case .pinned:
            return currentTarget.map { L10n.tr("pinned_format", $0.displayName) } ?? L10n.tr("pinned")
        case .failed:
            return L10n.tr("action_needed")
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
        PinUpDebugLogger.log("Permission state refreshed: \(permissionState.debugSummary)")

        if permissionState == .ready {
            permissionsController.close()
        }
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

    func copyDebugLogToClipboard() {
        let logText = PinUpDebugLogger.recentLogText()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(logText.isEmpty ? "[PinUp] No debug logs captured yet." : logText, forType: .string)
    }

    private func refreshDisplayedMessages() {
        if case .failed = pinState, let lastErrorMessage {
            overlayController.update(status: lastErrorMessage, showsProgress: false)
        }
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
        overlayController.update(status: L10n.tr("preparing_preview_status"), showsProgress: true)

        do {
            let target = try focusedWindowResolver.resolveFocusedWindow()
            currentTarget = target
            overlayController.show(for: target)
            overlayController.update(status: L10n.tr("connecting_to_format", target.appName), showsProgress: true)

            pinState = .startingCapture
            try await captureService.startCapture(for: target)
            scheduleFirstFrameTimeout(for: captureAttemptID, target: target)
        } catch {
            PinUpDebugLogger.log("Pin focused window failed: \(error.localizedDescription)")
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
        pinState = .failed(L10n.tr("capture_failed"))
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
            overlayController.update(status: L10n.tr("pinned"), showsProgress: false)
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
            self.pinState = .failed(L10n.tr("preview_unavailable"))
            self.lastErrorMessage = L10n.tr("preview_unavailable_message_format", target.appName)
            self.overlayController.update(status: L10n.tr("preview_unavailable_for_window"), showsProgress: false)
        }
    }
}

import AppKit
import Combine

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let appState: PinUpAppState
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var cancellables = Set<AnyCancellable>()

    init(appState: PinUpAppState) {
        self.appState = appState
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.behavior = .removalAllowed
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        refreshIcon()

        appState.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refreshIcon()
                }
            }
            .store(in: &cancellables)
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func refreshIcon() {
        guard let button = statusItem.button else {
            return
        }

        button.image = NSImage(
            systemSymbolName: appState.menuBarIconName,
            accessibilityDescription: "PinUp"
        )
        button.imagePosition = .imageOnly
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let statusItem = NSMenuItem(title: appState.statusTitle, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        menu.addItem(.separator())

        let pinItem = NSMenuItem(
            title: L10n.tr("pin_current_window"),
            action: #selector(pinCurrentWindow),
            keyEquivalent: "p"
        )
        pinItem.keyEquivalentModifierMask = [.command, .option]
        pinItem.target = self
        pinItem.isEnabled = !appState.isBusy
        menu.addItem(pinItem)

        let unpinItem = NSMenuItem(
            title: L10n.tr("unpin_current_window"),
            action: #selector(unpinCurrentWindow),
            keyEquivalent: "u"
        )
        unpinItem.keyEquivalentModifierMask = [.command, .option]
        unpinItem.target = self
        unpinItem.isEnabled = appState.isPinned || appState.isBusy
        menu.addItem(unpinItem)

        menu.addItem(.separator())

        addDisabledInfoItem(title: "\(L10n.tr("permissions")): \(appState.permissionState.summaryText)")

        if let currentTarget = appState.currentTarget {
            addDisabledInfoItem(title: "\(L10n.tr("target")): \(currentTarget.displayName)")
        }

        if let lastErrorMessage = appState.lastErrorMessage {
            addDisabledInfoItem(title: lastErrorMessage)
        }

        menu.addItem(.separator())

        addActionItem(title: L10n.tr("copy_debug_log"), action: #selector(copyDebugLog))
        addActionItem(title: L10n.tr("settings"), action: #selector(showSettings))

        menu.addItem(.separator())
        addActionItem(title: L10n.tr("quit"), action: #selector(quit))
    }

    private func addDisabledInfoItem(title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func addActionItem(title: String, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    @objc private func pinCurrentWindow() {
        Task {
            await appState.pinFocusedWindow()
        }
    }

    @objc private func unpinCurrentWindow() {
        Task {
            await appState.unpinCurrentWindow()
        }
    }

    @objc private func copyDebugLog() {
        appState.copyDebugLogToClipboard()
    }

    @objc private func showSettings() {
        appState.showSettings()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

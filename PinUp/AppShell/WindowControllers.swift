import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let window: NSWindow

    init(appState: PinUpAppState) {
        let rootView = SettingsView()
            .environmentObject(appState)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 330),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = L10n.tr("settings_title")
        window.isReleasedWhenClosed = false
        window.center()
        window.contentViewController = NSHostingController(rootView: rootView)
        self.window = window
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func refreshTitle() {
        window.title = L10n.tr("settings_title")
    }
}

@MainActor
final class PermissionsWindowController {
    private let window: NSWindow

    init(appState: PinUpAppState) {
        let rootView = PermissionsOnboardingView()
            .environmentObject(appState)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = L10n.tr("grant_permissions_window_title")
        window.isReleasedWhenClosed = false
        window.center()
        window.contentViewController = NSHostingController(rootView: rootView)
        self.window = window
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func refreshTitle() {
        window.title = L10n.tr("grant_permissions_window_title")
    }

    func close() {
        window.close()
    }
}

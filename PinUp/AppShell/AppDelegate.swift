import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let appState = PinUpAppState.shared
        statusItemController = StatusItemController(appState: appState)
        appState.start()
    }
}

import SwiftUI

@main
struct PinUpApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = PinUpAppState.shared

    var body: some Scene {
        MenuBarExtra("PinUp", systemImage: appState.menuBarIconName) {
            MenuBarContentView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.menu)
    }
}

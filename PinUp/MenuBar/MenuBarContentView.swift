import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var appState: PinUpAppState

    var body: some View {
        Text(appState.statusTitle)
            .font(.headline)
            .padding(.bottom, 4)

        Button("Pin Current Window") {
            Task {
                await appState.pinFocusedWindow()
            }
        }
        .keyboardShortcut("p", modifiers: [.command, .option])
        .disabled(appState.isBusy)

        Button("Unpin Current Window") {
            Task {
                await appState.unpinCurrentWindow()
            }
        }
        .keyboardShortcut("u", modifiers: [.command, .option])
        .disabled(!appState.isPinned && !appState.isBusy)

        Divider()

        Section {
            LabeledContent("Status", value: appState.pinState.summaryText)
            LabeledContent("Permissions", value: appState.permissionState.summaryText)

            if let currentTarget = appState.currentTarget {
                LabeledContent("Target", value: currentTarget.displayName)
            }

            if let lastError = appState.lastErrorMessage {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        Divider()

        Button("Copy Debug Log") {
            appState.copyDebugLogToClipboard()
        }

        Button("Settings") {
            appState.showSettings()
        }

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
}

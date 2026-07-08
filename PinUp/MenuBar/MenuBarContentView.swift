import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var appState: PinUpAppState

    var body: some View {
        Text(appState.statusTitle)
            .font(.headline)
            .padding(.bottom, 4)

        Button(L10n.tr("pin_current_window")) {
            Task {
                await appState.pinFocusedWindow()
            }
        }
        .keyboardShortcut("p", modifiers: [.command, .option])
        .disabled(appState.isBusy)

        Button(L10n.tr("unpin_current_window")) {
            Task {
                await appState.unpinCurrentWindow()
            }
        }
        .keyboardShortcut("u", modifiers: [.command, .option])
        .disabled(!appState.isPinned && !appState.isBusy)

        Divider()

        Section {
            LabeledContent(L10n.tr("permissions"), value: appState.permissionState.summaryText)

            if let currentTarget = appState.currentTarget {
                LabeledContent(L10n.tr("target"), value: currentTarget.displayName)
            }

            if let lastError = appState.lastErrorMessage {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        Divider()

        Button(L10n.tr("copy_debug_log")) {
            appState.copyDebugLogToClipboard()
        }

        Button(L10n.tr("settings")) {
            appState.showSettings()
        }

        Button(L10n.tr("quit")) {
            NSApplication.shared.terminate(nil)
        }
    }
}

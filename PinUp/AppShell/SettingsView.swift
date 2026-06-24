import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: PinUpAppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PinUp Settings")
                .font(.title2.bold())

            GroupBox("Shortcuts") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pin current window: Option + Command + P")
                    Text("Unpin current window: Option + Command + U")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Permissions") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Status: \(appState.permissionState.summaryText)")

                    HStack {
                        Button("Refresh") {
                            appState.refreshPermissions()
                        }

                        Button("Open Settings") {
                            appState.openSystemSettingsForPermissions()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Startup") {
                Text("Launch at login is intentionally left for a later iteration.")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 420, height: 280)
    }
}

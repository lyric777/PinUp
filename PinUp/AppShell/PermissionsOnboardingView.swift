import SwiftUI

struct PermissionsOnboardingView: View {
    @EnvironmentObject private var appState: PinUpAppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PinUp Needs Permissions")
                .font(.title2.bold())

            Text("PinUp uses Accessibility to detect the currently focused window and Screen Recording to mirror that window inside its own floating panel.")
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                Label("Accessibility", systemImage: appState.permissionState.hasAccessibility ? "checkmark.circle.fill" : "exclamationmark.circle")
                Label("Screen Recording", systemImage: appState.permissionState.hasScreenRecording ? "checkmark.circle.fill" : "exclamationmark.circle")
            }
            .foregroundStyle(.primary)

            HStack {
                Button("Request Accessibility") {
                    appState.requestAccessibilityPrompt()
                }
                .disabled(appState.permissionState.hasAccessibility)

                Button("Request Screen Recording") {
                    appState.requestScreenRecordingPrompt()
                }
                .disabled(appState.permissionState.hasScreenRecording)
            }

            HStack {
                Button("Open Settings") {
                    appState.openSystemSettingsForPermissions()
                }

                Button("Refresh") {
                    appState.refreshPermissions()
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 460, height: 250)
    }
}

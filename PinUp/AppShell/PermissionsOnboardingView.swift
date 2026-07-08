import SwiftUI

struct PermissionsOnboardingView: View {
    @EnvironmentObject private var appState: PinUpAppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.tr("permissions_title"))
                .font(.title2.bold())

            Text(L10n.tr("permissions_explanation"))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                Label(L10n.tr("accessibility"), systemImage: appState.permissionState.hasAccessibility ? "checkmark.circle.fill" : "exclamationmark.circle")
                Label(L10n.tr("screen_recording"), systemImage: appState.permissionState.hasScreenRecording ? "checkmark.circle.fill" : "exclamationmark.circle")
            }
            .foregroundStyle(.primary)

            HStack {
                Button(L10n.tr("request_accessibility")) {
                    appState.requestAccessibilityPrompt()
                }
                .disabled(appState.permissionState.hasAccessibility)

                Button(L10n.tr("request_screen_recording")) {
                    appState.requestScreenRecordingPrompt()
                }
                .disabled(appState.permissionState.hasScreenRecording)
            }

            HStack {
                Button(L10n.tr("open_settings")) {
                    appState.openSystemSettingsForPermissions()
                }

                Button(L10n.tr("refresh")) {
                    appState.refreshPermissions()
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 460, height: 250)
    }
}

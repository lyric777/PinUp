import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: PinUpAppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox(L10n.tr("shortcuts")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("pin_shortcut"))
                    Text(L10n.tr("unpin_shortcut"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox(L10n.tr("permissions")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("status_format", appState.permissionState.summaryText))

                    HStack {
                        Button(L10n.tr("refresh")) {
                            appState.refreshPermissions()
                        }

                        Button(L10n.tr("open_settings")) {
                            appState.openSystemSettingsForPermissions()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox(L10n.tr("language")) {
                Picker(L10n.tr("language"), selection: $appState.selectedLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName)
                            .tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }

            GroupBox(L10n.tr("startup")) {
                Text(L10n.tr("launch_at_login_later"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
        }
        .padding(.top, 18)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .frame(width: 420, height: 330)
    }
}

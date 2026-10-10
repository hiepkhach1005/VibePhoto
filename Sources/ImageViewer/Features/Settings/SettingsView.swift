import SwiftUI

struct SettingsView: View {
    @AppStorage("confirmBeforeTrash") private var confirmBeforeTrash = true
    @AppStorage("restoreLastSession") private var restoreLastSession = true

    var body: some View {
        Form {
            Section("Editing") {
                Toggle("Confirm before moving to Trash", isOn: $confirmBeforeTrash)
                LabeledContent("Rotation") { Text("Saves immediately with an Undo backup").foregroundStyle(.secondary) }
            }
            Section("Startup") {
                Toggle("Restore the last session", isOn: $restoreLastSession)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 480, height: 260)
    }
}

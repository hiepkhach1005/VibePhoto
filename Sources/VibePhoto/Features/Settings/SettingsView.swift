import AppKit
import SwiftUI

struct SettingsView: View {
    @AppStorage("confirmBeforeTrash") private var confirmBeforeTrash = true
    @AppStorage("restoreLastSession") private var restoreLastSession = true
    @ObservedObject private var folderAccess = FolderAccessStore.shared

    var body: some View {
        Form {
            Section {
                ForEach(folderAccess.pinnedFolders) { folder in
                    HStack {
                        Label(folder.displayName, systemImage: "folder.badge.person.crop")
                            .help(folder.originalPath)
                        Spacer()
                        Button("Remove") { folderAccess.unpin(folder) }
                            .help("Stop keeping permanent access to \(folder.originalPath)")
                    }
                }
                Button("Grant Access to Home Folder…", systemImage: "house") { grantFolder(FolderAccessStore.userHomeDirectory) }
                    .help("Choose your Home folder once; images in any folder inside it open without asking again")
                Button("Grant Access to Another Folder…", systemImage: "folder.badge.plus") { grantFolder(nil) }
            } header: {
                Text("Folder Access")
            } footer: {
                Text("macOS asks before an app can read a folder. Granting a parent folder once covers every folder inside it.")
                    .foregroundStyle(.secondary)
            }
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
        .frame(width: 520, height: 460)
    }

    private func grantFolder(_ suggested: URL?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = suggested
        panel.prompt = "Grant Access"
        panel.message = "VibePhoto will open images in this folder and every folder inside it without asking again."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        folderAccess.remember(url, pinned: true)
    }
}

import Foundation
import SwiftUI

extension Notification.Name {
    static let chooseImage = Notification.Name("VibePhoto.chooseImage")
    static let chooseFolder = Notification.Name("VibePhoto.chooseFolder")
}

struct VibePhotoCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open Image…") {
                NotificationCenter.default.post(name: .chooseImage, object: nil)
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("Open Folder…") {
                NotificationCenter.default.post(name: .chooseFolder, object: nil)
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
        }
    }
}

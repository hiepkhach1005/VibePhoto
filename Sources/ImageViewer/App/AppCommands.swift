import Foundation
import SwiftUI

extension Notification.Name {
    static let chooseImage = Notification.Name("ImageViewer.chooseImage")
    static let chooseFolder = Notification.Name("ImageViewer.chooseFolder")
}

struct ImageViewerCommands: Commands {
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

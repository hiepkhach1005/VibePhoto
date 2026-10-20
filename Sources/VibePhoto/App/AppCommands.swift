import Foundation
import SwiftUI

extension Notification.Name {
    static let chooseImage = Notification.Name("VibePhoto.chooseImage")
    static let chooseFolder = Notification.Name("VibePhoto.chooseFolder")
}

/// Actions the menu bar runs against the frontmost VibePhoto window.
struct WindowActions {
    let showFavorites: () -> Void
}

private struct WindowActionsKey: FocusedValueKey {
    typealias Value = WindowActions
}

extension FocusedValues {
    var windowActions: WindowActions? {
        get { self[WindowActionsKey.self] }
        set { self[WindowActionsKey.self] = newValue }
    }
}

struct VibePhotoCommands: Commands {
    @FocusedValue(\.windowActions) private var windowActions

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
        CommandMenu("Go") {
            Button("Favorites") { windowActions?.showFavorites() }
                .keyboardShortcut("f", modifiers: [.command, .option])
                .disabled(windowActions == nil)
        }
    }
}

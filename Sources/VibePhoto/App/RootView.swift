import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @Environment(\.openWindow) private var openWindow
    @Binding var route: AppWindowRoute

    var body: some View {
        Group {
            if library.rootFolder == nil && !library.showingFavorites {
                WelcomeView(
                    recentFolders: FolderAccessStore.shared.folders,
                    hasFavorites: !FavoritesStore.shared.records.isEmpty,
                    openImage: chooseImage,
                    openFolder: chooseFolder,
                    openFavorites: library.showFavorites,
                    openRecent: library.openRememberedFolder
                )
            } else {
                BrowserView(openImage: { openWindow(value: AppWindowRoute.viewer($0)) })
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .chooseImage)) { _ in chooseImage() }
        .onReceive(NotificationCenter.default.publisher(for: .chooseFolder)) { _ in chooseFolder() }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            if url.hasDirectoryPath {
                library.openFolder(url)
            } else if ImageFileService.isSupported(url) {
                if library.rootFolder == nil { route = .viewer(url) }
                else { openWindow(value: AppWindowRoute.viewer(url)) }
            }
            return true
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = ImageFileService.supportedTypes
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if library.rootFolder == nil { route = .viewer(url) }
        else { openWindow(value: AppWindowRoute.viewer(url)) }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        library.openFolder(url)
    }
}

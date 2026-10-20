import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @Binding var route: AppWindowRoute
    @Binding var viewerRequest: ViewerRequest?

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
                BrowserView(viewerRequest: $viewerRequest)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .chooseImage)) { _ in chooseImage() }
        .onReceive(NotificationCenter.default.publisher(for: .chooseFolder)) { _ in chooseFolder() }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            if url.hasDirectoryPath {
                library.openFolder(url)
            } else if ImageFileService.isSupported(url) {
                show(url)
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
        show(url)
    }

    /// Opens the image in this window: inside the browser when one is showing.
    private func show(_ url: URL) {
        if library.rootFolder == nil && !library.showingFavorites { route = .viewer(url) }
        else { viewerRequest = ViewerRequest(url: url, collection: nil) }
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

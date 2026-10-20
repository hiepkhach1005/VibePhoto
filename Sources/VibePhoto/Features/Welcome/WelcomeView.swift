import SwiftUI

struct WelcomeView: View {
    let recentFolders: [StoredFolderBookmark]
    let hasFavorites: Bool
    let openImage: () -> Void
    let openFolder: () -> Void
    let openFavorites: () -> Void
    let openRecent: (StoredFolderBookmark) -> Void

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                Text("VibePhoto").font(.largeTitle.weight(.semibold))
                Text("Open an image for quick viewing, or a folder to browse your collection.")
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button("Open Image…", systemImage: "photo", action: openImage)
                    .keyboardShortcut("o")
                Button("Open Folder…", systemImage: "folder", action: openFolder)
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                    .buttonStyle(.borderedProminent)
            }
            if hasFavorites {
                Button("View Favorites", systemImage: "heart", action: openFavorites)
                    .buttonStyle(.plain)
            }
            if !recentFolders.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recent Folders").font(.headline)
                    ForEach(recentFolders.prefix(5)) { folder in
                        Button {
                            openRecent(folder)
                        } label: {
                            Label(folder.displayName, systemImage: "folder")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .help(folder.originalPath)
                    }
                }
                .frame(maxWidth: 360)
                .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

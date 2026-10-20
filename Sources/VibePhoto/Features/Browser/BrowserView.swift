import AppKit
import SwiftUI

struct BrowserView: View {
    @EnvironmentObject private var model: LibraryViewModel
    @StateObject private var favorites = FavoritesStore.shared
    let openImage: (URL) -> Void

    private let columns = [GridItem(.adaptive(minimum: 128, maximum: 190), spacing: 16)]

    var body: some View {
        NavigationSplitView {
            List {
                Section("Library") {
                    Button { model.showFavorites() } label: {
                        Label("Favorites", systemImage: model.showingFavorites ? "heart.fill" : "heart")
                            .foregroundStyle(model.showingFavorites ? .pink : .primary)
                    }
                    .buttonStyle(.plain)
                }
                if let root = model.rootFolder {
                    Section("Folders") {
                        FolderTreeNode(url: root) { model.selectFolder($0) }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 230)
        } detail: {
            content
                .navigationTitle(model.showingFavorites ? "Favorites" : model.selectedFolder?.lastPathComponent ?? "Images")
                .searchable(text: $model.searchText, prompt: "Search file names")
                .toolbar { toolbar }
        }
        .alert("Unable to load folder", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) { Button("OK") {} } message: { Text(model.errorMessage ?? "Unknown error") }
        .onChange(of: favorites.records) {
            if model.showingFavorites { model.showFavorites() }
        }
    }

    @ViewBuilder private var content: some View {
        if model.isLoading && model.images.isEmpty {
            ProgressView("Scanning folder…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.filteredImages.isEmpty && model.missingFavorites.isEmpty {
            ContentUnavailableView("No images", systemImage: "photo", description: Text("Choose another folder or change the search."))
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(model.groupedImages) { section in
                        if !section.title.isEmpty {
                            Text(section.title).font(.title3.weight(.semibold))
                        }
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(section.items) { item in
                                ThumbnailCell(item: item, favorite: favorites.contains(item.url))
                                    .onTapGesture(count: 2) { openImage(item.url) }
                                    .contextMenu {
                                        Button("Open") { openImage(item.url) }
                                        Button(favorites.contains(item.url) ? "Remove from Favorites" : "Add to Favorites") {
                                            favorites.toggle(item.url)
                                            if model.showingFavorites { model.showFavorites() }
                                        }
                                        Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                                    }
                            }
                        }
                    }
                    if model.showingFavorites && !model.missingFavorites.isEmpty {
                        Text("Missing Files").font(.title3.weight(.semibold))
                        ForEach(model.missingFavorites) { favorite in
                            HStack {
                                Label(favorite.record.displayName, systemImage: "questionmark.square.dashed")
                                Spacer()
                                Text(favorite.record.path).foregroundStyle(.secondary).lineLimit(1)
                                Button("Remove") {
                                    favorites.remove(favorite.record)
                                    model.showFavorites()
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button { chooseFolder() } label: { Label("Open Folder", systemImage: "folder.badge.plus") }
            Toggle(isOn: $model.recursive) { Label("Include Subfolders", systemImage: "folder.badge.plus") }
                .onChange(of: model.recursive) { model.refreshCurrentCollection() }
            Menu {
                Picker("Sort by", selection: $model.sort) {
                    ForEach(ImageSort.allCases) { Text($0.rawValue).tag($0) }
                }
                Toggle("Ascending", isOn: $model.ascending)
            } label: { Label("Sort", systemImage: "arrow.up.arrow.down") }
            .onChange(of: model.sort) { model.refreshCurrentCollection() }
            .onChange(of: model.ascending) { model.refreshCurrentCollection() }
            Menu {
                Picker("Group by", selection: $model.group) {
                    ForEach(ImageGroup.allCases) { Text($0.rawValue).tag($0) }
                }
            } label: { Label("Group", systemImage: "rectangle.3.group") }
            Menu {
                Button("All Types") { model.selectedExtension = nil }
                Divider()
                ForEach(model.availableExtensions, id: \.self) { ext in
                    Button(ext) { model.selectedExtension = ext }
                }
            } label: { Label("Filter", systemImage: "line.3.horizontal.decrease.circle") }
            Button { model.refreshCurrentCollection() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.openFolder(url)
    }
}

private struct FolderTreeNode: View {
    let url: URL
    let onSelect: (URL) -> Void
    @State private var expanded = false

    var children: [URL] { expanded ? ImageFileService.subfolders(in: url) : [] }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ForEach(children, id: \.self) { child in
                FolderTreeNode(url: child, onSelect: onSelect)
            }
        } label: {
            Label(url.lastPathComponent, systemImage: "folder")
                .contentShape(Rectangle())
                .onTapGesture { onSelect(url) }
        }
    }
}

private struct ThumbnailCell: View {
    let item: ImageItem
    let favorite: Bool
    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.quaternary)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        if let thumbnail {
                            Image(nsImage: thumbnail).resizable().scaledToFit().padding(5)
                        } else {
                            ProgressView().controlSize(.small)
                        }
                    }
                if favorite {
                    Image(systemName: "heart.fill").foregroundStyle(.pink).padding(8)
                }
            }
            Text(item.name).font(.caption).lineLimit(1).truncationMode(.middle)
            Text(ByteCountFormatter.string(fromByteCount: item.fileSize, countStyle: .file))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .task(id: item.url) { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        thumbnail = await ThumbnailCache.shared.image(for: item.url, size: CGSize(width: 320, height: 320), scale: 2)
    }
}

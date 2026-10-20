import AppKit
import SwiftUI

struct BrowserView: View {
    @EnvironmentObject private var model: LibraryViewModel
    @StateObject private var favorites = FavoritesStore.shared
    /// The image shown in this window's viewer; nil shows the grid.
    @Binding var viewerRequest: ViewerRequest?
    @State private var selection: Set<URL> = []
    @State private var selectionAnchor: URL?
    @State private var lastOpened: URL?

    private let columns = [GridItem(.adaptive(minimum: 128, maximum: 190), spacing: 16)]

    var body: some View {
        if let request = viewerRequest {
            // The viewer replaces the grid inside this window, so Stage Manager keeps
            // one window instead of tucking the browser away into the side strip.
            ViewerWindow(
                initialURL: request.url,
                collection: request.collection,
                onClose: closeViewer,
                onShowFavorites: {
                    closeViewer()
                    model.showFavorites()
                }
            )
            .id(request.id)
        } else {
            browser
        }
    }

    private var browser: some View {
        NavigationSplitView {
            List {
                Section("Library") {
                    Button { model.showFavorites() } label: {
                        Label("Favorites", systemImage: model.showingFavorites ? "heart.fill" : "heart")
                            .foregroundStyle(model.showingFavorites ? .pink : .primary)
                    }
                    .buttonStyle(.plain)
                    .help("Images you marked with a heart (⌥⌘F)")
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
                .navigationSubtitle(subtitle)
                .searchable(text: $model.searchText, prompt: "Search file names")
                .toolbar { toolbar }
        }
        .background { keyboardShortcuts }
        .alert("Unable to load folder", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) { Button("OK") {} } message: { Text(model.errorMessage ?? "Unknown error") }
        .onChange(of: favorites.records) {
            if model.showingFavorites { model.showFavorites() }
        }
        .onChange(of: model.selectedFolder) { selection = [] }
        .onChange(of: model.showingFavorites) { selection = [] }
    }

    private var subtitle: String {
        let count = model.filteredImages.count
        var parts = ["\(count) image\(count == 1 ? "" : "s")"]
        if model.recursive && !model.showingFavorites { parts.append("including subfolders") }
        if selection.count > 1 { parts.append("\(selection.count) selected") }
        return parts.joined(separator: " · ")
    }

    private var orderedURLs: [URL] { model.groupedImages.flatMap(\.items).map(\.url) }

    @ViewBuilder private var content: some View {
        if model.isLoading && model.images.isEmpty {
            ProgressView(model.recursive ? "Scanning folder and subfolders…" : "Scanning folder…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.filteredImages.isEmpty && model.missingFavorites.isEmpty {
            ContentUnavailableView {
                Label("No images", systemImage: "photo")
            } description: {
                Text(model.recursive || model.showingFavorites
                    ? "Choose another folder or change the search."
                    : "This folder has no images of its own. Its subfolders may have some.")
            } actions: {
                if !model.recursive && !model.showingFavorites {
                    Button("Include Subfolders") { model.recursive = true }
                }
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(model.groupedImages) { section in
                            if !section.title.isEmpty {
                                Text(section.title).font(.title3.weight(.semibold))
                            }
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(section.items) { item in
                                    cell(for: item)
                                }
                            }
                        }
                        if model.showingFavorites && !model.missingFavorites.isEmpty {
                            missingFavorites
                        }
                    }
                    .padding(20)
                }
                .onAppear {
                    if let lastOpened { proxy.scrollTo(lastOpened, anchor: .center) }
                }
            }
        }
    }

    private func cell(for item: ImageItem) -> some View {
        let isSelected = selection.contains(item.url)
        let opensSelection = isSelected && selection.count > 1
        return ThumbnailCell(item: item, favorite: favorites.contains(item.url), selected: isSelected)
            .id(item.url)
            .onTapGesture(count: 2) { open(item) }
            .simultaneousGesture(TapGesture().onEnded { select(item) })
            .help("\(item.name) — double-click to open")
            .contextMenu {
                Button(opensSelection ? "Open \(selection.count) Selected Images" : "Open") { open(item) }
                Button(favorites.contains(item.url) ? "Remove from Favorites" : "Add to Favorites") {
                    favorites.toggle(item.url)
                    if model.showingFavorites { model.showFavorites() }
                }
                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
            }
    }

    private var missingFavorites: some View {
        Group {
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

    /// Click selects, ⌘-click toggles, ⇧-click extends the range.
    private func select(_ item: ImageItem) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            if selection.contains(item.url) { selection.remove(item.url) } else { selection.insert(item.url) }
            selectionAnchor = item.url
        } else if flags.contains(.shift), let anchor = selectionAnchor,
                  let from = orderedURLs.firstIndex(of: anchor), let to = orderedURLs.firstIndex(of: item.url) {
            selection = Set(orderedURLs[min(from, to)...max(from, to)])
        } else {
            selection = [item.url]
            selectionAnchor = item.url
        }
    }

    /// Opens inside this window. With several images selected the viewer steps through
    /// only those; otherwise through everything visible in the grid.
    private func open(_ item: ImageItem) {
        let visible = orderedURLs
        let collection = selection.count > 1 && selection.contains(item.url)
            ? visible.filter(selection.contains)
            : visible
        lastOpened = item.url
        viewerRequest = ViewerRequest(url: item.url, collection: collection)
    }

    private func openSelection() {
        guard let first = orderedURLs.first(where: selection.contains),
              let item = model.filteredImages.first(where: { $0.url == first }) else { return }
        open(item)
    }

    private func closeViewer() {
        viewerRequest = nil
    }

    private var keyboardShortcuts: some View {
        Button("Open Selection") { openSelection() }
            .keyboardShortcut(.return, modifiers: [])
            .disabled(selection.isEmpty)
            .frame(width: 0, height: 0)
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button { chooseFolder() } label: { Label("Open Folder", systemImage: "folder.badge.plus") }
                .help("Open Folder… (⇧⌘O)")
            Toggle(isOn: $model.recursive) { Label("Include Subfolders", systemImage: "square.stack.3d.down.right") }
                .onChange(of: model.recursive) { model.refreshCurrentCollection() }
                .help(model.recursive
                    ? "Showing images from all subfolders — click to show only this folder"
                    : "Include Subfolders — show every image inside this folder and its subfolders")
            Menu {
                Picker("Sort by", selection: $model.sort) {
                    ForEach(ImageSort.allCases) { Text($0.rawValue).tag($0) }
                }
                Toggle("Ascending", isOn: $model.ascending)
            } label: { Label("Sort", systemImage: "arrow.up.arrow.down") }
            .onChange(of: model.sort) { model.refreshCurrentCollection() }
            .onChange(of: model.ascending) { model.refreshCurrentCollection() }
            .help("Sort by name, type, date, or size")
            Menu {
                Picker("Group by", selection: $model.group) {
                    ForEach(ImageGroup.allCases) { Text($0.rawValue).tag($0) }
                }
            } label: { Label("Group", systemImage: "rectangle.3.group") }
            .help("Group by folder, type, month, or size")
            Menu {
                Button("All Types") { model.selectedExtension = nil }
                Divider()
                ForEach(model.availableExtensions, id: \.self) { ext in
                    Button(ext) { model.selectedExtension = ext }
                }
            } label: { Label("Filter", systemImage: "line.3.horizontal.decrease.circle") }
            .help(model.selectedExtension.map { "Showing only \($0) files" } ?? "Filter by file type")
            Button { model.refreshCurrentCollection() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                .help("Refresh")
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
                .help(url.path)
                .onTapGesture { onSelect(url) }
        }
    }
}

private struct ThumbnailCell: View {
    let item: ImageItem
    let favorite: Bool
    let selected: Bool
    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.quaternary)
                    .aspectRatio(1, contentMode: .fit)
                    .background {
                        if selected { RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.15)) }
                    }
                    .overlay {
                        if let thumbnail {
                            Image(nsImage: thumbnail).resizable().scaledToFit().padding(5)
                        } else {
                            ProgressView().controlSize(.small)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.accentColor, lineWidth: selected ? 3 : 0)
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

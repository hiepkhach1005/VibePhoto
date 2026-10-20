import SwiftUI

struct ViewerWindow: View {
    @StateObject private var model: ViewerViewModel
    private let initialURL: URL
    private let onClose: (() -> Void)?
    private let onShowFavorites: (() -> Void)?

    init(
        initialURL: URL,
        collection: [URL]? = nil,
        onClose: (() -> Void)? = nil,
        onShowFavorites: (() -> Void)? = nil
    ) {
        self.initialURL = initialURL
        self.onClose = onClose
        self.onShowFavorites = onShowFavorites
        _model = StateObject(wrappedValue: ViewerViewModel(initialURL: initialURL, collection: collection))
    }

    var body: some View {
        ViewerView(model: model, onClose: onClose, onShowFavorites: onShowFavorites)
            .task { model.load() }
            // A file opened from Finder while this window is frontmost replaces its image.
            .onChange(of: initialURL) { model.open(initialURL) }
    }
}

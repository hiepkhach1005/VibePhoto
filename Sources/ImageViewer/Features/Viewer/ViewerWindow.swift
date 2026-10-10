import SwiftUI

struct ViewerWindow: View {
    @StateObject private var model: ViewerViewModel

    init(initialURL: URL) {
        _model = StateObject(wrappedValue: ViewerViewModel(initialURL: initialURL))
    }

    var body: some View {
        ViewerView(model: model)
            .task { model.load() }
    }
}

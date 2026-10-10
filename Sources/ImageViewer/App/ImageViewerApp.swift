import SwiftUI

enum AppWindowRoute: Codable, Hashable {
    case library
    case browser(URL)
    case viewer(URL)

    static func destination(for url: URL) -> AppWindowRoute {
        url.hasDirectoryPath ? .browser(url) : .viewer(url)
    }
}

@main
struct ImageViewerApp: App {
    @StateObject private var library = LibraryViewModel()

    var body: some Scene {
        WindowGroup("Image Viewer", for: AppWindowRoute.self) { $route in
            AppWindowContent(route: $route)
                .environmentObject(library)
        } defaultValue: {
            .library
        }
        .defaultSize(width: 1080, height: 720)
        .commands { ImageViewerCommands() }

        Settings {
            SettingsView()
        }
    }
}

private struct AppWindowContent: View {
    @Binding var route: AppWindowRoute

    var body: some View {
        Group {
            switch route {
            case .library:
                RootView(route: $route)
            case .browser(let url):
                StandaloneBrowserWindow(initialFolder: url)
            case .viewer(let url):
                ViewerWindow(initialURL: url)
            }
        }
        .onOpenURL { route = .destination(for: $0) }
        .background(WindowRestorationDisabler())
    }
}

private struct StandaloneBrowserWindow: View {
    @StateObject private var library = LibraryViewModel()
    @Environment(\.openWindow) private var openWindow
    let initialFolder: URL

    var body: some View {
        BrowserView(openImage: { openWindow(value: AppWindowRoute.viewer($0)) })
            .environmentObject(library)
            .task(id: initialFolder) { library.openFolder(initialFolder) }
    }
}

import AppKit
import SwiftUI

enum AppWindowRoute: Codable, Hashable {
    case library
    case browser(URL)
    case viewer(URL)
    case favorites

    static func destination(for url: URL) -> AppWindowRoute {
        url.hasDirectoryPath ? .browser(url) : .viewer(url)
    }
}

/// An image shown inside a browser window, optionally limited to an explicit set of images.
struct ViewerRequest: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let collection: [URL]?
}

final class VibePhotoAppDelegate: NSObject, NSApplicationDelegate {
    // Closing the last window quits the app instead of leaving it running in the Dock.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct VibePhotoApp: App {
    @NSApplicationDelegateAdaptor(VibePhotoAppDelegate.self) private var appDelegate
    @StateObject private var library = LibraryViewModel()

    var body: some Scene {
        WindowGroup("VibePhoto", for: AppWindowRoute.self) { $route in
            AppWindowContent(route: $route)
                .environmentObject(library)
        } defaultValue: {
            .library
        }
        .defaultSize(width: 1080, height: 720)
        .commands { VibePhotoCommands() }

        Settings {
            SettingsView()
        }
    }
}

private struct AppWindowContent: View {
    @EnvironmentObject private var library: LibraryViewModel
    @Binding var route: AppWindowRoute
    @State private var viewerRequest: ViewerRequest?

    var body: some View {
        Group {
            switch route {
            case .library:
                RootView(route: $route, viewerRequest: $viewerRequest)
            case .browser(let url):
                StandaloneBrowserWindow(start: .folder(url), viewerRequest: $viewerRequest)
            case .favorites:
                StandaloneBrowserWindow(start: .favorites, viewerRequest: $viewerRequest)
            case .viewer(let url):
                ViewerWindow(initialURL: url, onShowFavorites: { route = .favorites })
            }
        }
        .onOpenURL(perform: open)
        // Let an existing window take files opened from Finder. A new window per file
        // makes Stage Manager push the previous window out to the side strip.
        .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
        .focusedSceneValue(\.windowActions, WindowActions(showFavorites: showFavorites))
        .background(WindowRestorationDisabler())
    }

    private var showsBrowser: Bool {
        switch route {
        case .browser, .favorites: true
        case .library: library.rootFolder != nil || library.showingFavorites
        case .viewer: false
        }
    }

    private func open(_ url: URL) {
        if url.hasDirectoryPath {
            viewerRequest = nil
            if case .library = route { library.openFolder(url) } else { route = .browser(url) }
        } else if case .viewer = route {
            route = .viewer(url)
        } else if showsBrowser {
            viewerRequest = ViewerRequest(url: url, collection: nil)
        } else {
            route = .viewer(url)
        }
    }

    private func showFavorites() {
        viewerRequest = nil
        switch route {
        case .library: library.showFavorites()
        case .favorites: break
        case .browser, .viewer: route = .favorites
        }
    }
}

private struct StandaloneBrowserWindow: View {
    enum Start: Hashable {
        case folder(URL)
        case favorites
    }

    @StateObject private var library = LibraryViewModel()
    let start: Start
    @Binding var viewerRequest: ViewerRequest?

    var body: some View {
        BrowserView(viewerRequest: $viewerRequest)
            .environmentObject(library)
            .task(id: start) {
                switch start {
                case .folder(let url): library.openFolder(url)
                case .favorites: library.showFavorites()
                }
            }
    }
}

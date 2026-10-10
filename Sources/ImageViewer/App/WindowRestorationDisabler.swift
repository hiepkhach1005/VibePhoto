import AppKit
import SwiftUI

struct WindowRestorationDisabler: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { RestorationView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class RestorationView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.isRestorable = false
        }
    }
}

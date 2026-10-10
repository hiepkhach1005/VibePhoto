# UI/UX Specification

## Welcome

Centered product icon, short explanation, Open Image, and primary Open Folder action. File/folder drag and drop is planned.

## Browser

Three-column-capable `NavigationSplitView`: folder tree on the left, adaptive thumbnail grid in the center, optional inspector on the right. Toolbar owns recursive scan, sort, group, refresh, view style, and search. Empty, loading, and error states must remain explicit.

## Viewer

Image content dominates a neutral background. Navigation actions lead the toolbar; rotate, resize, favorite, zoom, info, and Trash follow. Less frequent actions move into a More menu when toolbar width is constrained. The info button toggles a right-side inspector.

## Input

Left/Right navigate. Command-I toggles information. Command-Delete moves to Trash. Command-Plus/Minus and Command-0/1 are required before Viewer milestone completion. Mouse wheel and pinch zoom around the pointer. Double-click toggles Fit/100% (pending).

## Liquid Glass

Use standard SwiftUI/AppKit navigation and controls so the newest SDK supplies Liquid Glass automatically. Custom glass effects must be availability-gated. macOS 14/15 fallback uses native materials and must honor Reduce Transparency and Increase Contrast.

# History

## 2026-08-31 — Initial implementation

- Created native macOS Swift Package and feature-oriented source tree.
- Added Welcome, Browser, Viewer, Inspector, Resize, Favorites persistence, and Settings foundations.
- Implemented folder and sibling discovery, thumbnail grid, sorting, search, multiple viewer windows, zoom, navigation, metadata, rotate/save, resize, favorite, and Trash behavior.
- Added project governance, architecture, roadmap, testing, format, privacy, and AI handoff documents.
- `swift build`: passed.
- `swift run VibePhoto`: launched successfully; the Welcome window was captured and visually verified.
- `swift test`: blocked because the active Command Line Tools image contains neither XCTest nor Swift Testing. This is documented; test source remains in place.
- Initialized a new Git repository without creating a commit.

## 2026-09-01 — MVP completion pass

- Added a native Xcode app target, shared scheme, Info.plist image document registration, App Sandbox, app-scoped bookmarks, and user-selected read/write entitlements.
- Added persistent folder permissions, recent folders, stale-bookmark refresh, and Viewer grant-folder recovery.
- Replaced path-only favorites with versioned bookmark/resource records, migration, a real Favorites collection, and missing-file removal.
- Added grouped grids, file-type filters, combined sort/group behavior, cancellable scans, directory monitoring, and a bounded memory thumbnail cache.
- Added Fit/Fill/100%/custom zoom, pointer-centered wheel zoom, double-click mode toggle, keyboard shortcuts, fullscreen, slideshow, Share, Copy File, and Reveal in Finder.
- Added editing conflict checks, atomic output, writable-codec checks, unique resize naming, percentage resize, destructive confirmations, backup, and one-level Undo.
- Fixed Launch Services routing so folder URLs open Browser scenes and image URLs open Viewer scenes.
- Added programmatic image-edit tests verifying rotation dimensions, backup restoration, resize dimensions, and collision-safe output naming.
- Verified Swift Debug/Release builds, 4 passing tests, Xcode app build/local signing, entitlements, and sandboxed folder-browser runtime rendering.

## 2026-09-01 — Original app icon

- Researched current Apple app-icon and Icon Composer guidance plus the visual conventions of image-viewer competitors.
- Generated an original indigo/cyan Liquid Glass-inspired icon: a central photo window, layered album panels, and navigation chevrons, without copying Photos or Preview.
- Added a complete macOS AppIcon asset catalog covering 16, 32, 128, 256, 512, and 1024 pixel renditions with no alpha channel.
- Connected `Assets.xcassets` to the Xcode resource phase and set `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`.
- Verified readability at 16 and 128 pixels and confirmed Xcode emits `AppIcon.icns`, `Assets.car`, and `CFBundleIconName=AppIcon`.

## 2026-09-01 — Direct-open and common-format regression fix

- Replaced the competing Welcome and URL-specific window groups with one routed window scene, eliminating the duplicate Welcome window when a file is opened from Finder.
- Retained security-scoped access for direct files and made failed parent-folder enumeration fall back to a usable single-image Viewer instead of `0 / 0`.
- Added extension/UTType fallback recognition and an Image I/O loader with EXIF-orientation transforms for PNG, JPEG, HEIC, and other supported system codecs.
- Corrected the AppKit image canvas so large images are scaled and centered at the requested zoom instead of being cropped outside the visible area.
- Added three direct-open regression tests. All 7 tests pass.
- Runtime-verified one window for PNG and HEIC launches and successfully rendered the user's iPhone `IMG_0318.HEIC` with sibling position `2 / 3`.

## 2026-10-10 — Prepare public GitHub source publication

- Refreshed the root README with the product workflow, implemented features, source-build steps, and development-preview limitations.
- Added ignore rules for local metadata, build outputs, generated SARIF reports, signing material, environment files, and private configuration.
- Ran Gitleaks against the Git candidate file snapshot and reviewed findings; no actual credentials were identified.
- Checked README relative links and image references. Application behavior was not changed and app build/test suites were not run for this documentation/publication task.
- Git commits use the account's GitHub noreply address.

## 2026-10-21 — UX refactor: in-window viewing, permissions, zoom, discoverability

- Browser thumbnails, Finder opens and drag/drop now show images inside the existing window (`handlesExternalEvents` + in-browser viewer) instead of creating new windows, which Stage Manager tucked away. Esc / Back returns to the grid and scrolls to the last-opened image.
- Grid selection: click, ⌘-click, ⇧-click; double-click or Return opens. With several images selected the viewer steps only through the selection.
- Folder access accepts the image's folder or any parent; parent grants (e.g. Home) are pinned, survive the 12-item recent trim, and cover nested folders. Settings ▸ Folder Access manages them.
- Zoom: Core Animation layer rendering instead of per-event full-resolution redraws; SwiftUI→AppKit sync forwards only real requests so stale bindings no longer snap the zoom back; pinch anchors at the pointer. Decoding moved off the main actor with neighbour prefetch.
- Previous/Next wrap around both ends. Every toolbar icon has a tooltip with its shortcut; rarely used actions moved to a More menu so Information never falls into toolbar overflow. Inspector has a close button; Esc closes it.
- Favorites: ⌘L toggles, a toast offers "Show Favorites", and Go ▸ Favorites (⌥⌘F) opens the collection in the current window.
- Include Subfolders has its own icon, persists, and is offered from the empty state.
- Closing the last window quits the app.
- `swift build`, `swift test` (13 tests) and Xcode Debug build pass. Runtime: second Finder open reused the one window; closing it quit the process; layer rendering is upright.

# Architecture

## Shape

The application uses a feature-oriented SwiftUI architecture with targeted AppKit bridges.

```text
App / Window scenes
  ├─ Browser feature ── FileSystem ── local folders
  │                  └─ QuickLookThumbnailing cache (planned disk layer)
  └─ Viewer feature ─── Imaging / Metadata
                     ├─ Favorites persistence
                     └─ AppKit zoomable scroll view
```

`LibraryViewModel` owns browser state. Each viewer window owns an independent `ViewerViewModel`. Core services do not own UI state.

## Concurrency

View models are main-actor isolated. Directory enumeration and image encoding are dispatched through cancellable detached tasks. Folder changes are debounced before refreshing. Dedicated indexing/cache actors remain appropriate for the future disk-cache and 10k-image work.

## Image pipeline

- `NSImage` provides current MVP display decoding.
- `QuickLookThumbnailing` generates grid thumbnails.
- Image I/O extracts metadata and encodes output.
- Core Image applies orientation and Lanczos resampling.

## Filesystem and sandbox

The Xcode app target enables App Sandbox, app-scoped bookmarks, and user-selected read/write access. Folder bookmarks are resolved and their security scope is retained while the Browser/Viewer needs access, then balanced on access-object deinitialization. Direct file opens fall back to an explicit Grant Folder Access action when sibling enumeration is denied.

## Persistence

Favorites persist versioned bookmark/resource records in UserDefaults and migrate the earlier path-only format. Original paths remain only as a fallback and for Missing File display. A database becomes warranted if ratings, large indexes, or duplicate detection are added.

# Current Status

Updated: 2026-10-21

## Verified build

- Swift Package Debug build: passes.
- Swift Package Release build: passes.
- Swift Testing: 13 tests pass.
- Xcode 26.6 macOS app target: builds and signs locally.
- Original AppIcon asset catalog: all macOS 16–1024 px slots compile successfully to `AppIcon.icns` and `Assets.car`.
- App Sandbox entitlements were inspected in the resulting app and include app sandbox, app-scoped bookmarks, and user-selected read/write access.
- Sandboxed runtime smoke test opened a folder through Launch Services and rendered its folder tree and thumbnails correctly.
- Direct-file Launch Services smoke tests open exactly one Viewer window. PNG, JPEG, generated HEIC, and an iPhone HEIC were decoded; the iPhone HEIC rendered successfully and sibling navigation reported `2 / 3`.

## Working product behavior

- Welcome, Open Image, Open Folder, drag/drop URLs, recent folders, and File menu commands.
- Images open inside the current window: Browser thumbnails and Finder opens show an in-window viewer (Esc returns to the grid); a frontmost Viewer window replaces its image. Closing the last window quits the app.
- Grid multi-selection (click/⌘/⇧) opens a viewer limited to the selection; Previous/Next wrap around.
- Folder grants cover nested folders; a pinned Home-folder grant (Settings ▸ Folder Access) avoids repeated prompts.
- Common formats are recognized by filename/UTType even when sandbox metadata lookup fails; direct files retain security-scoped access and fall back to single-image viewing when their parent folder cannot be enumerated.
- Persistent security-scoped folder bookmarks with stale-bookmark refresh and explicit grant-folder recovery.
- Lazy subfolder tree, optional recursive scan, scan cancellation, debounced external-change refresh, and bounded memory thumbnail cache.
- Filename search, file-type filter, ascending/descending sort, and grouping by folder/type/month/size; sort and group combine.
- Favorites collection with bookmark/resource identity, migration from legacy paths, and Missing File removal.
- Previous/Next sibling navigation, arrow keys, Fit/Fill/100%/custom zoom, correctly scaled centered canvas drawing, mouse-wheel pointer anchoring, pinch, double-click Fit/100%, fullscreen, and slideshow.
- Metadata inspector for general/image/EXIF/TIFF/GPS/IPTC data plus Copy All.
- Favorite, Share, Copy File, Reveal in Finder, and Move to Trash with configurable confirmation.
- Rotate left/right with immediate atomic save, external-change check, backup, and one-level session Undo.
- Resize by pixels or percentage, constrained or free aspect ratio, Lanczos resampling, unique copy naming, replace confirmation, external-change check, backup, and Undo.
- Native standard controls inherit Liquid Glass on supported macOS and native fallback appearance on macOS 14/15.

## Remaining production/polish work

- JPEG rotation currently re-encodes at quality 0.95; a true lossless JPEG transform is not yet implemented.
- Backups support one-level Undo per Viewer but need startup recovery and age-based cleanup after abnormal termination.
- Thumbnail cache is memory-only; disk persistence and large-library benchmarks remain.
- Scan loading is cancellable but not yet incremental with item-count progress.
- Settings “restore last session” is not wired to window restoration policy.
- Compare 2–4, batch operations, ratings, duplicate detection, and advanced slideshow remain Post-MVP.
- Automated UI tests, accessibility audit, distribution identity, notarization, and App Store packaging remain.

## 2026-10-10 — Prepare public GitHub source publication

- Refreshed the root README with the product workflow, implemented features, source-build steps, and development-preview limitations.
- Added ignore rules for local metadata, build outputs, generated SARIF reports, signing material, environment files, and private configuration.
- Ran Gitleaks against the Git candidate file snapshot and reviewed findings; no actual credentials were identified.
- Checked README relative links and image references. Application behavior was not changed and app build/test suites were not run for this documentation/publication task.
- Git commits use the account's GitHub noreply address.

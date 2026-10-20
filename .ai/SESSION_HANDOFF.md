# Session Handoff

## Current objective

Keep the macOS image-viewer MVP stable after fixing duplicate direct-open windows and PNG/JPEG/HEIC decoding/rendering.

## Completed this session

- Added and verified a native Xcode app target, shared scheme, image document registration, App Sandbox, user-selected read/write access, and app-scoped bookmarks.
- Implemented persistent folder access, recent folders, stale-bookmark refresh, and a direct-file grant-folder recovery flow.
- Implemented durable Favorites records, legacy migration, a real Favorites collection, and Missing File handling.
- Completed Browser group/filter/sort combinations, cancellable scans, folder monitoring, and bounded thumbnail memory cache.
- Completed Viewer zoom modes/shortcuts, pointer-centered wheel zoom, pinch, double-click toggle, slideshow, fullscreen, Share, Copy, and Reveal in Finder.
- Hardened editing with external-change detection, writable-codec checks, unique copy naming, percentage/free resize, confirmation, backup, and one-level Undo.
- Fixed Launch Services routing between folder Browser scenes and image Viewer scenes.
- Added and ran image-processing integration tests.
- Added an original production AppIcon, all macOS bitmap renditions, asset-catalog integration, and verified compiled icon resources.
- Unified Welcome, Browser, and Viewer routing in one typed WindowGroup so a Finder-opened image creates exactly one Viewer window.
- Added direct-file security-scoped access, enumeration failure handling, extension/UTType recognition fallback, and Image I/O decoding with orientation transforms.
- Fixed scaled canvas drawing for large images and added direct-open/format regression tests.

## In progress

The requested core MVP works. Remaining work is production hardening and explicitly Post-MVP functionality listed in `.ai/TASKS.md`.

## Build status

Commands:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build -c release
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project VibePhoto.xcodeproj -scheme VibePhoto -configuration Debug -destination 'platform=macOS' clean build
```

Result: PASS. Xcode 26.6 signed the Debug app with “Sign to Run Locally”.

## Test status

Command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Result: PASS — 7 tests in 3 suites. Rotation, backup restore, resize dimensions, unique naming, sorting, direct-open routing, common-extension recognition, and PNG/JPEG/HEIC decoding are covered.

Runtime: PASS — Launch Services opened PNG and HEIC files in exactly one window. A generated HEIC and the user's iPhone `IMG_0318.HEIC` rendered successfully; sibling enumeration showed `2 / 3` for the Desktop file.

## Important decisions

See ADR-006 and ADR-007 in `docs/DECISIONS.md`.

## Files changed

Key additions/changes include `VibePhoto.xcodeproj`, `Config/Assets.xcassets`, `Config/`, `VibePhotoApp.swift`, `RootView.swift`, `WindowRestorationDisabler.swift`, `ImageFileService.swift`, `ImageLoadingService.swift`, `ViewerViewModel.swift`, `ViewerView.swift`, `ZoomableImageView.swift`, and `DirectOpenRegressionTests.swift`.

All project files remain uncommitted in the initialized Git repository.

## Known issues

- JPEG rotation is a quality-0.95 re-encode, not a mathematically lossless transform.
- Edit backups need abnormal-termination recovery and cleanup.
- Disk thumbnail cache, incremental scan progress, UI tests, accessibility audit, and session restoration remain.
- Distribution still needs the user’s final bundle identifier, Apple development team, notarization, and/or App Store configuration.

## Exact next steps

1. Implement `EDIT-002B`: lossless JPEG rotation or an explicit safe Save As policy.
2. Implement `EDIT-003`: backup recovery manifest and age-based cleanup.
3. Add `TEST-UI-001` and permanent legal image fixtures to the Xcode project.

## Safe resume instructions

Read `AGENTS.md` and `.ai/TASKS.md`, run the three verification commands above with `DEVELOPER_DIR`, and do not regress the sandboxed Launch Services folder/image routing. Keep the Swift Package and Xcode app target compiling the same source tree.

## 2026-10-10 — Prepare public GitHub source publication

- Refreshed the root README with the product workflow, implemented features, source-build steps, and development-preview limitations.
- Added ignore rules for local metadata, build outputs, generated SARIF reports, signing material, environment files, and private configuration.
- Ran Gitleaks against the Git candidate file snapshot and reviewed findings; no actual credentials were identified.
- Checked README relative links and image references. Application behavior was not changed and app build/test suites were not run for this documentation/publication task.
- Git commits use the account's GitHub noreply address.

## 2026-10-20 — Rename ImageViewer to VibePhoto

- Renamed product, Swift target, Xcode project/scheme, entitlements, sources/tests and bundle id (`com.local.ImageViewer` → `com.vibephoto.VibePhoto`); the outer folder is now `VibePhoto`.
- Replaced AppIcon with the Vibe family Apple-native icon (source: `VibeNote/assets/design/vibe-icons/`).
- `xcodebuild -project VibePhoto.xcodeproj -scheme VibePhoto -configuration Release -derivedDataPath build`: BUILD SUCCEEDED. Tests not run.

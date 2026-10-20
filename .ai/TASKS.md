# Tasks

## Completed core MVP

- [x] `INFRA-001` Native Xcode macOS app target, shared scheme, bundle metadata, image document registration, local signing, App Sandbox, and user-selected read/write entitlement.
- [x] `FS-001` Balanced security-scoped folder bookmarks, stale resolution, recent folders, and grant-folder recovery UI.
- [x] `EDIT-001` Backup/one-level Undo for replace edits and external modification conflict detection.
- [x] `FAV-001` Favorites collection, bookmark/resource identity, legacy migration, missing-file states, and removal.
- [x] `BROWSE-001` Combined group, sort, filename search, and type filter.
- [x] `VIEW-001` Fit, Fill, 100%, custom zoom, shortcuts, double-click toggle, pointer-anchored wheel zoom, pinch, fullscreen, and slideshow.
- [x] `EDIT-002A` Unique resized-copy naming, replace confirmation, output-codec check, pixel/percentage/free resize.
- [x] `FS-002A` Cancellable scans, debounced external-change monitoring, and refresh.
- [x] `CACHE-001A` Bounded modification-aware memory thumbnail cache.
- [x] `BUG-001` Direct image launch uses one window and robustly decodes PNG/JPEG/HEIC under App Sandbox.
- [x] `UX-001` In-window viewer, multi-select open, parent-folder grants, smooth layer zoom, wrap-around navigation, tooltips, inspector close, favorites discoverability, quit on last window close.

## P1 — Production hardening

- [ ] `EDIT-002B` Implement true lossless JPEG rotation or route JPEG rotate through a clearly disclosed Save As policy.
- [ ] `EDIT-003` Add startup edit-backup recovery, age-based cleanup, and multi-level Undo architecture.
- [ ] `FS-002B` Incremental folder scan with item-count progress and explicit Cancel control.
- [ ] `CACHE-001B` Versioned disk thumbnail cache, eviction, and 10k-image benchmark.
- [ ] `TEST-UI-001` Add Xcode UI-test target for open folder/image, navigation, favorite, inspector, resize, rotate/Undo, and Trash fixtures.
- [ ] `A11Y-001` VoiceOver, keyboard-only, Reduce Transparency, and Increase Contrast audit.
- [ ] `SESSION-001` Wire restore-last-session setting and persistent window/browser state.

## P2 — Extended features

- [x] Original macOS app icon and complete AppIcon asset catalog.
- [ ] Compare 2–4 images with synchronized zoom/pan.
- [ ] Batch rotate, resize, and rename.
- [ ] Ratings/color labels, duplicate detection, contact sheet, and advanced slideshow controls.
- [ ] Distribution bundle identifier/team, notarization, and App Store preparation.

## Repository publication

- [x] Prepare public README and exclude local/private artifacts (2026-10-10).

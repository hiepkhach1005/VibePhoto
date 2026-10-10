# Architecture Decisions

## ADR-001 — Native macOS stack — 2026-08-31

Use SwiftUI for scene/layout/state composition and AppKit for image scrolling, window-level behavior, and macOS integrations. This avoids Electron overhead and preserves native keyboard, accessibility, appearance, and Liquid Glass adoption.

## ADR-002 — macOS 14 deployment baseline — 2026-08-31

Use macOS 14 as the initial deployment target. Standard controls receive the current platform appearance; custom Liquid Glass will be availability-gated. This keeps a broad fallback while allowing modern SwiftUI APIs.

## ADR-003 — Filesystem remains source of truth — 2026-08-31

Do not import originals into an application library. Persist only bookmarks, favorites, preferences, indexes, and caches.

## ADR-004 — Swift Package bootstrap — 2026-08-31

The machine lacks a full Xcode selection, so bootstrap as a buildable Swift executable package. Add a proper Xcode app target, entitlements, signing, and UI-test plan as the next infrastructure task.

## ADR-005 — Safe quality language — 2026-08-31

The UI must not promise lossless resize. Lanczos resampling and metadata/profile preservation are used where supported, while upscaling and lossy re-encoding are disclosed.

## ADR-006 — Dual Xcode project and Swift Package workflow — 2026-09-01

Keep Swift Package Manager for fast deterministic builds and logic tests, and maintain a native Xcode macOS app target for bundle metadata, document registration, App Sandbox entitlements, signing, runtime validation, and future UI tests. Both targets compile the same `Sources/ImageViewer` tree.

## ADR-007 — Durable permissions and favorites — 2026-09-01

Folder access uses app-scoped security bookmarks retained for the lifetime of active browsing. Favorites use file bookmarks plus resource identifiers and retain the original path as a repair fallback. Missing favorites remain visible rather than disappearing silently.

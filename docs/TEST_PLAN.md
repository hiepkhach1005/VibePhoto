# Test Plan

## Automated unit coverage

- Natural filename sort and every ascending/descending sort mode.
- Combined sort/group/filter behavior.
- Supported type detection.
- Navigation after deletion or external removal.
- Resize aspect calculations and output collision naming.
- Metadata normalization.
- Favorite migration/bookmark/resource-identifier resolution.
- Thumbnail cache keys and invalidation.

## Integration coverage

- Open a fixture image and enumerate siblings.
- Recursively scan nested fixtures with hidden/package exclusions.
- Rotate/save/reload for writable formats.
- Resize copy and replacement with metadata/profile verification.
- Move a temporary fixture to Trash safely.
- Stale bookmark recovery.

## Manual matrix

Test JPEG, PNG, animated GIF, TIFF/multipage TIFF, HEIC, WebP, BMP, RAW, corrupt files, read-only files, very large dimensions, mixed folders, 10k-file folders, external drives, network volumes, Light/Dark, Reduce Transparency, VoiceOver, keyboard-only use, and multiple displays.

## Current environment

Full Xcode 26.6 is installed but is not the global `xcode-select` target. Prefix commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Four Swift Testing tests currently verify natural sorting, descending size sorting, collision-safe resize names, rotation dimensions, backup restoration, and resize output dimensions. The Xcode sandboxed app target is also built and smoke-tested through Launch Services.

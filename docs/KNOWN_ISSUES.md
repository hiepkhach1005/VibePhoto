# Known Issues

| Severity | Issue | Workaround / plan |
|---|---|---|
| High | JPEG rotation re-encodes and is not lossless | Add lossless JPEG transform capability or disclose/Save As |
| Medium | Edit backups can remain after an abnormal app termination | Add recovery manifest and age-based cleanup |
| Medium | Thumbnail cache has no disk tier | Add versioned disk cache and eviction |
| Medium | Scan progress is binary rather than incremental | Stream batches and expose item-count progress/cancel |
| Medium | Restore-last-session setting is not wired | Add scene/window restoration persistence |
| Medium | No automated UI-test target | Add Xcode UI test target and fixtures |
| Low | Thumbnail fallback displays a generic icon | Add error badge and retry action |

# Build and Test

Use this skill after Swift source, package, project, entitlement, or test changes.

1. Inspect active toolchain with `xcode-select -p`, `swift --version`, and when available `xcodebuild -version`.
2. Run `swift build` for the package baseline.
3. With full Xcode, run the app scheme and its unit tests with `xcodebuild` using an explicit project/workspace, scheme, and destination.
4. Never hide or ignore failures. Separate product failures from environment/toolchain blockers.
5. Record exact commands and results in `.ai/SESSION_HANDOFF.md` and notable changes in `docs/HISTORY.md`.

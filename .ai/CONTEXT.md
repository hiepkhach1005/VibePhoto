# Durable Context

- Product: native, local-first macOS folder image viewer.
- Source of truth: user files and folders, never a proprietary imported library.
- Deployment baseline: macOS 14; modern appearance including Liquid Glass is inherited from standard controls where available.
- Stack: SwiftUI + selective AppKit, Image I/O/Core Image, QuickLookThumbnailing.
- Invariant: image mutation must be atomic where possible and must not silently lose user data.
- Current bootstrap is Swift Package because full Xcode is not selected.
- Never add networking or telemetry without explicit approval.

# Agent Rules

## Required reading order

Before changing code, read this file, `.ai/SESSION_HANDOFF.md`, `docs/CURRENT_STATUS.md`, `.ai/TASKS.md`, and the newest entries in `docs/DECISIONS.md`.

## Working rules

- Inspect the working tree before editing and preserve unrelated user changes.
- Keep the app native to macOS: SwiftUI first, AppKit where it materially improves macOS behavior.
- Never block the main actor with directory scans, thumbnail generation, metadata extraction, or image encoding.
- Treat user images as irreplaceable. File mutations require error handling, atomic writes where possible, and explicit documentation of lossy behavior.
- Do not claim a feature is complete when only its UI exists.
- Prefer small feature-focused types over generic `Manager` classes.
- All icon-only controls require a label/tooltip accessible to VoiceOver.
- Maintain compatibility checks for APIs newer than the deployment target.
- Never add telemetry, uploading, or network access without an explicit product decision.

## Verification

Run `swift build` after code changes. Run `swift test` when a full Xcode toolchain with XCTest/Swift Testing is active. Record exact commands and results in `.ai/SESSION_HANDOFF.md`.

## Definition of done

A task is done only when behavior is implemented, build succeeds, relevant tests exist, failure states are handled, and `CURRENT_STATUS`, `HISTORY`, `TASKS`, and `SESSION_HANDOFF` are updated.

## End of every session

Follow `.ai/skills/session-handoff/SKILL.md`. Leave one exact, executable next step; never leave only a vague TODO.

<p align="center">
  <img src="Config/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" width="112" alt="Image Viewer app icon">
</p>

# Image Viewer

**Your folders. Your photos. A viewer that gets out of the way.**

A native macOS image viewer for people who organize photos in folders. Open an image, explore its neighbors, and make quick edits without importing everything into another photo library.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111827?logo=apple)
![Swift](https://img.shields.io/badge/Swift-native-F05138?logo=swift&logoColor=white)
![Development preview](https://img.shields.io/badge/status-development_preview-amber)

## Browse first. Edit when you need to.

- **Folders stay folders.** Browse a lazy folder tree and thumbnail grid, with search, filtering, sorting, and grouping.
- **Move through images naturally.** Arrow-key navigation, mouse-wheel and trackpad zoom, Fit / Fill / 100%, and a slideshow.
- **Keep useful images close.** Recent folders, persistent folder access, and Favorites with missing-file handling.
- **Make practical edits.** Rotate, resize by pixels or percentage, inspect metadata, and move unwanted images to Trash.
- **Work like a Mac app.** Independent viewer windows, Share, Copy, and Reveal in Finder.

Image Viewer works locally: no account, uploads, analytics, or telemetry.

## Get started

Requires **macOS 14+** and **Xcode with Swift 6 support**.

```sh
git clone https://github.com/hiepkhach1005/Image.git
cd Image
```

Open `ImageViewer.xcodeproj`, select the **ImageViewer** scheme, and Run. This is the sandboxed app target and supports local ad-hoc signing.

For the Swift Package executable:

```sh
swift build
swift run ImageViewer
```

To run unit tests with the full Xcode toolchain:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

## Development status

The folder-based MVP is implemented. This repository is a source preview; a signed, notarized distribution is still release work. See [current status](docs/CURRENT_STATUS.md) for verified behavior and remaining limitations.

Rotate/save can replace an image on disk, and some edits re-encode image data. A session Undo backup is available for rotation; keep originals when experimenting with edits.

## Explore or contribute

Read the [architecture](docs/ARCHITECTURE.md), [decisions](docs/DECISIONS.md), and [task list](.ai/TASKS.md). Found a bug or have an idea? [Open an issue](https://github.com/hiepkhach1005/Image/issues) with your macOS version, image format, and steps to reproduce.

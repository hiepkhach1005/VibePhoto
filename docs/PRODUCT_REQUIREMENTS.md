# Product Requirements

## Product promise

Open images as directly as Windows Photo Viewer while offering a native macOS folder browser. The filesystem remains the source of truth; users do not import images into a proprietary library.

## MVP user stories

- I can open an image from Finder or the app and navigate supported sibling images.
- I can use toolbar buttons or arrow keys to move backward and forward.
- I can zoom at the pointer using a mouse wheel or trackpad and pan large images.
- I can rotate left/right and save immediately, resize in pixels with an aspect lock, inspect metadata, favorite an image, and move it to Trash.
- I can choose a folder, see subfolders as a tree, browse thumbnails, optionally include descendants, search, sort, and group.
- Double-clicking a thumbnail opens an independent viewer window without losing browser state.
- Favorites survive relaunch and missing favorite files can be repaired or removed.

## MVP acceptance highlights

- UI remains responsive while scanning and generating thumbnails.
- Destructive operations never silently delete permanently.
- Resize communicates that upscaling cannot recreate original detail.
- Metadata and ICC profiles are preserved where the destination codec supports them.
- A permission failure produces a useful folder-access action rather than a crash.

## Post-MVP

Compare 2–4 images with synchronized zoom/pan, batch editing, ratings, duplicate detection, contact sheets, and advanced slideshows.

## Non-goals

Cloud sync, social features, full professional RAW development, face recognition, and a proprietary managed photo library.

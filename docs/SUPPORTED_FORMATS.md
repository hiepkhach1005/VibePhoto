# Supported Formats

Support is discovered from Image I/O at runtime; it varies with macOS and installed codecs.

| Format | View | Metadata | Edit/write | Current note |
|---|---:|---:|---:|---|
| JPEG | Yes | Yes | Yes | Rotation currently re-encodes at 0.95 quality |
| PNG | Yes | Yes | Yes | Alpha supported by Image I/O pipeline |
| HEIC/HEIF | Yes on supported macOS | Yes | OS-dependent | Viewing verified with generated and iPhone HEIC files; destination support checked at runtime |
| GIF | Yes | Partial | First frame only | Animation is pending |
| TIFF | Yes | Yes | First page only | Multipage navigation is pending |
| WebP | OS-dependent | Partial | OS-dependent | Runtime capability only |
| BMP/ICO | OS-dependent | Partial | OS-dependent | Runtime capability only |
| RAW | OS-dependent | Yes | No safe overwrite | View/thumbnail only for MVP |
| PDF | Not included as image | Partial | No | Possible post-MVP document mode |
| SVG | Not included | No | No | Requires a separate safe renderer decision |

# Add or Change Image Format Support

Use when adding or changing decoding, metadata, animation/page handling, editing, or encoding for a file format.

1. Confirm runtime UTType and Image I/O read/write capabilities separately.
2. Update `docs/SUPPORTED_FORMATS.md`; never equate thumbnail support with safe editing.
3. Add a small licensed fixture covering transparency, orientation, metadata, and animation/pages when applicable.
4. Verify display, thumbnail, metadata, rotate, resize, color profile, and error behavior independently.
5. A read-only format must never expose destructive editing without Save As to a supported destination.

@preconcurrency import ImageIO
import Foundation

struct MetadataSection: Identifiable {
    let title: String
    let rows: [MetadataRow]
    var isTechnical = false
    var id: String { title }
}

struct MetadataRow: Identifiable {
    let label: String
    let value: String
    var explanation: String? = nil
    var id: String { label }
}

enum ImageMetadataService {
    static func read(from url: URL) -> [MetadataSection] {
        let resource = try? url.resourceValues(forKeys: [
            .fileSizeKey, .creationDateKey, .contentModificationDateKey, .contentTypeKey
        ])
        var general: [MetadataRow] = [
            .init(label: "File name", value: url.lastPathComponent),
            .init(label: "File type", value: resource?.contentType?.localizedDescription ?? url.pathExtension.uppercased()),
            .init(
                label: "File size",
                value: ByteCountFormatter.string(fromByteCount: Int64(resource?.fileSize ?? 0), countStyle: .file)
            ),
            .init(label: "Folder", value: url.deletingLastPathComponent().path)
        ]
        if let date = resource?.creationDate { general.append(.init(label: "Created", value: date.formatted())) }
        if let date = resource?.contentModificationDate { general.append(.init(label: "Modified", value: date.formatted())) }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let raw = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return [.init(title: "General", rows: general)]
        }

        let width = number(raw[kCGImagePropertyPixelWidth as String])
        let height = number(raw[kCGImagePropertyPixelHeight as String])
        var image: [MetadataRow] = []
        if let width, let height {
            image.append(.init(
                label: "Dimensions",
                value: "\(width) × \(height) pixels",
                explanation: "The image width and height in actual pixels."
            ))
            image.append(.init(
                label: "Image size",
                value: String(format: "%.1f megapixels", Double(width * height) / 1_000_000),
                explanation: "Megapixels are the total number of pixels, not the file size."
            ))
            image.append(.init(label: "Aspect ratio", value: aspectRatio(width: width, height: height)))
        }
        if let dpiWidth = number(raw[kCGImagePropertyDPIWidth as String]),
           let dpiHeight = number(raw[kCGImagePropertyDPIHeight as String]) {
            image.append(.init(
                label: "Print resolution",
                value: "\(dpiWidth) × \(dpiHeight) DPI",
                explanation: "DPI mainly affects physical print size; it does not change the number of pixels."
            ))
        }
        if let color = raw[kCGImagePropertyColorModel as String] {
            image.append(.init(label: "Color", value: String(describing: color)))
        }
        if let depth = number(raw[kCGImagePropertyDepth as String]) {
            image.append(.init(
                label: "Color depth",
                value: "\(depth) bits per component",
                explanation: "More bits can represent smoother color and brightness changes."
            ))
        }
        if let orientation = number(raw[kCGImagePropertyOrientation as String]) {
            image.append(.init(label: "Orientation", value: orientationDescription(orientation)))
        }
        let frameCount = CGImageSourceGetCount(source)
        if frameCount > 1 {
            image.append(.init(label: "Frames / pages", value: String(frameCount)))
        }

        var sections = [MetadataSection(title: "General", rows: general)]
        if !image.isEmpty { sections.append(.init(title: "Image", rows: image)) }
        addCameraSummary(from: raw, to: &sections)
        addDictionary(raw[kCGImagePropertyExifDictionary as String], title: "EXIF details", to: &sections)
        addDictionary(raw[kCGImagePropertyTIFFDictionary as String], title: "TIFF details", to: &sections)
        addDictionary(raw[kCGImagePropertyGPSDictionary as String], title: "Location details", to: &sections)
        addDictionary(raw[kCGImagePropertyIPTCDictionary as String], title: "IPTC details", to: &sections)
        return sections
    }

    private static func addCameraSummary(from raw: [String: Any], to sections: inout [MetadataSection]) {
        let exif = raw[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiff = raw[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        var rows: [MetadataRow] = []
        if let make = tiff?[kCGImagePropertyTIFFMake as String] {
            rows.append(.init(label: "Camera maker", value: String(describing: make)))
        }
        if let model = tiff?[kCGImagePropertyTIFFModel as String] {
            rows.append(.init(label: "Camera model", value: String(describing: model)))
        }
        if let date = exif?[kCGImagePropertyExifDateTimeOriginal as String] {
            rows.append(.init(label: "Date taken", value: String(describing: date)))
        }
        if let exposure = (exif?[kCGImagePropertyExifExposureTime as String] as? NSNumber)?.doubleValue {
            let value = exposure > 0 && exposure < 1
                ? "1/\(Int((1 / exposure).rounded())) second"
                : String(format: "%.2f seconds", exposure)
            rows.append(.init(label: "Shutter speed", value: value))
        }
        if let aperture = (exif?[kCGImagePropertyExifFNumber as String] as? NSNumber)?.doubleValue {
            rows.append(.init(label: "Aperture", value: String(format: "f/%.1f", aperture)))
        }
        if let iso = exif?[kCGImagePropertyExifISOSpeedRatings as String] as? [NSNumber], let first = iso.first {
            rows.append(.init(label: "ISO", value: first.stringValue))
        }
        if let focalLength = (exif?[kCGImagePropertyExifFocalLength as String] as? NSNumber)?.doubleValue {
            rows.append(.init(label: "Focal length", value: String(format: "%.1f mm", focalLength)))
        }
        if !rows.isEmpty { sections.append(.init(title: "Camera", rows: rows)) }
    }

    private static func addDictionary(_ value: Any?, title: String, to sections: inout [MetadataSection]) {
        guard let dictionary = value as? [String: Any], !dictionary.isEmpty else { return }
        let rows = dictionary.keys.sorted().compactMap { key -> MetadataRow? in
            guard let value = dictionary[key] else { return nil }
            return .init(label: readableLabel(key), value: readableValue(value))
        }
        sections.append(.init(title: title, rows: rows, isTechnical: true))
    }

    private static func number(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue
    }

    private static func aspectRatio(width: Int, height: Int) -> String {
        func greatestCommonDivisor(_ lhs: Int, _ rhs: Int) -> Int {
            var a = abs(lhs), b = abs(rhs)
            while b != 0 { (a, b) = (b, a % b) }
            return max(1, a)
        }
        let divisor = greatestCommonDivisor(width, height)
        return "\(width / divisor):\(height / divisor)"
    }

    private static func orientationDescription(_ value: Int) -> String {
        switch value {
        case 1: "Normal"
        case 2: "Mirrored horizontally"
        case 3: "Rotated 180°"
        case 4: "Mirrored vertically"
        case 5: "Mirrored and rotated 90° left"
        case 6: "Rotated 90° right"
        case 7: "Mirrored and rotated 90° right"
        case 8: "Rotated 90° left"
        default: "Unknown (\(value))"
        }
    }

    private static func readableLabel(_ key: String) -> String {
        let cleaned = key.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
        return cleaned.replacingOccurrences(
            of: "([a-z0-9])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        )
    }

    private static func readableValue(_ value: Any) -> String {
        if let values = value as? [Any] {
            return values.map { String(describing: $0) }.joined(separator: ", ")
        }
        return String(describing: value)
    }
}

import SwiftUI

struct ResizeSheet: View {
    private enum InputMode: String, CaseIterable { case pixels = "Pixels", percentage = "Percentage" }
    @Environment(\.dismiss) private var dismiss
    let originalSize: CGSize
    let onResize: (Int, Int, Bool) -> Void

    @State private var width: Int
    @State private var height: Int
    @State private var lockAspectRatio = true
    @State private var replaceOriginal = false
    @State private var updating = false
    @State private var showReplaceConfirmation = false
    @State private var inputMode: InputMode = .pixels
    @State private var percentage = 100.0

    init(originalSize: CGSize, onResize: @escaping (Int, Int, Bool) -> Void) {
        self.originalSize = originalSize
        self.onResize = onResize
        _width = State(initialValue: max(1, Int(originalSize.width)))
        _height = State(initialValue: max(1, Int(originalSize.height)))
    }

    private var ratio: Double { Double(originalSize.width / max(1, originalSize.height)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Resize Image").font(.title2.weight(.semibold))
            Text("Original: \(Int(originalSize.width)) × \(Int(originalSize.height)) pixels")
                .foregroundStyle(.secondary)
            Picker("Resize by", selection: $inputMode) {
                ForEach(InputMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            if inputMode == .pixels {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        Text("Width")
                        TextField("Width", value: $width, format: .number).frame(width: 120)
                        Text("px").foregroundStyle(.secondary)
                    }
                    GridRow {
                        Text("Height")
                        TextField("Height", value: $height, format: .number).frame(width: 120)
                        Text("px").foregroundStyle(.secondary)
                    }
                }
                Toggle("Preserve aspect ratio", isOn: $lockAspectRatio)
            } else {
                HStack {
                    TextField("Percentage", value: $percentage, format: .number.precision(.fractionLength(0...1)))
                        .frame(width: 120)
                    Text("%").foregroundStyle(.secondary)
                    Menu("Presets") {
                        ForEach([25.0, 50.0, 75.0, 100.0, 150.0, 200.0], id: \.self) { value in
                            Button("\(Int(value))%") { percentage = value }
                        }
                    }
                }
            }
            Toggle("Replace original file", isOn: $replaceOriginal)
            if width > Int(originalSize.width) || height > Int(originalSize.height) {
                Label("Upscaling cannot recreate detail that is not present in the original.", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
            Text("High-quality Lanczos resampling is used. Metadata and the color profile are preserved when the format supports them.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button(replaceOriginal ? "Resize and Replace" : "Save Copy") {
                    if replaceOriginal {
                        showReplaceConfirmation = true
                    } else {
                        onResize(width, height, false)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(width <= 0 || height <= 0)
            }
        }
        .padding(24)
        .frame(width: 460)
        .onChange(of: width) {
            guard lockAspectRatio, !updating else { return }
            updating = true
            height = max(1, Int(Double(width) / ratio))
            updating = false
        }
        .onChange(of: height) {
            guard lockAspectRatio, !updating else { return }
            updating = true
            width = max(1, Int(Double(height) * ratio))
            updating = false
        }
        .onChange(of: percentage) {
            guard inputMode == .percentage else { return }
            width = max(1, Int(Double(originalSize.width) * percentage / 100))
            height = max(1, Int(Double(originalSize.height) * percentage / 100))
        }
        .onChange(of: inputMode) {
            if inputMode == .percentage {
                percentage = 100
                width = max(1, Int(originalSize.width))
                height = max(1, Int(originalSize.height))
            }
        }
        .confirmationDialog(
            "Replace the original image?", isPresented: $showReplaceConfirmation,
            titleVisibility: .visible
        ) {
            Button("Resize and Replace", role: .destructive) { onResize(width, height, true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A backup will be kept for Undo during this viewer session.")
        }
    }
}

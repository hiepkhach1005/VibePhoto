import AppKit
import SwiftUI

struct MetadataInspector: View {
    let sections: [MetadataSection]
    @State private var showsTechnicalDetails = false

    private var primarySections: [MetadataSection] { sections.filter { !$0.isTechnical } }
    private var technicalSections: [MetadataSection] { sections.filter(\.isTechnical) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                Text("The most useful details are shown first. Camera-specific metadata is available under Technical details.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(primarySections) { section in sectionView(section) }

                if !technicalSections.isEmpty {
                    DisclosureGroup(isExpanded: $showsTechnicalDetails) {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            ForEach(technicalSections) { section in sectionView(section) }
                        }
                        .padding(.top, 12)
                    } label: {
                        Label("Technical details", systemImage: "wrench.and.screwdriver")
                            .font(.headline)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Information")
        .toolbar {
            Button("Copy All", systemImage: "doc.on.doc") {
                let text = sections.map { section in
                    ([section.title] + section.rows.map { "\($0.label): \($0.value)" }).joined(separator: "\n")
                }.joined(separator: "\n\n")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
        }
    }

    private func sectionView(_ section: MetadataSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title).font(.headline)
            ForEach(section.rows) { row in
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.label).font(.caption).foregroundStyle(.secondary)
                    Text(row.value)
                        .font(.callout)
                        .textSelection(.enabled)
                        .contextMenu {
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(row.value, forType: .string)
                            }
                        }
                    if let explanation = row.explanation {
                        Text(explanation)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Divider()
            }
        }
    }
}

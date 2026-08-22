import SwiftUI
import NintekKit

/// Image-forward Shaper/CNC project layer.
struct ShaperProjectCard: View {
    let project: ShaperProject
    let heroURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Theme.recessed)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .overlay {
                        if heroURL != nil {
                            AuthImage(url: heroURL, contentMode: .fill, placeholderSymbol: "cpu")
                                .allowsHitTesting(false)
                        } else {
                            PlanCanvasBackground()
                                .overlay {
                                    Image(systemName: "cpu")
                                        .font(.system(size: 30, weight: .medium))
                                        .foregroundStyle(Theme.annotation.opacity(0.42))
                                }
                        }
                    }
                    .clipped()
                    .contentShape(Rectangle())

                Label("Shaper", systemImage: "cpu")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.action)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(12)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(project.title.isEmpty ? "Untitled" : project.title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                if let desc = project.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                }

                HStack(spacing: 14) {
                    Label("\(project.materials.count) materials", systemImage: "cube.box")
                    Label("CNC project", systemImage: "scope")
                }
                .font(.caption)
                .foregroundStyle(Theme.muted)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                .strokeBorder(Theme.divider.opacity(0.62), lineWidth: 1)
        )
        .shadow(color: Theme.navigationDeep.opacity(0.1), radius: 14, x: 0, y: 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var values = [
            project.title.isEmpty ? "Untitled Shaper project" : project.title,
            "\(project.materials.count) materials",
            "Source Shaper"
        ]
        if let description = project.description, !description.isEmpty {
            values.insert(description, at: 1)
        }
        return values.joined(separator: ", ")
    }

}

import SwiftUI
import NintekKit

/// Image-forward library card for a locally imported public 3D project.
struct BambuProjectCard: View {
    let project: BambuProject
    let heroURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Theme.recessed)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .overlay {
                        if heroURL != nil {
                            AuthImage(url: heroURL, contentMode: .fill, placeholderSymbol: "cube.fill")
                                .allowsHitTesting(false)
                        } else {
                            PlanCanvasBackground()
                                .overlay {
                                    Image(systemName: "cube.fill")
                                        .font(.system(size: 30, weight: .medium))
                                        .foregroundStyle(Theme.annotation.opacity(0.42))
                                }
                        }
                    }
                    .clipped()
                    .contentShape(Rectangle())

                Label(
                    project.sourceSite.workshopDisplayName,
                    systemImage: project.sourceSite.workshopSymbol
                )
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

                if let description = project.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                } else if let creator = project.creatorName, !creator.isEmpty {
                    Text("By \(creator)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }

                HStack(spacing: 14) {
                    Label(count(project.imageCount, singular: "image"), systemImage: "photo")
                    Label(count(project.fileCount, singular: "file"), systemImage: "doc.zipper")
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
            project.title.isEmpty ? "Untitled 3D project" : project.title,
            project.sourceSite.workshopDisplayName,
            count(project.imageCount, singular: "image"),
            count(project.fileCount, singular: "file"),
        ]
        if let creator = project.creatorName, !creator.isEmpty {
            values.insert("By \(creator)", at: 2)
        }
        return values.joined(separator: ", ")
    }

    private func count(_ value: Int, singular: String) -> String {
        "\(value) \(singular)\(value == 1 ? "" : "s")"
    }
}

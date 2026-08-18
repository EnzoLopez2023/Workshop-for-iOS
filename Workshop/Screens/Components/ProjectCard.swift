import SwiftUI
import NintekKit

/// Image-forward project layer used by the dashboard library. `heroURL` is
/// prebuilt by the parent so this view stays free of auth concerns.
struct ProjectCard: View {
    let project: WSProject
    let heroURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Rectangle()
                    .fill(Theme.flapShade)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .overlay {
                        if heroURL != nil {
                            AuthImage(url: heroURL, contentMode: .fill)
                                .allowsHitTesting(false)
                        } else {
                            PlanCanvasBackground()
                                .overlay {
                                    Image(systemName: "ruler")
                                        .font(.system(size: 28, weight: .medium))
                                        .foregroundStyle(Theme.accent.opacity(0.44))
                                }
                        }
                    }
                    .clipped()
                    .contentShape(Rectangle())

                StatusBadge(status: project.status, withBackdrop: true)
                    .padding(12)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(project.title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let desc = project.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    Label(
                        project.woodTypes.isEmpty ? "Wood not set" : project.woodTypes.joined(separator: " · "),
                        systemImage: "tree"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Label("\(project.partsCount ?? 0)", systemImage: "square.stack.3d.up")
                    Label(
                        project.estimatedHours > 0 ? "\(project.estimatedHours)h" : "—",
                        systemImage: "clock"
                    )
                }
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                .strokeBorder(Theme.line.opacity(0.62), lineWidth: 1)
        )
        .shadow(color: Theme.steelDark.opacity(0.1), radius: 14, x: 0, y: 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var values = [
            project.title,
            "Status \(project.status.rawValue)",
            "Stock \(project.woodTypes.isEmpty ? "not specified" : project.woodTypes.joined(separator: ", "))",
            "\(project.partsCount ?? 0) parts",
            project.estimatedHours > 0 ? "\(project.estimatedHours) hours" : "Hours not estimated"
        ]
        if let description = project.description, !description.isEmpty {
            values.insert(description, at: 2)
        }
        return values.joined(separator: ", ")
    }

}

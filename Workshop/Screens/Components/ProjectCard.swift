import SwiftUI
import NintekKit

/// A departure card: status flap top-right, destination in tracked caps, and
/// the three figures that decide whether you can start it today. Mirrors
/// `src/components/ProjectCard.tsx` and the `.depart-*` rules. `heroURL` is
/// prebuilt by the parent (`api.imageURL(imageId:userKey:)`), so this view
/// stays free of auth concerns.
struct ProjectCard: View {
    let project: WSProject
    let heroURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The Rectangle establishes the box and AuthImage fills it as an
            // overlay. Applying `.aspectRatio(contentMode: .fill)` to the image
            // directly lets it report a size larger than the proposal, so
            // `.clipped()` clips to the overflowed frame and the photo spills
            // across the grid.
            if heroURL != nil {
                Rectangle().fill(Theme.flapShade)
                    .aspectRatio(16.0 / 10.0, contentMode: .fit)
                    .overlay { AuthImage(url: heroURL, contentMode: .fill) }
                    .clipped()
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Theme.line).frame(height: 1)
                    }
            }

            HStack(alignment: .top, spacing: 12) {
                BoardCaps(project.title, size: 13.5)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                StatusBadge(status: project.status)
            }
            .padding(.horizontal, 14)
            .padding(.top, heroURL == nil ? 14 : 4)

            if let desc = project.description, !desc.isEmpty {
                Text(desc)
                    .font(Theme.ui(13))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
                    .padding(.horizontal, 14)
            }

            Spacer(minLength: 0)

            // The three figures, in their own cells, divided like a board's data
            // strip. The 1pt gaps let the line colour show through as dividers.
            HStack(spacing: 1) {
                cell("Stock", project.woodTypes.isEmpty ? "—" : project.woodTypes.joined(separator: " · "))
                cell("Parts", String(format: "%02d", project.partsCount ?? 0), fixed: true)
                cell("Hours", project.estimatedHours > 0 ? "\(project.estimatedHours)" : "—", fixed: true)
            }
            .background(Theme.line)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.flap)
        .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel))
        .overlay(RoundedRectangle(cornerRadius: Theme.rPanel).strokeBorder(Theme.line, lineWidth: 1))
    }

    private func cell(_ label: String, _ value: String, fixed: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(Theme.board(8.5, .semibold, relativeTo: .caption2))
                .tracking(1.1)
                .foregroundStyle(Theme.muted)
            Readout(value, size: 11.5)
                .lineLimit(1)
        }
        .frame(maxWidth: fixed ? nil : .infinity, alignment: .leading)
        .frame(minWidth: 46, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 9)
        .background(Theme.flapShade)
    }
}

import SwiftUI
import NintekKit

/// The Shaper Hub's departure card. Same board grammar as `ProjectCard`, with
/// a steel origin plate on the photo instead of a status flap — a Shaper
/// project has no status, it has a source. Mirrors
/// `src/components/ShaperProjectCard.tsx`.
struct ShaperProjectCard: View {
    let project: ShaperProject
    let heroURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Theme.flapShade)
                    .aspectRatio(16.0 / 10.0, contentMode: .fit)
                    .overlay {
                        if heroURL != nil {
                            AuthImage(url: heroURL, contentMode: .fill, placeholderSymbol: "cpu")
                        } else {
                            Image(systemName: "cpu")
                                .font(.system(size: 30))
                                .foregroundStyle(Theme.line)
                        }
                    }
                    .clipped()
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Theme.line).frame(height: 1)
                    }

                Text("SHAPER HUB")
                    .font(Theme.board(8.5, .bold, relativeTo: .caption2))
                    .tracking(1.4)
                    .foregroundStyle(Theme.onSteel)
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(Theme.steel.opacity(0.92), in: RoundedRectangle(cornerRadius: Theme.rFlap))
                    .padding(10)
            }

            BoardCaps(project.title.isEmpty ? "Untitled" : project.title, size: 13.5)
                .lineLimit(2)
                .padding(.horizontal, 14)

            if let desc = project.description, !desc.isEmpty {
                Text(desc)
                    .font(Theme.ui(13))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
                    .padding(.horizontal, 14)
            }

            Spacer(minLength: 0)

            HStack(spacing: 1) {
                cell("Materials", String(format: "%02d", project.materials.count))
                cell("Source", "Shaper", wide: true)
            }
            .background(Theme.line)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.flap)
        .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel))
        .overlay(RoundedRectangle(cornerRadius: Theme.rPanel).strokeBorder(Theme.line, lineWidth: 1))
    }

    private func cell(_ label: String, _ value: String, wide: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(Theme.board(8.5, .semibold, relativeTo: .caption2))
                .tracking(1.1)
                .foregroundStyle(Theme.muted)
            Readout(value, size: 11.5)
                .lineLimit(1)
        }
        .frame(maxWidth: wide ? .infinity : nil, alignment: .leading)
        .frame(minWidth: 62, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 9)
        .background(Theme.flapShade)
    }
}

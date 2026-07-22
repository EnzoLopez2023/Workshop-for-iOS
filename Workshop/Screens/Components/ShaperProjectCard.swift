import SwiftUI
import NintekKit

/// Shaper Hub project card — photo (hero image, else external `photo_url`, else a
/// CNC glyph), a "SHAPER HUB" ribbon, title, 2-line description, and a materials
/// count. Mirrors `src/components/ShaperProjectCard.tsx`.
struct ShaperProjectCard: View {
    let project: ShaperProject
    let heroURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Theme.creamSoft)
                    .aspectRatio(16.0 / 10.0, contentMode: .fit)
                    .overlay {
                        if heroURL != nil {
                            AuthImage(url: heroURL, contentMode: .fill, placeholderSymbol: "cpu")
                        } else {
                            Image(systemName: "cpu").font(.system(size: 34)).foregroundStyle(Theme.line)
                        }
                    }
                    .clipped()

                Text("SHAPER HUB")
                    .font(.system(size: 10, weight: .bold)).tracking(1.4)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(10)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(project.title.isEmpty ? "Untitled" : project.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                if let desc = project.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.subtle)
                        .lineLimit(2)
                }
                if !project.materials.isEmpty {
                    Text("\(project.materials.count) material\(project.materials.count == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.subtle)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .background(Theme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line, lineWidth: 1))
        .shadow(color: Color(red: 0.23, green: 0.14, blue: 0.06).opacity(0.10), radius: 9, x: 0, y: 5)
    }
}

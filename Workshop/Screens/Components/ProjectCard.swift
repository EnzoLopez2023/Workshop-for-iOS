import SwiftUI
import NintekKit

/// Project grid card — hero image (or monogram), status badge, title, 2-line
/// description, and a footer of wood types · estimated hours. Mirrors
/// `src/components/ProjectCard.tsx`. `heroURL` is prebuilt by the parent
/// (`api.imageURL(imageId:userKey:)`), so this view stays free of auth concerns.
struct ProjectCard: View {
    let project: WSProject
    let heroURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Theme.creamSoft)
                    .aspectRatio(16.0 / 11.0, contentMode: .fit)
                    .overlay {
                        if heroURL != nil {
                            AuthImage(url: heroURL, contentMode: .fill)
                        } else {
                            Text(project.title.prefix(1))
                                .font(.system(size: 34, weight: .semibold, design: .serif))
                                .italic()
                                .foregroundStyle(Theme.subtle)
                        }
                    }
                    .clipped()

                StatusBadge(status: project.status, withBackdrop: true)
                    .padding(12)
            }

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                    if let desc = project.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.subtle)
                            .lineLimit(2)
                    }
                }

                Divider().overlay(Theme.line)

                HStack {
                    Text(project.woodTypes.isEmpty ? "—" : project.woodTypes.joined(separator: " · "))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.system(size: 12))
                        Text("\(project.estimatedHours)h").font(.system(size: 13))
                    }
                    .foregroundStyle(Theme.subtle)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 18)
        }
        .background(Theme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line, lineWidth: 1))
        .shadow(color: Color(red: 0.23, green: 0.14, blue: 0.06).opacity(0.10), radius: 9, x: 0, y: 5)
    }
}

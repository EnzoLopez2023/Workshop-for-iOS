import SwiftUI
import NintekKit

/// Project detail. Phase 2.1 lands a working loader + header; Phase 2.2 expands
/// this to full parity with `ProjectDetail.tsx` (meta grid, wood/tools chips,
/// sketches + inspiration galleries, cut list, materials, finish/build logs,
/// linked projects).
struct ProjectDetailView: View {
    let api: WorkshopAPI
    let projectId: Int
    @EnvironmentObject private var model: AppModel

    @State private var detail: WSProjectDetail?
    @State private var loading = true
    @State private var loadError: String?

    var body: some View {
        ScrollView {
            if let d = detail {
                VStack(alignment: .leading, spacing: 16) {
                    if let hero = heroURL(d) {
                        AuthImage(url: hero, contentMode: .fill)
                            .frame(height: 220).frame(maxWidth: .infinity).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    StatusBadge(status: d.status)
                    Text(d.title).font(Theme.display(28)).foregroundStyle(Theme.ink)
                    if let desc = d.description, !desc.isEmpty {
                        Text(desc).font(.body).foregroundStyle(Theme.inkSoft)
                    }
                    Text("Full detail — Phase 2.2")
                        .font(.footnote).foregroundStyle(Theme.subtle)
                        .padding(.top, 8)
                }
                .contentColumn()
                .padding(20)
            } else if loading {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
            } else if let err = loadError {
                VStack(spacing: 8) {
                    Text("Couldn’t load project").font(.headline).foregroundStyle(Theme.ink)
                    Text(err).font(.footnote).foregroundStyle(Theme.subtle)
                    Button("Retry") { Task { await load() } }
                }.padding(.top, 60)
            }
        }
        .creamBackground()
        .navigationTitle(detail?.title ?? "Project")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func heroURL(_ d: WSProjectDetail) -> URL? {
        guard let key = model.userKey,
              let sketch = d.images.first(where: { $0.kind == .sketch && !$0.isPDF }) ?? d.images.first
        else { return nil }
        return api.imageURL(imageId: sketch.id, userKey: key)
    }

    private func load() async {
        loading = true; loadError = nil
        do { detail = try await api.project(id: projectId) }
        catch { loadError = error.localizedDescription }
        loading = false
    }
}

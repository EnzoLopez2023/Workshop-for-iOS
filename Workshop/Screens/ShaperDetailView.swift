import SwiftUI
import NintekKit

/// Shaper project detail. Phase 2.1 lands a working loader + header; Phase 2.3
/// expands to full parity with `ShaperProjectDetail.tsx` (photo hero, materials,
/// instructions, gallery, cut list).
struct ShaperDetailView: View {
    let api: WorkshopAPI
    let shaperId: Int
    @EnvironmentObject private var model: AppModel

    @State private var project: ShaperProject?
    @State private var loading = true
    @State private var loadError: String?

    var body: some View {
        ScrollView {
            if let p = project {
                VStack(alignment: .leading, spacing: 16) {
                    if let hero = heroURL(p) {
                        AuthImage(url: hero, contentMode: .fill, placeholderSymbol: "cpu")
                            .frame(height: 220).frame(maxWidth: .infinity).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    Eyebrow("Shaper Hub")
                    Text(p.title).font(Theme.display(28)).foregroundStyle(Theme.ink)
                    if let desc = p.description, !desc.isEmpty {
                        Text(desc).font(.body).foregroundStyle(Theme.inkSoft)
                    }
                    Text("Full detail — Phase 2.3")
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
        .navigationTitle(project?.title ?? "Shaper")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func heroURL(_ p: ShaperProject) -> URL? {
        if let id = p.heroImageId, let key = model.userKey { return api.imageURL(imageId: id, userKey: key) }
        if let photo = p.photoUrl, let url = URL(string: photo) { return url }
        return nil
    }

    private func load() async {
        loading = true; loadError = nil
        do { project = try await api.shaperProject(id: shaperId) }
        catch { loadError = error.localizedDescription }
        loading = false
    }
}

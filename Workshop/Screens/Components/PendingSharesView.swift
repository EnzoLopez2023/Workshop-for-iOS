import SwiftUI
import NintekKit

/// Reconciles items the Share Extension queued (Phase 7.5) — the extension
/// has no authenticated `WorkshopAPI`, so it just captured the URL/image;
/// this view does the actual authenticated work once the app is open. A
/// link opens the New Project form prefilled with that URL (via
/// `onCreateProject`); a photo picks an existing project to attach it to as
/// Inspiration.
struct PendingSharesView: View {
    let api: WorkshopAPI
    let items: [PendingShareItem]
    let onCreateProject: (String) -> Void
    let onHandled: (PendingShareItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var projects: [WSProject] = []
    @State private var attachingItem: PendingShareItem?
    @State private var attaching = false
    @State private var attachError: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    row(item)
                }
            }
            .navigationTitle("Shared with Workshop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                .boardToolbarItem()
            }
            .task { projects = (try? await api.listProjects()) ?? [] }
        }
    }

    @ViewBuilder private func row(_ item: PendingShareItem) -> some View {
        switch item.kind {
        case .url:
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shared Link").font(Theme.ui(14, .medium))
                    Text(item.urlString ?? "").font(Theme.ui(12, .regular)).foregroundStyle(Theme.muted).lineLimit(2)
                }
                Spacer()
                Button("Create Project") {
                    onHandled(item)
                    dismiss()
                    onCreateProject(item.urlString ?? "")
                }
                .font(Theme.ui(13, .medium))
            }
            .swipeActions { discardButton(item) }
        case .image:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    if let data = ShareQueue.imageData(for: item), let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage).resizable().aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    Text("Shared Photo").font(Theme.ui(14, .medium))
                    Spacer()
                }
                if attachingItem?.id == item.id {
                    ProgressView().frame(maxWidth: .infinity)
                } else if projects.isEmpty {
                    Text("Create a project first, then add this from its Sketches or Inspiration section.")
                        .font(Theme.ui(12, .regular)).foregroundStyle(Theme.muted)
                } else {
                    Menu {
                        ForEach(projects) { project in
                            Button(project.title) { Task { await attach(item, to: project) } }
                        }
                    } label: {
                        Label("Add to Project…", systemImage: "photo.badge.plus")
                            .font(Theme.ui(13, .medium))
                    }
                }
                if attachError != nil, attachingItem?.id == item.id {
                    Text(attachError!).font(Theme.ui(11, .regular)).foregroundStyle(Theme.red)
                }
            }
            .padding(.vertical, 4)
            .swipeActions { discardButton(item) }
        }
    }

    private func discardButton(_ item: PendingShareItem) -> some View {
        Button(role: .destructive) { onHandled(item) } label: {
            Label("Discard", systemImage: "trash")
        }
    }

    private func attach(_ item: PendingShareItem, to project: WSProject) async {
        guard let data = ShareQueue.imageData(for: item) else { return }
        attachingItem = item
        attachError = nil
        do {
            let file = MultipartFile(filename: "shared-\(Int(Date().timeIntervalSince1970)).jpg", mimeType: "image/jpeg", data: data)
            try await api.uploadImage(projectId: project.id, kind: .inspiration, file: file)
            Haptics.success()
            ToastCenter.shared.success("Added to \(project.title)")
            onHandled(item)
        } catch {
            attachError = "Could not attach: \(error.localizedDescription)"
        }
        attachingItem = nil
    }
}

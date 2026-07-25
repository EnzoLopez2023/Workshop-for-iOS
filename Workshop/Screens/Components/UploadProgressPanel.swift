import SwiftUI

/// One in-flight (or just-finished) upload — mirrors the web's `UploadEntry`.
struct UploadEntry: Identifiable {
    let id: UUID
    var name: String
    var progress: Double = 0
    var status: Status = .uploading
    var error: String?
    enum Status { case uploading, done, error }

    init(id: UUID = UUID(), name: String, progress: Double = 0, status: Status = .uploading, error: String? = nil) {
        self.id = id; self.name = name; self.progress = progress; self.status = status; self.error = error
    }
}

/// Floating upload-progress cards — parity with the web's `UploadProgressPanel`.
/// Bottom-trailing overlay; each card shows a spinner + progress bar while
/// uploading, a checkmark on success, or an error with dismiss.
struct UploadProgressPanel: View {
    let uploads: [UploadEntry]
    let onDismiss: (UUID) -> Void

    var body: some View {
        if !uploads.isEmpty {
            VStack(spacing: 8) {
                ForEach(uploads) { u in card(u) }
            }
            .frame(maxWidth: 300)
        }
    }

    private func card(_ u: UploadEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                switch u.status {
                case .uploading:
                    ProgressView().controlSize(.mini)
                case .done:
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                case .error:
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.fail)
                }
                Text(u.name).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.ink)
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                if u.status != .uploading {
                    Button { onDismiss(u.id) } label: {
                        Image(systemName: "xmark").font(.system(size: 11)).foregroundStyle(Theme.subtle)
                    }
                }
            }
            if u.status == .uploading {
                ProgressView(value: u.progress).tint(Theme.accent)
                Text("\(Int(u.progress * 100))%").font(.system(size: 11)).foregroundStyle(Theme.subtle)
            }
            if u.status == .error, let error = u.error {
                Text(error).font(.system(size: 12)).foregroundStyle(Theme.fail)
            }
        }
        .padding(12)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
    }
}

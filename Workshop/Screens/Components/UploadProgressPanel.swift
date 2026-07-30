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
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.red)
                }
                Text(u.name).font(Theme.ui(13, .medium)).foregroundStyle(Theme.ink)
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                if u.status != .uploading {
                    Button { onDismiss(u.id) } label: {
                        Image(systemName: "xmark").font(.system(size: 11)).foregroundStyle(Theme.muted)
                    }
                }
            }
            if u.status == .uploading {
                ProgressView(value: u.progress).tint(Theme.accent)
                Text("\(Int(u.progress * 100))%").font(Theme.ui(11, .regular)).foregroundStyle(Theme.muted)
            }
            if u.status == .error, let error = u.error {
                Text(error).font(Theme.ui(12, .regular)).foregroundStyle(Theme.red)
            }
        }
        .padding(12)
        .background(Theme.flap, in: RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.24), radius: 7, x: 0, y: 3)
    }
}

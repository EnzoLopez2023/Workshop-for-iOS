import SwiftUI

/// Transient success/error banners — native equivalent of the web's `sonner`
/// toasts. A singleton so any view or async function can post one without
/// threading a binding through; `RootView` hosts the actual overlay.
@MainActor
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()
    private init() {}

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let style: Style
        enum Style { case success, error }
    }

    @Published private(set) var current: Toast?
    private var dismissTask: Task<Void, Never>?

    func success(_ message: String) { show(Toast(message: message, style: .success)) }
    func error(_ message: String) { show(Toast(message: message, style: .error)) }

    private func show(_ toast: Toast) {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { current = toast }
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { current = nil }
        }
    }
}

/// The floating banner itself — pinned to the top by `RootView`, above
/// whichever tab/screen is showing.
struct ToastOverlay: View {
    @ObservedObject private var center = ToastCenter.shared

    var body: some View {
        VStack {
            if let toast = center.current {
                HStack(spacing: 10) {
                    Image(systemName: toast.style == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    Text(toast.message).font(Theme.ui(14, .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(toast.style == .success ? Theme.accent : Theme.red, in: RoundedRectangle(cornerRadius: Theme.rFlap))
                .shadow(color: .black.opacity(0.28), radius: 6, y: 3)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }
}

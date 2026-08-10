import SwiftUI
import UIKit

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
        let animation: Animation? = UIAccessibility.isReduceMotionEnabled
            ? nil
            : .spring(response: 0.35, dampingFraction: 0.8)
        withAnimation(animation) { current = toast }
        UIAccessibility.post(
            notification: .announcement,
            argument: "\(toast.style == .success ? "Success" : "Error"): \(toast.message)"
        )
        dismissTask = Task {
            let duration: UInt64 = UIAccessibility.isVoiceOverRunning ? 5_000_000_000 : 2_600_000_000
            try? await Task.sleep(nanoseconds: duration)
            guard !Task.isCancelled else { return }
            withAnimation(animation) { current = nil }
        }
    }
}

/// The floating banner itself — pinned to the top by `RootView`, above
/// whichever tab/screen is showing.
struct ToastOverlay: View {
    @ObservedObject private var center = ToastCenter.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            if let toast = center.current {
                HStack(spacing: 10) {
                    Image(systemName: toast.style == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .accessibilityHidden(true)
                    Text(toast.message).font(Theme.ui(14, .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(
                    toast.style == .success
                        ? Color(red: 0.08, green: 0.31, blue: 0.18)
                        : Color(red: 0.50, green: 0.06, blue: 0.04),
                    in: RoundedRectangle(cornerRadius: Theme.rFlap)
                )
                .shadow(color: .black.opacity(0.28), radius: 6, y: 3)
                .padding(.top, 8)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(toast.style == .success ? "Success" : "Error"): \(toast.message)")
                .accessibilityAddTraits(.isStaticText)
                .zIndex(1)
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }
}

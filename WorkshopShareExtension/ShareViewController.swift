import UIKit
import SwiftUI
import UniformTypeIdentifiers
import NintekKit

/// "Add to Workshop" from Safari/Photos/Pinterest share sheets (Phase 7.5).
/// Like the Phase 7.2 widget button, this extension has no authenticated
/// `WorkshopAPI` of its own — it just captures the shared URL/image into
/// `ShareQueue` and confirms; the app creates the project (URL) or offers to
/// attach the photo as Inspiration (image) the next time it's opened.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        Task { await handleShare() }
    }

    private func handleShare() async {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first else {
            complete()
            return
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let url = await loadURL(from: provider) {
                ShareQueue.enqueueURL(url.absoluteString)
                showConfirmation("Link saved — open Workshop to add it as a new project.")
                return
            }
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            if let image = await loadImage(from: provider), let data = image.jpegData(compressionQuality: 0.85) {
                if ShareQueue.enqueueImage(data) {
                    showConfirmation("Photo saved — open Workshop to add it to a project.")
                } else {
                    showConfirmation("Couldn't save this photo.", ok: false)
                }
                return
            }
        }
        showConfirmation("Workshop can only save links and photos.", ok: false)
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { cont in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                cont.resume(returning: item as? URL)
            }
        }
    }

    private func loadImage(from provider: NSItemProvider) async -> UIImage? {
        await withCheckedContinuation { cont in
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                cont.resume(returning: object as? UIImage)
            }
        }
    }

    /// A board confirmation rather than a system alert: the share sheet is the
    /// one place a user meets Workshop outside the app, so it wears the same
    /// steel and flaps. It dismisses itself — a share is a one-way action and
    /// making someone tap "Done" to acknowledge their own tap is friction.
    private func showConfirmation(_ message: String, ok: Bool = true) {
        let card = UIHostingController(rootView: ShareConfirmationCard(message: message, ok: ok))
        card.view.backgroundColor = .clear
        card.modalPresentationStyle = .overFullScreen
        card.modalTransitionStyle = .crossDissolve
        present(card, animated: true)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.7))
            self.complete()
        }
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}


// MARK: - Confirmation card

/// The Concourse Board world, reduced to the two tokens a one-shot confirmation
/// needs. The extension can't reach the app's `Palette`, so these are the amber
/// defaults from DESIGN.md.
private enum ShareTheme {
    static let flap    = adaptive(0xF7F9F6, 0x171B1D)
    static let ink     = adaptive(0x14181A, 0xEFF2ED)
    static let muted   = adaptive(0x59686A, 0x8B9794)
    static let line    = adaptive(0xC0CAC6, 0x2C3335)
    static let amber   = Color(red: 1, green: 0.706, blue: 0)
    static let red     = adaptive(0xB3271F, 0xD3392F)

    static func adaptive(_ l: UInt, _ d: UInt) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? ui(d) : ui(l) })
    }
    private static func ui(_ hex: UInt) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

private struct ShareConfirmationCard: View {
    let message: String
    let ok: Bool

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 0) {
                // The steel band, carried across every surface of this world.
                HStack(spacing: 7) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(ok ? ShareTheme.amber : ShareTheme.red)
                    Text("THE WORKSHOP")
                        .font(.custom("MartianMonoBoard-Bold", size: 11))
                        .tracking(1.5)
                        .foregroundStyle(Color(red: 0.929, green: 0.945, blue: 0.933))
                    Spacer(minLength: 0)
                    Text(ok ? "SAVED" : "NOT SAVED")
                        .font(.custom("MartianMonoBoard-Bold", size: 9))
                        .tracking(1.2)
                        .foregroundStyle(ok ? ShareTheme.amber : ShareTheme.red)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(
                    LinearGradient(colors: [Color(red: 0.227, green: 0.263, blue: 0.290),
                                            Color(red: 0.137, green: 0.165, blue: 0.184)],
                                   startPoint: .top, endPoint: .bottom)
                )

                Text(message)
                    .font(.custom("ArchivoWS-Regular", size: 14))
                    .foregroundStyle(ShareTheme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 15)
                    .background(ShareTheme.flap)
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(ShareTheme.line, lineWidth: 1))
            .padding(.horizontal, 20)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.35))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

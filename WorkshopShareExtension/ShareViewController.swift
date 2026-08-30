import UIKit
import SwiftUI
import UniformTypeIdentifiers
import NintekKit

/// "Add to Workshop" from URL and image share sheets.
/// The extension has no authenticated `WorkshopAPI` of its own. It captures
/// into `ShareQueue`; the app performs the authenticated write after launch.
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
                showConfirmation("Open Workshop to add this link as a new project.")
                return
            }
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            if let image = await loadImage(from: provider), let data = image.jpegData(compressionQuality: 0.85) {
                if ShareQueue.enqueueImage(data) {
                    showConfirmation("Open Workshop to add this photo to a project.")
                } else {
                    showConfirmation("This photo couldn’t be saved. Try sharing it again.", ok: false)
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

    /// A brief, self-dismissing confirmation keeps a one-way share frictionless.
    private func showConfirmation(_ message: String, ok: Bool = true) {
        let card = UIHostingController(rootView: ShareConfirmationView(message: message, ok: ok))
        card.view.backgroundColor = .clear
        card.modalPresentationStyle = .overFullScreen
        card.modalTransitionStyle = .crossDissolve
        present(card, animated: true)
        Task { @MainActor in
            let delay = UIAccessibility.isVoiceOverRunning ? 4.5 : 1.7
            try? await Task.sleep(for: .seconds(delay))
            self.complete()
        }
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

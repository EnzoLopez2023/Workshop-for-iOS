import UIKit
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
                    showConfirmation("Couldn't save this photo.")
                }
                return
            }
        }
        showConfirmation("Workshop can only save links and photos.")
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

    private func showConfirmation(_ message: String) {
        let alert = UIAlertController(title: "Workshop", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Done", style: .default) { [weak self] _ in
            self?.complete()
        })
        present(alert, animated: true)
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

import SwiftUI
import NintekKit

/// Loads a Workshop image by URL. Workshop's image bytes come from auth-exempt
/// routes scoped by a `?oid=<userKey>` query param (an `<img>`/URLSession GET
/// can't send an Authorization header), so callers build the URL with
/// `WorkshopAPI.imageURL(imageId:userKey:)` / `buildLogImageURL(...)`, or pass an
/// external `image_url` directly. Results are cached in memory by URL for the
/// process lifetime.
actor ImageCache {
    static let shared = ImageCache()
    private var cache: [String: Data] = [:]
    func get(_ key: String) -> Data? { cache[key] }
    func set(_ key: String, _ data: Data) { cache[key] = data }
}

struct AuthImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    var placeholderSymbol: String = "photo"

    @State private var uiImage: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ZStack {
                    Theme.flapShade
                    Image(systemName: failed ? "exclamationmark.triangle" : placeholderSymbol)
                        .foregroundStyle(Theme.muted.opacity(0.5))
                }
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        uiImage = nil; failed = false
        guard let url else { return }
        let key = url.absoluteString
        if let cached = await ImageCache.shared.get(key), let img = UIImage(data: cached) {
            uiImage = img; return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                failed = true; return
            }
            await ImageCache.shared.set(key, data)
            uiImage = UIImage(data: data)
        } catch {
            failed = true
        }
    }
}

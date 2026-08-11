import SwiftUI
import NintekKit

/// Loads a Workshop image by URL. Workshop's image bytes come from auth-exempt
/// routes scoped by a `?oid=<userKey>` query param (an `<img>`/URLSession GET
/// can't send an Authorization header), so callers build the URL with
/// `WorkshopAPI.imageURL(imageId:userKey:)` / `buildLogImageURL(...)`, or pass an
/// external `image_url` directly. Results are cached in memory by URL with a
/// fixed budget so a long image-heavy session cannot grow without bound.
actor ImageCache {
    static let shared = ImageCache()

    private struct Entry {
        let data: Data
        var lastAccess: UInt64
    }

    private let byteLimit = 64 * 1_024 * 1_024
    private var cache: [String: Entry] = [:]
    private var byteCount = 0
    private var accessCounter: UInt64 = 0

    func get(_ key: String) -> Data? {
        guard var entry = cache[key] else { return nil }
        accessCounter &+= 1
        entry.lastAccess = accessCounter
        cache[key] = entry
        return entry.data
    }

    func set(_ key: String, _ data: Data) {
        guard data.count <= byteLimit else { return }
        if let existing = cache[key] {
            byteCount -= existing.data.count
        }
        accessCounter &+= 1
        cache[key] = Entry(data: data, lastAccess: accessCounter)
        byteCount += data.count
        trimToBudget()
    }

    func clear() {
        cache.removeAll(keepingCapacity: false)
        byteCount = 0
    }

    private func trimToBudget() {
        while byteCount > byteLimit,
              let oldest = cache.min(by: { $0.value.lastAccess < $1.value.lastAccess }) {
            byteCount -= oldest.value.data.count
            cache.removeValue(forKey: oldest.key)
        }
    }
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
        if DemoWorkshopData.isDemoURL(url) {
            guard let data = DemoWorkshopData.imageData(for: url),
                  let image = UIImage(data: data)
            else { failed = true; return }
            await ImageCache.shared.set(url.absoluteString, data)
            uiImage = image
            return
        }
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

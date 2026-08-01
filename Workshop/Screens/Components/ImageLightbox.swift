import SwiftUI
import VisionKit

/// A set of images to preview fullscreen, starting at `index`. Identifiable so it
/// can drive `.fullScreenCover(item:)`.
struct GalleryPreview: Identifiable {
    let id = UUID()
    let urls: [URL]
    let index: Int
}

/// Fullscreen, swipeable image pager with pinch-to-zoom — the native replacement
/// for the web lightbox. Black backdrop, tap Done to close.
struct ImageLightbox: View {
    let preview: GalleryPreview
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Int

    init(preview: GalleryPreview) {
        self.preview = preview
        _selection = State(initialValue: preview.index)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $selection) {
                ForEach(Array(preview.urls.enumerated()), id: \.offset) { idx, url in
                    ZoomableImage(url: url).tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: preview.urls.count > 1 ? .automatic : .never))

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(Theme.ui(17, .bold, relativeTo: .headline)).foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.15), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(20)
        }
    }
}

/// A single pinch/double-tap zoomable image inside the lightbox. Loads
/// through the same `ImageCache` `AuthImage` uses (so a photo already shown
/// elsewhere in the app doesn't re-fetch), but renders via a real
/// `UIImageView` rather than `AuthImage`'s SwiftUI `Image` — Live Text
/// (`ImageAnalysisInteraction`) needs to attach to the exact view showing the
/// pixels to align its text-selection boxes correctly (Phase 7.9+). The
/// fullscreen lightbox is the one place in the app a photo is large enough,
/// and held still enough, for reading a handwritten dimension or note off it
/// to be worth the interaction — not worth wiring into every thumbnail strip.
private struct ZoomableImage: View {
    let url: URL
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var uiImage: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let uiImage {
                LiveTextImageView(image: uiImage)
            } else if failed {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                ProgressView().tint(.white)
            }
        }
        .scaleEffect(scale)
        .gesture(
            MagnificationGesture()
                .onChanged { value in scale = min(max(lastScale * value, 1), 5) }
                .onEnded { _ in lastScale = scale }
        )
        .onTapGesture(count: 2) {
            withAnimation(.spring(duration: 0.25)) {
                scale = scale > 1 ? 1 : 2.5
                lastScale = scale
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        uiImage = nil; failed = false
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

/// Wraps a plain `UIImageView` with an `ImageAnalysisInteraction` attached —
/// the same Live Text / data-detector / Visual Look Up interaction iOS's own
/// Photos app offers, available for any already-uploaded photo, not just
/// what a live camera sees (unlike Phase 7.3's `DataScannerViewController`,
/// which needs camera hardware and is unconditionally unavailable in
/// Simulator, `ImageAnalyzer`'s static-image analysis works there — no
/// hardware dependency).
private struct LiveTextImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.isUserInteractionEnabled = true
        if ImageAnalyzer.isSupported {
            let interaction = ImageAnalysisInteraction()
            interaction.preferredInteractionTypes = .automatic
            view.addInteraction(interaction)
        }
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        guard uiView.image !== image else { return }
        uiView.image = image
        guard ImageAnalyzer.isSupported,
              let interaction = uiView.interactions.compactMap({ $0 as? ImageAnalysisInteraction }).first
        else { return }
        Task {
            let analyzer = ImageAnalyzer()
            let configuration = ImageAnalyzer.Configuration([.text, .visualLookUp])
            if let analysis = try? await analyzer.analyze(image, configuration: configuration) {
                interaction.analysis = analysis
            }
        }
    }
}

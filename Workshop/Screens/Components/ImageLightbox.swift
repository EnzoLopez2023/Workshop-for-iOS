import SwiftUI

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
                    .font(.headline).foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.15), in: Circle())
            }
            .padding(20)
        }
    }
}

/// A single pinch/double-tap zoomable image inside the lightbox.
private struct ZoomableImage: View {
    let url: URL
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        AuthImage(url: url, contentMode: .fit)
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
    }
}

import SwiftUI
import PencilKit

/// A freehand sketch canvas (Phase 7.4, iPad) — draw directly with Apple
/// Pencil (or a finger) as an alternative to uploading a photo of a paper
/// sketch. `PKCanvasView` works fine with simulated touch input too, unlike
/// the camera-dependent features elsewhere in Phase 7.
private struct PKCanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    /// `PKCanvasView` is a reference type, so SwiftUI has no way to notice
    /// in-place changes to `canvasView.drawing` — this binding is how the
    /// delegate below tells the sheet "there's now a stroke to save".
    @Binding var hasStrokes: Bool
    private let toolPicker = PKToolPicker()

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .white
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 4)
        canvasView.delegate = context.coordinator
        return canvasView
    }

    // The tool picker needs to attach after the view is actually in the
    // hierarchy and can become first responder — not yet at `makeUIView` time.
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        toolPicker.setVisible(true, forFirstResponder: uiView)
        toolPicker.addObserver(uiView)
        uiView.becomeFirstResponder()
    }

    func makeCoordinator() -> Coordinator { Coordinator(hasStrokes: $hasStrokes) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var hasStrokes: Bool
        init(hasStrokes: Binding<Bool>) { _hasStrokes = hasStrokes }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            hasStrokes = !canvasView.drawing.strokes.isEmpty
        }
    }
}

/// Full-screen sketch sheet — Clear/Cancel/Done, exporting the drawing as a
/// white-backed JPEG through the same upload pipeline as a camera/photo sketch.
struct SketchCanvasSheet: View {
    let onSave: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var canvasView = PKCanvasView()
    @State private var hasStrokes = false

    var body: some View {
        NavigationStack {
            PKCanvasRepresentable(canvasView: $canvasView, hasStrokes: $hasStrokes)
                .navigationTitle("Sketch")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    .boardToolbarItem()
                    ToolbarItem(placement: .principal) {
                        Button("Clear") { canvasView.drawing = PKDrawing(); hasStrokes = false }
                    }
                    .boardToolbarItem()
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save() }
                            .disabled(!hasStrokes)
                    }
                    .boardToolbarItem()
                }
        }
    }

    private func save() {
        let bounds = canvasView.drawing.bounds.insetBy(dx: -20, dy: -20)
        let image = canvasView.drawing.image(from: bounds.isEmpty ? canvasView.bounds : bounds, scale: 2)
        // Flatten onto a white background — PKDrawing.image(from:scale:) itself
        // renders with a transparent background, and the upload pipeline
        // re-encodes as JPEG (no alpha channel) either way.
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let flattened = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: image.size))
            image.draw(at: .zero)
        }
        if let jpeg = flattened.jpegData(compressionQuality: 0.9) {
            onSave(jpeg)
        }
        dismiss()
    }
}

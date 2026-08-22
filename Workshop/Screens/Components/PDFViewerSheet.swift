import SwiftUI
import PDFKit

/// PDFKit view for a loaded document.
private struct PDFKitView: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.document = PDFDocument(data: data)
        v.backgroundColor = .black
        return v
    }
    func updateUIView(_ v: PDFView, context: Context) {
        if v.document == nil { v.document = PDFDocument(data: data) }
    }
}

/// Fullscreen PDF preview. Fetches the bytes from a `?oid=` URL (auth-exempt, no
/// bearer needed) then renders with PDFKit. Used for sketch PDFs on the detail.
struct PDFViewerSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var data: Data?
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Group {
                if let data {
                    PDFKitView(data: data).ignoresSafeArea(edges: .bottom)
                } else if failed {
                    ContentUnavailableView("Couldn’t load PDF", systemImage: "doc.questionmark")
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                .planToolbarItem()
            }
            .task {
                do {
                    let (d, resp) = try await URLSession.shared.data(from: url)
                    if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { failed = true }
                    else { data = d }
                } catch { failed = true }
            }
        }
    }
}

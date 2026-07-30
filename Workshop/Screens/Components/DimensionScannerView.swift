import SwiftUI
import VisionKit

/// Live-camera text recognition for cut-list dimensions (Phase 7.3) — point
/// the camera at a tape measure or a printed cut sheet and tap a recognized
/// number/fraction to fill a field, instead of typing "27 1/2" by hand.
/// Wraps `DataScannerViewController` (iOS 16+, text-only — no barcode).
///
/// `DataScannerViewController` needs real camera hardware: `isSupported` and
/// `isAvailable` are both always `false` in the Simulator, so the "device
/// doesn't support scanning" fallback below is the only path this project
/// can exercise without a physical device.
private struct DimensionScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        if !vc.isScanning { try? vc.startScanning() }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case .text(let text) = item {
                onScan(text.transcript)
            }
        }
    }
}

/// The sheet presented from a cut-list row's "Scan" button: a segmented
/// control picks which field (Length/Width/Thickness) the next tapped number
/// fills, so all three dimensions of a part can be scanned in one pass.
struct DimensionScannerSheet: View {
    @Binding var length: String
    @Binding var width: String
    @Binding var thickness: String

    @Environment(\.dismiss) private var dismiss
    @State private var target: Field = .length
    @State private var lastScanned: String?

    private enum Field: String, CaseIterable, Identifiable {
        case length = "Length", width = "Width", thickness = "Thickness"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Field", selection: $target) {
                    ForEach(Field.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(12)

                ZStack(alignment: .bottom) {
                    if DataScannerViewController.isSupported, DataScannerViewController.isAvailable {
                        DimensionScannerView { text in apply(text) }
                    } else {
                        ContentUnavailableView(
                            "Scanning Unavailable",
                            systemImage: "camera.metering.unknown",
                            description: Text("This device doesn't support live text scanning.")
                        )
                    }
                    if let lastScanned {
                        Text("Filled \(target.rawValue): \(lastScanned)")
                            .font(Theme.ui(13, .medium, relativeTo: .footnote))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.rFlap))
                            .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Scan Dimension")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                .boardToolbarItem()
            }
        }
    }

    private func apply(_ text: String) {
        switch target {
        case .length: length = text
        case .width: width = text
        case .thickness: thickness = text
        }
        lastScanned = text
        Haptics.success()
    }
}

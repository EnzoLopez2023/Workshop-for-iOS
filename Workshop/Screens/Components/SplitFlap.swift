import SwiftUI

/// A Solari split-flap readout. Characters live in individual flap cells and,
/// when the value changes, roll through the drum toward their target the way a
/// real board does — bounded to a handful of steps so it never outstays its
/// welcome. Under Reduce Motion the value simply swaps.
///
/// This is the app's signature component; it is the one place motion is
/// authored rather than incidental. The flap modules are dark in both light and
/// dark renditions, because they are hardware, not a color scheme.
struct SplitFlap: View {
    enum Tone { case letter, amber, green, red }

    let value: String
    /// Pad on the left with blank flaps so the readout keeps a fixed width.
    var cells: Int?
    /// Accessible text; defaults to the value itself.
    var label: String?
    var size: CGFloat = 22
    var tone: Tone = .letter

    init(_ value: String, cells: Int? = nil, label: String? = nil,
         size: CGFloat = 22, tone: Tone = .letter) {
        self.value = value
        self.cells = cells
        self.label = label
        self.size = size
        self.tone = tone
    }

    /// The drum, in the order a Solari board actually carries its flaps.
    private static let drum = Array(" ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,:$-/+")
    private static let maxSteps = 5
    private static let stepInterval: Double = 0.055
    /// Ticks a column waits behind the one to its left, so the board falls in a
    /// cascade off a single motor rather than all at once.
    private static let staggerTicks = 2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var display: [Character] = []
    @State private var rollTask: Task<Void, Never>?

    private var target: [Character] {
        let padded = cells.map { String(repeating: " ", count: max(0, $0 - value.count)) + value } ?? value
        return Array(padded.uppercased())
    }

    private var letterColor: Color {
        switch tone {
        case .letter: Theme.flapLetter
        case .amber:  Theme.accentFill
        case .green:  Theme.greenFill
        case .red:    Theme.redFill
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(display.enumerated()), id: \.offset) { _, ch in
                FlapCell(character: ch, size: size, letterColor: letterColor)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? value)
        .onAppear { start(from: nil) }
        .onChange(of: target) { previous, _ in start(from: previous) }
        .onDisappear { rollTask?.cancel() }
    }

    /// Rolls each column from its current face to the target, staggered left to
    /// right. Blank columns start from a blank flap so a fresh board falls in
    /// rather than appearing.
    private func start(from previous: [Character]?) {
        rollTask?.cancel()
        let want = target

        guard !reduceMotion else {
            display = want
            return
        }

        let from = previous ?? Array(repeating: " ", count: want.count)
        var seed = want.indices.map { i in i < from.count ? from[i] : " " }
        if seed.count != want.count { seed = Array(repeating: " ", count: want.count) }
        display = seed

        let paths = want.indices.map { Self.path(from: seed[$0], to: want[$0]) }
        let ticks = paths.indices.map { $0 * Self.staggerTicks + paths[$0].count }.max() ?? 0
        guard ticks > 0 else { return }

        rollTask = Task { @MainActor in
            for tick in 0..<ticks {
                try? await Task.sleep(for: .seconds(Self.stepInterval))
                if Task.isCancelled { return }
                for column in paths.indices {
                    let step = tick - column * Self.staggerTicks
                    if step >= 0 && step < paths[column].count {
                        display[column] = paths[column][step]
                    }
                }
            }
            display = want
        }
    }

    /// The characters a cell rolls through to get from `from` to `to`, capped so
    /// a long journey around the drum still lands promptly.
    private static func path(from: Character, to: Character) -> [Character] {
        let end = index(of: to)
        let distance = (end - index(of: from) + drum.count) % drum.count
        let steps = min(distance, maxSteps)
        guard steps > 0 else { return [] }
        return (0..<steps).reversed().map { drum[(end - $0 + drum.count) % drum.count] }
    }

    private static func index(of ch: Character) -> Int {
        drum.firstIndex(of: Character(ch.uppercased())) ?? 0
    }
}

/// One flap module — a dark face, a bright letter, and the horizontal split the
/// two halves meet at.
private struct FlapCell: View {
    let character: Character
    let size: CGFloat
    let letterColor: Color

    private var cellWidth: CGFloat { size * 0.74 }
    private var cellHeight: CGFloat { size * 1.24 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.rFlap)
                .fill(Theme.flapFaceGradient)

            Text(String(character))
                .font(Theme.board(size * 0.68, .bold, relativeTo: .title3))
                .foregroundStyle(letterColor)
                .monospacedDigit()
                // The letter itself flips; a fresh identity on each change makes
                // SwiftUI treat it as a new view so the fall restarts.
                .id(character)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
                .animation(.easeOut(duration: 0.05), value: character)
                .clipped()

            // The split — where the upper and lower halves meet.
            Rectangle()
                .fill(Color.black.opacity(0.55))
                .frame(height: 1)
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
                .offset(y: 1)
        }
        .frame(width: cellWidth, height: cellHeight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.rFlap))
    }
}

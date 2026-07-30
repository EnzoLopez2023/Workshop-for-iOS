import SwiftUI
import NintekKit

/// A status is a lettered flap in a signal colour — the fill carries the
/// meaning, so there is no coloured dot doing the same job twice. Mirrors the
/// web `StatusBadge` / `.flag-*` rules.
struct StatusBadge: View {
    let status: ProjectStatus
    /// Over a hero image the flag sits on a steel plate so it stays legible on
    /// any photograph.
    var withBackdrop = false

    var body: some View {
        Flag(status.label, tone: tone)
            .padding(withBackdrop ? 3 : 0)
            .background {
                if withBackdrop {
                    RoundedRectangle(cornerRadius: Theme.rFlap).fill(Theme.steel.opacity(0.92))
                }
            }
    }

    private var tone: Flag.Tone {
        switch status {
        case .idea:       .idle
        case .planning:   .steel
        case .inProgress: .amber
        case .completed:  .green
        case .unknown:    .idle
        }
    }
}

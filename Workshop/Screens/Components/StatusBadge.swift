import SwiftUI
import NintekKit

/// Semantic project status capsule.
struct StatusBadge: View {
    let status: ProjectStatus
    /// Over a hero image the capsule gets a material backing for contrast.
    var withBackdrop = false

    var body: some View {
        Flag(status.label, tone: tone)
            .padding(withBackdrop ? 3 : 0)
            .background {
                if withBackdrop {
                    Capsule().fill(.ultraThinMaterial)
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

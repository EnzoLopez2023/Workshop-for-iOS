import SwiftUI
import NintekKit

/// Semantic project status capsule.
struct StatusBadge: View {
    let status: ProjectStatus
    /// Over a hero image the capsule gets a material backing for contrast.
    var withBackdrop = false

    var body: some View {
        StatusFlag(status.label, tone: tone)
            .padding(withBackdrop ? 3 : 0)
            .background {
                if withBackdrop {
                    Capsule().fill(.ultraThinMaterial)
                }
            }
    }

    private var tone: StatusFlag.Tone {
        switch status {
        case .idea:       .neutral
        case .planning:   .accent
        case .inProgress: .accentStrong
        case .completed:  .success
        case .unknown:    .neutral
        }
    }
}

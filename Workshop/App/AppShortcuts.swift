import AppIntents
import SwiftUI

/// In-process bridge from App Intents (Siri / Spotlight / Shortcuts) to the UI.
/// When an intent runs with `openAppWhenRun`, the system foregrounds the app and
/// runs `perform()` in this same process — so setting a flag here is observed by
/// `RootView`. A singleton because intents can't be handed the SwiftUI
/// environment. (Mirrors ShopKeepNative's `IntentRouter`.)
@MainActor
final class IntentRouter: ObservableObject {
    static let shared = IntentRouter()
    private init() {}

    /// Bumped on an "Open Shopping List"/"Open Dashboard" request; `RootView`
    /// observes this to switch tabs (a token rather than a Bool so repeat
    /// requests to the same destination still re-trigger).
    @Published var requestedTab: (id: UUID, destination: AppDestination)?

    func request(_ destination: AppDestination) {
        requestedTab = (UUID(), destination)
    }
}

/// "Open Shopping List" — jumps straight to the shopping list to check items
/// off. ("Add to shopping list check-off" from the Phase 6.3 plan — resolving
/// a *specific* item by name would need a background-executable intent with
/// its own silent auth, which isn't worth the risk this pass; opening straight
/// to the list is the safe, still-genuinely-useful version.)
struct OpenShoppingListIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Shopping List"
    static let description = IntentDescription("Open Workshop's shopping list to check off items.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentRouter.shared.request(.shopping)
        return .result()
    }
}

/// "Open Dashboard" — jumps straight to the project dashboard.
struct OpenDashboardIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Workshop Dashboard"
    static let description = IntentDescription("Open Workshop's project dashboard.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentRouter.shared.request(.dashboard)
        return .result()
    }
}

/// Registers Workshop's App Shortcuts so they appear in Spotlight and Siri
/// without the user building anything in the Shortcuts app.
struct WorkshopShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenShoppingListIntent(),
            phrases: [
                "Open my shopping list in \(.applicationName)",
                "\(.applicationName) shopping list",
            ],
            shortTitle: "Shopping List",
            systemImageName: "cart.fill"
        )
        AppShortcut(
            intent: OpenDashboardIntent(),
            phrases: [
                "Open my \(.applicationName) dashboard",
                "\(.applicationName) dashboard",
            ],
            shortTitle: "Dashboard",
            systemImageName: "square.grid.2x2.fill"
        )
    }
}

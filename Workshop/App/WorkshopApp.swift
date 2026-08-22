import SwiftUI
import MSAL
import CoreSpotlight

@main
struct WorkshopApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @StateObject private var theme = ThemeManager.shared

    init() {
        Theme.configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            launchView
                .environmentObject(model)
                .environmentObject(theme)
                .onOpenURL { url in
                    // workshop:// deep links route within the app; everything else
                    // is an MSAL redirect returning through the Microsoft broker.
                    if model.handleDeepLink(url) { return }
                    _ = MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: nil)
                }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    // Spotlight search result tap — the item's uniqueIdentifier IS
                    // the workshop:// deep link (see SpotlightIndexer), so this
                    // reuses the exact same routing as widgets/onOpenURL.
                    guard let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                          let url = URL(string: id) else { return }
                    model.handleDeepLink(url)
                }
                .onContinueUserActivity(HandoffActivity.viewingProject) { activity in
                    // Handoff from another of Enzo's devices (see ProjectDetailView's
                    // `.userActivity`) — same workshop://project/<id> URL the deep
                    // links already speak, so it reuses the identical routing.
                    guard let id = activity.userInfo?[HandoffActivity.projectIdKey] as? Int,
                          let url = URL(string: "workshop://project/\(id)") else { return }
                    model.handleDeepLink(url)
                }
        }
        }

        @ViewBuilder
        private var launchView: some View {
    #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-ui-test-share-confirmation") {
                ShareConfirmationView(
                    message: "Open Workshop to add this link as a new project.",
                    ok: true
                )
            } else {
                RootView()
            }
    #else
            RootView()
    #endif
    }
}

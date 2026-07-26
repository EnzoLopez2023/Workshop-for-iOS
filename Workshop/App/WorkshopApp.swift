import SwiftUI
import MSAL
import CoreSpotlight

@main
struct WorkshopApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var theme = ThemeManager.shared

    init() { Theme.configureAppearance() }

    var body: some Scene {
        WindowGroup {
            RootView()
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
        }
    }
}

import SwiftUI
import MSAL

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
        }
    }
}

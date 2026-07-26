import Foundation
import UIKit
import WidgetKit
import MSAL
import NintekKit

/// Root app state: owns dual auth (MSAL + Apple session) and the configured
/// Workshop API client, and tracks whether we're signed in. Workshop keeps the
/// Azure backend (data must sync with the web app + server-side AI), so native is
/// a SwiftUI REST client authenticating with the same Entra app registration as
/// the web — or with a Workshop session minted from Sign in with Apple.
@MainActor
final class AppModel: ObservableObject {
    let msalAuth: MSALAuth?
    let appleAuth: AppleAuthService
    private(set) var api: WorkshopAPI

    @Published var isSignedIn: Bool
    @Published var authError: String?
    @Published var selectedTab = AppDestination.dashboard.rawValue
    /// Set by a deep link (`workshop://project/<id>`); the projects list consumes
    /// it to push the detail, then clears it.
    @Published var pendingProjectId: Int?
    /// Set alongside `pendingProjectId` when the link carries `?cutplan=1`
    /// (the Spotlight "Plan Cuts: …" entry); `ProjectDetailView` consumes it to
    /// auto-expand the Cut Plan Optimizer section, then clears it.
    @Published var pendingShowCutPlan = false

    var userName: String? {
        if let session = AppleSessionStore.load() { return session.displayName ?? "Apple user" }
        return msalAuth?.accountName
    }

    /// The signed-in user's backend per-user key (Entra `oid` or `apple_<hash>`),
    /// used to build auth-exempt `?oid=` image URLs. nil when signed out.
    var userKey: String? {
        if let session = AppleSessionStore.load() { return session.userKey }
        return msalAuth?.oid
    }

    init() {
        let env = ProcessInfo.processInfo.environment
        let base = Self.baseURL()
        self.appleAuth = AppleAuthService(baseURL: base)

        // Dev/local: a pasted access token via env skips MSAL (used to exercise
        // the API without a signed build). Never set in production.
        if let devToken = env["WORKSHOP_DEV_TOKEN"] {
            self.msalAuth = nil
            self.api = WorkshopAPI(baseURL: base, tokenProvider: StaticTokenProvider(devToken))
            self.isSignedIn = true
            return
        }

        // Always construct MSAL so "Sign in with Microsoft" stays available, but
        // an existing Apple session takes precedence for the initial state.
        let auth = try? MSALAuth()
        self.msalAuth = auth

        if AppleSessionStore.hasSession {
            self.api = WorkshopAPI(baseURL: base, tokenProvider: SessionTokenProvider(service: appleAuth))
            self.isSignedIn = true
        } else if let auth {
            self.api = WorkshopAPI(baseURL: base, tokenProvider: MSALTokenProvider(auth: auth))
            self.isSignedIn = auth.hasAccount
        } else {
            self.api = WorkshopAPI(baseURL: base, tokenProvider: StaticTokenProvider(nil))
            self.isSignedIn = false
        }
    }

    private static func baseURL() -> URL {
        if let override = ProcessInfo.processInfo.environment["WORKSHOP_API_BASE"],
           let url = URL(string: override) { return url }
        return WorkshopAPI.productionBaseURL
    }

    func signInWithMicrosoft(presenting viewController: UIViewController) async {
        guard let msalAuth else { authError = "Microsoft sign-in is unavailable."; return }
        do {
            try await msalAuth.signInInteractively(presenting: viewController)
            api = WorkshopAPI(baseURL: Self.baseURL(), tokenProvider: MSALTokenProvider(auth: msalAuth))
            isSignedIn = msalAuth.hasAccount
            authError = nil
        } catch let error as NSError {
            if error.domain == MSALErrorDomain, error.code == MSALError.userCanceled.rawValue { return }
            NSLog("[Workshop] MSAL sign-in failed: domain=%@ code=%ld userInfo=%@",
                  error.domain, error.code, error.userInfo)
            authError = Self.describe(error)
        }
    }

    private static func describe(_ error: NSError) -> String {
        var lines: [String] = []
        if let d = error.userInfo[MSALErrorDescriptionKey] as? String { lines.append(d) }
        if let o = error.userInfo[MSALOAuthErrorKey] as? String { lines.append("OAuth: \(o)") }
        if lines.isEmpty { lines.append(error.localizedDescription) }
        lines.append("(\(error.domain) \(error.code))")
        return lines.joined(separator: "\n")
    }

    /// Exchange the Apple identity token (from SignInWithAppleButton) for a
    /// Workshop session and switch the API client to it. A nil token means the
    /// authorization produced no usable token (or failed) — surfaced as an error.
    func signInWithApple(idToken: String?, name: String?) async {
        guard let idToken else {
            authError = "Apple sign-in failed. Please try again."
            return
        }
        do {
            try await appleAuth.exchange(idToken: idToken, name: name)
            api = WorkshopAPI(baseURL: Self.baseURL(), tokenProvider: SessionTokenProvider(service: appleAuth))
            isSignedIn = true
            authError = nil
        } catch {
            NSLog("[Workshop] Apple sign-in failed: %@", String(describing: error))
            authError = "Apple sign-in failed. Please try again."
        }
    }

    func signOut() {
        AppleSessionStore.clear()
        try? msalAuth?.signOut()
        isSignedIn = false
        WorkshopWidgetStore.clear()
        WidgetCenter.shared.reloadAllTimelines()
        SpotlightIndexer.clear()
    }

    // MARK: - Deep links

    /// Routes a `workshop://` URL (opened from a widget, a Spotlight search
    /// result, or a share link) to the right tab and target. Returns true if
    /// handled, so `onOpenURL` can fall through to MSAL.
    @discardableResult
    func handleDeepLink(_ url: URL) -> Bool {
        guard url.scheme == "workshop" else { return false }
        let dest = url.host ?? "dashboard"
        switch dest {
        case "project":
            // workshop://project/<id>[?cutplan=1] — the Dashboard grid consumes
            // pendingProjectId; ProjectDetailView consumes pendingShowCutPlan.
            if let last = url.pathComponents.last, let id = Int(last) {
                pendingProjectId = id
                let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
                pendingShowCutPlan = query.contains { $0.name == "cutplan" && $0.value == "1" }
                selectedTab = AppDestination.dashboard.rawValue
            }
        case AppDestination.shopping.rawValue,
             AppDestination.tables.rawValue,
             AppDestination.more.rawValue:
            selectedTab = dest
        default:
            selectedTab = AppDestination.dashboard.rawValue
        }
        return true
    }
}

import Foundation
import MSAL
import UIKit
import NintekKit

/// Wraps MSAL for Workshop. Constants mirror the web app's `msalConfig` so both
/// clients authenticate against the same Entra app registration and request the
/// same API scope (`api://<clientId>/access_as_user`) — which is what makes the
/// native app share the signed-in user's per-user database with the web app.
/// `@MainActor` keeps all MSAL calls on the main thread (and makes the type
/// implicitly Sendable so ``MSALTokenProvider`` can hold it).
@MainActor
final class MSALAuth {
    // Same app registration + tenant as the Workshop web app (VITE_AZURE_*,
    // from .github/workflows/deploy.yml).
    static let clientId = "0f303f8f-207f-4b7f-84a5-b5d0abcf49d1"
    static let authorityURL = URL(string: "https://login.microsoftonline.com/52188f12-db6b-46c6-88ff-08c802f0ed3b")!
    static let redirectURI = "msauth.com.nintek.workshop://auth"
    static let scopes = ["api://0f303f8f-207f-4b7f-84a5-b5d0abcf49d1/access_as_user"]

    private let application: MSALPublicClientApplication

    init() throws {
        let authority = try MSALAADAuthority(url: Self.authorityURL)
        let config = MSALPublicClientApplicationConfig(
            clientId: Self.clientId,
            redirectUri: Self.redirectURI,
            authority: authority
        )
        // Use the app's own keychain group instead of MSAL's default shared
        // `com.microsoft.adalcache` group, which isn't in our entitlements and
        // otherwise fails token-cache access with an opaque internal error.
        config.cacheConfig.keychainSharingGroup = Bundle.main.bundleIdentifier ?? "com.nintek.workshop"
        application = try MSALPublicClientApplication(configuration: config)
    }

    var account: MSALAccount? { (try? application.allAccounts())?.first }
    var hasAccount: Bool { account != nil }

    var accountName: String? {
        guard let account else { return nil }
        return (account.accountClaims?["name"] as? String) ?? account.username
    }

    /// The Entra object id (the per-user DB key on the backend). Used to scope
    /// auth-exempt `?oid=` image requests, exactly like the web app's `currentOid`.
    var oid: String? {
        (account?.accountClaims?["oid"] as? String) ?? account?.identifier
    }

    /// Interactive sign-in via the system web sheet.
    func signInInteractively(presenting viewController: UIViewController) async throws {
        let webParams = MSALWebviewParameters(authPresentationViewController: viewController)
        let params = MSALInteractiveTokenParameters(scopes: Self.scopes, webviewParameters: webParams)
        params.promptType = .selectAccount

        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String?, Error>) in
            application.acquireToken(with: params) { result, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: result?.accessToken) }
            }
        }
    }

    /// Silent access-token acquisition for the API scope. Returns nil when there
    /// is no cached account (caller treats that as "not signed in").
    func acquireTokenSilently() async throws -> String? {
        guard let account else { return nil }
        let params = MSALSilentTokenParameters(scopes: Self.scopes, account: account)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String?, Error>) in
            application.acquireTokenSilent(with: params) { result, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: result?.accessToken) }
            }
        }
    }

    func signOut() throws {
        guard let account else { return }
        try application.remove(account)
    }
}

/// Drop-in ``TokenProvider`` backed by MSAL. `MSALAuth` is `@MainActor` (hence
/// Sendable); `accessToken()` hops to the main actor to call MSAL and returns
/// only the token string.
struct MSALTokenProvider: TokenProvider {
    let auth: MSALAuth
    func accessToken() async throws -> String? {
        try await auth.acquireTokenSilently()
    }
}

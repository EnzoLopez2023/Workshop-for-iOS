import Foundation
import MSAL
import UIKit
import NintekKit

enum EntraIdentity {
    static let legacyHomeTenantID = "52188f12-db6b-46c6-88ff-08c802f0ed3b"

    static func userKey(tenantID: String?, objectID: String?) -> String? {
        guard let tenantID = canonicalGUID(tenantID),
              let objectID = canonicalGUID(objectID) else {
            return nil
        }

        return tenantID == legacyHomeTenantID
            ? objectID
            : "\(tenantID)_\(objectID)"
    }

    private static func canonicalGUID(_ value: String?) -> String? {
        guard let value, let uuid = UUID(uuidString: value) else { return nil }
        return uuid.uuidString.lowercased()
    }
}

/// Wraps MSAL for Workshop. Constants mirror the web app's `msalConfig` so both
/// clients authenticate against the same Entra app registration and request the
/// same API scope (`api://<clientId>/access_as_user`) — which is what makes the
/// native app share the signed-in user's per-user database with the web app.
/// `@MainActor` keeps all MSAL calls on the main thread (and makes the type
/// implicitly Sendable so ``MSALTokenProvider`` can hold it).
@MainActor
final class MSALAuth {
    // The common authority supports organizational Entra tenants and personal
    // Microsoft accounts through the same Workshop public-client registration.
    static let clientId = "0f303f8f-207f-4b7f-84a5-b5d0abcf49d1"
    static let authorityURL = URL(string: "https://login.microsoftonline.com/common")!
    static let redirectURI = "msauth.com.nintek.workshop://auth"
    static let scopes = ["api://0f303f8f-207f-4b7f-84a5-b5d0abcf49d1/access_as_user"]
    private static let selectedAccountIdentifierKey = "ws.msal.selectedAccountIdentifier"

    private let application: MSALPublicClientApplication
    private var selectedAccountIdentifier: String?

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
        selectedAccountIdentifier = UserDefaults.standard.string(forKey: Self.selectedAccountIdentifierKey)
    }

    var account: MSALAccount? {
        let accounts = (try? application.allAccounts()) ?? []
        if let selectedAccountIdentifier {
            return accounts.first(where: { $0.identifier == selectedAccountIdentifier })
        }
        return accounts.first
    }
    var hasAccount: Bool { account != nil }

    var accountName: String? {
        guard let account else { return nil }
        return (account.accountClaims?["name"] as? String) ?? account.username
    }

    /// The backend identity key used by per-user data and `?oid=` image requests.
    /// Existing Nintek users retain their bare oid; external tenants are namespaced
    /// by tid so identical object ids from two tenants can never share data.
    var userKey: String? {
        EntraIdentity.userKey(
            tenantID: account?.accountClaims?["tid"] as? String,
            objectID: account?.accountClaims?["oid"] as? String
        )
    }

    /// Interactive sign-in via the system web sheet.
    func signInInteractively(presenting viewController: UIViewController) async throws {
        let webParams = MSALWebviewParameters(authPresentationViewController: viewController)
        let params = MSALInteractiveTokenParameters(scopes: Self.scopes, webviewParameters: webParams)
        params.promptType = .selectAccount

        let accountIdentifier = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<String?, Error>) in
            application.acquireToken(with: params) { result, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: result?.account.identifier) }
            }
        }
        selectedAccountIdentifier = accountIdentifier
        UserDefaults.standard.set(accountIdentifier, forKey: Self.selectedAccountIdentifierKey)
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
        for account in try application.allAccounts() {
            try application.remove(account)
        }
        selectedAccountIdentifier = nil
        UserDefaults.standard.removeObject(forKey: Self.selectedAccountIdentifierKey)
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

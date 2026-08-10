import Foundation
import Security
import NintekKit

/// Sign in with Apple for Workshop (native).
///
/// The additive counterpart of the Microsoft flow: Apple's identity token and
/// one-time authorization code are exchanged at `POST /api/auth/apple` for a
/// Workshop session (access + refresh), stored in the Keychain. The backend
/// retains Apple's refresh token so account deletion can revoke it. Every API call
/// then sends the session's access token as its bearer (via
/// ``SessionTokenProvider``), refreshing through `POST /api/auth/refresh` when it
/// nears expiry — Apple id_tokens can't be silently refreshed, so the backend
/// owns the session instead. The backend keys Apple users `apple_<sha256(sub)>`.

// MARK: - Session model + Keychain store

struct AppleSession: Codable, Sendable {
    var accessToken: String
    var refreshToken: String
    var userKey: String       // apple_<sha256(sub)> — the backend's per-user key
    var expiresAt: Date       // when the access token expires
    var displayName: String?  // provider name (Apple sends it once); persisted server-side
}

/// Keychain-backed persistence for the Apple session (survives relaunch).
enum AppleSessionStore {
    private static let service = "com.nintek.workshop.session"
    private static let account = "apple-session"

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func load() -> AppleSession? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data,
              let session = try? JSONDecoder().decode(AppleSession.self, from: data) else { return nil }
        return session
    }

    static func save(_ session: AppleSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        SecItemDelete(baseQuery() as CFDictionary)
        var add = baseQuery()
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func clear() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    static var hasSession: Bool { load() != nil }
}

// MARK: - Token exchange / refresh

enum AppleAuthError: Error { case exchangeFailed, refreshFailed }

private struct AppleTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let userKey: String
    let expiresIn: Int
    let displayName: String?
}

/// Talks to the Workshop backend's Apple auth endpoints. Sendable so it can back
/// a ``TokenProvider``.
struct AppleAuthService: Sendable {
    let baseURL: URL

    /// Exchange Apple's identity token and one-time authorization code for a
    /// Workshop session. The backend exchanges the code for an Apple refresh
    /// token, which it needs to revoke Sign in with Apple when the user deletes
    /// their account (App Store Guideline 5.1.1(v)).
    ///
    /// `name` is only present on the first Apple consent (it isn't in the token);
    /// the backend stores it so later sign-ins / other devices can display it.
    func exchange(idToken: String, authorizationCode: String, name: String?) async throws {
        var body = [
            "id_token": idToken,
            "authorization_code": authorizationCode,
        ]
        if let name, !name.isEmpty { body["name"] = name }
        let session = try await post(path: "api/auth/apple", body: body, failure: .exchangeFailed)
        AppleSessionStore.save(session)
    }

    /// Rotate a session using its refresh token; persists and returns the new one.
    @discardableResult
    func refresh(_ current: AppleSession) async throws -> AppleSession {
        let session = try await post(path: "api/auth/refresh",
                                     body: ["refresh_token": current.refreshToken],
                                     failure: .refreshFailed)
        AppleSessionStore.save(session)
        return session
    }

    private func post(path: String, body: [String: String], failure: AppleAuthError) async throws -> AppleSession {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw failure
        }
        let r = try JSONDecoder().decode(AppleTokenResponse.self, from: data)
        return AppleSession(
            accessToken: r.accessToken,
            refreshToken: r.refreshToken,
            userKey: r.userKey,
            expiresAt: Date().addingTimeInterval(TimeInterval(r.expiresIn)),
            displayName: r.displayName
        )
    }
}

// MARK: - TokenProvider

/// Serializes refreshes so a burst of concurrent requests spends the refresh
/// token once.
///
/// `accessToken()` runs on every API call, and the app fans several out at once
/// (the dashboard's parallel loads, starter seeding). Without coalescing, every
/// request that finds the token expired POSTs the *same* refresh token: a
/// backend that rotates them answers the first and rejects the rest, and each
/// loser clears the Keychain — bouncing the user to the sign-in screen while
/// holding a session that was actually fine.
private actor SessionRefresher {
    static let shared = SessionRefresher()

    private var inFlight: Task<String?, Never>?

    func token(service: AppleAuthService) async -> String? {
        // Another caller may have finished refreshing while this one waited
        // its turn at the actor, in which case there's nothing to do.
        if let current = Self.unexpiredStoredToken() { return current }
        if let inFlight { return await inFlight.value }

        let task = Task<String?, Never> {
            guard let session = AppleSessionStore.load() else { return nil }
            do {
                return try await service.refresh(session).accessToken
            } catch {
                AppleSessionStore.clear()
                return nil
            }
        }
        inFlight = task
        let token = await task.value
        inFlight = nil
        return token
    }

    private static func unexpiredStoredToken() -> String? {
        guard let session = AppleSessionStore.load(),
              Date() < session.expiresAt.addingTimeInterval(-60) else { return nil }
        return session.accessToken
    }
}

/// Supplies the Apple session's access token to NintekKit's `APIClient`,
/// transparently refreshing it within 60s of expiry. Returns nil (and clears the
/// session) if refresh fails, so the app falls back to the sign-in screen.
struct SessionTokenProvider: TokenProvider {
    let service: AppleAuthService

    func accessToken() async throws -> String? {
        guard let session = AppleSessionStore.load() else { return nil }
        // Fast path stays lock-free: only an actual refresh goes through the actor.
        if Date() < session.expiresAt.addingTimeInterval(-60) { return session.accessToken }
        return await SessionRefresher.shared.token(service: service)
    }
}

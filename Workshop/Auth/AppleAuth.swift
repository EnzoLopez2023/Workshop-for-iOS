import Foundation
import Security
import NintekKit

/// Sign in with Apple for Workshop (native).
///
/// The additive counterpart of the Microsoft flow: the Apple identity token from
/// `SignInWithAppleButton` is exchanged once at `POST /api/auth/apple` for a
/// Workshop session (access + refresh), stored in the Keychain. Every API call
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

    /// Exchange an Apple identity token for a Workshop session and persist it.
    /// `name` is only present on the first Apple consent (it isn't in the token);
    /// the backend stores it so later sign-ins / other devices can display it.
    func exchange(idToken: String, name: String?) async throws {
        var body = ["id_token": idToken]
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

/// Supplies the Apple session's access token to NintekKit's `APIClient`,
/// transparently refreshing it within 60s of expiry. Returns nil (and clears the
/// session) if refresh fails, so the app falls back to the sign-in screen.
struct SessionTokenProvider: TokenProvider {
    let service: AppleAuthService

    func accessToken() async throws -> String? {
        guard var session = AppleSessionStore.load() else { return nil }
        if Date() < session.expiresAt.addingTimeInterval(-60) { return session.accessToken }
        do {
            session = try await service.refresh(session)
        } catch {
            AppleSessionStore.clear()
            return nil
        }
        return session.accessToken
    }
}

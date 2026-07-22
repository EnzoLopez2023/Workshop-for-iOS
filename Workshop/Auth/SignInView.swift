import SwiftUI
import AuthenticationServices

/// Sign-in gate. Mirrors the web landing's warm editorial look and offers
/// "Sign in with Microsoft" (Entra) and "Sign in with Apple" — both resolve to
/// the same backend per-user data model. See AppleAuth.swift. There is no demo
/// mode in native.
struct SignInView: View {
    @EnvironmentObject private var model: AppModel
    @State private var signingIn = false

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "hammer.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.accent)
                VStack(spacing: 8) {
                    Eyebrow("Workshop Journal")
                    (Text("Every project. ").foregroundStyle(Theme.ink)
                     + Text("From first cut to final coat.").foregroundStyle(Theme.accent))
                        .font(Theme.display(30))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 32)
                }

                if let err = model.authError {
                    Text(err).font(.footnote).foregroundStyle(Theme.fail)
                        .multilineTextAlignment(.center).padding(.horizontal, 32)
                }

                Spacer()
                VStack(spacing: 12) {
                    Button {
                        Task { await signIn() }
                    } label: {
                        HStack {
                            if signingIn { ProgressView().tint(.white) }
                            Text(signingIn ? "Signing in…" : "Sign in with Microsoft")
                            Image(systemName: "arrow.right")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(Theme.accentDeep, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(signingIn)

                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        Task { await handleApple(result) }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(signingIn)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
            .contentColumn(420)
        }
    }

    private func signIn() async {
        guard let vc = topViewController() else { return }
        signingIn = true
        await model.signInWithMicrosoft(presenting: vc)
        signingIn = false
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let auth):
            let credential = auth.credential as? ASAuthorizationAppleIDCredential
            let idToken = credential?.identityToken.flatMap { String(data: $0, encoding: .utf8) }
            // fullName arrives only on the first consent; format to "First Last".
            let name = credential?.fullName.flatMap { components -> String? in
                let s = PersonNameComponentsFormatter().string(from: components)
                    .trimmingCharacters(in: .whitespaces)
                return s.isEmpty ? nil : s
            }
            signingIn = true
            await model.signInWithApple(idToken: idToken, name: name)   // nil token → model reports the error
            signingIn = false
        case .failure(let error):
            // A user-cancelled sheet isn't an error worth surfacing.
            if let authError = error as? ASAuthorizationError, authError.code == .canceled { return }
            signingIn = true
            await model.signInWithApple(idToken: nil, name: nil)
            signingIn = false
        }
    }
}

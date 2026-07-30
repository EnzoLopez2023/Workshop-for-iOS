import SwiftUI
import AuthenticationServices

/// Sign-in gate. Carries the Concourse Board world — a steel plate above live
/// flaps — and offers
/// "Sign in with Microsoft" (Entra) and "Sign in with Apple" — both resolve to
/// the same backend per-user data model. See AppleAuth.swift. There is no demo
/// mode in native.
struct SignInView: View {
    @EnvironmentObject private var model: AppModel
    @State private var signingIn = false

    var body: some View {
        ZStack {
            Theme.concourse.ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer(minLength: 0)

                // The board announces itself the way a concourse board does —
                // a steel plate above the flaps, not a logo above a tagline.
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.accentFill)
                        Text("THE WORKSHOP")
                            .font(Theme.board(12, .bold, relativeTo: .caption))
                            .tracking(1.6)
                            .foregroundStyle(Theme.onSteel)
                        Spacer(minLength: 0)
                        Text("LIVE")
                            .font(Theme.board(9.5, .bold, relativeTo: .caption2))
                            .tracking(1.2)
                            .foregroundStyle(Theme.accentFill)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.steelFace)

                    VStack(spacing: 10) {
                        SplitFlap("IN PROGRESS", size: 19, tone: .amber)
                        SplitFlap("PLANNING", size: 19)
                        SplitFlap("COMPLETE", size: 19, tone: .green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(Theme.flapShade)

                    Text("Every project, from first cut to final coat.")
                        .font(Theme.ui(13))
                        .foregroundStyle(Theme.onSteel.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(Theme.steelFace)
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.rPanel)
                        .strokeBorder(Theme.line, lineWidth: 1)
                )
                .padding(.horizontal, 28)

                if let err = model.authError {
                    Text(err)
                        .font(Theme.ui(13))
                        .foregroundStyle(Theme.red)
                        .multilineTextAlignment(.center).padding(.horizontal, 32)
                }

                Spacer(minLength: 24)
                Spacer(minLength: 0)
                VStack(spacing: 12) {
                    Button {
                        Task { await signIn() }
                    } label: {
                        HStack(spacing: 8) {
                            if signingIn { ProgressView().tint(Theme.steelDark) }
                            Text(signingIn ? "SIGNING IN…" : "SIGN IN WITH MICROSOFT")
                                .font(Theme.board(12, .bold, relativeTo: .callout))
                                .tracking(1.1)
                        }
                        .foregroundStyle(Theme.steelDark)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(Theme.accentFill)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel))
                    }
                    // Without an explicit style the system dims the whole label
                    // in dark mode, which mutes the one amber action on screen.
                    .buttonStyle(.plain)
                    .disabled(signingIn)

                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        Task { await handleApple(result) }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel))
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

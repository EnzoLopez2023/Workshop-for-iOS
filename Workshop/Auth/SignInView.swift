import SwiftUI
import AuthenticationServices

/// Sign-in gate. Carries the Concourse Board world — a steel plate above live
/// flaps — and offers
/// "Sign in with Microsoft" (Entra) and "Sign in with Apple" — both resolve to
/// the same backend per-user data model. See AppleAuth.swift. There is no demo
/// mode in native.
struct SignInView: View {
    @EnvironmentObject private var model: AppModel
    /// Which provider is mid-flight, so only that plate shows the busy state.
    @State private var signingIn: SignInProvider?
    @State private var appleSignIn = AppleSignInController()

    private var busy: Bool { signingIn != nil }

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
                // The two providers are one pair of plates: same lettering,
                // same metrics, same square corners — only the fill and the
                // mark tell them apart. A system SignInWithAppleButton owns its
                // own type and height, so it can never join that pair; Apple's
                // request is made directly instead and the plate is ours.
                VStack(spacing: 12) {
                    SignInPlate(provider: .microsoft, busy: signingIn == .microsoft) {
                        Task { await signInWithMicrosoft() }
                    }
                    .disabled(busy)

                    SignInPlate(provider: .apple, busy: signingIn == .apple) {
                        startAppleSignIn()
                    }
                    .disabled(busy)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
            .contentColumn(420)
        }
    }

    private func signInWithMicrosoft() async {
        guard let vc = topViewController() else { return }
        signingIn = .microsoft
        await model.signInWithMicrosoft(presenting: vc)
        signingIn = nil
    }

    private func startAppleSignIn() {
        signingIn = .apple
        appleSignIn.start { result in
            Task { await handleApple(result) }
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let auth):
            let credential = auth.credential as? ASAuthorizationAppleIDCredential
            let idToken = credential?.identityToken.flatMap { String(data: $0, encoding: .utf8) }
            let authorizationCode = credential?.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
            // fullName arrives only on the first consent; format to "First Last".
            let name = credential?.fullName.flatMap { components -> String? in
                let s = PersonNameComponentsFormatter().string(from: components)
                    .trimmingCharacters(in: .whitespaces)
                return s.isEmpty ? nil : s
            }
            await model.signInWithApple(
                idToken: idToken,
                authorizationCode: authorizationCode,
                name: name
            )
        case .failure(let error):
            // A user-cancelled sheet isn't an error worth surfacing.
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                signingIn = nil
                return
            }
            await model.signInWithApple(idToken: nil, authorizationCode: nil, name: nil)
        }
        signingIn = nil
    }
}

// MARK: - The plate pair

private enum SignInProvider {
    case microsoft, apple

    /// Board lettering, so both plates speak the concourse's caps. The wording
    /// itself is each provider's required phrase, unchanged.
    var title: String {
        switch self {
        case .microsoft: "SIGN IN WITH MICROSOFT"
        case .apple:     "SIGN IN WITH APPLE"
        }
    }

    /// Amber is this screen's one signal lamp and marks the primary action;
    /// Apple's plate is the ink counterpart, not a second lamp.
    var fill: Color {
        switch self {
        case .microsoft: Theme.accentFill
        case .apple:     Color(uiColor: UIColor(rgb: 0x14181A))
        }
    }

    var foreground: Color {
        switch self {
        case .microsoft: Theme.steelDark
        case .apple:     .white
        }
    }
}

/// One sign-in action as a flap-square plate on the concourse.
private struct SignInPlate: View {
    let provider: SignInProvider
    let busy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if busy {
                    ProgressView().tint(provider.foreground)
                } else {
                    mark
                }
                Text(busy ? "SIGNING IN…" : provider.title)
                    .font(Theme.board(12, .bold, relativeTo: .callout))
                    .tracking(1.1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(provider.foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(provider.fill)
            .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel))
        }
        // Without an explicit style the system dims the whole label in dark
        // mode, which mutes the one amber action on screen.
        .buttonStyle(.plain)
        .accessibilityLabel(provider.title.capitalized)
    }

    @ViewBuilder private var mark: some View {
        switch provider {
        case .microsoft:
            // Microsoft's mark needs a white or dark ground — its yellow square
            // is invisible on amber. A white flap chip gives it one, and reads
            // as board hardware rather than a sticker.
            MicrosoftLogo(size: 13)
                .padding(3)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.rFlap))
        case .apple:
            Image(systemName: "applelogo")
                .font(.system(size: 16))
                // The glyph sits high in its box; nudge it onto the cap line.
                .offset(y: -1)
        }
    }
}

/// The Microsoft mark — four squares, per Microsoft's sign-in button branding.
private struct MicrosoftLogo: View {
    var size: CGFloat = 15
    /// Gutter between the squares, as a share of the mark's width.
    private let gutter: CGFloat = 0.1

    var body: some View {
        VStack(spacing: size * gutter) {
            HStack(spacing: size * gutter) {
                Rectangle().fill(Color(uiColor: UIColor(rgb: 0xF25022)))
                Rectangle().fill(Color(uiColor: UIColor(rgb: 0x7FBA00)))
            }
            HStack(spacing: size * gutter) {
                Rectangle().fill(Color(uiColor: UIColor(rgb: 0x00A4EF)))
                Rectangle().fill(Color(uiColor: UIColor(rgb: 0xFFB900)))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Drives Sign in with Apple from our own plate. `SignInWithAppleButton` bundles
/// the request with an appearance we can't match to the Microsoft plate, so the
/// request is issued here and the button is left to `SignInPlate`.
@MainActor
final class AppleSignInController: NSObject, ASAuthorizationControllerDelegate,
                                   ASAuthorizationControllerPresentationContextProviding {
    private var completion: ((Result<ASAuthorization, Error>) -> Void)?
    /// `ASAuthorizationController` holds its delegate weakly, so the request
    /// keeps us alive for exactly as long as it's in flight.
    private var inFlight: AppleSignInController?

    func start(_ completion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.completion = completion
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        inFlight = self
        controller.performRequests()
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        finish(.success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        finish(.failure(error))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        topViewController()?.view.window ?? ASPresentationAnchor()
    }

    private func finish(_ result: Result<ASAuthorization, Error>) {
        let handler = completion
        completion = nil
        inFlight = nil
        handler?(result)
    }
}

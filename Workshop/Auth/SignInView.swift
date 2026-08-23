import SwiftUI
import AuthenticationServices

/// Sign-in gate over a veiled technical-plan backdrop.
struct SignInView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Which provider is mid-flight, so only that plate shows the busy state.
    @State private var signingIn: SignInProvider?
    @State private var appleSignIn = AppleSignInController()

    private var busy: Bool { signingIn != nil }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                WorkshopLoginBackdrop(
                    reduceMotion: reduceMotion,
                    reduceTransparency: reduceTransparency
                )

                ScrollView {
                    VStack(spacing: 30) {
                        titlePanel

                        if let err = model.authError {
                            Text(err)
                                .font(Theme.ui(13))
                                .foregroundStyle(Theme.danger)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 460)
                        }

                        VStack(spacing: 12) {
                            SignInPlate(style: .microsoft, busy: signingIn == .microsoft) {
                                Task { await signInWithMicrosoft() }
                            }
                            .disabled(busy)

                            AppleSignInPlate(busy: signingIn == .apple) {
                                startAppleSignIn()
                            }
                            .disabled(busy)

                            Text(WorkshopAccountCopy.signInDisclosure)
                                .font(.footnote)
                                .foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 4)
                                .accessibilityIdentifier("provider-scope-disclosure")

                            SignInPlate(style: .demo, busy: false) {
                                model.enterDemo()
                            }
                            .disabled(busy)
                            .accessibilityHint("Opens seven complete starter projects without signing in")

                            Text("Demo is read-only · No account required")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                                .padding(.top, 4)
                        }
                        .frame(maxWidth: 460)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
                    .padding(.horizontal, 20)
                    .padding(.vertical, max(26, (proxy.size.height - 570) / 2))
                }
            }
        }
    }

    private var titlePanel: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 12) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.action)
                    .frame(width: 44, height: 44)
                    .background(
                        Theme.tint(Theme.annotation),
                        in: RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                    )
                Text("Workshop")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Keep the whole build connected.")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Every project, from first sketch to final coat.")
                    .font(.title3)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            stageTrack
        }
        .frame(maxWidth: 660)
        .padding(28)
        .planGlass()
    }

    @ViewBuilder private var stageTrack: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    stage("Idea", complete: true)
                    stage("Plan", complete: true)
                }
                HStack(spacing: 8) {
                    stage("Build", complete: false)
                    stage("Finish", complete: false)
                }
            }
        } else {
            HStack(spacing: 8) {
                stage("Idea", complete: true)
                connector(complete: true)
                stage("Plan", complete: true)
                connector(complete: false)
                stage("Build", complete: false)
                connector(complete: false)
                stage("Finish", complete: false)
            }
        }
    }

    private func stage(_ label: String, complete: Bool) -> some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(complete ? .white : Theme.muted)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(complete ? Theme.action : Theme.recessed, in: Capsule())
            .accessibilityLabel("\(label), \(complete ? "complete" : "upcoming")")
    }

    private func connector(complete: Bool) -> some View {
        Capsule()
            .fill(complete ? Theme.action : Theme.divider)
            .frame(maxWidth: .infinity)
            .frame(height: 2)
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
}

private enum SignInPlateStyle {
    case microsoft, demo

    var title: String {
        switch self {
        case .microsoft: "Sign in with Microsoft"
        case .demo:      "Browse Demo"
        }
    }

    var fill: Color {
        switch self {
        case .microsoft: Color(uiColor: UIColor(rgb: 0x2F2F2F))
        case .demo:      Theme.raised
        }
    }

    var foreground: Color {
        switch self {
        case .microsoft: .white
        case .demo:      Theme.ink
        }
    }
}

/// One sign-in action using native continuous geometry.
private struct SignInPlate: View {
    let style: SignInPlateStyle
    let busy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if busy {
                    ProgressView().tint(style.foreground)
                } else {
                    mark
                }
                Text(busy ? "Signing in…" : style.title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(style.foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(style.fill)
            .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous)
                    .strokeBorder(
                        style == .demo ? Theme.divider.opacity(0.7) : .clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.title)
    }

    @ViewBuilder private var mark: some View {
        switch style {
        case .microsoft:
            MicrosoftLogo(size: 13)
                .padding(3)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        case .demo:
            Image(systemName: "eye.fill")
                .font(.system(size: 15, weight: .semibold))
        }
    }
}

private struct AppleSignInPlate: View {
    let busy: Bool
    let action: () -> Void

    var body: some View {
        ZStack {
            SystemAppleSignInButton(action: action)
            if busy {
                Color.black.opacity(0.72)
                ProgressView().tint(.white)
            }
        }
        .frame(height: 52)
        .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel, style: .continuous))
        .accessibilityLabel("Sign in with Apple")
        .accessibilityValue(busy ? "In progress" : "")
    }
}

private struct SystemAppleSignInButton: UIViewRepresentable {
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.cornerRadius = Theme.rPanel
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.didTap),
            for: .touchUpInside
        )
        return button
    }

    func updateUIView(_ button: ASAuthorizationAppleIDButton, context: Context) {
        context.coordinator.action = action
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func didTap() {
            action()
        }
    }
}

private struct WorkshopLoginBackdrop: View {
    let reduceMotion: Bool
    let reduceTransparency: Bool
    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Theme.navigationMaterial
                if let file = Bundle.main.url(
                    forResource: "plan-hand-tool-cabinet",
                    withExtension: "png"
                ), let image = UIImage(contentsOfFile: file.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width + 100, height: proxy.size.height + 100)
                        .scaleEffect(drift ? 1.1 : 1.02)
                        .offset(x: drift ? -24 : 22, y: drift ? -16 : 18)
                        .saturation(0.28)
                        .contrast(1.15)
                        .opacity(0.78)
                        .clipped()
                }

                LinearGradient(
                    colors: [
                        Theme.canvas.opacity(reduceTransparency ? 0.96 : 0.82),
                        Theme.canvas.opacity(reduceTransparency ? 0.90 : 0.66),
                        Theme.canvas.opacity(reduceTransparency ? 0.96 : 0.86),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        Theme.canvas.opacity(reduceTransparency ? 0.08 : 0.02),
                        Theme.canvas.opacity(reduceTransparency ? 0.78 : 0.50),
                    ],
                    center: .center,
                    startRadius: 40,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.7
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) {
                drift = true
            }
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

/// Drives the authorization request started by the system Apple sign-in button.
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

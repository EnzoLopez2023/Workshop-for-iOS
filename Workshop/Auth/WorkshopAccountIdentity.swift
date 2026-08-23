import Foundation

enum WorkshopAccountProvider: String, CaseIterable, Sendable {
    case apple
    case microsoft

    var displayName: String {
        switch self {
        case .apple: "Apple"
        case .microsoft: "Microsoft"
        }
    }

    var underlyingAccountName: String {
        switch self {
        case .apple: "Apple Account"
        case .microsoft: "Microsoft account"
        }
    }

    var other: WorkshopAccountProvider {
        switch self {
        case .apple: .microsoft
        case .microsoft: .apple
        }
    }
}

enum WorkshopAccountCopy {
    static let signInDisclosure = """
    Apple and Microsoft create separate Workshop workspaces. Use the same sign-in each time to return to your projects. Apple and Microsoft workspaces are not linked or merged automatically.
    """

    static func workspaceDisclosure(for provider: WorkshopAccountProvider) -> String {
        "This \(provider.displayName) sign-in opens its own Workshop workspace. Apple and Microsoft workspaces are separate and are not linked or merged."
    }

    static func deletionFooter(for provider: WorkshopAccountProvider) -> String {
        "Delete Account permanently removes only this \(provider.displayName)-backed Workshop account and its workspace data, including projects, photos, lists, and uploads. Your \(provider.underlyingAccountName) and any \(provider.other.displayName)-backed Workshop workspace are not affected."
    }

    static func deletionConfirmation(for provider: WorkshopAccountProvider) -> String {
        "Deletes only this \(provider.displayName) Workshop workspace and its data. Your \(provider.underlyingAccountName) and \(provider.other.displayName) Workshop workspace are unaffected. Signing in with \(provider.displayName) again starts a new workspace with starter projects; deleted content does not return. This cannot be undone."
    }

    static let unknownDeletionFooter = """
    Delete Account permanently removes only the currently signed-in Workshop account and its workspace data. A Workshop workspace created with another sign-in provider is not affected.
    """

    static let unknownDeletionConfirmation = """
    Deletes only the currently signed-in Workshop workspace and its data. A workspace created with another sign-in provider is unaffected. Signing in with this provider again starts a new workspace with starter projects; deleted content does not return. This cannot be undone.
    """
}

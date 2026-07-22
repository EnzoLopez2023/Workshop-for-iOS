import UIKit

/// Finds the currently-presented view controller to anchor MSAL's sign-in sheet
/// to. SwiftUI has no direct handle to a UIViewController, so we walk the active
/// window scene's hierarchy.
@MainActor
func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive }
        ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first

    var top = scene?.keyWindow?.rootViewController
        ?? scene?.windows.first?.rootViewController
    while let presented = top?.presentedViewController {
        top = presented
    }
    return top
}

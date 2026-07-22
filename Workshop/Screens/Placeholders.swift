import SwiftUI
import NintekKit

// Remaining placeholder screens. Phase 2 replaces each with the real port:
//  • ShoppingView       → Phase 2.4
//  • ConversionTablesView → Phase 2.5 (pure Swift)
// MoreView is functional (accent + sign out + version); Phase 5 expands Settings.

struct ShoppingView: View {
    let api: WorkshopAPI
    var body: some View { PlaceholderScreen(title: "Shopping", symbol: "cart.fill", phase: "Phase 2.4") }
}

struct ConversionTablesView: View {
    var body: some View { PlaceholderScreen(title: "Tables", symbol: "ruler.fill", phase: "Phase 2.5") }
}

struct MoreView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Accent", selection: Binding(
                        get: { theme.selection },
                        set: { theme.selection = $0 }
                    )) {
                        ForEach(Palette.all) { p in Text(p.name).tag(p.id) }
                    }
                }
                Section("Account") {
                    if let name = model.userName {
                        LabeledContent("Signed in as", value: name)
                    }
                    Button("Sign Out", role: .destructive) { model.signOut() }
                }
                Section {
                    LabeledContent("Version", value: AppInfo.version)
                }
            }
            .navigationTitle("More")
        }
    }
}

/// Generic "coming in a later phase" placeholder body.
private struct PlaceholderScreen: View {
    let title: String
    let symbol: String
    let phase: String
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 44)).foregroundStyle(Theme.accent)
                Text(title).font(Theme.display(24)).foregroundStyle(Theme.ink)
                Text("Coming in \(phase)").font(.subheadline).foregroundStyle(Theme.subtle)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .creamBackground()
            .navigationTitle(title)
        }
    }
}

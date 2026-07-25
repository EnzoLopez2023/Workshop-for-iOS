import SwiftUI
import NintekKit

/// Settings tab: accent picker, signed-in identity + sign out, version footer.
/// Phase 5 expands this to match the web's full Settings.tsx (text size,
/// default project status, dashboard sort, show-completed, exports).
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

import SwiftUI

// Phase 0 placeholder entry point. Phase 1 replaces this with the real
// AppModel-driven RootView (dual auth, theme, shell). Kept minimal so the
// re-scaffolded target compiles and archives from day one.
@main
struct WorkshopApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Workshop")
                .font(.largeTitle.weight(.semibold))
            Text("Native port — Phase 0 scaffold")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

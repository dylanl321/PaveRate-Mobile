import SwiftUI

@main
struct PaveRateApp: App {
    @State private var model = AppModel.load()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let palette = FieldPalette.palette(for: model.appearance)
        TabView {
            NavigationStack {
                ToolListView()
            }
            .tabItem {
                Label("Calculators", systemImage: "plus.forwardslash.minus")
            }

            NavigationStack {
                JobSetupView()
            }
            .tabItem {
                Label("Job", systemImage: "road.lanes")
            }
        }
        .environment(\.fieldPalette, palette)
        .preferredColorScheme(model.appearance == .night ? .dark : .light)
        .tint(palette.accentText)
    }
}

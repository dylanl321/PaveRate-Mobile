import SwiftUI

@main
struct PaveRateApp: App {
    @State private var model = AppModel.load()
    @State private var location = FieldLocation()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(location)
                .task { WatchBridge.shared.start() }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let palette = FieldPalette.palette(for: model.appearance)
        TabView {
            NavigationStack {
                TodayView()
            }
            .tabItem {
                Label("Today", systemImage: "sun.max.fill")
            }

            NavigationStack {
                ToolListView()
            }
            .tabItem {
                Label("Calc", systemImage: "plus.forwardslash.minus")
            }

            NavigationStack {
                MapRunView()
            }
            .tabItem {
                Label("Map", systemImage: "map")
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
        .tint(palette.text)
    }
}

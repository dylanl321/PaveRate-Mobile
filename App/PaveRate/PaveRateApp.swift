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
    @AppStorage(FieldDensity.storageKey) private var densityRaw = ""

    private var density: FieldDensity {
        FieldDensity(rawValue: densityRaw) ?? .field
    }

    var body: some View {
        let palette = FieldPalette.palette(for: model.appearance, density: density)
        Group {
            if FieldDensity(rawValue: densityRaw) == nil {
                DensityGate { densityRaw = $0.rawValue }
            } else {
                tabs
            }
        }
        .environment(\.fieldPalette, palette)
        .preferredColorScheme(model.appearance == .night ? .dark : .light)
        .tint(palette.text)
        .installKeyboardDismiss()
    }

    private var tabs: some View {
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
    }
}

struct DensityGate: View {
    var choose: (FieldDensity) -> Void

    @Environment(\.fieldPalette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: palette.stackSpacing) {
                Text("How big should the controls be?")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Field is for gloves and sun. Compact fits more on the screen. You can change this in Settings. Sunlight, Glare, and Night stay available either way.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                ChoiceButton(
                    title: "Field",
                    subtitle: FieldDensity.field.detail,
                    selected: true
                ) {
                    choose(.field)
                }
                ChoiceButton(
                    title: "Compact",
                    subtitle: FieldDensity.compact.detail,
                    selected: false
                ) {
                    choose(.compact)
                }
            }
            .padding(palette.pagePadding)
        }
        .background(palette.background.ignoresSafeArea())
    }
}

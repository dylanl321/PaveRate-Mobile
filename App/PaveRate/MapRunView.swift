import MapKit
import SwiftUI
import PaveRateCore

struct MapRunView: View {
    @Environment(AppModel.self) private var model
    @Environment(FieldLocation.self) private var location
    @Environment(\.fieldPalette) private var palette

    @State private var camera: MapCameraPosition = .automatic
    @State private var center = CLLocationCoordinate2D(latitude: 32.9, longitude: -83.4)
    @State private var tracking = false
    @State private var showRoutes = false
    @State private var confirmClear = false

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            map
            sheet
        }
        .navigationTitle("Map")
        .background(palette.background.ignoresSafeArea())
        .onAppear {
            location.requestAndStart()
            centerOnExisting()
        }
        .onChange(of: location.coordinate?.latitude) { _, _ in
            guard tracking, let point = location.coordinate else { return }
            model.appendTrack(point, accuracyMeters: location.horizontalAccuracyM)
            if model.pavedPoints.count >= GeoMeasure.maxTrackPoints {
                tracking = false
            }
        }
        .onChange(of: tracking) { _, isOn in
            if isOn {
                model.drawMode = .paved
                location.requestAndStart()
            }
        }
        .sheet(isPresented: $showRoutes) {
            RouteSearchSheet { route in
                model.savedRoute = SavedRoute(
                    routeID: route.routeID,
                    name: route.name,
                    county: route.county,
                    lines: route.lines
                )
                if let first = route.lines.first?.first {
                    camera = .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude),
                        latitudinalMeters: 4000,
                        longitudinalMeters: 4000
                    ))
                }
            }
        }
        .confirmationDialog("Clear this line?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive) {
                model.clearActiveLine()
                FieldHaptics.tap()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(model.drawMode == .plan ? "Clears the plan. The paved track stays." : "Clears the paved track. The plan stays.")
        }
    }

    private var map: some View {
        MapReader { proxy in
            Map(position: $camera) {
                UserAnnotation()
                if let route = model.savedRoute {
                    ForEach(Array(route.lines.enumerated()), id: \.offset) { _, line in
                        MapPolyline(coordinates: coordinates(line))
                            .stroke(.blue, lineWidth: 4)
                    }
                }
                if model.plannedPoints.count >= 2 {
                    MapPolyline(coordinates: coordinates(model.plannedPoints))
                        .stroke(palette.text, lineWidth: 6)
                    let run = model.runMeasure
                    if run.plannedFeet > 0, run.pavedFeet > 0 {
                        MapPolyline(coordinates: coordinates(GeoMeasure.prefix(
                            points: model.plannedPoints,
                            feet: min(run.pavedFeet, run.plannedFeet)
                        )))
                        .stroke(palette.good, lineWidth: 8)
                    }
                }
                if model.pavedPoints.count >= 2 {
                    MapPolyline(coordinates: coordinates(model.pavedPoints))
                        .stroke(palette.good, lineWidth: 5)
                }
                if let head = headPoint {
                    Annotation("Paved", coordinate: CLLocationCoordinate2D(latitude: head.latitude, longitude: head.longitude)) {
                        Circle()
                            .fill(palette.good)
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                    }
                }
            }
            .mapStyle(.hybrid)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .onTapGesture { screen in
                guard let coord = proxy.convert(screen, from: .local) else { return }
                model.dropPoint(GeoPoint(latitude: coord.latitude, longitude: coord.longitude))
                FieldHaptics.tap()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                center = context.camera.centerCoordinate
            }
            .overlay {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.black)
                    .shadow(color: .white, radius: 2)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var sheet: some View {
        let run = model.runMeasure
        return VStack(alignment: .leading, spacing: 8) {
            Text(run.lengthForCalcs > 0 ? model.settings.lengthHeadline(feet: run.lengthForCalcs) : "—")
                .outdoorFont(48)
                .foregroundStyle(palette.text)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .accessibilityLabel(run.lengthForCalcs > 0 ? model.settings.lengthHeadline(feet: run.lengthForCalcs) : "No length yet")
            Text(lengthCaption(run))
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.text)
            if run.plannedFeet > 0, run.pavedFeet > 0 {
                ProgressView(value: min(max(run.fraction, 0), 1))
                    .tint(run.overrun ? palette.warn : palette.good)
            }
            ScrollView {
                VStack(spacing: 10) {
                    Picker("Line", selection: $model.drawMode) {
                        Text("Plan").tag(RunDrawMode.plan)
                        Text("Paved").tag(RunDrawMode.paved)
                    }
                    .pickerStyle(.segmented)
                    .frame(minHeight: 44)

                    Button("Drop point") {
                        model.dropPoint(GeoPoint(latitude: center.latitude, longitude: center.longitude))
                        FieldHaptics.tap()
                    }
                    .buttonStyle(FieldPrimaryButtonStyle())

                    Button(tracking ? "Stop tracking" : "Track") {
                        tracking.toggle()
                        FieldHaptics.tap()
                    }
                    .buttonStyle(FieldSecondaryButtonStyle())

                    Button("Use this length") {
                        model.applyRunLengthToJob()
                        FieldHaptics.success()
                    }
                    .buttonStyle(FieldPrimaryButtonStyle())
                    .disabled(run.lengthForCalcs <= 0)

                    HStack(spacing: 10) {
                        Button("Undo point") {
                            model.undoPoint()
                            FieldHaptics.tap()
                        }
                        .buttonStyle(FieldSecondaryButtonStyle())
                        Button("Route") { showRoutes = true }
                            .buttonStyle(FieldSecondaryButtonStyle())
                    }

                    if let route = model.savedRoute {
                        Text("\(route.routeID) · \(route.county) · \(FieldFormat.fixed(GeoMeasure.miles(feet: routeLength(route)), digits: 1)) mi centerline")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(palette.text)
                        Button("Use centerline length · \(FieldFormat.groupedRound(routeLength(route))) ft") {
                            model.applyLength(routeLength(route))
                            FieldHaptics.tap()
                        }
                        .buttonStyle(FieldSecondaryButtonStyle())
                    }

                    Button("Clear line") { confirmClear = true }
                        .buttonStyle(FieldSecondaryButtonStyle())
                }
            }
            .frame(maxHeight: 320)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(palette.background)
    }

    private var headPoint: GeoPoint? {
        let run = model.runMeasure
        guard run.plannedFeet > 0, run.pavedFeet > 0 else { return nil }
        return GeoMeasure.pointAlong(points: model.plannedPoints, feet: min(run.pavedFeet, run.plannedFeet))
    }

    private func lengthCaption(_ run: RunMeasure) -> String {
        if run.lengthForCalcs <= 0 {
            return "Line the crosshair up and drop a point. Or track the run."
        }
        let station = GeoMeasure.stationLabel(feet: run.lengthForCalcs)
        let area = run.plannedAreaSqYd > 0 ? run.plannedAreaSqYd : run.pavedAreaSqYd
        var text = "\(station) · \(FieldFormat.groupedRound(area)) SY at \(displayNumber(model.job.widthFt)) ft"
        if run.plannedFeet > 0, run.pavedFeet > 0 {
            text += " · \(FieldFormat.groupedRound(run.remainingFeet)) ft left"
        }
        if run.overrun {
            text += " · track is longer than the plan"
        }
        return text
    }

    private func routeLength(_ route: SavedRoute) -> Double {
        route.lines.reduce(0) { $0 + GeoMeasure.polylineFeet($1) }
    }

    private func coordinates(_ points: [GeoPoint]) -> [CLLocationCoordinate2D] {
        points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private func centerOnExisting() {
        let point = model.plannedPoints.first ?? model.pavedPoints.first ?? location.coordinate
        guard let point else { return }
        let coordinate = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
        center = coordinate
        camera = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 800, longitudinalMeters: 800))
    }
}

private struct RouteSearchSheet: View {
    var onPick: (GdotRoute) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.fieldPalette) private var palette
    @State private var query = ""
    @State private var routes: [GdotRoute] = []
    @State private var message = "Search a route, like SR 20. This is the centerline, not a milepost."
    @State private var searching = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    BigNumberField(label: "Route", hint: "Road name or route id.", unit: "", numeric: false, text: $query)
                    Button(searching ? "Searching…" : "Search GDOT") {
                        Task { await search() }
                    }
                    .buttonStyle(FieldPrimaryButtonStyle())
                    .disabled(searching)
                    Text(message)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.text)
                    ForEach(routes) { route in
                        Button {
                            onPick(route)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(route.routeID)
                                    .font(.title3.weight(.bold))
                                Text("\(route.name) · \(route.county)")
                                    .font(.body.weight(.semibold))
                                Text("\(FieldFormat.fixed(GeoMeasure.miles(feet: route.lengthFeet), digits: 1)) mi of centerline")
                                    .font(.body.weight(.semibold))
                            }
                            .foregroundStyle(palette.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .frame(minHeight: 88)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.border, lineWidth: palette.borderWidth))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .navigationTitle("GDOT route")
            .background(palette.background.ignoresSafeArea())
            .fieldKeyboardDone()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(.title3.weight(.bold))
                }
            }
        }
    }

    private func search() async {
        searching = true
        defer { searching = false }
        do {
            let found = try await RouteLookup.search(query: query)
            routes = found
            message = found.isEmpty ? "No match. The line you drew is still on the map." : "Pick the county. Check the length before you use it."
        } catch {
            routes = []
            message = "GDOT didn't answer. The line you drew is still on the map."
        }
    }
}

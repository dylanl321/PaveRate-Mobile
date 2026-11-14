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
    @State private var road = RoadSession()
    @State private var lengthText = ""
    @State private var endFocused = false

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            map
                .frame(minHeight: endFocused ? 56 : 180)
                .frame(maxHeight: endFocused ? 56 : .infinity)
            sheet
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .background(palette.background.ignoresSafeArea())
        .fieldKeyboardDone()
        .onAppear {
            location.requestAndStart()
            centerOnExisting()
            if road.endFeet > 0, lengthText.isEmpty {
                lengthText = displayNumber(road.endFeet)
            }
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
        .onChange(of: road.endFeet) { _, feet in
            commitRoad()
            guard !endFocused else { return }
            let shown = feet > 0 ? displayNumber(feet) : ""
            if lengthText != shown { lengthText = shown }
        }
        .onChange(of: road.choice?.id) { _, _ in commitRoad() }
        .onChange(of: road.phase) { _, phase in
            if phase != .along { endFocused = false }
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
                        let coords = coordinates(line)
                        MapPolyline(coordinates: coords)
                            .stroke(.black, lineWidth: 8)
                        MapPolyline(coordinates: coords)
                            .stroke(.blue, lineWidth: 4)
                    }
                }
                if model.plannedPoints.count >= 2 {
                    let plan = coordinates(model.plannedPoints)
                    MapPolyline(coordinates: plan)
                        .stroke(.black, lineWidth: 10)
                    MapPolyline(coordinates: plan)
                        .stroke(.white, lineWidth: 6)
                    let run = model.runMeasure
                    if run.plannedFeet > 0, run.pavedFeet > 0 {
                        let paved = coordinates(GeoMeasure.prefix(
                            points: model.plannedPoints,
                            feet: min(run.pavedFeet, run.plannedFeet)
                        ))
                        MapPolyline(coordinates: paved)
                            .stroke(.black, lineWidth: 12)
                        MapPolyline(coordinates: paved)
                            .stroke(palette.good, lineWidth: 8)
                    }
                }
                if model.pavedPoints.count >= 2 {
                    let paved = coordinates(model.pavedPoints)
                    MapPolyline(coordinates: paved)
                        .stroke(.black, lineWidth: 9)
                    MapPolyline(coordinates: paved)
                        .stroke(palette.good, lineWidth: 5)
                }
                ForEach(road.mileposts) { marker in
                    Annotation(marker.label, coordinate: CLLocationCoordinate2D(latitude: marker.point.latitude, longitude: marker.point.longitude)) {
                        Text(marker.label)
                            .font(.system(size: palette.tagPoints, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.blue, in: Capsule())
                            .overlay(Capsule().stroke(.black, lineWidth: 1))
                    }
                }
                ForEach(road.markers) { marker in
                    Annotation(marker.label, coordinate: CLLocationCoordinate2D(latitude: marker.point.latitude, longitude: marker.point.longitude)) {
                        Text(marker.label)
                            .font(.system(size: palette.tagPoints, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.white, in: Capsule())
                            .overlay(Capsule().stroke(.black, lineWidth: 1))
                    }
                }
                if road.phase == .along, let end = road.planned.last {
                    Annotation("End", coordinate: CLLocationCoordinate2D(latitude: end.latitude, longitude: end.longitude)) {
                        Circle()
                            .fill(palette.accent)
                            .frame(width: 28, height: 28)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .overlay(Circle().stroke(.black, lineWidth: 1))
                            .accessibilityLabel("End of the run")
                    }
                }
                if let head = headPoint {
                    Annotation("Paved", coordinate: CLLocationCoordinate2D(latitude: head.latitude, longitude: head.longitude)) {
                        Circle()
                            .fill(palette.good)
                            .frame(width: 24, height: 24)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .overlay(Circle().stroke(.black, lineWidth: 1))
                            .accessibilityLabel("Paved so far")
                    }
                }
            }
            .mapStyle(.hybrid)
            .tint(Color(red: 0.0, green: 0.35, blue: 0.75))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .onTapGesture { screen in
                FieldKeyboard.dismiss()
                guard let coord = proxy.convert(screen, from: .local) else { return }
                let point = GeoPoint(latitude: coord.latitude, longitude: coord.longitude)
                if road.phase == .manual {
                    model.dropPoint(point)
                } else {
                    Task { await road.handleTap(point) }
                }
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
                    .accessibilityHidden(true)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var sheet: some View {
        @Bindable var model = model
        @Bindable var road = road
        let run = model.runMeasure
        return VStack(alignment: .leading, spacing: palette.tightSpacing) {
            if !endFocused {
                Text(run.lengthForCalcs > 0 ? model.settings.lengthHeadline(feet: run.lengthForCalcs) : "—")
                    .outdoorFont(48)
                    .foregroundStyle(palette.text)
                    .minimumScaleFactor(0.35)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(run.lengthForCalcs > 0 ? model.settings.lengthHeadline(feet: run.lengthForCalcs) : "No length yet")
                Text(lengthCaption(run))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                if run.plannedFeet > 0, run.pavedFeet > 0 {
                    ProgressView(value: min(max(run.fraction, 0), 1))
                        .tint(run.overrun ? palette.warn : palette.good)
                        .accessibilityLabel(run.overrun ? "Tracked line is past the plan" : "Plan progress")
                        .accessibilityValue("\(FieldFormat.groupedRound(run.remainingFeet)) feet left")
                }
            }
            ScrollView {
                VStack(spacing: palette.tightSpacing) {
                    roadControls
                    if !endFocused {
                        FieldSegmented(
                            label: "Line",
                            options: [RunDrawMode.plan, .paved],
                            title: lineTitle,
                            selection: $model.drawMode
                        )

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

                        Button("Use this length in calculators") {
                            model.applyRunLengthToJob()
                            FieldHaptics.success()
                        }
                        .buttonStyle(FieldPrimaryButtonStyle())
                        .disabled(run.lengthForCalcs <= 0)
                        .accessibilityHint("Fills length on spread rate, feet left, tonnage, and tack.")

                        HStack(spacing: palette.tightSpacing) {
                            Button("Undo point") {
                                model.undoPoint()
                                FieldHaptics.tap()
                            }
                            .buttonStyle(FieldSecondaryButtonStyle())
                            Button("Find route") { showRoutes = true }
                                .buttonStyle(FieldSecondaryButtonStyle())
                                .accessibilityHint("Searches the GDOT centerline. It is not applied until you use the length.")
                        }

                        if let route = model.savedRoute {
                            Text("\(route.routeID) · \(route.county) · \(FieldFormat.fixed(GeoMeasure.miles(feet: routeLength(route)), digits: 1)) mi centerline")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(palette.text)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Use centerline length · \(FieldFormat.groupedRound(routeLength(route))) ft") {
                                model.applyLength(routeLength(route))
                                FieldHaptics.tap()
                            }
                            .buttonStyle(FieldSecondaryButtonStyle())
                        }

                        Button("Clear line") { confirmClear = true }
                            .buttonStyle(FieldSecondaryButtonStyle(destructive: true))
                    }
                }
            }
            .fieldScroll()
            .frame(maxHeight: endFocused ? .infinity : 320)
        }
        .padding(.horizontal, palette.pagePadding)
        .padding(.top, palette.tightSpacing)
        .padding(.bottom, palette.tightSpacing)
        .background(palette.background)
    }

    private var roadControls: some View {
        @Bindable var road = road
        return VStack(alignment: .leading, spacing: palette.tightSpacing) {
            Text(road.message)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
            switch road.phase {
            case .start:
                Button("Start here") {
                    Task { await road.begin(at: GeoPoint(latitude: center.latitude, longitude: center.longitude)) }
                }
                .buttonStyle(FieldPrimaryButtonStyle())
                Button("Start at GPS") {
                    guard let point = location.coordinate else {
                        location.requestAndStart()
                        road.message = "Waiting for GPS."
                        return
                    }
                    Task { await road.begin(at: point) }
                }
                .buttonStyle(FieldSecondaryButtonStyle())
            case .loading:
                Text("Finding the road…")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.text)
            case .choose:
                if let trace = road.trace {
                    ForEach(trace.directions) { choice in
                        Button("\(directionArrow(choice.heading)) \(choice.heading) on \(choice.name) · \(FieldFormat.groupedRound(choice.lengthFeet)) ft") {
                            road.pick(choice)
                            FieldHaptics.tap()
                        }
                        .buttonStyle(FieldPrimaryButtonStyle())
                    }
                }
            case .along:
                if let choice = road.choice {
                    Text("\(choice.name) · \(GeoMeasure.stationLabel(feet: road.endFeet)) · \(FieldFormat.groupedRound(GeoMeasure.areaSquareYards(lengthFt: road.endFeet, widthFt: model.job.widthFt))) SY")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .modifier(Collapsed(on: endFocused))
                    Slider(value: $road.endFeet, in: 0...max(choice.lengthFeet, 1))
                        .frame(minHeight: palette.sliderMin)
                        .accessibilityLabel("End along the road")
                        .accessibilityValue("\(FieldFormat.groupedRound(road.endFeet)) feet")
                        .modifier(Collapsed(on: endFocused))
                    BigNumberField(
                        label: "End at",
                        hint: "Feet from the start, along the road. Done saves it and closes the keypad.",
                        unit: "ft",
                        text: $lengthText,
                        onFocusChange: { endFocused = $0 }
                    ) {
                        applyTypedEnd(maxFeet: choice.lengthFeet)
                    }
                    Button("Set end at this length") {
                        applyTypedEnd(maxFeet: choice.lengthFeet)
                        FieldKeyboard.dismiss()
                    }
                    .buttonStyle(FieldPrimaryButtonStyle())
                    VStack(spacing: palette.tightSpacing) {
                        ForEach(choice.forks) { fork in
                            Button("Turn \(fork.heading) onto \(fork.name)") {
                                road.takeFork(fork)
                                FieldHaptics.tap()
                            }
                            .buttonStyle(FieldSecondaryButtonStyle())
                        }
                    }
                    .modifier(Collapsed(on: endFocused))
                }
            case .manual:
                EmptyView()
            }
            Group {
                if road.phase != .manual {
                    Button("Drop points instead") {
                        road.useManual()
                    }
                    .buttonStyle(FieldSecondaryButtonStyle())
                } else {
                    Button("Follow the road") {
                        road.phase = .start
                        road.message = "Drop a start on the road, or use the phone's GPS."
                    }
                    .buttonStyle(FieldSecondaryButtonStyle())
                }
            }
            .modifier(Collapsed(on: endFocused))
        }
    }

    private func applyTypedEnd(maxFeet: Double) {
        guard let feet = parseField(lengthText) else { return }
        endFocused = false
        road.endFeet = min(max(0, feet), maxFeet)
        let shown = displayNumber(road.endFeet)
        if lengthText != shown { lengthText = shown }
        FieldHaptics.tap()
    }

    private func commitRoad() {
        let points = road.planned
        guard points.count >= 2 else { return }
        model.plannedPoints = points
        model.drawMode = .plan
    }

    private var headPoint: GeoPoint? {
        let run = model.runMeasure
        guard run.plannedFeet > 0, run.pavedFeet > 0 else { return nil }
        return GeoMeasure.pointAlong(points: model.plannedPoints, feet: min(run.pavedFeet, run.plannedFeet))
    }

    private func lengthCaption(_ run: RunMeasure) -> String {
        if run.lengthForCalcs <= 0 {
            if road.phase == .manual {
                return "Line the crosshair up and drop a point. Or track the run."
            }
            return "Start on the road, pick a direction, then set the end."
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

    private func lineTitle(_ mode: RunDrawMode) -> String {
        switch mode {
        case .plan: return "Plan"
        case .paved: return "Paved"
        }
    }

    private func directionArrow(_ heading: String) -> String {
        switch heading {
        case "N": return "↑"
        case "NE": return "↗"
        case "E": return "→"
        case "SE": return "↘"
        case "S": return "↓"
        case "SW": return "↙"
        case "W": return "←"
        case "NW": return "↖"
        default: return "→"
        }
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

private struct Collapsed: ViewModifier {
    var on: Bool

    func body(content: Content) -> some View {
        content
            .frame(height: on ? 0 : nil, alignment: .top)
            .clipped()
            .opacity(on ? 0 : 1)
            .accessibilityHidden(on)
            .allowsHitTesting(!on)
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
                VStack(alignment: .leading, spacing: palette.stackSpacing) {
                    BigNumberField(
                        label: "Route",
                        hint: "Road name or route id.",
                        unit: "",
                        numeric: false,
                        placeholder: "SR 20",
                        text: $query
                    )
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
                            .padding(palette.cardPadding)
                            .frame(minHeight: 88)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: palette.cornerRadius))
                            .overlay(RoundedRectangle(cornerRadius: palette.cornerRadius).stroke(palette.border, lineWidth: palette.borderWidth))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(palette.pagePadding)
            }
            .fieldScroll()
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

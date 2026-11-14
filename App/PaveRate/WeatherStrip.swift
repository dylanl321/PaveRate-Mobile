import SwiftUI
import UIKit
import PaveRateCore

struct WeatherStrip: View {
    var showsTimeline: Bool = true
    /// Only the first screen asks for a fresh reading, and only after the cached numbers are on screen.
    var autoRefresh: Bool = false

    @Environment(AppModel.self) private var model
    @Environment(FieldLocation.self) private var location
    @Environment(\.fieldPalette) private var palette
    @State private var pulling = false
    @State private var failed = false

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 14) {
            if let reading = model.cachedWeather, let decision = model.weatherDecision {
                StatusBanner(kind: decision.status.kind, message: decision.headline, detail: detailLine(reading, decision: decision))
                readingGrid(reading)
                if let wind = decision.windNote {
                    Text(wind)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.text)
                }
                if let ground = decision.groundNote {
                    Text(ground)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.text)
                }
                if showsTimeline {
                    timeline(reading)
                }
                if drifted(reading) {
                    Text("This reading is \(driftMiles(reading)) mi from the phone. Pull it again on the mat, or use the saved one.")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.text)
                }
            } else {
                Text(location.isAuthorized ? "No weather on this phone yet." : "Location fills the temperature and the rain. You can still type both on the Job tab.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.text)
            }

            if failed {
                Text("No signal. The last reading stays on the phone.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.text)
            }

            if location.authorization == .denied || location.authorization == .restricted {
                Button("Turn on location") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(FieldSecondaryButtonStyle())
            }

            Button(pulling ? "Reading weather…" : "Use GPS weather") {
                Task { await pull() }
            }
            .buttonStyle(FieldPrimaryButtonStyle())
            .disabled(pulling)

            if model.cachedWeather != nil {
                Button("Use saved reading") {
                    model.useSavedReading()
                    if let status = model.weatherDecision?.status {
                        FieldHaptics.status(status)
                    }
                }
                .buttonStyle(FieldSecondaryButtonStyle())
            }

            Toggle(isOn: $model.followsWeather) {
                Text("Keep filling from GPS")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.text)
            }
            .tint(palette.good)
        }
        .task {
            guard autoRefresh else { return }
            await Task.yield()
            location.requestAndStart()
        }
        .onChange(of: location.coordinate?.latitude) { _, _ in
            guard autoRefresh, let point = location.coordinate else { return }
            Task { await model.refreshWeatherIfNeeded(at: point) }
        }
    }

    private func readingGrid(_ reading: WeatherReading) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(FieldFormat.jsNumber(reading.airTempF))°F air · \(reading.conditions)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text(windLine(reading))
                .font(.title3.weight(.semibold))
            Text("Rain next 24 h \(FieldFormat.fixed(reading.rainNext24hIn, digits: 2)) in")
                .font(.title3.weight(.semibold))
            if let ground = reading.groundTempF {
                Text("Ground forecast \(FieldFormat.jsNumber(ground))°F · not an IR gun")
                    .font(.title3.weight(.semibold))
            }
            Text("\(WeatherDecisions.sourceLabel(reading.source)) · \(WeatherPolicy.ageText(fetchedAt: reading.fetchedAt, now: Date()))")
                .font(.body.weight(.semibold))
        }
        .foregroundStyle(palette.text)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timeline(_ reading: WeatherReading) -> some View {
        let upcoming = reading.hours.filter { $0.time >= Date().addingTimeInterval(-30 * 60) }.prefix(8)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(upcoming.enumerated()), id: \.offset) { _, hour in
                    let threat = hour.precipIn > 0 || hour.probability >= 40
                    VStack(alignment: .leading, spacing: 4) {
                        Text(hourLabel(hour.time))
                            .font(.headline.weight(.bold))
                        Text(hour.airTempF.map { "\(FieldFormat.jsNumber($0))°" } ?? "—")
                            .font(.title2.weight(.bold))
                        Text(hour.precipIn > 0 ? "\(FieldFormat.fixed(hour.precipIn, digits: 2)) in" : "Dry")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundStyle(threat ? Color.white : palette.text)
                    .padding(12)
                    .frame(width: 116, alignment: .leading)
                    .frame(minHeight: 108)
                    .background(threat ? palette.warn : palette.surface, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.border, lineWidth: palette.borderWidth))
                }
            }
        }
        .fieldScroll()
    }

    private func pull() async {
        location.requestAndStart()
        guard let point = location.coordinate else {
            failed = true
            FieldHaptics.warning()
            return
        }
        pulling = true
        let ok = await model.pullWeather(at: point)
        pulling = false
        failed = !ok
        if let status = model.weatherDecision?.status {
            FieldHaptics.status(status)
        } else if !ok {
            FieldHaptics.warning()
        }
    }

    private func windLine(_ reading: WeatherReading) -> String {
        guard let wind = reading.windMph else { return "Wind not in this reading" }
        let compass = reading.windDirectionDeg.map { " \(GeoMeasure.compassLabel(degrees: $0))" } ?? ""
        return "Wind \(FieldFormat.jsNumber(FieldFormat.jsRound(wind))) mph\(compass)"
    }

    private func detailLine(_ reading: WeatherReading, decision: WeatherDecision) -> String? {
        if let rain = decision.rain, rain.status != .pass { return rain.message }
        return decision.placement?.message
    }

    private func drifted(_ reading: WeatherReading) -> Bool {
        WeatherPolicy.hasDrifted(reading: reading, current: location.coordinate)
    }

    private func driftMiles(_ reading: WeatherReading) -> String {
        guard let current = location.coordinate else { return "" }
        let miles = GeoMeasure.miles(feet: WeatherPolicy.driftFeet(reading: reading, current: current))
        return FieldFormat.fixed(miles, digits: 0)
    }

    private func hourLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h a"
        return formatter.string(from: date)
    }
}

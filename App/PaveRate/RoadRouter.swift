import CoreLocation
import Foundation
import MapKit
import PaveRateCore

/// Finds the road under a start point. GDOT centerline first, then MapKit routing. Neither blocks the first frame.
@MainActor
@Observable
final class RoadSession {
    enum Phase: Equatable {
        case start
        case loading
        case choose
        case along
        case manual
    }

    var phase: Phase = .start
    var trace: RoadTrace?
    var choice: RoadDirectionChoice?
    var endFeet: Double = 0
    var message: String = "Drop a start on the road, or use the phone's GPS."
    private var cachedPieces: [RoadPiece] = []

    var planned: [GeoPoint] {
        guard let choice else { return [] }
        return RoadFollow.trim(choice.points, toFeet: endFeet)
    }

    var markers: [RoadMarker] {
        let line = planned
        let length = GeoMeasure.polylineFeet(line)
        let spacing = max(500, length / 8)
        return RoadFollow.stationTicks(line, everyFeet: spacing)
    }

    var mileposts: [RoadMarker] {
        cachedPieces.flatMap { piece in
            guard let begin = piece.beginMile, let end = piece.endMile else { return [RoadMarker]() }
            return RoadFollow.mileMarkers(points: piece.points, beginMile: begin, endMile: end)
        }
    }

    func handleTap(_ point: GeoPoint) async {
        switch phase {
        case .start, .manual:
            await begin(at: point)
        case .choose:
            break
        case .loading:
            break
        case .along:
            guard let choice else { return }
            guard let snap = RoadFollow.snap(point, onto: choice.points), snap.offsetFeet <= 200 else {
                message = "Tap the highlighted road, or type the feet."
                return
            }
            endFeet = min(snap.alongFeet, choice.lengthFeet)
            message = "\(choice.name) · \(choice.heading)"
        }
    }

    func begin(at point: GeoPoint) async {
        phase = .loading
        message = "Finding the road…"
        var pieces = RoadCache.pieces(covering: point)
        if pieces.isEmpty {
            pieces = (try? await RoadCenterlines.fetch(around: point)) ?? []
            if !pieces.isEmpty {
                RoadCache.save(pieces, around: point)
            }
        }
        cachedPieces = pieces
        if let traced = RoadFollow.trace(pieces: pieces, from: point) {
            show(traced)
            return
        }
        let routed = await RoadRouter.probe(from: point)
        if !routed.isEmpty {
            show(RoadTrace(roadName: routed[0].name, snapped: point, directions: routed))
            return
        }
        phase = .manual
        message = "No road service right now. Drop points yourself. Length is the line between the points."
    }

    func pick(_ choice: RoadDirectionChoice) {
        self.choice = choice
        endFeet = choice.lengthFeet
        phase = .along
        message = choice.forks.isEmpty
            ? "\(choice.name) · \(choice.heading)"
            : "\(choice.name) ends at a fork. Pick a turn, or set the end on this road."
    }

    func takeFork(_ fork: RoadDirectionChoice) {
        guard var choice else { return }
        let joined = RoadFollow.extend(choice.points, with: fork.points)
        choice = RoadDirectionChoice(
            id: choice.id + "+" + fork.id,
            name: fork.name.isEmpty ? choice.name : fork.name,
            heading: choice.heading,
            points: joined,
            lengthFeet: GeoMeasure.polylineFeet(joined),
            forks: []
        )
        pick(choice)
    }

    func useManual() {
        phase = .manual
        message = "Manual points. Length is the line between them."
    }

    private func show(_ traced: RoadTrace) {
        trace = traced
        choice = nil
        phase = .choose
        if traced.directions.count == 1 {
            message = "Only one way is open on \(traced.roadName). The other way is one-way, divided, or the road ends."
        } else {
            message = traced.roadName
        }
    }
}

enum RoadRouter {
    /// A few short drives from the start. Routing is one-way aware, so a divided road comes back as one direction.
    static func probe(from start: GeoPoint) async -> [RoadDirectionChoice] {
        let offsets = [(0.004, 0.0), (-0.004, 0.0), (0.0, 0.005), (0.0, -0.005)]
        var found: [RoadDirectionChoice] = []
        await withTaskGroup(of: RoadDirectionChoice?.self) { group in
            for offset in offsets {
                group.addTask {
                    await route(
                        from: start,
                        to: GeoPoint(latitude: start.latitude + offset.0, longitude: start.longitude + offset.1)
                    )
                }
            }
            for await choice in group {
                if let choice { found.append(choice) }
            }
        }
        return dedupe(found)
    }

    private static func route(from start: GeoPoint, to end: GeoPoint) async -> RoadDirectionChoice? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: start.latitude, longitude: start.longitude)))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: end.latitude, longitude: end.longitude)))
        request.transportType = .automobile
        let response: MKDirections.Response
        do {
            response = try await MKDirections(request: request).calculate()
        } catch {
            return nil
        }
        guard let route = response.routes.first else { return nil }
        let points = coordinates(of: route.polyline)
        guard points.count >= 2 else { return nil }
        let name = route.name ?? "Road"
        let length = GeoMeasure.polylineFeet(points)
        guard length >= RoadFollow.minimumDirectionFeet else { return nil }
        let heading = GeoMeasure.compassLabel(degrees: bearing(from: points[0], to: points[min(3, points.count - 1)]))
        return RoadDirectionChoice(
            id: "route-\(name)-\(heading)-\(Int(length))",
            name: name,
            heading: heading,
            points: points,
            lengthFeet: length
        )
    }

    private static func dedupe(_ choices: [RoadDirectionChoice]) -> [RoadDirectionChoice] {
        var kept: [RoadDirectionChoice] = []
        for choice in choices.sorted(by: { $0.lengthFeet > $1.lengthFeet }) {
            let sameWay = kept.contains { existing in
                existing.name.caseInsensitiveCompare(choice.name) == .orderedSame && existing.heading == choice.heading
            }
            if !sameWay { kept.append(choice) }
        }
        return kept
    }

    private static func coordinates(of polyline: MKPolyline) -> [GeoPoint] {
        let count = polyline.pointCount
        guard count > 0 else { return [] }
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: count)
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))
        return coords.map { GeoPoint(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private static func bearing(from start: GeoPoint, to end: GeoPoint) -> Double {
        let lat = start.latitude * .pi / 180
        let y = (end.latitude - start.latitude) * .pi / 180
        let x = (end.longitude - start.longitude) * .pi / 180 * cos(lat)
        var degrees = atan2(x, y) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        return degrees
    }
}

enum RoadCenterlines {
    private static let endpoint = URL(string: "https://maps.georgia.gov/arcgis/rest/services/GDOT/GDOT_GPAS/MapServer/5/query")

    static func fetch(around point: GeoPoint) async throws -> [RoadPiece] {
        guard let endpoint else { return [] }
        let delta = 0.02
        let envelope = "\(point.longitude - delta),\(point.latitude - delta),\(point.longitude + delta),\(point.latitude + delta)"
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "geometry", value: envelope),
            URLQueryItem(name: "geometryType", value: "esriGeometryEnvelope"),
            URLQueryItem(name: "inSR", value: "4326"),
            URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects"),
            URLQueryItem(name: "outFields", value: "ROUTE_ID,ROAD_NAME,COUNTY,BEG_MP,END_MP"),
            URLQueryItem(name: "returnGeometry", value: "true"),
            URLQueryItem(name: "outSR", value: "4326"),
            URLQueryItem(name: "resultRecordCount", value: "80"),
            URLQueryItem(name: "f", value: "json")
        ]
        guard let url = components?.url else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(CenterlineResponse.self, from: data)
        return (decoded.features ?? []).compactMap { feature -> RoadPiece? in
            guard let path = feature.geometry?.paths?.first, path.count >= 2 else { return nil }
            let points = path.compactMap { pair -> GeoPoint? in
                guard pair.count >= 2 else { return nil }
                return GeoPoint(latitude: pair[1], longitude: pair[0])
            }
            guard points.count >= 2 else { return nil }
            let name = feature.attributes?.roadName ?? feature.attributes?.routeID ?? "Road"
            return RoadPiece(
                name: name,
                points: points,
                beginMile: feature.attributes?.beginMile,
                endMile: feature.attributes?.endMile
            )
        }
    }
}

enum RoadCache {
    private static let key = "paverate.roadcache.v1"

    static func pieces(covering point: GeoPoint) -> [RoadPiece] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode(SavedRoads.self, from: data) else { return [] }
        let center = GeoPoint(latitude: saved.latitude, longitude: saved.longitude)
        guard GeoMeasure.haversineFeet(center, point) < 2_000 else { return [] }
        return saved.pieces
    }

    static func save(_ pieces: [RoadPiece], around point: GeoPoint) {
        let saved = SavedRoads(latitude: point.latitude, longitude: point.longitude, pieces: pieces)
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

private struct SavedRoads: Codable {
    var latitude: Double
    var longitude: Double
    var pieces: [RoadPiece]
}

private struct CenterlineResponse: Decodable {
    var features: [Feature]?

    struct Feature: Decodable {
        var attributes: Attributes?
        var geometry: Geometry?
    }

    struct Attributes: Decodable {
        var routeID: String?
        var roadName: String?
        var beginMile: Double?
        var endMile: Double?

        enum CodingKeys: String, CodingKey {
            case routeID = "ROUTE_ID"
            case roadName = "ROAD_NAME"
            case beginMile = "BEG_MP"
            case endMile = "END_MP"
        }
    }

    struct Geometry: Decodable {
        var paths: [[[Double]]]?
    }
}

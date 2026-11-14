import Foundation
import PaveRateCore

struct GdotRoute: Identifiable, Equatable, Sendable {
    var routeID: String
    var name: String
    var county: String
    var lines: [[GeoPoint]]

    var id: String { "\(routeID)|\(county)" }

    var lengthFeet: Double {
        lines.reduce(0) { $0 + GeoMeasure.polylineFeet($1) }
    }
}

/// Public GDOT GPAS route search. Same layer the web app's legacy `q=` lookup uses.
/// A miss or a timeout leaves the drawn run alone.
enum RouteLookup {
    private static let endpoint = URL(string: "https://maps.georgia.gov/arcgis/rest/services/GDOT/GDOT_GPAS/MapServer/5/query")

    static func search(query: String) async throws -> [GdotRoute] {
        let safe = query.uppercased().filter { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" }
        let trimmed = safe.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2, let endpoint else { return [] }
        let whereClause = "UPPER(ROUTE_ID) LIKE UPPER('%\(trimmed)%') OR UPPER(ROAD_NAME) LIKE UPPER('%\(trimmed)%')"
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "where", value: whereClause),
            URLQueryItem(name: "outFields", value: "ROUTE_ID,ROAD_NAME,COUNTY,FUNCTION_TYPE,SYSTEM_CODE"),
            URLQueryItem(name: "returnGeometry", value: "true"),
            URLQueryItem(name: "outSR", value: "4326"),
            URLQueryItem(name: "resultRecordCount", value: "20"),
            URLQueryItem(name: "orderByFields", value: "ROUTE_ID ASC"),
            URLQueryItem(name: "f", value: "json")
        ]
        guard let url = components?.url else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(ArcGISRoutes.self, from: data)
        var grouped: [String: GdotRoute] = [:]
        for feature in decoded.features ?? [] {
            let routeID = feature.attributes.routeID ?? ""
            guard !routeID.isEmpty, let paths = feature.geometry?.paths else { continue }
            let county = feature.attributes.county ?? ""
            let key = "\(routeID)|\(county)"
            let lines: [[GeoPoint]] = paths.compactMap { path in
                let points = path.compactMap { pair -> GeoPoint? in
                    guard pair.count >= 2 else { return nil }
                    return GeoPoint(latitude: pair[1], longitude: pair[0])
                }
                return points.count >= 2 ? points : nil
            }
            guard !lines.isEmpty else { continue }
            if var existing = grouped[key] {
                existing.lines.append(contentsOf: lines)
                grouped[key] = existing
            } else {
                grouped[key] = GdotRoute(
                    routeID: routeID,
                    name: feature.attributes.roadName ?? routeID,
                    county: county,
                    lines: lines
                )
            }
        }
        return grouped.values.sorted { $0.routeID < $1.routeID }
    }
}

private struct ArcGISRoutes: Decodable {
    var features: [Feature]?

    struct Feature: Decodable {
        var attributes: Attributes
        var geometry: Geometry?
    }

    struct Attributes: Decodable {
        var routeID: String?
        var roadName: String?
        var county: String?

        enum CodingKeys: String, CodingKey {
            case routeID = "ROUTE_ID"
            case roadName = "ROAD_NAME"
            case county = "COUNTY"
        }
    }

    struct Geometry: Decodable {
        var paths: [[[Double]]]?
    }
}

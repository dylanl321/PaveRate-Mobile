import Foundation

/// One centerline piece from a map service or a routing result.
public struct RoadPiece: Codable, Equatable, Sendable {
    public var name: String
    public var points: [GeoPoint]
    public var beginMile: Double?
    public var endMile: Double?

    public init(name: String, points: [GeoPoint], beginMile: Double? = nil, endMile: Double? = nil) {
        self.name = name
        self.points = points
        self.beginMile = beginMile
        self.endMile = endMile
    }
}

public struct RoadSnap: Equatable, Sendable {
    public var point: GeoPoint
    public var alongFeet: Double
    public var offsetFeet: Double
    public var segmentIndex: Int

    public init(point: GeoPoint, alongFeet: Double, offsetFeet: Double, segmentIndex: Int) {
        self.point = point
        self.alongFeet = alongFeet
        self.offsetFeet = offsetFeet
        self.segmentIndex = segmentIndex
    }
}

/// One way to pave from the snapped start. `points` begins at the start.
public struct RoadDirectionChoice: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var heading: String
    public var points: [GeoPoint]
    public var lengthFeet: Double
    /// Other roads that touch the end of this trace. The foreman picks one to keep going.
    public var forks: [RoadDirectionChoice]

    public init(
        id: String,
        name: String,
        heading: String,
        points: [GeoPoint],
        lengthFeet: Double,
        forks: [RoadDirectionChoice] = []
    ) {
        self.id = id
        self.name = name
        self.heading = heading
        self.points = points
        self.lengthFeet = lengthFeet
        self.forks = forks
    }
}

public struct RoadTrace: Equatable, Sendable {
    public var roadName: String
    public var snapped: GeoPoint
    public var directions: [RoadDirectionChoice]

    public init(roadName: String, snapped: GeoPoint, directions: [RoadDirectionChoice]) {
        self.roadName = roadName
        self.snapped = snapped
        self.directions = directions
    }
}

public struct RoadMarker: Equatable, Sendable, Identifiable {
    public var id: String
    public var point: GeoPoint
    public var label: String

    public init(id: String, point: GeoPoint, label: String) {
        self.id = id
        self.point = point
        self.label = label
    }
}

/// Follow a real centerline: snap, walk one road name, trim to an exact length.
public enum RoadFollow {
    /// Endpoints closer than this are the same intersection.
    public static let joinFeet = 80.0
    /// A tap farther than this from every centerline is not on that road.
    public static let maxSnapFeet = 150.0
    /// Shorter than this is not a direction the paver can take.
    public static let minimumDirectionFeet = 30.0

    public static func snap(_ point: GeoPoint, onto line: [GeoPoint]) -> RoadSnap? {
        guard line.count >= 2 else { return nil }
        var bestOffset = Double.greatestFiniteMagnitude
        var best: RoadSnap?
        var along = 0.0
        for index in 0..<(line.count - 1) {
            let start = line[index]
            let end = line[index + 1]
            let segment = GeoMeasure.haversineFeet(start, end)
            let (t, offset) = project(point, start, end)
            if offset < bestOffset {
                bestOffset = offset
                best = RoadSnap(
                    point: interpolate(start, end, t: t),
                    alongFeet: along + t * segment,
                    offsetFeet: offset,
                    segmentIndex: index
                )
            }
            along += segment
        }
        return best
    }

    /// The part of `points` from the start through `feet`, including a point exactly at that distance.
    public static func trim(_ points: [GeoPoint], toFeet feet: Double) -> [GeoPoint] {
        GeoMeasure.prefix(points: points, feet: feet)
    }

    public static func trace(pieces: [RoadPiece], from start: GeoPoint) -> RoadTrace? {
        var best: (index: Int, snap: RoadSnap)?
        for (index, piece) in pieces.enumerated() {
            guard let snap = snap(start, onto: piece.points), snap.offsetFeet <= maxSnapFeet else { continue }
            if best == nil || snap.offsetFeet < best?.snap.offsetFeet ?? .greatestFiniteMagnitude {
                best = (index, snap)
            }
        }
        guard let best else { return nil }
        let piece = pieces[best.index]
        let name = displayName(piece.name)
        let forward = walk(
            pieces: pieces,
            startIndex: best.index,
            snap: best.snap,
            towardStart: false,
            roadName: normalized(piece.name)
        )
        let backward = walk(
            pieces: pieces,
            startIndex: best.index,
            snap: best.snap,
            towardStart: true,
            roadName: normalized(piece.name)
        )
        let directions = [forward, backward].compactMap { built -> RoadDirectionChoice? in
            guard built.points.count >= 2 else { return nil }
            let length = GeoMeasure.polylineFeet(built.points)
            guard length >= minimumDirectionFeet else { return nil }
            let heading = compassHeading(from: built.points[0], to: built.points[1])
            return RoadDirectionChoice(
                id: "\(normalized(name))-\(heading)-\(Int(length))",
                name: name,
                heading: heading,
                points: built.points,
                lengthFeet: length,
                forks: built.forks
            )
        }
        guard !directions.isEmpty else { return nil }
        return RoadTrace(roadName: name, snapped: best.snap.point, directions: directions)
    }

    /// Whole-mile labels between the GDOT begin and end measures, if the piece has them.
    public static func mileMarkers(points: [GeoPoint], beginMile: Double, endMile: Double) -> [RoadMarker] {
        let span = endMile - beginMile
        guard abs(span) > 0.0001, points.count >= 2 else { return [] }
        let length = GeoMeasure.polylineFeet(points)
        guard length > 0 else { return [] }
        var markers: [RoadMarker] = []
        var mile = ceil(min(beginMile, endMile) + 0.0001)
        let upper = max(beginMile, endMile) - 0.0001
        while mile < upper {
            let fraction = (mile - beginMile) / span
            if fraction >= 0, fraction <= 1, let point = GeoMeasure.pointAlong(points: points, feet: fraction * length) {
                let label = "MP \(Int(mile))"
                markers.append(RoadMarker(id: label, point: point, label: label))
            }
            mile += 1
        }
        return markers
    }

    public static func stationTicks(_ points: [GeoPoint], everyFeet: Double) -> [RoadMarker] {
        let length = GeoMeasure.polylineFeet(points)
        guard everyFeet > 0, length > everyFeet else { return [] }
        var ticks: [RoadMarker] = []
        var feet = everyFeet
        while feet < length - 1 {
            if let point = GeoMeasure.pointAlong(points: points, feet: feet) {
                let label = GeoMeasure.stationLabel(feet: feet)
                ticks.append(RoadMarker(id: label, point: point, label: label))
            }
            feet += everyFeet
        }
        return ticks
    }

    /// Attach a fork's centerline onto the end of the chosen direction.
    public static func extend(_ base: [GeoPoint], with next: [GeoPoint]) -> [GeoPoint] {
        guard let first = next.first else { return base }
        guard let last = base.last else { return next }
        if GeoMeasure.haversineFeet(last, first) <= joinFeet {
            return base + next.dropFirst()
        }
        return base + next
    }

    private struct Walk {
        var points: [GeoPoint]
        var forks: [RoadDirectionChoice]
    }

    private static func walk(
        pieces: [RoadPiece],
        startIndex: Int,
        snap: RoadSnap,
        towardStart: Bool,
        roadName: String
    ) -> Walk {
        let line = pieces[startIndex].points
        var points = remainder(line, snap: snap, towardStart: towardStart)
        guard let cursorStart = points.last else { return Walk(points: points, forks: []) }
        var cursor = cursorStart
        var previous = startIndex
        var visited: Set<Int> = [startIndex]
        var forks: [RoadDirectionChoice] = []
        var steps = 0
        while steps < 40 {
            steps += 1
            let neighbors = touching(pieces, cursor: cursor, visited: visited)
            let same = neighbors.filter { normalized($0.name) == roadName && !roadName.isEmpty }
            if same.count == 1, let only = same.first {
                points = extend(points, with: only.points)
                visited.insert(only.index)
                previous = only.index
                cursor = only.points.last ?? cursor
                continue
            }
            let pool = same.count > 1 ? same : neighbors
            if !pool.isEmpty {
                forks = pool.enumerated().map { offset, item in
                    let heading = item.points.count >= 2 ? compassHeading(from: item.points[0], to: item.points[1]) : ""
                    let length = GeoMeasure.polylineFeet(item.points)
                    return RoadDirectionChoice(
                        id: "fork-\(previous)-\(offset)-\(normalized(item.name))",
                        name: displayName(item.name),
                        heading: heading,
                        points: item.points,
                        lengthFeet: length
                    )
                }
            }
            break
        }
        return Walk(points: points, forks: forks)
    }

    private struct Touch {
        var index: Int
        var name: String
        var points: [GeoPoint]
    }

    private static func touching(_ pieces: [RoadPiece], cursor: GeoPoint, visited: Set<Int>) -> [Touch] {
        var found: [Touch] = []
        for (index, piece) in pieces.enumerated() where !visited.contains(index) {
            guard let first = piece.points.first, let last = piece.points.last else { continue }
            if GeoMeasure.haversineFeet(first, cursor) <= joinFeet {
                found.append(Touch(index: index, name: piece.name, points: piece.points))
            } else if GeoMeasure.haversineFeet(last, cursor) <= joinFeet {
                found.append(Touch(index: index, name: piece.name, points: Array(piece.points.reversed())))
            }
        }
        return found
    }

    private static func remainder(_ line: [GeoPoint], snap: RoadSnap, towardStart: Bool) -> [GeoPoint] {
        if towardStart {
            let head = GeoMeasure.prefix(points: line, feet: snap.alongFeet)
            return Array(head.reversed())
        }
        let total = GeoMeasure.polylineFeet(line)
        let back = GeoMeasure.prefix(points: Array(line.reversed()), feet: max(0, total - snap.alongFeet))
        return Array(back.reversed())
    }

    private static func project(_ point: GeoPoint, _ start: GeoPoint, _ end: GeoPoint) -> (t: Double, offsetFeet: Double) {
        let origin = local(point, origin: start)
        let vector = local(end, origin: start)
        let lengthSquared = vector.x * vector.x + vector.y * vector.y
        if lengthSquared < 1 {
            return (0, GeoMeasure.haversineFeet(point, start))
        }
        let raw = (origin.x * vector.x + origin.y * vector.y) / lengthSquared
        let t = min(1, max(0, raw))
        let dx = origin.x - t * vector.x
        let dy = origin.y - t * vector.y
        return (t, sqrt(dx * dx + dy * dy) * GeoMeasure.feetPerMeter)
    }

    private static func local(_ point: GeoPoint, origin: GeoPoint) -> (x: Double, y: Double) {
        let lat = origin.latitude * .pi / 180
        let y = (point.latitude - origin.latitude) * .pi / 180 * GeoMeasure.earthRadiusM
        let x = (point.longitude - origin.longitude) * .pi / 180 * GeoMeasure.earthRadiusM * cos(lat)
        return (x, y)
    }

    private static func interpolate(_ start: GeoPoint, _ end: GeoPoint, t: Double) -> GeoPoint {
        let clamped = min(1, max(0, t))
        return GeoPoint(
            latitude: start.latitude + (end.latitude - start.latitude) * clamped,
            longitude: start.longitude + (end.longitude - start.longitude) * clamped
        )
    }

    private static func compassHeading(from start: GeoPoint, to end: GeoPoint) -> String {
        let delta = local(end, origin: start)
        var degrees = atan2(delta.x, delta.y) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        return GeoMeasure.compassLabel(degrees: degrees)
    }

    private static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func displayName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Road" : trimmed
    }
}

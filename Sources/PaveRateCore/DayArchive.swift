import Foundation

/// A photo pinned to a station and, when the phone has a fix, a coordinate.
/// The JPEG lives on disk under `imageFilename`. This record is the caption.
public struct PhotoNote: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var caption: String
    public var stationFeet: Double?
    public var latitude: Double?
    public var longitude: Double?
    public var createdAt: Date
    public var imageFilename: String

    public init(
        id: UUID = UUID(),
        caption: String,
        stationFeet: Double? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        createdAt: Date = Date(),
        imageFilename: String
    ) {
        self.id = id
        self.caption = caption
        self.stationFeet = stationFeet
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
        self.imageFilename = imageFilename
    }

    public func line(index: Int) -> String {
        var place = "no station"
        if let stationFeet {
            place = GeoMeasure.stationLabel(feet: stationFeet)
        }
        if let latitude, let longitude {
            place += " · \(FieldFormat.fixed(latitude, digits: 5)), \(FieldFormat.fixed(longitude, digits: 5))"
        }
        let words = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = words.isEmpty ? "Photo" : words
        return "\(index). \(text) · \(place)"
    }
}

/// One finished shift, kept on the phone so New day cannot throw it away.
public struct DayArchive: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var savedAt: Date
    public var job: JobSetup
    public var loads: [LoadTicket]
    public var plannedPoints: [GeoPoint]
    public var pavedPoints: [GeoPoint]
    public var weather: WeatherReading?
    public var photoNotes: [PhotoNote]
    public var foremanName: String
    public var crewName: String
    public var tonsOrdered: Double?
    public var dayNote: String

    public init(
        id: UUID = UUID(),
        savedAt: Date = Date(),
        job: JobSetup,
        loads: [LoadTicket],
        plannedPoints: [GeoPoint],
        pavedPoints: [GeoPoint],
        weather: WeatherReading?,
        photoNotes: [PhotoNote],
        foremanName: String,
        crewName: String,
        tonsOrdered: Double?,
        dayNote: String
    ) {
        self.id = id
        self.savedAt = savedAt
        self.job = job
        self.loads = loads
        self.plannedPoints = plannedPoints
        self.pavedPoints = pavedPoints
        self.weather = weather
        self.photoNotes = photoNotes
        self.foremanName = foremanName
        self.crewName = crewName
        self.tonsOrdered = tonsOrdered
        self.dayNote = dayNote
    }

    public var tonsPlaced: Double { LoadLedger.tonsPlaced(loads) }
}

public enum DayHistory {
    /// A blank screen is not a day. Anything the crew recorded is.
    public static func shouldKeep(
        loads: [LoadTicket],
        pavedPoints: [GeoPoint],
        photoNotes: [PhotoNote],
        tonsOrdered: Double?,
        weather: WeatherReading?,
        dayNote: String
    ) -> Bool {
        if !loads.isEmpty { return true }
        if pavedPoints.count >= 2 { return true }
        if !photoNotes.isEmpty { return true }
        if let tonsOrdered, tonsOrdered > 0 { return true }
        if weather != nil { return true }
        return !dayNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

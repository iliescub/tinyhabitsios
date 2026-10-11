import Foundation

/// A themed set of habit templates (Option B). Packs are bundled JSON files: adding a niche needs no code.
public struct Pack: Codable, Identifiable, Hashable, Sendable {
    public struct Template: Codable, Hashable, Sendable {
        public var name: String
        public var symbol: String
        public var source: HabitSourceID
        public var target: Double
        public var unit: String
        public var perWeek: Int?

        public init(name: String, symbol: String, source: HabitSourceID, target: Double, unit: String, perWeek: Int? = nil) {
            self.name = name
            self.symbol = symbol
            self.source = source
            self.target = target
            self.unit = unit
            self.perWeek = perWeek
        }

        public var cadence: Cadence { Cadence(perWeek: perWeek ?? 7) }
    }

    public var id: String
    public var name: String
    public var tagline: String
    public var accent: String
    public var templates: [Template]
    public var graduation: GraduationRule?
}

public enum PackLibrary {
    public enum LoadError: Error {
        case missing(String)
    }

    /// Loads `Resources/Packs/<id>.json` from this package's bundle.
    public static func load(_ id: String) throws -> Pack {
        guard let url = Bundle.module.url(forResource: id, withExtension: "json", subdirectory: "Packs")
                ?? Bundle.module.url(forResource: id, withExtension: "json") else {
            throw LoadError.missing(id)
        }
        return try JSONDecoder().decode(Pack.self, from: Data(contentsOf: url))
    }

    public static func essentials() throws -> Pack {
        try load("essentials")
    }
}

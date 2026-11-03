import Foundation

/// A common resolution and the habits that carry it (RES-2). Bundled JSON, like packs: adding one needs no code.
public struct ResolutionTemplate: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    /// Shown in the picker: "Sleep better".
    public var title: String
    /// Fits "In 2027 I'm …": "sleeping better".
    public var sentence: String
    public var symbol: String
    public var accent: String
    /// Lowercased words that point a typed resolution here (`ResolutionLibrary.match`).
    public var keywords: [String]
    /// Up to `SlotPolicy.maxActive` habits, Health ones first.
    public var habits: [Pack.Template]
}

public enum ResolutionLibrary {
    private struct File: Codable {
        var resolutions: [ResolutionTemplate]
    }

    /// Decoded once per process; the file is bundled and never changes.
    private static let cached: Result<[ResolutionTemplate], Error> = Result { try load() }

    public static func all() throws -> [ResolutionTemplate] {
        try cached.get()
    }

    private static func load() throws -> [ResolutionTemplate] {
        guard let url = Bundle.module.url(forResource: "resolutions", withExtension: "json", subdirectory: "Resolutions")
                ?? Bundle.module.url(forResource: "resolutions", withExtension: "json") else {
            throw PackLibrary.LoadError.missing("resolutions")
        }
        return try JSONDecoder().decode(File.self, from: Data(contentsOf: url)).resolutions
    }

    public static func template(id: String) throws -> ResolutionTemplate? {
        try all().first { $0.id == id }
    }

    /// The template a typed resolution most likely means, by keyword hits; nil when nothing matches.
    /// "Stop doomscrolling at night" → Evenings off the phone, so an avoidance goal gets an approach plan (RES-3).
    public static func match(_ text: String, in templates: [ResolutionTemplate]) -> ResolutionTemplate? {
        let words = Set(
            ResolutionFraming.normalize(text)
                .split { !$0.isLetter && $0 != "'" }
                .map(String.init)
        )
        guard !words.isEmpty else { return nil }
        var best: (template: ResolutionTemplate, score: Int)?
        for template in templates {
            let score = template.keywords.filter { keyword in
                // Whole words, or a longer form of a keyword of 5+ letters ("stressed" → "stress"); short prefixes
                // matched unrelated words ("rest" → "restaurants").
                words.contains(keyword) || (keyword.count >= 5 && words.contains { $0.hasPrefix(keyword) })
            }.count
            if score > 0, score > (best?.score ?? 0) {
                best = (template, score)
            }
        }
        return best?.template
    }
}

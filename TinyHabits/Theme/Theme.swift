import SwiftUI

enum AccentTheme: String, CaseIterable, Identifiable {
    case blue
    case green
    case orange

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return Color.blue
        case .green: return Color.green
        case .orange: return Color.orange
        }
    }
}

struct ThemeManager {
    @AppStorage("accentTheme") private var storedAccent: String = AccentTheme.blue.rawValue

    var accent: AccentTheme {
        get { AccentTheme(rawValue: storedAccent) ?? .blue }
        set { storedAccent = newValue.rawValue }
    }
}


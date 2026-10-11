import SwiftUI

/// The only decorative element: a soft sky gradient that follows the time of day (docs/DESIGN.md §3.2).
public struct SkyBackground: View {
    public let date: Date
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(date: Date = .now) {
        self.date = date
    }

    public enum Phase: Equatable, Sendable {
        case dawn, day, dusk, night

        public init(hour: Int) {
            switch hour {
            case 5..<10: self = .dawn
            case 10..<17: self = .day
            case 17..<21: self = .dusk
            default: self = .night
            }
        }
    }

    public var body: some View {
        if reduceTransparency {
            FledgeTheme.Palette.cloud
        } else {
            LinearGradient(colors: [topColor, FledgeTheme.Palette.cloud], startPoint: .top, endPoint: .center)
        }
    }

    private var topColor: Color {
        let phase = Phase(hour: Calendar.current.component(.hour, from: date))
        if colorScheme == .dark {
            return phase == .night ? Color(light: 0x1B2240, dark: 0x1B2240) : Color(light: 0x23294D, dark: 0x23294D)
        }
        switch phase {
        case .dawn: return Color(light: 0xFFE2CF, dark: 0xFFE2CF)
        case .day: return Color(light: 0xDCE9FF, dark: 0xDCE9FF)
        case .dusk: return Color(light: 0xE7DBFF, dark: 0xE7DBFF)
        case .night: return Color(light: 0xC9D2EE, dark: 0xC9D2EE)
        }
    }
}

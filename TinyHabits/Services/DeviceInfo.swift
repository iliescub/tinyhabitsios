import UIKit
import HabitCore
import FledgeHealth

/// What differs between iPhone and iPad for copy and features (docs/DESIGN.md §12).
enum DeviceInfo {
    /// "iPhone" or "iPad", for lines like "Stays on your iPad".
    static var name: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    }

    /// Apple Health can be missing on iPad (managed devices, some models). Health templates then become tap-to-log.
    static var isHealthAvailable: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-FledgeNoHealth") { return false }
        #endif
        return HealthReader.isAvailable
    }
}

extension Pack.Template {
    /// The same habit, logged by tapping: for "Not now" in onboarding and devices without Apple Health.
    var tapToLog: Pack.Template {
        Pack.Template(name: name, symbol: symbol, source: .manual, target: 1, unit: "times", perWeek: perWeek)
    }
}

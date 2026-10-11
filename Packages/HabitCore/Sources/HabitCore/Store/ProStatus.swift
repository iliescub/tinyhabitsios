import Foundation

/// Fledge Pro state, cached in the App Group so widgets and controls can read it (PAY-1).
/// The app is the only writer; it derives the value from StoreKit entitlements.
public enum ProStatus {
    public static let isProKey = "isPro"

    public static let productIDs = ProductIDs()

    public struct ProductIDs: Sendable {
        public let monthly = "com.smartapps.TinyHabits.pro.monthly"
        public let yearly = "com.smartapps.TinyHabits.pro.yearly"
        public let lifetime = "com.smartapps.TinyHabits.pro.lifetime"
        public var all: Set<String> { [monthly, yearly, lifetime] }
    }

    public static var isPro: Bool {
        get { FledgeSettings.defaults.bool(forKey: isProKey) }
        set { FledgeSettings.defaults.set(newValue, forKey: isProKey) }
    }
}

/// What the free tier includes (docs/SPEC.md, Monetization). Three slots are never paid.
public enum ProPolicy {
    /// Free users get one habit that completes itself from Apple Health.
    public static let freeAutoHabits = 1

    public static func canAddAutoHabit(isPro: Bool, activeAutoCount: Int) -> Bool {
        isPro || activeAutoCount < freeAutoHabits
    }
}

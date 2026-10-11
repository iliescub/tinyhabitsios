import Foundation
import StoreKit
import WidgetKit
import HabitCore

/// StoreKit 2 entitlements for Fledge Pro (PAY-1). The result is cached in the App Group (`ProStatus`)
/// so widgets and controls can read it without StoreKit.
@MainActor
@Observable
final class Purchases {
    static let shared = Purchases()

    private(set) var isPro = ProStatus.isPro
    private var updates: Task<Void, Never>?

    private init() {}

    /// Call once at launch: reads current entitlements and listens for renewals, refunds and Ask to Buy.
    func start() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-FledgePro") {
            apply(true)
            return
        }
        #endif
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    func refresh() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  ProStatus.productIDs.all.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            entitled = true
        }
        apply(entitled)
    }

    /// Settings › Restore purchases.
    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }

    private func apply(_ entitled: Bool) {
        guard entitled != isPro || entitled != ProStatus.isPro else { return }
        isPro = entitled
        ProStatus.isPro = entitled
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
    }
}

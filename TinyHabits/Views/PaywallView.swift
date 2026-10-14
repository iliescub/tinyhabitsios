import SwiftUI
import SwiftData
import StoreKit
import HabitCore
import FledgeUI

/// Fledge Pro paywall (docs/DESIGN.md §6.7, v2 in UX-15). Always dismissible; never shown on launch.
/// Marketing on top (the user's own nest, Free vs Pro, the trial timeline), StoreKit's plan picker below.
/// Products are loaded first, so a slow or missing App Store shows a designed state instead of a blank sheet.
struct PaywallView: View {
    /// Why it was opened, for the header line.
    var reason: Reason = .general

    enum Reason {
        case general, onboarding, secondHealthHabit
    }

    private enum LoadState: Equatable {
        case loading, ready, failed
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var activeHabits: [Habit]
    @State private var purchases = Purchases.shared
    @State private var loadState: LoadState = .loading
    @State private var yearly: Product?
    @State private var trialDays: Int?

    init(reason: Reason = .general) {
        self.reason = reason
        let active = HabitState.active.rawValue
        _activeHabits = Query(filter: #Predicate<Habit> { $0.stateRaw == active })
    }

    var body: some View {
        Group {
            if loadState == .ready {
                store
            } else {
                placeholder
            }
        }
        .task { await load() }
        .onChange(of: purchases.isPro) { _, isPro in
            if isPro { dismiss() }
        }
    }

    // MARK: Store

    private var store: some View {
        SubscriptionStoreView(productIDs: [ProStatus.productIDs.yearly, ProStatus.productIDs.monthly]) {
            marketing
        }
        .subscriptionStoreControlStyle(.prominentPicker)
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .policies)
        .subscriptionStorePolicyDestination(url: AppLinks.terms, for: .termsOfService)
        .subscriptionStorePolicyDestination(url: AppLinks.privacy, for: .privacyPolicy)
        .tint(FledgeTheme.Palette.ink)
        .safeAreaInset(edge: .bottom) {
            lifetime
        }
        .onInAppPurchaseCompletion { _, result in
            if case .success(.success) = result {
                await purchases.refresh()
                dismiss()
            }
        }
    }

    private var lifetime: some View {
        ProductView(id: ProStatus.productIDs.lifetime) {
            Image(systemName: "infinity")
                .foregroundStyle(FledgeTheme.Palette.gold)
        }
        .productViewStyle(.compact)
        .padding(.horizontal, FledgeTheme.screenMargin)
        .padding(.vertical, FledgeTheme.Space.s)
        .background(.bar)
    }

    // MARK: Marketing

    private var marketing: some View {
        VStack(spacing: FledgeTheme.Space.l) {
            VStack(spacing: FledgeTheme.Space.s) {
                FledgeBird(.flying)
                    .frame(height: 70)
                    .shadow(color: FledgeTheme.Palette.ink.opacity(0.15), radius: 10, y: 6)
                    .padding(.top, FledgeTheme.Space.xl)
                Text("Fledge Pro").fledgeEyebrow()
                Text("Let all three fill in by themselves")
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .foregroundStyle(FledgeTheme.Palette.ink)
                    .multilineTextAlignment(.center)
                if let personal {
                    Text(personal)
                        .font(.subheadline)
                        .foregroundStyle(FledgeTheme.Palette.ink2)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, FledgeTheme.screenMargin)

            ComparisonTable()
                .padding(.horizontal, FledgeTheme.screenMargin)

            if let trialDays, let yearly {
                TrialTimeline(days: trialDays, yearly: yearly)
                    .padding(.horizontal, FledgeTheme.screenMargin)
            }

            Text("Three habits stay free forever.")
                .font(.footnote)
                .foregroundStyle(FledgeTheme.Palette.ink2)
                .padding(.bottom, FledgeTheme.Space.s)
        }
        .frame(maxWidth: .infinity)
        .background(SkyBackground())
    }

    /// The user's own nest, or why the paywall opened.
    private var personal: String? {
        let names = activeHabits.sorted { ($0.slot ?? 0) < ($1.slot ?? 0) }.map(\.name)
        switch reason {
        case .secondHealthHabit:
            if let used = activeHabits.first(where: { $0.source.isAuto })?.name {
                return "Free includes one Health habit, and \(used) is using it."
            }
            return "Free includes one habit from Apple Health."
        case .general, .onboarding:
            return names.isEmpty ? nil : "Your nest: \(names.formatted(.list(type: .and)))."
        }
    }

    // MARK: Loading and offline

    private var placeholder: some View {
        ScrollView {
            VStack(spacing: FledgeTheme.Space.l) {
                marketing
                VStack(spacing: FledgeTheme.Space.m) {
                    if loadState == .loading {
                        ForEach(0..<2, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: FledgeTheme.Radius.tile, style: .continuous)
                                .fill(FledgeTheme.Palette.hairline.opacity(0.6))
                                .frame(height: 64)
                        }
                        Label("Connecting to the App Store…", systemImage: "arrow.triangle.2.circlepath")
                            .font(.footnote)
                            .foregroundStyle(FledgeTheme.Palette.ink2)
                            .symbolEffect(.rotate, isActive: !reduceMotion)
                    } else {
                        Label("The App Store can't be reached right now.", systemImage: "wifi.exclamationmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FledgeTheme.Palette.ink)
                        Text("Check your connection and try again. Nothing has been charged.")
                            .font(.footnote)
                            .foregroundStyle(FledgeTheme.Palette.ink2)
                            .multilineTextAlignment(.center)
                        PrimaryActionButton(title: "Try again", systemImage: "arrow.clockwise") {
                            Task { await load() }
                        }
                    }
                }
                .padding(.horizontal, FledgeTheme.screenMargin)
            }
            .padding(.bottom, FledgeTheme.Space.xxl)
        }
        .background(FledgeTheme.Palette.cloud.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 36, height: 36)
                    .background(.regularMaterial, in: .circle)
            }
            .tint(FledgeTheme.Palette.ink)
            .padding(FledgeTheme.Space.l)
            .accessibilityLabel("Close")
        }
    }

    /// Loads the products (10 s limit) and the yearly plan's free trial, if this Apple ID can still get one.
    private func load() async {
        loadState = .loading
        let products = await withTaskGroup(of: [Product]?.self) { group in
            group.addTask { try? await Product.products(for: ProStatus.productIDs.all) }
            group.addTask {
                try? await Task.sleep(for: .seconds(10))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        guard let products, !products.isEmpty else {
            loadState = .failed
            return
        }
        yearly = products.first { $0.id == ProStatus.productIDs.yearly }
        if let yearly, let offer = yearly.subscription?.introductoryOffer, offer.paymentMode == .freeTrial,
           await yearly.subscription?.isEligibleForIntroOffer == true {
            trialDays = Self.days(in: offer.period)
        }
        loadState = .ready
    }

    private static func days(in period: Product.SubscriptionPeriod) -> Int {
        switch period.unit {
        case .day: period.value
        case .week: period.value * 7
        case .month: period.value * 30
        case .year: period.value * 365
        @unknown default: period.value
        }
    }
}

/// Free vs Pro in three rows, from `ProPolicy` (docs/SPEC.md, Monetization).
private struct ComparisonTable: View {
    private let rows: [(String, String, String)] = [
        ("Habits from Apple Health", "\(ProPolicy.freeAutoHabits)", "3"),
        ("Lock Screen, StandBy, every widget", "–", "✓"),
        ("App icons and CSV export", "–", "✓"),
    ]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: FledgeTheme.Space.m, verticalSpacing: FledgeTheme.Space.s) {
            GridRow {
                Text("")
                Text("Free").fledgeEyebrow().gridColumnAlignment(.center)
                Text("Pro").fledgeEyebrow().gridColumnAlignment(.center)
            }
            ForEach(rows, id: \.0) { row in
                Divider().gridCellUnsizedAxes(.horizontal)
                GridRow {
                    Text(row.0)
                        .font(.subheadline)
                        .foregroundStyle(FledgeTheme.Palette.ink)
                    Text(row.1)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FledgeTheme.Palette.ink2)
                        .frame(minWidth: 40)
                    Text(row.2)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(FledgeTheme.Palette.ink)
                        .frame(minWidth: 40)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(row.0): free \(row.1 == "–" ? "no" : row.1), Pro \(row.2 == "✓" ? "yes" : row.2)"))
            }
        }
        .padding(FledgeTheme.Space.l)
        .fledgeCard(cornerRadius: FledgeTheme.Radius.tile)
    }
}

/// What happens when, so the free trial holds no surprises.
private struct TrialTimeline: View {
    let days: Int
    let yearly: Product

    var body: some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.m) {
            row("Today", "Everything unlocks. Free for \(days) days.", fill: FledgeTheme.Palette.ink)
            row("Any day", "Cancel anytime before day \(days) and nothing is charged.", fill: FledgeTheme.Palette.ink2)
            row("Day \(days)", "The yearly plan starts: \(yearly.displayPrice), about \(perMonth) a month.", fill: FledgeTheme.Palette.hairline)
        }
        .padding(FledgeTheme.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fledgeCard(cornerRadius: FledgeTheme.Radius.tile)
    }

    private var perMonth: String {
        (yearly.price / 12).formatted(yearly.priceFormatStyle)
    }

    private func row(_ when: String, _ what: String, fill: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FledgeTheme.Space.m) {
            Circle().fill(fill).frame(width: 9, height: 9)
            Text(when)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(FledgeTheme.Palette.ink)
                .frame(width: 64, alignment: .leading)
            Text(what)
                .font(.subheadline)
                .foregroundStyle(FledgeTheme.Palette.ink2)
        }
        .accessibilityElement(children: .combine)
    }
}

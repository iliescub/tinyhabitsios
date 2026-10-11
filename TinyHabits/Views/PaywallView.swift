import SwiftUI
import StoreKit
import HabitCore
import FledgeUI

/// Fledge Pro paywall (docs/DESIGN.md §6.7). Always dismissible (StoreKit adds the close button in sheets); never shown on launch.
struct PaywallView: View {
    /// Why it was opened, for the header line.
    var reason: Reason = .general

    enum Reason {
        case general, onboarding, secondHealthHabit
    }

    @Environment(\.dismiss) private var dismiss
    @State private var purchases = Purchases.shared

    var body: some View {
        SubscriptionStoreView(productIDs: [ProStatus.productIDs.yearly, ProStatus.productIDs.monthly]) {
            header
        }
        .subscriptionStoreControlStyle(.prominentPicker)
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .policies)
        .subscriptionStorePolicyDestination(url: URL(string: "https://fledgehabits.com/terms")!, for: .termsOfService)
        .subscriptionStorePolicyDestination(url: URL(string: "https://fledgehabits.com/privacy")!, for: .privacyPolicy)
        .tint(FledgeTheme.Palette.skyText)
        .safeAreaInset(edge: .bottom) {
            lifetime
        }
        .onInAppPurchaseCompletion { _, result in
            if case .success(.success) = result {
                await purchases.refresh()
                dismiss()
            }
        }
        .onChange(of: purchases.isPro) { _, isPro in
            if isPro { dismiss() }
        }
    }

    private var header: some View {
        ZStack {
            SkyBackground()
            VStack(spacing: FledgeTheme.Space.l) {
                Image(systemName: "bird.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(FledgeTheme.Palette.dawn)
                    .padding(.top, FledgeTheme.Space.xxl)
                Text("Fledge Pro")
                    .font(.largeTitle.bold())
                    .fontDesign(.rounded)
                    .foregroundStyle(FledgeTheme.Palette.ink)
                Text(subtitle)
                    .font(.headline)
                    .foregroundStyle(FledgeTheme.Palette.ink2)
                    .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: FledgeTheme.Space.m) {
                    Benefit(symbol: "heart.fill", text: "All three habits done for you by Apple Health")
                    Benefit(symbol: "lock.rectangle.on.rectangle", text: "Lock Screen, StandBy, every widget size and Control Center")
                    Benefit(symbol: "square.and.arrow.up", text: "Export your history and choose an app icon")
                }
                .padding(.horizontal, FledgeTheme.screenMargin)
                Text("Three habits stay free forever.")
                    .font(.footnote)
                    .foregroundStyle(FledgeTheme.Palette.ink2)
            }
            .padding(.bottom, FledgeTheme.Space.l)
        }
    }

    private var subtitle: String {
        switch reason {
        case .general, .onboarding: "Let all three habits complete themselves."
        case .secondHealthHabit: "Free includes one habit from Apple Health. Pro does all three."
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
}

private struct Benefit: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(text).foregroundStyle(FledgeTheme.Palette.ink)
        } icon: {
            Image(systemName: symbol).foregroundStyle(FledgeTheme.Palette.skyText)
        }
        .font(.subheadline)
    }
}

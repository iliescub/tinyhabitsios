import SwiftUI
import SwiftData
import HabitCore
import FledgeUI

/// First run (docs/DESIGN.md §6.6): Promise → Pick up to 3 → Connect Health → Reminders & widget → Paywall → Today.
/// Under a minute; asks for nothing the app doesn't use.
struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(\.modelContext) private var context
    @State private var step: Step = .promise
    @State private var pack: Pack?
    @State private var picked: [Pack.Template] = []
    @State private var healthConnected = false
    @State private var remindersOn = false
    @State private var showPaywall = false
    @State private var paywallForLockedTile = false
    @State private var purchases = Purchases.shared

    enum Step: Int, CaseIterable { case promise, pick, health, reminders }

    private var pickedAuto: [Pack.Template] { picked.filter { $0.source.isAuto } }

    var body: some View {
        ZStack {
            SkyBackground().ignoresSafeArea()
            VStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                    .id(step)
                footer
            }
        }
        .animation(.snappy, value: step)
        .task { pack = try? PackLibrary.essentials() }
        .sheet(isPresented: $showPaywall, onDismiss: paywallDismissed) {
            PaywallView(reason: paywallForLockedTile ? .secondHealthHabit : .onboarding)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .promise: promise
        case .pick: pick
        case .health: health
        case .reminders: reminders
        }
    }

    // MARK: Screens

    private var promise: some View {
        VStack(spacing: FledgeTheme.Space.xl) {
            Spacer()
            PromiseAnimation()
            Text("Three habits.\nDone for you.\nThen they fly.")
                .font(.largeTitle.bold())
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)
                .foregroundStyle(FledgeTheme.Palette.ink)
            Text("Fledge fills in your habits from Apple Health, and lets them go once they stick.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(FledgeTheme.Palette.ink2)
                .padding(.horizontal, FledgeTheme.Space.xxl)
            Spacer()
        }
    }

    private var pick: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FledgeTheme.Space.l) {
                Text("Pick up to three")
                    .font(.largeTitle.bold())
                    .fontDesign(.rounded)
                    .foregroundStyle(FledgeTheme.Palette.ink)
                Text("\(picked.count) of 3 chosen. You can change targets later.")
                    .font(.subheadline)
                    .foregroundStyle(FledgeTheme.Palette.ink2)
                if let pack {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: FledgeTheme.Space.m)], spacing: FledgeTheme.Space.m) {
                        ForEach(pack.templates, id: \.name) { template in
                            tile(template)
                        }
                    }
                }
            }
            .padding(FledgeTheme.screenMargin)
        }
    }

    private func tile(_ template: Pack.Template) -> some View {
        let isPicked = picked.contains { $0.name == template.name }
        let isLocked = !isPicked && template.source.isAuto
            && !ProPolicy.canAddAutoHabit(isPro: purchases.isPro, activeAutoCount: pickedAuto.count)
        return Button {
            if isPicked {
                picked.removeAll { $0.name == template.name }
            } else if isLocked {
                paywallForLockedTile = true
                showPaywall = true
            } else if picked.count < SlotPolicy.maxActive {
                picked.append(template)
            }
        } label: {
            TemplateTile(template: template)
                .overlay(alignment: .topTrailing) {
                    if isPicked {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(FledgeTheme.Palette.skyText)
                            .padding(FledgeTheme.Space.s)
                    } else if isLocked {
                        Text("Pro")
                            .font(.caption.bold())
                            .padding(.horizontal, FledgeTheme.Space.s)
                            .padding(.vertical, 2)
                            .background(FledgeTheme.Palette.gold.opacity(0.2), in: .capsule)
                            .foregroundStyle(FledgeTheme.Palette.ink)
                            .padding(FledgeTheme.Space.s)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: FledgeTheme.Radius.tile)
                        .strokeBorder(isPicked ? FledgeTheme.Palette.skyText : .clear, lineWidth: 2)
                }
                .opacity(!isPicked && picked.count >= SlotPolicy.maxActive ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
        .accessibilityHint(isLocked ? "Fledge Pro" : "")
    }

    private var health: some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.xl) {
            Spacer()
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 64))
                .foregroundStyle(FledgeTheme.Palette.skyText)
            Text("Connect Apple Health")
                .font(.largeTitle.bold())
                .fontDesign(.rounded)
                .foregroundStyle(FledgeTheme.Palette.ink)
            VStack(alignment: .leading, spacing: FledgeTheme.Space.m) {
                Label("Reads only what \(pickedAuto.map(\.name).formatted(.list(type: .and))) need", systemImage: "eye")
                Label("Stays on your iPhone. No account.", systemImage: "lock.fill")
                Label("You choose what to share on the next screen", systemImage: "hand.raised.fill")
            }
            .font(.body)
            .foregroundStyle(FledgeTheme.Palette.ink)
            if healthConnected {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(FledgeTheme.Palette.meadow)
            }
            Spacer()
        }
        .padding(.horizontal, FledgeTheme.screenMargin)
    }

    private var reminders: some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.xl) {
            Spacer()
            Text("Check in without opening the app")
                .font(.largeTitle.bold())
                .fontDesign(.rounded)
                .foregroundStyle(FledgeTheme.Palette.ink)
            WidgetHint()
            Toggle(isOn: $remindersOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remind me at 7 PM").font(.headline)
                    Text("Only if a habit isn't done yet. Change the time per habit later.")
                        .font(.footnote)
                        .foregroundStyle(FledgeTheme.Palette.ink2)
                }
            }
            .padding(FledgeTheme.Space.l)
            .background(FledgeTheme.Palette.card, in: .rect(cornerRadius: FledgeTheme.Radius.tile))
            Spacer()
        }
        .padding(.horizontal, FledgeTheme.screenMargin)
    }

    // MARK: Footer and flow

    private var footer: some View {
        VStack(spacing: FledgeTheme.Space.m) {
            PrimaryActionButton(title: primaryTitle, systemImage: "arrow.right", action: next)
                .disabled(step == .pick && picked.isEmpty)
            HStack(spacing: 6) {
                ForEach(visibleSteps, id: \.self) { s in
                    Circle()
                        .fill(s == step ? FledgeTheme.Palette.skyText : FledgeTheme.Palette.hairline)
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityHidden(true)
            if step == .health {
                Button("Not now — track them by tapping") {
                    picked = picked.map { $0.source.isAuto ? manual($0) : $0 }
                    step = .reminders
                }
                .font(.footnote)
            }
        }
        .padding(.bottom, FledgeTheme.Space.l)
    }

    private var visibleSteps: [Step] {
        pickedAuto.isEmpty && step != .health ? Step.allCases.filter { $0 != .health } : Step.allCases
    }

    private var primaryTitle: String {
        switch step {
        case .promise: "Start"
        case .pick: picked.isEmpty ? "Pick at least one" : "Continue"
        case .health: healthConnected ? "Continue" : "Connect"
        case .reminders: "Finish"
        }
    }

    private func next() {
        switch step {
        case .promise:
            step = .pick
        case .pick:
            step = pickedAuto.isEmpty ? .reminders : .health
        case .health:
            if healthConnected {
                step = .reminders
            } else {
                Task { await connectHealth() }
            }
        case .reminders:
            Task {
                if remindersOn { await Reminders.requestAuthorizationIfNeeded() }
                createHabits()
                if purchases.isPro {
                    onFinish()
                } else {
                    paywallForLockedTile = false
                    showPaywall = true
                }
            }
        }
    }

    private func connectHealth() async {
        for template in pickedAuto {
            _ = await HealthSync.shared?.prepare(source: template.source, unit: template.unit)
        }
        healthConnected = true
        step = .reminders
    }

    private func createHabits() {
        for (index, template) in picked.enumerated() {
            var draft = HabitDraft(template: template, colorKey: FledgeTheme.defaultColorKey(forSlot: index), packID: pack?.id ?? "essentials")
            if remindersOn { draft.reminderMinutes = 19 * 60 }
            _ = try? context.addHabit(draft: draft)
        }
        AppRefresh.afterWrite(context: context, structural: true)
    }

    private func paywallDismissed() {
        if !paywallForLockedTile { onFinish() }
        paywallForLockedTile = false
    }

    private func manual(_ template: Pack.Template) -> Pack.Template {
        Pack.Template(name: template.name, symbol: template.symbol, source: .manual, target: 1, unit: "times", perWeek: template.perWeek)
    }
}

/// A ring that fills by itself, then becomes the bird.
private struct PromiseAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fill = 0.0
    @State private var flown = false

    var body: some View {
        ZStack {
            if flown {
                Image(systemName: "bird.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(FledgeTheme.Palette.dawn)
                    .transition(.scale.combined(with: .opacity))
            } else {
                HabitRing(fraction: fill, status: fill >= 1 ? .done : .pending, color: FledgeTheme.Palette.dawn, symbol: "figure.walk", size: 120, lineWidth: 12)
                    .transition(.opacity)
            }
        }
        .frame(height: 140)
        .accessibilityHidden(true)
        .task {
            if reduceMotion {
                fill = 1
                return
            }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.easeInOut(duration: 1.4)) { fill = 1 }
            try? await Task.sleep(for: .milliseconds(1700))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { flown = true }
        }
    }
}

/// Static illustration of the small widget with a how-to line.
private struct WidgetHint: View {
    var body: some View {
        HStack(spacing: FledgeTheme.Space.l) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    HabitRing(fraction: 0.7, status: .pending, color: FledgeTheme.Palette.dawn, symbol: "figure.walk", size: 34, lineWidth: 4)
                    HabitRing(fraction: 1, status: .done, color: FledgeTheme.Palette.sky, symbol: "checkmark", size: 34, lineWidth: 4)
                }
                HStack(spacing: 6) {
                    HabitRing(fraction: 0.3, status: .pending, color: FledgeTheme.Palette.meadow, symbol: "brain.head.profile", size: 34, lineWidth: 4)
                    Text("1/3").font(.headline.monospacedDigit()).frame(width: 34)
                }
            }
            .padding(FledgeTheme.Space.m)
            .background(FledgeTheme.Palette.card, in: .rect(cornerRadius: 20))
            .accessibilityHidden(true)
            Text("Touch and hold your Home Screen, tap Edit › Add Widget, and choose Fledge.")
                .font(.subheadline)
                .foregroundStyle(FledgeTheme.Palette.ink2)
        }
    }
}

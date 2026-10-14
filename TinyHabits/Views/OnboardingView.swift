import SwiftUI
import SwiftData
import HabitCore
import FledgeUI

/// First run (docs/DESIGN.md §6.6, v2 in UX-11): Promise → Pick up to 3 → Connect Health → Reminders & widget → Paywall → Today.
/// Under a minute; asks for nothing the app doesn't use. A progress bar and a back button sit on top of every step.
struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(\.modelContext) private var context
    @State private var step: Step = .promise
    @State private var goingBack = false
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
                topBar
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.asymmetric(
                        insertion: .move(edge: goingBack ? .leading : .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .id(step)
                footer
            }
        }
        .animation(.snappy, value: step)
        .task {
            pack = try? PackLibrary.essentials()
            #if DEBUG
            openDemoStep()
            #endif
        }
        .sheet(isPresented: $showPaywall, onDismiss: paywallDismissed) {
            PaywallView(reason: paywallForLockedTile ? .secondHealthHabit : .onboarding)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .promise: FittingScroll { promise }
        case .pick: pick
        case .health: FittingScroll { health }
        case .reminders: FittingScroll { reminders }
        }
    }

    // MARK: Top bar

    /// Back button and a segmented progress bar (UX-11). The Health step only counts when a Health habit is picked.
    private var topBar: some View {
        HStack(spacing: FledgeTheme.Space.m) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 36, height: 36)
                    .background(FledgeTheme.Palette.card.opacity(0.7), in: .circle)
                    .foregroundStyle(FledgeTheme.Palette.ink)
            }
            .buttonStyle(.plain)
            .opacity(step == .promise ? 0 : 1)
            .disabled(step == .promise)
            .accessibilityLabel("Back")

            HStack(spacing: 6) {
                ForEach(visibleSteps, id: \.self) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? FledgeTheme.Palette.ink : FledgeTheme.Palette.ink.opacity(0.12))
                        .frame(height: 5)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text("Step \((visibleSteps.firstIndex(of: step) ?? 0) + 1) of \(visibleSteps.count)"))

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, FledgeTheme.screenMargin)
        .padding(.top, FledgeTheme.Space.s)
        .animation(.snappy, value: visibleSteps)
    }

    // MARK: Screens

    private var promise: some View {
        VStack(spacing: FledgeTheme.Space.xl) {
            Spacer()
            PromiseAnimation()
            Text("Three habits.\nDone for you.\nThen they fly.")
                .font(FledgeTheme.Typeface.title)
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
                VStack(alignment: .leading, spacing: FledgeTheme.Space.xs) {
                    Text("Pick up to three")
                        .font(FledgeTheme.Typeface.title)
                        .foregroundStyle(FledgeTheme.Palette.ink)
                    Text("Fewer is fine. You can change goals later.")
                        .font(.subheadline)
                        .foregroundStyle(FledgeTheme.Palette.ink2)
                }
                if let pack {
                    pickGroup("Done for you · Apple Health", templates: pack.templates.filter { $0.source.isAuto })
                    pickGroup("Tap to log", templates: pack.templates.filter { !$0.source.isAuto })
                }
            }
            .padding(.horizontal, FledgeTheme.screenMargin)
            .padding(.vertical, FledgeTheme.Space.l)
        }
    }

    private func pickGroup(_ title: String, templates: [Pack.Template]) -> some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.s) {
            Text(title).fledgeEyebrow()
            VStack(spacing: 0) {
                ForEach(Array(templates.enumerated()), id: \.element.name) { index, template in
                    pickRow(template)
                    if index < templates.count - 1 {
                        Divider().padding(.leading, 64)
                    }
                }
            }
            .fledgeCard(cornerRadius: FledgeTheme.Radius.tile)
        }
    }

    private func pickRow(_ template: Pack.Template) -> some View {
        let isPicked = picked.contains { $0.name == template.name }
        let isLocked = !isPicked && template.source.isAuto
            && !ProPolicy.canAddAutoHabit(isPro: purchases.isPro, activeAutoCount: pickedAuto.count)
        let isFull = !isPicked && picked.count >= SlotPolicy.maxActive
        return Button {
            if isPicked {
                picked.removeAll { $0.name == template.name }
            } else if isLocked {
                paywallForLockedTile = true
                showPaywall = true
            } else if !isFull {
                picked.append(template)
            }
        } label: {
            TemplateRow(
                symbol: template.symbol,
                color: FledgeTheme.habitColor(colorKey(for: template)),
                title: template.name,
                subtitle: TemplateStyle.targetText(for: template),
                trailing: isLocked ? .locked : .selectable(isPicked)
            )
            .opacity(isFull ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isPicked)
        .accessibilityHint(isLocked ? "Needs Fledge Pro" : isFull ? "Your nest holds three" : "")
    }

    private var health: some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.xl) {
            Spacer()
            Image(systemName: "heart.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(
                    LinearGradient(colors: [Color(red: 1, green: 0.38, blue: 0.45), Color(red: 1, green: 0.23, blue: 0.33)], startPoint: .top, endPoint: .bottom),
                    in: .rect(cornerRadius: 18, style: .continuous)
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: FledgeTheme.Space.xs) {
                Text("Connect Apple Health")
                    .font(FledgeTheme.Typeface.title)
                    .foregroundStyle(FledgeTheme.Palette.ink)
                Text("So \(pickedAuto.map(\.name).formatted(.list(type: .and))) can fill in by themselves.")
                    .font(.subheadline)
                    .foregroundStyle(FledgeTheme.Palette.ink2)
            }
            VStack(alignment: .leading, spacing: 0) {
                promiseRow("eye", FledgeTheme.Palette.sky, "Reads only what your habits need", "Nothing else, and never writes")
                Divider().padding(.leading, 64)
                promiseRow("lock.fill", FledgeTheme.Palette.meadow, "Stays on your iPhone", "No account, no cloud copy of Health data")
                Divider().padding(.leading, 64)
                promiseRow("hand.raised.fill", FledgeTheme.Palette.gold, "You choose", "Pick exactly what to share on the next screen")
            }
            .fledgeCard(cornerRadius: FledgeTheme.Radius.tile)
            if healthConnected {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(FledgeTheme.Palette.meadow)
            }
            Spacer()
        }
        .padding(.horizontal, FledgeTheme.screenMargin)
    }

    private func promiseRow(_ symbol: String, _ color: Color, _ title: String, _ detail: String) -> some View {
        TemplateRow(symbol: symbol, color: color, title: title, subtitle: detail, trailing: .none)
    }

    private var reminders: some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.xl) {
            Spacer()
            VStack(alignment: .leading, spacing: FledgeTheme.Space.xs) {
                Text("Check in without opening the app")
                    .font(FledgeTheme.Typeface.title)
                    .foregroundStyle(FledgeTheme.Palette.ink)
                Text("Add the widget, and let Fledge remind you only when something is left.")
                    .font(.subheadline)
                    .foregroundStyle(FledgeTheme.Palette.ink2)
            }
            WidgetHint(colors: pickedColors)
            Toggle(isOn: $remindersOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remind me at 7 PM").font(.headline)
                    Text("Only if a habit isn't done yet. Change the time per habit later.")
                        .font(.footnote)
                        .foregroundStyle(FledgeTheme.Palette.ink2)
                }
            }
            .tint(FledgeTheme.Palette.meadow)
            .padding(FledgeTheme.Space.l)
            .fledgeCard(cornerRadius: FledgeTheme.Radius.tile)
            Spacer()
        }
        .padding(.horizontal, FledgeTheme.screenMargin)
    }

    // MARK: Footer and flow

    private var footer: some View {
        VStack(spacing: FledgeTheme.Space.m) {
            if step == .pick {
                pickSummary
            }
            PrimaryActionButton(title: primaryTitle, systemImage: "arrow.right", action: next)
                .disabled(step == .pick && picked.isEmpty)
            if step == .health {
                Button("Not now — track them by tapping") {
                    picked = picked.map { $0.source.isAuto ? manual($0) : $0 }
                    goingBack = false
                    step = .reminders
                }
                .font(.footnote)
                .tint(FledgeTheme.Palette.skyText)
            }
        }
        .padding(.top, FledgeTheme.Space.s)
        .padding(.bottom, FledgeTheme.Space.l)
    }

    /// "2 of 3 chosen" with the nest filling in the picked colours (UX-11).
    private var pickSummary: some View {
        HStack(spacing: FledgeTheme.Space.m) {
            NestGlyph(rings: pickedColors.map { NestGlyph.Ring(fraction: 1, status: .done, color: $0) })
                .frame(width: 34, height: 34)
            Text(picked.isEmpty ? "Nothing chosen yet" : "\(picked.count) of \(SlotPolicy.maxActive) chosen")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FledgeTheme.Palette.ink)
                .contentTransition(.numericText())
            Spacer(minLength: 0)
            Text(picked.map(\.name).formatted(.list(type: .and)))
                .font(.footnote)
                .foregroundStyle(FledgeTheme.Palette.ink2)
                .lineLimit(1)
        }
        .padding(.horizontal, FledgeTheme.Space.l)
        .padding(.vertical, FledgeTheme.Space.m)
        .fledgeCard(cornerRadius: FledgeTheme.Radius.tile)
        .padding(.horizontal, FledgeTheme.screenMargin)
        .animation(.snappy, value: picked.count)
        .accessibilityElement(children: .combine)
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
        goingBack = false
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

    private func back() {
        goingBack = true
        switch step {
        case .promise: break
        case .pick: step = .promise
        case .health: step = .pick
        case .reminders: step = pickedAuto.isEmpty ? .pick : .health
        }
    }

    private func connectHealth() async {
        for template in pickedAuto {
            _ = await HealthSync.shared?.prepare(source: template.source, unit: template.unit)
        }
        healthConnected = true
        step = .reminders
    }

    /// Each pick keeps its template colour unless an earlier pick took it (`TemplateStyle.preferredColorKey`).
    private var pickedColorKeys: [String] {
        var taken: Set<String> = []
        return picked.enumerated().map { index, template in
            let key = TemplateStyle.preferredColorKey(for: template, taken: taken, slot: index)
            taken.insert(key)
            return key
        }
    }

    private var pickedColors: [Color] { pickedColorKeys.map(FledgeTheme.habitColor) }

    private func colorKey(for template: Pack.Template) -> String {
        if let index = picked.firstIndex(where: { $0.name == template.name }) {
            return pickedColorKeys[index]
        }
        return TemplateStyle.colorKey(for: template)
    }

    private func createHabits() {
        for (template, colorKey) in zip(picked, pickedColorKeys) {
            var draft = HabitDraft(template: template, colorKey: colorKey, packID: pack?.id ?? "essentials")
            if remindersOn { draft.reminderMinutes = 19 * 60 }
            _ = try? context.addHabit(draft: draft)
        }
        AppRefresh.afterWrite(context: context, structural: true)
    }

    private func paywallDismissed() {
        if !paywallForLockedTile { onFinish() }
        paywallForLockedTile = false
    }

    #if DEBUG
    /// `-FledgeDemoScreen onboarding-pick|-health|-reminders` starts at that step with Walk and Read picked.
    private func openDemoStep() {
        guard let screen = DemoData.screen, screen.hasPrefix("onboarding-"), let pack else { return }
        picked = pack.templates.filter { ["Walk", "Read"].contains($0.name) }
        switch screen {
        case "onboarding-pick": step = .pick
        case "onboarding-health": step = .health
        case "onboarding-reminders": step = .reminders
        default: break
        }
    }
    #endif

    private func manual(_ template: Pack.Template) -> Pack.Template {
        Pack.Template(name: template.name, symbol: template.symbol, source: .manual, target: 1, unit: "times", perWeek: template.perWeek)
    }
}

/// Centred on the screen when it fits; scrolls at large Dynamic Type sizes instead of truncating.
struct FittingScroll<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

/// Three rings fill by themselves, one after another; then the fledgling hops out of the nest.
private struct PromiseAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fills: [Double] = [0, 0, 0]
    @State private var flown = false

    private let rings: [(Color, String)] = [
        (FledgeTheme.Palette.dawn, "figure.walk"),
        (FledgeTheme.Palette.sky, "book.fill"),
        (FledgeTheme.Palette.meadow, "brain.head.profile"),
    ]

    var body: some View {
        ZStack {
            nest
                .scaleEffect(flown ? 0.55 : 1)
                .offset(y: flown ? 52 : 0)
                .opacity(flown ? 0.35 : 1)
            if flown {
                FledgeBird(.flying)
                    .frame(width: 130)
                    .shadow(color: FledgeTheme.Palette.ink.opacity(0.15), radius: 12, y: 8)
                    .offset(y: -18)
                    .transition(.scale(scale: 0.3, anchor: .bottom).combined(with: .opacity))
            }
        }
        .frame(height: 180)
        .accessibilityHidden(true)
        .task {
            if reduceMotion {
                fills = [1, 1, 1]
                flown = true
                return
            }
            try? await Task.sleep(for: .milliseconds(300))
            for index in rings.indices {
                withAnimation(.easeInOut(duration: 0.7)) { fills[index] = 1 }
                try? await Task.sleep(for: .milliseconds(450))
            }
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) { flown = true }
        }
    }

    private var nest: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                ring(0)
                ring(1)
            }
            ring(2)
        }
    }

    private func ring(_ index: Int) -> some View {
        HabitRing(
            fraction: fills[index], status: fills[index] >= 1 ? .done : .pending,
            color: rings[index].0, symbol: rings[index].1, size: 72, lineWidth: 8
        )
    }
}

/// The small widget, drawn with the same nest glyph the widget uses, plus how to add it.
private struct WidgetHint: View {
    let colors: [Color]

    var body: some View {
        HStack(spacing: FledgeTheme.Space.l) {
            VStack(spacing: FledgeTheme.Space.s) {
                NestGlyph(rings: sample)
                    .frame(width: 74, height: 74)
                Text("1/\(max(sample.count, 1))")
                    .font(.system(.headline, design: .rounded, weight: .heavy).monospacedDigit())
                    .foregroundStyle(FledgeTheme.Palette.ink)
            }
            .frame(width: 128, height: 128)
            .fledgeCard(cornerRadius: 26)
            .accessibilityHidden(true)
            Text("Touch and hold your Home Screen, tap Edit › Add Widget, and choose Fledge.")
                .font(.subheadline)
                .foregroundStyle(FledgeTheme.Palette.ink2)
        }
    }

    /// The picked colours at different stages, so the preview looks like a real day.
    private var sample: [NestGlyph.Ring] {
        let palette = colors.isEmpty ? [FledgeTheme.Palette.dawn, FledgeTheme.Palette.sky, FledgeTheme.Palette.meadow] : colors
        let fractions = [1.0, 0.6, 0.25]
        return palette.enumerated().map { index, color in
            NestGlyph.Ring(fraction: fractions[index % 3], status: index == 0 ? .done : .pending, color: color)
        }
    }
}

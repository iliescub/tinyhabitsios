import SwiftUI
import SwiftData
import HabitCore
import FledgeUI

/// First run (RES-9, spec › "Update 2026-11-01"): Resolution → Habits → If-then plans → Letter to December → Connect Health →
/// Reminders & widget → Paywall → Today. Asks for nothing the app doesn't use. A progress bar and a back button sit on top of
/// every step; the Health step only appears when a Health habit is picked.
struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var step: Step = .resolution
    @State private var goingBack = false
    @State private var pack: Pack?
    @State private var picked: [Pack.Template] = []
    @State private var healthConnected = false
    /// HEAD-1: last 30 days per picked Health habit, and the starting goals the user chose from them.
    @State private var baselines: [String: [Double]] = [:]
    @State private var startGoals: [String: Double] = [:]
    @State private var remindersOn = false
    @State private var showPaywall = false
    @State private var paywallForLockedTile = false
    @State private var purchases = Purchases.shared
    /// RES-2/3: the resolution in the user's words and the template it matches (picked or typed).
    @State private var resolutionTemplates: [ResolutionTemplate] = []
    @State private var resolutionText = ""
    @State private var chosenTemplate: ResolutionTemplate?
    /// RES-4: the "if" of each picked habit's plan, by habit name.
    @State private var cues: [String: String] = [:]
    /// RES-6: why it matters, and the letter that opens on Dec 1.
    @State private var why = ""
    @State private var letter = ""
    @FocusState private var resolutionFieldFocused: Bool
    /// The template whose habits were last pre-picked, so going back and forth doesn't undo the user's own picks.
    @State private var lastPrefill: String?

    enum Step: Int, CaseIterable { case resolution, pick, plan, letter, health, reminders, seal }

    private var resolutionYear: Int { ResolutionYear.year(startingOn: DayKey(.now)) }

    /// The template the typed text points to; an explicit pick wins.
    private var matchedTemplate: ResolutionTemplate? {
        if let chosenTemplate, chosenTemplate.title == resolutionText { return chosenTemplate }
        return ResolutionLibrary.match(resolutionText, in: resolutionTemplates)
    }

    private var pickedAuto: [Pack.Template] { picked.filter { $0.source.isAuto } }

    var body: some View {
        ZStack {
            SkyBackground().ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .move(edge: goingBack ? .leading : .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .id(step)
                footer
            }
            // iPad: keep the flow at a readable width, centred on the sky (docs/DESIGN.md §12).
            .frame(maxWidth: NestLayout.readableWidth)
        }
        .animation(.snappy, value: step)
        .task {
            pack = try? PackLibrary.essentials()
            resolutionTemplates = (try? ResolutionLibrary.all()) ?? []
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
        case .resolution: resolution
        case .pick: pick
        case .plan: plan
        case .letter: FittingScroll { letterStep }
        case .health: FittingScroll { health }
        case .reminders: FittingScroll { reminders }
        case .seal: FittingScroll { seal }
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
            .opacity(step == .resolution ? 0 : 1)
            .disabled(step == .resolution)
            .accessibilityLabel("Back")

            HStack(spacing: 6) {
                ForEach(visibleSteps, id: \.self) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? FledgeTheme.Palette.ink : FledgeTheme.Palette.ink.opacity(0.12))
                        .frame(height: 5)
                }
            }
            .frame(minHeight: 44)
            .accessibilityElement()
            .accessibilityLabel(Text("Step \((visibleSteps.firstIndex(of: step) ?? 0) + 1) of \(visibleSteps.count)"))
            .accessibilityAddTraits(.isStaticText)

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, FledgeTheme.screenMargin)
        .padding(.top, FledgeTheme.Space.s)
        .animation(.snappy, value: visibleSteps)
    }

    // MARK: Screens

    /// Step 1 (RES-2/3): the resolution, picked from common ones or typed. "Stop …" wording gets an approach suggestion.
    private var resolution: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FledgeTheme.Space.l) {
                HStack(alignment: .bottom, spacing: FledgeTheme.Space.m) {
                    VStack(alignment: .leading, spacing: FledgeTheme.Space.xs) {
                        Text("Your \(String(resolutionYear)) resolution")
                            .font(FledgeTheme.Typeface.title)
                            .foregroundStyle(FledgeTheme.Palette.ink)
                        Text("One resolution, up to three small habits. Apple Health fills in what it can, and each habit flies once it sticks.")
                            .font(.subheadline)
                            .foregroundStyle(FledgeTheme.Palette.ink2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if !dynamicTypeSize.isAccessibilitySize {
                        FledgeBird(.flying)
                            .frame(width: 64)
                            .accessibilityHidden(true)
                    }
                }

                TextField("In \(String(resolutionYear)) I want to…", text: $resolutionText)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(FledgeTheme.Palette.ink)
                    .focused($resolutionFieldFocused)
                    .submitLabel(.done)
                    .padding(FledgeTheme.Space.l)
                    .fledgeCard(cornerRadius: FledgeTheme.Radius.tile)
                    .onChange(of: resolutionText) { _, text in
                        if text.count > ResolutionDraft.maxTextLength { resolutionText = String(text.prefix(ResolutionDraft.maxTextLength)) }
                    }
                    .accessibilityLabel("Your resolution")

                if let hint = framingHint {
                    hint
                }

                VStack(alignment: .leading, spacing: FledgeTheme.Space.s) {
                    Text("Common resolutions").fledgeEyebrow()
                    VStack(spacing: 0) {
                        ForEach(Array(resolutionTemplates.enumerated()), id: \.element.id) { index, template in
                            Button {
                                choose(template)
                            } label: {
                                TemplateRow(
                                    symbol: template.symbol,
                                    color: FledgeTheme.habitColor(template.accent),
                                    title: template.title,
                                    subtitle: template.habits.map(\.name).formatted(.list(type: .and)),
                                    trailing: .selectable(matchedTemplate?.id == template.id)
                                )
                            }
                            .buttonStyle(.plain)
                            .sensoryFeedback(.selection, trigger: matchedTemplate?.id == template.id)
                            if index < resolutionTemplates.count - 1 {
                                Divider().padding(.leading, 64)
                            }
                        }
                    }
                    .fledgeCard(cornerRadius: FledgeTheme.Radius.tile)
                }
            }
            .padding(.horizontal, FledgeTheme.screenMargin)
            .padding(.vertical, FledgeTheme.Space.l)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// RES-3: a calm note under a typed resolution. Avoidance wording → the approach version; otherwise the plan it matches.
    private var framingHint: AnyView? {
        let text = resolutionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, chosenTemplate?.title != text else { return nil }
        let match = matchedTemplate
        let avoidance = ResolutionFraming.isAvoidance(text)
        guard avoidance || match != nil else { return nil }
        let message: String = if avoidance, let match {
            "Resolutions about starting something are kept more often than ones about stopping. Plan it as \u{201C}\(match.title)\u{201D}?"
        } else if avoidance {
            "Resolutions about starting something are kept more often than ones about stopping. What will you do instead?"
        } else {
            "Sounds like \u{201C}\(match?.title ?? "")\u{201D}. We'll suggest habits for it."
        }
        return AnyView(
            HStack(alignment: .top, spacing: FledgeTheme.Space.m) {
                Image(systemName: avoidance ? "arrow.uturn.right.circle.fill" : "sparkles")
                    .font(.title3)
                    .foregroundStyle(FledgeTheme.Palette.skyText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: FledgeTheme.Space.s) {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(FledgeTheme.Palette.ink)
                    if avoidance, let match {
                        Button("Use \u{201C}\(match.title)\u{201D}") { choose(match) }
                            .font(.footnote.weight(.semibold))
                            .tint(FledgeTheme.Palette.skyText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(FledgeTheme.Space.l)
            .fledgeCard(cornerRadius: FledgeTheme.Radius.tile, tint: FledgeTheme.Palette.sky)
            .accessibilityElement(children: .combine)
        )
    }

    private func choose(_ template: ResolutionTemplate) {
        chosenTemplate = template
        resolutionText = template.title
        resolutionFieldFocused = false
    }

    private var pick: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FledgeTheme.Space.l) {
                VStack(alignment: .leading, spacing: FledgeTheme.Space.xs) {
                    Text("Your habits")
                        .font(FledgeTheme.Typeface.title)
                        .foregroundStyle(FledgeTheme.Palette.ink)
                    Text("Up to three small habits that add up to \u{201C}\(resolutionText.trimmingCharacters(in: .whitespaces))\u{201D}. Fewer is fine.")
                        .font(.subheadline)
                        .foregroundStyle(FledgeTheme.Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                let suggested = suggestedTemplates
                if !suggested.isEmpty {
                    pickGroup("For your resolution", templates: suggested)
                }
                if let pack {
                    let others = pack.templates.filter { template in !suggested.contains { $0.name == template.name } }
                    if DeviceInfo.isHealthAvailable {
                        pickGroup("Done for you · Apple Health", templates: others.filter { $0.source.isAuto })
                        pickGroup("Tap to log", templates: others.filter { !$0.source.isAuto })
                    } else {
                        // No Apple Health on this device: every template is logged by tapping.
                        pickGroup("Tap to log", templates: others.map(\.tapToLog))
                    }
                }
            }
            .padding(.horizontal, FledgeTheme.screenMargin)
            .padding(.vertical, FledgeTheme.Space.l)
        }
    }

    /// The matched resolution's habits (tap-to-log versions when Apple Health isn't available).
    private var suggestedTemplates: [Pack.Template] {
        let habits = matchedTemplate?.habits ?? []
        return DeviceInfo.isHealthAvailable ? habits : habits.map(\.tapToLog)
    }

    /// Step 3 (RES-4): an if-then plan per picked habit, prefilled from the template.
    private var plan: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FledgeTheme.Space.l) {
                VStack(alignment: .leading, spacing: FledgeTheme.Space.xs) {
                    Text("When will you do it?")
                        .font(FledgeTheme.Typeface.title)
                        .foregroundStyle(FledgeTheme.Palette.ink)
                    Text("Tie each habit to something you already do. Plans like \u{201C}After lunch, walk\u{201D} make a habit far more likely to happen.")
                        .font(.subheadline)
                        .foregroundStyle(FledgeTheme.Palette.ink2)
                }
                VStack(spacing: 0) {
                    ForEach(Array(picked.enumerated()), id: \.element.name) { index, template in
                        planRow(template)
                        if index < picked.count - 1 { Divider().padding(.leading, 64) }
                    }
                }
                .fledgeCard(cornerRadius: FledgeTheme.Radius.tile)
            }
            .padding(.horizontal, FledgeTheme.screenMargin)
            .padding(.vertical, FledgeTheme.Space.l)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func planRow(_ template: Pack.Template) -> some View {
        let binding = Binding(
            get: { cues[template.name] ?? template.cue ?? "" },
            set: { cues[template.name] = String($0.prefix(HabitDraft.maxCueLength)) }
        )
        return HStack(spacing: FledgeTheme.Space.m) {
            IconSquare(symbol: template.symbol, color: FledgeTheme.habitColor(colorKey(for: template)))
            VStack(alignment: .leading, spacing: 2) {
                TextField("After…", text: binding)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(FledgeTheme.Palette.ink)
                    .submitLabel(.next)
                    .accessibilityLabel(Text("When you'll do \(template.name)"))
                Text("\(template.name) · \(TemplateStyle.targetText(for: template))")
                    .font(.footnote)
                    .foregroundStyle(FledgeTheme.Palette.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                ForEach(Self.commonCues, id: \.self) { cue in
                    Button(cue) { cues[template.name] = cue }
                }
            } label: {
                Image(systemName: "text.badge.plus")
                    .font(.title3)
                    .foregroundStyle(FledgeTheme.Palette.skyText)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(Text("Suggestions for \(template.name)"))
        }
        .padding(.horizontal, FledgeTheme.Space.l)
        .padding(.vertical, FledgeTheme.Space.m)
    }

    /// Everyday anchors for an if-then plan (RES-4).
    private static let commonCues = [
        "After my morning coffee", "After breakfast", "At lunch", "After lunch", "After work",
        "Before dinner", "After dinner", "When I get into bed", "When I plug in my phone",
    ]

    /// Step 4 (RES-6): why it matters, and a letter that stays sealed until 1 December. Skippable.
    private var letterStep: some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.l) {
            Spacer(minLength: FledgeTheme.Space.l)
            VStack(alignment: .leading, spacing: FledgeTheme.Space.xs) {
                Text("A note to December")
                    .font(FledgeTheme.Typeface.title)
                    .foregroundStyle(FledgeTheme.Palette.ink)
                Text("Why does this matter to you? It stays sealed on your \(DeviceInfo.name) and opens on 1 December, or the day your resolution is kept.")
                    .font(.subheadline)
                    .foregroundStyle(FledgeTheme.Palette.ink2)
            }
            VStack(alignment: .leading, spacing: FledgeTheme.Space.s) {
                Text("Why it matters").fledgeEyebrow()
                TextField("So I have energy for the kids after work", text: $why, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(FledgeTheme.Space.l)
                    .fledgeCard(cornerRadius: FledgeTheme.Radius.tile)
                    .onChange(of: why) { _, text in
                        if text.count > ResolutionDraft.maxWhyLength { why = String(text.prefix(ResolutionDraft.maxWhyLength)) }
                    }
            }
            VStack(alignment: .leading, spacing: FledgeTheme.Space.s) {
                Label("Sealed until December", systemImage: "envelope.fill")
                    .fledgeEyebrow()
                TextField("Dear December me…", text: $letter, axis: .vertical)
                    .lineLimit(4...8)
                    .padding(FledgeTheme.Space.l)
                    .fledgeCard(cornerRadius: FledgeTheme.Radius.tile, tint: FledgeTheme.Palette.gold)
                    .onChange(of: letter) { _, text in
                        if text.count > ResolutionDraft.maxLetterLength { letter = String(text.prefix(ResolutionDraft.maxLetterLength)) }
                    }
            }
            Spacer(minLength: FledgeTheme.Space.l)
        }
        .padding(.horizontal, FledgeTheme.screenMargin)
    }

    /// Last step (UXR-1): the whole plan on one card, then press and hold to commit to it.
    private var seal: some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.l) {
            Spacer(minLength: FledgeTheme.Space.l)
            Text("Your plan")
                .font(FledgeTheme.Typeface.title)
                .foregroundStyle(FledgeTheme.Palette.ink)
            VStack(alignment: .leading, spacing: FledgeTheme.Space.m) {
                Text(String(resolutionYear)).fledgeEyebrow()
                Text(trimmedResolution)
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(FledgeTheme.Palette.ink)
                if !why.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(why)
                        .font(.footnote.italic())
                        .foregroundStyle(FledgeTheme.Palette.ink2)
                }
                Divider()
                ForEach(Array(zip(picked, pickedColorKeys)), id: \.0.name) { template, colorKey in
                    HStack(spacing: FledgeTheme.Space.m) {
                        IconSquare(symbol: template.symbol, color: FledgeTheme.habitColor(colorKey))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(template.name).font(.body.weight(.semibold)).foregroundStyle(FledgeTheme.Palette.ink)
                            let cue = (cues[template.name] ?? template.cue ?? "").trimmingCharacters(in: .whitespaces)
                            Text(cue.isEmpty ? TemplateStyle.targetText(for: template) : "\(cue) · \(TemplateStyle.targetText(for: template))")
                                .font(.footnote)
                                .foregroundStyle(FledgeTheme.Palette.ink2)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                if !letter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label("Letter sealed until 1 December", systemImage: "envelope.fill")
                        .font(FledgeTheme.Typeface.meta)
                        .foregroundStyle(FledgeTheme.Palette.ink2)
                }
            }
            .padding(FledgeTheme.Space.l)
            .fledgeCard(cornerRadius: FledgeTheme.Radius.tile, tint: FledgeTheme.Palette.gold)
            Text("Habits fly once they stick. When all of them have, your resolution is kept.")
                .font(.footnote)
                .foregroundStyle(FledgeTheme.Palette.ink2)
            Spacer(minLength: FledgeTheme.Space.l)
        }
        .padding(.horizontal, FledgeTheme.screenMargin)
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
        .accessibilityHint(isLocked ? "Needs Yearling Pro" : isFull ? "Your nest holds three" : "")
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
            if healthConnected && !baselines.isEmpty {
                headStartCard
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    promiseRow("eye", FledgeTheme.Palette.sky, "Reads only what your habits need", "Nothing else, and never writes")
                    Divider().padding(.leading, 64)
                    promiseRow("lock.fill", FledgeTheme.Palette.meadow, "Stays on your \(DeviceInfo.name)", "No account, no cloud copy of Health data")
                    Divider().padding(.leading, 64)
                    promiseRow("hand.raised.fill", FledgeTheme.Palette.gold, "You choose", "Pick exactly what to share on the next screen")
                }
                .fledgeCard(cornerRadius: FledgeTheme.Radius.tile)
            }
            if healthConnected {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(FledgeTheme.Palette.meadow)
            }
            Spacer()
        }
        .padding(.horizontal, FledgeTheme.screenMargin)
    }

    /// HEAD-1 in onboarding: what the last 30 days say about each picked Health habit.
    private var headStartCard: some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.s) {
            Text("Your head start").fledgeEyebrow()
            VStack(spacing: 0) {
                ForEach(Array(pickedAuto.enumerated()), id: \.element.name) { index, template in
                    if let values = baselines[template.name] {
                        headStartRow(template, values: values)
                        if index < pickedAuto.count - 1 { Divider().padding(.leading, 64) }
                    }
                }
            }
            .fledgeCard(cornerRadius: FledgeTheme.Radius.tile)
        }
    }

    private func headStartRow(_ template: Pack.Template, values: [Double]) -> some View {
        let baseline = HealthBaseline(
            values: values, target: template.target,
            step: TargetSteps.step(for: template.unit), range: TargetSteps.range(for: template.unit)
        )
        let chosen = startGoals[template.name]
        let average = baseline.average.formatted(.number.precision(.fractionLength(baseline.average < 10 ? 0...1 : 0...0)))
        let summary: String = switch baseline.verdict {
        case .notEnoughData: "Not much data yet. Yearling fills it in from today."
        case .alreadyHabit: "Already a habit: \(baseline.daysMet) of 30 days. Aim higher, or swap it."
        case .withinReach: "Within reach: \(baseline.daysMet) of 30 days at your goal."
        case .startSmaller: "Usually about \(average) \(template.unit). Start a little lower."
        }
        return HStack(spacing: FledgeTheme.Space.m) {
            IconSquare(symbol: template.symbol, color: FledgeTheme.habitColor(colorKey(for: template)))
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name).font(.body.weight(.semibold)).foregroundStyle(FledgeTheme.Palette.ink)
                Text(summary).font(.footnote).foregroundStyle(FledgeTheme.Palette.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let suggested = baseline.suggestedTarget {
                let label = suggested.formatted(.number.precision(.fractionLength(suggested < 10 ? 0...1 : 0...0)))
                Button {
                    startGoals[template.name] = chosen == nil ? suggested : nil
                } label: {
                    Label(label, systemImage: chosen == nil ? "plus.circle" : "checkmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                }
                .buttonStyle(.bordered)
                .tint(chosen == nil ? FledgeTheme.Palette.ink2 : FledgeTheme.Palette.meadow)
                .accessibilityLabel(Text(chosen == nil ? "Use \(label) \(template.unit) as the goal" : "Using \(label) \(template.unit)"))
            }
        }
        .padding(.horizontal, FledgeTheme.Space.l)
        .padding(.vertical, FledgeTheme.Space.m)
        .accessibilityElement(children: .contain)
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
                Text("Add the widget, and let Yearling remind you only when something is left.")
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
            if step == .seal {
                HoldToCommitButton(title: primaryTitle, action: next)
            } else {
                PrimaryActionButton(title: primaryTitle, systemImage: "arrow.right", action: next)
                    .disabled(step == .pick && picked.isEmpty || step == .resolution && trimmedResolution.isEmpty)
            }
            if step == .letter && why.isEmpty && letter.isEmpty {
                Button("Skip for now") { next() }
                    .font(.footnote)
                    .tint(FledgeTheme.Palette.skyText)
            }
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
            Text(summaryText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FledgeTheme.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
            Spacer(minLength: 0)
            if !dynamicTypeSize.isAccessibilitySize {
                Text(picked.map(\.name).formatted(.list(type: .and)))
                    .font(.footnote)
                    .foregroundStyle(FledgeTheme.Palette.ink2)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, FledgeTheme.Space.l)
        .padding(.vertical, FledgeTheme.Space.m)
        .fledgeCard(cornerRadius: FledgeTheme.Radius.tile)
        .padding(.horizontal, FledgeTheme.screenMargin)
        .animation(.snappy, value: picked.count)
        .accessibilityElement(children: .combine)
    }

    /// "2 of 3 chosen"; just "2/3" at accessibility sizes, where the bar must stay one line.
    private var summaryText: String {
        if dynamicTypeSize.isAccessibilitySize { return "\(picked.count)/\(SlotPolicy.maxActive)" }
        return picked.isEmpty ? "Nothing chosen yet" : "\(picked.count) of \(SlotPolicy.maxActive) chosen"
    }

    private var visibleSteps: [Step] {
        pickedAuto.isEmpty && step != .health ? Step.allCases.filter { $0 != .health } : Step.allCases
    }

    private var trimmedResolution: String { resolutionText.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The template the user picked (tapped, or accepted from the hint), if the text is still its title.
    private var pickedTemplateID: String? {
        guard let chosenTemplate, chosenTemplate.title == trimmedResolution else { return nil }
        return chosenTemplate.id
    }

    private var primaryTitle: String {
        switch step {
        case .resolution: trimmedResolution.isEmpty ? "Write or pick one" : "Continue"
        case .pick: picked.isEmpty ? "Pick at least one" : "Continue"
        case .plan: "Continue"
        case .letter: "Seal it"
        case .health: healthConnected ? "Continue" : "Connect"
        case .reminders: "Continue"
        case .seal: "Commit to my resolution"
        }
    }

    private func next() {
        goingBack = false
        switch step {
        case .resolution:
            resolutionFieldFocused = false
            prefillSuggestedHabits()
            step = .pick
        case .pick:
            step = .plan
        case .plan:
            step = .letter
        case .letter:
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
                step = .seal
            }
        case .seal:
            Task {
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
        case .resolution: break
        case .pick: step = .resolution
        case .plan: step = .pick
        case .letter: step = .plan
        case .health: step = .letter
        case .reminders: step = pickedAuto.isEmpty ? .letter : .health
        case .seal: step = .reminders
        }
    }

    private func connectHealth() async {
        for template in pickedAuto {
            _ = await HealthSync.shared?.prepare(source: template.source, unit: template.unit)
        }
        // HEAD-1: stay on this step to show the head start; without any data, move on as before.
        for template in pickedAuto {
            if let values = await HeadStart.values(source: template.source, unit: template.unit) {
                baselines[template.name] = values
            }
        }
        healthConnected = true
        if baselines.isEmpty { step = .reminders }
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

    /// Picks the matched resolution's habits the first time the user lands on step 2, within the free tier's Health limit.
    private func prefillSuggestedHabits() {
        guard let id = matchedTemplate?.id, id != lastPrefill else { return }
        lastPrefill = id
        let suggested = suggestedTemplates
        picked = []
        for template in suggested where picked.count < SlotPolicy.maxActive {
            if template.source.isAuto && !ProPolicy.canAddAutoHabit(isPro: purchases.isPro, activeAutoCount: pickedAuto.count) { continue }
            picked.append(template)
        }
    }

    private func createHabits() {
        var added: [Habit] = []
        let resolution = try? context.startResolution(
            // The template's sentence replaces the user's words on Today, so only a picked template counts
            // (a typed "Learn the cello" may match Read more for suggestions, but stays the user's own).
            ResolutionDraft(text: trimmedResolution, templateID: pickedTemplateID ?? "", why: why, letter: letter),
            startDay: DayKey(.now)
        )
        for (template, colorKey) in zip(picked, pickedColorKeys) {
            var draft = HabitDraft(
                template: template, colorKey: colorKey, packID: matchedTemplate?.id ?? pack?.id ?? "essentials",
                resolutionID: resolution?.id
            )
            draft.cue = cues[template.name] ?? template.cue ?? ""
            if remindersOn { draft.reminderMinutes = 19 * 60 }
            if let goal = startGoals[template.name] { draft.target = goal }
            if let habit = try? context.addHabit(draft: draft) { added.append(habit) }
        }
        AppRefresh.afterWrite(context: context, structural: true)
        Task {
            for habit in added { await HeadStart.backfill(habit) }
        }
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
        if let sleep = resolutionTemplates.first(where: { $0.id == "sleep-better" }) {
            choose(sleep)
            prefillSuggestedHabits()
            if let read = pack.templates.first(where: { $0.name == "Read" }) { picked.append(read) }
        }
        switch screen {
        case "onboarding-pick": step = .pick
        case "onboarding-plan":
            picked = suggestedTemplates   // all three of the resolution's habits, with their cues
            step = .plan
        case "onboarding-reframe":
            chosenTemplate = nil
            resolutionText = "Stop scrolling in bed"
            step = .resolution
        case "onboarding-letter": step = .letter
        case "onboarding-seal":
            cues["Read"] = "When I get into bed"
            why = "So evenings feel like mine again"
            step = .seal
        case "onboarding-health": step = .health
        case "onboarding-headstart":
            picked = pack.templates.filter { ["Walk", "Read", "Move"].contains($0.name) }
            for template in picked where template.source.isAuto {
                baselines[template.name] = DemoData.baselineValues(for: template.source)
            }
            healthConnected = true
            step = .health
        case "onboarding-reminders": step = .reminders
        default: break
        }
    }
    #endif

    private func manual(_ template: Pack.Template) -> Pack.Template {
        template.tapToLog
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
            Text("Touch and hold your Home Screen, tap Edit › Add Widget, and choose Yearling.")
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

/// Press and hold to commit (UXR-1): the ink capsule fills from the left over 1.2 s, then a success haptic.
/// Reduce Motion and VoiceOver get a plain tap (the same action, no hold).
private struct HoldToCommitButton: View {
    let title: String
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var progress: CGFloat = 0
    @State private var committed = false

    private static let duration = 1.2

    var body: some View {
        if reduceMotion || voiceOver {
            PrimaryActionButton(title: title, systemImage: "checkmark.seal.fill", action: action)
        } else {
            Label(title, systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(FledgeTheme.Palette.onInk)
                .padding(.horizontal, FledgeTheme.Space.xl)
                .padding(.vertical, FledgeTheme.Space.l)
                .background {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(FledgeTheme.Palette.ink)
                            Capsule().fill(FledgeTheme.Palette.gold)
                                .frame(width: proxy.size.width * progress)
                        }
                    }
                }
                .clipShape(.capsule)
                .contentShape(.capsule)
                .onLongPressGesture(minimumDuration: Self.duration) {
                    committed = true
                    action()
                } onPressingChanged: { pressing in
                    withAnimation(pressing ? .linear(duration: Self.duration) : .easeOut(duration: 0.2)) {
                        progress = pressing ? 1 : 0
                    }
                }
                .sensoryFeedback(.success, trigger: committed)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Press and hold")
                .accessibilityAction { action() }
            Text("Press and hold")
                .font(.footnote)
                .foregroundStyle(FledgeTheme.Palette.ink2)
        }
    }
}

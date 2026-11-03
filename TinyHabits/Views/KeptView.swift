import SwiftUI
import SwiftData
import HabitCore
import FledgeUI

/// Kept (RES-7): shown when the last habit of a resolution flies. The year fills in gold, the letter can be opened,
/// and the moment can be shared as an image. Reduce Motion: no bird hop.
struct KeptView: View {
    let resolution: Resolution
    let day: DayKey
    let onDone: () -> Void

    @Query private var allHabits: [Habit]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var showsLetter = false
    @State private var shareImage: Image?

    private var habits: [Habit] { allHabits.filter { $0.resolutionID == resolution.id } }

    private var dots: [YearMap.Dot] {
        ResolutionHeaderModel(resolution: resolution, habits: allHabits, today: day)?.dots ?? []
    }

    private var daysText: String {
        guard let start = resolution.startDay else { return "" }
        let days = start.days(to: day) + 1
        return "\(days) \(days == 1 ? "day" : "days")"
    }

    var body: some View {
        ZStack {
            SkyBackground().ignoresSafeArea()
            FittingScroll {
                VStack(spacing: FledgeTheme.Space.xl) {
                    Spacer(minLength: FledgeTheme.Space.l)
                    FledgeBird(.flying)
                        .frame(width: 120)
                        .offset(y: appeared || reduceMotion ? 0 : 30)
                        .opacity(appeared ? 1 : 0)
                        .accessibilityHidden(true)
                    VStack(spacing: FledgeTheme.Space.xs) {
                        Text("Resolution kept").fledgeEyebrow()
                        Text(resolution.text)
                            .font(FledgeTheme.Typeface.title)
                            .foregroundStyle(FledgeTheme.Palette.ink)
                            .multilineTextAlignment(.center)
                        Text("Every habit flew. \(daysText) from the first one to the last.")
                            .font(.subheadline)
                            .foregroundStyle(FledgeTheme.Palette.ink2)
                            .multilineTextAlignment(.center)
                    }
                    YearGrid(model: YearGridModel(year: resolution.year, dots: dots), kept: true)
                        .padding(FledgeTheme.Space.l)
                        .fledgeCard(tint: FledgeTheme.Palette.gold)
                    Spacer(minLength: FledgeTheme.Space.l)
                    VStack(spacing: FledgeTheme.Space.m) {
                        if !resolution.letter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            PrimaryActionButton(title: "Open your letter", systemImage: "envelope.open.fill") { showsLetter = true }
                        }
                        HStack {
                            Button("Done", action: onDone).frame(minHeight: 44)
                            Spacer()
                            if let shareImage {
                                ShareLink(
                                    item: shareImage,
                                    subject: Text("Resolution kept"),
                                    message: Text("I kept my \(String(resolution.year)) resolution: \(resolution.text)."),
                                    preview: SharePreview("Resolution kept", image: shareImage)
                                ) {
                                    Label("Share", systemImage: "square.and.arrow.up").frame(minHeight: 44)
                                }
                            }
                        }
                        .font(.subheadline)
                        .tint(FledgeTheme.Palette.ink)
                        .padding(.horizontal, FledgeTheme.Space.s)
                    }
                    .padding(.bottom, FledgeTheme.Space.l)
                }
                .padding(.horizontal, FledgeTheme.screenMargin)
                .frame(maxWidth: NestLayout.readableWidth)
            }
        }
        .sensoryFeedback(.success, trigger: appeared)
        .sheet(isPresented: $showsLetter) { LetterView(resolution: resolution) }
        .task {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.7, dampingFraction: 0.7)) { appeared = true }
            shareImage = renderShareCard()
        }
    }

    /// 1080 × 1920 story image: the resolution, the year grid in gold, the app name.
    private func renderShareCard() -> Image? {
        let card = KeptShareCard(text: resolution.text, year: resolution.year, daysText: daysText, grid: YearGridModel(year: resolution.year, dots: dots))
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 360, height: 640)
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

/// The share image for a kept resolution (no Health values, only the days).
struct KeptShareCard: View {
    let text: String
    let year: Int
    let daysText: String
    let grid: YearGridModel

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            FledgeBird(.flying).frame(width: 80)
            Text("RESOLUTION KEPT · \(String(year))")
                .font(.caption.weight(.bold)).tracking(1.2)
                .foregroundStyle(FledgeTheme.Palette.ink2)
            Text(text)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(FledgeTheme.Palette.ink)
                .multilineTextAlignment(.center)
            Text(daysText).font(.subheadline).foregroundStyle(FledgeTheme.Palette.ink2)
            YearGrid(model: grid, kept: true)
                .padding(14)
                .background(FledgeTheme.Palette.card, in: .rect(cornerRadius: 18))
            Spacer()
            Text("Yearling").font(.system(.headline, design: .rounded, weight: .heavy)).foregroundStyle(FledgeTheme.Palette.ink)
        }
        .padding(28)
        .frame(width: 360, height: 640)
        .background(SkyBackground())
        .environment(\.colorScheme, .light)
    }
}

/// Start a resolution after onboarding (RES-1): after one was kept or let go, or for people coming from Fledge with
/// habits but no resolution. The habits already in the nest join it.
struct NewResolutionSheet: View {
    let day: DayKey

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ResolutionDraft()
    @State private var templates: [ResolutionTemplate] = []
    @State private var errorMessage: String?

    private var year: Int { ResolutionYear.year(startingOn: day) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("In \(String(year)) I want to…", text: $draft.text)
                    if ResolutionFraming.isAvoidance(draft.text), let match = ResolutionLibrary.match(draft.text, in: templates) {
                        Button("Plan it as \u{201C}\(match.title)\u{201D}") { pick(match) }
                    }
                } header: {
                    Text("Your \(String(year)) resolution")
                } footer: {
                    Text("Habits in your nest join it. Resolutions about starting something are kept more often than ones about stopping.")
                }
                Section("Common resolutions") {
                    ForEach(templates) { template in
                        Button { pick(template) } label: {
                            Label(template.title, systemImage: template.symbol)
                                .foregroundStyle(FledgeTheme.Palette.ink)
                        }
                    }
                }
                Section("Why it matters") {
                    TextField("Optional", text: $draft.why, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle("New resolution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { start() }.disabled(draft.problem != nil)
                }
            }
            .task { templates = (try? ResolutionLibrary.all()) ?? [] }
            .alert("Couldn't do that", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func pick(_ template: ResolutionTemplate) {
        draft.text = template.title
        draft.templateID = template.id
    }

    private func start() {
        if draft.trimmedText != (templates.first { $0.id == draft.templateID }?.title ?? "") { draft.templateID = "" }
        do {
            try context.startResolution(draft, startDay: day, attachingActiveHabits: true)
            AppRefresh.afterWrite(context: context, structural: true)
            dismiss()
        } catch HabitStoreError.resolutionActive {
            errorMessage = "You already have a resolution in progress. Keep it or let it go first."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

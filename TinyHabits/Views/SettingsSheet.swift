import SwiftUI
import SwiftData
import StoreKit
import UserNotifications
import HabitCore
import FledgeUI

/// Settings (docs/DESIGN.md §6.8, SET-1).
struct SettingsSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Query private var paused: [Habit]
    @State private var errorMessage: String?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var purchases = Purchases.shared
    @State private var showPaywall = false
    @State private var showManageSubscription = false
    @State private var exportURL: URL?
    @State private var appIcon = UIApplication.shared.alternateIconName
    @State private var summaryOn = FledgeSettings.eveningSummaryMinutes != nil
    @State private var summaryMinutes = FledgeSettings.eveningSummaryMinutes ?? 21 * 60
    @AppStorage(FledgeSettings.dayEndHourKey, store: FledgeSettings.defaults) private var dayEndHour = FledgeSettings.defaultDayEndHour

    init() {
        let pausedState = HabitState.paused.rawValue
        _paused = Query(filter: #Predicate<Habit> { $0.stateRaw == pausedState }, sort: \Habit.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                proSection
                daySection
                notificationsSection
                healthSection
                appearanceSection
                pausedSection
                dataSection
                aboutSection
            }
            // Headers and footers in ink2 (AA); the system grey measured below 4.5 : 1 in the audit.
            .foregroundStyle(FledgeTheme.Palette.ink, FledgeTheme.Palette.ink2)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
                exportURL = makeExport()
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .manageSubscriptionsSheet(isPresented: $showManageSubscription)
            .alert("Couldn't do that", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: Sections

    /// Pro as a card on the sky, not a row like the others (UX-16).
    private var proSection: some View {
        Section {
            Button {
                if purchases.isPro { showManageSubscription = true } else { showPaywall = true }
            } label: {
                HStack(spacing: FledgeTheme.Space.l) {
                    FledgeBird(.flying)
                        .frame(width: 54)
                        .shadow(color: FledgeTheme.Palette.ink.opacity(0.15), radius: 6, y: 3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(purchases.isPro ? "Fledge Pro is on" : "Fledge Pro")
                            .font(.system(.title3, design: .rounded, weight: .heavy))
                            .foregroundStyle(FledgeTheme.Palette.ink)
                        Text(purchases.isPro
                             ? "Thank you. Manage your plan here."
                             : "All three habits from Apple Health, every widget and the Lock Screen.")
                            .font(.footnote)
                            .foregroundStyle(FledgeTheme.Palette.ink2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(FledgeTheme.Palette.ink2.opacity(0.6))
                }
                .padding(.vertical, FledgeTheme.Space.s)
            }
            .listRowBackground(
                LinearGradient(
                    colors: [FledgeTheme.Palette.sky.opacity(0.28), FledgeTheme.Palette.dawn.opacity(0.14)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .background(FledgeTheme.Palette.card)
            )
            .accessibilityHint(purchases.isPro ? "Manage your subscription" : "Opens Fledge Pro")
        }
    }

    /// A Settings-style row label: a filled icon square, then the title.
    private func rowLabel(_ title: String, _ symbol: String, _ color: Color) -> some View {
        Label {
            Text(title)
                .foregroundStyle(FledgeTheme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            IconSquare(symbol: symbol, color: color, size: 28, filled: true)
        }
    }

    private var daySection: some View {
        Section {
            Picker(selection: $dayEndHour) {
                ForEach(Array(FledgeSettings.dayEndHourRange), id: \.self) { hour in
                    Text(hourLabel(hour)).tag(hour)
                }
            } label: {
                rowLabel("Day ends at", "moon.stars.fill", FledgeTheme.habitColor("lilac"))
            }
        } footer: {
            Text("Anything you do before this time counts for the previous day — handy for late nights.")
        }
    }

    private var notificationsSection: some View {
        Section {
            LabeledContent {
                Text(notificationLabel)
            } label: {
                rowLabel("Reminders", "bell.fill", FledgeTheme.Palette.dawn)
            }
            if notificationStatus == .denied {
                Button("Turn on in Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
            }
            Toggle(isOn: $summaryOn) {
                rowLabel("Evening summary", "moon.fill", FledgeTheme.habitColor("slate"))
            }
            .tint(FledgeTheme.Palette.meadow)
                .onChange(of: summaryOn) { _, on in
                    FledgeSettings.eveningSummaryMinutes = on ? summaryMinutes : nil
                    Task {
                        if on { await Reminders.requestAuthorizationIfNeeded() }
                        await Reminders.reconcile(context: context)
                    }
                }
            if summaryOn {
                DatePicker("Time", selection: summaryTime, displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Reminders are sent only when a habit isn't done yet. The evening summary is skipped when all three are done.")
        }
    }

    private var healthSection: some View {
        Section {
            Button {
                if let url = URL(string: "x-apple-health://") { openURL(url) }
            } label: {
                rowLabel("Open the Health app", "heart.fill", FledgeTheme.habitColor("rose"))
            }
        } header: {
            Text("Apple Health")
        } footer: {
            Text("Fledge only reads the data for habits you choose, and it never leaves your \(DeviceInfo.name). To change access, open Health › your profile › Apps › Fledge.")
        }
    }

    private var appearanceSection: some View {
        Section("App icon") {
            ForEach(AppIconOption.allCases) { option in
                Button {
                    setIcon(option)
                } label: {
                    HStack {
                        Image(option.previewImage)
                            .resizable()
                            .frame(width: 44, height: 44)
                            .clipShape(.rect(cornerRadius: 10))
                            .accessibilityHidden(true)
                        Text(option.title).foregroundStyle(FledgeTheme.Palette.ink)
                        Spacer()
                        if option.alternateName == appIcon {
                            Image(systemName: "checkmark").foregroundStyle(FledgeTheme.Palette.skyText)
                        } else if option != .dawn && !purchases.isPro {
                            ProBadge()
                        }
                    }
                }
                .accessibilityAddTraits(option.alternateName == appIcon ? .isSelected : [])
            }
        }
    }

    private var pausedSection: some View {
        Section {
            if paused.isEmpty {
                Text("No paused habits")
                    .foregroundStyle(FledgeTheme.Palette.ink2)
            }
            ForEach(paused) { habit in
                HStack {
                    Label {
                        Text(habit.name).foregroundStyle(FledgeTheme.Palette.ink)
                    } icon: {
                        IconSquare(symbol: habit.symbol, color: FledgeTheme.habitColor(habit.colorKey), size: 28)
                    }
                    Spacer()
                    Button("Resume") { resume(habit) }
                        .buttonStyle(.borderless)
                }
            }
        } header: {
            Text("Paused habits")
        } footer: {
            Text("Pausing frees a slot and keeps the habit's history.")
        }
    }

    private var dataSection: some View {
        Section("Your data") {
            if purchases.isPro, let exportURL {
                ShareLink(item: exportURL) {
                    rowLabel("Export history (CSV)", "square.and.arrow.up", FledgeTheme.habitColor("teal"))
                }
            } else {
                Button { showPaywall = true } label: {
                    HStack {
                        rowLabel("Export history (CSV)", "square.and.arrow.up", FledgeTheme.habitColor("teal"))
                        Spacer()
                        ProBadge()
                    }
                }
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            Link(destination: URL(string: "https://fledgehabits.com/privacy")!) {
                rowLabel("Privacy policy", "hand.raised.fill", FledgeTheme.Palette.meadow)
            }
            Link(destination: URL(string: "mailto:hello@fledgehabits.com?subject=Fledge%20feedback")!) {
                rowLabel("Help and feedback", "envelope.fill", FledgeTheme.Palette.sky)
            }
            Button {
                Task { await purchases.restore() }
            } label: {
                rowLabel("Restore purchases", "arrow.clockwise", FledgeTheme.habitColor("slate"))
            }
            LabeledContent("Version", value: appVersion)
            Label("No account. Your Health data stays on your \(DeviceInfo.name).", systemImage: "lock.fill")
                .foregroundStyle(FledgeTheme.Palette.ink2)
        }
    }

    // MARK: Helpers

    private var summaryTime: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: summaryMinutes / 60, minute: summaryMinutes % 60, second: 0, of: .now) ?? .now },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                summaryMinutes = (parts.hour ?? 21) * 60 + (parts.minute ?? 0)
                FledgeSettings.eveningSummaryMinutes = summaryMinutes
                Task { await Reminders.reconcile(context: context) }
            }
        )
    }

    private var notificationLabel: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: "On"
        case .denied: "Off"
        default: "Not set up"
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return hour == 0 ? "Midnight" : date.formatted(date: .omitted, time: .shortened)
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func setIcon(_ option: AppIconOption) {
        guard option == .dawn || purchases.isPro else {
            showPaywall = true
            return
        }
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(option.alternateName)
                appIcon = option.alternateName
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Writes the CSV to a temporary file for the share sheet.
    private func makeExport() -> URL? {
        guard let habits = try? context.fetch(FetchDescriptor<Habit>()) else { return nil }
        let csv = CSVExporter.csv(CSVExporter.rows(from: habits))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Fledge history.csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private func resume(_ habit: Habit) {
        do {
            try context.resume(habitID: habit.id)
            AppRefresh.afterWrite(context: context, structural: true)
        } catch HabitStoreError.nestFull {
            errorMessage = "Your nest holds three. Let one fly or pause one first."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// App icons (Pro except the default). Names match the asset catalog's `AppIcon-Night` set.
enum AppIconOption: String, CaseIterable, Identifiable {
    case dawn, night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dawn: "Dawn"
        case .night: "Night"
        }
    }

    /// nil = primary icon.
    var alternateName: String? {
        switch self {
        case .dawn: nil
        case .night: "AppIcon-Night"
        }
    }

    var previewImage: String {
        switch self {
        case .dawn: "IconPreview-Dawn"
        case .night: "IconPreview-Night"
        }
    }
}

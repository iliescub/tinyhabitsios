import WidgetKit
import SwiftUI
import Intents

struct TinyHabitsEntry: TimelineEntry {
    let date: Date
    let completedCount: Int
    let totalCount: Int
}

struct TinyHabitsProvider: TimelineProvider {
    func placeholder(in context: Context) -> TinyHabitsEntry {
        TinyHabitsEntry(date: Date(), completedCount: 2, totalCount: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (TinyHabitsEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TinyHabitsEntry>) -> Void) {
        // In a real app, load shared data (e.g. App Group) here.
        let entry = TinyHabitsEntry(date: Date(), completedCount: 2, totalCount: 3)
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct TinyHabitsWidgetEntryView: View {
    var entry: TinyHabitsEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color(.systemBackground))

            VStack(spacing: 8) {
                Text("TinyHabits")
                    .font(.headline)
                Text("\(entry.completedCount) of \(entry.totalCount) done")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ProgressView(
                    value: Double(entry.completedCount),
                    total: Double(entry.totalCount)
                )
                .tint(.blue)
            }
            .padding()
        }
    }
}

@main
struct TinyHabitsWidget: Widget {
    let kind: String = "TinyHabitsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TinyHabitsProvider()) { entry in
            TinyHabitsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("TinyHabits")
        .description("See today's progress at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}


import SwiftUI

struct HabitRow: View {
    let habit: Habit
    var showDetails: Bool = true
    var onDelete: (() -> Void)?
    
    private var accent: Color {
        (AccentTheme(rawValue: habit.accentColorKey) ?? .blue).color
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.headline)
                Text("Daily target: \(habit.dailyTarget)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if showDetails {
                NavigationLink {
                    HabitDetailView(habit: habit)
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: DesignTokens.shadow, radius: DesignTokens.shadowRadius, y: DesignTokens.shadowY)
        )
    }
}

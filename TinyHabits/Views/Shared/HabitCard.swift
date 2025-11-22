import SwiftUI

struct HabitCard: View {
    let habit: Habit
    let progress: Double
    let subtitle: String
    let onPrimary: () -> Void
    let onSecondary: (() -> Void)?

    private var accent: Color {
        (AccentTheme(rawValue: habit.accentColorKey) ?? .blue).color
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: habit.iconSystemName)
                        .font(.headline)
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ProgressRing(progress: progress, accent: accent)
                    .frame(width: 36, height: 36)
            }

            HStack(spacing: 10) {
                Button(action: onPrimary) {
                    Label("Mark done", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(accent.opacity(0.9))
                        .clipShape(Capsule(style: .continuous))
                        .shadow(color: accent.opacity(0.25), radius: 8, y: 4)
                }
                .buttonStyle(.plain)

                if let onSecondary {
                    Button(action: onSecondary) {
                        Label("More", systemImage: "ellipsis")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.systemBackground), in: Capsule(style: .continuous))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadius, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: DesignTokens.shadow, radius: DesignTokens.shadowRadius, y: DesignTokens.shadowY)
        )
    }
}

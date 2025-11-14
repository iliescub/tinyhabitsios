import SwiftUI

struct HabitCardView: View {
    let habit: Habit
    let entry: HabitEntry?
    let onStatusChange: (HabitStatus) -> Void

    private var currentStatus: HabitStatus {
        entry?.status ?? .pending
    }

    var body: some View {
        let accent = AccentTheme(rawValue: habit.accentColorKey) ?? .blue

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: habit.iconSystemName)
                    .font(.title2)
                Text(habit.name)
                    .font(.headline)
                Spacer()
                statusChip
            }

            HStack(spacing: 12) {
                Button {
                    toggle(.done)
                } label: {
                    Label("Done", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(HabitButtonStyle(
                    isSelected: currentStatus == .done,
                    color: accent.color
                ))

                Button {
                    toggle(.skipped)
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(HabitButtonStyle(
                    isSelected: currentStatus == .skipped,
                    color: .gray.opacity(0.4)
                ))

                if currentStatus != .pending {
                    Button {
                        toggle(.pending)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStatus)
    }

    private var statusChip: some View {
        Group {
            switch currentStatus {
            case .done:
                Label("Done", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .skipped:
                Label("Skipped", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.orange)
            case .pending:
                Text("Not yet")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    private func toggle(_ newStatus: HabitStatus) {
        HapticManager.shared.play(.soft)
        onStatusChange(newStatus)
    }
}

struct HabitButtonStyle: ButtonStyle {
    let isSelected: Bool
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? color.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? color : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}


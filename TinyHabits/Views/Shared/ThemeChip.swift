import SwiftUI

struct ThemeChip: View {
    let theme: AccentTheme
    let isSelected: Bool
    var onSelect: () -> Void

    private var gradient: [Color] {
        let base = theme.color
        let complement = base.complementary
        return [
            complement.adjustingBrightness(by: -0.08),
            complement.adjustingBrightness(by: 0.12)
        ]
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(theme.color.opacity(isSelected ? 0.9 : 0.2), lineWidth: 3)
                    )
                    .frame(width: 120, height: 70)
                    .shadow(color: gradient.first?.opacity(0.25) ?? .clear, radius: 10, y: 6)
                Text(theme.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

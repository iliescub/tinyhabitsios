import SwiftUI
import SwiftData

struct ThemeView: View {
    @AppStorage("accentTheme") private var storedAccentTheme: String = AccentTheme.blue.rawValue
    @EnvironmentObject private var swipeGuard: SwipeGuard
    @State private var accentSliderValue: Double = 0
    @State private var themeCardFrame: CGRect = .zero
    
    private var themeManager = ThemeManager()

    private var accentThemes: [AccentTheme] { AccentTheme.allCases }
    private var accentTheme: AccentTheme {
        AccentTheme(rawValue: storedAccentTheme) ?? .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Theme")
                .font(.headline)
                .foregroundStyle(.primary.opacity(0.8))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(accentThemes.enumerated()), id: \.element.id) { index, theme in
                        ThemeChip(theme: theme, isSelected: Int(accentSliderValue.rounded()) == index) {
                            accentSliderValue = Double(index)
                            updateAccentTheme(with: Double(index))
                        }
                    }
                }
        }

//            themePreview(gradient: gradientForTheme(accentTheme))
        }
        .onAppear {
            syncAccentSlider()
        }
        .onChange(of: storedAccentTheme) { _, _ in
            syncAccentSlider()
        }
        .padding()
        .background(glassBackground())
        .shadow(color: themeManager.accent.color.opacity(0.2), radius: 8, y: 4)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        updateThemeCardFrame(geometry.frame(in: .named("MainTabSpace")))
                    }
                    .onChange(of: geometry.frame(in: .named("MainTabSpace"))) { _, frame in
                        updateThemeCardFrame(frame)
                    }
            }
        )
        .onDisappear {
            clearThemeCardFrame()
        }
    }

    private func themePreview(gradient: [Color]) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay(
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Circle().fill(themeManager.accent.color.opacity(0.3)).frame(width: 12, height: 12)
                        Circle().fill(themeManager.accent.color.opacity(0.5)).frame(width: 12, height: 12)
                        Circle().fill(themeManager.accent.color.opacity(0.8)).frame(width: 12, height: 12)
                    }
                    Text("Live preview")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.9))
                    Text("See how buttons & cards will glow with this accent.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .shadow(color: gradient.first?.opacity(0.25) ?? .clear, radius: 12, y: 8)
    }

    private func updateAccentTheme(with sliderValue: Double) {
        let index = max(0, min(accentThemes.count - 1, Int(sliderValue.rounded())))
        let selectedTheme = accentThemes[index]
        storedAccentTheme = selectedTheme.rawValue
    }

    private func syncAccentSlider() {
        guard let index = accentThemes.firstIndex(where: { $0.rawValue == storedAccentTheme }) else { return }
        accentSliderValue = Double(index)
    }

    private func gradientForTheme(_ theme: AccentTheme) -> [Color] {
        let base = theme.color
        let complement = base.complementary
        return [
            complement.adjustingBrightness(by: -0.08),
            complement.adjustingBrightness(by: 0.12)
        ]
    }

    private func glassBackground(cornerRadius: CGFloat = 24) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 10, y: 8)
    }

    private struct ThemeChip: View {
        let theme: AccentTheme
        let isSelected: Bool
        var onSelect: () -> Void

        private var gradient: [Color] {
            let base = theme.color
//            let complement = base.complementary
            return [
//                complement.adjustingBrightness(by: -0.08),
//                complement.adjustingBrightness(by: 0.12)
                base.adjustingBrightness(by: -0.08),
                base.adjustingBrightness(by: 0.12)
            ]
        }

        var body: some View {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
//                            DesignTokens.gradientThemeBackground(theme)
                            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(theme.color.complementary.opacity(isSelected ? 0.9 : 0.2), lineWidth: 3)
                        )
                        .frame(width: 70, height: 30)
                        .shadow(color: gradient.first?.opacity(0.25) ?? .clear, radius: 10, y: 6)
                    Text(theme.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    private func updateThemeCardFrame(_ frame: CGRect) {
        guard frame != .zero else { return }
        themeCardFrame = frame
        var regions = swipeGuard.blockedRegions.filter { $0 != .zero }
        if let existingIndex = regions.firstIndex(of: frame) {
            regions[existingIndex] = frame
        } else {
            regions.append(frame)
        }
        swipeGuard.blockedRegions = regions
    }

    private func clearThemeCardFrame() {
        swipeGuard.blockedRegions.removeAll { $0 == themeCardFrame }
        themeCardFrame = .zero
    }
}

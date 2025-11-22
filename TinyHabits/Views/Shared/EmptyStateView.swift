import SwiftUI

struct EmptyStateView: View {
    let accentColor: Color

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "bolt.heart")
                .font(.system(size: 46))
                .foregroundStyle(accentColor)
            Text("No habits for today yet.")
                .font(.headline)
            Text("Add up to three tiny habits to keep your streaks alive.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

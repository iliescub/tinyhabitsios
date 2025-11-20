//
//  StatsView.swift
//  TinyHabits
//
//  Created by Bogdan Iliescu on 20.11.2025.
//

import SwiftUI

struct StatsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.purple.opacity(0.8))
            Text("Insights coming soon")
                .font(.title2.bold())
            Text("Track your streaks and see how small habits compound over time. Stay tuned!")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

//
//  TodayView.swift
//  TinyHabits
//
//  Created by Bogdan Iliescu on 20.11.2025.
//

import SwiftUI

struct TodayView: View {
    let habits: [Habit]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Habits")
                .font(.largeTitle.bold())
                .padding(.bottom, 8)


        }
        .padding()
    }
}

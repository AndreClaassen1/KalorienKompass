//
//  CalorieRingView.swift
//  KalorienKompassWatch
//
//  Erstellt von André Claaßen am 06.02.26.
//

#if os(watchOS)
import SwiftUI

/// Kalorienring mit Rest-Kalorien im Zentrum
struct CalorieRingView: View {
    let progress: Double
    let remaining: Int
    let goal: Int

    private var ringColor: Color {
        if progress >= 1.0 {
            return .red
        } else if progress >= 0.85 {
            return .orange
        } else {
            return .green
        }
    }

    var body: some View {
        ZStack {
            // Hintergrund-Ring
            Circle()
                .stroke(lineWidth: 10)
                .foregroundStyle(.quaternary)

            // Fortschritts-Ring
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            // Ueberschreitung (zweiter Ring falls > 100%)
            if progress > 1.0 {
                Circle()
                    .trim(from: 0, to: min(progress - 1.0, 1.0))
                    .stroke(
                        .red.opacity(0.6),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }

            // Zentrum
            VStack(spacing: 0) {
                Text("\(abs(remaining))")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(remaining >= 0 ? Color.primary : Color.red)

                Text(remaining >= 0 ? String(localized: "remaining_label") : String(localized: "over_label"))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(4)
    }
}

#Preview {
    VStack {
        CalorieRingView(progress: 0.65, remaining: 700, goal: 2000)
            .frame(height: 100)
        CalorieRingView(progress: 1.15, remaining: -300, goal: 2000)
            .frame(height: 100)
    }
}
#endif

//
//  ProgressBarView.swift
//  KalorienKompassWatch
//
//  Erstellt von André Claaßen am 06.02.26.
//

#if os(watchOS)
import SwiftUI

/// Fortschrittsbalken mit Ziel-Label
struct ProgressBarView: View {
    let progress: Double
    let color: Color
    let goal: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Hintergrund
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(height: 8)

                    // Fortschritt
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(
                            width: geometry.size.width * min(progress, 1.0),
                            height: 8
                        )
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 8)

            // Ziel-Label
            Text(String(localized: "goal_prefix") + " \(goal)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    VStack {
        ProgressBarView(progress: 0.65, color: .green, goal: 10000)
        ProgressBarView(progress: 1.2, color: .orange, goal: 2000)
    }
    .padding()
}
#endif

//
//  CalorieHeroView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 06.02.26.
//

import SwiftUI

// MARK: - Custom Alignment fuer horizontale Zahlenausrichtung

private extension VerticalAlignment {
    struct CalorieNumberAlignment: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[VerticalAlignment.center]
        }
    }
    static let calorieNumber = VerticalAlignment(CalorieNumberAlignment.self)
}

/// Wiederverwendbare Hero-Ansicht: Gegessen | Ring+Uebrig | Verbrannt
/// Wird im Dashboard und im CalorieSummaryWidget identisch verwendet.
struct CalorieHeroView: View {
    let eaten: Int
    let remaining: Int
    let burned: Int
    let goal: Int
    var ringSize: CGFloat = 80
    var ringLineWidth: CGFloat = 6
    /// Optionale Ueberschreibung der Ringfarbe (z.B. Fokus-Ansicht: Tages-Score).
    /// Ohne Wert bleibt die progress-basierte Standardfarbe (gruen/orange/rot).
    var ringTint: Color? = nil

    /// Optionale Ueberschreibung der Farbe der "Uebrig"-Zahl. Ohne Wert folgt sie der
    /// Ringfarbe; die Fokus-Ansicht setzt `.primary`, damit die Zahl auch ueber dem
    /// dunklen Ambient-Hintergrund gut lesbar bleibt (statt score-gruen auf dunkel).
    var remainingColorOverride: Color? = nil

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return Double(eaten) / Double(goal)
    }

    private var ringColor: Color {
        if let ringTint { return ringTint }
        if progress > 1.0 { return .red }
        if progress > 0.85 { return .orange }
        return .green
    }

    var body: some View {
        HStack(alignment: .calorieNumber, spacing: 0) {
            // Links: Gegessen
            VStack(spacing: 4) {
                Image(systemName: "fork.knife")
                    .font(.title3)
                    .foregroundStyle(.orange)
                Text(eaten, format: .number)
                    .font(.title3)
                    .fontWeight(.bold)
                    .alignmentGuide(.calorieNumber) { d in d[VerticalAlignment.center] }
                Text("widget_eaten")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            // Mitte: Ring
            ZStack {
                Circle()
                    .stroke(.gray.opacity(0.2), lineWidth: ringLineWidth)
                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text(abs(remaining), format: .number)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(remainingColorOverride ?? ringColor)
                        .alignmentGuide(.calorieNumber) { d in d[VerticalAlignment.center] }
                    Text(remaining >= 0 ? String(localized: "widget_remaining") : String(localized: "over_label"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: ringSize, height: ringSize)

            // Rechts: Verbrannt
            VStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
                Text(burned, format: .number)
                    .font(.title3)
                    .fontWeight(.bold)
                    .alignmentGuide(.calorieNumber) { d in d[VerticalAlignment.center] }
                Text("widget_burned")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview("App Hero") {
    CalorieHeroView(
        eaten: 251, remaining: 1822, burned: 298, goal: 2073,
        ringSize: 110, ringLineWidth: 8
    )
    .padding()
}

#Preview("Widget") {
    CalorieHeroView(eaten: 1450, remaining: 750, burned: 520, goal: 2200)
        .padding()
}

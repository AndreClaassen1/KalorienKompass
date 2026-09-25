//
//  MealRowView.swift
//  KalorienKompassWatch
//
//  Erstellt von André Claaßen am 06.02.26.
//

#if os(watchOS)
import SwiftUI

/// Zeile fuer eine Mahlzeit mit Icon, Name, Fortschritt und kcal
struct MealRowView: View {
    let mealType: MealType
    let consumed: Int
    let budget: Int

    private var progress: Double {
        guard budget > 0 else { return 0 }
        return Double(consumed) / Double(budget)
    }

    private var progressColor: Color {
        if progress >= 1.0 {
            return .red
        } else if progress >= 0.85 {
            return .orange
        } else {
            return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: mealType.symbolName)
                    .foregroundStyle(progressColor)
                    .font(.caption)

                Text(mealType.localizedName)
                    .font(.caption)
                    .lineLimit(1)

                Spacer()

                Text("\(consumed)")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("/\(budget)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Mini-Fortschrittsbalken
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.quaternary)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(progressColor)
                        .frame(
                            width: geometry.size.width * min(progress, 1.0),
                            height: 4
                        )
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack {
        MealRowView(mealType: .breakfast, consumed: 350, budget: 500)
        MealRowView(mealType: .lunch, consumed: 600, budget: 600)
        MealRowView(mealType: .dinner, consumed: 700, budget: 500)
    }
    .padding()
}
#endif

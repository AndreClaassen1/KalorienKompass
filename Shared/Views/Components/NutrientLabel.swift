//
//  NutrientLabel.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import SwiftUI

/// Kompakte Anzeige eines Naehrwerts mit Label und Wert
struct NutrientLabel: View {
    let title: LocalizedStringKey
    let value: Double
    let unit: String
    let color: Color

    init(_ title: LocalizedStringKey, value: Double, unit: String = "g", color: Color = .primary) {
        self.title = title
        self.value = value
        self.unit = unit
        self.color = color
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(Int(value))\(unit)")
                .font(.headline)
                .foregroundStyle(color)
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        NutrientLabel("nutrient_protein", value: 65, color: .blue)
        NutrientLabel("nutrient_carbs", value: 230, color: .green)
        NutrientLabel("nutrient_fat", value: 55, color: .orange)
    }
    .padding()
}

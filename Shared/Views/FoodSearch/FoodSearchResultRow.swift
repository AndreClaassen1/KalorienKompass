//
//  FoodSearchResultRow.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import SwiftUI

/// Ergebniszeile fuer die Lebensmittelsuche (lokal oder online)
struct FoodSearchResultRow: View {
    let name: String
    let brand: String?
    let caloriesPer100g: Double
    let isLocal: Bool
    var fatPer100g: Double = 0
    var saturatedFatPer100g: Double = 0
    var sugarPer100g: Double = 0
    var saltPer100g: Double = 0

    var body: some View {
        HStack {
            TrafficLightIndicator(
                fat: fatPer100g,
                saturatedFat: saturatedFatPer100g,
                sugar: sugarPer100g,
                salt: saltPer100g,
                calories: caloriesPer100g
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                    .lineLimit(1)
                if let brand, !brand.isEmpty {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(caloriesPer100g)) kcal")
                    .font(.caption.bold())
                Text("/100g")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if isLocal {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    List {
        FoodSearchResultRow(name: "Haferflocken", brand: "Koelln", caloriesPer100g: 372, isLocal: true, fatPer100g: 7, saturatedFatPer100g: 1.3, sugarPer100g: 1, saltPer100g: 0.01)
        FoodSearchResultRow(name: "Vollkornbrot", brand: "Mestemacher", caloriesPer100g: 210, isLocal: false, fatPer100g: 1.5, saturatedFatPer100g: 0.3, sugarPer100g: 3.5, saltPer100g: 1.1)
    }
}

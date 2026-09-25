//
//  FoodDetailPanel.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import SwiftUI

/// Detailansicht eines Lebensmittels mit Naehrwertinformationen
struct FoodDetailPanel: View {
    let foodItem: FoodItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Kopfzeile
                HStack(spacing: 8) {
                    TrafficLightIndicator(foodItem: foodItem)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(foodItem.name)
                            .font(.title2.bold())
                        if let brand = foodItem.brand, !brand.isEmpty {
                            Text(brand)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                // Naehrwerte pro 100g
                Text("nutrients_per_100g")
                    .font(.headline)

                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                    nutrientGridRow("nutrient_calories", value: "\(Int(foodItem.caloriesPer100g)) kcal")
                    nutrientGridRow("nutrient_protein", value: String(format: "%.1f g", foodItem.proteinPer100g))
                    nutrientGridRow("nutrient_carbs", value: String(format: "%.1f g", foodItem.carbsPer100g))
                    nutrientGridRow("nutrient_fat", value: String(format: "%.1f g", foodItem.fatPer100g))
                    nutrientGridRow("nutrient_fiber", value: String(format: "%.1f g", foodItem.fiberPer100g))
                    nutrientGridRow("nutrient_sugar", value: String(format: "%.1f g", foodItem.sugarPer100g))
                    nutrientGridRow("nutrient_saturated_fat", value: String(format: "%.1f g", foodItem.saturatedFatPer100g))
                    nutrientGridRow("nutrient_salt", value: String(format: "%.1f g", foodItem.saltPer100g))
                }

                if let serving = foodItem.servingDescription {
                    Divider()
                    HStack {
                        Text("serving_size")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(serving)
                    }
                    .font(.subheadline)
                }

                if let barcode = foodItem.barcode {
                    HStack {
                        Text("barcode")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(barcode)
                            .font(.caption.monospaced())
                    }
                    .font(.subheadline)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func nutrientGridRow(_ title: LocalizedStringKey, value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .bold()
        }
    }
}

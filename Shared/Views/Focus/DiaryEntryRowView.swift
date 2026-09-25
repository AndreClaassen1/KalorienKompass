//
//  DiaryEntryRowView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import SwiftUI

/// Einzelne Zeile fuer einen Tagebucheintrag
struct DiaryEntryRowView: View {
    let entry: DiaryEntry

    var body: some View {
        HStack {
            // Fehlt das Lebensmittel ganz oder fehlen seine Naehrwerte, steht hier
            // der Platzhalter. Vorher zeigte der erste Fall gelb und der zweite
            // gruen — beides geraten (Issue #94).
            TrafficLightIndicator(rating: entry.foodItem?.trafficLight?.rating)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.foodItem?.name ?? "—")
                    .font(.body)
                if let brand = entry.foodItem?.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if entry.foodItem?.trafficLight == nil {
                    Text("traffic_light_no_nutrients")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.calories)) kcal")
                    .font(.body.bold())
                Text("\(Int(entry.amountGrams)) g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    let food = FoodItem(
        name: "Haferflocken",
        brand: "Koelln",
        caloriesPer100g: 372,
        proteinPer100g: 13.5,
        carbsPer100g: 58.7,
        fatPer100g: 7.0
    )
    let ohneNaehrwerte = FoodItem(name: "Copaburger mit Pommes", caloriesPer100g: 750)

    return VStack {
        DiaryEntryRowView(entry: DiaryEntry(
            date: Date(), mealType: .breakfast, amountGrams: 50, foodItem: food
        ))
        DiaryEntryRowView(entry: DiaryEntry(
            date: Date(), mealType: .lunch, amountGrams: 400, foodItem: ohneNaehrwerte
        ))
    }
    .padding()
}

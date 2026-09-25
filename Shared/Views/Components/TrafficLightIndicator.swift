//
//  TrafficLightIndicator.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 05.02.26.
//

import SwiftUI

extension TrafficLightRating {
    var color: Color {
        switch self {
        case .green: .green
        case .amber: .yellow
        case .red:   .red
        }
    }

    /// Asset-Name fuer das Ampel-Icon
    var imageName: String {
        switch self {
        case .green: "traffic_green"
        case .amber: "traffic_amber"
        case .red:   "traffic_red"
        }
    }
}

/// Wiederverwendbare Ampel-Anzeige als Emoji-Icon
///
/// Ohne Rating erscheint ein grauer Platzhalter statt einer Farbe: eine geratene
/// Ampel behauptet etwas ueber Daten, die es nicht gibt (Issue #94). Er nimmt
/// denselben Platz ein, damit das Zeilenraster einer Liste stehen bleibt.
struct TrafficLightIndicator: View {
    let rating: TrafficLightRating?

    var body: some View {
        Group {
            if let rating {
                Image(rating.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "questionmark.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel(Text("traffic_light_unknown_accessibility"))
            }
        }
        .frame(width: 20, height: 20)
    }

    // MARK: - Convenience-Initializer

    /// Erstellt den Indikator aus einzelnen Naehrwerten (pro 100g).
    /// Die Kalorien entscheiden mit, ob Nullwerte echt oder nicht erfasst sind.
    init(fat: Double, saturatedFat: Double, sugar: Double, salt: Double, calories: Double) {
        self.rating = NutrientTrafficLight.trafficLight(
            fat: fat, saturatedFat: saturatedFat, sugar: sugar, salt: salt, calories: calories
        )?.rating
    }

    /// Erstellt den Indikator aus einem FoodItem
    init(foodItem: FoodItem) {
        self.rating = foodItem.trafficLight?.rating
    }

    /// Erstellt den Indikator aus einem expliziten Rating (`nil` = Platzhalter)
    init(rating: TrafficLightRating?) {
        self.rating = rating
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        HStack {
            TrafficLightIndicator(fat: 0.1, saturatedFat: 0, sugar: 1.7, salt: 0.01, calories: 12)
            Text("Gurke (gruen)")
        }
        HStack {
            TrafficLightIndicator(fat: 0.2, saturatedFat: 0, sugar: 10, salt: 0, calories: 52)
            Text("Apfel (gruen)")
        }
        HStack {
            TrafficLightIndicator(fat: 1, saturatedFat: 0.2, sugar: 3, salt: 1.2, calories: 228)
            Text("Roggenbrot (gruen)")
        }
        HStack {
            TrafficLightIndicator(fat: 13.2, saturatedFat: 1.8, sugar: 0.3, salt: 0.7, calories: 272)
            Text("Pommes (gelb)")
        }
        HStack {
            TrafficLightIndicator(fat: 33, saturatedFat: 3, sugar: 1, salt: 1.3, calories: 533)
            Text("Chips (rot)")
        }
        HStack {
            TrafficLightIndicator(fat: 0, saturatedFat: 0, sugar: 0, salt: 0, calories: 750)
            Text("Burger (keine Angabe)")
        }
        HStack {
            TrafficLightIndicator(fat: 0, saturatedFat: 0, sugar: 0, salt: 0, calories: 0)
            Text("Wasser (echte Null, gruen)")
        }
    }
    .font(.body)
    .padding()
}

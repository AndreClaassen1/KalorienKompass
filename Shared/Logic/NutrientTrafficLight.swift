//
//  NutrientTrafficLight.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 05.02.26.
//

import Foundation

/// Ampelbewertung eines einzelnen Naehrwerts
///
/// Farbe und Icon-Name haengen an der Darstellung und stehen deshalb in
/// `TrafficLightIndicator.swift`: diese Datei wird auch vom Kommandozeilen-
/// werkzeug kompiliert, und das braucht kein SwiftUI.
enum TrafficLightRating: Int {
    case green = 0
    case amber = 1
    case red = 2
}

/// Naehrstoff-Ampel nach dem britischen Traffic-Light-System (pro 100g)
///
/// UK-FSA-Grenzwerte fuer Einzelbewertungen (Fett, ges. Fett, Zucker, Salz),
/// kombiniert zu einem Gesamtscore: gruen=0, gelb=1, rot=2 pro Kategorie (max. 8).
/// Gesamtbewertung: Score 0–1 → gesund, 2–3 → mittel, 4+ → ungesund.
struct NutrientTrafficLight {

    // MARK: - Einzelbewertungen (UK FSA per 100g)

    static func rateFat(_ g: Double) -> TrafficLightRating {
        if g <= 3.0 { return .green }
        if g <= 17.5 { return .amber }
        return .red
    }

    static func rateSaturatedFat(_ g: Double) -> TrafficLightRating {
        if g <= 1.5 { return .green }
        if g <= 5.0 { return .amber }
        return .red
    }

    static func rateSugar(_ g: Double) -> TrafficLightRating {
        if g <= 5.0 { return .green }
        if g <= 22.5 { return .amber }
        return .red
    }

    static func rateSalt(_ g: Double) -> TrafficLightRating {
        if g <= 0.3 { return .green }
        if g <= 1.5 { return .amber }
        return .red
    }

    // MARK: - Gesamtbewertung (0-1 gruen, 2-3 gelb, 4+ rot)

    /// Summe der Einzelbewertungen, 0 bis 8 (vier Kategorien à 2 Punkte).
    ///
    /// Oeffentlich, weil die Farbe allein die Naehe zur naechsten Stufe verschweigt:
    /// das CLI gibt den Score in `kk today --json` mit aus, damit die
    /// Morgenauswertung die Qualitaet eines Tages rechnen kann, statt Farben aus
    /// Text zu lesen.
    static func score(fat: Double, saturatedFat: Double, sugar: Double, salt: Double) -> Int {
        rateFat(fat).rawValue
            + rateSaturatedFat(saturatedFat).rawValue
            + rateSugar(sugar).rawValue
            + rateSalt(salt).rawValue
    }

    /// Ampelfarbe zu einem Score aus `score(fat:saturatedFat:sugar:salt:)`.
    static func rating(forScore score: Int) -> TrafficLightRating {
        if score <= 1 { return .green }
        if score <= 3 { return .amber }
        return .red
    }

    static func overallRating(fat: Double, saturatedFat: Double, sugar: Double, salt: Double) -> TrafficLightRating {
        rating(forScore: score(fat: fat, saturatedFat: saturatedFat, sugar: sugar, salt: salt))
    }

}

// MARK: - Bewertung eines Lebensmittels

/// Ampelbewertung samt Score. Der Score ist der Wert, die Farbe seine Einordnung.
struct TrafficLight {
    let score: Int

    var rating: TrafficLightRating { NutrientTrafficLight.rating(forScore: score) }
}

extension NutrientTrafficLight {

    /// Ampel aus Naehrwerten je 100 g, oder `nil`, wenn sie fehlen.
    ///
    /// Die vier Eingangswerte sind im Modell nicht optional, ein fehlender Wert
    /// ist also von einer echten Null nicht zu unterscheiden. Unterschieden wird
    /// deshalb ueber die Kalorien: ein Lebensmittel mit Energie, aber ohne ein
    /// einziges Gramm Fett, Zucker oder Salz hat keine erfassten Naehrwerte,
    /// keine besonders reinen. Bei null Kalorien (Wasser, schwarzer Kaffee) sind
    /// die Nullen dagegen echt.
    ///
    /// Wer damit umgeht, entscheidet die Oberflaeche: das CLI laesst die Spalte
    /// leer, die App zeigt einen Platzhalter. Beide raten nicht, weil eine
    /// falsche gruene Ampel schlechter ist als gar keine (Issues #92 und #94).
    ///
    /// Nicht abgedeckt sind **teilweise** erfasste Werte: ein einziges Gramm
    /// Fett laesst die drei uebrigen Kategorien als Null durchgehen und faerbt
    /// zu gruen. Das ist bekannt und in Issue #95 aufgehoben.
    static func trafficLight(
        fat: Double,
        saturatedFat: Double,
        sugar: Double,
        salt: Double,
        calories: Double
    ) -> TrafficLight? {
        let hasNutrients = fat > 0 || saturatedFat > 0 || sugar > 0 || salt > 0
        guard hasNutrients || calories == 0 else { return nil }

        return TrafficLight(score: score(
            fat: fat, saturatedFat: saturatedFat, sugar: sugar, salt: salt
        ))
    }
}

extension FoodItem {

    /// Ampel des Lebensmittels, oder `nil`, wenn die Naehrwerte dafuer fehlen.
    /// Siehe `NutrientTrafficLight.trafficLight(fat:saturatedFat:sugar:salt:calories:)`.
    var trafficLight: TrafficLight? {
        NutrientTrafficLight.trafficLight(
            fat: fatPer100g,
            saturatedFat: saturatedFatPer100g,
            sugar: sugarPer100g,
            salt: saltPer100g,
            calories: caloriesPer100g
        )
    }

    /// True, wenn die Ampel dieses Lebensmittels auf einer zu duennen Basis steht.
    ///
    /// Gemeint sind Altbestaende aus der Zeit vor #95: gesaettigte Fette, Zucker
    /// und Salz standen damals nur im Prompt und blieben gelegentlich aus, der
    /// Decoder setzte still 0 ein. Drei der vier Kategorien zaehlen dann als
    /// bester Fall, und die Ampel faellt zu gruen aus — ein Fruchtaufstrich ohne
    /// Zucker, Chips ohne Salz.
    ///
    /// Zwei Faelle sind ausgenommen. Bei null Kalorien (Wasser, schwarzer
    /// Kaffee) sind die Nullen echt. Und wo auch die Makros fehlen, ist nichts
    /// da, woran sich eine Nachschaetzung ausrichten koennte: solche Eintraege
    /// zeigen seit #94 ehrlich einen Platzhalter, und ein Nachtrag allein der
    /// drei Mikrowerte machte daraus eine halb erfundene Ampel.
    var needsNutrientRepair: Bool {
        let hasMacros = fatPer100g > 0 || proteinPer100g > 0 || carbsPer100g > 0
        return caloriesPer100g > 0
            && hasMacros
            && saturatedFatPer100g == 0
            && sugarPer100g == 0
            && saltPer100g == 0
    }
}

import Foundation

// MARK: - Naehrstoff-Ampel im CLI
// Bewertung und die Regel fuer fehlende Naehrwerte stehen in
// SharedLinks/NutrientTrafficLight.swift (Symlink auf
// Shared/Logic/NutrientTrafficLight.swift). Hier steht nur die Darstellung.

extension TrafficLightRating {
    /// Farbiger Punkt fuer das Zeilenende in `kk today`.
    ///
    /// Modulqualifiziert, weil die Enum-Faelle `green` und `red` hier drinnen
    /// die gleichnamigen Farbfunktionen verdecken.
    var dot: String {
        switch self {
        case .green: kk.green("●")
        case .amber: kk.yellow("●")
        case .red:   kk.red("●")
        }
    }

    /// Deutscher Name fuer die Tageszusammenfassung.
    var displayName: String {
        switch self {
        case .green: "grün"
        case .amber: "gelb"
        case .red:   "rot"
        }
    }

    /// Stabiler Schluessel fuer `--json` (bewusst englisch und unuebersetzt,
    /// damit Skripte nicht an der Anzeigesprache haengen).
    var jsonName: String {
        switch self {
        case .green: "green"
        case .amber: "amber"
        case .red:   "red"
        }
    }
}

/// Wie viele Eintraege eines Tages welche Ampelfarbe tragen.
struct TrafficLightSummary {
    var green = 0
    var amber = 0
    var red = 0
    /// Eintraege ohne ausreichende Naehrwerte — bewusst mitgezaehlt, damit eine
    /// duenne Datenlage nicht wie ein gruener Tag aussieht.
    var unknown = 0

    var rated: Int { green + amber + red }

    init(entries: [DiaryEntry]) {
        for entry in entries {
            switch entry.foodItem?.trafficLight?.rating {
            case .green?: green += 1
            case .amber?: amber += 1
            case .red?:   red += 1
            case nil:     unknown += 1
            }
        }
    }

    /// Zeile fuer `kk today`, oder `nil`, wenn nichts zu bewerten war.
    var line: String? {
        guard rated > 0 else { return nil }
        var parts = [
            "\(green) " + TrafficLightRating.green.displayName,
            "\(amber) " + TrafficLightRating.amber.displayName,
            "\(red) " + TrafficLightRating.red.displayName
        ]
        if unknown > 0 { parts.append("\(unknown) ohne Angabe") }
        return "🚦 " + parts.joined(separator: ", ")
    }
}

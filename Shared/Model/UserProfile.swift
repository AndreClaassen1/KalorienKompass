//
//  UserProfile.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import Foundation
import SwiftData

/// Benutzerprofil mit Zielen und Einstellungen
@Model
public class UserProfile {
    /// Eindeutiger Bezeichner
    var profileId: String = UUID().uuidString

    /// Taegliches Kalorienziel
    var dailyCalorieGoal: Int = 2000

    /// Proteinziel in Gramm
    var proteinGoalGrams: Int = 50

    /// Kohlenhydratziel in Gramm
    var carbsGoalGrams: Int = 250

    /// Fettziel in Gramm
    var fatGoalGrams: Int = 65

    /// Ballaststoffziel in Gramm
    var fiberGoalGrams: Int = 30

    /// Gewichtsziel in kg
    var weightGoalKg: Double?

    /// Taegliches Schritteziel
    var dailyStepsGoal: Int = 10000

    /// Taegliches Wasserziel in ml
    var dailyWaterGoalMl: Int = 2000

    /// Kaffee-Ziel fuer Werktage (Anzahl Tassen)
    var dailyCoffeeGoal: Int = 3

    /// Kaffee-Ziel fuer Wochenendtage (Anzahl Tassen)
    var weekendCoffeeGoal: Int = 6

    /// Bitmask fuer Wochenendtage — Bit entspricht Calendar.Weekday
    /// (Sonntag=1, Montag=2, ..., Samstag=7). Default = Fr(64) + Sa(128) + So(2) = 194
    var weekendCoffeeDaysRaw: Int = 194

    /// Standard-Tassengroesse in ml (fuer Info-Anzeige und Koffein-Schaetzung)
    var coffeeMlPerCup: Int = 150

    /// Geschaetzte Koffein-Menge pro Tasse in mg (Filterkaffee ~95mg, Espresso ~60mg)
    var caffeineMgPerCup: Int = 95

    /// Fallback, wenn (noch) kein Profil da ist — etwa beim ersten Siri-Aufruf.
    /// Steht hier, damit die Zahl nicht in jedem Aufrufer einzeln auftaucht.
    static let defaultCaffeineMgPerCup = 95

    /// Prueft, ob ein Datum als Wochenendtag gilt
    func isWeekendDay(_ date: Date, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return (weekendCoffeeDaysRaw & (1 << weekday)) != 0
    }

    /// Effektives Kaffee-Ziel fuer einen bestimmten Tag
    func coffeeGoal(for date: Date, calendar: Calendar = .current) -> Int {
        isWeekendDay(date, calendar: calendar) ? weekendCoffeeGoal : dailyCoffeeGoal
    }

    /// Bevorzugte Einheit fuer Gewicht
    var weightUnitRaw: String = WeightUnit.kg.rawValue

    var weightUnit: WeightUnit {
        get { WeightUnit(rawValue: weightUnitRaw) ?? .kg }
        set { weightUnitRaw = newValue.rawValue }
    }

    /// Koerpergewicht fuer Berechnung (in kg)
    var bodyWeightKg: Double = 80

    /// Koerpergroesse (in cm)
    var heightCm: Double = 175

    /// Alter (Jahre)
    var age: Int = 30

    /// Geschlecht (CloudKit-kompatibel als String)
    var genderRaw: String = Gender.male.rawValue

    var gender: Gender {
        get { Gender(rawValue: genderRaw) ?? .male }
        set { genderRaw = newValue.rawValue }
    }

    /// Aktivitaetslevel (CloudKit-kompatibel als String)
    var activityLevelRaw: String = ActivityLevel.moderatelyActive.rawValue

    var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityLevelRaw) ?? .moderatelyActive }
        set { activityLevelRaw = newValue.rawValue }
    }

    /// Automatische Kalorienberechnung aktiviert
    var useAutoCalories: Bool = false

    /// Zeitpunkt der Erstellung
    var createdAt: Date = Date()

    /// Zieltyp (CloudKit-kompatibel als Int)
    var goalTypeRaw: Int = 0

    var goalType: GoalType {
        get { GoalType(rawValue: goalTypeRaw) ?? .lose }
        set { goalTypeRaw = newValue.rawValue }
    }

    /// Startgewicht bei Zielbeginn
    var startWeightKg: Double?

    /// Datum des Zielbeginns
    var goalStartDate: Date?

    /// Wochenziel in kg (negativ = abnehmen, positiv = zunehmen)
    var weeklyWeightGoalKg: Double = -0.5

    /// Prozentsatz der Sportkalorien-Anrechnung (0-100, Standard 50%)
    var exerciseCreditPercent: Int = 50

    /// Wochenend-Bonus in Prozent (0=aus, 5, 10, 15, 20, 25)
    var weekendBonusPercent: Int = 0

    /// Dynamische Aktivitaetskalorien aus HealthKit (Apple Watch Modus)
    var useHealthKitActivity: Bool = false

    /// Erwartete taegliche Aktivitaetskalorien (Fallback fuer Durchschnittsberechnung)
    var expectedDailyActivityKcal: Int = 500

    /// Wasser-Erinnerungen aktiviert
    var waterRemindersEnabled: Bool = true

    /// Mahlzeiten-Erinnerungen aktiviert
    var mealRemindersEnabled: Bool = true

    /// Ruhezeit Start (Stunde, 0-23)
    var quietTimeStartHour: Int = 22

    /// Ruhezeit Ende (Stunde, 0-23)
    var quietTimeEndHour: Int = 7

    /// Zeitpunkt der letzten Aenderung
    var updatedAt: Date = Date()

    init(dailyCalorieGoal: Int = 2000) {
        self.dailyCalorieGoal = dailyCalorieGoal
    }
}

// MARK: - Inhaltliche Felder

extension UserProfile {

    /// Ein inhaltliches Feld als Kopier- und Vergleichsschritt.
    ///
    /// Die Feldliste steht damit genau **einmal** (`contentFields`), statt je
    /// einmal fuer Vergleich und Kopie. Ein vergessenes Feld waere hier
    /// besonders teuer: `isPristineDefault` haelt ein bearbeitetes Profil dann
    /// faelschlich fuer unberuehrt, und `canonical(in:)` verwirft es.
    private struct ContentField: Sendable {
        let copy: @Sendable (UserProfile, UserProfile) -> Void
        let isEqual: @Sendable (UserProfile, UserProfile) -> Bool

        init<V: Equatable & Sendable>(_ keyPath: ReferenceWritableKeyPath<UserProfile, V> & Sendable) {
            copy = { source, target in target[keyPath: keyPath] = source[keyPath: keyPath] }
            isEqual = { $0[keyPath: keyPath] == $1[keyPath: keyPath] }
        }
    }

    /// Alle Felder, die Nutzereingaben tragen.
    ///
    /// Bewusst ohne `profileId`, `createdAt` und `updatedAt`: das sind
    /// Identitaets- und Metadaten, keine Eingaben.
    private static let contentFields: [ContentField] = [
        .init(\.dailyCalorieGoal), .init(\.proteinGoalGrams), .init(\.carbsGoalGrams),
        .init(\.fatGoalGrams), .init(\.fiberGoalGrams), .init(\.weightGoalKg),
        .init(\.dailyStepsGoal), .init(\.dailyWaterGoalMl), .init(\.dailyCoffeeGoal),
        .init(\.weekendCoffeeGoal), .init(\.weekendCoffeeDaysRaw), .init(\.coffeeMlPerCup),
        .init(\.caffeineMgPerCup), .init(\.weightUnitRaw), .init(\.bodyWeightKg),
        .init(\.heightCm), .init(\.age), .init(\.genderRaw),
        .init(\.activityLevelRaw), .init(\.useAutoCalories), .init(\.goalTypeRaw),
        .init(\.startWeightKg), .init(\.goalStartDate), .init(\.weeklyWeightGoalKg),
        .init(\.exerciseCreditPercent), .init(\.weekendBonusPercent), .init(\.useHealthKitActivity),
        .init(\.expectedDailyActivityKcal), .init(\.waterRemindersEnabled), .init(\.mealRemindersEnabled),
        .init(\.quietTimeStartHour), .init(\.quietTimeEndHour)
    ]

    /// Uebernimmt alle inhaltlichen Felder aus `other`. `profileId`, `createdAt`
    /// und `updatedAt` bleiben unangetastet, die Identitaet wechselt also nicht.
    func copyContent(from other: UserProfile) {
        for field in Self.contentFields { field.copy(other, self) }
    }

    /// True, wenn das Profil ausschliesslich Standardwerte traegt, der Nutzer es
    /// also nie angefasst hat. Ein solches Profil darf niemals ein Profil mit
    /// echten Werten verdraengen.
    var isPristineDefault: Bool {
        // Referenzobjekt bewusst lokal, nicht als `static let`: ein prozessweit
        // gehaltenes @Model-Objekt ohne Kontext waere ein ueberraschender
        // Dauergast in Widget- und CLI-Prozessen.
        let reference = UserProfile()
        return Self.contentFields.allSatisfy { $0.isEqual(self, reference) }
    }
}

// MARK: - Kanonisches Profil

extension UserProfile {

    /// **Lesepfad.** Liefert das kanonische Benutzerprofil, oder `nil`, wenn
    /// noch keines existiert. Legt nichts an, loescht nichts, speichert nicht.
    ///
    /// **Kanonisch ist das aelteste Profil (`createdAt` aufsteigend), nicht das
    /// zuletzt aktualisierte.** Grund: CloudKit spielt pro Geraet ein Duplikat ein,
    /// und ein frisch angelegtes Default-Profil traegt per Definition das neueste
    /// `updatedAt`. Wer nach `updatedAt` sortiert, waehlt genau dann das leere
    /// Profil, wenn es am meisten schadet (Issue #63).
    static func existing(in context: ModelContext) -> UserProfile? {
        var descriptor = FetchDescriptor<UserProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// **Schreibpfad.** Liefert das kanonische Profil und fuehrt CloudKit-Duplikate
    /// darauf zusammen. Gibt `nil` zurueck, wenn es noch kein Profil gibt: angelegt
    /// wird eines nur durch eine Nutzeraktion (`SettingsViewModel.save()`), nie
    /// beim blossen Lesen.
    ///
    /// Nur aus dem bewussten Schreibpfad aufrufen. Ein `delete()` propagiert in die
    /// CloudKit-Zone und wirkt auf allen Geraeten; ein Anzeige-Refresh waehrend eines
    /// laufenden Imports wuerde ein gerade eintreffendes Profil als Duplikat
    /// missdeuten. Die Aenderungen bleiben ungespeichert im Kontext: der Aufrufer
    /// schreibt ohnehin und committet alles in einer Transaktion.
    static func canonical(in context: ModelContext) -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let profiles = (try? context.fetch(descriptor)) ?? []
        guard let primary = profiles.first else { return nil }
        guard profiles.count > 1 else { return primary }

        // Inhaltstraeger bestimmen: das zuletzt aktualisierte Profil, das nicht
        // nur Standardwerte traegt. Reine Default-Profile scheiden aus, egal wie
        // neu sie sind — sonst ueberschreibt ein leeres Profil die echten Daten.
        let richest = profiles.filter { !$0.isPristineDefault }.max { $0.updatedAt < $1.updatedAt }

        if let richest, richest !== primary {
            primary.copyContent(from: richest)
            primary.updatedAt = richest.updatedAt
        }

        for duplicate in profiles.dropFirst() {
            context.delete(duplicate)
        }
        return primary
    }
}

/// Zieltyp fuer Gewichtsmanagement
enum GoalType: Int, CaseIterable, Identifiable, Codable, Sendable {
    case lose = 0
    case maintain = 1
    case gain = 2

    var id: Int { rawValue }

    var localizedName: String {
        switch self {
        case .lose: String(localized: "goal_type_lose")
        case .maintain: String(localized: "goal_type_maintain")
        case .gain: String(localized: "goal_type_gain")
        }
    }
}

/// Geschlecht fuer Kalorienberechnung
enum Gender: String, CaseIterable, Identifiable, Codable, Sendable {
    case male = "male"
    case female = "female"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .male: String(localized: "gender_male")
        case .female: String(localized: "gender_female")
        }
    }
}

/// Aktivitaetslevel (PAL-Faktor)
enum ActivityLevel: String, CaseIterable, Identifiable, Codable, Sendable {
    case sedentary = "sedentary"
    case lightlyActive = "lightly_active"
    case moderatelyActive = "moderately_active"
    case veryActive = "very_active"

    var id: String { rawValue }

    var palFactor: Double {
        switch self {
        case .sedentary: 1.2
        case .lightlyActive: 1.375
        case .moderatelyActive: 1.55
        case .veryActive: 1.725
        }
    }

    var localizedName: String {
        switch self {
        case .sedentary: String(localized: "activity_sedentary")
        case .lightlyActive: String(localized: "activity_lightly_active")
        case .moderatelyActive: String(localized: "activity_moderately_active")
        case .veryActive: String(localized: "activity_very_active")
        }
    }
}

/// Gewichtseinheiten
enum WeightUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case kg = "kg"
    case lbs = "lbs"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .kg: "kg"
        case .lbs: "lbs"
        }
    }
}

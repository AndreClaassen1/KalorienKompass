//
//  ComplicationSnapshot.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 26.07.26.
//

import Foundation
import os

/// Die Zahlen, die eine Watch-Komplikation zeigt, als kleiner uebertragbarer Wert.
///
/// Hintergrund (Issue #69): Die Widget-Extension synchronisiert bewusst nicht selbst
/// (`DataModel.makeContainer` gibt Extensions einen Container ohne CloudKit), und den
/// lokalen Store der Uhr fuellt nur die Watch-App. Ohne App-Start bleibt die
/// Komplikation deshalb auf dem Stand des letzten Besuchs stehen.
///
/// Dieser Snapshot ist der zweite Weg an dieselben Zahlen: das iPhone schickt ihn
/// ueber `WatchConnectivity`, die Uhr legt ihn in die App Group, und die Komplikation
/// nimmt den **neueren** der beiden Staende. Bewusst klein und ohne SwiftData —
/// er muss durch einen `userInfo`-Transfer passen und in einem Widget-Prozess mit
/// knappem Speicher gelesen werden.
struct ComplicationSnapshot: Codable, Equatable, Sendable {
    /// Tag, auf den sich die Zahlen beziehen (Tagesbeginn)
    let day: Date
    let totalCaloriesConsumed: Double
    let effectiveCalorieGoal: Int
    let remainingCalories: Double
    let waterIntakeMl: Int
    let waterGoalMl: Int
    /// Zeitpunkt der Erhebung. Entscheidet, welcher Stand gewinnt.
    let updatedAt: Date

    init(
        day: Date,
        totalCaloriesConsumed: Double,
        effectiveCalorieGoal: Int,
        remainingCalories: Double,
        waterIntakeMl: Int,
        waterGoalMl: Int,
        updatedAt: Date
    ) {
        self.day = day.startOfDay
        self.totalCaloriesConsumed = totalCaloriesConsumed
        self.effectiveCalorieGoal = effectiveCalorieGoal
        self.remainingCalories = remainingCalories
        self.waterIntakeMl = waterIntakeMl
        self.waterGoalMl = waterGoalMl
        self.updatedAt = updatedAt
    }

    /// Vergleich ohne `updatedAt`: nur inhaltliche Aenderungen rechtfertigen eine
    /// Uebertragung. Das Kontingent fuer Komplikations-Transfers liegt bei rund
    /// 50 pro Tag, und `loadDay` laeuft deutlich oefter — jeder CloudKit-Import
    /// loest einen Reload aus.
    func hasSameValues(as other: ComplicationSnapshot) -> Bool {
        day == other.day
            && totalCaloriesConsumed == other.totalCaloriesConsumed
            && effectiveCalorieGoal == other.effectiveCalorieGoal
            && remainingCalories == other.remainingCalories
            && waterIntakeMl == other.waterIntakeMl
            && waterGoalMl == other.waterGoalMl
    }

    /// Gilt dieser Snapshot noch? Ein Stand von gestern darf die Komplikation nicht
    /// beschreiben, auch wenn er neuer erhoben wurde als die lokalen Daten.
    func isValid(for date: Date = Date()) -> Bool {
        day == date.startOfDay
    }
}

// MARK: - Ablage in der App Group

extension ComplicationSnapshot {

    private static let log = Logger(
        subsystem: "com.andre.claassen.KalorienKompass",
        category: "ComplicationSnapshot"
    )

    /// Woher ein Stand stammt. Beide Seiten legen getrennt ab, damit sie sich
    /// nicht gegenseitig ueberschreiben und die Komplikation vergleichen kann.
    enum Source: String {
        /// Auf der Uhr selbst erhoben (Watch-App hat gebucht oder geladen)
        case local = "complication.snapshot.local"
        /// Vom iPhone uebertragen
        case received = "complication.snapshot.received"
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupPaths.groupID)
    }

    /// Legt den Snapshot dort ab, wo die Widget-Extension ihn lesen kann.
    ///
    /// Bewusst `UserDefaults` der App Group statt SwiftData: der Widget-Prozess soll
    /// dafuer keinen zweiten Store oeffnen muessen, und der Wert ist winzig.
    func store(as source: Source) {
        guard let defaults = Self.defaults, let data = try? JSONEncoder().encode(self) else {
            Self.log.error("Snapshot konnte nicht abgelegt werden")
            return
        }
        defaults.set(data, forKey: source.rawValue)
    }

    /// Liest den zuletzt abgelegten Snapshot der Quelle, oder `nil`.
    static func stored(_ source: Source) -> ComplicationSnapshot? {
        guard let data = defaults?.data(forKey: source.rawValue) else { return nil }
        return try? JSONDecoder().decode(ComplicationSnapshot.self, from: data)
    }

    /// Der Stand, den die Komplikation zeigen soll.
    ///
    /// Gewinnt der uebertragene Snapshot, hat das iPhone eine Buchung gemeldet, die
    /// im lokalen Store der Uhr noch fehlt. Gewinnt der lokale Stand, war die Uhr
    /// selbst am Zug. Ein Snapshot von gestern scheidet immer aus.
    ///
    /// **Beide Seiten stempeln selbst.** Das Aenderungsdatum der Store-Datei taugt
    /// dafuer nicht: SQLite fasst die `-shm`-Datei schon beim Lesen an, der
    /// Widget-Prozess wuerde seinen eigenen Stand also bei jedem Timeline-Lauf auf
    /// „jetzt" datieren und damit immer gewinnen (Issue #69).
    static func newer(
        local: ComplicationSnapshot?,
        received: ComplicationSnapshot?,
        now: Date = Date()
    ) -> ComplicationSnapshot? {
        let gueltig = [local, received]
            .compactMap { $0 }
            .filter { $0.isValid(for: now) }
        return gueltig.max { $0.updatedAt < $1.updatedAt }
    }
}

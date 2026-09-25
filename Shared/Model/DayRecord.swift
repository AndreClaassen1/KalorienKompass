//
//  DayRecord.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import Foundation
import SwiftData

/// Tagesrekord mit aggregierten Daten (Schritte, Gewicht, etc.)
@Model
public class DayRecord {
    #Index<DayRecord>([\.date])

    /// Eindeutiger Bezeichner
    var recordId: String = UUID().uuidString

    /// Datum (normalisiert auf Tagesbeginn)
    var date: Date = Date()

    /// Schritte (von HealthKit synchronisiert)
    var steps: Int = 0

    /// Gewicht in kg (von HealthKit synchronisiert)
    var weight: Double?

    /// Wasseraufnahme in ml
    var waterIntakeMl: Int = 0

    /// Aktivitaetskalorien (von HealthKit synchronisiert)
    var activeEnergyKcal: Int = 0

    /// Kalorien aus Trainingseinheiten (von HealthKit synchronisiert)
    var workoutCaloriesKcal: Int = 0

    /// Anzahl getrunkener Kaffees heute (separat vom Kalorienbudget)
    var coffeeCups: Int = 0

    /// Geschaetzte Koffeinaufnahme in mg (optional, fuer HealthKit-Sync)
    var caffeineMg: Double?

    init(date: Date = Date()) {
        self.date = date.startOfDay
    }
}

// MARK: - Kaffee

extension DayRecord {

    /// Bucht Kaffee und fuehrt das Koffein mit.
    ///
    /// Tassenzahl und `caffeineMg` gehoeren zusammen; wer nur eins von beidem
    /// anfasst, hinterlaesst einen Tag, dessen Koffeinwert nicht zu seinen Tassen
    /// passt. Deshalb liegt die Buchung an einer Stelle und nicht in jedem der fuenf
    /// Aufrufer (App-Knopf, MenuBar, Siri, Kurzbefehl, CLI).
    ///
    /// Am Modell und nicht als eigene Logic-Datei wie `FocusBooking`: das hier
    /// aendert zwei Felder desselben Records, waehrend `FocusBooking` mehrere
    /// Modelle anlegt und verknuepft. Nebenbei erspart es die Registrierung einer
    /// neuen Datei in vier Xcode-Targets — `DayRecord.swift` liegt ohnehin in allen.
    ///
    /// - Parameter cups: positiv zum Eintragen, negativ zum Zuruecknehmen.
    /// - Returns: das tatsaechlich gebuchte Koffein-Delta in mg, nach dem Clamping
    ///   bei 0 — negativ beim Zuruecknehmen. Aufrufer, die den Wert weiterreichen
    ///   (etwa nach HealthKit), buchen damit nur, was hier auch passiert ist.
    @discardableResult
    func bookCoffee(cups: Int, caffeineMgPerCup: Int) -> Double {
        let neueTassen = max(coffeeCups + cups, 0)
        guard neueTassen != coffeeCups else { return 0 }

        let tassenDelta = neueTassen - coffeeCups
        coffeeCups = neueTassen

        let vorher = caffeineMg ?? 0
        let nachher = max(vorher + Double(tassenDelta) * Double(caffeineMgPerCup), 0)
        caffeineMg = nachher
        return nachher - vorher
    }

    /// Setzt die Tassenzahl direkt (manuelles Editieren) und rechnet das Koffein neu.
    func setCoffeeCups(_ cups: Int, caffeineMgPerCup: Int) {
        coffeeCups = max(cups, 0)
        caffeineMg = Double(coffeeCups) * Double(caffeineMgPerCup)
    }
}

extension DayRecord {

    /// **Lesepfad.** Liefert den kanonischen DayRecord eines Tages, oder `nil`,
    /// wenn es fuer den Tag noch keinen gibt.
    ///
    /// Legt nichts an, loescht nichts, speichert nicht. Beides waere hier falsch
    /// (Issue #65): ein Anzeige-Refresh kann waehrend eines laufenden
    /// CloudKit-Imports laufen, und dann sieht ein gerade eintreffender Record
    /// aus wie ein Duplikat. Ein `delete()` propagiert in die CloudKit-Zone und
    /// wirkt auf allen Geraeten. Ein Insert wiederum erzeugte bei jedem
    /// Tageswechsel einen leeren Record samt CloudKit-Push.
    ///
    /// Kanonisch ist der Record mit der kleinsten `recordId`. Das ist willkuerlich,
    /// aber auf allen Geraeten dieselbe Wahl, also stabil. Zusammengefuehrt wird
    /// erst im Schreibpfad, siehe `canonical(in:for:)`.
    static func existing(in context: ModelContext, for date: Date) -> DayRecord? {
        primary(of: fetchRecords(in: context, for: date))
    }

    /// **Schreibpfad.** Liefert den kanonischen DayRecord, fuehrt CloudKit-Duplikate
    /// zusammen und legt bei Bedarf einen neuen Record an.
    ///
    /// Nur aufrufen, wenn tatsaechlich geschrieben wird (Wasser, Kaffee, Gewicht,
    /// HealthKit-Werte). CloudKit erzeugt pro Geraet einen eigenen DayRecord;
    /// ohne Zusammenfuehrung operieren Mutation und Anzeige auf verschiedenen
    /// Datensaetzen, und ein Dekrement wird vom `max`-Merge wieder hochgezogen.
    ///
    /// Die Aenderungen bleiben ungespeichert im Kontext: der Aufrufer schreibt
    /// ohnehin und committet Merge, Loeschungen und seine eigenen Felder in einer
    /// Transaktion.
    static func canonical(in context: ModelContext, for date: Date) -> DayRecord {
        let records = fetchRecords(in: context, for: date)

        guard let primary = primary(of: records) else {
            let newRecord = DayRecord(date: date)
            context.insert(newRecord)
            return newRecord
        }

        mergeDuplicates(records, into: primary, in: context)
        return primary
    }

    /// Faltet die Werte aller Records eines Tages in `primary` und entfernt die
    /// uebrigen. Gibt die Anzahl der entfernten Records zurueck.
    ///
    /// Die eine Stelle, an der ein DayRecord verschwindet. `canonical` (Schreibpfad)
    /// und `DuplicateCleanup` (nach CloudKit-Import) rufen beide hierher, damit die
    /// Regel nicht in zwei Fassungen existiert.
    @discardableResult
    static func mergeDuplicates(
        _ records: [DayRecord],
        into primary: DayRecord,
        in context: ModelContext
    ) -> Int {
        guard records.count > 1, let folded = Day.folding(records) else { return 0 }

        folded.apply(to: primary)
        var removed = 0
        for duplicate in records where duplicate !== primary {
            context.delete(duplicate)
            removed += 1
        }
        return removed
    }

    /// **Lesepfad ueber einen Zeitraum.** Liefert einen Wert je Kalendertag,
    /// aufsteigend sortiert, mit derselben Faltung wie der Schreibpfad.
    ///
    /// Wer stattdessen die Records selbst zaehlt, zaehlt bei CloudKit-Duplikaten
    /// Zeilen statt Tage: drei Duplikate **eines** Tages erfuellen sonst eine
    /// Bedingung wie „mindestens drei Tage", und eine Gewichtskurve bekommt pro
    /// Geraet einen Punkt (Issue #67).
    static func days(in context: ModelContext, from startDate: Date, to endDate: Date) -> [Day] {
        let start = startDate.startOfDay
        let end = endDate.endOfDay
        let descriptor = FetchDescriptor<DayRecord>(
            predicate: #Predicate<DayRecord> { record in
                record.date >= start && record.date <= end
            }
        )
        let records = (try? context.fetch(descriptor)) ?? []

        return Dictionary(grouping: records, by: { $0.date.startOfDay })
            .compactMap { _, sameDay in Day.folding(sameDay) }
            .sorted { $0.date < $1.date }
    }

    /// Durchschnittliche Aktivitaetskalorien der Tage mit nennenswerter Aktivitaet.
    ///
    /// - Parameter minDays: Mindestanzahl auswertbarer **Tage** (nicht Records),
    ///   sonst `nil`.
    static func averageActiveEnergy(
        in context: ModelContext,
        from startDate: Date,
        to endDate: Date,
        threshold: Int = 100,
        minDays: Int = 3
    ) -> Int? {
        let days = self.days(in: context, from: startDate, to: endDate)
            .filter { $0.activeEnergyKcal > threshold }
        guard days.count >= minDays else { return nil }
        return days.reduce(0) { $0 + $1.activeEnergyKcal } / days.count
    }

    /// Die kanonische Wahl unter mehreren Records desselben Tages. Steht bewusst
    /// nur hier, damit Lese- und Schreibpfad nie auseinanderlaufen koennen.
    static func primary(of records: [DayRecord]) -> DayRecord? {
        records.min { $0.recordId < $1.recordId }
    }

    private static func fetchRecords(in context: ModelContext, for date: Date) -> [DayRecord] {
        let startOfDay = date.startOfDay
        let endOfDay = date.endOfDay
        let descriptor = FetchDescriptor<DayRecord>(
            predicate: #Predicate<DayRecord> { record in
                record.date >= startOfDay && record.date <= endOfDay
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}

// MARK: - Ein Tag, aus moeglichen Duplikaten gefaltet

extension DayRecord {

    /// Die Werte eines Kalendertages, unabhaengig davon, auf wie viele Records
    /// CloudKit sie verteilt hat.
    ///
    /// Hier steht die Merge-Regel **einmal**: Zaehlwerte gewinnen mit `max`
    /// (ein Wert, den ein Geraet gesehen hat, ist nie „zu viel"), Optionales
    /// nimmt den ersten belegten Wert. Sowohl `canonical` (Schreibpfad) als auch
    /// `days` (Lesepfad) falten darueber, damit beide dasselbe Ergebnis liefern.
    struct Day: Sendable, Equatable {
        let date: Date
        var steps: Int = 0
        var weight: Double?
        var waterIntakeMl: Int = 0
        var activeEnergyKcal: Int = 0
        var workoutCaloriesKcal: Int = 0
        var coffeeCups: Int = 0
        var caffeineMg: Double?

        /// Aktivitaetskalorien ohne den Trainingsanteil — dieselbe Groesse wie
        /// bei `DayRecord?`, nur aus dem gefalteten Tageswert. Die Wochenleiste
        /// arbeitet mit `Day` und braeuchte sonst eine eigene Kopie der Formel.
        var nonWorkoutActiveEnergy: Int {
            max(activeEnergyKcal - workoutCaloriesKcal, 0)
        }

        /// Faltet mehrere Records desselben Tages zu einem Wert.
        /// - Returns: `nil`, wenn die Liste leer ist.
        static func folding(_ records: [DayRecord]) -> Day? {
            guard let first = records.first else { return nil }
            // Nach `recordId` sortieren, bevor optionale Felder den ersten belegten
            // Wert nehmen: sonst haengt das Ergebnis an der Fetch-Reihenfolge, zwei
            // Geraete zeigen verschiedene Gewichte, und die Bereinigung loescht je
            // nach Geraet einen anderen Wert dauerhaft (Issue #67).
            var day = Day(date: first.date.startOfDay)
            for record in records.sorted(by: { $0.recordId < $1.recordId }) {
                day.steps = max(day.steps, record.steps)
                day.waterIntakeMl = max(day.waterIntakeMl, record.waterIntakeMl)
                day.activeEnergyKcal = max(day.activeEnergyKcal, record.activeEnergyKcal)
                day.workoutCaloriesKcal = max(day.workoutCaloriesKcal, record.workoutCaloriesKcal)
                day.coffeeCups = max(day.coffeeCups, record.coffeeCups)
                if day.weight == nil { day.weight = record.weight }
                if day.caffeineMg == nil { day.caffeineMg = record.caffeineMg }
            }
            return day
        }

        /// Schreibt die gefalteten Werte in einen Record.
        func apply(to record: DayRecord) {
            record.steps = steps
            record.waterIntakeMl = waterIntakeMl
            record.activeEnergyKcal = activeEnergyKcal
            record.workoutCaloriesKcal = workoutCaloriesKcal
            record.coffeeCups = coffeeCups
            if record.weight == nil { record.weight = weight }
            if record.caffeineMg == nil { record.caffeineMg = caffeineMg }
        }
    }
}

extension Optional where Wrapped == DayRecord {
    /// Aktivitaetskalorien ohne den Trainingsanteil; 0, wenn es fuer den Tag
    /// keinen Record gibt. Stand vorher in sieben Kopien in ViewModels, Widgets
    /// und Intents.
    var nonWorkoutActiveEnergy: Int {
        max((self?.activeEnergyKcal ?? 0) - (self?.workoutCaloriesKcal ?? 0), 0)
    }
}

// MARK: - Tageswerte aus HealthKit

extension DayRecord {

    /// Aus HealthKit gelesene Tageswerte, bevor sie einen `DayRecord` beruehren.
    ///
    /// Trennt Lesen von Schreiben: erst wird gemessen, und nur wenn tatsaechlich
    /// etwas anliegt (`hasData`), besorgt der Aufrufer einen Record. Ohne diese
    /// Trennung legte jeder Tageswechsel einen leeren Record an, nur weil der
    /// Sync ein Ziel zum Hineinschreiben brauchte.
    struct Metrics: Sendable, Equatable {
        var steps: Int = 0
        var weight: Double?
        var waterIntakeMl: Int = 0
        var activeEnergyKcal: Int = 0
        var workoutCaloriesKcal: Int = 0

        /// True, wenn mindestens ein Wert es wert ist, gespeichert zu werden.
        /// Ueber `Equatable` formuliert, damit ein spaeter ergaenztes Feld nicht
        /// stillschweigend aus der Pruefung faellt.
        var hasData: Bool { self != Metrics() }

        /// Die Werte, die ein Record aktuell traegt. Erlaubt dem Aufrufer, einen
        /// unnoetigen Schreibvorgang zu sparen, wenn sich nichts geaendert hat.
        init(record: DayRecord) {
            steps = record.steps
            weight = record.weight
            waterIntakeMl = record.waterIntakeMl
            activeEnergyKcal = record.activeEnergyKcal
            workoutCaloriesKcal = record.workoutCaloriesKcal
        }

        init(
            steps: Int = 0,
            weight: Double? = nil,
            waterIntakeMl: Int = 0,
            activeEnergyKcal: Int = 0,
            workoutCaloriesKcal: Int = 0
        ) {
            self.steps = steps
            self.weight = weight
            self.waterIntakeMl = waterIntakeMl
            self.activeEnergyKcal = activeEnergyKcal
            self.workoutCaloriesKcal = workoutCaloriesKcal
        }

        /// Uebertraegt die Werte in einen Record. Optionale Werte und Nullwerte
        /// ueberschreiben nichts, damit ein leerer HealthKit-Tag keine manuell
        /// erfassten Angaben loescht.
        func apply(to record: DayRecord) {
            record.steps = steps
            if let weight { record.weight = weight }
            if waterIntakeMl > 0 { record.waterIntakeMl = waterIntakeMl }
            record.activeEnergyKcal = activeEnergyKcal
            record.workoutCaloriesKcal = workoutCaloriesKcal
        }
    }
}

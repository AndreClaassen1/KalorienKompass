//
//  DayViewModel.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import SwiftUI
import SwiftData
import WidgetKit

/// ViewModel fuer die Tageszusammenfassung und Tagebucheintraege
@Observable
final class DayViewModel {
    /// Zeitfenster fuer die Kaffee-Streak. Grosszuegig bemessen, damit lange
    /// Streaks nicht abgeschnitten werden, aber ohne Volltabellen-Fetch.
    private static let streakWindowDays = 400

    private let modelContext: ModelContext

    /// Eintraege des aktuellen Tages
    var entries: [DiaryEntry] = []

    /// Tagesrekord (Schritte, Gewicht)
    var dayRecord: DayRecord?

    /// Benutzerprofil
    var profile: UserProfile?

    /// Workouts des Tages (aus HealthKit)
    var workouts: [WorkoutEntry] = []

    /// Geplante Eintraege des Tages (Issue #99) — zaehlen in keine Summe,
    /// `summary` rechnet ausschliesslich ueber `entries`.
    var plannedEntries: [PlannedEntry] = []

    /// Die sieben Tage der angezeigten Woche — speist die Wochenleiste im
    /// Fokus-Modus (Issue #81). Wird bei jedem `loadDay` mitgeladen.
    var week: [WeekDay] = []

    /// Aktuelle Kaffee-Streak (wird bei loadDay und Kaffee-Mutationen neu berechnet,
    /// darf NICHT als Methode aus dem View-Body aufgerufen werden — das loest einen
    /// SwiftUI-Update-Loop aus, weil der Fetch @Observable-Dependencies anfasst).
    var coffeeStreak: Int = 0

    /// Tageszusammenfassung
    var summary: NutrientCalculator.DaySummary {
        NutrientCalculator.calculateDaySummary(entries: entries)
    }

    /// Zuletzt geladenes Datum — benoetigt fuer CloudKit-Auto-Refresh
    @ObservationIgnored private var lastLoadedDate: Date?

    /// CloudKit-Import-Observer fuer Auto-Refresh bei eingehendem Sync
    @ObservationIgnored private var reloader: RemoteImportReloader?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        reloader = RemoteImportReloader { [weak self] in
            guard let self, let date = self.lastLoadedDate else { return }
            self.loadDay(date: date)
        }
    }

    /// Laedt die Daten fuer ein bestimmtes Datum
    func loadDay(date: Date) {
        lastLoadedDate = date
        let startOfDay = date.startOfDay
        let endOfDay = date.endOfDay

        // Tagebucheintraege laden
        let entryDescriptor = FetchDescriptor<DiaryEntry>(
            predicate: #Predicate<DiaryEntry> { entry in
                entry.date >= startOfDay && entry.date <= endOfDay
            },
            sortBy: [SortDescriptor(\.mealTypeRaw), SortDescriptor(\.createdAt)]
        )
        entries = (try? modelContext.fetch(entryDescriptor)) ?? []

        // Geplante Eintraege laden (eigenes Modell, Issue #99)
        let plannedDescriptor = FetchDescriptor<PlannedEntry>(
            predicate: #Predicate<PlannedEntry> { plan in
                plan.date >= startOfDay && plan.date <= endOfDay
            },
            sortBy: [SortDescriptor(\.mealTypeRaw), SortDescriptor(\.createdAt)]
        )
        plannedEntries = (try? modelContext.fetch(plannedDescriptor)) ?? []

        // Tagesrekord nur lesen: kein Record ohne Eingabe, keine Bereinigung im
        // Anzeigepfad (Issue #65). Zusammengefuehrt und angelegt wird beim Schreiben.
        dayRecord = DayRecord.existing(in: modelContext, for: date)

        // Nur lesen: Zusammengefuehrt wird im Schreibpfad, siehe
        // SettingsViewModel.save() und UserProfile.canonical (Issue #63).
        profile = UserProfile.existing(in: modelContext)

        // Kaffee-Streak neu berechnen
        refreshCoffeeStreak(today: date)

        // Wochenleiste: sieben Tage rund um den angezeigten Tag
        refreshWeek(around: date)

        // HealthKit-Sync auf iOS
        #if canImport(HealthKit)
        let currentEntries = self.entries
        Task {
            let (metrics, fetchedWorkouts) = await HealthKitManager.shared.fetchDayMetrics(for: date)
            await HealthKitManager.shared.syncNutritionToHealthKit(entries: currentEntries, for: date)
            await MainActor.run {
                self.workouts = fetchedWorkouts
                // Erst jetzt, mit echten Werten in der Hand, einen Record anlegen
                if metrics.hasData {
                    let record = self.writableDayRecord(for: date)
                    metrics.apply(to: record)
                    // Nur committen, wenn wirklich etwas anders ist: sonst pusht
                    // jeder Ladevorgang denselben Stand erneut nach CloudKit.
                    if self.modelContext.hasChanges { try? self.modelContext.save() }
                    self.dayRecord = record
                }
                self.refreshWidgetsAndComplication()
            }
            await rescheduleNotifications()
        }
        #else
        Task {
            await rescheduleNotifications()
        }
        #endif

        pushComplicationSnapshot(for: date)
    }

    /// Bringt Widgets **und** die Watch-Komplikation auf den neuen Stand.
    ///
    /// Ersetzt die vereinzelten `reloadAllTimelines()`-Aufrufe: die Uhr braucht
    /// denselben Anlass, sonst haengt ihre Komplikation an dem, was zuletzt
    /// zufaellig ueber `loadDay` lief (Issue #69).
    private func refreshWidgetsAndComplication() {
        WidgetCenter.shared.reloadAllTimelines()
        pushComplicationSnapshot(for: lastLoadedDate ?? Date())
    }

    /// Schickt der Uhr den aktuellen Stand fuer ihre Komplikation.
    ///
    /// Nur fuer heute: eine Komplikation zeigt den laufenden Tag, ein
    /// zurueckgeblaetterter waere dort falsch. Der Sender uebertraegt selbst nur bei
    /// inhaltlicher Aenderung, weil das Kontingent begrenzt ist (Issue #69).
    private func pushComplicationSnapshot(for date: Date) {
        #if os(iOS)
        guard Calendar.current.isDateInToday(date) else { return }

        WatchSnapshotSender.shared.send(
            ComplicationSnapshot(
                day: date,
                totalCaloriesConsumed: summary.totalCalories,
                effectiveCalorieGoal: effectiveCalorieGoal,
                remainingCalories: remainingCalories,
                waterIntakeMl: dayRecord?.waterIntakeMl ?? 0,
                waterGoalMl: profile?.dailyWaterGoalMl ?? 2000,
                updatedAt: Date()
            )
        )
        #endif
    }

    /// Liefert den DayRecord zum Schreiben: fuehrt CloudKit-Duplikate zusammen und
    /// legt bei Bedarf einen an. Nur aus Schreibpfaden aufrufen (Issue #65).
    private func writableDayRecord(for date: Date) -> DayRecord {
        DayRecord.canonical(in: modelContext, for: date)
    }

    /// Eintraege gruppiert nach Mahlzeitentyp
    func entriesForMeal(_ mealType: MealType) -> [DiaryEntry] {
        entries.filter { $0.mealType == mealType }
    }

    /// Naehrstoffzusammenfassung fuer eine Mahlzeit
    func summaryForMeal(_ mealType: MealType) -> NutrientCalculator.DaySummary {
        NutrientCalculator.calculateMealSummary(entries: entries, mealType: mealType)
    }

    /// Letzter Eintrag einer Mahlzeit (fuer Vorschautext)
    func lastEntryForMeal(_ mealType: MealType) -> DiaryEntry? {
        entriesForMeal(mealType).last
    }

    /// Geplante Eintraege einer Mahlzeit. Waehlt bei CloudKit-Duplikaten
    /// lesend den gueltigen Plan aus (loescht nichts — das erledigt
    /// `DuplicateCleanup` nach dem Import).
    func plannedEntriesForMeal(_ mealType: MealType) -> [PlannedEntry] {
        let matching = plannedEntries.filter { $0.mealType == mealType }
        guard let keep = PlannedEntry.effective(among: matching) else { return [] }
        return [keep]
    }

    /// Uebernimmt einen Plan als echten Eintrag (Issue #99). Der Reload laeuft
    /// ueber `loadDay` und erbt damit HealthKit-Sync, Notifications und
    /// Widget-Refresh wie jede andere Buchung.
    func acceptPlannedEntry(_ plan: PlannedEntry) {
        let planDate = plan.date
        plan.accept(in: modelContext)
        try? modelContext.save()
        loadDay(date: planDate)
        refreshWidgetsAndComplication()
    }

    /// Verwirft einen Plan spurlos. Bewusst ohne Widget-Refresh und ohne
    /// `loadDay`: fuer Summen und Widgets hat sich nichts geaendert.
    func discardPlannedEntry(_ plan: PlannedEntry) {
        plannedEntries.removeAll { $0 === plan }
        plan.discard(in: modelContext)
        try? modelContext.save()
    }

    /// Aktivitaetskalorien ohne Training (Gesamt-Aktivitaet minus Workout-Anteil)
    var nonWorkoutActiveEnergy: Int { dayRecord.nonWorkoutActiveEnergy }

    /// Effektives Kalorienziel — delegiert an einheitliche NutrientCalculator-Logik
    var effectiveCalorieGoal: Int { goalBreakdown.total }

    /// Die Posten des Tagesziels — fuer die Aufschluesselung im Budget-Sheet (#80).
    var goalBreakdown: NutrientCalculator.GoalBreakdown {
        NutrientCalculator.goalBreakdown(
            profile: profile,
            dayRecord: dayRecord,
            nonWorkoutActiveEnergy: nonWorkoutActiveEnergy
        )
    }

    /// Kalorienbudget fuer eine Mahlzeit basierend auf Tagesziel und Gewichtung
    func calorieBudgetForMeal(_ mealType: MealType) -> Int {
        return Int(Double(effectiveCalorieGoal) * mealType.budgetWeight)
    }

    /// Aktualisiert Grammzahl und Mahlzeitentyp eines bestehenden Eintrags
    func updateEntry(_ entry: DiaryEntry, amountGrams: Double, mealType: MealType) {
        entry.amountGrams = amountGrams
        entry.mealType = mealType
        try? modelContext.save()
        // Tag neu laden, damit Eintraege in der richtigen Sektion erscheinen
        loadDay(date: entry.date)
        refreshWidgetsAndComplication()

        Task {
            await rescheduleNotifications()
        }
    }

    /// Verschiebt einen Eintrag in eine andere Mahlzeit (Drag & Drop, Kontextmenue)
    func moveEntry(_ entryId: String, to mealType: MealType) {
        moveEntries([entryId], to: mealType)
    }

    /// Verschiebt mehrere Eintraege in einem Zug (Mehrfachauswahl auf dem Mac).
    /// Geschrieben wird ueber `FocusBooking.move`, den einzigen Umbuchpfad — so
    /// nimmt die App denselben Weg wie das Siri-Snippet. Ein gemeinsamer Aufruf
    /// statt einer je Eintrag: sonst laedt die Liste zwischendurch neu.
    func moveEntries(_ entryIds: [String], to mealType: MealType) {
        let ids = Set(entryIds)
        let betroffene = entries.filter { ids.contains($0.entryId) }
        // Eine Zeile auf ihre eigene Mahlzeit zu buchen ist kein Nichts: es zoege
        // Neuladen, HealthKit-Abgleich und Benachrichtigungen nach sich.
        guard betroffene.contains(where: { $0.mealType != mealType }) else { return }
        guard let datum = betroffene.first?.date else { return }

        FocusBooking.move(entryIds: entryIds, to: mealType, context: modelContext)
        loadDay(date: datum)
        refreshWidgetsAndComplication()
    }

    /// Loescht einen Eintrag
    func deleteEntry(_ entry: DiaryEntry) {
        let entryDate = entry.date
        modelContext.delete(entry)
        if let index = entries.firstIndex(where: { $0.entryId == entry.entryId }) {
            entries.remove(at: index)
        }
        try? modelContext.save()
        refreshWidgetsAndComplication()

        #if canImport(HealthKit)
        let remainingEntries = self.entries
        Task {
            await HealthKitManager.shared.syncNutritionToHealthKit(entries: remainingEntries, for: entryDate)
            await rescheduleNotifications()
        }
        #else
        Task {
            await rescheduleNotifications()
        }
        #endif
    }

    /// Aktualisiert das Gewicht fuer einen Tag
    func updateWeight(_ kg: Double, for date: Date) {
        let record = writableDayRecord(for: date)
        record.weight = kg
        // Aktuelles Gewicht hat genau eine Quelle: den Wiegewert. Beim Wiegen fuer
        // heute wird das Profilgewicht (Eingang der Kalorien-/BMR-Berechnung)
        // mitgezogen, damit Profil und Tagesanzeige nicht auseinanderlaufen und das
        // Kalorienziel aktuell bleibt. Ein nachtraeglich korrigierter Vergangenheitstag
        // aendert das aktuelle Gewicht bewusst nicht.
        if Calendar.current.isDateInToday(date) {
            profile?.bodyWeightKg = kg
        }
        try? modelContext.save()
        dayRecord = record

        #if canImport(HealthKit)
        Task {
            await HealthKitManager.shared.saveWeight(kg, for: date)
        }
        #endif
    }

    /// Fuegt Wasser hinzu (Inkrement)
    func addWater(ml: Int, for date: Date) {
        let record = writableDayRecord(for: date)
        record.waterIntakeMl += ml
        try? modelContext.save()
        dayRecord = record
        refreshWidgetsAndComplication()

        #if canImport(HealthKit)
        Task {
            await HealthKitManager.shared.saveWaterIntake(ml: ml, for: date)
        }
        #endif

        Task {
            await rescheduleNotifications()
        }
    }

    /// Fuegt eine Tasse Kaffee hinzu
    func addCoffee(for date: Date) {
        let record = writableDayRecord(for: date)
        let caffeine = record.bookCoffee(cups: 1, caffeineMgPerCup: profile?.caffeineMgPerCup ?? UserProfile.defaultCaffeineMgPerCup)
        commitCoffee(record, for: date)

        #if canImport(HealthKit)
        Task {
            await HealthKitManager.shared.saveCaffeine(mg: caffeine, for: date)
        }
        #endif
    }

    /// Entfernt eine Tasse Kaffee (nicht unter 0)
    func removeCoffee(for date: Date) {
        let record = writableDayRecord(for: date)
        guard record.coffeeCups > 0 else { return }
        record.bookCoffee(cups: -1, caffeineMgPerCup: profile?.caffeineMgPerCup ?? UserProfile.defaultCaffeineMgPerCup)
        commitCoffee(record, for: date)
    }

    /// Setzt Kaffee-Tassen direkt (manuelles Editieren)
    func setCoffeeCups(_ cups: Int, for date: Date) {
        let record = writableDayRecord(for: date)
        record.setCoffeeCups(cups, caffeineMgPerCup: profile?.caffeineMgPerCup ?? UserProfile.defaultCaffeineMgPerCup)
        commitCoffee(record, for: date)
    }

    private func commitCoffee(_ record: DayRecord, for date: Date) {
        try? modelContext.save()
        dayRecord = record
        refreshCoffeeStreak(today: date)
        refreshWidgetsAndComplication()
    }

    /// Aktualisiert die gecachte Kaffee-Streak (nur aus ViewModel-Methoden aufrufen,
    /// NIE aus einem View-Body — sonst Update-Loop).
    func refreshCoffeeStreak(today: Date = Date()) {
        guard let profile else {
            coffeeStreak = 0
            return
        }
        // Ueber Tage falten, nicht ueber Records: zwei Geraete-Duplikate eines
        // Tages sind ein Tag (#67). Fenster statt Volltabelle — laenger als die
        // bisherige Streak kann die naechste nicht werden.
        let start = Calendar.current.date(byAdding: .day, value: -Self.streakWindowDays, to: today) ?? today
        let counts = DayRecord.days(in: modelContext, from: start, to: today).map {
            CoffeeStreakCalculator.DailyCount(date: $0.date, cups: $0.coffeeCups)
        }
        coffeeStreak = CoffeeStreakCalculator.currentStreak(
            counts: counts,
            goalForDay: { profile.coffeeGoal(for: $0) },
            today: today
        )
    }

    /// Kaffee-Ziel fuer einen bestimmten Tag (beruecksichtigt Wochenend-Bonus)
    func coffeeGoal(for date: Date) -> Int {
        profile?.coffeeGoal(for: date) ?? 3
    }

    /// Setzt die Wasseraufnahme direkt (manuelles Editieren)
    func setWaterIntake(ml: Int, for date: Date) {
        let record = writableDayRecord(for: date)
        record.waterIntakeMl = ml
        try? modelContext.save()
        dayRecord = record
        refreshWidgetsAndComplication()

        Task {
            await rescheduleNotifications()
        }
    }

    /// Laedt den Durchschnitt der Aktivitaetskalorien der letzten N Tage
    /// - Returns: Durchschnitt oder nil wenn weniger als 3 Tage mit > 100 kcal vorhanden
    func fetchAverageActivityKcal(days: Int = 6) -> Int? {
        let endDate = Date().addingDays(-1)  // Gestern
        guard let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) else {
            return nil
        }

        return DayRecord.averageActiveEnergy(in: modelContext, from: startDate, to: endDate)
    }


    /// Verbleibende Kalorien
    var remainingCalories: Double {
        NutrientCalculator.remainingCalories(consumed: summary.totalCalories, goal: effectiveCalorieGoal)
    }

    /// Kalorienfortschritt (0.0 - 1.0+)
    var calorieProgress: Double {
        NutrientCalculator.progress(consumed: summary.totalCalories, goal: effectiveCalorieGoal)
    }

    // MARK: - Notifications

    /// Scheduled Notifications neu basierend auf aktuellem Stand
    private func rescheduleNotifications() async {
        guard let profile else { return }

        let trackedMeals = Set(entries.map(\.mealType))
        let currentWater = dayRecord?.waterIntakeMl ?? 0

        await NotificationManager.shared.rescheduleAll(
            profile: profile,
            currentWaterIntake: currentWater,
            trackedMeals: trackedMeals
        )
    }
}

// MARK: - Wochenleiste

extension DayViewModel {

    /// Ein Tag der Wochenleiste: wie voll sein Budget ist und wie er dasteht.
    ///
    /// Traegt bewusst nur, was die Leiste zeichnet. Die Bewertung kommt aus
    /// `DayScore` — derselben Quelle wie Kalorienring und Ambient-Hintergrund;
    /// ein zweiter Erfolgsbegriff im selben Bildschirm waere verwirrend.
    struct WeekDay: Identifiable, Equatable, Sendable {
        let date: Date
        let eatenCalories: Double
        let calorieGoal: Int
        /// Ob an diesem Tag ueberhaupt etwas erfasst wurde
        let hasEntries: Bool

        var id: Date { date }

        /// Verbrauchtes Budget als Verhaeltnis, ungedeckelt — kann ueber 1 liegen.
        var budgetShare: Double {
            guard calorieGoal > 0, hasEntries else { return 0 }
            return eatenCalories / Double(calorieGoal)
        }

        /// Anteil des verbrauchten Budgets, 0…1 — die Laenge des Balkens.
        /// Bei Ueberschreitung voll, die Farbe traegt dann den Rest der Aussage.
        var fill: Double { min(budgetShare, 1) }

        var score: DayScore {
            DayScore.compute(eatenCalories: eatenCalories, calorieGoal: calorieGoal)
        }
    }

    /// Laedt die sieben Tage der Woche, in der `date` liegt.
    ///
    /// Ein Fetch fuer die Eintraege, einer fuer die Tagesrekorde — nicht sieben
    /// einzelne Ladevorgaenge. Die Rekorde kommen ueber `DayRecord.days(in:from:to:)`,
    /// damit CloudKit-Duplikate als ein Tag zaehlen und nicht als mehrere.
    func refreshWeek(around date: Date) {
        let days = date.weekDays
        guard let first = days.first?.startOfDay, let last = days.last?.endOfDay else { return }

        let descriptor = FetchDescriptor<DiaryEntry>(
            predicate: #Predicate<DiaryEntry> { entry in
                entry.date >= first && entry.date <= last
            }
        )
        let entriesByDay = Dictionary(
            grouping: (try? modelContext.fetch(descriptor)) ?? [],
            by: { $0.date.startOfDay }
        )
        let recordsByDay = Dictionary(
            uniqueKeysWithValues: DayRecord.days(in: modelContext, from: first, to: last)
                .map { ($0.date, $0) }
        )

        week = days.map { day in
            let dayEntries = entriesByDay[day] ?? []
            let record = recordsByDay[day]
            let breakdown = NutrientCalculator.goalBreakdown(
                profile: profile,
                date: day,
                workoutCaloriesKcal: record?.workoutCaloriesKcal ?? 0,
                nonWorkoutActiveEnergy: record?.nonWorkoutActiveEnergy ?? 0
            )
            return WeekDay(
                date: day,
                eatenCalories: NutrientCalculator.calculateDaySummary(entries: dayEntries).totalCalories,
                calorieGoal: breakdown.total,
                hasEntries: !dayEntries.isEmpty
            )
        }
    }
}

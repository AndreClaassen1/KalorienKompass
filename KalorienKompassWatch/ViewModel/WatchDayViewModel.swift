//
//  WatchDayViewModel.swift
//  KalorienKompassWatch
//
//  Erstellt von André Claaßen am 06.02.26.
//
//  Vereinfachte Version von DayViewModel fuer die Watch.
//  Fokussiert auf "heute" ohne Datums-Navigator.
//

#if os(watchOS)
import SwiftUI
import SwiftData
import WidgetKit

/// ViewModel fuer die Watch-Tageszusammenfassung
@Observable
final class WatchDayViewModel {
    let modelContext: ModelContext

    /// Eintraege des aktuellen Tages
    var entries: [DiaryEntry] = []

    /// Tagesrekord (Schritte, Gewicht, Wasser)
    var dayRecord: DayRecord?

    /// Benutzerprofil
    var profile: UserProfile?

    /// Workouts des Tages
    var workouts: [WorkoutEntry] = []

    /// Zuletzt gebuchter Eintrag — ermoeglicht das Undo-Banner im Fokus-Screen
    var lastAddedEntry: DiaryEntry?

    /// Tageszusammenfassung
    var summary: NutrientCalculator.DaySummary {
        NutrientCalculator.calculateDaySummary(entries: entries)
    }

    /// CloudKit-Import-Observer fuer Auto-Refresh
    @ObservationIgnored private var reloader: RemoteImportReloader?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        reloader = RemoteImportReloader { [weak self] in await self?.loadToday() }
    }

    /// Laedt die Daten fuer heute
    @MainActor
    func loadToday() async {
        let date = Date()
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

        // Tagesrekord nur lesen: kein Record ohne Eingabe, keine Bereinigung im
        // Anzeigepfad (Issue #65).
        dayRecord = DayRecord.existing(in: modelContext, for: date)

        // Profil nur lesen, nicht bereinigen — die Watch bearbeitet keine
        // Einstellungen und darf deshalb nie ein Profil loeschen (Issue #63).
        profile = UserProfile.existing(in: modelContext)

        // HealthKit: erst messen, dann erst einen Record besorgen
        let (metrics, fetchedWorkouts) = await WatchHealthKitManager.shared.fetchDayMetrics(for: date)
        workouts = fetchedWorkouts
        if metrics.hasData {
            let record = writableDayRecord(for: date)
            metrics.apply(to: record)
            // Nur committen, wenn wirklich etwas anders ist (siehe DayViewModel)
            if modelContext.hasChanges { try? modelContext.save() }
            dayRecord = record
        }

        storeLocalComplicationSnapshot()
    }

    /// Haelt den Stand fest, den die Komplikation von der Uhr uebernehmen soll.
    ///
    /// Die Uhr stempelt selbst, statt dem Widget das Aenderungsdatum der Store-Datei
    /// zu ueberlassen: SQLite fasst die Store-Dateien schon beim Lesen an, damit
    /// waere jeder lokale Stand immer „von jetzt" und der vom iPhone uebertragene
    /// koennte nie gewinnen (Issue #69). Ausserdem laesst sich so eine Buchung auf
    /// der Uhr nicht von einem aelteren iPhone-Stand ueberschreiben.
    private func storeLocalComplicationSnapshot() {
        guard Calendar.current.isDateInToday(Date()) else { return }
        ComplicationSnapshot(
            day: Date(),
            totalCaloriesConsumed: summary.totalCalories,
            effectiveCalorieGoal: effectiveCalorieGoal,
            remainingCalories: remainingCalories,
            waterIntakeMl: dayRecord?.waterIntakeMl ?? 0,
            waterGoalMl: profile?.dailyWaterGoalMl ?? 2000,
            updatedAt: Date()
        ).store(as: .local)
    }

    /// Bringt Komplikation und lokalen Stand auf denselben Stand.
    private func refreshComplication() {
        storeLocalComplicationSnapshot()
        WidgetCenter.shared.reloadAllTimelines()
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

    /// Aktivitaetskalorien ohne Training
    var nonWorkoutActiveEnergy: Int { dayRecord.nonWorkoutActiveEnergy }

    /// Effektives Kalorienziel — delegiert an einheitliche NutrientCalculator-Logik
    var effectiveCalorieGoal: Int {
        NutrientCalculator.effectiveCalorieGoal(
            profile: profile,
            dayRecord: dayRecord,
            nonWorkoutActiveEnergy: nonWorkoutActiveEnergy
        )
    }

    /// Kalorienbudget fuer eine Mahlzeit
    func calorieBudgetForMeal(_ mealType: MealType) -> Int {
        return Int(Double(effectiveCalorieGoal) * mealType.budgetWeight)
    }

    /// Verbleibende Kalorien
    var remainingCalories: Double {
        NutrientCalculator.remainingCalories(consumed: summary.totalCalories, goal: effectiveCalorieGoal)
    }

    /// Kalorienfortschritt (0.0 - 1.0+)
    var calorieProgress: Double {
        NutrientCalculator.progress(consumed: summary.totalCalories, goal: effectiveCalorieGoal)
    }

    /// Schrittfortschritt (0.0 - 1.0+)
    var stepsProgress: Double {
        let steps = dayRecord?.steps ?? 0
        let goal = profile?.dailyStepsGoal ?? 10000
        guard goal > 0 else { return 0 }
        return Double(steps) / Double(goal)
    }

    /// Wasserfortschritt (0.0 - 1.0+)
    var waterProgress: Double {
        let water = dayRecord?.waterIntakeMl ?? 0
        let goal = profile?.dailyWaterGoalMl ?? 2000
        guard goal > 0 else { return 0 }
        return Double(water) / Double(goal)
    }

    /// Fuegt einen Quick-Eintrag hinzu (fuer schnelle Kalorienerfassung)
    @MainActor
    func addQuickEntry(name: String, calories: Int, mealType: MealType) async {
        // FoodItem erstellen
        let foodItem = FoodItem(
            name: name.isEmpty ? String(localized: "quick_entry_default_name") : name,
            caloriesPer100g: Double(calories),
            proteinPer100g: 0,
            carbsPer100g: 0,
            fatPer100g: 0
        )

        // DiaryEntry erstellen (100g = angegebene Kalorien)
        let entry = DiaryEntry(
            date: Date(),
            mealType: mealType,
            amountGrams: 100,
            foodItem: foodItem
         )

        modelContext.insert(foodItem)
        modelContext.insert(entry)
        try? modelContext.save()

        // Daten neu laden + Komplikationen aktualisieren
        await loadToday()
        refreshComplication()
    }

    /// Fuegt einen KI-geschaetzten Eintrag hinzu
    @MainActor
    func addAIEntry(estimate: AIFoodEstimate, mealType: MealType, portionGrams: Double) async {
        // Ueber FocusBooking, nicht selbst gebaut: die eigene Kopie hier verlor
        // Zucker, gesaettigte Fette und Salz und setzte `isQuickEntry` und
        // `isUserCreated` widerspruechlich zugleich.
        let entry = FocusBooking.book(
            estimate: estimate,
            meal: mealType,
            date: Date(),
            amountGrams: portionGrams,
            context: modelContext
        )
        lastAddedEntry = entry
        await loadToday()
        refreshComplication()
    }

    /// Macht die letzte Buchung rueckgaengig (Fokus-Undo). Entfernt Eintrag und
    /// das zugehoerige Quick-Entry-FoodItem.
    @MainActor
    func undoLast() async {
        guard let entry = lastAddedEntry else { return }
        let foodItemIds = entry.foodItem.map { $0.isQuickEntry ? [$0.itemId] : [] } ?? []
        FocusBooking.undo(
            entryIds: [entry.entryId],
            foodItemIds: foodItemIds,
            context: modelContext
        )
        lastAddedEntry = nil
        await loadToday()
        refreshComplication()
    }

    /// Fuegt Wasser hinzu (Inkrement)
    @MainActor
    func addWater(ml: Int) async {
        // Schreibpfad: legt den Record an, falls der Tag noch keinen hat.
        let record = writableDayRecord(for: Date())
        record.waterIntakeMl += ml
        try? modelContext.save()
        dayRecord = record

        // HealthKit-Sync + Komplikationen aktualisieren
        await WatchHealthKitManager.shared.saveWaterIntake(ml: ml, for: Date())
        refreshComplication()
    }
}
#endif


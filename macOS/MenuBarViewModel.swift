//
//  MenuBarViewModel.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 06.04.26.
//

#if os(macOS)
import SwiftUI
import SwiftData
import WidgetKit
import os

/// ViewModel fuer die macOS Menubar-Anzeige — Singleton mit eigenem ModelContext
@Observable
final class MenuBarViewModel {
    private static let logger = Logger(subsystem: "com.andre.claassen.KalorienKompass", category: "MenuBar")

    static let shared = MenuBarViewModel()

    // MARK: - Daten

    private(set) var entries: [DiaryEntry] = []
    private(set) var dayRecord: DayRecord?
    private(set) var profile: UserProfile?

    // MARK: - Berechnete Werte

    var summary: NutrientCalculator.DaySummary {
        NutrientCalculator.calculateDaySummary(entries: entries)
    }

    var effectiveCalorieGoal: Int {
        NutrientCalculator.effectiveCalorieGoal(
            profile: profile,
            dayRecord: dayRecord,
            nonWorkoutActiveEnergy: nonWorkoutActiveEnergy
        )
    }

    var remainingCalories: Double {
        NutrientCalculator.remainingCalories(consumed: summary.totalCalories, goal: effectiveCalorieGoal)
    }

    var calorieProgress: Double {
        NutrientCalculator.progress(consumed: summary.totalCalories, goal: effectiveCalorieGoal)
    }

    var isOverBudget: Bool { remainingCalories < 0 }

    var waterIntakeMl: Int { dayRecord?.waterIntakeMl ?? 0 }
    var waterGoalMl: Int { profile?.dailyWaterGoalMl ?? 2000 }

    var coffeeCups: Int { dayRecord?.coffeeCups ?? 0 }
    var coffeeGoal: Int { profile?.coffeeGoal(for: Date()) ?? 3 }

    var nonWorkoutActiveEnergy: Int {
        dayRecord.nonWorkoutActiveEnergy
    }

    var menuBarText: String {
        let eaten = Int(summary.totalCalories)
        let goal = effectiveCalorieGoal
        return "\(eaten) / \(goal) kcal"
    }

    var menuBarSymbol: String {
        isOverBudget ? "exclamationmark.triangle.fill" : "leaf.fill"
    }

    var mainMealSummaries: [(mealType: MealType, calories: Double)] {
        [MealType.breakfast, .lunch, .dinner, .snack].map { meal in
            (mealType: meal, calories: NutrientCalculator.calculateMealSummary(entries: entries, mealType: meal).totalCalories)
        }
    }

    var filledGlasses: Int {
        waterIntakeMl / 250
    }

    var waterSlotCount: Int {
        DrinkRow.slotCount(goal: max(waterGoalMl / 250, 1), filled: filledGlasses)
    }

    var coffeeSlotCount: Int {
        DrinkRow.slotCount(goal: coffeeGoal, filled: coffeeCups)
    }

    /// Ueber der Obergrenze. Das Kaffeeziel ist eine Hoechstmenge, kein Soll
    /// (Issue #77) — deshalb liegt die Grenze bei `>` und nicht bei `>=`.
    var coffeeOverLimit: Bool { coffeeCups > coffeeGoal }

    // MARK: - Aktionen

    func setWaterGlasses(_ count: Int) {
        mutateToday { $0.waterIntakeMl = count * 250 }
        Self.logger.debug("Wasser gesetzt: \(count, privacy: .public) Glaeser (\(count * 250, privacy: .public) ml)")
    }

    /// Fuellt ein Glas nach. Ungedeckelt, weil die Reihe im Popover ueber das
    /// Ziel hinaus buchen laesst — ein Deckel hier waere ein zweiter Maszstab.
    func addWaterGlass() {
        setWaterGlasses(filledGlasses + 1)
    }

    /// Bucht eine Tasse dazu — der Weg des Tastaturkuerzels ⌘⇧K. Ueber
    /// `bookCoffee` und nicht ueber `setCoffeeCups`, weil ein Delta einen von der
    /// Profilangabe abweichenden Koffeinwert stehen laesst, statt ihn neu zu
    /// rechnen.
    func addCoffee() {
        mutateToday { $0.bookCoffee(cups: 1, caffeineMgPerCup: caffeineMgPerCup) }
        Self.logger.debug("Kaffee: \(self.coffeeCups, privacy: .public) Tassen")
    }

    /// Setzt die Tassenzahl direkt — der Weg, den die Tassen-Reihe im Popover
    /// nutzt. Ueber `DayRecord.setCoffeeCups`, damit Koffein und Tassen zusammen
    /// bleiben.
    func setCoffeeCups(_ cups: Int) {
        mutateToday { $0.setCoffeeCups(cups, caffeineMgPerCup: caffeineMgPerCup) }
        Self.logger.debug("Kaffee gesetzt: \(self.coffeeCups, privacy: .public) Tassen")
    }

    /// Aendert den heutigen Datensatz und schreibt ihn weg. Alle Aktionen des
    /// Popovers laufen hier durch, damit Speichern, Uebernehmen in `dayRecord`
    /// und das Nachladen der Widgets an einer Stelle stehen.
    private func mutateToday(_ change: (DayRecord) -> Void) {
        guard let context = modelContext else { return }
        let record = DayRecord.canonical(in: context, for: Date())

        change(record)
        try? context.save()
        dayRecord = record
        WidgetCenter.shared.reloadAllTimelines()
    }

    private var caffeineMgPerCup: Int {
        profile?.caffeineMgPerCup ?? UserProfile.defaultCaffeineMgPerCup
    }


    // MARK: - Internes

    @ObservationIgnored private var modelContext: ModelContext?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var reloader: RemoteImportReloader?

    private init() {
        setupModelContext()
        setupTimer()
        reloader = RemoteImportReloader { [weak self] in self?.loadToday() }
        loadToday()
    }

    // MARK: - Setup

    private func setupModelContext() {
        modelContext = ModelContext(DataModel.shared.modelContainer)
        modelContext?.autosaveEnabled = false
    }

    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.loadToday()
            }
        }
    }

    // MARK: - Daten laden

    func loadToday() {
        guard let context = modelContext else { return }

        let today = Date().startOfDay
        let endOfDay = today.endOfDay

        let entryDescriptor = FetchDescriptor<DiaryEntry>(
            predicate: #Predicate<DiaryEntry> { entry in
                entry.date >= today && entry.date <= endOfDay
            },
            sortBy: [SortDescriptor(\.mealTypeRaw), SortDescriptor(\.createdAt)]
        )
        entries = (try? context.fetch(entryDescriptor)) ?? []

        // Lesepfad: kein Anlegen, kein Bereinigen (Issue #65)
        dayRecord = DayRecord.existing(in: context, for: today)

        // Profil kanonisch nach createdAt lesen, ohne Bereinigung (Issue #63)
        profile = UserProfile.existing(in: context)

        Self.logger.debug("MenuBar geladen: \(self.entries.count, privacy: .public) Eintraege, \(Int(self.summary.totalCalories), privacy: .public) kcal gegessen")
    }

    deinit {
        timer?.invalidate()
    }
}
#endif

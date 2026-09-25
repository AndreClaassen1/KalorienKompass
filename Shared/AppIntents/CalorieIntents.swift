//
//  CalorieIntents.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 10.02.26.
//

import AppIntents
import SwiftData
import WidgetKit
import os

// MARK: - Hilfsfunktionen

/// Gemeinsame Logik fuer DayRecord- und DiaryEntry-Zugriff in App Intents
enum IntentDataAccess {
    private static let logger = Logger(
        subsystem: "com.andre.claassen.KalorienKompass",
        category: "AppIntents"
    )

    /// Lesepfad: liefert den DayRecord des Tages, oder `nil`, wenn es keinen gibt.
    /// Legt nichts an und bereinigt nichts (Issue #65).
    @MainActor
    static func fetchDayRecord(for date: Date, in context: ModelContext) -> DayRecord? {
        DayRecord.existing(in: context, for: date)
    }

    /// Schreibpfad: liefert den DayRecord zum Beschreiben, legt ihn bei Bedarf an
    /// und fuehrt CloudKit-Duplikate zusammen.
    @MainActor
    static func writableDayRecord(for date: Date, in context: ModelContext) -> DayRecord {
        DayRecord.canonical(in: context, for: date)
    }

    /// Laedt die DiaryEntries fuer ein Datum
    @MainActor
    static func fetchEntries(for date: Date, in context: ModelContext) -> [DiaryEntry] {
        let startOfDay = date.startOfDay
        let endOfDay = date.endOfDay

        let descriptor = FetchDescriptor<DiaryEntry>(
            predicate: #Predicate<DiaryEntry> { entry in
                entry.date >= startOfDay && entry.date <= endOfDay
            },
            sortBy: [SortDescriptor(\.mealTypeRaw), SortDescriptor(\.createdAt)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    /// Schickt der Uhr den aktuellen Tagesstand.
    ///
    /// Ohne das erreichen Siri- und Kurzbefehl-Buchungen die Komplikation nie: bei
    /// ihnen laeuft die App gar nicht, es gibt also kein `loadDay`, das den Stand
    /// weiterreichen koennte (Issue #69).
    @MainActor
    static func pushComplicationSnapshot(in context: ModelContext) {
        let today = Date()
        let entries = fetchEntries(for: today, in: context)
        let profile = fetchProfile(in: context)
        let record = fetchDayRecord(for: today, in: context)

        let summary = NutrientCalculator.calculateDaySummary(entries: entries)
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile,
            dayRecord: record,
            nonWorkoutActiveEnergy: record.nonWorkoutActiveEnergy
        )

        // Nur iOS: den Sender gibt es nur dort. Auf dem Mac fuehrt der Weg zur Uhr
        // ueber CloudKit und die Hintergrund-Aktualisierung der Watch-App.
        #if os(iOS)
        WatchSnapshotSender.shared.send(
            ComplicationSnapshot(
                day: today,
                totalCaloriesConsumed: summary.totalCalories,
                effectiveCalorieGoal: goal,
                remainingCalories: NutrientCalculator.remainingCalories(
                    consumed: summary.totalCalories,
                    goal: goal
                ),
                waterIntakeMl: record?.waterIntakeMl ?? 0,
                waterGoalMl: profile?.dailyWaterGoalMl ?? 2000,
                updatedAt: Date()
            )
        )
        #endif
    }

    /// Laedt das kanonische UserProfile (aeltestes `createdAt`, siehe Issue #63)
    @MainActor
    static func fetchProfile(in context: ModelContext) -> UserProfile? {
        UserProfile.existing(in: context)
    }

    /// Sucht ein Lebensmittel nach Name in SwiftData (keine Quick Entries)
    @MainActor
    static func searchFood(name: String, in context: ModelContext) -> [FoodItem] {
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate<FoodItem> { food in
                food.name.localizedStandardContains(name)
                && food.isQuickEntry == false
            },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Sucht ein Lebensmittel per Barcode: SwiftData → Offline-DB → Online-API
    @MainActor
    static func lookupBarcode(_ barcode: String, in context: ModelContext) async -> FoodItem? {
        // 1. SwiftData (bereits gespeichert?)
        let bc = barcode
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate<FoodItem> { food in
                food.barcode == bc
            }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }

        // 2. Offline-DB
        let offlineDB = OfflineDatabaseService.shared
        do {
            try await offlineDB.open()
            if let product = await offlineDB.lookupBarcode(barcode) {
                let foodItem = product.toFoodItem()
                context.insert(foodItem)
                try? context.save()
                return foodItem
            }
        } catch {
            logger.warning("Offline-DB nicht verfuegbar: \(error.localizedDescription, privacy: .public)")
        }

        // 3. Online-API
        let offService = OpenFoodFactsService.shared
        do {
            if let product = try await offService.lookupBarcode(barcode) {
                let foodItem = await offService.createFoodItem(from: product)
                context.insert(foodItem)
                try? context.save()
                return foodItem
            }
        } catch {
            logger.warning("Online-Lookup fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
        }

        return nil
    }

    /// Sucht einen DiaryEntry nach Lebensmittelname und optionalem Mahlzeitentyp fuer heute
    @MainActor
    static func findEntry(
        foodName: String,
        mealType: MealType?,
        date: Date,
        in context: ModelContext
    ) -> DiaryEntry? {
        let entries = fetchEntries(for: date, in: context)
        let filtered = entries.filter { entry in
            guard let name = entry.foodItem?.name else { return false }
            let nameMatch = name.localizedStandardContains(foodName)
            if let meal = mealType {
                return nameMatch && entry.mealType == meal
            }
            return nameMatch
        }
        return filtered.last
    }

    /// Laedt Favoriten (FoodCustomization + zugehoerige FoodItems)
    @MainActor
    static func fetchFavorites(in context: ModelContext) -> [FoodItem] {
        let descriptor = FetchDescriptor<FoodCustomization>(
            predicate: #Predicate<FoodCustomization> { $0.isFavorite == true }
        )
        let customizations = (try? context.fetch(descriptor)) ?? []

        var items: [FoodItem] = []
        for cust in customizations {
            if let barcode = cust.barcode, !barcode.isEmpty {
                let bc = barcode
                let foodDesc = FetchDescriptor<FoodItem>(
                    predicate: #Predicate<FoodItem> { $0.barcode == bc }
                )
                if let food = (try? context.fetch(foodDesc))?.first {
                    items.append(food)
                    continue
                }
            }
            let fid = cust.foodItemId
            if !fid.isEmpty {
                let foodDesc = FetchDescriptor<FoodItem>(
                    predicate: #Predicate<FoodItem> { $0.itemId == fid }
                )
                if let food = (try? context.fetch(foodDesc))?.first {
                    items.append(food)
                }
            }
        }
        return items.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

}

// MARK: - Restkalorien abfragen

/// App Intent: "Wie viele Kalorien hab ich noch?"
struct GetRemainingCaloriesIntent: AppIntent {
    static var title: LocalizedStringResource = "Restkalorien abfragen"
    static var description: IntentDescription = "Zeigt die verbleibenden Kalorien fuer heute an."

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = DataModel.shared.modelContainer
        let context = ModelContext(container)
        let today = Date()

        let entries = IntentDataAccess.fetchEntries(for: today, in: context)
        let dayRecord = IntentDataAccess.fetchDayRecord(for: today, in: context)
        let profile = IntentDataAccess.fetchProfile(in: context)

        let summary = NutrientCalculator.calculateDaySummary(entries: entries)
        let workoutCals = (dayRecord?.workoutCaloriesKcal ?? 0)
        let activeEnergy = (dayRecord?.activeEnergyKcal ?? 0)
        let nonWorkoutActive = max(activeEnergy - workoutCals, 0)

        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile,
            dayRecord: dayRecord,
            nonWorkoutActiveEnergy: nonWorkoutActive
        )

        let remaining = Int(NutrientCalculator.remainingCalories(
            consumed: summary.totalCalories,
            goal: goal
        ))

        let eaten = Int(summary.totalCalories)

        if remaining >= 0 {
            return .result(
                dialog: "Du hast noch \(remaining) kcal übrig. Bisher gegessen: \(eaten) von \(goal) kcal."
            )
        } else {
            return .result(
                dialog: "Du hast dein Ziel um \(abs(remaining)) kcal überschritten. Gegessen: \(eaten) von \(goal) kcal."
            )
        }
    }
}

// MARK: - Tagesuebersicht abfragen

/// App Intent: Tagesuebersicht mit Kalorien und Makros
struct GetDaySummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Tagesübersicht"
    static var description: IntentDescription = "Zeigt die Kalorien- und Makro-Zusammenfassung für einen Tag."

    @Parameter(title: "Datum")
    var date: Date?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = DataModel.shared.modelContainer
        let context = ModelContext(container)
        let targetDate = date ?? Date()

        let entries = IntentDataAccess.fetchEntries(for: targetDate, in: context)
        let dayRecord = IntentDataAccess.fetchDayRecord(for: targetDate, in: context)
        let profile = IntentDataAccess.fetchProfile(in: context)

        let summary = NutrientCalculator.calculateDaySummary(entries: entries)
        let nonWorkoutActive = dayRecord.nonWorkoutActiveEnergy

        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile,
            dayRecord: dayRecord,
            nonWorkoutActiveEnergy: nonWorkoutActive
        )

        let remaining = Int(NutrientCalculator.remainingCalories(
            consumed: summary.totalCalories,
            goal: goal
        ))

        let eaten = Int(summary.totalCalories)
        let protein = Int(summary.totalProtein)
        let carbs = Int(summary.totalCarbs)
        let fat = Int(summary.totalFat)
        let fiber = Int(summary.totalFiber)

        let dateString = targetDate.formattedMedium

        return .result(
            dialog: """
            \(dateString): \(eaten) von \(goal) kcal gegessen, \(remaining) kcal übrig. \
            Protein: \(protein)g, Kohlenhydrate: \(carbs)g, Fett: \(fat)g, Ballaststoffe: \(fiber)g.
            """
        )
    }
}

// MARK: - Wasser hinzufuegen

/// App Intent: Wasser zum Tagesrekord hinzufuegen
struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Wasser trinken"
    static var description: IntentDescription = "Fügt Wasser zur heutigen Aufnahme hinzu."

    @Parameter(title: "Menge in ml", default: 250)
    var amountMl: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = DataModel.shared.modelContainer
        let context = ModelContext(container)
        let today = Date()

        let record = IntentDataAccess.writableDayRecord(for: today, in: context)
        record.waterIntakeMl += amountMl
        try? context.save()

        WidgetCenter.shared.reloadAllTimelines()
        IntentDataAccess.pushComplicationSnapshot(in: context)

        let profile = IntentDataAccess.fetchProfile(in: context)
        let goalMl = profile?.dailyWaterGoalMl ?? 2000
        let currentLiters = String(format: "%.1f", Double(record.waterIntakeMl) / 1000.0)
        let goalLiters = String(format: "%.1f", Double(goalMl) / 1000.0)

        return .result(
            dialog: "\(amountMl) ml Wasser hinzugefügt. Aktuell: \(currentLiters) von \(goalLiters) Liter."
        )
    }
}

// MARK: - Kaffee eintragen

/// App Intent: Kaffee zum Tagesrekord hinzufuegen
///
/// Zaehlt Tassen **und** rechnet das Koffein hoch — genau wie der Knopf in der App
/// (`DayViewModel.addCoffee`). Die Menge pro Tasse steht im Profil, damit Espresso
/// und Filterkaffee nicht denselben Wert bekommen.
struct LogCoffeeIntent: AppIntent {
    static var title: LocalizedStringResource = "Kaffee trinken"
    static var description: IntentDescription = "Trägt getrunkenen Kaffee für heute ein."

    @Parameter(title: "Tassen", default: 1, inclusiveRange: (1, 20))
    var cups: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(DataModel.shared.modelContainer)
        let today = Date()

        let profile = IntentDataAccess.fetchProfile(in: context)
        let record = IntentDataAccess.writableDayRecord(for: today, in: context)
        let caffeine = record.bookCoffee(
            cups: cups,
            caffeineMgPerCup: profile?.caffeineMgPerCup ?? UserProfile.defaultCaffeineMgPerCup
        )
        try? context.save()

        WidgetCenter.shared.reloadAllTimelines()
        IntentDataAccess.pushComplicationSnapshot(in: context)

        // Der Koffein-Wert gehoert auch nach HealthKit, sonst weicht der Tag dort
        // von dem in der App ab, sobald per Sprache gebucht wird.
        #if os(iOS)
        Task { await HealthKitManager.shared.saveCaffeine(mg: caffeine, for: today) }
        #endif

        let goal = profile?.coffeeGoal(for: today) ?? 4
        let getrunken = cups == 1 ? "Eine Tasse" : "\(cups) Tassen"
        return .result(
            dialog: "\(getrunken) Kaffee eingetragen. Heute: \(record.coffeeCups) von \(goal) Tassen, \(Int(record.caffeineMg ?? 0)) mg Koffein."
        )
    }
}

// MARK: - Schnelleintrag

/// App Intent: Schnelleintrag mit Kalorien und optionalen Makros
struct QuickAddFoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Kalorien eintragen"
    static var description: IntentDescription = "Erstellt einen Schnelleintrag mit Kalorien und optionalen Makros."

    @Parameter(title: "Name")
    var name: String?

    @Parameter(title: "Kalorien")
    var calories: Int

    @Parameter(title: "Mahlzeit", default: .snack)
    var mealType: MealTypeAppEnum

    @Parameter(title: "Protein (g)")
    var protein: Double?

    @Parameter(title: "Kohlenhydrate (g)")
    var carbs: Double?

    @Parameter(title: "Fett (g)")
    var fat: Double?

    @Parameter(title: "Ballaststoffe (g)")
    var fiber: Double?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = DataModel.shared.modelContainer
        let context = ModelContext(container)
        let today = Date()

        // FoodItem als Quick Entry erstellen
        let foodItem = FoodItem(
            name: name ?? String(localized: "quick_entry_default_name"),
            caloriesPer100g: Double(calories),
            proteinPer100g: protein ?? 0,
            carbsPer100g: carbs ?? 0,
            fatPer100g: fat ?? 0,
            fiberPer100g: fiber ?? 0
        )
        foodItem.isQuickEntry = true
        foodItem.isUserCreated = true
        context.insert(foodItem)

        // DiaryEntry mit 100g (= exakt die angegebenen Kalorien)
        let entry = DiaryEntry(
            date: today,
            mealType: mealType.mealType,
            amountGrams: 100,
            foodItem: foodItem
        )
        context.insert(entry)
        try? context.save()

        WidgetCenter.shared.reloadAllTimelines()
        IntentDataAccess.pushComplicationSnapshot(in: context)

        let displayName = name ?? String(localized: "quick_entry_default_name")
        let mealName = mealType.mealType.localizedString

        return .result(
            dialog: "\(calories) kcal als \"\(displayName)\" zum \(mealName) hinzugefügt."
        )
    }
}

// MARK: - P1: Mahlzeit erfassen

/// App Intent: Ein bekanntes Lebensmittel zu einer Mahlzeit hinzufuegen
struct LogFoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Lebensmittel eintragen"
    static var description: IntentDescription = "Fügt ein bekanntes Lebensmittel zu einer Mahlzeit hinzu."

    @Parameter(title: "Lebensmittel")
    var foodName: String

    @Parameter(title: "Menge in Gramm", default: 100)
    var amountGrams: Int

    @Parameter(title: "Mahlzeit", default: .snack)
    var mealType: MealTypeAppEnum

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = DataModel.shared.modelContainer
        let context = ModelContext(container)

        let results = IntentDataAccess.searchFood(name: foodName, in: context)

        guard let foodItem = results.first else {
            return .result(
                dialog: "Kein Lebensmittel mit dem Namen \"\(foodName)\" gefunden. Bitte suche es zuerst in der App."
            )
        }

        let entry = DiaryEntry(
            date: Date(),
            mealType: mealType.mealType,
            amountGrams: Double(amountGrams),
            foodItem: foodItem
        )
        context.insert(entry)
        try? context.save()

        WidgetCenter.shared.reloadAllTimelines()
        IntentDataAccess.pushComplicationSnapshot(in: context)

        let calories = Int(foodItem.caloriesPer100g * Double(amountGrams) / 100.0)
        let mealName = mealType.mealType.localizedString

        return .result(
            dialog: "\(amountGrams)g \(foodItem.name) zum \(mealName) hinzugefügt (\(calories) kcal)."
        )
    }
}

// MARK: - P1: Wasserstand abfragen

/// App Intent: Aktuelle Wasseraufnahme und Ziel abfragen
struct GetWaterStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Wasserstand abfragen"
    static var description: IntentDescription = "Zeigt die aktuelle Wasseraufnahme und das Tagesziel."

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = DataModel.shared.modelContainer
        let context = ModelContext(container)
        let today = Date()

        let record = IntentDataAccess.fetchDayRecord(for: today, in: context)
        let profile = IntentDataAccess.fetchProfile(in: context)

        let currentMl = record?.waterIntakeMl ?? 0
        let goalMl = profile?.dailyWaterGoalMl ?? 2000
        let glasses = currentMl / 250
        let glassesGoal = goalMl / 250
        let currentLiters = String(format: "%.1f", Double(currentMl) / 1000.0)
        let goalLiters = String(format: "%.1f", Double(goalMl) / 1000.0)

        if currentMl >= goalMl {
            return .result(
                dialog: "Ziel erreicht! Du hast \(currentLiters) von \(goalLiters) Liter getrunken (\(glasses) von \(glassesGoal) Gläsern)."
            )
        } else {
            let remainingMl = goalMl - currentMl
            return .result(
                dialog: "Du hast \(currentLiters) von \(goalLiters) Liter getrunken (\(glasses) von \(glassesGoal) Gläsern). Es fehlen noch \(remainingMl) ml."
            )
        }
    }
}

// MARK: - P1: Mahlzeit-Zusammenfassung

/// App Intent: Zusammenfassung fuer eine bestimmte Mahlzeit
struct GetMealSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Mahlzeit-Zusammenfassung"
    static var description: IntentDescription = "Zeigt was du bei einer bestimmten Mahlzeit gegessen hast."

    @Parameter(title: "Mahlzeit")
    var mealType: MealTypeAppEnum

    @Parameter(title: "Datum")
    var date: Date?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = DataModel.shared.modelContainer
        let context = ModelContext(container)
        let targetDate = date ?? Date()

        let allEntries = IntentDataAccess.fetchEntries(for: targetDate, in: context)
        let mealEntries = allEntries.filter { $0.mealType == mealType.mealType }
        let mealName = mealType.mealType.localizedString

        guard !mealEntries.isEmpty else {
            return .result(
                dialog: "Für \(mealName) sind noch keine Einträge vorhanden."
            )
        }

        let summary = NutrientCalculator.calculateMealSummary(
            entries: allEntries,
            mealType: mealType.mealType
        )

        let calories = Int(summary.totalCalories)
        let count = mealEntries.count

        // Eintraege auflisten (max. 5)
        let entryNames = mealEntries.prefix(5).compactMap { entry -> String? in
            guard let name = entry.foodItem?.name else { return nil }
            return "\(name) (\(Int(entry.calories)) kcal)"
        }

        let entryList = entryNames.joined(separator: ", ")
        let suffix = mealEntries.count > 5 ? " und \(mealEntries.count - 5) weitere" : ""

        return .result(
            dialog: "\(mealName): \(calories) kcal aus \(count) Einträgen. \(entryList)\(suffix)."
        )
    }
}

// MARK: - P1: Schritte abfragen

/// App Intent: Tagesschritte und Schrittziel abfragen
struct GetStepsIntent: AppIntent {
    static var title: LocalizedStringResource = "Schritte abfragen"
    static var description: IntentDescription = "Zeigt die heutigen Schritte und das Schrittziel."

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = DataModel.shared.modelContainer
        let context = ModelContext(container)
        let today = Date()

        let record = IntentDataAccess.fetchDayRecord(for: today, in: context)
        let profile = IntentDataAccess.fetchProfile(in: context)

        let steps = record?.steps ?? 0
        let goal = profile?.dailyStepsGoal ?? 10000

        if steps >= goal {
            return .result(
                dialog: "Schrittziel erreicht! Du hast \(steps) von \(goal) Schritten geschafft."
            )
        } else {
            let remaining = goal - steps
            let percent = goal > 0 ? steps * 100 / goal : 0
            return .result(
                dialog: "Du hast \(steps) von \(goal) Schritten geschafft (\(percent)%). Es fehlen noch \(remaining) Schritte."
            )
        }
    }
}

// MARK: - P1: Gewicht eintragen

/// App Intent: Koerpergewicht erfassen
struct LogWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Gewicht eintragen"
    static var description: IntentDescription = "Erfasst dein aktuelles Körpergewicht."

    @Parameter(title: "Gewicht in kg")
    var weightKg: Double

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = DataModel.shared.modelContainer
        let context = ModelContext(container)
        let today = Date()

        let record = IntentDataAccess.writableDayRecord(for: today, in: context)
        record.weight = weightKg
        try? context.save()

        WidgetCenter.shared.reloadAllTimelines()
        IntentDataAccess.pushComplicationSnapshot(in: context)

        // BMI berechnen
        let profile = IntentDataAccess.fetchProfile(in: context)
        let heightCm = profile?.heightCm ?? 175
        let heightM = heightCm / 100.0
        let bmi = weightKg / (heightM * heightM)
        let bmiString = String(format: "%.1f", bmi)

        let weightString = String(format: "%.1f", weightKg)

        // Zielgewicht-Fortschritt
        if let goalWeight = profile?.weightGoalKg, let startWeight = profile?.startWeightKg {
            let totalDiff = abs(startWeight - goalWeight)
            let currentDiff = abs(weightKg - goalWeight)
            let remainingKg = String(format: "%.1f", currentDiff)

            if totalDiff > 0 {
                let progress = Int(max(0, min(100, (1.0 - currentDiff / totalDiff) * 100)))
                return .result(
                    dialog: "\(weightString) kg eingetragen (BMI \(bmiString)). Noch \(remainingKg) kg bis zum Ziel (\(progress)% geschafft)."
                )
            }
        }

        return .result(
            dialog: "\(weightString) kg eingetragen. Dein BMI beträgt \(bmiString)."
        )
    }
}

// MARK: - P2: Lebensmittel suchen

/// App Intent: Lebensmittel in der Datenbank suchen
struct SearchFoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Lebensmittel suchen"
    static var description: IntentDescription = "Durchsucht die Lebensmittel-Datenbank nach Name."

    @Parameter(title: "Suchbegriff")
    var query: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = DataModel.shared.modelContainer
        let context = ModelContext(container)

        let results = IntentDataAccess.searchFood(name: query, in: context)

        guard !results.isEmpty else {
            return .result(
                dialog: "Keine Lebensmittel für \"\(query)\" gefunden. Suche in der App für Online-Ergebnisse."
            )
        }

        let items = results.prefix(5).map { food -> String in
            let brand = food.brand.map { " (\($0))" } ?? ""
            return "\(food.name)\(brand) — \(Int(food.caloriesPer100g)) kcal/100g"
        }

        let count = results.count
        let list = items.joined(separator: "; ")
        let suffix = count > 5 ? " und \(count - 5) weitere" : ""

        return .result(
            dialog: "\(count) Treffer für \"\(query)\": \(list)\(suffix)."
        )
    }
}

// MARK: - P2: Barcode nachschlagen

/// App Intent: Lebensmittel per Barcode finden
struct LookupBarcodeIntent: AppIntent {
    static var title: LocalizedStringResource = "Barcode nachschlagen"
    static var description: IntentDescription = "Findet ein Lebensmittel anhand des EAN/UPC-Barcodes."

    @Parameter(title: "Barcode")
    var barcode: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = DataModel.shared.modelContainer
        let context = ModelContext(container)

        guard let food = await IntentDataAccess.lookupBarcode(barcode, in: context) else {
            return .result(
                dialog: "Kein Produkt mit Barcode \(barcode) gefunden."
            )
        }

        let brand = food.brand.map { " von \($0)" } ?? ""
        let kcal = Int(food.caloriesPer100g)
        let protein = Int(food.proteinPer100g)
        let carbs = Int(food.carbsPer100g)
        let fat = Int(food.fatPer100g)

        return .result(
            dialog: "\(food.name)\(brand): \(kcal) kcal, \(protein)g Protein, \(carbs)g Kohlenhydrate, \(fat)g Fett pro 100g."
        )
    }
}

// MARK: - P2: Gewicht abfragen

/// App Intent: Aktuelles Gewicht und BMI abfragen
struct GetWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Gewicht abfragen"
    static var description: IntentDescription = "Zeigt dein aktuelles Gewicht und den BMI."

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = DataModel.shared.modelContainer
        let context = ModelContext(container)
        let today = Date()

        let record = IntentDataAccess.fetchDayRecord(for: today, in: context)
        let profile = IntentDataAccess.fetchProfile(in: context)

        guard let weight = record?.weight ?? profile?.bodyWeightKg else {
            return .result(
                dialog: "Kein Gewicht eingetragen. Trage dein Gewicht in der App oder per Siri ein."
            )
        }

        let heightCm = profile?.heightCm ?? 175
        let heightM = heightCm / 100.0
        let bmi = weight / (heightM * heightM)
        let weightStr = String(format: "%.1f", weight)
        let bmiStr = String(format: "%.1f", bmi)

        let category: String
        switch bmi {
        case ..<18.5: category = "Untergewicht"
        case 18.5..<25: category = "Normalgewicht"
        case 25..<30: category = "Übergewicht"
        default: category = "Adipositas"
        }

        return .result(
            dialog: "Dein Gewicht: \(weightStr) kg. BMI: \(bmiStr) (\(category))."
        )
    }
}

// MARK: - P2: Makro-Status abfragen

/// App Intent: Makro-Naehrstoffe im Vergleich zum Ziel
struct GetMacroStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Makro-Status"
    static var description: IntentDescription = "Zeigt den aktuellen Stand der Makronährstoffe im Vergleich zum Ziel."

    @Parameter(title: "Datum")
    var date: Date?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = DataModel.shared.modelContainer
        let context = ModelContext(container)
        let targetDate = date ?? Date()

        let entries = IntentDataAccess.fetchEntries(for: targetDate, in: context)
        let profile = IntentDataAccess.fetchProfile(in: context)
        let summary = NutrientCalculator.calculateDaySummary(entries: entries)

        let proteinGoal = profile?.proteinGoalGrams ?? 50
        let carbsGoal = profile?.carbsGoalGrams ?? 250
        let fatGoal = profile?.fatGoalGrams ?? 65
        let fiberGoal = profile?.fiberGoalGrams ?? 30

        let protein = Int(summary.totalProtein)
        let carbs = Int(summary.totalCarbs)
        let fat = Int(summary.totalFat)
        let fiber = Int(summary.totalFiber)

        func pct(_ current: Int, _ goal: Int) -> Int {
            goal > 0 ? current * 100 / goal : 0
        }

        return .result(
            dialog: """
            Protein: \(protein)g von \(proteinGoal)g (\(pct(protein, proteinGoal))%), \
            Kohlenhydrate: \(carbs)g von \(carbsGoal)g (\(pct(carbs, carbsGoal))%), \
            Fett: \(fat)g von \(fatGoal)g (\(pct(fat, fatGoal))%), \
            Ballaststoffe: \(fiber)g von \(fiberGoal)g (\(pct(fiber, fiberGoal))%).
            """
        )
    }
}

// MARK: - P2: Verbrannte Kalorien abfragen

/// App Intent: Aktivitaetskalorien und Workout-Details
struct GetBurnedCaloriesIntent: AppIntent {
    static var title: LocalizedStringResource = "Verbrannte Kalorien"
    static var description: IntentDescription = "Zeigt die durch Aktivität verbrannten Kalorien."

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = DataModel.shared.modelContainer
        let context = ModelContext(container)
        let today = Date()

        let record = IntentDataAccess.fetchDayRecord(for: today, in: context)
        let profile = IntentDataAccess.fetchProfile(in: context)

        let activeEnergy = record?.activeEnergyKcal ?? 0
        let workoutCals = record?.workoutCaloriesKcal ?? 0
        let nonWorkout = max(activeEnergy - workoutCals, 0)
        let creditPercent = profile?.exerciseCreditPercent ?? 50
        let creditedWorkout = workoutCals * creditPercent / 100

        if activeEnergy == 0 && workoutCals == 0 {
            return .result(
                dialog: "Heute noch keine Aktivitätskalorien erfasst. Daten kommen aus HealthKit."
            )
        }

        return .result(
            dialog: """
            Aktive Kalorien: \(activeEnergy) kcal (davon \(nonWorkout) kcal Alltagsaktivität, \
            \(workoutCals) kcal Training). Angerechnet: \(creditedWorkout) kcal (\(creditPercent)% der Trainings-Kalorien).
            """
        )
    }
}

// MARK: - P3: Zielfortschritt

/// App Intent: Fortschritt zum Gewichtsziel abfragen
struct GetGoalProgressIntent: AppIntent {
    static var title: LocalizedStringResource = "Zielfortschritt"
    static var description: IntentDescription = "Zeigt den Fortschritt zum Gewichtsziel."

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = DataModel.shared.modelContainer
        let context = ModelContext(container)

        let profile = IntentDataAccess.fetchProfile(in: context)
        let record = IntentDataAccess.fetchDayRecord(for: Date(), in: context)

        guard let goalWeight = profile?.weightGoalKg,
              let startWeight = profile?.startWeightKg else {
            return .result(
                dialog: "Kein Gewichtsziel eingestellt. Konfiguriere dein Ziel in den Einstellungen."
            )
        }

        let currentWeight = record?.weight ?? profile?.bodyWeightKg ?? startWeight
        let goalType = profile?.goalType ?? .maintain

        if goalType == .maintain {
            let weightStr = String(format: "%.1f", currentWeight)
            return .result(
                dialog: "Dein Ziel: Gewicht halten. Aktuelles Gewicht: \(weightStr) kg."
            )
        }

        let totalDiff = abs(startWeight - goalWeight)
        let currentDiff = abs(currentWeight - goalWeight)
        let startStr = String(format: "%.1f", startWeight)
        let currentStr = String(format: "%.1f", currentWeight)
        let goalStr = String(format: "%.1f", goalWeight)
        let remainingStr = String(format: "%.1f", currentDiff)

        if totalDiff > 0 {
            let progress = Int(max(0, min(100, (1.0 - currentDiff / totalDiff) * 100)))
            return .result(
                dialog: "Ziel: \(startStr) → \(goalStr) kg. Aktuell: \(currentStr) kg (\(progress)% geschafft). Noch \(remainingStr) kg."
            )
        }

        return .result(
            dialog: "Start: \(startStr) kg, Aktuell: \(currentStr) kg, Ziel: \(goalStr) kg."
        )
    }
}

// MARK: - P3: Workouts abfragen

/// App Intent: Workout-Zusammenfassung des Tages
struct GetWorkoutsIntent: AppIntent {
    static var title: LocalizedStringResource = "Workouts abfragen"
    static var description: IntentDescription = "Zeigt die Trainings-Zusammenfassung des heutigen Tages."

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = DataModel.shared.modelContainer
        let context = ModelContext(container)
        let today = Date()

        let record = IntentDataAccess.fetchDayRecord(for: today, in: context)

        let workoutCals = record?.workoutCaloriesKcal ?? 0
        let activeEnergy = record?.activeEnergyKcal ?? 0

        if workoutCals == 0 {
            if activeEnergy > 0 {
                return .result(
                    dialog: "Heute keine Workouts, aber \(activeEnergy) kcal Alltagsaktivität."
                )
            }
            return .result(
                dialog: "Heute noch keine Aktivität erfasst. Daten kommen aus HealthKit."
            )
        }

        return .result(
            dialog: "Heute \(workoutCals) kcal durch Training verbrannt. Gesamt-Aktivität: \(activeEnergy) kcal."
        )
    }
}

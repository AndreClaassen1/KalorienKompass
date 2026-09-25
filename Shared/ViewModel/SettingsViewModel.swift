//
//  SettingsViewModel.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import SwiftUI
import SwiftData
import os

/// ViewModel fuer die Einstellungen
@Observable
final class SettingsViewModel {
    private let modelContext: ModelContext

    var dailyCalorieGoal: Int = 2000
    var proteinGoalGrams: Int = 50
    var carbsGoalGrams: Int = 250
    var fatGoalGrams: Int = 65
    var fiberGoalGrams: Int = 30
    var weightGoalKg: Double?
    var dailyStepsGoal: Int = 10000
    var dailyWaterGoalMl: Int = 2000
    var dailyCoffeeGoal: Int = 3
    var weekendCoffeeGoal: Int = 6
    var weekendCoffeeDaysRaw: Int = 194
    var coffeeMlPerCup: Int = 150
    var caffeineMgPerCup: Int = 95

    /// Zugriff auf einzelne Wochentage als Binding-freundliche Bools
    /// weekday: 1=Sonntag, 2=Montag, ..., 7=Samstag
    func isWeekendCoffeeDay(_ weekday: Int) -> Bool {
        (weekendCoffeeDaysRaw & (1 << weekday)) != 0
    }

    func setWeekendCoffeeDay(_ weekday: Int, enabled: Bool) {
        if enabled {
            weekendCoffeeDaysRaw |= (1 << weekday)
        } else {
            weekendCoffeeDaysRaw &= ~(1 << weekday)
        }
    }
    var weightUnit: WeightUnit = .kg

    var bodyWeightKg: Double = 80
    var heightCm: Double = 175
    var age: Int = 30
    var gender: Gender = .male
    var activityLevel: ActivityLevel = .moderatelyActive
    var useAutoCalories: Bool = false

    var goalType: GoalType = .lose
    var startWeightKg: Double?
    var goalStartDate: Date?
    var weeklyWeightGoalKg: Double = -0.5

    var exerciseCreditPercent: Int = 50
    var weekendBonusPercent: Int = 0
    var useHealthKitActivity: Bool = false
    var expectedDailyActivityKcal: Int = 500

    var waterRemindersEnabled: Bool = true
    var mealRemindersEnabled: Bool = true
    var quietTimeStartHour: Int = 22
    var quietTimeEndHour: Int = 7

    /// Waehrend loadProfile aktiv — verhindert onChange-Kaskaden
    var isLoading = false

    /// Berechneter TDEE (ohne Defizit)
    var calculatedTDEE: Int {
        CalorieCalculator.totalDailyEnergyExpenditure(
            weightKg: bodyWeightKg,
            heightCm: heightCm,
            age: age,
            gender: gender,
            activityLevel: activityLevel
        )
    }

    /// Berechneter BMR
    var calculatedBMR: Int {
        Int(CalorieCalculator.basalMetabolicRate(
            weightKg: bodyWeightKg,
            heightCm: heightCm,
            age: age,
            gender: gender
        ))
    }

    /// Berechnetes Kalorienziel: immer TDEE-basiert (PAL-Faktor)
    var calculatedCalorieGoal: Int {
        if goalType == .maintain {
            return calculatedTDEE
        }
        return CalorieCalculator.goalAdjustedCalories(
            weightKg: bodyWeightKg,
            heightCm: heightCm,
            age: age,
            gender: gender,
            activityLevel: activityLevel,
            weeklyGoalKg: weeklyWeightGoalKg
        )
    }

    /// Aktueller BMI
    var currentBMI: Double {
        BMICalculator.bmi(weightKg: bodyWeightKg, heightCm: heightCm)
    }

    /// BMI-Kategorie
    var bmiCategory: BMICategory {
        BMICalculator.category(bmi: currentBMI)
    }

    /// Taegliches Defizit in kcal
    var dailyDeficit: Int {
        BMICalculator.dailyDeficit(weeklyGoalKg: weeklyWeightGoalKg)
    }

    /// Im PAL-Faktor implizierte Aktivitaetskalorien (TDEE − BMR)
    var palImpliedActivity: Int {
        CalorieCalculator.palImpliedActivity(
            weightKg: bodyWeightKg,
            heightCm: heightCm,
            age: age,
            gender: gender,
            activityLevel: activityLevel
        )
    }

    /// Ob das berechnete Ziel unter der Sicherheitsgrenze liegt
    var isBelowSafetyLimit: Bool {
        let raw = calculatedTDEE + dailyDeficit
        return raw < BMICalculator.safetyMinimum(gender: gender)
    }

    /// Geschaetztes Zieldatum
    var estimatedGoalDate: Date? {
        guard let goal = weightGoalKg else { return nil }
        return BMICalculator.estimatedGoalDate(
            currentKg: bodyWeightKg,
            goalKg: goal,
            weeklyGoalKg: weeklyWeightGoalKg
        )
    }

    /// Aktualisiert das Kalorienziel bei Auto-Modus
    func updateAutoCalories() {
        guard useAutoCalories else { return }
        dailyCalorieGoal = calculatedCalorieGoal
    }

    /// Setzt das Startziel (Startgewicht und Datum speichern)
    func setGoal() {
        startWeightKg = bodyWeightKg
        goalStartDate = Date()
    }

    /// Aktualisiert Makros nach 30/40/30-Verteilung
    func updateAutoMacros() {
        guard useAutoCalories else { return }
        let macros = BMICalculator.macroGrams(calorieGoal: dailyCalorieGoal)
        proteinGoalGrams = macros.protein
        carbsGoalGrams = macros.carbs
        fatGoalGrams = macros.fat
    }

    private static let logger = Logger(subsystem: "com.andre.claassen.KalorienKompass", category: "SettingsViewModel")
    private var profile: UserProfile?

    /// Ob seit dem letzten `loadProfile()` bereits zusammengefuehrt wurde.
    private var hasMergedDuplicates = false

    /// CloudKit-Import-Observer — triggert loadProfile nach eingehendem Sync,
    /// damit ein spaeter angekommenes UserProfile aus der Cloud nachgeladen wird.
    @ObservationIgnored private var reloader: RemoteImportReloader?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadProfile()
        reloader = RemoteImportReloader { [weak self] in self?.loadProfile() }
    }

    /// Laedt das Benutzerprofil oder erstellt ein neues
    func loadProfile() {
        isLoading = true
        defer { isLoading = false }

        // Nur lesen, nicht bereinigen (Issue #63). Ein spaeter eintreffender
        // Import kann neue Duplikate bringen, also darf der naechste Save wieder
        // zusammenfuehren.
        hasMergedDuplicates = false

        if let existing = UserProfile.existing(in: modelContext) {
            profile = existing
            dailyCalorieGoal = existing.dailyCalorieGoal
            proteinGoalGrams = existing.proteinGoalGrams
            carbsGoalGrams = existing.carbsGoalGrams
            fatGoalGrams = existing.fatGoalGrams
            fiberGoalGrams = existing.fiberGoalGrams
            weightGoalKg = existing.weightGoalKg
            dailyStepsGoal = existing.dailyStepsGoal
            dailyWaterGoalMl = existing.dailyWaterGoalMl
            dailyCoffeeGoal = existing.dailyCoffeeGoal
            weekendCoffeeGoal = existing.weekendCoffeeGoal
            weekendCoffeeDaysRaw = existing.weekendCoffeeDaysRaw
            coffeeMlPerCup = existing.coffeeMlPerCup
            caffeineMgPerCup = existing.caffeineMgPerCup
            weightUnit = existing.weightUnit
            bodyWeightKg = existing.bodyWeightKg
            heightCm = existing.heightCm
            age = existing.age
            gender = existing.gender
            activityLevel = existing.activityLevel
            useAutoCalories = existing.useAutoCalories
            goalType = existing.goalType
            startWeightKg = existing.startWeightKg
            goalStartDate = existing.goalStartDate
            weeklyWeightGoalKg = existing.weeklyWeightGoalKg
            exerciseCreditPercent = existing.exerciseCreditPercent
            weekendBonusPercent = existing.weekendBonusPercent
            useHealthKitActivity = existing.useHealthKitActivity
            expectedDailyActivityKcal = existing.expectedDailyActivityKcal
            waterRemindersEnabled = existing.waterRemindersEnabled
            mealRemindersEnabled = existing.mealRemindersEnabled
            quietTimeStartHour = existing.quietTimeStartHour
            quietTimeEndHour = existing.quietTimeEndHour
        } else {
            // WICHTIG: Kein Auto-Insert mehr — sonst erzeugt ein spaeter
            // ankommender CloudKit-Import Duplikate, und die Dedup-Logik
            // behaelt das neuere (leere) statt das echte Profil
            // (Data-Loss beim Wechsel zwischen lokalem und TestFlight-Build).
            //
            // Profil wird erst beim ersten save() lazy angelegt.
            profile = nil
            Self.logger.info("Kein UserProfile gefunden — wird beim ersten Save angelegt")
        }

        // Gespeichertes Kalorienziel mit berechnetem Wert abgleichen.
        // Verhindert veraltete Werte nach Formelaenderungen.
        let oldGoal = dailyCalorieGoal
        updateAutoCalories()
        updateAutoMacros()
        // Nur zurueckschreiben, wenn schon ein Profil existiert. Ohne Profil
        // wuerde dieser Abgleich eines anlegen, bevor CloudKit importiert hat —
        // genau die Race aus Issue #63.
        if dailyCalorieGoal != oldGoal, profile != nil {
            save()
        }
    }

    /// Speichert die Einstellungen im Benutzerprofil.
    ///
    /// Der einzige Pfad, der Profile zusammenfuehren und Duplikate entfernen
    /// darf: hier schreibt der Nutzer bewusst, und `UserProfile.canonical(in:)` uebertraegt
    /// vorher die Inhalte aller Duplikate auf das kanonische Profil.
    /// Erzeugt lazy ein neues Profil, falls noch keines existiert — verhindert
    /// die Race-Condition, bei der ein leeres Default-Profil vor dem
    /// CloudKit-Import angelegt wird.
    func save() {
        // Jeder Regler in den Einstellungen ruft save() ueber onChange, teils
        // mehrfach pro Bewegung. Zusammengefuehrt wird deshalb nur einmal je
        // Ladevorgang, danach genuegt die bereits aufgeloeste Referenz.
        let profile: UserProfile
        if let known = self.profile, hasMergedDuplicates {
            profile = known
        } else if let canonical = UserProfile.canonical(in: modelContext) {
            profile = canonical
            self.profile = canonical
            hasMergedDuplicates = true
        } else {
            Self.logger.info("Lazy-Create UserProfile beim ersten Save")
            profile = UserProfile()
            modelContext.insert(profile)
            self.profile = profile
            hasMergedDuplicates = true
        }
        profile.dailyCalorieGoal = dailyCalorieGoal
        profile.proteinGoalGrams = proteinGoalGrams
        profile.carbsGoalGrams = carbsGoalGrams
        profile.fatGoalGrams = fatGoalGrams
        profile.fiberGoalGrams = fiberGoalGrams
        profile.weightGoalKg = weightGoalKg
        profile.dailyStepsGoal = dailyStepsGoal
        profile.dailyWaterGoalMl = dailyWaterGoalMl
        profile.dailyCoffeeGoal = dailyCoffeeGoal
        profile.weekendCoffeeGoal = weekendCoffeeGoal
        profile.weekendCoffeeDaysRaw = weekendCoffeeDaysRaw
        profile.coffeeMlPerCup = coffeeMlPerCup
        profile.caffeineMgPerCup = caffeineMgPerCup
        profile.weightUnit = weightUnit
        profile.bodyWeightKg = bodyWeightKg
        profile.heightCm = heightCm
        profile.age = age
        profile.gender = gender
        profile.activityLevel = activityLevel
        profile.useAutoCalories = useAutoCalories
        profile.goalType = goalType
        profile.startWeightKg = startWeightKg
        profile.goalStartDate = goalStartDate
        profile.weeklyWeightGoalKg = weeklyWeightGoalKg
        profile.exerciseCreditPercent = exerciseCreditPercent
        profile.weekendBonusPercent = weekendBonusPercent
        profile.useHealthKitActivity = useHealthKitActivity
        profile.expectedDailyActivityKcal = expectedDailyActivityKcal
        profile.waterRemindersEnabled = waterRemindersEnabled
        profile.mealRemindersEnabled = mealRemindersEnabled
        profile.quietTimeStartHour = quietTimeStartHour
        profile.quietTimeEndHour = quietTimeEndHour
        profile.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            print("[SettingsViewModel] Save fehlgeschlagen: \(error)")
        }

        // Notifications nach Einstellungsaenderung neu schedulen
        Task {
            await NotificationManager.shared.checkAuthorizationStatus()
        }
    }
}

//
//  NutrientCalculator.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import Foundation

/// Berechnungen fuer Naehrwerte und Tageszusammenfassungen
enum NutrientCalculator {

    /// Zusammenfassung der Naehrwerte eines Tages
    struct DaySummary: Sendable {
        let totalCalories: Double
        let totalProtein: Double
        let totalCarbs: Double
        let totalFat: Double
        let totalFiber: Double
        let totalSugar: Double
        let totalSaturatedFat: Double
        let totalSalt: Double

        /// Natrium berechnet aus Salz (Salz × 0.4)
        var totalSodium: Double { totalSalt * 0.4 }

        init(
            totalCalories: Double,
            totalProtein: Double,
            totalCarbs: Double,
            totalFat: Double,
            totalFiber: Double,
            totalSugar: Double = 0,
            totalSaturatedFat: Double = 0,
            totalSalt: Double = 0
        ) {
            self.totalCalories = totalCalories
            self.totalProtein = totalProtein
            self.totalCarbs = totalCarbs
            self.totalFat = totalFat
            self.totalFiber = totalFiber
            self.totalSugar = totalSugar
            self.totalSaturatedFat = totalSaturatedFat
            self.totalSalt = totalSalt
        }

        /// Prozentuale Verteilung der Makronaehrstoffe (basierend auf Kalorien)
        var proteinPercentage: Double {
            guard totalCalories > 0 else { return 0 }
            return (totalProtein * 4.0) / totalCalories * 100.0
        }

        var carbsPercentage: Double {
            guard totalCalories > 0 else { return 0 }
            return (totalCarbs * 4.0) / totalCalories * 100.0
        }

        var fatPercentage: Double {
            guard totalCalories > 0 else { return 0 }
            return (totalFat * 9.0) / totalCalories * 100.0
        }
    }

    /// Berechnet die Tageszusammenfassung fuer eine Liste von Tagebucheintraegen
    static func calculateDaySummary(entries: [DiaryEntry]) -> DaySummary {
        let totalCalories = entries.reduce(0.0) { $0 + $1.calories }
        let totalProtein = entries.reduce(0.0) { $0 + $1.protein }
        let totalCarbs = entries.reduce(0.0) { $0 + $1.carbs }
        let totalFat = entries.reduce(0.0) { $0 + $1.fat }
        let totalFiber = entries.reduce(0.0) { $0 + $1.fiber }
        let totalSugar = entries.reduce(0.0) { $0 + $1.sugar }
        let totalSaturatedFat = entries.reduce(0.0) { $0 + $1.saturatedFat }
        let totalSalt = entries.reduce(0.0) { $0 + $1.salt }

        return DaySummary(
            totalCalories: totalCalories,
            totalProtein: totalProtein,
            totalCarbs: totalCarbs,
            totalFat: totalFat,
            totalFiber: totalFiber,
            totalSugar: totalSugar,
            totalSaturatedFat: totalSaturatedFat,
            totalSalt: totalSalt
        )
    }

    /// Berechnet die Zusammenfassung fuer eine einzelne Mahlzeit
    static func calculateMealSummary(entries: [DiaryEntry], mealType: MealType) -> DaySummary {
        let filtered = entries.filter { $0.mealType == mealType }
        return calculateDaySummary(entries: filtered)
    }

    /// Verbleibende Kalorien fuer den Tag
    static func remainingCalories(consumed: Double, goal: Int) -> Double {
        Double(goal) - consumed
    }

    /// Fortschritt in Prozent (0.0 - 1.0+, kann ueber 1.0 hinausgehen)
    static func progress(consumed: Double, goal: Int) -> Double {
        guard goal > 0 else { return 0 }
        return consumed / Double(goal)
    }

    // MARK: - Einheitliche Kalorienziel-Berechnung

    /// Die Posten, aus denen das Tagesziel besteht.
    ///
    /// Existiert, damit die Anzeige (Issue #80) und die Rechnung nicht auseinander
    /// laufen koennen: `effectiveCalorieGoal` ist nur noch die Summe hiervon.
    struct GoalBreakdown: Sendable, Equatable {
        /// Grundziel: berechnet (Auto-Modus) oder aus dem Profil
        let base: Int
        /// Aufschlag am Wochenende, 0 an Werktagen
        let weekendBonus: Int
        let weekendPercent: Int
        /// Rechnet HealthKit-Alltagsbewegung mit? Nur im PAL-Bonus-Modell.
        let usesActivity: Bool
        /// Alltagsbewegung laut HealthKit, ohne Training. Steht auch dann, wenn sie
        /// nicht angerechnet wird — sonst liesse sich die Null nicht erklaeren.
        let activityRaw: Int
        /// Davon steckt dieser Teil schon im Grundziel (TDEE minus Grundumsatz)
        let activityIncludedInBase: Int
        /// Trainingskalorien laut HealthKit
        let workoutRaw: Int
        let workoutPercent: Int

        /// Was von der Alltagsbewegung zusaetzlich angerechnet wird.
        var activityBonus: Int {
            guard usesActivity else { return 0 }
            return max(0, activityRaw - activityIncludedInBase)
        }

        /// Was vom Training angerechnet wird.
        var workoutBonus: Int { workoutRaw * workoutPercent / 100 }

        var total: Int { base + weekendBonus + activityBonus + workoutBonus }
    }

    /// Schluesselt das effektive Kalorienziel in seine Posten auf.
    ///
    /// PAL-Bonus-Modell: der TDEE steckt bereits im Grundziel. HealthKit-Aktivitaet
    /// zaehlt nur, soweit sie die im PAL-Faktor implizierte Alltagsbewegung
    /// uebersteigt — sonst waere sie doppelt drin.
    static func goalBreakdown(
        profile: UserProfile?,
        dayRecord: DayRecord?,
        nonWorkoutActiveEnergy: Int
    ) -> GoalBreakdown {
        goalBreakdown(
            profile: profile,
            date: dayRecord?.date,
            workoutCaloriesKcal: dayRecord?.workoutCaloriesKcal ?? 0,
            nonWorkoutActiveEnergy: nonWorkoutActiveEnergy
        )
    }

    /// Dieselbe Aufschluesselung aus rohen Tageswerten statt aus einem `DayRecord`.
    ///
    /// Die Wochenleiste wertet sieben Tage auf einmal aus und arbeitet dafuer mit
    /// `DayRecord.Day` (dem gefalteten Wert je Kalendertag), nicht mit den Records
    /// selbst — Duplikate wuerden sonst als eigene Tage zaehlen (Issue #67).
    /// Damit dabei dieselbe Formel greift wie im Tagesbildschirm, liegt die Logik
    /// hier und nicht in einer zweiten Rechnung daneben.
    static func goalBreakdown(
        profile: UserProfile?,
        date: Date?,
        workoutCaloriesKcal: Int,
        nonWorkoutActiveEnergy: Int
    ) -> GoalBreakdown {
        // Bei Auto-Kalorien: immer frisch berechnen statt gespeicherten Wert nutzen.
        // Der gespeicherte dailyCalorieGoal kann veraltet sein (z.B. nach Formelaenderung),
        // da er nur beim Oeffnen der Einstellungen aktualisiert wird.
        let useAuto = profile?.useAutoCalories ?? false
        let base = useAuto
            ? computeAutoCalorieGoal(profile: profile)
            : (profile?.dailyCalorieGoal ?? 2000)

        // Wochenend-Bonus (Sa=7, So=1)
        let weekendPercent = profile?.weekendBonusPercent ?? 0
        var weekendBonus = 0
        if let date {
            let weekday = Calendar.current.component(.weekday, from: date)
            if weekday == 1 || weekday == 7 {
                weekendBonus = base * weekendPercent / 100
            }
        }

        // Workout-Anrechnung (gilt in allen Modi)
        let workoutRaw = workoutCaloriesKcal
        let workoutPercent = profile?.exerciseCreditPercent ?? 50

        let usesActivity = useAuto && (profile?.useHealthKitActivity ?? false)
        let palActivity = usesActivity ? palImpliedActivityKcal(profile: profile) : 0

        return GoalBreakdown(
            base: base,
            weekendBonus: weekendBonus,
            weekendPercent: weekendPercent,
            usesActivity: usesActivity,
            activityRaw: nonWorkoutActiveEnergy,
            activityIncludedInBase: palActivity,
            workoutRaw: workoutRaw,
            workoutPercent: workoutPercent
        )
    }

    /// Berechnet das effektive Kalorienziel — einheitliche Logik fuer
    /// iPhone, Watch App, iOS Widget und Watch Widget.
    static func effectiveCalorieGoal(
        profile: UserProfile?,
        dayRecord: DayRecord?,
        nonWorkoutActiveEnergy: Int
    ) -> Int {
        goalBreakdown(
            profile: profile,
            dayRecord: dayRecord,
            nonWorkoutActiveEnergy: nonWorkoutActiveEnergy
        ).total
    }

    /// Berechnet BMR und TDEE aus dem Profil (Mifflin-St Jeor).
    /// Inline-Berechnung, damit kein CalorieCalculator noetig ist (Widget-Extensions).
    private static func bmrAndTdee(profile: UserProfile?) -> (bmr: Double, tdee: Int) {
        let weight = profile?.bodyWeightKg ?? 80
        let height = profile?.heightCm ?? 175
        let age = profile?.age ?? 30
        let gender = profile?.gender ?? .male
        let pal = profile?.activityLevel.palFactor ?? 1.55

        // Mifflin-St Jeor BMR
        let bmrBase = 10.0 * weight + 6.25 * height - 5.0 * Double(age)
        let bmr: Double
        switch gender {
        case .male: bmr = bmrBase + 5.0
        case .female: bmr = bmrBase - 161.0
        }

        // TDEE gerundet auf 50 kcal (gleiche Logik wie CalorieCalculator)
        let tdee = Int((bmr * pal / 50.0).rounded() * 50)

        return (bmr, tdee)
    }

    /// Im PAL-Faktor implizierte Aktivitaetskalorien (TDEE − BMR)
    private static func palImpliedActivityKcal(profile: UserProfile?) -> Int {
        let (bmr, tdee) = bmrAndTdee(profile: profile)
        return tdee - Int(bmr)
    }

    /// Berechnet das Basis-Kalorienziel frisch aus dem Profil (Auto-Modus).
    /// Inline-Berechnung nach Mifflin-St Jeor + Defizit, identisch mit
    /// CalorieCalculator.goalAdjustedCalories + BMICalculator.calorieGoalWithDeficit.
    private static func computeAutoCalorieGoal(profile: UserProfile?) -> Int {
        let gender = profile?.gender ?? .male
        let goalType = profile?.goalType ?? .maintain
        let (_, tdee) = bmrAndTdee(profile: profile)

        if goalType == .maintain {
            return tdee
        }

        // Defizit (gleiche Logik wie BMICalculator.dailyDeficit)
        let weeklyGoalKg = profile?.weeklyWeightGoalKg ?? -0.5
        let deficit = Int((weeklyGoalKg * 7700.0) / 7.0)
        let raw = tdee + deficit

        // Sicherheitsgrenze (gleiche Logik wie BMICalculator.safetyMinimum)
        let safetyMin: Int
        switch gender {
        case .male: safetyMin = 1500
        case .female: safetyMin = 1200
        }

        return max(raw, safetyMin)
    }

    /// Berechnet Kalorien fuer eine bestimmte Menge eines Lebensmittels
    static func caloriesForAmount(food: FoodItem, grams: Double) -> Double {
        food.caloriesPer100g * grams / 100.0
    }

    /// Berechnet die Grammzahl fuer eine bestimmte Kalorienmenge
    static func gramsForCalories(food: FoodItem, calories: Double) -> Double {
        guard food.caloriesPer100g > 0 else { return 0 }
        return calories / food.caloriesPer100g * 100.0
    }
}

//
//  KalorienKompassTests.swift
//  KalorienKompassTests
//
//  Erstellt von André Claaßen am 04.02.26.
//

import Testing
import Foundation
import SwiftData
@testable import KalorienKompass

// MARK: - NutrientCalculator Tests

struct NutrientCalculatorTests {

    // MARK: DaySummary Makro-Prozente

    @Test func daySummaryProteinPercentage() {
        // 50g Protein * 4 kcal/g = 200 kcal von 1000 kcal = 20%
        let summary = NutrientCalculator.DaySummary(
            totalCalories: 1000, totalProtein: 50, totalCarbs: 0, totalFat: 0, totalFiber: 0
        )
        #expect(summary.proteinPercentage == 20.0)
    }

    @Test func daySummaryCarbsPercentage() {
        // 100g Kohlenhydrate * 4 kcal/g = 400 kcal von 2000 kcal = 20%
        let summary = NutrientCalculator.DaySummary(
            totalCalories: 2000, totalProtein: 0, totalCarbs: 100, totalFat: 0, totalFiber: 0
        )
        #expect(summary.carbsPercentage == 20.0)
    }

    @Test func daySummaryFatPercentage() {
        // 50g Fett * 9 kcal/g = 450 kcal von 1500 kcal = 30%
        let summary = NutrientCalculator.DaySummary(
            totalCalories: 1500, totalProtein: 0, totalCarbs: 0, totalFat: 50, totalFiber: 0
        )
        #expect(summary.fatPercentage == 30.0)
    }

    @Test func daySummaryZeroCaloriesReturnsZeroPercent() {
        let summary = NutrientCalculator.DaySummary(
            totalCalories: 0, totalProtein: 10, totalCarbs: 20, totalFat: 5, totalFiber: 3
        )
        #expect(summary.proteinPercentage == 0)
        #expect(summary.carbsPercentage == 0)
        #expect(summary.fatPercentage == 0)
    }

    // MARK: Natrium-Berechnung aus Salz

    @Test func totalSodiumFromSalt() {
        let summary = NutrientCalculator.DaySummary(
            totalCalories: 2000, totalProtein: 80, totalCarbs: 250,
            totalFat: 70, totalFiber: 25, totalSalt: 5.0
        )
        // Natrium = Salz × 0.4
        #expect(summary.totalSodium == 2.0)
    }

    @Test func totalSodiumZeroWhenNoSalt() {
        let summary = NutrientCalculator.DaySummary(
            totalCalories: 1000, totalProtein: 50, totalCarbs: 100,
            totalFat: 30, totalFiber: 10
        )
        #expect(summary.totalSodium == 0)
    }

    // MARK: DaySummary Default-Werte

    @Test func daySummaryDefaultsForNewFields() {
        let summary = NutrientCalculator.DaySummary(
            totalCalories: 1000, totalProtein: 50, totalCarbs: 100,
            totalFat: 30, totalFiber: 10
        )
        #expect(summary.totalSugar == 0)
        #expect(summary.totalSaturatedFat == 0)
        #expect(summary.totalSalt == 0)
    }

    // MARK: Restliche Kalorien

    @Test func remainingCaloriesPositive() {
        let remaining = NutrientCalculator.remainingCalories(consumed: 1500, goal: 2000)
        #expect(remaining == 500.0)
    }

    @Test func remainingCaloriesNegativeWhenOverGoal() {
        let remaining = NutrientCalculator.remainingCalories(consumed: 2500, goal: 2000)
        #expect(remaining == -500.0)
    }

    // MARK: Fortschritt

    @Test func progressHalf() {
        let progress = NutrientCalculator.progress(consumed: 1000, goal: 2000)
        #expect(progress == 0.5)
    }

    @Test func progressZeroGoal() {
        let progress = NutrientCalculator.progress(consumed: 500, goal: 0)
        #expect(progress == 0)
    }

    @Test func progressOverGoal() {
        let progress = NutrientCalculator.progress(consumed: 2500, goal: 2000)
        #expect(progress == 1.25)
    }
}

// MARK: - Date Extensions Tests

struct DateExtensionTests {

    @Test func startOfDayRemovesTime() {
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 4
        components.hour = 14
        components.minute = 30
        let date = Calendar.current.date(from: components)!

        let start = date.startOfDay
        let startComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: start)
        #expect(startComponents.hour == 0)
        #expect(startComponents.minute == 0)
        #expect(startComponents.second == 0)
    }

    @Test func endOfDayIsLastSecond() {
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 4
        let date = Calendar.current.date(from: components)!

        let end = date.endOfDay
        let endComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: end)
        #expect(endComponents.hour == 23)
        #expect(endComponents.minute == 59)
        #expect(endComponents.second == 59)
    }

    @Test func addingDaysForward() {
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 1
        let date = Calendar.current.date(from: components)!

        let future = date.addingDays(5)
        let futureDay = Calendar.current.component(.day, from: future)
        #expect(futureDay == 6)
    }

    @Test func addingDaysBackward() {
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 10
        let date = Calendar.current.date(from: components)!

        let past = date.addingDays(-3)
        let pastDay = Calendar.current.component(.day, from: past)
        #expect(pastDay == 7)
    }

    @Test func isSameDayTrue() {
        var comp1 = DateComponents()
        comp1.year = 2026; comp1.month = 2; comp1.day = 4; comp1.hour = 8
        var comp2 = DateComponents()
        comp2.year = 2026; comp2.month = 2; comp2.day = 4; comp2.hour = 20

        let date1 = Calendar.current.date(from: comp1)!
        let date2 = Calendar.current.date(from: comp2)!
        #expect(date1.isSameDay(as: date2))
    }

    @Test func isSameDayFalse() {
        var comp1 = DateComponents()
        comp1.year = 2026; comp1.month = 2; comp1.day = 4
        var comp2 = DateComponents()
        comp2.year = 2026; comp2.month = 2; comp2.day = 5

        let date1 = Calendar.current.date(from: comp1)!
        let date2 = Calendar.current.date(from: comp2)!
        #expect(!date1.isSameDay(as: date2))
    }

    @Test func dayOfMonthCorrect() {
        var components = DateComponents()
        components.year = 2026; components.month = 3; components.day = 15
        let date = Calendar.current.date(from: components)!
        #expect(date.dayOfMonth == 15)
    }

    @Test func lastDaysCount() {
        let days = Date.lastDays(7)
        #expect(days.count == 7)
    }

    @Test func lastDaysEndsToday() {
        let days = Date.lastDays(7)
        let last = days.last!
        #expect(last.isToday)
    }

    @Test func todayIsToday() {
        #expect(Date().isToday)
    }
}

// MARK: - MealType Tests

struct MealTypeTests {

    @Test func allCasesCount() {
        #expect(MealType.allCases.count == 6)
    }

    @Test func rawValues() {
        #expect(MealType.breakfast.rawValue == "breakfast")
        #expect(MealType.secondBreakfast.rawValue == "secondBreakfast")
        #expect(MealType.lunch.rawValue == "lunch")
        #expect(MealType.coffeeBreak.rawValue == "coffeeBreak")
        #expect(MealType.dinner.rawValue == "dinner")
        #expect(MealType.snack.rawValue == "snack")
    }

    @Test func sortOrderSequential() {
        let sorted = MealType.allCases.sorted { $0.sortOrder < $1.sortOrder }
        #expect(sorted == [.breakfast, .secondBreakfast, .lunch, .coffeeBreak, .dinner, .snack])
    }

    @Test func symbolNamesNotEmpty() {
        for mealType in MealType.allCases {
            #expect(!mealType.symbolName.isEmpty)
        }
    }

    @Test func idMatchesRawValue() {
        for mealType in MealType.allCases {
            #expect(mealType.id == mealType.rawValue)
        }
    }

    @Test func decodableFromString() throws {
        let data = "\"breakfast\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(MealType.self, from: data)
        #expect(decoded == .breakfast)
    }

    // MARK: forHour

    @Test(arguments: [
        (0, MealType.snack), (4, MealType.snack),
        (5, MealType.breakfast), (9, MealType.breakfast),
        (10, MealType.secondBreakfast), (11, MealType.secondBreakfast),
        (12, MealType.lunch), (14, MealType.lunch),
        (15, MealType.coffeeBreak), (16, MealType.coffeeBreak),
        (17, MealType.dinner), (18, MealType.dinner), (21, MealType.dinner),
        (22, MealType.snack), (23, MealType.snack)
    ])
    func forHourMapsEveryBoundary(hour: Int, expected: MealType) {
        #expect(MealType.forHour(hour) == expected)
    }

    /// `currentBasedOnTime` ist nur noch ein `forHour`-Aufruf mit der jetzigen Stunde.
    @Test func currentBasedOnTimeMatchesForHour() {
        let hour = Calendar.current.component(.hour, from: Date())
        #expect(MealType.currentBasedOnTime == MealType.forHour(hour))
    }
}

// MARK: - AppGroupPaths Tests

struct AppGroupPathsTests {

    /// Die Group traegt in Debug-Builds den `.Debug`-Zusatz (Issue #64), damit ein
    /// Debug-Build den Produktionsstore nicht anfassen kann. Die Tests laufen in
    /// Debug, deshalb wird hier genau das erwartet.
    @Test func groupIDGehoertZumBuild() {
        let basis = "group.\(BundleIDs.prefix).KalorienKompass"
        #expect(AppGroupPaths.groupID.hasPrefix(basis))
        #if DEBUG
        #expect(AppGroupPaths.groupID == basis + ".Debug")
        #else
        #expect(AppGroupPaths.groupID == basis)
        #endif
    }

    /// Der Code-Wert muss zu den **Entitlements** passen, nicht nur zu sich selbst.
    /// Laufen sie auseinander, liefert `containerURL` `nil`, und `sharedContainer()`
    /// stuerzt beim Start mit einem force-unwrap ab. Der Test laeuft im Host-Prozess
    /// der App, sieht also deren echte Entitlements.
    @Test func appGroupIstFuerDiesenBuildErreichbar() {
        let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupPaths.groupID
        )
        #expect(url != nil, "App Group \(AppGroupPaths.groupID) ist nicht in den Entitlements")
    }

    /// Store und CloudKit-Container muessen denselben Zusatz tragen: eine Debug-App,
    /// die den Produktions-Container synchronisiert, waere genau die Vermischung,
    /// die #64 abstellt.
    @Test func storeUndCloudKitContainerPassenZusammen() {
        let groupSuffix = AppGroupPaths.groupID
            .replacingOccurrences(of: "group.\(BundleIDs.prefix).KalorienKompass", with: "")
        let containerSuffix = CloudKitConfiguration.containerIdentifier
            .replacingOccurrences(of: "iCloud.\(BundleIDs.prefix).KalorienKompass", with: "")
        #expect(groupSuffix == containerSuffix)
    }
}

// MARK: - CalorieCalculator Tests

struct CalorieCalculatorTests {

    // MARK: BMR (Mifflin-St Jeor)

    @Test func bmrMale() {
        // 10*80 + 6.25*175 - 5*30 + 5 = 800 + 1093.75 - 150 + 5 = 1748.75
        let bmr = CalorieCalculator.basalMetabolicRate(
            weightKg: 80, heightCm: 175, age: 30, gender: .male
        )
        #expect(bmr == 1748.75)
    }

    @Test func bmrFemale() {
        // 10*80 + 6.25*175 - 5*30 - 161 = 800 + 1093.75 - 150 - 161 = 1582.75
        let bmr = CalorieCalculator.basalMetabolicRate(
            weightKg: 80, heightCm: 175, age: 30, gender: .female
        )
        #expect(bmr == 1582.75)
    }

    @Test func bmrLightweight() {
        // 10*50 + 6.25*160 - 5*25 + 5 = 500 + 1000 - 125 + 5 = 1380
        let bmr = CalorieCalculator.basalMetabolicRate(
            weightKg: 50, heightCm: 160, age: 25, gender: .male
        )
        #expect(bmr == 1380.0)
    }

    // MARK: TDEE

    @Test func tdeeSedentary() {
        // BMR Mann 80kg/175cm/30J = 1748.75, * 1.2 = 2098.5, / 50 = 41.97 → gerundet 42 * 50 = 2100
        let tdee = CalorieCalculator.totalDailyEnergyExpenditure(
            weightKg: 80, heightCm: 175, age: 30, gender: .male, activityLevel: .sedentary
        )
        #expect(tdee == 2100)
    }

    @Test func tdeeLightlyActive() {
        // 1748.75 * 1.375 = 2404.53125, / 50 = 48.09 → gerundet 48 * 50 = 2400
        let tdee = CalorieCalculator.totalDailyEnergyExpenditure(
            weightKg: 80, heightCm: 175, age: 30, gender: .male, activityLevel: .lightlyActive
        )
        #expect(tdee == 2400)
    }

    @Test func tdeeModeratelyActive() {
        // 1748.75 * 1.55 = 2710.5625, / 50 = 54.21 → gerundet 54 * 50 = 2700
        let tdee = CalorieCalculator.totalDailyEnergyExpenditure(
            weightKg: 80, heightCm: 175, age: 30, gender: .male, activityLevel: .moderatelyActive
        )
        #expect(tdee == 2700)
    }

    @Test func tdeeVeryActive() {
        // 1748.75 * 1.725 = 3016.59375, / 50 = 60.33 → gerundet 60 * 50 = 3000
        let tdee = CalorieCalculator.totalDailyEnergyExpenditure(
            weightKg: 80, heightCm: 175, age: 30, gender: .male, activityLevel: .veryActive
        )
        #expect(tdee == 3000)
    }

    @Test func tdeeRoundingUp() {
        // Frau 60kg/165cm/25J: BMR = 10*60 + 6.25*165 - 5*25 - 161 = 600 + 1031.25 - 125 - 161 = 1345.25
        // * 1.55 = 2085.1375, / 50 = 41.70 → gerundet 42 * 50 = 2100
        let tdee = CalorieCalculator.totalDailyEnergyExpenditure(
            weightKg: 60, heightCm: 165, age: 25, gender: .female, activityLevel: .moderatelyActive
        )
        #expect(tdee == 2100)
    }
}

// MARK: - CalorieCalculator PAL-implizierte Aktivitaet Tests

struct CalorieCalculatorPALActivityTests {

    @Test func palImpliedActivityMale() {
        // BMR Mann 80kg/175cm/30J = 1748.75 → Int = 1748
        // TDEE = 1748.75 * 1.55 = 2710.5625, / 50 = 54.21 → gerundet 54 * 50 = 2700
        // PAL-Aktivitaet = 2700 - 1748 = 952
        let activity = CalorieCalculator.palImpliedActivity(
            weightKg: 80, heightCm: 175, age: 30,
            gender: .male, activityLevel: .moderatelyActive
        )
        #expect(activity == 952)
    }

    @Test func palImpliedActivityFemale() {
        // BMR Frau 60kg/165cm/25J = 1345.25 → Int = 1345
        // TDEE = 1345.25 * 1.55 = 2085.1375, / 50 = 41.70 → gerundet 42 * 50 = 2100
        // PAL-Aktivitaet = 2100 - 1345 = 755
        let activity = CalorieCalculator.palImpliedActivity(
            weightKg: 60, heightCm: 165, age: 25,
            gender: .female, activityLevel: .moderatelyActive
        )
        #expect(activity == 755)
    }

    @Test func palImpliedActivitySedentary() {
        // BMR Mann 80kg/175cm/30J = 1748.75 → Int = 1748
        // TDEE sedentary = 1748.75 * 1.2 = 2098.5, / 50 = 41.97 → gerundet 42 * 50 = 2100
        // PAL-Aktivitaet = 2100 - 1748 = 352
        let activity = CalorieCalculator.palImpliedActivity(
            weightKg: 80, heightCm: 175, age: 30,
            gender: .male, activityLevel: .sedentary
        )
        #expect(activity == 352)
    }

    @Test func palImpliedActivityVeryActive() {
        // BMR Mann 80kg/175cm/30J = 1748.75 → Int = 1748
        // TDEE veryActive = 1748.75 * 1.725 = 3016.59375, / 50 = 60.33 → gerundet 60 * 50 = 3000
        // PAL-Aktivitaet = 3000 - 1748 = 1252
        let activity = CalorieCalculator.palImpliedActivity(
            weightKg: 80, heightCm: 175, age: 30,
            gender: .male, activityLevel: .veryActive
        )
        #expect(activity == 1252)
    }
}

// MARK: - NutrientTrafficLight Tests

struct NutrientTrafficLightTests {

    // MARK: rateFat (gruen ≤3, gelb ≤17.5, rot >17.5)

    @Test func rateFatGreen() {
        #expect(NutrientTrafficLight.rateFat(2.5) == .green)
        #expect(NutrientTrafficLight.rateFat(3.0) == .green)
    }

    @Test func rateFatAmber() {
        #expect(NutrientTrafficLight.rateFat(3.1) == .amber)
        #expect(NutrientTrafficLight.rateFat(17.5) == .amber)
    }

    @Test func rateFatRed() {
        #expect(NutrientTrafficLight.rateFat(17.6) == .red)
        #expect(NutrientTrafficLight.rateFat(50.0) == .red)
    }

    // MARK: rateSaturatedFat (gruen ≤1.5, gelb ≤5.0, rot >5.0)

    @Test func rateSaturatedFatGreen() {
        #expect(NutrientTrafficLight.rateSaturatedFat(1.0) == .green)
        #expect(NutrientTrafficLight.rateSaturatedFat(1.5) == .green)
    }

    @Test func rateSaturatedFatAmber() {
        #expect(NutrientTrafficLight.rateSaturatedFat(1.6) == .amber)
        #expect(NutrientTrafficLight.rateSaturatedFat(5.0) == .amber)
    }

    @Test func rateSaturatedFatRed() {
        #expect(NutrientTrafficLight.rateSaturatedFat(5.1) == .red)
    }

    // MARK: rateSugar (gruen ≤5, gelb ≤22.5, rot >22.5)

    @Test func rateSugarGreen() {
        #expect(NutrientTrafficLight.rateSugar(4.0) == .green)
        #expect(NutrientTrafficLight.rateSugar(5.0) == .green)
    }

    @Test func rateSugarAmber() {
        #expect(NutrientTrafficLight.rateSugar(5.1) == .amber)
        #expect(NutrientTrafficLight.rateSugar(22.5) == .amber)
    }

    @Test func rateSugarRed() {
        #expect(NutrientTrafficLight.rateSugar(22.6) == .red)
    }

    // MARK: rateSalt (gruen ≤0.3, gelb ≤1.5, rot >1.5)

    @Test func rateSaltGreen() {
        #expect(NutrientTrafficLight.rateSalt(0.2) == .green)
        #expect(NutrientTrafficLight.rateSalt(0.3) == .green)
    }

    @Test func rateSaltAmber() {
        #expect(NutrientTrafficLight.rateSalt(0.4) == .amber)
        #expect(NutrientTrafficLight.rateSalt(1.5) == .amber)
    }

    @Test func rateSaltRed() {
        #expect(NutrientTrafficLight.rateSalt(1.6) == .red)
    }

    // MARK: overallRating (0-1 gruen, 2-3 gelb, 4+ rot)

    @Test func overallRatingAllGreen() {
        // Score: 0+0+0+0 = 0 → gruen
        let rating = NutrientTrafficLight.overallRating(
            fat: 1.0, saturatedFat: 0.5, sugar: 2.0, salt: 0.1
        )
        #expect(rating == .green)
    }

    @Test func overallRatingOneAmberStillGreen() {
        // Apfel: fat 0.2 → green(0), satfat 0 → green(0), sugar 10 → amber(1), salt 0 → green(0)
        // Score: 0+0+1+0 = 1 → gruen (ein einzelner leicht erhoehter Wert wird toleriert)
        let rating = NutrientTrafficLight.overallRating(
            fat: 0.2, saturatedFat: 0.0, sugar: 10.0, salt: 0.0
        )
        #expect(rating == .green)
    }

    @Test func overallRatingMixed() {
        // fat 10 → amber(1), satfat 0.5 → green(0), sugar 3 → green(0), salt 0.5 → amber(1)
        // Score: 1+0+0+1 = 2 → amber
        let rating = NutrientTrafficLight.overallRating(
            fat: 10.0, saturatedFat: 0.5, sugar: 3.0, salt: 0.5
        )
        #expect(rating == .amber)
    }

    @Test func overallRatingHighScore() {
        // fat 20 → red(2), satfat 6 → red(2), sugar 25 → red(2), salt 2 → red(2)
        // Score: 2+2+2+2 = 8 → rot
        let rating = NutrientTrafficLight.overallRating(
            fat: 20.0, saturatedFat: 6.0, sugar: 25.0, salt: 2.0
        )
        #expect(rating == .red)
    }

    @Test func overallRatingBorderlineAmberRed() {
        // Score genau 3 → amber, Score 4 → rot
        // fat 5 → amber(1), satfat 2 → amber(1), sugar 6 → amber(1), salt 0.1 → green(0)
        // Score: 1+1+1+0 = 3 → amber
        let amberRating = NutrientTrafficLight.overallRating(
            fat: 5.0, saturatedFat: 2.0, sugar: 6.0, salt: 0.1
        )
        #expect(amberRating == .amber)

        // fat 5 → amber(1), satfat 2 → amber(1), sugar 6 → amber(1), salt 0.5 → amber(1)
        // Score: 1+1+1+1 = 4 → rot
        let redRating = NutrientTrafficLight.overallRating(
            fat: 5.0, saturatedFat: 2.0, sugar: 6.0, salt: 0.5
        )
        #expect(redRating == .red)
    }

    // MARK: Praxisbeispiele

    @Test func cucumberIsGreen() {
        // Gurke: ~0.1g Fett, ~0g gesaettigtes Fett, ~1.7g Zucker, ~0.01g Salz
        let rating = NutrientTrafficLight.overallRating(
            fat: 0.1, saturatedFat: 0.0, sugar: 1.7, salt: 0.01
        )
        #expect(rating == .green)
    }

    @Test func appleIsGreen() {
        // Apfel: ~0.2g Fett, ~0g gesaettigtes Fett, ~10g Zucker, ~0g Salz
        // Score: 0+0+1+0 = 1 → gruen (Fruchtzucker wird toleriert)
        let rating = NutrientTrafficLight.overallRating(
            fat: 0.2, saturatedFat: 0.0, sugar: 10.0, salt: 0.0
        )
        #expect(rating == .green)
    }

    @Test func chipsAreRed() {
        // Chips: ~33g Fett, ~3g gesaettigtes Fett, ~0.5g Zucker, ~1.5g Salz
        // Score: 2+1+0+1 = 4 → rot
        let rating = NutrientTrafficLight.overallRating(
            fat: 33.0, saturatedFat: 3.0, sugar: 0.5, salt: 1.5
        )
        #expect(rating == .red)
    }

    @Test func ryeBreadIsAmber() {
        // Roggenbrot (Quelle: Riedmair): ~1.0g Fett, ~0.2g ges. Fett, ~2.0g Zucker, ~2.0g Salz
        // Score: green(0) + green(0) + green(0) + red(2) = 2 → gelb
        let rating = NutrientTrafficLight.overallRating(
            fat: 1.0, saturatedFat: 0.2, sugar: 2.0, salt: 2.0
        )
        #expect(rating == .amber)
    }

    @Test func currywurstIsRed() {
        // Currywurst mit Sosse: ~18g Fett, ~6g ges. Fett, ~9g Zucker, ~2g Salz
        // Score: red(2) + red(2) + amber(1) + red(2) = 7 → rot
        let rating = NutrientTrafficLight.overallRating(
            fat: 18.0, saturatedFat: 6.0, sugar: 9.0, salt: 2.0
        )
        #expect(rating == .red)
    }

    // MARK: score — der Zwischenwert, den `kk today --json` mit ausgibt

    @Test func scoreSumsAllFourCategories() {
        // fat 20 → red(2), satfat 6 → red(2), sugar 25 → red(2), salt 2 → red(2)
        // Hoechstmoeglicher Wert: vier Kategorien à 2 Punkte.
        #expect(NutrientTrafficLight.score(fat: 20.0, saturatedFat: 6.0, sugar: 25.0, salt: 2.0) == 8)
    }

    @Test func scoreIsZeroForCleanValues() {
        #expect(NutrientTrafficLight.score(fat: 1.0, saturatedFat: 0.5, sugar: 2.0, salt: 0.1) == 0)
    }

    @Test func ratingForScoreMatchesThresholds() {
        #expect(NutrientTrafficLight.rating(forScore: 0) == .green)
        #expect(NutrientTrafficLight.rating(forScore: 1) == .green)
        #expect(NutrientTrafficLight.rating(forScore: 2) == .amber)
        #expect(NutrientTrafficLight.rating(forScore: 3) == .amber)
        #expect(NutrientTrafficLight.rating(forScore: 4) == .red)
        #expect(NutrientTrafficLight.rating(forScore: 8) == .red)
    }

    @Test func scoresOfDocumentedExamples() {
        // Die Beispieltabelle aus Docs/NutrientTrafficLight.md — sie ist die
        // Referenz fuer den Wert, den `kk today --json` je Eintrag ausgibt.
        let beispiele: [(name: String, fat: Double, satFat: Double, sugar: Double,
                         salt: Double, score: Int, rating: TrafficLightRating)] = [
            ("Gurke",      0.1,   0.0,  1.7, 0.01, 0, .green),
            ("Apfel",      0.2,   0.0, 10.0, 0.0,  1, .green),
            ("Pommes",    13.2,   1.8,  0.3, 0.7,  3, .amber),
            ("Chips",     33.0,   3.0,  0.5, 1.5,  4, .red),
            ("Olivenoel", 100.0, 14.0,  0.0, 0.0,  4, .red)
        ]
        for b in beispiele {
            let score = NutrientTrafficLight.score(
                fat: b.fat, saturatedFat: b.satFat, sugar: b.sugar, salt: b.salt
            )
            #expect(score == b.score, "\(b.name)")
            #expect(NutrientTrafficLight.rating(forScore: score) == b.rating, "\(b.name)")
        }
    }

    // MARK: FoodItem.trafficLight — fehlende Naehrwerte werden nicht geraten

    @Test func trafficLightForFoodWithNutrients() {
        let chips = FoodItem(
            name: "Chips",
            caloriesPer100g: 533,
            fatPer100g: 33, sugarPer100g: 0.5, saturatedFatPer100g: 3, saltPer100g: 1.5
        )
        #expect(chips.trafficLight?.score == 4)
        #expect(chips.trafficLight?.rating == .red)
    }

    @Test func noTrafficLightWhenNutrientsAreMissing() {
        // Kalorien vorhanden, aber kein Gramm Fett, Zucker oder Salz: das sind
        // fehlende Angaben, keine besonders reinen Werte.
        let schnelleintrag = FoodItem(name: "Schnelleintrag", caloriesPer100g: 250)
        #expect(schnelleintrag.trafficLight == nil)
    }

    @Test func trafficLightForGenuinelyEmptyFood() {
        // Null Kalorien: hier sind die Nullen echt (Wasser, schwarzer Kaffee).
        let wasser = FoodItem(name: "Wasser", caloriesPer100g: 0)
        #expect(wasser.trafficLight?.rating == .green)
    }

    // MARK: needsNutrientRepair — Auswahl fuer `kk repair nutrients`

    @Test func repairPicksItemsWithoutMicronutrients() {
        // Altbestand: Kalorien und Fett da, die drei Mikrowerte fehlen.
        let pommes = FoodItem(name: "Pommes Frites", caloriesPer100g: 312, fatPer100g: 15)
        #expect(pommes.needsNutrientRepair)
    }

    @Test func repairSkipsCompleteItems() {
        let chips = FoodItem(
            name: "Chips",
            caloriesPer100g: 533,
            fatPer100g: 33, sugarPer100g: 0.5, saturatedFatPer100g: 3, saltPer100g: 1.5
        )
        #expect(!chips.needsNutrientRepair)
    }

    @Test func repairSkipsGenuinelyEmptyFood() {
        // Null Kalorien: die Nullen sind echt, es gibt nichts nachzutragen.
        let wasser = FoodItem(name: "Wasser", caloriesPer100g: 0)
        #expect(!wasser.needsNutrientRepair)
    }

    @Test func repairSkipsItemWithoutAnyMacros() {
        // 750 kcal und sonst nichts: hier fehlt auch der Anker fuer eine
        // Nachschaetzung. Der ehrliche Platzhalter ist besser als eine Ampel,
        // die auf zwei nachgetragenen Werten und vier Nullen steht.
        let burger = FoodItem(name: "Copaburger mit Pommes", caloriesPer100g: 750)
        #expect(!burger.needsNutrientRepair)
        #expect(burger.trafficLight == nil)
    }

    @Test func repairPicksItemWithSingleKnownNutrient() {
        // Ein belegter Wert reicht der Ampel, macht die Basis aber nicht gut:
        // solange die drei Mikrowerte fehlen, gehoert der Eintrag in die Reparatur.
        let magerquark = FoodItem(name: "Magerquark", caloriesPer100g: 67, fatPer100g: 0.3)
        #expect(magerquark.trafficLight != nil)
        #expect(magerquark.needsNutrientRepair)
    }

    @Test func trafficLightNeedsOnlyOneNutrientToCount() {
        // Ein einziger belegter Wert reicht als Beleg dafuer, dass Naehrwerte
        // erfasst wurden — der Rest darf echte Null sein.
        let magerquark = FoodItem(name: "Magerquark", caloriesPer100g: 67, saltPer100g: 0.1)
        #expect(magerquark.trafficLight?.score == 0)
        #expect(magerquark.trafficLight?.rating == .green)
    }
}

// MARK: - TrafficLightRating Tests

struct TrafficLightRatingTests {

    @Test func rawValues() {
        #expect(TrafficLightRating.green.rawValue == 0)
        #expect(TrafficLightRating.amber.rawValue == 1)
        #expect(TrafficLightRating.red.rawValue == 2)
    }

    @Test func imageNamesNotEmpty() {
        let ratings: [TrafficLightRating] = [.green, .amber, .red]
        for rating in ratings {
            #expect(!rating.imageName.isEmpty)
        }
    }

    @Test func colorsAreDifferent() {
        #expect(TrafficLightRating.green.color != TrafficLightRating.amber.color)
        #expect(TrafficLightRating.amber.color != TrafficLightRating.red.color)
        #expect(TrafficLightRating.green.color != TrafficLightRating.red.color)
    }
}

// MARK: - CurrentDayProvider Tests

struct CurrentDayProviderTests {

    @Test func initialDateIsToday() {
        let provider = CurrentDayProvider()
        #expect(provider.isToday)
    }

    @Test func previousDayGoesBack() {
        let provider = CurrentDayProvider()
        let today = provider.selectedDate
        provider.previousDay()
        let expected = today.addingDays(-1)
        #expect(provider.selectedDate.isSameDay(as: expected))
    }

    @Test func nextDayGoesForward() {
        let provider = CurrentDayProvider()
        provider.previousDay() // gehe einen Tag zurueck
        let yesterday = provider.selectedDate
        provider.nextDay()
        let expected = yesterday.addingDays(1)
        #expect(provider.selectedDate.isSameDay(as: expected))
    }

    @Test func goToTodayResetsToToday() {
        let provider = CurrentDayProvider()
        provider.previousDay()
        provider.previousDay()
        #expect(!provider.isToday)
        provider.goToToday()
        #expect(provider.isToday)
    }

    @Test func canGoForwardFalseWhenToday() {
        let provider = CurrentDayProvider()
        #expect(!provider.canGoForward)
    }

    @Test func canGoForwardTrueWhenPast() {
        let provider = CurrentDayProvider()
        provider.previousDay()
        #expect(provider.canGoForward)
    }
}

// MARK: - Enum Tests (Gender, ActivityLevel, WeightUnit)

struct EnumTests {

    // MARK: Gender

    @Test func genderCaseCount() {
        #expect(Gender.allCases.count == 2)
    }

    @Test func genderRawValues() {
        #expect(Gender.male.rawValue == "male")
        #expect(Gender.female.rawValue == "female")
    }

    @Test func genderIdMatchesRawValue() {
        for gender in Gender.allCases {
            #expect(gender.id == gender.rawValue)
        }
    }

    // MARK: ActivityLevel

    @Test func activityLevelCaseCount() {
        #expect(ActivityLevel.allCases.count == 4)
    }

    @Test func activityLevelPalFactors() {
        #expect(ActivityLevel.sedentary.palFactor == 1.2)
        #expect(ActivityLevel.lightlyActive.palFactor == 1.375)
        #expect(ActivityLevel.moderatelyActive.palFactor == 1.55)
        #expect(ActivityLevel.veryActive.palFactor == 1.725)
    }

    @Test func activityLevelIdMatchesRawValue() {
        for level in ActivityLevel.allCases {
            #expect(level.id == level.rawValue)
        }
    }

    // MARK: WeightUnit

    @Test func weightUnitCaseCount() {
        #expect(WeightUnit.allCases.count == 2)
    }

    @Test func weightUnitRawValues() {
        #expect(WeightUnit.kg.rawValue == "kg")
        #expect(WeightUnit.lbs.rawValue == "lbs")
    }

    // MARK: MealType budgetWeight

    @Test func mealTypeBudgetWeightsSumToOne() {
        let sum = MealType.allCases.reduce(0.0) { $0 + $1.budgetWeight }
        #expect(abs(sum - 1.0) < 0.0001)
    }

    @Test func mealTypeBudgetWeightValues() {
        #expect(MealType.breakfast.budgetWeight == 0.25)
        #expect(MealType.secondBreakfast.budgetWeight == 0.10)
        #expect(MealType.lunch.budgetWeight == 0.30)
        #expect(MealType.coffeeBreak.budgetWeight == 0.05)
        #expect(MealType.dinner.budgetWeight == 0.25)
        #expect(MealType.snack.budgetWeight == 0.05)
    }
}

// MARK: - BMICalculator Tests

struct BMICalculatorTests {

    // MARK: BMI-Berechnung

    @Test func bmiNormalWeight() {
        // 70 kg, 175 cm → 70 / (1.75)^2 = 70 / 3.0625 = 22.857...
        let bmi = BMICalculator.bmi(weightKg: 70, heightCm: 175)
        #expect(abs(bmi - 22.857) < 0.01)
    }

    @Test func bmiOverweight() {
        // 90 kg, 175 cm → 90 / 3.0625 = 29.387...
        let bmi = BMICalculator.bmi(weightKg: 90, heightCm: 175)
        #expect(abs(bmi - 29.388) < 0.01)
    }

    @Test func bmiZeroHeight() {
        let bmi = BMICalculator.bmi(weightKg: 70, heightCm: 0)
        #expect(bmi == 0)
    }

    // MARK: BMI-Kategorien

    @Test func categoryUnderweight() {
        #expect(BMICalculator.category(bmi: 17.0) == .underweight)
        #expect(BMICalculator.category(bmi: 18.4) == .underweight)
    }

    @Test func categoryNormal() {
        #expect(BMICalculator.category(bmi: 18.5) == .normal)
        #expect(BMICalculator.category(bmi: 22.0) == .normal)
        #expect(BMICalculator.category(bmi: 24.9) == .normal)
    }

    @Test func categoryOverweight() {
        #expect(BMICalculator.category(bmi: 25.0) == .overweight)
        #expect(BMICalculator.category(bmi: 29.9) == .overweight)
    }

    @Test func categoryObese1() {
        #expect(BMICalculator.category(bmi: 30.0) == .obese1)
        #expect(BMICalculator.category(bmi: 34.9) == .obese1)
    }

    @Test func categoryObese2() {
        #expect(BMICalculator.category(bmi: 35.0) == .obese2)
        #expect(BMICalculator.category(bmi: 39.9) == .obese2)
    }

    @Test func categoryObese3() {
        #expect(BMICalculator.category(bmi: 40.0) == .obese3)
        #expect(BMICalculator.category(bmi: 50.0) == .obese3)
    }

    // MARK: Sicherheitsminimum

    @Test func safetyMinimumFemale() {
        #expect(BMICalculator.safetyMinimum(gender: .female) == 1200)
    }

    @Test func safetyMinimumMale() {
        #expect(BMICalculator.safetyMinimum(gender: .male) == 1500)
    }

    // MARK: Tagesdefizit

    @Test func dailyDeficitModerate() {
        // -0.5 kg/Woche: (-0.5 * 7700) / 7 = -550
        let deficit = BMICalculator.dailyDeficit(weeklyGoalKg: -0.5)
        #expect(deficit == -550)
    }

    @Test func dailyDeficitSlow() {
        // -0.25 kg/Woche: (-0.25 * 7700) / 7 = -275
        let deficit = BMICalculator.dailyDeficit(weeklyGoalKg: -0.25)
        #expect(deficit == -275)
    }

    @Test func dailyDeficitFast() {
        // -1.0 kg/Woche: (-1.0 * 7700) / 7 = -1100
        let deficit = BMICalculator.dailyDeficit(weeklyGoalKg: -1.0)
        #expect(deficit == -1100)
    }

    @Test func dailyDeficitMaintain() {
        let deficit = BMICalculator.dailyDeficit(weeklyGoalKg: 0)
        #expect(deficit == 0)
    }

    // MARK: Kalorienziel mit Defizit

    @Test func calorieGoalWithDeficitNormal() {
        // TDEE 2700, Defizit -550 → 2150 (ueber Sicherheitsgrenze)
        let goal = BMICalculator.calorieGoalWithDeficit(tdee: 2700, weeklyGoalKg: -0.5, gender: .male)
        #expect(goal == 2150)
    }

    @Test func calorieGoalClampedToSafetyMale() {
        // TDEE 1800, Defizit -1100 → 700, aber Minimum 1500
        let goal = BMICalculator.calorieGoalWithDeficit(tdee: 1800, weeklyGoalKg: -1.0, gender: .male)
        #expect(goal == 1500)
    }

    @Test func calorieGoalClampedToSafetyFemale() {
        // TDEE 1500, Defizit -550 → 950, aber Minimum 1200
        let goal = BMICalculator.calorieGoalWithDeficit(tdee: 1500, weeklyGoalKg: -0.5, gender: .female)
        #expect(goal == 1200)
    }

    // MARK: Geschaetztes Zieldatum

    @Test func estimatedGoalDateReturnsDate() {
        let date = BMICalculator.estimatedGoalDate(currentKg: 90, goalKg: 80, weeklyGoalKg: -0.5)
        #expect(date != nil)
    }

    @Test func estimatedGoalDateNilWhenZeroRate() {
        let date = BMICalculator.estimatedGoalDate(currentKg: 90, goalKg: 80, weeklyGoalKg: 0)
        #expect(date == nil)
    }

    @Test func estimatedGoalDateNilWhenAlreadyAtGoal() {
        let date = BMICalculator.estimatedGoalDate(currentKg: 80, goalKg: 80, weeklyGoalKg: -0.5)
        #expect(date == nil)
    }

    @Test func estimatedGoalDateApproximateWeeks() {
        // 10 kg bei -0.5/Woche = 20 Wochen = 140 Tage
        let date = BMICalculator.estimatedGoalDate(currentKg: 90, goalKg: 80, weeklyGoalKg: -0.5)!
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day!
        #expect(abs(days - 140) <= 1)
    }

    // MARK: Makro-Verteilung

    @Test func macroGrams2000kcal() {
        let macros = BMICalculator.macroGrams(calorieGoal: 2000)
        // Protein: (2000 * 0.30) / 4 = 150
        #expect(macros.protein == 150)
        // Carbs: (2000 * 0.40) / 4 = 200
        #expect(macros.carbs == 200)
        // Fat: (2000 * 0.30) / 9 = 66.66 → 66
        #expect(macros.fat == 66)
    }

    @Test func macroGrams1500kcal() {
        let macros = BMICalculator.macroGrams(calorieGoal: 1500)
        // Protein: (1500 * 0.30) / 4 = 112.5 → 112
        #expect(macros.protein == 112)
        // Carbs: (1500 * 0.40) / 4 = 150
        #expect(macros.carbs == 150)
        // Fat: (1500 * 0.30) / 9 = 50
        #expect(macros.fat == 50)
    }

    // MARK: BMICategory

    @Test func bmiCategoryAllCasesCount() {
        #expect(BMICategory.allCases.count == 6)
    }

    @Test func bmiCategoryScaleWidthsSumTo30() {
        // BMI-Skala 15-45 = Gesamtbreite 30
        let total = BMICategory.allCases.reduce(0.0) { $0 + $1.scaleWidth }
        #expect(total == 30.0)
    }
}

// MARK: - CalorieCalculator goalAdjustedCalories Tests

struct CalorieCalculatorGoalTests {

    @Test func goalAdjustedCaloriesMale() {
        // TDEE Mann 80kg/175cm/30J/moderately = 2700
        // Defizit -0.5: -550 → 2150
        let goal = CalorieCalculator.goalAdjustedCalories(
            weightKg: 80, heightCm: 175, age: 30,
            gender: .male, activityLevel: .moderatelyActive,
            weeklyGoalKg: -0.5
        )
        #expect(goal == 2150)
    }

    @Test func goalAdjustedCaloriesFemale() {
        // BMR Frau 60kg/165cm/25J = 1345.25
        // TDEE: 1345.25 * 1.55 = 2085.14 → gerundet 2100
        // Defizit -0.5: -550 → 1550
        let goal = CalorieCalculator.goalAdjustedCalories(
            weightKg: 60, heightCm: 165, age: 25,
            gender: .female, activityLevel: .moderatelyActive,
            weeklyGoalKg: -0.5
        )
        #expect(goal == 1550)
    }

    @Test func goalAdjustedCaloriesClampedFemale() {
        // TDEE Frau sedentary ~1600, Defizit -1100 = 500 → clamped auf 1200
        let goal = CalorieCalculator.goalAdjustedCalories(
            weightKg: 60, heightCm: 165, age: 25,
            gender: .female, activityLevel: .sedentary,
            weeklyGoalKg: -1.0
        )
        #expect(goal == 1200)
    }
}

// MARK: - GoalType Tests

struct GoalTypeTests {

    @Test func goalTypeCaseCount() {
        #expect(GoalType.allCases.count == 3)
    }

    @Test func goalTypeRawValues() {
        #expect(GoalType.lose.rawValue == 0)
        #expect(GoalType.maintain.rawValue == 1)
        #expect(GoalType.gain.rawValue == 2)
    }

    @Test func goalTypeIdMatchesRawValue() {
        for goalType in GoalType.allCases {
            #expect(goalType.id == goalType.rawValue)
        }
    }

    @Test func goalTypeFromRawValue() {
        #expect(GoalType(rawValue: 0) == .lose)
        #expect(GoalType(rawValue: 1) == .maintain)
        #expect(GoalType(rawValue: 2) == .gain)
        #expect(GoalType(rawValue: 99) == nil)
    }
}

// MARK: - OFF Decoding Tests

struct OFFDecodingTests {

    @Test func decodeFullProduct() throws {
        let json = """
        {
            "code": "3017620422003",
            "product_name": "Nutella",
            "brands": "Ferrero",
            "nutriments": {
                "energy-kcal_100g": 539,
                "proteins_100g": 6.3,
                "carbohydrates_100g": 57.5,
                "fat_100g": 30.9,
                "fiber_100g": 0,
                "sugars_100g": 56.3,
                "saturated-fat_100g": 10.6,
                "salt_100g": 0.107
            },
            "serving_size": "15g",
            "image_front_small_url": "https://example.com/nutella.jpg"
        }
        """
        let data = json.data(using: .utf8)!
        let product = try JSONDecoder().decode(OFFProduct.self, from: data)

        #expect(product.code == "3017620422003")
        #expect(product.productName == "Nutella")
        #expect(product.brands == "Ferrero")
        #expect(product.servingSize == "15g")
        #expect(product.imageFrontSmallURL == "https://example.com/nutella.jpg")
        #expect(product.nutriments?.energyKcal100g == 539)
        #expect(product.nutriments?.proteins100g == 6.3)
        #expect(product.nutriments?.fat100g == 30.9)
        #expect(product.nutriments?.sugars100g == 56.3)
        #expect(product.nutriments?.saturatedFat100g == 10.6)
        #expect(product.nutriments?.salt100g == 0.107)
    }

    @Test func decodeProductWithMissingOptionalFields() throws {
        let json = """
        {
            "code": "12345"
        }
        """
        let data = json.data(using: .utf8)!
        let product = try JSONDecoder().decode(OFFProduct.self, from: data)

        #expect(product.code == "12345")
        #expect(product.productName == nil)
        #expect(product.brands == nil)
        #expect(product.nutriments == nil)
        #expect(product.servingSize == nil)
    }

    @Test func decodeNutrimentsWithSnakeCaseKeys() throws {
        let json = """
        {
            "energy-kcal_100g": 250,
            "proteins_100g": 8.5,
            "carbohydrates_100g": 30.0,
            "fat_100g": 10.0,
            "fiber_100g": 3.0,
            "sugars_100g": 5.0,
            "saturated-fat_100g": 4.0,
            "salt_100g": 1.2
        }
        """
        let data = json.data(using: .utf8)!
        let nutriments = try JSONDecoder().decode(OFFNutriments.self, from: data)

        #expect(nutriments.energyKcal100g == 250)
        #expect(nutriments.proteins100g == 8.5)
        #expect(nutriments.carbohydrates100g == 30.0)
        #expect(nutriments.fat100g == 10.0)
        #expect(nutriments.fiber100g == 3.0)
        #expect(nutriments.sugars100g == 5.0)
        #expect(nutriments.saturatedFat100g == 4.0)
        #expect(nutriments.salt100g == 1.2)
    }

    @Test func decodeSearchResponseEmptyHits() throws {
        let json = """
        {
            "hits": []
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(OFFSearchResponse.self, from: data)

        #expect(response.hits?.isEmpty == true)
    }

    @Test func decodeProductResponse() throws {
        let json = """
        {
            "status": 1,
            "product": {
                "code": "4006040123456",
                "product_name": "Testprodukt"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(OFFProductResponse.self, from: data)

        #expect(response.status == 1)
        #expect(response.product?.code == "4006040123456")
        #expect(response.product?.productName == "Testprodukt")
    }
}

// MARK: - ServingSizeParser Tests

struct ServingSizeParserTests {

    @Test func parseSimpleGrams() {
        #expect(ServingSizeParser.parseGrams(from: "30g") == 30.0)
    }

    @Test func parseGramsWithParentheses() {
        #expect(ServingSizeParser.parseGrams(from: "1 Scheibe (25 g)") == 25.0)
    }

    @Test func parseGramm() {
        #expect(ServingSizeParser.parseGrams(from: "100gramm") == 100.0)
    }

    @Test func parseGramsWithComma() {
        #expect(ServingSizeParser.parseGrams(from: "2,5g") == 2.5)
    }

    @Test func parseGramsWithSpace() {
        #expect(ServingSizeParser.parseGrams(from: "50 g") == 50.0)
    }

    @Test func parseMilliliterReturnsNil() {
        #expect(ServingSizeParser.parseGrams(from: "250 ml") == nil)
    }

    @Test func parseEmptyStringReturnsNil() {
        #expect(ServingSizeParser.parseGrams(from: "") == nil)
    }

    @Test func parseNoNumberReturnsNil() {
        #expect(ServingSizeParser.parseGrams(from: "keine Angabe") == nil)
    }

    @Test func parseDecimalGrams() {
        #expect(ServingSizeParser.parseGrams(from: "12.5g") == 12.5)
    }
}

// MARK: - AIFoodEstimate Tests

struct AIFoodEstimateTests {

    @Test func decodeValidJSON() throws {
        let json = """
        {
            "name": "Currywurst mit Pommes",
            "confidence": "high",
            "estimatedWeightGrams": 350,
            "caloriesPer100g": 220,
            "proteinPer100g": 8.5,
            "carbsPer100g": 25.0,
            "fatPer100g": 10.0,
            "fiberPer100g": 2.0,
            "sugarPer100g": 3.5,
            "saturatedFatPer100g": 4.0,
            "saltPer100g": 1.8,
            "totalCalories": 770,
            "components": [
                {"name": "Currywurst", "estimatedGrams": 150},
                {"name": "Pommes Frites", "estimatedGrams": 180},
                {"name": "Currysosse", "estimatedGrams": 20}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let estimate = try JSONDecoder().decode(AIFoodEstimate.self, from: data)

        #expect(estimate.name == "Currywurst mit Pommes")
        #expect(estimate.confidence == "high")
        #expect(estimate.estimatedWeightGrams == 350)
        #expect(estimate.caloriesPer100g == 220)
        #expect(estimate.proteinPer100g == 8.5)
        #expect(estimate.carbsPer100g == 25.0)
        #expect(estimate.fatPer100g == 10.0)
        #expect(estimate.fiberPer100g == 2.0)
        #expect(estimate.sugarPer100g == 3.5)
        #expect(estimate.saturatedFatPer100g == 4.0)
        #expect(estimate.saltPer100g == 1.8)
        #expect(estimate.totalCalories == 770)
        #expect(estimate.components.count == 3)
        #expect(estimate.components[0].name == "Currywurst")
        #expect(estimate.components[0].estimatedGrams == 150)
    }

    @Test func portionCalculation() {
        let json = """
        {
            "name": "Testgericht",
            "confidence": "medium",
            "estimatedWeightGrams": 200,
            "caloriesPer100g": 150,
            "proteinPer100g": 10,
            "carbsPer100g": 20,
            "fatPer100g": 5,
            "fiberPer100g": 3,
            "sugarPer100g": 2,
            "saturatedFatPer100g": 1,
            "saltPer100g": 0.5,
            "totalCalories": 300,
            "components": []
        }
        """
        let data = json.data(using: .utf8)!
        let estimate = try! JSONDecoder().decode(AIFoodEstimate.self, from: data)

        // 200g Portion × 150 kcal/100g = 300 kcal
        #expect(estimate.portionCalories == 300)
        // 200g × 10g/100g = 20g Protein
        #expect(estimate.portionProtein == 20)
        // 200g × 20g/100g = 40g Carbs
        #expect(estimate.portionCarbs == 40)
        // 200g × 5g/100g = 10g Fat
        #expect(estimate.portionFat == 10)
    }

    @Test func confidenceLevels() {
        #expect(ConfidenceLevel(rawValue: "high")?.dots == 3)
        #expect(ConfidenceLevel(rawValue: "medium")?.dots == 2)
        #expect(ConfidenceLevel(rawValue: "low")?.dots == 1)
        #expect(ConfidenceLevel(rawValue: "invalid") == nil)
    }
}

// MARK: - NutrientCalculator effectiveCalorieGoal Tests

struct EffectiveCalorieGoalTests {

    // Hilfsfunktion: UserProfile mit Standardwerten fuer Tests
    private func makeProfile(
        goal: Int = 2000,
        useAuto: Bool = false,
        useHKActivity: Bool = false,
        weightKg: Double = 80,
        heightCm: Double = 175,
        age: Int = 30,
        gender: Gender = .male,
        activityLevel: ActivityLevel = .moderatelyActive,
        exerciseCreditPercent: Int = 50,
        weekendBonusPercent: Int = 0,
        goalType: GoalType = .lose,
        weeklyWeightGoalKg: Double = -0.5
    ) -> UserProfile {
        let p = UserProfile(dailyCalorieGoal: goal)
        p.useAutoCalories = useAuto
        p.useHealthKitActivity = useHKActivity
        p.bodyWeightKg = weightKg
        p.heightCm = heightCm
        p.age = age
        p.gender = gender
        p.activityLevel = activityLevel
        p.exerciseCreditPercent = exerciseCreditPercent
        p.weekendBonusPercent = weekendBonusPercent
        p.goalType = goalType
        p.weeklyWeightGoalKg = weeklyWeightGoalKg
        return p
    }

    private func makeDayRecord(
        date: Date = Date(),
        activeEnergyKcal: Int = 0,
        workoutCaloriesKcal: Int = 0
    ) -> DayRecord {
        let r = DayRecord(date: date)
        r.activeEnergyKcal = activeEnergyKcal
        r.workoutCaloriesKcal = workoutCaloriesKcal
        return r
    }

    /// Erzeugt ein Datum fuer einen bestimmten Wochentag (1=So, 7=Sa)
    private func dateForWeekday(_ weekday: Int) -> Date {
        let calendar = Calendar.current
        let today = Date()
        let todayWeekday = calendar.component(.weekday, from: today)
        let diff = weekday - todayWeekday
        return calendar.date(byAdding: .day, value: diff, to: today)!
    }

    // MARK: Standardwerte (nil-Profile)

    @Test func nilProfileReturnsDefault2000() {
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: nil, dayRecord: nil, nonWorkoutActiveEnergy: 0
        )
        #expect(goal == 2000)
    }

    // MARK: Manueller Modus

    @Test func manualModeReturnsBaseGoal() {
        let profile = makeProfile(goal: 2500, useAuto: false)
        let record = makeDayRecord()
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 500
        )
        // Kein HealthKit-Active im manuellen Modus
        #expect(goal == 2500)
    }

    @Test func manualModeWithWorkoutCredit() {
        let profile = makeProfile(goal: 2000, useAuto: false, exerciseCreditPercent: 50)
        let record = makeDayRecord(workoutCaloriesKcal: 400)
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 0
        )
        // 2000 + (400 * 50/100) = 2200
        #expect(goal == 2200)
    }

    @Test func manualModeIgnoresNonWorkoutActivity() {
        let profile = makeProfile(goal: 2000, useAuto: false)
        let record = makeDayRecord()
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 1000
        )
        // nonWorkoutActiveEnergy wird ignoriert im manuellen Modus
        #expect(goal == 2000)
    }

    // MARK: Auto-Modus ohne HealthKit

    @Test func autoModeWithoutHealthKitReturnsBase() {
        // Auto-Modus berechnet TDEE frisch: 80/175/30/male/moderatelyActive → TDEE 2700
        // goalType=.maintain → base = TDEE = 2700
        let profile = makeProfile(useAuto: true, useHKActivity: false, goalType: .maintain)
        let record = makeDayRecord()
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 800
        )
        // useHKActivity=false → kein Aktivitaets-Bonus
        #expect(goal == 2700)
    }

    @Test func autoModeIgnoresStoredGoal() {
        // Gespeicherter dailyCalorieGoal=9999, aber useAuto=true → wird ignoriert
        let profile = makeProfile(goal: 9999, useAuto: true, useHKActivity: false, goalType: .maintain)
        let record = makeDayRecord()
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 0
        )
        // base = TDEE 2700 (berechnet, nicht gespeichert)
        #expect(goal == 2700)
    }

    @Test func autoModeComputesGoalWithDeficit() {
        // Auto-Modus mit Defizit: TDEE 2700 - 550 (0.5kg/Woche) = 2150
        let profile = makeProfile(goal: 9999, useAuto: true, useHKActivity: false,
                                  goalType: .lose, weeklyWeightGoalKg: -0.5)
        let record = makeDayRecord()
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 0
        )
        #expect(goal == 2150)
    }

    @Test func autoModeGoalConsistentWithCalorieCalculator() {
        // computeAutoCalorieGoal muss identisch mit CalorieCalculator.goalAdjustedCalories sein
        let calcGoal = CalorieCalculator.goalAdjustedCalories(
            weightKg: 80, heightCm: 175, age: 30,
            gender: .male, activityLevel: .moderatelyActive,
            weeklyGoalKg: -0.5
        )
        let profile = makeProfile(goal: 9999, useAuto: true, useHKActivity: false,
                                  goalType: .lose, weeklyWeightGoalKg: -0.5)
        let record = makeDayRecord()
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 0
        )
        #expect(goal == calcGoal)
    }

    // MARK: PAL-Bonus-Modell

    @Test func palBonusModelNoBonus() {
        // BMR Mann 80kg/175cm/30J = 1748.75
        // TDEE moderatelyActive = 2700 (gerundet)
        // Auto-Modus maintain → base = 2700
        // PAL-implizierte Aktivitaet = 2700 - 1748 = 952
        // nonWorkoutActiveEnergy 500 < 952 → kein Bonus
        let profile = makeProfile(useAuto: true, useHKActivity: true, goalType: .maintain)
        let record = makeDayRecord()
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 500
        )
        // 2700 + max(0, 500-952) + 0 = 2700
        #expect(goal == 2700)
    }

    @Test func palBonusModelWithBonus() {
        // PAL-implizierte Aktivitaet = 952
        // nonWorkoutActiveEnergy 1200 > 952 → Bonus = 248
        let profile = makeProfile(useAuto: true, useHKActivity: true, goalType: .maintain)
        let record = makeDayRecord()
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 1200
        )
        // 2700 + max(0, 1200-952) + 0 = 2700 + 248 = 2948
        #expect(goal == 2948)
    }

    @Test func palBonusModelExactlyAtPAL() {
        // nonWorkoutActiveEnergy genau = 952 → kein Bonus
        let profile = makeProfile(useAuto: true, useHKActivity: true, goalType: .maintain)
        let record = makeDayRecord()
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 952
        )
        #expect(goal == 2700)
    }

    @Test func palBonusModelWithWorkoutCredit() {
        // PAL-Aktivitaet = 952, nonWorkout 500 → kein Activity-Bonus
        // Workout 300 * 50% = 150
        let profile = makeProfile(useAuto: true, useHKActivity: true,
                                  exerciseCreditPercent: 50, goalType: .maintain)
        let record = makeDayRecord(workoutCaloriesKcal: 300)
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 500
        )
        // 2700 + 0 + 150 = 2850
        #expect(goal == 2850)
    }

    @Test func palBonusModelBonusPlusWorkout() {
        // PAL-Aktivitaet = 952, nonWorkout 1100 → Bonus = 148
        // Workout 400 * 50% = 200
        let profile = makeProfile(useAuto: true, useHKActivity: true,
                                  exerciseCreditPercent: 50, goalType: .maintain)
        let record = makeDayRecord(workoutCaloriesKcal: 400)
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 1100
        )
        // 2700 + 148 + 200 = 3048
        #expect(goal == 3048)
    }

    // MARK: PAL-Bonus fuer verschiedene Aktivitaetslevel

    @Test func palBonusSedentaryLowerThreshold() {
        // BMR Mann 80/175/30 = 1748, TDEE sedentary = 2100
        // Auto-Modus maintain → base = 2100
        // PAL-Aktivitaet = 2100 - 1748 = 352
        // nonWorkout 500 > 352 → Bonus = 148
        let profile = makeProfile(useAuto: true, useHKActivity: true,
                                  activityLevel: .sedentary, goalType: .maintain)
        let record = makeDayRecord()
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 500
        )
        #expect(goal == 2100 + 148)
    }

    @Test func palBonusVeryActiveHighThreshold() {
        // TDEE veryActive = 3000, base = 3000 (maintain)
        // PAL-Aktivitaet = 3000 - 1748 = 1252
        // nonWorkout 1000 < 1252 → kein Bonus
        let profile = makeProfile(useAuto: true, useHKActivity: true,
                                  activityLevel: .veryActive, goalType: .maintain)
        let record = makeDayRecord()
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 1000
        )
        #expect(goal == 3000)
    }

    // MARK: PAL-Bonus Frau

    @Test func palBonusFemale() {
        // BMR Frau 60kg/165cm/25J = 1345.25
        // TDEE moderatelyActive = 2100 (gerundet), base = 2100 (maintain)
        // PAL-Aktivitaet = 2100 - 1345 = 755
        // nonWorkout 800 > 755 → Bonus = 45
        let profile = makeProfile(
            useAuto: true, useHKActivity: true,
            weightKg: 60, heightCm: 165, age: 25,
            gender: .female, activityLevel: .moderatelyActive,
            goalType: .maintain
        )
        let record = makeDayRecord()
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 800
        )
        #expect(goal == 2100 + 45)
    }

    // MARK: Wochenend-Bonus

    @Test func weekendBonusSaturday() {
        let saturday = dateForWeekday(7)
        let profile = makeProfile(goal: 2000, weekendBonusPercent: 10)
        let record = makeDayRecord(date: saturday)
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 0
        )
        // 2000 + (2000 * 10/100) = 2200
        #expect(goal == 2200)
    }

    @Test func weekendBonusSunday() {
        let sunday = dateForWeekday(1)
        let profile = makeProfile(goal: 2000, weekendBonusPercent: 15)
        let record = makeDayRecord(date: sunday)
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 0
        )
        // 2000 + (2000 * 15/100) = 2300
        #expect(goal == 2300)
    }

    @Test func noWeekendBonusOnWeekday() {
        let wednesday = dateForWeekday(4)
        let profile = makeProfile(goal: 2000, weekendBonusPercent: 10)
        let record = makeDayRecord(date: wednesday)
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 0
        )
        // Kein Bonus an Wochentagen
        #expect(goal == 2000)
    }

    @Test func weekendBonusZeroPercent() {
        let saturday = dateForWeekday(7)
        let profile = makeProfile(goal: 2000, weekendBonusPercent: 0)
        let record = makeDayRecord(date: saturday)
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 0
        )
        #expect(goal == 2000)
    }

    // MARK: Workout-Credit Variationen

    @Test func workoutCreditZeroPercent() {
        let profile = makeProfile(goal: 2000, exerciseCreditPercent: 0)
        let record = makeDayRecord(workoutCaloriesKcal: 500)
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 0
        )
        // 0% Anrechnung
        #expect(goal == 2000)
    }

    @Test func workoutCreditFullPercent() {
        let profile = makeProfile(goal: 2000, exerciseCreditPercent: 100)
        let record = makeDayRecord(workoutCaloriesKcal: 500)
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 0
        )
        // 100% Anrechnung
        #expect(goal == 2500)
    }

    // MARK: Kombination: Wochenende + Workout + PAL-Bonus

    @Test func combinedWeekendWorkoutPALBonus() {
        // Samstag, 10% Weekend-Bonus, PAL-Modus, Workout
        // Auto-Modus maintain → base = TDEE 2700
        let saturday = dateForWeekday(7)
        let profile = makeProfile(
            useAuto: true, useHKActivity: true,
            exerciseCreditPercent: 50, weekendBonusPercent: 10,
            goalType: .maintain
        )
        let record = makeDayRecord(date: saturday, workoutCaloriesKcal: 400)
        // PAL-Aktivitaet Mann 80/175/30 moderately = 952
        // nonWorkout 1100 > 952 → Bonus = 148
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 1100
        )
        // adjustedBase = 2700 + 270 = 2970
        // activityBonus = 148
        // creditedWorkout = 400 * 50% = 200
        // Gesamt = 2970 + 148 + 200 = 3318
        #expect(goal == 3318)
    }

    // MARK: Konsistenz mit CalorieCalculator.palImpliedActivity

    @Test func palCalculationConsistentWithCalorieCalculator() {
        // Sicherstellen, dass die inline-PAL-Berechnung in NutrientCalculator
        // die gleichen Ergebnisse liefert wie CalorieCalculator.palImpliedActivity
        // Auto-Modus maintain → base = TDEE 2700
        let profile = makeProfile(
            useAuto: true, useHKActivity: true,
            weightKg: 80, heightCm: 175, age: 30,
            gender: .male, activityLevel: .moderatelyActive,
            goalType: .maintain
        )
        let record = makeDayRecord()

        // CalorieCalculator PAL-Aktivitaet = 952
        let calPAL = CalorieCalculator.palImpliedActivity(
            weightKg: 80, heightCm: 175, age: 30,
            gender: .male, activityLevel: .moderatelyActive
        )

        // Teste mit nonWorkout = PAL + 100 → Bonus muss = 100 sein
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: calPAL + 100
        )
        // base(2700) + bonus(100) + workout(0) = 2800
        #expect(goal == 2700 + 100)
    }

    @Test func palCalculationConsistentFemale() {
        // Frau 60/165/25/lightlyActive, maintain → TDEE
        // BMR = 1345.25, TDEE lightlyActive = 1345.25*1.375 = 1849.72 → gerundet 1850
        let calPAL = CalorieCalculator.palImpliedActivity(
            weightKg: 60, heightCm: 165, age: 25,
            gender: .female, activityLevel: .lightlyActive
        )

        let profile = makeProfile(
            useAuto: true, useHKActivity: true,
            weightKg: 60, heightCm: 165, age: 25,
            gender: .female, activityLevel: .lightlyActive,
            goalType: .maintain
        )
        let record = makeDayRecord()

        // base = TDEE = 1850
        // Teste mit nonWorkout genau auf PAL → kein Bonus
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: calPAL
        )
        #expect(goal == 1850)

        // Teste mit nonWorkout ueber PAL → Bonus
        let goalWithBonus = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: calPAL + 200
        )
        #expect(goalWithBonus == 2050)
    }
}

// MARK: - Aufschluesselung des Tagesziels (Issue #80)

/// Die Anzeige im Budget-Sheet und die Rechnung duerfen nicht auseinander laufen:
/// `effectiveCalorieGoal` ist nur noch die Summe der Posten.
struct GoalBreakdownTests {

    private func makeProfile(
        useAuto: Bool = true,
        useHKActivity: Bool = true,
        weekendBonusPercent: Int = 0,
        exerciseCreditPercent: Int = 50
    ) -> UserProfile {
        let p = UserProfile(dailyCalorieGoal: 2000)
        p.useAutoCalories = useAuto
        p.useHealthKitActivity = useHKActivity
        p.bodyWeightKg = 90
        p.heightCm = 186
        p.age = 60
        p.gender = .male
        p.activityLevel = .moderatelyActive
        p.exerciseCreditPercent = exerciseCreditPercent
        p.weekendBonusPercent = weekendBonusPercent
        p.goalType = .lose
        p.weeklyWeightGoalKg = -0.5
        return p
    }

    private func makeRecord(weekday: Int, workout: Int = 0) -> DayRecord {
        let calendar = Calendar.current
        let heute = Date()
        let diff = weekday - calendar.component(.weekday, from: heute)
        let r = DayRecord(date: calendar.date(byAdding: .day, value: diff, to: heute)!)
        r.workoutCaloriesKcal = workout
        return r
    }

    /// Der Kern: die Summe der angezeigten Posten ist genau das Ziel.
    @Test func totalMatchesEffectiveGoal() {
        let profile = makeProfile(weekendBonusPercent: 10)
        let record = makeRecord(weekday: 1, workout: 420)   // Sonntag

        let breakdown = NutrientCalculator.goalBreakdown(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 1325
        )
        let goal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 1325
        )

        #expect(breakdown.total == goal)
        #expect(breakdown.base + breakdown.weekendBonus + breakdown.activityBonus + breakdown.workoutBonus == goal)
    }

    /// Von der Alltagsbewegung kommt nur an, was ueber dem PAL-Anteil liegt — der Rest
    /// steckt schon im Grundziel. Genau das war ohne die Aufschluesselung unsichtbar.
    @Test func onlyActivityAbovePalCounts() {
        let breakdown = NutrientCalculator.goalBreakdown(
            profile: makeProfile(), dayRecord: makeRecord(weekday: 3), nonWorkoutActiveEnergy: 1325
        )

        #expect(breakdown.activityRaw == 1325)
        #expect(breakdown.activityIncludedInBase == 983)   // TDEE 2750 minus BMR 1768 (abgerundet)
        #expect(breakdown.activityBonus == 342)
    }

    @Test func activityBelowPalGivesNoBonus() {
        let breakdown = NutrientCalculator.goalBreakdown(
            profile: makeProfile(), dayRecord: makeRecord(weekday: 3), nonWorkoutActiveEnergy: 400
        )

        #expect(breakdown.activityBonus == 0)
        // Der Rohwert bleibt erhalten, damit die Null erklaert werden kann
        #expect(breakdown.activityRaw == 400)
        #expect(breakdown.activityIncludedInBase == 983)
    }

    /// Ohne HealthKit-Aktivitaet entfaellt die Bewegungszeile ganz.
    @Test func withoutHealthKitActivityThereIsNoActivityRow() {
        let breakdown = NutrientCalculator.goalBreakdown(
            profile: makeProfile(useHKActivity: false),
            dayRecord: makeRecord(weekday: 3),
            nonWorkoutActiveEnergy: 1325
        )

        #expect(!breakdown.usesActivity)
        #expect(breakdown.activityBonus == 0)
        // Der Rohwert bleibt stehen: der Ring zeigt ihn, also muss das Sheet
        // erklaeren koennen, warum er nicht im Budget landet
        #expect(breakdown.activityRaw == 1325)
    }

    @Test func weekendBonusOnlyOnWeekends() {
        let profile = makeProfile(weekendBonusPercent: 10)

        let werktag = NutrientCalculator.goalBreakdown(
            profile: profile, dayRecord: makeRecord(weekday: 3), nonWorkoutActiveEnergy: 0
        )
        #expect(werktag.weekendBonus == 0)

        let sonntag = NutrientCalculator.goalBreakdown(
            profile: profile, dayRecord: makeRecord(weekday: 1), nonWorkoutActiveEnergy: 0
        )
        #expect(sonntag.weekendBonus == sonntag.base * 10 / 100)
    }

    @Test func workoutIsCreditedByPercent() {
        let breakdown = NutrientCalculator.goalBreakdown(
            profile: makeProfile(exerciseCreditPercent: 50),
            dayRecord: makeRecord(weekday: 3, workout: 420),
            nonWorkoutActiveEnergy: 0
        )

        #expect(breakdown.workoutRaw == 420)
        #expect(breakdown.workoutPercent == 50)
        #expect(breakdown.workoutBonus == 210)
    }

    @Test func noWorkoutMeansNoWorkoutRow() {
        let breakdown = NutrientCalculator.goalBreakdown(
            profile: makeProfile(), dayRecord: makeRecord(weekday: 3), nonWorkoutActiveEnergy: 0
        )
        #expect(breakdown.workoutRaw == 0)
        #expect(breakdown.workoutBonus == 0)
    }
}


// MARK: - ClaudeAPIService Parsing Tests

struct ClaudeAPIParsingTests {

    @Test func parseCleanJSON() async throws {
        let json = """
        {
            "name": "Spaghetti Bolognese",
            "confidence": "high",
            "estimatedWeightGrams": 400,
            "caloriesPer100g": 130,
            "proteinPer100g": 6,
            "carbsPer100g": 18,
            "fatPer100g": 4,
            "fiberPer100g": 1.5,
            "sugarPer100g": 3,
            "saturatedFatPer100g": 1.5,
            "saltPer100g": 0.8,
            "totalCalories": 520,
            "components": [
                {"name": "Spaghetti", "estimatedGrams": 200},
                {"name": "Bolognese-Sosse", "estimatedGrams": 200}
            ]
        }
        """
        let result = try await ClaudeAPIService.shared.parseResponse(json)
        #expect(result.name == "Spaghetti Bolognese")
        #expect(result.components.count == 2)
    }

    @Test func parseJSONInMarkdownBlock() async throws {
        let json = """
        ```json
        {
            "name": "Apfel",
            "confidence": "high",
            "estimatedWeightGrams": 180,
            "caloriesPer100g": 52,
            "proteinPer100g": 0.3,
            "carbsPer100g": 14,
            "fatPer100g": 0.2,
            "fiberPer100g": 2.4,
            "sugarPer100g": 10.4,
            "saturatedFatPer100g": 0,
            "saltPer100g": 0,
            "totalCalories": 94,
            "components": [{"name": "Apfel", "estimatedGrams": 180}]
        }
        ```
        """
        let result = try await ClaudeAPIService.shared.parseResponse(json)
        #expect(result.name == "Apfel")
        #expect(result.estimatedWeightGrams == 180)
    }

    @Test func parseJSONWithSurroundingText() async throws {
        let text = """
        Hier ist meine Analyse:
        {"name": "Toast", "confidence": "low", "estimatedWeightGrams": 60, "caloriesPer100g": 265, "proteinPer100g": 9, "carbsPer100g": 49, "fatPer100g": 3.2, "fiberPer100g": 2.7, "sugarPer100g": 5, "saturatedFatPer100g": 0.7, "saltPer100g": 1.1, "totalCalories": 159, "components": []}
        Das war die Analyse.
        """
        let result = try await ClaudeAPIService.shared.parseResponse(text)
        #expect(result.name == "Toast")
        #expect(result.confidenceLevel == .low)
    }

    @Test func parseInvalidJSONThrows() async {
        let invalidJSON = "Dies ist kein JSON"
        do {
            _ = try await ClaudeAPIService.shared.parseResponse(invalidJSON)
            #expect(Bool(false), "Sollte einen Fehler werfen")
        } catch {
            // Erwarteter Fehler
            #expect(error is ClaudeAPIService.APIError)
        }
    }
}

// MARK: - KeychainHelper Tests

@Suite(.serialized)
struct KeychainHelperTests {

    @Test func saveAndLoadAPIKey() {
        KeychainHelper.deleteAPIKey()
        let testKey = "sk-ant-test-1234567890"
        KeychainHelper.saveAPIKey(testKey)
        let loaded = KeychainHelper.loadAPIKey()
        #expect(loaded == testKey)
        KeychainHelper.deleteAPIKey()
    }

    @Test func hasAPIKey() {
        // Bundle-Injection (Secrets.xcconfig) kann im Test-Target aktiv sein
        let bundleKey = Bundle.main.infoDictionary?["ClaudeAPIKey"] as? String
        let hasBundleKey = bundleKey.map { !$0.isEmpty && !$0.hasPrefix("$(") } ?? false

        KeychainHelper.deleteAPIKey()
        if !hasBundleKey {
            #expect(!KeychainHelper.hasAPIKey)
        }

        KeychainHelper.saveAPIKey("test-key")
        #expect(KeychainHelper.hasAPIKey)
        KeychainHelper.deleteAPIKey()
    }

    @Test func maskedAPIKey() {
        KeychainHelper.deleteAPIKey()
        KeychainHelper.saveAPIKey("sk-ant-api03-abcdefghij1234")
        let masked = KeychainHelper.maskedAPIKey
        #expect(masked != nil)
        #expect(masked?.hasSuffix("1234") == true)
        #expect(masked?.contains("sk-ant") == false)
        KeychainHelper.deleteAPIKey()
    }

    @Test func overwriteExistingKey() {
        KeychainHelper.deleteAPIKey()
        KeychainHelper.saveAPIKey("old-key")
        KeychainHelper.saveAPIKey("new-key")
        #expect(KeychainHelper.loadAPIKey() == "new-key")
        KeychainHelper.deleteAPIKey()
    }
}

// MARK: - Diktat-Uebernahme (Issue #75)

/// Der Erkenner meldet sich beim Abschluss noch einmal ohne Inhalt. Frueher landete
/// dieses Leerergebnis im Eingabefeld und das Diktat war weg.
struct DictationMergeTests {

    @Test func transcriptFillsEmptyField() {
        #expect(DictationService.merged(existing: "", transcript: "zwei Eier") == "zwei Eier")
    }

    @Test func transcriptIsAppendedToTypedText() {
        #expect(DictationService.merged(existing: "Rührei", transcript: "mit Speck") == "Rührei mit Speck")
    }

    @Test func emptyTranscriptKeepsTypedText() {
        #expect(DictationService.merged(existing: "Rührei", transcript: "") == "Rührei")
    }

    @Test func whitespaceTranscriptKeepsTypedText() {
        #expect(DictationService.merged(existing: "Rührei", transcript: "   \n") == "Rührei")
    }

    @Test func emptyTranscriptOnEmptyFieldStaysEmpty() {
        #expect(DictationService.merged(existing: "", transcript: "") == "")
    }
}

// MARK: - Kaffee-Buchung (DayRecord)

/// Tassen und Koffein muessen zusammenpassen, egal ueber welchen Weg gebucht wird
/// (App-Knopf, Siri `LogCoffeeIntent`, Kurzbefehl).
struct DayRecordCoffeeTests {

    @Test func bookingCupsAddsCaffeine() {
        let record = DayRecord(date: Date())
        let delta = record.bookCoffee(cups: 2, caffeineMgPerCup: 95)

        #expect(record.coffeeCups == 2)
        #expect(record.caffeineMg == 190)
        #expect(delta == 190)
    }

    @Test func negativeCupsTakeBookingBack() {
        let record = DayRecord(date: Date())
        record.bookCoffee(cups: 3, caffeineMgPerCup: 100)
        let delta = record.bookCoffee(cups: -1, caffeineMgPerCup: 100)

        #expect(record.coffeeCups == 2)
        #expect(record.caffeineMg == 200)
        #expect(delta == -100)
    }

    /// Nur so viel zuruecknehmen, wie da war: sonst zieht HealthKit Koffein ab,
    /// das der Tag nie hatte.
    @Test func takingBackStopsAtZero() {
        let record = DayRecord(date: Date())
        record.bookCoffee(cups: 1, caffeineMgPerCup: 95)
        let delta = record.bookCoffee(cups: -5, caffeineMgPerCup: 95)

        #expect(record.coffeeCups == 0)
        #expect(record.caffeineMg == 0)
        #expect(delta == -95)
    }

    @Test func bookingNothingChangesNothing() {
        let record = DayRecord(date: Date())
        let delta = record.bookCoffee(cups: -1, caffeineMgPerCup: 95)

        #expect(record.coffeeCups == 0)
        #expect(delta == 0)
        #expect(record.caffeineMg == nil)
    }

    @Test func settingCupsRecalculatesCaffeine() {
        let record = DayRecord(date: Date())
        record.bookCoffee(cups: 4, caffeineMgPerCup: 95)
        record.setCoffeeCups(2, caffeineMgPerCup: 95)

        #expect(record.coffeeCups == 2)
        #expect(record.caffeineMg == 190)
    }

    @Test func settingNegativeCupsClampsToZero() {
        let record = DayRecord(date: Date())
        record.setCoffeeCups(-3, caffeineMgPerCup: 95)

        #expect(record.coffeeCups == 0)
        #expect(record.caffeineMg == 0)
    }
}

// MARK: - Siri-Snippet: angebotene Mahlzeiten (Issue #78)

struct FocusLogSnippetMealsTests {

    /// Ohne Nebenmahlzeit bleiben es die vier Hauptmahlzeiten.
    @Test func primaryMealsOnly() {
        let meals = FocusLogSnippetView.selectableMeals(current: .lunch)
        #expect(meals == [.breakfast, .lunch, .dinner, .snack])
    }

    /// Eine Buchung um 16 Uhr landet in der Kaffeepause. Fehlt sie in der Leiste,
    /// ist weder erkennbar wohin gebucht wurde, noch gibt es einen Rueckweg.
    @Test func currentSideMealIsOffered() {
        let meals = FocusLogSnippetView.selectableMeals(current: .coffeeBreak)
        #expect(meals.contains(.coffeeBreak))
        #expect(meals == [.breakfast, .lunch, .coffeeBreak, .dinner, .snack])
    }

    @Test func secondBreakfastIsOfferedWhenCurrent() {
        let meals = FocusLogSnippetView.selectableMeals(current: .secondBreakfast)
        #expect(meals == [.breakfast, .secondBreakfast, .lunch, .dinner, .snack])
    }

    /// Nach dem Zuruecknehmen gibt es keine aktuelle Mahlzeit mehr.
    @Test func noCurrentMealKeepsPrimaries() {
        #expect(FocusLogSnippetView.selectableMeals(current: nil) == [.breakfast, .lunch, .dinner, .snack])
    }
}

// MARK: - CoffeeStreakCalculator Tests

/// Das Tageslimit ist eine **Obergrenze**: ein Tag zaehlt, solange hoechstens `goal`
/// Tassen getrunken wurden — auch bei null. Erst darueber reisst die Serie (Issue #77).
struct CoffeeStreakCalculatorTests {

    private let calendar = Calendar(identifier: .gregorian)
    private let today = Calendar(identifier: .gregorian).startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: today)!
    }

    private func counts(_ pairs: [(Int, Int)]) -> [CoffeeStreakCalculator.DailyCount] {
        pairs.map { CoffeeStreakCalculator.DailyCount(date: day($0.0), cups: $0.1) }
    }

    /// Ohne einen einzigen Datensatz gibt es keinen Zeitraum, ueber den gezaehlt
    /// werden koennte — und der Rueckwaertslauf braucht diese Grenze, sonst liefe er
    /// ins Unendliche (jeder Tag ohne Kaffee gilt als gehalten).
    @Test func emptyCountsReturnsZero() {
        let streak = CoffeeStreakCalculator.currentStreak(counts: [], goal: 3, today: today, calendar: calendar)
        #expect(streak == 0)
    }

    @Test func stayingUnderTheLimitKeepsTheStreak() {
        let streak = CoffeeStreakCalculator.currentStreak(
            counts: counts([(0, 1), (-1, 0), (-2, 3)]),
            goal: 3, today: today, calendar: calendar
        )
        #expect(streak == 3)
    }

    /// Der Kern der Umstellung: ein kaffeefreier Tag ist der beste Tag, nicht der,
    /// der die Serie kostet.
    @Test func aDayWithoutCoffeeCounts() {
        let streak = CoffeeStreakCalculator.currentStreak(
            counts: counts([(0, 0), (-1, 0), (-2, 0)]),
            goal: 6, today: today, calendar: calendar
        )
        #expect(streak == 3)
    }

    @Test func exactlyTheLimitStillCounts() {
        let streak = CoffeeStreakCalculator.currentStreak(
            counts: counts([(0, 6), (-1, 6)]),
            goal: 6, today: today, calendar: calendar
        )
        #expect(streak == 2)
    }

    @Test func oneCupOverTheLimitEndsIt() {
        let streak = CoffeeStreakCalculator.currentStreak(
            counts: counts([(0, 7), (-1, 2), (-2, 2)]),
            goal: 6, today: today, calendar: calendar
        )
        #expect(streak == 0)
    }

    @Test func theStreakStopsAtTheDayOverTheLimit() {
        let streak = CoffeeStreakCalculator.currentStreak(
            counts: counts([(0, 2), (-1, 2), (-2, 9), (-3, 1)]),
            goal: 6, today: today, calendar: calendar
        )
        #expect(streak == 2)
    }

    /// Ein Tag ohne Datensatz ist ein Tag ohne Kaffee. Frueher riss die Serie dort ab.
    @Test func aDayWithoutRecordDoesNotBreakTheStreak() {
        let streak = CoffeeStreakCalculator.currentStreak(
            counts: counts([(0, 2), (-2, 2)]),
            goal: 6, today: today, calendar: calendar
        )
        #expect(streak == 3)
    }

    /// Weiter zurueck als bis zum aeltesten bekannten Tag wird nicht gezaehlt.
    @Test func theStreakEndsAtTheOldestRecord() {
        let streak = CoffeeStreakCalculator.currentStreak(
            counts: counts([(-4, 1)]),
            goal: 6, today: today, calendar: calendar
        )
        #expect(streak == 5)
    }

    /// Limit 0 heisst: gar kein Kaffee. Wer trinkt, verliert die Serie.
    @Test func zeroLimitAllowsNoCoffee() {
        #expect(CoffeeStreakCalculator.currentStreak(
            counts: counts([(0, 0), (-1, 0)]), goal: 0, today: today, calendar: calendar
        ) == 2)
        #expect(CoffeeStreakCalculator.currentStreak(
            counts: counts([(0, 1)]), goal: 0, today: today, calendar: calendar
        ) == 0)
    }

    @Test func longestStreakAcrossHistory() {
        // -10 bis -8 gehalten, -7 darueber, -6 bis -5 wieder gehalten
        let longest = CoffeeStreakCalculator.longestStreak(
            counts: counts([(-10, 3), (-9, 1), (-8, 3), (-7, 9), (-6, 3), (-5, 0)]),
            goal: 3, calendar: calendar
        )
        #expect(longest == 3)
    }

    /// Auch in der Historie zaehlen Luecken als kaffeefreie Tage mit.
    @Test func longestStreakCountsGapsAsHeld() {
        let longest = CoffeeStreakCalculator.longestStreak(
            counts: counts([(-5, 2), (-2, 2)]),
            goal: 6, calendar: calendar
        )
        #expect(longest == 4)
    }

    /// Am Wochenende gilt das hoehere Limit — dieselbe Tassenzahl kann werktags
    /// darueber und am Wochenende darunter liegen.
    @Test func perDayLimitRespectsWeekendBonus() {
        let friday = Date(timeIntervalSince1970: 1_700_179_200)   // Fr 2023-11-17
        let cal = Calendar(identifier: .gregorian)
        let goalForDay: (Date) -> Int = { date in
            let wd = cal.component(.weekday, from: date)
            return (wd == 6 || wd == 7 || wd == 1) ? 6 : 4
        }

        let werte = [(0, 6), (-1, 4), (-2, 5)]   // Fr: 6/6 ✓, Do: 4/4 ✓, Mi: 5/4 ✗
        let streak = CoffeeStreakCalculator.currentStreak(
            counts: werte.map {
                CoffeeStreakCalculator.DailyCount(
                    date: cal.date(byAdding: .day, value: $0.0, to: friday)!,
                    cups: $0.1
                )
            },
            goalForDay: goalForDay,
            today: friday,
            calendar: cal
        )
        #expect(streak == 2)
    }
}

// MARK: - FocusBooking Tests

/// `FocusBooking.book` ist der einzige Buchungspfad fuer Fokus-Modus, KI-Schnelleingabe
/// im Menubar-Popover und `AIQuickAddIntent`. Frueher hatte jeder Aufrufer seine eigene
/// Kopie — dabei gingen je nach Weg Zucker/gesaettigte Fette/Salz verloren.
@MainActor
struct FocusBookingTests {

    /// Baut einen leeren In-Memory-Store fuer die beteiligten Modelle.
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: FoodItem.self, DiaryEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func makeEstimate(name: String = "Apfel", grams: Double = 180) throws -> AIFoodEstimate {
        let json = """
        {
            "name": "\(name)",
            "confidence": "high",
            "estimatedWeightGrams": \(grams),
            "caloriesPer100g": 52,
            "proteinPer100g": 0.3,
            "carbsPer100g": 14,
            "fatPer100g": 0.2,
            "fiberPer100g": 2.4,
            "sugarPer100g": 10.4,
            "saturatedFatPer100g": 0.1,
            "saltPer100g": 0.02,
            "totalCalories": 94,
            "components": []
        }
        """
        return try JSONDecoder().decode(AIFoodEstimate.self, from: Data(json.utf8))
    }

    @Test func bookuebernimmtAlleNaehrwerte() throws {
        let context = try makeContext()
        let entry = FocusBooking.book(
            estimate: try makeEstimate(), meal: .breakfast, date: Date(), context: context
        )

        let food = try #require(entry.foodItem)
        #expect(food.name == "Apfel")
        #expect(food.caloriesPer100g == 52)
        // Diese drei gingen ueber AIQuickAddIntent frueher verloren
        #expect(food.sugarPer100g == 10.4)
        #expect(food.saturatedFatPer100g == 0.1)
        #expect(food.saltPer100g == 0.02)
    }

    @Test func bookMarkiertAlsSchnelleintrag() throws {
        let context = try makeContext()
        let entry = FocusBooking.book(
            estimate: try makeEstimate(), meal: .lunch, date: Date(), context: context
        )

        let food = try #require(entry.foodItem)
        // isQuickEntry und isUserCreated sind gegensaetzlich gemeint: ein Schnelleintrag
        // ist gerade kein dauerhaft gespeichertes Nutzerprodukt.
        #expect(food.isQuickEntry)
        #expect(!food.isUserCreated)
        #expect(entry.mealType == .lunch)
    }

    /// Unsaubere KI-Antworten (leerer Name, 0 Gramm) duerfen keinen unbrauchbaren
    /// Eintrag erzeugen.
    @Test func bookBereinigtUnsaubereSchaetzung() throws {
        let context = try makeContext()
        let entry = FocusBooking.book(
            estimate: try makeEstimate(name: "   ", grams: 0),
            meal: .snack, date: Date(), context: context
        )

        let food = try #require(entry.foodItem)
        #expect(!food.name.trimmingCharacters(in: .whitespaces).isEmpty)
        #expect(entry.amountGrams >= 1)
    }

    // MARK: - Rueckgaengig und Umbuchen (Siri-Snippet, Issue #74)

    @Test func undoLoeschtEintraegeUndSchnellLebensmittel() throws {
        let context = try makeContext()
        let entries = try (1...2).map { i in
            FocusBooking.book(
                estimate: try makeEstimate(name: "Speise \(i)"),
                meal: .dinner, date: Date(), context: context
            )
        }

        let geloescht = FocusBooking.undo(
            entryIds: entries.map(\.entryId),
            foodItemIds: entries.compactMap { $0.foodItem?.itemId },
            context: context
        )

        #expect(geloescht == 2)
        #expect(try context.fetch(FetchDescriptor<DiaryEntry>()).isEmpty)
        // Die Schnell-Lebensmittel muessen mitgehen, sonst bleibt Datenmuell zurueck
        #expect(try context.fetch(FetchDescriptor<FoodItem>()).isEmpty)
    }

    /// Das Snippet wird mehrfach ausgefuehrt: ein zweiter Tipp auf Rueckgaengig
    /// darf nicht scheitern und nichts Fremdes loeschen.
    @Test func undoIstWiederholbar() throws {
        let context = try makeContext()
        let entry = FocusBooking.book(
            estimate: try makeEstimate(), meal: .snack, date: Date(), context: context
        )
        let ids = [entry.entryId]
        let foodIds = [entry.foodItem?.itemId].compactMap { $0 }

        #expect(FocusBooking.undo(entryIds: ids, foodItemIds: foodIds, context: context) == 1)
        #expect(FocusBooking.undo(entryIds: ids, foodItemIds: foodIds, context: context) == 0)
    }

    @Test func moveOrdnetEineAndereMahlzeitZu() throws {
        let context = try makeContext()
        let entry = FocusBooking.book(
            estimate: try makeEstimate(), meal: .snack, date: Date(), context: context
        )

        let geaendert = FocusBooking.move(entryIds: [entry.entryId], to: .breakfast, context: context)

        #expect(geaendert == 1)
        #expect(entry.mealType == .breakfast)
    }

    @Test func entriesLiefertNachRueckgaengigNichtsMehr() throws {
        let context = try makeContext()
        let entry = FocusBooking.book(
            estimate: try makeEstimate(), meal: .lunch, date: Date(), context: context
        )
        let ids = [entry.entryId]

        #expect(FocusBooking.entries(with: ids, context: context).count == 1)
        FocusBooking.undo(entryIds: ids, foodItemIds: [], context: context)
        // Das Snippet zeigt danach "Zurueckgenommen" statt einer leeren Liste
        #expect(FocusBooking.entries(with: ids, context: context).isEmpty)
    }

    @Test func leereIdListeAendertNichts() throws {
        let context = try makeContext()
        FocusBooking.book(estimate: try makeEstimate(), meal: .lunch, date: Date(), context: context)

        #expect(FocusBooking.undo(entryIds: [], foodItemIds: [], context: context) == 0)
        #expect(FocusBooking.move(entryIds: [], to: .dinner, context: context) == 0)
        #expect(try context.fetch(FetchDescriptor<DiaryEntry>()).count == 1)
    }
}

// MARK: - Hebel-Tests

/// Der Hebel bringt die Metabotschaft aus dem OKR-Check-In an den Point of
/// Decision. Zwei Invarianten sind kritisch: es gibt immer genau einen aktiven
/// Hebel, und unbeantwortete Tage schoenen die Adhaerenz nicht.
@MainActor
struct FocusLeverTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: FocusLever.self, FocusLeverCheck.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func date(_ hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    }

    // MARK: Trigger

    @Test func triggerGreiftAbDerEingestelltenStunde() throws {
        let lever = FocusLever(text: "Nuesse abwiegen", triggerStartHour: 20)

        #expect(FocusLeverTrigger.isHighlighted(lever: lever, now: date(19)) == false)
        #expect(FocusLeverTrigger.isHighlighted(lever: lever, now: date(20)))
        #expect(FocusLeverTrigger.isHighlighted(lever: lever, now: date(23)))
    }

    @Test func snackHebtUnabhaengigVonDerUhrzeitHervor() throws {
        let lever = FocusLever(text: "Nuesse abwiegen", triggerStartHour: 20, triggerOnSnack: true)

        #expect(FocusLeverTrigger.isHighlighted(lever: lever, now: date(14), lastBookedMeal: .snack))
        #expect(FocusLeverTrigger.isHighlighted(lever: lever, now: date(14), lastBookedMeal: .dinner))
        // Mittagessen ist keine Situation fuer diesen Hebel
        #expect(FocusLeverTrigger.isHighlighted(lever: lever, now: date(14), lastBookedMeal: .lunch) == false)
    }

    @Test func snackTriggerLaesstSichAbschalten() throws {
        let lever = FocusLever(text: "Nuesse abwiegen", triggerStartHour: 20, triggerOnSnack: false)
        #expect(FocusLeverTrigger.isHighlighted(lever: lever, now: date(14), lastBookedMeal: .snack) == false)
    }

    @Test func stundeNullBedeutetImmerHervorheben() throws {
        let lever = FocusLever(text: "Nuesse abwiegen", triggerStartHour: 0)
        #expect(FocusLeverTrigger.isHighlighted(lever: lever, now: date(3)))
    }

    // MARK: Invariante "genau eine aktive"

    @Test func setActiveLoestDieVorigeAb() throws {
        let context = try makeContext()

        let first = FocusLever.setActive(text: "Erste", in: context)
        let second = FocusLever.setActive(text: "Zweite", in: context)

        #expect(first.retiredAt != nil)
        #expect(second.retiredAt == nil)
        #expect(FocusLever.active(in: context)?.text == "Zweite")
        #expect(FocusLever.history(in: context).map(\.text) == ["Erste"])
    }

    @Test func mehrereAktiveLieferndenJuengstenDatensatz() throws {
        let context = try makeContext()

        // CloudKit kann pro Geraet einen aktiven Datensatz einspielen
        let older = FocusLever(text: "Alt")
        older.createdAt = Date().addingTimeInterval(-3600)
        let newer = FocusLever(text: "Neu")
        context.insert(older)
        context.insert(newer)
        try context.save()

        #expect(FocusLever.active(in: context)?.text == "Neu")
    }

    @Test func leverOnLiefertDenAmTagGueltigenHebel() throws {
        let context = try makeContext()
        let cal = Calendar.current
        let today = Date().startOfDay
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: today)! }

        // Alter Hebel: vor 5 Tagen gesetzt, vor 2 Tagen abgeloest
        let old = FocusLever(text: "Alt")
        old.createdAt = day(-5)
        old.retiredAt = day(-2)
        // Neuer Hebel: vor 2 Tagen gesetzt, noch aktiv
        let new = FocusLever(text: "Neu")
        new.createdAt = day(-2)
        context.insert(old)
        context.insert(new)
        try context.save()

        #expect(FocusLever.lever(on: day(-6), in: context) == nil)         // vor der Erstellung
        #expect(FocusLever.lever(on: day(-3), in: context)?.text == "Alt") // im alten Zeitraum
        #expect(FocusLever.lever(on: day(-2), in: context)?.text == "Neu") // Wechseltag: juengerer gewinnt
        #expect(FocusLever.lever(on: today, in: context)?.text == "Neu")   // heute
    }

    // MARK: Rueckmeldung

    @Test func rueckmeldungWirdProTagNurEinmalAngelegt() throws {
        let context = try makeContext()
        let lever = FocusLever.setActive(text: "Nuesse abwiegen", in: context)
        let today = Date()

        lever.recordCheck(kept: true, for: today, in: context)
        lever.recordCheck(kept: false, for: today, in: context)

        #expect(lever.sortedChecks.count == 1)
        #expect(lever.check(for: today)?.kept == false)
    }

    // MARK: Adhaerenz

    @Test func unbeantworteteTageZaehlenNichtAlsGehalten() throws {
        let context = try makeContext()
        let lever = FocusLever.setActive(text: "Nuesse abwiegen", in: context)
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -6, to: Date().startOfDay)!

        // Vier gehaltene, ein verfehlter, zwei unbeantwortete Tage
        for offset in 0..<4 {
            lever.recordCheck(kept: true, for: calendar.date(byAdding: .day, value: offset, to: start)!, in: context)
        }
        lever.recordCheck(kept: false, for: calendar.date(byAdding: .day, value: 4, to: start)!, in: context)

        let adherence = FocusLeverAdherence.evaluate(checks: lever.checks ?? [], start: start, days: 7)

        #expect(adherence.kept == 4)
        #expect(adherence.missed == 1)
        #expect(adherence.unanswered == 2)
        #expect(adherence.totalDays == 7)
        #expect(abs(adherence.rate - 4.0 / 7.0) < 0.0001)
    }

    @Test func rueckmeldungenAusserhalbDesZeitraumsZaehlenNicht() throws {
        let context = try makeContext()
        let lever = FocusLever.setActive(text: "Nuesse abwiegen", in: context)
        let calendar = Calendar.current
        let start = Date().startOfDay

        lever.recordCheck(kept: true, for: calendar.date(byAdding: .day, value: -5, to: start)!, in: context)

        let adherence = FocusLeverAdherence.evaluate(checks: lever.checks ?? [], start: start, days: 3)
        #expect(adherence.kept == 0)
        #expect(adherence.unanswered == 3)
    }
}

// MARK: - UserProfile: kanonisches Profil und Duplikate

/// Absicherung gegen den Datenverlust aus Issue #63: ein leeres Default-Profil
/// darf ein Profil mit echten Werten niemals verdraengen, und Lesepfade duerfen
/// waehrend eines laufenden CloudKit-Imports nichts loeschen.
@MainActor
struct UserProfileCanonicalTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// Legt ein Profil mit echten Nutzerwerten an.
    @discardableResult
    private func insertEchtesProfil(
        in context: ModelContext,
        createdAt: Date,
        updatedAt: Date,
        bodyWeightKg: Double = 89.9
    ) -> UserProfile {
        let profile = UserProfile(dailyCalorieGoal: 2225)
        profile.bodyWeightKg = bodyWeightKg
        profile.heightCm = 187
        profile.age = 59
        profile.weightGoalKg = 86
        profile.createdAt = createdAt
        profile.updatedAt = updatedAt
        context.insert(profile)
        return profile
    }

    @Test func keinProfilLiefertNil() throws {
        let context = try makeContext()
        #expect(UserProfile.existing(in: context) == nil)
    }

    @Test func frischesProfilIstPristineDefault() throws {
        let profile = UserProfile()
        #expect(profile.isPristineDefault)

        profile.bodyWeightKg = 89.9
        #expect(!profile.isPristineDefault)
    }

    /// Der Kern des Fehlers: das Default-Profil wurde nach dem Store-Reset
    /// angelegt und hatte damit das neueste `updatedAt`.
    @Test func aelteresEchtesProfilGewinntGegenNeueresDefault() throws {
        let context = try makeContext()
        let jetzt = Date()
        insertEchtesProfil(
            in: context,
            createdAt: jetzt.addingTimeInterval(-86400 * 30),
            updatedAt: jetzt.addingTimeInterval(-86400 * 4)
        )
        let frischesDefault = UserProfile()
        frischesDefault.createdAt = jetzt
        frischesDefault.updatedAt = jetzt
        context.insert(frischesDefault)

        let canonical = try #require(UserProfile.existing(in: context))
        #expect(canonical.bodyWeightKg == 89.9)
        #expect(canonical.dailyCalorieGoal == 2225)
        #expect(canonical.weightGoalKg == 86)
    }

    @Test func lesenLoeschtKeineProfile() throws {
        let context = try makeContext()
        let jetzt = Date()
        insertEchtesProfil(in: context, createdAt: jetzt.addingTimeInterval(-86400), updatedAt: jetzt)
        insertEchtesProfil(
            in: context,
            createdAt: jetzt,
            updatedAt: jetzt,
            bodyWeightKg: 88.0
        )

        _ = UserProfile.existing(in: context)

        let verbleibend = try context.fetch(FetchDescriptor<UserProfile>())
        #expect(verbleibend.count == 2)
    }

    @Test func cleanupBehaeltEchteWerteUndEntferntDuplikate() throws {
        let context = try makeContext()
        let jetzt = Date()
        insertEchtesProfil(
            in: context,
            createdAt: jetzt.addingTimeInterval(-86400 * 30),
            updatedAt: jetzt.addingTimeInterval(-86400 * 4)
        )
        let frischesDefault = UserProfile()
        frischesDefault.createdAt = jetzt
        frischesDefault.updatedAt = jetzt
        context.insert(frischesDefault)

        let canonical = try #require(UserProfile.canonical(in: context))
        #expect(canonical.bodyWeightKg == 89.9)
        // canonical committet bewusst nicht — der Schreibpfad speichert ohnehin.
        try context.save()

        let verbleibend = try context.fetch(FetchDescriptor<UserProfile>())
        #expect(verbleibend.count == 1)
        #expect(verbleibend.first?.bodyWeightKg == 89.9)
    }

    /// Zwei echte Profile von zwei Geraeten: der zuletzt bearbeitete Stand
    /// gewinnt inhaltlich, die Identitaet bleibt beim aelteren Profil.
    @Test func cleanupUebernimmtDenZuletztBearbeitetenStand() throws {
        let context = try makeContext()
        let jetzt = Date()
        let alt = insertEchtesProfil(
            in: context,
            createdAt: jetzt.addingTimeInterval(-86400 * 30),
            updatedAt: jetzt.addingTimeInterval(-86400 * 10)
        )
        let altId = alt.profileId
        insertEchtesProfil(
            in: context,
            createdAt: jetzt.addingTimeInterval(-86400 * 5),
            updatedAt: jetzt,
            bodyWeightKg: 87.4
        )

        let canonical = try #require(UserProfile.canonical(in: context))
        #expect(canonical.profileId == altId)
        #expect(canonical.bodyWeightKg == 87.4)
        try context.save()

        let verbleibend = try context.fetch(FetchDescriptor<UserProfile>())
        #expect(verbleibend.count == 1)
    }
}

// MARK: - DayRecord: Lesepfad und Schreibpfad

/// Absicherung gegen Issue #65: der Anzeigepfad darf weder Records anlegen noch
/// loeschen. Beides propagiert ueber CloudKit auf alle Geraete, und ein
/// Anzeige-Refresh kann waehrend eines laufenden Imports laufen.
@MainActor
struct DayRecordReadWriteTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DayRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @discardableResult
    private func insertRecord(
        in context: ModelContext,
        date: Date,
        recordId: String,
        water: Int = 0,
        coffee: Int = 0,
        steps: Int = 0
    ) -> DayRecord {
        let record = DayRecord(date: date)
        record.recordId = recordId
        record.waterIntakeMl = water
        record.coffeeCups = coffee
        record.steps = steps
        context.insert(record)
        return record
    }

    @Test func lesenLegtKeinenRecordAn() throws {
        let context = try makeContext()
        let heute = Date()

        #expect(DayRecord.existing(in: context, for: heute) == nil)

        try context.save()
        let alle = try context.fetch(FetchDescriptor<DayRecord>())
        #expect(alle.isEmpty)
    }

    @Test func lesenLoeschtKeineDuplikate() throws {
        let context = try makeContext()
        let heute = Date()
        insertRecord(in: context, date: heute, recordId: "b", water: 500)
        insertRecord(in: context, date: heute, recordId: "a", water: 250)
        try context.save()

        _ = DayRecord.existing(in: context, for: heute)

        let alle = try context.fetch(FetchDescriptor<DayRecord>())
        #expect(alle.count == 2)
    }

    /// Ohne stabile Wahl zeigen zwei Geraete verschiedene Zahlen fuer denselben Tag.
    @Test func lesenWaehltStabilDenselbenRecord() throws {
        let context = try makeContext()
        let heute = Date()
        insertRecord(in: context, date: heute, recordId: "c", water: 100)
        insertRecord(in: context, date: heute, recordId: "a", water: 200)
        insertRecord(in: context, date: heute, recordId: "b", water: 300)
        try context.save()

        let ersteWahl = try #require(DayRecord.existing(in: context, for: heute))
        let zweiteWahl = try #require(DayRecord.existing(in: context, for: heute))
        #expect(ersteWahl.recordId == "a")
        #expect(ersteWahl === zweiteWahl)
    }

    @Test func schreibenLegtRecordAn() throws {
        let context = try makeContext()
        let heute = Date()

        let record = DayRecord.canonical(in: context, for: heute)
        record.waterIntakeMl = 250
        try context.save()

        let alle = try context.fetch(FetchDescriptor<DayRecord>())
        #expect(alle.count == 1)
        #expect(alle.first?.waterIntakeMl == 250)
    }

    @Test func schreibenFuehrtDuplikateZusammen() throws {
        let context = try makeContext()
        let heute = Date()
        insertRecord(in: context, date: heute, recordId: "a", water: 250, coffee: 1, steps: 8000)
        insertRecord(in: context, date: heute, recordId: "b", water: 750, coffee: 3, steps: 1200)
        try context.save()

        let record = DayRecord.canonical(in: context, for: heute)
        try context.save()

        #expect(record.recordId == "a")
        #expect(record.waterIntakeMl == 750)
        #expect(record.coffeeCups == 3)
        #expect(record.steps == 8000)

        let alle = try context.fetch(FetchDescriptor<DayRecord>())
        #expect(alle.count == 1)
    }

    @Test func schreibenTrenntDieTageSauber() throws {
        let context = try makeContext()
        let heute = Date().startOfDay
        let gestern = Calendar.current.date(byAdding: .day, value: -1, to: heute)!
        insertRecord(in: context, date: gestern, recordId: "a", water: 999)
        try context.save()

        let record = DayRecord.canonical(in: context, for: heute)
        record.waterIntakeMl = 100
        try context.save()

        let alle = try context.fetch(FetchDescriptor<DayRecord>())
        #expect(alle.count == 2)
        #expect(DayRecord.existing(in: context, for: gestern)?.waterIntakeMl == 999)
        #expect(DayRecord.existing(in: context, for: heute)?.waterIntakeMl == 100)
    }

    @Test func leereHealthKitWerteRechtfertigenKeinenRecord() {
        #expect(DayRecord.Metrics().hasData == false)
        #expect(DayRecord.Metrics(steps: 1200).hasData)
        #expect(DayRecord.Metrics(weight: 89.9).hasData)
        #expect(DayRecord.Metrics(activeEnergyKcal: 300).hasData)
    }

    /// Ein HealthKit-Tag ohne Gewicht oder Wasser darf manuell erfasste Werte
    /// nicht ueberschreiben.
    @Test func metricsUeberschreibenKeineManuellenWerte() throws {
        let context = try makeContext()
        let record = insertRecord(in: context, date: Date(), recordId: "a", water: 1500)
        record.weight = 88.5

        DayRecord.Metrics(steps: 9000, activeEnergyKcal: 420).apply(to: record)

        #expect(record.steps == 9000)
        #expect(record.activeEnergyKcal == 420)
        #expect(record.waterIntakeMl == 1500)
        #expect(record.weight == 88.5)
    }
}

// MARK: - Zeitraeume: Tage zaehlen, nicht Zeilen

/// Absicherung gegen Issue #67: bei CloudKit-Duplikaten hat jede Auswertung ueber
/// mehrere Tage Zeilen gezaehlt statt Tage. Drei Duplikate eines Tages erfuellten
/// damit eine Bedingung wie „mindestens drei Tage", und die Gewichtskurve bekam
/// pro Geraet einen Punkt.
@MainActor
struct DayFoldingTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DayRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @discardableResult
    private func insert(
        in context: ModelContext,
        daysAgo: Int,
        recordId: String,
        steps: Int = 0,
        water: Int = 0,
        active: Int = 0,
        weight: Double? = nil
    ) -> DayRecord {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date().startOfDay)!
        let record = DayRecord(date: date)
        record.recordId = recordId
        record.steps = steps
        record.waterIntakeMl = water
        record.activeEnergyKcal = active
        record.weight = weight
        context.insert(record)
        return record
    }

    @Test func duplikateEinesTagesErgebenEinenTag() throws {
        let context = try makeContext()
        insert(in: context, daysAgo: 1, recordId: "a", steps: 8000, active: 400)
        insert(in: context, daysAgo: 1, recordId: "b", steps: 1200, active: 150)
        insert(in: context, daysAgo: 1, recordId: "c", steps: 300, active: 90)
        try context.save()

        let days = DayRecord.days(in: context, from: Date().addingDays(-7), to: Date())
        #expect(days.count == 1)
        #expect(days.first?.steps == 8000)
        #expect(days.first?.activeEnergyKcal == 400)
    }

    @Test func tageWerdenAufsteigendGeliefert() throws {
        let context = try makeContext()
        insert(in: context, daysAgo: 1, recordId: "a", steps: 100)
        insert(in: context, daysAgo: 3, recordId: "b", steps: 300)
        insert(in: context, daysAgo: 2, recordId: "c", steps: 200)
        try context.save()

        let days = DayRecord.days(in: context, from: Date().addingDays(-7), to: Date())
        #expect(days.map(\.steps) == [300, 200, 100])
    }

    @Test func gewichtsverlaufHatEinenPunktJeTag() throws {
        let context = try makeContext()
        insert(in: context, daysAgo: 2, recordId: "a", weight: 89.9)
        insert(in: context, daysAgo: 2, recordId: "b", weight: 90.4)
        insert(in: context, daysAgo: 1, recordId: "c", weight: 89.5)
        try context.save()

        let mitGewicht = DayRecord.days(in: context, from: Date().addingDays(-7), to: Date())
            .compactMap(\.weight)
        #expect(mitGewicht.count == 2)
    }

    /// Ohne Sortierung in `folding` haengt das Ergebnis an der Fetch-Reihenfolge:
    /// zwei Geraete zeigten verschiedene Gewichte, und die Bereinigung loeschte je
    /// nach Geraet einen anderen Wert dauerhaft.
    @Test func optionaleFelderWerdenDeterministischGefaltet() throws {
        let context = try makeContext()
        let heute = Date().startOfDay

        let a = DayRecord(date: heute); a.recordId = "a"; a.weight = 89.9
        let b = DayRecord(date: heute); b.recordId = "b"; b.weight = 95.0
        context.insert(b)
        context.insert(a)
        try context.save()

        let vorwaerts = try #require(DayRecord.Day.folding([a, b]))
        let rueckwaerts = try #require(DayRecord.Day.folding([b, a]))
        #expect(vorwaerts.weight == 89.9)
        #expect(vorwaerts == rueckwaerts)
    }

    @Test func faltungLaesstDenBestandUnberuehrt() throws {
        let context = try makeContext()
        insert(in: context, daysAgo: 1, recordId: "a", steps: 8000)
        insert(in: context, daysAgo: 1, recordId: "b", steps: 1200)
        try context.save()

        _ = DayRecord.days(in: context, from: Date().addingDays(-7), to: Date())

        #expect(try context.fetch(FetchDescriptor<DayRecord>()).count == 2)
    }
}

// MARK: - Tagesrueckmeldung zum Hebel bei Duplikaten

/// Absicherung gegen Issue #67: antworten zwei Geraete am selben Tag, lieferte
/// `.first` eine willkuerliche Antwort. Die Adhaerenz-Quote geht ueber die CLI in
/// die Wochenroutine, eine schwankende Zahl waere dort still falsch.
@MainActor
struct FocusLeverCheckCanonicalTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: FocusLever.self, FocusLeverCheck.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @discardableResult
    private func insertCheck(
        in context: ModelContext,
        lever: FocusLever,
        date: Date,
        kept: Bool,
        checkId: String,
        answeredAt: Date
    ) -> FocusLeverCheck {
        let check = FocusLeverCheck(date: date, kept: kept)
        check.checkId = checkId
        check.answeredAt = answeredAt
        check.lever = lever
        context.insert(check)
        return check
    }

    @Test func zuletztGegebeneAntwortGilt() throws {
        let context = try makeContext()
        let lever = FocusLever.setActive(text: "Nach 20 Uhr nichts mehr", in: context)
        let heute = Date().startOfDay

        insertCheck(in: context, lever: lever, date: heute, kept: true,
                    checkId: "a", answeredAt: heute.addingTimeInterval(3600))
        insertCheck(in: context, lever: lever, date: heute, kept: false,
                    checkId: "b", answeredAt: heute.addingTimeInterval(7200))
        try context.save()

        #expect(lever.check(for: heute)?.kept == false)
    }

    @Test func beiGleicherAntwortzeitEntscheidetDieId() throws {
        let context = try makeContext()
        let lever = FocusLever.setActive(text: "Nuesse abwiegen", in: context)
        let heute = Date().startOfDay
        let gleich = heute.addingTimeInterval(3600)

        insertCheck(in: context, lever: lever, date: heute, kept: true, checkId: "b", answeredAt: gleich)
        insertCheck(in: context, lever: lever, date: heute, kept: false, checkId: "a", answeredAt: gleich)
        try context.save()

        let ersteWahl = lever.check(for: heute)
        let zweiteWahl = lever.check(for: heute)
        #expect(ersteWahl?.checkId == "a")
        #expect(ersteWahl === zweiteWahl)
    }

    @Test func adhaerenzZaehltEinenTagEinmal() throws {
        let context = try makeContext()
        let lever = FocusLever.setActive(text: "Kein Snack nach dem Abendessen", in: context)
        let start = Date().startOfDay

        insertCheck(in: context, lever: lever, date: start, kept: true,
                    checkId: "a", answeredAt: start.addingTimeInterval(60))
        insertCheck(in: context, lever: lever, date: start, kept: true,
                    checkId: "b", answeredAt: start.addingTimeInterval(120))
        try context.save()

        let adherence = FocusLeverAdherence.evaluate(checks: lever.checks ?? [], start: start, days: 3)
        #expect(adherence.kept == 1)
        #expect(adherence.unanswered == 2)
        #expect(adherence.totalDays == 3)
    }

    @Test func korrekturRaeumtDuplikateDesTagesAb() throws {
        let context = try makeContext()
        let lever = FocusLever.setActive(text: "Wasser vor dem Essen", in: context)
        let heute = Date().startOfDay

        insertCheck(in: context, lever: lever, date: heute, kept: true,
                    checkId: "a", answeredAt: heute.addingTimeInterval(60))
        insertCheck(in: context, lever: lever, date: heute, kept: false,
                    checkId: "b", answeredAt: heute.addingTimeInterval(120))
        try context.save()

        lever.recordCheck(kept: true, for: heute, in: context)

        let verbleibend = try context.fetch(FetchDescriptor<FocusLeverCheck>())
        #expect(verbleibend.count == 1)
        #expect(verbleibend.first?.kept == true)
    }
}

// MARK: - Bereinigung nach CloudKit-Import

/// Issue #67: Duplikate werden dort bereinigt, wo sie entstehen — nach einem
/// abgeschlossenen Import — statt verteilt ueber alle Schreibpfade. Vergangene
/// Tage wurden vorher nie aufgeraeumt.
@MainActor
struct DuplicateCleanupTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DayRecord.self, UserProfile.self, FocusLever.self, FocusLeverCheck.self,
                PlannedEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func vergangeneTageWerdenZusammengefuehrt() throws {
        let context = try makeContext()
        let vorWochen = Calendar.current.date(byAdding: .day, value: -30, to: Date().startOfDay)!

        for (id, steps, water) in [("a", 9000, 250), ("b", 1000, 2000)] {
            let record = DayRecord(date: vorWochen)
            record.recordId = id
            record.steps = steps
            record.waterIntakeMl = water
            context.insert(record)
        }
        try context.save()

        let entfernt = DuplicateCleanup.run(in: context)

        #expect(entfernt == 1)
        let verbleibend = try context.fetch(FetchDescriptor<DayRecord>())
        #expect(verbleibend.count == 1)
        #expect(verbleibend.first?.steps == 9000)
        #expect(verbleibend.first?.waterIntakeMl == 2000)
    }

    @Test func echtesProfilUeberlebtGegenDefault() throws {
        let context = try makeContext()
        let jetzt = Date()

        let echt = UserProfile(dailyCalorieGoal: 2225)
        echt.bodyWeightKg = 89.9
        echt.createdAt = jetzt.addingTimeInterval(-86400 * 30)
        echt.updatedAt = jetzt.addingTimeInterval(-86400 * 4)
        context.insert(echt)

        let frisch = UserProfile()
        frisch.createdAt = jetzt
        frisch.updatedAt = jetzt
        context.insert(frisch)
        try context.save()

        DuplicateCleanup.run(in: context)

        let verbleibend = try context.fetch(FetchDescriptor<UserProfile>())
        #expect(verbleibend.count == 1)
        #expect(verbleibend.first?.bodyWeightKg == 89.9)
    }

    @Test func ohneDuplikateAendertSichNichts() throws {
        let context = try makeContext()
        let record = DayRecord(date: Date())
        record.waterIntakeMl = 500
        context.insert(record)
        let profile = UserProfile()
        context.insert(profile)
        try context.save()

        #expect(DuplicateCleanup.run(in: context) == 0)
        #expect(try context.fetch(FetchDescriptor<DayRecord>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<UserProfile>()).count == 1)
    }
}

// MARK: - Komplikations-Snapshot

/// Absicherung fuer Issue #69: die Komplikation las nur den lokalen Store der Uhr,
/// den ausschliesslich die Watch-App fuellt. Ohne App-Start zeigte sie deshalb den
/// Stand des letzten Besuchs. Jetzt gewinnt der neuere von lokalem und uebertragenem
/// Stand.
struct ComplicationSnapshotTests {

    private func snapshot(
        day: Date = Date(),
        rest: Double = 500,
        wasser: Int = 1000,
        updatedAt: Date
    ) -> ComplicationSnapshot {
        ComplicationSnapshot(
            day: day,
            totalCaloriesConsumed: 2000 - rest,
            effectiveCalorieGoal: 2000,
            remainingCalories: rest,
            waterIntakeMl: wasser,
            waterGoalMl: 2000,
            updatedAt: updatedAt
        )
    }

    @Test func neuererStandGewinnt() {
        let jetzt = Date()
        let lokal = snapshot(rest: 900, updatedAt: jetzt.addingTimeInterval(-3600))
        let empfangen = snapshot(rest: 400, updatedAt: jetzt)

        let gewinner = ComplicationSnapshot.newer(local: lokal, received: empfangen, now: jetzt)
        #expect(gewinner?.remainingCalories == 400)
    }

    /// Hat die Uhr selbst gebucht, ist ihr Stand der frischere.
    @Test func lokalerStandGewinntWennEreuerIst() {
        let jetzt = Date()
        let lokal = snapshot(rest: 300, updatedAt: jetzt)
        let empfangen = snapshot(rest: 800, updatedAt: jetzt.addingTimeInterval(-600))

        let gewinner = ComplicationSnapshot.newer(local: lokal, received: empfangen, now: jetzt)
        #expect(gewinner?.remainingCalories == 300)
    }

    /// Ein Stand von gestern darf die Komplikation nicht beschreiben, egal wie neu
    /// er erhoben wurde.
    @Test func standVonGesternScheidetAus() {
        let jetzt = Date()
        let gestern = Calendar.current.date(byAdding: .day, value: -1, to: jetzt)!
        let alt = snapshot(day: gestern, rest: 100, updatedAt: jetzt)
        let heute = snapshot(day: jetzt, rest: 700, updatedAt: jetzt.addingTimeInterval(-7200))

        let gewinner = ComplicationSnapshot.newer(local: heute, received: alt, now: jetzt)
        #expect(gewinner?.remainingCalories == 700)
    }

    @Test func ohneStandKommtNichtsZurueck() {
        #expect(ComplicationSnapshot.newer(local: nil, received: nil) == nil)
    }

    /// Getrennte Ablage: der empfangene Stand darf den lokalen nicht ueberschreiben,
    /// sonst verloere eine Buchung auf der Uhr gegen ein aelteres iPhone-Paket.
    @Test func beideQuellenLiegenGetrennt() {
        let jetzt = Date()
        let vonDerUhr = snapshot(rest: 300, updatedAt: jetzt)
        let vomTelefon = snapshot(rest: 900, updatedAt: jetzt.addingTimeInterval(-60))

        vonDerUhr.store(as: .local)
        vomTelefon.store(as: .received)

        #expect(ComplicationSnapshot.stored(.local)?.remainingCalories == 300)
        #expect(ComplicationSnapshot.stored(.received)?.remainingCalories == 900)
        #expect(ComplicationSnapshot.newer(
            local: .stored(.local),
            received: .stored(.received),
            now: jetzt
        )?.remainingCalories == 300)
    }

    /// Grundlage der Drosselung: das Kontingent liegt bei rund 50 Uebertragungen pro
    /// Tag, `loadDay` laeuft deutlich oefter.
    @Test func gleicherInhaltZaehltNichtAlsAenderung() {
        let jetzt = Date()
        let a = snapshot(rest: 500, updatedAt: jetzt)
        let b = snapshot(rest: 500, updatedAt: jetzt.addingTimeInterval(120))
        #expect(a.hasSameValues(as: b))

        let c = snapshot(rest: 480, updatedAt: jetzt)
        #expect(!a.hasSameValues(as: c))
    }

    @Test func snapshotUeberstehtKodierung() throws {
        let original = snapshot(rest: 640, wasser: 1750, updatedAt: Date())
        let data = try JSONEncoder().encode(original)
        let zurueck = try JSONDecoder().decode(ComplicationSnapshot.self, from: data)
        #expect(zurueck == original)
    }
}

// MARK: - Mehrere Speisen aus einer Eingabe

/// Absicherung fuer Issue #73: eine gesprochene Eingabe nennt selten nur eine
/// Sache. Frueher wurde alles zu einem Eintrag verschmolzen, aus dem sich nichts
/// mehr einzeln korrigieren liess.
@MainActor
struct MehrereSpeisenTests {

    private func item(_ name: String, kcal: Double = 100) -> String {
        """
        {"name": "\(name)", "confidence": "high", "estimatedWeightGrams": 100,
         "caloriesPer100g": \(kcal), "proteinPer100g": 1, "carbsPer100g": 1,
         "fatPer100g": 1, "fiberPer100g": 0, "sugarPer100g": 0,
         "saturatedFatPer100g": 0, "saltPer100g": 0, "totalCalories": \(kcal),
         "components": []}
        """
    }

    @Test func listeWirdVollstaendigGelesen() throws {
        let json = """
        {"items": [\(item("Rührei mit Speck", kcal: 180)), \(item("Kaffee", kcal: 1))]}
        """
        let estimates = try ClaudeAPIService.shared.parseEstimates(json)

        #expect(estimates.count == 2)
        #expect(estimates.first?.name == "Rührei mit Speck")
        #expect(estimates.last?.name == "Kaffee")
    }

    /// Sprachmodelle halten sich nicht immer ans Format. Ein einzelnes Objekt ist
    /// besser als ein Fehler, der die ganze Eingabe verwirft.
    @Test func einzelnesObjektBleibtLesbar() throws {
        let estimates = try ClaudeAPIService.shared.parseEstimates(item("Lasagne", kcal: 150))

        #expect(estimates.count == 1)
        #expect(estimates.first?.name == "Lasagne")
    }

    @Test func markdownUmschlagStoertNicht() throws {
        let json = """
        ```json
        {"items": [\(item("Apfel"))]}
        ```
        """
        #expect(try ClaudeAPIService.shared.parseEstimates(json).count == 1)
    }

    @Test func leereListeFaelltAufDenEinzelparserZurueck() {
        // {"items": []} ist keine brauchbare Antwort — dann greift der Einzelparser,
        // der hier ebenfalls scheitert und einen Fehler wirft statt still nichts zu buchen.
        #expect(throws: (any Error).self) {
            try ClaudeAPIService.shared.parseEstimates("{\"items\": []}")
        }
    }
}

// MARK: - Wochenleiste (Issue #81)

/// Die Leiste zeigt sieben Tage und unter jedem einen Balken. Getestet wird, was
/// den Balken bestimmt — Laenge und Stufe muessen zum Kalorienring passen, sonst
/// widersprechen sich zwei Anzeigen desselben Tages.
struct WochenleisteTests {

    private func tag(
        _ eaten: Double,
        goal: Int = 2000,
        hasEntries: Bool = true
    ) -> DayViewModel.WeekDay {
        DayViewModel.WeekDay(
            date: Date().startOfDay,
            eatenCalories: eaten,
            calorieGoal: goal,
            hasEntries: hasEntries
        )
    }

    @Test func wocheHatSiebenAufeinanderfolgendeTage() {
        let tage = Date().weekDays

        #expect(tage.count == 7)
        for (index, tag) in tage.enumerated() {
            #expect(tag == tage[0].addingDays(index))
            #expect(tag == tag.startOfDay)
        }
    }

    /// Jeder Tag der Woche liefert dieselbe Woche — sonst spraenge die Leiste
    /// beim Blaettern innerhalb einer Woche hin und her.
    @Test func jederTagDerWocheLiefertDieselbeWoche() {
        let referenz = Date().weekDays

        for tag in referenz {
            #expect(tag.weekDays == referenz)
        }
    }

    @Test func balkenlaengeIstDerVerbrauchteAnteil() {
        #expect(abs(tag(1000).fill - 0.5) < 0.0001)
        #expect(abs(tag(2000).fill - 1.0) < 0.0001)
    }

    /// Ueber dem Ziel laeuft der Balken nicht weiter — die Spur waere sonst zu
    /// kurz. Die Aussage traegt dann die Farbe, der Vorlesewert die volle Zahl.
    @Test func ueberdemZielBleibtDerBalkenVoll() {
        let ueberzogen = tag(2600)

        #expect(ueberzogen.fill == 1.0)
        #expect(abs(ueberzogen.budgetShare - 1.3) < 0.0001)
        #expect(ueberzogen.score.level == .over)
    }

    /// Ein Tag ohne Eintraege ist kein Tag mit null Kalorien: er bekommt gar
    /// keinen Balken, statt als besonders sparsam durchzugehen.
    @Test func tagOhneEintraegeZeigtKeinenBalken() {
        let leer = tag(0, hasEntries: false)

        #expect(leer.fill == 0)
        #expect(leer.budgetShare == 0)
    }

    @Test func stufenFolgenDemKalorienring() {
        #expect(tag(1200).score.level == .onTrack)   // 60 %
        #expect(tag(1900).score.level == .watch)     // 95 %
        #expect(tag(2400).score.level == .over)      // 120 %
    }

    /// Ohne Ziel darf nicht durch null geteilt werden.
    @Test func fehlendesZielKipptNicht() {
        #expect(tag(500, goal: 0).fill == 0)
        #expect(tag(500, goal: 0).budgetShare == 0)
    }
}

// MARK: - Tagesziel aus rohen Werten (Issue #81)

/// Die Wochenleiste rechnet mit `DayRecord.Day` statt mit Records. Beide Wege in
/// `goalBreakdown` muessen dasselbe ergeben, sonst zeigt die Leiste eine andere
/// Stufe als der Tag, den sie oeffnet.
struct GoalBreakdownAusRohwertenTests {

    private func profil(weekendBonusPercent: Int = 10) -> UserProfile {
        let p = UserProfile(dailyCalorieGoal: 2000)
        p.useAutoCalories = true
        p.useHealthKitActivity = true
        p.bodyWeightKg = 90
        p.heightCm = 186
        p.age = 60
        p.gender = .male
        p.activityLevel = .moderatelyActive
        p.exerciseCreditPercent = 50
        p.weekendBonusPercent = weekendBonusPercent
        p.goalType = .lose
        p.weeklyWeightGoalKg = -0.5
        return p
    }

    @Test func beideWegeLiefernDasselbe() {
        let profile = profil()
        let calendar = Calendar.current
        // Ein Sonntag, damit auch der Wochenend-Bonus mitgeprueft wird.
        let sonntag = calendar.nextDate(
            after: Date(),
            matching: DateComponents(weekday: 1),
            matchingPolicy: .nextTime
        )!.startOfDay

        let record = DayRecord(date: sonntag)
        record.workoutCaloriesKcal = 420

        let ueberRecord = NutrientCalculator.goalBreakdown(
            profile: profile, dayRecord: record, nonWorkoutActiveEnergy: 1325
        )
        let ueberRohwerte = NutrientCalculator.goalBreakdown(
            profile: profile, date: sonntag, workoutCaloriesKcal: 420, nonWorkoutActiveEnergy: 1325
        )

        #expect(ueberRecord.total == ueberRohwerte.total)
        #expect(ueberRecord.weekendBonus == ueberRohwerte.weekendBonus)
        #expect(ueberRecord.workoutBonus == ueberRohwerte.workoutBonus)
        #expect(ueberRecord.activityBonus == ueberRohwerte.activityBonus)
    }

    /// Ohne Datum entfaellt der Wochenend-Bonus — so verhaelt sich auch der
    /// Record-Weg, wenn gar kein Record existiert.
    @Test func ohneDatumKeinWochenendbonus() {
        let breakdown = NutrientCalculator.goalBreakdown(
            profile: profil(), date: nil, workoutCaloriesKcal: 0, nonWorkoutActiveEnergy: 0
        )

        #expect(breakdown.weekendBonus == 0)
    }
}

// MARK: - PlannedEntry Tests

/// Geplante Mahlzeit (Issue #99): Uebernahme erzeugt einen identischen DiaryEntry,
/// Verwerfen laesst nichts zurueck, und ein Plan zaehlt in keine Tagessumme.
@MainActor
struct PlannedEntryTests {

    /// Baut einen leeren In-Memory-Store. Registriert alle von
    /// `DuplicateCleanup.run` gefetchten Modelle, damit der Dedup-Test
    /// denselben Kontext nutzen kann.
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: FoodItem.self, DiaryEntry.self, PlannedEntry.self,
                DayRecord.self, UserProfile.self, FocusLever.self, FocusLeverCheck.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func makeFood() -> FoodItem {
        FoodItem(
            name: "Gemuesepfanne",
            caloriesPer100g: 136,
            proteinPer100g: 12,
            carbsPer100g: 8,
            fatPer100g: 6
        )
    }

    @Test func uebernahmeErzeugtIdentischenEintragUndVerbrauchtDenPlan() throws {
        let context = try makeContext()
        let food = makeFood()
        context.insert(food)
        let plan = PlannedEntry(date: Date(), mealType: .dinner, amountGrams: 450, servings: 1.5, foodItem: food)
        context.insert(plan)
        try context.save()

        // Erwartete Kalorien vor der Uebernahme festhalten — danach ist der
        // Plan geloescht und darf nicht mehr angefasst werden.
        let geplanteKalorien = plan.calories

        let entry = plan.accept(in: context)
        try context.save()

        #expect(entry.date == Date().startOfDay)
        #expect(entry.mealType == .dinner)
        #expect(entry.amountGrams == 450)
        #expect(entry.servings == 1.5)
        #expect(entry.foodItem === food)
        #expect(entry.calories == geplanteKalorien)
        // Der Plan ist verbraucht — keine zweite Buchung moeglich
        let remaining = try context.fetch(FetchDescriptor<PlannedEntry>())
        #expect(remaining.isEmpty)
    }

    @Test func verwerfenHinterlaesstKeinenDatensatz() throws {
        let context = try makeContext()
        let plan = PlannedEntry(date: Date(), mealType: .dinner, amountGrams: 300, foodItem: makeFood())
        context.insert(plan)
        try context.save()

        context.delete(plan)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<PlannedEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<DiaryEntry>()).isEmpty)
    }

    /// Ein Plan darf in keiner Tagesbilanz auftauchen: der typisierte
    /// DiaryEntry-Fetch (derselbe wie in DayViewModel, Widget, Watch und CLI)
    /// sieht ihn konstruktionsbedingt nicht.
    @Test func planZaehltNichtInDieTagessumme() throws {
        let context = try makeContext()
        let food = makeFood()
        context.insert(food)
        context.insert(PlannedEntry(date: Date(), mealType: .dinner, amountGrams: 450, foodItem: food))
        try context.save()

        let startOfDay = Date().startOfDay
        let endOfDay = Date().endOfDay
        let entries = try context.fetch(FetchDescriptor<DiaryEntry>(
            predicate: #Predicate<DiaryEntry> { entry in
                entry.date >= startOfDay && entry.date <= endOfDay
            }
        ))

        #expect(entries.isEmpty)
        #expect(NutrientCalculator.calculateDaySummary(entries: entries).totalCalories == 0)
    }

    @Test func dedupBehaeltDenNeuestenPlanJeMahlzeitUndTag() throws {
        let context = try makeContext()
        let food = makeFood()
        context.insert(food)

        let alt = PlannedEntry(date: Date(), mealType: .dinner, amountGrams: 300, foodItem: food)
        alt.createdAt = Date(timeIntervalSinceNow: -3600)
        let neu = PlannedEntry(date: Date(), mealType: .dinner, amountGrams: 450, foodItem: food)
        let andereMahlzeit = PlannedEntry(date: Date(), mealType: .lunch, amountGrams: 200, foodItem: food)
        context.insert(alt)
        context.insert(neu)
        context.insert(andereMahlzeit)
        try context.save()

        let removed = DuplicateCleanup.run(in: context)

        #expect(removed == 1)
        let remaining = try context.fetch(FetchDescriptor<PlannedEntry>())
        #expect(remaining.count == 2)
        #expect(remaining.contains { $0.plannedEntryId == neu.plannedEntryId })
        #expect(remaining.contains { $0.plannedEntryId == andereMahlzeit.plannedEntryId })
    }

    /// Ein liegengebliebener Plan von gestern verfaellt beim Cleanup — er soll
    /// nirgends als Verfehlung auftauchen, und der Bestand bleibt begrenzt.
    @Test func abgelaufenePlaeneVerfallenBeimCleanup() throws {
        let context = try makeContext()
        let food = makeFood()
        context.insert(food)

        let gestern = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        context.insert(PlannedEntry(date: gestern, mealType: .dinner, amountGrams: 300, foodItem: food))
        context.insert(PlannedEntry(date: Date(), mealType: .dinner, amountGrams: 450, foodItem: food))
        try context.save()

        let removed = DuplicateCleanup.run(in: context)

        #expect(removed == 1)
        let remaining = try context.fetch(FetchDescriptor<PlannedEntry>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.date == Date().startOfDay)
    }

    /// Geplant wird die naechste Hauptmahlzeit: drei Stunden Versatz, auf die
    /// Hauptmahlzeit aufgerundet. Nebenmahlzeiten sind nie Planungsziel.
    @Test func planungszielIstDieNaechsteHauptmahlzeit() {
        #expect(MealType.planningTarget(forHour: 2) == .breakfast)
        #expect(MealType.planningTarget(forHour: 6) == .breakfast)
        #expect(MealType.planningTarget(forHour: 7) == .lunch)      // 10 Uhr waere 2. Fruehstueck
        #expect(MealType.planningTarget(forHour: 9) == .lunch)
        #expect(MealType.planningTarget(forHour: 11) == .lunch)
        #expect(MealType.planningTarget(forHour: 13) == .dinner)    // 16 Uhr waere Kaffeepause
        #expect(MealType.planningTarget(forHour: 15) == .dinner)
        #expect(MealType.planningTarget(forHour: 18) == .dinner)
        #expect(MealType.planningTarget(forHour: 20) == .dinner)    // spaet abends bleibt Abendessen
        #expect(MealType.planningTarget(forHour: 23) == .dinner)
        #expect(MealType.planningTarget(forHour: 0) == .breakfast)  // nachts zielt der Plan aufs Fruehstueck
    }

    private func makeEstimate(name: String, grams: Double, kcalPer100g: Double) throws -> AIFoodEstimate {
        let json = """
        {
            "name": "\(name)",
            "confidence": "high",
            "estimatedWeightGrams": \(grams),
            "caloriesPer100g": \(kcalPer100g),
            "proteinPer100g": 1,
            "carbsPer100g": 2,
            "fatPer100g": 3,
            "fiberPer100g": 0,
            "sugarPer100g": 0,
            "saturatedFatPer100g": 0,
            "saltPer100g": 0,
            "totalCalories": 0,
            "components": []
        }
        """
        return try JSONDecoder().decode(AIFoodEstimate.self, from: Data(json.utf8))
    }

    /// Der Planungsmodus fasst mehrere KI-Komponenten zu EINEM Plan zusammen;
    /// die Kalorien des Plans entsprechen der Summe der Einzelschaetzungen.
    @Test func planAggregiertSchaetzungenZuEinemPlan() throws {
        let context = try makeContext()
        let estimates = [
            try makeEstimate(name: "Pizza", grams: 300, kcalPer100g: 250),
            try makeEstimate(name: "Cola", grams: 330, kcalPer100g: 42)
        ]

        let plan = try #require(FocusBooking.plan(
            estimates: estimates, meal: .dinner, date: Date(), context: context
        ))

        #expect(plan.amountGrams == 630)
        #expect(plan.foodItem?.name == "Pizza, Cola")
        #expect(plan.foodItem?.isQuickEntry == true)
        // 300g x 250/100 + 330g x 42/100 = 750 + 138.6
        #expect(abs(plan.calories - 888.6) < 0.01)
        #expect(try context.fetch(FetchDescriptor<PlannedEntry>()).count == 1)
    }

    /// Ein neuer KI-Plan ersetzt den alten samt dessen Schnell-Lebensmittel;
    /// beim Verwerfen bleibt ebenfalls kein Schnell-Lebensmittel zurueck.
    /// Ein Lebensmittel aus der Suche uebersteht das Verwerfen dagegen.
    @Test func discardRaeumtSchnellLebensmittelAbSuchtreffernNicht() throws {
        let context = try makeContext()

        _ = FocusBooking.plan(
            estimates: [try makeEstimate(name: "Pizza", grams: 300, kcalPer100g: 250)],
            meal: .dinner, date: Date(), context: context
        )
        let ersetzt = try #require(FocusBooking.plan(
            estimates: [try makeEstimate(name: "Salat", grams: 200, kcalPer100g: 45)],
            meal: .dinner, date: Date(), context: context
        ))
        #expect(try context.fetch(FetchDescriptor<FoodItem>()).count == 1)

        ersetzt.discard(in: context)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<PlannedEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<FoodItem>()).isEmpty)

        // Suchtreffer (kein Schnelleintrag) bleibt beim Verwerfen stehen
        let food = makeFood()
        context.insert(food)
        let plan = PlannedEntry.setPlan(foodItem: food, date: Date(), mealType: .lunch, amountGrams: 100, in: context)
        try context.save()
        plan.discard(in: context)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<FoodItem>()).count == 1)
    }

    /// Ein neuer Plan ersetzt den bestehenden derselben Mahlzeit und desselben
    /// Tages — die Invariante lebt in `setPlan` am Modell.
    @Test func setPlanErsetztBestehendenPlanDerselbenMahlzeit() throws {
        let context = try makeContext()
        let food = makeFood()
        context.insert(food)

        PlannedEntry.setPlan(foodItem: food, date: Date(), mealType: .dinner, amountGrams: 300, in: context)
        try context.save()
        PlannedEntry.setPlan(foodItem: food, date: Date(), mealType: .dinner, amountGrams: 450, in: context)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<PlannedEntry>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.amountGrams == 450)
    }
}

// MARK: - OFF-Suche Tests

/// Die Search-a-licious-API liefert `hits` mit `brands` als Array — der
/// Treffer muss verlustfrei ins App-Produktformat uebersetzen (Issue #100).
struct OFFSearchDecodingTests {

    @Test func hitWirdZumProdukt() throws {
        let json = """
        {
            "hits": [
                {
                    "code": "123",
                    "product_name": "Apfelmus",
                    "brands": ["GutBio", " Aldi"],
                    "nutriments": { "energy-kcal_100g": 80, "sugars_100g": 18 }
                }
            ]
        }
        """
        let response = try JSONDecoder().decode(OFFSearchResponse.self, from: Data(json.utf8))
        let product = try #require(response.hits?.first?.asProduct)

        #expect(product.code == "123")
        #expect(product.productName == "Apfelmus")
        #expect(product.brands == "GutBio, Aldi")
        #expect(product.nutriments?.energyKcal100g == 80)
        #expect(product.nutriments?.sugars100g == 18)
    }

    @Test func leereMarkenWerdenZuNil() throws {
        let json = """
        { "hits": [ { "code": "1", "product_name": "X", "brands": [] } ] }
        """
        let response = try JSONDecoder().decode(OFFSearchResponse.self, from: Data(json.utf8))
        #expect(response.hits?.first?.asProduct.brands == nil)
    }
}

// MARK: - BuildInfo Tests

/// Der Build-Zeitstempel kommt seit Issue #60 als Build-Setting in die Info.plist,
/// nicht mehr als Dateischreibung in die versionierte Secrets.plist. Bleibt das
/// Setting ungesetzt, muss der Platzhalter zu Leerstring expandieren und die
/// Anzeige auf das Aenderungsdatum der Executable zurueckfallen — keinesfalls darf
/// `$(BUILD_TIMESTAMP)` woertlich in der Fusszeile stehen.
struct BuildInfoTests {

    @Test func buildDateIstAufgeloestUndNichtLeer() {
        let datum = BuildInfo.buildDate
        #expect(!datum.isEmpty)
        #expect(!datum.contains("$("))
    }
}

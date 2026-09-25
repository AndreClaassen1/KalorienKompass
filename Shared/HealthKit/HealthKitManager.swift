//
//  HealthKitManager.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//
//  HealthKit-Integration fuer Schritte und Gewicht (nur iOS/iPadOS)
//

#if canImport(HealthKit)
import HealthKit
import SwiftData
import os

/// Manager fuer HealthKit-Datenabfragen
@Observable
final class HealthKitManager {
    private static let logger = Logger(subsystem: "com.andre.claassen.KalorienKompass", category: "HealthKit")
    static let shared = HealthKitManager()

    private let healthStore: HKHealthStore?
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    var isAuthorized = false

    private init() {
        healthStore = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    }

    /// Fordert HealthKit-Berechtigungen an (Lesen + Schreiben)
    func requestAuthorization() async {
        guard let healthStore, isAvailable else { return }

        let nutritionTypes: Set<HKQuantityType> = [
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryCarbohydrates),
            HKQuantityType(.dietaryFatTotal),
            HKQuantityType(.dietaryFiber),
            HKQuantityType(.dietarySugar),
            HKQuantityType(.dietaryFatSaturated),
            HKQuantityType(.dietarySodium),
            HKQuantityType(.dietaryCaffeine)
        ]

        var typesToRead: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.bodyMass),
            HKQuantityType(.dietaryWater),
            HKQuantityType(.activeEnergyBurned),
            HKWorkoutType.workoutType()
        ]
        typesToRead.formUnion(nutritionTypes)

        var typesToShare: Set<HKSampleType> = [
            HKQuantityType(.bodyMass),
            HKQuantityType(.dietaryWater)
        ]
        typesToShare.formUnion(nutritionTypes)

        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            isAuthorized = true
        } catch {
            print("HealthKit Autorisierung fehlgeschlagen: \(error.localizedDescription)")
            isAuthorized = false
        }
    }

    /// Liest die Schritte fuer einen bestimmten Tag
    func fetchSteps(for date: Date) async -> Int {
        guard let healthStore, isAvailable else { return 0 }

        let stepType = HKQuantityType(.stepCount)
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                // Bei fehlenden Daten oder Berechtigungsproblemen: 0 zurueckgeben
                let steps = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            healthStore.execute(query)
        }
    }

    /// Liest das aktuellste Gewicht
    func fetchLatestWeight(for date: Date) async -> Double? {
        guard let healthStore, isAvailable else { return nil }

        let weightType = HKQuantityType(.bodyMass)
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                let weight = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: weight)
            }
            healthStore.execute(query)
        }
    }

    /// Liest die Wasseraufnahme fuer einen bestimmten Tag (in ml)
    func fetchWaterIntake(for date: Date) async -> Int {
        guard let healthStore, isAvailable else { return 0 }

        let waterType = HKQuantityType(.dietaryWater)
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: waterType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                // Bei fehlenden Daten oder Berechtigungsproblemen: 0 zurueckgeben
                let ml = statistics?.sumQuantity()?.doubleValue(for: .literUnit(with: .milli)) ?? 0
                continuation.resume(returning: Int(ml))
            }
            healthStore.execute(query)
        }
    }

    /// Schreibt ein Gewicht nach HealthKit
    func saveWeight(_ kg: Double, for date: Date) async {
        guard let healthStore, isAvailable, isAuthorized else { return }

        let weightType = HKQuantityType(.bodyMass)
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        let sample = HKQuantitySample(
            type: weightType,
            quantity: quantity,
            start: date,
            end: date
        )

        do {
            try await healthStore.save(sample)
        } catch {
            print("Gewicht konnte nicht gespeichert werden: \(error.localizedDescription)")
        }
    }

    /// Schreibt eine Wasseraufnahme nach HealthKit (Inkrement)
    func saveWaterIntake(ml: Int, for date: Date) async {
        guard let healthStore, isAvailable, isAuthorized, ml > 0 else { return }

        let waterType = HKQuantityType(.dietaryWater)
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(ml))
        let sample = HKQuantitySample(
            type: waterType,
            quantity: quantity,
            start: date,
            end: date
        )

        do {
            try await healthStore.save(sample)
        } catch {
            print("Wasseraufnahme konnte nicht gespeichert werden: \(error.localizedDescription)")
        }
    }

    /// Schreibt eine Koffeinaufnahme nach HealthKit (Inkrement)
    func saveCaffeine(mg: Double, for date: Date) async {
        guard let healthStore, isAvailable, isAuthorized, mg > 0 else { return }

        let caffeineType = HKQuantityType(.dietaryCaffeine)
        let quantity = HKQuantity(unit: .gramUnit(with: .milli), doubleValue: mg)
        let sample = HKQuantitySample(
            type: caffeineType,
            quantity: quantity,
            start: date,
            end: date
        )

        do {
            try await healthStore.save(sample)
        } catch {
            Self.logger.warning("Koffein konnte nicht gespeichert werden: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Liest die Gewichtshistorie fuer einen Zeitraum
    func fetchWeightHistory(days: Int) async -> [(date: Date, weight: Double)] {
        guard let healthStore, isAvailable else { return [] }

        let weightType = HKQuantityType(.bodyMass)
        let endDate = Date()
        guard let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                let data = (samples ?? []).compactMap { sample -> (Date, Double)? in
                    guard let qs = sample as? HKQuantitySample else { return nil }
                    return (qs.startDate, qs.quantity.doubleValue(for: .gramUnit(with: .kilo)))
                }
                continuation.resume(returning: data)
            }
            healthStore.execute(query)
        }
    }

    /// Liest die Aktivitaetskalorien fuer einen bestimmten Tag
    func fetchActiveEnergy(for date: Date) async -> Int {
        guard let healthStore, isAvailable else { return 0 }

        let energyType = HKQuantityType(.activeEnergyBurned)
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: energyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                // Bei fehlenden Daten oder Berechtigungsproblemen: 0 zurueckgeben
                let kcal = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: Int(kcal))
            }
            healthStore.execute(query)
        }
    }

    /// Liest die Workouts fuer einen bestimmten Tag
    func fetchWorkouts(for date: Date) async -> [WorkoutEntry] {
        guard let healthStore, isAvailable else { return [] }

        let workoutType = HKWorkoutType.workoutType()
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                let entries = (samples ?? []).compactMap { sample -> WorkoutEntry? in
                    guard let workout = sample as? HKWorkout else { return nil }
                    let info = WorkoutEntry.activityInfo(for: workout.workoutActivityType.rawValue)
                    let kcal = Int(workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0)
                    let minutes = Int(workout.duration / 60)
                    return WorkoutEntry(
                        activityName: info.name,
                        durationMinutes: minutes,
                        caloriesBurned: kcal,
                        symbolName: info.symbol
                    )
                }
                continuation.resume(returning: entries)
            }
            healthStore.execute(query)
        }
    }

    /// Liest die Tageswerte aus HealthKit, ohne etwas zu speichern.
    ///
    /// Bewusst getrennt vom Schreiben (Issue #65): erst messen, und nur wenn
    /// `metrics.hasData` gilt, besorgt der Aufrufer einen `DayRecord`. Frueher
    /// bekam diese Methode den Record hereingereicht, weshalb jeder Tageswechsel
    /// einen leeren Record anlegte, nur damit der Sync ein Ziel hatte.
    func fetchDayMetrics(for date: Date) async -> (metrics: DayRecord.Metrics, workouts: [WorkoutEntry]) {
        let steps = await fetchSteps(for: date)
        let weight = await fetchLatestWeight(for: date)
        let water = await fetchWaterIntake(for: date)
        let activeEnergy = await fetchActiveEnergy(for: date)
        let workouts = await fetchWorkouts(for: date)

        let metrics = DayRecord.Metrics(
            steps: steps,
            weight: weight,
            waterIntakeMl: water,
            activeEnergyKcal: activeEnergy,
            workoutCaloriesKcal: workouts.reduce(0) { $0 + $1.caloriesBurned }
        )
        return (metrics, workouts)
    }

    // MARK: - Ernaehrungsdaten nach HealthKit schreiben

    /// Synchronisiert die Tages-Naehrwerte nach HealthKit (Delete-and-Rewrite)
    func syncNutritionToHealthKit(entries: [DiaryEntry], for date: Date) async {
        // Der Aufraeum-Schritt loescht nur Samples der eigenen Bundle-ID. Seit
        // Debug- und Release-App verschiedene IDs haben (Issue #64), koennte der
        // Debug-Build die Samples der echten App nicht mehr ersetzen — Health
        // wuerde beide Quellen addieren und die Kalorien doppelt zaehlen.
        #if DEBUG
        return
        #else
        guard let healthStore, isAvailable, isAuthorized else { return }

        let summary = NutrientCalculator.calculateDaySummary(entries: entries)

        await deleteOwnNutritionSamples(for: date)

        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let nutritionValues: [(HKQuantityTypeIdentifier, Double, HKUnit)] = [
            (.dietaryEnergyConsumed, summary.totalCalories, .kilocalorie()),
            (.dietaryProtein, summary.totalProtein, .gramUnit(with: .none)),
            (.dietaryCarbohydrates, summary.totalCarbs, .gramUnit(with: .none)),
            (.dietaryFatTotal, summary.totalFat, .gramUnit(with: .none)),
            (.dietaryFiber, summary.totalFiber, .gramUnit(with: .none)),
            (.dietarySugar, summary.totalSugar, .gramUnit(with: .none)),
            (.dietaryFatSaturated, summary.totalSaturatedFat, .gramUnit(with: .none)),
            (.dietarySodium, summary.totalSodium, .gramUnit(with: .none))
        ]

        var samples: [HKQuantitySample] = []
        for (identifier, value, unit) in nutritionValues where value > 0 {
            let type = HKQuantityType(identifier)
            let quantity = HKQuantity(unit: unit, doubleValue: value)
            let sample = HKQuantitySample(
                type: type,
                quantity: quantity,
                start: startOfDay,
                end: endOfDay
            )
            samples.append(sample)
        }

        guard !samples.isEmpty else { return }

        do {
            try await healthStore.save(samples)
            Self.logger.info("Ernaehrungsdaten nach HealthKit geschrieben: \(samples.count, privacy: .public) Samples")
        } catch {
            Self.logger.error("Ernaehrungsdaten konnten nicht gespeichert werden: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    /// Loescht eigene Ernaehrungs-Samples fuer einen Tag
    private func deleteOwnNutritionSamples(for date: Date) async {
        guard let healthStore else { return }

        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let nutritionIdentifiers: [HKQuantityTypeIdentifier] = [
            .dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates,
            .dietaryFatTotal, .dietaryFiber, .dietarySugar,
            .dietaryFatSaturated, .dietarySodium
        ]

        let datePredicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        let sourcePredicate = HKQuery.predicateForObjects(from: .default())
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, sourcePredicate])

        for identifier in nutritionIdentifiers {
            let type = HKQuantityType(identifier)
            let samples = await fetchSamples(type: type, predicate: predicate)
            guard !samples.isEmpty else { continue }
            do {
                try await healthStore.delete(samples)
            } catch {
                Self.logger.warning("Konnte \(identifier.rawValue, privacy: .public) Samples nicht loeschen: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Hilfsmethode: Samples fuer einen Typ und Praedikat abfragen
    private func fetchSamples(type: HKSampleType, predicate: NSPredicate) async -> [HKSample] {
        guard let healthStore else { return [] }

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples ?? [])
            }
            healthStore.execute(query)
        }
    }
}
#endif

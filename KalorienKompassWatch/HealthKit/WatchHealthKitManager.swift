//
//  WatchHealthKitManager.swift
//  KalorienKompassWatch
//
//  Erstellt von André Claaßen am 06.02.26.
//
//  Watch-native HealthKit-Abfragen (praeziser als iPhone)
//

#if os(watchOS)
import HealthKit
import SwiftData

/// Manager fuer HealthKit-Datenabfragen auf der Apple Watch
@Observable
final class WatchHealthKitManager {
    static let shared = WatchHealthKitManager()

    private let healthStore: HKHealthStore?
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    var isAuthorized = false

    private init() {
        healthStore = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    }

    /// Fordert HealthKit-Berechtigungen an
    func requestAuthorization() async {
        guard let healthStore, isAvailable else { return }

        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.dietaryWater),
            HKWorkoutType.workoutType()
        ]

        let typesToShare: Set<HKSampleType> = [
            HKQuantityType(.dietaryWater)
        ]

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
                let steps = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
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

    /// Liest die Tageswerte aus HealthKit, ohne etwas zu speichern (Issue #65).
    /// Der Aufrufer legt nur dann einen `DayRecord` an, wenn tatsaechlich Werte
    /// anliegen.
    func fetchDayMetrics(for date: Date) async -> (metrics: DayRecord.Metrics, workouts: [WorkoutEntry]) {
        let steps = await fetchSteps(for: date)
        let activeEnergy = await fetchActiveEnergy(for: date)
        let workouts = await fetchWorkouts(for: date)

        let metrics = DayRecord.Metrics(
            steps: steps,
            activeEnergyKcal: activeEnergy,
            workoutCaloriesKcal: workouts.reduce(0) { $0 + $1.caloriesBurned }
        )
        return (metrics, workouts)
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
}
#endif

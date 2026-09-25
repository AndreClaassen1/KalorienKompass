//
//  WorkoutEntry.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 05.02.26.
//

import Foundation

/// Einzelne Trainingseinheit (aus HealthKit synchronisiert)
struct WorkoutEntry: Identifiable, Sendable {
    let id = UUID()
    let activityName: String
    let durationMinutes: Int
    let caloriesBurned: Int
    let symbolName: String

    /// Mappt HKWorkoutActivityType-RawValue auf (Name, SF Symbol)
    static func activityInfo(for rawValue: UInt) -> (name: String, symbol: String) {
        switch rawValue {
        case 1: ("Laufen", "figure.run")
        case 2: ("Radfahren", "figure.outdoor.cycle")
        case 3: ("Gehen", "figure.walk")
        case 5: ("Crosstraining", "figure.cross.training")
        case 6: ("Elliptical", "figure.elliptical")
        case 10: ("Wandern", "figure.hiking")
        case 13: ("Schwimmen", "figure.pool.swim")
        case 20: ("Rudern", "figure.rower")
        case 24: ("Krafttraining", "figure.strengthtraining.traditional")
        case 25: ("Yoga", "figure.yoga")
        case 27: ("Pilates", "figure.pilates")
        case 35: ("Tanzen", "figure.dance")
        case 37: ("HIIT", "figure.highintensity.intervaltraining")
        case 46: ("Treppensteigen", "figure.stair.stepper")
        case 47: ("Tennis", "figure.tennis")
        case 50: ("Badminton", "figure.badminton")
        case 52: ("Fussball", "figure.soccer")
        case 56: ("Tischtennis", "figure.table.tennis")
        case 58: ("Volleyball", "figure.volleyball")
        case 62: ("Kampfsport", "figure.martial.arts")
        case 63: ("Basketball", "figure.basketball")
        case 76: ("Kickboxen", "figure.kickboxing")
        default: ("Training", "figure.run")
        }
    }
}

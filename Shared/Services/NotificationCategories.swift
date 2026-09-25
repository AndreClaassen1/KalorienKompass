//
//  NotificationCategories.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 06.02.26.
//

import Foundation
import UserNotifications

/// Kategorien fuer lokale Benachrichtigungen
enum NotificationCategory: String {
    case waterReminder = "WATER_REMINDER"
    case mealReminder = "MEAL_REMINDER"
    case streakCelebration = "STREAK_CELEBRATION"
}

/// Actions fuer Notification-Buttons
enum NotificationAction: String {
    case addWater = "ADD_WATER_250"
    case snooze = "SNOOZE_30"
    case trackMeal = "TRACK_MEAL"
    case skipMeal = "SKIP_MEAL"
}

/// Streak-Typ fuer Feier-Benachrichtigungen
enum StreakType {
    case water
    case meal
}

// MARK: - Category Registration

extension NotificationManager {
    /// Registriert alle Notification-Kategorien mit ihren Actions
    func registerCategories() async {
        // Wasser-Erinnerung Actions
        let addWater = UNNotificationAction(
            identifier: NotificationAction.addWater.rawValue,
            title: String(localized: "notification_action_add_water"),
            options: []
        )
        let snoozeWater = UNNotificationAction(
            identifier: NotificationAction.snooze.rawValue,
            title: String(localized: "notification_action_snooze"),
            options: []
        )
        let waterCategory = UNNotificationCategory(
            identifier: NotificationCategory.waterReminder.rawValue,
            actions: [addWater, snoozeWater],
            intentIdentifiers: []
        )

        // Mahlzeiten-Erinnerung Actions
        let trackMeal = UNNotificationAction(
            identifier: NotificationAction.trackMeal.rawValue,
            title: String(localized: "notification_action_track"),
            options: [.foreground]
        )
        let skipMeal = UNNotificationAction(
            identifier: NotificationAction.skipMeal.rawValue,
            title: String(localized: "notification_action_skip"),
            options: []
        )
        let mealCategory = UNNotificationCategory(
            identifier: NotificationCategory.mealReminder.rawValue,
            actions: [trackMeal, skipMeal],
            intentIdentifiers: []
        )

        // Streak-Feier (keine Actions, nur Anzeige)
        let streakCategory = UNNotificationCategory(
            identifier: NotificationCategory.streakCelebration.rawValue,
            actions: [],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            waterCategory,
            mealCategory,
            streakCategory
        ])
    }
}

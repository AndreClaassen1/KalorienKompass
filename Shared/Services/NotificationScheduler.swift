//
//  NotificationScheduler.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 06.02.26.
//

import Foundation
import UserNotifications

// MARK: - Water Reminders

extension NotificationManager {
    /// Scheduled Wasser-Erinnerungen basierend auf aktuellem Fortschritt
    func scheduleWaterReminders(
        profile: UserProfile,
        currentIntake: Int
    ) async {
        guard profile.waterRemindersEnabled else {
            await cancelWaterReminders()
            return
        }

        // Ruhezeit pruefen
        let now = Date()
        if isInQuietTime(now, profile: profile) {
            return
        }

        await cancelWaterReminders()

        let calendar = Calendar.current
        let isWeekend = calendar.isDateInWeekend(now)
        let offset = isWeekend ? 2 : 0  // Wochenende +2 Stunden

        let hours = [8, 10, 12, 14, 16, 18, 20].map { $0 + offset }
        let goal = profile.dailyWaterGoalMl

        for hour in hours {
            // Nur zukuenftige Zeiten und ausserhalb Ruhezeit schedulen
            guard let triggerDate = calendar.date(
                bySettingHour: hour, minute: 0, second: 0, of: now
            ), triggerDate > now else { continue }

            // Ruhezeit pruefen
            if isInQuietTime(triggerDate, profile: profile) {
                continue
            }

            // Erwarteter Fortschritt zu dieser Stunde
            let baseHour = isWeekend ? 10 : 8
            let hoursElapsed = Double(hour - baseHour)
            let totalHours = 12.0
            let expectedProgress = Int((hoursElapsed / totalHours) * Double(goal))

            // Nur schedulen wenn aktuell unter Soll
            let tolerance = 0.8
            if Double(currentIntake) >= Double(expectedProgress) * tolerance {
                continue
            }

            let deficit = expectedProgress - currentIntake
            let content = makeWaterContent(deficit: deficit, remaining: goal - currentIntake)

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.hour, .minute], from: triggerDate),
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: "water_\(hour)",
                content: content,
                trigger: trigger
            )

            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    private func makeWaterContent(deficit: Int, remaining: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = NotificationCategory.waterReminder.rawValue
        content.sound = .default

        if isFirstWeek {
            // Sanfter Start in der ersten Woche
            content.title = String(localized: "notification_water_title_gentle")
            content.body = String(localized: "notification_water_body_gentle")
        } else {
            content.title = String(localized: "notification_water_title")
            content.body = String(localized: "Du liegst \(deficit) ml zurück. Noch \(remaining) ml bis zum Ziel.")
        }

        return content
    }

    /// Loescht alle geplanten Wasser-Erinnerungen
    func cancelWaterReminders() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let waterIds = pending.filter { $0.identifier.hasPrefix("water_") }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: waterIds)
    }
}

// MARK: - Meal Reminders

extension NotificationManager {
    /// Scheduled Mahlzeiten-Erinnerungen basierend auf bereits getrackten Mahlzeiten
    func scheduleMealReminders(
        profile: UserProfile,
        trackedMeals: Set<MealType>
    ) async {
        guard profile.mealRemindersEnabled else {
            await cancelMealReminders()
            return
        }

        // Ruhezeit pruefen
        let now = Date()
        if isInQuietTime(now, profile: profile) {
            return
        }

        await cancelMealReminders()

        let calendar = Calendar.current
        let isWeekend = calendar.isDateInWeekend(now)
        let offset = isWeekend ? 2 : 0

        // Hauptmahlzeiten mit Erinnerungszeiten
        let meals: [(MealType, Int)] = [
            (.breakfast, 10 + offset),
            (.lunch, 14 + offset),
            (.dinner, 20 + offset)
        ]

        for (meal, hour) in meals {
            // Bereits getrackt?
            if trackedMeals.contains(meal) { continue }

            // Nur zukuenftige Zeiten
            guard let triggerDate = calendar.date(
                bySettingHour: hour, minute: 0, second: 0, of: now
            ), triggerDate > now else { continue }

            // Ruhezeit pruefen
            if isInQuietTime(triggerDate, profile: profile) {
                continue
            }

            let content = makeMealContent(meal: meal)

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.hour, .minute], from: triggerDate),
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: "meal_\(meal.rawValue)",
                content: content,
                trigger: trigger
            )

            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    private func makeMealContent(meal: MealType) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = NotificationCategory.mealReminder.rawValue
        content.sound = .default
        content.userInfo = ["meal": meal.rawValue]

        let mealName = meal.localizedString

        if isFirstWeek {
            content.title = String(localized: "notification_meal_title_gentle")
            content.body = String(localized: "Vergiss nicht dein \(mealName)!")
        } else {
            content.title = String(localized: "notification_meal_title")
            content.body = String(localized: "Hast du dein \(mealName) schon getrackt?")
        }

        return content
    }

    /// Loescht alle geplanten Mahlzeiten-Erinnerungen
    func cancelMealReminders() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let mealIds = pending.filter { $0.identifier.hasPrefix("meal_") }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: mealIds)
    }
}

// MARK: - Streak Celebrations

extension NotificationManager {
    /// Prueft und scheduled Streak-Feiern fuer Meilensteine
    func checkAndScheduleStreakCelebration(
        waterStreak: Int,
        mealStreak: Int
    ) async {
        let milestones = [3, 7, 14, 30]

        for milestone in milestones {
            if waterStreak == milestone {
                await scheduleStreakNotification(type: .water, days: milestone)
            }
            if mealStreak == milestone {
                await scheduleStreakNotification(type: .meal, days: milestone)
            }
        }
    }

    private func scheduleStreakNotification(type: StreakType, days: Int) async {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = NotificationCategory.streakCelebration.rawValue
        content.sound = .default

        switch (type, days) {
        case (.water, 3):
            content.title = "💧 3 Tage!"
            content.body = String(localized: "streak_water_3")
        case (.water, 7):
            content.title = "🌊 Eine Woche!"
            content.body = String(localized: "streak_water_7")
        case (.water, 14):
            content.title = "🏆 2 Wochen!"
            content.body = String(localized: "streak_water_14")
        case (.water, 30):
            content.title = "🚀 Ein Monat!"
            content.body = String(localized: "streak_water_30")
        case (.meal, 3):
            content.title = "📝 3 Tage!"
            content.body = String(localized: "streak_meal_3")
        case (.meal, 7):
            content.title = "⭐ Eine Woche!"
            content.body = String(localized: "streak_meal_7")
        case (.meal, 14):
            content.title = "🎯 2 Wochen!"
            content.body = String(localized: "streak_meal_14")
        case (.meal, 30):
            content.title = "🏅 Ein Monat!"
            content.body = String(localized: "streak_meal_30")
        default:
            // Unbekannter Meilenstein, nicht benachrichtigen
            return
        }

        // Um 21:00 heute benachrichtigen
        let calendar = Calendar.current
        guard let triggerDate = calendar.date(
            bySettingHour: 21, minute: 0, second: 0, of: Date()
        ), triggerDate > Date() else { return }

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.hour, .minute], from: triggerDate),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "streak_\(type)_\(days)",
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Quiet Time

extension NotificationManager {
    /// Prueft ob eine Zeit in der Ruhezeit liegt
    func isInQuietTime(_ date: Date, profile: UserProfile) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)

        let start = profile.quietTimeStartHour
        let end = profile.quietTimeEndHour

        // Ueber Mitternacht (z.B. 22:00 - 07:00)
        if start > end {
            return hour >= start || hour < end
        }

        // Innerhalb eines Tages (z.B. 13:00 - 14:00)
        return hour >= start && hour < end
    }
}

// MARK: - Reschedule All

extension NotificationManager {
    /// Scheduled alle Notifications neu (nach Aenderungen)
    func rescheduleAll(
        profile: UserProfile,
        currentWaterIntake: Int,
        trackedMeals: Set<MealType>
    ) async {
        guard isAuthorized else { return }

        await scheduleWaterReminders(profile: profile, currentIntake: currentWaterIntake)
        await scheduleMealReminders(profile: profile, trackedMeals: trackedMeals)
    }

    /// Loescht alle geplanten Notifications
    func cancelAll() async {
        await cancelWaterReminders()
        await cancelMealReminders()
    }
}

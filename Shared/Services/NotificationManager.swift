//
//  NotificationManager.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 06.02.26.
//

import Foundation
import UserNotifications
import SwiftData

/// Manager fuer lokale Push-Benachrichtigungen (Wasser, Mahlzeiten, Streaks)
@Observable
final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    /// Ob Benachrichtigungen autorisiert sind
    private(set) var isAuthorized = false

    /// Datum der ersten Installation (fuer sanften Start)
    private(set) var installDate: Date?

    private override init() {
        super.init()
        loadInstallDate()
        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Authorization

    /// Fordert Berechtigung fuer Benachrichtigungen an
    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        do {
            isAuthorized = try await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            if isAuthorized {
                await registerCategories()
            }
        } catch {
            isAuthorized = false
        }
    }

    /// Prueft den aktuellen Autorisierungsstatus
    func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Install Date (Sanfter Start)

    private func loadInstallDate() {
        let key = "notificationInstallDate"
        if let date = UserDefaults.standard.object(forKey: key) as? Date {
            installDate = date
        } else {
            installDate = Date()
            UserDefaults.standard.set(installDate, forKey: key)
        }
    }

    /// Ob der Benutzer in der ersten Woche ist (sanftere Benachrichtigungen)
    var isFirstWeek: Bool {
        guard let install = installDate else { return true }
        return Date().timeIntervalSince(install) < 7 * 24 * 60 * 60
    }

    // MARK: - Action Handling

    /// Verarbeitet Notification-Actions
    func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let actionId = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo

        switch actionId {
        case NotificationAction.addWater.rawValue:
            await handleAddWater()

        case NotificationAction.snooze.rawValue:
            await handleSnooze(category: response.notification.request.content.categoryIdentifier)

        case NotificationAction.trackMeal.rawValue:
            if let mealRaw = userInfo["meal"] as? String {
                await handleTrackMeal(mealRaw: mealRaw)
            }

        case NotificationAction.skipMeal.rawValue:
            // Nichts tun, Notification einfach dismissieren
            break

        default:
            // Standard-Tap: App oeffnen
            break
        }
    }

    private func handleAddWater() async {
        // 250ml Wasser hinzufuegen via DayViewModel
        // Da wir keinen direkten Zugriff auf den ModelContext haben,
        // posten wir eine Notification
        await MainActor.run {
            NotificationCenter.default.post(
                name: .addWaterFromNotification,
                object: nil,
                userInfo: ["ml": 250]
            )
        }
    }

    private func handleSnooze(category: String) async {
        // In 30 Minuten erneut erinnern
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = category
        content.sound = .default

        if category == NotificationCategory.waterReminder.rawValue {
            content.title = String(localized: "notification_water_title")
            content.body = String(localized: "notification_water_snooze_body")
        } else {
            content.title = String(localized: "notification_meal_title")
            content.body = String(localized: "notification_meal_snooze_body")
        }

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 30 * 60,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "snooze_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    private func handleTrackMeal(mealRaw: String) async {
        // Deep Link zur Mahlzeiten-Erfassung
        await MainActor.run {
            NotificationCenter.default.post(
                name: .openFoodSearchFromNotification,
                object: nil,
                userInfo: ["meal": mealRaw]
            )
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await handleNotificationResponse(response)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Zeige Notifications auch wenn App im Vordergrund ist
        return [.banner, .sound]
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let addWaterFromNotification = Notification.Name("addWaterFromNotification")
    static let openFoodSearchFromNotification = Notification.Name("openFoodSearchFromNotification")

    // Fokus-Modus: macOS-Menuebefehle steuern die Fokus-Ansicht per Notification
    static let focusDictateToggle = Notification.Name("focusDictateToggle")
    static let focusInputFocus = Notification.Name("focusInputFocus")
    static let focusPreviousDay = Notification.Name("focusPreviousDay")
    static let focusNextDay = Notification.Name("focusNextDay")
    static let focusGoToToday = Notification.Name("focusGoToToday")
    static let focusOpenSettings = Notification.Name("focusOpenSettings")
}

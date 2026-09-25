//
//  FocusMenuCommands.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 15.07.26.
//
//  Schlankes macOS-Hauptmenue fuer den Fokus-Modus. Steuert die Fokus-Ansicht
//  ausschliesslich ueber Notifications (die Fokus-Views halten ihren eigenen
//  Zustand). Wichtigster Eintrag: "Essen diktieren" (Cmd+D) startet das
//  On-Device-Diktat im Eingabefeld.
//

#if os(macOS)
import SwiftUI

struct FocusMenuCommands: Commands {

    private func post(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }

    var body: some Commands {
        // MARK: - Eintrag: diktieren / tippen
        CommandMenu(String(localized: "menu_focus_entry", defaultValue: "Eintrag")) {
            Button(String(localized: "menu_focus_dictate", defaultValue: "Essen diktieren…")) {
                post(.focusDictateToggle)
            }
            .keyboardShortcut("d", modifiers: .command)

            Button(String(localized: "menu_focus_type", defaultValue: "Essen eintragen")) {
                post(.focusInputFocus)
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        // MARK: - Tag-Navigation (Fokus-Ansicht)
        CommandMenu(String(localized: "menu_day", defaultValue: "Tag")) {
            Button(String(localized: "menu_previous_day", defaultValue: "Vorheriger Tag")) {
                post(.focusPreviousDay)
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .option])

            Button(String(localized: "menu_next_day", defaultValue: "Nächster Tag")) {
                post(.focusNextDay)
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .option])

            Divider()

            Button(String(localized: "menu_today", defaultValue: "Heute")) {
                post(.focusGoToToday)
            }
            .keyboardShortcut("t", modifiers: .command)
        }

        // MARK: - Einstellungen (Cmd+,) ersetzt Standard-Settings
        CommandGroup(replacing: .appSettings) {
            Button(String(localized: "menu_settings", defaultValue: "Einstellungen…")) {
                post(.focusOpenSettings)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
#endif

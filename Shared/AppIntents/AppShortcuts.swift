//
//  AppShortcuts.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 10.02.26.
//

import AppIntents

/// Die Siri-Phrasen der App.
///
/// Bewusst kurz gehalten (Issue #74): Apple erlaubt hoechstens **10** Eintraege
/// pro App, und zehn belegte Plaetze fuer Funktionen, die niemand per Sprache
/// nutzt, lassen keinen Raum fuer die, die zaehlen. Geblieben ist, was im Alltag
/// tatsaechlich gesprochen wird: Essen, Wasser und Kaffee (3 von 10 belegt).
///
/// **Alle uebrigen Intents bleiben nutzbar** — sie tauchen weiterhin in der
/// Kurzbefehle-App auf, nur ohne eigene Siri-Phrase. Wieder aufnehmen heisst
/// also: hier einen Eintrag ergaenzen, mehr nicht.
struct KalorienKompassShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // MARK: - Essen per Sprache (KI-Mehrfach-Eintrag, Fokus-Modus)
        AppShortcut(
            intent: AIFocusLogIntent(),
            phrases: [
                "Ich habe gegessen in \(.applicationName)",
                "Essen eintragen in \(.applicationName)",
                "Schnell erfassen in \(.applicationName)",
                "I just ate in \(.applicationName)",
                "Quick AI entry in \(.applicationName)",
                // Parameterisiert: Mahlzeit-Typ direkt im Satz
                "Ich habe zum \(\.$mealType) gegessen in \(.applicationName)",
                "Zum \(\.$mealType) eintragen in \(.applicationName)",
                "Log \(\.$mealType) in \(.applicationName)",
            ],
            shortTitle: "Essen per Sprache",
            systemImageName: "mic.fill"
        )

        // MARK: - Wasser hinzufuegen
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "Wasser trinken in \(.applicationName)",
                "Wasser hinzufügen in \(.applicationName)",
                "Ich hab Wasser getrunken in \(.applicationName)",
                "Trink Wasser in \(.applicationName)",
                "Glas Wasser in \(.applicationName)",

                "Log water in \(.applicationName)",
                "Drink water in \(.applicationName)",
                "Add water in \(.applicationName)"
            ],
            shortTitle: "Wasser trinken",
            systemImageName: "drop.fill"
        )

        // MARK: - Kaffee eintragen
        AppShortcut(
            intent: LogCoffeeIntent(),
            phrases: [
                "Kaffee trinken in \(.applicationName)",
                "Kaffee eintragen in \(.applicationName)",
                "Ich hab einen Kaffee getrunken in \(.applicationName)",
                "Eine Tasse Kaffee in \(.applicationName)",
                "Noch ein Kaffee in \(.applicationName)",

                "Log coffee in \(.applicationName)",
                "Add coffee in \(.applicationName)"
            ],
            shortTitle: "Kaffee trinken",
            systemImageName: "cup.and.saucer.fill"
        )
    }
}

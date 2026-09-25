//
//  WatchShortcuts.swift
//  KalorienKompassWatch
//
//  Erstellt von André Claaßen am 20.02.26.
//

#if os(watchOS)
import AppIntents

/// Die Siri-Phrasen der Uhr.
///
/// Gesprochen wird derselbe Weg wie auf dem iPhone: `AIFocusLogIntent` teilt
/// mehrere Speisen in einzelne Eintraege auf (Issue #73), leitet die Mahlzeit aus
/// der Uhrzeit ab, wenn keine genannt wird, und zeigt das Ergebnis als Snippet mit
/// Rueckgaengig (Issue #74). `AIQuickAddIntent` bleibt fuer die Kurzbefehle-App
/// erhalten, verliert hier aber seine Phrase: er buchte ohne Angabe alles als Snack.
struct KalorienKompassWatchShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AIFocusLogIntent(),
            phrases: [
                "Ich habe gegessen in \(.applicationName)",
                "Essen eintragen in \(.applicationName)",
                "Schnell erfassen in \(.applicationName)",
                "I just ate in \(.applicationName)",
                "Ich habe zum \(\.$mealType) gegessen in \(.applicationName)",
                "Zum \(\.$mealType) eintragen in \(.applicationName)",
                "Log \(\.$mealType) in \(.applicationName)",
            ],
            shortTitle: "Essen per Sprache",
            systemImageName: "mic.fill"
        )
    }
}
#endif

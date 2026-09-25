//
//  OpenQuickEntryIntent.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 20.07.26.
//
//  Oeffnet die App mit fokussiertem Eingabefeld — gedacht als Ziel fuer einen
//  Tastatur-Kurzbefehl. Den Hotkey vergibt die Shortcuts-App (bzw. Raycast oder
//  Alfred), nicht die App selbst: die macOS-App laeuft sandboxed
//  (ENABLE_APP_SANDBOX = YES), ein globaler CGEvent-Tap wie in `track` oder
//  `menubar-social` ist damit versperrt.
//

import AppIntents
import Foundation

/// App Intent: bringt die App nach vorn und setzt den Cursor ins Eingabefeld.
struct OpenQuickEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Schnelleingabe öffnen"
    static var description = IntentDescription(
        "Öffnet KalorienKompass mit fokussiertem Eingabefeld — bereit zum Tippen."
    )

    /// Bringt die App in den Vordergrund; ohne offenes Fenster erzeugt macOS eins.
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Ein Flag statt einer Notification, weil beim Tastendruck offen ist, ob die
        // App schon laeuft: eine Notification waere beim Kaltstart verpufft, bevor
        // `FocusInputView` ueberhaupt existiert. Das Flag beobachtet die View per
        // `onChange(initial: true)` und deckt damit beide Faelle ab.
        NavigationModel.shared.pendingQuickEntryFocus = true
        return .result()
    }
}

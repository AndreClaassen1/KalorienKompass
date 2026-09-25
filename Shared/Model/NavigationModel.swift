//
//  NavigationModel.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//
//  Navigationsmodell fuer den Fokus-Modus. Rein transient: seit dem Wegfall
//  des Vollmodus (Issue #66) gibt es keine Sidebar-Auswahl und keine
//  Spaltensichtbarkeit mehr, die einen Neustart ueberdauern muesste.
//

import SwiftUI

/// Navigationsmodell mit transientem Zustand
@Observable
final class NavigationModel {

    /// Singleton
    static let shared = NavigationModel()

    /// Zeigt die Lebensmittelsuche an
    var showFoodSearch = false

    /// Zeigt den Barcode-Scanner an (iPhone)
    var showBarcodeScanner = false

    /// Zeigt die KI-Schnelleingabe an (macOS: eigenes Fenster)
    var showAIQuickEntry = false

    /// Angeforderter Eingabefokus, der noch nicht zugestellt werden konnte.
    /// Wird von `OpenQuickEntryIntent` gesetzt: startet der Intent die App erst,
    /// existiert `FocusInputView` zum Zeitpunkt der Notification noch nicht.
    /// Die View holt das Flag in `onAppear` nach und raeumt es ab.
    var pendingQuickEntryFocus = false

    /// Zaehler: wird nach jedem gespeicherten Eintrag inkrementiert.
    /// Ermoeglicht einen Reload ohne Umweg ueber `showFoodSearch`.
    var entryAddedCount: Int = 0

    /// Ausgewaehlter Mahlzeitentyp fuer die Lebensmittelsuche
    var selectedMealTypeForSearch: MealType = .snack

    /// Ausgewaehltes Datum fuer die Lebensmittelsuche
    var selectedDateForSearch: Date = Date()
}

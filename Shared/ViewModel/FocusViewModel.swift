//
//  FocusViewModel.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 13.07.26.
//
//  ViewModel des minimalistischen Fokus-Modus: nimmt Freitext entgegen, laesst
//  ihn von der KI als EINEN Eintrag schaetzen (ein Produkt = ein Eintrag),
//  bucht ihn sofort in die Rubrik und haelt ihn fuer "Rueckgaengig" bereit.
//

import SwiftUI
import SwiftData
import WidgetKit
import os
#if canImport(UIKit)
import UIKit
#endif

@Observable
@MainActor
final class FocusViewModel {
    private static let logger = Logger(subsystem: "com.andre.claassen.KalorienKompass", category: "FocusViewModel")
    private let modelContext: ModelContext

    /// Eingabetext (Sprache folgt in Etappe 2)
    var inputText: String = ""

    /// Laeuft gerade eine KI-Anfrage?
    var isLoading: Bool = false

    /// Fehlermeldung fuer die UI
    var errorMessage: String?

    /// Vom Nutzer vorab gewaehlte Rubrik — erzwingt die Mahlzeit fuer die naechste Eingabe
    var contextMeal: MealType?

    /// Planungsmodus (Issue #99): die naechste Eingabe wird nicht gebucht,
    /// sondern als geplanter Eintrag abgelegt. Gilt fuer alle Eingabewege
    /// (Text, Diktat, Foto) und springt nach einem erfolgreichen Plan von
    /// selbst zurueck — Erfassen bleibt der Normalfall.
    var planningMode: Bool = false

    /// Zuletzt gebuchte Mahlzeit — loest die Hervorhebung des Hebels aus,
    /// wenn abends ein Snack oder Abendessen dazukommt.
    private(set) var lastBookedMeal: MealType?

    /// entryIds der zuletzt gebuchten Charge (fuer Rueckgaengig)
    private(set) var lastBatchEntryIds: [String] = []

    /// itemIds der zuletzt gebuchten Schnell-FoodItems (mit-Loeschen bei Rueckgaengig)
    private var lastBatchFoodItemIds: [String] = []

    var hasAPIKey: Bool { KeychainHelper.hasAPIKey }

    var canUndo: Bool { !lastBatchEntryIds.isEmpty }

    /// Ist der aktuelle Eingabetext absendbar (nicht leer, keine laufende Anfrage)?
    var canSubmit: Bool {
        !isLoading && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Eingabe verarbeiten

    /// Schaetzt den Eingabetext per KI als EINEN Eintrag und bucht ihn fuer das Datum.
    func submit(date: Date) async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        await submitEstimate(date: date) {
            try await ClaudeAPIService.shared.estimateMeal(description: text)
        }
        // Eingabefeld nur bei Erfolg leeren (bei Fehler bleibt der Text erhalten)
        if errorMessage == nil { inputText = "" }
    }

    #if canImport(UIKit) && !os(watchOS)
    /// Bucht ein Kamera-Foto direkt aus dem UIImage, optional mit Textnotiz als userHint
    /// (Kontext/Korrektur gegen Fehlinterpretation). Der Service skaliert und komprimiert
    /// EINMAL (kein Vorab-jpegData auf dem Main-Actor). Direkt gebucht, Korrektur via Undo.
    func submit(image: UIImage, note: String?, date: Date) async {
        let hint = Self.cleanedHint(note)
        await submitEstimate(date: date) {
            [try await ClaudeAPIService.shared.analyzeFood(image: image, userHint: hint)]
        }
        // Eingabefeld leeren, da sein Text als Notiz-Vorbelegung diente
        if errorMessage == nil { inputText = "" }
    }
    #endif

    /// Analysiert Bilddaten (Fotomediathek) per KI, optional mit Textnotiz als userHint.
    func submit(imageData: Data, note: String?, date: Date) async {
        guard !imageData.isEmpty else { return }
        let hint = Self.cleanedHint(note)
        await submitEstimate(date: date) {
            [try await ClaudeAPIService.shared.analyzeFood(imageData: imageData, userHint: hint)]
        }
        if errorMessage == nil { inputText = "" }
    }

    /// Trimmt eine optionale Notiz; leere Eingabe wird zu nil (kein userHint).
    private static func cleanedHint(_ note: String?) -> String? {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Mahlzeit, in der die naechste Eingabe landet. Beim Planen zaehlt nicht die
    /// jetzige, sondern die naechste Hauptmahlzeit; eine explizit gewaehlte Rubrik
    /// geht immer vor. Die Eingabezeile zeigt diesen Wert an, damit die Zuordnung
    /// vor dem Buchen sichtbar ist und nicht erst in der Liste auffaellt (#114).
    var targetMeal: MealType {
        contextMeal
            ?? (planningMode ? MealType.planningTargetBasedOnTime : MealType.currentBasedOnTime)
    }

    /// Gemeinsames Geruest aller Eingabewege (Text, Kamera, Mediathek): Loading/Fehler
    /// setzen, Schaetzung holen, als EINEN Eintrag buchen, Kontext zuruecksetzen. Wie beim
    /// Text-Pfad wird direkt gebucht (kein Zwischenscreen); Korrekturen laufen ueber das
    /// "Rueckgaengig"-Banner bzw. den Bearbeiten-Sheet. Die Estimate-Quelle kommt als Closure.
    private func submitEstimate(date: Date, using estimate: () async throws -> [AIFoodEstimate]) async {
        isLoading = true
        errorMessage = nil
        let meal = targetMeal
        do {
            let results = try await estimate()
            if planningMode {
                plan(estimates: results, meal: meal, date: date)
                planningMode = false
            } else {
                book(estimates: results, meal: meal, date: date)
            }
            contextMeal = nil
        } catch {
            // Bei Fehlern bleibt der Planungsmodus aktiv, damit der zweite
            // Versuch weiterhin plant statt zu buchen.
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Buchen

    /// Legt je Schaetzung einen FoodItem + DiaryEntry an.
    ///
    /// Mehrere Speisen aus einer Eingabe werden einzeln gebucht (Issue #73), damit
    /// sich jede fuer sich korrigieren laesst. Das Rueckgaengig fasst sie als Charge
    /// zusammen und nimmt die ganze Eingabe zurueck.
    private func book(estimates: [AIFoodEstimate], meal: MealType, date: Date) {
        guard !estimates.isEmpty else { return }

        let entries = estimates.map {
            FocusBooking.book(estimate: $0, meal: meal, date: date, context: modelContext)
        }
        lastBookedMeal = meal
        lastBatchEntryIds = entries.map(\.entryId)
        lastBatchFoodItemIds = entries.compactMap { $0.foodItem?.itemId }
        WidgetCenter.shared.reloadAllTimelines()
        Self.logger.info("Fokus-Charge gebucht: \(entries.count, privacy: .public) Eintraege")
    }

    /// Legt statt einer Buchung einen Plan an (Issue #99). Bewusst ohne
    /// Undo-Banner, Widget-Reload und Hebel-Trigger: ein Plan zaehlt nirgends
    /// und laesst sich in der Tagesansicht direkt verwerfen.
    private func plan(estimates: [AIFoodEstimate], meal: MealType, date: Date) {
        guard !estimates.isEmpty else { return }
        FocusBooking.plan(estimates: estimates, meal: meal, date: date, context: modelContext)
        Self.logger.info("Fokus-Plan angelegt: \(estimates.count, privacy: .public) Komponenten")
    }

    // MARK: - Rueckgaengig

    /// Loescht den zuletzt gebuchten Eintrag.
    func undoLastBatch() {
        guard !lastBatchEntryIds.isEmpty else { return }
        FocusBooking.undo(
            entryIds: lastBatchEntryIds,
            foodItemIds: lastBatchFoodItemIds,
            context: modelContext
        )
        clearUndo()
        WidgetCenter.shared.reloadAllTimelines()
        Self.logger.info("Fokus-Charge rueckgaengig gemacht")
    }

    /// Vergisst die Undo-Charge (z.B. nach Tageswechsel oder manueller Aenderung).
    func clearUndo() {
        lastBatchEntryIds = []
        lastBatchFoodItemIds = []
    }
}

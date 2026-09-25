//
//  FocusInputView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 13.07.26.
//
//  Eingabebereich des Fokus-Modus: Textfeld plus Mikrofon-Button fuer
//  On-Device-Diktat (SFSpeechRecognizer, iOS + macOS).
//

import SwiftUI

struct FocusInputView: View {
    @Bindable var viewModel: FocusViewModel
    /// Wird ausgeloest, wenn der Nutzer senden moechte
    let onSubmit: () -> Void
    /// Oeffnet die Einstellungen (fuer den "KI-Schluessel fehlt"-Zustand)
    let onOpenSettings: () -> Void
    /// Oeffnet die Live-Kamera fuer ein Mahlzeiten-Foto (nur iOS)
    let onTakePhoto: () -> Void
    /// Oeffnet die Fotomediathek zur Auswahl eines Mahlzeiten-Bildes
    let onPickFromLibrary: () -> Void
    /// Oeffnet den Barcode-Scanner (nur iOS)
    let onScanBarcode: () -> Void
    /// Oeffnet die Lebensmitteldatenbank-Suche (iOS + macOS)
    let onSearchDatabase: () -> Void

    @FocusState private var textFieldFocused: Bool
    @State private var dictation = DictationService()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.hasAPIKey {
                inputCard
            } else {
                missingKeyCard
            }

            mealChip

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if let dictError = dictation.errorMessage {
                VStack(alignment: .leading, spacing: 6) {
                    Label(dictError, systemImage: "mic.slash")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                    if dictation.deniedPermission != nil {
                        Button("dictation_open_system_settings") {
                            dictation.openSystemSettings()
                        }
                        .font(.footnote)
                    }
                }
            }
        }
        #if os(macOS)
        // Auf dem Mac steht der Cursor beim Start im Eingabefeld (Issue #83): die
        // Schnelleingabe ist der Hauptweg in die App, ein Klick davor ist unnoetig.
        // Der kurze Nachlauf ist noetig, weil das Fenster beim ersten Zeichnen noch
        // nicht Key-Window ist und die Fokusanforderung sonst verpufft.
        // Auf iOS bewusst nicht: dort schoebe sich die Tastatur sofort ueber den Tag.
        .task {
            guard viewModel.hasAPIKey else { return }
            try? await Task.sleep(for: .milliseconds(300))
            textFieldFocused = true
        }
        #endif
        // Fokusanforderung aus `OpenQuickEntryIntent` (Tastenkombination). `initial: true`
        // deckt den Kaltstart ab — dann wurde das Flag gesetzt, bevor es diese View gab.
        .onChange(of: NavigationModel.shared.pendingQuickEntryFocus, initial: true) { _, pending in
            guard pending else { return }
            NavigationModel.shared.pendingQuickEntryFocus = false
            guard viewModel.hasAPIKey else { return }
            textFieldFocused = true
        }
        // macOS-Menue: Feld fokussieren bzw. Diktat starten/stoppen
        .onReceive(NotificationCenter.default.publisher(for: .focusInputFocus)) { _ in
            textFieldFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusDictateToggle)) { _ in
            guard viewModel.hasAPIKey else { return }
            textFieldFocused = true
            toggleDictation()
        }
    }

    // MARK: - Eingabekarte

    private var inputCard: some View {
        HStack(alignment: inputRowAlignment, spacing: 8) {
            // "+"-Menue: sekundaere Eingaben (Foto), bewusst links, damit Text und
            // Sprache rechts die sichtbaren Hauptwege bleiben. Erweiterungspunkt fuer
            // spaeter (Barcode, Favoriten).
            addMenu

            TextField(
                placeholderKey,
                text: $viewModel.inputText,
                axis: .vertical
            )
            .lineLimit(1...4)
            .textFieldStyle(.plain)
            #if os(macOS)
            // Auf dem Mac etwas groesser fuer bessere Lesbarkeit (~+15 %)
            .font(.title3)
            #endif
            .focused($textFieldFocused)
            .disabled(viewModel.isLoading)
            .onSubmit(submitIfPossible)
            #if os(iOS)
            // Accessory oberhalb der Tastatur zum manuellen Ausblenden
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        textFieldFocused = false
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                    }
                    .accessibilityLabel(Text("focus_dismiss_keyboard"))
                }
            }
            #endif

            // Planungsmodus (Issue #99): die naechste Eingabe wird geplant statt
            // gebucht. Der aktive Zustand faerbt Feldrahmen, Placeholder und
            // Senden-Symbol, damit kein Versehen passiert.
            Button {
                viewModel.planningMode.toggle()
            } label: {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 22))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(viewModel.planningMode ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.secondary))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
            .accessibilityLabel(Text("focus_plan_toggle"))
            .help(Text("focus_plan_toggle"))

            // Mikrofon: Diktat starten/stoppen
            Button(action: toggleDictation) {
                Image(systemName: dictation.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(dictation.isRecording ? Color.red : Color.secondary)
                    .symbolEffect(.pulse, isActive: dictation.isRecording)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
            .help(dictation.isRecording ? Text("dictation_stop") : Text("dictation_start"))

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 34, height: 34)
            } else {
                Button(action: submitIfPossible) {
                    Image(systemName: viewModel.planningMode ? "calendar.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                // Waehrend des Diktats bedienbar: der Tipp beendet die Aufnahme und
                // sendet in einem Zug, statt erst das Mikrofon stoppen zu verlangen
                // (Issue #75).
                .disabled(!viewModel.canSubmit)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .padding(12)
        #if os(macOS)
        // Auf dem Mac bewusst hoeher: mehr Eingabeflaeche, Inhalt vertikal zentriert
        // (die Zeilenausrichtung .center sorgt fuer den mittigen Platzhalter).
        .frame(minHeight: 88)
        #endif
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            if viewModel.planningMode {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.tint, lineWidth: 1.5)
            }
        }
    }

    /// Vertikale Ausrichtung der Eingabezeile: mittig, damit der Platzhalter/Text
    /// vertikal zentriert steht (statt am unteren Rand).
    private var inputRowAlignment: VerticalAlignment { .center }

    /// Placeholder je Modus: „Was hast du gegessen?" bzw. „Was planst du?"
    private var placeholderKey: LocalizedStringKey {
        viewModel.planningMode ? "focus_plan_placeholder" : "focus_input_placeholder"
    }

    // MARK: - Hinzufuegen-Menue

    /// "+"-Menue links im Eingabefeld. Buendelt die sekundaeren Eingabewege, ohne
    /// die Leiste mit Buttons zu ueberladen. Auf macOS entfaellt die Live-Kamera.
    private var addMenu: some View {
        Menu {
            #if os(iOS)
            Button {
                onTakePhoto()
            } label: {
                Label("focus_add_photo", systemImage: "camera")
            }
            #endif
            Button {
                onPickFromLibrary()
            } label: {
                Label("focus_add_library", systemImage: "photo")
            }
            #if os(iOS)
            Button {
                onScanBarcode()
            } label: {
                Label("focus_add_barcode", systemImage: "barcode.viewfinder")
            }
            #endif
            Button {
                onSearchDatabase()
            } label: {
                Label("focus_add_search", systemImage: "magnifyingglass")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 30))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.secondary)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
        .accessibilityLabel(Text("focus_add_menu"))
        .help(Text("focus_add_menu"))
    }

    // MARK: - Kein API-Key

    private var missingKeyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("focus_missing_key_title", systemImage: "key.slash")
                .font(.headline)
            Text("focus_missing_key_hint")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("focus_open_settings", action: onOpenSettings)
                .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Mahlzeiten-Chip

    /// Zeigt dauerhaft, wohin die naechste Eingabe geht, und aendert es per Klick.
    /// Vorher erschien hier nur dann etwas, wenn zuvor eine Rubrik angetippt
    /// worden war; die Zuordnung aus der Uhrzeit blieb unsichtbar, und ein spaet
    /// getipptes Fruehstueck landete unbemerkt im zweiten Fruehstueck (#114).
    private var mealChip: some View {
        MealPickerMenu(
            current: viewModel.contextMeal,
            allowsAutomatic: true,
            onSelect: { viewModel.contextMeal = $0 }
        ) {
            HStack(spacing: 6) {
                // Im Planungsmodus steht die Uhr fuer die naechste Hauptmahlzeit,
                // sonst das Symbol der Mahlzeit selbst.
                Image(systemName: viewModel.planningMode
                      ? "calendar.badge.clock"
                      : viewModel.targetMeal.symbolName)
                Text(viewModel.targetMeal.localizedName)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.footnote)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.tint.opacity(0.15), in: Capsule())
        }
        #if os(macOS)
        // BorderlessButtonMenuStyle gibt es nur auf dem Mac; auf iOS traegt der
        // Standardstil die Pille bereits ohne zusaetzliche Umrandung.
        .menuStyle(.borderlessButton)
        #endif
        .menuIndicator(.hidden)
        .fixedSize()
        // Gewaehlt faerbt kraeftiger als die Vorgabe nach Uhrzeit.
        .foregroundStyle(viewModel.contextMeal == nil ? .secondary : .primary)
    }

    private func submitIfPossible() {
        guard viewModel.canSubmit else { return }

        // Laeuft noch ein Diktat, wird es zuerst beendet. Das letzte Erkennungs-
        // ergebnis trifft mit kurzem Verzug ein; ohne diese Nachlaufzeit fehlt
        // regelmaessig das zuletzt gesprochene Wort (Issue #75).
        guard dictation.isRecording else {
            send()
            return
        }
        dictation.stop()
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            if viewModel.canSubmit { send() }
        }
    }

    private func send() {
        onSubmit()
        // Auf iPhone die Tastatur nach dem Absenden ausblenden
        textFieldFocused = false
    }

    /// Startet bzw. stoppt das Diktat. Der erkannte Text wird an einen bereits
    /// vorhandenen Eingabetext angehaengt (wie "Diktat einfuegen" in Drafts).
    private func toggleDictation() {
        if dictation.isRecording {
            dictation.stop()
            return
        }
        let existing = viewModel.inputText
        Task {
            await dictation.start { transcript in
                viewModel.inputText = DictationService.merged(existing: existing, transcript: transcript)
            }
        }
    }
}

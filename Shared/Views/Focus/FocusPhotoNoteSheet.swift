//
//  FocusPhotoNoteSheet.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 17.07.26.
//
//  Kleines Sheet nach Foto-Aufnahme/-Auswahl im Fokus-Modus: zeigt das Foto und
//  ein optionales Textfeld, dessen Inhalt als userHint an die KI-Analyse geht. So
//  laesst sich die haeufige Fehlinterpretation reiner Fotos vermeiden, indem man
//  Kontext oder eine Korrektur mitgibt. Leeres Feld = Foto wird allein analysiert.
//

import SwiftUI

struct FocusPhotoNoteSheet: View {
    /// Vorschau des aufgenommenen/ausgewaehlten Fotos (plattformneutral vom Aufrufer gebaut)
    let preview: Image
    /// Wird mit der optionalen Notiz aufgerufen (nil, wenn leer) — startet die Analyse
    let onAnalyze: (String?) -> Void
    /// Wird beim Abbrechen aufgerufen (Foto verwerfen, nicht buchen)
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var note: String
    @FocusState private var noteFocused: Bool

    init(
        preview: Image,
        initialNote: String = "",
        onAnalyze: @escaping (String?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.preview = preview
        self.onAnalyze = onAnalyze
        self.onCancel = onCancel
        _note = State(initialValue: initialNote)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                preview
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .clipped()

                TextField("focus_photo_note_placeholder", text: $note, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .focused($noteFocused)
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                Text("focus_photo_note_hint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("focus_photo_note_title")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        onCancel()
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("focus_photo_analyze") {
                        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        onAnalyze(trimmed.isEmpty ? nil : trimmed)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, idealWidth: 440, minHeight: 420, idealHeight: 540)
        #endif
    }
}

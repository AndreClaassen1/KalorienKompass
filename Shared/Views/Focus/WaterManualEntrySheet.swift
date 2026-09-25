//
//  WaterManualEntrySheet.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 05.02.26.
//

import SwiftUI

/// Sheet fuer manuelle Wassereingabe
struct WaterManualEntrySheet: View {
    let currentMl: Int
    let onSave: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var inputText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("water_manual_entry", text: $inputText)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }
                Section {
                    Text("\(currentMl) ml")
                        .foregroundStyle(.secondary)
                } header: {
                    Text("water_title")
                }
            }
            .navigationTitle("water_manual_entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("weight_save") {
                        if let value = Int(inputText), value >= 0 {
                            onSave(value)
                            dismiss()
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(Int(inputText) == nil)
                }
            }
        }
    }
}


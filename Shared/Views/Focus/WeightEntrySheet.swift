//
//  WeightEntrySheet.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 05.02.26.
//

import SwiftUI

/// Sheet fuer Gewichtseingabe
struct WeightEntrySheet: View {
    let currentWeight: Double?
    let onSave: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var inputText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("weight_enter", text: $inputText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                } header: {
                    Text("weight_title")
                }
                #if canImport(HealthKit)
                Section {
                    Label("weight_healthkit_hint", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                #endif
            }
            .navigationTitle("weight_enter")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("weight_save") {
                        let normalized = inputText.replacingOccurrences(of: ",", with: ".")
                        if let value = Double(normalized), value > 0 {
                            onSave(value)
                            dismiss()
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled({
                        let normalized = inputText.replacingOccurrences(of: ",", with: ".")
                        return Double(normalized) == nil
                    }())
                }
            }
            .onAppear {
                if let weight = currentWeight {
                    inputText = String(format: "%.1f", weight)
                }
            }
        }
    }
}


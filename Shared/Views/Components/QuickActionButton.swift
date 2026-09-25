//
//  QuickActionButton.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import SwiftUI

/// Schnellaktions-Button mit Liquid Glass Effekt
struct QuickActionButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.bold())
        }
        .buttonStyle(.glass)
    }
}

#Preview {
    HStack(spacing: 12) {
        QuickActionButton(title: "action_add_food", systemImage: "plus") {}
        QuickActionButton(title: "action_scan_barcode", systemImage: "barcode.viewfinder") {}
    }
    .padding()
}

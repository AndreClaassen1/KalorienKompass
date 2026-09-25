//
//  ShortcutButton.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 20.07.26.
//

#if os(macOS)
import SwiftUI

/// Unsichtbarer Button, der ausschliesslich eine Tastenkombination bereitstellt.
///
/// Gedacht fuer das Menubar-Popover: dessen Bedienelemente (Wasserglaeser als `ForEach`)
/// bieten keinen einzelnen Button, an den sich ein Shortcut haengen liesse, und das
/// Popover ist eine eigene Scene — `FocusMenuCommands` erreicht es nicht.
/// Per `.background { … }` einhaengen, dort beeinflusst er das Layout nicht.
struct ShortcutButton: View {
    let key: KeyEquivalent
    var modifiers: EventModifiers = .command
    let action: () -> Void

    var body: some View {
        Button("", action: action)
            .keyboardShortcut(key, modifiers: modifiers)
            .opacity(0)
            .accessibilityHidden(true)
    }
}
#endif

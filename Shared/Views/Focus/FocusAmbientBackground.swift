//
//  FocusAmbientBackground.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 15.07.26.
//
//  Stimmungsvoller Hintergrund fuer die Fokus-Ansicht (macOS 26 / Liquid Glass):
//  ein tageszeitabhaengiges, weichgezeichnetes Foto, ueberlagert von einem
//  dezenten Score-Farbschleier (softLight) und einem Milchglas-Veil, das den
//  Content jederzeit lesbar haelt.
//

import SwiftUI

struct FocusAmbientBackground: View {
    /// Ambient-Farbe des aktuellen Tages-Scores
    let scoreColor: Color
    /// Referenzzeit fuer die Tageszeit-Auswahl (Standard: jetzt)
    var referenceDate: Date = Date()

    @Environment(\.colorScheme) private var colorScheme

    private enum Daypart {
        case morning, noon, evening, night
        var assetName: String {
            switch self {
            case .morning: "AmbientMorning"
            case .noon:    "AmbientNoon"
            case .evening: "AmbientEvening"
            case .night:   "AmbientNight"
            }
        }
    }

    private var daypart: Daypart {
        switch Calendar.current.component(.hour, from: referenceDate) {
        case 5..<11:  .morning
        case 11..<17: .noon
        case 17..<21: .evening
        default:      .night
        }
    }

    var body: some View {
        ZStack {
            Image(daypart.assetName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: 30, opaque: true)

            // Score-Farbe sanft ins Foto einweben
            scoreColor
                .opacity(0.42)
                .blendMode(.softLight)

            // Milchglas-Veil: haelt Text lesbar, laesst das Foto durchschimmern
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(colorScheme == .dark ? 0.60 : 0.55)

            // Scrim nach unten: hellt (Light) bzw. dunkelt (Dark) den unteren
            // Bildbereich, wo das Foto dunkler wird. So bleibt die Mahlzeitenliste
            // dort lesbar, ohne den oberen (vivid gehaltenen) Bereich zu ueberdecken.
            LinearGradient(
                colors: [.clear, Color(white: colorScheme == .dark ? 0 : 1).opacity(0.38)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.7), value: scoreColor)
    }
}

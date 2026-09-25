//
//  CalorieComplicationView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 01.09.26.
//
//  Der Kalorienstand als Komplikation, in den drei accessory-Formen.
//  Geteilt vom iOS-Sperrbildschirm (CalorieLockScreenWidget) und vom
//  Watch-Ziffernblatt (CalorieWidget); beide Seiten zeigen damit dieselben Zahlen
//  in derselben Schreibweise.
//
//  Liegt in genau diesen beiden Widget-Extensions, NICHT im App-Target: die App
//  zeigt ihren Kalorienstand ueber CalorieHeroView.
//

// Siehe CalorieLockScreenWidget: auf macOS fehlen die accessory-Familien.
#if os(iOS) || os(watchOS)

import SwiftUI
import WidgetKit

/// Woher die Komplikation ihre Farbe nimmt.
enum CalorieComplicationTint {
    /// Das System faerbt selbst. So ist es auf dem iOS-Sperrbildschirm: eine eigene
    /// Farbe kaeme dort nicht durch, deshalb traegt allein der Text die Ueberschreitung.
    /// Diese Wahl bitte nicht "vereinheitlichen" — sie ist der Grund fuer den Parameter.
    case system
    /// Gruen im Rahmen, Rot bei Ueberschreitung. So zeigt es das Watch-Ziffernblatt.
    case status
}

/// Kalorienstand fuer accessoryCircular, accessoryRectangular und accessoryInline.
struct CalorieComplicationView: View {
    @Environment(\.widgetFamily) private var family

    let eaten: Double
    let goal: Int
    /// Bewusst ohne Vorbelegung: die Wahl gehoert an jede Aufrufstelle, siehe oben.
    let tint: CalorieComplicationTint

    @ViewBuilder
    var body: some View {
        switch family {
        case .accessoryRectangular:
            rectangular
        case .accessoryInline:
            inline
        default:
            circular
        }
    }

    // MARK: - Formen

    private var circular: some View {
        Gauge(value: progress) {
            Image(systemName: "fork.knife")
        } currentValueLabel: {
            // Im Ring ist kein Platz fuer "drueber", also traegt das Pluszeichen
            // die Ueberschreitung.
            signedRemaining
                .font(.system(size: 18, weight: .bold))
                .minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircular)
        .tint(statusColor)
        .widgetAccentable()
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Restkalorien oben — wichtigster Wert
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(magnitude, format: .number)
                    .font(.title2.bold())
                    .foregroundStyle(statusColor ?? .primary)
                    .minimumScaleFactor(0.6)
                    .widgetAccentable()
                Text("kcal \(suffix)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Gauge(value: progress) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinear)
            .tint(statusColor)
            .widgetAccentable()

            // Gegessen / Ziel unten
            HStack(spacing: 4) {
                Image(systemName: "fork.knife")
                    .font(.caption2)
                    .widgetAccentable()
                Text("\(eatenRounded.formatted()) / \(goal.formatted()) kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var inline: some View {
        Label {
            Text("\(magnitude.formatted()) kcal \(suffix)")
        } icon: {
            Image(systemName: "fork.knife")
        }
    }

    // MARK: - Anzeigewerte

    /// Abgeleitet statt uebergeben, damit Ring und Zahl nicht auseinanderlaufen koennen.
    private var remaining: Int {
        Int(NutrientCalculator.remainingCalories(consumed: eaten, goal: goal).rounded())
    }

    private var eatenRounded: Int {
        Int(eaten.rounded())
    }

    private var isOverBudget: Bool {
        remaining < 0
    }

    /// Betrag der Restkalorien; das Vorzeichen tragen Suffix bzw. Pluszeichen.
    private var magnitude: Int {
        abs(remaining)
    }

    /// Anteil des Tagesziels, gekappt bei 1.0. Die Kappung verwirft, um wie viel ein
    /// Ziel ueberschritten wurde; diesen Teil zeigt der Text.
    private var progress: Double {
        min(NutrientCalculator.progress(consumed: eaten, goal: goal), 1.0)
    }

    /// Restkalorien mit Pluszeichen bei Ueberschreitung, fuer Anzeigen ohne Suffix.
    private var signedRemaining: Text {
        let number = Text(magnitude, format: .number)
        return isOverBudget ? Text(verbatim: "+") + number : number
    }

    /// "uebrig" bzw. "drueber", je nach Vorzeichen
    private var suffix: String {
        isOverBudget
            ? String(localized: "widget_over")
            : String(localized: "calories_remaining")
    }

    private var statusColor: Color? {
        switch tint {
        case .system: nil
        case .status: isOverBudget ? .red : .green
        }
    }
}

#endif

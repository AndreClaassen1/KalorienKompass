//
//  FocusWeekStrip.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 28.07.26.
//
//  Wochenleiste ueber dem Kalorienring (Issue #81): sieben Tage, der gewaehlte
//  als gefuellte Pille, darunter je ein schmaler Balken fuer das verbrauchte
//  Budget. Die Leiste macht die Wischgeste sichtbar — eine Geste, die niemand
//  ankuendigt, findet auch niemand.
//

import SwiftUI

struct FocusWeekStrip: View {
    let days: [DayViewModel.WeekDay]
    let selectedDate: Date

    /// Fortschritt der laufenden Wischgeste, -1 bis 1. Positiv heisst vorwaerts:
    /// die Pille wandert mit dem Finger nach rechts, noch bevor der Tag wechselt.
    var dragProgress: CGFloat = 0

    let onSelect: (Date) -> Void

    /// Hoehe der Balkenspur. Bewusst schmal: sie soll den Verlauf zeigen, nicht
    /// mit dem Kalorienring darunter um Aufmerksamkeit ringen.
    private let barWidth: CGFloat = 26
    private let barHeight: CGFloat = 3

    private var selectedIndex: Int {
        days.firstIndex { $0.date.isSameDay(as: selectedDate) } ?? 0
    }

    /// Die Pille darf die Leiste nicht verlassen, auch wenn ueber die
    /// Wochengrenze hinaus gezogen wird.
    private var clampedProgress: CGFloat {
        let lower = -CGFloat(selectedIndex)
        let upper = CGFloat(max(days.count - 1 - selectedIndex, 0))
        return min(max(dragProgress, lower), upper)
    }

    var body: some View {
        GeometryReader { geo in
            let cell = geo.size.width / CGFloat(max(days.count, 1))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.primary.opacity(0.07))
                    .frame(width: max(cell - 6, 0))
                    .offset(x: cell * (CGFloat(selectedIndex) + clampedProgress) + 3)

                HStack(spacing: 0) {
                    ForEach(days) { day in
                        dayCell(day)
                            .frame(width: cell)
                    }
                }
            }
        }
        .frame(height: 52)
        .padding(.horizontal, 12)
    }

    // MARK: - Einzelner Tag

    private func dayCell(_ day: DayViewModel.WeekDay) -> some View {
        Button {
            onSelect(day.date)
        } label: {
            VStack(spacing: 2) {
                Text(day.date.shortWeekdayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(day.date.dayOfMonth, format: .number)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(numberStyle(day.date))
                budgetBar(day)
            }
            .padding(.vertical, 7)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityValue(accessibilityValue(day))
        .accessibilityAddTraits(day.date.isSameDay(as: selectedDate) ? [.isButton, .isSelected] : .isButton)
    }

    /// Balken unter der Zahl: die Laenge ist das verbrauchte Budget, die Farbe die
    /// Tagesbewertung. Zwei Kanaele fuer dieselbe Aussage, damit sie auch dann
    /// lesbar bleibt, wenn die Farben nicht unterschieden werden.
    private func budgetBar(_ day: DayViewModel.WeekDay) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.quaternary)
                .frame(width: barWidth, height: barHeight)
            Capsule()
                .fill(day.score.color)
                .frame(width: barWidth * day.fill, height: barHeight)
        }
    }

    /// Heute bleibt erkennbar, auch wenn ein anderer Tag gewaehlt ist. Tage in der
    /// Zukunft treten zurueck — dort ist naturgemaess noch nichts erfasst.
    private func numberStyle(_ date: Date) -> HierarchicalShapeStyle {
        if date.isToday { return .primary }
        return date.startOfDay > Date().startOfDay ? .tertiary : .secondary
    }

    private func accessibilityValue(_ day: DayViewModel.WeekDay) -> Text {
        guard day.hasEntries else { return Text(verbatim: "") }
        return Text(day.budgetShare, format: .percent.precision(.fractionLength(0)))
    }
}

#Preview("Wochenleiste") {
    let today = Date().startOfDay
    let days = today.weekDays.enumerated().map { index, date in
        DayViewModel.WeekDay(
            date: date,
            eatenCalories: [1980, 1450, 2380, 0, 1620, 2050, 1180][index % 7],
            calorieGoal: 2100,
            hasEntries: index != 3
        )
    }
    return FocusWeekStrip(days: days, selectedDate: today) { _ in }
        .padding(.vertical)
}

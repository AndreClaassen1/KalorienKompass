//
//  FocusLeverBar.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 20.07.26.
//
//  Bringt den aktuellen Hebel dorthin, wo gehandelt wird — als eigene,
//  prominente Sektion im Zitat-Stil, so sichtbar wie das Eingabefeld. Zu den
//  Trigger-Zeiten (Abend oder frisch gebuchter Snack) wird er zusaetzlich
//  farblich hervorgehoben. Ohne aktiven Hebel erscheint nichts.
//

import SwiftUI

struct FocusLeverBar: View {
    @Bindable var viewModel: FocusLeverViewModel

    /// Zuletzt gebuchte Mahlzeit — loest die Hervorhebung unabhaengig von der Uhrzeit aus
    let lastBookedMeal: MealType?

    /// Tap auf Kopf oder Zitat oeffnet die Detailansicht
    let onOpenDetail: () -> Void

    /// Gedraengte Fassung fuer das iPhone im Querformat (Issue #85): dort steht die
    /// Karte neben den Vitals-Kacheln und muss deren Hoehe halten. Sektionskopf und
    /// Trennlinie entfallen, das Zitat bricht nach zwei Zeilen ab. Der Hebel bleibt
    /// dabei vollstaendig bedienbar, nur der Rahmen drumherum wird knapper.
    var isCompact: Bool = false

    var body: some View {
        if let lever = viewModel.displayedLever {
            if isCompact {
                compactCard(lever)
            } else {
                card(lever)
            }
        }
    }

    private func card(_ lever: FocusLever) -> some View {
        let highlighted = viewModel.isHighlighted(lastBookedMeal: lastBookedMeal)
        return VStack(alignment: .leading, spacing: 12) {
            Button(action: onOpenDetail) {
                VStack(alignment: .leading, spacing: 10) {
                    // Sektions-Kopf
                    HStack(spacing: 6) {
                        Image(systemName: "target")
                        Text("focus_lever_title")
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.forward")
                            .foregroundStyle(.tertiary)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    // Zitat
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "quote.opening")
                            .font(.title)
                            .foregroundStyle(highlighted ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                        Text(lever.text)
                            .font(.system(.body, design: .serif))
                            .italic()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            if let check = viewModel.todaysCheck {
                answeredRow(check)
            } else {
                askRow
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    /// Querformat: Zitat und Tagesfrage, sonst nichts. Die feste Hoehe ist die der
    /// Vitals-Kacheln nebenan — ohne sie stuende die Karte je nach Laenge des Zitats
    /// unterschiedlich hoch neben ihnen.
    private func compactCard(_ lever: FocusLever) -> some View {
        let highlighted = viewModel.isHighlighted(lastBookedMeal: lastBookedMeal)
        return VStack(alignment: .leading, spacing: 8) {
            Button(action: onOpenDetail) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "quote.opening")
                        .font(.title3)
                        .foregroundStyle(highlighted ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                    Text(lever.text)
                        .font(.system(.callout, design: .serif))
                        .italic()
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.forward")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            if let check = viewModel.todaysCheck {
                answeredRow(check)
            } else {
                askRow
            }
        }
        .padding(12)
        .frame(height: 112, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }

    /// Frage- bzw. Statustext tagesabhaengig: heute persoenlich ("Heute gehalten?"),
    /// beim Zurueckblaettern neutral ("Gehalten?" / "Gehalten" / "Nicht gehalten").
    private var questionKey: LocalizedStringKey {
        viewModel.isViewingToday ? "focus_lever_question" : "focus_lever_question_past"
    }

    private func stateKey(kept: Bool) -> LocalizedStringKey {
        if viewModel.isViewingToday {
            return kept ? "focus_lever_kept_state" : "focus_lever_missed_state"
        }
        return kept ? "focus_lever_kept" : "focus_lever_missed"
    }

    /// Offene Tagesfrage: gehalten oder nicht gehalten
    private var askRow: some View {
        HStack(spacing: 8) {
            Text(questionKey)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button("focus_lever_kept") { viewModel.answer(kept: true) }
                .font(.caption.bold())
            Button("focus_lever_missed") { viewModel.answer(kept: false) }
                .font(.caption.bold())
        }
        .buttonStyle(.bordered)
        #if os(iOS)
        .buttonBorderShape(.capsule)
        #endif
    }

    /// Bereits beantwortet — Tap korrigiert die Antwort
    private func answeredRow(_ check: FocusLeverCheck) -> some View {
        Button {
            viewModel.answer(kept: !check.kept)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: check.kept ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(check.kept ? .green : .orange)
                Text(stateKey(kept: check.kept))
                Spacer(minLength: 0)
                Text("focus_lever_correct")
                    .foregroundStyle(.tint)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

//
//  MenuBarQuickAddView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 06.04.26.
//

#if os(macOS)
import SwiftUI
import SwiftData
import WidgetKit

/// Kompakte KI-Schnelleingabe fuer das Menubar-Popover
struct MenuBarQuickAddView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var resultText: String?
    @State private var errorText: String?
    @FocusState private var inputFocused: Bool
    /// Ausdruecklich gewaehlte Mahlzeit; `nil` heisst „nach Uhrzeit" (#114).
    @State private var chosenMeal: MealType?

    private var targetMeal: MealType { chosenMeal ?? MealType.currentBasedOnTime }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                mealChip

                TextField("menubar_quick_add_placeholder", text: $inputText)
                    .textFieldStyle(.plain)
                    .focused($inputFocused)
                    .onSubmit { submitQuickAdd() }

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button(action: submitQuickAdd) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            if let result = resultText {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let error = errorText {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: resultText)
        .animation(.easeInOut(duration: 0.2), value: errorText)
        // ⌘N fokussiert das Eingabefeld — gleiche Taste wie "Essen eintragen"
        // im Hauptfenster (FocusMenuCommands).
        .background {
            ShortcutButton(key: "n") { inputFocused = true }
        }
    }

    private func submitQuickAdd() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isLoading = true
        errorText = nil
        resultText = nil

        Task {
            do {
                let estimates = try await ClaudeAPIService.shared.estimateMeal(description: text)
                saveEntries(estimates, date: Date())
                let kcal = Int(estimates.reduce(0) { $0 + $1.portionCalories })
                resultText = estimates.count == 1
                    ? "\(estimates[0].name) — \(kcal) kcal"
                    : "\(estimates.count) Eintraege — \(kcal) kcal"
                inputText = ""

                // Ergebnis nach 3 Sekunden ausblenden
                try? await Task.sleep(for: .seconds(3))
                resultText = nil
            } catch {
                errorText = error.localizedDescription
            }
            isLoading = false
        }
    }

    /// Zeigt, in welche Mahlzeit die Eingabe geht, und aendert es per Klick.
    /// Im Popover ist es eng, deshalb nur das Symbol; den Namen nennt der Tooltip.
    private var mealChip: some View {
        MealPickerMenu(
            current: chosenMeal,
            allowsAutomatic: true,
            onSelect: { chosenMeal = $0 }
        ) {
            HStack(spacing: 4) {
                Image(systemName: targetMeal.symbolName)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.caption)
            .foregroundStyle(chosenMeal == nil ? .secondary : .primary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(Text(targetMeal.localizedName))
    }

    /// Bucht jede erkannte Speise einzeln (Issue #73).
    private func saveEntries(_ estimates: [AIFoodEstimate], date: Date) {
        guard !estimates.isEmpty else { return }
        for estimate in estimates {
            FocusBooking.book(
                estimate: estimate,
                meal: targetMeal,
                date: date,
                context: modelContext
            )
        }
        chosenMeal = nil
        WidgetCenter.shared.reloadAllTimelines()
        NavigationModel.shared.entryAddedCount += 1
        MenuBarViewModel.shared.loadToday()
    }
}
#endif

//
//  DashboardView.swift
//  KalorienKompassWatch
//
//  Erstellt von André Claaßen am 06.02.26.
//

#if os(watchOS)
import SwiftUI
import SwiftData

/// Fokus-Screen der Watch: Kalorienring, prominenter Sprech-Button (Diktat-first),
/// kompakte Vitals und schnelle Wasser-Erfassung.
struct DashboardView: View {
    var viewModel: WatchDayViewModel
    @State private var showingWaterSheet = false
    /// Diktierter Text (Nutzlast) — praesentiert das KI-Sheet via .sheet(item:)
    @State private var voiceEntry: WatchDictation?
    /// Steuert das Undo-Banner nach einer Buchung
    @State private var showUndo = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Kalorienring
                CalorieRingView(
                    progress: viewModel.calorieProgress,
                    remaining: Int(viewModel.remainingCalories),
                    goal: viewModel.effectiveCalorieGoal
                )
                .frame(height: 100)

                // Diktat-first: Hauptaktion zum sofortigen Reinsprechen. TextFieldLink
                // oeffnet die native Watch-Eingabe (Diktat/Scribble/Tastatur).
                TextFieldLink(prompt: Text("watch_focus_speak")) {
                    Label("watch_focus_speak", systemImage: "mic.fill")
                        .font(.callout)
                        .frame(maxWidth: .infinity)
                } onSubmit: { text in
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    voiceEntry = WatchDictation(text: trimmed)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                // Undo-Banner nach einer Buchung
                if showUndo {
                    undoBanner
                }

                // Schritte und Wasser
                HStack(spacing: 8) {
                    // Schritte
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.walk")
                                .foregroundStyle(.green)
                            Text("\(viewModel.dayRecord?.steps ?? 0)")
                                .font(.headline)
                        }
                        ProgressView(value: min(viewModel.stepsProgress, 1.0))
                            .tint(.green)
                    }

                    // Wasser
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "drop.fill")
                                .foregroundStyle(.cyan)
                            Text("\(viewModel.dayRecord?.waterIntakeMl ?? 0) ml")
                                .font(.headline)
                        }
                        ProgressView(value: min(viewModel.waterProgress, 1.0))
                            .tint(.cyan)
                    }
                }

                // Aktueller Hebel samt Tagesrueckmeldung
                FocusLeverWatchCard(modelContext: viewModel.modelContext)

                // Wasser schnell erfassen
                Button {
                    showingWaterSheet = true
                } label: {
                    Label("water_label", systemImage: "drop.fill")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
        }
        .navigationTitle("focus_title")
        .sheet(item: $voiceEntry) { entry in
            AIWatchSheet(
                viewModel: viewModel,
                dictatedText: entry.text,
                onBooked: { withAnimation { showUndo = true } }
            )
        }
        .sheet(isPresented: $showingWaterSheet) {
            WaterSheet(viewModel: viewModel)
        }
        // Undo-Banner nach einigen Sekunden automatisch ausblenden
        .task(id: showUndo) {
            guard showUndo else { return }
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if !Task.isCancelled {
                withAnimation { showUndo = false }
            }
        }
    }

    // MARK: - Undo-Banner

    private var undoBanner: some View {
        HStack(spacing: 6) {
            Label("watch_focus_booked", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button {
                Task {
                    await viewModel.undoLast()
                    withAnimation { showUndo = false }
                }
            } label: {
                Label("watch_focus_undo", systemImage: "arrow.uturn.backward")
                    .font(.caption2)
            }
            .buttonStyle(.borderless)
            .tint(.cyan)
        }
        .padding(8)
        .background(.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    DashboardView(viewModel: WatchDayViewModel(modelContext: PreviewSampleData.container.mainContext))
}
#endif

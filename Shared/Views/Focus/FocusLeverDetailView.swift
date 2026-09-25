//
//  FocusLeverDetailView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 20.07.26.
//
//  Hebel setzen, Trigger konfigurieren, Adhaerenz der Woche ablesen
//  und die Historie abgeloester Hebel durchsehen.
//

import SwiftUI
import SwiftData

struct FocusLeverDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Wird als Sheet praesentiert (dann mit "Fertig"-Button) oder als NavigationLink-Ziel
    var isPresentedAsSheet: Bool = false

    @State private var viewModel: FocusLeverViewModel?
    @State private var draftText: String = ""
    @State private var triggerStartHour: Int = 20
    @State private var triggerOnSnack: Bool = true

    var body: some View {
        Group {
            if let viewModel {
                form(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("focus_lever_title")
        .onAppear(perform: setupIfNeeded)
        #if os(macOS)
        .frame(minWidth: 460, idealWidth: 520, minHeight: 480, idealHeight: 620)
        #endif
        .toolbar {
            if isPresentedAsSheet {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func form(_ viewModel: FocusLeverViewModel) -> some View {
        Form {
            currentSection(viewModel)
            triggerSection(viewModel)
            if let adherence = viewModel.currentWeekAdherence {
                weekSection(adherence)
            }
            if !viewModel.history.isEmpty {
                historySection(viewModel)
            }
            explanationSection
        }
        .formStyle(.grouped)
    }

    // MARK: - Aktueller Hebel

    @ViewBuilder
    private func currentSection(_ viewModel: FocusLeverViewModel) -> some View {
        Section("focus_lever_section_current") {
            TextField("focus_lever_placeholder", text: $draftText, axis: .vertical)
                .lineLimit(2...6)

            if let lever = viewModel.activeLever {
                LabeledContent("focus_lever_since") {
                    Text(lever.createdAt, format: .dateTime.day().month(.abbreviated).year())
                }
                if viewModel.isStale {
                    Label("focus_lever_stale_hint", systemImage: "clock.badge.exclamationmark")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Button("focus_lever_save") {
                viewModel.setLever(
                    text: draftText,
                    triggerStartHour: triggerStartHour,
                    triggerOnSnack: triggerOnSnack
                )
                syncDraft(from: viewModel)
            }
            .disabled(!canSave(viewModel))
        }
    }

    /// Speichern nur, wenn Text vorhanden ist und sich vom aktuellen unterscheidet.
    /// Trigger-Aenderungen laufen ueber `updateTrigger` und loesen den Hebel nicht ab.
    private func canSave(_ viewModel: FocusLeverViewModel) -> Bool {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed != viewModel.activeLever?.text
    }

    // MARK: - Trigger

    private func triggerSection(_ viewModel: FocusLeverViewModel) -> some View {
        Section {
            Picker("focus_lever_trigger_hour", selection: $triggerStartHour) {
                Text("focus_lever_trigger_always").tag(0)
                ForEach(6...23, id: \.self) { hour in
                    Text(verbatim: String(format: "%02d:00", hour)).tag(hour)
                }
            }
            .onChange(of: triggerStartHour) { _, newValue in
                viewModel.updateTrigger(startHour: newValue, onSnack: triggerOnSnack)
            }

            Toggle("focus_lever_trigger_snack", isOn: $triggerOnSnack)
                .onChange(of: triggerOnSnack) { _, newValue in
                    viewModel.updateTrigger(startHour: triggerStartHour, onSnack: newValue)
                }
        } header: {
            Text("focus_lever_section_trigger")
        } footer: {
            Text("focus_lever_trigger_footer")
        }
    }

    // MARK: - Wochenauswertung

    private func weekSection(_ adherence: FocusLeverAdherence) -> some View {
        Section("focus_lever_section_week") {
            HStack(spacing: 6) {
                ForEach(dayMarkers(for: adherence), id: \.date) { marker in
                    VStack(spacing: 4) {
                        Image(systemName: marker.symbol)
                            .foregroundStyle(marker.color)
                        Text(marker.date, format: .dateTime.weekday(.narrow))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 4)

            LabeledContent("focus_lever_rate") {
                Text(verbatim: "\(adherence.kept) / \(adherence.totalDays)")
            }
        }
    }

    private struct DayMarker {
        let date: Date
        let symbol: String
        let color: Color
    }

    /// Sieben-Tage-Streifen: gehalten, nicht gehalten oder unbeantwortet
    private func dayMarkers(for adherence: FocusLeverAdherence) -> [DayMarker] {
        guard let viewModel, let lever = viewModel.activeLever else { return [] }
        let calendar = Calendar.current
        return (0..<adherence.totalDays).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: adherence.start) else { return nil }
            guard let check = lever.check(for: day) else {
                return DayMarker(date: day, symbol: "circle.dashed", color: .secondary)
            }
            return DayMarker(
                date: day,
                symbol: check.kept ? "checkmark.circle.fill" : "xmark.circle.fill",
                color: check.kept ? .green : .orange
            )
        }
    }

    // MARK: - Historie

    private func historySection(_ viewModel: FocusLeverViewModel) -> some View {
        Section("focus_lever_section_history") {
            ForEach(viewModel.history) { lever in
                let adherence = viewModel.lifetimeAdherence(for: lever)
                VStack(alignment: .leading, spacing: 4) {
                    Text(lever.text)
                        .font(.footnote)
                    HStack(spacing: 4) {
                        Text(verbatim: "\(adherence.kept) / \(adherence.totalDays)")
                        Text("focus_lever_history_detail")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var explanationSection: some View {
        Section {
            Text("focus_lever_explanation")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Setup

    private func setupIfNeeded() {
        guard viewModel == nil else { return }
        let vm = FocusLeverViewModel(modelContext: modelContext)
        viewModel = vm
        syncDraft(from: vm)
    }

    /// Uebernimmt Text und Trigger des aktiven Hebels in die Eingabefelder.
    private func syncDraft(from viewModel: FocusLeverViewModel) {
        draftText = viewModel.activeLever?.text ?? ""
        triggerStartHour = viewModel.activeLever?.triggerStartHour ?? 20
        triggerOnSnack = viewModel.activeLever?.triggerOnSnack ?? true
    }
}

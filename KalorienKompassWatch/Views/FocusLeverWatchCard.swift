//
//  FocusLeverWatchCard.swift
//  KalorienKompassWatch
//
//  Erstellt von André Claaßen am 20.07.26.
//

#if os(watchOS)
import SwiftUI
import SwiftData

/// Zeigt den aktuellen Hebel auf der Watch und nimmt die Tagesrueckmeldung
/// entgegen. Gesetzt wird er auf iPhone, Mac oder per `kk focus set` — die Watch
/// zeigt nur an und fragt nach.
struct FocusLeverWatchCard: View {
    let modelContext: ModelContext

    @State private var lever: FocusLever?
    @State private var todaysCheck: FocusLeverCheck?

    var body: some View {
        if let lever {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "target")
                        .font(.caption)
                        .foregroundStyle(.tint)
                    Text(lever.text)
                        .font(.caption2)
                        .lineLimit(3)
                    Spacer(minLength: 0)
                }

                if let todaysCheck {
                    Label(
                        todaysCheck.kept ? "focus_lever_kept_state" : "focus_lever_missed_state",
                        systemImage: todaysCheck.kept ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .font(.caption2)
                    .foregroundStyle(todaysCheck.kept ? .green : .orange)
                } else {
                    HStack(spacing: 6) {
                        Button("focus_lever_kept") { answer(kept: true) }
                        Button("focus_lever_missed") { answer(kept: false) }
                    }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                }
            }
            .padding(8)
            .background(.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            .onAppear(perform: load)
        } else {
            // Ohne aktiven Hebel nichts anzeigen, aber beim ersten Erscheinen laden
            Color.clear
                .frame(height: 0)
                .onAppear(perform: load)
        }
    }

    private func load() {
        lever = FocusLever.active(in: modelContext)
        todaysCheck = lever?.check(for: Date())
    }

    private func answer(kept: Bool) {
        guard let lever else { return }
        lever.recordCheck(kept: kept, in: modelContext)
        load()
    }
}
#endif

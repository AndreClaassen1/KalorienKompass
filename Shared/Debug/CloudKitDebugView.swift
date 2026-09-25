//
//  CloudKitDebugView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 06.02.26.
//

import SwiftUI

/// In-App CloudKit Diagnose-Ansicht — Live-Status, Diagnose und Reparatur
struct CloudKitDebugView: View {
    @State private var debugger = CloudKitDebugger.shared
    @State private var showSyncRepairAlert = false
    @State private var syncRepairStatus: SyncRepairStatus = .idle

    private var syncMonitor: CloudKitSyncMonitor { .shared }

    private enum SyncRepairStatus: Equatable {
        case idle
        case repairing
        case success
        case error(String)
    }

    var body: some View {
        List {
            // Live-Sync-Status
            Section {
                syncStatusView
            }

            // Aktionen
            Section {
                actionButtons
                repairButton
            }

            // Diagnose-Log
            Section("Diagnose-Log") {
                if debugger.logEntries.isEmpty && !debugger.isRunning {
                    ContentUnavailableView(
                        "Keine Diagnose",
                        systemImage: "stethoscope",
                        description: Text("Tippe auf \"Alle Checks\", um die Diagnose zu starten.")
                    )
                } else {
                    ForEach(debugger.logEntries) { entry in
                        logRow(entry)
                    }
                }
            }
        }
        .navigationTitle("sidebar_cloudkit")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if debugger.isRunning {
                    ProgressView()
                } else {
                    Button {
                        copyToClipboard(debugger.allLogsAsText)
                    } label: {
                        Label("Kopieren", systemImage: "doc.on.doc")
                    }
                    .disabled(debugger.logEntries.isEmpty)
                }
            }
        }
        .onAppear {
            if debugger.logEntries.isEmpty {
                Task { await debugger.runAllDiagnostics() }
            }
        }
        .alert("settings_repair_sync_confirm_title", isPresented: $showSyncRepairAlert) {
            Button("settings_repair_sync_confirm_action", role: .destructive) {
                performSyncRepair()
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("settings_repair_sync_confirm_message")
        }
    }

    // MARK: - Live-Sync-Status

    @ViewBuilder
    private var syncStatusView: some View {
        VStack(spacing: 8) {
            switch syncMonitor.syncState {
            case .unknown:
                Image(systemName: "icloud.slash")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("sync_status_unknown")
                    .font(.headline)
            case .syncing:
                ProgressView()
                    .controlSize(.large)
                Text("sync_status_syncing")
                    .font(.headline)
            case .upToDate:
                Image(systemName: "checkmark.icloud.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.green)
                Text("sync_status_up_to_date")
                    .font(.headline)
            case .error(let message):
                Image(systemName: "exclamationmark.icloud.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.red)
                Text("sync_status_error")
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let lastSync = syncMonitor.lastSuccessfulSync {
                Text("sync_last_sync \(lastSync.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Aktions-Buttons

    private var actionButtons: some View {
        Group {
            Button {
                Task { await debugger.runAllDiagnostics() }
            } label: {
                Label("Alle Checks ausfuehren", systemImage: "stethoscope")
            }
            .disabled(debugger.isRunning)

            Button {
                Task { await debugger.checkWriteTest() }
            } label: {
                Label("Nur Schreibtest", systemImage: "pencil.and.outline")
            }
            .disabled(debugger.isRunning)

            Button(role: .destructive) {
                debugger.clear()
            } label: {
                Label("Log loeschen", systemImage: "trash")
            }
            .disabled(debugger.isRunning)
        }
    }

    // MARK: - Sync-Reparatur

    @ViewBuilder
    private var repairButton: some View {
        switch syncRepairStatus {
        case .idle:
            Button(role: .destructive) {
                showSyncRepairAlert = true
            } label: {
                Label("settings_repair_sync", systemImage: "arrow.triangle.2.circlepath")
            }
        case .repairing:
            HStack {
                ProgressView()
                Text("settings_repair_sync_running")
                    .padding(.leading, 8)
            }
        case .success:
            VStack(alignment: .leading, spacing: 4) {
                Label("settings_repair_sync_success", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("settings_repair_sync_restart_hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .error(let message):
            VStack(alignment: .leading, spacing: 4) {
                Label("settings_repair_sync_error", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func performSyncRepair() {
        syncRepairStatus = .repairing
        Task {
            do {
                try await CloudKitConfiguration.repairSync()
                syncRepairStatus = .success
            } catch {
                syncRepairStatus = .error(error.localizedDescription)
                CloudKitDebugger.shared.clear()
                CloudKitDebugger.shared.checkRepairFlag()
            }
        }
    }

    // MARK: - Log-Zeile

    private func logRow(_ entry: CloudKitDebugger.LogEntry) -> some View {
        HStack(alignment: .top, spacing: 6) {
            levelIcon(entry.level)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)

                Text(formatted(entry.timestamp))
                    .font(.system(.caption2))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func levelIcon(_ level: CloudKitDebugger.LogEntry.Level) -> some View {
        Group {
            switch level {
            case .info:
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .warning:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            case .error:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .font(.caption)
    }

    private func formatted(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .medium)
    }

    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

#Preview {
    NavigationStack {
        CloudKitDebugView()
    }
}

//
//  DatabaseDownloadView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import SwiftUI

/// Ansicht zur Verwaltung der Offline-Datenbank in den Einstellungen
struct DatabaseDownloadView: View {
    @State private var downloadManager = DatabaseDownloadManager.shared
    @State private var currentVersion: String?
    @State private var productCount: Int?
    @State private var remoteVersion: DatabaseDownloadManager.RemoteVersion?
    @State private var showDeleteConfirmation = false

    var body: some View {
        Group {
            if downloadManager.isDatabaseAvailable {
                installedView
            } else {
                notInstalledView
            }
        }
        .task {
            await loadStatus()
        }
    }

    // MARK: - Installiert

    @ViewBuilder
    private var installedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("offline_db_installed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)

            if let version = currentVersion {
                Text("offline_db_version \(version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let count = productCount {
                let formatted = NumberFormatter.localizedString(
                    from: NSNumber(value: count), number: .decimal
                )
                Text("offline_db_product_count \(formatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        if downloadManager.isDownloading || downloadManager.isDecompressing {
            downloadProgressView
        } else {
            Button("offline_db_update") {
                Task {
                    await downloadManager.downloadDatabase()
                    await loadStatus()
                }
            }

            Button("offline_db_delete", role: .destructive) {
                showDeleteConfirmation = true
            }
            .confirmationDialog(
                "offline_db_delete",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("offline_db_delete", role: .destructive) {
                    downloadManager.deleteDatabase()
                    currentVersion = nil
                    productCount = nil
                }
            }
        }

        if let error = downloadManager.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    // MARK: - Nicht installiert

    @ViewBuilder
    private var notInstalledView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("offline_db_not_installed", systemImage: "arrow.down.circle")
                .foregroundStyle(.secondary)

            if let remote = remoteVersion {
                let sizeMB = String(format: "%.0f", Double(remote.sizeBytes) / 1_000_000)
                Text("offline_db_size_info \(sizeMB)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        if downloadManager.isDownloading || downloadManager.isDecompressing {
            downloadProgressView
        } else {
            Button("offline_db_download") {
                Task {
                    await downloadManager.downloadDatabase()
                    await loadStatus()
                }
            }
        }

        if let error = downloadManager.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    // MARK: - Fortschrittsanzeige

    @ViewBuilder
    private var downloadProgressView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if downloadManager.isDecompressing {
                Text("offline_db_decompressing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ProgressView()
                    .progressViewStyle(.linear)
            } else {
                Text("offline_db_downloading")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ProgressView(value: downloadManager.downloadProgress)
                    .progressViewStyle(.linear)
                Text("\(Int(downloadManager.downloadProgress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Hilfsmethoden

    private func loadStatus() async {
        currentVersion = await downloadManager.currentVersion()
        productCount = await downloadManager.currentProductCount()
        remoteVersion = await downloadManager.checkForUpdate()
    }
}

#Preview("Nicht installiert") {
    Form {
        Section("settings_offline_database") {
            DatabaseDownloadView()
        }
    }
}

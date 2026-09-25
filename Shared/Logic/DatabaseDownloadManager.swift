//
//  DatabaseDownloadManager.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import Foundation
import Compression

/// Verwaltet den Download und die Aktualisierung der Offline-Datenbank
@Observable
final class DatabaseDownloadManager: @unchecked Sendable {
    static let shared = DatabaseDownloadManager()

    private let baseURL = "https://andreclaassen.de/off/"

    // MARK: - State

    /// Download laeuft gerade
    var isDownloading = false

    /// Download-Fortschritt (0.0 - 1.0)
    var downloadProgress: Double = 0

    /// Dekompression laeuft gerade
    var isDecompressing = false

    /// Fehlermeldung
    var errorMessage: String?

    // MARK: - Remote-Version

    /// Versionsinfo vom Server
    struct RemoteVersion: Codable, Sendable {
        let version: String
        let sizeBytes: Int
        let productCount: Int
        let buildDate: String

        enum CodingKeys: String, CodingKey {
            case version
            case sizeBytes = "size_bytes"
            case productCount = "product_count"
            case buildDate = "build_date"
        }
    }

    /// Prüft ob eine neue Version verfuegbar ist
    func checkForUpdate() async -> RemoteVersion? {
        guard let url = URL(string: "\(baseURL)version.json") else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(RemoteVersion.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - Download

    /// Laedt die Datenbank herunter und installiert sie
    @MainActor
    func downloadDatabase() async {
        guard !isDownloading else { return }

        isDownloading = true
        downloadProgress = 0
        isDecompressing = false
        errorMessage = nil

        do {
            // 1. Komprimierte Datei herunterladen
            let gzData = try await downloadFile()

            // 2. Dekomprimieren
            isDecompressing = true
            let dbData = try decompressGzip(data: gzData)

            // 3. In App-Group-Container speichern
            let dbPath = AppGroupPaths.sharedContainer()
                .appendingPathComponent("off_foods.sqlite")

            try dbData.write(to: dbPath, options: .atomic)

            // 4. Datenbank oeffnen
            try await OfflineDatabaseService.shared.open()

        } catch {
            errorMessage = error.localizedDescription
        }

        isDownloading = false
        isDecompressing = false
    }

    /// Laedt die komprimierte Datei mit Fortschrittsanzeige herunter
    @MainActor
    private func downloadFile() async throws -> Data {
        guard let url = URL(string: "\(baseURL)foods_de.sqlite.gz") else {
            throw OfflineDatabaseError.downloadFailed("Ungueltige URL")
        }

        let (bytes, response) = try await URLSession.shared.bytes(from: url)

        let expectedLength = (response as? HTTPURLResponse)
            .flatMap { Int($0.value(forHTTPHeaderField: "Content-Length") ?? "") } ?? 0

        var receivedData = Data()
        if expectedLength > 0 {
            receivedData.reserveCapacity(expectedLength)
        }

        var receivedBytes = 0
        for try await byte in bytes {
            receivedData.append(byte)
            receivedBytes += 1

            if expectedLength > 0 && receivedBytes % 65536 == 0 {
                downloadProgress = Double(receivedBytes) / Double(expectedLength)
            }
        }

        downloadProgress = 1.0
        return receivedData
    }

    /// Dekomprimiert GZIP-Daten mit dem Compression-Framework
    private func decompressGzip(data: Data) throws -> Data {
        // GZIP-Header ueberspringen (10 Bytes Minimum)
        guard data.count > 10 else {
            throw OfflineDatabaseError.downloadFailed("Datei zu klein fuer GZIP")
        }

        // GZIP Magic Number pruefen
        guard data[data.startIndex] == 0x1f && data[data.startIndex + 1] == 0x8b else {
            // Kein GZIP — vielleicht schon unkomprimiert?
            return data
        }

        // GZIP-Header parsen um den Deflate-Stream zu finden
        var offset = 10  // Fester Header: 10 Bytes
        let flags = data[data.startIndex + 3]

        // FEXTRA
        if flags & 0x04 != 0 {
            let extraLen = Int(data[data.startIndex + offset]) | (Int(data[data.startIndex + offset + 1]) << 8)
            offset += 2 + extraLen
        }

        // FNAME
        if flags & 0x08 != 0 {
            while offset < data.count && data[data.startIndex + offset] != 0 {
                offset += 1
            }
            offset += 1  // Null-Terminator
        }

        // FCOMMENT
        if flags & 0x10 != 0 {
            while offset < data.count && data[data.startIndex + offset] != 0 {
                offset += 1
            }
            offset += 1
        }

        // FHCRC
        if flags & 0x02 != 0 {
            offset += 2
        }

        // Deflate-Stream extrahieren (ohne GZIP-Header und Trailer)
        let deflateData = data.subdata(in: (data.startIndex + offset)..<(data.endIndex - 8))

        // Mit Compression-Framework dekomprimieren
        let decompressed = try deflateData.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) -> Data in
            guard let sourcePointer = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw OfflineDatabaseError.downloadFailed("Buffer-Fehler")
            }

            // Grosszuegigen Buffer allokieren (10x komprimierte Groesse als Schaetzung)
            var destCapacity = deflateData.count * 10
            var destBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destCapacity)
            defer { destBuffer.deallocate() }

            let decodedSize = compression_decode_buffer(
                destBuffer, destCapacity,
                sourcePointer, deflateData.count,
                nil,
                COMPRESSION_ZLIB
            )

            if decodedSize == 0 || decodedSize == destCapacity {
                // Buffer zu klein, nochmal mit groesserem Buffer
                destBuffer.deallocate()
                destCapacity = deflateData.count * 30
                destBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destCapacity)

                let retrySize = compression_decode_buffer(
                    destBuffer, destCapacity,
                    sourcePointer, deflateData.count,
                    nil,
                    COMPRESSION_ZLIB
                )

                guard retrySize > 0 && retrySize < destCapacity else {
                    throw OfflineDatabaseError.downloadFailed("Dekompression fehlgeschlagen")
                }

                return Data(bytes: destBuffer, count: retrySize)
            }

            return Data(bytes: destBuffer, count: decodedSize)
        }

        return decompressed
    }

    // MARK: - Status

    /// Pruefen ob die Datenbank installiert ist
    var isDatabaseAvailable: Bool {
        FileManager.default.fileExists(
            atPath: AppGroupPaths.sharedContainer()
                .appendingPathComponent("off_foods.sqlite").path
        )
    }

    /// Aktuelle Version der installierten Datenbank
    func currentVersion() async -> String? {
        guard isDatabaseAvailable else { return nil }
        do {
            try await OfflineDatabaseService.shared.open()
            return await OfflineDatabaseService.shared.currentVersion()
        } catch {
            return nil
        }
    }

    /// Produktanzahl der installierten Datenbank
    func currentProductCount() async -> Int? {
        guard isDatabaseAvailable else { return nil }
        do {
            try await OfflineDatabaseService.shared.open()
            return await OfflineDatabaseService.shared.productCount()
        } catch {
            return nil
        }
    }

    /// Loescht die installierte Datenbank
    @MainActor
    func deleteDatabase() {
        let path = AppGroupPaths.sharedContainer()
            .appendingPathComponent("off_foods.sqlite")

        Task {
            await OfflineDatabaseService.shared.close()
        }

        try? FileManager.default.removeItem(at: path)
    }
}

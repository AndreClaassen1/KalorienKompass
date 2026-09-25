//
//  OfflineDatabaseService.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import Foundation
import SQLite3

/// Offline-Produkt aus der lokalen OpenFoodFacts-Datenbank
struct OfflineProduct: Identifiable, Sendable {
    let code: String
    let name: String
    let brand: String?
    let caloriesPer100g: Double
    let proteinPer100g: Double
    let carbsPer100g: Double
    let fatPer100g: Double
    let fiberPer100g: Double
    let sugarPer100g: Double
    let saturatedFatPer100g: Double
    let saltPer100g: Double
    let servingSize: String?
    let imageURL: String?

    var id: String { code }

    /// Konvertiert in ein FoodItem fuer SwiftData
    func toFoodItem() -> FoodItem {
        let food = FoodItem(
            name: name,
            brand: brand,
            barcode: code,
            caloriesPer100g: caloriesPer100g,
            proteinPer100g: proteinPer100g,
            carbsPer100g: carbsPer100g,
            fatPer100g: fatPer100g,
            fiberPer100g: fiberPer100g,
            sugarPer100g: sugarPer100g,
            saturatedFatPer100g: saturatedFatPer100g,
            saltPer100g: saltPer100g
        )
        food.imageURL = imageURL
        food.isUserCreated = false
        food.lastFetched = Date()

        // Portionsgroesse parsen
        if let serving = servingSize {
            food.servingDescription = serving
            if let grams = ServingSizeParser.parseGrams(from: serving) {
                food.defaultServingSizeGrams = grams
            }
        }

        return food
    }

}

/// Actor-basierter Zugriff auf die lokale OpenFoodFacts SQLite-Datenbank
actor OfflineDatabaseService {
    static let shared = OfflineDatabaseService()

    private var db: OpaquePointer?

    /// Pfad zur Offline-Datenbank im App-Group-Container
    var databasePath: String {
        AppGroupPaths.sharedContainer()
            .appendingPathComponent("off_foods.sqlite").path
    }

    /// Pruefen ob die Datenbank existiert
    var databaseExists: Bool {
        FileManager.default.fileExists(atPath: databasePath)
    }

    /// Oeffnet die Datenbank (idempotent)
    func open() throws {
        guard db == nil else { return }
        guard databaseExists else {
            throw OfflineDatabaseError.databaseNotFound
        }

        var dbPointer: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        let result = sqlite3_open_v2(databasePath, &dbPointer, flags, nil)

        guard result == SQLITE_OK, let dbPointer else {
            throw OfflineDatabaseError.openFailed(
                String(cString: sqlite3_errmsg(dbPointer))
            )
        }

        db = dbPointer
    }

    /// Schliesst die Datenbank
    func close() {
        if let db {
            sqlite3_close(db)
        }
        db = nil
    }

    /// Liest die Version aus der meta-Tabelle
    func currentVersion() -> String? {
        return queryMeta(key: "version")
    }

    /// Liest die Produktanzahl aus der meta-Tabelle
    func productCount() -> Int? {
        guard let value = queryMeta(key: "product_count") else { return nil }
        return Int(value)
    }

    // MARK: - Suche

    /// FTS5-Volltextsuche nach Produktname und Marke
    func searchProducts(query: String, limit: Int = 30) -> [OfflineProduct] {
        guard let db else { return [] }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // FTS5-Query: Woerter mit * am Ende fuer Prefix-Match
        let ftsQuery = trimmed
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { "\($0)*" }
            .joined(separator: " ")

        let sql = """
            SELECT p.code, p.name, p.brand, p.calories, p.protein, p.carbs, p.fat,
                   p.fiber, p.sugar, p.saturated_fat, p.salt, p.serving_size, p.image_url
            FROM products p
            JOIN products_fts fts ON p.rowid = fts.rowid
            WHERE products_fts MATCH ?
            ORDER BY rank
            LIMIT ?
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, ftsQuery, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int(stmt, 2, Int32(limit))

        var results: [OfflineProduct] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(readProduct(from: stmt!))
        }

        return results
    }

    /// Barcode-Lookup (exakte Suche)
    func lookupBarcode(_ barcode: String) -> OfflineProduct? {
        guard let db else { return nil }

        let sql = """
            SELECT code, name, brand, calories, protein, carbs, fat,
                   fiber, sugar, saturated_fat, salt, serving_size, image_url
            FROM products
            WHERE code = ?
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, barcode, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return readProduct(from: stmt!)
    }

    // MARK: - Hilfsmethoden

    /// Liest einen Wert aus der meta-Tabelle
    private func queryMeta(key: String) -> String? {
        guard let db else { return nil }

        let sql = "SELECT value FROM meta WHERE key = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, key, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        guard let cString = sqlite3_column_text(stmt, 0) else { return nil }
        return String(cString: cString)
    }

    /// Liest ein OfflineProduct aus einem SQLite Statement
    private func readProduct(from stmt: OpaquePointer) -> OfflineProduct {
        OfflineProduct(
            code: columnText(stmt, 0) ?? "",
            name: columnText(stmt, 1) ?? "",
            brand: columnText(stmt, 2),
            caloriesPer100g: sqlite3_column_double(stmt, 3),
            proteinPer100g: sqlite3_column_double(stmt, 4),
            carbsPer100g: sqlite3_column_double(stmt, 5),
            fatPer100g: sqlite3_column_double(stmt, 6),
            fiberPer100g: sqlite3_column_double(stmt, 7),
            sugarPer100g: sqlite3_column_double(stmt, 8),
            saturatedFatPer100g: sqlite3_column_double(stmt, 9),
            saltPer100g: sqlite3_column_double(stmt, 10),
            servingSize: columnText(stmt, 11),
            imageURL: columnText(stmt, 12)
        )
    }

    /// Liest einen Text-Spaltenwert aus einem Statement
    private func columnText(_ stmt: OpaquePointer, _ index: Int32) -> String? {
        guard let cString = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: cString)
    }
}

// MARK: - Fehler

enum OfflineDatabaseError: Error, LocalizedError {
    case databaseNotFound
    case openFailed(String)
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .databaseNotFound:
            "Offline-Datenbank nicht gefunden"
        case .openFailed(let message):
            "Datenbank konnte nicht geoeffnet werden: \(message)"
        case .downloadFailed(let message):
            "Download fehlgeschlagen: \(message)"
        }
    }
}

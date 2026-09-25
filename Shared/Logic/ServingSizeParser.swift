//
//  ServingSizeParser.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 05.02.26.
//

import Foundation

/// Extrahiert Gramm-Angaben aus Portionsstrings (z.B. "30g", "1 Scheibe (25 g)")
enum ServingSizeParser {

    /// Extrahiert die erste Gramm-Angabe aus einem String
    /// - Parameter string: Portionsstring wie "30g", "1 Scheibe (25 g)", "100gramm"
    /// - Returns: Gramm als Double oder nil wenn keine Gramm-Angabe gefunden
    nonisolated static func parseGrams(from string: String) -> Double? {
        let pattern = #"(\d+(?:[.,]\d+)?)\s*g(?:ramm?)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, range: range) else { return nil }
        guard let numberRange = Range(match.range(at: 1), in: string) else { return nil }
        let numberString = String(string[numberRange]).replacingOccurrences(of: ",", with: ".")
        return Double(numberString)
    }
}

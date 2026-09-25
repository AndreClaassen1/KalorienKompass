//
//  BuildInfo.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 06.07.26.
//

import Foundation
import AppChangelog

/// Versions- und Build-Informationen der laufenden App.
///
/// Bewusst plattformuebergreifend und nur einmal vorhanden: die Fusszeile der
/// Menubar-App braucht sie ebenso wie die Changelog-Anzeige, die daraus die
/// aktuelle Marketing-Version zieht (Issue #71).
enum BuildInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    static var configuration: String {
        #if DEBUG
        "Debug"
        #else
        "Release"
        #endif
    }

    /// Wann dieser Build entstanden ist.
    ///
    /// Drei Stufen, weil keine allein traegt:
    /// 1. Der Zeitstempel, den Fastlane als `$(BUILD_TIMESTAMP)` in die Info.plist
    ///    einbettet. Er reist mit dem Bundle und ist damit der einzige Wert, der
    ///    auch nach der App-Store-Verarbeitung und dem Entpacken auf dem Geraet
    ///    noch die Bauzeit meint.
    /// 2. Das Aenderungsdatum der Executable. Greift bei einem Build direkt aus
    ///    Xcode, wo Fastlane das Setting nicht gesetzt hat und der Wert leer ist.
    /// 3. Die Build-Nummer, falls sich nicht einmal das lesen laesst.
    static var buildDate: String {
        if let stamped = Bundle.main.infoDictionary?["BuildTimestamp"] as? String,
           !stamped.isEmpty {
            return stamped
        }
        if let url = Bundle.main.executableURL,
           let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let date = attrs[.modificationDate] as? Date {
            return dateFormatter.string(from: date)
        }
        return "Build \(buildNumber)"
    }

    /// Bewusst einmal angelegt statt je Aufruf: `buildDate` wird in `FocusDayView`
    /// aus dem View-Body gelesen und liefe sonst bei jedem Durchlauf neu.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
}

extension BuildInfo {

    /// Der geparste Aenderungsverlauf, einmal je Prozess.
    ///
    /// `Changelog.load()` liest und parst die Bundle-Ressource. Direkt im
    /// View-Body aufgerufen liefe das bei **jedem** Durchlauf erneut, auf dem
    /// Main-Thread — in `FocusDayView` also bei jedem Tippen und jedem
    /// Tageswechsel.
    static let changelog = Changelog.load()

    /// Die laufende Version als `SemanticVersion`, fuer die Changelog-Anzeige.
    static let semanticVersion = SemanticVersion(version)
}

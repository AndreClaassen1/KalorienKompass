import Foundation

@main
struct KKEntry {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())

        guard let command = args.first else {
            printHelp()
            exit(0)
        }

        do {
            switch command {
            case "add":
                try await Commands.add(args: Array(args.dropFirst()))
            case "today":
                try await Commands.today(args: Array(args.dropFirst()))
            case "coffee", "kaffee":
                try await Commands.coffee(args: Array(args.dropFirst()))
            case "energy", "energie":
                try await Commands.energy(args: Array(args.dropFirst()))
            case "focus":
                try await Commands.focus(args: Array(args.dropFirst()))
            case "repair":
                try await Commands.repair(args: Array(args.dropFirst()))
            case "undo":
                try await Commands.undo()
            case "delete", "del", "rm":
                try await Commands.delete(args: Array(args.dropFirst()))
            case "move", "mv":
                try await Commands.move(args: Array(args.dropFirst()))
            case "stats":
                try await Commands.stats(args: Array(args.dropFirst()))
            case "help", "--help", "-h":
                printHelp()
            default:
                printError("Unbekannter Befehl: \(command)")
                printHelp()
                exit(1)
            }
        } catch let err as KKError {
            printError(err.message)
            exit(1)
        } catch {
            printError(error.localizedDescription)
            exit(1)
        }
    }
}

// MARK: - Error

struct KKError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}

// MARK: - Ausgabe-Hilfsfunktionen

func printHelp() {
    print("""
    \(bold("kk")) — KalorienKompass CLI

    \(bold("Verwendung:"))
      kk add "Beschreibung"                          KI schätzt Nährwerte (Standard)
      kk add --meal lunch "Spaghetti Bolognese"       Mit Mahlzeitstyp
      kk add --name "Apfel" --calories 52 --grams 150 Manuelle Eingabe
      kk add --date 2026-06-01 --time 19:30 "Pizza"   Eintrag rückwirkend auf ein Datum
      kk add --yesterday --time 19:30 "Pizza"         Eintrag auf gestern buchen
      kk today                                        Heutige Einträge anzeigen (mit Ampel)
      kk today --yesterday                            Einträge eines vergangenen Tages
      kk today --json                                 Tagesstand maschinenlesbar (für Skripte)
      kk energy                                       Aktivkalorien, Training, Schritte, Gewicht
      kk energy --yesterday --json                    Verbrauchsseite eines Tages als JSON
      kk energy report --weeks 4                      Wochenschnitt der Verbrauchsseite
      kk coffee                                       Kaffee-Status heute (Tassen + Koffein)
      kk coffee add [N]                               N Tassen hinzufügen (Standard 1)
      kk coffee remove [N]                            N Tassen entfernen (Standard 1)
      kk coffee add 2 --yesterday                     Tassen für einen vergangenen Tag
      kk focus                                        Aktueller Hebel + Adhärenz heute
      kk focus set "…"                                Neuen Hebel setzen (löst den alten ab)
      kk focus kept | missed                          Tagesrückmeldung setzen
      kk focus report --weeks 4 --json                Adhärenz-Auswertung (JSON für Skripte)
      kk undo                                         Letzten Eintrag löschen
      kk delete                                       Heutige Einträge nummeriert auflisten
      kk delete 2                                     Eintrag Nr. 2 von heute löschen
      kk delete --date 2026-06-01 3                   Eintrag Nr. 3 an einem bestimmten Tag löschen
      kk move                                         Einträge zum Umhängen nummeriert auflisten
      kk move 2 --meal dinner                         Eintrag Nr. 2 dem Abendessen zuordnen
      kk move 1 2 3 --meal breakfast                  Mehrere Einträge auf einmal umhängen
      kk move --from lunch --meal breakfast           Alle Einträge einer Mahlzeit umhängen
      kk move 1 --to-date gestern                     Eintrag auf einen anderen Tag buchen
      kk repair nutrients                              Altbestände ohne Zucker/Salz auflisten
      kk repair nutrients --apply                      Fehlende Nährwerte per KI nachtragen
      kk repair nutrients --date heute --apply         Nur Lebensmittel eines Tages
      kk stats                                        Tracking-Statistik (Wochen)
      kk stats --weeks 13 --min-entries 5             Wochen mit mind. N Eintraegen
      kk stats --format count                         Nur Zahl ausgeben (fuer Skripte)

    \(bold("Optionen für kk add:"))
      --meal MAHLZEIT   \(MealType.cliNameHint)
                        (Standard heute: aus der aktuellen Uhrzeit)
      --time HH:MM      Essenszeit; bestimmt die Mahlzeit. Bei einem vergangenen Tag
                        ist --time oder --meal Pflicht, sonst bricht der Befehl ab
      --name NAME       Bezeichnung (Pflicht bei manuellem Modus)
      --calories N      Kalorien pro 100g (Pflicht bei manuellem Modus)
      --grams N         Portionsgröße in Gramm (Standard: 100)
      --protein N       Protein in g pro 100g
      --carbs N         Kohlenhydrate in g pro 100g
      --fat N           Fett in g pro 100g
      --saturated-fat N Gesättigte Fettsäuren in g pro 100g
      --sugar N         Zucker in g pro 100g
      --salt N          Salz in g pro 100g
                        (ohne diese drei fällt die Ampel zu günstig aus)

    \(bold("Optionen für kk move:"))
      --meal MAHLZEIT   Ziel-Mahlzeit (\(MealType.cliNameHint))
      --time HH:MM      Ziel-Mahlzeit über die Uhrzeit; --meal hat Vorrang
      --to-date DATUM   Zieltag (Datumsformate wie unten)
      --from MAHLZEIT   wählt alle Einträge dieser Mahlzeit statt einzelner Nummern
                        Nährwerte, Menge und Erfassungszeit bleiben unverändert

    \(bold("Datum (für add, today, coffee, energy, delete, move, repair, focus kept/missed):"))
      --date DATUM      YYYY-MM-DD, 'heute', 'gestern' oder 'vorgestern'
                        (Zukünftige Tage werden abgelehnt)
      --yesterday       Kurzform für --date gestern
                        (bei kk move ist das der Quelltag, das Ziel steht in --to-date)

    \(bold("Optionen für kk focus:"))
      --from-hour N     Ab dieser Stunde wird der Hebel hervorgehoben (0 = immer)
      --no-snack        Nicht zusätzlich nach einem Snack/Abendessen hervorheben
      --weeks N         Anzahl Wochen im report (Standard: 4)
      --json            report als JSON ausgeben

    \(bold("Optionen für kk energy:"))
      --weeks N         Anzahl Wochen im report (Standard: 4)
      --json            Ausgabe als JSON

    \(bold("Nährstoff-Ampel:"))
      kk today setzt je Eintrag einen farbigen Punkt (UK-FSA-Bewertung aus Fett,
      gesättigten Fetten, Zucker und Salz). Fehlen die Nährwerte, bleibt die Stelle
      leer — geraten wird nicht.

    \(bold("Konfiguration:"))
      CLAUDE_API_KEY              Umgebungsvariable für den API-Key
      ~/.config/kk/config.json   { "apiKey": "sk-ant-..." }
    """)
}

func printError(_ msg: String) {
    fputs(red("Fehler:") + " \(msg)\n", stderr)
}

func green(_ s: String) -> String { "\u{1B}[32m\(s)\u{1B}[0m" }
func bold(_ s: String) -> String  { "\u{1B}[1m\(s)\u{1B}[0m" }
func dim(_ s: String) -> String   { "\u{1B}[2m\(s)\u{1B}[0m" }
func yellow(_ s: String) -> String { "\u{1B}[33m\(s)\u{1B}[0m" }
func red(_ s: String) -> String    { "\u{1B}[31m\(s)\u{1B}[0m" }

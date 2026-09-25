# Tastatur-Schnelleingabe (macOS)

Wie sich KalorienKompass per Tastenkombination oeffnen und bedienen laesst.

## Warum kein eingebauter globaler Hotkey

Die macOS-App laeuft mit `ENABLE_APP_SANDBOX = YES`. Ein systemweiter Hotkey braucht
einen CGEvent-Tap mit Accessibility-Berechtigung (Muster aus `track` und
`menubar-social`). Fuer sandboxed Apps ist dieser Weg versperrt und im App-Review ein
Ablehnungsgrund.

Deshalb die Arbeitsteilung: **Den Hotkey vergibt das System, die App liefert das
Eingabefeld.** Die Shortcuts-App kann jedem Kurzbefehl eine Tastenkombination zuweisen
und darf das systemweit — die App muss dafuer keine Sonderrechte anfordern.

## Einrichtung: Hotkey fuer die Schnelleingabe

1. Shortcuts-App oeffnen, neuen Kurzbefehl anlegen
2. Aktion **„Schnelleingabe öffnen"** (KalorienKompass) hinzufuegen
3. Rechts in den Kurzbefehl-Details auf **Tastaturkurzbefehl** klicken
4. Wunschtaste druecken, z. B. `⌃⌥Leertaste`

Danach: Taste druecken, tippen, Enter. Die App kommt nach vorn, der Cursor steht im
Eingabefeld. Die Mahlzeit ergibt sich aus der Uhrzeit
(`MealType.currentBasedOnTime`), es gibt keine Rueckfrage. Vertippt? Das
„Rueckgaengig"-Banner nimmt den Eintrag zurueck.

Alfred und Raycast koennen denselben Kurzbefehl ebenfalls auf eine Taste legen.

## Warum ein Flag statt einer Notification

Beim Tastendruck steht nicht fest, ob die App schon laeuft. Eine Notification
(`.focusInputFocus`, wie sie `FocusMenuCommands` fuer ⌘N nutzt) wuerde beim Kaltstart
verpuffen: `FocusInputView` existiert zum Sendezeitpunkt noch nicht.

Deshalb setzt `OpenQuickEntryIntent` nur das Flag
`NavigationModel.pendingQuickEntryFocus`. `FocusInputView` beobachtet es mit
`onChange(of:initial: true)` und raeumt es dabei ab:

| Lage | Was greift |
|---|---|
| App startet erst | `initial: true` — die View sieht das bereits gesetzte Flag beim Erscheinen |
| App laeuft schon | Die Flag-Aenderung loest `onChange` aus |

Ein Mechanismus fuer beide Faelle. `NavigationModel` persistiert das Flag nicht: seine
`CodingKeys` umfassen nur `selectedCategory` und `columnVisibility`, transiente Felder
wie dieses und `entryAddedCount` bleiben aussen vor.

## Tastatur im Menubar-Popover

Bei geoeffnetem Popover:

| Taste | Aktion |
|---|---|
| `⌘⇧W` | Wasser +250 ml |
| `⌘⇧K` | Kaffee +1 Tasse |
| `⌘N` | Cursor ins Eingabefeld |

Bewusst mit `⌘⇧`: Das Popover enthaelt ein Textfeld, modifierlose Buchstaben wuerden
beim Tippen mitfeuern. `⌘W` allein scheidet aus, das schliesst das Fenster.

## Tastatur im Hauptfenster

Aus `FocusMenuCommands`:

| Taste | Aktion |
|---|---|
| `⌘N` | Essen eintragen (Cursor ins Feld) |
| `⌘D` | Essen diktieren |
| `⌘T` | Heute |
| `⌘⌥←` / `⌘⌥→` | Vorheriger / naechster Tag |
| `⌘,` | Einstellungen |

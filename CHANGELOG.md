# Changelog

Alle nennenswerten Änderungen an KalorienKompass. Format nach
[Keep a Changelog](https://keepachangelog.com/de/1.1.0/), Versionierung nach
[Semantic Versioning](https://semver.org/lang/de/).

## [Unreleased]

## [1.27.0] – 2026-09-19

### Geändert

- Beim Erfassen siehst du jetzt, in welche Mahlzeit die Eingabe geht: eine Pille unter dem Eingabefeld zeigt die Zuordnung, vorbelegt aus der Uhrzeit, und ein Klick darauf ändert sie. Das späte Frühstück landet damit nicht mehr unbemerkt im zweiten Frühstück. Im Popover der Menüleiste steht dieselbe Auswahl als Symbol neben dem Eingabefeld.

## [1.26.0] – 2026-09-19

### Hinzugefügt

- Der manuelle Modus von `kk add` nimmt gesättigte Fettsäuren, Zucker und Salz an
  (`--saturated-fat`, `--sugar`, `--salt`, je pro 100 g). Bisher entstand jeder manuelle Eintrag
  ohne diese drei Werte und damit ohne Ampel. `kk repair nutrients` lässt sich mit `--date` oder
  `--yesterday` auf die Lebensmittel eines Tages einschränken, statt den ganzen Bestand
  nachzuschätzen.

### Geändert

- Einträge lassen sich jetzt ohne Ziehen einer anderen Mahlzeit zuordnen: Rechtsklick (auf dem iPhone langes Drücken) zeigt „Verschieben nach" mit allen sechs Mahlzeiten, auch den gerade leeren. Auf dem Mac steht die Mahlzeit zusätzlich als anklickbare Pille in jeder Zeile, und mit gedrückter Befehlstaste sammelst du mehrere Einträge und buchst sie in einem Zug um.

## [1.25.0] – 2026-09-07

### Hinzugefügt

- Die CLI kann Einträge nachträglich umhängen: `kk move 2 --meal breakfast` ordnet einen
  Eintrag einer anderen Mahlzeit zu, `kk move 1 2 3 --to-date gestern` bucht mehrere auf einen
  anderen Tag, und `kk move --from lunch --meal breakfast` nimmt gleich alle Einträge einer
  Mahlzeit. Bisher blieb nur löschen und neu erfassen, wobei die KI die Nährwerte neu geschätzt
  hat und sich die Tagessumme verschob. Beim Umhängen bleiben Nährwerte, Menge und
  Erfassungszeit unverändert.

## [1.24.0] – 2026-09-02

### Hinzugefügt

- Das Kalorien-Widget gibt es jetzt auch in klein. Damit erscheint es am Ladegerät im Querformat (StandBy), wo bisher nur Wasser und Schnell-Eintrag zur Wahl standen, und als kleine Kachel auf dem Homescreen. Es zeigt die Restkalorien als große Zahl mit einem Balken darunter, aus einigen Metern Entfernung noch lesbar. Hast du dein Ziel überschritten, steht dort in Rot, um wie viel.

## [1.23.0] – 2026-09-02

### Hinzugefügt

- Deine Restkalorien stehen jetzt auf dem Sperrbildschirm. Du kannst zwischen drei Formen wählen: einem Ring neben den anderen runden Widgets, einer breiten Zeile mit Balken und Tagesbilanz, oder einer schmalen Zeile über der Uhrzeit. Dieselbe Anzeige erscheint am Ladegerät auch im StandBy-Modus. Ein Tipp darauf öffnet die App.

### Behoben

- Auf der Uhr stand bei überschrittenem Tagesziel „-600 kcal Übrig", obwohl nichts mehr übrig war. Die Komplikation sagt jetzt „600 kcal drüber", und im Ring steht ein Pluszeichen. Außerdem schreibt die Uhr große Zahlen nun mit Punkt, also „2.000" statt „2000", wie der Rest der App.

## [1.22.0] – 2026-08-25

### Hinzugefügt

- Das Kommandozeilenwerkzeug `kk` zeigt jetzt auch die Verbrauchsseite des Tages.
  `kk today` nennt unter der Tagessumme die Aktivkalorien, davon den Trainingsanteil,
  und die Schritte; an Tagen ohne Uhr bleibt die Zeile weg. Der neue Befehl
  `kk energy` zeigt dieselben Werte samt Gewicht ausfuehrlich, `kk energy report`
  den Wochenschnitt, und beide geben mit `--json` maschinenlesbar aus. Die Zahlen
  kommen aus den Werten, die das iPhone ohnehin schon aus HealthKit uebertraegt.
- `kk today` setzt hinter jeden Eintrag die Naehrstoff-Ampel als farbigen Punkt und
  zaehlt am Tagesende zusammen, wie viele Eintraege gruen, gelb und rot waren. Fehlen
  einem Lebensmittel die noetigen Naehrwerte, bleibt die Stelle leer und der Eintrag
  wird als „ohne Angabe" gefuehrt: eine falsche gruene Ampel waere schlechter als gar
  keine. Neu ist ausserdem `kk today --json`, das den ganzen Tag maschinenlesbar
  ausgibt, mit Farbe und Punktwert je Eintrag.
- Der neue Befehl `kk repair nutrients` trägt fehlende Nährwerte in älteren
  Lebensmitteln nach. Betroffen sind Einträge aus der Zeit, als die KI gesättigte
  Fette, Zucker und Salz gelegentlich ausließ; ihre Ampel fällt dadurch bis heute zu
  grün aus. Ohne weitere Angabe listet der Befehl nur auf, was er ändern würde,
  geschrieben wird erst mit `--apply`. Kalorien und Makronährwerte bleiben dabei
  unangetastet, damit vergangene Tagessummen sich nicht nachträglich verschieben.
- Eine Mahlzeit lässt sich jetzt vorplanen. In der Lebensmittelsuche gibt es dafür den Knopf „Für später planen", und im Eingabefeld schaltet das Kalender-Symbol den Planungsmodus ein: die nächste KI-Eingabe wird dann geplant statt gebucht. Der geplante Eintrag erscheint ausgegraut in seiner Mahlzeiten-Rubrik, zählt aber noch nicht zum Tag. Ein Tipp darauf trägt ihn ein, per Wischen lässt er sich verwerfen.

### Geändert

- Der Hintergrund der Fokus-Ansicht ist weniger stark verwischt. Das tageszeitabhängige Foto behält jetzt erkennbare Struktur, ohne die Lesbarkeit von Ring, Karten und Mahlzeitenliste zu beeinträchtigen.
- In der Menüleiste haben Wasser und Kaffee jetzt eigene Symbole und werden gleich bedient. Beim Wasser stehen ein Tropfen und eine Reihe Gläser, beim Kaffee eine Kaffeebohne und eine Reihe Tassen. Vorher waren die Wassergläser als dampfende Kaffeetassen gezeichnet, und der Kaffee ließ sich nur über Plus und Minus zählen; jetzt genügt ein Klick auf die gewünschte Tasse. Tassen über dem Tagesziel stehen abgesetzt und in Rot, und das Ziel heißt dort, was es ist: höchstens so viele Tassen. Am Ende beider Reihen steht immer eine leere Position, damit sich auch mehr als das Tagesziel eintragen lässt.

### Behoben

- Die Online-Lebensmittelsuche meldet nicht mehr sporadisch einen Serverfehler. Sie nutzt jetzt die neue, deutlich schnellere Suche von OpenFoodFacts und bevorzugt dabei Produktnamen in deiner Sprache.
- Lebensmittel ohne hinterlegte Nährwerte bekommen keine erfundene Ampel mehr. Bisher
  galt ein nicht erfasster Wert als null und damit als bester Fall, ein Burger ohne
  jede Angabe war deshalb grün. Jetzt steht dort ein graues Fragezeichen und der
  Hinweis „Keine Nährwerte hinterlegt". Dasselbe gilt für Einträge, hinter denen gar
  kein Lebensmittel mehr steht; die zeigten vorher wahllos Gelb.
- Die KI liefert bei Schätzungen jetzt zuverlässig auch gesättigte Fette, Zucker und
  Salz. Bisher blieben diese drei Werte in etwa jeder zwanzigsten Antwort einfach aus
  und wurden als null gespeichert, was die Nährstoff-Ampel zu freundlich ausfallen
  ließ: ein Erdbeer-Fruchtaufstrich ohne Zucker wurde grün, Pommes ohne Salz ebenso.
  Die Antwortform ist nun verbindlich vorgegeben, statt nur erbeten. Betrifft die
  Schnelleingabe in App, Watch, Menüleiste und Kommandozeile sowie die Foto-Erkennung.

## [1.21.0] – 2026-07-29

### Geändert
- Beim Scrollen verlieren sich die Zeilen jetzt in einem weichen Nebel unter dem
  Eingabefeld, statt an dessen Kante abgeschnitten zu werden. Stehst du oben am
  Anfang, ist der Nebel nicht da und du siehst den Tag unverstellt.

### Behoben
- Nach einer Buchung schien beim Scrollen Text durch die Lücke zwischen
  Eingabefeld und Rückgängig-Hinweis. Beide sitzen jetzt in einem gemeinsamen
  Rahmen, dazwischen bleibt nichts mehr durchsichtig.

## [1.20.0] – 2026-07-29

### Behoben
- Zählst du viele Dinge auf einmal auf, werden jetzt alle gebucht. Ab etwa sechs
  Positionen brach die Antwort der KI vorher mittendrin ab, und statt der
  Einträge stand eine technische Fehlermeldung auf dem Bildschirm. Reißt eine
  Antwort doch einmal ab, sagt die App das jetzt in klaren Worten.

## [1.19.0] – 2026-07-29

### Hinzugefügt
- Scrollst du den Kalorienring nach oben aus dem Bild, erscheint deine
  Restkalorienzahl klein oben in der Kopfzeile. Sie ist damit immer sichtbar,
  auch wenn du weit unten in deinen Mahlzeiten liest. Ein Tipp darauf zeigt wie
  beim großen Ring, wie dein Tagesziel zustande kommt.

## [1.18.0] – 2026-07-29

### Geändert
- Beim Scrollen wandern Datum und Kalorienring jetzt mit nach oben weg, nur das
  Eingabefeld bleibt unter der Wochenleiste stehen. Damit kannst du jederzeit
  etwas eintragen und siehst trotzdem deutlich mehr von deinen Mahlzeiten,
  besonders wenn du das iPhone quer hältst.

## [1.17.0] – 2026-07-29

### Geändert
- Auf dem Mac steht der Cursor beim Start der App direkt im Eingabefeld. Du
  kannst sofort lostippen, was du gegessen hast, ohne vorher hineinzuklicken.
- Auf dem iPhone im Querformat steht der Hebel jetzt neben Gewicht, Wasser und
  Kaffee statt darüber. Das spart eine Zeile, sodass die erste Mahlzeit wieder
  ins Bild rückt. Im Hochformat bleibt alles, wie es war.

### Behoben
- Die App zeigt nach dem Nachtwechsel den neuen Tag. Bisher blieb der Tag
  stehen, an dem du die App geöffnet hattest, was vor allem auf dem Mac auffiel,
  wo das Fenster tagelang offen bleibt. Ein Tag, den du bewusst aufgeschlagen
  hast, bleibt weiterhin stehen, wenn du kurz in eine andere App wechselst.

## [1.16.1] – 2026-07-28

## [1.16.0] – 2026-07-28

### Hinzugefügt
- Auf dem iPhone blätterst du jetzt durch die Tage, indem du über den oberen
  Bereich wischst — über das Datum, den Kalorienring oder das Eingabefeld. Der
  Tag folgt deinem Finger, der Nachbartag schaut schon an der Kante hervor. Die
  kleinen Pfeile bleiben, wo sie sind.
- Über dem Kalorienring liegt eine Wochenleiste mit den sieben Tagen der Woche.
  Ein Tipp springt direkt zu einem Tag. Unter jeder Zahl zeigt ein schmaler
  Balken, wie voll dein Budget an diesem Tag war: seine Länge ist der verbrauchte
  Anteil, seine Farbe dieselbe Bewertung, die auch der Ring trägt. Tage ohne
  Einträge bleiben leer.

## [1.15.0] – 2026-07-26

### Hinzugefügt
- Ein Tipp auf den Kalorienring zeigt, wie dein Tagesziel zustande kommt:
  Grundziel, Wochenendaufschlag, angerechnete Bewegung und angerechnetes Training.
  Bei der Bewegung steht dabei, wie viel davon schon im Grundziel steckt — dein
  Aktivitätslevel enthält Alltagsbewegung bereits, deshalb kommt nur der Teil
  darüber im Budget an.

## [1.14.0] – 2026-07-26

### Geändert
- Die Kaffee-Serie zählt jetzt richtig herum: Sie hält, solange du **höchstens**
  so viele Tassen trinkst wie eingestellt, und ein kaffeefreier Tag zählt mit.
  Bisher musste die Menge erreicht werden, wer wenig trank verlor die Serie. Über
  dem Limit reißt sie ab.
- Wer nach 17 Uhr etwas einträgt, bucht aufs Abendessen statt auf die Kaffeepause.
- Im Siri-Ergebnis sind die Mahlzeiten jetzt Symbole in einer Reihe, und die
  gebuchte ist hervorgehoben. Liegt der Eintrag in einer Nebenmahlzeit wie der
  Kaffeepause, steht sie mit dabei — vorher gab es von dort keinen Rückweg.

## [1.13.0] – 2026-07-26

### Hinzugefügt
- Siri zeigt nach dem Eintragen, was gebucht wurde, und lässt dich direkt dort
  handeln: „Rückgängig" nimmt die Eingabe zurück, und die Mahlzeit lässt sich
  korrigieren, ohne die App zu öffnen.
- Auf der Uhr hört Siri jetzt denselben Befehl wie am iPhone: mehrere Speisen in
  einem Satz werden getrennt gebucht, und ohne Angabe wählt sie die Mahlzeit nach
  der Uhrzeit statt alles als Snack einzutragen.
- In den Einstellungen steht ein Siri-Abschnitt mit den Sätzen, die funktionieren,
  und einem Weg in die Kurzbefehle-App.

## [1.12.0] – 2026-07-26

### Hinzugefügt
- Kaffee lässt sich per Siri eintragen: „Kaffee trinken in KalorienKompass".
  Mehrere Tassen auf einmal gehen auch, das Koffein wird mitgezählt und die
  Antwort nennt den Tagesstand.

### Behoben
- Diktiertes ging beim Beenden der Aufnahme verloren. Der Text bleibt jetzt
  stehen, und der Senden-Knopf lässt sich schon während des Diktats drücken:
  ein Tipp beendet die Aufnahme und bucht in einem Zug.

## [1.11.0] – 2026-07-26

### Geändert
- Sagst oder tippst du mehrere Dinge auf einmal, entstehen daraus jetzt einzelne
  Einträge: „Rührei mit Speck und ein Kaffee" wird getrennt gebucht, jeder Posten
  einzeln korrigierbar. Ein Gericht aus Zutaten bleibt ein Eintrag, „Lasagne" also
  weiterhin eine Zeile. Rückgängig nimmt die ganze Eingabe auf einmal zurück.
  Gilt für den Fokus-Modus, Siri, die Menubar und die Kommandozeile.

## [1.10.0] – 2026-07-26

### Hinzugefügt

- `--time HH:MM` für `kk add`: die Mahlzeit wird aus der angegebenen Essenszeit
  bestimmt, nicht aus der Uhrzeit der Eingabe
- `kk today --date` und `kk today --yesterday`: die Einträge eines vergangenen Tages
  ansehen, samt Kaffee-Stand dieses Tages
- `kk coffee --date`: den Kaffee-Stand eines vergangenen Tages lesen und ändern

### Behoben

- `kk add` auf einen vergangenen Tag leitete die Mahlzeit aus der aktuellen Uhrzeit
  ab. Ein morgens nachgetragenes Abendessen landete so still im Frühstück. Ohne
  `--meal` oder `--time` bricht der Befehl für einen vergangenen Tag jetzt mit einem
  Hinweis ab, statt zu raten
- Datumsangaben in der Zukunft werden abgelehnt. Ein Tippfehler im Monat legte vorher
  still einen Eintrag an, den niemand mehr findet

### Geändert

- Die Datumsoptionen `--date` und `--yesterday` teilen in allen Befehlen einen Parser
  samt Fehlermeldung. `vorgestern` wird überall genannt, und unbekannte Argumente
  werden nicht mehr stillschweigend verschluckt
- `kk coffee add N` schreibt in einer Transaktion statt in N aufeinanderfolgenden
  Schreibvorgängen

## [1.9.0] – 2026-07-26

### Hinzugefügt
- Dieser Änderungsverlauf, erreichbar über Einstellungen. Nach einem Update zeigt
  die App einmalig, was seither dazugekommen ist.

## [1.8.0] – 2026-07-26

### Behoben
- Die Komplikation auf der Apple Watch aktualisiert sich jetzt von selbst. Bisher
  zeigte sie den Stand des letzten Besuchs in der Watch-App, oft stundenalt. Das
  iPhone schickt seine Zahlen nun direkt an die Uhr, die dafür nicht mehr geöffnet
  werden muss. Buchungen vom Mac oder über die Kommandozeile holt sich die Uhr
  regelmäßig selbst.

## [1.7.0] – 2026-07-26

### Geändert
- Entwicklungsversionen der App arbeiten auf einem eigenen Datenbestand und können
  die echten Daten nicht mehr anfassen. Sie heißen auf dem Gerät „KK Debug" und
  liegen neben der regulären App, statt sie zu ersetzen.

### Entfernt
- Das nie sichtbare Notizfeld am Tag. Es hätte beim ersten Befüllen den gesamten
  iCloud-Abgleich blockiert.

## [1.6.0] – 2026-07-25

### Behoben
- Auswertungen über mehrere Tage zählen jetzt Tage statt Datensätze. Der
  Aktivitätsdurchschnitt ließ sich vorher von einem einzigen Tag erfüllen, und die
  Gewichtskurve bekam pro Gerät einen Punkt.
- Doppelte Datensätze, die der iCloud-Abgleich über die Zeit angelegt hat, werden
  nach jedem Abgleich einmalig zusammengeführt. Vergangene Tage wurden vorher nie
  bereinigt.
- Antwortest du auf zwei Geräten am selben Tag auf deinen Hebel, zählt jetzt
  eindeutig die zuletzt gegebene Antwort. Die Quote in der Wochenauswertung
  schwankte vorher je nach Gerät.

## [1.5.0] – 2026-07-25

### Behoben
- Das bloße Anschauen eines Tages legt keine Daten mehr an und löscht keine. Jeder
  Tageswechsel erzeugte vorher einen leeren Datensatz, und ein Bildschirm-Refresh
  während eines laufenden iCloud-Abgleichs konnte ankommende Daten für Duplikate
  halten.
- Die Wasser-Knöpfe im Widget schreiben auf denselben Datensatz, den die App
  anzeigt. Ein Minus konnte vorher wirkungslos verpuffen.

## [1.4.0] – 2026-07-25

### Entfernt
- Der Abenteuer-Modus und das alte Vollmodus-Layout. Der Fokus-Modus ist seit
  Längerem die einzige Ansicht, die übrigen Bildschirme wurden nur noch
  mitgeschleppt.

## [1.3.0] – 2026-07-25

### Behoben
- Deine Profildaten gehen nicht mehr verloren. Beim Start konnte ein leeres
  Standardprofil entstehen, bevor iCloud das echte geliefert hatte; die
  anschließende Bereinigung behielt dann das leere und löschte das echte, auf allen
  Geräten. Gewicht, Größe, Alter und Zielgewicht waren damit weg.

## [1.2.0] – 2026-07-24

### Behoben
- Die App stürzt beim Start nicht mehr ab, wenn sich die Datenbank nicht öffnen
  lässt. Sie versucht der Reihe nach mehrere Wege und legt eine Sicherung an, statt
  aufzugeben.

## [1.1.0] – 2026-07-22

### Hinzugefügt
- Der Kalorienring färbt sich nach dem verbleibenden Budget: grün, solange Puffer
  da ist, rot über dem Ziel.
- Der aktuelle Hebel aus dem wöchentlichen Check-In erscheint im Fokus-Modus im
  Moment der Entscheidung, mit Tagesrückmeldung und Wochenauswertung.
- Startgewicht und Startdatum lassen sich im Profil erfassen.

## [1.0.0] – 2026-02

### Hinzugefügt
- Erste Fassung: Fokus-Modus mit Freitext- und Foto-Eingabe per KI, Kalorienring,
  Wasser und Kaffee, Mahlzeitenübersicht, Lebensmittelsuche mit Barcode-Scanner,
  Apple-Watch-App mit Komplikationen, Widgets, Menubar-App auf dem Mac, Siri und
  Kurzbefehle, iCloud-Abgleich über alle Geräte.

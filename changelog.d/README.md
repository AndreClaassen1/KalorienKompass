# Offene Changelog-Einträge

Jede Änderung bekommt hier **eine eigene Datei**, statt direkt in `CHANGELOG.md`
geschrieben zu werden. Beim Versions-Bump sammelt `bin/freeze-changelog` sie ein,
gruppiert sie nach Rubrik, schreibt daraus den Versionsblock und löscht sie
wieder.

**Warum getrennte Dateien:** Der `[Unreleased]`-Block ist eine einzige Stelle, in
die jeder Branch schreibt. Wird parallel in mehreren Worktrees gearbeitet,
kollidieren sie dort fast bei jedem Merge, und zwar in derselben Zeile. Zwei
Branches berühren nie dieselbe Fragment-Datei; Konflikte sind damit
ausgeschlossen statt nur seltener.

## Dateiname

```
<rubrik>.<slug>.md
```

Der Slug ist frei; die Issue-Nummer voranzustellen hält ihn eindeutig und
verweist auf den Kontext.

| Rubrik im Dateinamen | Überschrift im Changelog |
|---|---|
| `hinzugefuegt` | Hinzugefügt |
| `geaendert` | Geändert |
| `veraltet` | Veraltet |
| `entfernt` | Entfernt |
| `behoben` | Behoben |
| `sicherheit` | Sicherheit |

Beispiel: `behoben.42-doppelte-eintraege.md`

## Inhalt

Reine Prosa. Der Text wird zu einem Aufzählungspunkt, Folgezeilen werden
eingerückt:

```markdown
Ein Eintrag ohne Datum wird nicht mehr stumm einsortiert, sondern zur
Nachfrage vorgelegt.
```

Brauchst du Unterpunkte oder mehrere Einträge, schreib die `- ` selbst — dann
bleibt der Text unangetastet übernommen:

```markdown
- Erster Punkt.
- Zweiter Punkt mit Unterpunkt:
  - Detail
```

Schreibe für die Nutzer, nicht für Entwickler: Was ändert sich für sie, und
warum. Keine Gedankenstriche, keine Commit-Sprache.

## Weiterhin möglich

Ein Eintrag direkt unter `## [Unreleased]` in `CHANGELOG.md` funktioniert
unverändert und wird beim Einfrieren mit den Fragmenten zusammengeführt. Für
alles, was parallel zu anderen Branches entsteht, ist die Fragment-Datei aber
der konfliktfreie Weg.

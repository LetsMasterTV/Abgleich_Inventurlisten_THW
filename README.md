# XLSX Abgleich Inventurlisten THW

Eine macOS-App zum Vergleichen zweier Inventurlisten-Exporte (`.xlsx`) auf neu, gelöschte oder geänderte Einträge.

## Was die App macht

Du wählst zwei Excel-Dateien aus – eine "alte" und eine "neue" Inventurliste – und die App zeigt dir automatisch:

- **Neu**: Einträge, die nur in der neuen Datei vorkommen
- **Entfernt**: Einträge, die nur in der alten Datei vorkommen
- **Geändert**: Einträge, die in beiden Dateien vorkommen, aber sich in mindestens einem Feld unterscheiden (mit Alt- und Neu-Wert nebeneinander)
- **Unverändert**: Einträge, die identisch geblieben sind

> [!NOTE]
> Weitere Infos findest du bei im Abschnitt: [Bedienung](##Bedienung) 

## Voraussetzungen

- **macOS** (getestet unter macOS Tahoe 26.5.2)

## Installation unter macOS

Da diese App nicht über einen Apple-Entwickler-Account zertifiziert ist, blockiert macOS standardmäßig den Start nach dem Download. Folge dieser Anleitung, um das Programm sicher einzurichten.

### 📥 1. Download

1. Öffne die ['XLSX Abgleich Inventurlisten THW'-Latest-Release](https://github.com/LetsMasterTV/Abgleich_Inventurlisten_THW/releases/tag/latest).
2. Lade die aktuelle Datei herunter. Wähle zwischen `.dmg`(*Standard*) oder `.zip`.

### ⚙️ 2. Installation

Der Ablauf ist derselbe wie bei allen anderen Programmen aus dem Internet.

Gehe entsprechend der Spalte vor, die zu deiner heruntergeladenen Datei passt.

| <center>`.dmg`-Datei</center>| <center>`.zip`-Datei</center>|
| --- | --- |
| 1. Doppelklick auf die `.dmg`-Datei. | 1. Doppelklick auf die `.zip`-Datei zum Entpacken. |
| 2. Ziehe die App per Drag-and-Drop in den Ordner **Programme**. | 2. Verschiebe die entpackte App-Datei in den Ordner **Programme**. |
| 3. Werfe die `.dmg`-Datei aus und lösche sie. | 3. Lege die ursprüngliche `.zip`-Datei in den Papierkorb. |

### 🔐 3. Sicherheitswarnung umgehen (Wichtig)

Wenn du die App das erste Mal aus dem Programme-Ordner startest, zeigt macOS die Meldung: *„... kann nicht geöffnet werden, da es von einem nicht verifizierten Entwickler stammt“*.

So schaltest du die App frei:

- #### Methode 1 (Am schnellsten)
  1. Öffne den Ordner **Programme** im Finder.
  2. Halte die **Control-Taste (Strg ⌃)** gedrückt und klicke auf die App.
  3. Wähle im Kontextmenü **Öffnen**.
  4. Es erscheint ein neues Fenster mit einem zusätzlichen Button. Klicke dort auf **Öffnen**. *(Dieser Button fehlt beim normalen Doppelklick!)*.
  5. Ab jetzt startet die App immer ganz normal per einfachem Doppelklick.

- #### Methode 2 (Über die Systemeinstellungen)
  1. Versuche die App einmal normal per Doppelklick zu starten und schließe die Fehlermeldung.
  2. Öffne die **Systemeinstellungen** deines Macs.
  3. Gehe zu **Datenschutz & Sicherheit** und scrolle nach unten zum Bereich *Sicherheit*.
  4. Dort siehst du den Hinweis, dass die App blockiert wurde. Klicke auf **Dennoch öffnen**.
  5. Bestätige die Aktion mit deinem Mac-Passwort oder per Touch ID.

## Bedienung 

### Vergleich starten

1. **"Alte Datei wählen"** → erste xlsx-Datei auswählen
2. **"Neue Datei wählen"** → zweite xlsx-Datei auswählen
3. Der Vergleich läuft automatisch, sobald beide Dateien geladen sind
    - unter der Auflistung aller Neuen, Gelöschten und Geänderten Daten befindet sich ein Button der zur einer Auflistung aller Unveränderten Einträge verweißt (sofern welche vorhanden sind)  

> [!IMPORTANT]
> - Die App erwartet ein [spezielles Excel Format](##ErwartetesExcel-Format)
> - Änderungen an Sach- und Inventarnummer können nicht als Änderung erfasst werden, sondern werden als Neu und Gelöscht angezeigt siehe [Wie Zeilen einander zugeordnet werden](##WieZeileneinanderzugeordnetwerden).
> - siehe [Bekannte Einschränkungen](##BekannteEinschränkungen)


### Neue Datein vergleichen
- Ist für einen Slot bereits eine Datei geladen, fragt ein Popup vor dem Überschreiben nach
  - Nach dem überschreiben einer einzelnen Datei werden beide geladen Datein sofort wieder verglichen
- der **Pfeil** in der oben-rechts setzt beide geladenen Dateien und den Vergleich zurück

## Erwartetes Excel-Format

Die App benötigt die Excel Datein zwigend als .xlsx Datei, alle Anderen Dateiformate werden nicht Akzeptiert und können nicht verarbeitet werden.

Die App erwartet eine Kopfzeile mit folgenden Spaltennamen, in beliebiger Reihenfolge:

```
Ebene, Art, STAN soll, Menge Ist, THWin Bestand, Bestand Fahrzeug,
Beschreibung, Sachnummer, Inventarnummer, Geraetenummer, Status
```

- Leere Zellen sind unproblematisch und werden als leerer Wert behandelt
- Dopplungen einer Zeile sind unproblematisch und werden nach vollständigkeit in der neuen Datei überprüft
- Enthält die Datei mehrere Sheets, werden alle durchsucht; leere Sheets werden übersprungen
- Werte werden automatisch von führenden/nachgestellten Leerzeichen befreit

## Wie Zeilen einander zugeordnet werden

Jeder Eintrag bekommt einen Schlüssel aus **Inventarnummer + Sachnummer**. Zwei Zeilen mit identischem Schlüssel gelten als "derselbe" Gegenstand über beide Dateien hinweg.

**Einschränkung:** Fehlt bei mehreren Zeilen sowohl die Inventarnummer als auch eine eindeutige Sachnummer (z. B. mehrere baugleiche Ersatzteile ohne individuelle Kennzeichnung), können diese Zeilen nicht hundertprozentig zuverlässig einander zugeordnet werden. Die App erkennt solche Fälle und nummeriert sie durch, statt abzustürzen – die Zuordnung kann in diesen Sonderfällen aber von der Position in der Datei abhängen.

## Architektur

| Datei/Typ | Zweck |
|---|---|
| `Bestandsobjekt` | Ein einzelner Inventar-Eintrag (Datenmodell) |
| `Inventurliste` | Geparstes Excel-Dokument, unveränderlich |
| `XLSXDiff` | Ergebnis eines Vergleichs zweier `Inventurliste`n |
| `XLSXViewModel` | Hält den UI-Zustand (geladene Dateien, aktueller Vergleich, Fehler) |
| `ContentView` | Hauptfenster: Datei-Auswahl, Reset, Bestätigungs-Popup |
| `DiffView` | Zeigt die vier Kategorien (Neu/Entfernt/Geändert/Unverändert) |
| `BestandsobjektRow` | Kompakte Detailansicht eines einzelnen Eintrags |
| `ModifiedBestandsobjektRow` | Wie oben, zeigt bei geänderten Feldern zusätzlich Alt- und Neuwert |
| `UnchangedListView` | Separate, sortierte Liste aller unveränderten Einträge |

Die App verwendet **kein Netzwerk und keine dauerhafte Speicherung**: Alle Daten leben nur im Arbeitsspeicher, solange die App läuft. Eine temporäre Kopie der xlsx-Datei wird beim Einlesen kurzzeitig angelegt und direkt danach wieder gelöscht.

## Bekannte Einschränkungen

- Getestet mit Exporten aus Microsoft-Access-Abfragen; andere Erzeugungswege (z. B. Numbers, Google Sheets) wurden nicht gesondert geprüft
- Kein Undo für den "Zurücksetzen"-Button – einmal zurückgesetzt, müssen beide Dateien erneut geladen werden
- Keine Möglichkeit, die Ergebnisse direkt aus der App heraus zu exportieren (z. B. als PDF oder neue Excel-Datei)

## Anpassung 

Eine Anpassung für Andere Header ist grundsätzlich nur mit code Änderungen möglich.

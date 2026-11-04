# Werkzeuge und Tests

## Make-Ziele

| Ziel | Wirkung |
|------|---------|
| `make` | Binärabbilder nach `build/`, Listings, Referenzen, `sb4515/SB4515.mzf` |
| `make check` | `build/SB4515.bin` und die Daten der MZF-Datei gegen `sb4515/PASCAL.OBJ` |
| `make test` | u. a. `tools/test_sb4515_run.py` (Programmlauf im Emulator) |
| `make reloc-check` | Verschiebbarkeit, mit Programmlauf jeder verschobenen Fassung |
| `make ref` | `docs/BEFEHLE_SB4515.md` |
| `make doku4515` | diese Dokumentation nach `sb4515/doku/` |
| `make sb4515-src` | `sb4515/SB4515.asm` aus `PASCAL.OBJ` und der Konfiguration neu erzeugen |

## Programme

| Datei | Aufgabe |
|-------|---------|
| `tools/dis4515.py` | Analyse: Code ab den Einsprüngen und Sprungtabellen verfolgen, Daten erkennen, den Monitorteil aus `SB1511.asm` übernehmen |
| `tools/emit4515.py` | Ausgabe der Quelle: Labels, Symbole statt Zahlen, Gleitkommakonstanten mit Dezimalwert, Schlüsselworttabelle mit Token |
| `tools/mklst.py` | Listing (`.lst`) zu einer pasmo-Quelle |
| `tools/test_sb4515_run.py` | Programmlauf im Emulator |
| `tools/reloccheck.py` | Verschiebbarkeit prüfen |
| `tools/mkref4515.py` | Befehlsreferenz |
| `tools/mkdoku4515.py` | diese Dokumentation |
| `tools/mkmzf.py` | MZF-Datei aus einem Binärabbild |

## Der Programmlauf im Emulator

`tools/test_sb4515_run.py` startet den Interpreter in `z88dk-ticks` bei `PAS_NEW` mit
Stapelobergrenze C000h. Der Code ist der des Originals; umgeleitet sind nur die Geräte:

| Monitorroutine | Ersatz |
|----------------|--------|
| `PRNT`, `?DSP`, `NL`, `LETNL` | Ausgabe in einen Puffer; Spalte und `DSPXY` werden mitgeführt |
| `GETL` | nächste Zeile eines Skripts, mit dem schon ausgegebenen Zeilenanfang davor (wie das Lesen einer Bildschirmzeile) |
| `BRKEY` | nie BREAK |
| `GETKY`, `NOKKEY`, `BELL` | keine Taste / sofort zurück |

Die Sitzungen geben Programme über den Editor ein, führen sie mit `G` aus und vergleichen die
Ausgabe: INTEGER, CHAR und BOOLEAN, Gleitkommafunktionen (mit Python nachgerechnet), READ mit
Fehleingabe, WRITE mit Format, Listing und Fehlermeldungen im Prüflauf und zur Laufzeit.

Nicht nachgebildet sind der Zeitgeber 8253 (`TIMST` wartet auf ihn), Kassette, Drucker, Grafik
und das Farbterminal; diese Teile sind nur durch Lesen des Codes und das Handbuch belegt. Den
Start der MZF-Datei vom Monitor-Kaltstart bis zur Kommandoschleife kann man im Emulator nur mit
übersprungenem `TIMST` nachvollziehen.

# Unterschiede zu SB-6511

SB-6610 entstand aus derselben Quelle wie SB-6511. Etwa drei Viertel des BASIC-Teils stimmen
Byte für Byte überein, wenn man nur die Adressen außer Acht lässt. Die folgende Übersicht fasst
alle gefundenen Abweichungen zusammen; Einzelheiten stehen auf den jeweiligen Seiten.

## Neu in SB-6610

| Neuerung | Wo | Seite |
|----------|----|-------|
| BCD-Arithmetik mit 16 Stellen, 9-Byte-Zahlen | {{FPA_FLAG}}–37D6h | [Zahlen](zahlen.html) |
| `PRINT [/P] USING schablone; …` (Token 9Dh) | `PR_USING` {{PR_USING}}, `USING_PARSE` {{USING_PARSE}}, `NUM_OUT` {{NUM_OUT}} | [PRINT USING](printusing.html) |
| `DELETE a-b` löscht Programmzeilen; `DELETE "datei"` wie bisher | `ST_DELLINES` {{ST_DELLINES}} | [Tokenizer](tokenizer.html#delete-programmzeilen-loeschen) |
| eindimensionale Felder mit Index über 255 | `ARR_FIND` | [Interpreter](interpreter.html#felder) |
| `GET` liefert eine gehaltene Taste nur einmal | `GET_LASTKEY` {{GET_LASTKEY}} | [Ein-/Ausgabe](ein-ausgabe.html#get) |
| Sperre für `LIST` und `SAVE` (`LIST_LOCK`, ungeklärt) | `CHK_DIRECT_LK` {{CHK_DIRECT_LK}} | [Interpreter](interpreter.html#list-lock-ein-unbekannter-listschutz) |
| Druckerbreite 80/136 Zeichen bei Schriftwechsel | `PRN_DOTW` {{PRN_DOTW}} | [Ein-/Ausgabe](ein-ausgabe.html#drucker) |
| Ziffer 0 als Buchstabe „O“ bei PRINT USING (`POKE $002D,1`) | `USING_DIGS` | [PRINT USING](printusing.html) |
| drei nachträgliche Korrekturen (INT, POINT, Bereichszeiger) | `INT_FINISH`, `POINT_GET`, `AREA_RESIZE_CLR` | [Überblick](index.html#fassungen) |

## Weggefallen

| Was | Folge |
|-----|-------|
| `^`, `SIN(`, `COS(`, `TAN(`, `ATN(`, `EXP(`, `LOG(`, `LN(` | Tabelleneinträge zeigen auf `ERR_01`: Fehler 1. Das Handbuch (2.4.4) verweist auf BASIC-Unterprogramme in der Datei „FUNCTION“ der Systemdiskette. |
| `APPEND` | Fehler 1 |
| GP-IB-Befehle (`SSRQ`, `GPIB`, `PPC` … `EOI`), `ON SRQ` | Plätze in der Schlüsselworttabelle frei (FFh) |
| RS-232C (`RSMODE`, `RSO`, `RSI`), Ringpuffer, SIO-Interrupts | Monitor läuft mit `IM 1` statt `IM 2` |
| Fehler 29–39 (RS-232C, GP-IB) | Nummern bleiben in der Kette, werden aber nicht mehr ausgelöst |

## Geändert

| Was | SB-6511 | SB-6610 |
|-----|---------|---------|
| Zahl im Speicher | 5 Bytes (Exponent + 32-Bit-Mantisse) | 9 Bytes (16 BCD-Ziffern + Exponentbyte) |
| Zahlvariable | Name 2 + Wert 5 = 7 Bytes | Name 2 + Wert 9 = 11 Bytes |
| FOR-Eintrag | 19 Bytes | 27 Bytes |
| Arbeitsbereich | ab 6B00h | ab {{RAM_START}} |
| Programmtext | ab 725Ch | ab {{PRGTXT}} |
| Datei in falschem Modus | Fehler 44 | Fehler 45 |
| Datei zu groß beim Schreiben | Fehler 55 | Fehler 53 |
| Port bei `INP@`/`OUT@` | `EVAL_ADDR` | `EVAL_BYTE` (0–255) |
| Funktionstastentexte | Grenze 1201h | Grenze 1221h |
| Ausgabe von Zahlen | bis 8 Ziffern | bis 16 Ziffern, Exponentform ab 17 Stellen |

## Gleich geblieben

Monitor SB-1510 (bis auf `IM 1`), Bildschirmeditor, Tastatur, Uhr und MUSIC, das Token-Format
mit allen Token-Nummern, die Interpreterschleife, Strings, das Disketten-Dateisystem
(BTX/OBJ/BSD/BRD), Kassette, Grafik und der Floppy-Treiber. Diese Teile beschreibt die
[SB-6511-Dokumentation](../../basic-sb6511/doku-basic/index.html) ausführlich; die Namen der Routinen sind
in beiden Quellen gleich, nur die Adressen unterscheiden sich.

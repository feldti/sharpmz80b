# Ein-/Ausgabe, Dateien, Drucker

Ein- und Ausgabe, Dateisystem, Kassette und Floppy-Treiber sind aus SB-6511 übernommen. Die
[SB-6511-Dokumentation](../../basic-sb6511/doku-basic/ein-ausgabe.html) beschreibt das Disketten-Dateisystem
(Verzeichnis, Belegungstabelle, Dateitypen BTX/OBJ/BSD/BRD, Satzdateien) ausführlich; es gilt
unverändert. Diese Seite nennt die Unterschiede.

## Geräte und DEV_DISPATCH

Jedes `PRINT`-Element und jede Eingabe geht über `DEV_DISPATCH` ({{DEV_DISPATCH}}). Die Routine
wählt aus einer Tabelle nach `FILE_NO` (80h Bildschirm, 81h DATA, 82h Drucker `/P`, 83h Kassette
`/T`, 1–127 Datei `#n`) bzw. nach dem Dateityp.

`DEVTAB_PRINT` ({{DEVTAB_PRINT}}) hat wie bei SB-6511 30 Einträge: 0–14 Zeilenabschluss, 15–29
ein Element ausgeben. Die Einträge 4–9 gehörten bei SB-6511 zu den Geräten 84h–89h (GP-IB,
RS-232C) und sind hier unbenutzt. In ihren 12 Bytes steht stattdessen Code: der Schluss von `INT`
(`INT_FINISH`, {{INT_FINISH}}), eine der nachträglichen Korrekturen. `DEVTAB_INPUT`
({{DEVTAB_INPUT}}) hat 15 Einträge für die Eingabe; die Tastatur behandelt `INPUT` selbst,
über die Tabelle lesen Kassette (`TINPUT`) und Datei (`FILE_GET`), die Geräte 84h–89h führen zu
Fehler 1.

## PRINT

`ST_PRINT` ({{ST_PRINT}}) arbeitet wie bei SB-6511, setzt aber zu Beginn `USING_PTR` auf 0 und
prüft nach `PRINT` bzw. `PRINT/P` auf das Token `USING` ([PRINT USING](printusing.html)). Zahlen
werden mit bis zu 16 Ziffern ausgegeben, davor ein Leerzeichen oder `-`.

## GET

`GET var` ({{ST_GET}}) liest wie bei SB-6511 eine Taste ohne zu warten. Neu: `GET_LASTKEY`
({{GET_LASTKEY}}) merkt sich die zuletzt gelieferte Taste. Wird beim nächsten `GET` dieselbe
Taste gemeldet, weil sie noch gedrückt ist, gibt `GET` einen leeren String bzw. 0 zurück. Eine
gehaltene Taste erscheint so nur einmal, die Tastenwiederholung der Tastaturroutine wirkt sich
nicht aus.

## Dateien

Dateibefehle und Dateisystem sind gleich geblieben. Geändert haben sich zwei Fehlernummern; das
Handbuch (Anhang A.2) nennt dieselben Bedeutungen:

| Fall | SB-6511 | SB-6610 | Handbuch |
|------|--------:|--------:|----------|
| Datei lesen/schreiben in anderem Modus als geöffnet (`FILE_GET`/`FILE_PUT`) | 44 | 45 | „A file was accessed in different mode from ROPEN, WOPEN or XOPEN“ |
| sequentielle Datei wird beim Schreiben zu groß | 55 | 53 | „File space on the diskette is insufficient“ |

`DELETE` löscht weiterhin Dateien, wenn das Argument kein Zeilenbereich ist
([Tokenizer: DELETE](tokenizer.html#delete-programmzeilen-loeschen)). Der Floppy-Motor wird
an allen Stellen über den kleinen Sprungpunkt `MOTOR_OFF` ({{MOTOR_OFF}}) abgeschaltet, der nach
`FD_MOTOR_OFF` ({{FD_MOTOR_OFF}}) weiterleitet.

Der Arbeitsbereich der Dateiverwaltung (aktuelle Datei `FC_IDX` …, Dateitabelle `FILETAB`,
Puffer ab 6650h) liegt um A00h tiefer als bei SB-6511, siehe
[Aufbau und Speicher](architektur.html#arbeitsbereich-zur-laufzeit).

## Drucker

Die Druckerbefehle `PRINT/P`, `LIST/P`, `PAGE/P`, `IMAGE/P` und `COPY/P` sind übernommen. Neu ist
`PRN_DOTW` ({{PRN_DOTW}}), die Breite einer Druckzeile in Punkten:

| Steuerzeichen im Text | an den Drucker | `PRN_DOTW` | Zeichen je Zeile |
|-----------------------|----------------|-----------:|-----------------:|
| 14h | 0Fh (Schmalschrift) | 0330h = 816 | 136 |
| 05h, 06h, 10h, 11h, 12h, 13h, 15h | wie SB-6511 | 01E0h = 480 | 80 |

`PRN_C_NORMW` und `PRN_C_WIDEW` stellen den Wert um, `PRN_SETCOL`/`PRN_COLWRAP` ({{PRN_COLWRAP}})
rechnen die Druckspalte danach modulo 80 bzw. 136. Bei SB-6511 galt immer die feste Breite.

## Grafik und Bildschirm

Grafikbefehle, `CONSOLE`, `CURSOR`, `CSR`, `POS` und `CHARACTER$` sind unverändert. `POINT(x,y)`
ruft `GR_POINT` jetzt über `POINT_GET` ({{POINT_GET}}) auf, das das Registerpaar BC rettet – eine
der Korrekturen gegenüber der älteren Fassung. Eine Kopie dieser Routinen aus einem älteren
Entwicklungsstand steht unerreicht bei 5A13h ([Speicherreste](architektur.html#speicherreste)).

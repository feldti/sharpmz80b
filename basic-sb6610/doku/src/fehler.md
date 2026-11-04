# Fehler und Fehlerbehandlung

Die Fehlerbehandlung ist dieselbe wie bei SB-6511
([SB-6511: Fehler](../../basic-sb6511/doku-basic/fehler.html)). Neu sind nur einzelne Zuordnungen von
Fehlernummern, und die Nummern der weggefallenen Schnittstellen werden nicht mehr ausgelöst.

## Meldungen

| Meldung | Bedeutung |
|---------|-----------|
| `*Error n` | Fehler n im Direktmodus |
| `*Error n in z` | Fehler n in Programmzeile z |
| `*Break` / `*Break in z` | Abbruch mit der BREAK-Taste |
| `Ready` | bereit für die nächste Eingabe |

## Ablauf eines Fehlers

Jeder Fehler springt in die Kette `ERR_01` … `ERR_70` (ab {{ERR_01}}): Jeder Einsprung lädt seine
Nummer in A, das folgende `DEFB 01h` (= `LD BC,nn`) verschluckt die übrigen `LD A,n`, am Ende geht
es nach `ERROR` ({{ERROR}}):

1. Nummer nach `ERRNUM`. Läuft gerade der Autostart (`RUN FDn"AUTO RUN"` beim Einschalten), geht
   es ohne Meldung nach „Ready“ – fehlt `AUTO RUN` auf der Diskette, sieht man also nichts.
2. Dateien und Geräte schließen (`CLOSE_ALL`), Links wiederherstellen (`RELINK`).
3. Im Programm mit aktivem `ON ERROR GOTO` (`ONERR_FLAG` = 1): Flag auf 2, Stack zurücksetzen und
   zur Behandlerzeile springen. `ERL` und `ERN` liefern dann Zeile und Nummer, `RESUME` kehrt zurück.
4. Sonst: `ON ERROR` aus, Stacks und Variablen löschen, `*Error n` (im Programm mit `in z`),
   Piepton, „Ready“.

## Fehlernummern

Die Tabelle verbindet die Deutung aus dem Code (Kommentar in der Kette) mit dem Text aus Anhang A.2
des Handbuchs. Nummern ohne Handbuchtext sind dort leer.

{{FEHLERTABELLE}}

## Unterschiede zu SB-6511

- **45** statt 44, wenn eine Datei in einem anderen Modus benutzt wird, als sie geöffnet wurde
  (`FILE_GET`, `FILE_PUT`).
- **53** statt 55, wenn eine sequentielle Datei beim Schreiben über 64 KB wachsen würde.
- **29–39** (RS-232C und GP-IB) stehen noch in der Kette, werden aber nicht mehr ausgelöst.
- **1** für die fehlenden Funktionen `^`, `SIN`, `COS`, `TAN`, `ATN`, `EXP`, `LOG`, `LN` und für
  `APPEND`, außerdem bei unzulässigen `PRINT USING`-Schablonen und Zahlen in Exponentform unter
  `USING`.
- **2** für Überlauf über 9.999999999999999E+78 und Division durch 0; kleinere Beträge als 1E-48
  werden ohne Fehler zu 0.
- **3** sofort, wenn ein Wert für einen Befehl (Adresse, Index …) eine Million oder mehr beträgt:
  `VAL2UINT` prüft dafür die oberen zehn Ziffern. Werte zwischen 65536 und 999999 und negative
  Werte meldet wie bei SB-6511 der aufrufende Befehl (meist ebenfalls Fehler 3). Außerdem bei
  `DIM` mit einem ersten Index über 255 in einem zweidimensionalen Feld.

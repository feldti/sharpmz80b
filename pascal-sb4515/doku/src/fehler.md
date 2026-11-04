# Fehler

## Ausgabe

Alle Fehler laufen über `ERROR` ({{ERROR}}). Die Nummer ist BCD-kodiert und wird zweistellig
ausgegeben (einstellige mit Leerzeichen). Was hinter der Nummer steht, hängt von `RUN_MODE` ab:

| Zustand | `RUN_MODE` | Ausgabe |
|---------|-----------:|---------|
| Kommandomodus | 0 | `*Err 40*` |
| Prüflauf (`G`) | 1 | `*Err 19* Line   2.` – Nummer der Zeile, in der der Fehler erkannt wurde |
| Ausführung | 2 | `*Err 13* Run*` |

Danach geht es nach `PAS_READY` („Ready.“). Ein Fehler zur Laufzeit beendet das Programm; es gibt
keine Fehlerbehandlung im Programm.

## Fehlereinsprünge

Für jeden Fehler gibt es einen Einsprung `ERR_nn` ab {{ERR_01}}, der nur die Nummer lädt:

```
ERR_01: LD   A,01h
        DEFB 01h          ; LD BC,nn: verschluckt das folgende LD A,n
ERR_02: LD   A,02h
        DEFB 01h
...
ERR_55: LD   A,55h
ERROR:  LD   B,A
```

Das Byte 01h ist der Opcode von `LD BC,nn`; es verschluckt jeweils den nächsten Befehl, so dass
jeder Einsprung mit seiner Nummer in A bei `ERROR` ankommt. Die Prüfroutinen springen meist
bedingt dorthin (`JP NZ,ERR_08`).

## Fehlernummern

Texte nach dem Handbuch (Error message table, S. 137). Wo der Scan das fehlende Zeichen nicht
zeigt, ist es aus dem Code erschlossen; 48–55 beschreibt das Handbuch nicht.

{{FEHLERTABELLE}}

## Häufige Ursachen

| Fehler | Typischer Anlass |
|--------|------------------|
| 01 | Programm ohne `END.` oder Text endet mitten in einer Anweisung |
| 04 | falscher Typ, z. B. `writeln(b)` mit `BOOLEAN`, `DIV` mit `REAL` |
| 13 | Überlauf (INTEGER, REAL über 0.92E+19), Division durch 0, Feldindex außerhalb, Koordinate außerhalb, zu wenig Platz für Symboltabellen |
| 17 | verschiedene Typen, z. B. `1/3` mit INTEGER-Werten (`/` verlangt REAL) |
| 27 | Bezeichner nicht deklariert |
| 39 | Programm passt nicht in den Speicher, Laufzeitstapel voll, Funktionstastentexte zu lang |
| 40 | unbekanntes Editorkommando |
| 48 | `G` oder `S` ohne Programm |

## Kassettenfehler im Programmlauf

Lese- und Schreibfehler bei Datendateien brechen nicht sofort ab. `CMT_ERR34`/`CMT_ERR35` zeigen

```
Err 34* Run*
** Push key [ C)ontinue E)ditor ]
```

und warten auf eine Taste: `C` versucht es noch einmal, `E` kehrt zum Editor zurück.

## BREAK

BREAK beim Listing, beim Eingeben einer Zeile, in Schleifen und bei Kassettenoperationen führt
zu `*Break` und `PAS_READY` (`BREAK_STOP`, {{BREAK_STOP}}).

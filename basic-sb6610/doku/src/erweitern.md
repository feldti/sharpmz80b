# Erweitern und Verschieben

`sb6610.asm` ist wie die Quelle von SB-6511 **verschiebbar**: Jede Adresse im BASIC-Teil steht
als Label, der Assembler passt alle Verweise an, wenn Code wächst oder schrumpft. Wie man einen
neuen Befehl einbaut (Schlüsselwort, Sprungtabelle, Routine, Hilfsroutinen für Parameter), zeigt
der Leitfaden der [SB-6511-Dokumentation](../../basic-sb6511/doku-basic/erweitern.html); er gilt für SB-6610
genauso. Diese Seite beschreibt, was bei SB-6610 anders ist.

## Kein freier Platz im Original

Bei SB-6511 bleibt hinter dem Code Platz bis 6900h. Bei SB-6610 endet der Code **genau** bei
{{RAM_START}}, wo der Arbeitsbereich beginnt; der letzte Nachtrag (`AREA_RESIZE_CLR`) füllt die
letzten Bytes. Die Quelle prüft das:

    IF $ > 6000h
    .ERROR Code reicht über 6000h (Arbeitsbereich); mit NOJUNK übersetzen oder kürzen
    ENDIF
    FILL_FREE:
    DEFS 6000h-$,00h

## Platz schaffen mit NOJUNK

Die Speicherreste bei 5A13h–5CFFh (749 Bytes, siehe [Aufbau](architektur.html#speicherreste))
werden nie ausgeführt. Die Quelle schließt sie in einen bedingten Block ein:

    IF NOT DEFINED NOJUNK
    ... Speicherreste ...
    ENDIF

Übersetzt man mit

    pasmo --equ NOJUNK=1 sb6610/sb6610.asm sb6610_neu.bin

fallen sie weg, der Floppy-Treiber und alles dahinter rücken nach vorn, und am Ende stehen 749
Bytes frei (`FILL_FREE`). Das Ergebnis ist nicht mehr bytegleich mit dem Original, verhält sich
aber gleich – `make reloc-check` und die Tests prüfen genau das.

Ein weiterer Kandidat zum Kürzen sind die sieben nie angesprungenen Bytes vor `DIV_NEXTDIG`
(`LD HL,FPR_EXP / INC (HL) / EXX / JR DIV_DIGIT`), ein Rest einer früheren Fassung der Division.

## Was die Prüfung sicherstellt

`make reloc-check` fügt an sieben Stellen (`BAS_COLD`, `KWTAB_STMT`, `FP_NORM`, `OP_SUB`,
`PR_USING`, `ST_DELLINES`, `FD_READ`) je 16 Bytes ein und vergleicht Zeile für Zeile mit dem
Original:

- Jede veränderte Zeile darf sich nur in 16-Bit-Adressen unterscheiden, die genau mitgewandert sind.
- Kein Zahlenwert im Code darf auf eine Stelle zeigen, die sich verschiebt; echte Zahlen, die wie
  Adressen aussehen, stehen begründet in `tools/reloc_allow.txt` (für SB-6610 die Konstante 10000
  in `VAL2UINT`).
- Auf den verschobenen Abbildern laufen der Tokenizertest, der BCD-Test und der Gesamtlauf
  (`tools/test_sb6610_run.py`).

Dafür wurden bei der Analyse alle festen Adressen symbolisch gemacht, zum Beispiel
`DEVTAB_PRINT+2*15`, `OPENTAB-2*10`, `USING_CHARS`, `RAM_START-1` oder die Zeichenlisten von
PRINT USING.

## Hinweise für eigenen Code

- Zahlen sind 9 Bytes groß. Zum Kopieren eines Werts `LD BC,0009h` / `LDIR`; die Rechenroutinen
  erwarten Zeiger auf das **Exponentbyte** (Byte 8) und rechnen `(DE) = (DE) op (HL)`.
- Ganzzahlige Ergebnisse sollten mit `FP_INTFORM` in Ganzzahlform gebracht werden, wie es die
  Grundrechenarten tun; `FP_CMP`, `FN_INT` und die Ausgabe gehen von dieser Form aus.
- Eine Zahl 0–65535 aus einem Ausdruck holt `EVAL_INT`; einen Wert 0–255 als Ergebnis zurückgeben
  kann `BYTE2VAL` bzw. `RET_A`.
- Der Monitorbereich 0000h–1221h ist nicht verschiebbar.
- Im Arbeitsbereich ab 6000h gibt es keinen Platz für eigene Variablen ohne Änderung der EQUs;
  einzelne Bytes legt man besser im Code-Bereich an (wie `GET_LASTKEY` oder `LIST_LOCK`).

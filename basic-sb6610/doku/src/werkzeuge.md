# Werkzeuge und Tests

Alle Werkzeuge liegen in `tools/` und laufen mit Python 3; zum Übersetzen braucht man `pasmo`,
für die Emulatortests `z88dk-ticks` aus z88dk.

## make-Ziele

| Ziel | SB-6610-Anteil |
|------|----------------|
| `make` | übersetzt `sb6610/sb6610.asm` nach `build/sb6610.bin`, erzeugt `sb6610/sb6610.lst` |
| `make check` | vergleicht `build/sb6610.bin` Byte für Byte mit dem Original-Abbild |
| `make test` | Tokenizertest mit `--basic 6610`, BCD-Test, Gesamtlauf |
| `make reloc-check` | Verschiebbarkeit (mit `NOJUNK`), Tests auf den verschobenen Abbildern |
| `make ref` | Befehlsreferenz `docs/BEFEHLE_SB6610.md` |
| `make doku6610` | diese HTML-Dokumentation |

## Tokenizer

`tools/sb6511tok.py --basic 6610` wandelt Programme zwischen MZF (Typ BTX) und Klartext und
bildet dabei `CRUNCH` und `LISTLINE` des Originals exakt nach
([Tokenizer](tokenizer.html#werkzeug)). `tools/test_sb6511tok.py --basic 6610` prüft die
Schlüsselworttabellen gegen das Abbild und vergleicht im Emulator 334 feste und zufällige
Zeilen mit dem Originalcode.

## BCD-Test

`tools/test_sb6610.py` ruft einzelne Routinen des Abbilds im Emulator auf: `STR2NUM` (Bytes des
Zahlformats), `NUM2STR` (Ausgabeformen), `OP_ADD`/`OP_SUB`/`OP_MUL`/`OP_DIV`, `FN_SQR`, `FN_INT`
und die Flags von `FP_CMP` – 38 Fälle mit festen Erwartungen.

## Gesamtlauf

`tools/test_sb6610_run.py` lässt **das ganze BASIC** im Emulator laufen. Das Abbild startet bei
`BC_RAMEND` (RAM-Ende C000h, ohne RAM-Test und Autostart); umgeleitet werden nur die Geräte:

| Original | im Test |
|----------|---------|
| `GETLINE` ({{GETLINE}}) | liest die nächste Zeile eines Skripts |
| `PRTCHR_RAW` ({{PRTCHR_RAW}}), `DISPCTRL` ({{DISPCTRL}}) | schreiben in einen Ausgabepuffer |
| `MOTOR_OFF`, `BEEP`, `TIMER_SET` | kehren sofort zurück |

Eingänge (`IN`) liefert der Emulator als FFh, beim MZ-80B heißt das „keine Taste, kein BREAK“.
Alles andere ist Originalcode. Sechs Sitzungen werden mit festen Erwartungen verglichen:

1. Rechnen, Fehlermeldung, `LIST` mit Bereich.
2. Programm mit FOR, Strings, SQR/INT/ABS/SGN, großen Zahlen, Feldern, DEF FN, GOSUB.
3. PRINT USING, DELETE, fehlende Funktionen, READ/DATA/ON GOTO, Division durch 0.
4. weitere PRINT-USING-Fälle.
5. Abschneiden bei PRINT USING.
6. alle Beispiele aus dem Handbuch, Kapitel 2.4.1.

Mit `--show` gibt das Werkzeug die Bildschirmausgabe nur aus; so lassen sich eigene Versuche
machen. Beispiel einer Sitzung:

```
10 A=1/3:PRINT A;A*3
20 PRINT 0.1+0.2,2^0
RUN
 0.333333333333333 0.999999999999999
 0.3
*Error 1 in 20
Ready
```

## Werkzeuge der Analyse

| Werkzeug | Zweck |
|----------|-------|
| `tools/port_sb6610.py`, `tools/emit_sb6610.py` | haben die erste Fassung von `sb6610.asm` aus der SB-6511-Quelle erzeugt (Bytevergleich mit Platzhaltern für Adressen, Übernahme von Namen und Kommentaren, Ablaufverfolgung im neuen Code). Die Quelle wird seitdem von Hand gepflegt. |
| `tools/z80dis.py` | Z80-Disassembler mit pasmo-Syntax (nur dokumentierte Befehle) |
| `tools/reloccheck.py` | Verschiebbarkeit prüfen (`--define NOJUNK`) |
| `tools/mkref.py --basic 6610` | Befehlsreferenz |
| `tools/mkdoku6610.py` | diese Doku aus `sb6610/doku/src/*.md`, der Quelle und der Symboldatei |
| `tools/sbdisk.py` | Disketten lesen; erkennt SB-6610-Systemdisketten und Programme mit `USING` |

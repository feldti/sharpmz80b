# Aufbau und Speicher

## Vom Laden bis „Ready.“

Die Kassettendatei hat Lade- und Startadresse 0000h; nach dem Laden über den IPL liegt das Abbild
ab 0000h, und es läuft zuerst der Kaltstart des Monitors SB-1511 (Initialisierung, Uhr über
`TIMST`). Am Ende springt der Monitor über `GOOUT` (00AEh) in seine
Kommandoschleife – im PASCAL-Abbild steht dort aber `JP PAS_BOOT`.

1. `PAS_BOOT` ({{PAS_BOOT}}) springt nach `PAS_INIT` ({{PAS_INIT}}). Dieser Code liegt hinter dem
   Interpreter im Bereich des Programmtexts und wird nur einmal gebraucht.
2. `PAS_INIT` kopiert `FKEY_DEF` (Vorgaben „begin“, „procedure“, „function“, „:=“, „integer;“ …)
   in die Funktionstastenbelegung `FARE` (1200h) und schreibt 01h nach 00AEh: Aus `JP PAS_BOOT`
   wird `LD BC,12FDh`. Danach führt `GOOUT` wieder in die Monitor-Kommandoschleife, so wie es das
   Kommando `Q/` braucht.
3. `PAS_START` ({{PAS_START}}) sucht das RAM-Ende: ab 2FFFh in Schritten von 1000h AAh und 55h
   schreiben und zurücklesen. Das Ergebnis (bei 64 KB FFFFh) wird Stapelobergrenze `STACK_TOP` und
   Operand von `RAM_END` (für `E$`). Uhr auf 0, weiter nach `PAS_COLD`.
4. `PAS_COLD` ({{PAS_COLD}}) setzt den Stapel, schickt `J,$13F8` an ein angeschlossenes
   Farbterminal (`TRAN_INIT`) und kommt nach `PAS_NEW` ({{PAS_NEW}}): Programm löschen, Puffer
   anlegen (`SET_BUFFERS`), Kopfmeldung zwischen zwei Linien aus Zeichen 90h, freien Speicher
   ausgeben.
5. `PAS_READY` ({{PAS_READY}}) setzt Ausgabe und Stapel zurück, leitet `GETL` um
   (`GETL_PATCH`, siehe [Editor](editor.html)), gibt „Ready.“ aus und läuft in `CMD_LOOP`
   ({{CMD_LOOP}}). Dorthin kehren auch Fehler, BREAK und das Programmende zurück.

## Speicherkarte

<table class="memmap">
<tr><th>Bereich</th><th>Inhalt</th></tr>
<tr><td>0000h–129Fh</td><td>Monitor SB-1511 mit seinem Arbeitsspeicher; FARE (1200h) hält die Funktionstastentexte</td></tr>
<tr><td>12A0h–12FCh</td><td>FFh-Füllung; die Funktionstastentexte dürfen bis 12FFh reichen (<code>RUN_FKEY</code>)</td></tr>
<tr><td>{{PAS_BOOT}}–{{KWTAB_0}}</td><td>Einsprung, Start, Editor, Kommandos, Kassette (Programme), Hilfsroutinen</td></tr>
<tr><td>{{KWTAB}}–{{TOKENIZE}}</td><td>Schlüsselworttabelle <code>KWTAB</code></td></tr>
<tr><td>{{TOKENIZE}}–{{CALL_SAVE}}</td><td>Tokenizer, Lister, Zeilenverwaltung</td></tr>
<tr><td>{{CALL_SAVE}}–{{RUN_SIN}}</td><td>Laufzeit: KEY/PEEK/POKE …, Zahlenumwandlung, READ/WRITE, Datendateien, MUSIC</td></tr>
<tr><td>{{RUN_SIN}}–{{PCMD_R}}</td><td>SIN/COS/TAN, Farbterminal, Funktionen, Grafik, Drucker, Hardcopy</td></tr>
<tr><td>{{PCMD_R}}–{{PCMD_G}}</td><td>Systemkommandos, Prüfung und Ausführung der Grafik- und Sonderbefehle</td></tr>
<tr><td>{{PCMD_G}}–{{ERR_01}}</td><td>Prüflauf: Deklarationen, Symboltabellen, Anweisungen, Ausdrücke; Sprungtabellen <code>SYN_TAB…</code></td></tr>
<tr><td>{{ERR_01}}–{{FSUB}}</td><td>Fehlereinsprünge, Fehlerausgabe</td></tr>
<tr><td>{{FSUB}}–{{RUN_START}}</td><td>Gleitkomma: Grundrechenarten, Umwandlung, Funktionen, Konstanten</td></tr>
<tr><td>{{RUN_START}}–{{TXT_START}}</td><td>Ausführung: Variablen, Anweisungen, Ausdrücke, Operatoren, Ganzzahl-Arithmetik; Sprungtabellen <code>RUN_TAB…</code></td></tr>
<tr><td>ab {{TXT_START}}</td><td>Programmtext (<code>TXT_START</code> … <code>TXT_END</code>); beim Laden stehen hier <code>FKEY_DEF</code> und <code>PAS_INIT</code></td></tr>
</table>

Im Code liegen außerdem Puffer und Variablen: `NUMBUF` ({{NUMBUF}}) und `LINEBUF` ({{LINEBUF}})
für Zahlen und Zeilen, `FILEBUF` ({{FILEBUF}}, 256 Bytes) für Datendateien, `MUSIC_BUF`, die
Hardcopy-Puffer und die Zeiger `RT_AREA0` … `RT_AREA3`, `RT_SP` ({{RT_SP}}).

## Arbeitsspeicher unter STACK_TOP

`SET_BUFFERS` legt von oben nach unten an:

| Name | Lage | Inhalt |
|------|------|--------|
| `STACK_TOP` | RAM-Ende (bzw. `E$`-Grenze) | Prozessorstapel wächst von hier nach unten |
| `WORKBUF` | STACK_TOP − 320h | Arbeitspuffer: tokenisierte Eingabezeile, Bezeichner im Prüflauf |
| `INBUF` | WORKBUF − 56h | Eingabezeile; zur Laufzeit Basis der globalen Variablen (sie liegen darunter) |
| `TXT_LIMIT` | INBUF − C8h | Obergrenze des Programmtexts |

Der freie Speicher („nnnnn Bytes“, Kommando `M`) ist `TXT_LIMIT − TXT_END`; bei 64 KB RAM und
leerem Programm sind das 39542 Bytes.

Zur Laufzeit liegen hinter dem Programmtext die Symboltabellen und darunter (von `INBUF` abwärts)
die globalen Variablen; der Laufzeitstapel `RT_SP` wächst nach unten auf sie zu. `RUN_BEGIN`
verlangt mindestens 100h Bytes Abstand zwischen `RT_AREA0` und `RT_SP`, sonst Err 39. Details
unter [Prüflauf](pruefung.html) und [Ausführung](ausfuehrung.html).

## Eingriffe in den Monitor

| Stelle | Änderung |
|--------|----------|
| `GOOUT` (00AEh) | im Abbild `JP PAS_BOOT`; `PAS_INIT` macht daraus `LD BC,12FDh` |
| `GETL_ENTER`, `GETL_DONE` | `GETL_PATCH` lässt `GETL` die ganze Bildschirmzeile ab Zeilenanfang (`??TOL`) liefern; `GETL_SCREEN` (READ) setzt eigene Werte |
| FARE (1200h) | Funktionstasten mit PASCAL-Wörtern vorbelegt |
| `KNUMBS` | Grenze der Eingabelänge für `GETL`: 50h im Editor, A0h bei READ |

Ansonsten benutzt der Interpreter die Monitorroutinen (`PRNT`, `MSG`, `GETL`, `GETKY`, `BRKEY`,
`RDINF`/`RDDAT`/`WRINF`/`WRDAT`, `MELDY`, `XTEMP` …) unverändert.

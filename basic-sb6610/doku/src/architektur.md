# Aufbau und Speicher

## Vom Einschalten bis „Ready“

Das IPL-ROM des MZ-80B lädt das Abbild (7E00h Bytes) von Diskette nach 8000h und löst den
„Normal Start“ aus: Das ROM wird ausgeblendet, das Abbild liegt ab 0000h. Dort beginnt der Monitor
SB-1510 (`MON_INIT`), der die I/O-Bausteine über `IOINIT_TAB` programmiert, den
40-Zeichen-Modus einstellt, seinen Arbeitsspeicher löscht, `IM 1` einschaltet und nach `BAS_COLD` springt. SB-6511 schaltet hier `IM 2`
für die RS-232C-Interrupts ein; SB-6610 braucht keine Interrupts.

### Kaltstart BAS_COLD ({{BAS_COLD}})

1. Den Sprung `JP BAS_COLD` im Monitor zu `LD BC,nn` entschärfen und das Autostart-Flag setzen.
2. Die vom IPL hinterlassene Laufwerksnummer in den Autostart-Befehl `RUN FDn"AUTO RUN"`
   (`AUTORUN_CMD`) eintragen.
3. RAM-Test ab `RAM_START` ({{RAM_START}}) bis FF00h: Das erste nicht beschreibbare Byte wird
   `MEMTOP` und Anfangswert des Stacks (`STKTOP`). Ab `BC_RAMEND` ({{BC_RAMEND}}) geht es weiter.
4. Piepton, Uhr starten (`TIMER_SET`), Einschaltmeldung mit Rahmen aus Zeichen 90h:
   `Double precision BASIC  SB-6610`, `Copyright 1981 by SHARP Corp.`
5. `CLEARALL` (leeres Programm), freien Speicher ausgeben („22123 Bytes“ bei 64 KB).
6. Über `BAS_START2` zur Eingabeschleife; mit gesetztem Autostart-Flag holt `INLINE` statt einer
   Tastaturzeile den Befehl `RUN FDn"AUTO RUN"`. Fehlt die Datei, endet das mit einer Fehlermeldung
   und „Ready“.

### Warmstart BAS_READY ({{BAS_READY}}) und Hauptschleife

`BAS_READY` setzt den Stack zurück, schaltet den Floppy-Motor ab (`MOTOR_OFF`), meldet „Ready“
und läuft in `BAS_MAIN` ({{BAS_MAIN}}): `INLINE` liest eine Zeile nach `INBUF`, `CRUNCH`
tokenisiert sie, `BAS_DIRECT` führt sie aus oder übernimmt sie mit Zeilennummer ins Programm
(`BD_EDIT`). In SB-6511 erledigte das eine eigene Routine `EDITLINE`; in SB-6610 ist ihr Code in
`BD_EDIT` eingebaut, Teile davon (`EDIT_DEL`, `EDIT_DELMEM`) benutzt auch `DELETE`.

Das Handbuch nennt 1220h als Kaltstart- und 1280h als Warmstartadresse; gemeint sind
`BAS_COLD` ({{BAS_COLD}}) und `BAS_READY` ({{BAS_READY}}).

## Speicherkarte des Abbilds

<table class="memmap">
<tr><th>Bereich</th><th>Inhalt</th></tr>
<tr><td>0000h–003Ah</td><td>RST-Vektoren, dazwischen Monitor-Variablen (z. B. 002Dh: „O“ statt „0“ bei PRINT USING)</td></tr>
<tr><td>003Bh–06A3h</td><td>Monitor SB-1510: Initialisierung, Kommandos, Kassette, Hex-Ein-/Ausgabe</td></tr>
<tr><td>06A4h–103Eh</td><td>Bildschirmeditor, Zeichenausgabe, Tastatur, Uhr, Ton, MUSIC</td></tr>
<tr><td>103Fh–1221h</td><td>Arbeitsspeicher des Monitors (Funktionstastentexte bis 1221h)</td></tr>
<tr><td>{{BAS_COLD}}–1E1Fh</td><td>BASIC-Kern: Start, Meldungen, Fehlerkette, Tokenizer, Schlüsselworttabellen, Zeilenverwaltung, Interpreterschleife</td></tr>
<tr><td>1E20h–2DECh</td><td>Anweisungen, Ausdrucksauswertung, Variablen, Felder, Strings, Funktionstabelle</td></tr>
<tr><td>{{FPA_FLAG}}–37D6h</td><td>BCD-Arithmetik: Arbeitsbereich, Konstanten, Grundrechenarten, SQR, Vergleiche, RND, INT, STR2NUM, NUM2STR</td></tr>
<tr><td>{{ST_PRINT}}–3D51h</td><td>PRINT/INPUT, Geräteverteilung (DEVTAB_PRINT mit eingebettetem INT_FINISH)</td></tr>
<tr><td>3D52h–506Ch</td><td>Dateibefehle (Kassette, Diskette), DELETE von Zeilen</td></tr>
<tr><td>506Dh–57A3h</td><td>Drucker, PRINT USING (USING_PARSE, NUM_OUT)</td></tr>
<tr><td>57A4h–5A12h</td><td>Grafik, CONSOLE, CSR/POS/CHARACTER$</td></tr>
<tr><td>5A13h–5CFFh</td><td>Speicherreste (nicht erreicht), siehe unten</td></tr>
<tr><td>{{FD_READ}}–5FEFh</td><td>Floppy-Treiber (MB8876)</td></tr>
<tr><td>5FF0h–5FFFh</td><td>Nachtrag <code>AREA_RESIZE_CLR</code></td></tr>
<tr><td>6000h–6FFFh</td><td>im Abbild Speicherreste (RAM-Muster, Bruchstücke von Sharps Assembler-Quelltext), zur Laufzeit Arbeitsbereich</td></tr>
<tr><td>7000h–7DFFh</td><td>BFh-Füllung</td></tr>
</table>

Die Bereichsgrenzen folgen den Abschnittsbannern der Quelle; das [Routinenverzeichnis](routinen.html)
listet jede Routine mit Adresse.

### Speicherreste

Zwei Bereiche des Abbilds enthalten keinen erreichbaren Code:

- **5A13h–5B19h** ist eine Kopie von `ST_GRAPH` … `FN_CHARACTER` (heute 5906h–5A12h) aus einem
  älteren Stand, in dem dieser Code 10Dh weiter hinten lag. Die Adressen darin gelten für jenen
  Stand (z. B. `CALL 1987h` = damals `CHK_CHR_ALT`, heute 190Dh). Danach folgen ein RAM-Muster
  (16 Bytes 00h/FFh im Wechsel) und eine Kopie des Monitor-Arbeitsspeichers ab 1050h.
- **6000h–6FFFh** liegt schon im Arbeitsbereich und enthält neben dem RAM-Muster Bruchstücke von
  Assembler-Quelltext aus der Entwicklung bei Sharp (`ERN1:PUSH HL`, `LD DE,(ERD3)`, `CALL TESTX`
  …) – offenbar Reste aus dem Speicher des Entwicklungssystems.

Die Quelle schließt den ersten Bereich in `IF NOT DEFINED NOJUNK` ein; ohne ihn steht der Platz
am Ende des Codes frei ([Erweitern](erweitern.html)).

## Arbeitsbereich zur Laufzeit

Der Arbeitsbereich beginnt bei `RAM_START` ({{RAM_START}}) statt bei 6B00h. Weil der
RS-232C-Ringpuffer fehlt und die Zahlen größer sind, haben sich alle Adressen verschoben, nicht
alle um denselben Betrag.

<table class="memmap">
<tr><th>Adresse</th><th>Name</th><th>Inhalt</th></tr>
<tr><td>{{MEMTOP}}</td><td>MEMTOP, STKTOP</td><td>RAM-Ende, Anfangswert des Stacks</td></tr>
<tr><td>{{INBUF}}</td><td>INBUF</td><td>Eingabe- und Zeilenpuffer</td></tr>
<tr><td>{{TOKLINE}}</td><td>TOKLINE</td><td>CRUNCH-Ergebnis als Programmzeile (Link, Nummer, Text)</td></tr>
<tr><td>{{TAPEBUF}}</td><td>TAPEBUF</td><td>Puffer der Kassettendatei (256 Bytes)</td></tr>
<tr><td>{{USING_PTR}}</td><td>USING_PTR</td><td>PRINT USING: Zeiger, 0 = ohne USING (neu)</td></tr>
<tr><td>{{USING_FMT}}</td><td>USING_FMT</td><td>PRINT USING: aufbereitete Ausgabe (neu)</td></tr>
<tr><td>{{FC_IDX}}</td><td>FC_IDX …</td><td>aktuelle Datei (Kopie des Tabelleneintrags)</td></tr>
<tr><td>{{FILETAB}}</td><td>FILETAB</td><td>Dateitabelle, 10 Einträge zu 9 Bytes</td></tr>
<tr><td>{{PRGEND}}</td><td>PRGEND, P_*</td><td>Bereichszeiger: Programmende, Dateipuffer, DEF FN, Felder, Variablen, Strings</td></tr>
<tr><td>{{VALSP}}</td><td>VALSP</td><td>Zeiger auf den Wertestack (9-Byte-Einträge)</td></tr>
<tr><td>{{FNPAR_SP}}</td><td>FNPAR_SP, FOR_SP, GOSUB_SP</td><td>Zeiger der drei Stacks (FN ab 66BAh, FOR ab 684Fh, GOSUB ab 68B8h abwärts)</td></tr>
<tr><td>{{FOR_VAR}}</td><td>FOR_VAR …</td><td>FOR-Eintrag im Aufbau: Variable, Schrittweite (9), Vorzeichen, Endwert (9)</td></tr>
<tr><td>{{CURLINE}}</td><td>CURLINE, TXTPTR …</td><td>aktuelle Zeile, Textzeiger, Zähler, ON ERROR, READ</td></tr>
<tr><td>{{PRGTXT}}</td><td>PRGTXT</td><td>Beginn des BASIC-Programms, danach Variablen und Felder</td></tr>
</table>

Die dynamischen Bereiche (Programm, DEF FN, Felder, Variablen, Strings, Wertestack) liegen wie bei
SB-6511 hintereinander und werden beim Einfügen verschoben; siehe
[SB-6511: Die dynamischen Bereiche](../../basic-sb6511/doku-basic/architektur.html#die-dynamischen-bereiche).
Neu ist nur der Nachtrag `AREA_RESIZE_CLR`, der nach dem Umbau eines Dateipuffers die zwei Wörter
hinter dem Zeiger 6680h auf 0 setzt.

## Monitor-Routinen, die das BASIC benutzt

| Routine | Adresse | Aufgabe |
|---------|--------:|---------|
| `GETLINE` | {{GETLINE}} | Zeile mit dem Bildschirmeditor einlesen |
| `PRTCHR_RAW` | {{PRTCHR_RAW}} | Zeichen ausgeben, Spalte zählen |
| `DISPCTRL` | {{DISPCTRL}} | Steuerzeichen ausführen (CR, Cursor, Löschen …) |
| `TIMER_SET`, `TIMER_GET` | {{TIMER_SET}}, {{TIMER_GET}} | Uhr über den 8253 (TI$, RND mit negativem Argument) |

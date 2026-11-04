# Ein-/Ausgabe, Grafik, Drucker

Bildschirm und Tastatur laufen über den Monitor SB-1511 (`PRNT`, `MSG`, `GETL`, `GETKY`,
`BRKEY`). `PR_CHAR` ({{PR_CHAR}}) gibt ein Zeichen aus: ist `OUT_PRT` gesetzt (Kommando `H`,
`PWRITE`), geht es an den Drucker (`PRT_OUT`), sonst an `PRNT`.

## READ und WRITE

**READ** von der Tastatur (`READ_KBD`, {{READ_KBD}}) gibt „?“ aus und liest die Zeile mit
`GETL_SCREEN` vom Bildschirm. Die Werte werden durch Kommas getrennt nacheinander den Variablen
zugewiesen; `READ_NUMBER` erkennt Vorzeichen, Dezimalpunkt und Exponent. Passt die Eingabe nicht
(z. B. Text für eine Zahl), fragt READ mit „?“ erneut; eine zu große Ganzzahl ergibt dagegen
Err 13. `READLN` liest danach bis zum Zeilenende.

**WRITE** (`WRITE_ITEMS`, {{WRITE_ITEMS}}) gibt Texte und Ausdrücke aus, auf Wunsch mit
`:Breite` (bis 20) und `:Nachkommastellen` (bis 9). Ohne Format sind Zahlen und Zeichen
15 Stellen breit, rechtsbündig. Passt eine Zahl nicht in die Breite, folgt Err 36; Texte
haben keine Breitenangabe (Err 08). `BOOLEAN`
kann nicht ausgegeben werden (Err 04). Die Ausgabe von Texten geht über den Operanden von
`SM_WROUT`: `MSG` für den Bildschirm, `PRT_TEXT` für den Drucker oder die Dateiroutinen.

| Anweisung | Ziel |
|-----------|------|
| `WRITE(`, `WRITELN(` | Bildschirm oder Datei (erstes Argument FILE-Variable) |
| `PWRITE(`, `PWRITELN(` | Drucker |
| `READ(`, `READLN(` | Tastatur oder Datei |

## Datendateien auf Kassette

Eine Datei wird mit `FNAME(Name)` benannt und geöffnet (`RUN_FNAME`; ohne Text fragt
`ASK_FILENAME` mit „Filename?“), mit `READ`/`WRITE` und einer FILE-Variablen als erstem
Argument gelesen oder geschrieben und mit `CLOSE` abgeschlossen. Die Daten gehen in Blöcken zu
100h Bytes über `FILEBUF` ({{FILEBUF}}) als Kassettendatei vom **Typ 03h**:

| Routine | Aufgabe |
|---------|---------|
| `FILE_FIND` | Datei vom Typ 03h mit dem Namen aus `FNAME` suchen, „Found“/„Loading“ |
| `CMT_SETBLK` | Kassettenkopf auf einen Block von 100h Bytes ab `FILEBUF` einstellen |
| `CMT_READBLK`, `CMT_WRITEBLK` | Block lesen bzw. schreiben (`RDDAT`/`WRDAT` über `SM_CMT_IO`) |
| `FILE_ITEM` | einen Wert im Puffer lesen oder ablegen |
| `RUN_CLOSE` | letzten Block schreiben; läuft auch am Programmende |

Bei einem Lese- oder Schreibfehler während des Programms erscheint „Err 34* Run*“ bzw.
„Err 35* Run*“ und `** Push key [ C)ontinue E)ditor ]`: `C` wiederholt, `E` kehrt zum Editor
zurück. Programme (Typ A0h) speichern und laden die Editorkommandos `S`, `A`, `V`.

## Grafik

Die Grafik braucht die Grafik-RAM-Karte des MZ-80B. Das Grafik-RAM wird ab E000h eingeblendet
(Port E8h), gesteuert über Port F4h.

| Anweisung | Routine | Umsetzung |
|-----------|---------|-----------|
| `GRAPH(` | `RUN_GRAPH` | Ein-/Ausgabeebene wählen, löschen (`GR_CLEAR`), füllen |
| `GSET(x,y)`, `GRSET(x,y)` | `GR_SET`, `GR_RESET` | Punkt setzen/löschen über `GR_PLOT` |
| `LINE(`, `BLINE(` | `GR_LINE` | Linienzug, Punktroutine über `SM_GR_PLOTFN` |
| `POSITION(x,y)` | `RUN_POSITION` | Positionszeiger setzen (`POSH`, `POSV` lesen ihn) |
| `PATTERN(n, Text)` | `GR_PATTERN` | Punktmuster byteweise schreiben |
| `POINT(x,y)` | `GR_POINT` | Punkt abfragen |

`GR_PLOT` ({{GR_PLOT}}) berechnet mit `GR_BYTEADDR` die Byteadresse und führt einen Bitbefehl
aus, den es in `SM_GR_BITOP` einträgt (`SET`, `RES` oder `BIT`). Koordinaten nimmt `RT_POPY`
vom Stapel; erlaubt sind −16384 bis 16383, sonst Err 13.

## Bildschirm

`RANGE(` stellt Rollbereich (`S`), 40/80 Zeichen (`C`) und inverse/normale Darstellung
(`R`/`N`) ein, wie das Editorkommando `R`. `CURSOR(x,y)` setzt den Cursor, `CSRH`/`CSRV`
lesen ihn, `COUT(c)` schreibt ein Zeichen an die Cursorposition, `CIN` liest es.

## Drucker

Der Drucker hängt an den Ports FEh (Strobe/Status) und FFh (Daten). `PRT_OUT` ({{PRT_OUT}})
wartet auf Bereitschaft (`PRT_WAIT`, sonst Err 42), legt das Zeichen an und gibt den Strobe.
`PRT_STATUS` meldet Papierende (Err 43) und Störungen (Err 44). Steuerfolgen beginnen mit ESC
(`PRT_ESC`). `IMAGE(` druckt Punktmuster, `COPY(n)` eine Hardcopy der Text- oder Grafikanzeige
(`PRT_COPY`, Puffer `HC_BUF`, `HC_LINE`).

## Farbterminal

`TRAN(`, `REQTR`, `SYRET` und `SYRET2` steuern laut Handbuch das **Farbsteuersystem**
(Farbterminal mit Kassette der Reihe SB-3000). Die Bytes gehen mit Handshake über die Ports EEh
(Daten) und EFh (Status/Steuerung): `TRAN_BYTE` sendet, `REQTR` liest ein Byte. `SYRET`/`SYRET2`
setzen das Terminal zurück und schicken ihm Monitorkommandos wie `J,$13A8` (`SYRET_CMD1` …).
Auch der Kaltstart sendet `J,$13F8` (`TRAN_INIT`).

## Musik, Tasten, Speicher und Ports

| Anweisung/Funktion | Umsetzung |
|--------------------|-----------|
| `MUSIC(Text)` | `MUSIC_TEXT` zerlegt den Text, `MUSIC_PLAY` spielt über `MELDY` |
| `TEMPO(n)` | n = 1–7 über `XTEMP` |
| `FKEY(n, Text)` | `RUN_FKEY`: Text der Funktionstaste n (1–20) in FARE ersetzen; alle Texte zusammen dürfen bis 12FFh reichen (Err 39) |
| `KEY` | Taste lesen; eine gehaltene Taste nur einmal (`SM_LASTKEY`) |
| `PEEK(a)`, `POKE(c,a)` | Speicher lesen/schreiben (`CHAR`) |
| `INPUT(p)`, `OUTPUT(c,p)` | Port lesen/schreiben |
| `CALL(a) v1, v2` | Maschinenprogramm bei a aufrufen, v1 in HL, v2 in DE (`SM_USRCALL`) |

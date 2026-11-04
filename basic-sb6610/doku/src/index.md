# Double Precision BASIC SB-6610 – Technische Dokumentation

Diese Dokumentation beschreibt den BASIC-Interpreter **SB-6610** („Double precision DISK BASIC“)
von Sharp (1981) für den **Sharp MZ-80B**, so wie er im kommentierten Disassembly
`sb6610/sb6610.asm` vorliegt.

SB-6610 ist ein Abkömmling des Disk BASIC SB-6511: Tokenizer, Interpreterschleife,
Dateisystem, Grafik und Floppy-Treiber sind dieselben, nur verschoben. Neu geschrieben ist die
**Zahlendarstellung**: Statt 5-Byte-Gleitkomma mit 32-Bit-Mantisse rechnet SB-6610 mit
**9-Byte-BCD-Zahlen mit 16 Dezimalstellen**. Dazu kommen `PRINT USING` und `DELETE` für
Programmzeilen; weggefallen sind GP-IB, RS-232C und die Funktionen `^`, `SIN`, `COS`, `TAN`,
`ATN`, `EXP`, `LOG` und `LN`.

Die Doku setzt die [Dokumentation von SB-6511](../../basic-sb6511/doku-basic/index.html) nicht voraus,
verweist aber für unveränderte Teile dorthin. Was in SB-6610 anders ist, steht gesammelt unter
[Unterschiede zu SB-6511](unterschiede.html).

<div class="cards">
<p><a href="unterschiede.html"><strong>Unterschiede zu SB-6511</strong>Was neu, was weggefallen, was verschoben ist.</a>
<a href="architektur.html"><strong>Aufbau und Speicher</strong>Start, Speicherkarte von Abbild und Arbeitsbereich, Speicherreste.</a>
<a href="tokenizer.html"><strong>Tokenizer und Programmtext</strong>Token-Format, USING, CRUNCH/LISTLINE, Zeilenformat.</a>
<a href="interpreter.html"><strong>Interpreterschleife</strong>NEXTSTMT, DISPATCH, Stacks mit 9-Byte-Zahlen, LIST_LOCK.</a>
<a href="zahlen.html"><strong>BCD-Zahlen und Arithmetik</strong>Zahlformat, Grundrechenarten, SQR, INT, RND, Wandlung.</a>
<a href="printusing.html"><strong>PRINT USING</strong>Schablonen, Beispiele aus dem Handbuch, Umsetzung.</a>
<a href="befehle.html"><strong>Befehlsreferenz</strong>Alle Schlüsselwörter mit Token, Routine und Adresse.</a>
<a href="ein-ausgabe.html"><strong>Ein-/Ausgabe, Dateien, Drucker</strong>Geräteverteilung, Dateien, Druckerbreite.</a>
<a href="fehler.html"><strong>Fehler</strong>Fehlernummern mit Handbuchtexten, ON ERROR.</a>
<a href="erweitern.html"><strong>Erweitern und Verschieben</strong>NOJUNK, freier Platz, Verschiebbarkeit.</a>
<a href="werkzeuge.html"><strong>Werkzeuge und Tests</strong>Tokenizer, Emulatortests, Gesamtlauf.</a>
<a href="routinen.html"><strong>Routinenverzeichnis</strong>Alle kommentierten Routinen mit Adresse.</a></p>
</div>

## Das System in Zahlen

| Merkmal | Wert |
|---------|------|
| Hersteller, Jahr | Sharp Corp., 1981 (`Copyright 1981 by SHARP Corp.`) |
| Rechner | Sharp MZ-80B, Z80 mit 4 MHz, 64 KB RAM |
| Abbild | `Disk Basic6610ipl.mzf`, 7E00h Bytes (32 256), geladen ab 0000h |
| Monitor im Abbild | SB-1510 (0000h–1221h), bis auf `IM 1` gleich dem von SB-6511 |
| BASIC-Teil | {{BAS_COLD}}–5FFFh; der Code endet genau vor dem Arbeitsbereich ab {{RAM_START}} |
| Programmbeginn | {{PRGTXT}} (`PRGTXT`), bei SB-6511 725Ch |
| Einschaltmeldung | `Double precision BASIC  SB-6610`, danach 22123 Bytes frei (64 KB RAM) |
| Anweisungen | 70 belegte von 81 Plätzen (Token `80h,80h`–`80h,D0h`) |
| Operatoren/Funktionen | 9 Vergleichsoperatoren, `USING`, `TO`/`STEP`, 20 Funktionen A0h–B3h, 12 Plätze C0h–CBh (davon 5 benutzbar: `RND(` `INT(` `ABS(` `SGN(` `SQR(`) |
| Zahlen | 9 Bytes BCD: 16 Ziffern Mantisse + Exponentbyte; ganze Zahlen bis 16 Stellen exakt; Bereich 1E-48 bis 9.999999999999999E+78 (Handbuch) |
| Strings | bis 255 Zeichen |
| Variablennamen | 2 signifikante Zeichen |
| Felder | ein- oder zweidimensional; eindimensional nur durch den Speicher begrenzt, zweidimensional je Index 0–255 |
| Verschachtelung | 15 FOR, 15 GOSUB, FN-Ebenen wie SB-6511 |
| Fehlernummern | 1–70 |
| Disketten | 16 Sektoren × 256 Bytes je Spur, Controller MB8876, bis 4 Laufwerke |

## Fassungen

Das untersuchte Abbild liegt in `sb6610/` und ist identisch mit dem BASIC auf den
Systemdisketten `disketten-2/DISK8.DSK` und `DISK16.DSK`. Auf `disketten/DISK26.DSK` steht eine
**ältere Fassung**, die sich in 76 Bytes unterscheidet. Ihr fehlen drei nachträgliche
Korrekturen:

| Korrektur | Wirkung | ältere Fassung |
|-----------|---------|----------------|
| `INT_FINISH` ({{INT_FINISH}}) | `INT` einer Zahl zwischen −1 und 0 ergibt echte 0 statt „−0“ | `FN_INT` springt direkt nach `FP_INTFORM` |
| `POINT_GET` ({{POINT_GET}}) | `POINT(x,y)` rettet das Registerpaar BC | `FN_POINT` ruft `GR_POINT` direkt |
| `AREA_RESIZE_CLR` ({{AREA_RESIZE_CLR}}) | nach dem Umbau eines Bereichs zwei Zeigerwörter auf 0 | `AREA_RESIZE` direkt |

Außerdem programmiert `MON_INIT` die I/O-Bausteine in der älteren Fassung mit einzelnen
`OUT`-Befehlen statt über die Tabelle `IOINIT_TAB`. Die Korrekturen sind in freie Stellen gelegt
worden: `INT_FINISH` in unbenutzte Einträge der Gerätetabelle `DEVTAB_PRINT`, die beiden anderen
an das Ende des Codes.

## Wie diese Doku entstanden ist

Grundlage ist das Disassembly `sb6610.asm`. Es wurde zunächst mit `tools/port_sb6610.py` aus der
kommentierten SB-6511-Quelle abgeleitet: Zeilen, deren Bytes bis auf Adressen gleich sind,
übernahmen Namen und Kommentare. Neuer Code wurde danach von Hand analysiert und benannt; das
Verhalten der BCD-Arithmetik und von PRINT USING wurde im Z80-Emulator mit dem Originalcode
geprüft (siehe [Werkzeuge und Tests](werkzeuge.html)). Das Handbuch
(`sb6610/Double_Precision_DISK_BASIC_MANUAL_nobmp_SB-6610.pdf`) bestätigt die Befunde.

Adressen werden hexadezimal mit nachgestelltem `h` angegeben und beziehen sich auf das
Original-Abbild. Die Seiten werden mit `tools/mkdoku6610.py` erzeugt, die Adressen kommen dabei
aus der Symboldatei des Assemblers.

> Offene Punkte sind als solche gekennzeichnet, vor allem `LIST_LOCK`
> ([Interpreter](interpreter.html#list-lock-ein-unbekannter-listschutz)).

## Begriffe

| Begriff | Bedeutung |
|---------|-----------|
| BCD | Binary Coded Decimal: zwei Dezimalziffern je Byte, Rechnen mit `DAA` |
| Mantisse, Exponentbyte | die 16 Ziffern einer Zahl bzw. Byte 8 mit Vorzeichen und Zehnerexponent |
| Ganzzahlform | Darstellung mit Exponentbyte 40h, Mantisse rechtsbündig (1 = `00…01 40`) |
| Token | Kürzel für ein Schlüsselwort im Programmtext (`80h,88h` = `PRINT`) |
| Inline-Parameter | Daten direkt hinter einem `CALL`, die die gerufene Routine liest |
| Wertestack | Stapel der Zwischenergebnisse beim Auswerten von Ausdrücken (`VALSP`) |
| BTX / OBJ / BSD / BRD | Dateitypen: BASIC-Programm, Maschinenprogramm, sequentielle Datei, Satzdatei |

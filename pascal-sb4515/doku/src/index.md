# PASCAL-Interpreter SB-4515 – Technische Dokumentation

Diese Dokumentation beschreibt den **PASCAL-Interpreter SB-4515** von Sharp (1981) für den
**Sharp MZ-80B**, so wie er im kommentierten Disassembly `sb4515/SB4515.asm` vorliegt.

SB-4515 ist kein Compiler, sondern ein Interpreter für eine Teilmenge von PASCAL mit eingebautem
Zeileneditor. Das Programm wird beim Eintippen in Token umgesetzt. Beim Start mit `G` läuft erst
ein **Prüflauf** über den ganzen Text: Er prüft Deklarationen, Syntax und Typen und trägt die
Adressen der Variablen und die Sprungziele direkt in den Tokentext ein. Danach führt die
**Ausführung** den so vorbereiteten Text aus. Dazu kommen Gleitkomma-Arithmetik, Grafik,
Drucker, Kassettendateien, Musik und die Ansteuerung des Farbterminals.

<div class="cards">
<p><a href="architektur.html"><strong>Aufbau und Speicher</strong>Start über den Monitor, Speicherkarte, Arbeitsbereiche.</a>
<a href="editor.html"><strong>Editor und Programmtext</strong>Kommandos, Zeilen ohne Nummern, Token, Listing.</a>
<a href="pruefung.html"><strong>Prüflauf und Symboltabellen</strong>Deklarationen, Typen, eingetragene Adressen.</a>
<a href="ausfuehrung.html"><strong>Ausführung</strong>Laufzeitstapel, Ausdrücke, Anweisungen, Unterprogramme.</a>
<a href="zahlen.html"><strong>Zahlen und Arithmetik</strong>INTEGER, 5-Byte-Gleitkomma, Funktionen, Genauigkeit.</a>
<a href="befehle.html"><strong>Befehlsreferenz</strong>Alle Schlüsselwörter mit Token und Routinen.</a>
<a href="ein-ausgabe.html"><strong>Ein-/Ausgabe, Grafik, Drucker</strong>READ/WRITE, Kassette, Grafik, Farbterminal.</a>
<a href="fehler.html"><strong>Fehler</strong>Alle Fehlernummern, Ausgabe, Kassettenfehler.</a>
<a href="erweitern.html"><strong>Ändern und Verschieben</strong>Generator, Verschiebbarkeit, MZF-Datei.</a>
<a href="werkzeuge.html"><strong>Werkzeuge und Tests</strong>Make-Ziele, Emulatorlauf, Prüfungen.</a>
<a href="routinen.html"><strong>Routinenverzeichnis</strong>Alle kommentierten Routinen mit Adresse.</a></p>
</div>

## Das System in Zahlen

| Merkmal | Wert |
|---------|------|
| Hersteller, Jahr | Sharp Corp., 1981 (`Copyright (C) 1981 by SHARP Corp.`) |
| Rechner | Sharp MZ-80B, Z80 mit 4 MHz, 64 KB RAM |
| Abbild | `PASCAL.OBJ` (DISK18), 61EDh Bytes (25 069), geladen ab 0000h; als Kassettendatei `sb4515/SB4515.mzf` |
| Monitor im Abbild | SB-1511 (0000h–129Fh), bis auf den Sprung in `GOOUT` und Speicherreste gleich `SB1511.bin` |
| Interpreter | {{PAS_BOOT}}–{{FKEY_DEF}}; der Programmtext beginnt bei {{TXT_START}} |
| Einschaltmeldung | `PASCAL interpreter SB-4515`, danach 39542 Bytes frei (64 KB RAM, im Emulator ermittelt) |
| Schlüsselwörter | Token 60h–E1h in `KWTAB`; 5 davon nicht erreichbar (`PROGRAM`, `TYPE`, `SET`, `PACKED`, `IN`) |
| Datentypen | `INTEGER` (16 Bit), `REAL` (5 Bytes), `CHAR`, `BOOLEAN`, `ARRAY [..] OF`, `FILE OF` |
| REAL | 32-Bit-Mantisse, Bereich bis ±0.92233720E+19, Ausgabe mit 8 Stellen |
| Unterprogramme | `PROCEDURE`, `FUNCTION`, Wert-Parameter, rekursiv aufrufbar |
| Bezeichner | bis 32 Zeichen (sonst Err 06) |
| Fehlernummern | 01–55 (BCD), Texte zu 01–47 im Handbuch |

## Was es nicht gibt

`PROGRAM`, `TYPE`, `SET`, `PACKED` und der Operator `IN` stehen in der Schlüsselworttabelle mit
einem `*` am Anfang und sind damit nicht eingebbar. Es gibt keine Zeiger, keine Records, keine
Strings als Typ (Texte nur in `WRITE`, `TRAN`, `MUSIC` …), keine Direktausführung von
Anweisungen im Kommandomodus und kein `GOTO`. Der Operator `/` verlangt zwei `REAL`-Operanden;
`WRITE` kann keine `BOOLEAN`-Werte ausgeben.

## Fassung und Quellen

Das Abbild stammt von der FDOS-Diskette `disketten-2/DISK18` (Datei `PASCAL`, Typ OBJ) und ist
die **Kassettenfassung**: vorn steht der Monitor SB-1511, wie bei BASIC SB-5510. Das Handbuch liegt
als `sb4515/Sharp_MZ-80B_PASCAL_Language_Manual_SB4515.pdf` bei.

| Datei | Inhalt |
|-------|--------|
| `sb4515/SB4515.asm`, `.lst` | Quelle und Listing, bytegleich zu `PASCAL.OBJ` |
| `sb4515/sb4515_cfg.py` | Namen, Beschreibungen und Analyse-Angaben, aus denen die Quelle erzeugt wird |
| `sb4515/SB4515.mzf` | Kassettendatei („PASCAL SB-4515“, Laden und Start bei 0000h) |
| `docs/BEFEHLE_SB4515.md` | Befehlsreferenz (auch als [Seite](befehle.html)) |
| `tools/test_sb4515_run.py` | Programmlauf im Emulator als Test |

## Benennung

Alle Namen stammen aus der Analyse; die Datei enthält keine Symbole. Die Monitornamen sind die von
Sharp (aus `MONEQU`). Im Interpreter gilt:

| Präfix | Bedeutung |
|--------|-----------|
| `PCMD_x` | Editorkommando `x` |
| `SYN_…` | Prüflauf (Syntax, Typen) zu einem Schlüsselwort |
| `RUN_…` | Ausführung zu einem Schlüsselwort |
| `ERR_nn` | Fehler nn |
| `F…` | Gleitkommaroutine (`FADD`, `FSIN` …) |
| `SM_…` | Befehl mit Operand, der zur Laufzeit geändert wird (Operand = Name+1) |
| `GR_…`, `PRT_…`, `CMT_…`, `TRAN_…` | Grafik, Drucker, Kassette, Farbterminal |
| `Lnnnn`, `Dnnnn` | automatisch vergebene Namen für Sprungziele innerhalb von Routinen und für Konstanten |

# BCD-Zahlen und Arithmetik

Der größte Unterschied zu SB-6511: Statt binärer Gleitkommazahlen mit 32-Bit-Mantisse (etwa neun
Stellen) rechnet SB-6610 dezimal mit **16 Stellen**. Der ganze Bereich {{FPA_FLAG}}–37D6h ist neu
geschrieben. Die Routinen benutzen die BCD-Befehle des Z80 (`DAA`, `RLD`, `RRD`); 26 `DAA` stehen
in diesem Teil, bei SB-6511 eines.

## Zahlformat

Eine Zahl belegt **9 Bytes**:

| Byte | Inhalt |
|------|--------|
| 0–7 | Mantisse M: 16 BCD-Ziffern, die höchstwertigen zuerst |
| 8 | Exponentbyte: Bit 7 = Vorzeichen (1 = negativ), Bits 6–0 = E |

Der Wert ist **M × 10^(E−40h)**, wobei M als 16-stellige ganze Zahl gelesen wird. Gleichwertig: M
als Dezimalbruch 0,M und Wert = 0,M × 10^(E−30h).

Es gibt zwei Formen derselben Zahl:

- **Ganzzahlform:** E = 40h, die Mantisse ist rechtsbündig. Ganze Zahlen bis 16 Stellen stehen so
  und sind exakt. 1 = `00 00 00 00 00 00 00 01 40`.
- **Normierte Form:** die erste Ziffer ist nicht 0. 0,5 = `50 00 00 00 00 00 00 00 30`.

Null sind neun Null-Bytes. Nach jeder Rechnung bringt `FP_INTFORM` ({{FP_INTFORM}}) ein
ganzzahliges Ergebnis zurück in die Ganzzahlform; vor dem Rechnen normiert `FP_NORM`
({{FP_NORM}}) bei Bedarf.

Beispiele, mit `STR2NUM` im Emulator erzeugt:

| Eingabe | Mantisse | E |
|---------|----------|---|
| `1` | `0000000000000001` | 40 |
| `10` | `0000000000000010` | 40 |
| `0.5` | `5000000000000000` | 30 |
| `12.75` | `1275000000000000` | 32 |
| `3.14159265358979323` | `3141592653589793` | 31 |
| `123456789012345678` | `1234567890123457` | 42 |
| `1E-10` | `1000000000000000` | 27 |
| `2.5E63` | `2500000000000000` | 70 |

Bereich laut Handbuch: 1E-48 bis 9.999999999999999E+78. Im Emulator: `1E-49` wird zu 0, `1E79`
gibt Fehler 2. Der größte Betrag steht als Konstante `FP_MAX` (`99…99 7F`) im Abbild.

### Konstanten und Arbeitsbereich

| Name | Adresse | Inhalt |
|------|--------:|--------|
| `NUMBUF`, `FP_TMP1` | {{FP_TMP1}} | normierte Kopie eines Operanden; Ausgabetext von NUM2STR |
| `FP_TMP2` | {{FP_TMP2}} | normierte Kopie des anderen Operanden |
| `FP_DIG` | {{FP_DIG}} | Ziffernpuffer: Produkt (gepackt), Quotient/Wurzel (eine Ziffer je Byte) |
| `FPR_EXP`, `FPR_PTR` | {{FPR_EXP}} | Exponent und Zeiger des Ergebnisses bei MUL/DIV/SQR |
| `FP_ONE` | {{FP_ONE}} | 1 |
| `FP_ZERO`, `FP_MONE` | {{FP_ZERO}}, {{FP_MONE}} | 0 und −1 (überlappen sich) |
| `FP_PI` | {{FP_PI}} | 3.141592653589793 |
| `FP_MAX` | {{FP_MAX}} | größter Betrag |
| `FP_ONE_N` | {{FP_ONE_N}} | 1 in normierter Form (für INT) |
| `SQR_SQUARES` | {{SQR_SQUARES}} | Quadrate 0–9 in BCD |
| `RND_X`, `RND_MUL`, `RND_INIT` | {{RND_X}} | Zufallszahl, Faktor 23, Startwert |

## Grundbausteine

| Routine | Adresse | Aufgabe |
|---------|--------:|---------|
| `FP_NORM` | {{FP_NORM}} | führende Null-Bytes und eine führende Null-Ziffer herausschieben, Exponent anpassen; Unterlauf → 0 |
| `FP_NORMCOPY` | {{FP_NORMCOPY}} | beide Operanden normiert nach `FP_TMP1`/`FP_TMP2` kopieren |
| `FP_SHR1` | {{FP_SHR1}} | Mantisse eine Ziffer nach rechts, E + 1, CY = Rundung |
| `FP_SHRN` | {{FP_SHRN}} | Mantisse A Ziffern nach rechts (ganze Bytes über `FSRN_BYTES`) |
| `FP_INTFORM` | {{FP_INTFORM}} | ganzzahligen Wert auf E = 40h bringen |
| `MANT_ADD`, `MANT_SUB` | {{MANT_ADD}}, {{MANT_SUB}} | 8 Bytes BCD addieren bzw. subtrahieren |
| `MANT_CARRY` | {{MANT_CARRY}} | Übertrag aus der höchsten Stelle: eine Ziffer nach rechts, 1 einsetzen |
| `FP_ISZERO` | {{FP_ISZERO}} | Test auf 0 |
| `FP_SETZERO` | {{FP_SETZERO}} | Zahl löschen |
| `FP_OVERFLOW` | {{FP_OVERFLOW}} | `FP_MAX` mit Vorzeichen eintragen, Fehler 2 |

Fast alle Routinen bekommen Zeiger auf das **Exponentbyte** (Byte 8); die Mantisse liegt in den
acht Bytes darunter. Die Grundrechenarten rechnen `(DE) = (DE) op (HL)`.

## Addition und Subtraktion

`OP_ADD` ({{OP_ADD}}) und `OP_SUB` ({{OP_SUB}}) entscheiden nach den Vorzeichen, ob die Beträge
addiert (`ADD_MAG`) oder subtrahiert (`SUB_MAG`) werden:

1. Sind beide Operanden in Ganzzahlform, wird direkt addiert – ohne Angleichen und ohne Rundung.
2. Sonst wird der Operand mit dem kleineren Exponenten um die Differenz nach rechts geschoben
   (`ADD_ALIGN`, `FP_SHRN`) und dabei gerundet. Ab 16 Stellen Unterschied bestimmt der größere
   Operand allein das Ergebnis.
3. `MANT_ADD` bzw. `MANT_SUB`; ein negatives Ergebnis der Subtraktion wird ins Zehnerkomplement
   umgerechnet und das Vorzeichen gedreht.
4. Normieren und `FP_INTFORM`.

Beim Tausch der Operanden setzt `ADD_MAG`/`SUB_MAG` den Befehl `ASW_SIGN` in `ADD_SWAP` auf `NOP`
oder `CPL`, damit das Vorzeichen stimmt.

## Multiplikation und Division

`OP_MUL` ({{OP_MUL}}) und `OP_DIV` ({{OP_DIV}}) teilen sich `MULDIV` ({{MULDIV}}): Null-Operanden
abfangen (Division durch 0: Fehler 2), beide Operanden normiert kopieren, Exponent und Vorzeichen
des Ergebnisses nach `FPR_EXP` (Bereich prüfen).

- **Multiplikation** (`MUL_START`): Jedes Byte des linken mal jedes Byte des rechten Operanden.
  Ein Teilprodukt entsteht durch wiederholtes Addieren mit `DAA` (untere Ziffer, dann obere Ziffer
  nach `ADD HL,HL` × 4) und wird an der richtigen Stelle in das 32-stellige Produkt in `FP_DIG`
  aufaddiert. Die oberen 16 Ziffern werden das Ergebnis, das nächste Byte entscheidet die Rundung.
- **Division**: wie schriftlich – für jede der 17 Ziffern den Divisor abziehen, bis der Rest
  negativ wird, einmal zurückaddieren, die Ziffer nach `FP_DIG`, nächste Stelle des Dividenden
  einschieben. `MD_PACK` packt die Ziffern zur Mantisse, `MD_FINISH` rundet.

Weil der Quotient mit einer führenden Null beginnen kann, hat er manchmal nur 15 gültige Ziffern:
`1/3` ergibt 0.333333333333333 (15 Dreien), `2/3` ergibt 0.666666666666667.

## Quadratwurzel

`FN_SQR` ({{FN_SQR}}) zieht die Wurzel Ziffer für Ziffer wie beim schriftlichen Wurzelziehen:
negatives Argument Fehler 3, Exponent halbieren (bei ungeradem Exponent die Mantisse vorher eine
Stelle verschieben), erste Ziffer über die Summe der ungeraden Zahlen, jede weitere durch
fortgesetztes Abziehen; `SQR_SQUARES` liefert die Quadrate der Ziffern. `SQR(16)` = 4 exakt,
`SQR(2)` = 1.414213562373096 (richtig gerundet wäre …095).

## Vergleich, ABS, SGN

`FP_CMP` ({{FP_CMP}}) vergleicht `(DE)` mit `(HL)`: Z bei Gleichheit, CY wenn `(DE)` größer ist.
Zwei Zahlen in Ganzzahlform werden direkt verglichen, sonst normierte Kopien (erst Vorzeichen und
Exponent, dann die Mantisse). Die Vergleichsoperatoren legen −1 (wahr) oder 0 (falsch) ab
(`SET_TRUE`/`SET_FALSE`). `ABS` löscht das Vorzeichenbit, `SGN` liefert −1, 0 oder 1.

## INT

`FN_INT` ({{FN_INT}}) schneidet die Nachkommastellen ab; bei negativen Zahlen mit Rest wird 1
abgezogen (`OP_SUB` mit `FP_ONE_N`). `INT_FINISH` ({{INT_FINISH}}) bringt das Ergebnis in
Ganzzahlform und macht aus −0 eine echte 0 – diese Korrektur fehlt in der älteren Fassung auf
DISK26. Beispiele: `INT(3.7)` = 3, `INT(-3.7)` = −4, `INT(-5)` = −5, `INT(0.2)` = 0.

## RND

`FN_RND` ({{FN_RND}}) arbeitet mit dem Startwert `RND_X` (0.2029882764533591):

- `RND(0)` setzt `RND_X` auf `RND_INIT` zurück,
- jeder Aufruf rechnet `RND_X = RND_X × 23` und behält nur die Nachkommastellen,
- bei negativem Argument kommt vorher ein Anteil aus der Uhr dazu (`TIMER_GET`, über `BYTE2BCD`).

Das Ergebnis ist normiert und liegt zwischen 0 und 1. `RND(0)` liefert nach dem Zurücksetzen
gleich den ersten Wert der Folge: `RND(1);RND(1);RND(0);RND(1)` ergibt im Emulator
0.668730358427259, 0.38079824382696, 0.668730358427259, 0.38079824382696.

## Umwandlung zwischen Text und Zahl

`STR2NUM` ({{STR2NUM}}) liest Ziffern, Punkt und `E[+|-]nn`. Ziffern werden von rechts in die
Mantisse geschoben (`S2N_PUTDIG`); ab der 17. Ziffer wird nur noch gerundet bzw. der Exponent
erhöht. Ohne Ziffer: Fehler 1, zu groß: Fehler 2, zu klein: 0.

`NUM2STR` ({{NUM2STR}}) schreibt nach `NUMBUF`: Vorzeichen (Leerzeichen oder `-`), dann die
Ziffern ohne führende und abschließende Nullen. Es gibt drei Formen:

| Form | wann | Beispiel |
|------|------|----------|
| ganz | ganze Zahl mit bis zu 16 Stellen | ` 1234567890123456`, ` 1500000000000000` |
| Dezimalbruch | sonst, solange die Ziffern in 16 Stellen passen | ` 0.000123`, ` 0.000000000000001`, ` 0.0000000000000015` |
| Exponent | mehr als 16 Stellen vor dem Komma oder sehr klein (ab etwa 1E-16) | ` 1E+16`, ` 1.234567890123457E+17`, ` 1E-16`, ` 2.5E+63` |

Am Ende ruft `NUM2STR` die Routine `NUM_OUT` auf, die den Text normal kopiert oder – bei
`PRINT USING` – nach der Schablone aufbereitet ([PRINT USING](printusing.html)).

## Ganze Zahlen für Befehle

`VAL2UINT` ({{VAL2UINT}}) wandelt einen Wert in eine Zahl 0–65535 für Befehle wie `POKE`, `GOTO`
oder Feldindizes: Kopie nach `FP_TMP1`, `FN_INT`, die oberen zehn Ziffern müssen 0 sein (sonst
Fehler 3), dann Ziffern 1–2 × 10000 + Ziffern 3–4 × 100 + Ziffern 5–6. Umgekehrt legt `BYTE2VAL`
({{BYTE2VAL}}) einen Wert 0–255 in Ganzzahlform auf den Wertestack (über `BYTE2BCD`).

## Genauigkeit und Eigenheiten

Im Emulator mit dem Originalcode gerechnet:

| Ausdruck | Ergebnis | Bemerkung |
|----------|----------|-----------|
| `0.1+0.2` | 0.3 | exakt, weil dezimal |
| `1/3` | 0.333333333333333 | 15 Stellen (führende Null im Quotienten) |
| `1/3*3` | 0.999999999999999 | |
| `123456789*987654321` | 1.219326311126353E+17 | auf 16 Stellen gerundet |
| `9999999999999999+1` | 1E+16 | |
| `1E16-1` | 1E+16 | beim Angleichen geht die 1 verloren |
| `99999999*99999999` | 9999999800000001 | exakt (16 Stellen) |
| `SQR(2)` | 1.414213562373096 | letzte Stelle um 1 zu hoch |

## Fehlende Funktionen

`^`, `SIN`, `COS`, `TAN`, `ATN`, `EXP`, `LOG` und `LN` gibt es nicht; ihre Einträge in
`FUNC_TAB` zeigen auf `ERR_01`. Das Handbuch (2.4.4) empfiehlt dafür die BASIC-Unterprogramme in
der Datei „FUNCTION“ der Systemdiskette (`programme/disk26/FUNCTION.bas`) oder SB-6510.

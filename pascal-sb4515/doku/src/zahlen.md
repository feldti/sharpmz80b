# Zahlen und Arithmetik

## INTEGER

16 Bit mit Vorzeichen (−32768 … 32767), auf dem Laufzeitstapel niederwertiges Byte zuerst.
`+` und `-` rechnen direkt in `RUN_PLUS`/`RUN_MINUS`, `*`, `DIV` und `MOD` über `IMUL`
({{IMUL}}), `IDIV` ({{IDIV}}) und `IMOD` ({{IMOD}}). Diese verknüpfen erst die Vorzeichen
(`ISIGNS`, Ergebnis im Operanden von `SM_ISIGN`) und rechnen dann mit Beträgen (`UMUL16`,
`UDIV16`). `DIV` schneidet zur Null hin ab: `-7 DIV 2` ergibt −3. Überlauf und Division durch 0
ergeben Err 13.

Ganzzahlige Konstanten liest `GET_DEC` ({{GET_DEC}}). `READ` nimmt −32767 bis 32767 an; „32768“
ergibt Err 13. −32768 kann nur durch Rechnen entstehen (`-32767-1`); `INT2STR` gibt es über den
eigenen Text `TXT_M32768` aus, weil sich der Betrag nicht als positive Zahl darstellen lässt.
Beides ist im Emulatortest geprüft.

## REAL: 5-Byte-Gleitkomma

```
Byte 0      Bit 7 = Vorzeichen (1 = positiv!), Bit 0-6 = Exponent mit Bias 40h
Byte 1-4    Mantisse, niederwertiges Byte zuerst, normalisiert (Bit 31 gesetzt)
Wert        Mantisse / 2^32 * 2^(Exponent - 40h)
```

Anders als bei vielen anderen Formaten bedeutet ein **gesetztes** Bit 7 „positiv“. Null hat die
Mantisse 0; `FP_SETZERO` erzeugt 80h, 00h, 00h, 00h, 00h.

| Wert | Bytes | Name in der Quelle |
|------|-------|--------------------|
| 0 | `80 00 00 00 00` | `FP_ZERO` |
| 1 | `C1 00 00 00 80` | `FP_PONE` |
| −1 | `41 00 00 00 80` | `FP_MONE` |
| π/2 | `C1 A1 DA 0F C9` | `FP_PI2` |
| ln 2 | `C0 F8 17 72 B1` | `FP_LN2` |

Die Quelle zeigt bei jeder Konstante den Dezimalwert als Kommentar. Der Wertebereich reicht laut
Handbuch bis ±0.92233720E+19; ein größeres Ergebnis ergibt Err 13 (`1E10*1E10` im Test).

### Grundrechenarten

Alle Routinen arbeiten auf Speicherstellen: `(DE) = (DE) op (HL)`.

| Routine | Adresse | Wirkung |
|---------|--------:|---------|
| `FADD` | {{FADD}} | Addition: Exponenten angleichen, Mantissen addieren oder subtrahieren, normalisieren |
| `FSUB` | {{FSUB}} | Subtraktion: dreht das Vorzeichen von (HL) um und läuft in `FADD` |
| `FMUL` | {{FMUL}} | Multiplikation, 32 × 32 Bit |
| `FDIV` | {{FDIV}} | Division; Überlauf Err 13 |
| `FCMP` | {{FCMP}} | Vergleich: Z gleich, C kleiner |
| `FINT` | {{FINT}} | ganzzahligen Anteil bilden |
| `FCOPY` | {{FCOPY}} | 5 Bytes kopieren |

Zwischenergebnisse stehen in `FP_SIGN`, `FP_RSIGN`, `FP_EXP` und den Speichern `FTMP1` …
`FTMP4`; `FTMP1_ADDMUL` ist ein Schritt des Horner-Schemas für die Reihen.

### Umwandlung

`STR2FP` ({{STR2FP}}) liest eine Zahl aus dem Text (Ziffern, Dezimalpunkt, Exponent). `FP2STR`
({{FP2STR}}) wandelt mit Hilfe der Zehnerpotenzen `FP_POW10` (1E-19 … 1E18) zurück. `WRITELN`
ohne Format gibt REAL rechtsbündig in 15 Stellen mit 8 gültigen Ziffern aus; sehr große und sehr
kleine Beträge erscheinen in Exponentenschreibweise ohne führende 0:

```
     0.33333333        1/3
  .12345678E+09        123456.78*1000
      -.123E-03        -0.000123
     .3333             x:10:4
```

## Funktionen

| Funktion | Routine | Verfahren |
|----------|---------|-----------|
| `SIN(` | `RUN_SIN` → `FSIN` | Argument auf eine Periode reduzieren (`TRIG_ARG`), Quadrant über Vergleiche mit π/2 und π, Reihe in x/(π/2) (Koeffizienten `SIN_COEF`) |
| `COS(` | `FCOS` | über `FSIN` mit verschobenem Argument |
| `TAN(` | `FTAN` | sin/cos |
| `ARCTAN(` | `FATN` | Reihe (`ATN_COEF`, 9 Koeffizienten); große Beträge vermutlich über 1/x (`FRECIP`) |
| `EXP(` | `FEXP` | Reihe (`EXP_COEF`, enthält ln 2, 1/√2 und 0,5), Exponent über `FEXP_SCALE` |
| `LN(` | `FLN` | Mantisse und Exponent getrennt, Reihe mit √2 (`LN_COEF`) |
| `LOG(` | `FLOG` | `LN(x)` · log₁₀ e (`FP_LOG10E`) |
| `SQRT(` | `FSQRT` | Exponent halbieren (`EXP_HALF`), Startwert über Konstanten (`SQRT_C1` …), dann Verbesserungsschritte |
| `RND(` | `FRND` | neue Zufallszahl aus der vorigen (`RND_SEED`, Faktor `FP_23`) |
| `ABS(`, `TRUNC(`, `FLOAT(` | `RUN_ABS`, `RUN_TRUNC`, `RUN_FLOAT` | `TRUNC` und `FLOAT` gehen über Text (`FP2STR`/`STR2FP`) |

### Genauigkeit

Der Emulatortest vergleicht die Ausgaben mit Python. Mit acht ausgegebenen Stellen stimmen
überein:

| Ausdruck | Ausgabe | genauer Wert |
|----------|---------|--------------|
| `1.0/3.0` | 0.33333333 | 0.333333333 |
| `sin(1.0)` | 0.84147098 | 0.841470985 |
| `cos(1.0)` | 0.54030231 | 0.540302306 |
| `tan(0.5)` | 0.54630249 | 0.546302490 |
| `sqrt(2.0)` | 1.4142136 | 1.414213562 |
| `ln(10.0)` | 2.3025851 | 2.302585093 |
| `log(1000.0)` | 3 | 3 |
| `exp(1.0)` | 2.7182818 | 2.718281828 |
| `arctan(1.0)` | **0.78540579** | 0.785398163 |

`ARCTAN` ist nur auf etwa fünf Stellen genau – eine Schwäche des Originals, kein Fehler der
Analyse.

# Interpreterschleife und Ablauf

Interpreterschleife, Ausdrucksauswertung, Variablen und Strings sind aus SB-6511 übernommen. Was
sich geändert hat, hängt fast immer an der Größe der Zahlen: Jede Stelle, die eine Zahl kopiert,
anlegt oder überspringt, rechnet jetzt mit 9 statt 5 Bytes. Die
[SB-6511-Dokumentation](../../basic-sb6511/doku-basic/interpreter.html) beschreibt die Abläufe im Einzelnen.

## Die Schleife

| Routine | Adresse | Aufgabe |
|---------|--------:|---------|
| `NEXTSTMT` | {{NEXTSTMT}} | nach `:` weiter oder zur nächsten Zeile; prüft BREAK und die Tasten |
| `NEXTLINE` / `NL_NEXT` | {{NEXTLINE}} / {{NL_NEXT}} | nächste Programmzeile nach `CURLINE`, Programmende |
| `EXECSTMT2` | {{EXECSTMT2}} | vor jeder Anweisung |
| `DISPATCH` | {{DISPATCH}} | Token `80h,80h+n` → `STMT_TAB[n]` ({{STMT_TAB}}), kein Token → `LET` |

In SB-6511 prüfte `NEXTLINE` über `NL_SRQ` zusätzlich die SRQ-Leitung der GP-IB-Karte (`ON SRQ`);
dieser Teil fehlt, die Aufrufer springen direkt nach `NL_NEXT`.

Die Programmiertechniken sind dieselben: Inline-Parameter hinter `CALL` (`SYNCHK`, `CHK_CHR_ALT`,
`FINDLINE`, `MUL16`, `VAL2UINT` …), die Kette der Fehlereinsprünge `ERR_01`…`ERR_70` mit dem
`DEFB 01h`-Trick und viel selbstmodifizierender Code. Im neuen Code kommen weitere Fälle dazu, etwa
`FP_NORM` und `FP_SHRN`, die ihre Schiebeweiten in die eigenen Befehle schreiben, oder
`ADD_SWAP`, dessen Befehl `ASW_SIGN` je nach Addition oder Subtraktion `NOP` oder `CPL` ist.

## Ausdrücke

`EVAL` ({{EVAL}}) und `EVAL_EXPR` ({{EVAL_EXPR}}) werten wie bei SB-6511 mit Vorrangstufen aus;
Zwischenergebnisse liegen auf dem Wertestack, dessen Zeiger `VALSP` ({{VALSP}}) bei jedem Operanden
um 9 Bytes weiterrückt (`VALSP_ADD`). Die Operatoren und Funktionen laufen über `FUNC_TAB`
({{FUNC_TAB}}); die Rechenroutinen bekommen Zeiger auf die Exponentbytes der beiden Operanden
(siehe [Zahlen](zahlen.html)).

`^` wird weiterhin erkannt (`POWER_OP`), sein Eintrag `FUNC_TAB[16]` zeigt aber auf `ERR_01`.
Ebenso die Funktionen `SIN(` bis `LN(` (Einträge 38–42, 44, 45). Das Zeichen FFh im Programmtext
steht wie bei SB-6511 für π (`PRIM_PI`), jetzt mit 16 Stellen: `FP_PI` = 3.141592653589793.

## Variablen

Eine Zahlvariable belegt 11 Bytes: zwei Bytes Name, neun Bytes Wert. `NUMVAR` ({{NUMVAR}}) sucht im
Bereich `P_NUMVAR` und legt eine fehlende Variable mit dem Wert aus `FP_ZERO` an
(`NUMVAR_NEW`). `VAL_PUT` und `VAL_GET` kopieren 9 Bytes zwischen Variable und Wertestack.
Stringvariablen sind unverändert (Name, Länge, Text, 0Dh).

## Felder

Felder werden mit `DIM` angelegt, die Elemente von Zahlenfeldern sind 9 Bytes groß und beim Anlegen
mit `FP_ZERO` gefüllt. Neu ist, dass der Index eines **eindimensionalen** Feldes größer als 255
sein darf: `ARR_FIND` ({{ARR_FIND}}) liest ihn mit `EVAL_INT` statt `EVAL_BYTE`. Bei
zweidimensionalen Feldern prüft `ARR_DIM2CHK` ({{ARR_DIM2CHK}}), dass der erste Index unter 256
bleibt. Das Handbuch (2.4.3) bestätigt: `DIM A(1000)` ist erlaubt, `DIM B(80,80)` höchstens bis
255 je Index.

## Stacks

| Stack | Zeiger | Eintrag | Bereich | Grenze |
|-------|--------|---------|---------|--------|
| FOR | `FOR_SP` ({{FOR_SP}}) | 27 Bytes: Variable (2), Schrittweite (9), Vorzeichen (1), Endwert (9), `CURLINE` (4), `TXTPTR` (2) | ab 684Fh abwärts | 15 Einträge (Fehler 11) |
| GOSUB | `GOSUB_SP` ({{GOSUB_SP}}) | 7 Bytes: `CURLINE`, `TXTPTR`, `FOR_CNT` | ab 68B8h abwärts | 15 Einträge (Fehler 10) |
| FN | `FNPAR_SP` ({{FNPAR_SP}}) | 6 Bytes je Ebene | ab 66BAh abwärts | `FNPAR_END` (Fehler 12) |

`ST_FOR` baut den Eintrag in `FOR_VAR` ({{FOR_VAR}}) auf: Laufvariable, Endwert, Schrittweite
(ohne `STEP`: `FP_ONE`) und ihr Vorzeichen in `FOR_STEPSGN`. Ein älterer Eintrag derselben
Variablen wird samt allen jüngeren entfernt, dann kommen 27 Bytes auf den Stack. `ST_NEXT`
addiert die Schrittweite mit `OP_ADD` und vergleicht je nach Vorzeichen mit `FP_CMP`; weil die
Arithmetik dezimal rechnet, endet z. B. `FOR I=0 TO 1 STEP 0.1` genau nach elf Durchläufen.

## LIST_LOCK: ein unbekannter Listschutz

`LIST` und `SAVE` prüfen den Direktmodus mit `CHK_DIRECT_LK` ({{CHK_DIRECT_LK}}) statt
`CHK_DIRECT`. Zusätzlich wird das Byte `LIST_LOCK` ({{LIST_LOCK}}) gelesen: Ist es nicht 0, kehrt der
Befehl stillschweigend nach „Ready“ zurück – das Programm lässt sich weder listen noch speichern.

`CLEARALL` (`NEW`, Kaltstart) setzt `LIST_LOCK` auf 0. Gesetzt wird es aber nirgends im BASIC.
Vermutlich war es als Listschutz gedacht, den ein Programm per `POKE` einschaltet. Weder das
Handbuch noch eines der Programme auf den 66 vorhandenen Diskettenabbildern erwähnt oder benutzt es.

> Offener Punkt: Wer `LIST_LOCK` setzt, ist ungeklärt.

## Weitere Änderungen

- `GET var` merkt sich die zuletzt gelesene Taste in `GET_LASTKEY`; solange dieselbe Taste
  gedrückt bleibt, liefert `GET` einen leeren String bzw. 0 ([Ein-/Ausgabe](ein-ausgabe.html#get)).
- `CLR` ruft `PROG_CLRVARS` (Bereiche, Variablen und Stackzeiger zurücksetzen).
- `INP@`/`OUT@` lesen die Portnummer mit `EVAL_BYTE` (0–255).

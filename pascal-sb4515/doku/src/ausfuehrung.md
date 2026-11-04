# Ausführung

## Start

`RUN_START` ({{RUN_START}}) setzt `RUN_MODE` auf 2 (Fehler werden dann mit `Run*` gemeldet),
legt mit `RUN_ALLOC` ({{RUN_ALLOC}}) die globalen Variablen an und führt den Hauptblock aus. Am
Ende schließt `RUN_END` eine offene Datei (`RUN_CLOSE`) und kehrt nach `PAS_READY` zurück.

`RUN_ALLOC` geht den `VAR`-Abschnitt durch und belegt für jede Variable von `INBUF` abwärts so
viele Bytes, wie `NEG_SIZE_TAB` ({{NEG_SIZE_TAB}}) für ihren Typ angibt (−6, −3, −2, −2), und
schreibt das Typbyte hinein. Felder bekommen einen Kopf (Typ, Dimension, Zeiger auf die Daten);
die Daten selbst liegen ab `RT_AREA0`. Danach beginnt dort, wo die Variablen enden, der
**Laufzeitstapel** (`RT_SP`, {{RT_SP}}).

## Text lesen

Zur Laufzeit liest `RUN_GETTOK` ({{RUN_GETTOK}}) den Text über HL. Es überspringt alle Bytes
unter 60h – Einrückung und die Buchstaben der Bezeichner – und liefert nur Token; Kommentare
werden über ihren Verweis übersprungen. Die Bezeichner selbst braucht die Ausführung nicht mehr:
Hinter jedem steht seit dem Prüflauf E2h/E3h mit Typ und Adresse.

## Laufzeitstapel

Ausdrücke werden auf einem eigenen Stapel ausgewertet, der von `RT_SP` nach unten wächst. Jeder
Eintrag beginnt mit dem Typbyte:

| Typbyte | Inhalt | Länge |
|--------:|--------|------:|
| 00h | `REAL`, 5 Bytes Gleitkomma | 6 |
| 01h | `INTEGER`, 2 Bytes (niederwertig zuerst) | 3 |
| 02h | `CHAR`, 1 Byte | 2 |
| 03h | `BOOLEAN`, 1 Byte (Bit 0 = TRUE) | 2 |

`RT_PUSHVAR` ({{RT_PUSHVAR}}) legt eine Variable auf den Stapel, `RT_POPVAR` ({{RT_POPVAR}})
schreibt den obersten Wert zurück, `RT_DROP`, `RT_DUP`, `RT_SWAP` und `RT_POPBOOL` helfen bei den
Operatoren. Variablenadressen liefert `VAR_ADDR` ({{VAR_ADDR}}): bei E2h `INBUF` plus Abstand,
bei E3h `RT_AREA1` plus Abstand; bei Feldern rechnet `ARRAY_INDEX` die Elementadresse aus und
prüft die Grenzen (Err 13).

## Ausdrücke

`RUN_EXPR` ({{RUN_EXPR}}) → `RUN_SIMPLE` → `RUN_TERM` → `RUN_FACTOR` werten nach denselben
Rangstufen aus wie der Prüflauf. Die Operatoren springen über Tabellen: `RUN_TAB7A` (Vergleiche),
`RUN_TAB81` (`-` `+` `OR` `XOR`), `RUN_TAB_MUL` (`*` `AND` `DIV` `MOD` `/`), die Funktionen ab
B3h über `RUN_TABB3`, Variablen, Konstanten und Funktionsaufrufe über `RUN_TABE2B`.

`OP_PREP` stellt beide Operanden bereit und meldet, ob sie `INTEGER` sind; danach rechnet der
Operator ganzzahlig (`IMUL`, `IDIV` …) oder mit Gleitkomma (`FADD`, `FMUL` …). Vergleiche legen
ein `BOOLEAN` auf den Stapel.

## Anweisungen

`RUN_STATEMENT` ({{RUN_STATEMENT}}) verteilt nach dem Token: 69h–6Eh über `RUN_TAB69`,
eingebaute Prozeduren 8Fh–B2h über `RUN_TAB8F`, Zuweisung und Prozeduraufruf über `RUN_TABE2`
(E2h globale, E3h lokale Variable, E4h Prozedur). Andere Token beenden die Anweisung.

| Anweisung | Umsetzung |
|-----------|-----------|
| `BEGIN … END` | `RUN_BEGIN`: Speicher prüfen, Anweisungen ausführen, solange `;` folgt |
| `IF … THEN … ELSE` | `RUN_IF`: Bedingung auswerten; bei FALSE über das eingetragene Sprungziel hinter `THEN` zum `ELSE` bzw. dahinter |
| `WHILE … DO` | `RUN_WHILE`: Bedingung, Rumpf, zurück; Abbruch über das Sprungziel hinter `DO` |
| `REPEAT … UNTIL` | `RUN_REPEAT`: Anweisungen bis `UNTIL`, dann Bedingung |
| `FOR … TO/DOWNTO … DO` | `RUN_FOR`, siehe unten |
| `CASE … OF … END` | `RUN_CASE`: Marken der Reihe nach vergleichen (`CASE_LABEL`), passende Anweisung ausführen, Rest überspringen (`CASE_SKIP`) |

In `WHILE`-, `REPEAT`- und `FOR`-Schleifen sowie zu Beginn des Hauptblocks und jedes
Unterprogramms (`RUN_STMT_BRK`) fragt der Interpreter die BREAK-Taste ab; BREAK führt zu
„*Break“ und `PAS_READY`.

### FOR

`RUN_FOR` arbeitet mit selbstmodifiziertem Code: `FOR_SETVAR` trägt Länge und Adresse der
Laufvariablen in mehrere Befehle ein (`SM_FOR_LEN1` … `SM_FOR_VAR3`), und je nach `TO` oder
`DOWNTO` werden Vergleich (`SM_FOR_CMP`) und Schritt (`SM_FOR_STEP`: `FOR_INC` oder `FOR_DEC`)
gesetzt. Weil diese Werte im Code stehen, rettet `RUN_FOR` die alten Operanden auf dem
Prozessorstapel und stellt sie am Ende wieder her – so funktionieren auch verschachtelte
Schleifen. Die Laufvariable kann `INTEGER` oder `CHAR` sein; ein Überlauf ergibt Err 13.

## Unterprogramme

Ein Prozeduraufruf (E4h, `RUN_PCALL`) oder Funktionsaufruf (E5h, `RUN_FCALL`) läuft über
`RUN_CALLSUB` ({{RUN_CALLSUB}}):

1. Die aktuellen Parameter auswerten (Wertübergabe) und als lokale Variablen anlegen; bei einer
   Funktion vorher Platz für das Ergebnis schaffen.
2. `RT_AREA1` auf die neuen lokalen Variablen setzen.
3. Mit gesperrten Interrupts den Prozessorstapel zwischen SP und `STACK_TOP` unter den
   Laufzeitstapel umkopieren und den Rumpf ausführen.
4. Danach Stapel, `RT_AREA1` und `RT_AREA0` wiederherstellen.

Weil jeder Aufruf seine eigenen lokalen Variablen bekommt, sind Unterprogramme rekursiv
aufrufbar, wie es das Handbuch angibt. Im Beispiel aus dem [Editor](editor.html#beispiel) ruft
die Schleife `p(i)` dreimal auf; das Ergebnis `6` ist im Emulatortest nachgeprüft.

## Ende und Abbruch

| Ereignis | Ablauf |
|----------|--------|
| `END.` erreicht | `RUN_END`: Datei schließen, „Ready.“ |
| Fehler | `ERROR`: „*Err nn* Run*“, `PAS_READY`; eine offene Datei wird nicht abgeschlossen, `PAS_READY` setzt nur ihren Zustand zurück |
| BREAK | `BREAK_STOP`: „*Break“, `PAS_READY` |
| Kassettenfehler | „Err 34/35* Run*“ und Wahl C)ontinue / E)ditor |

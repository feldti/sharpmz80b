# Prüflauf und Symboltabellen

`G` startet nicht sofort das Programm. `PCMD_G` ({{PCMD_G}}) liest den ganzen Text einmal durch,
prüft Deklarationen, Syntax und Typen, legt die Symboltabellen an und trägt dabei Adressen und
Sprungziele in den Tokentext ein. Erst wenn der Hauptblock mit `END.` endet, geht es nach
`RUN_START` ({{RUN_START}}). Ein Fehler im Prüflauf wird mit der Zeilennummer gemeldet:

```
*Err 19* Line   2.
```

Da der Prüflauf vor jedem `G` neu läuft, dürfen Änderungen am Text die eingetragenen Werte
ungültig machen – sie werden ohnehin neu berechnet.

## Lesen des Texts

`SYN_GETTOK` ({{SYN_GETTOK}}) liefert das nächste Zeichen oder Token. Es überspringt Kommentare
(`SYN_SKIPCMT` trägt dabei den Verweis auf ihr Ende ein), zählt bei jedem 0Dh `LINE_NO` hoch und
übergeht das Einrückungsbyte. Läuft der Text ab, bevor das Programm vollständig ist, folgt Err 01.
`SCAN_TOKEN` sucht nur das nächste Schlüsselwort (für den Vorlauf über Unterprogramme);
`PUSH_LINENO`/`POP_LINENO` und `CALL_KEEPLINE` retten `LINE_NO`, wenn ein Teil des Texts
mehrfach gelesen wird.

## Programmaufbau

```
[VAR Name, Name : Typ; ...]
[PROCEDURE Name(Parameter); Block;]   (beliebig viele, auch FUNCTION Name(...): Typ;)
BEGIN Anweisung; ... END.
```

- `SYN_DECLS` / `SYN_VAR` ({{SYN_VAR}}): „`Name, Name : Typ ;`“ bis kein Bezeichner mehr folgt.
  Typen sind `REAL`, `INTEGER`, `CHAR`, `BOOLEAN`, `ARRAY [n, m ...] OF Typ`
  (`SYN_ARRAYTYPE`, Grenzen als ganzzahlige Konstanten) und `FILE OF Typ`.
- `DECL_PROC` / `DECL_FUNC` tragen Prozeduren (Art E4h) und Funktionen (Art E5h) ein;
  `SYN_PARAMS` liest die formalen Parameter, `SYN_SUBBODY` prüft den Rumpf mit lokalen
  Deklarationen.
- `MAIN_BLOCK` ({{MAIN_BLOCK}}) prüft den Hauptblock; folgt der Punkt, beginnt die Ausführung.

## Typen

| Code | Typ | Token | Größe auf dem Laufzeitstapel (mit Typbyte) |
|-----:|-----|-------|------:|
| 0 | `REAL` | 63h | 6 |
| 1 | `INTEGER` | 64h | 3 |
| 2 | `CHAR` | 65h | 2 |
| 3 | `BOOLEAN` | 66h | 2 |

Der Typcode ist das Token minus 63h (`TYPE_CODE`); `TYPE_SIZE` ({{TYPE_SIZE}}) liefert die Größe.
Bit 6 kennzeichnet Felder, Bit 5 FILE-Variablen. `TYPE_MATCH` ({{TYPE_MATCH}}) vergleicht zwei
Typcodes und meldet Err 17, wenn sie verschieden sind. Es gibt **keine automatische Umwandlung**
von `INTEGER` nach `REAL`: dafür ist `FLOAT(` da, zurück geht es mit `TRUNC(`.

## Symboltabellen

Jeder Eintrag besteht aus dem Namen (letztes Zeichen mit Bit 7) und fünf Bytes. Globale Namen
stehen ab `RT_AREA0` direkt hinter dem Programmtext, Unterprogramme ab `RT_AREA1`, lokale Namen
werden beim Prüfen eines Rumpfs dahinter angelegt (`SYM_LOCAL`). Die Bereiche liegen
hintereinander; `SYM_MAKEROOM` und `SYM_GROW1`–`SYM_GROW3` verschieben sie beim Einfügen. Reicht
der Platz bis `WORKBUF` nicht, folgt Err 13.

Im Beispiel aus dem [Editor](editor.html#beispiel) (`var i,s:integer;`) steht nach dem Prüflauf:

```
C9  01  5B 61  FD FF     I   INTEGER, Deklaration bei 615Bh, Abstand -3
D3  01  5B 61  FA FF     S   INTEGER, Deklaration bei 615Bh, Abstand -6
00                       Ende der globalen Tabelle
```

Die globalen Variablen liegen zur Laufzeit unter `INBUF`, in der Reihenfolge der Deklaration,
jede mit ihrer Größe samt Typbyte.

`DECLARE` ({{DECLARE}}) trägt einen Namen ein (schon vorhanden: Err 02), `SYM_FIND`
({{SYM_FIND}}) sucht ihn. Welche Tabelle gemeint ist, steht in den Operanden von `SM_SYMTAB`,
`SM_SYMTAB_IY` und `SM_SYMGROW`, die `PCMD_G` und `SYM_LOCAL` umstellen.

## Bezeichner auflösen

Trifft der Prüflauf auf einen Bezeichner, sucht `RESOLVE_IDENT` ({{RESOLVE_IDENT}}) erst lokal,
dann global und schreibt das Token davor um: **E3h** für lokale, **E2h** für globale Variablen,
dahinter Typ und Abstand. Bei Feldern prüft `SYN_INDEX` die Indexliste (Anzahl der Indizes gleich
der Dimension, sonst Err 29). Unbekannte Namen ergeben Err 27.

## Anweisungen und Ausdrücke

`SYN_STATEMENT` ({{SYN_STATEMENT}}) unterscheidet Zuweisung bzw. Prozeduraufruf (Bezeichner),
die Steueranweisungen 69h–6Eh (`SYN_TAB69`) und die eingebauten Prozeduren 8Fh–B2h
(`SYN_TAB8F`). Bei `IF`, `WHILE`, `FOR` und `CASE` prüft `SYN_LINKSTMT` die abhängige Anweisung
und schreibt die Adresse ihres Endes in die zwei Bytes hinter `THEN`, `ELSE` bzw. `DO`. Die
Ausführung springt dann ohne Suchen über nicht ausgeführte Zweige.

Ausdrücke prüfen `SYN_EXPR` → `SYN_SIMPLE` → `SYN_TERM` → `SYN_FACTOR` mit den üblichen
Rangstufen:

| Stufe | Operatoren | Bedingung |
|-------|------------|-----------|
| Vergleich | `<` `<=` `=` `>=` `>` `<>` | gleiche Typen, Ergebnis `BOOLEAN` |
| Addition | `+` `-` `OR` `XOR` | `OR`/`XOR` auf `BOOLEAN` |
| Multiplikation | `*` `AND` `DIV` `MOD` `/` | `DIV`/`MOD` nur `INTEGER`, `/` nur `REAL` |
| Faktor | `( … )`, `NOT`, Konstante, Variable, Funktion | |

Die Funktionen ab B3h prüft `SYN_TABB3` (z. B. `SYN_FN_REAL` für `SIN(` … `SQRT(`).

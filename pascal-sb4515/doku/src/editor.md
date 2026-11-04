# Editor und Programmtext

## Kommandoschleife

`CMD_LOOP` ({{CMD_LOOP}}) liest eine Zeile mit `GET_LINE` und entscheidet am ersten Zeichen:

| Eingabe | Wirkung |
|---------|---------|
| `#` | Zeilennummern im Listing ein/aus (Operand von `PR_LINENO`) |
| `$` | Einrücken bei der Eingabe ein/aus (Operand von `INDENT_MASK`) |
| Pfeil (1Fh) | `PCMD_ARROW`: Eingabe ab der Zeile am Zeiger |
| Ziffer | `PCMD_LINENO`: Zeile *n* löschen, ersetzen oder Eingabe ab *n* |
| Buchstabe | Kommando über `CMD_TAB` ({{CMD_TAB}}); `JP_INLINE_TAB` springt über die Tabelle hinter dem Aufruf |

Belegt sind A, B, D, E, F, G, H, I, K, L, M, N, P, Q, R, S, T, V, Z; die übrigen Buchstaben
führen zu Err 40. Die vollständige Liste mit Routinen steht in der
[Befehlsreferenz](befehle.html#editorkommandos). `T` (Zeiger an den Anfang, dann wie `N`) steht
nicht im Handbuch.

## Zeilen ohne Nummern

Das Programm ist eine Folge von Zeilen ab `TXT_START` ({{TXT_START}}) bis `TXT_END`. Gespeichert
wird **keine** Zeilennummer: Die Nummer, die der Editor anzeigt (`   0.`, `   1.` …), ist die
Position der Zeile im Text. Daraus folgt:

- Einfügen und Löschen verschieben alle folgenden Nummern.
- Der Editor hat einen **Zeiger**: `CUR_LINE` (Nummer) und `TXT_PTR` (Adresse). `L` und `N`
  bewegen ihn, `PTR_TOP` setzt ihn auf Zeile 0, `LINE_SKIP` zählt vom Anfang aus vor.
- `LINE_INSERT` ({{LINE_INSERT}}) schiebt den Rest des Texts nach oben und fügt vor der Zeile am
  Zeiger ein; `LINE_DELETE` ({{LINE_DELETE}}) entfernt die Zeile am Zeiger.

### Eingabe über die Bildschirmzeile

Im Eingabemodus (`B`, `Z`, `n` + Pfeil) gibt `INPUT_LOOP` ({{INPUT_LOOP}}) die Zeilennummer aus,
z. B. `   3.`, rückt bei eingeschaltetem `$` passend ein und liest dann die Zeile. Weil
`GETL_PATCH` den Monitor die **ganze Bildschirmzeile ab Zeilenanfang** zurückgeben lässt, kommt
die angezeigte Nummer mit zurück; `INPUT_LOOP` liest sie mit `GET_DEC`, stellt den Zeiger auf
diese Zeile, falls sie nicht `CUR_LINE` ist, und fügt den Rest der Zeile dort ein. So kann man eine angezeigte Zeile auf dem Bildschirm
ändern und mit CR neu eingeben. Eine leere Zeile beendet die Eingabe.

`PCMD_LINENO` arbeitet genauso: „`n`“ allein löscht Zeile *n*, „`n Text`“ ersetzt sie, „`n`“ mit
Pfeil setzt die Eingabe dort fort.

## Tokenizer

`TOKENIZE` ({{TOKENIZE}}) setzt die Zeile nach `WORKBUF` um:

1. Kleinbuchstaben außerhalb von Texten und Kommentaren werden groß (`UPCASE_LINE`).
2. Die Zahl der führenden Leerzeichen wird das erste Byte der Zeile (Einrückung).
3. Ein Wort aus Buchstaben und Ziffern wird in `KWTAB` gesucht (`KW_FIND`, {{KW_FIND}}); dabei
   zählt „`READ(`“ mit Klammer als ein Schlüsselwort. Gefunden: ein Token 60h–E1h. Sonst ist es
   ein Bezeichner: der Name bleibt als Text stehen, dahinter kommt das Token E2h mit drei
   Platzhalterbytes.
4. Zahlen werden zur Konstante E6h (`TOK_NUMBER`), mit Typbyte (01h `INTEGER`, 00h `REAL`).
5. Operatoren aus zwei Zeichen (`:=`, `<=`, `>=`, `<>`) werden zu einem Token; `"…"`, `'…'` und
   `{…}` bekommen die Token E0h, DFh, DEh mit Platz für einen Verweis. Zeichen wie `!`, `#`,
   `@`, `\` oder `^` führen zu Err 45.

Die Schlüsselworttabelle `KWTAB` ({{KWTAB}}) enthält die Wörter mit gesetztem Bit 7 im letzten
Zeichen; das Token ist 60h plus die Position. Wörter mit `*` am Anfang (`*ROGRAM`, `**TYPE` …)
können nie passen, 80h-Einträge sind freie Token.

### Zeilenformat

<pre>
Einrückung  Token und Zeichen ...  0Dh
</pre>

Token ab D8h tragen Operandenbytes, deren Anzahl `TOKLEN_TAB` ({{TOKLEN_TAB}}) angibt. Beim
Tokenisieren sind sie leer; gefüllt werden sie erst im [Prüflauf](pruefung.html).

| Token | Operanden |
|-------|-----------|
| E2h / E3h (hinter einem Bezeichner) | Typ, 2 Bytes Adresse (Deklaration) bzw. Abstand (Verwendung) |
| E4h (Prozeduraufruf) | 3 Bytes, Verweis auf die Deklaration |
| E6h (Zahl) | Typ; `INTEGER`: 3 ungenutzte Bytes und der Wert, `REAL`: 5 Bytes Gleitkomma |
| DAh/DBh/DCh (`THEN`/`ELSE`/`DO`) | 2 Bytes Sprungziel |
| DEh, E0h (Kommentar, Text) | 2 Bytes Verweis auf das Ende |
| D8h/D9h (`PROCEDURE`/`FUNCTION`) | Anzahl der Parameter, Verweis auf die Parameterliste … |

## Beispiel

Das folgende Programm wurde im Emulator eingegeben und mit `G` ausgeführt (Ausgabe `6`); danach
wurde der Text ausgelesen. Zeile 5 sieht im Speicher so aus:

```
for i:=1 to 3 do p(i);

00                Einrückung 0
6E                FOR
49 E2 01 FD FF    I   E2h: INTEGER, Abstand FFFDh (-3) zu INBUF
79                :=
E6 01 8A 58 00 01 00     Zahl: INTEGER, (3 Bytes Rest), 0001h
6F                TO
E6 01 0D 72 76 03 00     Zahl: INTEGER, 0003h
DC C4 61          DO, Sprungziel 61C4h (das ";" hinter dem Aufruf)
50 E4 00 60 61    P   E4h: Prozeduraufruf, Deklaration bei 6160h
8A 49 E2 01 FD FF 8D     ( I )
76 0D             ;  Zeilenende
```

Die drei „ungenutzten“ Bytes der Zahlkonstanten sind Reste aus dem Arbeitspuffer. Das ganze
Programm:

```
var i,s:integer;
procedure p(x:integer);
begin s:=s+x end;
begin
s:=0;
for i:=1 to 3 do p(i);
writeln(s)
end.
```

## Listing

`LIST_LINE` ({{LIST_LINE}}) gibt die Zeile am Zeiger mit Nummer aus, `DETOKENIZE`
({{DETOKENIZE}}) baut den Klartext in `LINEBUF` auf: Einrückung, Schlüsselwörter **klein**
(`TO_LOWER`), Bezeichner groß, Zahlen über `LIST_NUMBER`. `KW_SPACE_AFTER` entscheidet, ob nach
einem Schlüsselwort ein Leerzeichen folgt. `P` listet auf den Bildschirm (Leertaste hält an,
BREAK bricht ab), `H` auf den Drucker; `#` schaltet dort die Nummern ab.

```
   0.var I:integer;
   1.begin 
   2.if I=0 I:=1 
```

## Kassette: S, A, V

`S` schreibt den Programmtext als Datei vom **Typ A0h** (`PCMD_S`), `A` sucht eine solche Datei
mit passendem Namen und hängt sie an das Programm an (`PCMD_A`), `V` vergleicht sie mit dem
Speicher (`PCMD_V`, gleicher Code). Laden heißt also: `K/` und dann `A`. Schreib- und Lesefehler
sind Err 34 bzw. 35, zu wenig Speicher Err 39, kein Programm Err 48.

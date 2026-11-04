# PRINT USING

`PRINT USING` gibt Zahlen nach einer Schablone aus. Es ist neu in SB-6610 (Token 9Dh) und
funktioniert auf dem Bildschirm und mit `PRINT/P` auf dem Drucker.

    PRINT [/P] USING schablone ; ausdruck [ , ausdruck ...]

Die Schablone ist ein beliebiger Stringausdruck. Jede Zahl der Liste wird nach derselben
Schablone ausgegeben; ein `,` zwischen den Ausdrücken springt wie bei `PRINT` zur nächsten
Tabulatorposition, ein `;` hängt direkt an.

## Formatzeichen

| Zeichen | Bedeutung |
|---------|-----------|
| `#` | eine Ziffernstelle; freie Stellen vorn werden Leerzeichen |
| `*` | eine Ziffernstelle; freie Stellen vorn werden `*` (nicht mit `#` mischen) |
| `.` | Dezimalpunkt, höchstens einer; fehlende Nachkommastellen werden `0` |
| `,` | Tausendertrenner an dieser Stelle |
| `X` | Leerzeichen zwischen den Ziffern |
| `+` | Vorzeichen immer ausgeben |
| `-` | Vorzeichen nur bei negativen Zahlen, sonst Leerzeichen |
| `$` `£` `@` | Währungszeichen direkt vor der Zahl (£ ist das Zeichen 91h) |
| anderer Text | vor dem ersten bzw. hinter dem letzten Formatzeichen: wird unverändert ausgegeben |

## Beispiele aus dem Handbuch

Alle Beispiele aus Kapitel 2.4.1 des Handbuchs, im Emulator mit dem Originalcode ausgegeben
(„·“ steht für ein Leerzeichen). Die Ausgaben stimmen genau mit dem Handbuch überein und sind Teil
von `tools/test_sb6610_run.py`.

| Anweisung | Ausgabe |
|-----------|---------|
| `PRINT USING "##,###";12345` | `12,345` |
| `PRINT USING "##.##";12.345` | `12.34` |
| `PRINT USING "+###,###";123456` | `+123,456` |
| `A$="-#,###":PRINT USING A$;-1234` | `-1,234` |
| `PRINT USING "+#.##";1.23` | `+1.23` |
| `PRINT USING "#.###";1.23` | `1.230` |
| `PRINT USING "##,###.#";12345` | `12,345.0` |
| `PRINT USING "##,###";12` | `····12` |
| `PRINT USING "**,***";12` | `****12` |
| `PRINT USING "+****";12` | `**+12` |
| `PRINT USING "@##.##";12.3` | `@12.30` |
| `PRINT USING "##XXX##";1234` | `12···34` |
| `PRINT USING "#,###.XXX##";123.4` | `··123.···40` |
| `PRINT USING "##,###";123456` | `%123,456` |
| `PRINT USING "UNIT PRICE @##.## YEN";12.34` | `UNIT PRICE @12.34 YEN` |
| `A$="COMPUTER ### SYSTEMS":PRINT USING A$;12` | `COMPUTER··12·SYSTEMS` |
| `PRINT USING "##,###";1234,567` | `·1,234·······567` |

## Eigenheiten

Ebenfalls im Emulator geprüft:

- **Abschneiden statt Runden:** `"#.##";2.556` ergibt `2.55`, `"##";9.9` ergibt `·9`,
  `"###";-12.7` ergibt `·-12`.
- **Zu wenig Stellen:** Passt der Vorkommateil nicht, kommt `%` und die Zahl in voller Länge
  (`"##";123` → `%123`).
- **Negative Zahlen ohne `+`/`-` in der Schablone** bekommen eine Stelle mehr für das `-`:
  `"###.##";3.14159` → `··3.14`, aber `"###.##";-2.5` → `··-2.50`.
- **Fehler 1** bei: Zahlen in Exponentform (`"##.#";1E20`), `#` und `*` gemischt (`"**###"`),
  zwei Währungs- oder Vorzeichenzeichen (`"$$##"`), zwei Dezimalpunkten, einer Schablone ohne
  Ziffernstelle, leerer Schablone.
- **Null als „O“:** Mit `POKE $002D,1` gibt `PRINT USING` die Ziffer 0 als Buchstaben O aus,
  `POKE $002D,0` schaltet zurück (Handbuch). Das Byte liegt im Monitor-Bereich und wird vom
  BASIC sonst nicht benutzt.
- `STR$` setzt `USING_PTR` auf 0 und ist deshalb von `USING` nicht betroffen.

## Umsetzung

### Ablauf

1. `ST_PRINT` ({{ST_PRINT}}) setzt `USING_PTR` ({{USING_PTR}}) auf 0. Folgt nach `PRINT` bzw.
   `PRINT/P` das Token 9Dh, ruft es `PR_USING` ({{PR_USING}}) auf.
2. `PR_USING` wertet die Schablone aus (`;` muss folgen), kopiert sie mit `STR2TEXT` nach
   `INBUF` und zerlegt sie mit `USING_PARSE` ({{USING_PARSE}}). Danach zeigt `USING_PTR` auf
   `USING_FMT` ({{USING_FMT}}).
3. Jede Zahl der Liste geht wie sonst über `VAL2TEXT` → `NUM2STR`. Am Ende von `NUM2STR` steht
   der Text in `NUMBUF`; `NUM_OUT` ({{NUM_OUT}}) kopiert ihn ohne USING unverändert, mit USING
   baut es die Ausgabe nach der Schablone in `USING_FMT` auf.

`NUM2STR` übergibt in A, welche Form der Text hat (0 normal, 1 mit Exponent, 2 ganz); der Wert
entsteht mit einem Byte-Trick in `N2S_END0`/`N2S_END` (`LD A,01h / DEFB 01h / LD A,00h`, und der
Operand von `LD BC,023Eh` ist zugleich `LD A,02h`).

### USING_PARSE

`USING_PARSE` geht die Schablone einmal durch und füllt 13 Bytes Variablen:

| Variable | Adresse | Inhalt |
|----------|--------:|--------|
| `USG_PRELEN` | {{USG_PRELEN}} | Länge des Präfixtexts (schon nach `USING_FMT` kopiert) |
| `USG_SUFLEN`, `USG_SUFPTR` | {{USG_SUFLEN}}, {{USG_SUFPTR}} | Länge und Lage des Suffixtexts |
| `USG_CURR` | {{USG_CURR}} | Währungszeichen `$`, £ oder `@` |
| `USG_SIGN` | {{USG_SIGN}} | `+` oder `-` |
| `USG_POINT` | {{USG_POINT}} | Lage des Dezimalpunkts in der Schablone |
| `USG_FILL` | {{USG_FILL}} | Ziffernzeichen `#` oder `*` |
| `USG_INTDIG`, `USG_FRACDIG` | {{USG_INTDIG}}, {{USG_FRACDIG}} | Ziffernstellen vor und hinter dem Punkt |

Die Zeichenklassen prüft `USING_MATCH` ({{USING_MATCH}}) mit drei überlappenden Listen ab
`USING_CHARS`: alle Formatzeichen, darin ab `USING_SIGNS` die Vorzeichen- und Währungszeichen,
und `USING_DIGCH` mit `#` und `*`.

### NUM_OUT

1. Exponentform → Fehler 1. Präfix ausgeben.
2. Stellen der Zahl vor dem Punkt zählen. Zu viele: `NOU_OVERFLOW` gibt `%` und alles aus.
3. Freie Stellen vorn mit Leerzeichen oder `*` füllen, Kommas dazwischen ebenfalls.
4. `USING_SIGN`: Währungszeichen, dann `-`, `+` oder Leerzeichen nach `USG_SIGN`.
5. `USING_DIGS` ({{USING_DIGS}}): Ziffern nach der Schablone, `,` und `.` übernehmen, `X` als
   Leerzeichen, nach dem Ende der Ziffern `0`; bei gesetztem Byte 002Dh `O` statt `0`.
6. Nachkommastellen (`USG_FRACDIG`), dann Suffix bzw. 0Dh.

Der Text in `USING_FMT` wird danach wie jedes andere `PRINT`-Element ausgegeben.

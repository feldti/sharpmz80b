# Tokenizer und Programmtext

Der Tokenizer ist unverändert aus SB-6511 übernommen; nur die Schlüsselworttabellen und die
Adressen unterscheiden sich. Die ausführliche Beschreibung von CRUNCH und LISTLINE steht in der
[SB-6511-Dokumentation](../../basic-sb6511/doku-basic/tokenizer.html) und gilt Wort für Wort auch hier.

## Token-Format

| Token | Bedeutung |
|-------|-----------|
| `80h, 80h+n` | Anweisung n aus `KWTAB_STMT` ({{KWTAB_STMT}}), Routine `STMT_TAB[n]` ({{STMT_TAB}}) |
| `81h, …` / `82h, …` | Präfixe für zwei leere Erweiterungstabellen (`KWTAB_EXT81` {{KWTAB_EXT81}}, `KWTAB_EXT82` {{KWTAB_EXT82}}) |
| `83h+n` | Eintrag n der zusammenhängenden Tabelle `KWTAB_OPS` ({{KWTAB_OPS}}) + `KWTAB_FUNC` ({{KWTAB_FUNC}}) + `KWTAB_MATH` ({{KWTAB_MATH}}) |
| `9Dh` | **`USING`** – in SB-6511 ein freier Platz |
| sonst | Zahlen, Variablennamen und Zeichen bleiben ASCII |

Alle Token-Nummern sind dieselben wie bei SB-6511. In `KWTAB_STMT` sind die Plätze 75 bis 80
(bei SB-6511 GP-IB- und RS-232C-Befehle bis Nr. 99) frei; die Tabelle hat 81 statt 100
Einträge, `STMT_TAB` endet bei `XOPEN` (Nr. 73). Freie Plätze stehen in der Tabelle als FFh und
führen zu Fehler 1. Ein SB-6511-Programm mit GP-IB-Befehlen läuft daher nicht; umgekehrt kann
SB-6511 `USING` nicht darstellen.

Das Handbuch weist auf eine Folge unterschiedlicher Token-Nummern hin: Wandelt man Programme des
Double-Precision-BASIC SP-6115 (Kassettenversion) mit dem Text Converter MZ-80T10C um, wird aus
`PRINT USING` der Text `PRINT ERL`; man muss `ERL` von Hand wieder in `USING` ändern.

## CRUNCH und LISTLINE

| Routine | Adresse | Aufgabe |
|---------|--------:|---------|
| `CRUNCH` | {{CRUNCH}} | Eingabezeile in `INBUF` tokenisieren, Ergebnis in `TOKLINE` |
| `KWSEARCH` | {{KWSEARCH}} | Schlüsselwort in einer Tabelle suchen (Leerzeichen werden überlesen) |
| `COPYCHR` | {{COPYCHR}} | Zeichen übernehmen, Strings unverändert |
| `LISTLINE` | {{LISTLINE}} | Programmzeile wieder in Klartext wandeln (LIST, Fehlermeldungen) |

Die Eigenheiten sind dieselben wie bei SB-6511: Schlüsselwörter werden auch mitten in Namen erkannt
(`TOTAL` = `TO` + `TAL`), Leerzeichen innerhalb eines Schlüsselworts verschwinden, `?` wird zu
`PRINT`, und hinter `REM`, `DATA` und `DEF KEY(` bleibt der Text bis zum nächsten `:` unverändert.
`USING` wird wie jedes andere Einzelbyte-Token erkannt; ausgewertet wird es nur von `PRINT`
([PRINT USING](printusing.html)).

## Programmzeilen

Im Speicher beginnt das Programm bei `PRGTXT` ({{PRGTXT}}). Jede Zeile hat die Form

    [Link 2 Bytes][Zeilennummer 2 Bytes][Tokentext ... 0Dh]

und das Programm endet mit `00h 00h`. Im Speicher ist der Link absolut, in der Datei (Typ BTX)
relativ zur Zeile; `RELINK` ({{RELINK}}) und `UNLINK` ({{UNLINK}}) rechnen um. Beim Laden ist das
Dateiformat gleich dem von SB-6511, nur die Ladeadresse im MZF-Kopf ist 68DDh statt 725Ch.
Programme ohne `USING` und ohne GP-IB-/RS-Befehle sind deshalb zwischen beiden BASICs austauschbar.

### Zeilen eingeben

`BAS_DIRECT` führt eine Zeile ohne Nummer sofort aus. Mit Nummer springt es nach `BD_EDIT`
({{BD_EDIT}}): `READ` zurücksetzen, `CONT` sperren, mit `FINDLINE` ({{FINDLINE}}) eine
vorhandene Zeile suchen und löschen (`EDIT_DEL`), dann die neue einfügen (Platz schaffen,
Bereiche verschieben, Links korrigieren). Eine Zeile, die nur aus der Nummer besteht, löscht.
Bei SB-6511 stand dieser Ablauf in der Routine `EDITLINE`.

## DELETE: Programmzeilen löschen

`DELETE` hat in SB-6610 zwei Bedeutungen. `ST_DELLINES` ({{ST_DELLINES}}) prüft das erste Zeichen:
Ist es eine Ziffer oder `-`, werden Programmzeilen gelöscht, sonst geht es zu `ST_DELETE`
({{ST_DELETE}}), das wie bei SB-6511 eine Datei löscht.

| Eingabe | Wirkung (laut Handbuch 2.4.2, im Emulator geprüft) |
|---------|--------------------------------------------------|
| `DELETE 10` | Zeile 10 |
| `DELETE 10-` | ab Zeile 10 bis zum Ende |
| `DELETE -10` | vom Anfang bis Zeile 10 |
| `DELETE 10-50` | Zeilen 10 bis 50 |
| `DELETE "NAME"` | Datei löschen (wie SB-6511) |

Ablauf: Grenzen nach `DEL_FROM`/`DEL_TO` (a > b: Fehler 1), ohne Programm nichts tun
(`DL_CHKPRG`), die erste Zeile ≥ a suchen (`DL_FINDA`), hinter die letzte Zeile ≤ b laufen
(`DL_FINDB`) und den Bereich dazwischen mit `EDIT_DELMEM` entfernen; dabei werden die folgenden
Bereiche nachgezogen und die Links neu berechnet.

## Werkzeug

`tools/sb6511tok.py` bildet CRUNCH und LISTLINE nach. Mit `--basic 6610` benutzt es die Tabellen
von SB-6610 (mit `USING`, ohne GP-IB/RS) und die Ladeadresse 68DDh:

    python3 tools/sb6511tok.py --basic 6610 tok  PROG.BAS -o PROG.MZF
    python3 tools/sb6511tok.py --basic 6610 detok PROG.MZF -o PROG.BAS

`make test` vergleicht die Nachbildung im Emulator mit dem Original (334 feste und zufällige Zeilen,
alle identisch). Beim Auslesen von Disketten (`tools/sbdisk.py`) werden Programme, die Token 9Dh
enthalten, automatisch als SB-6610-Programme gelistet; auf den vorhandenen Disketten benutzt
allerdings keines `PRINT USING`.

# Ändern und Verschieben

## Die Quelle wird erzeugt

`sb4515/SB4515.asm` ist nicht von Hand geschrieben, sondern wird von `tools/dis4515.py` aus
`PASCAL.OBJ` und der Konfiguration `sb4515/sb4515_cfg.py` erzeugt (`make sb4515-src`). Die
Konfiguration enthält:

| Eintrag | Inhalt |
|---------|--------|
| `ENTRIES`, `TABLES`, `INLINE`, `DATA` | Einsprünge, Sprungtabellen, Daten hinter Aufrufen, Datenbereiche |
| `NAMES`, `ROUTINES` | Namen; `ROUTINES` zusätzlich die Beschreibung, die als Kommentarblock erscheint |
| `COMMENTS`, `BLOCKS` | Zeilenkommentare und Abschnittsköpfe |
| `IMM_NUM` | Befehle, deren 16-Bit-Wert eine Zahl und keine Adresse ist |
| `ERR_TEXT`, `KEYWORD_NOTES` | Fehlertexte und Kurzbeschreibungen der Schlüsselwörter |

Wer Namen oder Kommentare ändern will, ändert die Konfiguration und erzeugt die Quelle neu;
`make check` bestätigt danach, dass das Abbild bytegleich bleibt. Der Generator meldet doppelte
Namen und Namen, die mit dem Monitor kollidieren.

Für **inhaltliche Änderungen** am Interpreter (Fehler beheben, Befehle ergänzen) ist es
einfacher, die erzeugte Quelle als Ausgangspunkt zu nehmen, sie unter neuem Namen weiterzuführen
und den Generator nicht mehr zu benutzen.

## Verschiebbarkeit

Im Interpreterteil stehen alle Adressen als Symbole: Sprungziele, Tabellen, Puffer, die
Startwerte selbstmodifizierter Befehle (`SM_…`) und die Zeiger in Datenbereichen. Echte Zahlen,
die zufällig wie Adressen aussehen, sind ausgenommen und begründet (`IMM_NUM`,
`sb4515/reloc_allow.txt`), z. B. 2710h = 10000, 4000h = „bis zum Ende“, 42EDh = die Befehlsbytes
`SBC HL,BC`.

`make reloc-check` fügt an sieben Stellen (`PAS_START`, `TOKENIZE`, `SYN_EXPR`, `PRT_OUT`,
`FP2STR`, `FSIN`, `RUN_START`) je 16 Bytes ein, vergleicht das Ergebnis mit dem Original
(`tools/reloccheck.py`) und lässt jede verschobene Fassung den vollständigen Programmlauf im
Emulator bestehen. Damit kann man Code einfügen, ohne Adressen von Hand nachzuziehen.

### Was fest bleibt

| Stelle | Grund |
|--------|-------|
| Monitor 0000h–129Fh | eigene Quelle, Adressen durch den MZ-80B und die Programme vorgegeben |
| `LD BC,1300h` in `RUN_FKEY` | Ende des Bereichs der Funktionstastentexte (FARE 1200h–12FFh) |
| Grafik-RAM E000h, VRAM D000h | Hardware |
| `TXT_START` | Programmtext beginnt direkt hinter dem Interpreter; wächst der Code, wird weniger Speicher frei |

Die Startdaten `FKEY_DEF` und `PAS_INIT` liegen am Anfang des Programmbereichs und werden vom
ersten Programm überschrieben. Neue Startdaten gehören ebenfalls dorthin oder müssen vor
`TXT_START` liegen.

## Bekannte Schwächen des Originals

| Stelle | Befund |
|--------|--------|
| `FATN` | ARCTAN nur auf etwa 5 Stellen genau (0.78540579 statt 0.78539816) |
| `SYN_WRITEX` | `BOOLEAN` lässt sich nicht ausgeben |
| `SYN_RDIV` | `/` ohne automatische Umwandlung von INTEGER |
| Fehlerbehandlung | ein Laufzeitfehler schließt eine offene Datendatei nicht ab |

## MZF-Datei bauen

`make sb4515/SB4515.mzf` erzeugt aus `build/SB4515.bin` die Kassettendatei (`tools/mkmzf.py`):
Attribut 01h, Name „PASCAL SB-4515“, Laden und Start bei 0000h. Für eine geänderte Fassung:

```
make sb4515-src                 # nur wenn die Konfiguration geändert wurde
make build/SB4515.bin
python3 tools/mkmzf.py build/SB4515.bin neu.mzf --name "PASCAL NEU" --load 0000 --exec 0000
```

`make check` vergleicht die Daten der MZF-Datei mit `PASCAL.OBJ`; für eine geänderte Fassung
entfällt dieser Vergleich natürlich.

;==============================================================================
;  SHARP MZ-80B  –  Disk BASIC SB-6511 mit Monitor SB-1510
;  Variante mit RS-232C-Erweiterung (Befehle RSMODE / RSO / RSI)
;==============================================================================
;  Quelle : Disk_Basic6511ipl.mzf
;           MZF-Header: Attribut 01h (Maschinenprogramm), Name "Disk Basic",
;           Länge 7E00h, Ladeadresse 0000h, Startadresse 0000h.
;           Das Image wird vom IPL nach 8000h geladen und läuft nach dem
;           "Normal Start" (NST) ab 0000h im RAM.
;
;  Reassemblierbar mit pasmo; ergibt bytegleich die 7E00h Bytes des Images
;  (ohne den 128-Byte-MZF-Header).
;  Ab BAS_COLD (1222h) ist die Quelle verschiebbar: alle Adressen im Abbild
;  stehen als Label, Code und Tabellen dürfen wachsen (make reloc-check).
;  Grenze: der Code muss vor 6900h enden (RS-232C-Puffer, Prüfung vor FILL_FREE).
;  Der Monitor (0000h-1221h) benutzt feste Adressen und bleibt, wo er ist.
;
;  Speicheraufteilung des Images
;  -----------------------------
;    0000h-003Ah  Sprungvektoren RST 00h-38h, dazwischen Monitor-Variablen
;    003Bh-06A3h  Monitor SB-1510: Init, Kommandoschleife (J M D L S V),
;                 Kassettenroutinen, Hex-Ein-/Ausgabe, Meldungen
;    06A4h-0D47h  Bildschirmeditor, Zeichenausgabe, Tastatur, Steuerzeichen,
;                 40/80-Zeichen-Umschaltung, RST-38h-Registeranzeige
;    0D48h-0DF7h  Tastaturtabellen
;    0DF8h-1038h  Timer, Piepton, MUSIC-Interpreter mit Notentabellen
;    103Fh-1221h  Arbeitsspeicher des Monitors (Puffer, Kassetten-Header ...)
;    1222h-13FFh  BASIC: Kaltstart, Hauptschleife, Meldungstexte
;    1407h-14D9h  Fehlereinsprünge ERR_01..ERR_70 (LD A,n / DEFB 01h-Trick)
;    14DAh-1691h  Fehlerbehandlung, Tokenizer (CRUNCH), Zeilenausgabe (LIST)
;    1692h-1901h  Schlüsselworttabellen
;    1902h-1CFCh  Hilfsroutinen: Textzeiger, Syntaxprüfung, Zeilenverwaltung
;    1CFDh-1E64h  Interpreterschleife und Anweisungs-Sprungtabelle STMT_TAB
;    1E65h-2E42h  Anweisungen (LIST, RUN, LET, FOR ...), Ausdrucksauswertung,
;                 String-Funktionen, Funktionstabelle FUNC_TAB
;    2E43h-3C35h  Gleitkomma-Arithmetik und mathematische Funktionen
;    3C36h-4177h  PRINT / INPUT mit Geräteverteilung
;    4178h-5C07h  Datei-Befehle (Kassette/Diskette), Drucker, Grafik, CONSOLE
;    5C08h-5EEEh  Floppy-Treiber (MB8876)
;    5EEFh-6560h  GP-IB (IEEE-488)-Erweiterung, Ports C0h-C5h
;    6561h-65FFh  unbenutzt: Kopie von 560Bh-56A9h (Rest eines älteren Standes)
;    6600h-68ABh  RS-232C-Erweiterung (Z80-SIO, Ports B0h-B3h)
;    68ACh-6FFFh  FFh-Füllung
;    7000h-7DFFh  BFh-Füllung (im Betrieb Variablenbereich des BASIC)
;
;  Laufzeit-RAM (nicht im Image): 6900h/6A00h RS-232C-Ringpuffer,
;  ab 6B00h Arbeitsbereich des BASIC (siehe EQUs unten), ab 725Ch Programm.
;
;  Token-Format
;  ------------
;  Anweisungen sind zwei Bytes: 80h, 80h+n   (n = Index in STMT_TAB)
;  Operatoren und Funktionen sind ein Byte: 83h+n, wobei KWTAB_OPS,
;  KWTAB_FUNC und KWTAB_MATH ohne Trenner eine Tabelle bilden
;  (83h-8Bh Vergleiche, 8Ch-9Dh frei, 9Eh TO, 9Fh STEP, A0h-B3h LEFT$( .. POS,
;  C0h-CBh RND( .. SQR(). Auswertung über FUNC_TAB.
;  81h/82h, n: Präfixe für die leeren Tabellen bei 1835h/1837h.
;  Eine Befehlsreferenz erzeugt tools/mkref.py (docs/BEFEHLE.md).
;  In den Schlüsselworttabellen ist das letzte Zeichen jedes Wortes mit
;  Bit 7 markiert, FFh ist ein freier Platz (zählt als Nummer).
;
;  Programmtricks, die im Listing auftauchen
;  -----------------------------------------
;  - Inline-Parameter: Mehrere Routinen lesen Daten hinter dem CALL und
;    kehren dahinter zurück, z.B.
;        CALL SYNCHK      / DEFB zeichen          (Syntaxprüfung)
;        CALL CHK_CHR_ALT / DEFB zeichen / DEFW ziel  (sonst Sprung nach ziel)
;        CALL MUL16 / FINDLINE / ... / DEFW fehler    (Fehlerziel)
;        CALL DIR_SCAN / DEFW handler
;  - DEFB 01h vor "LD A,n" (= LD BC,nn) überspringt den nächsten Befehl;
;    so entsteht die Kette der Fehlereinsprünge ERR_01..ERR_70.
;  - Viel selbstmodifizierender Code: "LD (Lxxxx+1),A" ändert Operanden.
;
;  Was die Kommentare leisten
;  --------------------------
;  Das Listing ist vollständig disassembliert. Code und Daten sind getrennt,
;  Tabellen sind aufgelöst. Alle Routinen und Daten tragen Namen aus der
;  Analyse; übrig sind nur Marken der Form Dxxxx an Inline-Parametern
;  (DEFB/DEFW direkt hinter einem CALL). Jeder Teil hat Kommentarblöcke zu
;  Ein-/Ausgaben und Ablauf; Fehlernummern stehen bei ERR_01..ERR_70,
;  Arbeitsbereiche als EQU am Dateianfang. "??" markiert Bytes, die von
;  keinem gefundenen Codepfad verwendet werden (meist Arbeitsspeicher oder
;  Puffer). Wo eine Deutung nur erschlossen ist, sagt der Kommentar das.
;  I/O-Ports nach MAME (sharp/mz2000.cpp) und eigener Analyse; die
;  GP-IB-Register C0h-C5h sind nur aus dem Code erschlossen.
;==============================================================================

SIO_AD    EQU    0B0h    ; Z80-SIO Kanal A Daten (RS-232C)
SIO_AC    EQU    0B1h    ; Z80-SIO Kanal A Steuerung
SIO_BD    EQU    0B2h    ; Z80-SIO Kanal B Daten
SIO_BC    EQU    0B3h    ; Z80-SIO Kanal B Steuerung
GP_C0     EQU    0C0h    ; GP-IB-Karte: PIO Port A, Statuseingänge (Handshake, Bit 2 SRQ, Bit 4 EOI)
GP_C1     EQU    0C1h    ; GP-IB-Karte: PIO Port B, Steuerleitungen (Bit 0 REN, 1 IFC, 2 SRQ, 3 ATN)
GP_C2     EQU    0C2h    ; GP-IB-Karte: PIO Port A Steuerung
GP_C3     EQU    0C3h    ; GP-IB-Karte: PIO Port B Steuerung
GP_C4     EQU    0C4h    ; GP-IB-Karte: Datenbyte (senden/empfangen)
GP_C5     EQU    0C5h    ; GP-IB-Karte: Betriebsart der Schnittstelle (Kopie in GP_C5COPY)
FDC_CMD   EQU    0D8h    ; FDC MB8876 Kommando/Status (invertiert)
FDC_TRK   EQU    0D9h    ; FDC Spurregister
FDC_SEC   EQU    0DAh    ; FDC Sektorregister
FDC_DAT   EQU    0DBh    ; FDC Datenregister
FDD_SEL   EQU    0DCh    ; Floppy: Laufwerk/Motor
FDD_SID   EQU    0DDh    ; Floppy: Seitenwahl
PPI_A     EQU    0E0h    ; 8255 Port A (Kassette, Video)
PPI_B     EQU    0E1h    ; 8255 Port B (Kassette, BREAK, VBLANK)
PPI_C     EQU    0E2h    ; 8255 Port C
PPI_CTL   EQU    0E3h    ; 8255 Steuerwort
PIT_C0    EQU    0E4h    ; 8253 PIT Zähler 0
PIT_C1    EQU    0E5h    ; 8253 PIT Zähler 1
PIT_C2    EQU    0E6h    ; 8253 PIT Zähler 2
PIT_CTL   EQU    0E7h    ; 8253 PIT Steuerwort
PIO_AD    EQU    0E8h    ; Z80-PIO Port A Daten (Tastaturzeile, VRAM)
PIO_AC    EQU    0E9h    ; Z80-PIO Port A Steuerung
PIO_BD    EQU    0EAh    ; Z80-PIO Port B Daten (Tastatur)
PIO_BC    EQU    0EBh    ; Z80-PIO Port B Steuerung
TMR_F0    EQU    0F0h    ; Timer/Ton F0
TMR_F1    EQU    0F1h    ; Timer/Ton F1
TMR_F2    EQU    0F2h    ; Timer/Ton F2
TMR_F3    EQU    0F3h    ; Timer/Ton F3
GRPH      EQU    0F4h    ; Grafik-VRAM Bank/Maske
EXT_AH    EQU    0F8h    ; externe Karte Adresse H
EXT_AL    EQU    0F9h    ; externe Karte Adresse L / Daten
PRN_CTL   EQU    0FEh    ; Drucker Steuerung/Status
PRN_DAT   EQU    0FFh    ; Drucker Daten

; Monitor-Variablen in den Lücken zwischen den RST-Vektoren (Auswahl)
MV_NOTELEN EQU   0005h   ; MUSIC: zuletzt angegebene Notenlänge (0-9)
MV_PM     EQU    000Fh   ; Uhr: 0 vormittags, 1 nachmittags
MV_TISTART EQU   0016h   ; Uhr: beim Stellen angegebene Sekunden (0-43199)
MV_TEMPO  EQU    001Dh   ; MUSIC: Tempofaktor = 8 - TEMPO
MV_C2LATCH EQU   001Eh   ; Uhr: zuletzt gelesener Stand von Zähler 2
MV_PERIOD EQU    0036h   ; MUSIC: Halbperiode des aktuellen Tons (0 = Pause)

INBUF     EQU    6B0Dh   ; Eingabe-/Zeilenpuffer
TOKLINE   EQU    6C0Eh   ; CRUNCH-Ergebnis als Programmzeile: Link (2), ...
TOKLNUM   EQU    6C10h   ; ... Zeilennummer (2, 0 = Direktmodus) und ...
TOKTEXT   EQU    6C12h   ; ... Tokentext bis 0Dh
MEMTOP    EQU    6B08h   ; oberes RAM-Ende (vom RAM-Test bei 1237h ermittelt)
STKTOP    EQU    6B0Ah   ; Anfangswert des Stackpointers
TAPEBUF   EQU    6ED3h   ; Kassettendatei (ROPEN/WOPEN /T): Puffer für einen 256-Byte-Block
TAPEBUF_END EQU  6FD3h   ; ... Ende des Puffers
FC_IDX    EQU    6FD3h   ; aktuelle Datei: Index 0-9 in FILETAB, danach Kopie des Eintrags:
FILE_NO   EQU    6FD4h   ; Gerät/Datei: 1-127 = #n, 80h Bildschirm, 81h DATA (READ),
                         ; 82h Drucker (/P), 83h Kassette (/T)
FC_MODE   EQU    6FD5h   ; Dateimodus: 0 lesen, 1 schreiben, 2 Sätze zu 32 Bytes ((n))
FC_TYPE   EQU    6FD6h   ; Dateityp/-gerät (Index für DEV_DISPATCH: +10)
FC_UNIT   EQU    6FD7h   ; Laufwerk/Einheit (Puffer über 7064h + 2*n)
FC_VOL    EQU    6FD8h   ; Volumennummer der Diskette (@n bzw. aus dem Verzeichnis)
FC_ENTRY  EQU    6FDDh   ; Zeiger auf den Eintrag in FILETAB
FC_UNITBUF EQU   6FDFh   ; Puffer der Einheit (UNIT_GETBUF)
FC_B00    EQU    6FE1h   ; Zeiger in den Dateipuffer (320 Bytes, Bereich 7050h + 2*Index):
FC_B14    EQU    6FE3h   ; ... +14h
FC_B1E    EQU    6FE5h   ; ... +1Eh
FC_B20    EQU    6FE7h   ; ... +20h
FC_B40    EQU    6FE9h   ; ... +40h (Sektorpuffer)
FC_B13E   EQU    6FEBh   ; ... +13Eh (Ende des Sektorpuffers, Folgesektor)
FILETAB   EQU    6FF2h   ; Dateitabelle: 10 Einträge zu 9 Bytes, Byte 0 = Dateinummer
PRGEND    EQU    704Eh   ; Ende des Programms (hinter 00h 00h) = Beginn der Variablen;
                         ; erster Eintrag der Bereichszeiger 704Eh-7095h (siehe AREAS_INIT)
P_DEFFN   EQU    7084h   ; Bereichszeiger: DEF FN (Name, Parameter, Text bis 0Dh)
P_ARRAYS  EQU    7086h   ; Bereichszeiger Felder: +0 Zahl 2-dim., +2 Zahl 1-dim.,
                         ; +6 String 2-dim., +8 String 1-dim. (siehe ARR_FIND)
P_NUMVAR  EQU    708Ah   ; Bereichszeiger: Zahlvariablen (Name 2 + Wert 5 Bytes)
P_STRVAR  EQU    7090h   ; Bereichszeiger: Stringvariablen (Name 2, Länge, Text, 0Dh)
P_STRTMP  EQU    7092h   ; Bereichszeiger: String-Zwischenergebnisse (STR_NEW)
VALSP     EQU    7094h   ; Zeiger auf den Werte-/Ausdrucksstack (5-Byte-Einträge)
FNPAR_SP  EQU    7096h   ; FN: gesicherte Parameter, 6 Bytes je Ebene, wächst abwärts
FNPAR_END EQU    709Ch   ; ... bis hierher (5 Ebenen ab 70BAh), sonst Fehler 12
FOR_SP    EQU    7098h   ; FOR-Stack: 19 Bytes je Eintrag (Kopie von FOR_VAR..TXTPTR),
                         ; wächst abwärts ab 71D7h, max. 15 Einträge
GOSUB_SP  EQU    709Ah   ; GOSUB-Stack: 7 Bytes je Eintrag (CURLINE, TXTPTR, FOR_CNT),
                         ; wächst abwärts ab 7240h, max. 15 Einträge
FOR_VAR   EQU    7240h   ; FOR-Eintrag im Aufbau: Adresse der Laufvariablen (2),
FOR_STEP  EQU    7242h   ; ... Schrittweite (5),
FOR_STEPSGN EQU  7247h   ; ... Vorzeichenbyte der Schrittweite (1),
FOR_LIMIT EQU    7248h   ; ... Endwert (5); danach CURLINE (4) und TXTPTR (2)
CURLINE   EQU    724Dh   ; aktuelle Programmzeile: Link (2) + Zeilennummer (2)
CURLNUM   EQU    724Fh   ; aktuelle Zeilennummer, 0 = Direktmodus
TXTPTR    EQU    7251h   ; Textzeiger des Interpreters
FOR_CNT   EQU    7253h   ; Anzahl FOR-Einträge der aktuellen GOSUB-Ebene
FOR_DEPTH EQU    7254h   ; Anzahl FOR-Einträge insgesamt
GOSUB_DEPTH EQU  7255h   ; GOSUB-Tiefe
ONERR_FLAG EQU   7256h   ; ON ERROR: 0 aus, 1 aktiv, 2 im Fehlerbehandler (RESUME erlaubt)
ONERR_LINE EQU   7257h   ; ON ERROR GOTO: Zeilennummer des Behandlers
DATA_FLAG EQU    7259h   ; READ: 1 = DATA_PTR zeigt in eine DATA-Zeile, 0 = neu suchen
DATA_PTR  EQU    725Ah   ; READ: nächstes Element in der aktuellen DATA-Anweisung
PRGTXT    EQU    725Ch   ; Beginn des BASIC-Programmtextes
IPL_DRIVE EQU    7FECh   ; vom IPL hinterlassene Laufwerksnummer (FFECh vor dem NST)

        ORG     0000h


; ==============================================================================
;  MONITOR SB-1510
; ==============================================================================
;  RST-Vektoren. Zwischen den JP-Befehlen liegen Monitor-Variablen
;  (Cursorgrenzen, Zeiger, Prüfsummen ...). RST 08h springt auf 0000h,
;  RST 10h-30h auf den Monitor-Warmstart, RST 38h auf die Register-
;  anzeige RST38_DUMP. 002Bh/0033h: Prüfsumme bzw. Start/Ende bei
;  den Monitor-Kommandos.
MON_RESET:
        JP      MON_INIT
;  Variablen in den Lücken (Auswahl, aus der Verwendung):
;    0003h/0004h GETLINE: VRAM-Adresse des Cursors   0005h Notenlänge
;    0006h/0007h zuletzt gedrückte Taste (Zeile/Spalte)
;    000Bh/000Ch Rollbereich erste/letzte Zeile        000Dh/000Eh Zeichen unter
;    dem Cursor / angezeigtes Zeichen (Blinken)        000Fh Uhr nachmittags
;    0013h/0014h VRAM-Adresse des Rollbereichs         0015h <> 0: kein Tastenklick
;    0016h/0017h Uhr: Startsekunden   001Bh/001Ch Länge des Rollbereichs
;    001Dh Tempo  001Eh/001Fh Zählerstand 2  0023h "00" (für Taste 1Ah)
;    002Bh/002Ch Startadresse bzw. Prüfsumme  002Eh/002Fh SP in GETLINE
;    0033h/0034h Endadresse bzw. Prüfsumme    0035h Zähler Tastenwiederholung
;    0036h/0037h Halbperiode des Tons
MV_03:  DEFB    00h,00h,00h,00h,00h
        JP      MON_RESET
MV_0B:  DEFB    01h,18h,00h,00h,00h
        JP      MON_WARM
MV_13:  DEFB    00h,0D0h,00h,00h,00h
        JP      MON_WARM
MV_1B:  DEFB    80h,07h,00h,00h,00h
        JP      MON_WARM
MV_23:  DEFB    30h,30h,0Dh,00h,00h
        JP      MON_WARM
MV_2B:  DEFB    00h,00h,00h,00h,00h
        JP      MON_WARM
MV_33:  DEFB    00h,00h,40h,00h,00h
        JP      RST38_DUMP

; ------------------------------------------------------------------------------
;  MON_INIT – I/O-Bausteine über IOINIT_TAB programmieren
;  Tabelle aus Paaren (Wert, Port); Ende nach dem Wert FFh.
;  8255 PC1=1, 8253 Zähler 0-2, PIO A Bit-Modus/Ausgang,
;  PIO B Bit-Modus/Eingang.
; ------------------------------------------------------------------------------
MON_INIT:
        LD      HL,IOINIT_TAB           ; HL -> Tabelle (Wert, Port)
MI_LOOP:
        LD      A,(HL)
        INC     HL
MI_NEXT:
        LD      C,(HL)
        INC     HL
        OUT     (C),A                   ; Wert an Port
        INC     A                       ; Ende nach Wert FFh
        JR      NZ,MI_LOOP
        JR      MON_COLD
;  IOINIT_TAB: Paare (Wert, Port), Ende nach Wert FFh; das 00h dahinter
;  füllt bis zum NMI-Vektor 0066h. Die Bytes hinter "JP MON_INIT" (0069h)
;  werden von keinem gefundenen Codepfad erreicht.
IOINIT_TAB:
        DEFB    02h,0E3h,34h,0E7h,74h,0E7h,0B4h,0E7h
        DEFB    00h,0E6h,00h,0E6h,02h,0E5h,00h,0E5h
        DEFB    02h,0E4h,00h,0E4h,0CFh,0E9h,00h,0E9h
        DEFB    0CFh,0EBh,0FFh,0EBh,00h

; ------------------------------------------------------------------------------
;  NMI-Vektor (0066h) -> Neustart
; ------------------------------------------------------------------------------
        JP      MON_INIT
        OUT     (PIO_BC),A
        LD      A,0FFh
        OUT     (PIO_BC),A

; ------------------------------------------------------------------------------
;  MON_COLD – Kaltstart: Stack, 40-Zeichen-Modus, Kassette stoppen,
;  Arbeitsspeicher löschen, Meldung "** MONITOR SB-1510 **",
;  IM 2, dann direkt ins BASIC (MON_GOBASIC).
; ------------------------------------------------------------------------------
MON_COLD:
        LD      HL,1801h                ; 000Bh/000Ch = 01h/18h: Zeilen 1..24 (Rollbereich)
        LD      (000Bh),HL
        LD      SP,10C0h                ; Monitor-Stack
        CALL    SET40COL                ; 40-Zeichen-Modus einstellen
        LD      B,2Fh
        LD      HL,PPI_A_COPY           ; Arbeitsbereich löschen, PA-Kopie = 12h
MC_CLRWORK:
        LD      A,12h
        LD      (HL),A
        OUT     (PPI_A),A               ; Kassette: Ruhezustand
        INC     HL
        CALL    CLRMEM
        LD      A,0Dh                   ; PC6 = 1
        OUT     (PPI_CTL),A
        LD      B,0A0h
        CALL    FILLMEM
        LD      HL,FKEY_DEFEND
        LD      (FKEY_END),HL
        LD      A,04h
        LD      (MV_TEMPO),A
        INC     A
        LD      (MV_NOTELEN),A
        LD      DE,MSG_MONITOR          ; "** MONITOR SB-1510 **"
        CALL    MSGX
        IM      2                       ; Interrupt-Modus 2
        LD      A,0FFh
        LD      (0015h),A
MON_GOBASIC:
        JP      BAS_COLD                ; Monitor -> BASIC

; ------------------------------------------------------------------------------
;  MON_WARM – Monitor-Kommandoschleife
;  Prompt "*", Eingabezeile lesen, Kommandobuchstabe über MON_CMDTAB:
;    J adr  Sprung      M adr  Speicher ändern   D s e  Dump
;    L      Laden       S      Sichern           V      Vergleichen
; ------------------------------------------------------------------------------
MON_WARM:
        LD      A,0Dh
        OUT     (PPI_CTL),A
        LD      SP,10C0h
        CALL    CRLF_IF
        LD      A,2Ah                   ; Prompt "*"
        CALL    PRTCHR
        LD      DE,MON_BUF
        LD      A,28h                   ; Eingabezeile max. 40 Zeichen
        LD      (GL_MAXLEN),A
MON_CMDIN:
        CALL    GETLINE
        LD      A,(DE)
        CP      2Ah                     ; Zeile muss mit "*" beginnen
        JR      NZ,MON_WARM
        INC     DE
        LD      A,(DE)
        LD      HL,MON_CMDTAB           ; Kommando in MON_CMDTAB suchen
        LD      B,06h
;  MON_CMDSRCH – Kommandobuchstaben in MON_CMDTAB suchen (6 Einträge zu
;  3 Bytes: Zeichen, Adresse), sonst neue Eingabe.
MON_CMDSRCH:
        CP      (HL)
        JR      Z,MON_CMDJMP
        INC     HL
        INC     HL
        INC     HL
        DJNZ    MON_CMDSRCH
        JR      MON_WARM
MON_CMDJMP:
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        JP      (HL)                    ; Kommando ausführen
MON_CMDTAB:
        DEFB    4Ah                     ; 'J'
        DEFW    CMD_J
        DEFB    4Dh                     ; 'M'
        DEFW    CMD_M
        DEFB    44h                     ; 'D'
        DEFW    CMD_D
        DEFB    4Ch                     ; 'L'
        DEFW    CMD_L
        DEFB    53h                     ; 'S'
        DEFW    CMD_S
        DEFB    56h                     ; 'V'
        DEFW    CMD_V
;  *M adr – Speicher ändern: Adresse und Inhalt zeigen, neuen Wert (2 Hex-
;  ziffern) eingeben; leere Eingabe = nächste Adresse, ungültig = neue
;  Adresse. BREAK (Shift+BREAK, 0Bh) beendet.
CMD_M:  LD      A,4Dh                   ; 'M'
        CALL    IN_HEXADR
CMDM_START:
        DEC     HL
CMDM_NEXT:
        INC     HL
CMDM_SHOW:
        CALL    PRTADR
CMDM_BYTE:
        LD      A,(HL)
        CALL    PRTHEX
        CALL    PRTSPC
        LD      DE,MON_BUF
        CALL    GETLINE_MON
        LD      DE,MON_MIN
        LD      A,(DE)
        CP      0Dh
        JR      Z,CMDM_NEXT
CMDM_SET:
        CALL    HEX2
        JR      C,CMD_M
        LD      (HL),A
        JR      CMDM_NEXT
;  *D – Speicher ab Startadresse bis Endadresse hexadezimal ausgeben, 8
;  (40 Zeichen) bzw. 16 Bytes je Zeile (CMDD_PERLINE wird von SET40COL/
;  SET80COL gesetzt); BREAK beendet, Taste mit Code FDh hält an.
CMD_D:  CALL    IN_START
CMDD_END:
        CALL    IN_END
        EX      DE,HL
        LD      HL,(002Bh)
CMDD_LINE:
        CALL    PRTADR
CMDD_PERLINE:
        LD      B,10h
CMDD_BYTE:
        CALL    PRTSPC
        LD      A,(HL)
        CALL    PRTHEX
        PUSH    HL
        XOR     A
        SBC     HL,DE
        POP     HL
CMDD_DONE:
        JP      Z,MON_WARM
        CALL    BRKCHK
        JR      Z,CMDD_DONE
CMDD_HOLD:
        IN      A,(PIO_BD)
        CP      0FDh
        JR      Z,CMDD_HOLD
        INC     HL
        DJNZ    CMDD_BYTE
        JR      CMDD_LINE
;  *S – Programm auf Kassette sichern: Dateiname, Start-, End- und
;  Ausführungsadresse abfragen (Kopf Typ 1). *L laden (Name optional, Start
;  an der Startadresse), *V vergleichen. TAPEMODE: 2 sichern, 1 laden,
;  0 vergleichen.
CMD_S:  LD      A,02h
TAPECMD:
        LD      (TAPEMODE),A
        LD      HL,MSG_FNAME
        LD      DE,MON_BUF
        LD      BC,000Bh
        PUSH    DE
        LDIR
        EX      DE,HL
        LD      B,11h
        LD      A,0Dh
        CALL    FILLMEM
        POP     DE
        CALL    MSGX
        CALL    GETLINE_MON
        LD      A,(TAPEMODE)
        CP      02h
        JP      NZ,CMDL_SEARCH
        LD      DE,CMT_HEADER
        LD      A,01h
        LD      (DE),A
        INC     DE
        LD      HL,MON_NAMEIN
        LD      BC,0010h
        LDIR
        LD      A,0Dh
        LD      (DE),A
CMDS_RANGE:
        CALL    IN_START
        LD      (CMT_HLOAD),HL
        CALL    IN_END
        LD      DE,(002Bh)
        XOR     A
        SBC     HL,DE
        JR      C,CMDS_RANGE
        LD      (CMT_HSIZE),HL
        LD      HL,MON_WARM
        LD      (CMT_HEXEC),HL
        LD      A,4Ah                   ; 'J'
        LD      (ASK_ADR+1),A
CMDS_EXEC:
        CALL    ASK_ADR
        JR      Z,CMDS_WRITE
        CALL    HEX4
        JR      C,CMDS_EXEC
        LD      (CMT_HEXEC),HL
CMDS_WRITE:
        CALL    WRHEAD
        JR      C,MON_RETURN
        CALL    WRDATA
MON_RETURN:
        JP      MON_WARM
MSG_FNAME:
        DEFB    "FILE NAME:",0Dh
CMD_L:  LD      A,01h
CMDV_GO:
        JR      TAPECMD
CMDL_SEARCH:
        LD      HL,MON_NAMEIN
        LD      A,(HL)
        CP      0Dh
        PUSH    AF
        CALL    RDHEAD
        JR      C,MON_RETURN
        POP     AF
        CALL    NZ,CMDL_FOUND
        JR      NZ,CMDL_SEARCH
        LD      A,(TAPEMODE)
        DEC     A
        JR      NZ,CMDV_VERIFY
        LD      DE,MSG_LOADING
        CALL    MSG_NAME
        CALL    RDDATA
        JR      C,MON_RETURN
        LD      HL,(CMT_HEXEC)
        JP      (HL)
; <- aufgerufen von 01DCh
CMDL_FOUND:
        LD      DE,MSG_FOUND
        CALL    MSG_NAME
CMDL_CMPNAME:
        LD      DE,MON_NAMEIN
        LD      HL,CMT_HNAME
        LD      B,10h
CMDL_CMP:
        CALL    CMPNAME
        RET     Z
        CALL    CMT_REWIND
        CALL    CMT_STOP
        JR      C,MON_RETURN
        CALL    DLY_SHORT
        POP     BC
        JR      CMDL_SEARCH
TAPEMODE:
        DEFB    00h                     ; ?? |.|
CMD_V:  XOR     A
        JR      CMDV_GO
CMDV_VERIFY:
        LD      DE,MSG_VERIFY
        CALL    MSG_NAME
        CALL    VFDATA
        JR      C,MON_RETURN
        LD      DE,MSG_OK
        CALL    MSGX
        JR      MON_RETURN
MSG_LOADING:
        DEFB    "LOADING ",0Dh
MSG_VERIFY:
        DEFB    "VERIFYING ",0Dh
MSG_FOUND:
        DEFB    "FOUND ",0Dh
MSG_OK: DEFB    4Fh,4Bh,0Dh             ; ?? |OK.|
CMD_J:  LD      A,4Ah                   ; 'J'
        CALL    IN_HEXADR
        JP      (HL)

; ------------------------------------------------------------------------------
;  Kassetten-Grundroutinen
;  D-Register = Modus: 01h Header schreiben, 02h Daten schreiben,
;  04h Header lesen, 08h Daten lesen/vergleichen.
;  Header: 128 Byte ab CMT_HEADER (10C0h), Daten: Länge/Adresse aus
;  CMT_HSIZE/CMT_HLOAD. Jeder Block wird zweimal geschrieben.
; ------------------------------------------------------------------------------
;  Kassettenformat: Bit 1 = langer Puls, Bit 0 = kurzer Puls (Port C Bit 7
;  über Bit-Set/Reset). Byte = Startbit 1 + 8 Bits (höchstes zuerst).
;  Prüfsumme = Anzahl der 1-Bits (16 Bit), nach den Daten gesendet. Jeder
;  Block wird zweimal geschrieben, dazwischen 256 Null-Bits. Davor eine
;  Bandmarke (WRGAP_TM): Kopf 10000 Nullen, 40 Einsen, 40 Nullen, 1;
;  Daten 11000 Nullen, 20 Einsen, 20 Nullen, 1.
;  WRHEAD/WRDATA/RDHEAD/RDDATA/VFDATA: D = Art (01h/02h/04h/08h), Kopf
;  128 Bytes ab CMT_HEADER, Daten nach CMT_HSIZE/CMT_HLOAD. C bei Fehler
;  oder BREAK.
; <- aufgerufen von 01B5h, 516Ch, 5243h
WRHEAD: DI
        LD      D,01h
        LD      HL,CMT_HEADER
        LD      BC,0080h
CMT_WRITE:
        CALL    CKSUM
        CALL    CMT_READY
        JR      C,CMT_ABORT
        BIT     0,D
        JR      Z,CMT_WRBLK
        PUSH    DE
        LD      DE,MSG_WRITING
CMT_WRMSG:
        CALL    MSG_NAME
        POP     DE
        CALL    DLY_LONG
CMT_WRBLK:
        CALL    WRGAP_TM
        CALL    WRBLK
        JR      C,CMT_ABORT
        BIT     1,D
        CALL    NZ,DLY_LONG
        JR      NZ,CMT_ABORT
        EI
        RET
; <- aufgerufen von 01BAh, 5175h, 519Ch, 52C7h, 52D7h
WRDATA: DI
        LD      D,02h
        LD      BC,(CMT_HSIZE)
        LD      HL,(CMT_HLOAD)
        JR      CMT_WRITE
; <- aufgerufen von 01D6h, 5028h, 5276h
RDHEAD: DI
        LD      D,04h
        LD      HL,CMT_HEADER
        LD      BC,0080h
CMT_READ:
        CALL    CMT_READY
        JR      C,CMT_ABORT
        CALL    RDTMARK
        JR      C,CMT_ABORT
        CALL    RDBLK
CMT_RDDONE:
        JR      C,CMT_ABORT
        BIT     3,D
        JR      Z,CMT_EI_RET
        CALL    CMT_REWIND
CMT_ABORT:
        CALL    CMT_STOP
CMT_EI_RET:
        EI
        RET
; <- aufgerufen von 01EDh, 5075h, 50EAh, 51D7h
RDDATA: DI
        LD      D,08h
        LD      BC,(CMT_HSIZE)
        LD      HL,(CMT_HLOAD)
        JR      CMT_READ
; <- aufgerufen von 0220h, 4FFDh
VFDATA: DI
        LD      D,08h
        LD      BC,(CMT_HSIZE)
        LD      HL,(CMT_HLOAD)
        CALL    CKSUM
        CALL    CMT_READY
        JR      C,CMT_ABORT
        CALL    RDTMARK
        JR      C,CMT_ABORT
        CALL    VFBLK
        JR      CMT_RDDONE
; <- aufgerufen von 0274h
WRBLK:  LD      E,02h
WRBLK_COPY:
        PUSH    BC
        PUSH    HL
WRBLK_BYTE:
        LD      A,(HL)
        CALL    WRBYTE
        CALL    BRKKEY
        JR      C,BLK_RET
        INC     HL
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,WRBLK_BYTE
        LD      HL,(002Bh)
        LD      A,H
        CALL    WRBYTE
        LD      A,L
        CALL    WRBYTE
        CALL    WR1BIT
        DEC     E
        JR      NZ,WRBLK_GAP
        XOR     A
BLK_RET:
        POP     HL
        POP     BC
        RET
WRBLK_GAP:
        CALL    WR0BIT
        DJNZ    WRBLK_GAP
        POP     HL
        POP     BC
        JR      WRBLK_COPY
;  RDBLK – Block lesen, bei Prüfsummenfehler die zweite Kopie versuchen;
;  beide falsch: "CHECK SUM ERROR", A = FFh, C.
; <- aufgerufen von 02A1h
RDBLK:  LD      E,02h
        PUSH    BC
        PUSH    HL
RDBLK_SYNC:
        CALL    EDGE
        JR      C,BLK_RET
        CALL    DLY_BIT
        IN      A,(PPI_B)
        AND     40h
        JR      Z,RDBLK_SYNC
        LD      HL,0000h
        LD      (002Bh),HL
        POP     HL
        POP     BC
        PUSH    BC
        PUSH    HL
RDBLK_BYTE:
        CALL    RDBYTE
        JR      C,BLK_RET
        LD      (HL),A
        INC     HL
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,RDBLK_BYTE
        LD      HL,(002Bh)
        CALL    RDBYTE
        JR      C,BLK_RET
        LD      C,A
        CALL    RDBYTE
        JR      C,BLK_RET
        CP      L
        JR      NZ,RDBLK_RETRY
        LD      A,C
        CP      H
        LD      A,00h
        JR      Z,BLK_RET
RDBLK_RETRY:
        DEC     E
        JR      NZ,RDBLK_SYNC
CMT_CKERR:
        LD      DE,MSG_CKSUM
        CALL    MSGX
        LD      A,0FFh
        SCF
        JR      BLK_RET
; <- aufgerufen von 02D5h
VFBLK:  LD      E,02h
VFBLK_COPY:
        PUSH    BC
        PUSH    HL
VFBLK_SYNC:
        CALL    EDGE
        JR      C,BLK_RET
        CALL    DLY_BIT
        IN      A,(PPI_B)
        AND     40h
        JR      Z,VFBLK_SYNC
VFBLK_BYTE:
        CALL    RDBYTE
        JR      C,BLK_RET
        CP      (HL)
        JR      NZ,CMT_CKERR
        INC     HL
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,VFBLK_BYTE
        LD      HL,(0033h)
        CALL    RDBYTE
        CP      H
        JR      NZ,CMT_CKERR
        CALL    RDBYTE
        CP      L
        JR      NZ,CMT_CKERR
        DEC     E
        JP      Z,BLK_RET
        POP     HL
        POP     BC
        JR      VFBLK_COPY
; <- aufgerufen von 02DFh, 02F1h, 02F5h
WRBYTE: PUSH    BC
        LD      B,08h
        CALL    WR1BIT
WRBYTE_BIT:
        RLCA
        CALL    C,WR1BIT
        CALL    NC,WR0BIT
        DJNZ    WRBYTE_BIT
        POP     BC
        RET
;  RDBYTE – ein Byte lesen: je Bit Flanke abwarten, nach DLY_BIT den Pegel
;  prüfen (1 = langer Puls), 1-Bits für die Prüfsumme zählen (002Bh).
; <- aufgerufen von 0327h, 0336h, 033Ch, 036Ah, 037Bh, 0381h
RDBYTE: PUSH    HL
        LD      HL,0800h
RDBYTE_BIT:
        CALL    EDGE
        JR      C,RDBYTE_RET
        CALL    DLY_BIT
        IN      A,(PPI_B)
        AND     40h
        JR      Z,RDBYTE_SHIFT
        PUSH    HL
        LD      HL,(002Bh)
        INC     HL
        LD      (002Bh),HL
        POP     HL
        SCF
RDBYTE_SHIFT:
        RL      L
        DEC     H
        JR      NZ,RDBYTE_BIT
        CALL    EDGE
        LD      A,L
RDBYTE_RET:
        POP     HL
        RET
; <- aufgerufen von 0271h
WRGAP_TM:
        PUSH    BC
        PUSH    HL
        LD      BC,2AF8h
        LD      HL,1414h
        BIT     1,D
        JR      NZ,GAP_ZEROS
        LD      BC,2710h
        ADD     HL,HL
GAP_ZEROS:
        CALL    WR0BIT
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,GAP_ZEROS
GAP_ONES:
        CALL    WR1BIT
        DEC     H
        JR      NZ,GAP_ONES
GAP_ZEROS2:
        CALL    WR0BIT
GAP_ZEROS2N:
        DEC     L
        JR      NZ,GAP_ZEROS2
        CALL    WR1BIT
POP_HL_BC_RET:
        POP     HL
        POP     BC
GAP_RET:
        RET
;  RDTMARK – Bandmarke suchen: 40 (Kopf) bzw. 20 (Daten) Einsen in Folge,
;  dann ebenso viele Nullen.
; <- aufgerufen von 029Ch, 02D0h
RDTMARK:
        PUSH    HL
        LD      L,14h
        BIT     3,D
        JR      NZ,TMARK_ONES
        RLC     L
TMARK_ONES:
        LD      H,L
TMARK_ONES_LP:
        CALL    EDGE
        JR      C,TMARK_RET
TMARK_ONESBIT:
        CALL    DLY_BIT
        IN      A,(PPI_B)
        AND     40h
        JR      Z,TMARK_ONES
        DEC     H
        JR      NZ,TMARK_ONES_LP
        LD      H,L
TMARK_ZEROS:
        CALL    EDGE
        JR      C,TMARK_RET
        CALL    DLY_BIT
        IN      A,(PPI_B)
        AND     40h
        JR      NZ,TMARK_ONES
        DEC     H
        JR      NZ,TMARK_ZEROS
        CALL    EDGE
TMARK_RET:
        POP     HL
        RET
;  CKSUM – Anzahl der 1-Bits von BC Bytes ab HL nach 002Bh und 0033h.
; <- aufgerufen von 025Ah, 02C8h
CKSUM:  PUSH    BC
        PUSH    HL
        PUSH    DE
        LD      DE,0000h
CKSUM_LP:
        LD      A,B
        OR      C
        JR      NZ,CKSUM_BYTE
        EX      DE,HL
        LD      (002Bh),HL
        LD      (0033h),HL
        POP     DE
        JR      POP_HL_BC_RET
CKSUM_BYTE:
        LD      A,(HL)
        PUSH    BC
        LD      B,08h
CKSUM_BIT:
        RLCA
        JR      NC,CKSUM_NEXT
        INC     DE
CKSUM_NEXT:
        DJNZ    CKSUM_BIT
        POP     BC
        INC     HL
        DEC     BC
        JR      CKSUM_LP

; ------------------------------------------------------------------------------
;  EDGE – auf steigende Flanke des Bandsignals warten, CY = BREAK
; ------------------------------------------------------------------------------
;  EDGE – auf eine Flanke des Lesesignals (PPI Port B Bit 6) warten;
;  C = BREAK gedrückt.
; <- aufgerufen von 030Fh, 035Ch, 03A4h, 03C1h, 03FBh, 040Dh, 041Eh
EDGE:   IN      A,(PPI_B)
        CPL
        RLCA
        RET     C
        RLCA
        JR      NC,EDGE
EDGE_LOW:
        IN      A,(PPI_B)
        CPL
        RLCA
        RET     C
        RLCA
        JR      C,EDGE_LOW
        RET

; ------------------------------------------------------------------------------
;  CMT_READY – Kassette bereit? Sonst "SET TAPE" und Fach öffnen;
;  beim Schreiben Schreibschutz prüfen ("WRITE PROTECT"), dann PLAY.
; ------------------------------------------------------------------------------
;  Laufwerk: PPI Port A Bit 0 REW, 1 FF, 2 PLAY, 3 STOP (Flanke 0->1 über
;  PPIA_OUT mit PPI_A_COPY), Port C über Bit-Set/Reset: Bit 4 Fach
;  öffnen (CMT_EJECT), Bit 5 wird vor PLAY/REW gepulst (CMT_PREPULSE),
;  Bit 6 Aufnahme. Port B Bit 4: Schreibschutz, Bit 5: keine Kassette.
; <- aufgerufen von 025Dh, 0297h, 02CBh
CMT_READY:
        CALL    KEYROW3
        IN      A,(PPI_B)
        AND     20h
        JR      Z,CMTR_WPCHK
        PUSH    DE
        LD      DE,MSG_SETTAPE
        CALL    MSGX
        POP     DE
        CALL    CMT_EJECT
CMTR_WAIT:
        CALL    BRKKEY
        RET     C
        IN      A,(PPI_B)
        AND     20h
        JR      NZ,CMTR_WAIT
        CALL    DLY_MID
CMTR_WPCHK:
        LD      A,03h
        AND     D
        JR      Z,CMTR_PLAY
        IN      A,(PPI_B)
        AND     10h
        JR      Z,CMTR_REC
        PUSH    DE
        LD      DE,MSG_WPROT
        CALL    MSGX
        POP     DE
        SCF
; <- aufgerufen von 0468h, 4FD8h
CMT_EJECT:
        LD      A,08h
        OUT     (PPI_CTL),A
        CALL    DLY_MID
        INC     A
        OUT     (PPI_CTL),A
        RET
CMTR_REC:
        LD      A,0Ch
        OUT     (PPI_CTL),A
CMTR_PLAY:
        LD      A,D
        AND     05h
        CALL    NZ,CMT_STOPCMD
        CALL    CMT_PREPULSE
        LD      A,(PPI_A_COPY)
        SET     2,A
        JR      CMT_SETCMD
        DEFB    00h                     ; ?? |.|
; <- aufgerufen von 04E3h
PPC_PULSE:
        OUT     (PPI_CTL),A
        JP      DLY_SHORT
; <- aufgerufen von 0208h, 02AAh, 501Dh, 52E4h
CMT_REWIND:
        CALL    CMT_STOP
        CALL    DLY_SHORT
        CALL    CMT_REWCMD
        CALL    DLY_SHORT
REW_WAIT:
        LD      BC,01A6h
REW_WAIT_LP:
        IN      A,(PPI_B)
        CPL
        RLCA
        RET     C
        RLCA
        JR      NC,REW_WAIT
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,REW_WAIT_LP
        RET
; <- aufgerufen von 020Bh, 02ADh, 04B1h, 5020h, 50F3h, 50F9h, 524Fh, 5296h (+1 weitere)
CMT_STOP:
        LD      A,0Dh
        OUT     (PPI_CTL),A
; <- aufgerufen von 049Eh
CMT_STOPCMD:
        LD      A,(PPI_A_COPY)
        SET     3,A
CMT_SETCMD:
        CALL    PPIA_OUT
; <- aufgerufen von 04ECh, 04F2h
CMT_IDLE:
        LD      A,(PPI_A_COPY)
; <- aufgerufen von 04D7h, 4FB9h
PPIA_OUT:
        OUT     (PPI_A),A
        JR      DLY_SHORT
; <- aufgerufen von 04A1h, 04EFh
CMT_PREPULSE:
        LD      A,0Bh
        CALL    PPC_PULSE
        DEC     A
        JR      PPC_PULSE
; <- aufgerufen von 04B7h, 4FC5h
CMT_REWCMD:
        CALL    KEYROW3
        CALL    CMT_IDLE
; <- aufgerufen von 4FBCh
CMT_FASTCMD:
        CALL    CMT_PREPULSE
        CALL    CMT_IDLE
        SET     0,A
        JR      CMT_SETCMD
;  DLY_LONG / DLY_SHORT / DLY_MID – Wartezeiten über DLY_BC (BC Durchläufe
;  zu 256). DLY_A: A Durchläufe; WR0BIT/WR1BIT/DLY_BIT setzen den Wert
;  vorher in den Operanden von DLY_A.
; <- aufgerufen von 026Eh, 027Bh
DLY_LONG:
        LD      A,0Eh
        OUT     (PPI_CTL),A
        CALL    DLY_LONG2
; <- aufgerufen von 04FDh
DLY_LONG2:
        PUSH    BC
        LD      BC,0F2Bh
DLY_BC: PUSH    AF
DLY_BC_LP:
        XOR     A
DLY_BC_IN:
        DEC     A
        JR      NZ,DLY_BC_IN
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,DLY_BC_LP
        POP     AF
        POP     BC
        RET
; <- aufgerufen von 0210h, 04B4h, 04BAh, 5025h
DLY_SHORT:
        PUSH    BC
        LD      BC,0123h
        JR      DLY_BC
; <- aufgerufen von 0475h, 0490h
DLY_MID:
        PUSH    BC
        LD      BC,0796h
        JR      DLY_BC
; <- aufgerufen von 0302h, 0399h, 03D7h, 03E5h
WR0BIT: PUSH    AF
        LD      A,0Fh
        OUT     (PPI_CTL),A
        LD      A,(BC)
        LD      A,2Ah                   ; '*'
        LD      (DLY_A+1),A
        CALL    DLY_A
        LD      A,0Eh
        OUT     (PPI_CTL),A
        LD      A,25h                   ; '%'
        LD      (DLY_A+1),A
        CALL    DLY_A
        POP     AF
        RET
; <- aufgerufen von 02F8h, 0392h, 0396h, 03DFh, 03EBh
WR1BIT: PUSH    AF
        LD      A,0Fh
        OUT     (PPI_CTL),A
        LD      A,5Ah                   ; 'Z'
        LD      (DLY_A+1),A
        CALL    DLY_A
        LD      A,0Eh
        OUT     (PPI_CTL),A
        LD      A,55h                   ; 'U'
        LD      (DLY_A+1),A
        CALL    DLY_A
        POP     AF
        RET
; <- aufgerufen von 0314h, 0361h, 03A9h, 0400h, 0412h
DLY_BIT:
        LD      A,H
        LD      A,L
        LD      A,41h                   ; 'A'
        LD      (DLY_A+1),A
; <- aufgerufen von 0528h, 0534h, 0543h, 054Fh
DLY_A:  LD      A,0FFh
DLY_A_LP:
        DEC     A
        JP      NZ,DLY_A_LP
        RET

; ------------------------------------------------------------------------------
;  BRKCHK – BREAK-Taste abfragen: Z = gedrückt
; ------------------------------------------------------------------------------
; <- aufgerufen von 013Eh, 1D41h, 1EFDh, 55B5h, 55F9h, 6527h, 67BFh, 67DFh
BRKCHK: CALL    KEYROW3
        IN      A,(PIO_BD)
        IN      A,(PIO_BD)
        AND     80h
        RET
; <- aufgerufen von 02E2h, 046Bh, 0FE0h, 4FDBh
BRKKEY: IN      A,(PIO_BD)
        CPL
        RLCA
        RET
; <- aufgerufen von 0457h, 04E9h, 0562h, 0FDDh, 4FCAh
KEYROW3:
        IN      A,(PIO_AD)
        AND     0E0h
        OR      13h
        OUT     (PIO_AD),A
        RET
;  IN_START / IN_END – Start- bzw. Endadresse abfragen (Prompt "S"/"E",
;  "-ADR.$"), nach 002Bh bzw. 0033h. IN_HEXADR: Adresse mit Prompt A.
; <- aufgerufen von 0120h, 0188h
IN_START:
        LD      A,53h                   ; 'S'
        CALL    IN_HEXADR
        LD      (002Bh),HL
        RET
; <- aufgerufen von 0123h, 018Eh
IN_END: LD      A,45h                   ; 'E'
        CALL    IN_HEXADR
        LD      (0033h),HL
        RET
; <- aufgerufen von 00FBh, 024Dh, 057Ch, 0585h
IN_HEXADR:
        LD      (ASK_ADR+1),A
ASKADR_RETRY:
        CALL    ASK_ADR
        CALL    HEX4
        JR      C,ASKADR_RETRY
        RET
; <- aufgerufen von 01A8h, 058Fh
ASK_ADR:
        LD      A,0FFh
        LD      DE,MON_BUF
        LD      (DE),A
        PUSH    DE
        INC     DE
        LD      HL,MSG_ADR
        LD      BC,0007h
        LDIR
        POP     DE
        CALL    MSGX
        CALL    GETLINE_MON
        LD      DE,MON_ADRIN
        LD      A,(DE)
        CP      0Dh
        RET

; ------------------------------------------------------------------------------
;  Hex-Ein-/Ausgabe und Meldungsausgabe
; ------------------------------------------------------------------------------
; <- aufgerufen von 00A4h, 0168h, 0228h, 0350h, 0464h, 0487h, 05A9h, 05CFh (+8 weitere)
MSGX:   CALL    CRLF_IF
        JP      PRTSTR
; <- aufgerufen von 0100h, 012Ah
PRTADR: CALL    CRLF_IF
        CALL    PRTHL
        JP      PRTSPC
; <- aufgerufen von 010Dh, 016Bh, 05ACh
GETLINE_MON:
        CALL    GETLINE
        LD      A,(DE)
        CP      0Bh
        JP      Z,MON_WARM
        RET
; <- aufgerufen von 01EAh, 01F9h, 021Dh, 026Ah
MSG_NAME:
        CALL    MSGX
        LD      DE,CMT_HNAME
        JP      PRTSTR
; <- aufgerufen von 05BFh, 0D38h, 0D42h
PRTHL:  LD      A,H
        CALL    PRTHEX
        LD      A,L
; <- aufgerufen von 0104h, 0133h, 05D9h
PRTHEX: PUSH    AF
        AND     0F0h
        RRCA
        RRCA
        RRCA
        RRCA
        CALL    NIB2ASC
        CALL    PRTCHR
        POP     AF
        AND     0Fh
        CALL    NIB2ASC
        JP      PRTCHR
; <- aufgerufen von 05E4h, 05EDh, 2DF6h
NIB2ASC:
        AND     0Fh
        ADD     A,30h
        CP      3Ah                     ; ':'
        RET     C
        ADD     A,07h
        RET
; <- aufgerufen von 0626h, 0632h
ASC2NIB:
        CP      47h                     ; 'G'
        JR      NC,A2N_ERR
        CP      41h                     ; 'A'
        JR      NC,A2N_LETTER
        CP      3Ah                     ; ':'
        JR      NC,A2N_ERR
        CP      30h                     ; '0'
        RET     C
        SUB     30h
        RET
A2N_LETTER:
        SUB     37h
        RET
A2N_ERR:
        SCF
        RET
;  HEX4 / HEX2 – 4 bzw. 2 Hexziffern ab (DE) nach HL bzw. A; C bei
;  ungültiger Ziffer. ASC2NIB: ein Zeichen. NIB2ASC: umgekehrt.
; <- aufgerufen von 01ADh, 0592h
HEX4:   PUSH    DE
        CALL    HEX2
        JR      C,HEX4_RET
        LD      H,A
        CALL    HEX2
        JR      C,HEX4_RET
        LD      L,A
HEX4_RET:
        POP     DE
        RET
; <- aufgerufen von 0118h, 0615h, 061Bh
HEX2:   PUSH    BC
        LD      A,(DE)
        INC     DE
        CALL    ASC2NIB
        JR      C,HEX2_RET
        RLCA
        RLCA
        RLCA
        RLCA
        LD      C,A
        LD      A,(DE)
        INC     DE
        CALL    ASC2NIB
        JR      C,HEX2_RET
        OR      C
HEX2_RET:
        POP     BC
        RET
;  CMPNAME – B Zeichen ab DE und HL vergleichen, bis 0Dh. Z = gleich.
; <- aufgerufen von 0204h
CMPNAME:
        PUSH    BC
        PUSH    DE
        PUSH    HL
CMPNAME_LP:
        LD      A,(DE)
        CP      (HL)
        JR      NZ,CMPNAME_RET
        DJNZ    CMPNAME_NEXT
CMPNAME_RET:
        POP     HL
        POP     DE
        POP     BC
        RET
CMPNAME_NEXT:
        CP      0Dh
        JR      Z,CMPNAME_RET
        INC     DE
        INC     HL
        JR      CMPNAME_LP
;  CLRMEM / FILLMEM – B Bytes ab HL mit 0 bzw. A füllen.
; <- aufgerufen von 0086h, 0B79h
CLRMEM: XOR     A
; <- aufgerufen von 008Fh, 0164h
FILLMEM:
        LD      (HL),A
        INC     HL
        DJNZ    FILLMEM
        RET

; ------------------------------------------------------------------------------
;  Meldungstexte des Monitors (mit 0Dh abgeschlossen)
; ------------------------------------------------------------------------------
MSG_MONITOR:
        DEFB    "** MONITOR SB-1510 **",0Dh
MSG_ADR:
        DEFB    "-ADR.$",0Dh
MSG_SETTAPE:
        DEFB    "SET TAPE",0Dh
MSG_WRITING:
        DEFB    "WRITING ",0Dh
MSG_WPROT:
        DEFB    "WRITE PROTECT",0Dh
MSG_CKSUM:
        DEFB    "CHECK SUM ERROR",0Dh
;  GL_MAXLEN: höchste Eingabelänge (BASIC setzt FAh), GL_LEFT: noch erlaubte
;  Zeichen der laufenden Eingabe.
GL_MAXLEN:
        DEFB    00h                     ; ?? |.|
GL_LEFT:
        DEFB    00h                     ; ?? |.|

; ==============================================================================
;  BILDSCHIRMEDITOR UND ZEICHENAUSGABE
; ==============================================================================
;  GETLINE: Zeile mit Cursor-Editor einlesen (Ergebnis ab DE, Ende 0Dh)
; <- aufgerufen von 00C8h, 05C5h, 12DDh, 3FD1h
GETLINE:
        PUSH    AF
        PUSH    BC
        PUSH    HL
        PUSH    DE
        LD      A,(GL_MAXLEN)
        LD      (GL_LEFT),A
;  Ablauf von GETLINE: Zeichen unter dem Cursor merken, Cursor (1Fh)
;  blinken lassen, bis eine Taste kommt (KEYSCAN). Tasten 01h-04h
;  (Cursor) wiederholen sich bei langem Drücken (Zähler 0035h).
;  Druckbare Zeichen werden geschrieben (im Grafikmodus bzw. bei PPI_A_COPY
;  Bit 7 mit Bit 7 = invers), Steuerzeichen über DISPCTRL ausgeführt.
;  CR: logische Zeile ab dem Bildschirm einsammeln (GL_ENTER), 0Bh (BREAK):
;  0Bh, 0Dh zurückgeben. 10h-19h: Funktionstaste (Text aus FKEY_TAB, 7Fh
;  im Text = CR), 1Bh: Tabulator (TABSTOPS).
GL_NEWPOS:
        CALL    CSR2VRAM
        LD      (0003h),HL
        CALL    VRAM_RD
        LD      (000Dh),A
        LD      (000Eh),A
        LD      (002Eh),SP
        LD      HL,(0003h)
GL_BLINK:
        LD      A,(000Eh)
        CP      1Fh
        JR      NZ,GL_CURSORCH
        LD      A,(000Dh)
GL_BLINKSET:
        LD      (000Eh),A
        CALL    VRAM_WR
        JR      GL_WAITKEY
GL_CURSORCH:
        LD      A,1Fh
        JR      GL_BLINKSET
GL_WAITKEY:
        PUSH    AF
        PUSH    HL
        LD      BC,0040h
GL_WAITLP:
        PUSH    BC
;  GL_KEYCALL: "CALL KEYSCAN"; RS_TERM (RS-232C) patcht hier fälschlich das
;  Opcode-Byte (06E0h) statt des Operanden.
GL_KEYCALL:
        CALL    KEYSCAN
        CP      1Eh
        JR      NZ,GL_KEY
        POP     BC
        DEC     BC
        LD      A,C
        OR      B
        JR      NZ,GL_WAITLP
        POP     HL
        POP     AF
        JR      GL_BLINK
GL_KEY: PUSH    AF
        CP      01h
        JR      C,GL_PRESS
        CP      05h
        JR      NC,GL_PRESS
        BIT     2,B
        JR      Z,GL_PRESS
        XOR     A
        LD      (0006h),A
        LD      (0007h),A
        LD      A,78h                   ; 'x'
        LD      (KEY_STATE3),A
        LD      A,(0035h)
        DEC     A
        LD      (0035h),A
        JR      Z,GL_REPRESET
        POP     AF
        CALL    GETKEY
        CP      01h
        JR      C,GL_REPEAT
        CP      05h
        JR      C,GL_KEY
GL_REPEAT:
        CALL    GL_RESTCH
        JR      GL_CONT
GL_REPRESET:
        LD      A,40h                   ; '@'
        LD      (0035h),A
GL_PRESS:
        CALL    GL_RESTCH
        POP     AF
        LD      C,A
        LD      A,(0015h)
        OR      A
        CALL    Z,BEEP
        LD      A,C
        AND     0F0h
        CP      20h                     ; ' '
        JR      C,GL_CTRL
        LD      A,C
        BIT     3,B
        JR      NZ,GL_GRAPHCHK
        LD      HL,PPI_A_COPY
        BIT     7,(HL)
        JR      Z,GL_PUTCH
GL_GRAPHCHK:
        LD      A,(0007h)
        AND     0Fh
        CP      03h
        LD      A,C
        JR      C,GL_PUTCH
        OR      80h
GL_PUTCH:
        LD      C,A
        LD      A,(GL_LEFT)
        DEC     A
        LD      (GL_LEFT),A
        JR      Z,GL_ENTER
        LD      A,C
        CALL    PUTCH_VRAM
GL_CONT:
        LD      HL,GL_NEWPOS
        LD      SP,(002Eh)
        PUSH    HL
        RET
GL_CTRL:
        BIT     4,A
        LD      A,C
        JP      NZ,GL_SPECIAL
        CP      0Dh
        JR      Z,GL_ENTER
        CP      0Bh
        JR      Z,GL_BREAK
        CALL    DISPCTRL
        JR      GL_CONT
GL_BREAK:
        LD      SP,(002Eh)
        POP     HL
        PUSH    HL
        LD      (HL),0Bh
        INC     HL
        LD      (HL),0Dh
GL_DONE:
        CALL    CRLF
        POP     DE
        POP     HL
        POP     BC
        POP     AF
        RET
;  KEY_NONE – keine Taste: Zustand merken, A = 1Eh.
KEY_NONE:
        LD      HL,KEY_MODS
        LD      (HL),A
        JP      KEY_CLRSTATE
;  GL_ENTER – Anfang der logischen Zeile über LINE_TAB suchen, alle ihre
;  Bildschirmzeilen nach (DE) kopieren, 00h als Leerzeichen, Leerzeichen
;  am Ende entfernen, 0Dh anhängen.
GL_ENTER:
        LD      HL,(CSR_XY)
        LD      E,H
GL_ENT_ROW:
        LD      BC,0028h
        CALL    LINE_FLAG
        EX      DE,HL
        LD      HL,(CSR_XY)
        JR      NZ,GL_ENT_UP
GL_ENT_NEXT:
        INC     DE
        LD      A,(DE)
        OR      A
        JR      Z,GL_ENT_COPY
GL_ENT_WIDTH:
        LD      A,28h                   ; '('
        ADD     A,C
        LD      C,A
        JR      GL_ENT_NEXT
;  LINE_UP – Zeile zurück und eine Zeilenbreite addieren. ADD_WIDTH:
;  C += Zeilenbreite; der Operand (28h/50h) wird von SET40COL/SET80COL
;  gesetzt und ist auch die Grenze für CURSOR.
; <- aufgerufen von 07C2h, 07C5h
LINE_UP:
        DEC     H
ADD_WIDTH:
        LD      A,28h                   ; '('
        ADD     A,C
        LD      C,A
        RET
GL_ENT_UP:
        DEC     H
        DEC     DE
        DEC     A
        JP      Z,GL_ENT_NEXT
        JR      GL_ENT_UP
        DEFB    07h                     ; ?? |.|
        CALL    LINE_UP
        CALL    LINE_UP
;  Die Bytes davor (07h, 2 x CALL LINE_UP) werden von keinem gefundenen
;  Codepfad erreicht.
GL_ENT_COPY:
        LD      L,00h
        CALL    XY2VRAM
        LD      SP,(002Eh)
        POP     DE
        PUSH    DE
        PUSH    BC
        CALL    VRAM_LDIR
        POP     BC
        POP     HL
        PUSH    HL
        LD      B,C
GL_ENT_CONV:
        LD      A,(HL)
        OR      A
        CALL    Z,GL_ZERO2SP
        LD      (HL),A
        INC     HL
        DJNZ    GL_ENT_CONV
GL_ENT_TRIM:
        LD      (HL),0Dh
        DEC     HL
        LD      A,(HL)
        CP      20h                     ; ' '
        JR      Z,GL_ENT_TRIM
        JR      GL_DONE
; <- aufgerufen von 07DDh
GL_ZERO2SP:
        LD      A,20h                   ; ' '
        RET
;  GL_SPECIAL – Zeichen 10h-1Fh: 1Bh Tabulator, 1Ah (GL_KEY1A), sonst
;  Funktionstaste 1-10 aus FKEY_TAB ausgeben.
GL_SPECIAL:
        CP      1Bh
        JR      Z,GL_TAB
        CP      1Ah
        JR      Z,GL_KEY1A
        AND     0Fh
        INC     A
        LD      B,A
        LD      HL,FKEY_TAB
GL_FKEY_SRCH:
        LD      D,H
        LD      E,L
GL_FKEY_SKIP:
        LD      A,L
        CP      20h                     ; ' '
        JR      Z,GL_FKEY_END
        LD      A,(HL)
        INC     HL
        CP      0Dh
        JR      NZ,GL_FKEY_SKIP
        DJNZ    GL_FKEY_SRCH
GL_FKEY_OUT:
        LD      A,(DE)
        CP      7Fh
        JP      Z,GL_ENTER
        CP      0Dh
GL_FKEY_END:
        JP      Z,GL_CONT
        LD      C,A
        CALL    PUTC
        INC     DE
        JR      GL_FKEY_OUT
GL_TAB: LD      A,03h
        CALL    DISPCTRL
        LD      A,(CSR_XY)
        OR      A
        JP      Z,GL_ENTER
        LD      HL,TABSTOPS
GL_TAB_NEXT:
        INC     HL
GL_TAB_MAX:
        LD      A,27h                   ; '''
        CP      (HL)
        JP      C,GL_ENTER
GL_TAB_MOVE:
        LD      A,(CSR_XY)
        SUB     (HL)
        JP      Z,GL_CONT
        JR      NC,GL_TAB_NEXT
        LD      A,03h
        CALL    DISPCTRL
        JR      GL_TAB_MOVE
GL_KEY1A:
        LD      A,(GL_LEFT)
        DEC     A
        JR      Z,GL_KEY1A_SET
        DEC     A
GL_KEY1A_SET:
        LD      (GL_LEFT),A
        JP      Z,GL_ENTER
        LD      DE,0023h
        CALL    PRTSTR
        JP      GL_CONT
; <- aufgerufen von 071Fh, 0729h
GL_RESTCH:
        LD      HL,(0003h)
        LD      A,(000Dh)
        JP      VRAM_WR
KEY_CLRSTATE:
        DEC     A
        LD      B,0Bh
KEY_CLR_LP:
        INC     HL
        LD      (HL),A
        DJNZ    KEY_CLR_LP
        LD      A,1Eh
        RET
        DEFB    00h                     ; ?? |.|
;  INKEY – GETKEY ohne Warten, keine Taste: A = 0 (für GET).
; <- aufgerufen von 2B9Bh
INKEY:  PUSH    BC
        PUSH    DE
        PUSH    HL
        CALL    GETKEY
        POP     HL
        POP     DE
        POP     BC
        CP      1Eh
        RET     NZ
        XOR     A
        RET
;  PUTCH_VRAM – Zeichen A an der Cursorposition in den Text-VRAM, am
;  Zeilenende die Fortsetzung in LINE_TAB vermerken (in 80 Zeichen wird
;  PUTCH_CONT über einen eingesetzten JR übersprungen), Cursor weiter.
; <- aufgerufen von 075Fh, 0907h
PUTCH_VRAM:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        CALL    CSR2VRAM
        CALL    VRAM_WR
        LD      HL,(CSR_XY)
        LD      A,L
PUTCH_EOL:
        CP      27h                     ; '''
        JR      NZ,PUTCH_RIGHT
        LD      E,H
        CALL    LINE_FLAG
        INC     HL
        LD      (HL),01h
        OR      A
        JR      Z,PUTCH_CONT2
PUTCH_CONT:
        LD      (HL),02h
        DEC     A
        JR      Z,PUTCH_CONT2
        LD      (HL),03h
        DEC     A
        JR      NZ,PUTCH_CONT3
PUTCH_CONT2:
        INC     HL
PUTCH_CONT3:
        LD      (HL),00h
PUTCH_RIGHT:
        JP      CTL_03

; ------------------------------------------------------------------------------
;  Zeichenausgabe: CRLF_IF, PRTSPC, PRTSTR (DE, bis 0Dh), PRTCHR (A)
; ------------------------------------------------------------------------------
;  CRLF_IF – Zeilenvorschub nur, wenn der Cursor nicht in Spalte 0 steht.
;  CRLF – immer. TABPOS – Leerzeichen bis zur nächsten durch 10 teilbaren
;  Spalte (PRINT ",").
; <- aufgerufen von 00B8h, 05B6h, 05BCh, 12ADh, 3FEEh, 481Eh
CRLF_IF:
        LD      A,(CSR_COL)
        OR      A
        RET     Z
; <- aufgerufen von 0789h, 1395h
CRLF:   XOR     A
        LD      (CSR_COL),A
        LD      A,0Dh
        JP      DISPCTRL
; <- aufgerufen von 0107h, 012Fh, 08BEh, 0D3Bh, 2DFCh
PRTSPC: LD      A,20h                   ; ' '
        JP      PRTCHR
TABPOS: CALL    PRTSPC
        LD      A,(CSR_COL)
        OR      A
        RET     Z
TABPOS_LP:
        SUB     0Ah
        JR      C,TABPOS
        JR      NZ,TABPOS_LP
        RET
; <- aufgerufen von 0857h, 12DAh, 130Eh, 1392h, 153Ah, 1F67h, 1F6Dh, 481Bh (+1 weitere)
PRTSTR: PUSH    AF
        PUSH    BC
        PUSH    DE
PRTSTR_LP:
        LD      A,(DE)
        CP      0Dh
        JR      Z,PRTSTR_RET
        CALL    PRTCHR_RAW
        INC     DE
        JR      PRTSTR_LP
; <- aufgerufen von 3FA5h
PRTSTR_RAW:
        PUSH    AF
        PUSH    BC
        PUSH    DE
PRTSTRR_LP:
        LD      A,(DE)
        CP      0Dh
        JR      Z,PRTSTR_RET
        LD      C,A
        CALL    PUTC
        INC     DE
        JR      PRTSTRR_LP
PRTSTR_RET:
        POP     DE
        POP     BC
        POP     AF
        RET
;  PUTC – Zeichen C ausgeben: unter 10h als Steuerzeichen (CSR_COL wird
;  angepasst), sonst PRTCHR_RAW. PRTCHR_RAW zählt CSR_COL (0-159).
; <- aufgerufen von 081Bh, 08E4h, 091Ch
PUTC:   LD      A,C
        AND     0F0h
        LD      A,C
        JR      NZ,PRTCHR_RAW
        CALL    DISPCTRL
        CP      03h
        JR      Z,PUTC_INCCOL
        CP      05h
        JR      Z,PUTC_COL0
        CP      06h
        RET     NZ
PUTC_COL0:
        XOR     A
PUTC_SETCOL:
        LD      (CSR_COL),A
        RET
; <- aufgerufen von 08D5h
PRTCHR_RAW:
        CALL    PUTCH_VRAM
PUTC_INCCOL:
        LD      A,(CSR_COL)
        INC     A
        CP      0A0h
        JR      C,PUTC_SETCOL
        SUB     0A0h
        JR      PUTC_SETCOL
; <- aufgerufen von 00BDh, 05E7h, 138Bh, 2DE9h, 2DF9h, 2E04h, 2E0Eh
PRTCHR: CP      0Dh
PRTCHR_CR:
        JR      Z,CRLF
        PUSH    BC
        LD      C,A
        CALL    PUTC
        LD      A,C
        POP     BC
        RET
;  SCROLL_INIT – aus dem Rollbereich (000Bh/000Ch = erste/letzte Zeile)
;  Startadresse (0013h) und Länge (001Bh) im VRAM berechnen, Bildschirm
;  löschen (Steuerzeichen 06h).
; <- aufgerufen von 0D10h
SCROLL_INIT:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      A,(000Bh)
        LD      B,A
        LD      C,A
SCR_TOPROW:
        LD      HL,0CFD8h
SCR_WIDTH1:
        LD      DE,0028h
SCR_TOP_LP:
        ADD     HL,DE
        DJNZ    SCR_TOP_LP
        LD      (0013h),HL
        LD      A,(000Ch)
        INC     A
        SUB     C
        LD      B,A
        LD      HL,0000h
SCR_LEN_LP:
        ADD     HL,DE
        DJNZ    SCR_LEN_LP
        LD      (001Bh),HL
        LD      A,06h
        CALL    DISPCTRL
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

; ------------------------------------------------------------------------------
;  GETKEY – Tastatur abfragen und in ASCII umsetzen
; ------------------------------------------------------------------------------
;  Tastaturmatrix: PIO Port A wählt die Zeile (Bit 0-3), Port B liefert die
;  Spalten (0 = gedrückt). KEY_STATE speichert je Zeile den letzten Stand,
;  damit nur neue Tasten zählen. KEY_MODS: Stand der Sondertasten (Zeile
;  mit SHIFT/CTRL/GRAPH ...). Ohne Taste: 1Eh. Umsetzung über KEYTAB_N
;  (normal), KEYTAB_S (Shift/klein) bzw. KEYTAB_G (Grafik) je nach
;  PPI_A_COPY Bit 5/6; einige Sondertasten liefern direkt 09h, 0Ah, 0Ch,
;  0Eh, 0Fh, 7Fh.
; <- aufgerufen von 0714h, 0874h, 688Eh
GETKEY: IN      A,(PIO_AD)
        AND     0F0h
        OR      1Bh
        LD      D,A
        OUT     (PIO_AD),A
        XOR     A
        LD      (0026h),A
        LD      (0027h),A
        IN      A,(PIO_BD)
        CPL
        LD      B,A
        LD      C,0EAh
KEY_ROWLP:
        DEC     C
        DEC     C
        DEC     D
        OUT     (C),D
        INC     C
        INC     C
        PUSH    DE
        LD      HL,KEY_STATE
        LD      A,D
        AND     0Fh
        LD      E,A
        LD      D,00h
        ADD     HL,DE
        IN      A,(C)
        LD      E,A
        CPL
        AND     (HL)
        LD      (HL),E
        POP     DE
        LD      E,A
        OR      A
        CALL    NZ,KEY_STORE
        LD      A,D
        AND     0Fh
        JR      NZ,KEY_ROWLP
        LD      DE,(0026h)
        LD      A,E
        OR      A
        JR      NZ,KEY_PRESSED
        LD      HL,KEY_MODS
        LD      A,B
        CP      (HL)
        JR      Z,KEY_RET1E
        LD      (HL),A
        LD      HL,PPI_A_COPY
        CP      01h
        JR      Z,KEY_CTRLB6
        CP      02h
        JR      Z,KEY_CTRLB5
        CP      03h
        JR      Z,KEY_RET7F
        CP      05h
        JR      Z,KEY_RET09
        CP      06h
        JR      Z,KEY_RET0A
        CP      08h
        JR      Z,KEY_CTRLB7
        CP      0Ch
        JR      NZ,KEY_RET1E
        LD      A,0Ch
        RET
KEY_CTRLB6:
        BIT     6,(HL)
        JR      Z,KEY_RET1E
KEY_RET0E:
        LD      A,0Eh
        RET
KEY_CTRLB5:
        BIT     5,(HL)
        JR      NZ,KEY_RET0E
KEY_RET1E:
        LD      A,1Eh
        RET
KEY_RET7F:
        LD      A,7Fh
        RET
KEY_RET09:
        LD      A,09h
        RET
KEY_RET0A:
        LD      A,0Ah
        RET
KEY_CTRLB7:
        BIT     7,(HL)
        JR      Z,KEY_RET1E
        LD      A,0Fh
        RET
KEY_PRESSED:
        LD      (0006h),DE
        LD      A,E
        LD      E,00h
        OR      A
KEY_COLNUM:
        RRA
        JR      C,KEY_ONECOL
        INC     E
        JR      KEY_COLNUM
KEY_ONECOL:
        OR      A
        JR      NZ,KEY_RET1E
        LD      A,0Fh
        AND     D
        RRA
        LD      D,A
        JR      NC,KEY_INDEX
        LD      A,08h
        ADD     A,E
        LD      E,A
KEY_INDEX:
        LD      A,D
        LD      C,D
        RLCA
        RLCA
        RLCA
        RLCA
        OR      E
        LD      E,A
        XOR     A
        LD      D,A
        LD      A,C
        CP      02h
        JR      C,KEY_NORMAL
        CP      04h
        JR      NC,KEY_ROW4
        LD      A,B
        CP      01h
        JR      NZ,KEY_ROW23
KEY_GRAPH:
        LD      HL,KEYTAB_G
        JR      KEY_LOOKUP
; <- aufgerufen von 0A26h, 0A2Bh
KEY_MODCHK:
        POP     HL
        LD      A,B
        CP      02h
        JR      Z,KEY_SHIFT
        CP      04h
        JR      Z,KEY_SHIFT
        AND     07h
        OR      A
        JR      NZ,KEY_RET1E
        PUSH    HL
        LD      HL,PPI_A_COPY
        RET
KEY_ROW4:
        CALL    KEY_MODCHK
        JR      KEY_LOWER
KEY_ROW23:
        CALL    KEY_MODCHK
        BIT     6,(HL)
        JR      NZ,KEY_GRAPH
KEY_LOWER:
        BIT     5,(HL)
        JR      NZ,KEY_SHIFTLO
KEY_NORMAL:
        LD      HL,KEYTAB_N
KEY_LOOKUP:
        ADD     HL,DE
        LD      A,(HL)
        RET
KEY_SHIFT:
        LD      HL,KEYTAB_S
        JR      KEY_LOOKUP
KEY_SHIFTLO:
        LD      HL,KEYTAB_S
        ADD     HL,DE
        LD      A,(HL)
        CP      09h
        RET     NC
        CP      05h
        RET     C
        JR      KEY_NORMAL
; <- aufgerufen von 0981h
KEY_STORE:
        LD      (0026h),DE
        RET
;  KEYSCAN – kurz prüfen, ob überhaupt eine Taste gedrückt ist (sonst
;  KEY_NONE), dann GETKEY.
; <- aufgerufen von 06E0h
KEYSCAN:
        IN      A,(PIO_AD)
        RES     4,A
        OUT     (PIO_AD),A
        IN      A,(PIO_BD)
        IN      A,(PIO_BD)
        INC     A
        PUSH    AF
        LD      B,05h
KS_DELAY:
        XOR     A
KS_DELAY_LP:
        DEC     A
        JR      NZ,KS_DELAY_LP
        DJNZ    KS_DELAY
        POP     AF
        JP      Z,KEY_NONE
        JP      GETKEY

; ------------------------------------------------------------------------------
;  DISPCTRL – Zeichen/Steuerzeichen auf dem Bildschirm ausführen
;  Steuerzeichen werden über CTRLTAB verteilt.
; ------------------------------------------------------------------------------
;  Steuerzeichen (CTRLTAB): 01h Cursor ab (rollt), 02h auf, 03h rechts,
;  04h links, 05h Home, 06h Bildschirm löschen, 07h DEL, 08h INST,
;  09h Grafikmodus, 0Ah Kleinschrift, 0Bh nichts, 0Ch Invers ein,
;  0Dh CR (nächste logische Zeile), 0Eh Normalmodus, 0Fh Invers aus.
;  Die Modi stehen in PPI_A_COPY (Bit 5, 6, 7).
; <- aufgerufen von 0779h, 0823h, 0842h, 08F4h, 0948h
DISPCTRL:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        OR      A
        JR      Z,CTL_RET
        LD      HL,CTRLTAB
        DEC     A
        RLCA
        LD      C,A
        LD      B,00h
        ADD     HL,BC
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        JP      (HL)
CTRLTAB:
        DEFW    CTL_01
        DEFW    CTL_02
        DEFW    CTL_03
        DEFW    CTL_04
        DEFW    CTL_05
        DEFW    CTL_06
        DEFW    CTL_07
        DEFW    CTL_08
        DEFW    CTL_09
        DEFW    CTL_0A
        DEFW    CTL_RET
        DEFW    CTL_0C
        DEFW    CTL_0D
        DEFW    CTL_0E
        DEFW    CTL_0F
CTL_0F: LD      HL,PPI_A_COPY
        RES     7,(HL)
CTL_SETPPI:
        LD      A,(HL)
        OUT     (PPI_A),A
CTL_RET:
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET
CTL_0E: LD      HL,PPI_A_COPY
        NOP
        NOP
        RES     6,(HL)
        RES     5,(HL)
        JR      CTL_SETPPI
CTL_0C: LD      HL,PPI_A_COPY
        SET     7,(HL)
        JR      CTL_SETPPI
CTL_0A: LD      HL,PPI_A_COPY
        SET     5,(HL)
        RES     6,(HL)
        JR      CTL_SETPPI
CTL_09: LD      HL,PPI_A_COPY
        RES     5,(HL)
        SET     6,(HL)
        JR      CTL_SETPPI
;  SCROLL_UP – Rollbereich eine Zeile nach oben schieben, unterste Zeile
;  löschen, LINE_TAB mitschieben.
SCROLL_UP:
        LD      DE,(0013h)
        LD      BC,(001Bh)
SCR_WIDTH2:
        LD      HL,0028h
        ADD     HL,DE
        CALL    VRAM_LDIR
        EX      DE,HL
SCR_CLRW:
        LD      B,28h
        CALL    VRAM_CLR
        LD      A,(000Bh)
        LD      C,A
        LD      A,(000Ch)
        SUB     C
        ADD     A,03h
        LD      C,A
        LD      B,00h
        LD      DE,LINE_TAB
        LD      A,(000Bh)
        LD      L,A
        LD      H,00h
        ADD     HL,DE
        PUSH    HL
        POP     DE
        DEC     DE
        PUSH    DE
        LDIR
        LD      (HL),00h
        POP     HL
        LD      A,(HL)
        OR      A
        JR      Z,CTL_RET
        LD      HL,(CSR_XY)
        DEC     H
        LD      (CSR_XY),HL
        JR      SCROLL_UP
CTL_01: LD      HL,(CSR_XY)
        LD      A,(000Ch)
        CP      H
        JR      Z,SCROLL_UP
        INC     H
CTL_SETCSR:
        LD      (CSR_XY),HL
        JR      CTL_RET
CTL_02: CALL    CSR_ATTOP
        JP      Z,CTL_RET
        DEC     H
        JR      CTL_SETCSR
CTL_03: LD      HL,(CSR_XY)
        LD      A,L
CTL_03_MAX:
        CP      27h                     ; '''
        JR      NC,CTL_03_NEWL
        INC     L
        JR      CTL_SETCSR
CTL_03_NEWL:
        LD      L,00h
        INC     H
        LD      A,(000Ch)
        CP      H
        JR      NC,CTL_SETCSR
        LD      H,A
        LD      (CSR_XY),HL
        JP      SCROLL_UP
CTL_04: LD      HL,(CSR_XY)
        LD      A,L
        OR      A
        JR      Z,CTL_04_UP
        DEC     L
        JR      CTL_SETCSR
CTL_04_UP:
        LD      L,27h
        CALL    ROW_ATTOP
        JR      Z,CTL_05
        DEC     H
        JR      CTL_SETCSR
CTL_06: LD      HL,000Bh
        LD      E,(HL)
        INC     HL
        LD      A,(HL)
        SUB     E
        INC     A
        INC     A
        LD      C,A
        LD      HL,(0013h)
CTL_06_CLR:
        LD      B,28h
        CALL    VRAM_CLR
        DEC     C
        JR      NZ,CTL_06_CLR
        LD      HL,LINE_TAB
        LD      C,E
        ADD     HL,BC
        LD      A,6Fh                   ; 'o'
        SUB     L
        LD      B,A
        CALL    CLRMEM
CTL_05: CALL    ROW_ATTOP
        LD      H,A
        LD      L,00h
        JR      CTL_SETCSR
;  CTL_07 (DEL) – Zeichen links vom Cursor löschen, Rest der logischen
;  Zeile nachziehen. CTL_08 (INST) – Leerzeichen einfügen, falls am Ende
;  der logischen Zeile Platz ist.
CTL_07: CALL    CSR_ATTOP
        JR      NZ,CTL_07_GO
        XOR     A
        OR      L
        JP      Z,CTL_RET
CTL_07_GO:
        LD      A,L
        OR      A
        JR      NZ,CTL_07_SHIFT
        LD      E,H
        CALL    LINE_FLAG
        JR      NZ,CTL_07_SHIFT
        CALL    CSR2VRAM
        DEC     HL
        XOR     A
        CALL    VRAM_WR
        JR      CTL_04
CTL_07_SHIFT:
        CALL    LINE_NEXTFLAG
        LD      B,00h
CTL_07_LEN:
        LD      A,B
CTL_07_W:
        ADD     A,28h
        LD      B,A
        LD      A,(HL)
        OR      A
        JR      Z,CTL_07_MOVE
        INC     HL
        JR      CTL_07_LEN
CTL_07_MOVE:
        LD      HL,(CSR_XY)
        LD      A,B
        SUB     L
        LD      C,A
        LD      B,00h
        CALL    CSR2VRAM
        PUSH    HL
        POP     DE
        DEC     DE
        CALL    VRAM_LDIR
        DEC     HL
        XOR     A
        CALL    VRAM_WR
        JP      CTL_04
CTL_08: CALL    LINE_NEXTFLAG
        EX      DE,HL
        LD      C,00h
        LD      HL,(CSR_XY)
CTL_08_MAX:
        LD      L,27h
        JR      Z,CTL_08_CHK
CTL_08_LEN:
        INC     H
        LD      A,C
CTL_08_W:
        ADD     A,28h
        LD      C,A
        INC     DE
        LD      A,(DE)
        OR      A
        JR      NZ,CTL_08_LEN
CTL_08_CHK:
        CALL    XY2VRAM
        CALL    VRAM_RD
        OR      A
        JP      NZ,CTL_RET
        PUSH    HL
        LD      HL,(CSR_XY)
CTL_08_MAXC:
        LD      A,27h                   ; '''
        SUB     L
        ADD     A,C
        LD      B,A
        POP     DE
        PUSH    DE
        POP     HL
        DEC     HL
        IN      A,(PIO_AD)
        SET     7,A
        DI
        OUT     (PIO_AD),A
CTL_08_LP:
        LD      A,(HL)
        LD      (DE),A
        LD      (HL),20h
        DEC     HL
        DEC     DE
        DJNZ    CTL_08_LP
        IN      A,(PIO_AD)
        RES     7,A
        OUT     (PIO_AD),A
        EI
        JP      CTL_RET
CTL_0D: CALL    LINE_NEXTFLAG
        EX      DE,HL
        LD      HL,(CSR_XY)
        JP      Z,CTL_03_NEWL
        LD      B,00h
CTL_0D_LEN:
        INC     B
        INC     DE
        LD      A,(DE)
        OR      A
        JR      NZ,CTL_0D_LEN
        INC     H
        LD      L,00h
        LD      A,(000Ch)
        LD      D,A
        LD      A,H
        ADD     A,B
        CP      D
        JR      C,CTL_0D_DOWN
        LD      (CSR_XY),HL
        JP      SCROLL_UP
CTL_0D_DOWN:
        INC     H
        DJNZ    CTL_0D_DOWN
        JP      CTL_SETCSR
; <- aufgerufen von 0B23h, 0B84h
CSR_ATTOP:
        LD      HL,(CSR_XY)
; <- aufgerufen von 0B53h, 0B7Ch
ROW_ATTOP:
        LD      A,(000Bh)
        DEC     A
        CP      H
        RET
; <- aufgerufen von 0BA2h, 0BCBh, 0C12h
LINE_NEXTFLAG:
        LD      HL,(CSR_XY)
        LD      E,H
        INC     E
;  LINE_FLAG – LINE_TAB[E]: Z, wenn Zeile E keine Fortsetzung ist.
;  LINE_TAB: je Bildschirmzeile 0 = Anfang einer logischen Zeile, sonst
;  Fortsetzung.
; <- aufgerufen von 079Fh, 0892h, 0B93h
LINE_FLAG:
        LD      D,00h
        LD      HL,LINE_TAB
        ADD     HL,DE
        LD      A,(HL)
        OR      A
        RET
;  CSR2VRAM / XY2VRAM – VRAM-Adresse der Position (L = Spalte, H = Zeile):
;  D000h + Zeile * Breite (+ Spalte); Breite und Basis setzt SET40COL/80COL.
; <- aufgerufen von 06AEh, 0883h, 0B98h, 0BBAh
CSR2VRAM:
        LD      HL,(CSR_XY)
; <- aufgerufen von 07CAh, 0BE2h
XY2VRAM:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        POP     BC
        INC     B
XY_WIDTH:
        LD      DE,0028h
XY_BASE:
        LD      HL,0CFD8h
XY_LP:  ADD     HL,DE
        DJNZ    XY_LP
        ADD     HL,BC
        POP     DE
        POP     BC
        RET
;  VRAM_RD / VRAM_WR / VRAM_LDIR / VRAM_CLR – Text-VRAM über PIO Port A
;  Bit 7 einblenden, lesen/schreiben/kopieren/löschen, ausblenden
;  (mit gesperrten Interrupts).
; <- aufgerufen von 06B4h, 0BE5h, 55A6h, 5BF8h
VRAM_RD:
        DI
        PUSH    BC
        LD      C,0E8h
        IN      B,(C)
        SET     7,B
        OUT     (C),B
        LD      A,(HL)
VRAM_OFF:
        RES     7,B
        OUT     (C),B
        POP     BC
        EI
        RET
; <- aufgerufen von 06D1h, 0886h, 0B9Dh, 0BC5h
VRAM_WR:
        DI
        PUSH    BC
        LD      C,0E8h
        IN      B,(C)
        SET     7,B
        OUT     (C),B
        LD      (HL),A
        JR      VRAM_OFF
; <- aufgerufen von 07D4h, 0ADEh, 0BC0h
VRAM_LDIR:
        DI
        IN      A,(PIO_AD)
        SET     7,A
        OUT     (PIO_AD),A
        LDIR
VRAM_OFFA:
        RES     7,A
        OUT     (PIO_AD),A
        EI
        RET
; <- aufgerufen von 0AE4h, 0B6Ah, 0D08h
VRAM_CLR:
        DI
        IN      A,(PIO_AD)
        SET     7,A
        OUT     (PIO_AD),A
        XOR     A
VRAM_CLR_LP:
        LD      (HL),A
        INC     HL
        DJNZ    VRAM_CLR_LP
        IN      A,(PIO_AD)
        JR      VRAM_OFFA

; ------------------------------------------------------------------------------
;  Umschaltung 80/40 Zeichen: patcht Konstanten in vielen Routinen
; ------------------------------------------------------------------------------
;  SET80COL / SET40COL – Zeilenbreite umschalten: patcht die Breite (28h/
;  50h) und davon abgeleitete Werte in vielen Routinen, PIO Port A Bit 5,
;  löscht den Bildschirm und setzt den Rollbereich neu.
SET80COL:
        LD      A,10h
        LD      (CMDD_PERLINE+1),A
        LD      HL,0918h                ; Befehlsbytes 18h,09h = JR $+11 (werden in den Code geschrieben)
        LD      (PUTCH_CONT),HL
        LD      A,0B0h
        LD      (SETCOL_BASE+1),A
        LD      A,0EFh
        LD      (SETCOL_MODE+1),A
        LD      A,4Fh                   ; 'O'
SETCOL_COMMON:
        LD      (SETCOL_MAXX+1),A
SETCOL_BASE:
        LD      A,0B0h
        LD      (SCR_TOPROW+1),A
        LD      (XY_BASE+1),A
SETCOL_MAXX:
        LD      A,4Fh                   ; 'O'
        LD      (GL_TAB_MAX+1),A
        LD      (PUTCH_EOL+1),A
        LD      (CTL_03_MAX+1),A
        LD      (CTL_04_UP+1),A
        LD      (CTL_08_MAX+1),A
        LD      (CTL_08_MAXC+1),A
        INC     A
        LD      (GL_ENT_ROW+1),A
        LD      (GL_ENT_WIDTH+1),A
        LD      (ADD_WIDTH+1),A
        LD      (SCR_WIDTH1+1),A
        LD      (SCR_WIDTH2+1),A
        LD      (SCR_CLRW+1),A
        LD      (CTL_06_CLR+1),A
        LD      (CTL_07_W+1),A
        LD      (CTL_08_W+1),A
        LD      (XY_WIDTH+1),A
        IN      A,(PIO_AD)
SETCOL_MODE:
        SET     5,A
        OUT     (PIO_AD),A
        LD      HL,0D000h
        XOR     A
        OUT     (GRPH),A
        LD      B,A
SETCOL_CLR:
        CALL    VRAM_CLR
        LD      A,H
        CP      0E0h
        JR      NZ,SETCOL_CLR
        CALL    SCROLL_INIT
        LD      A,06h
        JP      DISPCTRL
; <- aufgerufen von 0078h
SET40COL:
        LD      A,08h
        LD      (CMDD_PERLINE+1),A
        LD      HL,0236h                ; Befehlsbytes 36h,02h = LD (HL),02h (Original bei PUTCH_CONT)
        LD      (PUTCH_CONT),HL
        LD      A,0D8h
        LD      (SETCOL_BASE+1),A
        LD      A,0AFh
        LD      (SETCOL_MODE+1),A
        LD      A,27h                   ; '''
        JR      SETCOL_COMMON

; ------------------------------------------------------------------------------
;  RST38_DUMP – Register HL, DE, BC, AF und PC anzeigen (RST 38h)
; ------------------------------------------------------------------------------
RST38_DUMP:
        PUSH    HL
        PUSH    DE
        PUSH    BC
        PUSH    AF
        LD      B,04h
DUMP_LP:
        POP     HL
        CALL    PRTHL
        CALL    PRTSPC
        DJNZ    DUMP_LP
        POP     HL
        DEC     HL
        CALL    PRTHL
        JP      MON_WARM

; ------------------------------------------------------------------------------
;  Tastaturtabellen (normal / Shift / Grafik)
; ------------------------------------------------------------------------------
KEYTAB_N:
        DEFB    10h,11h,12h,13h,14h,15h,16h,17h  ; ?? |........|
        DEFB    18h,19h,38h,39h,1Ah,2Eh,2Bh,2Dh  ; ?? |..89..+-|
        DEFB    30h,31h,32h,33h,34h,35h,36h,37h  ; ?? |01234567|
        DEFB    1Bh,20h,0Dh,02h,01h,04h,03h,0Bh  ; ?? |. ......|
        DEFB    2Fh                     ; ?? |/|
;  KEYTAB_N_AZ/KEYTAB_S_AZ: Buchstabenbereiche, deren Bit 5 CHANGE umdreht.
KEYTAB_N_AZ:
        DEFB    41h,42h,43h,44h,45h,46h,47h,48h  ; ?? |ABCDEFGH|
        DEFB    49h,4Ah,4Bh,4Ch,4Dh,4Eh,4Fh,50h  ; ?? |IJKLMNOP|
        DEFB    51h,52h,53h,54h,55h,56h,57h  ; ?? |QRSTUVW|
KEYTAB_S:
        DEFB    58h,59h,5Ah,5Eh,5Ch,3Fh,2Eh,2Ch  ; ?? |XYZ^\?.,|
        DEFB    30h,31h,32h,33h,34h,35h,36h,37h  ; ?? |01234567|
        DEFB    38h,39h,3Ah,3Bh,2Dh,40h,5Bh,00h  ; ?? |89:;-@[.|
        DEFB    5Dh,00h,05h,07h,00h,00h,00h,00h  ; ?? |].......|
        DEFB    84h                     ; ?? |.|
KEYTAB_S_AZ:
        DEFB    61h,62h,63h,64h,65h,66h,67h,68h  ; ?? |abcdefgh|
        DEFB    69h,6Ah,6Bh,6Ch,6Dh,6Eh,6Fh,70h  ; ?? |ijklmnop|
KEYTAB_S_QR:
        DEFB    71h,72h                 ; ?? |qr|
KEYTAB_S_SW:
        DEFB    73h,74h,75h,76h,77h     ; ?? |stuvw|
KEYTAB_G:
        DEFB    78h,79h,7Ah,7Eh,7Ch,82h,3Eh,3Ch  ; ?? |xyz~|.><|
        DEFB    5Fh,21h,22h,23h,24h,25h,26h,27h  ; ?? |_!"#$%&'|
        DEFB    28h,29h,2Ah,2Bh,3Dh,60h,7Bh,00h  ; ?? |()*+=`{.|
        DEFB    7Dh,00h,06h,08h,00h,00h,00h,00h  ; ?? |}.......|
        DEFB    83h,98h,88h,86h,9Ah,9Eh,9Bh,99h  ; ?? |........|
        DEFB    80h,89h,90h,8Dh,8Fh,92h,94h,8Ch  ; ?? |........|
        DEFB    8Bh,97h,9Fh,96h,9Ch,8Ah,87h,95h  ; ?? |........|
        DEFB    85h,9Dh,8Eh,5Eh,5Ch,81h,0FFh,91h  ; ?? |...^\...|
;  TEMPO_SET – TEMPO n (1-7): MV_TEMPO = 8 - n (größer = langsamer).
; <- aufgerufen von 2545h
TEMPO_SET:
        PUSH    AF
        PUSH    BC
        AND     0Fh
        LD      B,A
        LD      A,08h
        SUB     B
        LD      (MV_TEMPO),A
        POP     BC
        POP     AF
        RET

; ------------------------------------------------------------------------------
;  Timer (8253), Piepton und MUSIC-Interpreter
; ------------------------------------------------------------------------------
;  TIMER_SET – Uhr stellen: A = 0 vormittags / 1 nachmittags, DE =
;  Sekunden (0-43199). 8253: Zähler 1 zählt die Sekunden von 43200
;  abwärts, Zähler 0 teilt den Takt auf 1 Hz (7A12h = 31250), Zähler 2
;  zählt die Durchläufe von Zähler 1 (12-Stunden-Wechsel).
; <- aufgerufen von 1253h, 2092h
TIMER_SET:
        PUSH    BC
        LD      (MV_PM),A
        LD      (MV_TISTART),DE
        LD      A,0C1h
TIMER_PROG:
        OUT     (PIT_C1),A
        LD      A,0A8h
        OUT     (PIT_C1),A
        LD      A,02h
        OUT     (PIT_C0),A
        XOR     A
        OUT     (PIT_C0),A
        OUT     (TMR_F0),A
TIMER_SYNC:
        LD      A,44h                   ; 'D'
        OUT     (PIT_CTL),A
        IN      A,(PIT_C1)
        LD      C,A
        IN      A,(PIT_C1)
        CP      0A8h
        JR      NZ,TIMER_SYNC
        LD      A,0C0h
        CP      C
        JR      NZ,TIMER_SYNC
        LD      A,0C0h
        OUT     (PIT_C1),A
        LD      A,0A8h
        OUT     (PIT_C1),A
        LD      A,12h
        OUT     (PIT_C0),A
        LD      A,7Ah                   ; 'z'
        OUT     (PIT_C0),A
        LD      A,84h
        OUT     (PIT_CTL),A
        IN      A,(PIT_C2)
        LD      C,A
        IN      A,(PIT_C2)
        LD      B,A
        LD      (MV_C2LATCH),BC
        POP     BC
        RET
;  TIMER_GET – Uhr lesen: DE = Sekunden seit 0:00 bzw. 12:00 (0-43199),
;  A = 0/1 vormittags/nachmittags. Hat Zähler 2 seit dem letzten Lesen
;  ungerade oft gezählt, wird MV_PM umgeschaltet (TG_TOGGLE).
; <- aufgerufen von 286Ah
TIMER_GET:
        PUSH    BC
        PUSH    HL
        LD      A,84h
        OUT     (PIT_CTL),A
        LD      A,44h                   ; 'D'
        OUT     (PIT_CTL),A
        IN      A,(PIT_C2)
        LD      C,A
        IN      A,(PIT_C2)
        LD      B,A
        IN      A,(PIT_C1)
        LD      E,A
        IN      A,(PIT_C1)
        LD      D,A
        LD      HL,(MV_C2LATCH)
        XOR     A
        SBC     HL,BC
        LD      A,L
        RRCA
        CALL    C,TG_TOGGLE
        PUSH    DE
        LD      A,D
        OR      E
        JR      NZ,TG_ELAPSED
        LD      DE,0A8C0h
TG_ELAPSED:
        LD      HL,0A8C0h
        SBC     HL,DE
        LD      DE,(MV_TISTART)
        ADD     HL,DE
        JR      C,TG_WRAP
        PUSH    HL
        LD      DE,0A8C0h
        SBC     HL,DE
        JR      C,TG_SAME
        POP     AF
TG_AMPM:
        EX      DE,HL
        LD      A,(MV_PM)
        XOR     01h
        POP     HL
        LD      BC,0001h
        SBC     HL,BC
        JR      NZ,TG_RET
        XOR     01h
TG_RET: POP     HL
        POP     BC
        RET
TG_SAME:
        POP     DE
        POP     HL
        LD      A,(MV_PM)
        JR      TG_RET
TG_WRAP:
        LD      DE,5740h
        ADD     HL,DE
        JR      TG_AMPM
; <- aufgerufen von 0E6Fh
TG_TOGGLE:
        LD      (MV_C2LATCH),BC
        LD      A,(MV_PM)
        XOR     01h
        LD      (MV_PM),A
        RET
        DEFB    00h,00h                 ; ?? |..|
;  BEEP – kurzer Piepton. TONE: BC Schwingungen mit der Halbperiode HL
;  (Warteschleife) über PPI Port C Bit 2 (Bit-Set/Reset 05h/04h).
; <- aufgerufen von 0732h, 124Dh, 1530h
BEEP:   PUSH    BC
        PUSH    HL
        LD      BC,0030h
        LD      HL,0060h
        CALL    TONE
        POP     HL
        POP     BC
        RET
; <- aufgerufen von 0EC6h, 1023h, 1032h
TONE:   PUSH    BC
        PUSH    DE
TONE_LP:
        LD      A,05h
        CALL    SPK_HALF
        LD      A,04h
        CALL    SPK_HALF
        DEC     BC
        LD      A,C
        OR      B
        JR      NZ,TONE_LP
        JR      TONE_END
; <- aufgerufen von 0ED0h, 0ED5h
SPK_HALF:
        OUT     (PPI_CTL),A
        LD      D,H
        LD      E,L
SPK_DELAY:
        DEC     DE
        LD      A,D
        OR      E
        JR      NZ,SPK_DELAY
        RET
;  MUSIC_PLAY – Text (DE) spielen, bis 0Dh oder "*". Je Note: Buchstabe
;  C D E F G A B oder R (Pause), "#" davor für den Halbton, "-"/"+" davor
;  für die tiefe/hohe Oktave (sonst mittlere), danach optional die Länge
;  0-9 (gilt auch für folgende Noten, MV_NOTELEN). Unbekannte Zeichen
;  werden übergangen, BREAK bricht ab (C gesetzt).
; <- aufgerufen von 2532h
MUSIC_PLAY:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      A,02h
        LD      (MUS_OCTAVE),A
MUS_LOOP:
        LD      A,(DE)
        CP      0Dh
        JR      Z,MUS_END
        CP      2Ah                     ; '*'
        JR      Z,MUS_END
        CP      2Dh                     ; '-'
        JR      Z,MUS_LOW
        CP      2Bh                     ; '+'
        JR      Z,MUS_HIGH
        LD      HL,NOTETAB1
        CP      23h                     ; '#'
        LD      A,00h
        JR      NZ,MUS_NOTE
        LD      HL,NOTETAB2
        INC     A
        INC     DE
MUS_NOTE:
        LD      (MUS_SHARP),A
        CALL    MUS_LOOKUP
        JR      C,MUS_LOOP
        CALL    PLAYNOTE
        LD      A,02h
        LD      (MUS_OCTAVE),A
        JR      C,MUS_END
        JR      MUS_LOOP
MUS_LOW:
        LD      A,03h
MUS_SETOCT:
        LD      (MUS_OCTAVE),A
        INC     DE
        JR      MUS_LOOP
MUS_HIGH:
        LD      A,01h
        JR      MUS_SETOCT
MUS_END:
        POP     HL
TONE_END:
        POP     DE
        POP     BC
        RET
;  MUS_LOOKUP – Note in NOTETAB1/2 suchen: MV_PERIOD = Halbperiode, je
;  nach Oktave verdoppelt/halbiert; BC = Dauer = LENTAB[Länge] * MV_TEMPO.
;  Nicht gefunden: C.
; <- aufgerufen von 0F13h
MUS_LOOKUP:
        PUSH    BC
        LD      B,08h
        LD      A,(DE)
MUS_LK_LP:
        CP      (HL)
        JR      Z,MUS_FOUND
        INC     HL
        INC     HL
        INC     HL
        DJNZ    MUS_LK_LP
        SCF
        INC     DE
        POP     BC
        RET
MUS_FOUND:
        LD      A,B
        LD      (MUS_NOTEIDX),A
        INC     HL
        PUSH    DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        LD      A,H
        OR      L
        JR      Z,MUS_SETPER
        LD      A,(MUS_OCTAVE)
        DEC     A
        JR      Z,MUS_PER_HI
        DEC     A
        JR      Z,MUS_SETPER
        ADD     HL,HL
MUS_SETPER:
        LD      (MV_PERIOD),HL
        POP     DE
        INC     DE
        LD      A,(DE)
        LD      B,A
        AND     0F0h
        CP      30h                     ; '0'
        JR      Z,MUS_LENDIG
        LD      A,(MV_NOTELEN)
        JR      MUS_DUR
MUS_LENDIG:
        INC     DE
        LD      A,B
        AND     0Fh
        LD      (MV_NOTELEN),A
MUS_DUR:
        LD      C,A
        LD      B,00h
        LD      HL,LENTAB
        ADD     HL,BC
        PUSH    DE
        LD      E,(HL)
        LD      D,B
        LD      A,(MV_TEMPO)
        LD      B,A
        LD      H,D
        LD      L,D
MUS_DUR_LP:
        ADD     HL,DE
        DJNZ    MUS_DUR_LP
        POP     DE
        POP     BC
        PUSH    HL
        POP     BC
        XOR     A
        RET
MUS_PER_HI:
        SRL     H
        RR      L
        JR      MUS_SETPER
;  NOTETAB1/NOTETAB2: Stammtöne bzw. Halbtöne (#): Zeichen und Halbperiode
;  für TONE (mittlere Oktave), R = Pause.
NOTETAB1:
        DEFB    43h                     ; 'C'
        DEFW    0125h                   ; Halbperiode C
        DEFB    44h                     ; 'D'
        DEFW    0105h                   ; Halbperiode D
        DEFB    45h                     ; 'E'
        DEFW    00E9h                   ; Halbperiode E
        DEFB    46h                     ; 'F'
        DEFW    00DCh                   ; Halbperiode F
        DEFB    47h                     ; 'G'
        DEFW    00C3h                   ; Halbperiode G
        DEFB    41h                     ; 'A'
        DEFW    00AEh                   ; Halbperiode A
        DEFB    42h                     ; 'B'
        DEFW    009Bh                   ; Halbperiode B
        DEFB    52h                     ; 'R'
        DEFW    0000h                   ; Pause
NOTETAB2:
        DEFB    43h                     ; 'C'
        DEFW    0115h                   ; Halbperiode C#
        DEFB    44h                     ; 'D'
        DEFW    00F6h                   ; Halbperiode D#
        DEFB    45h                     ; 'E'
        DEFW    00DCh                   ; Halbperiode E#
        DEFB    46h                     ; 'F'
        DEFW    00CFh                   ; Halbperiode F#
        DEFB    47h                     ; 'G'
        DEFW    00B8h                   ; Halbperiode G#
        DEFB    41h                     ; 'A'
        DEFW    00A4h                   ; Halbperiode A#
        DEFB    42h                     ; 'B'
        DEFW    0092h                   ; Halbperiode B#
        DEFB    52h                     ; 'R'
        DEFW    0000h                   ; Pause
LENTAB:                                 ; Notenlänge 0-9 (Vielfache der Grundlänge)
        DEFB    01h,02h,03h,04h,06h,08h,0Ch,10h,18h,20h
NOTE_CYC        EQU     LENTAB+9        ; Schwingungen je Längeneinheit, Index = MUS_NOTEIDX (+7 bei #)
        DEFB    08h,0Fh,0Dh,0Ch,0Bh,0Ah,09h     ; Index 1-7: R B A G F E D
        DEFB    08h,10h,0Eh,0Dh,0Bh,0Bh,0Ah,08h ; 8: C, 9-15: B# A# G# F# E# D# C#
;  PLAYNOTE – Note spielen: Schwingungszahl = Dauer * NOTE_CYC[Note] (in
;  der hohen Oktave doppelt, in der tiefen halb so viele), dann TONE.
;  Pause (R): Warteschleife ohne Ton (Ausgabewert in TONE_LP auf 04h
;  gesetzt). BREAK: C gesetzt.
; <- aufgerufen von 0F18h
PLAYNOTE:
        CALL    KEYROW3
        CALL    BRKKEY
        RET     C
        PUSH    DE
        PUSH    BC
        PUSH    BC
        LD      HL,NOTE_CYC
        LD      A,(MUS_SHARP)
        CP      00h
        JR      Z,PN_NATURAL
        LD      BC,0007h
        ADD     HL,BC
PN_NATURAL:
        LD      A,(MUS_NOTEIDX)
        LD      C,A
        CP      01h
        JR      NZ,PN_CYC
        LD      A,02h
        LD      (MUS_OCTAVE),A
PN_CYC: ADD     HL,BC
        LD      B,(HL)
        LD      A,(MUS_OCTAVE)
        DEC     A
        JR      Z,PN_OCT_HI
        DEC     A
        JR      Z,PN_COUNT
        SRL     B
        JR      PN_COUNT
PN_OCT_HI:
        SLA     B
PN_COUNT:
        POP     DE
        LD      HL,0000h
PN_MUL: ADD     HL,DE
        DJNZ    PN_MUL
        LD      B,H
        LD      C,L
        LD      HL,(MV_PERIOD)
        LD      A,H
        OR      L
        JR      Z,PN_REST
        CALL    TONE
PN_RET: POP     BC
        POP     DE
        RET
PN_REST:
        PUSH    HL
        LD      A,04h
        LD      (TONE_LP+1),A
        LD      HL,0125h
        CALL    TONE
        LD      A,05h
        LD      (TONE_LP+1),A
        POP     HL
        JR      PN_RET
;  MUS_SHARP: 1 bei Halbton; MUS_NOTEIDX: Index der Note (C = 8 ... B = 2,
;  R = 1); MUS_OCTAVE: 1 hoch, 2 mittel, 3 tief.
MUS_SHARP:
        DEFB    00h                     ; ?? |.|
MUS_NOTEIDX:
        DEFB    00h                     ; ?? |.|

; ==============================================================================
;  ARBEITSSPEICHER DES MONITORS (im Image mit 00h/FFh vorbelegt)
; ==============================================================================
MON_BUF:
        DEFB    00h,00h,00h,00h,00h,00h,00h  ; ?? |.......|
;  MON_ADRIN/MON_MIN/MON_NAMEIN: Positionen im Eingabepuffer hinter den
;  Prompts ("-ADR.$", Adresse beim *M, "FILE NAME:").
MON_ADRIN:
        DEFB    00h                     ; ?? |.|
MON_MIN:
        DEFB    00h,00h                 ; ?? |..|
MON_NAMEIN:
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh  ; ?? |.......|
CMT_HEADER:
        DEFB    00h                     ; ?? |.|
CMT_HNAME:
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,0FFh  ; ?? |........|
CMT_HNAME_END:
        DEFB    0FFh                    ; ?? |.|
CMT_HSIZE:
        DEFB    0FFh,0FFh               ; ?? |..|
CMT_HLOAD:
        DEFB    0FFh,0FFh               ; ?? |..|
CMT_HEXEC:
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh               ; ?? |..|
;  TABSTOPS: Tabulatorpositionen des Bildschirmeditors (1, 5, 10 ... 70).
TABSTOPS:
        DEFB    01h,05h,0Ah,0Fh,14h,19h,1Eh,23h  ; ?? |.......#|
        DEFB    28h,2Dh,32h,37h,3Ch,41h,46h,0FFh  ; ?? |(-27<AF.|
PPI_A_COPY:
        DEFB    0FFh                    ; ?? |.|
CSR_XY: DEFB    0FFh                    ; ?? |.|
CSR_Y:  DEFB    0FFh                    ; ?? |.|
LINE_TAB:
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h         ; ?? |....|
MUS_OCTAVE:
        DEFB    00h                     ; ?? |.|
FKEY_END:
        DEFB    0FFh,0FFh               ; ?? |..|
CSR_COL:
        DEFB    0FFh                    ; ?? |.|
KEY_MODS:
        DEFB    0FFh                    ; ?? |.|
KEY_STATE:
        DEFB    0FFh,0FFh,0FFh          ; ?? |...|
KEY_STATE3:
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh  ; ?? |........|
        DEFB    0FFh                    ; ?? |.|
FKEY_TAB:
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h             ; ?? |...|
;  FKEY_DEFEND: Ende der Vorbelegung der Funktionstasten (FKEY_END nach
;  dem Kaltstart).
FKEY_DEFEND:
        DEFB    00h,00h,00h,00h,00h,0FFh,0FFh,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,0FFh,0FFh,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,0FFh,0FFh,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,0FFh,0FFh,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh  ; ?? |......|
FKEY_LIMIT:
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh  ; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,18h  ; ?? |........|
        DEFB    10h                     ; ?? |.|

; ==============================================================================
;  BASIC-INTERPRETER SB-6511
; ==============================================================================
;  BAS_COLD: Laufwerksnummer des IPL in den Autostart-Befehl
;  "RUN FDn"AUTO RUN"" eintragen, RAM-Ende suchen, Bildschirm,
;  Uhr, Einschaltmeldung, I/O-Init (inkl. SIO), Autostart.
BAS_COLD:
        LD      A,01h                   ; JP BAS_COLD bei 00AEh zu LD BC,nn entschärfen ...
        LD      (MON_GOBASIC),A
        LD      (AUTORUN_FLAG),A        ; ... und Autostart-Flag setzen
        LD      A,(IPL_DRIVE)           ; Laufwerksnummer vom IPL (0-3)
        ADD     A,31h                   ; -> "1".."4"
        LD      (AUTORUN_CMD+6),A       ; in "RUN FDn"AUTO RUN"" eintragen
        LD      HL,6AFFh                ; RAM-Test ab 6B00h
        LD      D,0FFh
BC_RAMTEST:
        INC     HL
        LD      A,H
        CP      D
        JR      Z,BC_RAMEND
        LD      A,0FFh                  ; FFh schreiben und prüfen ...
        LD      (HL),A
        SUB     (HL)
        JR      NZ,BC_RAMEND
        LD      (HL),A                  ; ... 00h schreiben und prüfen
        CP      (HL)
        JR      Z,BC_RAMTEST
BC_RAMEND:
        LD      (MEMTOP),HL             ; erstes nicht beschreibbares Byte (bzw. FF00h)
        LD      (STKTOP),HL
        LD      SP,HL                   ; Stack ans RAM-Ende
        CALL    BEEP
        XOR     A
        LD      D,A
        LD      E,A
        CALL    TIMER_SET
        CALL    CRLF2
        CALL    PRT_RULE
        LD      DE,MSG_BASIC            ; "  BASIC interpreter  SB-6511"
        CALL    PRTMSG_CR
        LD      DE,MSG_COPYR            ; "  Copyright 1981 by SHARP Corp."
        CALL    PRTMSG_CR
        CALL    PRT_RULE
        CALL    CLEARALL
        LD      BC,000Ah
        CALL    CHKMEM
        CALL    PRTNUM                  ; freien Speicher ausgeben
        CALL    MSGX
        LD      DE,MSG_BYTES
        JP      BAS_START2              ; " Bytes"

; ------------------------------------------------------------------------------
;  BAS_READY – Warmstart: "Ready", Zeile einlesen, ausführen
;  (Die 10 NOPs sind ein Patch-Platz.)
; ------------------------------------------------------------------------------
BAS_READY:
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        LD      SP,(STKTOP)
        CALL    FD_MOTOR_OFF
        XOR     A
        LD      (AUTORUN_FLAG),A
        LD      DE,MSG_READY
        CALL    MSGX
        LD      A,0FAh
        LD      (GL_MAXLEN),A
BAS_MAIN:
        LD      HL,BAS_DIRECT
        PUSH    HL
;  INLINE – Eingabezeile nach INBUF holen (DE = INBUF beim Rücksprung).
;  Löscht CURLINE/CURLNUM (Direktmodus). Bei Autostart wird AUTORUN_CMD
;  kopiert; bei AUTO wird die nächste Zeilennummer (AUTO_LINE, danach um
;  AUTO_STEP erhöht) als Vorgabe ausgegeben. Erstes Zeichen 0Bh beendet AUTO.
;  Überlauf der Zeilennummer bei AUTO -> AUTO aus, Fehler 1.
; <- aufgerufen von 131Eh
INLINE: LD      HL,CURLINE
        CALL    CLRWORD
        CALL    CLRWORD
        CALL    CRLF_IF
        LD      DE,INBUF
        LD      A,(AUTORUN_FLAG)
        OR      A
        JR      NZ,INL_AUTORUN
        LD      A,(AUTO_FLAG)
        OR      A
        JR      Z,INL_GET
        LD      HL,(AUTO_LINE)
        PUSH    HL
        LD      BC,(AUTO_STEP)
        ADD     HL,BC
        JR      C,INL_AUTOERR
        LD      (AUTO_LINE),HL
        POP     HL
        PUSH    DE
        CALL    NUM2DEC
        EX      DE,HL
        LD      (HL),20h
        INC     HL
        LD      (HL),0Dh
        EX      DE,HL
        POP     DE
        CALL    PRTSTR
INL_GET:
        CALL    GETLINE
        LD      A,(DE)
        CP      0Bh
        RET     NZ
        XOR     A
        LD      (AUTO_FLAG),A
        JR      INL_GET
INL_AUTOERR:
        XOR     A
        LD      (AUTO_FLAG),A
        JP      ERR_01
INL_AUTORUN:
        PUSH    DE                      ; Autostart: Befehl in den Eingabepuffer kopieren
        LD      HL,AUTORUN_CMD
        LD      BC,0012h
        LDIR
        POP     DE
        RET
AUTORUN_CMD:
        DEFB    "RUN FD2",22h,"AUTO RUN",22h,0Dh  ; Laufwerksziffer (1302h) wird bei 122Fh eingesetzt
BAS_START2:
        CALL    PRTSTR
        CALL    IO_INIT                 ; I/O-Init: GP-IB und RS-232C (SIO)
        LD      A,(AUTORUN_FLAG)
        OR      A
        JP      NZ,BAS_MAIN
        JP      BAS_READY
INLINE_CHK:
        CALL    INLINE
        LD      A,(DE)
        CP      0Dh
        RET     Z
        LD      HL,(STKTOP)
        LD      SP,HL
        CALL    CLOSE_ALL
;  BAS_DIRECT – Zeile tokenisieren (CRUNCH) und wieder nach INBUF listen
;  (LISTLINE, normalisiert die Anzeige). Ohne Zeilennummer wird sie ab
;  TOKTEXT sofort ausgeführt, mit Nummer über EDITLINE ins Programm übernommen.
BAS_DIRECT:
        CALL    CRUNCH
        CALL    LISTLINE
        LD      HL,(TOKLNUM)
        LD      A,L
        OR      H
        JR      NZ,BD_EDIT
        LD      HL,TOKTEXT
        LD      (TXTPTR),HL
        CALL    CHK_CHR_ALT
D1342:  DEFB    0Dh                     ; Inline-Parameter
D1343:  DEFW    EXECSTMT2
        JP      BAS_MAIN
BD_EDIT:
        CALL    EDITLINE
        JP      BAS_MAIN
;  EDITLINE – Zeile TOKLNUM/TOKTEXT ins Programm einfügen.
;  Setzt READ/DATA und CONT zurück, sucht die Zeilennummer (FINDLINE).
;  Existiert sie, wird sie zuerst entfernt (EDIT_DELETE). Ist der Text leer
;  (nur 0Dh), bleibt es beim Löschen. Sonst wird an der Fundstelle Platz
;  geschaffen und TOKLINE (Link, Nummer, Text) eingefügt (EDIT_INSERT);
;  danach werden Bereichszeiger und Links korrigiert (EDIT_FIXUP).
;  FINDLINE2 hat als Inline-Adresse die Stelle direkt dahinter (D1365):
;  gefunden oder Programmende, beide Wege laufen bei EDIT_LINK weiter.
; <- aufgerufen von 1348h, 42F3h
EDITLINE:
        CALL    DATA_RESET
        CALL    CONT_CLR
        CALL    FINDLINE
D1357:  DEFW    EDIT_INSERT
        CALL    Z,EDIT_DELETE
; <- aufgerufen von 1354h
EDIT_INSERT:
        LD      A,(TOKTEXT)
        CP      0Dh
        RET     Z
        CALL    FINDLINE2
D1365:  DEFW    EDIT_LINK               ; Inline-Parameter: zeigt direkt dahinter
EDIT_LINK:
        LD      (TOKLINE),HL
        EX      DE,HL
        LD      HL,TOKLINE
        CALL    LINESIZE
        CALL    MOVEUP
        JR      EDIT_FIXUP
; <- aufgerufen von 1359h
EDIT_DELETE:
        CALL    LINESIZE
        EX      DE,HL
        CALL    MEMDEL
        CALL    NEGBC
EDIT_FIXUP:
        CALL    ADJ_PTRS
        EX      DE,HL
        JP      LINKS_ADD
;  PRT_RULE – 33 Mal Zeichen 90h ausgeben, dann zwei Zeilenvorschübe.
; <- aufgerufen von 1259h, 1268h
PRT_RULE:
        LD      B,21h
PRT_RULE_LP:
        LD      A,90h
        CALL    PRTCHR
        DJNZ    PRT_RULE_LP
        JR      CRLF2
; <- aufgerufen von 125Fh, 1265h
PRTMSG_CR:
        CALL    PRTSTR
; <- aufgerufen von 1256h
CRLF2:  CALL    CRLF
        JP      CRLF
MSG_BASIC:
        DEFB    "  BASIC interpreter  SB-6511",0Dh
MSG_COPYR:
        DEFB    "  Copyright 1981 by SHARP Corp.",0Dh,00h,00h,00h,00h
        DEFB    00h,00h
AUTORUN_FLAG:
        DEFB    00h,00h                 ; ?? |..|
MSG_READY:
        DEFB    "Ready",0Dh
MSG_ERROR:
        DEFB    "*Error",0Dh
MSG_IN: DEFB    20h,69h,6Eh,0Dh         ; ?? | in.|
MSG_BREAK:
        DEFB    "*Break",0Dh
MSG_BYTES:
        DEFB    " Bytes",0Dh
ERRNUM: DEFB    00h,00h                 ; ?? |..|
;  ERRCTX_*: bei aktivem ON ERROR vor jeder Anweisung gesicherte Kopie von
;  CURLINE (Link, Zeilennummer) und TXTPTR, siehe ERRCTX_SAVE. ERRCTX_LNUM
;  liefert ERL, ERRCTX_TXT ist der Wiederaufsetzpunkt für RESUME.
ERRCTX_LINK:
        DEFB    00h,00h                 ; ?? |..|
ERRCTX_LNUM:
        DEFB    00h,00h                 ; ?? |..|
ERRCTX_TXT:
        DEFB    00h,00h                 ; ?? |..|

; ------------------------------------------------------------------------------
;  Fehlereinsprünge ERR_01..ERR_70
;  Jeder Einsprung lädt seine Nummer in A; das folgende DEFB 01h
;  verschluckt die restlichen LD A,n bis zum Sprung nach ERROR.
; ------------------------------------------------------------------------------
; <- aufgerufen von 19BEh, 2CD8h, 4791h
ERR_01: LD      A,01h                   ; Fehler 1: Syntax-Fehler
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_02: LD      A,02h                   ; Fehler 2: Überlauf (auch Division durch 0, LN negativ)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 1997h, 204Fh, 20A5h
ERR_03: LD      A,03h                   ; Fehler 3: Wert außerhalb des Bereichs / Überlauf
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 1FBCh, 2BB3h, 416Bh, 6136h
ERR_04: LD      A,04h                   ; Fehler 4: Typfehler (Zahl/String verwechselt)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_05: LD      A,05h                   ; Fehler 5: String zu lang (> 255 Zeichen)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 2356h, 2369h
ERR_06: LD      A,06h                   ; Fehler 6: Speicher voll
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_07: LD      A,07h                   ; Fehler 7
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_08: LD      A,08h                   ; Fehler 8: Zeile zu lang (CRUNCH)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_09: LD      A,09h                   ; Fehler 9
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_10: LD      A,0Ah                   ; Fehler 10: GOSUB zu tief verschachtelt (max. 15)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_11: LD      A,0Bh                   ; Fehler 11: FOR zu tief verschachtelt (max. 15)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_12: LD      A,0Ch                   ; Fehler 12: FN zu tief verschachtelt
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_13: LD      A,0Dh                   ; Fehler 13: NEXT ohne FOR
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_14: LD      A,0Eh                   ; Fehler 14: RETURN ohne GOSUB
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_15: LD      A,0Fh                   ; Fehler 15: FN nicht definiert
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 1F90h
ERR_16: LD      A,10h                   ; Fehler 16: Zeilennummer nicht vorhanden
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_17: LD      A,11h                   ; Fehler 17: CONT nicht möglich
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_18: LD      A,12h                   ; Fehler 18: Adresse im BASIC-Bereich (unter LIMIT bzw. belegt)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_19: LD      A,13h                   ; Fehler 19: im Direkt- bzw. Programmmodus nicht erlaubt
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_20: LD      A,14h                   ; Fehler 20
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_21: LD      A,15h                   ; Fehler 21: RESUME ohne Fehler
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_22: LD      A,16h                   ; Fehler 22
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_23: LD      A,17h                   ; Fehler 23
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_24: LD      A,18h                   ; Fehler 24: keine DATA mehr
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_25: LD      A,19h                   ; Fehler 25: SWAP während SWAP
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_26: LD      A,1Ah                   ; Fehler 26
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_27: LD      A,1Bh                   ; Fehler 27
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_28: LD      A,1Ch                   ; Fehler 28
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_29: LD      A,1Dh                   ; Fehler 29: RS-232C: Framing-Fehler (SIO RR1 Bit 6)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_30: LD      A,1Eh                   ; Fehler 30: RS-232C: Empfangs-Überlauf (SIO RR1 Bit 5)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_31: LD      A,1Fh                   ; Fehler 31: RS-232C: Paritätsfehler (SIO RR1 Bit 4)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_32: LD      A,20h                   ; Fehler 32: RS-232C: Sende-Timeout (Sendepuffer wird nicht leer)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_33: LD      A,21h                   ; Fehler 33: RS-232C: Empfangspuffer voll (256 Byte Ringpuffer übergelaufen)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_34: LD      A,22h                   ; Fehler 34: GP-IB: in dieser Betriebsart nicht möglich (Controller/Gerät)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_35: LD      A,23h                   ; Fehler 35: GP-IB: Schnittstelle nicht bereit (Port C1 Bit 7)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_36: LD      A,24h                   ; Fehler 36: GP-IB: keine Bestätigung beim Senden
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_37: LD      A,25h                   ; Fehler 37: GP-IB: ungültige Geräteadresse
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_38: LD      A,26h                   ; Fehler 38
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_39: LD      A,27h                   ; Fehler 39: GP-IB: nicht als Sprecher bzw. Hörer adressiert
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_40: LD      A,28h                   ; Fehler 40: Datei nicht gefunden
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_41: LD      A,29h                   ; Fehler 41: Diskette: Lese-/Schreibfehler, auch Schreibschutz
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_42: LD      A,2Ah                   ; Fehler 42: Datei existiert bereits
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_43: LD      A,2Bh                   ; Fehler 43: Datei ist geöffnet
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 247Ah, 4B67h
ERR_44: LD      A,2Ch                   ; Fehler 44: Datei nicht bzw. nicht in diesem Modus geöffnet
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_45: LD      A,2Dh                   ; Fehler 45
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_46: LD      A,2Eh                   ; Fehler 46: Datei gesperrt (LOCK)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_47: LD      A,2Fh                   ; Fehler 47
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_48: LD      A,30h                   ; Fehler 48
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_49: LD      A,31h                   ; Fehler 49
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_50: LD      A,32h                   ; Fehler 50: Diskette: Laufwerk nicht bereit
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_51: LD      A,33h                   ; Fehler 51: Verzeichnis voll
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 4F7Ch
ERR_52: LD      A,34h                   ; Fehler 52: falsche Diskette bzw. Volumennummer
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_53: LD      A,35h                   ; Fehler 53: Diskette voll
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_54: LD      A,36h                   ; Fehler 54: Diskette: Sektor nicht gefunden
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_55: LD      A,37h                   ; Fehler 55: Datei zu groß
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_56: LD      A,38h                   ; Fehler 56
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_57: LD      A,39h                   ; Fehler 57
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_58: LD      A,3Ah                   ; Fehler 58
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_59: LD      A,3Bh                   ; Fehler 59
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_60: LD      A,3Ch                   ; Fehler 60: ungültiger Dateiname
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_61: LD      A,3Dh                   ; Fehler 61: ungültiges Laufwerk
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_62: LD      A,3Eh                   ; Fehler 62
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_63: LD      A,3Fh                   ; Fehler 63: falscher Dateityp
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 45DAh, 469Eh, 49EFh, 4B2Dh
ERR_64: LD      A,40h                   ; Fehler 64: ungültige Dateinummer
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_65: LD      A,41h                   ; Fehler 65: Drucker antwortet nicht (Zeitüberschreitung)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_66: LD      A,42h                   ; Fehler 66: Drucker meldet Fehler (Status ESC 04h)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_67: LD      A,43h                   ; Fehler 67: Drucker meldet Fehler (Status ESC 03h)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_68: LD      A,44h                   ; Fehler 68
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_69: LD      A,45h                   ; Fehler 69
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_70: LD      A,46h                   ; Fehler 70: Kassette: Lesefehler
        JR      ERROR

; ------------------------------------------------------------------------------
;  Fehlerbehandlung
;  ERROR: Nummer merken, ON ERROR prüfen, sonst "*Error n [in z]".
;  BREAK: "*Break [in z]". SET_IOERR setzt IY auf IOERR (JP (IY)).
; ------------------------------------------------------------------------------
; <- aufgerufen von 2BECh, 3F32h, 4C72h
SET_IOERR:
        LD      IY,IOERR
        RET
IOERR_NUM:
        DEFB    00h                     ; ?? |.|
IOERR:  LD      A,(IOERR_NUM)
ERROR:  LD      (ERRNUM),A              ; Fehlernummer merken
        LD      A,(AUTORUN_FLAG)
        OR      A
        LD      BC,BAS_READY
        CALL    CLOSE_ALL               ; Dateien/Geräte aufräumen
        CALL    RELINK
        CALL    IS_DIRECT               ; Direktmodus?
        JR      Z,ERR_PRINT
        LD      HL,ONERR_FLAG                ; ON ERROR GOTO aktiv?
        LD      A,(HL)
        CP      01h
        JR      NZ,ERR_NOTRAP
        INC     (HL)
        LD      HL,(STKTOP)
        LD      SP,HL
        LD      HL,(ONERR_LINE)
        JP      GOTO_LNUM2
ERR_NOTRAP:
        CALL    CLR_ONERR
        CALL    INITVARPTR
        CALL    CLEARVARS
ERR_PRINT:
        LD      DE,MSG_ERROR            ; "*Error"
        CALL    MSGX
        LD      HL,(ERRNUM)
        CALL    PRTLINENUM
        JR      ERR_TAIL
BREAK:  LD      DE,MSG_BREAK            ; "*Break"
        CALL    MSGX
ERR_TAIL:
        LD      BC,BAS_READY
        PUSH    BC
        XOR     A
        LD      (AUTO_FLAG),A
        CALL    BEEP
        CALL    IS_DIRECT
        RET     Z
        LD      DE,MSG_IN
        CALL    PRTSTR
; <- aufgerufen von 151Dh
PRTLINENUM:
        CALL    PRTNUM
        JP      PRTSTR
;  CONT_CLR – CONT sperren (CONT_FLAG = 0).
; <- aufgerufen von 1351h, 1B1Bh, 20D6h, 5116h, 5183h, 51B4h, 52ADh, 67C7h
CONT_CLR:
        XOR     A
        LD      (CONT_FLAG),A
        RET
;  DATA_RESET – READ beginnt wieder beim ersten DATA (DATA_FLAG = 0).
; <- aufgerufen von 134Eh, 20D3h
DATA_RESET:
        XOR     A
        LD      (DATA_FLAG),A
        RET
CONT_FLAG:
        DEFB    00h                     ; ?? |.|
CONT_SAVE:
        DEFB    00h,00h,00h,00h,00h,00h ; ?? |......|

; ------------------------------------------------------------------------------
;  CRUNCH – Eingabezeile in Token umsetzen (INBUF -> TOKTEXT)
;  LISTLINE – Token-Zeile wieder in Klartext wandeln.
; ------------------------------------------------------------------------------
; <- aufgerufen von 132Ch
CRUNCH: LD      HL,INBUF
        CALL    GETLNUM_SN
        LD      (TOKLNUM),DE
        LD      DE,TOKTEXT
        LD      C,00h
;  Ablauf von CRUNCH: COPYCHR kopiert Leerzeichen, FFh, Klammern und
;  Strings unverändert. Am ersten anderen Zeichen wird nacheinander gesucht:
;  "?" (= PRINT), KWTAB_STMT (-> 80h,80h+n), Tabelle 1835h (-> 81h,80h+n),
;  KWTAB_OPS/FUNC/MATH (-> 83h+n). Nach REM/DATA/DEF KEY( (n < 4) wird der
;  Rest bis ":" unverändert kopiert (CR_LITERAL). Zeichen >= 80h außerhalb
;  von Strings: Fehler 1, mehr als 255 Zeichen: Fehler 8.
CR_LOOP:
        CALL    COPYCHR
        RET     Z
        OR      A
        JP      M,ERR_01
        DEC     DE
        PUSH    HL
        LD      HL,CR_LOOP
        EX      (SP),HL
        CP      3Fh                     ; '?'
        LD      B,88h
        JR      Z,CR_STMT
        DEC     HL
        PUSH    DE
        LD      DE,KWTAB_STMT
        CALL    KWSEARCH
        JR      NZ,CR_EXT81
        POP     DE
CR_STMT:
        LD      A,80h
        CALL    CR_PUT2
        CP      84h
        RET     NC
CR_LITERAL:
        CALL    COPY_TO_COLON
        CP      3Ah                     ; ':'
        RET     Z
        POP     AF
        RET
CR_EXT81:
        LD      DE,KWTAB_EXT81
        CALL    KWSEARCH
        JR      NZ,CR_SINGLE
        POP     DE
        LD      A,81h
; <- aufgerufen von 1584h
CR_PUT2:
        LD      (DE),A
        INC     DE
CR_PUT1:
        LD      A,B
        LD      (DE),A
        INC     DE
        RET
CR_SINGLE:
        LD      DE,KWTAB_OPS
        LD      B,83h
        CALL    KWSEARCH_B
        POP     DE
        JR      Z,CR_PUT1
        INC     HL
        INC     DE
        RET
;  KWSEARCH – Schlüsselwort ab (HL) in der Tabelle (DE) suchen, B = 80h.
;  KWSEARCH_B: dasselbe mit Startnummer B. Leerzeichen in Eingabe und
;  Tabelle werden überlesen. Treffer: Z, B = Nummer des Eintrags, HL hinter
;  dem Wort. Kein Treffer: NZ, HL unverändert. Das letzte Zeichen eines
;  Eintrags hat Bit 7 gesetzt, 00h beendet die Tabelle.
; <- aufgerufen von 157Ch, 1595h, 2BF7h
KWSEARCH:
        LD      B,80h
; <- aufgerufen von 15A8h, 4761h, 4F32h, 4F9Eh
KWSEARCH_B:
        PUSH    HL
KWS_CMP:
        CALL    SKIPSP
        OR      A
        JP      M,KWS_HIBIT
        EX      DE,HL
        CALL    SKIPSP
        EX      DE,HL
        SUB     (HL)
        INC     HL
        INC     DE
        JR      Z,KWS_CMP
        ADD     A,80h
        JR      NZ,KWS_NEXT
        INC     SP
        INC     SP
        RET
KWS_NEXT:
        POP     HL
        DEC     DE
KWS_SKIP:
        LD      A,(DE)
        INC     DE
        OR      A
        JR      Z,KWS_END
        JP      P,KWS_SKIP
        INC     B
        JR      KWSEARCH_B
KWS_END:
        DEC     A
        RET
KWS_HIBIT:
        POP     HL
        CALL    SKIPSP
        DEC     A
        LD      A,(HL)
        RET
; <- aufgerufen von 132Fh, 1EDAh
LISTLINE:
        LD      HL,(TOKLNUM)
        LD      DE,INBUF
        LD      C,62h
        CALL    NUM2DEC_C
        LD      A,20h                   ; ' '
        LD      (DE),A
        INC     DE
        LD      HL,TOKTEXT
;  Ablauf von LISTLINE: Zeilennummer + " " nach INBUF, dann Zeichen
;  kopieren (Strings unverändert). Token 83h-FFh: Eintrag Token-83h aus
;  KWTAB_OPS ff.; 80h/81h/82h + n: Eintrag n-80h aus KWTAB_STMT/1835h/1837h.
;  Nach REM/DATA/DEF KEY( folgt der Rest bis ":" unverändert.
LL_LOOP:
        CALL    COPYCHR
        RET     Z
        SUB     80h
        JR      C,LL_LOOP
        DEC     DE
        DEC     C
        CP      03h
        JR      C,LL_PREFIX
        SUB     02h
        LD      B,A
        PUSH    HL
        LD      HL,KWTAB_OPS
LL_SINGLE:
        CALL    KWNTH
        POP     HL
        JR      LL_LOOP
LL_PREFIX:
        EX      AF,AF'
        LD      A,(HL)
        INC     HL
        SUB     7Fh
        LD      B,A
        PUSH    HL
        EX      AF,AF'
        OR      A
        JR      Z,LL_STMT
        LD      HL,LL_SINGLE
        PUSH    HL
        LD      HL,KWTAB_EXT81
        DEC     A
        RET     Z
        LD      HL,KWTAB_EXT82
        RET
LL_STMT:
        PUSH    BC
        LD      HL,KWTAB_STMT
        CALL    KWNTH
        POP     AF
        LD      HL,LL_LOOP
        EX      (SP),HL
        CP      04h
        RET     NC
        JP      CR_LITERAL
KWNTH_SKIP:
        BIT     7,(HL)
        INC     HL
        JR      Z,KWNTH_SKIP
;  KWNTH – B-ten Eintrag (ab 1) der Tabelle HL nach (DE) kopieren, Bit 7 des
;  letzten Zeichens wird gelöscht. C zählt die Ausgabelänge mit.
; <- aufgerufen von 1609h, 162Bh
KWNTH:  DJNZ    KWNTH_SKIP
KWNTH_COPY:
        CALL    COPY1
        ADD     A,80h
        JR      NC,KWNTH_COPY
        DEC     DE
        LD      (DE),A
        INC     DE
        RET
; <- aufgerufen von 1563h, 15F4h
COPYCHR:
        CALL    COPY1
        RET     Z
        CALL    ISPASS
        JR      Z,COPYCHR
        CP      22h                     ; '"'
        RET     NZ
        CALL    COPYSTR
        CP      0Dh
        JR      NZ,COPYCHR
        RET
;  ISPASS – Z, wenn A ein Zeichen ist, das CRUNCH/LISTLINE ungeprüft
;  übernimmt: Leerzeichen, FFh, "(" oder ")".
; <- aufgerufen von 164Fh
ISPASS: CP      20h                     ; ' '
        RET     Z
        CP      0FFh
        RET     Z
        CP      28h                     ; '('
        RET     Z
        CP      29h                     ; ')'
        RET
;  COPYSTR – bis einschließlich '"' oder 0Dh kopieren (Z bei 0Dh).
; <- aufgerufen von 1657h, 168Ah
COPYSTR:
        CALL    COPY1
        RET     Z
        CP      22h                     ; '"'
        JR      NZ,COPYSTR
        RET
;  COPY1 – ein Zeichen (HL) -> (DE) kopieren, C zählen (Überlauf: Fehler 8).
;  Z, wenn das Zeichen 0Dh war.
; <- aufgerufen von 1640h, 164Bh, 166Bh, 167Fh
COPY1:  LD      A,(HL)
        LD      (DE),A
        INC     HL
        INC     DE
        INC     C
        JP      Z,ERR_08
        CP      0Dh
        RET
;  COPY_TO_COLON – kopieren bis ":" oder 0Dh, Strings unverändert.
; <- aufgerufen von 158Ah
COPY_TO_COLON:
        CALL    COPY1
        RET     Z
        CP      3Ah                     ; ':'
        RET     Z
        CP      22h                     ; '"'
        JR      NZ,COPY_TO_COLON
        CALL    COPYSTR
        CP      0Dh
        JR      NZ,COPY_TO_COLON
        RET

; ------------------------------------------------------------------------------
;  Schlüsselworttabellen
;  KWTAB_STMT: Anweisungen, Token 80h,80h+Nr.
;  Die Nummern 75-90 sind GP-IB-, 96-98 RS-232C-Befehle.
; ------------------------------------------------------------------------------
KWTAB_STMT:
        DEFB    "RE","M"+80h            ; Nr.   0: REM
        DEFB    "DAT","A"+80h           ; Nr.   1: DATA
        DEFB    "DEF KEY","("+80h       ; Nr.   2: DEF KEY(
        DEFB    0FFh                    ; Nr.   3: (frei)
        DEFB    "REA","D"+80h           ; Nr.   4: READ
        DEFB    "LIS","T"+80h           ; Nr.   5: LIST
        DEFB    "RU","N"+80h            ; Nr.   6: RUN
        DEFB    "NE","W"+80h            ; Nr.   7: NEW
        DEFB    "PRIN","T"+80h          ; Nr.   8: PRINT
        DEFB    "LE","T"+80h            ; Nr.   9: LET
        DEFB    "FO","R"+80h            ; Nr.  10: FOR
        DEFB    "I","F"+80h             ; Nr.  11: IF
        DEFB    "THE","N"+80h           ; Nr.  12: THEN
        DEFB    "GOT","O"+80h           ; Nr.  13: GOTO
        DEFB    "GOSU","B"+80h          ; Nr.  14: GOSUB
        DEFB    "RETUR","N"+80h         ; Nr.  15: RETURN
        DEFB    "NEX","T"+80h           ; Nr.  16: NEXT
        DEFB    "STO","P"+80h           ; Nr.  17: STOP
        DEFB    "EN","D"+80h            ; Nr.  18: END
        DEFB    "ON ERROR GOT","O"+80h  ; Nr.  19: ON ERROR GOTO
        DEFB    "O","N"+80h             ; Nr.  20: ON
        DEFB    "LOA","D"+80h           ; Nr.  21: LOAD
        DEFB    "SAV","E"+80h           ; Nr.  22: SAVE
        DEFB    "VERIF","Y"+80h         ; Nr.  23: VERIFY
        DEFB    "POK","E"+80h           ; Nr.  24: POKE
        DEFB    "DI","M"+80h            ; Nr.  25: DIM
        DEFB    "DEF F","N"+80h         ; Nr.  26: DEF FN
        DEFB    "INPU","T"+80h          ; Nr.  27: INPUT
        DEFB    "RESTOR","E"+80h        ; Nr.  28: RESTORE
        DEFB    "CL","R"+80h            ; Nr.  29: CLR
        DEFB    "MUSI","C"+80h          ; Nr.  30: MUSIC
        DEFB    "TEMP","O"+80h          ; Nr.  31: TEMPO
        DEFB    "USR","("+80h           ; Nr.  32: USR(
        DEFB    "WOPE","N"+80h          ; Nr.  33: WOPEN
        DEFB    "ROPE","N"+80h          ; Nr.  34: ROPEN
        DEFB    "CLOS","E"+80h          ; Nr.  35: CLOSE
        DEFB    "MO","N"+80h            ; Nr.  36: MON
        DEFB    "LIMI","T"+80h          ; Nr.  37: LIMIT
        DEFB    "CON","T"+80h           ; Nr.  38: CONT
        DEFB    "GE","T"+80h            ; Nr.  39: GET
        DEFB    "INP","@"+80h           ; Nr.  40: INP@
        DEFB    "OUT","@"+80h           ; Nr.  41: OUT@
        DEFB    "CURSO","R"+80h         ; Nr.  42: CURSOR
        DEFB    "SE","T"+80h            ; Nr.  43: SET
        DEFB    "RESE","T"+80h          ; Nr.  44: RESET
        DEFB    "LIN","E"+80h           ; Nr.  45: LINE
        DEFB    "BLIN","E"+80h          ; Nr.  46: BLINE
        DEFB    "CONSOL","E"+80h        ; Nr.  47: CONSOLE
        DEFB    "GRAP","H"+80h          ; Nr.  48: GRAPH
        DEFB    "POSITIO","N"+80h       ; Nr.  49: POSITION
        DEFB    "PATTER","N"+80h        ; Nr.  50: PATTERN
        DEFB    "AUT","O"+80h           ; Nr.  51: AUTO
        DEFB    "APPEN","D"+80h         ; Nr.  52: APPEND
        DEFB    "IMAGE/","P"+80h        ; Nr.  53: IMAGE/P
        DEFB    "COPY/","P"+80h         ; Nr.  54: COPY/P
        DEFB    "PAGE/","P"+80h         ; Nr.  55: PAGE/P
        DEFB    0FFh                    ; Nr.  56: (frei)
        DEFB    "BOO","T"+80h           ; Nr.  57: BOOT
        DEFB    "KLIS","T"+80h          ; Nr.  58: KLIST
        DEFB    "CHANG","E"+80h         ; Nr.  59: CHANGE
        DEFB    0FFh                    ; Nr.  60: (frei)
        DEFB    0FFh                    ; Nr.  61: (frei)
        DEFB    "RE","W"+80h            ; Nr.  62: REW
        DEFB    "FAS","T"+80h           ; Nr.  63: FAST
        DEFB    "DI","R"+80h            ; Nr.  64: DIR
        DEFB    "DELET","E"+80h         ; Nr.  65: DELETE
        DEFB    "SWA","P"+80h           ; Nr.  66: SWAP
        DEFB    "KIL","L"+80h           ; Nr.  67: KILL
        DEFB    "RENAM","E"+80h         ; Nr.  68: RENAME
        DEFB    "LOC","K"+80h           ; Nr.  69: LOCK
        DEFB    "CHAI","N"+80h          ; Nr.  70: CHAIN
        DEFB    "UNLOC","K"+80h         ; Nr.  71: UNLOCK
        DEFB    "RESUM","E"+80h         ; Nr.  72: RESUME
        DEFB    "XOPE","N"+80h          ; Nr.  73: XOPEN
        DEFB    0FFh                    ; Nr.  74: (frei)
        DEFB    "SSR","Q"+80h           ; Nr.  75: SSRQ
        DEFB    "GPI","B"+80h           ; Nr.  76: GPIB
        DEFB    "PP","C"+80h            ; Nr.  77: PPC
        DEFB    "PPO","L"+80h           ; Nr.  78: PPOL
        DEFB    "PP","U"+80h            ; Nr.  79: PPU
        DEFB    "RE","N"+80h            ; Nr.  80: REN
        DEFB    "IC","L"+80h            ; Nr.  81: ICL
        DEFB    "LC","L"+80h            ; Nr.  82: LCL
        DEFB    "CM","D"+80h            ; Nr.  83: CMD
        DEFB    "WR","T"+80h            ; Nr.  84: WRT
        DEFB    "RE","D"+80h            ; Nr.  85: RED
        DEFB    "SR","Q"+80h            ; Nr.  86: SRQ
        DEFB    "SPO","L"+80h           ; Nr.  87: SPOL
        DEFB    "LL","O"+80h            ; Nr.  88: LLO
        DEFB    "DC","L"+80h            ; Nr.  89: DCL
        DEFB    0FFh                    ; Nr.  90: (frei)
        DEFB    "TR","G"+80h            ; Nr.  91: TRG
        DEFB    "PC","T"+80h            ; Nr.  92: PCT
        DEFB    "RD","S"+80h            ; Nr.  93: RDS
        DEFB    "RQSMSG","="+80h        ; Nr.  94: RQSMSG=
        DEFB    "EO","I"+80h            ; Nr.  95: EOI
        DEFB    "RS","O"+80h            ; Nr.  96: RSO
        DEFB    "RS","I"+80h            ; Nr.  97: RSI
        DEFB    "RSMOD","E"+80h         ; Nr.  98: RSMODE
        DEFB    0FFh                    ; Nr.  99: (frei)
        DEFB    00h                     ; Trenner
KWTAB_EXT81:
        DEFB    0FFh                    ; Nr. 100: (frei)
        DEFB    00h                     ; Trenner
KWTAB_EXT82:
        DEFB    0FFh                    ; Nr. 101: (frei)
        DEFB    00h                     ; Trenner
KWTAB_OPS:
        DEFB    ">","<"+80h             ; Nr.   0: ><
        DEFB    "<",">"+80h             ; Nr.   1: <>
        DEFB    "=","<"+80h             ; Nr.   2: =<
        DEFB    "<","="+80h             ; Nr.   3: <=
        DEFB    "=",">"+80h             ; Nr.   4: =>
        DEFB    ">","="+80h             ; Nr.   5: >=
        DEFB    0FFh                    ; Nr.   6: (frei)
        DEFB    ">"+80h                 ; Nr.   7: >
        DEFB    "<"+80h                 ; Nr.   8: <
        DEFB    0FFh                    ; Nr.   9: (frei)
        DEFB    0FFh                    ; Nr.  10: (frei)
        DEFB    0FFh                    ; Nr.  11: (frei)
        DEFB    0FFh                    ; Nr.  12: (frei)
        DEFB    0FFh                    ; Nr.  13: (frei)
        DEFB    0FFh                    ; Nr.  14: (frei)
        DEFB    0FFh                    ; Nr.  15: (frei)
        DEFB    0FFh                    ; Nr.  16: (frei)
        DEFB    0FFh                    ; Nr.  17: (frei)
        DEFB    0FFh                    ; Nr.  18: (frei)
        DEFB    0FFh                    ; Nr.  19: (frei)
        DEFB    0FFh                    ; Nr.  20: (frei)
        DEFB    0FFh                    ; Nr.  21: (frei)
        DEFB    0FFh                    ; Nr.  22: (frei)
        DEFB    0FFh                    ; Nr.  23: (frei)
        DEFB    0FFh                    ; Nr.  24: (frei)
        DEFB    0FFh                    ; Nr.  25: (frei)
        DEFB    0FFh                    ; Nr.  26: (frei)
KWTAB_FUNC:
        DEFB    "T","O"+80h             ; Nr.   0: TO
        DEFB    "STE","P"+80h           ; Nr.   1: STEP
        DEFB    "LEFT$","("+80h         ; Nr.   2: LEFT$(
        DEFB    "RIGHT$","("+80h        ; Nr.   3: RIGHT$(
        DEFB    "MID$","("+80h          ; Nr.   4: MID$(
        DEFB    "LEN","("+80h           ; Nr.   5: LEN(
        DEFB    "CHR$","("+80h          ; Nr.   6: CHR$(
        DEFB    "STR$","("+80h          ; Nr.   7: STR$(
        DEFB    "ASC","("+80h           ; Nr.   8: ASC(
        DEFB    "VAL","("+80h           ; Nr.   9: VAL(
        DEFB    "PEEK","("+80h          ; Nr.  10: PEEK(
        DEFB    "TAB","("+80h           ; Nr.  11: TAB(
        DEFB    "SPACE$","("+80h        ; Nr.  12: SPACE$(
        DEFB    "SIZ","E"+80h           ; Nr.  13: SIZE
        DEFB    "ER","L"+80h            ; Nr.  14: ERL
        DEFB    "ER","N"+80h            ; Nr.  15: ERN
        DEFB    "EOF","("+80h           ; Nr.  16: EOF(
        DEFB    "STRING$","("+80h       ; Nr.  17: STRING$(
        DEFB    "POINT","("+80h         ; Nr.  18: POINT(
        DEFB    "CHARACTER$","("+80h    ; Nr.  19: CHARACTER$(
        DEFB    "CS","R"+80h            ; Nr.  20: CSR
        DEFB    "PO","S"+80h            ; Nr.  21: POS
        DEFB    0FFh                    ; Nr.  22: (frei)
        DEFB    0FFh                    ; Nr.  23: (frei)
        DEFB    0FFh                    ; Nr.  24: (frei)
        DEFB    0FFh                    ; Nr.  25: (frei)
        DEFB    0FFh                    ; Nr.  26: (frei)
        DEFB    0FFh                    ; Nr.  27: (frei)
        DEFB    0FFh                    ; Nr.  28: (frei)
        DEFB    0FFh                    ; Nr.  29: (frei)
        DEFB    0FFh                    ; Nr.  30: (frei)
        DEFB    0FFh                    ; Nr.  31: (frei)
        DEFB    0FFh                    ; Nr.  32: (frei)
        DEFB    0FFh                    ; Nr.  33: (frei)
KWTAB_MATH:
        DEFB    "RND","("+80h           ; Nr.   0: RND(
        DEFB    "SIN","("+80h           ; Nr.   1: SIN(
        DEFB    "COS","("+80h           ; Nr.   2: COS(
        DEFB    "TAN","("+80h           ; Nr.   3: TAN(
        DEFB    "ATN","("+80h           ; Nr.   4: ATN(
        DEFB    "EXP","("+80h           ; Nr.   5: EXP(
        DEFB    "INT","("+80h           ; Nr.   6: INT(
        DEFB    "LOG","("+80h           ; Nr.   7: LOG(
        DEFB    "LN","("+80h            ; Nr.   8: LN(
        DEFB    "ABS","("+80h           ; Nr.   9: ABS(
        DEFB    "SGN","("+80h           ; Nr.  10: SGN(
        DEFB    "SQR","("+80h           ; Nr.  11: SQR(
        DEFB    0FFh                    ; Nr.  12: (frei)
        DEFB    00h                     ; Trenner

; ------------------------------------------------------------------------------
;  Hilfsroutinen für Textzeiger, Syntaxprüfung und Zahlen
;  SKIPSP: Leerzeichen überlesen.  SYNCHK: Zeichen aus Inline-Byte
;  prüfen, sonst Fehler 1.  CPHLDE: HL mit DE vergleichen.
;  JP_INLINE / RET_SKIP2: Hilfen für Routinen mit Inline-Parametern.
; ------------------------------------------------------------------------------
; <- aufgerufen von 1D67h
GETTXT: LD      HL,(TXTPTR)
        DEC     HL
; <- aufgerufen von 1C59h, 272Fh, 2760h, 2827h, 2932h
SKIPSP_INC:
        INC     HL
; <- aufgerufen von 15B4h, 15BCh, 15DCh, 1932h, 195Dh, 196Bh, 1B03h, 1BBBh (+15 weitere)
SKIPSP: LD      A,(HL)
        CP      20h                     ; ' '
        RET     NZ
        JR      SKIPSP_INC
;  SKIPLINE – HL hinter das nächste 0Dh setzen (A bleibt erhalten).
; <- aufgerufen von 24EFh, 27CFh
SKIPLINE:
        PUSH    AF
        LD      A,0Dh
SKIPLINE_LP:
        CP      (HL)
        INC     HL
        JR      NZ,SKIPLINE_LP
        POP     AF
        RET
SKIPSTMT_NX:
        INC     HL
;  SKIPSTMT – HL an das Ende der Anweisung (":" oder 0Dh) setzen,
;  Strings werden übersprungen.
; <- aufgerufen von 1E6Fh, 22C8h, 2307h, 24D9h, 2509h, 41CEh
SKIPSTMT:
        CALL    CHRGET
        RET     Z
        CP      22h                     ; '"'
        JR      NZ,SKIPSTMT_NX
SKIPSTMT_STR:
        INC     HL
        LD      A,(HL)
        CP      0Dh
        RET     Z
        CP      22h                     ; '"'
        JR      NZ,SKIPSTMT_STR
        JR      SKIPSTMT_NX
;  NEGBC – BC = -BC.
; <- aufgerufen von 137Dh, 1BB3h, 200Ah, 5099h
NEGBC:  LD      A,C
        CPL
        LD      C,A
        LD      A,B
        CPL
        LD      B,A
        INC     BC
        RET
;  ISDIGIT – Leerzeichen überlesen; C gesetzt, wenn (HL) eine Ziffer ist.
; <- aufgerufen von 19A1h, 1C5Fh, 203Dh, 20D9h, 24B1h, 2C35h, 4770h, 4F3Bh (+3 weitere)
ISDIGIT:
        CALL    SKIPSP
        SUB     30h
        CP      0Ah
        LD      A,(HL)
        RET
; <- aufgerufen von 1A89h, 1AA2h, 1C99h, 1CEDh, 1ECCh, 1ED5h, 27E7h, 2C0Dh (+18 weitere)
CPHLDE: LD      A,H
        SUB     D
        RET     NZ
        LD      A,L
        SUB     E
        RET
;  Hilfen für Routinen mit Inline-Parametern (Adresse hinter dem CALL):
;  JP_INLINE: zur Inline-Adresse springen (Fehler-/Alternativziel),
;  RET_SKIP2: hinter die Inline-Adresse zurückkehren (Normalfall).
;  Die *_POP-Varianten holen vorher HL vom Stack.
JP_INL_POP:
        POP     HL
JP_INLINE:
        EX      (SP),HL
JP_INLINE2:
        PUSH    AF
        LD      A,(HL)
        INC     HL
        LD      H,(HL)
        LD      L,A
        POP     AF
        EX      (SP),HL
        RET
RET_SKIP2_POP:
        POP     HL
RET_SKIP2:
        EX      (SP),HL
        INC     HL
        INC     HL
        EX      (SP),HL
        RET
; <- aufgerufen von 1A41h, 1A56h
FACPTR5:
        LD      HL,(VALSP)
        INC     HL
        INC     HL
        INC     HL
        INC     HL
        INC     HL
        RET
; <- aufgerufen von 2192h, 2275h, 46A6h, 49F6h
CHK_CHR_ALT_T:
        LD      HL,(TXTPTR)
;  CHK_CHR_ALT – Leerzeichen überlesen, (HL) mit dem Inline-Byte
;  vergleichen. Gleich: HL dahinter, zurück hinter das Inline-Wort.
;  Ungleich: Sprung zur Inline-Adresse. _T: ab TXTPTR.
; <- aufgerufen von 133Fh, 1C3Dh, 1E84h, 204Fh, 2285h, 228Bh, 22FAh, 23A0h (+42 weitere)
CHK_CHR_ALT:
        CALL    SKIPSP
        EX      (SP),HL
        CP      (HL)
        INC     HL
        JR      NZ,JP_INLINE2
        INC     HL
        JR      SYNCHK_OK
; <- aufgerufen von 2185h
SYNCHK_T:
        LD      HL,(TXTPTR)
;  SYNCHK – wie CHK_CHR_ALT, aber ungleich ergibt Fehler 1.
; <- aufgerufen von 1D07h, 1E8Ah, 1F28h, 1FB5h, 2172h, 229Fh, 2300h, 2344h (+31 weitere)
SYNCHK: CALL    SKIPSP
        EX      (SP),HL
        CP      (HL)
        JP      NZ,ERR_01
SYNCHK_OK:
        INC     HL
        EX      (SP),HL
        JR      SKIPSP_INC
;  MUL16 – HL = HL * DE (16 Bit, ohne Vorzeichen). Überlauf: Sprung zur
;  Inline-Adresse. MUL16_ERR: Überlauf ergibt Fehler 3.
; <- aufgerufen von 1997h, 2356h, 2369h
MUL16:  XOR     A
        CP      H
        JR      Z,MUL16_GO
        EX      DE,HL
        CP      H
        JR      NZ,JP_INLINE
MUL16_GO:
        LD      A,L
        LD      L,H
MUL16_LP:
        OR      A
        JR      Z,MUL16_END
        RRA
        JR      NC,MUL16_SHL
        ADD     HL,DE
        JR      C,JP_INLINE
MUL16_SHL:
        OR      A
        JR      Z,MUL16_END
        EX      DE,HL
        ADD     HL,HL
        EX      DE,HL
        JR      NC,MUL16_LP
        JR      JP_INLINE
MUL16_END:
        EX      DE,HL
        JR      RET_SKIP2
; <- aufgerufen von 206Ch, 207Eh, 2403h, 240Fh, 28CAh, 28D9h
MUL16_ERR:
        CALL    MUL16
D199A:  DEFW    ERR_03
        RET
;  GETLNUM – Dezimalzahl ab (HL) nach DE, Leerzeichen dazwischen und danach
;  werden überlesen. Überlauf (nur geprüft für den Übertrag des letzten
;  ADD HL,HL) -> Inline-Adresse; sonst läuft die Zahl modulo 65536 über.
;  GETLNUM_SN: Überlauf ergibt Fehler 1.
; <- aufgerufen von 19BEh, 4B2Dh, 4F7Ch
GETLNUM:
        LD      DE,0000h
        LD      B,D
GETLNUM_LP:
        CALL    ISDIGIT
        JR      NC,RET_SKIP2
        AND     0Fh
        LD      C,A
        XOR     A
        PUSH    HL
        LD      L,E
        LD      H,D
        ADD     HL,HL
        RRA
        ADD     HL,HL
        RRA
        ADD     HL,DE
        RRA
        ADD     HL,HL
        RRA
        ADD     HL,BC
        EX      DE,HL
        POP     HL
        INC     HL
        ADC     A,A
        JR      NC,GETLNUM_LP
        JR      JP_INLINE
; <- aufgerufen von 1557h, 1F1Ch, 1F30h, 1F7Ch, 20DEh, 210Eh, 22C5h, 22D3h (+2 weitere)
GETLNUM_SN:
        CALL    GETLNUM
D19C1:  DEFW    ERR_01
        RET
;  NUM2DEC – HL als Dezimalzahl ohne führende Nullen nach (DE), davor ein
;  Leerzeichen, danach 0Dh. Zurück: DE zeigt auf das 0Dh.
;  NUM2DEC_C: Ausgabelänge in C mitzählen (für LISTLINE).
; <- aufgerufen von 12CFh, 1A0Dh, 4841h, 486Eh
NUM2DEC:
        LD      C,00h
; <- aufgerufen von 15EAh
NUM2DEC_C:
        LD      A,20h                   ; ' '
        LD      (DE),A
        INC     DE
        PUSH    DE
        LD      B,00h
        LD      DE,2710h
        CALL    NUM2DEC_DIG
        LD      DE,03E8h
        CALL    NUM2DEC_DIG
        LD      DE,0064h
        CALL    NUM2DEC_DIG
        LD      DE,000Ah
        CALL    NUM2DEC_DIG
        LD      A,L
        POP     HL
        OR      30h
        LD      (HL),A
        INC     HL
        LD      (HL),0Dh
        EX      DE,HL
        RET
; <- aufgerufen von 19D0h, 19D6h, 19DCh, 19E2h
NUM2DEC_DIG:
        LD      A,0FFh
N2D_SUB:
        INC     A
        OR      A
        SBC     HL,DE
        JR      NC,N2D_SUB
        ADD     HL,DE
        OR      A
        JR      NZ,N2D_PUT
        OR      B
        RET     Z
        XOR     A
N2D_PUT:
        INC     B
        OR      30h
        POP     DE
        EX      (SP),HL
        LD      (HL),A
        INC     HL
        EX      (SP),HL
        PUSH    DE
        INC     C
        RET
;  PRTNUM – HL dezimal nach 6CB3h wandeln, DE zeigt auf den Text
;  (gibt trotz des Namens nichts aus; danach folgt meist PRTSTR/MSGX).
; <- aufgerufen von 1274h, 153Dh, 1F6Ah, 4328h
PRTNUM: LD      DE,6CB3h
        PUSH    DE
        CALL    NUM2DEC
        POP     DE
        RET
;  MEMFREE/CHKMEM – HL = SP - 100 - ((VALSP) + BC), also der freie Platz
;  nach Belegung von BC Bytes. Zu wenig: Fehler 6 (Speicher voll).
; <- aufgerufen von 2B25h
MEMFREE:
        LD      BC,0000h
; <- aufgerufen von 1271h, 1A29h
CHKMEM: LD      HL,(VALSP)
        ADD     HL,BC
        JR      C,CHKMEM_ERR
        EX      DE,HL
        LD      HL,0FF9Ch
        ADD     HL,SP
        XOR     A
        SBC     HL,DE
        RET     NC
CHKMEM_ERR:
        JP      ERR_06
; <- aufgerufen von 1A50h, 274Dh, 4294h
CHKMEM2:
        PUSH    HL
        PUSH    DE
        CALL    CHKMEM
        POP     DE
        POP     HL
        RET
;  GETLINK – Programmzeile bei HL lesen: HL = Link, DE = Zeilennummer.
;  Z, wenn der Link 0 ist (Programmende).
; <- aufgerufen von 1A7Fh, 1AB3h, 1EB7h
GETLINK:
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        LD      A,(HL)
        INC     HL
        LD      H,(HL)
        LD      L,A
        EX      DE,HL
        LD      A,L
        OR      H
        RET
;  MEMDEL – BC Bytes ab DE entfernen: alles von DE+BC bis zum Ende des
;  Wertestacks (VALSP+5) rückt nach unten.
; <- aufgerufen von 137Ah, 1BAFh, 200Dh, 5096h
MEMDEL: PUSH    BC
        PUSH    HL
        PUSH    DE
        EX      DE,HL
        ADD     HL,BC
        EX      DE,HL
        CALL    FACPTR5
        LD      A,L
        SUB     E
        LD      C,A
        LD      A,H
        SBC     A,D
        LD      B,A
        INC     BC
        POP     HL
        PUSH    HL
        EX      DE,HL
        JR      BLKMOVE_GO
;  MEMINS – BC Bytes Platz ab DE schaffen (Speicher bis VALSP+5 rückt nach
;  oben, CHKMEM prüft vorher). MOVEUP: zusätzlich BC Bytes von HL nach DE
;  kopieren. BLKMOVE: nur kopieren (LDIR, BC = 0 erlaubt).
; <- aufgerufen von 1A6Ah, 1B88h, 1BFDh, 2004h, 5068h
MEMINS: CALL    CHKMEM2
        PUSH    BC
        PUSH    HL
        PUSH    DE
        CALL    FACPTR5
        PUSH    HL
        ADD     HL,BC
        EX      (SP),HL
        LD      A,L
        SUB     E
        LD      C,A
        LD      A,H
        SBC     A,D
        LD      B,A
        INC     BC
        POP     DE
        LDDR
MEM_RET:
        POP     DE
        POP     HL
        POP     BC
        RET
; <- aufgerufen von 1371h, 2517h, 263Bh, 2796h, 2855h
MOVEUP: CALL    MEMINS
; <- aufgerufen von 1BDEh, 27FCh, 2803h, 281Dh, 3CFEh
BLKMOVE:
        PUSH    BC
        PUSH    HL
        PUSH    DE
BLKMOVE_GO:
        LD      A,C
        OR      B
        JR      Z,MEM_RET
        LDIR
        JR      MEM_RET
;  FINDLINE – Zeile HL im Programm suchen. Zurück hinter das Inline-Wort
;  mit HL = Adresse der ersten Zeile mit Nummer >= HL, Z bei Gleichheit.
;  Am Programmende: Sprung zur Inline-Adresse, HL = Endmarke.
;  FINDLINE2 sucht noch einmal mit der zuletzt gesetzten Nummer
;  (Operand von FL_TARGET wird selbst verändert).
; <- aufgerufen von 1354h, 1F90h
FINDLINE:
        LD      (FL_TARGET+1),HL
; <- aufgerufen von 1362h
FINDLINE2:
        LD      HL,PRGTXT
FINDLINE_LP:
        PUSH    HL
        CALL    GETLINK
        JP      Z,JP_INL_POP
        PUSH    HL
FL_TARGET:
        LD      HL,0000h
        CALL    CPHLDE
        POP     HL
        JP      Z,RET_SKIP2_POP
        JP      C,RET_SKIP2_POP
        POP     AF
        JR      FINDLINE_LP
;  LISTKEY_CMP – Wort bei (HL) mit LISTKEY vergleichen (Operand wird selbst
;  verändert, von DIM/Feldzugriff gesetzt). Wort = 0: Listenende, Sprung
;  zur Inline-Adresse. Sonst Flags von CPHLDE, HL += 2.
; <- aufgerufen von 23F3h, 283Fh
LISTKEY_CMP:
        PUSH    HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      A,E
        OR      D
        JP      Z,JP_INL_POP
LISTKEY:
        LD      HL,0000h
        CALL    CPHLDE
        POP     HL
        INC     HL
        INC     HL
        JP      RET_SKIP2
LINKS_ADD_LP:
        ADD     HL,BC
        EX      DE,HL
        POP     HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        EX      DE,HL
;  LINKS_ADD – ab der Zeile HL zu allen Links BC addieren (nach Einfügen
;  oder Löschen von Programmtext).
LINKS_ADD:
        PUSH    HL
        CALL    GETLINK
        JR      NZ,LINKS_ADD_LP
        POP     HL
        RET
;  LINESIZE – BC = Länge der Programmzeile bei HL (4 + Text + 0Dh).
;  LEN_CR: BC = Anzahl Zeichen bis vor 0Dh, LEN_CR_BC addiert sie zu BC.
; <- aufgerufen von 136Eh, 1376h, 1EBDh
LINESIZE:
        PUSH    HL
        LD      BC,0004h
        ADD     HL,BC
        CALL    LEN_CR_BC
        INC     BC
        POP     HL
        RET
; <- aufgerufen von 3CF3h, 40FCh, 47DAh
LEN_CR: LD      BC,0000h
; <- aufgerufen von 1ABFh
LEN_CR_BC:
        PUSH    HL
        LD      A,0Dh
LEN_CR_LP:
        CP      (HL)
        INC     HL
        INC     BC
        JR      NZ,LEN_CR_LP
        DEC     BC
        POP     HL
        RET
; <- aufgerufen von 2031h, 252Fh, 2575h, 257Bh, 262Bh, 2631h, 29BBh, 29DFh (+12 weitere)
GETSTR: CALL    REQ_STR
;  GETSTR_E – Eintrag Nummer E in den String-Zwischenwerten (P_STRTMP)
;  suchen: DE = Text, C = Länge.
; <- aufgerufen von 2018h
GETSTR_E:
        LD      A,E
        EX      DE,HL
        LD      BC,0000h
        LD      HL,(P_STRTMP)
        DEC     HL
GETSTR_LP:
        INC     HL
        ADD     HL,BC
        CP      (HL)
        INC     HL
        LD      C,(HL)
        INC     HL
        JR      NZ,GETSTR_LP
        EX      DE,HL
        RET
;  REQ_STR – D = 0 (Zahl): Fehler 4 (Typfehler). CHKSTRTYPE ist das
;  Gegenstück: Fehler 4, wenn D <> 0 (String).
; <- aufgerufen von 1AD3h
REQ_STR:
        LD      A,D
        OR      A
        RET     NZ
        JR      ERR_TYPE
; <- aufgerufen von 20A2h, 2297h, 248Eh, 2711h, 27BAh, 280Ah, 2A3Ah
CHKSTRTYPE:
        LD      A,D
        OR      A
        RET     Z
ERR_TYPE:
        JP      ERR_04
;  VAL_PUT – 5 Bytes von HL nach (VALSP) kopieren.
;  VAL_GET – 5 Bytes von (VALSP) nach DE kopieren.
; <- aufgerufen von 25B4h, 26AEh
VAL_PUT:
        LD      HL,(VALSP)
        EX      DE,HL
VAL_MOVE5:
        LD      BC,0005h
        LDIR
        RET
; <- aufgerufen von 1FE7h, 2182h, 218Fh
VAL_GET:
        LD      HL,(VALSP)
        JR      VAL_MOVE5
; <- aufgerufen von 1917h, 1E65h, 1EAAh, 1F23h, 1F2Ch, 1F37h, 1F9Ah, 20E7h (+34 weitere)
CHRGET: CALL    SKIPSP
        CP      0Dh
        RET     Z
        CP      3Ah                     ; ':'
        RET
;  CLEARALL – NEW: leeres Programm, alle Variablen und Zeiger löschen.
; <- aufgerufen von 126Bh, 1E79h, 505Bh, 5081h
CLEARALL:
        LD      HL,0000h
        LD      (704Ch),HL
        CALL    CLRPROG
        CALL    CLEARVARS
        CALL    INITVARPTR
        CALL    CONT_CLR
        RET
;  CLRPROG – Programm leeren (00h 00h bei PRGTXT) und die Bereichszeiger
;  704Eh-7095h (PRGEND, 26 Puffer der Dateiverwaltung ab 7050h - siehe
;  CLEARVARS -, ab 7084h DEF FN, Felder, Variablen,
;  String-Zwischenwerte und VALSP, siehe EQUs P_*)
;  auf leere Bereiche dahinter setzen; jeder Bereich beginnt mit 00h 00h.
;  CLR_AREAS: dasselbe ab dem Zeiger 7084h (für CLR).
; <- aufgerufen von 1B12h
CLRPROG:
        LD      HL,PRGTXT
        CALL    CLRWORD
        LD      DE,PRGEND
AREAS_INIT:
        PUSH    HL
        LD      HL,7096h
        XOR     A
        SBC     HL,DE
        LD      B,L
        SRL     B
        POP     HL
        EX      DE,HL
AREAS_LP:
        XOR     A
        LD      (HL),E
        INC     HL
        LD      (HL),D
        INC     HL
        LD      (DE),A
        INC     DE
        LD      (DE),A
        INC     DE
        DJNZ    AREAS_LP
        RET
; <- aufgerufen von 150Eh, 1B18h, 1CBFh, 20F3h, 43DCh
INITVARPTR:
        LD      HL,7240h
        LD      (GOSUB_SP),HL
        LD      HL,71D7h
        LD      (FOR_SP),HL
        LD      HL,70BAh
        LD      (FNPAR_SP),HL
        LD      HL,FOR_CNT
        CALL    CLRWORD
        LD      (HL),A
; <- aufgerufen von 150Bh, 20ECh, 2332h
CLR_ONERR:
        XOR     A
        LD      (ONERR_FLAG),A
        RET
; <- aufgerufen von 1CB9h, 20F6h, 245Fh
CLR_AREAS:
        LD      HL,(P_DEFFN)
        LD      DE,P_DEFFN
        JR      AREAS_INIT
;  CLEARVARS – Dateitabelle FILETAB (6FF2h-704Bh) nullen und die 26
;  Puffer ab 7050h freigeben (AREA_FREE): 7050h + 2*n Dateipuffer der 10
;  Tabelleneinträge, ab 7064h Puffer je Einheit, 707Ch-7083h vier weitere.
; <- aufgerufen von 1511h, 1B15h, 1CBCh, 20F9h, 4523h
CLEARVARS:
        LD      HL,FILETAB
        LD      B,5Ah
CLRV_ZERO:
        LD      (HL),00h
        INC     HL
        DJNZ    CLRV_ZERO
        LD      B,1Ah
        LD      HL,7050h
CLRV_LP:
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        PUSH    HL
        EX      DE,HL
        CALL    AREA_FREE
        POP     HL
        DJNZ    CLRV_LP
        RET
; <- aufgerufen von 12A7h, 12AAh, 1B22h, 1B55h, 1D61h, 1EA2h, 2AA4h, 4A47h
CLRWORD:
        XOR     A
; <- aufgerufen von 1EA6h
CLRWORD_A:
        LD      (HL),A
        INC     HL
        LD      (HL),A
        INC     HL
        RET
;  MEMINS_ADJ – MEMINS und danach ADJ_PTRS.
;  ADJ_PTRS – Bereichszeiger von VALSP abwärts um BC verschieben, solange
;  sie größer als DE sind. MEMDEL_ADJ: MEMDEL und Zeiger um -BC korrigieren.
; <- aufgerufen von 1CDEh, 2378h, 24F8h, 428Eh, 4BE7h
MEMINS_ADJ:
        CALL    MEMINS
; <- aufgerufen von 1380h, 1BB6h, 2011h, 251Ah, 263Eh, 2799h, 2858h, 506Bh
ADJ_PTRS:
        PUSH    HL
        LD      A,E
        EX      AF,AF'
        LD      A,D
        LD      HL,VALSP
ADJ_LP: LD      E,(HL)
        INC     HL
        LD      D,(HL)
        CP      D
        JR      C,ADJ_ADD
        JR      NZ,ADJ_END
        EX      AF,AF'
        CP      E
        JR      NC,ADJ_END1
        EX      AF,AF'
ADJ_ADD:
        EX      DE,HL
        ADD     HL,BC
        EX      DE,HL
        LD      (HL),D
        DEC     HL
        LD      (HL),E
        DEC     HL
        DEC     HL
        JR      ADJ_LP
ADJ_END1:
        EX      AF,AF'
ADJ_END:
        LD      D,A
        EX      AF,AF'
        LD      E,A
        POP     HL
        RET
; <- aufgerufen von 2512h, 29EBh, 4BE3h
MEMDEL_ADJ:
        CALL    MEMDEL
        PUSH    BC
        CALL    NEGBC
        CALL    ADJ_PTRS
        POP     BC
        RET
;  STRLIT – String ab (HL) lesen: in Anführungszeichen bis '"' oder 0Dh,
;  sonst bis "," oder 0Dh (STRLIT_DE: Endzeichen in D/E). Der Text wird mit
;  STR_NEW als neuer Eintrag im Stringbereich (P_STRTMP) abgelegt.
;  Zurück: D = 1 (String), E = Nummer des Eintrags, BC = Länge.
; <- aufgerufen von 2A4Ch, 411Ch, 4122h, 4198h, 60F3h
STRLIT: CALL    SKIPSP
        LD      DE,0D2Ch
; <- aufgerufen von 60EDh
STRLIT_DE:
        LD      BC,0000h
        CP      22h                     ; '"'
        JR      NZ,STRLIT_GO
        LD      E,A
        INC     HL
STRLIT_GO:
        PUSH    HL
STRLIT_LP:
        LD      A,(HL)
        CP      D
        JR      Z,STR_STORE2
        CP      E
        INC     HL
        JR      Z,STR_STORE2
        INC     BC
        JR      STRLIT_LP
; <- aufgerufen von 26F9h, 4013h
STR_STORE:
        PUSH    HL
STR_STORE2:
        EX      (SP),HL
        PUSH    HL
        CALL    STR_NEW
        EX      DE,HL
        EX      (SP),HL
        CALL    BLKMOVE
        POP     DE
        POP     HL
        JP      SKIPSP
; <- aufgerufen von 1BD9h, 2AC9h
STR_NEW:
        PUSH    BC
        XOR     A
        LD      E,A
        LD      HL,(P_STRTMP)
        JR      STR_NEW_CNT
STR_NEW_LP:
        INC     HL
        LD      C,(HL)
        INC     HL
        INC     HL
        ADD     HL,BC
STR_NEW_CNT:
        INC     E
        CP      (HL)
        JR      NZ,STR_NEW_LP
        POP     BC
        PUSH    BC
        INC     BC
        INC     BC
        INC     BC
        EX      DE,HL
        CALL    MEMINS
        EX      DE,HL
        PUSH    HL
        ADD     HL,BC
        DEC     HL
        LD      (HL),0Dh
        LD      HL,(VALSP)
        ADD     HL,BC
        LD      (VALSP),HL
        POP     HL
        POP     BC
        LD      (HL),E
        INC     HL
        LD      (HL),C
        INC     HL
        LD      D,01h
        RET
;  VAL2UINT – Wert bei (VALSP) als ganze Zahl 0-65535 nach DE (Nachkomma-
;  stellen werden abgeschnitten). Negativ oder >= 65536: Sprung zur
;  Inline-Adresse.
; <- aufgerufen von 20A5h, 229Ah
VAL2UINT:
        PUSH    HL
        LD      HL,(VALSP)
        LD      DE,0000h
        LD      A,(HL)
        OR      A
        JP      P,JP_INL_POP
        CP      0C1h
        JR      C,V2U_RET
        SUB     0D1h
        JP      NC,JP_INL_POP
        LD      E,03h
        ADD     HL,DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        JR      V2U_LP
V2U_SHR:
        SRL     D
        RR      E
V2U_LP: INC     A
        JR      NZ,V2U_SHR
V2U_RET:
        JP      RET_SKIP2_POP
;  NUMSTR_EVAL – besteht der Rest der Zeile ab HL nur aus Zeichen einer
;  Zahl (Ziffern, ".", "+", "-", "E"), wird sie mit EVAL ausgewertet und
;  hinter das Inline-Wort zurückgekehrt; sonst (auch bei leerem Rest)
;  Sprung zur Inline-Adresse.
; <- aufgerufen von 2A62h, 416Bh, 6136h
NUMSTR_EVAL:
        CALL    CHK_CHR_ALT
D1C40:  DEFB    0Dh                     ; Inline-Parameter
D1C41:  DEFW    NUMSTR_CHK
        JP      JP_INLINE
; <- aufgerufen von 1C3Dh
NUMSTR_CHK:
        PUSH    HL
        DEC     HL
NUMSTR_LP:
        CALL    NUMCHR_INC
        JR      Z,NUMSTR_LP
        CP      0Dh
        JP      NZ,JP_INL_POP
        POP     HL
        CALL    EVAL
        JP      RET_SKIP2
; <- aufgerufen von 1C48h
NUMCHR_INC:
        CALL    SKIPSP_INC
        CP      45h                     ; 'E'
        RET     Z
;  NUMCHR – Z bzw. C, wenn (HL) zu einer Zahl gehören kann.
; <- aufgerufen von 2742h
NUMCHR: CALL    ISDIGIT
        JR      NC,NUMCHR_SIGN
        CP      (HL)
        RET
NUMCHR_SIGN:
        CP      2Eh                     ; '.'
        RET     Z
        CP      2Bh                     ; '+'
        RET     Z
        CP      2Dh                     ; '-'
        RET
;  CHK_DIRECT – nur im Direktmodus erlaubt, CHK_NODIRECT – nur im
;  Programm erlaubt; sonst Fehler 19.
; <- aufgerufen von 1E93h, 2C5Bh, 2CBCh, 2DDEh, 41DAh, 436Eh, 474Ch, 4FEAh
CHK_DIRECT:
        PUSH    HL
        CALL    IS_DIRECT
        POP     HL
        RET     Z
        JR      ERR_MODE
; <- aufgerufen von 1F43h, 1F5Bh, 210Bh, 213Ch, 2282h, 22E5h, 2465h, 3F75h (+7 weitere)
CHK_NODIRECT:
        PUSH    HL
        CALL    IS_DIRECT
        POP     HL
        RET     NZ
ERR_MODE:
        JP      ERR_19
; <- aufgerufen von 14F3h, 1533h, 1C70h, 1C78h, 1D8Ah
IS_DIRECT:
        LD      HL,(CURLNUM)
        LD      A,H
        OR      L
        RET
;  RELINK_NEW: ist das Flag gesetzt, ersetzt RELINK das Programm durch ein
;  leeres (PROG_NEW). Gefunden wird nur das Zurücksetzen auf 0 (LOAD).
RELINK_NEW:
        DEFB    00h                     ; ?? |.|
;  RELINK – relative Links (Dateiformat, Satzlänge) in absolute Adressen
;  umrechnen; bereits absolute Links bleiben (Link > Zeilenadresse).
; <- aufgerufen von 14F0h, 4303h, 43C1h, 5179h
RELINK: LD      HL,RELINK_NEW
        XOR     A
        CP      (HL)
        LD      (HL),A
        JR      NZ,PROG_NEW
; <- aufgerufen von 5001h
RELINK_ALL:
        LD      HL,PRGTXT
RELINK_LP:
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        DEC     HL
        LD      A,E
        OR      D
        RET     Z
        CALL    CPHLDE
        RET     C
        EX      DE,HL
        ADD     HL,DE
        EX      DE,HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        EX      DE,HL
        JR      RELINK_LP
;  PROG_DEL – das ganze Programm entfernen (MEMDEL_ADJ).
;  PROG_NEW – Programm entfernen, Variablen und Zeiger zurücksetzen.
; <- aufgerufen von 1CB6h, 43DFh
PROG_DEL:
        LD      HL,(PRGEND)
        LD      DE,PRGTXT
        DEC     HL
        DEC     HL
        XOR     A
        SBC     HL,DE
        LD      B,H
        LD      C,L
        JP      MEMDEL_ADJ
; <- aufgerufen von 1CCCh, 4272h
PROG_NEW:
        CALL    PROG_DEL
        CALL    CLR_AREAS
        CALL    CLEARVARS
        CALL    INITVARPTR
        RET
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        PUSH    BC
        CALL    PROG_NEW
        POP     BC
        LD      A,B
        OR      A
        JR      NZ,PROG_MKROOM
        LD      A,C
        CP      03h
        RET     C
PROG_MKROOM:
        PUSH    BC
        DEC     BC
        DEC     BC
        LD      DE,PRGTXT
        CALL    MEMINS_ADJ
        POP     BC
        RET
;  UNLINK – absolute Links in relative (Satzlänge) umrechnen, vor dem
;  Speichern. Gegenstück zu RELINK.
; <- aufgerufen von 43ACh, 4FFAh, 5172h
UNLINK: LD      HL,PRGTXT
UNLINK_LP:
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        DEC     HL
        LD      A,D
        OR      E
        RET     Z
        CALL    CPHLDE
        RET     NC
        PUSH    DE
        EX      DE,HL
        XOR     A
        SBC     HL,DE
        EX      DE,HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        POP     HL
        JR      UNLINK_LP

; ------------------------------------------------------------------------------
;  Interpreterschleife
;  NEXTSTMT: nach ":" weiter oder nächste Zeile; prüft SRQ der
;  GP-IB-Karte (ON SRQ), BREAK und die Tasten. DISPATCH: Token
;  80h,80h+n -> STMT_TAB[n]; kein Token -> LET.
; ------------------------------------------------------------------------------
; <- aufgerufen von 2275h
NEXTSTMT:
        LD      HL,(TXTPTR)
; <- aufgerufen von 23A0h, 641Fh
NEXTSTMT_HL:
        CALL    SKIPSP                  ; Anweisungsende?
NS_CHKEND:
        CP      0Dh
        JR      Z,NEXTLINE
        CALL    SYNCHK                  ; sonst muss ":" folgen
D1D0A:  DEFB    3Ah                     ; Inline-Parameter ':'
        JR      EXECSTMT
NEXTLINE:
        LD      HL,(CURLINE)            ; Zeilenende: Link der aktuellen Zeile
        LD      A,H
        OR      L
        JP      Z,BAS_READY
;  NL_SRQ – bei ON SRQ und gesetzter SRQ-Leitung wird stattdessen die
;  Programmzeile ab der Adresse in SRQ_LINE fortgesetzt.
;  Link 0 (Programmende) -> END_PRG.
NL_SRQ: LD      A,(SRQ_ON)               ; ON SRQ aktiv?
        OR      A
        JR      Z,NL_NEXT
        IN      A,(GP_C0)               ; SRQ-Leitung der GP-IB-Karte
        BIT     2,A
        JR      Z,NL_NEXT
        XOR     A
        LD      (SRQ_ON),A
        LD      HL,(SRQ_LINE)
NL_NEXT:
        LD      A,(HL)
        INC     HL
        OR      (HL)
        DEC     HL
        JP      Z,END_PRG
        LD      DE,CURLINE              ; Link + Zeilennummer nach CURLINE
        LD      BC,0004h
        LDIR
EXECSTMT:
        LD      (TXTPTR),HL
; <- aufgerufen von 133Fh
EXECSTMT2:
        LD      A,(ONERR_FLAG)
        DEC     A
        CALL    Z,ERRCTX_SAVE
        CALL    BRKCHK                  ; BREAK?
        JR      NZ,DISPATCH
        IN      A,(PIO_AD)
        AND     0E0h
        OR      1Bh
        OUT     (PIO_AD),A
        IN      A,(PIO_BD)
        IN      A,(PIO_BD)
        AND     04h
        JR      NZ,DISPATCH
        LD      A,02h                   ; Position für CONT sichern
        CALL    CONT_POS
        JP      BREAK
DISPATCH:
        LD      HL,(P_STRTMP)
        CALL    CLRWORD
        LD      (VALSP),HL
        CALL    GETTXT                  ; Zeichen am Textzeiger
DISP_TOKEN:
        SUB     80h                     ; kein Token (< 80h) -> LET
        JP      C,ST_LET
        INC     HL
        LD      C,(HL)                  ; zweites Tokenbyte
        INC     HL
        PUSH    HL
        LD      HL,STMT_TAB             ; Tabellenbasis
        JP      NZ,ERR_01               ; erstes Byte muss genau 80h sein
        LD      A,C
        ADD     A,80h                   ; zweites Byte 80h..FFh -> Index 0..7Fh
        JP      NC,ERR_01
        LD      C,A
;  JPTAB – Eintrag C der Sprungtabelle HL anspringen (Adresse liegt
;  vorher als Rücksprung auf dem Stack). Auch für FUNC_TAB benutzt.
JPTAB:  LD      B,00h
        ADD     HL,BC
        ADD     HL,BC
        LD      A,(HL)
        INC     HL
        LD      H,(HL)
        LD      L,A
        EX      (SP),HL                 ; Handler-Adresse als Rücksprung auf den Stack ...
        RET                             ; ... und anspringen
;  ERRCTX_SAVE – im Programmmodus CURLINE, CURLNUM und TXTPTR nach
;  ERRCTX_* sichern (vor jeder Anweisung, solange ONERR_FLAG = 1).
;  ERRCTX_COPY: mit Z die Richtung umkehren (RESUME stellt so zurück).
; <- aufgerufen von 1D3Eh
ERRCTX_SAVE:
        CALL    IS_DIRECT
        RET     Z
ERRCTX_COPY:
        LD      DE,ERRCTX_LINK
        LD      HL,CURLINE
        JR      NZ,ERRCTX_MOVE
        EX      DE,HL
ERRCTX_MOVE:
        LD      BC,0006h
        LDIR
        RET

; ------------------------------------------------------------------------------
;  STMT_TAB – Sprungtabelle der Anweisungen (100 Einträge)
;  Freie Plätze zeigen auf ERR_01 (Syntax-Fehler).
; ------------------------------------------------------------------------------
STMT_TAB:
        DEFW    ST_REM                  ; Token 80h,80h: REM
        DEFW    ST_REM                  ; Token 80h,81h: DATA
        DEFW    ST_DEFKEY               ; Token 80h,82h: DEF KEY(
        DEFW    ERR_01                  ; Token 80h,83h: (frei) -> Syntax Error
        DEFW    ST_READ                 ; Token 80h,84h: READ
        DEFW    ST_LIST                 ; Token 80h,85h: LIST
        DEFW    ST_RUN                  ; Token 80h,86h: RUN
        DEFW    ST_NEW                  ; Token 80h,87h: NEW
        DEFW    ST_PRINT                ; Token 80h,88h: PRINT
        DEFW    ST_LET                  ; Token 80h,89h: LET
        DEFW    ST_FOR                  ; Token 80h,8Ah: FOR
        DEFW    ST_IF                   ; Token 80h,8Bh: IF
        DEFW    ERR_01                  ; Token 80h,8Ch: THEN
        DEFW    ST_GOTO                 ; Token 80h,8Dh: GOTO
        DEFW    ST_GOSUB                ; Token 80h,8Eh: GOSUB
        DEFW    ST_RETURN               ; Token 80h,8Fh: RETURN
        DEFW    ST_NEXT                 ; Token 80h,90h: NEXT
        DEFW    ST_STOP                 ; Token 80h,91h: STOP
        DEFW    ST_END                  ; Token 80h,92h: END
        DEFW    ST_ONERR                ; Token 80h,93h: ON ERROR GOTO
        DEFW    ST_ON                   ; Token 80h,94h: ON
        DEFW    ST_LOAD                 ; Token 80h,95h: LOAD
        DEFW    ST_SAVE                 ; Token 80h,96h: SAVE
        DEFW    ST_VERIFY               ; Token 80h,97h: VERIFY
        DEFW    ST_POKE                 ; Token 80h,98h: POKE
        DEFW    ST_DIM                  ; Token 80h,99h: DIM
        DEFW    ST_DEFFN                ; Token 80h,9Ah: DEF FN
        DEFW    ST_INPUT                ; Token 80h,9Bh: INPUT
        DEFW    ST_RESTORE              ; Token 80h,9Ch: RESTORE
        DEFW    ST_CLR                  ; Token 80h,9Dh: CLR
        DEFW    ST_MUSIC                ; Token 80h,9Eh: MUSIC
        DEFW    ST_TEMPO                ; Token 80h,9Fh: TEMPO
        DEFW    ST_USR                  ; Token 80h,A0h: USR(
        DEFW    ST_WOPEN                ; Token 80h,A1h: WOPEN
        DEFW    ST_ROPEN                ; Token 80h,A2h: ROPEN
        DEFW    ST_CLOSE                ; Token 80h,A3h: CLOSE
        DEFW    ST_MON                  ; Token 80h,A4h: MON
        DEFW    ST_LIMIT                ; Token 80h,A5h: LIMIT
        DEFW    ST_CONT                 ; Token 80h,A6h: CONT
        DEFW    ST_GET                  ; Token 80h,A7h: GET
        DEFW    ST_INPAT                ; Token 80h,A8h: INP@
        DEFW    ST_OUTAT                ; Token 80h,A9h: OUT@
        DEFW    ST_CURSOR               ; Token 80h,AAh: CURSOR
        DEFW    ST_SET                  ; Token 80h,ABh: SET
        DEFW    ST_RESET                ; Token 80h,ACh: RESET
        DEFW    ST_LINE                 ; Token 80h,ADh: LINE
        DEFW    ST_BLINE                ; Token 80h,AEh: BLINE
        DEFW    ST_CONSOLE              ; Token 80h,AFh: CONSOLE
        DEFW    ST_GRAPH                ; Token 80h,B0h: GRAPH
        DEFW    ST_POSITION             ; Token 80h,B1h: POSITION
        DEFW    ST_PATTERN              ; Token 80h,B2h: PATTERN
        DEFW    ST_AUTO                 ; Token 80h,B3h: AUTO
        DEFW    ST_APPEND               ; Token 80h,B4h: APPEND
        DEFW    ST_IMAGEP               ; Token 80h,B5h: IMAGE/P
        DEFW    ST_COPYP                ; Token 80h,B6h: COPY/P
        DEFW    ST_PAGEP                ; Token 80h,B7h: PAGE/P
        DEFW    ERR_01                  ; Token 80h,B8h: (frei) -> Syntax Error
        DEFW    ST_BOOT                 ; Token 80h,B9h: BOOT
        DEFW    ST_KLIST                ; Token 80h,BAh: KLIST
        DEFW    ST_CHANGE               ; Token 80h,BBh: CHANGE
        DEFW    ERR_01                  ; Token 80h,BCh: (frei) -> Syntax Error
        DEFW    ERR_01                  ; Token 80h,BDh: (frei) -> Syntax Error
        DEFW    ST_REW                  ; Token 80h,BEh: REW
        DEFW    ST_FAST                 ; Token 80h,BFh: FAST
        DEFW    ST_DIR                  ; Token 80h,C0h: DIR
        DEFW    ST_DELETE               ; Token 80h,C1h: DELETE
        DEFW    ST_SWAP                 ; Token 80h,C2h: SWAP
        DEFW    ST_KILL                 ; Token 80h,C3h: KILL
        DEFW    ST_RENAME               ; Token 80h,C4h: RENAME
        DEFW    ST_LOCK                 ; Token 80h,C5h: LOCK
        DEFW    ST_CHAIN                ; Token 80h,C6h: CHAIN
        DEFW    ST_UNLOCK               ; Token 80h,C7h: UNLOCK
        DEFW    ST_RESUME               ; Token 80h,C8h: RESUME
        DEFW    ST_XOPEN                ; Token 80h,C9h: XOPEN
        DEFW    ERR_01                  ; Token 80h,CAh: (frei) -> Syntax Error
        DEFW    ST_SSRQ                 ; Token 80h,CBh: SSRQ
        DEFW    ST_GPIB                 ; Token 80h,CCh: GPIB
        DEFW    ST_PPC                  ; Token 80h,CDh: PPC
        DEFW    ST_PPOL                 ; Token 80h,CEh: PPOL
        DEFW    ST_PPU                  ; Token 80h,CFh: PPU
        DEFW    ST_REN                  ; Token 80h,D0h: REN
        DEFW    ST_ICL                  ; Token 80h,D1h: ICL
        DEFW    ST_LCL                  ; Token 80h,D2h: LCL
        DEFW    ST_CMD                  ; Token 80h,D3h: CMD
        DEFW    ST_WRT                  ; Token 80h,D4h: WRT
        DEFW    ST_RED                  ; Token 80h,D5h: RED
        DEFW    ST_SRQ                  ; Token 80h,D6h: SRQ
        DEFW    ST_SPOL                 ; Token 80h,D7h: SPOL
        DEFW    ST_LLO                  ; Token 80h,D8h: LLO
        DEFW    ST_DCL                  ; Token 80h,D9h: DCL
        DEFW    ERR_01                  ; Token 80h,DAh: (frei) -> Syntax Error
        DEFW    ST_TRG                  ; Token 80h,DBh: TRG
        DEFW    ST_PCT                  ; Token 80h,DCh: PCT
        DEFW    ST_RDS                  ; Token 80h,DDh: RDS
        DEFW    ST_RQSMSG               ; Token 80h,DEh: RQSMSG=
        DEFW    ST_EOI                  ; Token 80h,DFh: EOI
        DEFW    ST_RSO                  ; Token 80h,E0h: RSO
        DEFW    ST_RSI                  ; Token 80h,E1h: RSI
        DEFW    ST_RSMODE               ; Token 80h,E2h: RSMODE
        DEFW    ERR_01                  ; Token 80h,E3h: (frei) -> Syntax Error

; ==============================================================================
;  ANWEISUNGEN, AUSDRUCKSAUSWERTUNG, STRINGFUNKTIONEN
; ==============================================================================
;  CHK_EOS – Anweisungsende (":" oder 0Dh) erzwingen, sonst Fehler 1;
;  TXTPTR auf das Ende setzen.
; <- aufgerufen von 1F53h, 1F7Fh, 2111h, 22D6h, 4225h, 438Ah, 4401h, 4592h (+5 weitere)
CHK_EOS:
        CALL    CHRGET
        JP      NZ,ERR_01
        LD      (TXTPTR),HL
        RET
ST_REM: CALL    SKIPSTMT
        JP      NEXTSTMT_HL
;  NEW – CONT sperren, Programm und Variablen löschen, "Ready".
ST_NEW: XOR     A
        LD      (CONT_FLAG),A
        CALL    CLEARALL
NEW_READY:
        JP      BAS_READY
LIST_CNT:
        DEFB    00h                     ; ?? |.|
;  LIST[/P] [a][-[b]] – Programmzeilen a bis b listen (/P: Drucker).
;  Nur im Direktmodus. Bereich in 6CB3h/6CB5h (Vorgabe 0-65535).
;  Jede Zeile wird nach TOKLINE kopiert und mit LISTLINE nach INBUF
;  gewandelt. Bildschirm: nach den ersten 10 Zeilen kurze Pause pro Zeile
;  (LIST_DELAY); solange die Taste mit Code FDh an PIO_BD gedrückt ist,
;  wird angehalten; BREAK bricht ab.
;  LIST_DEV: Operand = 1 bei LIST/P (selbstverändernd).
ST_LIST:
        XOR     A
        LD      (LIST_DEV+1),A
        CALL    CHK_CHR_ALT
D1E87:  DEFB    2Fh                     ; Inline-Parameter '/'
D1E88:  DEFW    LIST_GO
        CALL    SYNCHK
D1E8D:  DEFB    50h                     ; Inline-Parameter 'P'
        LD      A,01h
        LD      (LIST_DEV+1),A
; <- aufgerufen von 1E84h
LIST_GO:
        CALL    CHK_DIRECT
        XOR     A
        OUT     (GRPH),A
        LD      A,0Ah
        LD      (LIST_CNT),A
        PUSH    HL
        LD      HL,6CB3h
        CALL    CLRWORD
        DEC     A
        CALL    CLRWORD_A
        POP     HL
        CALL    CHRGET
        CALL    NZ,LIST_RANGE
        LD      (TXTPTR),HL
        LD      HL,PRGTXT
LIST_LINE:
        PUSH    HL
        CALL    GETLINK
        POP     HL
LIST_CHKEND:
        JR      Z,NEW_READY
        CALL    LINESIZE
        LD      DE,TOKLINE
        LDIR
        LD      HL,(6CB3h)
        EX      DE,HL
        LD      HL,(TOKLNUM)
        CALL    CPHLDE
        JR      C,LIST_NEXT
        EX      DE,HL
        LD      HL,(6CB5h)
        CALL    CPHLDE
        JR      C,LIST_NEXT
        CALL    LISTLINE
        LD      DE,INBUF
LIST_DEV:
        LD      A,0FFh
        OR      A
        JR      Z,LIST_SCR
        CALL    PRN_EOLCHK
        CALL    PRN_LINE
        CALL    PRN_CRLF
        JR      LIST_BRK
LIST_SCR:
        CALL    MSGX
        LD      A,(LIST_CNT)
        DEC     A
        LD      (LIST_CNT),A
        CALL    Z,LIST_DELAY
LIST_BRK:
        CALL    BRKCHK
        JR      Z,LIST_CHKEND
LIST_HOLD:
        IN      A,(PIO_BD)
        CP      0FDh
        JR      Z,LIST_HOLD
LIST_NEXT:
        LD      HL,(TOKLINE)
        JR      LIST_LINE
; <- aufgerufen von 1EFAh
LIST_DELAY:
        INC     A
        LD      (LIST_CNT),A
        PUSH    BC
        LD      BC,2000h
LIST_DLY_LP:
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,LIST_DLY_LP
        POP     BC
        RET
; <- aufgerufen von 1EADh
LIST_RANGE:
        CALL    GETLNUM_SN
        LD      (6CB3h),DE
        CALL    CHRGET
        JR      Z,LIST_TO
        CALL    SYNCHK
D1F2B:  DEFB    2Dh                     ; Inline-Parameter '-'
        CALL    CHRGET
        RET     Z
        CALL    GETLNUM_SN
LIST_TO:
        LD      (6CB5h),DE
        CALL    CHRGET
        RET     Z
        JP      ERR_01
;  END – Programm beenden (CONT_POS mit A=1, CONT möglich).
;  END_PRG: Ende des Programmtextes erreicht.
;  END_SWAP: Operand <> 0, solange ein mit SWAP geladenes Programm läuft;
;  dann geht es bei SWAP_BACK zurück ins aufrufende Programm.
ST_END: XOR     A
        DEFB    01h                     ; Trick: Opcode 01h verschluckt den folgenden Befehl
END_PRG:
        LD      A,01h
        EX      AF,AF'
        CALL    CHK_NODIRECT
END_SWAP:
        LD      A,00h
        OR      A
        JP      NZ,SWAP_BACK
        EX      AF,AF'
        OR      A
        CALL    Z,STOP_SAVE
        JR      STOP_READY
; <- aufgerufen von 1F4Eh, 1F5Eh
STOP_SAVE:
        CALL    CHK_EOS
        LD      A,01h
        JP      CONT_POS
;  STOP – wie END, gibt zusätzlich "*STOP IN zeile" aus.
ST_STOP:
        CALL    CHK_NODIRECT
        CALL    STOP_SAVE
        LD      HL,(CURLNUM)
        LD      DE,MSG_STOPIN
        CALL    PRTSTR
        CALL    PRTNUM
        CALL    PRTSTR
STOP_READY:
        JP      BAS_READY
MSG_STOPIN:
        DEFB    "*STOP IN",0Dh
;  RESTORE [zeile] – READ beginnt beim ersten DATA bzw. ab der Zeile.
ST_RESTORE:
        CALL    GETLNUM_SN
        CALL    CHK_EOS
        LD      BC,NEXTSTMT
        PUSH    BC
        LD      A,D
        OR      E
        JP      Z,DATA_RESET
        LD      BC,DATA_SRCH_FROM
        PUSH    BC
;  GOTO_DE/GOTO_HL – Zeile DE bzw. HL suchen; fehlt sie: Fehler 16.
; <- aufgerufen von 2114h, 2321h, 61DAh
GOTO_DE:
        EX      DE,HL
; <- aufgerufen von 20E2h
GOTO_HL:
        CALL    FINDLINE
D1F93:  DEFW    ERR_16
        RET     Z
        JP      ERR_16
;  LET var = ausdruck (auch ohne LET). Erst wird hinter dem "=" der
;  Ausdruck ausgewertet, dann die Variable bestimmt und zugewiesen.
ST_LET: PUSH    HL
LET_FINDEQ:
        CALL    CHRGET
        JP      Z,ERR_01
        CP      3Dh                     ; '='
        INC     HL
        JR      NZ,LET_FINDEQ
        CALL    EVAL_EXPR
        LD      (TXTPTR),HL
        CALL    SAVEPAR0
        POP     HL
        CALL    GETNAME_SN
        CALL    GETVAR
        CALL    SYNCHK
D1FB8:  DEFB    3Dh                     ; Inline-Parameter '='
        CALL    SAVEPAR1
        CALL    ASSIGN
D1FBF:  DEFW    ERR_04
        JP      NEXTSTMT
;  SAVEPAR0/SAVEPAR1 – BC und DE (Wert bzw. Variable: D = Typ) nach
;  6B00h bzw. 6B04h sichern; ASSIGN liest beides.
; <- aufgerufen von 1FABh, 2BB0h, 412Ch, 4170h, 60F9h, 613Bh
SAVEPAR0:
        LD      HL,6B00h
        JR      SAVEPAR_HL
; <- aufgerufen von 1FB9h, 2B98h, 2C9Eh, 413Bh, 6108h, 6236h, 627Ah, 62FFh
SAVEPAR1:
        LD      HL,6B04h
; <- aufgerufen von 4C60h
SAVEPAR_HL:
        LD      (HL),C
        INC     HL
        LD      (HL),B
        INC     HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        RET
;  ASSIGN – Wert (6B00h) der Variablen (6B04h) zuweisen. Typen ungleich:
;  Sprung zur Inline-Adresse. Zahl: 5 Bytes kopieren. String: Platz der
;  Variablen an die neue Länge anpassen und Text kopieren. Variable TI$
;  (TI_STR): Wert "hhmmss" prüfen und die Uhr stellen (ASG_TI).
; <- aufgerufen von 1FBCh, 2BB3h, 413Eh, 610Bh
ASSIGN: LD      HL,6B03h
        LD      B,(HL)
        INC     HL
        LD      C,(HL)
        INC     HL
        LD      A,(HL)
        LD      DE,(6B06h)
        OR      A
        JR      NZ,ASG_STR
        OR      B
        JP      NZ,JP_INLINE
        CALL    VAL_GET
        JR      ASG_DONE
ASG_STR:
        XOR     A
        OR      B
        JP      Z,JP_INLINE
        LD      HL,TI_STR
        XOR     A
        LD      B,A
        SBC     HL,DE
        JR      Z,ASG_TI
        LD      HL,(6B00h)
        XOR     A
        SBC     HL,BC
ASG_RESIZE:
        LD      B,H
        LD      C,L
        JR      C,ASG_SHRINK
        CALL    MEMINS
        JR      ASG_COPY
ASG_SHRINK:
        PUSH    BC
        CALL    NEGBC
        CALL    MEMDEL
        POP     BC
ASG_COPY:
        CALL    ADJ_PTRS
        LD      HL,(6B02h)
        EX      DE,HL
        CALL    GETSTR_E
        EX      DE,HL
        DEC     DE
        DEC     HL
        INC     BC
        LDIR
ASG_DONE:
        JP      RET_SKIP2
;  TI_STR: Puffer für TI$ ("hh", "mm", "ss" je mit 0Dh).
TI_STR: DEFB    00h,00h                 ; ?? |..|
TI_STR2:
        DEFB    00h,00h,00h,00h,00h,00h,00h  ; ?? |.......|
ASG_TI: LD      HL,(6B02h)
        EX      DE,HL
        CALL    GETSTR
        EX      DE,HL
        LD      DE,TI_STR
        PUSH    DE
        LD      B,03h
ASG_TI_PAIR:
        LD      C,02h
ASG_TI_DIG:
        CALL    ISDIGIT
        JR      NC,ASG_TI_CHK
        LD      (DE),A
        INC     DE
        INC     HL
        DEC     C
        JR      NZ,ASG_TI_DIG
        LD      A,0Dh
        LD      (DE),A
        INC     DE
        DEC     B
        JR      NZ,ASG_TI_PAIR
        CALL    CHK_CHR_ALT
D2052:  DEFB    0Dh                     ; Inline-Parameter
D2053:  DEFW    ERR_03
        POP     HL
        CALL    EVAL_INT
        LD      B,00h
        LD      A,E
        CP      18h
        JR      NC,ASG_TI_CHK
        SUB     0Ch
        JR      C,ASG_TI_HMS
        LD      E,A
        INC     B
ASG_TI_HMS:
        LD      A,B
        PUSH    AF
        PUSH    HL
        LD      HL,0E10h
        CALL    MUL16_ERR
        POP     HL
        PUSH    DE
        INC     HL
        CALL    EVAL_INT
        LD      A,E
        CP      3Ch                     ; '<'
        JR      NC,ASG_TI_CHK
        PUSH    HL
        LD      HL,003Ch
        CALL    MUL16_ERR
        POP     HL
        EX      (SP),HL
        ADD     HL,DE
        EX      (SP),HL
        INC     HL
        CALL    EVAL_INT
        LD      A,E
        CP      3Ch                     ; '<'
ASG_TI_CHK:
        JR      NC,ERR_RANGE
        POP     HL
        ADD     HL,DE
        EX      DE,HL
        POP     AF
        CALL    TIMER_SET
        JP      RET_SKIP2
;  EVAL_INT – Ausdruck auswerten, als ganze Zahl 0-65535 nach DE
;  (sonst Fehler 3, String: Fehler 4). Der Wertestack bleibt unverändert.
;  EVAL_BYTE – dasselbe, Wert 0-255.
; <- aufgerufen von 2056h, 2072h, 2086h, 20B7h, 2AF9h, 2B0Bh, 2D07h, 3D22h (+7 weitere)
EVAL_INT:
        EXX
        LD      BC,0005h
        CALL    VALSP_ADD
        CALL    EVAL
        CALL    CHKSTRTYPE
        CALL    VAL2UINT
D20A8:  DEFW    ERR_03
        EXX
        LD      BC,0FFFBh
; <- aufgerufen von 209Ch
VALSP_ADD:
        LD      HL,(VALSP)
        ADD     HL,BC
        LD      (VALSP),HL
        EXX
        RET
; <- aufgerufen von 23C1h, 2441h, 253Ah, 29B2h, 29D6h, 29FEh, 2ABCh, 2AE3h (+22 weitere)
EVAL_BYTE:
        CALL    EVAL_INT
        LD      A,D
        OR      A
        RET     Z
ERR_RANGE:
        JP      ERR_03
;  RUN [zeile] / RUN "datei" – SWAP-/Lade-/SRQ-Zustände zurücksetzen, READ
;  und CONT zurücksetzen. Mit Zeilennummer: Start dort (über GOTO, Variablen
;  bleiben); ohne Argument: Variablen löschen und von vorn; sonst Datei
;  laden und starten (RUN_LOAD -> LOAD_FD).
ST_RUN: XOR     A
        LD      (END_SWAP+1),A
        LD      (SWAP_ACTIVE),A
        LD      (CHAIN_MODE),A
RUN_CLR:
        LD      (TFILE_MODE),A
        LD      (SRQ_ON),A
        CALL    SKIPCOMMA
        CALL    DATA_RESET
        CALL    CONT_CLR
        CALL    ISDIGIT
        JR      NC,RUN_ARGS
;  GOTO zeile – auch Ziel von THEN zeile, ON ... GOTO und RESUME zeile.
ST_GOTO:
        CALL    GETLNUM_SN
GOTO_LNUM:
        EX      DE,HL
GOTO_LNUM2:
        CALL    GOTO_HL
        JR      RUN_GO
RUN_ARGS:
        CALL    CHRGET
        JR      NZ,RUN_LOAD
RUN_START:
        CALL    CLR_ONERR
        XOR     A
        LD      (END_SWAP+1),A
        CALL    INITVARPTR
        CALL    CLR_AREAS
        CALL    CLEARVARS
        LD      HL,PRGTXT
RUN_GO: JP      NL_SRQ
RUN_LOADFLG:
        DEFB    00h                     ; ?? |.|
RUN_LOAD:
        LD      A,01h
        LD      (RUN_LOADFLG),A
        JP      LOAD_FD
;  GOSUB zeile – CURLINE, TXTPTR und FOR_CNT (7 Bytes) auf den GOSUB-Stack,
;  FOR_CNT = 0 für die neue Ebene. Mehr als 15 Ebenen: Fehler 10.
ST_GOSUB:
        CALL    CHK_NODIRECT
        CALL    GETLNUM_SN
GOSUB_DO:
        CALL    CHK_EOS
        CALL    GOTO_DE
        EXX
        LD      HL,GOSUB_DEPTH
        LD      A,(HL)
        CP      0Fh
        JP      Z,ERR_10
        INC     (HL)
        DEC     HL
        DEC     HL
        LD      DE,(GOSUB_SP)
        DEC     DE
        LD      BC,0007h
        LDDR
        INC     DE
        LD      (GOSUB_SP),DE
        LD      C,07h
        ADD     HL,BC
        LD      (HL),00h
        EXX
        JP      NL_SRQ
;  RETURN – FOR-Einträge der aktuellen Ebene verwerfen, dann CURLINE,
;  TXTPTR und FOR_CNT vom GOSUB-Stack holen. Ohne GOSUB: Fehler 14.
ST_RETURN:
        CALL    CHK_NODIRECT
        LD      HL,GOSUB_DEPTH
        XOR     A
        CP      (HL)
        JP      Z,ERR_14
        DEC     (HL)
RET_DROPFOR:
        LD      HL,FOR_CNT
        LD      A,(HL)
        OR      A
        JR      Z,RET_POP
        DEC     (HL)
        INC     HL
        DEC     (HL)
        LD      HL,(FOR_SP)
        LD      BC,0013h
        ADD     HL,BC
        LD      (FOR_SP),HL
        JR      RET_DROPFOR
RET_POP:
        LD      HL,(GOSUB_SP)
        LD      DE,CURLINE
        LD      BC,0007h
        LDIR
        LD      (GOSUB_SP),HL
        JP      NEXTSTMT
;  FOR var = a TO b [STEP c] – Eintrag in FOR_VAR..FOR_LIMIT aufbauen
;  (STEP fehlt: 1), einen vorhandenen Eintrag derselben Variablen samt
;  allen jüngeren entfernen und 19 Bytes auf den FOR-Stack legen.
;  Mehr als 15 Einträge: Fehler 11.
ST_FOR: CALL    GETNAME_SN
        CALL    SYNCHK
D2175:  DEFB    3Dh                     ; Inline-Parameter '='
        PUSH    DE
        CALL    FOR_EVALNUM
        POP     HL
        LD      (FOR_VAR),HL
        EX      DE,HL
        CALL    NUMVAR
        CALL    VAL_GET
        CALL    SYNCHK_T
D2188:  DEFB    9Eh                     ; Inline-Parameter
        CALL    FOR_EVALNUM
        LD      DE,FOR_LIMIT
        CALL    VAL_GET
        CALL    CHK_CHR_ALT_T
D2195:  DEFB    9Fh                     ; Inline-Parameter
D2196:  DEFW    FOR_STEP1
        CALL    FOR_EVALNUM
        LD      HL,(VALSP)
        JR      FOR_SETSTEP
; <- aufgerufen von 2192h
FOR_STEP1:
        LD      HL,FP_ONE
FOR_SETSTEP:
        LD      DE,FOR_STEP
        LD      A,(HL)
        LD      (FOR_STEPSGN),A
        LD      BC,0005h
        LDIR
        LD      HL,(FOR_SP)
        LD      DE,(FOR_VAR)
        LD      A,(FOR_CNT)
        INC     A
FOR_SRCH:
        DEC     A
        JR      Z,FOR_PUSH
        EX      AF,AF'
        LD      A,(HL)
        SUB     E
        LD      B,A
        INC     HL
        LD      A,(HL)
        SUB     D
        OR      B
        LD      BC,0012h
        ADD     HL,BC
        JR      Z,FOR_DROP
        EX      AF,AF'
        JR      FOR_SRCH
FOR_DROP:
        LD      (FOR_SP),HL
        EX      AF,AF'
        DEC     A
        LD      HL,FOR_CNT
        LD      B,(HL)
        LD      (HL),A
        SUB     B
        INC     HL
        ADD     A,(HL)
        LD      (HL),A
FOR_PUSH:
        LD      HL,FOR_DEPTH
        LD      A,(HL)
        CP      0Fh
        JP      Z,ERR_11
        INC     (HL)
        DEC     HL
        INC     (HL)
        DEC     HL
        LD      DE,(FOR_SP)
        LD      BC,0013h
        DEC     DE
        LDDR
        INC     DE
        EX      DE,HL
        LD      (FOR_SP),HL
        JP      NEXTSTMT
; <- aufgerufen von 2177h, 2189h, 2198h
FOR_EVALNUM:
        CALL    EVAL
        LD      (TXTPTR),HL
        JP      CHKSTRTYPE
;  NEXT [var[,var...]] – passenden FOR-Eintrag suchen (jüngere werden
;  verworfen; keiner: Fehler 13), Schrittweite addieren und je nach
;  Vorzeichen mit dem Endwert vergleichen. Weiter: CURLINE/TXTPTR aus dem
;  Eintrag holen; fertig: Eintrag entfernen, nächste Variable nach ",".
ST_NEXT:
        LD      A,(FOR_CNT)
        OR      A
NEXT_ERR:
        JP      Z,ERR_13
        CALL    GETNAME
        LD      (TXTPTR),HL
        LD      HL,(FOR_SP)
        CALL    NC,NEXT_CURVAR
NEXT_SRCH:
        LD      A,E
        SUB     (HL)
        INC     HL
        LD      B,A
        LD      A,D
        SUB     (HL)
        OR      B
        JR      Z,NEXT_STEP
        EXX
        LD      HL,FOR_CNT
        LD      A,(HL)
        DEC     A
        JR      Z,NEXT_ERR
        LD      (HL),A
        INC     HL
        DEC     (HL)
        EXX
        LD      BC,0012h
        ADD     HL,BC
        LD      (FOR_SP),HL
        JR      NEXT_SRCH
NEXT_STEP:
        INC     HL
        CALL    NUMVAR
        PUSH    DE
        PUSH    HL
        CALL    OP_ADD
        POP     HL
        POP     DE
        LD      BC,0005h
        ADD     HL,BC
        LD      A,(HL)
        INC     HL
        PUSH    HL
        OR      A
        JP      P,NEXT_UP
        EX      DE,HL
        CALL    FP_CMP_BC
        POP     HL
        LD      BC,0005h
        JR      C,NEXT_DONE
NEXT_LOOP:
        ADD     HL,BC
        LD      DE,CURLINE
        INC     C
        LDIR
        JP      NEXTSTMT
NEXT_UP:
        CALL    FP_CMP_BC
        POP     HL
        LD      BC,0005h
        CCF
        JR      C,NEXT_LOOP
NEXT_DONE:
        LD      C,0Bh
        ADD     HL,BC
        LD      (FOR_SP),HL
        LD      HL,FOR_CNT
        DEC     (HL)
        INC     HL
        DEC     (HL)
        CALL    CHK_CHR_ALT_T
D2278:  DEFB    2Ch                     ; Inline-Parameter ','
D2279:  DEFW    NEXTSTMT
        JR      ST_NEXT
; <- aufgerufen von 2214h
NEXT_CURVAR:
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        DEC     HL
        RET
;  ON ausdruck GOTO/GOSUB z1,z2,... – auch ON SRQ (Token 80h,D6h ->
;  ST_SRQ). Wert 0 oder > 255: Rest der Anweisung überspringen; gibt es
;  weniger Ziele als der Wert, geht es mit der nächsten Anweisung weiter.
ST_ON:  CALL    CHK_NODIRECT
        CALL    CHK_CHR_ALT
D2288:  DEFB    80h                     ; Inline-Parameter
D2289:  DEFW    ON_EXPR
        CALL    CHK_CHR_ALT
D228E:  DEFB    0D6h                    ; Inline-Parameter
D228F:  DEFW    ON_EXPR
        JP      ST_SRQ
; <- aufgerufen von 2285h, 228Bh
ON_EXPR:
        CALL    EVAL
        CALL    CHKSTRTYPE
        CALL    VAL2UINT
D229D:  DEFW    ON_KW
; <- aufgerufen von 229Ah
ON_KW:  CALL    SYNCHK
D22A2:  DEFB    80h                     ; Inline-Parameter
        SUB     8Dh
        CP      02h
        JP      NC,ERR_01
        EX      AF,AF'
        INC     HL
        LD      A,E
        OR      A
        JR      Z,ON_SKIP
        LD      A,D
        OR      A
        JR      Z,ON_COUNT
ON_SKIP:
        JP      ST_REM
ON_FINDCOMMA:
        CALL    CHRGET
        JP      Z,NS_CHKEND
        CP      2Ch                     ; ','
        INC     HL
        JR      NZ,ON_FINDCOMMA
ON_COUNT:
        DEC     E
        JR      NZ,ON_FINDCOMMA
        CALL    GETLNUM_SN
        CALL    SKIPSTMT
        EX      AF,AF'
        OR      A
        JP      NZ,GOSUB_DO
        JP      GOTO_LNUM
;  ON ERROR GOTO zeile – Behandler setzen (ONERR_FLAG = 1).
ST_ONERR:
        CALL    GETLNUM_SN
        CALL    CHK_EOS
        LD      HL,ONERR_FLAG
        LD      (HL),01h
        EX      DE,HL
        LD      (ONERR_LINE),HL
        JP      NEXTSTMT
;  RESUME [NEXT | zeile | 0] – nur im Fehlerbehandler (ONERR_FLAG = 2),
;  sonst Fehler 21. Ohne Argument: fehlerhafte Anweisung wiederholen
;  (ERRCTX zurückholen); NEXT: dahinter weiter; zeile: dort weiter;
;  0: ON ERROR abschalten und wie RUN neu starten.
ST_RESUME:
        CALL    CHK_NODIRECT
        LD      A,(ONERR_FLAG)
        CP      02h
        JP      NZ,ERR_21
        CALL    CHRGET
        JR      NZ,RES_NEXT
        LD      BC,EXECSTMT2
        JR      RES_GO
RES_NEXT:
        CALL    CHK_CHR_ALT
D22FD:  DEFB    80h                     ; Inline-Parameter
D22FE:  DEFW    RES_LINE
        CALL    SYNCHK
D2303:  DEFB    90h                     ; Inline-Parameter
        LD      HL,(ERRCTX_TXT)
        CALL    SKIPSTMT
        LD      (ERRCTX_TXT),HL
        LD      BC,NEXTSTMT
RES_GO: PUSH    BC
        LD      A,01h
        LD      (ONERR_FLAG),A
        XOR     A
        JP      ERRCTX_COPY
; <- aufgerufen von 22FAh
RES_LINE:
        CALL    GETLNUM_SN
        LD      A,D
        OR      E
        JR      Z,RES_ZERO
        CALL    GOTO_DE
        LD      A,01h
        LD      (ONERR_FLAG),A
        JP      NL_SRQ
RES_ZERO:
        CALL    CHRGET
        JP      NZ,ERR_01
        CALL    CLR_ONERR
        JP      RUN_START
;  DIM name[$](n[,m])[,...] – höchstens zwei Dimensionen, je 0-255.
;  Ein schon vorhandenes Feld wird übergangen (passen die neuen Grenzen
;  nicht hinein: Fehler 3).
;  Eintrag: Name (2), Dimensionen (2), dann (n+1)*(m+1) Elemente:
;  Zahlen 5 Bytes (0), Strings 2 Bytes (Länge 0, 0Dh).
ST_DIM: CALL    GETNAME_SN
        LD      BC,0000h
        CP      24h                     ; '$'
        JR      NZ,DIM_PAR
        INC     HL
        INC     B
DIM_PAR:
        CALL    SYNCHK
D2347:  DEFB    28h                     ; Inline-Parameter '('
        CALL    ARR_FIND
        JR      NZ,DIM_NEXT
        PUSH    HL
        LD      HL,(ARR_DIMS)
        LD      E,H
        LD      D,A
        LD      H,A
        INC     HL
        INC     DE
        CALL    MUL16
D2359:  DEFW    ERR_06
        LD      A,(ARR_TYPE)
        OR      A
        POP     HL
        PUSH    DE
        PUSH    HL
        LD      HL,0002h
        JR      NZ,DIM_SIZE
        LD      L,05h
DIM_SIZE:
        CALL    MUL16
D236C:  DEFW    ERR_06
        LD      HL,0004h
        ADD     HL,DE
        JP      C,ERR_06
        LD      B,H
        LD      C,L
        POP     DE
        CALL    MEMINS_ADJ
        LD      HL,(LISTKEY+1)
        EX      DE,HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        INC     HL
        LD      DE,(ARR_DIMS)
        LD      (HL),E
        INC     HL
        LD      (HL),D
        INC     HL
        POP     BC
        LD      A,(ARR_TYPE)
        OR      A
        JR      Z,DIM_NUMINIT
DIM_STRINIT:
        LD      (HL),00h
        INC     HL
        LD      (HL),0Dh
        INC     HL
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,DIM_STRINIT
DIM_NEXT:
        LD      HL,(ARR_TXTP)
        CALL    CHK_CHR_ALT
D23A3:  DEFB    2Ch                     ; Inline-Parameter ','
D23A4:  DEFW    NEXTSTMT_HL
        JR      ST_DIM
DIM_NUMINIT:
        EX      DE,HL
DIM_NUM_LP:
        PUSH    BC
        LD      HL,FP_ZERO
        LD      BC,0005h
        LDIR
        POP     BC
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,DIM_NUM_LP
        JR      DIM_NEXT
;  ARR_*: Arbeitswerte von ARR_FIND – Textzeiger hinter ")", Typ (0 Zahl,
;  1 String) und Indizes (E = erster, D = zweiter).
ARR_TXTP:
        DEFB    00h,00h                 ; ?? |..|
ARR_TYPE:
        DEFB    00h                     ; ?? |.|
ARR_DIMS:
        DEFB    00h,00h                 ; ?? |..|
;  ARR_FIND – nach "(" Indizes lesen und Feld suchen (Name in DE, B = Typ).
;  Liste nach Typ und Dimensionszahl aus P_ARRAYS. Nicht gefunden: A = 0, Z.
;  Gefunden: Indizes gegen die Dimensionen prüfen (zu groß: Fehler 3),
;  NZ, HL hinter den Dimensionen.
; <- aufgerufen von 2348h, 28BAh
ARR_FIND:
        PUSH    DE
        PUSH    BC
        CALL    EVAL_BYTE
        POP     BC
        LD      A,(HL)
        CP      2Ch                     ; ','
        CALL    Z,ARR_DIM2
        CALL    SYNCHK
D23CE:  DEFB    29h                     ; Inline-Parameter ')'
        LD      (ARR_TXTP),HL
        POP     HL
        LD      (LISTKEY+1),HL
        EX      DE,HL
        LD      (ARR_DIMS),HL
        LD      A,B
        LD      (ARR_TYPE),A
        LD      HL,P_ARRAYS
        LD      DE,0006h
        OR      A
        JR      Z,ARR_1D
        ADD     HL,DE
ARR_1D: LD      A,C
        LD      E,02h
        OR      A
        JR      NZ,ARR_LIST
        ADD     HL,DE
ARR_LIST:
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
ARR_SRCH:
        CALL    LISTKEY_CMP
D23F6:  DEFW    LKUP_NONE               ; Inline-Parameter: Listenende
        JR      Z,ARR_CHKIDX
        LD      E,(HL)
        INC     HL
        PUSH    HL
        LD      L,(HL)
        LD      D,00h
        LD      H,D
        INC     HL
        INC     DE
        CALL    MUL16_ERR
        LD      A,(ARR_TYPE)
        OR      A
        JR      NZ,ARR_SKIPSTR
        LD      HL,0005h
        CALL    MUL16_ERR
        POP     HL
        ADD     HL,DE
        INC     HL
        JR      ARR_SRCH
ARR_SKIPSTR:
        POP     HL
        INC     HL
        LD      B,00h
ARR_SKS_LP:
        LD      C,(HL)
        INC     HL
        INC     HL
        ADD     HL,BC
        DEC     DE
        LD      A,D
        OR      E
        JR      NZ,ARR_SKS_LP
        JR      ARR_SRCH
LKUP_NONE:
        XOR     A                       ; nicht gefunden: A = 0
        RET
ARR_CHKIDX:
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        INC     HL
        LD      DE,(ARR_DIMS)
        LD      A,B
        CP      D
        JR      C,ARR_IDXERR
        LD      A,C
        CP      E
ARR_IDXERR:
        JP      C,ERR_03
        LD      A,01h
        OR      A
        RET
; <- aufgerufen von 23C8h
ARR_DIM2:
        INC     C
        PUSH    BC
        PUSH    DE
        INC     HL
        CALL    EVAL_BYTE
        LD      A,E
        POP     DE
        LD      D,A
        POP     BC
        RET
;  POKE adresse, wert – Adresse auch als $hex (EVAL_ADDR), Wert 0-255.
ST_POKE:
        CALL    EVAL_ADDR
        CALL    SKIPCOMMA
        PUSH    DE
        CALL    EVAL_ADDR
        LD      A,D
        OR      A
        JP      NZ,ERR_03
        EX      (SP),HL
        LD      (HL),E
        POP     HL
POKE_DONE:
        JP      NEXTSTMT_HL
;  CLR – Variablen, Felder, DEF FN und Strings löschen (CLR_AREAS).
ST_CLR: PUSH    HL
        CALL    CLR_AREAS
        POP     HL
        JR      POKE_DONE
;  IF bedingung THEN zeile | THEN anweisung | GOTO zeile | GOSUB zeile
;  IF EOF(#n) ... – Sonderform für Dateien (GETFILENO/FTAB_FIND, Fehler 44).
;  Bedingung = 0: Rest der Zeile überspringen (IF_FALSE).
ST_IF:  CALL    CHK_NODIRECT
        CALL    CHK_CHR_ALT
D246B:  DEFB    0AEh                    ; Inline-Parameter
D246C:  DEFW    IF_COND
        CALL    GETFILENO
        JP      Z,ERR_01
        LD      B,A
        CALL    CHK_RPAR
        PUSH    HL
        LD      A,B
        CALL    FTAB_FIND
D247D:  DEFW    ERR_44
        LD      BC,0008h
        ADD     HL,BC
        LD      A,(HL)
        POP     HL
        OR      A
        JR      NZ,IF_THEN
IF_FALSE:
        JP      NEXTLINE
; <- aufgerufen von 2468h
IF_COND:
        CALL    EVAL_EXPR
        CALL    CHKSTRTYPE
        LD      IX,(VALSP)
        BIT     7,(IX+4)
        JR      Z,IF_FALSE
IF_THEN:
        CALL    SYNCHK
D249E:  DEFB    80h                     ; Inline-Parameter
        SUB     8Ch
        INC     HL
        CP      02h
        JP      Z,ST_GOSUB
IF_ERR: JP      NC,ERR_01
        OR      A
        CALL    Z,IF_THENNUM
        JP      ST_GOTO
; <- aufgerufen von 24ABh
IF_THENNUM:
        CALL    ISDIGIT
        RET     C
        POP     BC
        JP      DISP_TOKEN
;  DEF FNx(y) = ausdruck – x, y je ein Buchstabe. Der Text hinter "=" wird
;  in die Liste P_DEFFN kopiert (Eintrag: x, y, Text, 0Dh); eine
;  vorhandene Definition wird ersetzt.
ST_DEFFN:
        CALL    SKIPSP
        SUB     41h
        CP      1Ah
        JR      NC,IF_ERR
        LD      E,(HL)
        INC     HL
        CALL    SYNCHK
D24C7:  DEFB    28h                     ; Inline-Parameter '('
        SUB     41h
        CP      1Ah
        JR      NC,IF_ERR
        LD      D,(HL)
        INC     HL
        CALL    SYNCHK
D24D3:  DEFB    29h                     ; Inline-Parameter ')'
        CALL    SYNCHK
D24D7:  DEFB    3Dh                     ; Inline-Parameter '='
        PUSH    HL
        CALL    SKIPSTMT
        POP     BC
        PUSH    HL
        XOR     A
        SBC     HL,BC
        PUSH    BC
        PUSH    HL
        LD      HL,(P_DEFFN)
DEFFN_SRCH:
        LD      A,(HL)
        CP      E
        JR      Z,DEFFN_OLD
        OR      A
        JR      Z,DEFFN_NEW
        INC     HL
        INC     HL
        CALL    SKIPLINE
        JR      DEFFN_SRCH
DEFFN_NEW:
        EX      DE,HL
        LD      BC,0003h
        CALL    MEMINS_ADJ
        EX      DE,HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        INC     HL
        LD      (HL),0Dh
        EX      DE,HL
        JR      DEFFN_COPY
DEFFN_OLD:
        INC     HL
        LD      (HL),D
        INC     HL
        PUSH    HL
        CALL    SKIPSTMT
        POP     DE
        XOR     A
        SBC     HL,DE
        LD      B,H
        LD      C,L
        CALL    MEMDEL_ADJ
DEFFN_COPY:
        POP     BC
        POP     HL
        CALL    MOVEUP
        CALL    ADJ_PTRS
        POP     HL
MUSIC_DONE:
        JP      NEXTSTMT_HL
;  MUSIC s1[,s2...] – Strings nacheinander mit MUSIC_PLAY spielen;
;  BREAK bricht ab.
ST_MUSIC:
        CALL    CHRGET
        JR      Z,MUSIC_DONE
        CALL    EVAL
        CALL    CHRGET
        JR      Z,MUSIC_PLAY1
        INC     HL
MUSIC_PLAY1:
        CALL    GETSTR
        CALL    MUSIC_PLAY
        JP      C,BREAK
        JR      ST_MUSIC
;  TEMPO n – n = 1-7, sonst Fehler 3.
ST_TEMPO:
        CALL    EVAL_BYTE
        LD      A,E
        DEC     A
        CP      07h
        JP      NC,ERR_03
        INC     A
        CALL    TEMPO_SET
        JR      MUSIC_DONE
; <- aufgerufen von 2750h
EVAL_EXPR_INC:
        INC     HL
;  Ausdrucksauswertung (Rangfolge von unten nach oben):
;  EVAL_EXPR  Vergleiche (Token 83h-8Bh, "=" -> 89h); Strings über STRCMP
;  EVAL       + und - (Strings: + verkettet, > 255 Zeichen: Fehler 5)
;  TERM       * und /
;  POWER      ^
;  PRIMARY    Vorzeichen, Zahl, Variable, FN, "(", String, Funktion, Pi
;  Ergebnis: D = 0 Zahl (Wert bei (VALSP), 5 Bytes), D <> 0 String
;  (E = Nummer, siehe GETSTR). A = nächstes Zeichen.
; <- aufgerufen von 1FA5h, 248Bh, 3CC3h, 54F5h, 6004h, 61AAh, 6734h
EVAL_EXPR:
        CALL    EVAL
EXPR_REL:
        CP      3Dh                     ; '='
        JR      NZ,EXPR_RELTOK
        LD      A,89h
EXPR_RELTOK:
        CP      83h
        RET     C
        CP      90h
        RET     NC
        SUB     83h
        EX      AF,AF'
        LD      A,D
        OR      A
        JR      NZ,EXPR_STRCMP
        EX      AF,AF'
        EXX
        LD      BC,EXPR_REL
        LD      DE,EVAL_INC
        JP      APPLY_OP
EXPR_STRCMP:
        EX      AF,AF'
        PUSH    DE
        PUSH    AF
        CALL    EVAL_INC
        POP     AF
        EX      AF,AF'
        EX      (SP),HL
        CALL    GETSTR
        LD      A,C
        PUSH    AF
        EX      DE,HL
        CALL    GETSTR
        POP     AF
        LD      B,A
        CALL    STRCMP
        LD      HL,STRCMP_RES
        PUSH    HL
        LD      HL,STRCMP_TAB
        EX      AF,AF'
        LD      C,A
        LD      B,00h
        ADD     HL,BC
        ADD     HL,BC
        LD      A,(HL)
        INC     HL
        LD      H,(HL)
        LD      L,A
        EX      AF,AF'
        OR      A
        LD      A,01h
        JP      (HL)
STRCMP_TAB:
        DEFW    SC_NE
        DEFW    SC_NE
        DEFW    SC_LE
        DEFW    SC_LE
        DEFW    SC_GE
        DEFW    SC_GE
        DEFW    SC_EQ
        DEFW    SC_GT
        DEFW    SC_LT
STRCMP_RES:
        LD      DE,FP_MONE
        OR      A
        JR      NZ,STRCMP_PUT
        LD      DE,FP_ZERO
STRCMP_PUT:
        CALL    VAL_PUT
        POP     HL
        CALL    PRIM_RETHL
        JR      EXPR_REL
;  STRCMP – Strings (HL, Länge C) und (DE, Länge B) vergleichen. Liefert
;  die Flags für die Tabelle STRCMP_TAB (Einträge wie FUNC_TAB 0-8).
; <- aufgerufen von 2580h
STRCMP: LD      A,B
        OR      C
        RET     Z
        LD      A,C
        CP      B
        JR      NZ,STRCMP_NE
STRCMP_LP:
        LD      A,(DE)
        SUB     (HL)
        JR      NZ,STRCMP_NE
        INC     HL
        INC     DE
        DJNZ    STRCMP_LP
        RET
STRCMP_NE:
        LD      A,01h
        RET     NC
        LD      A,80h
        RET
SC_NE:  RET     NZ
        XOR     A
        RET
SC_LE:  RET     Z
        RET     M
        XOR     A
        RET
SC_GE:  RET     P
        XOR     A
        RET
SC_EQ:  RET     Z
        XOR     A
        RET
SC_GT:  LD      A,00h
        RET     Z
        RET     M
        LD      A,01h
        RET
SC_LT:  RET     M
        XOR     A
        RET
; <- aufgerufen von 256Fh, 270Eh
EVAL_INC:
        INC     HL
; <- aufgerufen von 1C53h, 209Fh, 21FBh, 2294h, 2526h, 254Bh, 27B7h, 2807h (+13 weitere)
EVAL:   LD      A,(HL)
        CP      20h                     ; ' '
        JR      Z,EVAL_INC
        CP      2Bh                     ; '+'
        JR      Z,EVAL_PLUS
        CP      2Dh                     ; '-'
        JR      NZ,EVAL_TERM1
        CALL    TERM_INC
        CALL    NEG_VAL
        JR      EVAL_ADDOP
EVAL_PLUS:
        INC     HL
EVAL_TERM1:
        CALL    TERM
EVAL_ADDOP:
        CP      2Bh                     ; '+'
        JR      Z,EVAL_ADD
        CP      2Dh                     ; '-'
        RET     NZ
        LD      A,0Dh
        DEFB    01h                     ; Trick: Opcode 01h verschluckt den folgenden Befehl
EVAL_ADD:
        LD      A,0Ch
        EX      AF,AF'
        LD      A,D
        OR      A
        JR      NZ,EVAL_STRCAT
        EX      AF,AF'
        EXX
        LD      BC,EVAL_ADDOP
        LD      DE,TERM_INC
        JR      APPLY_OP
EVAL_STRCAT:
        EX      AF,AF'
        CP      0Ch
        JP      NZ,ERR_01
        PUSH    DE
        CALL    TERM_INC
        EX      (SP),HL
        PUSH    DE
        CALL    GETSTR
        LD      A,C
        PUSH    AF
        EX      DE,HL
        CALL    GETSTR
        POP     AF
        ADD     A,C
        JP      C,ERR_05
        PUSH    AF
        EX      DE,HL
        CALL    MOVEUP
        CALL    ADJ_PTRS
        POP     AF
        LD      C,A
        DEC     DE
        LD      (DE),A
        POP     DE
        POP     HL
        LD      A,(HL)
        JR      EVAL_ADDOP
; <- aufgerufen von 25F8h, 2626h
TERM_INC:
        INC     HL
; <- aufgerufen von 2601h
TERM:   CALL    POWER
TERM_MULOP:
        CP      2Fh                     ; '/'
        JR      Z,TERM_DIV
        CP      2Ah                     ; '*'
        RET     NZ
        LD      A,0Eh
        DEFB    01h                     ; Trick: Opcode 01h verschluckt den folgenden Befehl
TERM_DIV:
        LD      A,0Fh
        EXX
        LD      BC,TERM_MULOP
        LD      DE,TERM_NEXT
        JR      APPLY_OP
TERM_NEXT:
        INC     HL                      ; Fortsetzung nach * /: Operator überspringen, nächste Potenz
; <- aufgerufen von 264Bh
POWER:  CALL    PRIMARY
POWER_OP:
        CP      5Eh                     ; '^'
        RET     NZ
        LD      A,10h
        EXX
        LD      BC,POWER_OP
        LD      DE,POWER_NEXT
;  APPLY_OP – Operator A (Index in FUNC_TAB) anwenden. Linker Wert liegt
;  auf dem Wertestack (VALSP wird um 5 erhöht), DE = Routine für den
;  rechten Operanden, BC = Fortsetzung danach. Beide müssen Zahlen sein
;  (sonst Fehler 4). TERM_NEXT/POWER_NEXT sind solche Fortsetzungen: INC HL
;  überspringt das Operatorzeichen.
APPLY_OP:
        PUSH    BC
        LD      HL,(VALSP)
        LD      BC,0005h
        ADD     HL,BC
        LD      (VALSP),HL
        LD      HL,FUNC_TAB
        LD      C,A
        ADD     HL,BC
        ADD     HL,BC
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        PUSH    BC
        LD      HL,APPLY_CALC
        PUSH    HL
        PUSH    DE
        EXX
        LD      A,D
        OR      A
        RET     Z
APPLY_TYPERR:
        JP      ERR_04
APPLY_CALC:
        LD      A,D
        OR      A
        JR      NZ,APPLY_TYPERR
        POP     IY
        PUSH    HL
        LD      HL,(VALSP)
        LD      BC,0FFFBh
        LD      E,L
        LD      D,H
        ADD     HL,BC
        LD      (VALSP),HL
        EX      DE,HL
        LD      BC,PRIM_RET
        PUSH    BC
        JP      (IY)
PRIM_PUTVAL:
        CALL    VAL_PUT
PRIM_RET:
        POP     HL
; <- aufgerufen von 25B8h
PRIM_RETHL:
        LD      BC,0005h
        LD      D,B
        LD      E,B
        LD      A,(HL)
        RET
POWER_NEXT:
        INC     HL                      ; Fortsetzung nach ^: Operator überspringen, nächster Faktor
;  PRIMARY – ein Operand mit Vorzeichen. Zeichen FFh steht für Pi.
;  Funktions-Token: A0h-B3h über FUNC_TAB ab Eintrag 17 (Argumente liest
;  die Funktion selbst), C0h-CBh über D2993 (Argument wird vorher
;  ausgewertet).
; <- aufgerufen von 2664h
PRIMARY:
        CALL    SKIPSP
        CP      2Bh                     ; '+'
        JR      Z,PRIM_INC
        CP      2Dh                     ; '-'
        JR      NZ,PRIM_NAME
        CALL    PRIM_INC
;  NEG_VAL – Wert bei (VALSP) negieren (Bit 7 des Exponentbytes, 0 bleibt).
; <- aufgerufen von 25FBh
NEG_VAL:
        EXX
        LD      HL,(VALSP)
        PUSH    HL
        LD      BC,0004h
        ADD     HL,BC
        LD      A,(HL)
        POP     HL
        OR      A
        JR      Z,NEG_DONE
        LD      A,(HL)
        ADD     A,80h
        LD      (HL),A
NEG_DONE:
        EXX
        LD      A,(HL)
        RET
; <- aufgerufen von 26C5h
PRIM_INC:
        INC     HL
PRIM_NAME:
        CALL    GETNAME
        JR      NC,PRIM_TOKEN
        LD      A,46h                   ; 'F'
        CP      E
        JR      NZ,PRIM_VAR
        LD      A,4Eh                   ; 'N'
        CP      D
        JP      Z,FN_CALL
PRIM_VAR:
        CALL    GETVAR
        PUSH    HL
        LD      A,B
        OR      A
        JR      Z,PRIM_PUTVAL
        EX      DE,HL
        LD      B,00h
        CALL    STR_STORE
        POP     HL
        LD      A,(HL)
        RET
PRIM_TOKEN:
        CP      80h
        JR      C,PRIM_OTHER
        CP      0FFh
        JR      Z,PRIM_PI
        CP      0C0h
        JR      C,PRIM_FUNC
        SUB     0C0h
        PUSH    AF
        CALL    EVAL_INC
        CALL    CHKSTRTYPE
        CALL    SYNCHK
D2717:  DEFB    29h                     ; Inline-Parameter ')'
        POP     AF
        PUSH    HL
        LD      HL,PRIM_RET
        PUSH    HL
        LD      HL,(VALSP)
        EX      DE,HL
        LD      HL,D2993
        PUSH    HL
        LD      C,A
        JP      JPTAB
PRIM_FUNC:
        SUB     0A0h
        JR      C,PRIM_ERR
        LD      C,A
        CALL    SKIPSP_INC
        PUSH    HL
        LD      HL,FUNC_TAB+2*17
        JP      JPTAB
PRIM_OTHER:
        CP      28h                     ; '('
        JR      Z,PRIM_PAREN
        CP      22h                     ; '"'
        JP      Z,STRLIT
        CALL    NUMCHR
        JR      Z,PRIM_NUM
PRIM_ERR:
        JP      ERR_01
PRIM_PAREN:
        LD      BC,0000h
        CALL    CHKMEM2
        CALL    EVAL_EXPR_INC
        JP      CHK_RPAR
PRIM_NUM:
        LD      DE,(VALSP)
        CALL    STR2NUM
        JP      PRIM_RETHL
PRIM_PI:
        CALL    SKIPSP_INC
        PUSH    HL
        LD      DE,FP_PI
        JP      PRIM_PUTVAL
; <- aufgerufen von 1FB2h, 26EEh, 2B92h, 2BDCh, 2C98h, 4135h, 6102h, 6230h (+2 weitere)
GETVAR: LD      A,(HL)
        CP      24h                     ; '$'
        JP      Z,STRVAR
        CP      28h                     ; '('
        JP      Z,ARR_NUMELEM
;  NUMVAR – Zahlvariable DE (Name) in P_NUMVAR suchen, fehlt sie, wird sie
;  mit Wert 0 angelegt. Zurück: DE = Adresse des Werts, B = 0, C = 5.
; <- aufgerufen von 217Fh, 2236h, 27DBh, 281Ah
NUMVAR: PUSH    HL
        LD      HL,(P_NUMVAR)
        LD      BC,0005h
NUMVAR_LP:
        LD      A,(HL)
        CP      E
        INC     HL
        JR      NZ,NUMVAR_NEXT
        LD      A,(HL)
        CP      D
        JR      Z,NUMVAR_FOUND
NUMVAR_NEXT:
        OR      A
        JR      Z,NUMVAR_NEW
        INC     HL
        ADD     HL,BC
        JR      NUMVAR_LP
NUMVAR_NEW:
        LD      C,07h
        DEC     HL
        PUSH    DE
        EX      DE,HL
        LD      HL,FP_ZERO
        DEC     HL
        DEC     HL
        CALL    MOVEUP
        CALL    ADJ_PTRS
        EX      DE,HL
        POP     DE
        LD      (HL),E
        INC     HL
        LD      (HL),D
        LD      C,05h
NUMVAR_FOUND:
        INC     HL
        EX      DE,HL
        POP     HL
        LD      A,(HL)
        RET
;  FN_CALL – FNx(ausdruck): Definition in P_DEFFN suchen (fehlt: Fehler
;  15), Parametervariable y sichern (FNPAR_SP, 6 Bytes, max. 5 Ebenen,
;  sonst Fehler 12), mit dem Argument belegen, Text auswerten, y
;  zurückholen.
FN_CALL:
        LD      A,(HL)
        SUB     41h
        CP      1Ah
        JP      NC,ERR_01
        LD      E,(HL)
        INC     HL
        CALL    SYNCHK
D27B5:  DEFB    28h                     ; Inline-Parameter '('
        PUSH    DE
        CALL    EVAL
        CALL    CHKSTRTYPE
        CALL    CHK_RPAR
        POP     DE
        PUSH    HL
        LD      HL,(P_DEFFN)
FNC_SRCH:
        LD      A,(HL)
        OR      A
        JP      Z,ERR_15
        CP      E
        JR      Z,FNC_FOUND
        INC     HL
        INC     HL
        CALL    SKIPLINE
        JR      FNC_SRCH
FNC_FOUND:
        INC     HL
        LD      E,(HL)
        INC     HL
        PUSH    HL
        PUSH    DE
        LD      D,20h
        CALL    NUMVAR
        POP     HL
        PUSH    DE
        PUSH    HL
        LD      HL,(FNPAR_SP)
        LD      DE,FNPAR_END
        CALL    CPHLDE
        JP      Z,ERR_12
        LD      BC,0FFFAh
        ADD     HL,BC
        LD      (FNPAR_SP),HL
        POP     DE
        LD      (HL),E
        INC     HL
        POP     DE
        LD      BC,0005h
        EX      DE,HL
        CALL    BLKMOVE
        EX      DE,HL
        LD      HL,(VALSP)
        CALL    BLKMOVE
        POP     HL
        CALL    EVAL
        CALL    CHKSTRTYPE
        CALL    CHRGET
        JP      NZ,ERR_01
        LD      HL,(FNPAR_SP)
        LD      E,(HL)
        INC     HL
        LD      D,20h
        CALL    NUMVAR
        CALL    BLKMOVE
        ADD     HL,BC
        LD      (FNPAR_SP),HL
        JP      PRIM_RET
;  STRVAR – Stringvariable DE in P_STRVAR suchen bzw. leer anlegen
;  (LK2_NEW). TI$ wird gesondert aus der Uhr gelesen (TI_READ).
;  Zurück: B = 1 (String), C = Länge, DE = Text.
STRVAR: CALL    SKIPSP_INC
        CP      28h                     ; '('
        JP      Z,ARR_STRELEM
        PUSH    HL
        LD      HL,4954h                ; Variablenname "TI" ('T' = 54h, 'I' = 49h)
        XOR     A
        SBC     HL,DE
        JR      Z,TI_READ
        EX      DE,HL
        LD      (LISTKEY+1),HL
        LD      HL,(P_STRVAR)
STRVAR_SRCH:
        CALL    LISTKEY_CMP
D2842:  DEFW    LK2_NEW                 ; Inline-Parameter: Listenende -> neuer Eintrag
        JR      Z,LK2_FOUND
        LD      B,00h
        LD      C,(HL)
        ADD     HL,BC
        INC     HL
        INC     HL
        JR      STRVAR_SRCH
LK2_NEW:
        LD      BC,0004h
        EX      DE,HL
        LD      HL,LISTKEY+1
        CALL    MOVEUP
        CALL    ADJ_PTRS
        EX      DE,HL
        ADD     HL,BC
        DEC     HL
        LD      (HL),0Dh
        DEC     HL
        LD      (HL),B
LK2_FOUND:
        LD      C,(HL)
        INC     HL
        LD      B,01h
        EX      DE,HL
        POP     HL
        LD      A,(HL)
        RET
;  TI_READ – Uhr lesen (TIMER_GET: HL = Sekunden, A <> 0 nachmittags) und als
;  "hh" "mm" "ss" (24 Stunden) nach TI_STR schreiben.
TI_READ:
        CALL    TIMER_GET
TI_FMT: EX      DE,HL
        OR      A
        JR      Z,TI_FMT2
        LD      A,0Ch
TI_FMT2:
        EXX
        LD      HL,TI_STR
        PUSH    HL
        EXX
        LD      DE,0F1F0h
        CALL    TI_DIV
        LD      DE,0FFC4h
        CALL    TI_DIV0
        LD      A,L
        CALL    TI_2DIG
        POP     DE
        LD      BC,0106h
        POP     HL
        LD      A,(HL)
        RET
; <- aufgerufen von 2882h
TI_DIV0:
        XOR     A
; <- aufgerufen von 287Ch
TI_DIV: ADD     HL,DE
        JR      NC,TI_DIVEND
        INC     A
        JR      TI_DIV
TI_DIVEND:
        OR      A
        SBC     HL,DE
; <- aufgerufen von 2886h
TI_2DIG:
        LD      BC,30F6h
TI_2DIG_LP:
        ADD     A,C
        JR      NC,TI_2DIG_PUT
        INC     B
        JR      TI_2DIG_LP
TI_2DIG_PUT:
        ADD     A,3Ah
        EX      AF,AF'
        LD      A,B
        EXX
        LD      (HL),A
        INC     HL
        EX      AF,AF'
        LD      (HL),A
        INC     HL
        LD      (HL),0Dh
        EXX
        RET
;  ARR_STRELEM/ARR_NUMELEM – Feldelement name(i[,j]) bestimmen. Das Feld
;  muss mit DIM angelegt sein, sonst Fehler 3. Zahl: Adresse des Werts;
;  String: Eintrag über die Längenbytes abzählen.
ARR_STRELEM:
        LD      BC,0100h
        JR      ARR_ELEM
ARR_NUMELEM:
        LD      BC,0000h
ARR_ELEM:
        INC     HL
        CALL    ARR_FIND
        JP      Z,ERR_03
        PUSH    HL
        LD      L,C
        LD      H,00h
        LD      C,E
        LD      E,D
        LD      B,H
        LD      D,H
        PUSH    BC
        INC     HL
        CALL    MUL16_ERR
        POP     HL
        ADD     HL,DE
        EX      DE,HL
        LD      A,(ARR_TYPE)
        OR      A
        JR      NZ,ARR_STRPOS
        LD      HL,0005h
        CALL    MUL16_ERR
        POP     HL
        ADD     HL,DE
        LD      BC,0005h
        JR      ARR_ELEMRET
ARR_STRPOS:
        POP     HL
        LD      B,00h
ARR_STRP_LP:
        LD      C,(HL)
        INC     HL
        LD      A,D
        OR      E
        JR      Z,ARR_STRFND
        ADD     HL,BC
        INC     HL
        DEC     DE
        JR      ARR_STRP_LP
ARR_STRFND:
        INC     B
ARR_ELEMRET:
        EX      DE,HL
        LD      HL,(ARR_TXTP)
        LD      A,(HL)
        RET
;  GETNAME – Variablennamen ab HL lesen: Buchstabe, optional Buchstabe
;  oder Ziffer (E, D; D = 20h bei einem Zeichen). Weitere Buchstaben und
;  Ziffern werden überlesen, nur zwei Zeichen zählen. C, wenn gültig.
;  Sonderfall "FN": HL hinter FN.
;  GETNAME_SN – dasselbe, "FN" oder kein Name: Fehler 1.
; <- aufgerufen von 220Bh, 26DEh, 2937h
GETNAME:
        CALL    SKIPSP
        LD      BC,411Ah
        SUB     B
        CP      C
        LD      A,(HL)
        RET     NC
        LD      E,A
        LD      D,20h
GETNAME_2:
        INC     HL
        LD      A,(HL)
        CP      D
        JR      Z,GETNAME_2
        SUB     B
        CP      C
        JR      C,GETNAME_CHK2
        SUB     0EFh
        CP      0Ah
GETNAME_CHK2:
        LD      A,(HL)
        CCF
        RET     C
        LD      D,A
        CP      4Eh                     ; 'N'
        JR      NZ,GETNAME_SKIP
        LD      A,46h                   ; 'F'
        CP      E
        JR      Z,GETNAME_FN
GETNAME_SKIP:
        INC     HL
        LD      A,(HL)
        CP      20h                     ; ' '
        JR      Z,GETNAME_SKIP
        SUB     B
        CP      C
        JR      C,GETNAME_SKIP
        SUB     0EFh
        CP      0Ah
        JR      C,GETNAME_SKIP
GETNAME_OK:
        LD      A,(HL)
        SCF
        RET
GETNAME_FN:
        CALL    SKIPSP_INC
        SCF
        RET
; <- aufgerufen von 1FAFh, 216Fh, 2338h, 2B8Fh, 2BD9h, 2C95h, 4132h, 60FFh (+3 weitere)
GETNAME_SN:
        CALL    GETNAME
        JR      NC,GETNAME_ERR
        LD      A,46h                   ; 'F'
        CP      E
        JR      NZ,GETNAME_FNCHK
        LD      A,4Eh                   ; 'N'
        CP      D
GETNAME_FNCHK:
        JR      NZ,GETNAME_OK
GETNAME_ERR:
        JP      ERR_01

; ------------------------------------------------------------------------------
;  FUNC_TAB – Operatoren und Funktionen (49 Einträge)
;  Index 0-8:   Vergleich, Token 83h-8Bh minus 83h; "=" wird vorher
;               zu 89h (EVAL_EXPR, 254Eh)
;  Index 12-16: + - * / ^ (keine Token, Index im Code gesetzt)
;  Index 17-36: Token A0h-B3h (LEFT$( .. POS), Einsprung 296Bh = Eintrag 17
;  Index 37-48: Token C0h-CBh (RND( .. SQR(), Einsprung D2993 = Eintrag 37
;  Siehe PRIM_TOKEN. TO (9Eh) und STEP (9Fh) haben keinen Eintrag.
; ------------------------------------------------------------------------------
FUNC_TAB:
        DEFW    OP_NE2                  ;  0: Vergleich <> (><)
        DEFW    OP_NE2                  ;  1: Vergleich <>
        DEFW    OP_LE2                  ;  2: Vergleich <= (=<)
        DEFW    OP_LE2                  ;  3: Vergleich <=
        DEFW    OP_GE2                  ;  4: Vergleich >= (=>)
        DEFW    OP_GE2                  ;  5: Vergleich >=
        DEFW    OP_EQ                   ;  6: Vergleich = (Token 89h, aus "=" erzeugt)
        DEFW    OP_GT                   ;  7: Vergleich >
        DEFW    OP_LT                   ;  8: Vergleich <
        DEFW    ERR_01                  ;  9: (frei)
        DEFW    ERR_01                  ; 10: (frei)
        DEFW    ERR_01                  ; 11: (frei)
        DEFW    OP_ADD                  ; 12: Addition +
        DEFW    OP_SUB                  ; 13: Subtraktion -
        DEFW    OP_MUL                  ; 14: Multiplikation *
        DEFW    OP_DIV                  ; 15: Division /
        DEFW    OP_POW                  ; 16: Potenz ^
        DEFW    FN_LEFT                 ; 17: LEFT$(
        DEFW    FN_RIGHT                ; 18: RIGHT$(
        DEFW    FN_MID                  ; 19: MID$(
        DEFW    FN_LEN                  ; 20: LEN(
        DEFW    FN_CHR                  ; 21: CHR$(
        DEFW    FN_STR                  ; 22: STR$(
        DEFW    FN_ASC                  ; 23: ASC(
        DEFW    FN_VAL                  ; 24: VAL(
        DEFW    FN_PEEK                 ; 25: PEEK(
        DEFW    FN_TAB                  ; 26: TAB(
        DEFW    FN_SPACE                ; 27: SPACE$(
        DEFW    FN_SIZE                 ; 28: SIZE
        DEFW    FN_ERL                  ; 29: ERL
        DEFW    FN_ERN                  ; 30: ERN
        DEFW    ERR_01                  ; 31: EOF(
        DEFW    FN_STRING               ; 32: STRING$(
        DEFW    FN_POINT                ; 33: POINT(
        DEFW    FN_CHARACTER            ; 34: CHARACTER$(
        DEFW    FN_CSR                  ; 35: CSR
        DEFW    FN_POS                  ; 36: POS
D2993:  DEFW    FN_RND                  ; 37: RND(
        DEFW    FN_SIN                  ; 38: SIN(
        DEFW    FN_COS                  ; 39: COS(
        DEFW    FN_TAN                  ; 40: TAN(
        DEFW    FN_ATN                  ; 41: ATN(
        DEFW    FN_EXP                  ; 42: EXP(
        DEFW    FN_INT                  ; 43: INT(
        DEFW    FN_LOG                  ; 44: LOG(
        DEFW    FN_LN                   ; 45: LN(
        DEFW    FN_ABS                  ; 46: ABS(
        DEFW    FN_SGN                  ; 47: SGN(
        DEFW    FN_SQR                  ; 48: SQR(
;  LEFT$(s,n), RIGHT$(s,n), MID$(s,p,n) – schneiden den String auf dem
;  Wertestack zu (STR_CUT). Bei MID$ darf statt n ein "-" stehen: dann
;  bleibt der Rest ab p. p = 0: Fehler 3.
FN_LEFT:
        CALL    EVAL
        CALL    SKIPCOMMA
LEFT_LEN:
        PUSH    DE
        CALL    EVAL_BYTE
        CALL    CHK_RPAR
        EX      (SP),HL
        PUSH    HL
        EX      DE,HL
        CALL    GETSTR
        LD      A,C
        SUB     L
        JR      C,STR_CUTRET
        PUSH    HL
        LD      C,A
        ADD     HL,DE
        JR      STR_CUT
FN_RIGHT:
        CALL    RIGHT_ARGS
; <- aufgerufen von 2475h, 27BDh, 29B5h, 2A23h, 2A2Dh, 2A3Dh, 2A58h, 2A72h (+5 weitere)
CHK_RPAR:
        CALL    SYNCHK
D29CD:  DEFB    29h                     ; Inline-Parameter ')'
        RET
; <- aufgerufen von 29C7h
RIGHT_ARGS:
        CALL    EVAL
        CALL    SKIPCOMMA
        PUSH    DE
        CALL    EVAL_BYTE
        JR      RIGHT_DO
; <- aufgerufen von 2A10h
RIGHT_BC:
        PUSH    BC
RIGHT_DO:
        EX      (SP),HL
        PUSH    HL
        EX      DE,HL
        CALL    GETSTR
        LD      A,C
        SUB     L
        JR      C,STR_CUTRET
        PUSH    HL
        LD      C,A
        LD      L,E
        LD      H,D
STR_CUT:
        EX      DE,HL
        CALL    MEMDEL_ADJ
        POP     BC
        DEC     HL
        LD      (HL),C
        INC     HL
STR_CUTRET:
        POP     DE
        POP     HL
        LD      A,(HL)
        RET
FN_MID: CALL    EVAL
        CALL    SKIPCOMMA
        PUSH    DE
        PUSH    BC
        CALL    EVAL_BYTE
        POP     BC
        LD      A,E
        OR      A
        JP      Z,ERR_03
        LD      A,C
        SUB     E
        JR      NC,MID_START
        LD      A,0FFh
MID_START:
        INC     A
        LD      E,A
        POP     BC
        CALL    RIGHT_BC
        CALL    SKIPCOMMA
        CP      2Dh                     ; '-'
        JR      NZ,LEFT_LEN
        INC     HL
        JR      CHK_RPAR
;  LEN(s), CHR$(n), STR$(x), VAL(s), ASC(s), PEEK(adr): wie üblich.
;  VAL eines leeren oder nicht numerischen Strings ergibt 0 (STR_ZERO).
;  ASC("") ergibt Fehler 3. PEEK und CHR$ nehmen Adresse/Wert auch als $hex.
FN_LEN: CALL    EVAL
        CALL    GETSTR
        CALL    CHK_RPAR
        PUSH    HL
        LD      A,C
        JR      RET_A
FN_CHR: CALL    EVAL_ADDR
        CALL    CHK_RPAR
        LD      A,E
        LD      BC,0001h
        JP      STR_FILL
FN_STR: CALL    EVAL
        CALL    CHKSTRTYPE
        CALL    CHK_RPAR
        PUSH    HL
        LD      HL,(VALSP)
        LD      DE,6CB3h
        PUSH    DE
        CALL    NUM2STR
        POP     HL
        CALL    STRLIT
        POP     HL
        LD      A,(HL)
        RET
FN_VAL: CALL    EVAL
        CALL    GETSTR
        CALL    CHK_RPAR
        PUSH    HL
        EX      DE,HL
        JR      VAL_EVAL
; <- aufgerufen von 2A62h
VAL_ZERO:
        LD      HL,STR_ZERO
VAL_EVAL:
        CALL    NUMSTR_EVAL
D2A65:  DEFW    VAL_ZERO
        POP     HL
        LD      A,(HL)
        RET
STR_ZERO:
        DEFB    30h,0Dh                 ; ?? |0.|
FN_ASC: CALL    EVAL
        CALL    GETSTR
        CALL    CHK_RPAR
        LD      A,C
        OR      A
        JP      Z,ERR_03
RET_BYTE:
        LD      A,(DE)
        PUSH    HL
RET_A:  LD      E,A
        LD      D,00h
RET_DE: CALL    INT2VAL
        POP     HL
        LD      A,(HL)
        RET
;  INT2VAL – DE (0-65535) als Gleitkommazahl nach (VALSP).
; <- aufgerufen von 2A7Fh, 2BC1h
INT2VAL:
        LD      B,80h
        LD      A,D
        OR      E
        JR      Z,I2V_STORE
        LD      B,0D0h
        LD      A,D
        OR      A
        JR      NZ,I2V_NORM
        LD      B,0C8h
        LD      D,E
        LD      E,00h
I2V_NORM:
        EX      DE,HL
I2V_LP: BIT     7,H
        JR      NZ,I2V_SWAP
        ADD     HL,HL
        DJNZ    I2V_LP
I2V_SWAP:
        EX      DE,HL
I2V_STORE:
        LD      HL,(VALSP)
        LD      (HL),B
        INC     HL
        CALL    CLRWORD
        LD      (HL),E
        INC     HL
        LD      (HL),D
        LD      BC,0005h
        LD      DE,0000h
        RET
FN_PEEK:
        CALL    EVAL_ADDR
        CALL    CHK_RPAR
        JR      RET_BYTE
;  TAB( ist nur in PRINT erlaubt; als Funktion: Fehler 1.
FN_TAB: JP      ERR_01
FN_SPACE:
        CALL    EVAL_BYTE
        CALL    CHK_RPAR
        LD      A,20h                   ; ' '
        LD      C,E
        LD      B,00h
;  STR_FILL – neuen String mit C Zeichen A anlegen (SPACE$, STRING$, CHR$).
; <- aufgerufen von 2BADh, 3CBEh
STR_FILL:
        PUSH    HL
        PUSH    AF
        CALL    STR_NEW
        POP     AF
        PUSH    DE
        PUSH    BC
        LD      B,C
        INC     B
        JR      STR_FILL_CNT
STR_FILL_LP:
        LD      (HL),A
        INC     HL
STR_FILL_CNT:
        DJNZ    STR_FILL_LP
        POP     BC
        POP     DE
        POP     HL
        LD      A,(HL)
        RET
FN_STRING:
        CALL    EVAL
        CALL    SKIPCOMMA
        PUSH    DE
        CALL    EVAL_BYTE
        CALL    CHK_RPAR
        EX      (SP),HL
        PUSH    DE
        EX      DE,HL
        CALL    GETSTR
        LD      A,C
        OR      A
        JP      Z,ERR_03
        LD      A,(DE)
        POP     BC
        POP     HL
        JR      STR_FILL
;  POINT(x,y) – x 0-319, y 0-199, sonst Fehler 3; Ergebnis von GR_POINT.
FN_POINT:
        CALL    EVAL_INT
        PUSH    HL
        XOR     A
        LD      HL,013Fh
        SBC     HL,DE
POINT_ERR:
        JP      C,ERR_03
        POP     HL
        PUSH    DE
        CALL    SKIPCOMMA
        CALL    EVAL_INT
        CALL    CHK_RPAR
        PUSH    HL
        XOR     A
        LD      HL,00C7h
        SBC     HL,DE
        JR      C,POINT_ERR
        POP     BC
        EX      DE,HL
        POP     DE
        PUSH    BC
        CALL    GR_POINT
        JP      RET_A
;  SIZE – freier Speicher. ERL, ERN – Fehlerzeile bzw. -nummer, außerhalb
;  des Fehlerbehandlers 0.
FN_SIZE:
        PUSH    HL
        CALL    MEMFREE
        JR      RET_HL
FN_ERL: LD      DE,(ERRCTX_LNUM)
        JR      ERLN_RET
FN_ERN: LD      DE,(ERRNUM)
ERLN_RET:
        PUSH    HL
        LD      A,(ONERR_FLAG)
        LD      HL,0000h
        CP      02h
        JR      Z,RET_DE2
RET_HL: EX      DE,HL
RET_DE2:
        JP      RET_DE
;  ABS(x) setzt das Vorzeichenbit, SGN(x) liefert -1, 0 oder 1.
FN_ABS: LD      A,(DE)
        OR      80h
        LD      (DE),A
        RET
FN_SGN: LD      A,(DE)
        LD      DE,VAL_PUT
        PUSH    DE
        LD      DE,FP_MONE
        OR      A
        RET     P
        LD      DE,FP_ONE
        CP      80h
        RET     NZ
        LD      DE,FP_ZERO
        RET
ST_MON: JP      MON_WARM
ST_BOOT:
        LD      A,06h
        OUT     (PPI_CTL),A
;  CURSOR x, y – x kleiner als die Zeilenbreite (Operand von ADD_WIDTH),
;  y 0-24, sonst Fehler 3.
ST_CURSOR:
        CALL    EVAL_BYTE
        LD      A,(ADD_WIDTH+1)
        LD      (CURSOR_MAXX+1),A
        LD      A,E
CURSOR_MAXX:
        CP      0FFh
CURSOR_ERR:
        JP      NC,ERR_03
        PUSH    AF
        CALL    SYNCHK
D2B76:  DEFB    2Ch                     ; Inline-Parameter ','
        CALL    EVAL_BYTE
        LD      A,E
        CP      19h
        JR      NC,CURSOR_ERR
        EX      DE,HL
        LD      H,L
        POP     AF
        LD      L,A
        LD      (CSR_XY),HL
        LD      (CSR_COL),A
        EX      DE,HL
        JP      NEXTSTMT_HL
        DEFB    00h,00h                 ; ?? |..|
;  GET var – Taste ohne Warten lesen (INKEY). String: das Zeichen oder "";
;  Zahl: Ziffernwert, sonst 0.
ST_GET: CALL    GETNAME_SN
        CALL    GETVAR
        LD      (TXTPTR),HL
        CALL    SAVEPAR1
        CALL    INKEY
        PUSH    AF
        LD      A,(6B05h)
        OR      A
        JR      Z,GET_NUM
        POP     AF
        LD      BC,0000h
        OR      A
        JR      Z,GET_STR
        INC     BC
GET_STR:
        CALL    STR_FILL
GET_ASSIGN:
        CALL    SAVEPAR0
        CALL    ASSIGN
D2BB6:  DEFW    ERR_04
        JR      STMT_DONE
GET_NUM:
        POP     AF
        LD      DE,0000h
        CALL    GET_DIGIT
GET_NUMVAL:
        CALL    INT2VAL
        JR      GET_ASSIGN
; <- aufgerufen von 2BBEh
GET_DIGIT:
        OR      A
        RET     Z
        SUB     30h
        CP      0Ah
        RET     NC
        LD      E,A
        RET
;  USR(adresse [, var$]) – Maschinenprogramm aufrufen, zurück über
;  NEXTSTMT (liegt als Rücksprung auf dem Stack). Mit var$ liefert GETVAR
;  deren Angaben in BC/DE (B = 0); eine Zahlvariable ergibt Fehler 4.
ST_USR: CALL    EVAL_ADDR
        PUSH    DE
        CALL    CHK_CHR_ALT
D2BD6:  DEFB    2Ch                     ; Inline-Parameter ','
D2BD7:  DEFW    USR_CALL
        CALL    GETNAME_SN
        CALL    GETVAR
        LD      A,B
        OR      A
        JP      Z,ERR_04
        LD      B,00h
; <- aufgerufen von 2BD3h
USR_CALL:
        CALL    CHK_RPAR
        LD      (TXTPTR),HL
        CALL    SET_IOERR
        LD      HL,NEXTSTMT
        EX      (SP),HL
        JP      (HL)
;  LIMIT MAX | adresse – Obergrenze des BASIC-Speichers setzen (STKTOP und
;  SP). Über MEMTOP: Fehler 3; zu nah am belegten Speicher (< 200 Bytes):
;  Fehler 18.
ST_LIMIT:
        LD      DE,KW_MAX
        CALL    KWSEARCH
        JR      NZ,LIMIT_ADDR
        LD      (TXTPTR),HL
        LD      HL,(MEMTOP)
        JR      LIMIT_SET
LIMIT_ADDR:
        CALL    EVAL_ADDR
        LD      (TXTPTR),HL
        LD      HL,(MEMTOP)
        CALL    CPHLDE
        JP      C,ERR_03
        LD      HL,(VALSP)
        LD      BC,00C8h
        ADD     HL,BC
        CALL    CPHLDE
        JP      NC,ERR_18
        EX      DE,HL
LIMIT_SET:
        LD      (STKTOP),HL
        LD      SP,HL
STMT_DONE:
        JP      NEXTSTMT
KW_MAX: DEFB    "MA",0D8h               ; MAX
        DEFB    00h                     ; ?? |.|
;  EVAL_ADDR – Adresse lesen: "$" + bis zu 4 Hexziffern (mehr: Fehler 3)
;  oder sonst ein Ausdruck (EVAL_INT).
; <- aufgerufen von 2449h, 2450h, 2A2Ah, 2AB1h, 2BCFh, 2C04h, 2C8Bh, 2CA9h (+2 weitere)
EVAL_ADDR:
        CALL    CHK_CHR_ALT
D2C2F:  DEFB    24h                     ; Inline-Parameter '$'
D2C30:  DEFW    ADDR_DEC
        LD      DE,0000h
HEX_LP: CALL    ISDIGIT
        JR      NC,HEX_AF
HEX_ADD:
        AND     0Fh
        LD      C,A
        LD      B,00h
        LD      A,D
        AND     0F0h
        JP      NZ,ERR_03
        EX      DE,HL
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,BC
        EX      DE,HL
        INC     HL
        JR      HEX_LP
HEX_AF: SUB     41h
        CP      06h
        RET     NC
        ADD     A,0Ah
        JR      HEX_ADD
; <- aufgerufen von 2C2Ch
ADDR_DEC:
        JP      EVAL_INT
;  CONT – nur im Direktmodus, ohne gesicherte Stelle Fehler 17.
;  CONT_FLAG: 1 = nach STOP/END (weiter mit der nächsten Anweisung),
;  2 = nach BREAK (Anweisung wiederholen), negativ = aus INPUT (IN_MORE).
ST_CONT:
        CALL    CHK_DIRECT
        LD      A,(CONT_FLAG)
        OR      A
        JP      Z,ERR_17
        PUSH    AF
        XOR     A
        CALL    CONT_POS
        POP     AF
        LD      HL,(TXTPTR)
        OR      A
        JP      M,IN_MORE
        DEC     A
        JR      Z,STMT_DONE
        JP      EXECSTMT2
; <- aufgerufen von 1D58h, 2C67h, 3FDCh
CONT_POS:
        LD      (CONT_FLAG),A           ; A<>0: Zeile/Textzeiger für CONT sichern, A=0: zurückholen
        LD      DE,CONT_SAVE
        LD      BC,0006h
        LD      HL,CURLINE
        OR      A
        JR      NZ,CONT_COPY
        EX      DE,HL
CONT_COPY:
        LDIR
        RET
;  INP@ port, var – Port lesen (Portnummer wird in den IN-Befehl
;  geschrieben).
ST_INPAT:
        CALL    EVAL_ADDR
        CALL    SKIPCOMMA
        LD      A,E
        LD      (INPAT_IN+1),A
        CALL    GETNAME_SN
        CALL    GETVAR
        LD      (TXTPTR),HL
        CALL    SAVEPAR1
INPAT_IN:
        IN      A,(PRN_DAT)
        LD      E,A
        LD      D,00h
        JP      GET_NUMVAL
;  OUT@ port, wert – unteres Byte des Werts an den Port ausgeben (Portnummer wird in
;  den OUT-Befehl geschrieben).
ST_OUTAT:
        CALL    EVAL_ADDR
        CALL    SKIPCOMMA
        LD      A,E
        LD      (OUTAT_OUT+1),A
        CALL    EVAL_ADDR
        LD      A,E
OUTAT_OUT:
        OUT     (PRN_DAT),A
AUTO_DONE:
        JP      NEXTSTMT_HL
;  AUTO [start][,schritt] – nur im Direktmodus, Vorgabe je 10, 0: Fehler 1.
ST_AUTO:
        CALL    CHK_DIRECT
        CALL    CHRGET
        JR      Z,AUTO_DEF
        CALL    CHK_CHR_ALT
D2CC7:  DEFB    2Ch                     ; Inline-Parameter ','
D2CC8:  DEFW    AUTO_START
        JR      AUTO_LINE10
; <- aufgerufen von 2CC4h
AUTO_START:
        CALL    AUTO_NUM
        LD      (AUTO_LINE),DE
        CALL    CHRGET
        JR      Z,AUTO_STEP10
        CALL    CHK_CHR_ALT
D2CDB:  DEFB    2Ch                     ; Inline-Parameter ','
D2CDC:  DEFW    ERR_01
AUTO_STEPARG:
        CALL    AUTO_NUM
        LD      (AUTO_STEP),DE
AUTO_ON:
        LD      A,01h
        LD      (AUTO_FLAG),A
        JR      AUTO_DONE
AUTO_DEF:
        LD      DE,000Ah
        LD      (AUTO_LINE),DE
AUTO_SETSTEP:
        LD      (AUTO_STEP),DE
        JR      AUTO_ON
AUTO_STEP10:
        LD      DE,000Ah
        JR      AUTO_SETSTEP
AUTO_LINE10:
        LD      DE,000Ah
        LD      (AUTO_LINE),DE
        JR      AUTO_STEPARG
; <- aufgerufen von 2CCCh, 2CDEh
AUTO_NUM:
        CALL    EVAL_INT
        LD      A,D
        OR      E
        RET     NZ
DEFKEY_ERR:
        JP      ERR_01
;  AUTO: AUTO_FLAG <> 0 = aktiv, AUTO_LINE = nächste Zeilennummer,
;  AUTO_STEP = Schrittweite (Vorgabe je 10).
AUTO_FLAG:
        DEFB    00h                     ; ?? |.|
AUTO_LINE:
        DEFB    0Ah,00h                 ; ?? |..|
AUTO_STEP:
        DEFB    0Ah,00h                 ; ?? |..|

; ------------------------------------------------------------------------------
;  Gleitkommakonstanten
;  Format 5 Byte: Exponent (Bit 7 = 1: positiv, Bits 6-0 mit
;  Bias 40h), dann 32-Bit-Mantisse little-endian (0,5 <= m < 1).
; ------------------------------------------------------------------------------
FP_ONE: DEFB    0C1h,00h,00h,00h,80h    ; FP-Konstante = 1
FP_ZERO:
        DEFB    80h,00h,00h,00h,00h     ; FP-Konstante = 0
FP_MONE:
        DEFB    41h,00h,00h,00h,80h     ; FP-Konstante = -1
FP_PI:  DEFB    0C2h,0A1h,0DAh,0Fh,0C9h ; FP-Konstante = 3.14159265
;  DEF KEY(n) = text – Funktionstaste n = 1-10 belegen. Tabelle FKEY_TAB
;  (je Text bis 0Dh), Ende in FKEY_END, Grenze FKEY_LIMIT (voll: Fehler 1).
;  Der Text reicht bis zum Zeilenende; "!" wird als ":" gespeichert.
;  Ab dem ersten ":" wird der Rest der Programmzeile mit Leerzeichen
;  überschrieben, damit er nicht ausgeführt wird.
;  DEFKEY_SYNCHK: wie SYNCHK, Fehler stellt vorher die Tabelle wieder her.
ST_DEFKEY:
        CALL    EVAL_BYTE
        LD      A,E
        OR      A
        JR      Z,DEFKEY_ERR
        CP      0Bh
        JR      NC,DEFKEY_ERR
        PUSH    HL
        LD      DE,FKEY_TAB
        LD      B,A
DEFKEY_SRCH:
        LD      H,D
        LD      L,E
DEFKEY_SKIP:
        LD      A,(DE)
        INC     DE
        CP      0Dh
        JR      NZ,DEFKEY_SKIP
        DJNZ    DEFKEY_SRCH
        PUSH    HL
        LD      HL,(FKEY_END)
        XOR     A
        SBC     HL,DE
        LD      B,H
        LD      C,L
        LD      (DEFKEY_REST),HL
        POP     HL
        EX      DE,HL
        LDIR
        EX      DE,HL
        LD      (FKEY_END),HL
        EX      (SP),HL
        CALL    DEFKEY_SYNCHK
D2D5B:  DEFB    29h                     ; Inline-Parameter ')'
        CALL    DEFKEY_SYNCHK
D2D5F:  DEFB    3Dh                     ; Inline-Parameter '='
        PUSH    HL
        CALL    DEFKEY_EOL
        LD      (TXTPTR),HL
        POP     DE
        XOR     A
        SBC     HL,DE
        INC     HL
        LD      B,H
        LD      C,L
        EX      DE,HL
        EX      (SP),HL
        PUSH    HL
        ADD     HL,BC
        EX      DE,HL
        PUSH    DE
        LD      HL,FKEY_LIMIT
        XOR     A
        SBC     HL,DE
        JR      C,DEFKEY_FULL
        POP     HL
        LD      (FKEY_END),HL
        POP     DE
        EX      DE,HL
        PUSH    BC
        LD      BC,(DEFKEY_REST)
        DEC     HL
        DEC     DE
        LDDR
        POP     BC
        EX      DE,HL
        XOR     A
        SBC     HL,BC
        EX      DE,HL
        POP     HL
        INC     DE
        LD      B,C
DEFKEY_COPY:
        LD      A,(HL)
        CP      21h                     ; '!'
        JR      NZ,DEFKEY_PUT
        LD      A,3Ah                   ; ':'
DEFKEY_PUT:
        LD      (DE),A
        INC     HL
        INC     DE
        DJNZ    DEFKEY_COPY
        JP      NEXTSTMT
DEFKEY_SYNERR:
        LD      HL,(FKEY_END)
        JR      DEFKEY_UNDO
DEFKEY_FULL:
        POP     DE
        POP     HL
DEFKEY_UNDO:
        LD      D,H
        LD      E,L
        INC     HL
        LD      (FKEY_END),HL
        DEC     HL
        DEC     HL
        LD      BC,(DEFKEY_REST)
        LDDR
        EX      DE,HL
        LD      (HL),0Dh
        JP      ERR_01
DEFKEY_REST:
        DEFB    00h,00h                 ; ?? |..|
; <- aufgerufen von 2D58h, 2D5Ch
DEFKEY_SYNCHK:
        CALL    SKIPSP
        EX      (SP),HL
        CP      (HL)
        JR      NZ,DEFKEY_SYNERR
        INC     HL
        EX      (SP),HL
        JP      SKIPSP_INC
DEFKEY_EOL_LP:
        INC     HL
; <- aufgerufen von 2D61h
DEFKEY_EOL:
        LD      A,(HL)
        CP      0Dh
        RET     Z
        CP      3Ah                     ; ':'
        JR      NZ,DEFKEY_EOL_LP
DEFKEY_BLANK:
        LD      (HL),20h
        INC     HL
        LD      A,(HL)
        CP      0Dh
        RET     Z
        JR      DEFKEY_BLANK
;  KLIST – Belegung der Funktionstasten 1-10 ausgeben (nur Direktmodus).
ST_KLIST:
        CALL    CHK_DIRECT
        PUSH    HL
        LD      B,00h
        LD      HL,FKEY_TAB
        LD      A,0Dh
        CALL    PRTCHR
KLIST_LP:
        INC     B
        LD      A,B
        CP      0Ah
        JR      Z,KLIST_10
        CP      0Bh
        JR      Z,KLIST_DONE
        CALL    NIB2ASC
KLIST_NUM:
        CALL    PRTCHR
        CALL    PRTSPC
KLIST_TEXT:
        LD      A,(HL)
        INC     HL
        CP      0Dh
        PUSH    AF
        CALL    PRTCHR
        POP     AF
        JR      NZ,KLIST_TEXT
        JR      KLIST_LP
KLIST_10:
        LD      A,31h                   ; '1'
        CALL    PRTCHR
        LD      A,30h                   ; '0'
        JR      KLIST_NUM
KLIST_DONE:
        POP     HL
        JP      NEXTSTMT_HL
CHANGE_FLAG:
        DEFB    00h                     ; ?? |.|
;  CHANGE – Groß-/Kleinschreibung der Buchstabentasten umschalten:
;  Bit 5 in je 26 Einträgen der Tastaturtabellen KEYTAB_N_AZ/KEYTAB_S_AZ setzen bzw.
;  löschen, Zustand in CHANGE_FLAG.
ST_CHANGE:
        PUSH    HL
        LD      HL,KEYTAB_N_AZ
        LD      DE,KEYTAB_S_AZ
        LD      A,(CHANGE_FLAG)
        OR      A
        JR      Z,CHANGE_ON
        EX      DE,HL
        DEC     A
        JR      CHANGE_SET
CHANGE_ON:
        INC     A
CHANGE_SET:
        LD      (CHANGE_FLAG),A
        LD      B,1Ah
        PUSH    BC
CHANGE_UP:
        SET     5,(HL)
        INC     HL
        DJNZ    CHANGE_UP
        POP     BC
        EX      DE,HL
CHANGE_LOW:
        RES     5,(HL)
        INC     HL
        DJNZ    CHANGE_LOW
        JR      KLIST_DONE
;  Arbeitszellen der Grundrechenarten: FPA_FLAG (Addition/Subtraktion bzw.
;  Überlaufzähler bei MUL), FPA_SIGN (Vorzeichen des Ergebnisses), FPA_EXP
;  (Exponent des Ergebnisses).
FPA_FLAG:
        DEFB    00h                     ; ?? |.|
FPA_SIGN:
        DEFB    00h                     ; ?? |.|
FPA_EXP:
        DEFB    00h                     ; ?? |.|

; ==============================================================================
;  GLEITKOMMA-ARITHMETIK UND MATHEMATISCHE FUNKTIONEN
; ==============================================================================
;  OP_SUB / OP_ADD – (DE) = (DE) - (HL) bzw. (DE) + (HL).
;  Alle Rechenroutinen: DE zeigt auf den linken Operanden und bekommt das
;  Ergebnis, HL auf den rechten. Format: 5 Bytes, Exponentbyte (Bit 7 = 1
;  positiv, Bits 6-0 Exponent mit Bias 40h), dann 32 Bit Mantisse (Low-Byte
;  zuerst, normiert: Bit 31 = 1); 0 = 80h, 0, 0, 0, 0.
;  Der kleinere Wert wird um die Exponentdifferenz nach rechts geschoben,
;  dann addiert bzw. subtrahiert und normiert. Überlauf: Fehler 2,
;  Unterlauf: 0.
; <- aufgerufen von 36C1h, 3753h, 3870h, 39BDh, 3B62h, 3C03h
OP_SUB: XOR     A
        DEFB    01h                     ; Trick: Opcode 01h verschluckt den folgenden Befehl
; <- aufgerufen von 223Bh
OP_ADD: LD      A,80h
        PUSH    DE
        XOR     (HL)
        CPL
        LD      C,A
        LD      A,(DE)
        AND     80h
        LD      B,A
        XOR     C
        CPL
        AND     80h
        LD      C,A
ADD_ORDER:
        PUSH    BC
        LD      B,(HL)
        RES     7,B
        LD      A,(DE)
        AND     7Fh
        CP      B
        JR      NC,ADD_ALIGN
        POP     BC
        EX      DE,HL
        LD      A,B
        XOR     C
        CPL
        AND     80h
        LD      B,A
        JR      ADD_ORDER
ADD_ALIGN:
        LD      C,A
        ADD     A,40h
        LD      (FPA_EXP),A
        LD      A,C
        SUB     B
        POP     BC
        LD      (FPA_FLAG),BC
        PUSH    DE
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        POP     HL
        INC     HL
        JR      Z,ADD_DO
ADD_SHIFT:
        CP      08h
        JR      NC,ADD_SHR8
ADD_SHR1:
        SRL     B
        RR      C
        RR      D
        RR      E
        DEC     A
        JR      NZ,ADD_SHR1
        JR      ADD_DO
ADD_SHR8:
        LD      E,D
        LD      D,C
        LD      C,B
        LD      B,00h
        SUB     08h
        JR      NZ,ADD_SHIFT
ADD_DO: LD      A,(FPA_FLAG)
        OR      A
        JR      Z,SUB_DO
        LD      A,(HL)
        INC     HL
        ADD     A,E
        LD      E,A
        LD      A,(HL)
        INC     HL
        ADC     A,D
        LD      D,A
        LD      A,(HL)
        INC     HL
        ADC     A,C
        LD      C,A
        LD      A,(HL)
        ADC     A,B
        LD      B,A
        JR      NC,FP_PACK
        RR      B
        RR      C
        RR      D
        RR      E
        LD      HL,FPA_EXP
        INC     (HL)
;  FP_PACK – Exponent FPA_EXP und Vorzeichen zusammensetzen, Ergebnis nach
;  (DE vom Stack) schreiben (FP_STORE_DE). FP_UNDER: Ergebnis 0.
FP_PACK:
        LD      HL,FPA_EXP
        LD      A,(HL)
        SUB     40h
        JR      C,FP_UNDER
        JP      M,ERR_02
        DEC     HL
        OR      (HL)
        JR      FP_STORE_DE
FP_UNDER:
        CALL    FP_ZERO_REGS
FP_STORE_DE:
        POP     HL
;  FP_STORE – A (Exponentbyte) und EDCB (Mantisse) nach (HL) schreiben.
; <- aufgerufen von 3609h, 36B3h
FP_STORE:
        LD      (HL),A
        INC     HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        INC     HL
        LD      (HL),C
        INC     HL
        LD      (HL),B
        RET
SUB_DO: LD      A,(HL)
        INC     HL
        SUB     E
        LD      E,A
        LD      A,(HL)
        INC     HL
        SBC     A,D
        LD      D,A
        LD      A,(HL)
        INC     HL
        SBC     A,C
        LD      C,A
        LD      A,(HL)
        SBC     A,B
        LD      B,A
        CALL    C,MANT_NEG
        OR      C
        OR      D
        JR      NZ,FP_NORM
        LD      A,E
        CP      3Fh                     ; '?'
        JR      C,FP_UNDER
;  FP_NORM – Mantisse BCDE so weit nach links schieben, bis Bit 31 gesetzt
;  ist (ganze Bytes zuerst), Exponent entsprechend verringern.
FP_NORM:
        LD      HL,FPA_EXP
FP_NORM_LP:
        LD      A,B
        OR      A
        JP      M,FP_PACK
        JR      NZ,FP_NORM_SHL
        LD      A,(HL)
        SUB     08h
        JR      C,FP_UNDER
        LD      (HL),A
        LD      A,C
        OR      D
        OR      E
        JR      Z,FP_UNDER
        LD      B,C
        LD      C,D
        LD      D,E
        LD      E,00h
        JP      FP_NORM_LP
FP_NORM_SHL:
        DEC     (HL)
        JR      C,FP_UNDER
        SLA     E
        RL      D
        RL      C
        RL      B
        JP      P,FP_NORM_SHL
        JR      FP_PACK
;  MANT_NEG – Mantisse BCDE negieren (Zweierkomplement) und Vorzeichen
;  umdrehen (Subtraktion mit negativem Zwischenergebnis).
; <- aufgerufen von 2EEBh
MANT_NEG:
        LD      HL,FPA_SIGN
        LD      A,(HL)
        ADD     A,80h
        LD      (HL),A
        LD      A,E
        CPL
        ADD     A,01h
        LD      E,A
        LD      A,D
        CPL
        ADC     A,00h
        LD      D,A
        LD      A,C
        CPL
        ADC     A,00h
        LD      C,A
        LD      A,B
        CPL
        ADC     A,00h
        LD      B,A
        RET
;  OP_MUL – (DE) = (DE) * (HL): Exponenten addieren (Bereich prüfen,
;  Unterlauf 0, Überlauf Fehler 2), Mantissen 32x32 Bit bitweise
;  multiplizieren (Teilsumme in HL/HL', Schattenregister), runden.
; <- aufgerufen von 35F4h, 39D3h, 39E3h, 3BCFh
OP_MUL: PUSH    DE
        LD      A,(DE)
        XOR     (HL)
        CPL
        AND     80h
        LD      (FPA_SIGN),A
        LD      B,(HL)
        RES     7,B
        LD      A,(DE)
        AND     7Fh
        ADD     A,B
        JP      Z,FP_UNDER
        DEC     A
MUL_EXP:
        CP      30h                     ; '0'
        JP      C,FP_UNDER
        CP      0E0h
        JP      NC,ERR_02
        LD      (FPA_EXP),A
        XOR     A
        LD      (FPA_FLAG),A
        LD      BC,0004h
        ADD     HL,BC
        LD      A,(HL)
        OR      A
        JP      P,FP_UNDER
        PUSH    HL
        POP     IY
        LD      C,B
        EX      DE,HL
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        PUSH    HL
        LD      H,B
        LD      L,B
        EXX
        POP     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      HL,0000h
        LD      A,D
        OR      A
        JP      P,FP_UNDER
        LD      C,04h
MUL_BYTE:
        LD      A,(IY+0)
        LD      B,08h
        OR      A
        JR      Z,MUL_ZEROB
MUL_BIT:
        RLA
        JR      NC,MUL_SHIFT
        EX      AF,AF'
        EXX
        LD      A,B
        ADD     A,C
        LD      C,A
        ADC     HL,DE
        EXX
        ADC     HL,DE
        JR      NC,MUL_NOCARRY
        LD      A,(FPA_FLAG)
        INC     A
        LD      (FPA_FLAG),A
MUL_NOCARRY:
        EX      AF,AF'
MUL_SHIFT:
        SRL     D
        RR      E
        EXX
        RR      D
        RR      E
        RR      B
        EXX
        DJNZ    MUL_BIT
MUL_NEXTB:
        DEC     IY
        DEC     C
        JR      NZ,MUL_BYTE
        LD      A,(FPA_FLAG)
        OR      A
        JR      Z,MUL_ROUND
        LD      B,A
        LD      A,(FPA_EXP)
        ADD     A,B
        LD      (FPA_EXP),A
MUL_FIXOVF:
        SCF
        RR      H
        RR      L
        EXX
        RR      H
        RR      L
        RR      C
        EXX
        DJNZ    MUL_FIXOVF
MUL_ROUND:
        EXX
        LD      A,C
        OR      A
        JP      P,MUL_DONE
        LD      DE,0001h
        ADD     HL,DE
        EXX
        LD      DE,0000h
        ADC     HL,DE
        JR      NC,MUL_RND_OK
        RR      H
        RR      L
        EXX
        RR      H
        RR      L
        EXX
        LD      A,(FPA_EXP)
        INC     A
        LD      (FPA_EXP),A
MUL_RND_OK:
        EXX
MUL_DONE:
        PUSH    HL
        EXX
        LD      B,H
        LD      C,L
        POP     DE
        JP      FP_NORM
MUL_ZEROB:
        LD      A,E
        LD      E,D
        LD      D,00h
        EXX
        LD      B,E
        LD      E,D
        LD      D,A
        EXX
        JR      MUL_NEXTB
;  OP_DIV – (DE) = (DE) / (HL): Exponenten subtrahieren, Mantissen durch
;  fortgesetztes Subtrahieren teilen, Ergebnisbytes über den Stack
;  sammeln. Division durch 0 und Überlauf: Fehler 2.
; <- aufgerufen von 3664h, 37CEh, 385Bh, 38F7h, 39CBh, 3A6Fh, 3AE9h
OP_DIV: PUSH    DE
        LD      A,(DE)
        XOR     (HL)
        CPL
        AND     80h
        LD      (FPA_SIGN),A
        LD      B,(HL)
        RES     7,B
        LD      A,(DE)
        AND     7Fh
        SUB     B
        ADD     A,81h
DIV_EXP:
        CP      30h                     ; '0'
        JP      C,FP_UNDER
        CP      0E0h
        JP      NC,ERR_02
        LD      (FPA_EXP),A
        INC     HL
        INC     DE
        EX      DE,HL
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        INC     HL
        PUSH    HL
        EX      DE,HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        LD      A,L
        EX      AF,AF'
        LD      A,H
        LD      H,B
        LD      L,C
        EXX
        POP     HL
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        LD      H,A
        EX      AF,AF'
        LD      L,A
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      H,B
        LD      L,C
        LD      A,D
        OR      A
        JP      P,ERR_02
        LD      C,04h
DIV_BYTE:
        LD      B,08h
DIV_BIT:
        BIT     7,H
        JR      NZ,DIV_SUB
        OR      A
DIV_SHIFT:
        RLA
        EXX
        ADD     HL,HL
        EXX
        ADC     HL,HL
        DJNZ    DIV_BIT
        PUSH    AF
        DEC     C
        JR      NZ,DIV_BYTE
DIV_DONE:
        POP     AF
        LD      E,A
        POP     AF
        LD      D,A
        POP     AF
        LD      C,A
        POP     AF
        LD      B,A
        JP      FP_NORM
DIV_SUB:
        EXX
        OR      A
        SBC     HL,DE
        EXX
        SBC     HL,DE
        CCF
        JR      C,DIV_SHIFT
        EXX
        ADD     HL,DE
        EXX
        ADC     HL,DE
        OR      A
        RLA
        EXX
        ADD     HL,HL
        EXX
        ADC     HL,HL
        DEC     B
        JR      NZ,DIV_SUB2
        PUSH    AF
        LD      B,08h
        DEC     C
        JR      Z,DIV_DONE
DIV_SUB2:
        EXX
        OR      A
        SBC     HL,DE
        EXX
        SBC     HL,DE
        SCF
        RLA
        DEC     B
        JR      NZ,DIV_SHL
        PUSH    AF
        LD      B,08h
        DEC     C
        JR      Z,DIV_DONE
DIV_SHL:
        EXX
        ADD     HL,HL
        EXX
        ADC     HL,HL
        JR      NC,DIV_BIT
        JR      DIV_SUB2
NUM_DEXP:
        DEFB    00h                     ; ?? |.|
NUM_DST:
        DEFB    00h,00h                 ; ?? |..|
;  STR2NUM – Zahl im Text (HL) in Gleitkomma nach (DE) wandeln:
;  Ziffern, ".", "E[+|-]nn". Bis zu 9 gültige Ziffern werden als ganze
;  Zahl gesammelt (DIG_MUL10), der Dezimalexponent in NUM_DEXP; danach
;  mit der Zehnerpotenz aus POW10TAB multipliziert. Exponent mit mehr als
;  zwei Ziffern oder zu groß: Fehler 2.
; <- aufgerufen von 275Ah
STR2NUM:
        LD      A,(HL)
        PUSH    HL
        POP     IX
        EX      DE,HL
        LD      (NUM_DST),HL
        EX      AF,AF'
        XOR     A
        LD      (NUM_DEXP),A
        LD      H,A
        LD      L,A
        EXX
        LD      H,A
        LD      L,A
        LD      B,A
        LD      C,A
        EX      AF,AF'
        CP      2Eh                     ; '.'
        JR      Z,S2N_FRAC
        SUB     30h
S2N_INT:
        CALL    DIG_INT
        CALL    S2N_NEXTCH
        SUB     30h
        CP      0Ah
        JR      C,S2N_INT
        ADD     A,30h
        CP      2Eh                     ; '.'
        JR      NZ,S2N_EXPCHK
S2N_FRAC:
        CALL    S2N_NEXTCH
        SUB     30h
        CP      0Ah
        JR      NC,S2N_FRACEND
        CALL    DIG_FRAC
        JR      S2N_FRAC
S2N_FRACEND:
        ADD     A,30h
S2N_EXPCHK:
        CP      45h                     ; 'E'
        JR      NZ,S2N_SCALE
        EXX
        CALL    S2N_NEXTCH
        LD      B,01h
        CP      2Bh                     ; '+'
        JR      Z,S2N_EXPDIG
        CP      2Dh                     ; '-'
        JR      NZ,S2N_EXPNOSGN
        DEC     B
S2N_EXPSGN:
        LD      A,B
S2N_EXPDIG:
        OR      A
        EX      AF,AF'
        CALL    S2N_NEXTCH
        SUB     30h
        NOP
        NOP
        CP      0Ah
        JR      NC,S2N_EXPEND
        LD      B,A
        CALL    S2N_NEXTCH
        SUB     30h
        CP      0Ah
        JR      NC,S2N_EXPEND
        LD      C,A
        CALL    S2N_NEXTCH
        SUB     30h
        CP      0Ah
        JP      C,ERR_02
        LD      A,B
        ADD     A,A
        ADD     A,A
        ADD     A,B
        ADD     A,A
        ADD     A,C
        LD      B,A
S2N_EXPEND:
        EX      AF,AF'
        LD      A,B
        JR      NZ,S2N_EXPSET
        CPL
        INC     A
S2N_EXPSET:
        LD      (NUM_DEXP),A
        EXX
S2N_SCALE:
        PUSH    IX
        LD      A,(NUM_DEXP)
        ADD     A,1Dh
        ADD     A,C
        LD      (NUM_DEXP),A
        CP      30h                     ; '0'
        JR      C,S2N_BIN
        CP      80h
        JP      C,ERR_02
        JR      S2N_ZERO
S2N_EXPNOSGN:
        SUB     30h
        CP      0Ah
        JP      NC,ERR_01
        DEC     IX
        JR      S2N_EXPSGN
S2N_BIN:
        LD      A,80h
        LD      (FPA_SIGN),A
        LD      A,0A0h
        LD      (FPA_EXP),A
        PUSH    HL
        EXX
        POP     BC
        LD      D,H
        LD      E,L
        LD      HL,S2N_POW10
        PUSH    HL
        LD      HL,(NUM_DST)
        PUSH    HL
        JP      FP_NORM
S2N_POW10:
        LD      A,(NUM_DEXP)
        LD      L,A
        LD      C,A
        LD      H,00h
        LD      B,H
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,BC
        LD      BC,POW10TAB
        ADD     HL,BC
        LD      DE,(NUM_DST)
        LD      A,80h
        LD      (FPA_SIGN),A
        LD      A,20h                   ; ' '
        ADD     A,(HL)
        LD      B,A
        LD      A,(DE)
        AND     7Fh
        ADD     A,B
        JP      C,ERR_02
        SUB     21h
        JR      NC,S2N_MUL
        XOR     A
S2N_MUL:
        LD      BC,S2N_RET
        PUSH    BC
        PUSH    DE
        JP      MUL_EXP
S2N_RET:
        POP     HL
        LD      BC,0005h
        LD      D,B
        LD      E,B
        LD      A,(HL)
        RET
S2N_ZERO:
        LD      HL,S2N_RET
        PUSH    HL
        LD      HL,(NUM_DST)
        PUSH    HL
        JP      FP_UNDER
;  S2N_NEXTCH – nächstes Zeichen (IX), Leerzeichen werden überlesen.
; <- aufgerufen von 30CEh, 30DDh, 30F2h, 3103h, 310Fh, 3119h
S2N_NEXTCH:
        INC     IX
        LD      A,(IX+0)
        CP      20h                     ; ' '
        RET     NZ
        JR      S2N_NEXTCH
;  DIG_INT / DIG_FRAC – Ziffer A an die Zahl anhängen (Vor- bzw.
;  Nachkommastelle); C zählt die Stellen für den Dezimalexponenten, mehr
;  als 9 Ziffern werden nur gezählt. DIG_MUL10: Zahl * 10 + A.
; <- aufgerufen von 30CBh, 3514h
DIG_INT:
        OR      A
        JR      NZ,DIG_ADD
        OR      B
        RET     Z
        XOR     A
DIG_ADD:
        EX      AF,AF'
        LD      A,B
        CP      09h
        JR      NZ,DIG_MUL10
        INC     C
        RET
; <- aufgerufen von 30E6h
DIG_FRAC:
        OR      A
        JR      NZ,DIG_FRAC2
        DEC     C
        OR      B
        RET     Z
        INC     C
        XOR     A
DIG_FRAC2:
        EX      AF,AF'
        LD      A,B
        CP      09h
        RET     Z
        DEC     C
DIG_MUL10:
        INC     B
        LD      D,H
        LD      E,L
        EXX
        LD      D,H
        LD      E,L
        XOR     A
        ADD     HL,HL
        RLA
        ADD     HL,HL
        RLA
        ADD     HL,DE
        LD      D,00h
        ADC     A,D
        ADD     HL,HL
        RLA
        EX      AF,AF'
        LD      E,A
        EX      AF,AF'
        ADD     HL,DE
        ADC     A,D
        EXX
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,DE
        ADD     HL,HL
        LD      D,00h
        LD      E,A
        ADD     HL,DE
        RET

; ------------------------------------------------------------------------------
;  POW10TAB – Zehnerpotenzen 10^-29 bis 10^19 (49 Einträge zu 5 Bytes) für
;  STR2NUM, FP2DIGITS und INT. Format wie die Gleitkommazahlen, aber ohne
;  Vorzeichenbit: Exponent = 40h + Zweierexponent (8 Bit, umlaufend),
;  dann die Mantisse (32 Bit, Low-Byte zuerst). Eintrag n = 10^(n-29).
; ------------------------------------------------------------------------------
POW10TAB:
        DEFB    0E0h,0F5h,0F7h,0D2h,0CAh ; 1E-29
        DEFB    0E3h,0F3h,0B5h,87h,0FDh ; 1E-28
        DEFB    0E7h,0B8h,0D1h,74h,9Eh  ; 1E-27
        DEFB    0EAh,25h,06h,12h,0C6h   ; 1E-26
        DEFB    0EDh,0AFh,87h,96h,0F7h  ; 1E-25
        DEFB    0F1h,0CDh,14h,0BEh,9Ah  ; 1E-24
        DEFB    0F4h,01h,9Ah,6Dh,0C1h   ; 1E-23
        DEFB    0F7h,81h,00h,0C9h,0F1h  ; 1E-22
        DEFB    0FBh,50h,0A0h,1Dh,97h   ; 1E-21
POW10_M20:
        DEFB    0FEh,65h,08h,0E5h,0BCh  ; 1E-20
        DEFB    01h,7Eh,4Ah,1Eh,0ECh    ; 1E-19
        DEFB    05h,8Fh,0EEh,92h,93h    ; 1E-18
        DEFB    08h,32h,0AAh,77h,0B8h   ; 1E-17
        DEFB    0Bh,0BFh,94h,95h,0E6h   ; 1E-16
        DEFB    0Fh,0F7h,7Ch,1Dh,90h    ; 1E-15
        DEFB    12h,35h,0DCh,24h,0B4h   ; 1E-14
        DEFB    15h,42h,13h,2Eh,0E1h    ; 1E-13
        DEFB    19h,09h,0CCh,0BCh,8Ch   ; 1E-12
        DEFB    1Ch,0Ch,0FFh,0EBh,0AFh  ; 1E-11
        DEFB    1Fh,0CFh,0FEh,0E6h,0DBh ; 1E-10
        DEFB    23h,41h,5Fh,70h,89h     ; 1E-9
        DEFB    26h,12h,77h,0CCh,0ABh   ; 1E-8
        DEFB    29h,0D6h,94h,0BFh,0D6h  ; 1E-7
        DEFB    2Dh,06h,0BDh,37h,86h    ; 1E-6
        DEFB    30h,47h,0ACh,0C5h,0A7h  ; 1E-5
        DEFB    33h,59h,17h,0B7h,0D1h   ; 1E-4
        DEFB    37h,98h,6Eh,12h,83h     ; 1E-3
        DEFB    3Ah,3Dh,0Ah,0D7h,0A3h   ; 1E-2
        DEFB    3Dh,0CDh,0CCh,0CCh,0CCh ; 1E-1
        DEFB    41h,00h,00h,00h,80h     ; 1E0
        DEFB    44h,00h,00h,00h,0A0h    ; 1E1
        DEFB    47h,00h,00h,00h,0C8h    ; 1E2
        DEFB    4Ah,00h,00h,00h,0FAh    ; 1E3
        DEFB    4Eh,00h,00h,40h,9Ch     ; 1E4
        DEFB    51h,00h,00h,50h,0C3h    ; 1E5
        DEFB    54h,00h,00h,24h,0F4h    ; 1E6
        DEFB    58h,00h,80h,96h,98h     ; 1E7
        DEFB    5Bh,00h,20h,0BCh,0BEh   ; 1E8
        DEFB    5Eh,00h,28h,6Bh,0EEh    ; 1E9
        DEFB    62h,00h,0F9h,02h,95h    ; 1E10
        DEFB    65h,40h,0B7h,43h,0BAh   ; 1E11
        DEFB    68h,10h,0A5h,0D4h,0E8h  ; 1E12
        DEFB    6Ch,2Ah,0E7h,84h,91h    ; 1E13
        DEFB    6Fh,0F5h,20h,0E6h,0B5h  ; 1E14
        DEFB    72h,32h,0A9h,5Fh,0E3h   ; 1E15
        DEFB    76h,0BFh,0C9h,1Bh,8Eh   ; 1E16
        DEFB    79h,2Fh,0BCh,0A2h,0B1h  ; 1E17
        DEFB    7Ch,3Ah,6Bh,0Bh,0DEh    ; 1E18
        DEFB    80h,05h,23h,0C7h,8Ah    ; 1E19
;  N2S_*: Arbeitsbereich von NUM2STR/FP2DIGITS: Zeiger auf die Zahl,
;  Dezimalexponent, Vorzeichenzeichen, Dezimalpunkt und die Ziffern.
N2S_SRC:
        DEFB    00h,00h                 ; ?? |..|
N2S_DEXP:
        DEFB    00h                     ; ?? |.|
N2S_SIGN:
        DEFB    00h                     ; ?? |.|
N2S_POINT:
        DEFB    00h                     ; ?? |.|
N2S_DIGITS:
        DEFB    00h,00h,00h,00h,00h,00h,00h  ; ?? |.......|
N2S_D8: DEFB    00h                     ; ?? |.|
N2S_D9: DEFB    00h                     ; ?? |.|
N2S_BUF2:
        DEFB    00h                     ; ?? |.|
N2S_BUF3:
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h                     ; ?? |.|
;  NUM2STR – Gleitkommazahl (HL) als Text nach (DE): Vorzeichen (" " oder
;  "-"), bis zu 8 Ziffern, Dezimalpunkt; bei sehr großen oder kleinen
;  Zahlen mit Exponent ("E+nn"/"E-nn"), 0 als " 0". Endet mit 0Dh.
; <- aufgerufen von 2A48h, 3CEFh
NUM2STR:
        PUSH    DE
        CALL    FP2DIGITS
        LD      A,(N2S_DEXP)
        OR      A
        JP      Z,N2S_FRAC1
        JP      M,N2S_SMALL
        CP      09h
        JR      C,N2S_FIXED
        JR      N2S_EXPFMT
N2S_SMALL:
        CP      0FFh
        JP      NC,N2S_FRAC2
N2S_EXPFMT:
        LD      A,2Eh                   ; '.'
        LD      (N2S_POINT),A
        LD      HL,N2S_D9
        XOR     A
N2S_TRIM:
        DEC     HL
        CP      (HL)
        JR      Z,N2S_TRIM
        LD      A,(HL)
        CP      2Eh                     ; '.'
        JP      Z,N2S_ZERO
        INC     HL
        LD      (HL),45h
        INC     HL
        LD      A,(N2S_DEXP)
        LD      B,2Bh
        OR      A
        JP      P,N2S_EXPSIGN
        CP      0EDh
        JP      C,N2S_ZERO
        LD      B,2Dh
        CPL
        INC     A
N2S_EXPSIGN:
        LD      (HL),B
        INC     HL
        LD      BC,0FF0Ah
N2S_EXP10:
        INC     B
        SUB     C
        JR      NC,N2S_EXP10
        ADD     A,C
        LD      (HL),B
        INC     HL
        LD      (HL),A
        INC     HL
        LD      (HL),0Dh
N2S_ASCII:
        LD      HL,N2S_SIGN
N2S_ASCII_LP:
        INC     HL
        LD      A,(HL)
        CP      0Dh
        JR      Z,N2S_COPY
        JR      NC,N2S_ASCII_LP
        OR      30h
        LD      (HL),A
        JR      N2S_ASCII_LP
N2S_COPY:
        LD      DE,N2S_SIGN
        XOR     A
        SBC     HL,DE
        LD      B,H
        LD      C,L
        POP     HL
        EX      DE,HL
        INC     BC
        LDIR
        RET
N2S_FIXED:
        LD      HL,N2S_DIGITS
        LD      DE,N2S_POINT
        LD      B,A
        INC     B
N2S_FIX_LP:
        DEC     B
        JR      Z,N2S_FIX_POINT
        LD      A,(HL)
        LD      (DE),A
        INC     HL
        INC     DE
        JR      N2S_FIX_LP
N2S_FIX_POINT:
        LD      A,2Eh                   ; '.'
        LD      (DE),A
        LD      HL,N2S_D9
N2S_FIX_TRIM:
        LD      (HL),0Dh
        DEC     HL
        LD      A,(HL)
        OR      A
        JR      Z,N2S_FIX_TRIM
        CP      2Eh                     ; '.'
        JR      NZ,N2S_FIX_LEAD
        LD      (HL),0Dh
N2S_FIX_LEAD:
        LD      HL,N2S_POINT
        LD      A,(HL)
        CP      0Dh
        JR      NZ,N2S_ASCII
        LD      (HL),00h
        JR      N2S_ASCII
N2S_FRAC2:
        LD      DE,N2S_BUF3
        JR      N2S_FRAC
N2S_FRAC1:
        LD      DE,N2S_BUF2
N2S_FRAC:
        LD      HL,N2S_D8
        LD      A,0Dh
        LD      (DE),A
        PUSH    DE
        DEC     DE
        LD      BC,0008h
        LDDR
        EX      DE,HL
        LD      A,(N2S_DEXP)
        OR      A
        JR      Z,N2S_FRAC_PT
        LD      (HL),00h
        DEC     HL
N2S_FRAC_PT:
        LD      (HL),2Eh
        DEC     HL
        LD      (HL),00h
        POP     HL
N2S_FRAC_TRIM:
        DEC     HL
        LD      A,(HL)
        CP      00h
        JR      NZ,N2S_ASCII
        LD      (HL),0Dh
        JR      N2S_FRAC_TRIM
N2S_ZERO:
        LD      HL,STR_SP0
        LD      BC,0003h
        POP     DE
        LDIR
        RET
STR_SP0:
        DEFB    20h,30h,0Dh             ; ?? | 0.|
;  FP2DIGITS – Betrag der Zahl (HL) in 9 Dezimalziffern (N2S_DIGITS) und
;  den Dezimalexponenten (N2S_DEXP) zerlegen: passende Zehnerpotenz in
;  POW10TAB suchen, dividieren, Ziffern durch fortgesetztes Mal-10 bilden,
;  die 9. Ziffer zum Runden auf 8 Stellen benutzen (F2D_ROUND). Vorzeichen nach N2S_SIGN.
; <- aufgerufen von 3306h, 34D1h
FP2DIGITS:
        LD      (N2S_SRC),HL
        LD      A,(HL)
        LD      B,20h
        OR      A
        JP      M,F2D_ABS
        LD      B,2Dh
F2D_ABS:
        AND     7Fh
        LD      (HL),A
        LD      A,B
        LD      (N2S_SIGN),A
        EX      DE,HL
        LD      HL,POW10_M20
        LD      A,0ECh
        EX      AF,AF'
F2D_SCALE:
        EX      AF,AF'
        INC     A
        EX      AF,AF'
        LD      BC,0005h
        ADD     HL,BC
        PUSH    HL
        PUSH    DE
        LD      A,(DE)
        CALL    FP_CMP_EXP
        POP     DE
        POP     HL
        JR      NC,F2D_SCALE
        EX      AF,AF'
        LD      (N2S_DEXP),A
        PUSH    DE
        LD      BC,F2D_DIGITS
        PUSH    BC
        PUSH    DE
        LD      A,80h
        LD      (FPA_SIGN),A
        LD      A,(DE)
        SUB     (HL)
        ADD     A,81h
        JP      DIV_EXP
;  F2D_DIGITS – Fortsetzung nach der Division (über LD BC,F2D_DIGITS /
;  PUSH BC als Rücksprung eingesetzt, keine Inline-Parameter).
F2D_DIGITS:
        LD      HL,N2S_POINT
        LD      (HL),00h
        INC     HL
        EX      (SP),HL
        LD      A,(HL)
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        PUSH    HL
        EX      DE,HL
        EXX
        POP     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        SUB     0C0h
        JR      NC,F2D_GEN
F2D_SHR:
        SRL     H
        RR      L
        EXX
        RR      H
        RR      L
        EXX
        INC     A
        JR      NZ,F2D_SHR
F2D_GEN:
        POP     BC
        LD      A,09h
F2D_GEN_LP:
        EX      AF,AF'
        XOR     A
        LD      D,H
        LD      E,L
        EXX
        LD      D,H
        LD      E,L
        ADD     HL,HL
        EXX
        ADC     HL,HL
        RLA
        EXX
        ADD     HL,HL
        EXX
        ADC     HL,HL
        RLA
        EXX
        ADD     HL,DE
        EXX
        ADC     HL,DE
        LD      D,00h
        ADC     A,D
        EXX
        ADD     HL,HL
        EXX
        ADC     HL,HL
        RLA
        LD      (BC),A
        INC     BC
        EX      AF,AF'
        DEC     A
        JR      NZ,F2D_GEN_LP
F2D_ROUND:
        LD      HL,N2S_D9
        LD      A,(HL)
        LD      (HL),00h
        CP      05h
        LD      C,00h
        JR      C,F2D_RND_GO
        INC     C
F2D_RND_GO:
        LD      B,0Ah
F2D_RND_LP:
        DEC     B
        JR      Z,F2D_RND_OVF
        DEC     HL
        LD      A,(HL)
        ADD     A,C
        LD      (HL),A
        SUB     0Ah
        LD      C,00h
        JR      C,F2D_RND_LP
        INC     C
        LD      (HL),A
        JR      F2D_RND_LP
F2D_RND_OVF:
        LD      A,(N2S_POINT)
        OR      A
        RET     Z
        LD      HL,N2S_D8
        LD      DE,N2S_D9
        LD      BC,0009h
        LDDR
        EX      DE,HL
        LD      (HL),00h
        LD      A,(N2S_DEXP)
        INC     A
        LD      (N2S_DEXP),A
        JR      F2D_ROUND
;  FP_CMP – (DE) mit (HL) vergleichen: Z = gleich, C = (DE) < (HL).
; <- aufgerufen von 35ADh, 35C2h, 35CAh, 35D6h, 3ACDh
FP_CMP: LD      BC,0005h
; <- aufgerufen von 224Ch, 225Fh
FP_CMP_BC:
        LD      A,(DE)
        OR      A
        JP      M,FP_CMP_EXP
        BIT     7,(HL)
        JR      Z,FP_CMP_NEG
        SCF
        RET
FP_CMP_NEG:
        EX      DE,HL
        LD      A,(DE)
; <- aufgerufen von 3405h
FP_CMP_EXP:
        CP      (HL)
        RET     NZ
        DEC     C
        ADD     HL,BC
        EX      DE,HL
        ADD     HL,BC
        EX      DE,HL
        LD      B,03h
FP_CMP_LP:
        LD      A,(DE)
        CP      (HL)
        RET     NZ
        DEC     HL
        DEC     DE
        DJNZ    FP_CMP_LP
        LD      A,(DE)
        CP      (HL)
        RET
;  FN_INT – INT(x): größte ganze Zahl <= x. Über die Dezimalziffern
;  (FP2DIGITS): Nachkommastellen abschneiden, bei negativen Zahlen mit
;  Rest um 1 erhöhen, dann wieder zusammensetzen.
; <- aufgerufen von 3BFAh
FN_INT: EX      DE,HL
        CALL    FP2DIGITS
        LD      A,(N2S_SIGN)
        LD      B,80h
        CP      20h                     ; ' '
        JR      Z,INT_SIGN
        LD      B,00h
INT_SIGN:
        LD      A,B
        LD      (FPA_SIGN),A
        OR      A
        JR      Z,INT_NEG
        LD      A,(N2S_DEXP)
        DEC     A
        JP      M,INT_ZERO
        LD      HL,N2S_D9
        LD      B,0Dh
        LD      (HL),B
        SUB     08h
        JR      NC,INT_REBUILD
INT_CUT_LP:
        LD      (HL),B
        DEC     HL
        INC     A
        JR      NZ,INT_CUT_LP
        DEC     A
INT_REBUILD:
        INC     A
        LD      (NUM_DEXP),A
        LD      IX,N2S_POINT
        XOR     A
        LD      H,A
        LD      L,A
        EXX
        LD      B,A
        LD      C,A
        LD      H,A
        LD      L,A
INT_DIG_LP:
        LD      A,(IX+0)
        CP      0Dh
        JR      Z,INT_SCALE
        CALL    DIG_INT
        INC     IX
        JR      INT_DIG_LP
INT_SCALE:
        LD      A,(NUM_DEXP)
        ADD     A,1Dh
        ADD     A,C
        LD      (NUM_DEXP),A
        LD      A,0A0h
        LD      (FPA_EXP),A
        PUSH    HL
        EXX
        POP     BC
        LD      D,H
        LD      E,L
        LD      HL,INT_POW10
        PUSH    HL
        LD      HL,(N2S_SRC)
        PUSH    HL
        JP      FP_NORM
INT_POW10:
        LD      A,(NUM_DEXP)
        LD      C,A
        LD      L,A
        LD      H,00h
        LD      B,H
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,BC
        LD      BC,POW10TAB
        ADD     HL,BC
        LD      DE,(N2S_SRC)
        XOR     A
        LD      (FPA_FLAG),A
        LD      A,20h                   ; ' '
        ADD     A,(HL)
        LD      B,A
        LD      A,(DE)
        AND     7Fh
        ADD     A,B
        JP      C,ERR_02
        SUB     21h
        JR      NC,INT_MUL
        XOR     A
INT_MUL:
        PUSH    DE
        JP      MUL_EXP
INT_NEG:
        LD      A,(N2S_DEXP)
        DEC     A
        JP      M,INT_MONE
        LD      HL,N2S_D9
        LD      BC,0D00h
        LD      (HL),B
        SUB     08h
        JR      NC,INT_NEG_UP
        JR      INT_NEG_NEXT
INT_NEG_LP:
        EX      AF,AF'
        LD      A,(HL)
        OR      A
        JR      Z,INT_NEG_CLR
        INC     C
INT_NEG_CLR:
        LD      (HL),B
        EX      AF,AF'
INT_NEG_NEXT:
        DEC     HL
        INC     A
        JR      NZ,INT_NEG_LP
        DEC     A
INT_NEG_UP:
        EX      AF,AF'
        LD      A,C
        OR      A
        JR      Z,INT_NEG_GO
INT_NEG_INC:
        LD      A,(HL)
        INC     A
        LD      (HL),A
        CP      0Ah
        JR      NZ,INT_NEG_GO
        LD      (HL),00h
        DEC     HL
        JR      INT_NEG_INC
INT_NEG_GO:
        EX      AF,AF'
        JP      INT_REBUILD
INT_ZERO:
        LD      DE,FP_ZERO
        JR      INT_CONST
INT_MONE:
        LD      DE,FP_MONE
INT_CONST:
        LD      HL,(N2S_SRC)
        EX      DE,HL
;  FP_MOVE – 5 Bytes von (HL) nach (DE) kopieren.
; <- aufgerufen von 3615h, 36D2h, 36DBh, 36E7h, 3763h, 3770h, 3778h, 37B1h (+20 weitere)
FP_MOVE:
        LD      BC,0005h
        LDIR
        RET
;  Vergleichsoperatoren: (DE) = -1 (wahr) oder 0 (falsch), über FP_CMP.
OP_NE2: PUSH    DE
        CALL    FP_CMP
        JR      Z,CMP_FALSE
CMP_TRUE:
        LD      HL,FP_MONE
        JR      CMP_STORE
CMP_FALSE:
        LD      HL,FP_ZERO
CMP_STORE:
        POP     DE
        JR      FP_MOVE
OP_GT:  PUSH    DE
        EX      DE,HL
        JR      CMP_LESS
OP_LT:  PUSH    DE
CMP_LESS:
        CALL    FP_CMP
        JR      C,CMP_TRUE
        JR      CMP_FALSE
OP_EQ:  PUSH    DE
        CALL    FP_CMP
        JR      Z,CMP_TRUE
        JR      CMP_FALSE
OP_LE2: PUSH    DE
        EX      DE,HL
        JR      CMP_GE
OP_GE2: PUSH    DE
CMP_GE: CALL    FP_CMP
        JR      C,CMP_FALSE
        JR      CMP_TRUE
;  RND_SEED: aktueller Startwert; RND_SEED0: Startwert nach dem Rücksetzen.
RND_SEED:
        DEFB    0BEh,35h,28h,0DCh,0CFh  ; FP-Konstante = 0.20298827
;  FN_RND – RND(x): x > 0 nächste Zufallszahl (Startwert * 23, ganzzahliger
;  Teil abgeschnitten), x <= 0 Startwert zurücksetzen.
FN_RND: PUSH    DE
        EX      DE,HL
        LD      A,(HL)
        LD      BC,0004h
        ADD     HL,BC
        XOR     (HL)
        JP      M,RND_RESET
        LD      DE,RND_SEED
        PUSH    DE
        LD      HL,FPK_23
        CALL    OP_MUL
        POP     HL
        PUSH    HL
        LD      A,(HL)
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        CP      0C1h
        CALL    NC,RND_FRAC
        POP     HL
        PUSH    HL
        CALL    FP_STORE
        JR      RND_RET
RND_RESET:
        LD      DE,RND_SEED
        LD      HL,RND_SEED0
        PUSH    DE
        CALL    FP_MOVE
RND_RET:
        POP     HL
        POP     DE
        JR      FP_MOVE
; <- aufgerufen von 3604h
RND_FRAC:
        SUB     0C0h
RND_FRAC_LP:
        SLA     E
        RL      D
        RL      C
        RL      B
        DEC     A
        JR      NZ,RND_FRAC_LP
        LD      A,0C0h
        JP      FP_NORM_A
RND_SEED0:
        DEFB    0BEh,35h,28h,0DCh,0CFh  ; FP-Konstante = 0.20298827
FPK_23:
        DEFB    0C5h,00h,00h,00h,0B8h   ; FP-Konstante = 23
FP_W1:
        DEFB    00h,00h,00h,00h,00h     ; FP-Konstante = 0
FP_W2:
        DEFB    00h,00h,00h,00h,00h     ; FP-Konstante = 0
FP_W3:
        DEFB    00h,00h,00h,00h,00h     ; FP-Konstante = 0
FP_W4:
        DEFB    00h,00h,00h,00h,00h     ; FP-Konstante = 0
;  FPW1_ADD – FP_W1 = FP_W1 + (HL). FPW1_MUL: FP_W1 = FP_W1 * (HL).
;  FPW1_ADDMUL: FP_W1 = (FP_W1 + (HL)) * FP_W2. Damit werten SIN, EXP, LN
;  und ATN ihre Polynome nach Horner aus.
; <- aufgerufen von 3652h, 3705h, 37BDh, 37D4h, 3884h, 388Fh, 389Ah, 38A5h (+6 weitere)
FPW1_ADD:
        LD      DE,FP_W1
        JP      OP_ADD
; <- aufgerufen von 36F3h, 36F9h, 36FFh, 39F8h, 39FEh, 3B0Fh, 3B15h, 3B1Bh (+5 weitere)
FPW1_ADDMUL:
        CALL    FPW1_ADD
; <- aufgerufen von 36DEh
FPW1_MULW2:
        LD      HL,FP_W2
; <- aufgerufen von 36EDh, 37B7h, 382Eh, 387Eh, 3889h, 3894h, 389Fh, 38AAh (+7 weitere)
FPW1_MUL:
        LD      DE,FP_W1
        JP      OP_MUL
SIN_FLAGS:
        DEFB    00h                     ; ?? |.|
SIN_SIGN:
        DEFB    00h                     ; ?? |.|
;  FN_SIN – SIN(x): x / (Pi/2), in den Bereich 0-1 mit Quadrant zurückführen,
;  Polynom in x^2 (SIN_C1..SIN_PI2) auswerten, Vorzeichen nach Quadrant.
;  FN_COS: SIN(Pi/2 - x). FN_TAN: SIN(x)/COS(x).
; <- aufgerufen von 377Dh
FN_SIN: PUSH    DE
        LD      HL,FP_PI2
        CALL    OP_DIV
        POP     HL
        PUSH    HL
        LD      A,(HL)
        LD      (SIN_SIGN),A
        OR      80h
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        CP      0C3h
        JR      C,SIN_QUAD
        SUB     0C2h
SIN_RED:
        SLA     E
        RL      D
        RL      C
        RL      B
        DEC     A
        JR      NZ,SIN_RED
        LD      A,0C2h
        CALL    FP_NORM_A
SIN_QUAD:
        LD      HL,8000h
        CP      0C2h
        JR      C,SIN_QUAD2
        LD      H,L
        RES     7,B
        CALL    FP_NORM_A
SIN_QUAD2:
        CP      0C1h
        JR      C,SIN_QSIGN
        INC     L
        RES     7,B
        CALL    FP_NORM_A
SIN_QSIGN:
        EX      AF,AF'
        LD      A,(SIN_SIGN)
        XOR     H
        CPL
        AND     80h
        LD      H,A
        LD      (SIN_FLAGS),HL
        EX      AF,AF'
        POP     HL
        PUSH    HL
        CALL    FP_STORE
        LD      A,(SIN_FLAGS)
        OR      A
        JR      Z,SIN_POLY
        POP     DE
        PUSH    DE
        LD      HL,FP_ONE
        CALL    OP_SUB
SIN_POLY:
        POP     HL
        PUSH    HL
        LD      A,(HL)
        AND     7Fh
        LD      B,A
        LD      A,(SIN_SIGN)
        OR      B
        LD      (HL),A
        LD      DE,FP_W1
        CALL    FP_MOVE
        LD      DE,FP_W2
        LD      HL,FP_W1
        CALL    FP_MOVE
        CALL    FPW1_MULW2
        LD      DE,FP_W2
        LD      HL,FP_W1
        CALL    FP_MOVE
        LD      HL,SIN_C1
        CALL    FPW1_MUL
        LD      HL,SIN_C2
        CALL    FPW1_ADDMUL
        LD      HL,SIN_C3
        CALL    FPW1_ADDMUL
        LD      HL,SIN_C4
        CALL    FPW1_ADDMUL
        LD      HL,SIN_PI2
        CALL    FPW1_ADD
        POP     DE
        LD      HL,FP_W1
        JP      OP_MUL
;  FP_NORM_A – Mantisse normieren, Exponent in A; 0 ergibt FP_ZERO_REGS.
; <- aufgerufen von 368Ah, 3697h, 36A1h, 3928h
FP_NORM_A:
        BIT     7,B
        RET     NZ
        EX      AF,AF'
        LD      A,B
        OR      C
        OR      E
        OR      D
        JR      Z,FP_ZERO_REGS
        EX      AF,AF'
FP_NORM_A_LP:
        BIT     7,B
        RET     NZ
        SLA     E
        RL      D
        RL      C
        RL      B
        DEC     A
        JR      NZ,FP_NORM_A_LP
; <- aufgerufen von 2ECEh
FP_ZERO_REGS:
        LD      BC,0000h
        LD      DE,0000h
        LD      A,80h
        RET
FP_PI2: DEFB    0C1h,0A1h,0DAh,0Fh,0C9h ; FP-Konstante = 1.57079633
SIN_C1:
        DEFB    0B4h,0DCh,0Fh,0Ah,9Fh   ; FP-Konstante = 0.0001516717
SIN_C2:
        DEFB    39h,61h,8Fh,29h,99h     ; FP-Konstante = -0.0046741438
SIN_C3:
        DEFB    0BDh,0C8h,77h,34h,0A3h  ; FP-Konstante = 0.0796899183
SIN_C4:
        DEFB    40h,85h,0E1h,5Dh,0A5h   ; FP-Konstante = -0.645963759
SIN_PI2:
        DEFB    0C1h,94h,0DAh,0Fh,0C9h  ; FP-Konstante = 1.57079632
; <- aufgerufen von 3768h
FN_COS: PUSH    DE
        LD      HL,FP_PI2
        CALL    OP_SUB
        POP     HL
        CALL    FP_NEG
        EX      DE,HL
        JP      FN_SIN
FN_TAN: PUSH    DE
        EX      DE,HL
        LD      DE,FP_W4
        CALL    FP_MOVE
        POP     DE
        PUSH    DE
        CALL    FN_COS
        POP     HL
        PUSH    HL
        LD      DE,FP_W3
        CALL    FP_MOVE
        POP     DE
        PUSH    DE
        LD      HL,FP_W4
        CALL    FP_MOVE
        POP     DE
        PUSH    DE
        CALL    FN_SIN
        POP     DE
        LD      HL,FP_W3
        JP      OP_DIV
SQR_ITER:
        DEFB    00h                     ; ?? |.|
SQR_EXP:
        DEFB    00h                     ; ?? |.|
;  FN_SQR – SQR(x): negativ Fehler 3. Exponent halbieren, Startwert aus
;  einer linearen Näherung (SQR_K1..K4, gerader/ungerader Exponent), dann
;  3 Newton-Schritte (x = (x + a/x) / 2).
; <- aufgerufen von 3997h
FN_SQR: LD      A,03h
        LD      (SQR_ITER),A
        PUSH    DE
        EX      DE,HL
        LD      A,(HL)
        ADD     A,80h
        JP      NC,ERR_03
        JR      NZ,SQR_EVEN
        EX      AF,AF'
        LD      BC,0004h
        ADD     HL,BC
        LD      A,(HL)
        SBC     HL,BC
        OR      A
        JP      P,SQR_ZERO
        EX      AF,AF'
SQR_EVEN:
        BIT     0,A
        JR      NZ,SQR_ODD
        LD      (SQR_EXP),A
        LD      (HL),0C0h
        LD      DE,FP_W1
        CALL    FP_MOVE
        LD      HL,SQR_K1
        CALL    FPW1_MUL
        LD      HL,SQR_K2
SQR_START:
        CALL    FPW1_ADD
SQR_NEWTON:
        LD      DE,FP_W2
        POP     HL
        PUSH    HL
        CALL    FP_MOVE
        LD      DE,FP_W2
        LD      HL,FP_W1
        CALL    OP_DIV
        LD      HL,FP_W2
        CALL    FPW1_ADD
        LD      HL,FP_W1
        LD      A,(HL)
        AND     7Fh
        DEC     A
        JR      C,SQR_ZERO
        OR      80h
        LD      (HL),A
        LD      A,(SQR_ITER)
        DEC     A
        LD      (SQR_ITER),A
        JR      NZ,SQR_NEWTON
        LD      A,(SQR_EXP)
        CP      40h                     ; '@'
        CALL    NZ,SQR_HALFEXP
        LD      B,(HL)
        RES     7,B
        ADD     A,B
        SUB     40h
        JR      C,SQR_ZERO
        JP      M,ERR_02
        OR      80h
        LD      (HL),A
        JR      SQR_STORE
SQR_ZERO:
        LD      HL,FP_ZERO
SQR_STORE:
        POP     DE
        JP      FP_MOVE
; <- aufgerufen von 37F1h
SQR_HALFEXP:
        JR      C,SQR_HALFNEG
        SUB     40h
        SRL     A
        ADD     A,40h
        RET
SQR_HALFNEG:
        LD      B,A
        LD      A,40h                   ; '@'
        SUB     B
        SRL     A
        LD      B,A
        LD      A,40h                   ; '@'
        SUB     B
        RET
SQR_ODD:
        INC     A
        LD      (SQR_EXP),A
        LD      (HL),0BFh
        LD      DE,FP_W1
        CALL    FP_MOVE
        LD      HL,SQR_K3
        CALL    FPW1_MUL
        LD      HL,SQR_K4
        JP      SQR_START
SQR_K1: DEFB    0C0h,00h,00h,00h,90h    ; FP-Konstante = 0.5625
SQR_K2:
        DEFB    0BFh,00h,00h,00h,0E0h   ; FP-Konstante = 0.4375
SQR_K3:
        DEFB    0C0h,00h,00h,00h,0E0h   ; FP-Konstante = 0.875
SQR_K4:
        DEFB    0BFh,00h,00h,00h,90h    ; FP-Konstante = 0.28125
EXP_SIGN:
        DEFB    00h                     ; ?? |.|
EXP_INT:
        DEFB    00h                     ; ?? |.|
;  FN_EXP – EXP(x): x / ln 2 in ganzzahligen Teil (Zweierexponent) und Rest
;  zerlegen, 2^Rest über ein Polynom (EXP_C0..EXP_SQRTH), bei negativem x
;  der Kehrwert. Überlauf: Fehler 2.
; <- aufgerufen von 3BD4h
FN_EXP: PUSH    DE
        LD      A,(DE)
        AND     80h
        LD      (EXP_SIGN),A
        LD      A,(DE)
        OR      80h
        LD      (DE),A
        LD      HL,EXP_LN2
        CALL    OP_DIV
        POP     HL
        PUSH    HL
        LD      A,40h                   ; '@'
        LD      (EXP_INT),A
        LD      A,(HL)
        SUB     0C1h
        CALL    NC,EXP_SPLIT
        POP     DE
        PUSH    DE
        LD      HL,EXP_HALF
        CALL    OP_SUB
        POP     HL
        PUSH    HL
        LD      DE,FP_W1
        CALL    FP_MOVE
        LD      HL,EXP_C0
        CALL    FPW1_MUL
        LD      HL,EXP_C1
        CALL    FPW1_ADD
        POP     HL
        PUSH    HL
        CALL    FPW1_MUL
        LD      HL,EXP_C2
        CALL    FPW1_ADD
        POP     HL
        PUSH    HL
        CALL    FPW1_MUL
        LD      HL,EXP_C3
        CALL    FPW1_ADD
        POP     HL
        PUSH    HL
        CALL    FPW1_MUL
        LD      HL,EXP_C4
        CALL    FPW1_ADD
        POP     HL
        PUSH    HL
        CALL    FPW1_MUL
        LD      HL,EXP_C5
        CALL    FPW1_ADD
        POP     HL
        PUSH    HL
        CALL    FPW1_MUL
        LD      HL,EXP_SQRTH
        CALL    FPW1_ADD
        LD      HL,FP_W1
        LD      B,(HL)
        RES     7,B
        LD      A,(EXP_INT)
        ADD     A,B
        JP      C,EXP_OVF
        SUB     3Fh
        JR      C,EXP_UNDER
        JP      M,EXP_OVF
        OR      80h
        LD      (HL),A
        LD      A,(EXP_SIGN)
        OR      A
        JR      Z,EXP_RECIP
        LD      HL,FP_W1
        POP     DE
        JP      FP_MOVE
EXP_RECIP:
        POP     DE
        PUSH    DE
        LD      HL,FP_ONE
        CALL    FP_MOVE
        POP     DE
        PUSH    DE
        LD      A,(DE)
        CP      0FCh
        PUSH    AF
        JR      C,EXP_RECIP2
        DEC     A
        LD      (DE),A
EXP_RECIP2:
        LD      HL,FP_W1
        CALL    OP_DIV
        POP     AF
        POP     HL
        RET     C
        LD      A,(HL)
        DEC     A
        LD      (HL),A
        RET     M
        PUSH    HL
        JP      FP_UNDER
; <- aufgerufen von 3868h
EXP_SPLIT:
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        PUSH    HL
        INC     A
        LD      H,A
        XOR     A
EXP_SPLIT_LP:
        SLA     E
        RL      D
        RL      C
        RL      B
        RLA
        JR      C,EXP_OVF2
        DEC     H
        JR      NZ,EXP_SPLIT_LP
        ADD     A,40h
        JR      C,EXP_OVF2
        LD      (EXP_INT),A
        LD      A,0C0h
        CALL    FP_NORM_A
        POP     HL
        LD      (HL),B
        DEC     HL
        LD      (HL),C
        DEC     HL
        LD      (HL),D
        DEC     HL
        LD      (HL),E
        DEC     HL
        LD      (HL),A
        RET
EXP_UNDER:
        LD      A,(EXP_SIGN)
        OR      A
        JP      Z,ERR_02
EXP_ZERO:
        LD      HL,FP_ZERO
        POP     DE
        JP      FP_MOVE
EXP_OVF2:
        POP     AF
        POP     AF
EXP_OVF:
        LD      A,(EXP_SIGN)
        OR      A
        JP      NZ,ERR_02
        JR      EXP_ZERO
EXP_C0: DEFB    0B3h,7Ch,8Ch,90h,0E3h   ; FP-Konstante = 0.000108511278
EXP_C1:
        DEFB    0B6h,1Fh,0DFh,62h,0F8h  ; FP-Konstante = 0.000947518223
EXP_C2:
        DEFB    0B9h,0E2h,6Dh,0DDh,0DEh ; FP-Konstante = 0.00680129876
EXP_C3:
        DEFB    0BCh,8Bh,33h,0C1h,0A0h  ; FP-Konstante = 0.0392467512
EXP_C4:
        DEFB    0BEh,89h,4Ah,0F1h,0ADh  ; FP-Konstante = 0.169865765
EXP_C5:
        DEFB    0BFh,34h,33h,0F2h,0FAh  ; FP-Konstante = 0.490129089
EXP_SQRTH:
        DEFB    0C0h,36h,0F3h,04h,0B5h  ; FP-Konstante = 0.707106782
EXP_HALF:
        DEFB    0C0h,00h,00h,00h,80h    ; FP-Konstante = 0.5
EXP_LN2:
        DEFB    0C0h,0F8h,17h,72h,0B1h  ; FP-Konstante = 0.693147181
LN_SQRFLAG:
        DEFB    00h                     ; ?? |.|
LN_SIGN:
        DEFB    00h                     ; ?? |.|
LN_EXP: DEFB    00h                     ; ?? |.|
;  FN_LN – LN(x): negatives Argument Fehler 2. Zweierexponent abtrennen,
;  Mantisse über (m - Wurzel 2)/(m + Wurzel 2) in eine schnell
;  konvergierende Reihe (LN_C0..LN_C5), Exponent * ln 2 addieren; kleine
;  Werte über den Kehrwert (LN_RECIP).
; <- aufgerufen von 3AAFh, 3BC0h
FN_LN:  PUSH    DE
        LD      A,80h
        LD      (LN_SIGN),A
        LD      (LN_SQRFLAG),A
        EX      DE,HL
        LD      A,(HL)
        OR      A
        JP      P,ERR_02
        CP      8Ah
        JR      NC,LN_RANGE
        XOR     A
        LD      (LN_SQRFLAG),A
        EX      DE,HL
        CALL    FN_SQR
        POP     HL
        PUSH    HL
        LD      A,(HL)
LN_RANGE:
        CP      0C1h
        CALL    C,LN_RECIP
        LD      B,00h
        CP      0C1h
        JR      Z,LN_SERIES
        SUB     0C1h
        LD      B,A
        LD      A,0C1h
        LD      (HL),A
LN_SERIES:
        LD      A,B
        LD      (LN_EXP),A
        LD      DE,FP_W1
        CALL    FP_MOVE
        POP     DE
        PUSH    DE
        LD      HL,LN_SQRT2
        CALL    OP_SUB
        LD      HL,LN_SQRT2
        CALL    FPW1_ADD
        POP     DE
        PUSH    DE
        LD      HL,FP_W1
        CALL    OP_DIV
        POP     DE
        PUSH    DE
        LD      HL,LN_C5
        CALL    OP_MUL
        POP     HL
        PUSH    HL
        LD      DE,FP_W2
        CALL    FP_MOVE
        POP     HL
        PUSH    HL
        LD      DE,FP_W2
        CALL    OP_MUL
        LD      DE,FP_W1
        LD      HL,FP_W2
        CALL    FP_MOVE
        LD      HL,LN_C0
        CALL    FPW1_MUL
        LD      HL,LN_C1
        CALL    FPW1_ADDMUL
        LD      HL,LN_C2
        CALL    FPW1_ADDMUL
        LD      HL,LN_C3
        CALL    FPW1_ADD
        POP     HL
        PUSH    HL
        CALL    FPW1_MUL
        LD      DE,FP_W2
        LD      HL,FP_W1
        CALL    FP_MOVE
        LD      A,(LN_EXP)
        ADD     A,A
        INC     A
        LD      B,A
        LD      A,08h
LN_EXPNORM:
        BIT     7,B
        JR      NZ,LN_EXPADD
        SLA     B
        DEC     A
        JR      NZ,LN_EXPNORM
LN_EXPADD:
        ADD     A,0C0h
        LD      HL,FP_W1
        LD      (HL),A
        INC     HL
        XOR     A
        LD      (HL),A
        INC     HL
        LD      (HL),A
        INC     HL
        LD      (HL),A
        INC     HL
        LD      (HL),B
        LD      HL,LN_LN2H
        CALL    FPW1_MUL
        LD      HL,FP_W2
        CALL    FPW1_ADD
        LD      HL,FP_W1
        LD      A,(LN_SIGN)
        CALL    FP_SETSIGN
        POP     DE
        PUSH    DE
        CALL    FP_MOVE
        POP     DE
        LD      A,(LN_SQRFLAG)
        OR      A
        RET     NZ
        LD      HL,FP_W1
        JP      OP_ADD
; <- aufgerufen von 399Fh
LN_RECIP:
        PUSH    HL
        LD      DE,FP_W1
        CALL    FP_MOVE
        POP     DE
        PUSH    DE
        LD      HL,FP_ONE
        CALL    FP_MOVE
        POP     DE
        PUSH    DE
        LD      HL,FP_W1
        CALL    OP_DIV
        POP     HL
        LD      A,(HL)
        CP      0C1h
        JR      NC,LN_RECIP_RET
        PUSH    HL
        EX      DE,HL
        LD      HL,FP_ONE
        CALL    FP_MOVE
        POP     HL
        LD      A,0C1h
LN_RECIP_RET:
        EX      AF,AF'
        LD      A,00h
        LD      (LN_SIGN),A
        EX      AF,AF'
        RET
LN_C0:  DEFB    0ADh,0A4h,62h,0CCh,0AFh ; FP-Konstante = 1.3098e-06
LN_C1:
        DEFB    0B2h,9Fh,0E9h,47h,0F9h  ; FP-Konstante = 5.94332e-05
LN_C2:
        DEFB    0B8h,0A4h,82h,0AAh,0DCh ; FP-Konstante = 0.0033670968
LN_C3:
        DEFB    0BFh,0BFh,0CCh,0B0h,0AFh  ; FP-Konstante = 0.34314575
LN_SQRT2:
        DEFB    0C1h,33h,0F3h,04h,0B5h  ; FP-Konstante = 1.41421356
LN_C5:
        DEFB    0C3h,99h,79h,82h,0BAh   ; FP-Konstante = 5.82842712
LN_LN2H:
        DEFB    0BFh,0F8h,17h,72h,0B1h  ; FP-Konstante = 0.34657359
;  FN_LOG – LOG(x) = LN(x) * 0,434294482 (1/ln 10).
FN_LOG: PUSH    DE
        CALL    FN_LN
        POP     DE
        LD      HL,LOG_K
        JP      OP_MUL
LOG_K:  DEFB    0BFh,0A9h,0D8h,5Bh,0DEh ; FP-Konstante = 0.434294482
ATN_SIGN:
        DEFB    00h                     ; ?? |.|
ATN_RECIP:
        DEFB    00h                     ; ?? |.|
;  FN_ATN – ATN(x): |x| > 1 über den Kehrwert (Ergebnis Pi/2 - ATN(1/x)),
;  Polynom in x^2 (ATN_C0..ATN_C8), Vorzeichen zurück.
FN_ATN: PUSH    DE
        EX      DE,HL
        LD      A,(HL)
        AND     80h
        LD      (ATN_SIGN),A
        SET     7,(HL)
        LD      DE,FP_ONE
        CALL    FP_CMP
        LD      A,80h
        JR      NC,ATN_SERIES
        LD      DE,FP_W1
        POP     HL
        PUSH    HL
        CALL    FP_MOVE
        POP     DE
        PUSH    DE
        LD      HL,FP_ONE
        CALL    FP_MOVE
        POP     DE
        PUSH    DE
        LD      HL,FP_W1
        CALL    OP_DIV
        XOR     A
ATN_SERIES:
        LD      (ATN_RECIP),A
        POP     HL
        PUSH    HL
        LD      DE,FP_W1
        CALL    FP_MOVE
        POP     HL
        PUSH    HL
        CALL    FPW1_MUL
        LD      HL,FP_W1
        LD      DE,FP_W2
        CALL    FP_MOVE
        LD      HL,ATN_C0
        CALL    FPW1_MUL
        LD      HL,ATN_C1
        CALL    FPW1_ADDMUL
        LD      HL,ATN_C2
        CALL    FPW1_ADDMUL
        LD      HL,ATN_C3
        CALL    FPW1_ADDMUL
        LD      HL,ATN_C4
        CALL    FPW1_ADDMUL
        LD      HL,ATN_C5
        CALL    FPW1_ADDMUL
        LD      HL,ATN_C6
        CALL    FPW1_ADDMUL
        LD      HL,ATN_C7
        CALL    FPW1_ADDMUL
        LD      HL,ATN_C8
        CALL    FPW1_ADDMUL
        LD      HL,FP_ONE
        CALL    FPW1_ADD
        POP     HL
        PUSH    HL
        CALL    FPW1_MUL
        POP     DE
        PUSH    DE
        LD      HL,FP_W1
        CALL    FP_MOVE
        LD      A,(ATN_RECIP)
        OR      A
        JR      NZ,ATN_SETSIGN
        POP     DE
        PUSH    DE
        LD      HL,FP_PI2
        CALL    FP_MOVE
        POP     DE
        PUSH    DE
        LD      HL,FP_W1
        CALL    OP_SUB
ATN_SETSIGN:
        POP     HL
        LD      A,(ATN_SIGN)
        JR      FP_SETSIGN
ATN_C0: DEFB    37h,0CAh,9Ah,56h,0DFh   ; FP-Konstante = -0.001703936
ATN_C1:
        DEFB    0BAh,12h,77h,0CCh,0ABh  ; FP-Konstante = 0.01048576
ATN_C2:
        DEFB    3Bh,23h,0B2h,5Eh,0F8h   ; FP-Konstante = -0.030318592
ATN_C3:
        DEFB    0BCh,20h,63h,90h,0E9h   ; FP-Konstante = 0.057022464
ATN_C4:
        DEFB    3Dh,0EEh,3Dh,0E0h,0AAh  ; FP-Konstante = -0.08343552
ATN_C5:
        DEFB    0BDh,4Fh,1Ah,0D5h,0DFh  ; FP-Konstante = 0.10929318
ATN_C6:
        DEFB    3Eh,0E3h,0AFh,03h,92h   ; FP-Konstante = -0.14259219
ATN_C7:
        DEFB    0BEh,2Ah,7Bh,0C7h,0CCh  ; FP-Konstante = 0.19997971
ATN_C8:
        DEFB    3Fh,17h,96h,0AAh,0AAh   ; FP-Konstante = -0.33333272
POW_TMP:
        DEFB    00h,00h,00h,00h         ; ?? |....|
POW_TMP4:
        DEFB    00h                     ; ?? |.|
POW_SIGN:
        DEFB    00h                     ; ?? |.|
POW_EXP:
        DEFB    00h,00h,00h,00h,00h     ; ?? |.....|
;  OP_POW – (DE) = (DE) ^ (HL) = EXP(HL * LN(DE)). Basis 0: 0. Negative
;  Basis nur mit ganzzahligem Exponenten (sonst Fehler 3), ungerader
;  Exponent ergibt ein negatives Ergebnis (POW_ODD).
OP_POW: PUSH    DE
        LD      DE,POW_EXP
        CALL    FP_MOVE
        POP     HL
        PUSH    HL
        LD      BC,0004h
        ADD     HL,BC
        LD      A,(HL)
        OR      A
        POP     HL
        PUSH    HL
        JP      P,FP_UNDER
        LD      A,(HL)
        AND     80h
        LD      (POW_SIGN),A
        SET     7,(HL)
        EX      DE,HL
        CALL    FN_LN
        LD      A,(POW_SIGN)
        OR      A
        CALL    Z,POW_ODD
        POP     DE
        PUSH    DE
        LD      HL,POW_EXP
        CALL    OP_MUL
        POP     DE
        PUSH    DE
        CALL    FN_EXP
        POP     HL
        LD      A,(POW_SIGN)
;  FP_SETSIGN – A = 0: Zahl (HL) negieren (FP_NEG), sonst unverändert.
;  FP_NEG: Vorzeichenbit umdrehen (0 bleibt 0).
; <- aufgerufen von 3A47h
FP_SETSIGN:
        OR      A
        RET     NZ
; <- aufgerufen von 3757h
FP_NEG: LD      BC,0004h
        ADD     HL,BC
        BIT     7,(HL)
        PUSH    AF
        XOR     A
        SBC     HL,BC
        POP     AF
        RET     Z
        LD      A,(HL)
        ADD     A,80h
        LD      (HL),A
        RET
; <- aufgerufen von 3BC7h
POW_ODD:
        LD      HL,POW_EXP
        LD      DE,POW_TMP
        CALL    FP_MOVE
        LD      DE,POW_EXP
        CALL    FN_INT
        LD      DE,POW_TMP
        LD      HL,POW_EXP
        CALL    OP_SUB
        LD      HL,POW_TMP4
        LD      A,(HL)
        OR      A
        JP      M,ERR_03
        LD      HL,POW_EXP
        LD      A,(HL)
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        AND     7Fh
        SUB     41h
        JR      C,POW_POS
        JR      Z,POW_ODD_BIT
POW_ODD_SHL:
        SLA     E
        RL      D
        RL      C
        RL      B
        DEC     A
        JR      NZ,POW_ODD_SHL
POW_ODD_BIT:
        RL      B
        RET     C
POW_POS:
        LD      A,80h
        LD      (POW_SIGN),A
        RET

; ==============================================================================
;  PRINT / INPUT
; ==============================================================================
;  Geräteverteilung über DEV_DISPATCH und die Tabellen
;  DEVTAB_PRINT/DEVTAB_INPUT (Bildschirm, Drucker, Kassette, Diskette,
;  GP-IB ...).
;  PRINT [/P | /T | #n[(satz)]] [ausdruck][; | ,][...] – auch "?".
;  /P und /T setzen FILE_NO auf 82h bzw. 83h (GETDEVICE), #n auf n
;  (FILE_RECNO liest bei Satzdateien die Satznummer), sonst 80h.
;  Jedes Element wird mit VAL2TEXT/STR2TEXT nach INBUF gewandelt und über
;  DEVTAB_PRINT+2*15 ausgegeben; ohne ; oder , am Ende folgt der
;  Zeilenabschluss über DEVTAB_PRINT. "," springt auf dem Bildschirm zur
;  nächsten Tabulatorposition (TABPOS), beim Drucker über PRN_TABZONE.
;  TAB(n) füllt auf dem Bildschirm mit 03h, beim Drucker mit Leerzeichen
;  bis Spalte n auf; bei anderen Geräten Fehler 1.
ST_PRINT:
        CALL    CHK_CHR_ALT
D3C39:  DEFB    2Fh                     ; Inline-Parameter '/'
D3C3A:  DEFW    PR_FILE
        CALL    GETDEVICE
        JR      PR_LOOP
; <- aufgerufen von 3C36h
PR_FILE:
        CALL    FILE_SELECT
        CALL    FILE_RECNO
PR_LOOP:
        CALL    CHRGET
        JR      NZ,PR_SEP
        LD      (TXTPTR),HL
PR_EOL: LD      HL,DEVTAB_PRINT
        CALL    DEV_DISPATCH
        JP      NEXTSTMT
PR_SEP: CALL    CHK_CHR_ALT
D3C5B:  DEFB    3Bh                     ; Inline-Parameter ';'
D3C5C:  DEFW    PR_SEPDO
; <- aufgerufen von 3C58h
PR_SEPDO:
        LD      BC,PR_NEXT
        PUSH    BC
        CP      2Ch                     ; ','
        RET     NZ
        INC     HL
        LD      A,(FILE_NO)
        OR      A
        RET     P
        AND     7Fh
        JP      Z,TABPOS
        CP      02h
        RET     NZ
        JP      PRN_TABZONE
PR_NEXT:
        CALL    CHRGET
        LD      (TXTPTR),HL
        JP      NZ,PR_ITEM
        LD      A,(FILE_NO)
        OR      A
        JP      M,NEXTSTMT
        JP      PR_EOL
PR_ITEM:
        CP      3Bh                     ; ';'
        JR      Z,PR_ISSEP
        CP      2Ch                     ; ','
PR_ISSEP:
        JP      Z,PR_SEP
        CALL    CHK_CHR_ALT
D3C95:  DEFB    0A9h                    ; Inline-Parameter
D3C96:  DEFW    PR_EXPR
        CALL    EVAL_BYTE
        CALL    SYNCHK
D3C9E:  DEFB    29h                     ; Inline-Parameter ')'
        LD      D,03h
        LD      A,(CSR_COL)
        LD      B,A
        LD      A,(FILE_NO)
        CP      80h
        JR      Z,PR_TABPAD
        LD      D,20h
        CP      82h
        JR      NZ,PR_ERR
        LD      A,(PRN_COL)
        LD      B,A
PR_TABPAD:
        LD      A,E
        SUB     B
        JR      C,PR_SEP
        LD      C,A
        LD      B,00h
        LD      A,D
        CALL    STR_FILL
        JR      PR_OUT
; <- aufgerufen von 3C92h
PR_EXPR:
        CALL    EVAL_EXPR
PR_OUT: PUSH    HL
        LD      HL,INBUF
        LD      A,D
        OR      A
        CALL    Z,VAL2TEXT
        CALL    NZ,STR2TEXT
        LD      HL,DEVTAB_PRINT+2*15
        CALL    DEV_DISPATCH
        LD      HL,PR_LOOP
        EX      (SP),HL
        CALL    CHRGET
        RET     Z
        CP      3Bh                     ; ';'
        RET     Z
        CP      2Ch                     ; ','
        RET     Z
PR_ERR: JP      ERR_01
;  VAL2TEXT – Zahl bei (VALSP) als Text nach (HL+1), Länge in (HL).
;  STR2TEXT – String (E = Nummer) ebenso. Beide hängen 0Dh an.
; <- aufgerufen von 3CCCh, 5504h, 653Ah
VAL2TEXT:
        PUSH    AF
        PUSH    HL
        EX      DE,HL
        LD      HL,(VALSP)
        CALL    NUM2STR
        POP     HL
        CALL    LEN_CR
        JP      TEXT_LEN
; <- aufgerufen von 3CCFh, 5507h, 653Dh
STR2TEXT:
        PUSH    AF
        CALL    GETSTR
        EX      DE,HL
        CALL    BLKMOVE
        EX      DE,HL
TEXT_LEN:
        DEC     HL
        LD      (HL),C
        INC     HL
        PUSH    HL
        ADD     HL,BC
        LD      (HL),0Dh
        POP     DE
        POP     AF
        RET
;  FILE_RECNO – nach #n: Dateieintrag holen; bei Satzdateien (FC_MODE = 2)
;  muss "(satz)" folgen, Satznummer > 0 nach REC_NO. Danach optionales ",".
; <- aufgerufen von 3C44h, 3FFAh
FILE_RECNO:
        LD      BC,SKIPCOMMA
        PUSH    BC
        LD      A,(FILE_NO)
        OR      A
        RET     M
        CALL    FILE_RELBUF
        LD      A,(FC_MODE)
        CP      02h
        RET     NZ
        CALL    SYNCHK
D3D21:  DEFB    28h                     ; Inline-Parameter '('
        CALL    EVAL_INT
        LD      (REC_NO),DE
        LD      A,D
        OR      E
        JP      Z,ERR_03
        CALL    SYNCHK
D3D31:  DEFB    29h                     ; Inline-Parameter ')'
        RET
;  FILE_FLUSH – geänderten Sektor der Satzdatei zurückschreiben, dann
;  FILE_RELBUF: Puffer 7082h freigeben.
; <- aufgerufen von 3E44h
FILE_FLUSH:
        LD      A,(REC_BUFOK)
        OR      A
        JP      Z,FILE_RELBUF
        PUSH    HL
        LD      HL,(7082h)
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        DEC     DE
        DEC     DE
        LD      BC,(REC_BUFSEC)
        CALL    DISK_WRITE
        POP     HL
; <- aufgerufen von 3D15h, 414Ch
FILE_RELBUF:
        XOR     A
        LD      (REC_BUFOK),A
        PUSH    HL
        LD      HL,(7082h)
        CALL    AREA_FREE
        POP     HL
        RET
;  REC_*: Satzdateien (32-Byte-Sätze). REC_NO aktuelle Satznummer,
;  REC_BUFOK/REC_BUFSEC geladener Sektor im Puffer 7082h, REC_SEC und
;  REC_OFS Sektor und Versatz des Satzes (REC_LOCATE).
REC_NO: DEFB    00h,00h                 ; ?? |..|
REC_BUFOK:
        DEFB    00h                     ; ?? |.|
REC_BUFSEC:
        DEFB    00h,00h                 ; ?? |..|
REC_SEC:
        DEFB    00h,00h                 ; ?? |..|
REC_OFS:
        DEFB    00h,00h                 ; ?? |..|
;  FILE_PUT – Text (DE, Länge BC) in die Datei schreiben. Sequentiell
;  (FC_MODE = 1): in den Sektorpuffer, volle Sektoren werden mit
;  FPUT_NEXTSEC geschrieben (neuer Sektor über FILE_NEWSEC/SEC_ALLOC).
;  Satzdatei (FC_MODE = 2): REC_PUT. Sonst Fehler 44.
FILE_PUT:
        LD      A,(FC_MODE)
        CP      02h
        JP      Z,REC_PUT
        CP      01h
        JP      NZ,ERR_44
        LD      (FPUT_SRC+1),DE
        LD      HL,(FC_B14)
        PUSH    HL
        INC     BC
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        ADD     HL,BC
        JP      C,ERR_55
        PUSH    HL
        LD      HL,(FC_B20)
        PUSH    HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      HL,(FC_B40)
        PUSH    HL
        ADD     HL,DE
        EX      DE,HL
FPUT_SRC:
        LD      HL,0FFFFh
FPUT_LP:
        PUSH    HL
        LD      HL,(FC_B13E)
        CALL    CPHLDE
        CALL    Z,FPUT_NEXTSEC
        POP     HL
        LDI
        LD      A,B
        OR      C
        JP      NZ,FPUT_LP
        POP     HL
        EX      DE,HL
        XOR     A
        SBC     HL,DE
        EX      DE,HL
        POP     HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        POP     BC
        POP     HL
        LD      (HL),C
        INC     HL
        LD      (HL),B
        RET
; <- aufgerufen von 3D98h
FPUT_NEXTSEC:
        PUSH    BC
        CALL    FILE_FIRSTSEC
        CALL    FILE_SECCNT
        CALL    FILE_SWAPSEC
        POP     BC
        RET
; <- aufgerufen von 3DBAh, 46F4h
FILE_SWAPSEC:
        LD      HL,(FC_B13E)
        LD      A,(HL)
        LD      (HL),C
        LD      C,A
        INC     HL
        LD      A,(HL)
        LD      (HL),B
        LD      B,A
        CALL    FILE_SECSIZE
        PUSH    HL
        CALL    DISK_WRITE
        POP     DE
        RET
; <- aufgerufen von 3DB4h, 46EEh
FILE_FIRSTSEC:
        LD      HL,(FC_B1E)
        LD      A,(HL)
        INC     HL
        OR      (HL)
        RET     NZ
        PUSH    HL
        LD      HL,(FC_B40)
        DEC     HL
        CALL    FILE_NEWSEC
        POP     HL
        LD      (HL),B
        DEC     HL
        LD      (HL),C
        LD      HL,(FC_B13E)
        LD      (HL),C
        INC     HL
        LD      (HL),B
        RET
; <- aufgerufen von 3DB7h
FILE_SECCNT:
        LD      HL,(FC_B40)
        DEC     HL
        DEC     (HL)
        JR      Z,FILE_NEWSEC
        LD      HL,(FC_B13E)
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        INC     BC
DEV_NOP:
        RET
; <- aufgerufen von 3DDEh
FILE_NEWSEC:
        PUSH    HL
        LD      DE,0004h
        CALL    SEC_ALLOC
        POP     HL
        LD      (HL),E
        RET
;  REC_PUT – Satz REC_NO schreiben: Text auf 32 Bytes mit Leerzeichen
;  auffüllen, Datei bei Bedarf verlängern (REC_EXTEND), Sektor laden,
;  Satz hineinkopieren, REC_NO erhöhen.
REC_PUT:
        PUSH    DE
        EX      DE,HL
        ADD     HL,BC
        LD      A,C
        SUB     20h
        JR      NC,REC_PUT2
        CPL
        INC     A
        LD      B,A
REC_PAD:
        LD      (HL),20h
        INC     HL
        DJNZ    REC_PAD
REC_PUT2:
        LD      BC,0012h
        LD      HL,(FC_B00)
        ADD     HL,BC
        LD      A,(HL)
        OR      A
        JP      NZ,ERR_46
        LD      HL,(FC_B14)
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      HL,(REC_NO)
        EX      DE,HL
        CALL    CPHLDE
        CALL    C,REC_EXTEND
        CALL    REC_LOCATE
        LD      A,(REC_BUFOK)
        OR      A
        JR      Z,REC_PUTCOPY
        LD      HL,(REC_BUFSEC)
        EX      DE,HL
        LD      HL,(REC_SEC)
        CALL    CPHLDE
        CALL    NZ,FILE_FLUSH
REC_PUTCOPY:
        CALL    REC_GETBUF
        EX      DE,HL
        LD      HL,(REC_OFS)
        ADD     HL,DE
        EX      DE,HL
        POP     HL
        LD      BC,0020h
        LDIR
; <- aufgerufen von 40E7h
REC_NEXTNO:
        LD      HL,(REC_NO)
        INC     HL
        LD      (REC_NO),HL
        RET
; <- aufgerufen von 3E47h, 40D6h
REC_GETBUF:
        LD      A,(REC_BUFOK)
        OR      A
        JP      Z,REC_LOADSEC
        LD      HL,(REC_BUFSEC)
        EX      DE,HL
        LD      HL,(REC_SEC)
        CALL    CPHLDE
        JP      Z,REC_BUFADR
REC_LOADSEC:
        CALL    SECTOR_SIZE
        LD      HL,(7082h)
        CALL    AREA_ALLOC
        LD      D,B
        LD      E,C
        LD      BC,(REC_SEC)
        PUSH    BC
        CALL    DISK_READ
        POP     HL
        LD      (REC_BUFSEC),HL
        LD      A,01h
        LD      (REC_BUFOK),A
REC_BUFADR:
        LD      HL,(7082h)
        INC     HL
        INC     HL
        RET
;  REC_LOCATE – Satznummer REC_NO-1 in Sektor (REC_SEC, über die
;  Sektortabelle bei FC_B40) und Versatz (REC_OFS = Satz * 32) zerlegen.
;  Nur für FC_TYPE = 0, sonst Fehler 1.
; <- aufgerufen von 3E31h, 40D3h
REC_LOCATE:
        LD      A,(FC_TYPE)
        OR      A
        JP      NZ,ERR_01
        LD      DE,(REC_NO)
        DEC     DE
        LD      B,03h
        CALL    REC_SPLIT
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        LD      (REC_OFS),HL
        LD      B,04h
        CALL    REC_SPLIT
        PUSH    HL
        LD      HL,(FC_B40)
        ADD     HL,DE
        ADD     HL,DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        POP     HL
        ADD     HL,DE
        LD      (REC_SEC),HL
        RET
; <- aufgerufen von 3EA2h, 3EAFh, 3EDBh
REC_SPLIT:
        LD      A,08h
        SUB     B
        PUSH    AF
        XOR     A
        LD      H,A
REC_SPLIT_LP:
        SRL     D
        RR      E
        RRA
        DJNZ    REC_SPLIT_LP
        POP     BC
REC_SPLIT_SH:
        RRA
        DJNZ    REC_SPLIT_SH
        LD      L,A
        RET
; <- aufgerufen von 3E2Eh
REC_EXTEND:
        LD      DE,(REC_NO)
        DEC     DE
        LD      B,07h
        CALL    REC_SPLIT
        INC     DE
        LD      HL,(FC_B40)
REC_EXT_LP:
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        INC     HL
        PUSH    DE
        LD      A,B
        OR      C
        CALL    Z,REC_EXT_SEC
        POP     DE
        DEC     DE
        LD      A,D
        OR      E
        JR      NZ,REC_EXT_LP
        LD      HL,(REC_NO)
        EX      DE,HL
        LD      HL,(FC_B14)
        LD      (HL),E
        INC     HL
        LD      (HL),D
        LD      HL,(FC_B40)
        DEC     HL
        LD      (HL),01h
        RET
; <- aufgerufen von 3EE9h
REC_EXT_SEC:
        PUSH    HL
        LD      A,(FC_TYPE)
        LD      DE,0010h
        OR      A
        JR      Z,REC_EXT_ALLOC
        LD      DE,0004h
REC_EXT_ALLOC:
        CALL    SEC_ALLOC
        POP     HL
        DEC     HL
        DEC     HL
        LD      (HL),C
        INC     HL
        LD      (HL),B
        INC     HL
        RET
;  DEV_USER – Dateityp 3: Routine, deren Adresse im FILETAB-Eintrag
;  (+3/+4) steht.
DEV_USER:
        LD      HL,(FC_ENTRY)
        INC     HL
        INC     HL
        INC     HL
        LD      A,(HL)
        INC     HL
        LD      H,(HL)
        LD      L,A
        JP      (HL)
;  DEV_DISPATCH – Routine aus der Tabelle HL für das aktuelle Gerät:
;  FILE_NO >= 80h -> Eintrag FILE_NO-80h, Datei #n -> Eintrag FC_TYPE+10.
;  Fehler werden über SET_IOERR abgefangen.
;  DEVTAB_PRINT: Einträge 0-14 = Zeilenabschluss, ab Eintrag 15 (Basis
;  DEVTAB_PRINT+2*15) = ein Element ausgeben. DEV_NOP = nichts tun.
; <- aufgerufen von 3C52h, 3CD5h, 4007h, 45EFh, 46B4h
DEV_DISPATCH:
        LD      A,(FILE_NO)
        ADD     A,80h
        JR      C,DEV_JUMP
        LD      A,(FC_TYPE)
        ADD     A,0Ah
DEV_JUMP:
        CALL    SET_IOERR
        CALL    TABJUMP
        JP      (HL)
DEVTAB_PRINT:
        DEFW    CRLF
        DEFW    ERR_01
        DEFW    PRN_CRLF
        DEFW    DEV_NOP
        DEFW    DEV_NOP
        DEFW    DEV_NOP
        DEFW    DEV_NOP
        DEFW    DEV_NOP
        DEFW    ERR_01
        DEFW    ERR_01
        DEFW    FILE_FLUSH
        DEFW    FILE_FLUSH
        DEFW    ERR_01
        DEFW    DEV_NOP
        DEFW    DEV_NOP
        DEFW    PRTSTR_RAW
        DEFW    ERR_01
        DEFW    PRN_TEXT
        DEFW    TPRINT
        DEFW    ERR_01
        DEFW    ERR_01
        DEFW    ERR_01
        DEFW    ERR_01
        DEFW    ERR_01
        DEFW    ERR_01
        DEFW    FILE_PUT
        DEFW    ERR_01
        DEFW    ERR_01
        DEFW    DEV_USER
        DEFW    ERR_01
;  INPUT [/T | #n] ["text";] var[,var...] – nur im Programm.
;  Bildschirm: Text bzw. "? " ausgeben, Zeile ab der Cursorposition mit
;  GETLINE lesen; BREAK (0Bh) merkt die Stelle für CONT (CONT_FLAG = 80h).
;  Werte durch Kommas getrennt, Strings auch in Anführungszeichen; fehlen
;  Werte, wird mit "? " nachgefragt (IN_MORE). Gerät/Datei: je Variable
;  ein Satz über DEVTAB_INPUT. Zahlen über NUMSTR_EVAL (sonst Fehler 4).
ST_INPUT:
        CALL    CHK_NODIRECT
        CALL    CHK_CHR_ALT
D3F7B:  DEFB    2Fh                     ; Inline-Parameter '/'
D3F7C:  DEFW    IN_FILE
        CALL    GETDEVICE
        JP      IN_DEV
; <- aufgerufen von 3F78h
IN_FILE:
        CALL    FILE_SELECT
        LD      A,(FILE_NO)
        OR      A
        JP      P,IN_DEV
        CALL    SKIPSP
        CP      22h                     ; '"'
        LD      DE,MSG_QMARK
        JR      NZ,IN_PROMPT
        CALL    EVAL
        CALL    SYNCHK
D3F9E:  DEFB    3Bh                     ; Inline-Parameter ';'
        CALL    GETSTR
IN_PROMPT:
        LD      (TXTPTR),HL
IN_ASK: CALL    PRTSTR_RAW
        LD      A,(ADD_WIDTH+1)
        LD      (IN_WIDTH+1),A
        LD      HL,(CSR_XY)
        PUSH    HL
        LD      C,H
        LD      B,00h
        LD      HL,LINE_TAB
        ADD     HL,BC
        LD      A,(HL)
        POP     HL
        LD      H,00h
IN_WIDTH:
        LD      BC,0050h
        INC     A
IN_ROWLP:
        DEC     A
        JR      Z,IN_GETLINE
        ADD     HL,BC
        JR      IN_ROWLP
IN_GETLINE:
        LD      B,L
        LD      H,00h
        LD      DE,INBUF
        ADD     HL,DE
        LD      (IN_PTR),HL
        CALL    GETLINE
        EX      DE,HL
        LD      A,(HL)
        CP      0Bh
        JR      NZ,IN_ENDCHK
        LD      A,80h
        CALL    CONT_POS
        JP      BREAK
IN_ENDCHK:
        INC     B
        LD      A,0Dh
IN_ENDLP:
        CP      (HL)
        JR      Z,IN_MORE
        INC     HL
        DJNZ    IN_ENDLP
        JP      IN_NEXTVAL
IN_MORE:
        CALL    CRLF_IF
        LD      DE,MSG_QMARK
        JP      IN_ASK
MSG_QMARK:
        DEFB    3Fh,20h,0Dh             ; ?? |? .|
IN_DEV: CALL    FILE_RECNO
        LD      (TXTPTR),HL
IN_DEVLOOP:
        LD      DE,INBUF
        PUSH    DE
        LD      HL,DEVTAB_INPUT
        CALL    DEV_DISPATCH
        POP     HL
        DEC     HL
        LD      (HL),C
        INC     HL
        LD      A,B
        OR      A
        JP      NZ,ERR_05
        CALL    STR_STORE
        LD      HL,IN_DEVLOOP
        JP      IN_ASSIGN
DEVTAB_INPUT:
        DEFW    ERR_01
        DEFW    ERR_01
        DEFW    ERR_01
        DEFW    TINPUT
        DEFW    ERR_01
        DEFW    ERR_01
        DEFW    ERR_01
        DEFW    ERR_01
        DEFW    DEV_NOP
        DEFW    DEV_NOP
        DEFW    FILE_GET
        DEFW    ERR_01
        DEFW    ERR_01
        DEFW    DEV_USER
        DEFW    ERR_01
;  FILE_GET – nächsten Text aus der Datei nach (DE), Länge in C.
;  Sequentiell (FC_MODE = 0): bis 0Dh, über Sektorgrenzen hinweg;
;  Satzdatei (FC_MODE = 2): Satz REC_NO (32 Bytes, REC_GET). Am Dateiende
;  wird im Eintrag Byte 8 gesetzt (FILE_EOF, für IF EOF). Sonst Fehler 44.
FILE_GET:
        LD      A,(FC_MODE)
        CP      02h
        JP      Z,REC_GET
        OR      A
        JP      NZ,ERR_44
        LD      HL,(FC_B14)
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        LD      A,B
        OR      C
        JP      Z,FILE_EOF
        PUSH    HL
        PUSH    BC
        LD      HL,(FC_B20)
        PUSH    HL
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        LD      HL,(FC_B40)
        PUSH    HL
        ADD     HL,BC
        PUSH    DE
        LD      BC,0000h
        CALL    FGET_LP
        POP     DE
        DEC     DE
        LD      A,C
        LD      (DE),A
        POP     DE
        XOR     A
        SBC     HL,DE
        EX      DE,HL
        POP     HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        POP     HL
        SCF
        SBC     HL,BC
        EX      DE,HL
        POP     HL
        LD      (HL),D
        DEC     HL
        LD      (HL),E
        XOR     A
        JR      FILE_SETEOF
FILE_EOF:
        LD      A,01h
        LD      BC,0000h
FILE_SETEOF:
        LD      IX,(FC_ENTRY)
        LD      (IX+8),A
        RET
; <- aufgerufen von 4063h
FGET_LP:
        PUSH    DE
        LD      DE,(FC_B13E)
        CALL    CPHLDE
        PUSH    BC
        CALL    Z,FGET_NEXTSEC
        POP     BC
        POP     DE
        LD      A,(HL)
        INC     BC
        LD      (DE),A
        INC     HL
        INC     DE
        CP      0Dh
        JR      NZ,FGET_LP
        DEC     BC
        RET
; <- aufgerufen von 4095h
FGET_NEXTSEC:
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        CALL    FILE_SECSIZE
        PUSH    HL
        CALL    DISK_READ
        POP     HL
        RET
; <- aufgerufen von 3DC9h, 40A8h, 465Ah
FILE_SECSIZE:
        LD      HL,(FC_B40)
        EX      DE,HL
        LD      HL,(FC_B13E)
        INC     HL
        INC     HL
        XOR     A
        SBC     HL,DE
        EX      DE,HL
        RET
REC_GET:
        LD      (REC_GETDST+1),DE
        LD      HL,(FC_B14)
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      HL,(REC_NO)
        EX      DE,HL
        CALL    CPHLDE
        JP      C,FILE_EOF
        CALL    REC_LOCATE
        CALL    REC_GETBUF
        EX      DE,HL
        LD      HL,(REC_OFS)
        ADD     HL,DE
REC_GETDST:
        LD      DE,0FFFFh
        LD      BC,0020h
        PUSH    BC
        LDIR
        CALL    REC_NEXTNO
        POP     BC
        XOR     A
        JP      FILE_SETEOF
IN_PTR: DEFB    00h,00h                 ; ?? |..|
IN_NEXTVAL:
        LD      A,(FILE_NO)
        CP      81h
        JP      Z,READ_NEXT
        LD      HL,(IN_PTR)
        CALL    LEN_CR
        LD      DE,INBUF
        PUSH    DE
        INC     BC
        LDIR
        POP     HL
        LD      (IN_PTR),HL
        CALL    SKIPSP
        CP      0Dh
        JP      Z,IN_MORE
        CALL    CHK_CHR_ALT
D4115:  DEFB    2Ch                     ; Inline-Parameter ','
D4116:  DEFW    IN_STRVAL
        PUSH    HL
        LD      DE,STR_CR
        CALL    STRLIT
        POP     HL
        JR      IN_SETPTR
; <- aufgerufen von 4112h
IN_STRVAL:
        CALL    STRLIT
IN_SETPTR:
        LD      (IN_PTR),HL
        LD      HL,IN_NEXTVAL
;  IN_ASSIGN – Wert (STRLIT-Ergebnis) der nächsten Variablen aus der
;  INPUT-Liste zuweisen; danach zurück zur Adresse auf dem Stack (nächster
;  Wert) oder am Ende der Liste NEXTSTMT.
IN_ASSIGN:
        PUSH    HL
        CALL    SAVEPAR0
        LD      HL,(TXTPTR)
        CALL    GETNAME_SN
        CALL    GETVAR
        LD      (TXTPTR),HL
        CALL    SAVEPAR1
IN_ASG_DO:
        CALL    ASSIGN
D4141:  DEFW    IN_TONUM
        LD      HL,(TXTPTR)
        CALL    CHRGET
        JR      NZ,IN_COMMA
        POP     AF
        CALL    FILE_RELBUF
        JP      NEXTSTMT
IN_COMMA:
        CALL    SYNCHK
D4155:  DEFB    2Ch                     ; Inline-Parameter ','
        LD      (TXTPTR),HL
        RET
; <- aufgerufen von 413Eh
IN_TONUM:
        LD      DE,(6B02h)
        CALL    GETSTR
        EX      DE,HL
        CALL    CHK_CHR_ALT
D4165:  DEFB    0Dh                     ; Inline-Parameter
D4166:  DEFW    IN_TONUM2
        LD      HL,STR_0
; <- aufgerufen von 4162h
IN_TONUM2:
        CALL    NUMSTR_EVAL
D416E:  DEFW    ERR_04
        CALL    SAVEPAR0
        JP      IN_ASG_DO
STR_0:  DEFB    30h                     ; ?? |0|
STR_CR: DEFB    0Dh                     ; ?? |.|

; ==============================================================================
;  DATEIBEFEHLE (KASSETTE / DISKETTE)
; ==============================================================================
ST_READ:
        LD      (TXTPTR),HL
        LD      A,81h
        LD      (FILE_NO),A
        CALL    CHK_NODIRECT
;  READ_NEXT – READ: nächstes Element aus DATA holen (DATA_FLAG/DATA_PTR),
;  bei Bedarf die nächste DATA-Anweisung suchen (DATA_SEARCH, keine mehr:
;  Fehler 24). READ läuft über die INPUT-Zuweisung mit FILE_NO = 81h.
READ_NEXT:
        LD      A,(DATA_FLAG)
        OR      A
        CALL    Z,DATA_SEARCH
        LD      HL,(DATA_PTR)
        CALL    CHRGET
        JR      NZ,READ_VAL
        CALL    DATA_NEXTSTMT
        JP      READ_NEXT
READ_VAL:
        CALL    STRLIT
        CALL    SKIPCOMMA
        LD      (DATA_PTR),HL
        LD      HL,INBUF
        LD      (HL),0Dh
        JP      IN_SETPTR
; <- aufgerufen von 4187h
DATA_SEARCH:
        LD      HL,PRGTXT
DATA_SRCH_FROM:
        XOR     A
        LD      (DATA_FLAG),A
DATA_SRCH_LINE:
        LD      A,(HL)
        INC     HL
        OR      (HL)
        INC     HL
        JP      Z,ERR_24
        INC     HL
        INC     HL
DATA_SRCH_STMT:
        CALL    CHK_CHR_ALT
D41BC:  DEFB    80h                     ; Inline-Parameter
D41BD:  DEFW    DATA_SKIPSTMT
        CALL    CHK_CHR_ALT
D41C2:  DEFB    81h                     ; Inline-Parameter
D41C3:  DEFW    DATA_SKIPSTMT
        LD      (DATA_PTR),HL
        LD      A,01h
        LD      (DATA_FLAG),A
        RET
; <- aufgerufen von 41B9h, 41BFh
DATA_SKIPSTMT:
        CALL    SKIPSTMT
; <- aufgerufen von 4192h
DATA_NEXTSTMT:
        INC     HL
        CP      3Ah                     ; ':'
        JP      Z,DATA_SRCH_STMT
        JP      DATA_SRCH_LINE
ST_APPEND:
        CALL    CHK_DIRECT
        PUSH    HL
        LD      HL,PRGTXT
        LD      A,(HL)
        INC     HL
        OR      (HL)
        POP     HL
        JR      Z,ST_LOAD
        LD      A,0FFh
        LD      (APPEND_FLAG),A
        PUSH    HL
        LD      HL,(VALSP)
        LD      BC,1FFFh
        ADD     HL,BC
        LD      (APPEND_ADDR),HL
        POP     HL
        JR      LOAD_GO
;  APPEND_FLAG/APPEND_ADDR: APPEND lädt hinter das vorhandene Programm
;  (Ladeadresse (VALSP)+1FFFh). LOAD_MODE: 0 = VERIFY, 1 = LOAD von Kassette.
APPEND_FLAG:
        DEFB    00h                     ; ?? |.|
APPEND_ADDR:
        DEFB    00h,00h                 ; ?? |..|
LOAD_MODE:
        DEFB    00h                     ; ?? |.|
;  LOAD [/T | dateiangabe] – BASIC-Programm (Typ BTX) laden, auch CHAIN,
;  RUN "datei" und APPEND laufen hier durch. /T: von Kassette (LOAD_TAPE).
;  Diskette: Eintrag im Verzeichnis suchen (DIR_SCAN, nicht gefunden:
;  Fehler 40), Typ OBJ -> LOAD_OBJ (Maschinenprogramm), sonst muss es BTX
;  sein (Fehler 63). Programm in zwei Teilen lesen (LOAD_PART1 direkt,
;  LOAD_PART2 über (VALSP) bei unvollständigem letztem Sektor), Links
;  umrechnen (RELINK). Bei RUN "datei" danach starten.
ST_LOAD:
        LD      A,(CHAIN_MODE)
        LD      (SAVE_CHAIN),A
        LD      A,(RUN_LOADFLG)
        LD      (SAVE_RUNFLG),A
        XOR     A
        LD      (APPEND_FLAG),A
LOAD_GO:
        XOR     A
        LD      (CHAIN_MODE),A
        LD      (RUN_LOADFLG),A
        CALL    CHK_CHR_ALT
D4218:  DEFB    2Fh                     ; Inline-Parameter '/'
D4219:  DEFW    LOAD_FD
        CALL    SYNCHK
D421E:  DEFB    54h                     ; Inline-Parameter 'T'
        JP      LOAD_TAPE
; <- aufgerufen von 4215h
LOAD_FD:
        CALL    FILESPEC
        CALL    CHK_EOS
        LD      A,(APPEND_FLAG)
        OR      A
        JR      Z,LOAD_TOPRG
        LD      HL,(APPEND_ADDR)
        JR      LOAD_SETDST
LOAD_TOPRG:
        LD      HL,PRGTXT
LOAD_SETDST:
        LD      (LOAD_DST),HL
        LD      HL,0000h
        LD      (LOAD_OFS),HL
        CALL    DIR_SCAN
D4242:  DEFW    LOAD_MATCH
        JP      ERR_40
; <- aufgerufen von 423Fh
LOAD_MATCH:
        RET     Z
        RET     M
        CALL    NAMECMP
        RET     NZ
        POP     AF
        LD      A,(HL)
LOAD_ENTRY:
        LD      DE,DIRENT
        LD      BC,0020h
        LDIR
        DEC     A
        JP      Z,LOAD_OBJ
        DEC     A
        JP      NZ,ERR_63
        LD      HL,(707Ch)
        CALL    AREA_FREE
        LD      A,(CHAIN_MODE)
        OR      A
        JP      NZ,CHAIN_KEEP
        LD      A,(APPEND_FLAG)
        OR      A
        JR      NZ,LOAD_ROOM
        CALL    PROG_NEW
LOAD_ROOM:
        LD      BC,(DIRENT_SIZE)
        LD      HL,(LOAD_OFS)
        ADD     HL,BC
        LD      C,L
        LD      B,H
        DEC     BC
        DEC     BC
        LD      A,(APPEND_FLAG)
        OR      A
        LD      DE,(APPEND_ADDR)
        JR      NZ,LOAD_READ
        LD      DE,PRGTXT
        CALL    MEMINS_ADJ
LOAD_READ:
        LD      BC,0400h
        CALL    CHKMEM2
        CALL    SECTOR_SIZE
        LD      (LOAD_SECLEN),BC
        CALL    FILE_SECCOUNT
        LD      (LOAD_PART1+1),BC
        DEC     DE
        LD      H,D
        LD      L,E
        ADD     HL,BC
        LD      (LOAD_PART2+1),HL
        CALL    SEC2BYTES
        LD      (LOAD_P1LEN+1),DE
        LD      HL,(LOAD_DST)
        ADD     HL,DE
        LD      (LOAD_P2DST+1),HL
        LD      HL,(DIRENT_SIZE)
        XOR     A
        SBC     HL,DE
        LD      (LOAD_P2LEN+1),HL
        CALL    LOAD_PART1
        CALL    LOAD_PART2
        LD      A,(DIRENT)
        DEC     A
        JR      Z,LOAD_DONE
        LD      A,(APPEND_FLAG)
        OR      A
        JR      Z,LOAD_RELINK0
;  APPEND: Zeilen aus dem hinter das Programm geladenen Text einzeln über
;  EDITLINE einfügen (gleiche Nummern ersetzen vorhandene Zeilen).
APP_LINE:
        LD      DE,6C0Dh
        LD      HL,(APPEND_ADDR)
        DEC     HL
        LD      B,04h
APP_HDR:
        INC     HL
        INC     DE
        LD      A,(HL)
        LD      (DE),A
        DJNZ    APP_HDR
APP_TEXT:
        INC     HL
        INC     DE
        LD      A,(HL)
        LD      (DE),A
        CP      0Dh
        JR      NZ,APP_TEXT
        INC     HL
APP_INSERT:
        LD      (APPEND_ADDR),HL
        LD      HL,(TOKLNUM)
        CALL    EDITLINE
        LD      HL,(APPEND_ADDR)
        LD      D,(HL)
        INC     HL
        LD      A,(HL)
        OR      D
        JR      NZ,APP_LINE
LOAD_RELINK0:
        XOR     A
        LD      (RELINK_NEW),A
LOAD_RELINK:
        CALL    RELINK
LOAD_DONE:
        CALL    FD_MOTOR_OFF
        LD      A,(APPEND_FLAG)
        OR      A
        JR      Z,LOAD_RUN
        XOR     A
        LD      (APPEND_FLAG),A
        JP      BAS_READY
LOAD_RUN:
        LD      A,(RUN_LOADFLG)
        OR      A
        JP      Z,NEXTSTMT
        LD      HL,(PRGTXT)
        LD      A,H
        OR      L
        JP      Z,BAS_READY
        LD      HL,(725Eh)
        CALL    PRTNUM
        EX      DE,HL
        LD      A,(SWAP_ACTIVE)
        OR      A
        JP      Z,RUN_CLR
        XOR     A
        LD      (SWAP_ACTIVE),A
        JP      SWAP_RESTORE
; <- aufgerufen von 42C3h
LOAD_PART1:
        LD      BC,0FFFFh
LOAD_P1LEN:
        LD      DE,0FFFFh
        LD      HL,(LOAD_DST)
        LD      A,D
        OR      E
        RET     Z
        JP      DISK_READ
; <- aufgerufen von 42C6h
LOAD_PART2:
        LD      BC,0FFFFh
        LD      HL,(LOAD_P2LEN+1)
        LD      A,H
        OR      L
        RET     Z
        LD      HL,(LOAD_SECLEN)
        EX      DE,HL
        LD      HL,(VALSP)
        CALL    DISK_READ
LOAD_P2DST:
        LD      DE,0FFFFh
LOAD_P2LEN:
        LD      BC,0FFFFh
        LD      HL,(VALSP)
        LDIR
        RET
LOAD_DST:
        DEFB    00h,00h                 ; ?? |..|
LOAD_OFS:
        DEFB    00h,00h                 ; ?? |..|
LOAD_SECLEN:
        DEFB    00h,00h                 ; ?? |..|
;  SAVE [/T | dateiangabe] – Programm als BTX speichern (nur Direktmodus).
;  Platz suchen (SEC_ALLOC), Links relativ machen (UNLINK), Sektoren
;  schreiben, Links zurückrechnen, Verzeichniseintrag anlegen
;  (DIR_NEWFILE; vorhandener Name: Fehler 42, Verzeichnis voll: 51).
ST_SAVE:
        CALL    CHK_DIRECT
        XOR     A
        LD      (RUN_LOADFLG),A
        CALL    CHK_CHR_ALT
D4378:  DEFB    2Fh                     ; Inline-Parameter '/'
D4379:  DEFW    SAVE_FD
        CALL    SYNCHK
D437E:  DEFB    54h                     ; Inline-Parameter 'T'
        JP      SAVE_TAPE
; <- aufgerufen von 4375h
SAVE_FD:
        CALL    FILESPEC
        LD      A,02h
        LD      (DIRENT),A
        CALL    CHK_EOS
        LD      DE,PRGTXT
SAVE_AREA:
        LD      HL,(PRGEND)
        XOR     A
        SBC     HL,DE
        LD      (DIRENT_SIZE),HL
        LD      (SWAP_SIZE),HL
        CALL    FILE_SECCOUNT
        CALL    SEC_ALLOC
        LD      (DIRENT_SEC),BC
        LD      (SWAP_SEC),BC
        PUSH    BC
        PUSH    DE
        CALL    UNLINK
        POP     DE
        CALL    SEC2BYTES
        LD      HL,PRGTXT
        POP     BC
        LD      A,(RUN_LOADFLG)
        OR      A
        JP      NZ,SWAP_WRITE
        CALL    DISK_WRITE
        CALL    RELINK
        CALL    DIR_NEWFILE
        JP      NEXTSTMT
CHAIN_MODE:
        DEFB    00h                     ; ?? |.|
;  CHAIN dateiangabe – Programm laden und starten, Variablen bleiben
;  erhalten (CHAIN_MODE = 1). Auch SWAP benutzt diesen Weg (CHAIN_MODE
;  2/3, CHAIN_SWAP).
ST_CHAIN:
        CALL    CHK_NODIRECT
        LD      A,01h
        LD      (CHAIN_MODE),A
        LD      (RUN_LOADFLG),A
        JP      LOAD_FD
CHAIN_KEEP:
        DEC     A
        JR      NZ,CHAIN_SWAP
        CALL    INITVARPTR
CHAIN_DEL:
        CALL    PROG_DEL
        XOR     A
        LD      (CHAIN_MODE),A
        JP      LOAD_ROOM
CHAIN_SWAP:
        DEC     A
        JR      NZ,CHAIN_DEL
        XOR     A
        LD      (FOR_CNT),A
        JR      CHAIN_DEL
;  SWAP dateiangabe – laufendes Programm samt Variablen (ab 7096h) als
;  Auslagerungsdatei (Typ 80h/81h) speichern, das andere Programm laden
;  und starten. Sein END kehrt über SWAP_BACK zurück (END_SWAP). SWAP
;  während SWAP: Fehler 25.
ST_SWAP:
        CALL    CHK_NODIRECT
        CALL    FILES_RESET
        CALL    FILESPEC
        CALL    DEV_SAVE
        CALL    DEV_DEFAULT
        CALL    CHK_EOS
        LD      A,(END_SWAP+1)
        OR      A
        JP      NZ,ERR_25
        INC     A
        LD      (RUN_LOADFLG),A
        LD      HL,DIRENT
        LD      DE,SWAP_DIRENT
SWAP_SAVEDIR:
        CALL    COPY32
        CALL    DIR_SCAN
D441B:  DEFW    SWAP_MATCH
        JP      ERR_40
; <- aufgerufen von 4418h
SWAP_MATCH:
        RET     P
        POP     AF
        INC     HL
        LD      A,(HL)
        LD      (SWAP_VOL),A
        DEC     HL
        LD      A,(HL)
        CP      81h
        JR      Z,SWAP_REUSE
        PUSH    HL
        LD      DE,7096h
        JP      SAVE_AREA
SWAP_REUSE:
        CALL    SWAP_SETENT
        LD      HL,SWAP_DIRENT
        LD      DE,DIRENT
        JR      SWAP_SAVEDIR
SWAP_WRITE:
        LD      (END_SWAP+1),A
        LD      A,02h
        LD      (CHAIN_MODE),A
        LD      HL,7096h
        CALL    DISK_WRITE
        POP     HL
        LD      A,81h
        LD      (DIRENT),A
        LD      A,(SWAP_VOL)
        LD      (DIRENT_NAME),A
        LD      (DIR_ENTPTR+1),HL
        LD      A,02h
        LD      (FREE_TYPE+1),A
        DEC     A
        LD      (FREE_SECS+1),A
        CALL    DIR_WRITEENT
        CALL    DEV_RESTORE
        XOR     A
        LD      (FC_VOL),A
        LD      HL,SWAP_DIRENT
        LD      DE,DIRENT
        CALL    COPY32
        JP      LOAD_TOPRG
SWAP_BACK:
        XOR     A
        LD      (FC_VOL),A
        CALL    FILES_RESET
        CALL    DEV_DEFAULT
        CALL    DIR_SCAN
D4488:  DEFW    SWAP_BMATCH
        JP      ERR_40
; <- aufgerufen von 4485h
SWAP_BMATCH:
        RET     P
        POP     AF
        LD      A,(HL)
        CP      81h
        JP      NZ,ERR_40
        PUSH    HL
        LD      HL,7096h
        LD      (LOAD_DST),HL
        LD      HL,0FE3Ah
        LD      (LOAD_OFS),HL
        POP     HL
        LD      (SWAP_ACTIVE),A
        LD      A,03h
        LD      (CHAIN_MODE),A
        DEC     A
        JP      LOAD_ENTRY
SWAP_RESTORE:
        LD      HL,(SWAP_SIZE)
        LD      (DIRENT_SIZE),HL
        LD      HL,(SWAP_SEC)
        LD      (DIRENT_SEC),HL
        CALL    DIR_SCAN
D44BE:  DEFW    SWAP_RMATCH
        JP      ERR_40
; <- aufgerufen von 44BBh
SWAP_RMATCH:
        RET     Z
        RET     P
        POP     AF
        LD      (DIR_ENTPTR+1),HL
        LD      A,80h
        LD      (DIRENT),A
        LD      A,(SWAP_VOL)
        LD      (DIRENT_NAME),A
        CALL    SWAP_FREE
        XOR     A
        LD      (END_SWAP+1),A
        CALL    FD_MOTOR_OFF
        JP      NEXTSTMT
; <- aufgerufen von 4434h
SWAP_SETENT:
        LD      (DIR_ENTPTR+1),HL
        LD      A,80h
        LD      (HL),A
        INC     HL
        LD      A,(SWAP_VOL)
        LD      (HL),A
        DEC     HL
        LD      BC,0020h
        LD      DE,DIRENT
        LDIR
; <- aufgerufen von 44D4h
SWAP_FREE:
        XOR     A
        LD      (FREE_SECS+1),A
        LD      A,02h
        LD      (FREE_TYPE+1),A
        JP      DIR_WRITEENT
; <- aufgerufen von 4415h, 4475h
COPY32: LD      BC,0020h
        LDIR
        RET
;  DEV_DEFAULT – Standardgerät (DEV_DEFTYPE, von DIR gesetzt) nach FC_TYPE/
;  FC_UNIT. DEV_SAVE/DEV_RESTORE sichern bzw. holen es für SWAP.
; <- aufgerufen von 43FEh, 4482h, 4759h
DEV_DEFAULT:
        PUSH    HL
        LD      HL,(DEV_DEFTYPE)
        LD      (FC_TYPE),HL
        POP     HL
        RET
; <- aufgerufen von 43FBh
DEV_SAVE:
        PUSH    HL
        LD      HL,(FC_TYPE)
        LD      (SWAP_DEV),HL
        POP     HL
        RET
; <- aufgerufen von 4468h
DEV_RESTORE:
        PUSH    HL
        LD      HL,(SWAP_DEV)
        LD      (FC_TYPE),HL
        POP     HL
        RET
;  FILES_RESET – Dateitabelle leeren und alle Puffer freigeben.
; <- aufgerufen von 43F5h, 447Fh
FILES_RESET:
        PUSH    HL
        CALL    CLEARVARS
        CALL    CLOSE_ALL
        POP     HL
        RET
SWAP_DEV:
        DEFB    00h,00h                 ; ?? |..|
SWAP_ACTIVE:
        DEFB    00h                     ; ?? |.|
SWAP_SIZE:
        DEFB    00h,00h                 ; ?? |..|
SWAP_SEC:
        DEFB    00h,00h                 ; ?? |..|
SWAP_VOL:
        DEFB    00h                     ; ?? |.|
SWAP_DIRENT:
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
;  XOPEN #n, dateiangabe – Satzdatei (Typ BRD, FC_MODE 2) öffnen.
;  ROPEN #n, ... – sequentiell lesen (BSD, Modus 0), /T: Kassette.
;  WOPEN #n, ... – sequentiell schreiben (BSD, Modus 1), /T: Kassette.
;  Nur im Programm; #n muss angegeben sein (Fehler 64). OPEN_CHKOPEN
;  prüft über FTAB_SCAN, dass Nummer und Datei frei sind (Fehler 64/43),
;  OPEN_NEWENT legt den Eintrag in FILETAB an, OPEN_DISK sucht bzw. legt
;  die Datei an (lesen: nicht gefunden Fehler 40; schreiben: vorhanden
;  Fehler 42; falscher Typ Fehler 63).
ST_XOPEN:
        LD      BC,0204h
        JR      OPEN_FD
ST_ROPEN:
        CALL    CHK_CHR_ALT
D455B:  DEFB    2Fh                     ; Inline-Parameter '/'
D455C:  DEFW    ROPEN_FD
        CALL    SYNCHK
D4561:  DEFB    54h                     ; Inline-Parameter 'T'
        JP      ROPEN_TAPE
; <- aufgerufen von 4558h
ROPEN_FD:
        LD      BC,0003h
        JR      OPEN_FD
ST_WOPEN:
        CALL    CHK_CHR_ALT
D456D:  DEFB    2Fh                     ; Inline-Parameter '/'
D456E:  DEFW    WOPEN_FD
        CALL    SYNCHK
D4573:  DEFB    54h                     ; Inline-Parameter 'T'
        JP      WOPEN_TAPE
; <- aufgerufen von 456Ah
WOPEN_FD:
        LD      BC,0103h
OPEN_FD:
        LD      A,B
        PUSH    AF
        LD      (FC_MODE),A
        LD      A,C
        LD      (DIRENT),A
        CALL    GETFILENO
        LD      (OPEN_NUMCHK+1),A
        JP      M,ERR_64
        CALL    CHK_NODIRECT
        CALL    FILESPEC
        CALL    CHK_EOS
        POP     AF
        CP      02h
        JR      NZ,OPEN_CHKOPEN
        LD      A,(FC_TYPE)
        CP      03h
        JP      NC,ERR_63
OPEN_CHKOPEN:
        CALL    FTAB_SCAN
D45A5:  DEFW    OPEN_CHKENT
        JP      OPEN_NEWENT
; <- aufgerufen von 45A2h
OPEN_CHKENT:
        RET     Z
OPEN_NUMCHK:
        CP      0FFh
        JP      Z,ERR_64
        INC     HL
        LD      A,(HL)
        LD      (OPEN_MODECHK+1),A
        INC     HL
        LD      A,(FC_TYPE)
        CP      (HL)
        RET     NZ
        CP      03h
        RET     Z
        CP      04h
        JP      Z,ERR_63
        INC     HL
        LD      A,(FC_UNIT)
        CP      (HL)
        RET     NZ
        EX      DE,HL
        INC     HL
        INC     HL
        CALL    NAMECMP
        RET     NZ
        LD      A,(FC_MODE)
OPEN_MODECHK:
        OR      0FFh
        RET     Z
        JP      ERR_43
OPEN_NEWENT:
        XOR     A
        CALL    FTAB_FIND
D45DD:  DEFW    ERR_64
        LD      DE,FC_IDX
        LD      (DE),A
        INC     DE
        PUSH    DE
        PUSH    HL
        LD      (FC_ENTRY),HL
        CALL    FILE_INITBUF
        LD      HL,OPENTAB-2*10
        CALL    DEV_DISPATCH
        POP     DE
        POP     HL
        LD      BC,0009h
        LDIR
        JP      FILECMD_DONE
OPENTAB:
        DEFW    OPEN_DISK
        DEFW    ERR_01
        DEFW    ERR_01
        DEFW    DEV_NOP
        DEFW    ERR_01
OPEN_DISK:
        CALL    DIR_SCAN
D4609:  DEFW    OPEN_MATCH
        LD      A,(FC_MODE)
        OR      A
        JP      Z,ERR_40
        LD      HL,DIRENT
        CALL    OPEN_INITBUF
        LD      A,(FC_MODE)
        CP      02h
        RET     NZ
        LD      DE,0001h
        CALL    SEC_ALLOC
        LD      HL,(FC_B1E)
        LD      (HL),C
        INC     HL
        LD      (HL),B
        LD      HL,(FC_B40)
        DEC     HL
        LD      (HL),01h
        RET
; <- aufgerufen von 4606h
OPEN_MATCH:
        RET     M
        RET     Z
        CALL    NAMECMP
        RET     NZ
        POP     AF
        LD      A,(FC_MODE)
        CP      01h
        JP      Z,ERR_42
        LD      A,(DIRENT)
        CP      (HL)
        JP      NZ,ERR_63
        CALL    OPEN_INITBUF
        LD      HL,(FC_B1E)
        JP      FGET_NEXTSEC
; <- aufgerufen von 4615h, 4647h
OPEN_INITBUF:
        LD      DE,(FC_B00)
        LD      BC,0020h
        LDIR
        PUSH    DE
        CALL    FILE_SECSIZE
        LD      HL,0020h
        ADD     HL,DE
        EX      DE,HL
        POP     HL
OPEN_CLRBUF:
        LD      (HL),00h
        INC     HL
        DEC     DE
        LD      A,D
        OR      E
        JR      NZ,OPEN_CLRBUF
        RET
        DEFB    00h                     ; ?? |.|
;  CLOSE [/T | #n[,#m...]] – Dateien schließen, ohne Nummer alle (127..1).
;  Schreibdateien: letzten Sektor schreiben und Verzeichniseintrag anlegen
;  (CLOSE_DISK/DIR_NEWFILE), Satzdateien: Sektortabelle sichern
;  (CLOSE_REC). Danach FILETAB-Eintrag löschen.
ST_CLOSE:
        CALL    CHK_CHR_ALT
D4670:  DEFB    2Fh                     ; Inline-Parameter '/'
D4671:  DEFW    CLOSE_FD
        CALL    SYNCHK
D4676:  DEFB    54h                     ; Inline-Parameter 'T'
        JP      CLOSE_TAPE
; <- aufgerufen von 466Dh
CLOSE_FD:
        CALL    CHK_NODIRECT
        CALL    GETFILENO
        LD      (TXTPTR),HL
        JP      P,CLOSE_ONE
        LD      A,7Fh
        JR      CLOSE_ALLNO
; <- aufgerufen von 4694h
CLOSE_ALLNEXT:
        LD      A,(FILE_NO)
        DEC     A
        JP      Z,FILECMD_DONE
CLOSE_ALLNO:
        LD      (FILE_NO),A
        CALL    CLOSE_FIND
D4697:  DEFW    CLOSE_ALLNEXT
        CALL    CLOSE_ENTRY
        JR      CLOSE_ALLNEXT
CLOSE_ONE:
        CALL    CLOSE_FIND
D46A1:  DEFW    ERR_64
        CALL    CLOSE_ENTRY
        CALL    CHK_CHR_ALT_T
D46A9:  DEFB    2Ch                     ; Inline-Parameter ','
D46AA:  DEFW    FILECMD_DONE
        JR      CLOSE_FD
; <- aufgerufen von 4699h, 46A3h
CLOSE_ENTRY:
        CALL    FILE_LOAD
        LD      HL,CLOSETAB-2*10
        CALL    DEV_DISPATCH
        LD      HL,(FC_ENTRY)
        LD      (HL),00h
        RET
; <- aufgerufen von 4694h, 469Eh
CLOSE_FIND:
        PUSH    AF
        LD      HL,(7082h)
        LD      A,(HL)
        INC     HL
        CP      (HL)
        DEC     HL
        CALL    NZ,AREA_FREE
        POP     AF
        JP      FTAB_FIND
CLOSETAB:
        DEFW    CLOSE_DISK
        DEFW    ERR_01
        DEFW    ERR_01
        DEFW    DEV_NOP
        DEFW    ERR_01
; <- aufgerufen von 46E2h, 46F7h
CLOSE_GETDIR:
        LD      HL,(FC_B00)
        LD      DE,DIRENT
        LD      BC,0020h
        LDIR
        RET
CLOSE_DISK:
        CALL    CLOSE_GETDIR
        LD      A,(FC_MODE)
        OR      A
        RET     Z
        DEC     A
        JP      NZ,CLOSE_REC
        CALL    FILE_FIRSTSEC
        LD      BC,0000h
        CALL    FILE_SWAPSEC
        CALL    CLOSE_GETDIR
;  DIR_NEWFILE – freien Verzeichniseintrag suchen (DIR_SCAN; Name schon
;  vorhanden: Fehler 42; kein Platz: Fehler 51) und DIRENT dort eintragen.
; <- aufgerufen von 43C4h
DIR_NEWFILE:
        CALL    DIR_SCAN
D46FD:  DEFW    DIR_NEWMATCH
        JP      Z,ERR_51
        LD      (DIR_ENTPTR+1),HL
DIR_STORE:
        LD      A,(DIRENT)
        LD      (FREE_TYPE+1),A
        LD      A,01h
        LD      (FREE_SECS+1),A
        JP      DIR_WRITEENT
; <- aufgerufen von 46FAh
DIR_NEWMATCH:
        RET     M
        RET     Z
        CALL    NAMECMP
        RET     NZ
        JP      ERR_42
CLOSE_REC:
        CALL    DIR_SCAN
D471F:  DEFW    CLOSE_RECMATCH
        JP      Z,ERR_51
        JP      CLOSE_RECDIR
; <- aufgerufen von 471Ch
CLOSE_RECMATCH:
        RET     M
        RET     Z
        CALL    NAMECMP
        RET     NZ
        POP     AF
CLOSE_RECDIR:
        LD      (DIR_ENTPTR+1),HL
        LD      HL,(FC_B40)
        DEC     HL
        LD      A,(HL)
        OR      A
        RET     Z
        CALL    SECTOR_SIZE
        LD      D,B
        LD      E,C
        CALL    DIRENT_START
        LD      HL,(FC_B40)
        CALL    DISK_WRITE
        JP      DIR_STORE
DIR_TOPRN:
        DEFB    00h                     ; ?? |.|
DEV_DEFTYPE:
        DEFB    00h,00h                 ; ?? |..|
;  DIR [FD[n]] [/P] – Verzeichnis ausgeben (nur Direktmodus), mit FD[n]
;  wird außerdem das Standardgerät gesetzt. Je Eintrag Typ, Sperre (*)
;  und Name in Anführungszeichen; Kopfzeile mit Volumennummer bzw. MASTER
;  und freien Sektoren. Bildschirm: nach 20 Zeilen Pause (INLINE_CHK).
ST_DIR: CALL    CHK_DIRECT
        CALL    SKIPCOMMA
        CALL    SKIPSP
        OR      A
        JP      M,ERR_01
        CALL    DEV_DEFAULT
        LD      B,00h
        LD      DE,KW_DEVICES
        CALL    KWSEARCH_B
        JP      NZ,DIR_OPTS
        LD      A,B
        CP      02h
        JP      NC,ERR_01
        LD      (FC_TYPE),A
        CALL    ISDIGIT
        JR      C,DIR_UNIT
        LD      A,01h
        DEC     HL
DIR_UNIT:
        INC     HL
        AND     0Fh
        DEC     A
        CP      04h
        JP      NC,ERR_01
        LD      (FC_UNIT),A
DIR_OPTS:
        XOR     A
        LD      (FC_VOL),A
        LD      (DIR_TOPRN),A
        CALL    CHK_CHR_ALT
D478E:  DEFB    2Fh                     ; Inline-Parameter '/'
D478F:  DEFW    DIR_GO
        CALL    CHK_CHR_ALT
D4794:  DEFB    50h                     ; Inline-Parameter 'P'
D4795:  DEFW    ERR_01
        LD      A,01h
        LD      (DIR_TOPRN),A
; <- aufgerufen von 478Bh
DIR_GO: CALL    CHK_EOS
        XOR     A
        OUT     (GRPH),A
        LD      HL,(FC_TYPE)
        LD      (DEV_DEFTYPE),HL
        LD      A,14h
        LD      (DIR_LINES),A
        CALL    DIR_SCAN
D47B0:  DEFW    DIR_ENTRY
        JP      FILECMD_DONE
; <- aufgerufen von 47ADh
DIR_ENTRY:
        CALL    M,DIR_GETFREE
        LD      DE,DIRENT
        LD      BC,0020h
        LDIR
        RET     Z
        LD      B,26h
        LD      HL,INBUF
DIR_CLRLINE:
        LD      (HL),20h
        INC     HL
        DJNZ    DIR_CLRLINE
        LD      (HL),0Dh
        JP      M,DIR_HEADER
        LD      HL,6B14h
        LD      (HL),22h
        INC     HL
        EX      DE,HL
        LD      HL,DIRENT_NAME
        CALL    LEN_CR
        LD      A,C
        OR      B
        JP      Z,ERR_60
        LD      A,C
        CP      11h
        JP      NC,ERR_60
        LDIR
        LD      A,22h                   ; '"'
        LD      (DE),A
        INC     DE
        LD      A,0Dh
        LD      (DE),A
        LD      A,(DIRENT)
        CP      05h
        JR      C,DIR_TYPENAME
        LD      A,05h
DIR_TYPENAME:
        LD      HL,MSG_FTYPES-3
        LD      BC,0003h
DIR_TYPE_LP:
        ADD     HL,BC
        DEC     A
        JR      NZ,DIR_TYPE_LP
        LD      DE,6B0Eh
        LDIR
        EX      DE,HL
        LD      A,(DIRENT_LOCK)
        OR      A
        JR      Z,DIR_OUT
        LD      (HL),2Ah
DIR_OUT:
        LD      DE,INBUF
        LD      A,(DIR_TOPRN)
        OR      A
        JR      NZ,DIR_OUTPRN
        CALL    PRTSTR
        CALL    CRLF_IF
        LD      HL,DIR_LINES
        DEC     (HL)
        RET     P
        LD      (HL),14h
        JP      INLINE_CHK
DIR_OUTPRN:
        CALL    PRN_LINE
        JP      PRN_CRLF
DIR_HEADER:
        LD      DE,INBUF
        LD      A,(DIRENT_NAME)
        OR      A
        JP      Z,DIR_MASTER
        LD      L,A
        LD      H,00h
        LD      DE,6B12h
        CALL    NUM2DEC
        LD      A,20h                   ; ' '
        LD      (DE),A
        LD      HL,MSG_FTYPES+15
        LD      BC,0004h
        JP      DIR_HDRTXT
DIR_MASTER:
        LD      HL,MSG_FTYPES+19
        LD      BC,0006h
DIR_HDRTXT:
        LD      DE,INBUF
        LDIR
DIR_FREE:
        LD      HL,0FFFFh
        INC     HL
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        LD      A,(HL)
        INC     HL
        LD      H,(HL)
        LD      L,A
        XOR     A
        SBC     HL,DE
        LD      DE,6B17h
        CALL    NUM2DEC
        LD      HL,MSG_FTYPES+25
        LD      BC,000Dh
        LDIR
        JP      DIR_OUT
; <- aufgerufen von 47B5h
DIR_GETFREE:
        PUSH    HL
        PUSH    AF
        CALL    BITMAP_GET
        LD      (DIR_FREE+1),HL
        CALL    FD_MOTOR_OFF
DIR_GF_RET:
        POP     AF
        POP     HL
        RET
;  MSG_FTYPES: Typnamen je 3 Zeichen (1 OBJ, 2 BTX, 3 BSD, 4 BRD, sonst
;  " ? ") und die Texte der DIR-Kopfzeile.
MSG_FTYPES:
        DEFB    "OBJBTXBSDBRD ? VOL.MASTER SECTOR FREE",0Dh
DIR_LINES:
        DEFB    00h                     ; ?? |.|
;  DELETE dateiangabe – Datei löschen: nur Typ 1-4 (Fehler 63), nicht
;  gesperrt (Fehler 46), nicht geöffnet (CHK_NOTOPEN). Sektoren freigeben
;  (FREE_*), Eintrag mit Typ 0 zurückschreiben.
ST_DELETE:
        CALL    FILESPEC
        LD      A,(FC_TYPE)
        CP      03h
        JP      NC,ERR_01
        CALL    CHK_EOS
        CALL    DIR_SCAN
D48C2:  DEFW    DEL_MATCH
        JP      ERR_40
; <- aufgerufen von 48BFh
DEL_MATCH:
        RET     Z
        RET     M
        CALL    NAMECMP
        RET     NZ
        POP     AF
        LD      A,(HL)
        CP      05h
        JP      NC,ERR_63
        LD      (FREE_TYPE+1),A
        CALL    IS_LOCKED
        JP      NZ,ERR_46
        LD      (DIR_ENTPTR+1),HL
        LD      BC,0020h
        LD      DE,DIRENT
        LDIR
        CALL    CHK_NOTOPEN
        XOR     A
        LD      (DIRENT),A
        LD      (FREE_SECS+1),A
        LD      HL,FILECMD_DONE
        PUSH    HL
; <- aufgerufen von 4465h
DIR_WRITEENT:
        LD      HL,DIRENT
DIR_ENTPTR:
        LD      DE,0FFFFh
        LD      BC,0020h
        LDIR
        CALL    DIR_WRITE
        LD      HL,(707Ch)
        LD      BC,0400h
        CALL    AREA_ALLOC
        LD      (FREE_BUF),HL
        CALL    BITMAP_GET
;  FREE_TYPE (Operand) = Dateityp: OBJ/BTX zusammenhängend (FREE_CONT),
;  BSD als Sektorkette (FREE_BSD), BRD über die Sektortabelle (FREE_BRD).
FREE_TYPE:
        LD      A,00h
        DEC     A
        LD      HL,FREETAB
        CALL    TABJUMP
        JP      (HL)
FREETAB:
        DEFW    FREE_CONT
        DEFW    FREE_CONT
        DEFW    FREE_BSD
        DEFW    FREE_BRD
FREE_BSD:
        LD      HL,DIRENT_SEC+2         ; DEC HL/DEC HL liest DIRENT_SEC (erster Sektor)
FREE_BSD_LP:
        DEC     HL
        LD      B,(HL)
        DEC     HL
        LD      C,(HL)
        LD      A,B
        OR      C
        JP      Z,BITMAP_WRITE
        LD      DE,0100h
        LD      HL,(FREE_BUF)
        PUSH    HL
        PUSH    DE
        PUSH    BC
        CALL    DISK_READ
        POP     BC
        LD      DE,0001h
        CALL    FREE_SECS
        POP     DE
        POP     HL
        ADD     HL,DE
        JP      FREE_BSD_LP
; <- aufgerufen von 4941h, 4954h, 49A6h, 49C0h
FREE_SECS:
        LD      A,00h
        JP      BM_MARK
FREE_BUF:
        DEFB    00h,00h                 ; ?? |..|
FREE_CONT:
        CALL    FILE_SECCOUNT
FREE_CONT2:
        CALL    FREE_SECS
        JP      BITMAP_WRITE
; <- aufgerufen von 429Eh, 439Ch, 4951h
FILE_SECCOUNT:
        CALL    SECTOR_SIZE
        PUSH    HL
        LD      HL,(DIRENT_SIZE)
        LD      DE,0000h
FSC_LP: INC     DE
        XOR     A
        SBC     HL,BC
        JR      Z,FSC_DONE
        JR      NC,FSC_LP
FSC_DONE:
        POP     HL
; <- aufgerufen von 473Dh, 4997h
DIRENT_START:
        LD      BC,(DIRENT_SEC)
        RET
;  SECTOR_SIZE – BC = Sektorgröße der Einheit: 256 bei FC_TYPE 0, sonst
;  1024. FILE_SECCOUNT: Anzahl Sektoren für DIRENT_SIZE.
; <- aufgerufen von 3E72h, 4297h, 4738h, 495Ah, 4980h, 4992h
SECTOR_SIZE:
        LD      A,(FC_TYPE)
        LD      BC,0100h
        OR      A
        RET     Z
        LD      BC,0400h
        RET
; <- aufgerufen von 42ACh, 43B0h
SEC2BYTES:
        PUSH    BC
        PUSH    HL
        CALL    SECTOR_SIZE
        LD      HL,0000h
        JR      S2B_CHK
S2B_LP: ADD     HL,BC
        DEC     DE
S2B_CHK:
        LD      A,D
        OR      E
        JR      NZ,S2B_LP
        EX      DE,HL
        POP     HL
        POP     BC
        RET
FREE_BRD:
        CALL    SECTOR_SIZE
        LD      D,B
        LD      E,C
        CALL    DIRENT_START
        LD      HL,(FREE_BUF)
        PUSH    HL
        PUSH    BC
        CALL    DISK_READ
        POP     BC
        LD      DE,0001h
        CALL    FREE_SECS
FREE_BRD_LP:
        POP     HL
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        INC     HL
        LD      A,B
        OR      C
        JP      Z,BITMAP_WRITE
        PUSH    HL
        LD      A,(FC_TYPE)
        OR      A
        LD      DE,0010h
        JR      Z,FREE_BRD_DO
        LD      DE,0004h
FREE_BRD_DO:
        CALL    FREE_SECS
        JP      FREE_BRD_LP
;  IS_LOCKED – NZ, wenn der Verzeichniseintrag HL gesperrt ist (+12h).
; <- aufgerufen von 48D7h, 4B14h
IS_LOCKED:
        PUSH    HL
        LD      BC,0012h
        ADD     HL,BC
        LD      A,(HL)
        POP     HL
        OR      A
        RET
;  KILL [#n[,#m...]] – Einträge aus der Dateitabelle streichen, ohne
;  Nummer alle; anders als CLOSE ohne Schreiben.
ST_KILL:
        CALL    GETFILENO
        LD      (TXTPTR),HL
        JP      P,KILL_ONE
        LD      A,7Fh
        JR      KILL_NO
; <- aufgerufen von 49E6h
KILL_NEXT:
        LD      A,(FILE_NO)
        DEC     A
        JP      Z,FILECMD_DONE
KILL_NO:
        LD      (FILE_NO),A
        CALL    FTAB_FIND
D49E9:  DEFW    KILL_NEXT
        LD      (HL),00h
        JR      KILL_NEXT
KILL_ONE:
        CALL    FTAB_FIND
D49F2:  DEFW    ERR_64
        LD      (HL),00h
        CALL    CHK_CHR_ALT_T
D49F9:  DEFB    2Ch                     ; Inline-Parameter ','
D49FA:  DEFW    FILECMD_DONE
        JP      ST_KILL
;  LOCK / UNLOCK dateiangabe – Sperrbyte (+12h) im Verzeichnis setzen bzw.
;  löschen (nicht bei geöffneten Dateien).
ST_UNLOCK:
        XOR     A
        DEFB    01h                     ; Trick: Opcode 01h verschluckt den folgenden Befehl
ST_LOCK:
        LD      A,01h
        LD      (LOCK_SET+1),A
        CALL    FILESPEC
        CALL    CHK_EOS
        LD      A,(FC_TYPE)
        CP      03h
        JP      NC,ERR_01
        CALL    DIR_SCAN
D4A17:  DEFW    LOCK_MATCH
        JP      FILECMD_DONE
; <- aufgerufen von 4A14h
LOCK_MATCH:
        RET     Z
        RET     M
        CALL    NAMECMP
        RET     NZ
        EX      (SP),HL
        CALL    CHK_NOTOPEN
        POP     HL
        LD      BC,0012h
        ADD     HL,BC
LOCK_SET:
        LD      (HL),0FFh
DIR_WRITEBACK:
        CALL    DIR_WRITE
;  FILECMD_DONE – Puffer aufräumen (CLOSE_ALL), weiter mit NEXTSTMT.
; <- aufgerufen von 46A6h, 49F6h
FILECMD_DONE:
        CALL    CLOSE_ALL
        JP      NEXTSTMT
UNIT_USE:
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h         ; ?? |....|
;  UNITS_CHECK – zählt in UNIT_USE, welche Einheiten noch von geöffneten
;  Dateien benutzt werden, schaltet ohne offene Datei den Motor ab und gibt
;  die Puffer unbenutzter Einheiten frei.
; <- aufgerufen von 4A95h
UNITS_CHECK:
        LD      HL,UNIT_USE
        LD      B,06h
UNITS_CLR:
        CALL    CLRWORD
        DJNZ    UNITS_CLR
        CALL    FTAB_SCAN
D4A4F:  DEFW    UNITS_COUNT
        LD      HL,UNIT_USE
        LD      B,04h
        XOR     A
UNITS_ANY:
        OR      (HL)
        INC     HL
        DJNZ    UNITS_ANY
        CALL    Z,FD_MOTOR_OFF
        LD      HL,7064h
        PUSH    HL
        LD      HL,UNIT_USE
        LD      B,0Ch
UNITS_FREE:
        LD      A,(HL)
        EX      (SP),HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        PUSH    HL
        EX      DE,HL
        OR      A
        CALL    Z,AREA_FREE
        POP     HL
        EX      (SP),HL
        INC     HL
        DJNZ    UNITS_FREE
        POP     AF
        RET
; <- aufgerufen von 4A4Ch
UNITS_COUNT:
        JP      Z,AREA_FREE_DE
        INC     HL
        INC     HL
        LD      A,(HL)
        INC     HL
        LD      C,(HL)
        CP      03h
        RET     NC
        LD      HL,UNIT_USE
        LD      B,00h
        ADD     A,A
        ADD     A,A
        ADD     A,C
        LD      C,A
        ADD     HL,BC
        INC     (HL)
        RET
; <- aufgerufen von 4AA2h
AREA_FREE_DE:
        EX      DE,HL
        JP      AREA_FREE
; <- aufgerufen von 1329h, 14EDh, 4526h, 4A30h
CLOSE_ALL:
        CALL    UNITS_CHECK
        LD      B,04h
        LD      HL,707Ch
CLOSEALL_LP:
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        PUSH    HL
        CALL    AREA_FREE_DE
        POP     HL
        DJNZ    CLOSEALL_LP
        RET
RENAME_NEW:
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    0Dh                     ; ?? |.|
;  RENAME dateiangabe, "neuer name" – Name 1-16 Zeichen (Fehler 60), neuer
;  Name schon vorhanden: Fehler 42, alter fehlt: 40, gesperrt: 46.
ST_RENAME:
        CALL    FILESPEC
        LD      A,(FC_TYPE)
        CP      03h
        JP      NC,ERR_01
        CALL    SKIPCOMMA
        CALL    EVAL
        CALL    CHK_EOS
        LD      A,D
        OR      A
        JP      Z,ERR_60
        LD      A,C
        DEC     A
        CP      10h
        JP      NC,ERR_60
        CALL    GETSTR
        EX      DE,HL
        INC     BC
        LD      DE,RENAME_NEW
        LDIR
        XOR     A
        LD      (RENAME_DO+1),A
        CALL    DIR_SCAN
D4AEB:  DEFW    RENAME_MATCH
        JP      RENAME_DO
; <- aufgerufen von 4AE8h
RENAME_MATCH:
        RET     Z
        RET     M
        LD      DE,RENAME_NEW
        CALL    NAMECMP_DE
        JP      Z,ERR_42
        CALL    NAMECMP
        RET     NZ
        LD      (RENAME_ENT+1),HL
        LD      A,01h
        LD      (RENAME_DO+1),A
        RET
RENAME_DO:
        LD      A,0FFh
        OR      A
        JP      Z,ERR_40
        CALL    CHK_NOTOPEN
RENAME_ENT:
        LD      HL,0FFFFh
        CALL    IS_LOCKED
        JP      NZ,ERR_46
        LD      DE,RENAME_NEW
        INC     HL
        EX      DE,HL
        LD      BC,0011h
        LDIR
        JP      DIR_WRITEBACK
;  GETFILENO – optionales "#n" lesen: FILE_NO = n (1-127, sonst Fehler 64),
;  ohne "#" 80h. Flags: M, wenn kein "#".
; <- aufgerufen von 246Eh, 4583h, 467Dh, 49CFh, 4B5Fh
GETFILENO:
        CALL    CHK_CHR_ALT
D4B2A:  DEFB    23h                     ; Inline-Parameter '#'
D4B2B:  DEFW    FILENO_DEV
        CALL    GETLNUM
D4B30:  DEFW    ERR_64
        LD      A,D
        OR      A
        JP      NZ,ERR_64
        LD      A,E
        DEC     A
        CP      7Fh
        JP      NC,ERR_64
        INC     A
        JR      FILENO_SET
; <- aufgerufen von 4B27h
FILENO_DEV:
        LD      A,80h
FILENO_SET:
        LD      (FILE_NO),A
        OR      A
        RET
;  FTAB_FIND – Eintrag mit Dateinummer A in FILETAB suchen: HL = Eintrag,
;  A = Index; fehlt er, Sprung zur Inline-Adresse.
; <- aufgerufen von 247Ah, 45DAh, 49E6h, 49EFh, 4B67h
FTAB_FIND:
        LD      HL,FILETAB
        LD      DE,0009h
        LD      B,0Ah
FTAB_FIND_LP:
        CP      (HL)
        JR      Z,FTAB_FOUND
        ADD     HL,DE
        DJNZ    FTAB_FIND_LP
        JP      JP_INLINE
FTAB_FOUND:
        LD      A,0Ah
        SUB     B
        JP      RET_SKIP2
;  FILE_SELECT – #n lesen und die Datei zur aktuellen machen (FILE_LOAD:
;  Eintrag nach FC_IDX.., Puffer einrichten), fehlt sie: Fehler 44.
; <- aufgerufen von 3C41h, 3F84h
FILE_SELECT:
        CALL    GETFILENO
        RET     M
; <- aufgerufen von 46AEh
FILE_LOAD:
        PUSH    HL
        LD      A,(FILE_NO)
        CALL    FTAB_FIND
D4B6A:  DEFW    ERR_44
        LD      (FC_ENTRY),HL
        LD      DE,FC_IDX
        LD      (DE),A
        INC     DE
        LD      BC,0009h
        LDIR
        CALL    FILE_INITBUF
        POP     HL
        RET
; <- aufgerufen von 45E9h, 4B79h
FILE_INITBUF:
        LD      HL,INITBUFTAB
        LD      A,(FC_TYPE)
        CALL    TABJUMP
        JP      (HL)
INITBUFTAB:
        DEFW    FILE_INITFD
        DEFW    ERR_01
        DEFW    ERR_01
        DEFW    DEV_NOP
        DEFW    ERR_01
;  FILE_INITFD – Dateipuffer (320 Bytes, Bereich 7050h + 2*FC_IDX) anlegen
;  und FC_B00..FC_B13E darauf setzen, Puffer der Einheit holen.
FILE_INITFD:
        LD      A,(FC_IDX)
        LD      HL,7050h
        CALL    TABJUMP
        LD      BC,0140h
        CALL    AREA_ALLOC
        LD      (FC_B00),HL
        LD      BC,0014h
        ADD     HL,BC
        LD      (FC_B14),HL
        LD      BC,000Ah
        ADD     HL,BC
        LD      (FC_B1E),HL
        INC     HL
        INC     HL
        LD      (FC_B20),HL
        LD      BC,0020h
        ADD     HL,BC
        LD      (FC_B40),HL
        LD      BC,00FEh
        ADD     HL,BC
        LD      (FC_B13E),HL
        CALL    UNIT_GETBUF
        LD      (FC_UNITBUF),HL
        RET
;  AREA_RESIZE – Bereich (Zeiger bei HL) auf BC Bytes bringen (+2 für die
;  Länge, BC = 0: freigeben). AREA_ALLOC: dasselbe, HL hinter die Länge.
;  AREA_FREE: freigeben.
; <- aufgerufen von 4BF7h, 4C01h, 54E0h, 5FE7h
AREA_RESIZE:
        LD      A,B
        OR      C
        JR      Z,AREA_RS_GO
        INC     BC
        INC     BC
AREA_RS_GO:
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        DEC     HL
        PUSH    HL
        LD      H,B
        LD      L,C
        CALL    CPHLDE
        POP     HL
        JR      Z,AREA_RS_SET
        EX      DE,HL
        PUSH    BC
        LD      C,L
        LD      B,H
        CALL    MEMDEL_ADJ
        POP     BC
        CALL    MEMINS_ADJ
        EX      DE,HL
AREA_RS_SET:
        LD      D,H
        LD      E,L
        LD      A,C
        OR      B
        RET     Z
        LD      (HL),C
        INC     HL
        LD      (HL),B
        DEC     HL
        DEC     BC
        DEC     BC
        RET
; <- aufgerufen von 3E78h, 490Ah, 4B9Eh, 4C47h, 4E6Eh
AREA_ALLOC:
        CALL    AREA_RESIZE
        INC     HL
        INC     HL
        RET
; <- aufgerufen von 1B7Bh, 3D54h, 4262h, 46C5h, 4A70h
AREA_FREE:
        PUSH    BC
        LD      BC,0000h
        CALL    AREA_RESIZE
        POP     BC
        RET
BITMAP_WRITE:
        LD      HL,(7082h)
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        DEC     DE
        DEC     DE
        LD      BC,000Fh
        CALL    DISK_WRITE
        RET
;  BITMAP_GET/UNIT_GETBUF – Puffer der Einheit holen; ist er leer, 256
;  Bytes anlegen und Sektor 15 (Belegungstabelle) lesen.
; <- aufgerufen von 487Eh, 4910h, 4CF6h
BITMAP_GET:
        LD      HL,(7082h)
        JP      UNIT_BUFCHK
BITMAP_PTR:
        DEFB    00h,00h                 ; ?? |..|
; <- aufgerufen von 4BC5h, 4C96h, 4E3Ah, 4E64h
UNIT_GETBUF:
        LD      HL,7064h
        LD      A,(FC_UNIT)
        CALL    TABJUMP
UNIT_BUFCHK:
        LD      A,(HL)
        INC     HL
        OR      (HL)
        INC     HL
        CALL    Z,UNIT_BUFNEW
        LD      (BITMAP_PTR),HL
        LD      A,(HL)
        OR      A
        RET     P
        PUSH    HL
        LD      BC,000Fh
        LD      DE,0100h
        CALL    DISK_READ
        POP     HL
        LD      A,(HL)
        OR      A
        RET
; <- aufgerufen von 4C2Bh
UNIT_BUFNEW:
        DEC     HL
        DEC     HL
        LD      BC,0100h
        CALL    AREA_ALLOC
        LD      (HL),80h
        RET
;  DISK_READ / DISK_WRITE – DE Bytes ab Sektor BC nach/von HL. Über
;  DISKTAB nach FC_TYPE + Richtung: nur FD (FD_READ lesen, FD_WRITE schreiben).
; <- aufgerufen von 3E82h, 40ACh, 4359h, 493Ah, 499Fh, 4C3Bh, 5327h, 5349h
DISK_READ:
        XOR     A
        JR      DISK_RW
; <- aufgerufen von 3D48h, 3DCDh, 43BEh, 444Ah, 4743h, 4C12h
DISK_WRITE:
        LD      A,03h
; <- aufgerufen von 4E77h
DISK_RW:
        LD      (DISK_RWOP+1),A
        LD      (DISK_ADDR),HL
        LD      HL,DISK_PAR
        LD      A,(FC_UNIT)
        LD      (HL),A
        INC     HL
        CALL    SAVEPAR_HL
        LD      A,(FC_TYPE)
DISK_RWOP:
        ADD     A,0FFh
        LD      HL,DISKTAB
        CALL    TABJUMP
        LD      IX,DISK_PAR
        CALL    SET_IOERR
        JP      (HL)
DISKTAB:
        DEFW    FD_READ
        DEFW    ERR_01
        DEFW    ERR_01
        DEFW    FD_WRITE
        DEFW    ERR_01
        DEFW    ERR_01
DISK_PAR:
        DEFB    00h,00h,00h,00h,00h     ; ?? |.....|
DISK_ADDR:
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h             ; ?? |...|
;  BM_*: Belegungstabelle (je Sektor ein Bit). Der Bittest wird in den
;  Befehlen bei BM_SCAN_TEST bzw. BM_BITCODE zur Laufzeit zusammengesetzt.
;  Kein freier Bereich: Fehler 53.
; <- aufgerufen von 4D7Dh
BM_SCANINIT:
        POP     HL
        LD      (BM_SCAN_CB+1),HL
        CALL    UNIT_GETBUF
        INC     HL
        LD      A,(HL)
        INC     HL
        INC     HL
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        LD      (BM_SCAN_PTR+1),HL
        EX      DE,HL
        LD      (BM_SCAN_LP+1),HL
        LD      L,A
        LD      H,00h
        LD      (BM_SCAN_SEC+1),HL
BM_SCAN_BYTE:
        XOR     A
        LD      (BM_SCAN_BIT+1),A
BM_SCAN_LP:
        LD      HL,0FFFFh
BM_SCAN_SEC:
        LD      DE,0FFFFh
        CALL    CPHLDE
        JP      C,ERR_53
BM_SCAN_PTR:
        LD      HL,0FFFFh
BM_SCAN_BIT:
        LD      A,0FFh
        ADD     A,A
        ADD     A,A
        ADD     A,A
        OR      46h
        LD      (BM_SCAN_TEST+1),A
BM_SCAN_TEST:
        SET     7,A
        LD      B,D
        LD      C,E
BM_SCAN_CB:
        CALL    Z,0FFFFh
        LD      HL,(BM_SCAN_SEC+1)
        INC     HL
        LD      (BM_SCAN_SEC+1),HL
        LD      HL,BM_SCAN_BIT+1
        INC     (HL)
        LD      A,08h
        CP      (HL)
        JP      NZ,BM_SCAN_LP
        LD      HL,(BM_SCAN_PTR+1)
        INC     HL
        LD      (BM_SCAN_PTR+1),HL
        JP      BM_SCAN_BYTE
        LD      A,01h
        JR      BM_MARK
        DEFB    0AFh                    ; ?? |.|
BM_MARK:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        CALL    BITMAP_GET
        POP     DE
        POP     BC
        POP     AF
BM_MARK_MODE:
        LD      (BM_BITMODE+1),A
        PUSH    BC
        PUSH    DE
BM_MARK_LP:
        PUSH    DE
        CALL    BM_BIT
        POP     DE
        INC     BC
        DEC     DE
        LD      A,D
        OR      E
        JR      NZ,BM_MARK_LP
        POP     DE
        POP     BC
        RET
; <- aufgerufen von 4D02h
BM_BIT: PUSH    BC
        PUSH    HL
        INC     HL
        LD      A,C
        SUB     (HL)
        LD      C,A
        JR      NC,BM_BIT2
        DEC     B
BM_BIT2:
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        PUSH    HL
        PUSH    DE
        PUSH    BC
        LD      A,C
        AND     07h
        ADD     A,A
        ADD     A,A
        ADD     A,A
        LD      C,A
        OR      46h
        LD      (BM_BITCODE+1),A
BM_BITMODE:
        LD      A,0FFh
        OR      A
        LD      A,28h                   ; '('
        JR      NZ,BM_BIT_JR
        LD      A,20h                   ; ' '
BM_BIT_JR:
        LD      (BM_BITCODE+2),A
        LD      A,13h
        JR      NZ,BM_BIT_CNT
        LD      A,1Bh
BM_BIT_CNT:
        LD      (BM_BITCODE+13),A
        LD      A,0C6h
        JR      NZ,BM_BIT_SR
        LD      A,86h
BM_BIT_SR:
        OR      C
        LD      (BM_BITCODE+10),A
        POP     DE
        LD      B,03h
BM_BIT_SHR:
        SRL     D
        RR      E
        DJNZ    BM_BIT_SHR
        ADD     HL,DE
        INC     HL
        INC     HL
        INC     HL
BM_BITCODE:
        DEFB    0CBh,0FFh               ; SMC: BIT n,(HL)   – 2. Byte wird bei 4D28 gesetzt (46h+8*n)
        DEFB    0FFh,05h                ; SMC: JR Z/NZ,+5   – Opcode wird bei 4D34 gesetzt (28h/20h)
        DEFB    0D1h                    ; POP DE
        DEFB    0E1h                    ; POP HL
        DEFB    0E1h                    ; POP HL
        DEFB    0C1h                    ; POP BC
        DEFB    0C9h                    ; RET
        DEFB    0CBh,0FFh               ; SMC: SET/RES n,(HL) – 2. Byte wird bei 4D47 gesetzt
        DEFB    0D1h                    ; POP DE
        DEFB    0E1h                    ; POP HL
        DEFB    0FFh                    ; SMC: INC DE / DEC DE – wird bei 4D3D gesetzt (13h/1Bh)
        DEFB    72h                     ; LD (HL),D
        DEFB    2Bh                     ; DEC HL
        DEFB    73h                     ; LD (HL),E
        DEFB    0E1h                    ; POP HL
        DEFB    0C1h                    ; POP BC
        DEFB    0C9h                    ; RET
;  SEC_ALLOC – DE zusammenhängende freie Sektoren suchen und belegen,
;  BC = erster Sektor.
; <- aufgerufen von 3DFFh, 3F10h, 439Fh, 4621h
SEC_ALLOC:
        CALL    SEC_FINDRUN
        LD      HL,(BITMAP_PTR)
        LD      A,01h
        JP      BM_MARK_MODE
; <- aufgerufen von 4D6Bh
SEC_FINDRUN:
        EX      DE,HL
        LD      (SFR_LEN+1),HL
        CALL    SFR_RESET
        CALL    BM_SCANINIT
SFR_FIRST:
        LD      A,0FFh
        OR      A
        JR      NZ,SFR_NEXT
        INC     A
        LD      (SFR_FIRST+1),A
        LD      (SFR_START+1),BC
        LD      (SFR_NEXT+1),BC
SFR_NEXT:
        LD      HL,0FFFFh
        LD      D,B
        LD      E,C
        CALL    CPHLDE
        JR      NZ,SFR_RESET
        INC     HL
        LD      (SFR_NEXT+1),HL
SFR_COUNT:
        LD      HL,0FFFFh
        DEC     HL
        LD      (SFR_COUNT+1),HL
        LD      A,H
        OR      L
        RET     NZ
        POP     AF
SFR_START:
        LD      BC,0FFFFh
SFR_LEN:
        LD      DE,0FFFFh
        RET
; <- aufgerufen von 4D7Ah
SFR_RESET:
        LD      HL,(SFR_LEN+1)
        LD      (SFR_COUNT+1),HL
        XOR     A
        LD      (SFR_FIRST+1),A
        RET
; <- aufgerufen von 3F35h, 4919h, 4B84h, 4B98h, 4C24h, 4C6Bh, 4EBFh
TABJUMP:
        ADD     A,A
        ADD     A,L
        LD      L,A
        JR      NC,TABJUMP_GO
        INC     H
TABJUMP_GO:
        LD      A,(HL)
        INC     HL
        LD      H,(HL)
        LD      L,A
        RET
;  CHK_NOTOPEN – Fehler 43, wenn die Datei DIRENT in FILETAB geöffnet ist.
; <- aufgerufen von 48E8h, 4A23h, 4B0Eh
CHK_NOTOPEN:
        CALL    FTAB_SCAN
D4DCA:  DEFW    CHK_NOTOPEN_CB
        RET
; <- aufgerufen von 4DC7h
CHK_NOTOPEN_CB:
        RET     Z
        INC     HL
        INC     HL
        LD      A,(FC_TYPE)
        CP      (HL)
        RET     NZ
        CP      03h
        RET     Z
        CP      04h
        JP      Z,ERR_43
        INC     HL
        LD      A,(FC_UNIT)
        CP      (HL)
        RET     NZ
        EX      DE,HL
        INC     HL
        INC     HL
        CALL    NAMECMP
        RET     NZ
        JP      ERR_43
DIR_FREEFLG:
        DEFB    00h                     ; ?? |.|
DIR_FREEENT:
        DEFB    00h,00h                 ; ?? |..|
DIR_COUNT:
        DEFB    00h                     ; ?? |.|
DIR_PTR:
        DEFB    00h,00h                 ; ?? |..|
;  DIR_SCAN – Verzeichnis lesen (64 Einträge zu 32 Bytes) und für jeden die
;  Rückrufroutine (Inline-Adresse) mit HL = Eintrag aufrufen: Z = leer,
;  M = Diskettenkopf (Volumen wird geprüft, falsche Diskette: Fehler 52).
;  Die Rückrufroutine kehrt zurück (weiter suchen) oder bricht mit POP AF
;  ab. Danach: A = 1 und HL = erster freier Eintrag, falls es einen gab;
;  Fortsetzung hinter dem Inline-Wort.
; <- aufgerufen von 423Fh, 4418h, 4485h, 44BBh, 4606h, 46FAh, 471Ch, 47ADh (+3 weitere)
DIR_SCAN:
        POP     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        LD      (DIR_SCAN_RET+1),HL
        EX      DE,HL
        LD      (DIR_SCAN_CB+1),HL
        XOR     A
        LD      (DIR_FREEFLG),A
        CALL    DIR_READ
        LD      (DIR_PTR),HL
        LD      A,40h                   ; '@'
        LD      (DIR_COUNT),A
DIR_SCAN_LP:
        LD      HL,(DIR_PTR)
        LD      A,(HL)
        BIT     7,A
        CALL    NZ,DIR_VOLCHK
        OR      A
        CALL    Z,DIR_FREEMARK
DIR_SCAN_CB:
        CALL    0FFFFh
        LD      HL,(DIR_PTR)
        LD      BC,0020h
        ADD     HL,BC
        LD      (DIR_PTR),HL
        LD      HL,DIR_COUNT
        DEC     (HL)
        JP      NZ,DIR_SCAN_LP
        LD      A,(DIR_FREEFLG)
        LD      HL,(DIR_FREEENT)
        OR      A
DIR_SCAN_RET:
        JP      0FFFFh
; <- aufgerufen von 4E14h
DIR_VOLCHK:
        PUSH    HL
        CALL    UNIT_GETBUF
        LD      A,(FC_VOL)
        OR      A
        JR      Z,DIR_VOLSET
        CP      (HL)
        JP      NZ,ERR_52
DIR_VOLSET:
        LD      A,(HL)
        LD      (FC_VOL),A
        POP     HL
        LD      A,(HL)
        RET
; <- aufgerufen von 4E18h
DIR_FREEMARK:
        PUSH    AF
        LD      A,(DIR_FREEFLG)
        OR      A
        JR      NZ,DIR_FM_RET
        INC     A
        LD      (DIR_FREEFLG),A
        LD      (DIR_FREEENT),HL
DIR_FM_RET:
        POP     AF
        RET
;  DIR_READ / DIR_WRITE – 2 KB Verzeichnis ab Sektor 16 in
;  den Puffer 707Ch lesen bzw. zurückschreiben.
; <- aufgerufen von 4E03h
DIR_READ:
        XOR     A
        JR      DIR_RW
; <- aufgerufen von 4901h, 4A2Dh
DIR_WRITE:
        LD      A,03h
DIR_RW: PUSH    AF
        CALL    UNIT_GETBUF
        LD      HL,(707Ch)
        LD      BC,0800h
        PUSH    BC
        CALL    AREA_ALLOC
        POP     DE
        LD      BC,0010h
        POP     AF
        PUSH    HL
        CALL    DISK_RW
        POP     HL
        RET
;  NAMECMP – DIRENT_NAME mit dem Namen im Eintrag HL (+1) vergleichen,
;  höchstens 16 Zeichen bzw. bis 0Dh. Z = gleich.
; <- aufgerufen von 4249h, 45CCh, 4633h, 4715h, 4729h, 48C9h, 4A1Eh, 4AFBh (+3 weitere)
NAMECMP:
        LD      DE,DIRENT_NAME
; <- aufgerufen von 4AF5h
NAMECMP_DE:
        PUSH    HL
        INC     HL
        LD      B,10h
NAMECMP_LP:
        LD      A,(DE)
        CP      (HL)
        JR      NZ,NAMECMP_RET
        INC     HL
        INC     DE
        CP      0Dh
        JR      Z,NAMECMP_RET
        DEC     B
        JR      NZ,NAMECMP_LP
NAMECMP_RET:
        POP     HL
        RET
;  FTAB_SCAN – für jeden der 10 FILETAB-Einträge die Rückrufroutine
;  (Inline-Adresse) aufrufen, HL = Eintrag, A = Dateinummer (Z = frei);
;  danach weiter hinter dem Inline-Wort.
; <- aufgerufen von 45A2h, 4A4Ch, 4DC7h
FTAB_SCAN:
        POP     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        LD      (FTS_DONE+1),HL
        EX      DE,HL
        LD      (FTS_CB+1),HL
        LD      A,0Ah
        LD      (FTS_COUNT+1),A
        LD      HL,704Ch
        JR      FTS_PREV
FTS_NEXT:
        LD      HL,0FFFFh
FTS_PREV:
        LD      DE,0FFF7h
        ADD     HL,DE
        LD      (FTS_NEXT+1),HL
        EX      DE,HL
FTS_COUNT:
        LD      A,0FFh
        DEC     A
        LD      (FTS_COUNT+1),A
FTS_DONE:
        JP      M,0FFFFh
        LD      HL,7050h
        CALL    TABJUMP
        EX      DE,HL
        LD      A,(HL)
        OR      A
FTS_CB: CALL    0FFFFh
        JR      FTS_NEXT
;  DIRENT: Verzeichniseintrag (32 Bytes): Typ (1 OBJ, 2 BTX, 3 BSD,
;  4 BRD), Name (16 + 0Dh), +12h Sperre, +14h Größe, +16h Ladeadresse,
;  +18h Startadresse, +1Eh erster Sektor.
DIRENT: DEFB    00h                     ; ?? |.|
DIRENT_NAME:
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h                     ; ?? |.|
DIRENT_LOCK:
        DEFB    00h,00h                 ; ?? |..|
DIRENT_SIZE:
        DEFB    00h,00h                 ; ?? |..|
DIRENT_LOAD:
        DEFB    00h,00h                 ; ?? |..|
DIRENT_EXEC:
        DEFB    00h,00h,00h,00h,00h,00h ; ?? |......|
DIRENT_SEC:
        DEFB    00h,00h                 ; ?? |..|
;  FILESPEC – Dateiangabe lesen: [FD[1-4][@vol],] "name" (1-16 Zeichen,
;  sonst Fehler 60) oder USR(adresse) (FC_TYPE 3: eigene Treiberroutine).
;  Ohne Gerät gilt das Standardgerät. Laufwerk 1-4: Fehler 61,
;  Volumen 1-127: Fehler 52.
; <- aufgerufen von 4222h, 4382h, 43F8h, 458Fh, 48B1h, 4A06h, 4ABAh
FILESPEC:
        PUSH    HL
        LD      HL,(DEV_DEFTYPE)
        LD      (FC_TYPE),HL
        LD      HL,FC_VOL
        LD      B,05h
FSPEC_CLR:
        LD      (HL),00h
        INC     HL
        DJNZ    FSPEC_CLR
        LD      HL,DIRENT_NAME
        LD      B,11h
FSPEC_CLRNAME:
        LD      (HL),0Dh
        INC     HL
        DJNZ    FSPEC_CLRNAME
        LD      B,0Eh
FSPEC_CLRREST:
        LD      (HL),00h
        INC     HL
        DJNZ    FSPEC_CLRREST
        POP     HL
        CALL    SKIPCOMMA
        CALL    CHK_CHR_ALT
D4F13:  DEFB    80h                     ; Inline-Parameter
D4F14:  DEFW    FSPEC_DEV
        CALL    SYNCHK
D4F19:  DEFB    0A0h                    ; Inline-Parameter
        CALL    EVAL_ADDR
        CALL    SYNCHK
D4F20:  DEFB    29h                     ; Inline-Parameter ')'
        PUSH    HL
        LD      HL,FC_TYPE
        LD      (HL),03h
        INC     HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        POP     HL
        RET
; <- aufgerufen von 4F10h
FSPEC_DEV:
        LD      B,00h
        LD      DE,KW_DEVICES
        CALL    KWSEARCH_B
        JR      NZ,FSPEC_NAME
        LD      A,B
        LD      (FC_TYPE),A
        CALL    ISDIGIT
        CALL    C,FSPEC_UNIT
        CALL    SKIPSP
        CP      40h                     ; '@'
        CALL    Z,FSPEC_VOL
FSPEC_NAME:
        CALL    SKIPCOMMA
        CALL    EVAL
        LD      A,D
        OR      A
        JP      Z,ERR_60
        LD      A,C
        DEC     A
        CP      10h
        JP      NC,ERR_60
        PUSH    HL
        CALL    GETSTR
        LD      HL,DIRENT_NAME
        EX      DE,HL
        LDIR
        POP     HL
        RET
KW_DEVICES:
        DEFB    46h,0C4h,0FFh,0FFh,0FFh,0FFh,00h  ; ?? |F......|
; <- aufgerufen von 4F3Eh
FSPEC_UNIT:
        AND     0Fh
        DEC     A
        CP      04h
        JP      NC,ERR_61
        LD      (FC_UNIT),A
        INC     HL
        RET
; <- aufgerufen von 4F46h
FSPEC_VOL:
        INC     HL
        CALL    GETLNUM
D4F7F:  DEFW    ERR_52
        LD      A,D
        OR      A
        JP      NZ,ERR_52
        LD      A,E
        DEC     A
        CP      7Fh
        JP      NC,ERR_52
        INC     A
        LD      (FC_VOL),A
        RET
; <- aufgerufen von 20D0h, 244Ch, 29AEh, 29D2h, 29F9h, 2A13h, 2ADFh, 2B08h (+25 weitere)
SKIPCOMMA:
        CALL    CHK_CHR_ALT
D4F95:  DEFB    2Ch                     ; Inline-Parameter ','
D4F96:  DEFW    SKIPCOMMA_RET
; <- aufgerufen von 4F92h
SKIPCOMMA_RET:
        RET
;  GETDEVICE – nach "/": P -> FILE_NO 82h (Drucker), T -> 83h (Kassette).
; <- aufgerufen von 3C3Ch, 3F7Eh
GETDEVICE:
        LD      B,00h
        LD      DE,KW_PT
        CALL    KWSEARCH_B
        JP      NZ,ERR_01
        CALL    SKIPCOMMA
        LD      A,B
        ADD     A,82h
        LD      (FILE_NO),A
        RET
KW_PT:  DEFB    0D0h,0D4h,00h           ; ?? |...|
;  REW / FAST – Kassette zurück- bzw. vorspulen. TAPE_WAIT verlangt eine
;  eingelegte Kassette ("Set tape", BREAK bricht ab).
ST_REW: CALL    TAPE_WAIT
        LD      A,(PPI_A_COPY)
        RES     1,A
        CALL    PPIA_OUT
        CALL    CMT_FASTCMD
REW_DONE:
        JP      NEXTSTMT_HL
ST_FAST:
        CALL    TAPE_WAIT
        CALL    CMT_REWCMD
        JR      REW_DONE
; <- aufgerufen von 4FB1h, 4FC2h
TAPE_WAIT:
        CALL    KEYROW3
        IN      A,(PPI_B)
        AND     20h
        RET     Z
        LD      DE,MSG_SETTAPE
        CALL    MSGX
        CALL    CMT_EJECT
TAPE_WAIT_LP:
        CALL    BRKKEY
        JP      C,BREAK
        IN      A,(PPI_B)
        AND     20h
        JR      NZ,TAPE_WAIT_LP
        JP      DLY_MID
;  VERIFY ["name"] – gespeichertes Programm mit dem Band vergleichen (nur
;  Direktmodus). LOAD /T ["name"] läuft über denselben Weg (LOAD_MODE 1).
ST_VERIFY:
        CALL    CHK_DIRECT
        XOR     A
        JR      TAPE_LV
VFY_DO: LD      A,(CMT_HEADER)
        CP      02h
        JR      NZ,TLV_SEARCH
        CALL    MSG_VERIFYING
        CALL    UNLINK
        CALL    VFDATA
        PUSH    AF
        CALL    RELINK_ALL
        POP     AF
        JP      C,TAPE_ERR
        LD      DE,MSG_OK
        CALL    MSGX
        JP      NEXTSTMT
LOAD_TAPE:
        LD      A,01h
;  TAPE_LV – Kassette lesen: Kopf suchen (Typ 1-3, Name passend oder leer),
;  "Found"/"Loading" ausgeben. Typ 2 (BTX): Programm laden, Typ 1 (OBJ):
;  an die Ladeadresse (TLV_OBJ; unter LIMIT: Fehler 18, über MEMTOP:
;  Fehler 6). Lesefehler: TAPE_ERR (Fehler 70 bzw. BREAK).
TAPE_LV:
        LD      (LOAD_MODE),A
        LD      BC,TLV_HEAD
        PUSH    BC
        JP      TAPE_NAME
TLV_SEARCH:
        CALL    CMT_REWIND
        CALL    CMT_STOP
        JR      C,TLV_CHK
        CALL    DLY_SHORT
TLV_HEAD:
        CALL    RDHEAD
TLV_CHK:
        JP      C,TAPE_ERR
        CALL    MSG_FOUNDNAME
        LD      HL,CMT_HEADER
        LD      A,(HL)
        OR      A
        JR      Z,TLV_SEARCH
        CP      04h
        JR      NC,TLV_SEARCH
        LD      DE,DIRENT_NAME
        LD      A,(DE)
        CP      0Dh
        JR      Z,TLV_FOUND
        CALL    NAMECMP
        JR      NZ,TLV_SEARCH
TLV_FOUND:
        LD      A,(LOAD_MODE)
        OR      A
        JR      Z,VFY_DO
        LD      A,(CMT_HEADER)
        CP      01h
        JP      Z,TLV_OBJ
        CP      02h
        JR      NZ,TLV_SEARCH
        CALL    CLEARALL
        LD      HL,(CMT_HSIZE)
        DEC     HL
        DEC     HL
        LD      C,L
        LD      B,H
        LD      DE,PRGTXT
        CALL    MEMINS
        CALL    ADJ_PTRS
        LD      (CMT_HLOAD),DE
        CALL    MSG_LOADNAME
        CALL    RDDATA
        JR      C,TLV_ERR
        JP      LOAD_RELINK
TLV_ERR:
        PUSH    AF
        CALL    TLV_UNDO
        CALL    CLEARALL
        POP     AF
        JP      TAPE_ERR
; <- aufgerufen von 507Eh
TLV_UNDO:
        LD      DE,725Eh
        LD      HL,PRGEND
        XOR     A
        SBC     HL,DE
        RET     Z
        LD      C,L
        LD      B,H
        DEC     DE
        DEC     DE
        CALL    MEMDEL
        CALL    NEGBC
        JP      ADJ_PTRS
; <- aufgerufen von 4FF7h
MSG_VERIFYING:
        LD      DE,MSG_VERIFY
        JR      TAPE_MSGNAME
; <- aufgerufen von 502Eh
MSG_FOUNDNAME:
        LD      DE,MSG_FOUND
        JR      TAPE_MSGNAME
; <- aufgerufen von 5072h, 50E7h
MSG_LOADNAME:
        LD      DE,MSG_LOADING
TAPE_MSGNAME:
        CALL    MSGX
        LD      DE,CMT_HNAME
        LD      A,(DE)
        CP      0Dh
        RET     Z
        PUSH    DE
        CALL    PRT_QUOTE
        POP     DE
        LD      A,0Dh
        LD      (CMT_HNAME_END),A
        CALL    PRTSTR
; <- aufgerufen von 50B7h
PRT_QUOTE:
        LD      DE,STR_QUOTE
        JP      PRTSTR
STR_QUOTE:
        DEFB    22h,0Dh                 ; ?? |".|
TLV_OBJ:
        LD      HL,(CMT_HLOAD)
        EX      DE,HL
        LD      HL,(STKTOP)
        DEC     HL
        CALL    CPHLDE
        JR      NC,TLV_TOOLOW
        LD      HL,(CMT_HSIZE)
        ADD     HL,DE
        JR      C,TLV_TOOBIG
        EX      DE,HL
        LD      HL,(MEMTOP)
        CALL    CPHLDE
        JR      C,TLV_TOOBIG
        CALL    MSG_LOADNAME
        CALL    RDDATA
        JP      C,TAPE_ERR
        JP      NEXTSTMT
TLV_TOOLOW:
        CALL    CMT_STOP
        JP      ERR_18
TLV_TOOBIG:
        CALL    CMT_STOP
        JP      ERR_06
;  SAVE /T ["name"] – Programm (Typ 2) mit Kopf auf Kassette schreiben.
SAVE_TAPE:
        LD      BC,SAVE_TAPE_GO
        PUSH    BC
;  TAPE_NAME – optional ",", dann optional "name" (1-16 Zeichen, sonst
;  Fehler 60) nach DIRENT_NAME; Typ in DIRENT.
TAPE_NAME:
        CALL    CHK_CHR_ALT
D5106:  DEFB    2Ch                     ; Inline-Parameter ','
D5107:  DEFW    TAPE_NAME_GO
; <- aufgerufen von 5103h
TAPE_NAME_GO:
        PUSH    HL
        LD      HL,DIRENT
        LD      (HL),02h
TAPE_NAME_CLR:
        LD      B,11h
TAPE_NAME_LP:
        INC     HL
        LD      (HL),0Dh
        DJNZ    TAPE_NAME_LP
        CALL    CONT_CLR
        POP     HL
        CALL    CHRGET
        LD      (TXTPTR),HL
        RET     Z
        CALL    EVAL
        CALL    CHRGET
        JP      NZ,ERR_01
        LD      (TXTPTR),HL
        LD      A,D
        OR      A
        JP      Z,ERR_60
        CALL    GETSTR
        LD      A,C
        OR      A
        RET     Z
        CP      11h
        JP      NC,ERR_60
        EX      DE,HL
        LD      DE,DIRENT_NAME
        LDIR
        RET
; <- aufgerufen von 5157h, 522Ch
TAPE_SETHDR:
        LD      DE,CMT_HEADER
        LD      HL,DIRENT
        LD      BC,0012h
        LDIR
        LD      B,6Eh
TAPE_HDRCLR:
        XOR     A
        LD      (DE),A
        INC     DE
        DJNZ    TAPE_HDRCLR
        RET
SAVE_TAPE_GO:
        CALL    TAPE_SETHDR
        LD      HL,PRGTXT
        LD      (CMT_HLOAD),HL
        LD      DE,PRGTXT
        LD      HL,(PRGEND)
        XOR     A
        SBC     HL,DE
        LD      (CMT_HSIZE),HL
        CALL    WRHEAD
        JP      C,BREAK
        CALL    UNLINK
        CALL    WRDATA
        PUSH    AF
        CALL    RELINK
        POP     AF
        JP      C,BREAK
        JP      BAS_READY
;  TPRINT / TINPUT – PRINT/INPUT /T: Text in den Puffer TAPEBUF (256
;  Bytes) bzw. aus ihm; ein voller Puffer wird als Block geschrieben bzw.
;  der nächste Block gelesen. FFh im Puffer markiert das Ende der Datei.
;  TFILE_MODE: 0 keine, 1 WOPEN /T, 2 ROPEN /T; TFILE_PTR: Position.
;  Falsche Richtung: Fehler 44.
TPRINT: CALL    CONT_CLR
        LD      A,(TFILE_MODE)
        CP      01h
        JR      NZ,TFILE_ERR44
        LD      HL,(TFILE_PTR)
TPRINT_LP:
        PUSH    DE
        LD      DE,TAPEBUF_END
        CALL    CPHLDE
        JR      C,TPRINT_PUT
        CALL    DLY_OFF
        CALL    WRDATA
        CALL    DLY_ON
        JR      C,TAPE_BREAK
        LD      HL,TAPEBUF
TPRINT_PUT:
        POP     DE
        LD      A,(DE)
        LD      (HL),A
        INC     HL
        INC     DE
        CP      0Dh
        JR      NZ,TPRINT_LP
        LD      (TFILE_PTR),HL
        RET
TINPUT: CALL    CONT_CLR
        LD      A,(TFILE_MODE)
        PUSH    DE
        LD      C,00h
        CP      02h
TFILE_ERR44:
        JP      NZ,ERR_44
        LD      (LOAD_MODE),A
        LD      HL,(TFILE_PTR)
TINPUT_LP:
        PUSH    DE
        LD      DE,TAPEBUF_END
        CALL    CPHLDE
        JR      C,TINPUT_GET
        PUSH    BC
        LD      A,0C9h
        LD      (CMT_REWIND),A
        CALL    RDDATA
        PUSH    AF
        LD      A,0CDh
        LD      (CMT_REWIND),A
        POP     AF
        POP     BC
        JR      NC,TINPUT_BUF
TAPE_ERR:
        INC     A
        JP      Z,ERR_70
TAPE_BREAK:
        JP      BREAK
TINPUT_BUF:
        LD      HL,TAPEBUF
TINPUT_GET:
        LD      A,(HL)
        LD      B,A
        CP      0FFh
        JR      NZ,TINPUT_PUT
        LD      A,(LOAD_MODE)
        CP      02h
        JP      Z,ERR_63
TINPUT_PUT:
        XOR     A
        LD      (LOAD_MODE),A
        LD      A,B
        POP     DE
        LD      (DE),A
        INC     HL
        INC     DE
        INC     C
        CP      0Dh
        JR      NZ,TINPUT_LP
        DEC     C
        POP     DE
        LD      (TFILE_PTR),HL
        LD      B,00h
        RET
TFILE_MODE:
        DEFB    00h                     ; ?? |.|
TFILE_PTR:
        DEFB    00h,00h                 ; ?? |..|
;  WOPEN /T ["name"] – Kopf (Typ 3, BSD) schreiben, Puffer leeren.
;  ROPEN /T ["name"] – Kopf vom Typ 3 suchen. Schon geöffnet: Fehler 43.
WOPEN_TAPE:
        CALL    CHK_NODIRECT
        LD      A,(TFILE_MODE)
        OR      A
        JP      NZ,ERR_43
        LD      BC,WOPEN_T_GO
        PUSH    BC
        PUSH    HL
        LD      HL,DIRENT
        LD      (HL),03h
        JP      TAPE_NAME_CLR
WOPEN_T_GO:
        CALL    TAPE_SETHDR
        LD      HL,0100h
        LD      (CMT_HSIZE),HL
        LD      HL,TAPEBUF
        LD      (TFILE_PTR),HL
        LD      (CMT_HLOAD),HL
        LD      A,11h
        LD      (CMT_WRMSG),A
        CALL    WRHEAD
        PUSH    AF
        LD      A,0CDh
        LD      (CMT_WRMSG),A
        POP     AF
TAPE_CHKBRK:
        JR      C,TAPE_BREAK
        CALL    CMT_STOP
        LD      A,01h
        LD      (TFILE_MODE),A
TFILE_DONE:
        JP      NEXTSTMT
ROPEN_TAPE:
        CALL    CHK_NODIRECT
        LD      A,(TFILE_MODE)
        OR      A
        JP      NZ,ERR_43
        LD      BC,ROPEN_T_SRCH
        PUSH    BC
        LD      A,02h
        LD      (LOAD_MODE),A
        PUSH    HL
        LD      HL,DIRENT
        LD      (HL),04h
        JP      TAPE_NAME_CLR
ROPEN_T_SRCH:
        CALL    RDHEAD
        JP      C,TAPE_ERR
        LD      HL,CMT_HEADER
        LD      A,(HL)
        CP      03h
        JR      NZ,ROPEN_T_SRCH
        LD      DE,DIRENT_NAME
        LD      A,(DE)
        CP      0Dh
        JR      Z,ROPEN_T_OK
        CALL    NAMECMP
        JR      NZ,ROPEN_T_SRCH
ROPEN_T_OK:
        LD      A,02h
        LD      (TFILE_MODE),A
        CALL    CMT_STOP
        LD      HL,TAPEBUF
        LD      (CMT_HLOAD),HL
        LD      HL,0100h
        LD      (CMT_HSIZE),HL
        LD      HL,TAPEBUF_END
        LD      (TFILE_PTR),HL
        JR      TFILE_DONE
;  CLOSE /T – beim Schreiben letzten Block mit FFh-Ende schreiben, beim
;  Lesen Band stoppen; TFILE_MODE = 0.
CLOSE_TAPE:
        CALL    CONT_CLR
        LD      A,(TFILE_MODE)
        OR      A
        JR      Z,CLOSE_T_RET
        PUSH    HL
        DEC     A
        JR      NZ,CLOSE_T_READ
        LD      HL,(TFILE_PTR)
        LD      DE,TAPEBUF_END
        CALL    CPHLDE
        JR      NC,CLOSE_T_FULL
CLOSE_T_LAST:
        LD      (HL),0FFh
        CALL    WRDATA
CLOSE_T_CHK:
        JR      C,TAPE_CHKBRK
CLOSE_T_DONE:
        XOR     A
        LD      (TFILE_MODE),A
        POP     HL
CLOSE_T_RET:
        JP      ST_REM
CLOSE_T_FULL:
        CALL    DLY_OFF
        CALL    WRDATA
        CALL    DLY_ON
        JR      C,CLOSE_T_CHK
        LD      HL,TAPEBUF
        JR      CLOSE_T_LAST
CLOSE_T_READ:
        CALL    CMT_REWIND
        CALL    CMT_STOP
        JR      CLOSE_T_DONE
;  DLY_OFF/DLY_ON – Wartezeit DLY_LONG des Monitors abschalten (C9h = RET)
;  bzw. wieder einschalten (3Eh), damit Blöcke ohne Pause folgen.
; <- aufgerufen von 5199h, 52D4h
DLY_OFF:
        PUSH    AF
        LD      A,0C9h
DLY_SET:
        LD      (DLY_LONG),A
        POP     AF
        RET
; <- aufgerufen von 519Fh, 52DAh
DLY_ON: PUSH    AF
        LD      A,3Eh                   ; '>'
        JR      DLY_SET
;  LOAD_OBJ – Maschinenprogramm (OBJ) von Diskette an seine Ladeadresse
;  laden (unter LIMIT: Fehler 18, über MEMTOP: Fehler 6). Bei RUN "datei"
;  stattdessen RUN_OBJ.
LOAD_OBJ:
        LD      BC,(DIRENT_SIZE)
        LD      DE,(DIRENT_LOAD)
        LD      A,(RUN_LOADFLG)
        OR      A
        JR      NZ,RUN_OBJ
        LD      HL,(STKTOP)
        EX      DE,HL
        CALL    CPHLDE
        JP      C,ERR_18
        ADD     HL,BC
        EX      DE,HL
        LD      HL,(MEMTOP)
        CALL    CPHLDE
        JP      C,ERR_06
        LD      BC,(DIRENT_SEC)
        LD      DE,(DIRENT_SIZE)
        LD      HL,(DIRENT_LOAD)
        CALL    DISK_READ
        CALL    FD_MOTOR_OFF
        LD      A,(SAVE_CHAIN)
        LD      (CHAIN_MODE),A
        LD      A,(SAVE_RUNFLG)
        LD      (RUN_LOADFLG),A
        JP      NEXTSTMT
SAVE_CHAIN:
        DEFB    00h                     ; ?? |.|
SAVE_RUNFLG:
        DEFB    00h                     ; ?? |.|
;  RUN_OBJ – OBJ-Programm erst nach PRGTXT laden, dann RUN_TRAMP mit Länge,
;  Quelle, Ziel und Startadresse füllen, nach FF10h kopieren und dort
;  ausführen: verschiebt das Programm an seine Ladeadresse (LDDR, wenn es
;  nach oben geht) und springt es an.
RUN_OBJ:
        LD      HL,PRGTXT
        LD      BC,(DIRENT_SEC)
        LD      DE,(DIRENT_SIZE)
        CALL    DISK_READ
        CALL    FD_MOTOR_OFF
        LD      HL,(DIRENT_SIZE)
        LD      B,H
        LD      C,L
        LD      (RUN_TRAMP+1),HL
        LD      HL,(DIRENT_EXEC)
        LD      (RUN_TRAMP+12),HL
        LD      HL,PRGTXT
        LD      DE,(DIRENT_LOAD)
        CALL    CPHLDE
        JR      C,RUN_OBJ_DOWN
        LD      A,0B0h
RUN_OBJ_GO:
        LD      (RUN_TRAMP+10),A
        LD      (RUN_TRAMP+4),HL
        LD      (RUN_TRAMP+7),DE
        LD      BC,000Eh                ; 14 Bytes
        LD      HL,RUN_TRAMP
        LD      DE,0FF10h
        LDIR
        JP      0FF10h
RUN_OBJ_DOWN:
        EX      DE,HL
        ADD     HL,BC
        DEC     HL
        EX      DE,HL
        ADD     HL,BC
        DEC     HL
        LD      A,0B8h
        JR      RUN_OBJ_GO
; Kopier- und Startroutine, wird nach FF10h kopiert und dort ausgeführt
; (Operanden werden vorher eingesetzt, LDIR/LDDR je nach Richtung)
RUN_TRAMP:
        LD      BC,0FFFFh               ; RUN_TRAMP+1: Länge
        LD      HL,0FFFFh               ; RUN_TRAMP+4: Quelle (PRGTXT)
        LD      DE,0FFFFh               ; RUN_TRAMP+7: Ziel (Ladeadresse)
        LDIR                            ; RUN_TRAMP+10: B0h LDIR / B8h LDDR
        JP      0FFFFh                  ; RUN_TRAMP+12: Startadresse
;  PRN_EOLCHK – Zeilenvorschub nur, wenn die Druckerzeile nicht leer ist.
;  PRN_CRLF – Drucker prüfen, LF senden, Spalte 0.
; <- aufgerufen von 1EE5h
PRN_EOLCHK:
        LD      A,(PRN_COL)
        OR      A
        RET     Z
; <- aufgerufen von 1EEBh, 54CBh, 559Fh, 55C0h
PRN_CRLF:
        CALL    PRN_CHECK
        LD      A,0Ah
        CALL    PRN_OUT
        XOR     A
        LD      (PRN_COL),A
        RET
;  PRN_TEXT – Text (DE, bis 0Dh) drucken und PRN_COL mitzählen.
;  Steuerzeichen 05h, 06h, 10h-15h werden in Druckerbefehle übersetzt
;  (PRN_CTRL), andere unter 20h übergangen.
PRN_TEXT:
        PUSH    BC
        PUSH    DE
        LD      A,(PRN_COL)
        LD      B,A
PRN_TEXT_LP:
        LD      A,(DE)
        CP      0Dh
        JP      Z,PRN_SETCOL
        CP      20h                     ; ' '
        CALL    C,PRN_CTRL
        CALL    PRN_OUT
        INC     B
        INC     DE
        JR      PRN_TEXT_LP
; <- aufgerufen von 53BBh
PRN_CTRL:
        CP      05h
        JR      Z,PRN_C_FF
        CP      06h
        JR      Z,PRN_C_06
        CP      10h
        JR      Z,PRN_C_10
        CP      11h
        JR      Z,PRN_C_11
        CP      12h
        JR      Z,PRN_C_0E
        CP      13h
        JR      Z,PRN_C_13
        CP      14h
        JR      Z,PRN_C_14
        CP      15h
        JR      Z,PRN_C_15
        POP     AF
        INC     DE
        JR      PRN_TEXT_LP
PRN_C_FF:
        LD      A,0Ch
PRN_C_RET:
        LD      B,0FFh
        RET
PRN_C_0E:
        LD      A,0Eh
        JR      PRN_C_RET
PRN_C_11:
        CALL    PRN_ESC
        XOR     A
        LD      (PRN_LFMODE),A
        JR      PRN_C_RET
PRN_C_06:
        LD      A,14h
        CALL    PRN_OUT
        LD      A,12h
        CALL    PRN_OUT
        CALL    PRN_ESC_02
        CALL    PRN_OUT
        JR      PRN_C_FF
PRN_C_10:
        CALL    PRN_ESC_02
        JR      PRN_C_RET
PRN_C_13:
        LD      A,14h
        JR      PRN_C_RET
PRN_C_14:
        LD      A,0Fh
        JR      PRN_C_RET
PRN_C_15:
        LD      A,12h
        JR      PRN_C_RET
;  PRN_LINE – Text unverändert drucken (für LIST/P, DIR/P).
; <- aufgerufen von 1EE8h, 482Bh
PRN_LINE:
        PUSH    BC
        PUSH    DE
        LD      A,(PRN_COL)
        LD      B,A
PRN_LINE_LP:
        LD      A,(DE)
        CP      0Dh
        JR      Z,PRN_SETCOL
        CALL    PRN_OUT
        INC     DE
        INC     B
        JR      PRN_LINE_LP
PRN_SETCOL:
        LD      A,B
        CP      0A0h
        JR      C,PRN_COLST
        SUB     0A0h
PRN_COLST:
        LD      (PRN_COL),A
        POP     DE
        POP     BC
        JP      PRN_CHECK
; <- aufgerufen von 5405h, 540Dh
PRN_ESC_02:
        CALL    PRN_ESC
        LD      A,02h
        LD      (PRN_LFMODE),A
        RET
PRN_LFMODE:
        DEFB    02h                     ; ?? |.|
;  PRN_TABZONE – PRINT "," auf dem Drucker: Leerzeichen bis zur nächsten
;  Spalte, die durch 10 teilbar ist.
PRN_TABZONE:
        PUSH    BC
        PUSH    DE
        LD      A,(PRN_COL)
        LD      B,A
PRN_TAB_LP:
        LD      A,20h                   ; ' '
        CALL    PRN_OUT
        INC     B
        LD      A,B
PRN_TAB_MOD:
        SUB     0Ah
        JR      C,PRN_TAB_LP
        JR      NZ,PRN_TAB_MOD
        JP      PRN_SETCOL
; <- aufgerufen von 54A4h, 54ACh
PRN_STATUS:
        LD      B,A
        CALL    PRN_ESC
        LD      A,B
        CALL    PRN_OUT
        CALL    PRN_WAITRDY
        IN      A,(PRN_CTL)
        RRCA
        RRCA
        RET

; ==============================================================================
;  DRUCKER (Ports FEh/FFh): PRN_OUT, PAGE/P, IMAGE/P, COPY/P
; ==============================================================================
;  PRN_ESC – ESC (1Bh) senden. PRN_OUT – Byte A an Port FFh, Strobe über
;  Port FEh; wartet auf den Drucker (PRN_WAIT, Zeitüberschreitung:
;  Fehler 65).
; <- aufgerufen von 53F2h, 543Fh, 5460h, 54BCh, 5562h, 55EAh, 5613h, 5622h
PRN_ESC:
        LD      A,1Bh
; <- aufgerufen von 53A5h, 53BEh, 53FDh, 5402h, 5408h, 5429h, 5451h, 5464h (+11 weitere)
PRN_OUT:
        PUSH    AF
        CALL    PRN_WAITRDY
        POP     AF
        OUT     (PRN_DAT),A
        LD      A,80h
        OUT     (PRN_CTL),A
        LD      A,01h
        CALL    PRN_WAIT
        XOR     A
        OUT     (PRN_CTL),A
        RET
; <- aufgerufen von 5467h, 5472h
PRN_WAITRDY:
        XOR     A
; <- aufgerufen von 547Eh
PRN_WAIT:
        PUSH    BC
        PUSH    DE
        LD      C,A
        LD      B,0Fh
        LD      DE,0000h
PRN_WAIT_LP:
        IN      A,(PRN_CTL)
        AND     0Dh
        CP      C
        JR      Z,PRN_WAIT_OK
        DEC     DE
        LD      A,D
        OR      E
        JR      NZ,PRN_WAIT_LP
        DJNZ    PRN_WAIT_LP
        JP      ERR_65
PRN_WAIT_OK:
        POP     DE
        POP     BC
        RET
;  PRN_CHECK – Druckerstatus abfragen (ESC 03h, ESC 04h); Fehler 67 bzw. 66.
; <- aufgerufen von 53A0h, 555Fh, 5588h
PRN_CHECK:
        LD      A,03h
        CALL    PRN_STATUS
        JP      NC,ERR_67
        LD      A,04h
        CALL    PRN_STATUS
        RET     C
        JP      ERR_66
PRN_COL:
        DEFB    00h                     ; ?? |.|
;  PAGE/P n – Seitenlänge n (1-255) an den Drucker (ESC 12h n).
ST_PAGEP:
        CALL    EVAL_BYTE
        LD      A,E
        OR      A
        JP      Z,ERR_03
        CALL    PRN_ESC
        LD      A,12h
        CALL    PRN_OUT
        LD      A,E
        CALL    PRN_OUT
        JP      NEXTSTMT_HL
IMAGEP_EOL:
        CALL    PRN_CRLF
        JP      NEXTSTMT
;  IMAGE/P ausdruck[;...] – die Texte der Ausdrücke als Bitmuster an den
;  Drucker senden (ESC 18h, Länge, Daten; höchstens 1000 Bytes, sonst
;  Fehler 3). Puffer: Bereich 7080h. Ohne Argument: Zeilenvorschub.
ST_IMAGEP:
        CALL    CHRGET
        LD      (TXTPTR),HL
        JR      Z,IMAGEP_EOL
        PUSH    HL
        CALL    IMAGEP_FREE
        LD      BC,0500h
        CALL    AREA_RESIZE
        POP     HL
IMAGEP_LOOP:
        CALL    CHRGET
        LD      (TXTPTR),HL
        JR      Z,IMAGEP_SEND
        CALL    SKIPCOMMA
        CALL    CHK_CHR_ALT
D54F2:  DEFB    3Bh                     ; Inline-Parameter ';'
D54F3:  DEFW    IMAGEP_ITEM
; <- aufgerufen von 54EFh
IMAGEP_ITEM:
        CALL    EVAL_EXPR
        PUSH    HL
        LD      HL,(7080h)
        PUSH    BC
        LD      BC,03F0h
        ADD     HL,BC
        POP     BC
        LD      A,D
        OR      A
        CALL    Z,VAL2TEXT
        CALL    NZ,STR2TEXT
        LD      A,B
        OR      C
        JR      Z,IMAGEP_NEXT
        PUSH    DE
        LD      HL,(7080h)
        INC     HL
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        DEC     HL
        PUSH    DE
        PUSH    HL
        EX      DE,HL
        ADD     HL,BC
        XOR     A
        EX      DE,HL
        LD      HL,03E8h
        SBC     HL,DE
        JP      C,ERR_03
        POP     HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        INC     HL
        POP     DE
        ADD     HL,DE
        POP     DE
        EX      DE,HL
        LDIR
IMAGEP_NEXT:
        LD      HL,IMAGEP_LOOP
        EX      (SP),HL
        CALL    CHRGET
        RET     Z
        CP      3Bh                     ; ';'
        RET     Z
        CP      2Ch                     ; ','
        RET     Z
        JP      ERR_01
IMAGEP_SEND:
        LD      HL,(7080h)
        INC     HL
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      A,D
        OR      E
        JR      Z,IMAGEP_DONE
        INC     HL
        EX      DE,HL
        CALL    PRN_BITIMG
        CALL    IMAGEP_FREE
IMAGEP_DONE:
        JP      NEXTSTMT
; <- aufgerufen von 54DAh, 5553h
IMAGEP_FREE:
        LD      HL,(7080h)
        JP      AREA_FREE
; <- aufgerufen von 5550h
PRN_BITIMG:
        CALL    PRN_CHECK
        CALL    PRN_ESC
        LD      A,18h
        CALL    PRN_OUT
        LD      A,L
        CALL    PRN_OUT
        LD      A,H
        CALL    PRN_OUT
PRN_BITIMG_LP:
        LD      A,(DE)
        CALL    PRN_OUT
        INC     DE
        DEC     HL
        LD      A,H
        OR      L
        JR      NZ,PRN_BITIMG_LP
        RET
;  COPY/P n – Bildschirm drucken. 1: Textbildschirm (25 Zeilen ab D000h),
;  2-4: Grafik (Ebenen über GR2_PATCH/GR2_PLANE1 gewählt, invertiert je
;  nach Darstellung PPI_A Bit 4). BREAK bricht ab.
ST_COPYP:
        CALL    CHRGET
        JP      Z,ERR_01
        INC     HL
        LD      (TXTPTR),HL
        PUSH    AF
        CALL    PRN_CHECK
        POP     AF
        SUB     34h
        JR      Z,COPYP_4
        INC     A
        JR      Z,COPYP_3
        INC     A
        JR      Z,COPYP_2
        INC     A
        JP      NZ,ERR_01
        LD      HL,0D000h
        LD      C,19h
COPYP_TXTROW:
        CALL    PRN_CRLF
        LD      A,(ADD_WIDTH+1)
        LD      B,A
COPYP_TXTCOL:
        CALL    VRAM_RD
        OR      A
        JR      Z,COPYP_SPACE
        CP      0Dh
        JR      NZ,COPYP_TXTOUT
COPYP_SPACE:
        LD      A,20h                   ; ' '
COPYP_TXTOUT:
        CALL    PRN_OUT
        CALL    BRKCHK
        JR      Z,COPYP_BRK2
        INC     HL
        DJNZ    COPYP_TXTCOL
        DEC     C
        JR      NZ,COPYP_TXTROW
        CALL    PRN_CRLF
        JP      NEXTSTMT
COPYP_3:
        LD      A,0C7h
        JR      COPYP_PLANE
COPYP_4:
        LD      A,87h
        LD      (GR2_PLANE1+1),A
        LD      HL,7947h
        JR      COPYP_GRAPH
COPYP_2:
        LD      A,87h
COPYP_PLANE:
        LD      (GR2_PLANE1+1),A
        LD      HL,0918h                ; Befehlsbytes 18h,09h = JR $+11 (werden in den Code geschrieben)
COPYP_GRAPH:
        LD      (GR2_PATCH),HL
        LD      A,(PPI_A_COPY)
        BIT     4,A
        CALL    Z,COPYP_INV
        CALL    NZ,COPYP_NOINV
        CALL    PRN_ESC
        XOR     A
        CALL    PRN_OUT
        LD      HL,0DEE8h
        LD      DE,0118h
        LD      C,19h
COPYP_GROW:
        CALL    BRKCHK
        JR      Z,COPYP_BRK
        LD      B,28h
        CALL    PRN_GRAPH8
        ADD     HL,DE
COPYP_GCOL:
        CALL    COPYP_CELL
        INC     HL
        DJNZ    COPYP_GCOL
        DEC     C
        JR      NZ,COPYP_GROW
        CALL    PRN_LFRESTORE
        JP      NEXTSTMT
; <- aufgerufen von 560Dh, 561Ch
PRN_LFRESTORE:
        CALL    PRN_ESC
        LD      A,(PRN_LFMODE)
        JP      PRN_OUT
COPYP_BRK:
        CALL    PRN_LFRESTORE
COPYP_BRK2:
        JP      BREAK
; <- aufgerufen von 5600h
PRN_GRAPH8:
        CALL    PRN_ESC
        LD      A,18h
        CALL    PRN_OUT
        LD      A,40h                   ; '@'
        CALL    PRN_OUT
        LD      A,01h
        JP      PRN_OUT
; <- aufgerufen von 5604h
COPYP_CELL:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      DE,COPYP_BUF
        LD      B,08h
COPYP_CELL_LP:
        PUSH    BC
        LD      BC,0028h
        CALL    GRAM_READ2
        LD      (DE),A
        INC     DE
        ADD     HL,BC
        POP     BC
        DJNZ    COPYP_CELL_LP
        LD      C,08h
COPYP_ROT:
        LD      HL,COPYP_BUFEND
        LD      B,08h
        XOR     A
COPYP_ROT_LP:
        RRC     (HL)
        RLA
        DEC     HL
        DJNZ    COPYP_ROT_LP
        CALL    PRN_OUT
        DEC     C
        JR      NZ,COPYP_ROT
        POP     HL
        POP     DE
        POP     BC
        RET
; <- aufgerufen von 55E7h
COPYP_NOINV:
        XOR     A
        DEFB    01h                     ; Trick: Opcode 01h verschluckt den folgenden Befehl
; <- aufgerufen von 55E4h
COPYP_INV:
        LD      A,2Fh                   ; '/'
        LD      (GR2_INV1),A
        LD      (GR2_INV2),A
        RET
;  GRAM_READ2 – Byte (HL) aus beiden Grafikebenen lesen und verknüpfen.
;  In GR2_PATCH wird je nach COPY/P-Art "LD B,A / LD A,C" (7947h) oder
;  "JR $+11" (0918h) eingesetzt.
; <- aufgerufen von 5640h
GRAM_READ2:
        DI
        EXX
        IN      A,(PIO_AD)
        SET     7,A
        OUT     (PIO_AD),A
        EX      AF,AF'
        LD      A,(GRPH_PORT)
        LD      C,A
GR2_PLANE1:
        RES     0,A
        OUT     (GRPH),A
        EXX
        LD      A,(HL)
GR2_INV1:
        CPL
        EXX
GR2_PATCH:
        LD      B,A
        LD      A,C
        SET     0,A
        OUT     (GRPH),A
        EXX
        LD      A,(HL)
GR2_INV2:
        CPL
        EXX
        OR      B
        EX      AF,AF'
        RES     7,A
        OUT     (PIO_AD),A
        EXX
        EX      AF,AF'
        EI
        RET
COPYP_BUF:
        DEFB    00h,00h,00h,00h,00h,00h,00h  ; ?? |.......|
COPYP_BUFEND:
        DEFB    00h                     ; ?? |.|
;  GR_POINT – POINT(x,y): Pixel in beiden Grafikebenen testen, A = 0-3
;  (Bit 1 Ebene 1, Bit 0 Ebene 0; FFh außerhalb des Bildes).
; <- aufgerufen von 2B1Eh
GR_POINT:
        LD      A,(GRPH_PORT)
        PUSH    AF
        SET     0,A
        OUT     (GRPH),A
        CALL    GR_TESTPIX
        RLCA
        LD      B,A
        POP     AF
        PUSH    AF
        RES     0,A
        OUT     (GRPH),A
        CALL    GR_TESTPIX
        OR      B
        EX      AF,AF'
        POP     AF
        OUT     (GRPH),A
        EX      AF,AF'
        RET
; <- aufgerufen von 56A5h, 56B0h
GR_TESTPIX:
        LD      A,46h                   ; 'F'
        CALL    GR_PIXOP
        PUSH    AF
        INC     A
        JR      Z,GR_PIX_OFF2
        POP     AF
        LD      A,00h
        RET     Z
        INC     A
        RET
GR_RESCUR:
        LD      DE,(GR_X)
        LD      HL,(GR_Y)
GR_RESPIX:
        PUSH    AF
        LD      A,86h
        JR      GR_PIXOP2
;  Pixel setzen/löschen: GR_SETPIX (DE = x, HL = y) bzw. GR_RESPIX;
;  GR_SETCUR/GR_RESCUR an der Grafikposition GR_X/GR_Y. GR_TESTPIX testet.
GR_SETCUR:
        LD      DE,(GR_X)
        LD      HL,(GR_Y)
; <- aufgerufen von 582Bh
GR_SETPIX:
        PUSH    AF
        LD      A,0C6h
GR_PIXOP2:
        CALL    GR_PIXOP
        POP     AF
        RET
;  GR_PIXOP – Pixelbefehl auf (DE = x 0-319, HL = y 0-199) anwenden; A ist
;  das zweite Byte von SET/RES/BIT 0,(HL) (C6h/86h/46h). Die Bitnummer wird
;  dazugerechnet und in GR_PIX_DO eingesetzt. Grafik-VRAM wird dafür über
;  PIO_AD Bit 7 eingeblendet. Außerhalb des Bildes: nichts, A = FFh.
; <- aufgerufen von 56BCh, 56DFh
GR_PIXOP:
        LD      (GR_PIX_OPC+1),A
        LD      A,D
        OR      A
        JR      Z,GR_PIX_Y
        DEC     A
        JR      NZ,GR_PIX_OFF
        LD      A,E
        CP      40h                     ; '@'
        JR      NC,GR_PIX_OFF
GR_PIX_Y:
        LD      A,H
        OR      A
        JR      NZ,GR_PIX_OFF
        LD      A,L
        CP      0C8h
        JR      NC,GR_PIX_OFF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        CALL    GR_ADDR
GR_PIX_OPC:
        OR      0FFh
        LD      (GR_PIX_DO+1),A
        DI
        IN      A,(PIO_AD)
        SET     7,A
        OUT     (PIO_AD),A
GR_PIX_DO:
        SET     7,A
        RES     7,A
        OUT     (PIO_AD),A
        EI
        POP     HL
        POP     DE
        POP     BC
        RET
GR_PIX_OFF2:
        POP     AF
GR_PIX_OFF:
        LD      A,0FFh
        RET
;  GR_ADDR – Adresse im Grafik-VRAM: HL = E000h + y*40 + x/8, B = Bit*8.
; <- aufgerufen von 56FFh
GR_ADDR:
        LD      A,E
        RLA
        RLA
        RLA
        AND     38h
        LD      B,A
; <- aufgerufen von 58C0h
GR_ADDR_B:
        LD      A,D
        RRCA
        LD      A,E
        RRA
        RRA
        RRA
        AND     3Fh
        LD      C,A
        LD      A,B
        LD      B,0E0h
        LD      D,H
        LD      E,L
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,DE
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,BC
        RET
;  GR_LINE – Linie von (GRL_X1,GRL_Y1) nach (DE,HL) mit dem Pixelbefehl
;  aus GRL_PIXCALL (Bresenham). Koordinaten werden intern um 4000h
;  verschoben (GR_BIAS), damit Differenzen positiv bleiben; Schrittrichtung
;  über selbst eingesetzte INC/DEC (GRL_INCX/GRL_INCY).
; <- aufgerufen von 586Ah
GR_LINE:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        CALL    GR_BIAS
        PUSH    HL
        LD      B,40h
        LD      A,(GRL_X1H)
        ADD     A,B
        LD      (GRL_X1H),A
        LD      A,(GRL_Y1H)
        ADD     A,B
        LD      (GRL_Y1H),A
        POP     HL
        PUSH    DE
        EX      DE,HL
        LD      HL,(GRL_Y1)
        CALL    GR_ABSDIFF
        LD      (GRL_SY),A
        LD      (GRL_DY),HL
        POP     DE
        PUSH    HL
        LD      HL,(GRL_X1)
        CALL    GR_ABSDIFF
        LD      (GRL_SX),A
        LD      (GRL_DX),HL
        XOR     A
        POP     BC
        EX      AF,AF'
        XOR     A
        SBC     HL,BC
        SET     7,A
        JR      NC,GRL_DIR
        XOR     A
        LD      HL,GRL_X1
        LD      DE,GRL_TMP
        CALL    COPY5
        LD      HL,GRL_Y1
        LD      DE,GRL_X1
        CALL    COPY5
        LD      HL,GRL_TMP
        LD      DE,GRL_Y1
        CALL    COPY5
GRL_DIR:
        EX      AF,AF'
        LD      A,(GRL_SY)
        AND     A
        LD      A,23h                   ; '#'
        JR      Z,GRL_STEPY
        LD      A,2Bh                   ; '+'
GRL_STEPY:
        LD      (GRL_INCY),A
        LD      A,(GRL_SX)
        AND     A
        LD      A,13h
        JR      Z,GRL_STEPX
        LD      A,1Bh
GRL_STEPX:
        LD      (GRL_INCX),A
        EXX
        LD      HL,(GRL_DX)
        PUSH    HL
        POP     DE
        JR      Z,GRL_ERR0
        DEC     HL
        JR      GRL_INIT
GRL_ERR0:
        LD      HL,0000h
GRL_INIT:
        LD      BC,(GRL_DY)
        EXX
        LD      HL,(GRL_Y1)
        LD      DE,(GRL_X1)
        LD      BC,(GRL_DX)
GRL_LOOP:
        EX      AF,AF'
        AND     A
        JR      NZ,GRL_PLOTXY
        EX      DE,HL
        CALL    GRL_PLOT
        EX      DE,HL
        JR      GRL_COUNT
GRL_PLOTXY:
        CALL    GRL_PLOT
GRL_COUNT:
        DEC     BC
        LD      A,B
        INC     A
        JR      Z,GRL_DONE
GRL_INCX:
        NOP
        EXX
        ADD     HL,BC
        XOR     A
        SBC     HL,DE
        JP      M,GRL_NOSTEP
        EXX
GRL_INCY:
        NOP
        JR      GRL_LOOP
GRL_NOSTEP:
        ADD     HL,DE
        EXX
        JR      GRL_LOOP
GRL_DONE:
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET
; <- aufgerufen von 5780h, 5789h, 5792h
COPY5:  LD      BC,0005h
        LDIR
        RET
GRL_X1: DEFB    00h                     ; ?? |.|
GRL_X1H:
        DEFB    00h                     ; ?? |.|
GRL_DX: DEFB    00h,00h                 ; ?? |..|
GRL_SX: DEFB    00h                     ; ?? |.|
GRL_Y1: DEFB    00h                     ; ?? |.|
GRL_Y1H:
        DEFB    00h                     ; ?? |.|
GRL_DY: DEFB    00h,00h                 ; ?? |..|
GRL_SY: DEFB    00h                     ; ?? |.|
GRL_TMP:
        DEFB    00h,00h,00h,00h,00h     ; ?? |.....|
; <- aufgerufen von 5758h, 5766h
GR_ABSDIFF:
        LD      A,D
        CPL
        LD      B,A
        LD      A,E
        CPL
        LD      C,A
        ADD     HL,BC
        JR      C,GR_ABS_NEG
        LD      A,L
        CPL
        LD      L,A
        LD      A,H
        CPL
        LD      H,A
        XOR     A
        RET
GR_ABS_NEG:
        INC     HL
        LD      A,0FFh
        RET
; <- aufgerufen von 57D3h, 57D9h
GRL_PLOT:
        EX      AF,AF'
        PUSH    AF
        LD      A,H
        SUB     40h
        LD      H,A
        LD      A,D
        SUB     40h
        LD      D,A
GRL_PIXCALL:
        CALL    GR_SETPIX
        JR      GR_BIAS2
; <- aufgerufen von 573Eh
GR_BIAS:
        PUSH    AF
GR_BIAS2:
        LD      A,H
        ADD     A,40h
        LD      H,A
        LD      A,D
        ADD     A,40h
        LD      D,A
        POP     AF
        RET
;  LINE_SET / LINE_RESET – Streckenzug zeichnen bzw. löschen.
;  Eingang: DE = Punktliste (je Punkt x, y als 16-Bit-Werte, Low-Byte
;  zuerst), A = Anzahl der Strecken (Punkte - 1). Punkte außerhalb von
;  320x200 werden nicht gezeichnet. Danach steht die Grafikposition
;  GR_X/GR_Y auf dem letzten Punkt. Ändert alle Register.
LINE_SET:
        LD      HL,GR_SETPIX
        JR      LINE_GO
LINE_RESET:
        LD      HL,GR_RESPIX
LINE_GO:
        LD      (GRL_PIXCALL+1),HL
        LD      B,A
LINE_SEG:
        LD      A,(DE)
        LD      (GRL_X1),A
        INC     DE
        LD      A,(DE)
        LD      (GRL_X1H),A
        INC     DE
        LD      A,(DE)
        LD      (GRL_Y1),A
        INC     DE
        LD      A,(DE)
        LD      (GRL_Y1H),A
        INC     DE
        PUSH    DE
        EX      DE,HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        PUSH    HL
        POP     IX
        LD      L,(IX+0)
        LD      H,(IX+1)
        CALL    GR_LINE
        DJNZ    LINE_NEXT
        POP     BC
        LD      (GR_Y),HL
        LD      (GR_X),DE
        RET
LINE_NEXT:
        POP     DE
        JR      LINE_SEG
;  GR_FILL / GR_CLEAR – die gewählten Grafikebenen (E000h-FFFFh) mit FFh
;  füllen bzw. löschen (GRAPH F / GRAPH C).
; <- aufgerufen von 5B8Eh
GR_FILL:
        LD      A,0FFh
        LD      (GR_FILLVAL+1),A
        JR      GR_FILLDO
; <- aufgerufen von 5B83h
GR_CLEAR:
        XOR     A
        LD      (GR_FILLVAL+1),A
GR_FILLDO:
        LD      HL,0E000h
        DI
        IN      A,(PIO_AD)
        SET     7,A
        OUT     (PIO_AD),A
        LD      DE,0E001h
GR_FILLVAL:
        LD      (HL),00h
        LD      BC,1FFFh
        LDIR
        IN      A,(PIO_AD)
        RES     7,A
        OUT     (PIO_AD),A
        EI
        RET
;  PAT_DRAW – Bitmuster (Zeichenkette, je Zeichen 8 Pixel) ab GR_X/GR_Y
;  zeichnen, n Zeilen pro Spalte, dann weiter nach rechts. Richtung nach
;  oben oder unten über PAT_STRIDE/PAT_STEP (von PATTERN eingesetzt).
PAT_DRAW:
        DEC     DE
        OR      A
        RET     Z
        EXX
        LD      C,A
        EXX
        LD      A,(DE)
        OR      A
        RET     Z
        EXX
        LD      D,A
        EXX
        INC     DE
        PUSH    DE
        LD      HL,(GR_Y)
        LD      DE,(GR_X)
        PUSH    DE
        PUSH    DE
        POP     IY
        LD      BC,0008h
        ADD     IY,BC
        CALL    GR_ADDR_B
        POP     DE
        PUSH    HL
        POP     IX
        LD      A,07h
        AND     E
        POP     DE
        EXX
        LD      B,A
        EXX
        LD      B,A
        LD      C,0FFh
PAT_MASK:
        SLA     C
        DJNZ    PAT_MASK
        AND     A
        LD      A,00h
        JR      Z,PAT_SETMODE
        LD      A,10h
PAT_SETMODE:
        LD      (PAT_JR+1),A
PAT_ROW:
        EXX
        PUSH    AF
        LD      A,01h
        LD      (PAT_COUNT),A
        POP     AF
        LD      E,C
        EXX
PAT_JR: JR      PAT_SHIFTED
        XOR     A
        LD      (GR_WR_MASK+1),A
        CALL    PAT_REVBITS
        LD      (GR_WR_BITS+1),A
        CALL    GR_WRBYTE
        INC     HL
        JR      PAT_ROWDONE
PAT_SHIFTED:
        EXX
        LD      A,B
        EXX
        LD      B,A
        CALL    PAT_REVBITS
PAT_ROT:
        RLCA
        DJNZ    PAT_ROT
        LD      B,A
        AND     C
        LD      (GR_WR_BITS+1),A
        LD      A,C
        CPL
        LD      (GR_WR_MASK+1),A
        CALL    GR_WRBYTE
        INC     HL
        LD      A,C
        LD      (GR_WR_MASK+1),A
        CPL
        AND     B
        LD      (GR_WR_BITS+1),A
        CALL    GR_WRBYTE
PAT_ROWDONE:
        EXX
        DEC     D
        JR      Z,PAT_END
        EXX
        PUSH    BC
PAT_STRIDE:
        LD      BC,0029h
        XOR     A
PAT_STEP:
        SBC     HL,BC
        POP     BC
        INC     DE
        EXX
        LD      A,(PAT_COUNT)
        INC     A
        LD      (PAT_COUNT),A
        DEC     E
        EXX
        JR      NZ,PAT_JR
        INC     IX
        PUSH    IX
        POP     HL
        PUSH    BC
        LD      BC,0008h
        ADD     IY,BC
        POP     BC
        JR      PAT_ROW
PAT_END:
        LD      A,(PAT_COUNT)
        CP      C
        JR      Z,PAT_SETX
        LD      BC,0008h
        PUSH    IY
        POP     HL
        OR      A
        SBC     HL,BC
        LD      (GR_X),HL
        LD      C,A
        XOR     A
        LD      B,A
        LD      HL,(GR_Y)
PAT_STEP2:
        SBC     HL,BC
        LD      (GR_Y),HL
        RET
PAT_SETX:
        LD      (GR_X),IY
        RET
; <- aufgerufen von 58EFh, 58FFh
PAT_REVBITS:
        LD      A,(DE)
        EXX
        LD      L,08h
        LD      H,A
PAT_REV_LP:
        SRL     H
        RLA
        DEC     L
        JR      NZ,PAT_REV_LP
        EXX
        RET
;  GR_WRBYTE – Byte (HL) im Grafik-VRAM mit Maske GR_WR_MASK und Bits
;  GR_WR_BITS ändern (Adressen über FFFFh werden übergangen).
; <- aufgerufen von 58F5h, 590Fh, 591Ch
GR_WRBYTE:
        PUSH    HL
        PUSH    BC
        LD      BC,2000h
        ADD     HL,BC
        POP     BC
        POP     HL
        RET     NC
        DI
        IN      A,(PIO_AD)
        SET     7,A
        OUT     (PIO_AD),A
        LD      A,(HL)
GR_WR_MASK:
        AND     0FFh
GR_WR_BITS:
        OR      00h
        LD      (HL),A
        IN      A,(PIO_AD)
        RES     7,A
        OUT     (PIO_AD),A
        EI
        RET
;  GR_X/GR_Y: Grafikposition (POSITION, letzter Punkt von SET/LINE).
GR_X:   DEFB    00h,00h                 ; ?? |..|
GR_Y:   DEFB    00h,00h                 ; ?? |..|
PAT_COUNT:
        DEFB    00h                     ; ?? |.|

; ==============================================================================
;  GRAFIK: SET, RESET, LINE, BLINE, CONSOLE, PATTERN, POSITION, GRAPH
; ==============================================================================
ST_RESET:
        XOR     A
        DEFB    01h                     ; Trick: Opcode 01h verschluckt den folgenden Befehl
;  SET x,y / RESET x,y – Pixel setzen bzw. löschen und Grafikposition
;  dorthin setzen. Außerhalb des Bildes passiert nichts.
ST_SET: LD      A,01h
        PUSH    AF
        CALL    EVAL_INT
        LD      (GR_X),DE
        CALL    SYNCHK
D59A9:  DEFB    2Ch                     ; Inline-Parameter ','
        CALL    EVAL_INT
        LD      (GR_Y),DE
        POP     AF
        PUSH    HL
        LD      HL,GR_DONE
        PUSH    HL
        OR      A
        JP      Z,GR_RESCUR
        JP      GR_SETCUR
;  CHK_X / CHK_Y – Fehler 3, wenn DE > 319 bzw. > 199.
; <- aufgerufen von 5B00h
CHK_X:  PUSH    HL
        LD      HL,013Fh
CHK_LIMIT:
        XOR     A
        SBC     HL,DE
        JP      C,ERR_03
        POP     HL
        RET
; <- aufgerufen von 5B0Ah
CHK_Y:  PUSH    HL
        LD      HL,00C7h
        JR      CHK_LIMIT
LINE_PTR:
        DEFB    00h,00h                 ; ?? |..|
LINE_CNT:
        DEFB    00h                     ; ?? |.|
ST_BLINE:
        XOR     A
        DEFB    01h                     ; Trick: Opcode 01h verschluckt den folgenden Befehl
;  LINE x1,y1,x2,y2[,x3,y3...] / BLINE ... – Streckenzug zeichnen bzw.
;  löschen. Die Punkte werden ab INBUF gesammelt (LINE_PUTW), mindestens
;  zwei, sonst Fehler 1; dann LINE_SET bzw. LINE_RESET.
ST_LINE:
        LD      A,01h
        LD      (LINE_MODE+1),A
        LD      BC,6B0Dh
        LD      (LINE_PTR),BC
        PUSH    BC
        LD      A,00h
LINE_ARGS:
        LD      (LINE_CNT),A
        CALL    CHRGET
        JR      Z,LINE_DO
        CALL    SKIPCOMMA
        CALL    EVAL_INT
        CALL    LINE_PUTW
        CALL    SYNCHK
D59F8:  DEFB    2Ch                     ; Inline-Parameter ','
        CALL    EVAL_INT
        CALL    LINE_PUTW
        LD      A,(LINE_CNT)
        INC     A
        JR      LINE_ARGS
LINE_DO:
        POP     BC
        PUSH    HL
        LD      HL,GR_DONE
        PUSH    HL
        LD      A,(LINE_CNT)
        CP      02h
        JP      C,ERR_01
        DEC     A
        LD      E,C
        LD      D,B
        LD      C,A
LINE_MODE:
        LD      A,0FFh
        OR      A
        LD      A,C
        JP      Z,LINE_RESET
        JP      LINE_SET
GR_DONE:
        POP     HL
        JP      NEXTSTMT_HL
; <- aufgerufen von 59F2h, 59FCh
LINE_PUTW:
        LD      IY,(LINE_PTR)
        LD      (IY+0),E
        INC     IY
        LD      (IY+0),D
        INC     IY
        LD      (LINE_PTR),IY
        RET
CONS_NEXT:
        POP     HL
;  CONSOLE [S a,b] [C 40|80] [R|N] – Rollbereich Zeile a bis b (1-24),
;  40/80 Zeichen, inverse (R) bzw. normale (N) Darstellung (PPI_A Bit 4).
;  Mehrere Angaben nacheinander möglich.
ST_CONSOLE:
        CALL    CHRGET
        JP      Z,NEXTSTMT_HL
        CALL    SKIPCOMMA
        CALL    CHK_CHR_ALT
D5A45:  DEFB    53h                     ; Inline-Parameter 'S'
D5A46:  DEFW    CONS_COLS
        CALL    EVAL_BYTE
        INC     E
        LD      A,E
        PUSH    AF
        CALL    CHK_ROW
        CALL    SKIPCOMMA
        CALL    EVAL_BYTE
        LD      A,E
        CALL    CHK_ROW
        POP     AF
        CP      E
        JR      NC,CONS_ERR
        LD      (000Bh),A
        LD      A,E
        LD      (000Ch),A
        PUSH    HL
        LD      HL,CONS_NEXT
        PUSH    HL
        JP      SCROLL_INIT
;  CHK_ROW – Fehler 3, wenn A nicht 1-24 ist.
; <- aufgerufen von 5A4Eh, 5A58h, 5ADCh
CHK_ROW:
        OR      A
        JR      Z,CONS_ERR
        CP      19h
        RET     C
CONS_ERR:
        JP      ERR_03
; <- aufgerufen von 5A42h
CONS_COLS:
        CALL    CHK_CHR_ALT
D5A7A:  DEFB    43h                     ; Inline-Parameter 'C'
D5A7B:  DEFW    CONS_REV
        CALL    EVAL_BYTE
        LD      A,E
        PUSH    HL
        LD      HL,CONS_NEXT
        PUSH    HL
        CP      28h                     ; '('
        JP      Z,SET40COL
        CP      50h                     ; 'P'
        JP      Z,SET80COL
        JR      CONS_ERR
; <- aufgerufen von 5A77h
CONS_REV:
        CALL    CHK_CHR_ALT
D5A95:  DEFB    52h                     ; Inline-Parameter 'R'
D5A96:  DEFW    CONS_NORM
        LD      A,(PPI_A_COPY)
        RES     4,A
CONS_SETPPI:
        LD      (PPI_A_COPY),A
        OUT     (PPI_A),A
        JP      ST_CONSOLE
; <- aufgerufen von 5A92h
CONS_NORM:
        CALL    SYNCHK
D5AA8:  DEFB    4Eh                     ; Inline-Parameter 'N'
        LD      A,(PPI_A_COPY)
        SET     4,A
        JR      CONS_SETPPI
PAT_NEXT:
        POP     HL                      ; Rücksprung nach PAT_DRAW: Textzeiger, nächstes Muster
;  PATTERN [-]n, muster$ [, ...] – Bitmuster an der Grafikposition zeichnen
;  (PAT_DRAW), n = 1-24 Zeilen; mit "-" in der Gegenrichtung (Schrittweite
;  und ADD/SBC werden in PAT_STRIDE/PAT_STEP eingesetzt).
ST_PATTERN:
        CALL    CHRGET
        JP      Z,NEXTSTMT_HL
        CALL    SKIPCOMMA
        CALL    CHK_CHR_ALT
D5ABD:  DEFB    2Dh                     ; Inline-Parameter '-'
D5ABE:  DEFW    PAT_UP
        PUSH    HL
        LD      HL,0009h                ; Befehlsbytes 09h,00h = ADD HL,BC / NOP
        LD      A,27h                   ; Schrittweite 39 statt 41 (PAT_STRIDE)
        JR      PAT_PATCH
; <- aufgerufen von 5ABAh
PAT_UP: PUSH    HL
        LD      HL,42EDh                ; Befehlsbytes EDh,42h = SBC HL,BC (Original bei PAT_STEP/PAT_STEP2)
        LD      A,29h                   ; ')'
PAT_PATCH:
        LD      (PAT_STRIDE+1),A
        LD      (PAT_STEP),HL
        LD      (PAT_STEP2),HL
        POP     HL
        CALL    EVAL_BYTE
        LD      A,E
        CALL    CHK_ROW
        PUSH    AF
        CALL    SKIPCOMMA
        CALL    EVAL
        CALL    GETSTR
        POP     AF
        PUSH    HL
        LD      HL,PAT_NEXT
        PUSH    HL
        LD      HL,INBUF
        PUSH    HL
        INC     BC
        DEC     HL
        DEC     DE
        EX      DE,HL
        LDIR
        POP     DE
        JP      PAT_DRAW
;  POSITION x,y – Grafikposition setzen (x 0-319, y 0-199, sonst Fehler 3).
ST_POSITION:
        CALL    EVAL_INT
        CALL    CHK_X
        PUSH    DE
        CALL    SKIPCOMMA
        CALL    EVAL_INT
        CALL    CHK_Y
        LD      (GR_Y),DE
        POP     DE
        LD      (GR_X),DE
        JP      NEXTSTMT_HL
;  GRPH_PORT: an Port F4h ausgegebener Wert = GRPH_IN (Leseebene, GRAPH I)
;  + GRPH_OUT (Schreibebenen, GRAPH O).
GRPH_PORT:
        DEFB    00h                     ; ?? |.|
GRPH_IN:
        DEFB    00h                     ; ?? |.|
GRPH_OUT:
        DEFB    00h                     ; ?? |.|
;  GRAPH [I n] [O ab] [C] [F] – Leseebene n (1-2), Schreibebenen (Ziffern
;  0-2), gewählte Ebenen löschen (C) oder füllen (F); setzt Port F4h.
ST_GRAPH:
        CALL    SKIPCOMMA
        CP      0Dh
        JR      Z,GRAPH_SET
        CALL    CHK_CHR_ALT
D5B26:  DEFB    49h                     ; Inline-Parameter 'I'
D5B27:  DEFW    GRAPH_OUTARG
        CALL    ISDIGIT
GRAPH_ERR:
        JP      NC,ERR_03
        INC     HL
        AND     0Fh
        DEC     A
        CP      02h
        JR      NC,GRAPH_ERR
        LD      (GRPH_IN),A
        JR      GRAPH_SET
; <- aufgerufen von 5B23h
GRAPH_OUTARG:
        CALL    CHK_CHR_ALT
D5B3F:  DEFB    4Fh                     ; Inline-Parameter 'O'
D5B40:  DEFW    GRAPH_C
        CALL    ISDIGIT
        JR      C,GRAPH_O1
        LD      A,00h
        DEC     HL
GRAPH_O1:
        INC     HL
        AND     0Fh
        CP      03h
        JR      NC,GRAPH_ERR
        LD      B,A
        CALL    ISDIGIT
        JR      C,GRAPH_O2
        LD      A,00h
        DEC     HL
GRAPH_O2:
        INC     HL
        AND     0Fh
        CP      03h
        JR      NC,GRAPH_ERR
        OR      B
        SLA     A
        LD      (GRPH_OUT),A
GRAPH_SET:
        LD      A,(GRPH_IN)
        LD      B,A
        LD      A,(GRPH_OUT)
        OR      B
        LD      (GRPH_PORT),A
        OUT     (GRPH),A
        CALL    CHRGET
        JR      NZ,ST_GRAPH
        JP      NEXTSTMT_HL
; <- aufgerufen von 5B3Ch
GRAPH_C:
        CALL    CHK_CHR_ALT
D5B7F:  DEFB    43h                     ; Inline-Parameter 'C'
D5B80:  DEFW    GRAPH_F
        PUSH    HL
        CALL    GR_CLEAR
GRAPH_CF_RET:
        POP     HL
        JR      GRAPH_SET
; <- aufgerufen von 5B7Ch
GRAPH_F:
        CALL    SYNCHK
D5B8C:  DEFB    46h                     ; Inline-Parameter 'F'
        PUSH    HL
        CALL    GR_FILL
        JR      GRAPH_CF_RET
;  CSRV / CSRH – Cursorzeile bzw. -spalte des Textbildschirms.
;  POSV / POSH – Grafikposition y bzw. x.
FN_CSR: CALL    CHK_CHR_ALT
D5B96:  DEFB    56h                     ; Inline-Parameter 'V'
D5B97:  DEFW    CSR_H
        LD      A,(CSR_Y)
CSR_RET:
        LD      D,00h
        LD      E,A
POS_RET:
        PUSH    HL
        JP      RET_DE
; <- aufgerufen von 5B93h
CSR_H:  CALL    SYNCHK
D5BA6:  DEFB    48h                     ; Inline-Parameter 'H'
        LD      A,(CSR_XY)
        JR      CSR_RET
FN_POS: CALL    CHK_CHR_ALT
D5BAF:  DEFB    56h                     ; Inline-Parameter 'V'
D5BB0:  DEFW    POS_H
        LD      DE,(GR_Y)
        JR      POS_RET
; <- aufgerufen von 5BACh
POS_H:  CALL    SYNCHK
D5BBB:  DEFB    48h                     ; Inline-Parameter 'H'
        LD      DE,(GR_X)
        JR      POS_RET
;  CHARACTER$(x,y) – Zeichen an Textposition x (kleiner als die
;  Zeilenbreite), y (0-24) als String; sonst Fehler 3.
FN_CHARACTER:
        CALL    EVAL_INT
        LD      A,(ADD_WIDTH+1)
        LD      (CHARS_MAXX+1),A
        LD      (CHARS_WIDTH+1),A
        LD      A,E
CHARS_MAXX:
        CP      0FFh
CHARS_ERR:
        JP      NC,ERR_03
        PUSH    AF
        CALL    SYNCHK
D5BD8:  DEFB    2Ch                     ; Inline-Parameter ','
        CALL    EVAL_BYTE
        CALL    SYNCHK
D5BDF:  DEFB    29h                     ; Inline-Parameter ')'
        LD      A,E
        CP      19h
        JR      NC,CHARS_ERR
        POP     AF
        LD      C,A
        LD      B,E
        INC     B
        PUSH    HL
        LD      HL,0D000h
        LD      D,00h
CHARS_WIDTH:
        LD      E,0FFh
        XOR     A
        SBC     HL,DE
CHARS_ROWLP:
        ADD     HL,DE
        DJNZ    CHARS_ROWLP
        ADD     HL,BC
        CALL    VRAM_RD
        POP     HL
        LD      BC,0001h
        JP      STR_FILL
;  FD_READ / FD_WRITE – Einsprünge des Floppy-Treibers für DISK_RW.
;  FD_READ / FD_WRITE – Sektoren lesen/schreiben, Einsprung aus DISK_RW
;  mit IX = DISK_PAR:
;    +0 Laufwerk (0-3)       +1/+2 logischer Startsektor   +3/+4 Bytes
;    +5/+6 Speicheradresse   +7/+8 Spur/Sektor in Arbeit   +9/+10 Startspur/-sektor
;  16 Sektoren zu 256 Bytes je Spur; logische Spur / 2 = Zylinder, Bit 0 =
;  Seite. Der MB8876 hat einen invertierten Datenbus: alle Werte werden
;  vor OUT und nach IN mit CPL umgedreht. Fehler gehen über (IY-1)/JP (IY)
;  an den mit SET_IOERR gesetzten Behandler.
FD_READ:
        JP      FDR_START
FD_WRITE:
        JP      FDW_START

; ==============================================================================
;  FLOPPY-TREIBER (MB8876, Ports D8h-DDh)
; ==============================================================================
;  FD_MOTOR_OFF – Laufwerke abwählen, Motor aus, "zurückgesetzt"-Flags
;  löschen (FD_RESET).
; <- aufgerufen von 128Eh, 4306h, 44DBh, 4884h, 4A5Bh, 532Ah, 534Ch
FD_MOTOR_OFF:
        JP      FD_RESET
;  FD_SELECT – Motor einschalten (beim ersten Mal mit Anlaufzeit,
;  FD_MOTORON), Laufwerk (IX+0) wählen (Port DCh: Bit 7 Motor, Bit 2
;  Auswahl, Bit 0-1 Laufwerk), auf "bereit" warten (sonst Fehler 50);
;  beim ersten Zugriff auf das Laufwerk RESTORE (Spur 0).
; <- aufgerufen von 5D7Ah, 5E00h
FD_SELECT:
        LD      A,(FD_MOTOR)
        RRCA
        CALL    NC,FD_MOTORON
        LD      A,(IX+0)
        OR      84h
        OUT     (FDD_SEL),A
        XOR     A
        LD      (FD_LASTCMD),A
        CALL    FD_DLY_L
        LD      HL,0000h
FD_WAITRDY:
        DEC     HL
        LD      A,H
        OR      L
        JR      Z,FD_NOTRDY
        IN      A,(FDC_CMD)
        CPL
        RLCA
        JR      C,FD_WAITRDY
        LD      C,(IX+0)
        LD      HL,FD_RESTORED
        LD      B,00h
        ADD     HL,BC
        BIT     0,(HL)
        JR      NZ,FD_SEL_RET
        CALL    FD_RESTORE
        SET     0,(HL)
FD_SEL_RET:
        RET
FD_NOTRDY:
        LD      A,32h                   ; '2'
        JP      FD_ERRA
; <- aufgerufen von 5C0Fh
FD_MOTORON:
        LD      A,80h
        OUT     (FDD_SEL),A
        LD      B,10h
FD_MOTOR_DLY:
        CALL    FD_DLY_L
        DJNZ    FD_MOTOR_DLY
        LD      A,01h
        LD      (FD_MOTOR),A
        RET
;  FD_SEEK – SEEK (1Bh) zur Spur im Datenregister. NZ bei Fehlerbits.
; <- aufgerufen von 5CC3h, 5D16h, 5E18h
FD_SEEK:
        LD      A,1Bh
        CALL    FD_CMDWAIT
        AND     99h
        RET
; <- aufgerufen von 5EACh
FD_RESET:
        CALL    FD_DLY_M
        XOR     A
        OUT     (FDD_SEL),A
        LD      (FD_RESTORED),A
        LD      (FD_RESTORED1),A
        LD      (FD_RESTORED2),A
        LD      (FD_RESTORED3),A
        LD      (FD_MOTOR),A
        RET
;  FD_RESTORE – RESTORE (0Bh), Kopf auf Spur 0; Fehler: FD_ERROR.
; <- aufgerufen von 5C3Bh, 5DC5h, 5E73h
FD_RESTORE:
        LD      A,0Bh
        CALL    FD_CMDWAIT
        AND     85h
        XOR     04h
        RET     Z
        JP      FD_ERROR
;  FD_CMDWAIT – Kommando A ausgeben (FD_LASTCMD), auf "nicht beschäftigt"
;  warten, Status nach FD_STATUS.
; <- aufgerufen von 5C59h, 5C77h
FD_CMDWAIT:
        LD      (FD_LASTCMD),A
        CPL
        OUT     (FDC_CMD),A
        LD      A,38h                   ; '8'
        LD      (FD_WB_JR),A
        CALL    FD_WAITBUSY
        CALL    FD_DLY_L
        IN      A,(FDC_CMD)
        CPL
        LD      (FD_STATUS),A
        RET
;  FD_WAITBUSY – warten, bis Bit 0 des Status wechselt; die Richtung (JR C
;  bzw. JR NC) wird in FD_WB_JR eingesetzt. Zeitüberschreitung: Fehler 41.
; <- aufgerufen von 5C8Dh, 5DE6h, 5DF4h
FD_WAITBUSY:
        PUSH    DE
        PUSH    HL
        CALL    FD_DLY_S
        LD      E,07h
FD_WB_OUTER:
        LD      HL,0000h
FD_WB_LP:
        DEC     HL
        LD      A,H
        OR      L
        JR      Z,FD_WB_TIMEOUT
        IN      A,(FDC_CMD)
        CPL
        RRCA
FD_WB_JR:
        JR      C,FD_WB_LP
        POP     HL
        POP     DE
        RET
FD_WB_TIMEOUT:
        DEC     E
        JR      NZ,FD_WB_OUTER
        LD      A,29h                   ; ')'
        JP      FD_ERRA
;  FDR_START – Lesen: Spur/Sektor aus dem logischen Sektor (FD_PREP),
;  je Spur SEEK, Spur- und Sektorregister setzen, READ SECTOR mit
;  Mehrfachsektoren (94h) und die Bytes mit INI holen (Datenport DBh).
;  Nach Sektor 16 Abbruch mit FORCE INTERRUPT und weiter auf der nächsten
;  Spur. Fehler: bis zu 10 Versuche (FD_RETRY) mit RESTORE dazwischen.
FDR_START:
        CALL    FD_PREP
FDR_RETRY:
        CALL    FD_SETUP
FDR_TRACK:
        CALL    FD_SIDE
        CALL    FD_SEEK
        JR      NZ,FDR_ERR
        CALL    FD_SETTS
        DI
        LD      A,94h
        CALL    FD_CMDRW
FDR_SECTOR:
        LD      B,00h
FDR_BYTE:
        IN      A,(FDC_CMD)
        RRCA
        JR      C,FDR_STATUS
        RRCA
        JR      C,FDR_BYTE
        INI
        JR      NZ,FDR_BYTE
        INC     (IX+8)
        LD      A,(IX+8)
        CP      11h
        JR      Z,FDR_LAST
        DEC     D
        JR      NZ,FDR_SECTOR
        JR      FDR_STOP
FDR_LAST:
        DEC     D
FDR_STOP:
        CALL    FD_FORCEINT
FDR_STATUS:
        EI
        IN      A,(FDC_CMD)
        CPL
        LD      (FD_STATUS),A
        AND     0FFh
        JR      NZ,FDR_ERR
        CALL    FD_NEXTSEC
        JP      Z,FD_DONE
        LD      A,(IX+7)
        JR      FDR_TRACK
FDR_ERR:
        CALL    FD_RETRY
        JR      FDR_RETRY
;  FDW_START – Schreiben wie FDR_START mit WRITE SECTOR (B4h) und OUTI;
;  danach Kontrolllesen (FD_VERIFY). Schreibschutz: Fehler 41.
FDW_START:
        CALL    FD_PREP
FDW_RETRY:
        CALL    FD_SETUP
FDW_TRACK:
        CALL    FD_SIDE
        CALL    FD_SEEK
        JP      NZ,FDW_ERR
        CALL    FD_SETTS
        DI
        LD      A,0B4h
        CALL    FD_CMDRW
FDW_SECTOR:
        LD      B,00h
FDW_BYTE:
        IN      A,(FDC_CMD)
        RRCA
        JR      C,FDW_STATUS
        RRCA
        JR      C,FDW_BYTE
        OUTI
        JR      NZ,FDW_BYTE
        INC     (IX+8)
        LD      A,(IX+8)
        CP      11h
        JR      Z,FDW_LAST
        DEC     D
        JR      NZ,FDW_SECTOR
        JR      FDW_STOP
FDW_LAST:
        DEC     D
FDW_STOP:
        CALL    FD_FORCEINT
FDW_STATUS:
        EI
        IN      A,(FDC_CMD)
        CPL
        LD      (FD_STATUS),A
        CP      40h                     ; '@'
        JP      Z,FD_ERROR
        AND     0FFh
        JR      NZ,FDW_ERR
        CALL    FD_NEXTSEC
        JR      NZ,FDW_NEXTTRK
        CALL    FD_VERIFY
        JR      NC,FD_DONE
FDW_ERR:
        CALL    FD_RETRY
        JP      FDW_RETRY
FDW_NEXTTRK:
        LD      A,(IX+7)
        JP      FDW_TRACK
FD_DONE:
        LD      A,80h
        OUT     (FDD_SEL),A
        RET
;  FD_PREP – Startspur/-sektor berechnen, 10 Versuche einstellen.
;  FD_SETUP – Laufwerk wählen, D = Anzahl Sektoren, HL = Speicheradresse.
; <- aufgerufen von 5CBAh, 5D0Dh
FD_PREP:
        CALL    FD_LOG2PHYS
        LD      A,0Ah
        LD      (FD_RETRIES),A
        RET
; <- aufgerufen von 5CBDh, 5D10h
FD_SETUP:
        CALL    FD_SELECT
        LD      D,(IX+4)
        LD      A,(IX+3)
        OR      A
        JR      Z,FD_SETUP2
        INC     D
FD_SETUP2:
        LD      A,(IX+10)
        LD      (IX+8),A
        LD      A,(IX+9)
        LD      (IX+7),A
        LD      L,(IX+5)
        LD      H,(IX+6)
        RET
;  FD_SIDE – A = logische Spur: A/2 ins Datenregister (für SEEK), Bit 0
;  als Seite an Port DDh.
; <- aufgerufen von 5CC0h, 5D13h, 5E15h
FD_SIDE:
        SRL     A
        CPL
        OUT     (FDC_DAT),A
        JR      NC,FD_SIDE0
        LD      A,01h
        JR      FD_SIDE_OUT
FD_SIDE0:
        XOR     A
FD_SIDE_OUT:
        CPL
        OUT     (FDD_SID),A
        RET
; <- aufgerufen von 5CC8h, 5D1Ch
FD_SETTS:
        LD      C,0DBh
        LD      A,(IX+7)
        SRL     A
        CPL
        OUT     (FDC_TRK),A
        LD      A,(IX+8)
        CPL
        OUT     (FDC_SEC),A
        RET
; <- aufgerufen von 5D08h, 5D60h
FD_RETRY:
        LD      A,(FD_RETRIES)
        DEC     A
        LD      (FD_RETRIES),A
        JP      Z,FD_ERROR
        CALL    FD_RESTORE
        RET
;  FD_NEXTSEC – nach Sektor 16 auf Sektor 1 der nächsten Spur; NZ, wenn
;  noch Sektoren fehlen (D).
; <- aufgerufen von 5CFDh, 5D56h
FD_NEXTSEC:
        LD      A,(IX+8)
        CP      11h
        JR      NZ,FD_NS_RET
        LD      A,01h
        LD      (IX+8),A
        INC     (IX+7)
FD_NS_RET:
        LD      A,D
        OR      A
        RET
; <- aufgerufen von 5CCEh, 5D22h, 5E2Ch
FD_CMDRW:
        LD      (FD_LASTCMD),A
        CPL
        OUT     (FDC_CMD),A
        LD      A,30h                   ; '0'
        LD      (FD_WB_JR),A
        CALL    FD_WAITBUSY
        RET
;  FD_FORCEINT – FORCE INTERRUPT (D8h) und auf Ende warten.
; <- aufgerufen von 5CEFh, 5D43h, 5E49h
FD_FORCEINT:
        LD      A,0D8h
        CPL
        OUT     (FDC_CMD),A
        LD      A,38h                   ; '8'
        LD      (FD_WB_JR),A
        CALL    FD_WAITBUSY
        RET
;  FD_VERIFY – geschriebene Sektoren zur Kontrolle lesen (Daten werden
;  verworfen), 2 Versuche; C bei Fehler.
; <- aufgerufen von 5D5Bh
FD_VERIFY:
        CALL    FD_LOG2PHYS
        LD      A,02h
        LD      (FD_VRETRIES),A
FDV_RETRY:
        CALL    FD_SELECT
        LD      D,(IX+4)
        LD      A,(IX+3)
        OR      A
        JR      Z,FDV_SETUP
        INC     D
FDV_SETUP:
        LD      A,(IX+10)
        LD      L,A
        LD      A,(IX+9)
        LD      H,A
FDV_TRACK:
        CALL    FD_SIDE
        CALL    FD_SEEK
        JR      NZ,FDV_ERR
        LD      C,0DBh
        LD      A,H
        SRL     A
        CPL
        OUT     (FDC_TRK),A
        LD      A,L
        CPL
        OUT     (FDC_SEC),A
        DI
        LD      A,94h
        CALL    FD_CMDRW
FDV_SECTOR:
        LD      B,00h
FDV_BYTE:
        IN      A,(FDC_CMD)
        RRCA
        JR      C,FDV_STATUS
        RRCA
        JR      C,FDV_BYTE
        IN      A,(C)
        DJNZ    FDV_BYTE
        INC     L
        LD      A,L
        CP      11h
        JR      Z,FDV_LAST
        DEC     D
        JR      NZ,FDV_SECTOR
        JR      FDV_STOP
FDV_LAST:
        DEC     D
FDV_STOP:
        CALL    FD_FORCEINT
FDV_STATUS:
        EI
        IN      A,(FDC_CMD)
        CPL
        LD      (FD_STATUS),A
        AND     0FFh
        JR      NZ,FDV_ERR
        LD      A,L
        CP      11h
        JR      NZ,FDV_CHKEND
        LD      L,01h
        INC     H
FDV_CHKEND:
        LD      A,D
        OR      A
        JR      NZ,FDV_NEXTTRK
        RET
FDV_NEXTTRK:
        LD      A,H
        JP      FDV_TRACK
FDV_ERR:
        LD      A,(FD_VRETRIES)
        DEC     A
        LD      (FD_VRETRIES),A
        JR      NZ,FDV_AGAIN
        SCF
        RET
FDV_AGAIN:
        CALL    FD_RESTORE
        JP      FDV_RETRY
FD_STATUS:
        DEFB    00h                     ; ?? |.|
;  FD_ERROR – Fehlernummer aus dem Status: nicht bereit (Bit 7) 50,
;  Satz nicht gefunden (Bit 4) 54, sonst (auch Schreibschutz, Bit 6) 41.
;  Nummer nach (IY-1) schreiben, Laufwerke abschalten, JP (IY).
FD_ERROR:
        LD      A,(FD_LASTCMD)
        CP      0Bh
        JR      Z,FD_ERR_SEEK
        CP      1Bh
        JR      Z,FD_ERR_SEEK
        CP      0F4h
        JR      Z,FD_ERR_SEEK
        LD      A,(FD_STATUS)
        BIT     7,A
        JR      NZ,FD_ERR50
        BIT     6,A
        JR      NZ,FD_ERR41
        BIT     4,A
        LD      A,36h                   ; '6'
        JR      NZ,FD_ERRA
        JR      FD_ERR41
FD_ERR_SEEK:
        LD      A,(FD_STATUS)
        BIT     7,A
        JR      NZ,FD_ERR50
FD_ERR41:
        LD      A,29h                   ; ')'
        JR      FD_ERRA
FD_ERR50:
        LD      A,32h                   ; '2'
FD_ERRA:
        LD      (IY-1),A
        CALL    FD_RESET
        JP      (IY)
;  FD_LOG2PHYS – logischen Sektor (IX+1/+2) in Spur (= Sektor / 16) und
;  Sektor (= Rest + 1) zerlegen (IX+9/+10).
; <- aufgerufen von 5D71h, 5DF8h
FD_LOG2PHYS:
        LD      B,00h
        LD      DE,0010h
        LD      L,(IX+1)
        LD      H,(IX+2)
        XOR     A
FD_L2P_LP:
        SBC     HL,DE
        JR      C,FD_L2P_DONE
        INC     B
        JR      FD_L2P_LP
FD_L2P_DONE:
        ADD     HL,DE
        LD      H,B
        INC     L
        LD      (IX+9),H
        LD      (IX+10),L
        RET
;  FD_DLY_S / FD_DLY_M / FD_DLY_L – Warteschleifen (Zähler 000Fh, 00A0h,
;  2026h).
; <- aufgerufen von 5C9Ch
FD_DLY_S:
        PUSH    DE
        LD      DE,000Fh
        JP      FD_DLY_LP
; <- aufgerufen von 5C5Fh
FD_DLY_M:
        PUSH    DE
        LD      DE,00A0h
        JP      FD_DLY_LP
; <- aufgerufen von 5C1Dh, 5C4Ch, 5C90h
FD_DLY_L:
        PUSH    DE
        LD      DE,2026h                ; Wartezeit (Schleifenzähler, keine Adresse)
FD_DLY_LP:
        DEC     DE
        LD      A,E
        OR      D
        JR      NZ,FD_DLY_LP
        POP     DE
        RET
;  FD_LASTCMD: letztes Kommando; FD_MOTOR: 1 = Motor läuft;
;  FD_RESTORED..3: je Laufwerk 1 nach dem ersten RESTORE; FD_RETRIES,
;  FD_VRETRIES: verbleibende Versuche.
FD_LASTCMD:
        DEFB    00h                     ; ?? |.|
FD_MOTOR:
        DEFB    00h                     ; ?? |.|
FD_RESTORED:
        DEFB    00h                     ; ?? |.|
FD_RESTORED1:
        DEFB    00h                     ; ?? |.|
FD_RESTORED2:
        DEFB    00h                     ; ?? |.|
FD_RESTORED3:
        DEFB    00h                     ; ?? |.|
FD_RETRIES:
        DEFB    00h                     ; ?? |.|
FD_VRETRIES:
        DEFB    00h                     ; ?? |.|

; ==============================================================================
;  GP-IB (IEEE-488)
; ==============================================================================
;  IO_INIT: PIO der GP-IB-Karte programmieren und – das ist der
;  Einhängepunkt der RS-232C-Erweiterung – mit JP SIO_INIT enden.
; <- aufgerufen von 1311h
IO_INIT:
        LD      HL,GPIB_PIOINIT         ; PIO-Init-Daten der GP-IB-Karte
        LD      BC,03C3h                ; 3 Bytes an Port C3h
        OTIR
        LD      BC,03C2h                ; 3 Bytes an Port C2h
        OTIR
        LD      A,10h
        OUT     (GP_C1),A
        XOR     A
        OUT     (GP_C4),A
        JP      SIO_INIT                ; Einhängepunkt der RS-232C-Erweiterung
;  GP-IB-Befehle als Controller. Adressen: Hörer 0-30 (20h+n), Sprecher
;  0-31 (40h+n), sonst Fehler 37; mehrere Geräte durch ";" getrennt
;  (GET_ADDRS, bis 14). Gesendet wird mit ATN (ATN_ON ... ATN_OFF):
;  TRG adr[;adr]  – UNL, Hörer, GET (08h)
;  DCL [adr...]   – mit Adressen UNL, Hörer, SDC (04h), sonst DCL (14h)
;  LCL [adr...]   – mit Adressen GTL (01h), sonst REN abschalten
;  LLO            – LLO (11h)
;  PCT adr        – UNL, Sprecher, TCT (09h): Controllerrolle abgeben
ST_TRG: CALL    GET_ADDRS
        CALL    ATN_ON
        CALL    SEND_UNL
        CALL    SEND_ADDRS
        LD      A,08h
GP_SENDCMD:
        CALL    GP_SENDBYTE
GP_ATNOFF_DONE:
        CALL    ATN_OFF
        JP      NEXTSTMT_HL
ST_DCL: CALL    CHRGET
        JR      Z,DCL_ALL
        CALL    GET_ADDRS
        CALL    ATN_ON
        CALL    SEND_UNL
        CALL    SEND_ADDRS
        LD      A,04h
        JR      GP_SENDCMD
DCL_ALL:
        CALL    ATN_ON
        LD      A,14h
        JR      GP_SENDCMD
ST_LCL: CALL    CHRGET
        JR      Z,LCL_ALL
        CALL    GET_ADDRS
        CALL    ATN_ON
        CALL    SEND_UNL
        CALL    SEND_ADDRS
        LD      A,01h
        JR      GP_SENDCMD
LCL_ALL:
        CALL    CHK_SYSCTRL
        CALL    REN_OFF
        JP      NEXTSTMT_HL
ST_LLO: CALL    ATN_ON
        LD      A,11h
        JR      GP_SENDCMD
ST_PCT: CALL    ATN_ON
        CALL    SEND_UNL
        CALL    GET_TLKADDR
        CALL    GP_SENDBYTE
        LD      A,10h
        CALL    GP_OUTC5
        PUSH    HL
        LD      HL,GP_MODE
        RES     6,(HL)
        POP     HL
        LD      A,09h
        CALL    GP_SENDBYTE
        XOR     A
        OUT     (GP_C4),A
        JR      GP_ATNOFF_DONE
;  REN – REN setzen (Port C1 Bit 0). ICL – IFC kurz setzen (Bit 1),
;  Schnittstelle zurücksetzen; nur als Systemcontroller (CHK_SYSCTRL).
ST_REN: CALL    CHK_SYSCTRL
        CALL    GP_DELAY22
        IN      A,(GP_C1)
        SET     0,A
        JR      GP_SETCTL
ST_ICL: CALL    CHK_SYSCTRL
        IN      A,(GP_C1)
        AND     13h
        OR      12h
        OUT     (GP_C1),A
        CALL    GP_DELAY22
        PUSH    HL
        LD      HL,GP_MODE
        SET     6,(HL)
        POP     HL
        RES     1,A
GP_SETCTL:
        OUT     (GP_C1),A
        JP      NEXTSTMT_HL
;  WRT [/adr[;adr...],] ausdruck[;...] – Daten senden. Mit "/" erst UNT,
;  UNL, eigene Sprecheradresse und die Hörer adressieren, sonst muss die
;  Karte schon Sprecher sein (Fehler 39). Die Texte werden im Puffer 7074h
;  gesammelt (höchstens 500 Bytes, Fehler 3) und mit den Endezeichen
;  EOI_WCHR1/2 gesendet; ";" am Ende unterdrückt sie.
ST_WRT: CALL    CHK_IFREADY
        CALL    CHK_CHR_ALT
D5FAE:  DEFB    2Fh                     ; Inline-Parameter '/'
D5FAF:  DEFW    WRT_ADDR
        JR      WRT_CHKTALK
; <- aufgerufen von 5FABh
WRT_ADDR:
        CALL    GET_ADDRS
        CALL    ATN_ON
        LD      A,80h
        CALL    GP_OUTC5
        CALL    SEND_UNT_UNL
        LD      A,(GP_MYTLK)
        CALL    GP_SENDBYTE
        CALL    SEND_ADDRS
        CALL    ATN_OFF
WRT_CHKTALK:
        IN      A,(GP_C1)
        BIT     6,A
        JP      Z,ERR_39
        CALL    SKIPCOMMA
        CALL    CHRGET
        LD      (TXTPTR),HL
        JP      Z,ERR_01
        PUSH    HL
        CALL    WRT_FREEBUF
        LD      BC,0304h
        CALL    AREA_RESIZE
        POP     HL
WRT_LOOP:
        CALL    CHRGET
        LD      (TXTPTR),HL
        JR      Z,WRT_SEND
        CALL    SKIPCOMMA
        CALL    CHK_CHR_ALT
D5FF9:  DEFB    3Bh                     ; Inline-Parameter ';'
D5FFA:  DEFW    WRT_ITEM
        CALL    CHRGET
        LD      (TXTPTR),HL
        JR      Z,WRT_SEMI
; <- aufgerufen von 5FF6h
WRT_ITEM:
        CALL    EVAL_EXPR
        PUSH    HL
        LD      HL,(7074h)
        PUSH    BC
        LD      BC,01FCh
        ADD     HL,BC
        POP     BC
        CALL    VAL2TEXT_HL
        JR      Z,WRT_NEXT
        PUSH    DE
        LD      HL,(7074h)
        INC     HL
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        DEC     HL
        PUSH    DE
        PUSH    HL
        EX      DE,HL
        ADD     HL,BC
        XOR     A
        EX      DE,HL
        LD      HL,01F4h
        SBC     HL,DE
        JP      C,ERR_03
        POP     HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        INC     HL
        POP     DE
        ADD     HL,DE
        POP     DE
        EX      DE,HL
        LDIR
WRT_NEXT:
        LD      HL,WRT_LOOP
        EX      (SP),HL
        CALL    CHRGET
        RET     Z
        CP      3Bh                     ; ';'
        RET     Z
        CP      2Ch                     ; ','
        RET     Z
        JP      ERR_01
WRT_LASTSEP:
        DEFB    00h                     ; ?? |.|
WRT_SEMI:
        LD      A,3Bh                   ; ';'
WRT_SEND:
        LD      (WRT_LASTSEP),A
        LD      HL,(7074h)
        INC     HL
        INC     HL
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        LD      A,B
        OR      C
        JR      Z,WRT_DONE
        INC     HL
        LD      D,H
        LD      E,L
        LD      A,(WRT_LASTSEP)
        CP      3Bh                     ; ';'
        JR      NZ,WRT_DELIM
        DEC     BC
        CALL    SEND_BUF
        CALL    GP_C1BIT4_OFF
WRT_SEND_LP:
        LD      A,(DE)
        CALL    GP_SENDBYTE
        CALL    GP_C1BIT4_ON
WRT_DONE:
        CALL    WRT_FREEBUF
        JP      NEXTSTMT
WRT_DELIM:
        CALL    SEND_BUF
        LD      DE,EOI_WCHR2
        LD      A,(DE)
        DEC     DE
        DEC     DE
        INC     A
        JR      Z,WRT_DELIM2
        INC     DE
        LD      A,(DE)
        CALL    GP_SENDBYTE
WRT_DELIM2:
        CALL    GP_C1BIT4_OFF
        INC     DE
        JR      WRT_SEND_LP
; <- aufgerufen von 5FE1h, 6074h
WRT_FREEBUF:
        LD      HL,(7074h)
        JP      AREA_FREE
;  RED [/adr,] var[,var...] – Daten empfangen (wie INPUT): mit "/" UNL,
;  eigene Hörer- und die Sprecheradresse senden, sonst muss die Karte
;  Hörer sein (Fehler 39). Eine Zeile bis EOI oder zu den Endezeichen
;  EOI_RCHR1/2 nach INBUF lesen (GP_READLINE), Werte durch "," getrennt
;  den Variablen zuweisen; Zahlen über NUMSTR_EVAL (sonst Fehler 4).
ST_RED: CALL    CHK_IFREADY
        CALL    CHK_CHR_ALT
D609D:  DEFB    2Fh                     ; Inline-Parameter '/'
D609E:  DEFW    RED_ADDR
        JR      RED_CHKLSN
; <- aufgerufen von 609Ah
RED_ADDR:
        CALL    ATN_ON
        LD      A,20h                   ; ' '
        CALL    GP_OUTC5
        CALL    SEND_UNT_UNL
        CALL    GET_TLKADDR
        CALL    GP_SENDBYTE
        LD      A,(GP_MYLSN)
        CALL    GP_SENDBYTE
        CALL    ATN_OFF
RED_CHKLSN:
        IN      A,(GP_C1)
        BIT     5,A
        JP      Z,ERR_39
        CALL    SKIPCOMMA
        LD      (TXTPTR),HL
        CALL    GP_READLINE
RED_PARSE:
        EX      DE,HL
        LD      (IN_PTR),HL
        PUSH    HL
        LD      HL,(TXTPTR)
RED_SCAN:
        LD      A,(HL)
        CP      2Ch                     ; ','
        JR      Z,RED_VALUE
        CP      24h                     ; '$'
        JR      Z,RED_STRVAR
        INC     HL
        CALL    CHRGET
        JP      Z,RED_VALUE
        JR      RED_SCAN
RED_STRVAR:
        POP     HL
        CALL    SKIPSP
        LD      DE,0D0Dh
        CALL    STRLIT_DE
        JR      RED_ASSIGN
RED_VALUE:
        POP     HL
RED_VALUE2:
        CALL    STRLIT
RED_ASSIGN:
        LD      (IN_PTR),HL
        CALL    SAVEPAR0
        LD      HL,(TXTPTR)
        CALL    GETNAME_SN
        CALL    GETVAR
        LD      (TXTPTR),HL
        CALL    SAVEPAR1
RED_ASG_DO:
        CALL    ASSIGN
D610E:  DEFW    RED_TONUM
        LD      HL,(TXTPTR)
        CALL    CHRGET
        JP      Z,NEXTSTMT
        CALL    SYNCHK
D611C:  DEFB    2Ch                     ; Inline-Parameter ','
        LD      (TXTPTR),HL
        LD      HL,(IN_PTR)
        JR      RED_VALUE2
; <- aufgerufen von 610Bh
RED_TONUM:
        LD      DE,(6B02h)
        CALL    GETSTR
        EX      DE,HL
        CALL    CHK_CHR_ALT
D6130:  DEFB    0Dh                     ; Inline-Parameter
D6131:  DEFW    RED_TONUM2
        LD      HL,RED_STR0
; <- aufgerufen von 612Dh
RED_TONUM2:
        CALL    NUMSTR_EVAL
D6139:  DEFW    ERR_04
        CALL    SAVEPAR0
        JR      RED_ASG_DO
RED_STR0:
        DEFB    30h,0Dh                 ; ?? |0.|
; <- aufgerufen von 60C9h
GP_READLINE:
        XOR     A
        OUT     (GP_C4),A
        PUSH    HL
        LD      DE,INBUF
        PUSH    DE
        LD      BC,0000h
GPR_LOOP:
        CALL    GP_WAITDAV
        CALL    GP_RECVBYTE
GPR_STORE:
        LD      (DE),A
        INC     DE
        INC     BC
        LD      HL,EOI_RCHR1
        PUSH    AF
        IN      A,(GP_C0)
        BIT     4,A
        JR      NZ,GPR_EOI
        POP     AF
        CP      (HL)
        JR      Z,GPR_DELIM1
        CALL    GP_RECVACK
        LD      A,C
        INC     A
        JP      Z,ERR_03
        JR      GPR_LOOP
GPR_EOI:
        POP     AF
        DEC     DE
        LD      A,0Dh
        LD      (DE),A
        INC     HL
        LD      A,(HL)
        INC     A
        JR      Z,GPR_DONE
        CALL    GP_RECVACK
        CALL    GP_RECVBYTE
GPR_DONE:
        POP     DE
        POP     HL
        JP      GP_RECVACK
GPR_DELIM1:
        INC     HL
        LD      A,(HL)
        INC     A
        JR      NZ,GPR_DELIM2
GPR_ENDLINE:
        DEC     DE
        LD      A,0Dh
        LD      (DE),A
        JR      GPR_DONE
GPR_DELIM2:
        CALL    GP_RECVACK
        CALL    GP_RECVBYTE
        CP      (HL)
        INC     DE
        JR      NZ,GPR_STORE
        JR      GPR_ENDLINE
;  CMD R|W, ausdruck – Text als Adress-/Befehlsbytes mit ATN senden,
;  die Karte dabei auf Empfang (R) bzw. Senden (W) stellen.
ST_CMD: CALL    SKIPSP
        INC     HL
        CP      52h                     ; 'R'
        JR      Z,CMD_SEND
        CP      57h                     ; 'W'
        JP      NZ,ERR_01
CMD_SEND:
        LD      (CMD_RW),A
        CALL    EVAL_EXPR
        PUSH    HL
        CALL    VAL2STRBUF
        JR      Z,CMD_DONE
        CALL    ATN_ON
        LD      A,(CMD_RW)
        CP      52h                     ; 'R'
        LD      A,20h                   ; ' '
        JR      Z,CMD_MODE
        LD      A,80h
CMD_MODE:
        CALL    GP_OUTC5
        CALL    SEND_BUF
CMD_DONE:
        POP     HL
        CALL    ATN_OFF
        JP      NEXTSTMT_HL
CMD_RW: DEFB    00h                     ; ?? |.|
;  ON SRQ GOTO zeile (über ON) – bei gesetzter SRQ-Leitung springt
;  NL_SRQ vor der nächsten Zeile dorthin (einmalig, SRQ_ON wird gelöscht).
ST_SRQ: CALL    GETLNUM_SN
        CALL    CHK_EOS
        LD      A,01h
        LD      (SRQ_ON),A
        CALL    GOTO_DE
        LD      (SRQ_LINE),HL
        JP      NEXTSTMT
SRQ_ON: DEFB    00h                     ; ?? |.|
SRQ_LINE:
        DEFB    00h,00h                 ; ?? |..|
;  SPOL adr, var – Serial Poll: UNL, SPE (18h), Sprecher, Statusbyte
;  lesen, SPD (19h), UNT; Statusbyte nach var.
ST_SPOL:
        CALL    ATN_ON
        LD      A,44h                   ; 'D'
        CALL    GP_OUTC5
        CALL    SEND_UNL
        LD      A,18h
        CALL    GP_SENDBYTE
        CALL    GET_TLKADDR
        CALL    GP_SENDBYTE
        CALL    ATN_OFF
        CALL    SKIPCOMMA
        XOR     A
        OUT     (GP_C4),A
        CALL    GP_RECVBYTE
        PUSH    AF
        CALL    GP_RECVACK
        CALL    GP_WAITDAV
        CALL    ATN_ON2
        LD      A,42h                   ; 'B'
        CALL    GP_OUTC5
        LD      A,19h
        CALL    GP_SENDBYTE
        LD      A,5Fh                   ; '_'
        CALL    GP_SENDBYTE
        CALL    ATN_OFF
        XOR     A
        LD      (SRQ_ON),A
        POP     AF
        PUSH    AF
        CALL    SKIPCOMMA
        CALL    GETNAME_SN
        CALL    GETVAR
        LD      (TXTPTR),HL
        CALL    SAVEPAR1
GP_RETBYTE:
        POP     AF
GP_RETVAL:
        LD      E,A
        LD      D,00h
        JP      GET_NUMVAL
;  PPC adr, n – Parallel Poll Configure: Hörer, PPC (05h), PPE (68h+n,
;  n = 0-7, sonst Fehler 3). PPOL var – Parallel Poll ausführen, Ergebnisbyte nach var.
;  PPU – Parallel Poll Unconfigure (15h).
ST_PPC: CALL    ATN_ON
        CALL    SEND_UNL
        CALL    GET_LSNADDR
        CALL    GP_SENDBYTE
        LD      A,05h
        CALL    GP_SENDBYTE
        CALL    SKIPCOMMA
        CALL    EVAL_BYTE
        LD      A,E
        CP      08h
        JP      NC,ERR_03
        OR      68h
        CALL    GP_SENDBYTE
        CALL    SEND_UNL
        CALL    ATN_OFF
        JP      NEXTSTMT_HL
ST_PPOL:
        XOR     A
        OUT     (GP_C4),A
        CALL    SKIPCOMMA
        CALL    GETNAME_SN
        CALL    GETVAR
        LD      (TXTPTR),HL
        CALL    SAVEPAR1
        CALL    ATN_ON
        CALL    GP_C1BIT4_OFF
        LD      A,01h
        CALL    GP_DELAY
        IN      A,(GP_C4)
        PUSH    AF
        CALL    ATN_OFF
        CALL    GP_C1BIT4_ON
        JP      GP_RETBYTE
ST_PPU: CALL    ATN_ON
        LD      A,15h
        CALL    GP_SENDBYTE
        CALL    ATN_OFF
        JP      NEXTSTMT_HL
;  GPIB [M|S] [, hörer [, sprecher]] – Betriebsart: M = Controller
;  (GP_MODE C0h), S = Gerät (0). Eigene Hörer-/Sprecheradresse (0-30,
;  Vorgabe Sprecher = Hörer).
ST_GPIB:
        PUSH    AF
        XOR     A
        OUT     (GP_C4),A
        OR      10h
        OUT     (GP_C1),A
        POP     AF
        CALL    CHK_CHR_ALT
D62AE:  DEFB    4Dh                     ; Inline-Parameter 'M'
D62AF:  DEFW    GPIB_SLAVE
        LD      A,0C0h
GPIB_SETMODE:
        LD      (GP_MODE),A
; <- aufgerufen von 62DFh
GPIB_ADDR:
        CALL    CHRGET
        JP      Z,NEXTSTMT_HL
        CALL    EVAL_BYTE
        LD      A,E
        ADD     A,20h
        CALL    CHK_LSNADDR
        LD      (GP_MYLSN),A
        CALL    CHRGET
        JR      Z,GPIB_DEFTALK
        CALL    SKIPCOMMA
        CALL    EVAL_BYTE
        LD      A,E
        ADD     A,40h
        CALL    CHK_TLKADDR
GPIB_SETTALK:
        LD      (GP_MYTLK),A
        JP      NEXTSTMT_HL
; <- aufgerufen von 62ABh
GPIB_SLAVE:
        CALL    CHK_CHR_ALT
D62E2:  DEFB    53h                     ; Inline-Parameter 'S'
D62E3:  DEFW    GPIB_ADDR
        XOR     A
        JR      GPIB_SETMODE
GPIB_DEFTALK:
        LD      A,(GP_MYLSN)
        ADD     A,20h
        JR      GPIB_SETTALK
RDS_STATE:
        DEFB    00h                     ; ?? |.|
;  RDS var – als Gerät auf den Controller warten und dessen Befehle
;  auswerten (RDS_DECODE: UNL, UNT, eigene Adressen, DCL, SDC, SPE/SPD,
;  GET, TCT); Ergebnis in RDS_STATE nach var. Bei Serial Poll wird
;  RQS_BYTE gesendet. Nur als Gerät (Fehler 34).
ST_RDS: CALL    CHK_NOTCTRL
        XOR     A
        OUT     (GP_C4),A
        CALL    GETNAME_SN
        CALL    GETVAR
        LD      (TXTPTR),HL
        CALL    SAVEPAR1
        LD      HL,RDS_STATE
        XOR     A
        LD      (HL),A
RDS_WAIT:
        CALL    GP_BRKCHK
        IN      A,(GP_C0)
        AND     08h
        JR      Z,RDS_WAIT
        CALL    GP_RECV_WAIT
RDS_DECODE:
        AND     7Fh
        CP      20h                     ; ' '
        JR      C,RDS_UCMD
        CP      3Fh                     ; '?'
        JR      Z,RDS_UNL
        JR      C,RDS_MLA
        CP      5Fh                     ; '_'
        JR      Z,RDS_UNT
        JR      C,RDS_MTA
RDS_NEXT:
        LD      HL,RDS_STATE
        CALL    RDS_HANDSHAKE
        IN      A,(GP_C4)
        JR      RDS_DECODE
RDS_UNT:
        RES     1,(HL)
        LD      A,40h                   ; '@'
        JR      RDS_OUTC5
RDS_UCMD:
        CP      0Fh
        JR      C,RDS_ACMD
        CP      14h
        JR      Z,RDS_DCL
        CP      18h
        JR      Z,RDS_SPE
        CP      19h
        JR      NZ,RDS_NEXT
        XOR     A
        LD      (HL),A
        LD      A,40h                   ; '@'
RDS_OUTC5:
        CALL    GP_OUTC5
        JR      RDS_NEXT
RDS_SPE:
        LD      (HL),01h
        LD      A,08h
        JR      RDS_OUTC5
RDS_DCL:
        LD      A,40h                   ; '@'
        LD      (HL),A
        OR      10h
        JR      RDS_OUTC5
RDS_UNL:
        RES     2,(HL)
        LD      A,10h
        JR      RDS_OUTC5
RDS_MLA:
        LD      B,A
        LD      A,(GP_MYLSN)
        CP      B
        JR      NZ,RDS_NEXT
        LD      (HL),04h
        LD      A,20h                   ; ' '
        JR      RDS_OUTC5
RDS_MTA:
        LD      B,A
        LD      A,(GP_MYTLK)
        CP      B
        JR      NZ,RDS_NEXT
        LD      A,80h
        SET     1,(HL)
        BIT     0,(HL)
        JR      Z,RDS_OUTC5
        OR      08h
        JR      RDS_OUTC5
RDS_ACMD:
        BIT     2,(HL)
        JR      NZ,RDS_ACMD2
        BIT     1,(HL)
        JR      Z,RDS_NEXT
        CP      09h
        JR      NZ,RDS_NEXT
        LD      A,20h                   ; ' '
        CALL    GP_OUTC5
        XOR     A
        OUT     (GP_C4),A
        CALL    ATN_OFF
        CALL    GP_C1BIT4_ON
RDS_TCT_WAIT:
        IN      A,(GP_C0)
        BIT     3,A
        JR      NZ,RDS_TCT_WAIT
        XOR     A
        OUT     (GP_C4),A
        LD      (HL),20h
        LD      A,(GP_MODE)
        SET     6,A
        LD      (GP_MODE),A
        JR      RDS_RET
RDS_ACMD2:
        CP      08h
        JR      Z,RDS_GET
        CP      04h
        JR      Z,RDS_DCL
        CP      01h
        JP      NZ,RDS_NEXT
        LD      A,10h
        LD      (HL),A
        JR      RDS_OUTC5
RDS_GET:
        LD      (HL),A
        JR      RDS_RET
; <- aufgerufen von 6328h
RDS_HANDSHAKE:
        CALL    GP_BRKCHK
        IN      A,(GP_C0)
        CPL
        AND     88h
        RET     Z
        CP      80h
        JR      Z,RDS_HANDSHAKE
        POP     AF
        LD      A,(HL)
        AND     07h
        JR      Z,RDS_RET
        CP      03h
        JR      Z,RDS_SERPOLL
        IN      A,(GP_C1)
        AND     60h
        CP      60h                     ; '`'
        JP      Z,ERR_38
RDS_RET:
        LD      A,(HL)
        JP      GP_RETVAL
RDS_SERPOLL:
        LD      A,(RQS_BYTE)
        CALL    GP_SENDBYTE
        IN      A,(GP_C1)
        RES     2,A
        OUT     (GP_C1),A
        XOR     A
        OUT     (GP_C4),A
        JP      RDS_WAIT
RQS_BYTE:
        DEFB    00h                     ; ?? |.|
;  RQSMSG= n – Statusbyte für den Serial Poll (RQS_BYTE).
;  SSRQ – Service Request auslösen (Port C1 Bit 2).
ST_RQSMSG:
        CALL    EVAL_BYTE
        LD      A,E
        LD      (RQS_BYTE),A
        JP      NEXTSTMT_HL
;  EOI R n[,m] / EOI W n[,m] – Endezeichen für RED bzw. WRT (zweites
;  Zeichen optional; FFh = keins). Vorgabe: WRT 0Dh,0Ah; RED 0Ah.
ST_EOI: CALL    CHK_CHR_ALT
D6409:  DEFB    52h                     ; Inline-Parameter 'R'
D640A:  DEFW    EOI_WRITE
        PUSH    HL
        LD      HL,EOI_RCHR1
EOI_SET:
        LD      (EOI_SET1+1),HL
        INC     HL
        LD      (EOI_SET2+1),HL
        POP     HL
        CALL    EVAL_BYTE
        LD      A,E
EOI_SET1:
        LD      (EOI_RCHR1),A
        CALL    CHK_CHR_ALT
D6422:  DEFB    2Ch                     ; Inline-Parameter ','
D6423:  DEFW    NEXTSTMT_HL
        CALL    EVAL_BYTE
        LD      A,E
EOI_SET2:
        LD      (EOI_RCHR2),A
        JP      NEXTSTMT_HL
; <- aufgerufen von 6406h
EOI_WRITE:
        CALL    SYNCHK
D6432:  DEFB    57h                     ; Inline-Parameter 'W'
        PUSH    HL
        LD      HL,EOI_WCHR1
        JR      EOI_SET
ST_SSRQ:
        IN      A,(GP_C1)
        SET     2,A
        OUT     (GP_C1),A
        JP      NEXTSTMT_HL
; <- aufgerufen von 6285h, 644Bh
GP_DELAY:
        DEC     A
        NOP
        JP      NZ,GP_DELAY
        RET
; <- aufgerufen von 5F83h, 5F97h
GP_DELAY22:
        PUSH    AF
        LD      A,16h
        CALL    GP_DELAY
        POP     AF
        RET
; <- aufgerufen von 6470h
GPIB_WAIT:
        LD      A,(GP_MODE)
        BIT     6,A
        JR      Z,GP_ERR34
        JR      CHK_IFREADY
;  CHK_SYSCTRL / CHK_IFREADY / CHK_NOTCTRL – Betriebsart prüfen: nur als
;  Controller bzw. nur als Gerät (sonst Fehler 34); Port C1 Bit 7 gesetzt:
;  Fehler 35.
; <- aufgerufen von 5F4Eh, 5F80h, 5F8Ch
CHK_SYSCTRL:
        LD      A,(GP_MODE)
        BIT     7,A
        JR      Z,GP_ERR34
; <- aufgerufen von 5FA8h, 6097h
CHK_IFREADY:
        IN      A,(GP_C1)
        RLCA
        RET     NC
        JP      ERR_35
; <- aufgerufen von 62F0h
CHK_NOTCTRL:
        LD      A,(GP_MODE)
        BIT     6,A
        RET     Z
GP_ERR34:
        JP      ERR_34
;  ATN_ON / ATN_OFF – ATN setzen bzw. löschen (Port C1 Bit 3): die
;  folgenden Bytes sind Befehle/Adressen.
; <- aufgerufen von 5F09h, 5F25h, 5F32h, 5F41h, 5F57h, 5F5Eh, 5FB6h, 60A2h (+5 weitere)
ATN_ON: CALL    GPIB_WAIT
; <- aufgerufen von 620Fh
ATN_ON2:
        IN      A,(GP_C1)
        SET     3,A
GP_OUTC1:
        OUT     (GP_C1),A
        RET
; <- aufgerufen von 5F17h, 5FCAh, 60B9h, 61C8h, 61FCh, 6221h, 6265h, 628Bh (+2 weitere)
ATN_OFF:
        IN      A,(GP_C1)
        RES     3,A
        JR      GP_OUTC1
; <- aufgerufen von 6071h, 628Eh, 6398h
GP_C1BIT4_ON:
        IN      A,(GP_C1)
        SET     4,A
        JR      GP_OUTC1
; <- aufgerufen von 606Ah, 608Bh, 6280h
GP_C1BIT4_OFF:
        IN      A,(GP_C1)
        RES     4,A
        JR      GP_OUTC1
; <- aufgerufen von 5F51h
REN_OFF:
        IN      A,(GP_C1)
        RES     0,A
        JR      GP_OUTC1
; <- aufgerufen von 5FBEh, 60AAh
SEND_UNT_UNL:
        LD      A,5Fh                   ; '_'
        CALL    GP_SENDBYTE
; <- aufgerufen von 5F0Ch, 5F28h, 5F44h, 5F61h, 61EEh, 6243h, 6262h
SEND_UNL:
        LD      A,3Fh                   ; '?'
;  GP_SENDBYTE – Byte A auf den Bus (Port C4) mit Handshake; GP_WAITRDY
;  wartet, bis gesendet werden kann (fehlt die Bestätigung: Fehler 36).
;  BREAK bricht jedes Warten ab (GP_BRKCHK).
; <- aufgerufen von 5F14h, 5F67h, 5F78h, 5FC4h, 606Eh, 6088h, 60B0h, 60B6h (+11 weitere)
GP_SENDBYTE:
        CALL    GP_WAITRDY
        OUT     (GP_C4),A
; <- aufgerufen von 614Dh, 620Ch
GP_WAITDAV:
        CALL    GP_BRKCHK
        IN      A,(GP_C0)
        RLCA
        JR      C,GP_WAITDAV
        RET
; <- aufgerufen von 6499h
GP_WAITRDY:
        PUSH    AF
GP_WAITRDY_LP:
        CALL    GP_BRKCHK
        IN      A,(GP_C0)
        RLCA
        RLCA
        JR      C,GP_WAITRDY_LP
        RLCA
        JP      NC,ERR_36
        POP     AF
        RET
;  GP_RECVBYTE – ein Byte empfangen (A), GP_RECVACK quittiert es.
; <- aufgerufen von 6150h, 617Bh, 6191h, 6205h
GP_RECVBYTE:
        LD      A,(GP_C5COPY)
        SET     0,A
        OUT     (GP_C5),A
; <- aufgerufen von 6310h
GP_RECV_WAIT:
        CALL    GP_BRKCHK
        IN      A,(GP_C0)
        RLCA
        JR      NC,GP_RECV_WAIT
        IN      A,(GP_C4)
        RET
; <- aufgerufen von 6164h, 6178h, 618Eh, 6209h
GP_RECVACK:
        XOR     A
        OUT     (GP_C4),A
        LD      A,(GP_C5COPY)
        RES     0,A
        OUT     (GP_C5),A
        RET
;  SEND_ADDRS – die mit GET_ADDRS gesammelten Adressen (GP_ADDRBUF, BC
;  Stück) senden. SEND_BUF: BC Bytes ab DE.
; <- aufgerufen von 5F0Fh, 5F2Bh, 5F47h, 5FC7h
SEND_ADDRS:
        LD      DE,GP_ADDRBUF
; <- aufgerufen von 6067h, 607Ah, 61C4h
SEND_BUF:
        LD      A,(DE)
        CALL    GP_SENDBYTE
        INC     DE
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,SEND_BUF
        RET
; <- aufgerufen von 5F06h, 5F22h, 5F3Eh, 5FB3h
GET_ADDRS:
        LD      DE,GP_ADDRBUF
        LD      BC,0000h
GET_ADDRS_LP:
        CALL    GET_LSNADDR
        LD      (DE),A
        INC     DE
        INC     BC
        LD      A,C
        CP      0Fh
        JP      NC,ERR_03
        CALL    SKIPSP
        INC     HL
        CP      3Bh                     ; ';'
        JR      Z,GET_ADDRS_LP
        DEC     HL
        RET
; <- aufgerufen von 6246h, 64E8h
GET_LSNADDR:
        PUSH    BC
        PUSH    DE
        CALL    EVAL_BYTE
        LD      A,E
        ADD     A,20h
        CALL    CHK_LSNADDR
        POP     DE
        POP     BC
        RET
; <- aufgerufen von 62C2h, 6506h
CHK_LSNADDR:
        CP      40h                     ; '@'
        JR      NC,GP_ERR37
        CP      20h                     ; ' '
        RET     NC
GP_ERR37:
        JP      ERR_37
; <- aufgerufen von 62D6h
CHK_TLKADDR:
        CP      60h                     ; '`'
        JR      NC,GP_ERR37
        CP      40h                     ; '@'
        RET     NC
        JR      GP_ERR37
; <- aufgerufen von 5F64h, 60ADh, 61F6h
GET_TLKADDR:
        CALL    EVAL_BYTE
        LD      A,E
        ADD     A,40h
        JR      CHK_TLKADDR
; <- aufgerufen von 6307h, 63C5h, 649Eh, 64A8h, 64BEh
GP_BRKCHK:
        CALL    BRKCHK
        JP      Z,BREAK
        RET
GP_C5COPY:
        DEFB    00h                     ; ?? |.|
; <- aufgerufen von 5F6Ch, 5FBBh, 60A7h, 61C1h, 61EBh, 6214h, 6349h, 638Fh
GP_OUTC5:
        LD      (GP_C5COPY),A
        OUT     (GP_C5),A
        RET
; <- aufgerufen von 61AEh, 6738h
VAL2STRBUF:
        LD      HL,INBUF
; <- aufgerufen von 6011h
VAL2TEXT_HL:
        LD      A,D
        OR      A
        CALL    Z,VAL2TEXT
        CALL    NZ,STR2TEXT
        LD      A,B
        OR      C
        RET
GPIB_PIOINIT:
        DEFB    0CFh,60h,07h,0CFh,0FFh,07h  ; ?? |.`....|
EOI_WCHR1:
        DEFB    0Dh                     ; ?? |.|
EOI_WCHR2:
        DEFB    0Ah                     ; ?? |.|
EOI_RCHR1:
        DEFB    0Ah                     ; ?? |.|
EOI_RCHR2:
        DEFB    0FFh                    ; ?? |.|
GP_MYLSN:
        DEFB    21h                     ; ?? |!|
GP_MYTLK:
        DEFB    41h                     ; ?? |A|
;  GP_MODE: Bit 7 Systemcontroller, Bit 6 Controller aktiv (ICL/PCT).
;  GP_MYLSN/GP_MYTLK: eigene Hörer-/Sprecheradresse (20h+n/40h+n).
;  EOI_*: Endezeichen (EOI W/R). GP_ADDRBUF: Adressen für TRG/DCL/LCL/WRT.
GP_MODE:
        DEFB    0C0h                    ; ?? |.|
GP_ADDRBUF:
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h                     ; ?? |.|

; ------------------------------------------------------------------------------
;  OLD_COPY – unbenutzt
;  Bytegleiche Kopie von 560Bh-56A9h; übrig geblieben, als der
;  Bereich ab 6600h für die RS-232C-Routinen genutzt wurde.
; ------------------------------------------------------------------------------
OLD_COPY:
        DEFB    20h,0ECh,0CDh,13h,56h,0C3h,0FDh,1Ch
        DEFB    0CDh,6Fh,54h,3Ah,48h,54h,0C3h,71h
        DEFB    54h,0CDh,13h,56h,0C3h,22h,15h,0CDh
        DEFB    6Fh,54h,3Eh,18h,0CDh,71h,54h,3Eh
        DEFB    40h,0CDh,71h,54h,3Eh,01h,0C3h,71h
        DEFB    54h,0C5h,0D5h,0E5h,11h,95h,56h,06h
        DEFB    08h,0C5h,01h,28h,00h,0CDh,6Ch,56h
        DEFB    12h,13h,09h,0C1h,10h,0F3h,0Eh,08h
        DEFB    21h,9Ch,56h,06h,08h,0AFh,0CBh,0Eh
        DEFB    17h,2Bh,10h,0FAh,0CDh,71h,54h,0Dh
        DEFB    20h,0EEh,0E1h,0D1h,0C1h,0C9h,0AFh,01h
        DEFB    3Eh,2Fh,32h,7Fh,56h,32h,89h,56h
        DEFB    0C9h,0F3h,0D9h,0DBh,0E8h,0CBh,0FFh,0D3h
        DEFB    0E8h,08h,3Ah,19h,5Bh,4Fh,0CBh,87h
        DEFB    0D3h,0F4h,0D9h,7Eh,2Fh,0D9h,47h,79h
        DEFB    0CBh,0C7h,0D3h,0F4h,0D9h,7Eh,2Fh,0D9h
        DEFB    0B0h,08h,0CBh,0BFh,0D3h,0E8h,0D9h,08h
        DEFB    0FBh,0C9h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,3Ah,19h,5Bh,0F5h,0CBh,0C7h
        DEFB    0D3h,0F4h,0CDh,0BAh,56h,07h,47h

; ==============================================================================
;  RS-232C-ERWEITERUNG  (6600h-68ABh)
; ==============================================================================
;  Dieser Block ist die "besondere Anpassung" für die serielle Schnittstelle.
;  Er steht hinter dem GP-IB-Teil in einem Bereich, der vorher eine Kopie
;  von 560Bh-56A9h enthielt (siehe OLD_COPY bei 6561h), und wird über
;  drei neue Schlüsselwörter (Token 80h,E0h-E2h) angesprochen:
;
;    RSMODE {A|B} [,R n] [,T n] [,M n] [,RX n]
;         A/B   Kanal wählen (A = Ports B0h/B1h, B = Ports B2h/B3h)
;         R n   Empfangs-Datenbits 5..8   (SIO WR3 Bit 7-6)
;         T n   Sende-Datenbits 5..8      (SIO WR5 Bit 6-5)
;         M n   Byte für SIO WR4 direkt (Taktteiler, Stoppbits, Parität)
;         RX n  n<>0: Empfänger ein, Ringpuffer leeren, Interrupts ein;
;               n=0: Empfänger aus. RX beendet die Anweisung.
;    RSO {A|B}, ausdruck     Zahl/String senden, danach CR (0Dh)
;    RSI {A|B}, variablen    eine Zeile bis CR aus dem Ringpuffer lesen und
;                            wie bei GP-IB "RED" den Variablen zuweisen
;
;  Hardware: Z80-SIO an Ports B0h-B3h (A-Daten, A-Steuer., B-Daten, B-Steuer.).
;  Die Baudrate wird nicht per Software eingestellt (kein Zugriff auf einen
;  Baudratengenerator) – sie kommt vom Takt der Schnittstellenkarte.
;
;  Empfang läuft interruptgesteuert (IM 2): I-Register = 66h, Vektoren ab
;  6600h. Jeder Kanal hat einen 256-Byte-Ringpuffer genau auf einer Seite
;  (A: 6900h-69FFh, B: 6A00h-6AFFh); die Zeiger werden nur über L erhöht.
;  Grundeinstellung (SIO_INITTAB): 8 Datenbits, gerade Parität, 2 Stoppbits,
;  Takt x16, DTR und RTS aktiv, Sender ein, Empfänger aus.
;
;  Fehlernummern dieser Erweiterung:
;    29 Framing   30 Überlauf (SIO)   31 Parität   32 Sende-Timeout
;    33 Ringpuffer voll
;
;  Eingebunden wird der Block durch:
;    - Einträge 96-98 in STMT_TAB (1E5Dh) und RSO/RSI/RSMODE in KWTAB_STMT,
;    - JP SIO_INIT am Ende von IO_INIT (5F03h), d.h. beim BASIC-Start und
;      nach Fehlern wird die SIO neu initialisiert.
;  Viele Befehle hier ändern Operanden anderer Befehle (selbstmodifizierender
;  Code), um denselben Code für beide Kanäle zu nutzen.
SIO_VECTORS:
        DEFW    MON_RESET               ; SIO Kanal B: Sendepuffer leer (nicht benutzt)
        DEFW    MON_RESET               ; SIO Kanal B: Ext./Status (nicht benutzt)
        DEFW    SIO_RXB_INT             ; SIO Kanal B: Zeichen empfangen
        DEFW    SIO_SPB_INT             ; SIO Kanal B: Sonderempfangsbedingung
        DEFW    MON_RESET               ; SIO Kanal A: Sendepuffer leer (nicht benutzt)
        DEFW    MON_RESET               ; SIO Kanal A: Ext./Status (nicht benutzt)
        DEFW    SIO_RXA_INT             ; SIO Kanal A: Zeichen empfangen
        DEFW    SIO_SPA_INT             ; SIO Kanal A: Sonderempfangsbedingung

; ------------------------------------------------------------------------------
;  Ringpuffer-Zeiger (je 16 Bit, High-Byte = Pufferseite)
; ------------------------------------------------------------------------------
RXA_WR: DEFB    00h,00h                 ; Schreibzeiger Ringpuffer Kanal A (Seite 69xxh)
RXA_RD: DEFB    00h,00h                 ; Lesezeiger  Ringpuffer Kanal A
RXB_WR: DEFB    00h,00h                 ; Schreibzeiger Ringpuffer Kanal B (Seite 6Axxh)
RXB_RD: DEFB    00h,00h                 ; Lesezeiger  Ringpuffer Kanal B
RS_FLAG:
        DEFB    00h                     ; wird bei RSMODE RX gelöscht, sonst nirgends benutzt

; ------------------------------------------------------------------------------
;  SIO_INIT – beide SIO-Kanäle mit SIO_INITTAB programmieren, Vektor setzen.
;  Aufruf: am Ende von IO_INIT (BASIC-Start), nach BREAK in RSI und nach
;  Empfangsfehlern.  Hinterlässt DI – die Interrupts werden erst durch
;  RSMODE ...,RX n (oder anderen Code mit EI) wieder freigegeben.
; ------------------------------------------------------------------------------
; <- aufgerufen von 67C4h, 6823h, 6857h
SIO_INIT:
        DI                              ; keine Unterbrechungen während der SIO-Programmierung
        LD      HL,SIO_VECTORS          ; HL = Basis der Vektortabelle
        LD      A,H                     ; High-Byte -> I-Register (IM 2 ist seit 00A7h aktiv)
        LD      I,A
        LD      A,L                     ; Low-Byte (00h) ...
        LD      (SIO_INITTAB+4),A       ; ... als Interruptvektor in den WR2-Eintrag der Tabelle
        LD      BC,0DB1h                ; B = 13 Bytes, C = SIO_AC (Kanal A Steuerung)
        LD      HL,SIO_INITTAB
        OTIR                            ; Kanal A initialisieren
        LD      BC,0DB3h                ; B = 13 Bytes, C = SIO_BC (Kanal B Steuerung)
        LD      HL,SIO_INITTAB
        OTIR                            ; Kanal B initialisieren (WR2 = Vektor gilt für beide Kanäle)
        RET

; ------------------------------------------------------------------------------
;  SIO_SETMODE – WR4, WR1, WR3, WR5 aus der Tabelle an den gewählten Kanal
;  schicken und die Datenbit-Maske in den passenden Empfangs-Interrupt
;  eintragen.  Der Kanal steht im Operanden von "LD C,..." (6636h).
; ------------------------------------------------------------------------------
; <- aufgerufen von 6651h, 66B0h
SIO_SETMODE:
        LD      C,0B3h                  ; C = Steuerport; Operand 6636h wird von RSMODE A/B gesetzt (B1h/B3h)
        LD      B,08h                   ; 8 Bytes: WR4, WR1, WR3, WR5 (jeweils Register + Wert)
        PUSH    AF
        LD      A,C
        CP      0B3h                    ; Kanal B?
        LD      A,(RX_MASK)             ; aktuelle Datenbit-Maske (1Fh/3Fh/7Fh/FFh)
        JR      NZ,SSM_MASKA
        LD      (RXB_MASK+1),A          ; -> AND-Maske im Empfangs-Interrupt Kanal B
        JR      SSM_OUT
SSM_MASKA:
        LD      (RXA_MASK+1),A          ; -> AND-Maske im Empfangs-Interrupt Kanal A
SSM_OUT:
        POP     AF
        LD      HL,SIO_INITTAB+5        ; Zeiger auf "04h,WR4,01h,WR1,03h,WR3,05h,WR5" in SIO_INITTAB
        OTIR                            ; Register an die SIO ausgeben
        RET
RSM_DONE:
        CALL    SIO_SETMODE             ; Statement-Ende: Einstellungen übernehmen ...
        JP      NEXTSTMT                ; ... und mit der nächsten Anweisung weitermachen

; ------------------------------------------------------------------------------
;  ST_RSMODE – Anweisung RSMODE (Token 80h,E2h)
;  Schleife über die Optionen A, B, R n, T n, M n, RX n (durch Kommas
;  getrennt).  Die Werte landen in SIO_INITTAB und werden am Ende (oder bei
;  RX) an die SIO übertragen.
; ------------------------------------------------------------------------------
ST_RSMODE:
        DI                              ; Interrupts aus (Achtung: nur der RX-Zweig schaltet sie wieder ein)
        CALL    SKIPCOMMA               ; optionales Komma überlesen
        CALL    CHRGET                  ; nächstes Zeichen; Z = Anweisungsende
        LD      (TXTPTR),HL             ; Textzeiger merken
        JR      Z,RSM_DONE
        INC     HL
        CP      41h                     ; RSMODE A ...
        LD      B,0B1h                  ; ... Kanal A = Steuerport B1h
        JR      Z,RSM_CHAN
        CP      42h                     ; RSMODE B ...
        LD      B,0B3h                  ; ... Kanal B = Steuerport B3h
        JR      NZ,RSM_R
RSM_CHAN:
        LD      A,B
        LD      (SIO_SETMODE+1),A       ; Port in SIO_SETMODE eintragen (selbstmodifizierend)
        JR      ST_RSMODE
RSM_R:  CP      52h                     ; R (Empfang) ?
        JR      NZ,RSM_T
        CALL    SKIPSP                  ; nächstes Zeichen ansehen
        CP      58h                     ; RX n: Empfänger ein/aus
        JR      NZ,RSM_RBITS
        INC     HL
        CALL    EVAL_BYTE               ; n auswerten (0..255) -> E
        PUSH    HL
        LD      A,E
        OR      A
        LD      A,(SIO_INITTAB+10)      ; WR3-Wert aus der Tabelle
        RES     0,A                     ; Rx Enable aus
        JR      Z,RSM_RXSET             ; n = 0 -> Empfänger aus
        SET     0,A                     ; n <> 0 -> Rx Enable ein
        LD      HL,RS_FLAG
        LD      (HL),00h
        LD      HL,SIO_SETMODE+1        ; Adresse des Port-Operanden in SIO_SETMODE
        BIT     1,(HL)                  ; Bit 1 des Ports: 0 = B1h (Kanal A), 1 = B3h (Kanal B)
        LD      HL,6900h                ; Ringpuffer Kanal A = 6900h-69FFh
        LD      (RXA_WR),HL             ; Schreib- und Lesezeiger zurücksetzen (Puffer leer)
        LD      (RXA_RD),HL
        JR      Z,RSM_RXSET             ; Kanal A -> fertig
        LD      HL,6A00h                ; Ringpuffer Kanal B = 6A00h-6AFFh (A wurde oben mit zurückgesetzt)
        LD      (RXB_WR),HL
        LD      (RXB_RD),HL
RSM_RXSET:
        LD      D,A                     ; D = neuer WR3-Wert
        CALL    SIO_SETMODE             ; WR4/WR1/WR3/WR5 schreiben, Maske setzen
        LD      HL,SIO_SETMODE+1        ; C = Steuerport des gewählten Kanals
        LD      C,(HL)
        LD      A,03h                   ; WR0: Zeiger auf WR3
        OUT     (C),A
        OUT     (C),D                   ; WR3 mit/ohne Rx Enable
        POP     HL
        EI                              ; Interrupts wieder zulassen (Empfang läuft ab jetzt)
        JP      NEXTSTMT_HL             ; RX beendet die Anweisung
RSM_RBITS:
        CALL    GET_BITS                ; R n: Empfangs-Datenbits (5..8)
        LD      E,A
        LD      A,(SIO_INITTAB+10)      ; WR3: Bits 7-6 = Rx Bits/Zeichen
        AND     3Fh
        OR      E
        LD      (SIO_INITTAB+10),A
RSM_NEXT:
        JR      ST_RSMODE
RSM_T:  CP      54h                     ; T n: Sende-Datenbits?
        JR      NZ,RSM_M
        CALL    GET_BITS                ; Bitcode in Bits 7-6 ...
        RRCA                            ; ... nach Bits 6-5 schieben
        LD      E,A
        LD      A,(SIO_INITTAB+12)      ; WR5: Bits 6-5 = Tx Bits/Zeichen
        AND     9Fh
        OR      E
        LD      (SIO_INITTAB+12),A
        JR      RSM_NEXT
RSM_M:  CP      4Dh                     ; M n: WR4 (Takt, Stoppbits, Parität) direkt setzen
        JP      NZ,ERR_01
        CALL    EVAL_BYTE
        LD      A,E
        LD      (SIO_INITTAB+6),A       ; neuer WR4-Wert in die Tabelle
        JR      RSM_NEXT

; ------------------------------------------------------------------------------
;  GET_BITS – Datenbitanzahl n (5..8) lesen.
;  Ausgang: A = SIO-Bitcode in Bit 7-6, RX_MASK = passende AND-Maske.
; ------------------------------------------------------------------------------
; <- aufgerufen von 66C2h, 66D5h
GET_BITS:
        CALL    EVAL_BYTE               ; n = Anzahl Datenbits 5..8
        LD      A,E
        SUB     05h                     ; -> 0..3
        CP      04h
        JP      NC,ERR_03               ; sonst Fehler 3
        PUSH    AF
        PUSH    HL
        LD      HL,MASKTAB              ; Maskentabelle 1Fh,3Fh,7Fh,FFh
        ADD     A,L
        LD      L,A
        LD      A,(HL)
        LD      (RX_MASK),A             ; Maske für empfangene Zeichen merken
        POP     HL
        POP     AF
        CP      01h                     ; SIO-Code: 5 Bit=00, 6 Bit=10, 7 Bit=01, 8 Bit=11
        JR      Z,GB_SWAP
        CP      02h
        JR      NZ,GB_SHIFT
GB_SWAP:
        XOR     03h                     ; 6 <-> 7 Bit vertauschen
GB_SHIFT:
        RRCA                            ; Code nach Bits 7-6 bringen
        RRCA
        RET

; ------------------------------------------------------------------------------
;  ST_RSO – Anweisung RSO {A|B}, ausdruck   (Token 80h,E0h)
;  Wandelt den Ausdruck in einen String und sendet ihn zeichenweise,
;  abgeschlossen mit CR.  Kein Hardware-Handshake (siehe SP_CTSWAIT).
; ------------------------------------------------------------------------------
ST_RSO: CALL    SKIPSP                  ; Kanalbuchstabe A/B lesen
        INC     HL
        CP      41h                     ; 'A'
        LD      B,0B1h                  ; Kanal A: Steuerport B1h
        JR      Z,RSO_CHAN
        CP      42h                     ; 'B'
        LD      B,0B3h                  ; Kanal B: Steuerport B3h
        JP      NZ,ERR_01
RSO_CHAN:
        LD      A,B
        LD      (SP_WR0+1),A            ; Port für WR0-Ausgabe in SIO_PUT eintragen
        LD      (SP_RR0+1),A            ; Port für RR0-Abfrage
        DEC     A                       ; Datenport = Steuerport - 1 (B0h/B2h)
        LD      (SP_OUT+1),A            ; ... für die Zeichenausgabe
        CALL    EVAL_EXPR               ; Ausdruck auswerten (Zahl oder String)
        PUSH    HL
        CALL    VAL2STRBUF              ; als String nach 6B0Dh; DE = Adresse, BC = Länge, Z = leer
        JR      Z,RSO_END
        INC     BC                      ; ein Zeichen mehr senden: das abschließende 0Dh (CR)
RSO_LOOP:
        LD      A,(DE)                  ; nächstes Zeichen
        CALL    SIO_PUT                 ; senden (mit Timeout)
        JP      C,ERR_32                ; Timeout -> Fehler 32
        INC     DE
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,RSO_LOOP
RSO_END:
        POP     HL
        JP      NEXTSTMT_HL

; ------------------------------------------------------------------------------
;  SIO_PUTx / SIO_PUT – ein Zeichen senden (Polling von RR0 Bit 2).
;  Eingang A = Zeichen.  Ausgang CY = 1 bei Timeout, sonst CY = 0.
;  Die Portnummern stehen als Operanden in SP_WR0, SP_RR0 und SP_OUT.
; ------------------------------------------------------------------------------
SIO_PUTB:
        PUSH    AF                      ; Zeichen in A über Kanal B senden (nicht referenziert)
        LD      A,0B3h
        JR      SIO_PUTSEL
; <- aufgerufen von 6894h
SIO_PUTA:
        PUSH    AF                      ; Zeichen in A über Kanal A senden (von RS_CONIN benutzt)
        LD      A,0B1h
SIO_PUTSEL:
        LD      (SP_WR0+1),A            ; Ports in SIO_PUT eintragen
        LD      (SP_RR0+1),A
        DEC     A
        LD      (SP_OUT+1),A
        POP     AF
; <- aufgerufen von 673Fh
SIO_PUT:
        PUSH    AF                      ; Zeichen in A senden; CY = 1 bei Timeout
        PUSH    DE
        LD      DE,0000h                ; Timeout-Zähler 65536 Durchläufe
SP_POLL:
        LD      A,10h                   ; WR0-Kommando 2: Reset Ext/Status-Interrupts ...
SP_WR0: OUT     (SIO_AC),A              ; ... (aktualisiert die Statusbits in RR0)
        NOP
SP_RR0: IN      A,(SIO_AC)              ; RR0 lesen
        BIT     2,A                     ; Bit 2 = Sendepuffer leer?
        JR      NZ,SP_SEND              ; ja -> senden
        DEC     DE
        LD      A,D
        OR      E
        JR      NZ,SP_POLL
        POP     DE
        POP     AF
        SCF                             ; Timeout: CY = 1
        RET
SP_CTSWAIT:
        PUSH    BC                      ; unerreichbar: Variante mit CTS-Abfrage (RR0 Bit 5) und Verzögerung
        PUSH    AF
        LD      BC,0800h
SPCTS_DLY:
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,SPCTS_DLY
        POP     AF
        POP     BC
        BIT     5,A                     ; CTS aktiv?
        JR      Z,SP_POLL
SP_SEND:
        POP     DE
        POP     AF
SP_OUT: OUT     (SIO_AD),A              ; Zeichen an den Datenport (Operand selbstmodifizierend)
        OR      A                       ; CY = 0: OK
        RET

; ------------------------------------------------------------------------------
;  ST_RSI – Anweisung RSI {A|B}, variablenliste   (Token 80h,E1h)
;  Wartet (BREAK-abfragend), bis im Ringpuffer eine komplette Zeile mit CR
;  steht, kopiert sie nach 6B0Dh und übergibt an den Zuweisungscode der
;  GP-IB-Anweisung RED (60CCh).
; ------------------------------------------------------------------------------
ST_RSI: CALL    SKIPSP                  ; Kanalbuchstabe A/B lesen
        INC     HL
        LD      (TXTPTR),HL
        CP      41h                     ; 'A'
        LD      HL,RXA_WR               ; Kanal A: Schreibzeiger ...
        LD      (RSI_CHK+2),HL          ; ... für den Vergleich in RSI_CHK
        LD      HL,RXA_RD               ; Lesezeiger Kanal A
        JR      Z,RSI_SETPTR
        CP      42h                     ; 'B'
        JP      NZ,ERR_01
        LD      HL,RXB_WR               ; Kanal B: Schreibzeiger
        LD      (RSI_CHK+2),HL
        LD      HL,RXB_RD               ; Lesezeiger Kanal B
RSI_SETPTR:
        LD      (RSI_WAIT+1),HL         ; Adresse des Lesezeigers in drei Befehle eintragen
        LD      (RSI_COPY+1),HL
        LD      (RSI_DONE+1),HL
RSI_WAIT:
        LD      HL,(RXA_RD)             ; HL = Lesezeiger (Operand selbstmodifizierend)
RSI_WAIT2:
        CALL    BRKCHK                  ; BREAK gedrückt?
        JR      NZ,RSI_CHK
RSI_BREAK:
        CALL    SIO_INIT                ; BREAK: SIO neu initialisieren ...
        CALL    CONT_CLR
        JP      BREAK                   ; ... und "*Break" melden
RSI_CHK:
        LD      BC,(RXA_WR)             ; BC = Schreibzeiger (Operand selbstmodifizierend)
        LD      A,L
        CP      C                       ; Puffer leer -> weiter warten
        JR      Z,RSI_WAIT2
RSI_SCAN:
        LD      A,0Dh                   ; nach CR (Zeilenende) suchen
        CP      (HL)
        JR      Z,RSI_COPY
        INC     L                       ; nächstes Byte (Wrap innerhalb der 256-Byte-Seite)
        LD      A,L
        CP      C                       ; Schreibzeiger erreicht, noch kein CR -> warten
        JR      Z,RSI_WAIT
        CALL    BRKCHK
        JR      Z,RSI_BREAK
        JR      RSI_SCAN
RSI_COPY:
        LD      HL,(RXA_RD)             ; vollständige Zeile: HL = Lesezeiger
        LD      DE,INBUF                ; Ziel: Eingabepuffer 6B0Dh
        PUSH    DE
        LD      BC,0000h
RSI_CLOOP:
        LD      A,(HL)                  ; Zeile bis einschließlich CR kopieren
        LD      (DE),A
        INC     L                       ; Ringpuffer: nur L erhöhen
        INC     DE
        INC     BC
        CP      0Dh
        JR      NZ,RSI_CLOOP
RSI_DONE:
        LD      (RXA_RD),HL             ; neuen Lesezeiger speichern
        DEC     BC                      ; BC = Länge ohne CR
        POP     DE
        JP      RED_PARSE                   ; Variablen zuweisen wie bei GP-IB "RED" (gemeinsamer Code)

; ------------------------------------------------------------------------------
;  SIO_INITTAB – 13 Bytes, per OTIR an den Steuerport (Register, Wert):
;    18h          WR0: Kanal-Reset
;    10h,10h      WR0: Reset Ext/Status-Interrupts (2x)
;    02h,00h      WR2: Interruptvektor (Low-Byte, von SIO_INIT eingetragen)
;    04h,4Fh      WR4: Takt x16, 2 Stoppbits, Parität gerade+aktiv  (RSMODE M)
;    01h,14h      WR1: Rx-Interrupt bei jedem Zeichen, "Status affects vector"
;    03h,C0h      WR3: Rx 8 Bit, Empfänger aus                       (RSMODE R/RX)
;    05h,EAh      WR5: DTR, Tx 8 Bit, Sender ein, RTS                 (RSMODE T)
; ------------------------------------------------------------------------------
SIO_INITTAB:
        DEFB    18h,10h,10h,02h,00h,04h,4Fh,01h  ; WR0: Kanal-Reset
        DEFB    14h,03h,0C0h,05h,0EAh

; ------------------------------------------------------------------------------
;  Interrupt-Routinen (IM 2, Vektoren in SIO_VECTORS)
;  Empfang: Zeichen maskieren, in den Ringpuffer schreiben, Schreibzeiger
;  erhöhen.  Holt der Schreibzeiger den Lesezeiger ein, ist der Puffer voll:
;  SIO zurücksetzen und Fehler 33 – direkt aus der Interrupt-Routine
;  heraus (der BASIC-Fehlerhandler setzt den Stack zurück).
; ------------------------------------------------------------------------------
SIO_RXA_INT:
        PUSH    AF                      ; Empfangs-Interrupt Kanal A
        PUSH    HL
        IN      A,(SIO_AD)              ; empfangenes Zeichen
RXA_MASK:
        AND     0FFh                    ; auf Datenbits maskieren (Operand von SIO_SETMODE gesetzt)
        LD      HL,(RXA_WR)             ; in den Ringpuffer schreiben
        LD      (HL),A
        INC     L                       ; nur L erhöhen: Puffer = genau eine 256-Byte-Seite
        LD      (RXA_WR),HL
        LD      A,L                     ; neuer Schreibzeiger (Low) mit ...
        LD      HL,(RXA_RD)             ; ... dem Lesezeiger vergleichen
RX_CHKFULL:
        CP      L
        JR      NZ,RX_EXIT              ; nicht gleich -> OK
        CALL    SIO_INIT                ; Puffer übergelaufen: SIO zurücksetzen
        JP      ERR_33                  ; Fehler 33 (direkt aus dem Interrupt heraus)
RX_EXIT:
        POP     HL
        POP     AF
        EI
        RETI                            ; Interrupt beenden
SIO_RXB_INT:
        PUSH    AF                      ; Empfangs-Interrupt Kanal B (wie oben)
        PUSH    HL
        IN      A,(SIO_BD)
RXB_MASK:
        AND     0FFh
        LD      HL,(RXB_WR)
        LD      (HL),A
        INC     L
        LD      (RXB_WR),HL
        LD      A,L
        LD      HL,(RXB_RD)
        JR      RX_CHKFULL

; ------------------------------------------------------------------------------
;  Sonderempfangsbedingung: RR1 lesen und als BASIC-Fehler 29/30/31 melden.
; ------------------------------------------------------------------------------
SIO_SPA_INT:
        LD      A,0B1h                  ; Sonderempfangsbedingung Kanal A
        JR      SP_INT
SIO_SPB_INT:
        LD      A,0B3h                  ; Sonderempfangsbedingung Kanal B
SP_INT: LD      (SPI_WR0+1),A           ; Steuerport in die beiden folgenden Befehle eintragen
        LD      (SPI_RR1+1),A
        LD      A,01h                   ; WR0: Zeiger auf RR1
SPI_WR0:
        OUT     (SIO_AC),A
SPI_RR1:
        IN      A,(SIO_AC)              ; RR1 lesen
        AND     70h                     ; Bit 6 Framing, Bit 5 Überlauf, Bit 4 Parität
        PUSH    AF
        CALL    SIO_INIT                ; SIO zurücksetzen
        POP     AF
        BIT     6,A
        JP      NZ,ERR_29               ; Fehler 29: Framing
        BIT     5,A
        JP      NZ,ERR_30               ; Fehler 30: Überlauf
        JP      ERR_31                  ; sonst Fehler 31: Parität

; ------------------------------------------------------------------------------
;  RXA_GET – Zeichen aus dem Ringpuffer von Kanal A holen.
;  Ausgang: CY = 1 und A = Zeichen, oder CY = 0 wenn der Puffer leer ist.
; ------------------------------------------------------------------------------
; <- aufgerufen von 688Ah
RXA_GET:
        PUSH    BC                      ; Zeichen aus Ringpuffer A holen (nicht blockierend)
        PUSH    HL
        LD      HL,(RXA_RD)
        LD      BC,(RXA_WR)
        LD      A,L
        CP      C                       ; Puffer leer -> CY = 0 (aus CP)
        JR      Z,RXG_EXIT
        LD      A,(HL)                  ; Zeichen holen
        INC     L
        LD      (RXA_RD),HL
        SCF                             ; CY = 1: Zeichen in A
RXG_EXIT:
        POP     HL
        POP     BC
        RET

; ------------------------------------------------------------------------------
;  RS_TERM – NICHT REFERENZIERT (vermutlich für USR gedacht)
;  Leitet die Tastatureingabe um: RS_CONIN liefert Zeichen von der
;  RS-232C (Kanal A) oder von der Tastatur und schickt Tastendrücke über
;  Kanal A hinaus ("Terminal").  Der Patch zielt auf 06E0h; in diesem
;  Monitor steht dort aber der Opcode von "CALL KEYSCAN" (06E0h = CDh,
;  Operand ab 06E1h).  Die Routine passt also offenbar zu einer anderen
;  Monitor-Version und würde hier den Code zerstören.
; ------------------------------------------------------------------------------
RS_TERM:
        CALL    EVAL_BYTE               ; Parameter: 0 = aus, sonst ein
        LD      A,E
        OR      A
        JR      Z,RST_KBD
        LD      HL,RS_CONIN             ; neue Eingaberoutine: RS_CONIN
        JR      RST_PATCH
RS_CONIN:
        CALL    RXA_GET                 ; Zeichen von der RS-232C da?
        RET     C                       ; ja -> zurückgeben
        CALL    GETKEY                  ; sonst Tastatur abfragen
        CP      1Eh                     ; 1Eh = keine Taste
        RET     Z
        CALL    SIO_PUTA                ; Taste über Kanal A senden
        JP      C,ERR_32                ; Timeout -> Fehler 32
        RET
RST_KBD:
        LD      HL,GETKEY               ; normale Tastaturroutine
RST_PATCH:
        LD      (GL_KEYCALL),HL              ; ACHTUNG: Patch-Adresse passt nicht zu diesem Monitor (siehe oben)
        JP      BAS_READY               ; BASIC-Warmstart ("Ready")
RS_STUB:
        JP      NEXTSTMT_HL             ; nicht referenziert

; ------------------------------------------------------------------------------
;  Datenbit-Maske und Maskentabelle (5/6/7/8 Bit)
; ------------------------------------------------------------------------------
RX_MASK:
        DEFB    0FFh                    ; aktuelle Datenbit-Maske (Vorgabe FFh = 8 Bit)
MASKTAB:
        DEFB    1Fh,3Fh,7Fh,0FFh        ; Masken für 5, 6, 7, 8 Datenbits

; ==============================================================================
;  ENDE DES CODES – Füllbereiche
; ==============================================================================
        IF      $ > 6900h
        .ERROR  Code reicht über 6900h (RS-232C-Puffer); OLD_COPY entfernen oder kürzen
        ENDIF
FILL_FREE:
        DEFS    6900h-$,0FFh            ; frei bis 6900h (wächst/schrumpft mit dem Code)
FILL_RTAREA:
        DEFS    7000h-6900h,0FFh        ; zur Laufzeit RS-232C-Puffer und BASIC-Arbeitsbereich
FILL_END:
        DEFS    7E00h-7000h,0BFh        ; Füllung bis zum Ende des Abbilds (7E00h Bytes)

        END

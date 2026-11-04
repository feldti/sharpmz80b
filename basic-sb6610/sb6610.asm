;==============================================================================
;  SHARP MZ-80B  –  Double precision BASIC SB-6610 mit Monitor SB-1510
;==============================================================================
;  Quelle : sb6610/Disk Basic6610ipl.mzf
;           MZF-Header: Attribut 01h (Maschinenprogramm), Name "Disk Basic",
;           Länge 7E00h, Ladeadresse 0000h, Startadresse 0000h.
;           Wird wie SB-6511 vom IPL nach 8000h geladen und läuft nach dem
;           "Normal Start" ab 0000h.
;
;  Reassemblierbar mit pasmo; ergibt bytegleich die 7E00h Bytes des Images
;  (ohne den 128-Byte-MZF-Header).
;
;  Herkunft dieser Quelle
;  ----------------------
;  Ausgangspunkt war eine von tools/port_sb6610.py aus SB6511_RS232.asm
;  erzeugte Fassung; seitdem wird diese Datei direkt gepflegt. Zeilen, deren
;  Bytes (bis auf Adressen) mit SB-6511 übereinstimmen, tragen Namen und
;  Kommentare von dort. Weicht ein Befehl ab, steht der alte Befehl als
;  "[SB-6511: ...]" im Kommentar. "; >>> SB-6610: ohne Gegenstück in
;  SB-6511" markiert neuen Code. Adressen in übernommenen Kommentaren (Code
;  und Arbeitsspeicher) sind auf SB-6610 umgerechnet. Übrig sind nur Marken
;  der Form Dxxxx an Inline-Parametern.
;
;  Unterschiede zu SB-6511
;  -----------------------
;  - Monitor SB-1510 (0000h-1221h) gleich bis auf IM 1 statt IM 2 (keine SIO).
;  - Zahlen in BCD, 9 Bytes: 16 Ziffern Mantisse + Exponentbyte, ganze
;    Zahlen exakt (Format bei FPA_FLAG). Arithmetik, SQR, INT, RND und die
;    Wandlungen STR2NUM/NUM2STR sind neu; ^, SIN, COS, TAN, ATN, EXP, LOG,
;    LN und APPEND fehlen (Syntax Error).
;  - Ohne GP-IB- und RS-232C-Erweiterung; deren Token sind frei (FFh), in
;    freien Plätzen von DEVTAB_PRINT steht Code (INT_FINISH).
;  - Neu: PRINT [/P] USING schablone; ... (Token 9Dh, PR_USING/NUM_OUT),
;    DELETE a-b löscht Programmzeilen (ST_DELLINES), LIST_LOCK sperrt
;    LIST/SAVE, Druckerbreite 80/136 Zeichen (PRN_DOTW).
;  - Arbeitsbereich des BASIC ab 6000h (SB-6511: 6000h); der Code endet
;    genau bei 6000h. 5A13h-5CFFh wird nicht erreicht (Reste), 6000h-6FFFh
;    enthält im Abbild Bruchstücke von Sharps Assembler-Quelltext.
;
;  Fassungen
;  ---------
;  Dieses Abbild ist auch auf disketten-2/DISK8.DSK und DISK16.DSK. Auf
;  disketten/DISK26.DSK liegt eine ältere Fassung (76 Bytes anders): ohne
;  die Korrekturen INT_FINISH (FN_INT springt dort direkt nach FP_INTFORM,
;  INT einer Zahl zwischen -1 und 0 kann "-0" ergeben), POINT_GET (FN_POINT
;  ruft GR_POINT direkt, BC geht verloren) und AREA_RESIZE_CLR (50DEh ruft
;  AREA_RESIZE direkt); MON_INIT programmiert die Bausteine dort mit
;  einzelnen OUT-Befehlen statt über IOINIT_TAB.
;
;  Handbuch: sb6610/Double_Precision_DISK_BASIC_MANUAL_nobmp_SB-6610.pdf
;  (Kapitel 2.4 beschreibt die Neuerungen: PRINT USING, DELETE, DIM,
;  fehlende Funktionen).
;
;  Token-Format wie SB-6511 (siehe dort bzw. docs/BEFEHLE.md).
;==============================================================================

FDC_CMD   EQU    0D8h    ; FDC MB8876 Kommando/Status (invertiert)
FDC_TRK   EQU    0D9h    ; FDC Spurregister
FDC_SEC   EQU    0DAh    ; FDC Sektorregister
FDC_DAT   EQU    0DBh    ; FDC Datenregister
FDD_SEL   EQU    0DCh    ; Floppy: Laufwerk/Motor
FDD_SID   EQU    0DDh    ; Floppy: Seitenwahl
PPI_A     EQU    0E0h    ; 8255 Port A (Kassette, Video)
PPI_B     EQU    0E1h    ; 8255 Port B (Kassette, BREAK, VBLANK)
PPI_CTL   EQU    0E3h    ; 8255 Steuerwort
PIT_C0    EQU    0E4h    ; 8253 PIT Zähler 0
PIT_C1    EQU    0E5h    ; 8253 PIT Zähler 1
PIT_C2    EQU    0E6h    ; 8253 PIT Zähler 2
PIT_CTL   EQU    0E7h    ; 8253 PIT Steuerwort
PIO_AD    EQU    0E8h    ; Z80-PIO Port A Daten (Tastaturzeile, VRAM)
PIO_BD    EQU    0EAh    ; Z80-PIO Port B Daten (Tastatur)
PIO_BC    EQU    0EBh    ; Z80-PIO Port B Steuerung
TMR_F0    EQU    0F0h    ; Timer/Ton F0
GRPH      EQU    0F4h    ; Grafik-VRAM Bank/Maske
PRN_CTL   EQU    0FEh    ; Drucker Steuerung/Status
PRN_DAT   EQU    0FFh    ; Drucker Daten

; Monitor-Variablen in den Lücken zwischen den RST-Vektoren (Auswahl)
MV_NOTELEN EQU    05h    ; MUSIC: zuletzt angegebene Notenlänge (0-9)
MV_PM     EQU    0Fh     ; Uhr: 0 vormittags, 1 nachmittags
MV_TISTART EQU    16h    ; Uhr: beim Stellen angegebene Sekunden (0-43199)
MV_TEMPO  EQU    1Dh     ; MUSIC: Tempofaktor = 8 - TEMPO
MV_C2LATCH EQU    1Eh    ; Uhr: zuletzt gelesener Stand von Zähler 2
MV_PERIOD EQU    36h     ; MUSIC: Halbperiode des aktuellen Tons (0 = Pause)

RAM_START EQU    6000h   ; Beginn des Arbeitsbereichs (RAM-Test ab hier, Code endet davor)
INBUF     EQU    600Dh   ; Eingabe-/Zeilenpuffer [SB-6511: 6B0Dh]
TOKLINE   EQU    610Eh   ; CRUNCH-Ergebnis als Programmzeile: Link (2), ... [SB-6511: 6C0Eh]
TOKLNUM   EQU    6110h   ; ... Zeilennummer (2, 0 = Direktmodus) und ... [SB-6511: 6C10h]
TOKTEXT   EQU    6112h   ; ... Tokentext bis 0Dh [SB-6511: 6C12h]
MEMTOP    EQU    6008h   ; oberes RAM-Ende (vom RAM-Test bei 1237h ermittelt) [SB-6511: 6B08h]
STKTOP    EQU    600Ah   ; Anfangswert des Stackpointers [SB-6511: 6B0Ah]
TAPEBUF   EQU    63D3h   ; Kassettendatei (ROPEN/WOPEN /T): Puffer für einen 256-Byte-Block [SB-6511: 6ED3h]
TAPEBUF_END EQU    64D3h ; ... Ende des Puffers [SB-6511: 6FD3h]
USING_PTR EQU    64D3h   ; PRINT USING: Zeiger auf die Ausgabe (USING_FMT), 0 = ohne USING
USING_FMT EQU    64D6h   ; PRINT USING: Ausgabe nach Schablone (Präfix, Ziffern, Suffix)
FC_IDX    EQU    65D3h   ; aktuelle Datei: Index 0-9 in FILETAB, danach Kopie des Eintrags: [SB-6511: 6FD3h]
FILE_NO   EQU    65D4h   ; Gerät/Datei: 1-127 = #n, 80h Bildschirm, 81h DATA (READ), [SB-6511: 6FD4h]
                         ; 82h Drucker (/P), 83h Kassette (/T)
FC_MODE   EQU    65D5h   ; Dateimodus: 0 lesen, 1 schreiben, 2 Sätze zu 32 Bytes ((n)) [SB-6511: 6FD5h]
FC_TYPE   EQU    65D6h   ; Dateityp/-gerät (Index für DEV_DISPATCH: +10) [SB-6511: 6FD6h]
FC_UNIT   EQU    65D7h   ; Laufwerk/Einheit (Puffer über 6664h + 2*n) [SB-6511: 6FD7h]
FC_VOL    EQU    65D8h   ; Volumennummer der Diskette (@n bzw. aus dem Verzeichnis) [SB-6511: 6FD8h]
FC_ENTRY  EQU    65DDh   ; Zeiger auf den Eintrag in FILETAB [SB-6511: 6FDDh]
FC_UNITBUF EQU    65DFh  ; Puffer der Einheit (UNIT_GETBUF) [SB-6511: 6FDFh]
FC_B00    EQU    65E1h   ; Zeiger in den Dateipuffer (320 Bytes, Bereich 6650h + 2*Index): [SB-6511: 6FE1h]
FC_B14    EQU    65E3h   ; ... +14h [SB-6511: 6FE3h]
FC_B1E    EQU    65E5h   ; ... +1Eh [SB-6511: 6FE5h]
FC_B20    EQU    65E7h   ; ... +20h [SB-6511: 6FE7h]
FC_B40    EQU    65E9h   ; ... +40h (Sektorpuffer) [SB-6511: 6FE9h]
FC_B13E   EQU    65EBh   ; ... +13Eh (Ende des Sektorpuffers, Folgesektor) [SB-6511: 6FEBh]
FILETAB   EQU    65F2h   ; Dateitabelle: 10 Einträge zu 9 Bytes, Byte 0 = Dateinummer [SB-6511: 6FF2h]
PRGEND    EQU    664Eh   ; Ende des Programms (hinter 00h 00h) = Beginn der Variablen; [SB-6511: 704Eh]
                         ; erster Eintrag der Bereichszeiger 664Eh-6695h (siehe AREAS_INIT)
P_DEFFN   EQU    6684h   ; Bereichszeiger: DEF FN (Name, Parameter, Text bis 0Dh) [SB-6511: 7084h]
P_ARRAYS  EQU    6686h   ; Bereichszeiger Felder: +0 Zahl 2-dim., +2 Zahl 1-dim., [SB-6511: 7086h]
                         ; +6 String 2-dim., +8 String 1-dim. (siehe ARR_FIND)
P_NUMVAR  EQU    668Ah   ; Bereichszeiger: Zahlvariablen (Name 2 + Wert 9 Bytes) [SB-6511: 708Ah]
P_STRVAR  EQU    6690h   ; Bereichszeiger: Stringvariablen (Name 2, Länge, Text, 0Dh) [SB-6511: 7090h]
P_STRTMP  EQU    6692h   ; Bereichszeiger: String-Zwischenergebnisse (STR_NEW) [SB-6511: 7092h]
VALSP     EQU    6694h   ; Zeiger auf den Werte-/Ausdrucksstack (9-Byte-Einträge) [SB-6511: 7094h]
FNPAR_SP  EQU    6696h   ; FN: gesicherte Parameter, 6 Bytes je Ebene, wächst abwärts [SB-6511: 7096h]
FNPAR_END EQU    669Ch   ; ... bis hierher (5 Ebenen ab 66BAh), sonst Fehler 12 [SB-6511: 709Ch]
FOR_SP    EQU    6698h   ; FOR-Stack: 27 Bytes je Eintrag (Kopie von FOR_VAR..TXTPTR), [SB-6511: 7098h]
                         ; wächst abwärts ab 684Fh, max. 15 Einträge
GOSUB_SP  EQU    669Ah   ; GOSUB-Stack: 7 Bytes je Eintrag (CURLINE, TXTPTR, FOR_CNT), [SB-6511: 709Ah]
                         ; wächst abwärts ab 68B8h, max. 15 Einträge
FOR_VAR   EQU    68B8h   ; FOR-Eintrag im Aufbau: Adresse der Laufvariablen (2), [SB-6511: 7240h]
FOR_STEP  EQU    68BAh   ; ... Schrittweite (9), [SB-6511: 7242h]
FOR_STEPSGN EQU  68C3h   ; ... Vorzeichenbyte der Schrittweite (1), [SB-6511: 7247h]
FOR_LIMIT EQU    68C4h   ; ... Endwert (9); danach CURLINE (4) und TXTPTR (2) [SB-6511: 7248h]
CURLINE   EQU    68CDh   ; aktuelle Programmzeile: Link (2) + Zeilennummer (2) [SB-6511: 724Dh]
CURLNUM   EQU    68CFh   ; aktuelle Zeilennummer, 0 = Direktmodus [SB-6511: 724Fh]
TXTPTR    EQU    68D1h   ; Textzeiger des Interpreters [SB-6511: 7251h]
FOR_CNT   EQU    68D3h   ; Anzahl FOR-Einträge der aktuellen GOSUB-Ebene [SB-6511: 7253h]
FOR_DEPTH EQU    68D4h   ; Anzahl FOR-Einträge insgesamt [SB-6511: 7254h]
GOSUB_DEPTH EQU    68D5h ; GOSUB-Tiefe [SB-6511: 7255h]
ONERR_FLAG EQU    68D7h  ; ON ERROR: 0 aus, 1 aktiv, 2 im Fehlerbehandler (RESUME erlaubt) [SB-6511: 7256h]
ONERR_LINE EQU    68D8h  ; ON ERROR GOTO: Zeilennummer des Behandlers [SB-6511: 7257h]
DATA_FLAG EQU    68DAh   ; READ: 1 = DATA_PTR zeigt in eine DATA-Zeile, 0 = neu suchen [SB-6511: 7259h]
DATA_PTR  EQU    68DBh   ; READ: nächstes Element in der aktuellen DATA-Anweisung [SB-6511: 725Ah]
PRGTXT    EQU    68DDh   ; Beginn des BASIC-Programmtextes [SB-6511: 725Ch]
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
; <- aufgerufen von 0008h
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
; <- aufgerufen von 0000h, 0066h
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
        IM      1                       ; Interrupt-Modus 1 (SB-6511: IM 2 für die SIO)
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
; <- aufgerufen von 0010h, 0018h, 0020h, 0028h, 0030h, 013Bh, 01BDh, 05CBh (+2 weitere)
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
; <- aufgerufen von 0173h
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
; <- aufgerufen von 01B5h, 4D53h, 4E2Ah
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
; <- aufgerufen von 01BAh, 4D5Ch, 4D83h, 4EAEh, 4EBEh
WRDATA: DI
        LD      D,02h
        LD      BC,(CMT_HSIZE)
        LD      HL,(CMT_HLOAD)
        JR      CMT_WRITE
; <- aufgerufen von 01D6h, 4C12h, 4E5Dh
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
; <- aufgerufen von 01EDh, 4C5Fh, 4CD1h, 4DBEh
RDDATA: DI
        LD      D,08h
        LD      BC,(CMT_HSIZE)
        LD      HL,(CMT_HLOAD)
        JR      CMT_READ
; <- aufgerufen von 0220h, 4BE7h
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
; <- aufgerufen von 0388h
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
; <- aufgerufen von 0468h, 4BC2h
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
; <- aufgerufen von 0208h, 02AAh, 4C07h, 4ECBh
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
; <- aufgerufen von 020Bh, 02ADh, 04B1h, 4C0Ah, 4CDAh, 4CE0h, 4E36h, 4E7Dh (+1 weitere)
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
; <- aufgerufen von 04D7h, 4BA3h
PPIA_OUT:
        OUT     (PPI_A),A
        JR      DLY_SHORT
; <- aufgerufen von 04A1h, 04EFh
CMT_PREPULSE:
        LD      A,0Bh
        CALL    PPC_PULSE
        DEC     A
        JR      PPC_PULSE
; <- aufgerufen von 04B7h, 4BAFh
CMT_REWCMD:
        CALL    KEYROW3
        CALL    CMT_IDLE
; <- aufgerufen von 4BA6h
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
; <- aufgerufen von 0210h, 04AEh, 04B4h, 04BAh, 4C0Fh
DLY_SHORT:
        PUSH    BC
        LD      BC,0123h
        JR      DLY_BC
; <- aufgerufen von 0475h, 0490h, 4BD1h
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
; <- aufgerufen von 055Eh
DLY_A_LP:
        DEC     A
        JP      NZ,DLY_A_LP
        RET
; ------------------------------------------------------------------------------
;  BRKCHK – BREAK-Taste abfragen: Z = gedrückt
; ------------------------------------------------------------------------------
; <- aufgerufen von 013Eh, 1D30h, 1EB8h, 51ADh, 51F1h
BRKCHK: CALL    KEYROW3
        IN      A,(PIO_BD)
        IN      A,(PIO_BD)
        AND     80h
        RET
; <- aufgerufen von 02E2h, 046Bh, 0FE0h, 4BC5h
BRKKEY: IN      A,(PIO_BD)
        CPL
        RLCA
        RET
; <- aufgerufen von 0457h, 04E9h, 0562h, 0FDDh, 4BB4h
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
; <- aufgerufen von 05E4h, 05EDh, 2DA3h
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
; <- aufgerufen von 00C8h, 05C5h, 12D3h, 3BABh
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
;  GL_KEYCALL: "CALL KEYSCAN" (bei SB-6511 patcht RS_TERM hier das
;  Opcode-Byte statt des Operanden; SB-6610 hat kein RS-232C).
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
; <- aufgerufen von 0817h, 083Bh, 085Ah
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
; <- aufgerufen von 0A68h
KEY_NONE:
        LD      HL,KEY_MODS
        LD      (HL),A
        JP      KEY_CLRSTATE
;  GL_ENTER – Anfang der logischen Zeile über LINE_TAB suchen, alle ihre
;  Bildschirmzeilen nach (DE) kopieren, 00h als Leerzeichen, Leerzeichen
;  am Ende entfernen, 0Dh anhängen.
; <- aufgerufen von 0812h, 082Ah, 0834h, 0851h
GL_ENTER:
        LD      HL,(CSR_XY)
        LD      E,H
GL_ENT_ROW:
        LD      BC,0028h
        CALL    LINE_FLAG
        EX      DE,HL
        LD      HL,(CSR_XY)
        JR      NZ,GL_ENT_UP
; <- aufgerufen von 07BCh
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
; <- aufgerufen von 076Eh
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
; <- aufgerufen von 0795h
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
; <- aufgerufen von 2B5Dh
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
; <- aufgerufen von 00B8h, 05B6h, 05BCh, 12A3h, 3BC8h, 4373h
CRLF_IF:
        LD      A,(CSR_COL)
        OR      A
        RET     Z
; <- aufgerufen von 0789h, 1387h, 138Ah
CRLF:   XOR     A
        LD      (CSR_COL),A
        LD      A,0Dh
        JP      DISPCTRL
; <- aufgerufen von 0107h, 012Fh, 05C2h, 08BEh, 0D3Bh, 2DA9h
PRTSPC: LD      A,20h                   ; ' '
        JP      PRTCHR
; <- aufgerufen von 382Ch
TABPOS: CALL    PRTSPC
        LD      A,(CSR_COL)
        OR      A
        RET     Z
TABPOS_LP:
        SUB     0Ah
        JR      C,TABPOS
        JR      NZ,TABPOS_LP
        RET
; <- aufgerufen von 05B9h, 05D5h, 0857h, 12D0h, 1304h, 1384h, 1531h, 1537h (+5 weitere)
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
; <- aufgerufen von 3B7Fh
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
; <- aufgerufen von 00BDh, 05E7h, 05F0h, 08BBh, 137Dh, 2D96h, 2DA6h, 2DB1h (+1 weitere)
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
; <- aufgerufen von 0D10h, 5875h
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
; <- aufgerufen von 0714h, 0874h, 0A6Bh
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
; <- aufgerufen von 0779h, 0823h, 0842h, 08B6h, 08F4h, 0948h, 0D15h
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
; <- aufgerufen von 0B26h, 0B8Bh, 0BE9h, 0C0Fh
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
; <- aufgerufen von 0B44h, 0C33h
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
; <- aufgerufen von 0C39h
CTL_SETCSR:
        LD      (CSR_XY),HL
        JR      CTL_RET
CTL_02: CALL    CSR_ATTOP
        JP      Z,CTL_RET
        DEC     H
        JR      CTL_SETCSR
; <- aufgerufen von 08A8h
CTL_03: LD      HL,(CSR_XY)
        LD      A,L
CTL_03_MAX:
        CP      27h                     ; '''
        JR      NC,CTL_03_NEWL
        INC     L
        JR      CTL_SETCSR
; <- aufgerufen von 0C19h
CTL_03_NEWL:
        LD      L,00h
        INC     H
        LD      A,(000Ch)
        CP      H
        JR      NC,CTL_SETCSR
        LD      H,A
        LD      (CSR_XY),HL
        JP      SCROLL_UP
; <- aufgerufen von 0BC8h
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
; <- aufgerufen von 06B4h, 0BE5h, 519Eh, 5A03h
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
; <- aufgerufen von 06D1h, 0863h, 0886h, 0B9Dh, 0BC5h
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
; <- aufgerufen von 5897h
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
; <- aufgerufen von 0078h, 5892h
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
; <- aufgerufen von 0038h
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
        DEFB    10h,11h,12h,13h,14h,15h,16h,17h; ?? |........|
        DEFB    18h,19h,38h,39h,1Ah,2Eh,2Bh,2Dh; ?? |..89..+-|
        DEFB    30h,31h,32h,33h,34h,35h,36h,37h; ?? |01234567|
        DEFB    1Bh,20h,0Dh,02h,01h,04h,03h,0Bh; ?? |. ......|
        DEFB    2Fh                     ; ?? |/|
;  KEYTAB_N_AZ/KEYTAB_S_AZ: Buchstabenbereiche, deren Bit 5 CHANGE umdreht.
KEYTAB_N_AZ:
        DEFB    41h,42h,43h,44h,45h,46h,47h,48h; ?? |ABCDEFGH|
        DEFB    49h,4Ah,4Bh,4Ch,4Dh,4Eh,4Fh,50h; ?? |IJKLMNOP|
        DEFB    51h,52h,53h,54h,55h,56h,57h; ?? |QRSTUVW|
KEYTAB_S:
        DEFB    58h,59h,5Ah,5Eh,5Ch,3Fh,2Eh,2Ch; ?? |XYZ^\?.,|
        DEFB    30h,31h,32h,33h,34h,35h,36h,37h; ?? |01234567|
        DEFB    38h,39h,3Ah,3Bh,2Dh,40h,5Bh,00h; ?? |89:;-@[.|
        DEFB    5Dh,00h,05h,07h,00h,00h,00h,00h; ?? |].......|
        DEFB    84h                     ; ?? |.|
KEYTAB_S_AZ:
        DEFB    61h,62h,63h,64h,65h,66h,67h,68h; ?? |abcdefgh|
        DEFB    69h,6Ah,6Bh,6Ch,6Dh,6Eh,6Fh,70h; ?? |ijklmnop|
KEYTAB_S_QR:
        DEFB    71h,72h                 ; ?? |qr|
KEYTAB_S_SW:
        DEFB    73h,74h,75h,76h,77h     ; ?? |stuvw|
KEYTAB_G:
        DEFB    78h,79h,7Ah,7Eh,7Ch,82h,3Eh,3Ch; ?? |xyz~|.><|
        DEFB    5Fh,21h,22h,23h,24h,25h,26h,27h; ?? |_!"#$%&'|
        DEFB    28h,29h,2Ah,2Bh,3Dh,60h,7Bh,00h; ?? |()*+=`{.|
        DEFB    7Dh,00h,06h,08h,00h,00h,00h,00h; ?? |}.......|
        DEFB    83h,98h,88h,86h,9Ah,9Eh,9Bh,99h; ?? |........|
        DEFB    80h,89h,90h,8Dh,8Fh,92h,94h,8Ch; ?? |........|
        DEFB    8Bh,97h,9Fh,96h,9Ch,8Ah,87h,95h; ?? |........|
        DEFB    85h,9Dh,8Eh,5Eh,5Ch,81h,0FFh,91h; ?? |...^\...|
;  TEMPO_SET – TEMPO n (1-7): MV_TEMPO = 8 - n (größer = langsamer).
; <- aufgerufen von 250Dh
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
; <- aufgerufen von 1253h, 204Dh
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
; <- aufgerufen von 283Dh, 34B7h
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
; <- aufgerufen von 0732h, 124Dh, 1527h
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
; <- aufgerufen von 24FAh
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
LENTAB:  ; Notenlänge 0-9 (Vielfache der Grundlänge)
        DEFB    01h,02h,03h,04h,06h,08h,0Ch,10h,18h,20h
NOTE_CYC        EQU     LENTAB+9        ; Schwingungen je Längeneinheit, Index = MUS_NOTEIDX (+7 bei #)
        DEFB    08h,0Fh,0Dh,0Ch,0Bh,0Ah,09h; Index 1-7: R B A G F E D
        DEFB    08h,10h,0Eh,0Dh,0Bh,0Bh,0Ah,08h; 8: C, 9-15: B# A# G# F# E# D# C#
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
        DEFB    00h,00h,00h,00h,00h,00h,00h; ?? |.......|
;  MON_ADRIN/MON_MIN/MON_NAMEIN: Positionen im Eingabepuffer hinter den
;  Prompts ("-ADR.$", Adresse beim *M, "FILE NAME:").
MON_ADRIN:
        DEFB    00h                     ; ?? |.|
MON_MIN:
        DEFB    00h,00h                 ; ?? |..|
MON_NAMEIN:
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,0FFh; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,0FFh; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,0FFh; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh; ?? |.......|
CMT_HEADER:
        DEFB    00h                     ; ?? |.|
CMT_HNAME:
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,0FFh; ?? |........|
CMT_HNAME_END:
        DEFB    0FFh                    ; ?? |.|
CMT_HSIZE:
        DEFB    0FFh,0FFh               ; ?? |..|
CMT_HLOAD:
        DEFB    0FFh,0FFh               ; ?? |..|
CMT_HEXEC:
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh; ?? |........|
        DEFB    0FFh,0FFh,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh; ?? |........|
        DEFB    0FFh,0FFh,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh; ?? |........|
        DEFB    0FFh,0FFh,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh; ?? |........|
        DEFB    0FFh,0FFh               ; ?? |..|
;  TABSTOPS: Tabulatorpositionen des Bildschirmeditors (1, 5, 10 ... 70).
TABSTOPS:
        DEFB    01h,05h,0Ah,0Fh,14h,19h,1Eh,23h; ?? |.......#|
        DEFB    28h,2Dh,32h,37h,3Ch,41h,46h,0FFh; ?? |(-27<AF.|
PPI_A_COPY:
        DEFB    0FFh                    ; ?? |.|
CSR_XY: DEFB    0FFh                    ; ?? |.|
CSR_Y:  DEFB    0FFh                    ; ?? |.|
LINE_TAB:
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
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
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh; ?? |........|
        DEFB    0FFh                    ; ?? |.|
FKEY_TAB:
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h             ; ?? |...|
;  FKEY_DEFEND: Ende der Vorbelegung der Funktionstasten (FKEY_END nach
;  dem Kaltstart).
FKEY_DEFEND:
        DEFB    00h,00h,00h,00h,00h,0FFh,0FFh,0FFh; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,0FFh,0FFh,0FFh; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,0FFh,0FFh,0FFh; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,0FFh,0FFh,0FFh; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh; ?? |......|
FKEY_LIMIT:
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh; ?? |........|
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,18h; ?? |........|
        DEFB    10h                     ; ?? |.|
; ==============================================================================
;  BASIC-INTERPRETER SB-6610
; ==============================================================================
;  BAS_COLD: Laufwerksnummer des IPL in den Autostart-Befehl
;  "RUN FDn"AUTO RUN"" eintragen, RAM-Ende suchen, Bildschirm,
;  Uhr, Einschaltmeldung, I/O-Init, Autostart.
; <- aufgerufen von 00AEh
BAS_COLD:
        LD      A,01h                   ; JP BAS_COLD bei 00AEh zu LD BC,nn entschärfen ...
        LD      (MON_GOBASIC),A
        LD      (AUTORUN_FLAG),A        ; ... und Autostart-Flag setzen
        LD      A,(IPL_DRIVE)           ; Laufwerksnummer vom IPL (0-3)
        ADD     A,31h                   ; -> "1".."4"
        LD      (AUTORUN_CMD+6),A       ; in "RUN FDn"AUTO RUN"" eintragen
        LD      HL,RAM_START-1          ; RAM-Test ab 6000h [SB-6511: LD HL,6AFFh]
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
        LD      DE,MSG_BASIC            ; "  Double precision BASIC  SB-6610"
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
; <- aufgerufen von 130Eh, 14E1h, 1C75h, 1D14h, 1E37h, 1F2Bh, 3E82h, 4D67h
BAS_READY:
        LD      SP,(STKTOP)
        CALL    MOTOR_OFF                   ; [SB-6511: CALL FD_MOTOR_OFF]
        XOR     A
        LD      (AUTORUN_FLAG),A
        LD      DE,MSG_READY
        CALL    MSGX
        LD      A,0FAh
        LD      (GL_MAXLEN),A
; <- aufgerufen von 130Bh, 1338h, 1365h
BAS_MAIN:
        LD      HL,BAS_DIRECT
        PUSH    HL
;  INLINE – Eingabezeile nach INBUF holen (DE = INBUF beim Rücksprung).
;  Löscht CURLINE/CURLNUM (Direktmodus). Bei Autostart wird AUTORUN_CMD
;  kopiert; bei AUTO wird die nächste Zeilennummer (AUTO_LINE, danach um
;  AUTO_STEP erhöht) als Vorgabe ausgegeben. Erstes Zeichen 0Bh beendet AUTO.
;  Überlauf der Zeilennummer bei AUTO -> AUTO aus, Fehler 1.
; <- aufgerufen von 1311h
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
        DEFB    "RUN FD2",22h,"AUTO RUN",22h,0Dh; Laufwerksziffer (1302h) wird bei 122Fh eingesetzt
; <- aufgerufen von 127Dh
BAS_START2:
        CALL    PRTSTR
        LD      A,(AUTORUN_FLAG)
        OR      A
        JP      NZ,BAS_MAIN
        JP      BAS_READY
; <- aufgerufen von 437Dh
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
D1335:  DEFB    0Dh                     ; Inline-Parameter
D1336:  DEFW    EXECSTMT2
        JP      BAS_MAIN
BD_EDIT:
        CALL    DATA_RESET
; >>> SB-6610: ohne Gegenstück in SB-6511
        CALL    CONT_CLR
        CALL    FINDLINE
        DEFW    BDE_INSERT                   ; Inline-Parameter
        CALL    Z,EDIT_DEL
BDE_INSERT:
        LD      A,(TOKTEXT)
        CP      0Dh
        JR      Z,BDE_DONE
        CALL    FINDLINE2
        DEFW    BDE_LINK                   ; Inline-Parameter
BDE_LINK:
        LD      (TOKLINE),HL
        EX      DE,HL
        LD      HL,TOKLINE
        CALL    LINESIZE
        CALL    MOVEUP
        CALL    EDIT_ADJ
BDE_DONE:
        JP      BAS_MAIN
;  EDIT_DEL/EDIT_DELMEM/EDIT_ADJ – Teile der Zeilenverwaltung von BD_EDIT
;  (bei SB-6511 Routine EDITLINE, hier eingebaut): Zeile löschen, Bereiche
;  verschieben, Links korrigieren.
; <- aufgerufen von 1346h
EDIT_DEL:
        CALL    LINESIZE
        EX      DE,HL
; <- aufgerufen von 4488h
EDIT_DELMEM:
        CALL    MEMDEL
        CALL    NEGBC
; <- aufgerufen von 1362h
EDIT_ADJ:
        CALL    ADJ_PTRS
        EX      DE,HL
        JP      LINKS_ADD
;  PRT_RULE – 35 Mal Zeichen 90h ausgeben, dann zwei Zeilenvorschübe.
; <- aufgerufen von 1259h, 1268h
PRT_RULE:
        LD      B,23h
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
        DEFB    "  Double precision BASIC  SB-6610",0Dh
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
; <- aufgerufen von 12E4h, 155Fh, 1920h, 1D65h, 1D6Bh, 1E23h, 1EF6h, 1F58h (+34 weitere)
ERR_01: LD      A,01h                   ; Fehler 1: Syntax-Fehler
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 2FCFh, 30EAh, 3678h
ERR_02: LD      A,02h                   ; Fehler 2: Überlauf (auch Division durch 0, LN negativ)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 1BE8h, 2078h, 23F8h, 2402h, 241Dh, 2509h, 2890h, 29E6h (+14 weitere)
ERR_03: LD      A,03h                   ; Fehler 3: Wert außerhalb des Bereichs / Überlauf
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 1AA1h, 2659h, 2BA5h
ERR_04: LD      A,04h                   ; Fehler 4: Typfehler (Zahl/String verwechselt)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 25FEh, 3BEAh
ERR_05: LD      A,05h                   ; Fehler 5: String zu lang (> 255 Zeichen)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 19D4h, 2324h, 4CE3h, 4F00h
ERR_06: LD      A,06h                   ; Fehler 6: Speicher voll
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_07: LD      A,07h                   ; Fehler 7
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 1670h
ERR_08: LD      A,08h                   ; Fehler 8: Zeile zu lang (CRUNCH)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_09: LD      A,09h                   ; Fehler 9
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 20D6h
ERR_10: LD      A,0Ah                   ; Fehler 10: GOSUB zu tief verschachtelt (max. 15)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 219Bh
ERR_11: LD      A,0Bh                   ; Fehler 11: FOR zu tief verschachtelt (max. 15)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 27BDh
ERR_12: LD      A,0Ch                   ; Fehler 12: FN zu tief verschachtelt
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 21C1h
ERR_13: LD      A,0Dh                   ; Fehler 13: NEXT ohne FOR
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 20FCh
ERR_14: LD      A,0Eh                   ; Fehler 14: RETURN ohne GOSUB
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 279Ah
ERR_15: LD      A,0Fh                   ; Fehler 15: FN nicht definiert
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 1F51h
ERR_16: LD      A,10h                   ; Fehler 16: Zeilennummer nicht vorhanden
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 2C26h
ERR_17: LD      A,11h                   ; Fehler 17: CONT nicht möglich
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 2BE1h, 4CDDh, 4EF5h
ERR_18: LD      A,12h                   ; Fehler 18: Adresse im BASIC-Bereich (unter LIMIT bzw. belegt)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 1C7Fh
ERR_19: LD      A,13h                   ; Fehler 19: im Direkt- bzw. Programmmodus nicht erlaubt
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_20: LD      A,14h                   ; Fehler 20
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 2297h
ERR_21: LD      A,15h                   ; Fehler 21: RESUME ohne Fehler
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_22: LD      A,16h                   ; Fehler 22
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_23: LD      A,17h                   ; Fehler 23
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 3D8Eh
ERR_24: LD      A,18h                   ; Fehler 24: keine DATA mehr
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 3F6Ch
ERR_25: LD      A,19h                   ; Fehler 25: SWAP während SWAP
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_26: LD      A,1Ah                   ; Fehler 26
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_27: LD      A,1Bh                   ; Fehler 27
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_28: LD      A,1Ch                   ; Fehler 28
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_29: LD      A,1Dh                   ; Fehler 29: RS-232C: Framing-Fehler (SIO RR1 Bit 6) – in SB-6610 unbenutzt
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_30: LD      A,1Eh                   ; Fehler 30: RS-232C: Empfangs-Überlauf (SIO RR1 Bit 5) – in SB-6610 unbenutzt
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_31: LD      A,1Fh                   ; Fehler 31: RS-232C: Paritätsfehler (SIO RR1 Bit 4) – in SB-6610 unbenutzt
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_32: LD      A,20h                   ; Fehler 32: RS-232C: Sende-Timeout (Sendepuffer wird nicht leer) – in SB-6610 unbenutzt
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_33: LD      A,21h                   ; Fehler 33: RS-232C: Empfangspuffer voll (256 Byte Ringpuffer übergelaufen) – in SB-6610 unbenutzt
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_34: LD      A,22h                   ; Fehler 34: GP-IB: in dieser Betriebsart nicht möglich (Controller/Gerät) – in SB-6610 unbenutzt
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_35: LD      A,23h                   ; Fehler 35: GP-IB: Schnittstelle nicht bereit (Port C1 Bit 7) – in SB-6610 unbenutzt
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_36: LD      A,24h                   ; Fehler 36: GP-IB: keine Bestätigung beim Senden – in SB-6610 unbenutzt
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_37: LD      A,25h                   ; Fehler 37: GP-IB: ungültige Geräteadresse – in SB-6610 unbenutzt
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_38: LD      A,26h                   ; Fehler 38
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_39: LD      A,27h                   ; Fehler 39: GP-IB: nicht als Sprecher bzw. Hörer adressiert – in SB-6610 unbenutzt
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 3DECh, 3F81h, 3FEEh, 3FF6h, 4024h, 4173h, 44ABh, 46F2h
ERR_40: LD      A,28h                   ; Fehler 40: Datei nicht gefunden
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_41: LD      A,29h                   ; Fehler 41: Diskette: Lese-/Schreibfehler, auch Schreibschutz
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 41A1h, 426Eh, 46DFh
ERR_42: LD      A,2Ah                   ; Fehler 42: Datei existiert bereits
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 413Ah, 49C4h, 49D4h, 4E03h, 4E48h
ERR_43: LD      A,2Bh                   ; Fehler 43: Datei ist geöffnet
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 4DA6h
ERR_44: LD      A,2Ch                   ; Fehler 44: Datei nicht bzw. nicht in diesem Modus geöffnet
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 3946h, 3C1Dh
ERR_45: LD      A,2Dh                   ; Fehler 45: Datei in anderem Modus als bei ROPEN/WOPEN/XOPEN benutzt (SB-6511: 44)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 39F8h, 44C1h, 46FEh
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
; <- aufgerufen von 4254h, 4276h
ERR_51: LD      A,33h                   ; Fehler 51: Verzeichnis voll
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 4A2Eh, 4B6Dh, 4B74h
ERR_52: LD      A,34h                   ; Fehler 52: falsche Diskette bzw. Volumennummer
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 3957h, 48A6h
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
; <- aufgerufen von 4334h, 433Ah, 46B7h, 46BEh, 4B3Bh, 4B42h, 4D16h, 4D21h
ERR_60: LD      A,3Ch                   ; Fehler 60: ungültiger Dateiname
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 4B5Dh
ERR_61: LD      A,3Dh                   ; Fehler 61: ungültiges Laufwerk
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_62: LD      A,3Eh                   ; Fehler 62
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 3E04h, 4103h, 4124h, 41A8h, 44B8h, 4DE0h
ERR_63: LD      A,3Fh                   ; Fehler 63: falscher Dateityp
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 40EDh, 4111h, 471Bh, 4722h
ERR_64: LD      A,40h                   ; Fehler 64: ungültige Dateinummer
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 509Ah
ERR_65: LD      A,41h                   ; Fehler 65: Drucker antwortet nicht (Zeitüberschreitung)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 50AEh
ERR_66: LD      A,42h                   ; Fehler 66: Drucker meldet Fehler (Status ESC 04h)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 50A5h
ERR_67: LD      A,43h                   ; Fehler 67: Drucker meldet Fehler (Status ESC 03h)
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_68: LD      A,44h                   ; Fehler 68
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
ERR_69: LD      A,45h                   ; Fehler 69
        DEFB    01h                     ; DEFB 01h = LD BC,nn: überspringt das folgende LD A,n
; <- aufgerufen von 4DCCh
ERR_70: LD      A,46h                   ; Fehler 70: Kassette: Lesefehler
        JR      ERROR
; ------------------------------------------------------------------------------
;  Fehlerbehandlung
;  ERROR: Nummer merken, ON ERROR prüfen, sonst "*Error n [in z]".
;  BREAK: "*Break [in z]". SET_IOERR setzt IY auf IOERR (JP (IY)).
; ------------------------------------------------------------------------------
; <- aufgerufen von 2BB0h, 3B0Ch, 4859h
SET_IOERR:
        LD      IY,IOERR
        RET
IOERR_NUM:
        DEFB    00h                     ; ?? |.|
IOERR:  LD      A,(IOERR_NUM)
ERROR:  LD      (ERRNUM),A              ; Fehlernummer merken
        LD      A,(AUTORUN_FLAG)
        OR      A
        JP      NZ,BAS_READY
        CALL    CLOSE_ALL               ; Dateien/Geräte aufräumen
        CALL    RELINK
        CALL    IS_DIRECT               ; Direktmodus?
        JR      Z,ERR_PRINT
        LD      HL,ONERR_FLAG           ; ON ERROR GOTO aktiv?
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
; <- aufgerufen von 1D4Ah, 24FDh, 3BB9h, 4BC8h, 4D56h, 4D64h, 4DCFh, 5217h
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
; <- aufgerufen von 1514h
PRTLINENUM:
        CALL    PRTNUM
        JP      PRTSTR
;  CONT_CLR – CONT sperren (CONT_FLAG = 0).
; <- aufgerufen von 133Eh, 1ACEh, 208Eh, 4CFDh, 4D6Ah, 4D9Bh, 4E94h
CONT_CLR:
        XOR     A
        LD      (CONT_FLAG),A
        RET
;  DATA_RESET – READ beginnt wieder beim ersten DATA (DATA_FLAG = 0).
; <- aufgerufen von 133Bh, 1F43h, 208Bh
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
; <- aufgerufen von 131Fh
CRUNCH: LD      HL,INBUF
        CALL    GETLNUM_SN
        LD      (TOKLNUM),DE
        LD      DE,TOKTEXT
        LD      C,00h
;  Ablauf von CRUNCH: COPYCHR kopiert Leerzeichen, FFh, Klammern und
;  Strings unverändert. Am ersten anderen Zeichen wird nacheinander gesucht:
;  "?" (= PRINT), KWTAB_STMT (-> 80h,80h+n), Tabelle 17E0h (-> 81h,80h+n),
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
; <- aufgerufen von 162Dh
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
; <- aufgerufen von 157Bh
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
; <- aufgerufen von 1573h, 158Ch, 2BBBh
KWSEARCH:
        LD      B,80h
; <- aufgerufen von 159Fh, 42B6h, 4B1Ch, 4B88h
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
; <- aufgerufen von 15CAh
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
; <- aufgerufen von 15AFh
KWS_HIBIT:
        POP     HL
        CALL    SKIPSP
        DEC     A
        LD      A,(HL)
        RET
; <- aufgerufen von 1322h, 1E95h
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
;  KWTAB_OPS ff.; 80h/81h/82h + n: Eintrag n-80h aus KWTAB_STMT/17E0h/17E2h.
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
; <- aufgerufen von 1600h, 1622h
KWNTH:  DJNZ    KWNTH_SKIP
KWNTH_COPY:
        CALL    COPY1
        ADD     A,80h
        JR      NC,KWNTH_COPY
        DEC     DE
        LD      (DE),A
        INC     DE
        RET
; <- aufgerufen von 155Ah, 15EBh
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
; <- aufgerufen von 1646h
ISPASS: CP      20h                     ; ' '
        RET     Z
        CP      0FFh
        RET     Z
        CP      28h                     ; '('
        RET     Z
        CP      29h                     ; ')'
        RET
;  COPYSTR – bis einschließlich '"' oder 0Dh kopieren (Z bei 0Dh).
; <- aufgerufen von 164Eh, 1681h
COPYSTR:
        CALL    COPY1
        RET     Z
        CP      22h                     ; '"'
        JR      NZ,COPYSTR
        RET
;  COPY1 – ein Zeichen (HL) -> (DE) kopieren, C zählen (Überlauf: Fehler 8).
;  Z, wenn das Zeichen 0Dh war.
; <- aufgerufen von 1637h, 1642h, 1662h, 1676h
COPY1:  LD      A,(HL)
        LD      (DE),A
        INC     HL
        INC     DE
        INC     C
        JP      Z,ERR_08
        CP      0Dh
        RET
;  COPY_TO_COLON – kopieren bis ":" oder 0Dh, Strings unverändert.
; <- aufgerufen von 1581h
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
;  Die Nummern 75-99 (bei SB-6511 GP-IB- und RS-232C-Befehle) sind frei.
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
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh
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
        DEFB    "USIN"
        DEFB    0C7h
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
; <- aufgerufen von 1D56h
GETTXT: LD      HL,(TXTPTR)
        DEC     HL
; <- aufgerufen von 1C4Dh, 26FDh, 2733h, 27FAh, 2914h, 2D76h
SKIPSP_INC:
        INC     HL
; <- aufgerufen von 15ABh, 15B3h, 15D3h, 18E1h, 190Dh, 191Bh, 1AB3h, 1B6Eh (+13 weitere)
SKIPSP: LD      A,(HL)
        CP      20h                     ; ' '
        RET     NZ
        JR      SKIPSP_INC
;  SKIPLINE – HL hinter das nächste 0Dh setzen (A bleibt erhalten).
; <- aufgerufen von 24B7h, 27A2h
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
; <- aufgerufen von 1E2Ah, 2272h, 22B1h, 24A1h, 24D1h, 3DA8h
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
; <- aufgerufen von 136Fh, 1B66h, 1FC5h, 4C80h
NEGBC:  LD      A,C
        CPL
        LD      C,A
        LD      A,B
        CPL
        LD      B,A
        INC     BC
        RET
;  ISDIGIT – Leerzeichen überlesen; C gesetzt, wenn (HL) eine Ziffer ist.
; <- aufgerufen von 1951h, 1C53h, 1FF8h, 2091h, 2479h, 2BF9h, 42C5h, 440Ch (+5 weitere)
ISDIGIT:
        CALL    SKIPSP
        SUB     30h
        CP      0Ah
        LD      A,(HL)
        RET
; <- aufgerufen von 1A39h, 1A52h, 1C9Bh, 1CEFh, 1E87h, 1E90h, 23F5h, 27BAh (+22 weitere)
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
; <- aufgerufen von 1A32h, 1A4Ch, 1C11h, 1C43h
JP_INL_POP:
        POP     HL
; <- aufgerufen von 1C37h, 1F9Fh, 1FA9h, 473Dh
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
; <- aufgerufen von 1A3Dh, 1A40h, 1C0Bh
RET_SKIP2_POP:
        POP     HL
; <- aufgerufen von 1A58h, 1C4Ah, 1FDCh, 2050h, 4743h
RET_SKIP2:
        EX      (SP),HL
        INC     HL
        INC     HL
        EX      (SP),HL
        RET
; <- aufgerufen von 19F1h, 1A06h
FACPTR5:
        LD      HL,(VALSP)
        PUSH    DE
        LD      DE,0009h
        ADD     HL,DE
        POP     DE
        RET
; <- aufgerufen von 214Ah, 222Eh, 420Ah, 45DDh
CHK_CHR_ALT_T:
        LD      HL,(TXTPTR)
;  CHK_CHR_ALT – Leerzeichen überlesen, (HL) mit dem Inline-Byte
;  vergleichen. Gleich: HL dahinter, zurück hinter das Inline-Wort.
;  Ungleich: Sprung zur Inline-Adresse. _T: ab TXTPTR.
; <- aufgerufen von 1332h, 1C31h, 1E3Fh, 200Ah, 22A4h, 2352h, 2430h, 2B97h (+32 weitere)
CHK_CHR_ALT:
        CALL    SKIPSP
        EX      (SP),HL
        CP      (HL)
        INC     HL
        JR      NZ,JP_INLINE2
        INC     HL
        JR      SYNCHK_OK
; <- aufgerufen von 213Dh
SYNCHK_T:
        LD      HL,(TXTPTR)
;  SYNCHK – wie CHK_CHR_ALT, aber ungleich ergibt Fehler 1.
; <- aufgerufen von 1D09h, 1E45h, 1EE3h, 1F70h, 212Ah, 2249h, 22AAh, 22EEh (+30 weitere)
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
; <- aufgerufen von 1947h, 2308h, 231Bh
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
; <- aufgerufen von 1C17h, 2027h, 2039h, 23BFh, 23CBh, 28A3h, 28B2h
MUL16_ERR:
        CALL    MUL16
D194A:  DEFW    ERR_03
        RET
;  GETLNUM – Dezimalzahl ab (HL) nach DE, Leerzeichen dazwischen und danach
;  werden überlesen. Überlauf (nur geprüft für den Übertrag des letzten
;  ADD HL,HL) -> Inline-Adresse; sonst läuft die Zahl modulo 65536 über.
;  GETLNUM_SN: Überlauf ergibt Fehler 1.
; <- aufgerufen von 196Eh, 4714h, 4B66h
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
; <- aufgerufen von 154Eh, 1ED7h, 1EEBh, 1F37h, 2096h, 20C6h, 226Fh, 227Dh (+3 weitere)
GETLNUM_SN:
        CALL    GETLNUM
D1971:  DEFW    ERR_01
        RET
;  NUM2DEC – HL als Dezimalzahl ohne führende Nullen nach (DE), davor ein
;  Leerzeichen, danach 0Dh. Zurück: DE zeigt auf das 0Dh.
;  NUM2DEC_C: Ausgabelänge in C mitzählen (für LISTLINE).
; <- aufgerufen von 12C5h, 19BDh, 4396h, 43C3h
NUM2DEC:
        LD      C,00h
; <- aufgerufen von 15E1h
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
; <- aufgerufen von 1980h, 1986h, 198Ch, 1992h
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
;  PRTNUM – HL dezimal nach 61B3h wandeln, DE zeigt auf den Text
;  (gibt trotz des Namens nichts aus; danach folgt meist PRTSTR/MSGX).
; <- aufgerufen von 1274h, 1534h, 1F25h, 2AF8h, 3E88h
PRTNUM: LD      DE,61B3h
        PUSH    DE
        CALL    NUM2DEC
        POP     DE
        RET
;  MEMFREE/CHKMEM – HL = SP - 100 - ((VALSP) + BC), also der freie Platz
;  nach Belegung von BC Bytes. Zu wenig: Fehler 6 (Speicher voll).
; <- aufgerufen von 2AF5h
MEMFREE:
        LD      BC,0000h
; <- aufgerufen von 1271h, 19D9h
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
; <- aufgerufen von 1A00h, 271Bh, 3E31h
CHKMEM2:
        PUSH    HL
        PUSH    DE
        CALL    CHKMEM
        POP     DE
        POP     HL
        RET
;  GETLINK – Programmzeile bei HL lesen: HL = Link, DE = Zeilennummer.
;  Z, wenn der Link 0 ist (Programmende).
; <- aufgerufen von 1A2Fh, 1A63h, 1E72h, 4457h, 446Bh
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
;  Wertestacks (VALSP+9) rückt nach unten.
; <- aufgerufen von 136Ch, 1B62h, 1FC8h, 4C7Dh
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
;  MEMINS – BC Bytes Platz ab DE schaffen (Speicher bis VALSP+9 rückt nach
;  oben, CHKMEM prüft vorher). MOVEUP: zusätzlich BC Bytes von HL nach DE
;  kopieren. BLKMOVE: nur kopieren (LDIR, BC = 0 erlaubt).
; <- aufgerufen von 1A1Ah, 1B3Bh, 1BB0h, 1FBFh, 4C52h
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
; <- aufgerufen von 135Fh, 24DFh, 2603h, 2769h, 2828h
MOVEUP: CALL    MEMINS
; <- aufgerufen von 1B91h, 27CFh, 27D6h, 27F0h, 38BDh
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
; <- aufgerufen von 1341h, 1F4Bh
FINDLINE:
        LD      (FL_TARGET+1),HL
; <- aufgerufen von 1350h
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
; <- aufgerufen von 23A9h, 2812h
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
; <- aufgerufen von 1376h
LINKS_ADD:
        PUSH    HL
        CALL    GETLINK
        JR      NZ,LINKS_ADD_LP
        POP     HL
        RET
;  LINESIZE – BC = Länge der Programmzeile bei HL (4 + Text + 0Dh).
;  LEN_CR: BC = Anzahl Zeichen bis vor 0Dh, LEN_CR_BC addiert sie zu BC.
; <- aufgerufen von 135Ch, 1368h, 1E78h
LINESIZE:
        PUSH    HL
        LD      BC,0004h
        ADD     HL,BC
        CALL    LEN_CR_BC
        INC     BC
        POP     HL
        RET
; <- aufgerufen von 38B2h, 3CD6h, 432Fh
LEN_CR: LD      BC,0000h
; <- aufgerufen von 1A6Fh
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
; <- aufgerufen von 1FECh, 24F7h, 253Dh, 2543h, 25F3h, 25F9h, 299Dh, 29C1h (+11 weitere)
GETSTR: CALL    REQ_STR
;  GETSTR_E – Eintrag Nummer E in den String-Zwischenwerten (P_STRTMP)
;  suchen: DE = Text, C = Länge.
; <- aufgerufen von 1FD3h
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
; <- aufgerufen von 1A83h
REQ_STR:
        LD      A,D
        OR      A
        RET     NZ
        JR      ERR_TYPE
; <- aufgerufen von 205Dh, 21BAh, 2241h, 2456h, 26DBh, 278Dh, 27DDh, 2A1Bh
CHKSTRTYPE:
        LD      A,D
        OR      A
        RET     Z
ERR_TYPE:
        JP      ERR_04
;  VAL_PUT – 9 Bytes von HL nach (VALSP) kopieren.
;  VAL_GET – 9 Bytes von (VALSP) nach DE kopieren.
; <- aufgerufen von 257Ch, 2679h
VAL_PUT:
        LD      HL,(VALSP)
        EX      DE,HL
; >>> SB-6610: ohne Gegenstück in SB-6511
VAL_COPY9:
        LD      BC,0009h
        LDIR
        RET
; <- aufgerufen von 1FA2h, 213Ah, 2147h
VAL_GET:
        LD      HL,(VALSP)
        JR      VAL_COPY9
; <- aufgerufen von 18C6h, 1E20h, 1E65h, 1EDEh, 1EE7h, 1EF2h, 1F55h, 209Fh (+24 weitere)
CHRGET: CALL    SKIPSP
        CP      0Dh
        RET     Z
        CP      3Ah                     ; ':'
        RET
;  CLEARALL – NEW: leeres Programm, alle Variablen und Zeiger löschen,
;  LIST_LOCK aufheben.
; <- aufgerufen von 126Bh, 1E34h, 4C45h
CLEARALL:
        LD      HL,0000h
        LD      (LIST_LOCK),HL
        LD      (664Ch),HL
        CALL    CLRPROG
        CALL    CLEARVARS
        CALL    INITVARPTR
        CALL    CONT_CLR
        RET
;  CLRPROG – Programm leeren (00h 00h bei PRGTXT) und die Bereichszeiger
;  664Eh-6695h (PRGEND, 26 Puffer der Dateiverwaltung ab 6650h - siehe
;  CLEARVARS -, ab 6684h DEF FN, Felder, Variablen,
;  String-Zwischenwerte und VALSP, siehe EQUs P_*)
;  auf leere Bereiche dahinter setzen; jeder Bereich beginnt mit 00h 00h.
;  CLR_AREAS: dasselbe ab dem Zeiger 6684h (für CLR).
; <- aufgerufen von 1AC5h
CLRPROG:
        LD      HL,PRGTXT
        CALL    CLRWORD
        LD      DE,PRGEND
AREAS_INIT:
        PUSH    HL
        LD      HL,FNPAR_SP
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
; <- aufgerufen von 1505h, 1ACBh, 1CC1h, 20ABh, 3F40h
INITVARPTR:
        LD      HL,FOR_VAR
        LD      (GOSUB_SP),HL
        LD      HL,684Fh
        LD      (FOR_SP),HL
        LD      HL,66BAh
        LD      (FNPAR_SP),HL
        LD      HL,FOR_CNT
        CALL    CLRWORD
        LD      (HL),A
; <- aufgerufen von 1502h, 20A4h, 22DCh
CLR_ONERR:
        XOR     A
        LD      (ONERR_FLAG),A
        RET
; <- aufgerufen von 1CBBh, 20AEh
CLR_AREAS:
        LD      HL,(P_DEFFN)
        LD      DE,P_DEFFN
        JR      AREAS_INIT
;  CLEARVARS – Dateitabelle FILETAB (65F2h-664Bh) nullen und die 26
;  Puffer ab 6650h freigeben (AREA_FREE): 6650h + 2*n Dateipuffer der 10
;  Tabelleneinträge, ab 6664h Puffer je Einheit, 667Ch-6683h vier weitere.
; <- aufgerufen von 1508h, 1AC8h, 1CBEh, 20B1h, 4087h
CLEARVARS:
        LD      HL,FILETAB
        LD      B,5Ah
CLRV_ZERO:
        LD      (HL),00h
        INC     HL
        DJNZ    CLRV_ZERO
        LD      B,1Ah
        LD      HL,6650h
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
; <- aufgerufen von 129Dh, 12A0h, 1AD5h, 1B08h, 1D50h, 1E5Dh, 462Eh
CLRWORD:
        XOR     A
; <- aufgerufen von 1E61h
CLRWORD_A:
        LD      (HL),A
        INC     HL
        LD      (HL),A
        INC     HL
        RET
;  MEMINS_ADJ – MEMINS und danach ADJ_PTRS.
;  ADJ_PTRS – Bereichszeiger von VALSP abwärts um BC verschieben, solange
;  sie größer als DE sind. MEMDEL_ADJ: MEMDEL und Zeiger um -BC korrigieren.
; <- aufgerufen von 1CE0h, 232Ah, 24C0h, 3E26h, 47CEh
MEMINS_ADJ:
        CALL    MEMINS
; <- aufgerufen von 1372h, 1B69h, 1FCCh, 24E2h, 2606h, 276Ch, 282Bh, 4C55h (+1 weitere)
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
; <- aufgerufen von 1CB5h, 24DAh, 29CDh, 47CAh
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
; <- aufgerufen von 270Dh, 2A33h, 3CF6h, 3CFCh, 3D72h
STRLIT: CALL    SKIPSP
        LD      BC,0000h
        LD      DE,0D2Ch
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
; <- aufgerufen von 26C3h, 3BEDh
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
; <- aufgerufen von 1B8Ch, 2A9Ah
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
; <- aufgerufen von 2060h, 2244h
VAL2UINT:
        PUSH    HL
        LD      HL,(VALSP)
; >>> SB-6610: ohne Gegenstück in SB-6511
        LD      DE,FP_TMP1              ; Wert nach FP_TMP1
        LD      BC,0009h
        LDIR
        PUSH    BC
        POP     IX
        DEC     DE
        LD      A,(DE)
        OR      A
        JP      M,V2U_FAIL              ; negativ: Inline-Sprung
        CALL    FN_INT                  ; Nachkommastellen abschneiden
        LD      B,05h                   ; obere 5 Bytes (10 Ziffern) müssen 0 sein, sonst Fehler 3
        XOR     A
        LD      HL,FP_TMP1
V2U_CHKHI:
        CP      (HL)
        JP      NZ,ERR_03
        INC     HL
        DJNZ    V2U_CHKHI
        LD      B,H
        LD      C,L
        LD      HL,2710h                ; 10000
        CALL    V2U_MULADD              ; IX = Ziffern 1-2 * 10000
        JR      C,V2U_FAIL
        LD      HL,0064h                ; + Ziffern 3-4 * 100
        CALL    V2U_MULADD
        JR      C,V2U_FAIL
        CALL    BCD2BIN                 ; + Ziffern 5-6
        OR      A
        ADD     IX,DE
        JR      C,V2U_FAIL              ; über 65535: Inline-Sprung
        PUSH    IX
        POP     DE
        JP      RET_SKIP2_POP           ; Rückkehr hinter das Inline-Wort
;  V2U_FAIL – negativ oder zu groß: DE = 0, Sprung zur Inline-Adresse.
;  V2U_MULADD: IX = IX + BCD-Byte (BC) * HL (HL = 10000 bzw. 100).
; <- aufgerufen von 1BDBh
V2U_FAIL:
        LD      DE,0000h
        JP      JP_INL_POP
; <- aufgerufen von 1BF3h, 1BFBh
V2U_MULADD:
        CALL    BCD2BIN
        CALL    MUL16_ERR
        OR      A
        ADD     IX,DE
        RET
;  BCD2BIN – BCD-Byte (BC) als Zahl 0-99 nach DE, BC + 1.
; <- aufgerufen von 1C00h, 1C14h
BCD2BIN:
        LD      A,(BC)
        INC     BC
        LD      E,A
        AND     0F0h
        RRCA
        LD      D,A
        RRCA
        RRCA
        ADD     A,D
        LD      D,A
        LD      A,E
        AND     0Fh
        ADD     A,D
        LD      E,A
        LD      D,00h
        RET
;  NUMSTR_EVAL – besteht der Rest der Zeile ab HL nur aus Zeichen einer
;  Zahl (Ziffern, ".", "+", "-", "E"), wird sie mit EVAL ausgewertet und
;  hinter das Inline-Wort zurückgekehrt; sonst (auch bei leerem Rest)
;  Sprung zur Inline-Adresse.
; <- aufgerufen von 2A49h, 3D45h
NUMSTR_EVAL:
        CALL    CHK_CHR_ALT
D1C34:  DEFB    0Dh                     ; Inline-Parameter
D1C35:  DEFW    NUMSTR_CHK
        JP      JP_INLINE
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
; <- aufgerufen von 1C3Ch
NUMCHR_INC:
        CALL    SKIPSP_INC
        CP      45h                     ; 'E'
        RET     Z
;  NUMCHR – Z bzw. C, wenn (HL) zu einer Zahl gehören kann.
; <- aufgerufen von 2710h
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
;  CHK_DIRECT_LK – wie CHK_DIRECT (nur im Direktmodus), zusätzlich
;  LIST_LOCK prüfen: <> 0 -> zurück nach "Ready" (für LIST und SAVE).
; <- aufgerufen von 1E4Eh, 3ED0h
CHK_DIRECT_LK:
        SCF
        JR      CHK_DIRECT2
;  CHK_DIRECT – nur im Direktmodus erlaubt, CHK_NODIRECT – nur im
;  Programm erlaubt; sonst Fehler 19.
; <- aufgerufen von 2C1Fh, 2C7Dh, 2D8Bh, 42A1h, 4BD4h
CHK_DIRECT:
        XOR     A
CHK_DIRECT2:
        EX      AF,AF'
        PUSH    HL
        CALL    IS_DIRECT
        POP     HL
        JR      NZ,ERR_MODE
        EX      AF,AF'
        RET     NC
        LD      A,(LIST_LOCK)
        OR      A
        JP      NZ,BAS_READY
        RET
; <- aufgerufen von 1EFEh, 1F16h, 20C3h, 20F4h, 223Bh, 228Fh, 242Dh, 3B4Fh (+7 weitere)
CHK_NODIRECT:
        PUSH    HL
        CALL    IS_DIRECT
        POP     HL
        RET     NZ
ERR_MODE:
        JP      ERR_19
; <- aufgerufen von 14EAh, 152Ah, 1C69h, 1C7Ah, 1D79h
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
; <- aufgerufen von 14E7h, 3E70h, 3F23h, 4D60h
RELINK: LD      HL,RELINK_NEW
        XOR     A
        CP      (HL)
        LD      (HL),A
        JR      NZ,PROG_NEW
; <- aufgerufen von 4BEBh
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
; <- aufgerufen von 1CB8h, 3F43h
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
; <- aufgerufen von 1CCEh, 3E14h
PROG_NEW:
        CALL    PROG_DEL
; <- aufgerufen von 2427h
PROG_CLRVARS:
        CALL    CLR_AREAS
        CALL    CLEARVARS
        CALL    INITVARPTR
        RET
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
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
; <- aufgerufen von 3F0Eh, 4BE4h, 4D59h
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
;  NEXTSTMT: nach ":" weiter oder nächste Zeile; prüft BREAK und die
;  Tasten. DISPATCH: Token
;  80h,80h+n -> STMT_TAB[n]; kein Token -> LET.
; ------------------------------------------------------------------------------
; <- aufgerufen von 1F7Ch, 2124h, 21B1h, 2217h, 228Ch, 2B83h, 2BE9h, 2D4Dh (+18 weitere)
NEXTSTMT:
        LD      HL,(TXTPTR)
; <- aufgerufen von 1E2Dh, 2423h, 24E6h, 2B48h, 2C7Ah, 2DC3h, 4BA9h, 50C6h (+5 weitere)
NEXTSTMT_HL:
        CALL    SKIPSP                  ; Anweisungsende?
; <- aufgerufen von 2264h
NS_CHKEND:
        CP      0Dh
        JR      Z,NEXTLINE
        CALL    SYNCHK                  ; sonst muss ":" folgen
D1D0C:  DEFB    3Ah                     ; Inline-Parameter ':'
        JR      EXECSTMT
; <- aufgerufen von 2450h
NEXTLINE:
        LD      HL,(CURLINE)            ; Zeilenende: Link der aktuellen Zeile
        LD      A,H
        OR      L
        JP      Z,BAS_READY
; <- aufgerufen von 20B7h, 20F1h, 22D3h
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
; <- aufgerufen von 2C39h
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
; <- aufgerufen von 247Eh
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
; <- aufgerufen von 26F5h, 2704h
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
; <- aufgerufen von 1D2Dh
ERRCTX_SAVE:
        CALL    IS_DIRECT
        RET     Z
; <- aufgerufen von 22C1h
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
        DEFW    ERR_01                  ; Token 80h,B4h: APPEND – fehlt in SB-6610 -> Syntax Error
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
        DEFW    ST_DELLINES             ; Token 80h,C1h: DELETE (Zeilen oder Datei)
        DEFW    ST_SWAP                 ; Token 80h,C2h: SWAP
        DEFW    ST_KILL                 ; Token 80h,C3h: KILL
        DEFW    ST_RENAME               ; Token 80h,C4h: RENAME
        DEFW    ST_LOCK                 ; Token 80h,C5h: LOCK
        DEFW    ST_CHAIN                ; Token 80h,C6h: CHAIN
        DEFW    ST_UNLOCK               ; Token 80h,C7h: UNLOCK
        DEFW    ST_RESUME               ; Token 80h,C8h: RESUME
        DEFW    ST_XOPEN                ; Token 80h,C9h: XOPEN
; ==============================================================================
;  ANWEISUNGEN, AUSDRUCKSAUSWERTUNG, STRINGFUNKTIONEN
; ==============================================================================
;  CHK_EOS – Anweisungsende (":" oder 0Dh) erzwingen, sonst Fehler 1;
;  TXTPTR auf das Ende setzen.
; <- aufgerufen von 1F0Eh, 1F3Ah, 20C9h, 2280h, 3DD8h, 3EECh, 3F65h, 40F6h (+4 weitere)
CHK_EOS:
        CALL    CHRGET
        JP      NZ,ERR_01
        LD      (TXTPTR),HL
        RET
; <- aufgerufen von 225Eh, 4EB8h
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
;  Nur im Direktmodus. Bereich in 61B3h/61B5h (Vorgabe 0-65535).
;  Jede Zeile wird nach TOKLINE kopiert und mit LISTLINE nach INBUF
;  gewandelt. Bildschirm: nach den ersten 10 Zeilen kurze Pause pro Zeile
;  (LIST_DELAY); solange die Taste mit Code FDh an PIO_BD gedrückt ist,
;  wird angehalten; BREAK bricht ab.
;  LIST_DEV: Operand = 1 bei LIST/P (selbstverändernd).
ST_LIST:
        XOR     A
        LD      (LIST_DEV+1),A
        CALL    CHK_CHR_ALT
D1E42:  DEFB    2Fh                     ; Inline-Parameter '/'
D1E43:  DEFW    LIST_GO
        CALL    SYNCHK
D1E48:  DEFB    50h                     ; Inline-Parameter 'P'
        LD      A,01h
        LD      (LIST_DEV+1),A
LIST_GO:
        CALL    CHK_DIRECT_LK                   ; [SB-6511: CALL CHK_DIRECT]
        XOR     A
        OUT     (GRPH),A
        LD      A,0Ah
        LD      (LIST_CNT),A
        PUSH    HL
        LD      HL,61B3h
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
        LD      HL,(61B3h)
        EX      DE,HL
        LD      HL,(TOKLNUM)
        CALL    CPHLDE
        JR      C,LIST_NEXT
        EX      DE,HL
        LD      HL,(61B5h)
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
; <- aufgerufen von 1EB5h
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
; <- aufgerufen von 1E68h
LIST_RANGE:
        CALL    GETLNUM_SN
        LD      (61B3h),DE
        CALL    CHRGET
        JR      Z,LIST_TO
        CALL    SYNCHK
D1EE6:  DEFB    2Dh                     ; Inline-Parameter '-'
        CALL    CHRGET
        RET     Z
        CALL    GETLNUM_SN
LIST_TO:
        LD      (61B5h),DE
        CALL    CHRGET
        RET     Z
        JP      ERR_01
;  END – Programm beenden (CONT_POS mit A=1, CONT möglich).
;  END_PRG: Ende des Programmtextes erreicht.
;  END_SWAP: Operand <> 0, solange ein mit SWAP geladenes Programm läuft;
;  dann geht es bei SWAP_BACK zurück ins aufrufende Programm.
ST_END: XOR     A
        DEFB    01h                     ; Trick: Opcode 01h verschluckt den folgenden Befehl
; <- aufgerufen von 1D1Bh
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
; <- aufgerufen von 1F09h, 1F19h
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
; <- aufgerufen von 20CCh, 22CBh
GOTO_DE:
        EX      DE,HL
; <- aufgerufen von 209Ah
GOTO_HL:
        CALL    FINDLINE
D1F4E:  DEFW    ERR_16
        RET     Z
        JP      ERR_16
;  LET var = ausdruck (auch ohne LET). Erst wird hinter dem "=" der
;  Ausdruck ausgewertet, dann die Variable bestimmt und zugewiesen.
; <- aufgerufen von 1D5Bh
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
D1F73:  DEFB    3Dh                     ; Inline-Parameter '='
        CALL    SAVEPAR1
        CALL    ASSIGN
D1F7A:  DEFW    ERR_04
        JP      NEXTSTMT
;  SAVEPAR0/SAVEPAR1 – BC und DE (Wert bzw. Variable: D = Typ) nach
;  6000h bzw. 6004h sichern; ASSIGN liest beides.
; <- aufgerufen von 1F66h, 2B7Bh, 3D06h, 3D4Ah
SAVEPAR0:
        LD      HL,6000h
        JR      SAVEPAR_HL
; <- aufgerufen von 1F74h, 2B56h, 2C62h, 3D15h
SAVEPAR1:
        LD      HL,6004h
; <- aufgerufen von 4847h
SAVEPAR_HL:
        LD      (HL),C
        INC     HL
        LD      (HL),B
        INC     HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        RET
;  ASSIGN – Wert (6000h) der Variablen (6004h) zuweisen. Typen ungleich:
;  Sprung zur Inline-Adresse. Zahl: 9 Bytes kopieren. String: Platz der
;  Variablen an die neue Länge anpassen und Text kopieren. Variable TI$
;  (TI_STR): Wert "hhmmss" prüfen und die Uhr stellen (ASG_TI).
; <- aufgerufen von 1F77h, 2B7Eh, 3D18h
ASSIGN: LD      HL,6003h
        LD      B,(HL)
        INC     HL
        LD      C,(HL)
        INC     HL
        LD      A,(HL)
        LD      DE,(6006h)
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
        LD      HL,(6000h)
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
        LD      HL,(6002h)
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
        DEFB    00h,00h,00h,00h,00h,00h,00h; ?? |.......|
ASG_TI: LD      HL,(6002h)
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
D200D:  DEFB    0Dh                     ; Inline-Parameter
D200E:  DEFW    ERR_03
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
; <- aufgerufen von 2011h, 202Dh, 2041h, 2072h, 2374h, 2ACAh, 2ADCh, 2C1Ch (+9 weitere)
EVAL_INT:
        EXX
; >>> SB-6610: ohne Gegenstück in SB-6511
        LD      BC,0009h
        CALL    VALSP_ADD
        CALL    EVAL
        CALL    CHKSTRTYPE
        CALL    VAL2UINT
        DEFW    ERR_03                  ; Inline-Parameter
        EXX
        LD      BC,0FFF7h
; <- aufgerufen von 2057h
VALSP_ADD:
        LD      HL,(VALSP)
        ADD     HL,BC
        LD      (VALSP),HL
        EXX
        RET
; <- aufgerufen von 2409h, 2502h, 2994h, 29B8h, 29E0h, 2A8Dh, 2AB4h, 2B21h (+12 weitere)
EVAL_BYTE:
        CALL    EVAL_INT
        LD      A,D
        OR      A
        RET     Z
ERR_RANGE:
        JP      ERR_03
;  RUN [zeile] / RUN "datei" – SWAP-/Lade-Zustände zurücksetzen, READ
;  und CONT zurücksetzen. Mit Zeilennummer: Start dort (über GOTO, Variablen
;  bleiben); ohne Argument: Variablen löschen und von vorn; sonst Datei
;  laden und starten (RUN_LOAD -> LOAD_FD).
ST_RUN: XOR     A
        LD      (END_SWAP+1),A
        LD      (SWAP_ACTIVE),A
        LD      (CHAIN_MODE),A
; <- aufgerufen von 3E90h
RUN_CLR:
        LD      (TFILE_MODE),A
        CALL    SKIPCOMMA
        CALL    DATA_RESET
        CALL    CONT_CLR
        CALL    ISDIGIT
        JR      NC,RUN_ARGS
;  GOTO zeile – auch Ziel von THEN zeile, ON ... GOTO und RESUME zeile.
; <- aufgerufen von 2476h
ST_GOTO:
        CALL    GETLNUM_SN
; <- aufgerufen von 227Ah
GOTO_LNUM:
        EX      DE,HL
; <- aufgerufen von 14FFh
GOTO_LNUM2:
        CALL    GOTO_HL
        JR      RUN_GO
RUN_ARGS:
        CALL    CHRGET
        JR      NZ,RUN_LOAD
; <- aufgerufen von 22DFh
RUN_START:
        CALL    CLR_ONERR
        XOR     A
        LD      (END_SWAP+1),A
        CALL    INITVARPTR
        CALL    CLR_AREAS
        CALL    CLEARVARS
        LD      HL,PRGTXT
RUN_GO: JP      NL_NEXT
RUN_LOADFLG:
        DEFB    00h                     ; ?? |.|
RUN_LOAD:
        LD      A,01h
        LD      (RUN_LOADFLG),A
        JP      LOAD_FD
;  GOSUB zeile – CURLINE, TXTPTR und FOR_CNT (7 Bytes) auf den GOSUB-Stack,
;  FOR_CNT = 0 für die neue Ebene. Mehr als 15 Ebenen: Fehler 10.
; <- aufgerufen von 246Ch
ST_GOSUB:
        CALL    CHK_NODIRECT
        CALL    GETLNUM_SN
; <- aufgerufen von 2277h
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
        JP      NL_NEXT
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
        LD      BC,001Bh                ; 27 Bytes je FOR-Eintrag
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
;  allen jüngeren entfernen und 27 Bytes auf den FOR-Stack legen.
;  Mehr als 15 Einträge: Fehler 11.
ST_FOR: CALL    GETNAME_SN
        CALL    SYNCHK
D212D:  DEFB    3Dh                     ; Inline-Parameter '='
        PUSH    DE
        CALL    FOR_EVALNUM
        POP     HL
        LD      (FOR_VAR),HL
        EX      DE,HL
        CALL    NUMVAR
        CALL    VAL_GET
        CALL    SYNCHK_T
D2140:  DEFB    9Eh                     ; Inline-Parameter
        CALL    FOR_EVALNUM
        LD      DE,FOR_LIMIT
        CALL    VAL_GET
        CALL    CHK_CHR_ALT_T
D214D:  DEFB    9Fh                     ; Inline-Parameter
D214E:  DEFW    FOR_STEP1
        CALL    FOR_EVALNUM
        LD      HL,(VALSP)
        JR      FOR_SETSTEP
FOR_STEP1:
        LD      HL,FP_ONE
FOR_SETSTEP:
        LD      DE,FOR_STEP
; >>> SB-6610: ohne Gegenstück in SB-6511
        LD      BC,0009h
        LDIR
        DEC     HL
        LD      A,(HL)
        LD      (FOR_STEPSGN),A         ; Vorzeichen der Schrittweite merken
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
        LD      BC,001Ah                ; zum nächsten Eintrag (27 Bytes, HL steht auf Byte 1)
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
        LD      BC,001Bh                ; 27 Bytes je FOR-Eintrag
        DEC     DE
        LDDR
        INC     DE
        EX      DE,HL
        LD      (FOR_SP),HL
        JP      NEXTSTMT
; <- aufgerufen von 212Fh, 2141h, 2150h
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
; >>> SB-6610: ohne Gegenstück in SB-6511
        LD      BC,001Ah                ; zum nächsten Eintrag (27 Bytes, HL steht auf Byte 1)
        ADD     HL,BC
        LD      (FOR_SP),HL
        JR      NEXT_SRCH
NEXT_STEP:
        INC     HL
        CALL    NUMVAR
        CALL    FP_PTREXP
        PUSH    DE
        PUSH    HL
        CALL    OP_ADD
        POP     HL
        POP     DE
        INC     HL
        LD      A,(HL)
        LD      BC,0009h
        ADD     HL,BC
        PUSH    HL
        OR      A
        JP      P,NEXT_CMPNEG
        EX      DE,HL
        CALL    FP_CMP
        POP     HL
        JR      C,NEXT_END
NEXT_LOOP2:
        INC     HL
        LD      DE,CURLINE
        LD      BC,0006h
        LDIR
        JP      NEXTSTMT
; <- aufgerufen von 2204h
NEXT_CMPNEG:
        CALL    FP_CMP
        POP     HL
        CCF
        JR      C,NEXT_LOOP2
NEXT_END:
        LD      BC,0007h
        ADD     HL,BC
        LD      (FOR_SP),HL
        LD      HL,FOR_CNT
        DEC     (HL)
        INC     HL
        DEC     (HL)
        CALL    CHK_CHR_ALT_T
D2231:  DEFB    2Ch                     ; Inline-Parameter ','
D2232:  DEFW    NEXTSTMT
        JR      ST_NEXT
; <- aufgerufen von 21CDh
NEXT_CURVAR:
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        DEC     HL
        RET
;  ON ausdruck GOTO/GOSUB z1,z2,... (ON SRQ gibt es in SB-6610 nicht).
;  Wert 0 oder > 255: Rest der Anweisung überspringen; gibt es
;  weniger Ziele als der Wert, geht es mit der nächsten Anweisung weiter.
ST_ON:  CALL    CHK_NODIRECT
ON_EXPR:
        CALL    EVAL
        CALL    CHKSTRTYPE
        CALL    VAL2UINT
D2247:  DEFW    ON_KW
ON_KW:  CALL    SYNCHK
D224C:  DEFB    80h                     ; Inline-Parameter
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
D22A7:  DEFB    80h                     ; Inline-Parameter
D22A8:  DEFW    RES_LINE
        CALL    SYNCHK
D22AD:  DEFB    90h                     ; Inline-Parameter
        LD      HL,(ERRCTX_TXT)
        CALL    SKIPSTMT
        LD      (ERRCTX_TXT),HL
        LD      BC,NEXTSTMT
RES_GO: PUSH    BC
        LD      A,01h
        LD      (ONERR_FLAG),A
        XOR     A
        JP      ERRCTX_COPY
RES_LINE:
        CALL    GETLNUM_SN
        LD      A,D
        OR      E
        JR      Z,RES_ZERO
        CALL    GOTO_DE
        LD      A,01h
        LD      (ONERR_FLAG),A
        JP      NL_NEXT
RES_ZERO:
        CALL    CHRGET
        JP      NZ,ERR_01
        CALL    CLR_ONERR
        JP      RUN_START
;  DIM name[$](n[,m])[,...] – höchstens zwei Dimensionen; n bei
;  eindimensionalen Feldern auch über 255, sonst je 0-255.
;  Ein schon vorhandenes Feld wird übergangen (passen die neuen Grenzen
;  nicht hinein: Fehler 3).
;  Eintrag: Name (2), Dimensionen (2), dann (n+1)*(m+1) Elemente:
;  Zahlen 9 Bytes (0), Strings 2 Bytes (Länge 0, 0Dh).
ST_DIM: CALL    GETNAME_SN
        LD      BC,0000h
        CP      24h                     ; '$'
        JR      NZ,DIM_PAR
        INC     HL
        INC     B
DIM_PAR:
        CALL    SYNCHK
D22F1:  DEFB    28h                     ; Inline-Parameter '('
        CALL    ARR_FIND
        JR      NZ,DIM_NEXT
        PUSH    HL
        LD      HL,(ARR_DIMS)
; >>> SB-6610: ohne Gegenstück in SB-6511
        LD      D,A
        LD      E,A
        LD      A,(ARR_NDIM)
        OR      A
        JR      Z,DIM_SIZE2
        LD      E,H
        LD      H,00h
DIM_SIZE2:
        INC     HL
        INC     DE
        CALL    MUL16
        DEFW    ERR_06                  ; Inline-Parameter
        LD      A,(ARR_TYPE)
        OR      A
        POP     HL
        PUSH    DE
        PUSH    HL
        LD      HL,0002h
        JR      NZ,DIM_SIZE
        LD      L,09h
DIM_SIZE:
        CALL    MUL16
D231E:  DEFW    ERR_06
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
D2355:  DEFB    2Ch                     ; Inline-Parameter ','
D2356:  DEFW    NEXTSTMT_HL
        JR      ST_DIM
DIM_NUMINIT:
        EX      DE,HL
DIM_NUM_LP:
        PUSH    BC
        LD      HL,FP_ZERO
; >>> SB-6610: ohne Gegenstück in SB-6511
        LD      BC,0009h
        LDIR
        POP     BC
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,DIM_NUM_LP
        JR      DIM_NEXT
ARR_NDIM:
        DEFB    00h
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
;  NZ, HL hinter den Dimensionen. Der erste Index darf in SB-6610 bis
;  65535 gehen (EVAL_INT statt EVAL_BYTE), der zweite bis 255 (ARR_DIM2CHK).
; <- aufgerufen von 22F2h, 288Dh
ARR_FIND:
        PUSH    DE
        PUSH    BC
        CALL    EVAL_INT                ; [SB-6511: CALL EVAL_BYTE]
        POP     BC
        LD      A,(HL)
        CP      2Ch                     ; ','
        CALL    Z,ARR_DIM2CHK                 ; [SB-6511: CALL Z,ARR_DIM2]
        CALL    SYNCHK
D2381:  DEFB    29h                     ; Inline-Parameter ')'
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
; >>> SB-6610: ohne Gegenstück in SB-6511
        LD      (ARR_NDIM),A
        OR      A
        JR      NZ,ARR_SRCH
        ADD     HL,DE
ARR_SRCH:
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
ARR_SRCHLP:
        CALL    LISTKEY_CMP
        DEFW    ARR_NOTFOUND                   ; Inline-Parameter
        JR      Z,ARR_FOUND
        LD      E,(HL)
        INC     HL
        PUSH    HL
        LD      A,(ARR_NDIM)
        OR      A
        JR      Z,ARR_SKIP1D
        LD      L,(HL)
        LD      D,00h
        LD      H,D
ARR_SKIP:
        INC     HL
        INC     DE
        CALL    MUL16_ERR
        LD      A,(ARR_TYPE)
        OR      A
        JR      NZ,ARR_SKIPSTR
        LD      HL,0009h
        CALL    MUL16_ERR
        POP     HL
        ADD     HL,DE
        INC     HL
        JR      ARR_SRCHLP
ARR_SKIP1D:
        LD      D,(HL)
        LD      HL,0000h
        JR      ARR_SKIP
ARR_SKIPSTR:
        POP     HL
        INC     HL
        LD      B,00h
ARR_SKSTRLP:
        LD      C,(HL)
        INC     HL
        INC     HL
        ADD     HL,BC
        DEC     DE
        LD      A,D
        OR      E
        JR      NZ,ARR_SKSTRLP
        JR      ARR_SRCHLP
ARR_NOTFOUND:
        XOR     A                       ; nicht gefunden: A = 0
        RET
ARR_FOUND:
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        INC     HL
        PUSH    HL
        LD      H,B
        LD      L,C
        LD      DE,(ARR_DIMS)
        CALL    CPHLDE
        JP      C,ERR_03
        POP     HL
        LD      A,01h
        OR      A
        RET
; <- aufgerufen von 237Bh
ARR_DIM2CHK:
        LD      A,D
        OR      A
        JP      NZ,ERR_03
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
        CALL    PROG_CLRVARS                   ; [SB-6511: CALL CLR_AREAS]
        POP     HL
        JR      POKE_DONE
;  IF bedingung THEN zeile | THEN anweisung | GOTO zeile | GOSUB zeile
;  IF EOF(#n) ... – Sonderform für Dateien (GETFILENO/FTAB_FIND, Fehler 44).
;  Bedingung = 0: Rest der Zeile überspringen (IF_FALSE).
ST_IF:  CALL    CHK_NODIRECT
        CALL    CHK_CHR_ALT
D2433:  DEFB    0AEh                    ; Inline-Parameter
D2434:  DEFW    IF_COND
        CALL    GETFILENO
        JP      Z,ERR_01
        LD      B,A
        CALL    CHK_RPAR
        PUSH    HL
        LD      A,B
        CALL    FTAB_FIND
D2445:  DEFW    ERR_44
        LD      BC,0008h
        ADD     HL,BC
        LD      A,(HL)
        POP     HL
        OR      A
        JR      NZ,IF_THEN
IF_FALSE:
        JP      NEXTLINE
IF_COND:
        CALL    EVAL_EXPR
        CALL    CHKSTRTYPE
        LD      IX,(VALSP)
        LD      A,(IX+8)
        OR      A
        JR      Z,IF_FALSE
IF_THEN:
        CALL    SYNCHK
D2466:  DEFB    80h                     ; Inline-Parameter
        SUB     8Ch
        INC     HL
        CP      02h
        JP      Z,ST_GOSUB
IF_ERR: JP      NC,ERR_01
        OR      A
        CALL    Z,IF_THENNUM
        JP      ST_GOTO
; <- aufgerufen von 2473h
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
D248F:  DEFB    28h                     ; Inline-Parameter '('
        SUB     41h
        CP      1Ah
        JR      NC,IF_ERR
        LD      D,(HL)
        INC     HL
        CALL    SYNCHK
D249B:  DEFB    29h                     ; Inline-Parameter ')'
        CALL    SYNCHK
D249F:  DEFB    3Dh                     ; Inline-Parameter '='
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
; <- aufgerufen von 271Eh, 38CBh
EVAL_EXPR_INC:
        INC     HL
;  Ausdrucksauswertung (Rangfolge von unten nach oben):
;  EVAL_EXPR  Vergleiche (Token 83h-8Bh, "=" -> 89h); Strings über STRCMP
;  EVAL       + und - (Strings: + verkettet, > 255 Zeichen: Fehler 5)
;  TERM       * und /
;  POWER      ^
;  PRIMARY    Vorzeichen, Zahl, Variable, FN, "(", String, Funktion, Pi
;  Ergebnis: D = 0 Zahl (Wert bei (VALSP), 9 Bytes), D <> 0 String
;  (E = Nummer, siehe GETSTR). A = nächstes Zeichen.
; <- aufgerufen von 1F60h, 2453h, 3882h, 50F3h
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
; <- aufgerufen von 2548h
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
; <- aufgerufen von 2537h, 26D8h
EVAL_INC:
        INC     HL
; <- aufgerufen von 1C47h, 205Ah, 21B4h, 223Eh, 24EEh, 2513h, 278Ah, 27DAh (+14 weitere)
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
; <- aufgerufen von 25C0h, 25EEh
TERM_INC:
        INC     HL
; <- aufgerufen von 25C9h
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
; <- aufgerufen von 2613h
POWER:  CALL    PRIMARY
POWER_OP:
        CP      5Eh                     ; '^'
        RET     NZ
        LD      A,10h
        EXX
        LD      BC,POWER_OP
        LD      DE,POWER_NEXT
;  APPLY_OP – Operator A (Index in FUNC_TAB) anwenden. Linker Wert liegt
;  auf dem Wertestack (VALSP wird um 9 erhöht), DE = Routine für den
;  rechten Operanden, BC = Fortsetzung danach. Beide müssen Zahlen sein
;  (sonst Fehler 4). TERM_NEXT/POWER_NEXT sind solche Fortsetzungen: INC HL
;  überspringt das Operatorzeichen.
; <- aufgerufen von 2531h
APPLY_OP:
        PUSH    BC
        LD      HL,(VALSP)
        LD      BC,0009h
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
; >>> SB-6610: ohne Gegenstück in SB-6511
        LD      BC,0FFF7h
        LD      E,L
        LD      D,H
        ADD     HL,BC
        LD      (VALSP),HL
        EX      DE,HL
        CALL    FP_PTREXP
        LD      BC,PRIM_RET
        PUSH    BC
        JP      (IY)
; <- aufgerufen von 273Ah
PRIM_PUTVAL:
        CALL    VAL_PUT
; <- aufgerufen von 27F7h
PRIM_RET:
        POP     HL
; <- aufgerufen von 2580h, 2730h
PRIM_RETHL:
        LD      BC,0009h
        LD      D,B
        LD      E,B
        LD      A,(HL)
        RET
POWER_NEXT:
        INC     HL                      ; Fortsetzung nach ^: Operator überspringen, nächster Faktor
;  PRIMARY – ein Operand mit Vorzeichen. Zeichen FFh steht für Pi.
;  Funktions-Token: A0h-B3h über FUNC_TAB ab Eintrag 17 (Argumente liest
;  die Funktion selbst), C0h-CBh über D2975 (Argument wird vorher
;  ausgewertet).
; <- aufgerufen von 262Ch
PRIMARY:
        CALL    SKIPSP
        CP      2Bh                     ; '+'
        JR      Z,PRIM_INC
        CP      2Dh                     ; '-'
        JR      NZ,PRIM_NAME
        CALL    PRIM_INC
;  NEG_VAL – Wert bei (VALSP) negieren (Bit 7 des Exponentbytes, 0 bleibt).
; <- aufgerufen von 25C3h
NEG_VAL:
        EXX
        LD      HL,(VALSP)
        LD      BC,0008h
        ADD     HL,BC
        CALL    FP_ISZERO
        JR      Z,NEG_DONE
        LD      A,(HL)
        ADD     A,80h
        LD      (HL),A
NEG_DONE:
        EXX
        LD      A,(HL)
        RET
; <- aufgerufen von 2690h
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
D26E1:  DEFB    29h                     ; Inline-Parameter ')'
        POP     AF
        PUSH    HL
        LD      HL,PRIM_RET
        PUSH    HL
        LD      HL,(VALSP)
        LD      BC,0008h
        ADD     HL,BC
        EX      DE,HL
        LD      HL,FUNC_TAB+2*37
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
PRIM_NUMCHK:
        CALL    NUMCHR
        JR      Z,PRIM_NUM
PRIM_ERR:
        JP      ERR_01
PRIM_PAREN:
        LD      BC,0000h
        CALL    CHKMEM2
        CALL    EVAL_EXPR_INC
        JP      CHK_RPAR
; >>> SB-6610: ohne Gegenstück in SB-6511
PRIM_NUM:
        EX      DE,HL
        LD      HL,(VALSP)
        LD      BC,0008h
        ADD     HL,BC
        EX      DE,HL
        CALL    STR2NUM
        JP      PRIM_RETHL
PRIM_PI:
        CALL    SKIPSP_INC
        PUSH    HL
        LD      DE,FP_PI
        JP      PRIM_PUTVAL
; <- aufgerufen von 1F6Dh, 26B8h, 2B50h, 2BA0h, 2C5Ch, 3D0Fh
GETVAR: LD      A,(HL)
        CP      24h                     ; '$'
        JP      Z,STRVAR
        CP      28h                     ; '('
        JP      Z,ARR_NUMELEM
;  NUMVAR – Zahlvariable DE (Name) in P_NUMVAR suchen, fehlt sie, wird sie
;  mit Wert 0 angelegt. Zurück: DE = Adresse des Werts, B = 0, C = 5.
; <- aufgerufen von 2137h, 21EFh, 27AEh, 27EDh
NUMVAR: PUSH    HL
        LD      HL,(P_NUMVAR)
; >>> SB-6610: ohne Gegenstück in SB-6511
        LD      BC,0009h
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
        LD      C,0Bh
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
        LD      C,09h
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
; <- aufgerufen von 26B5h
FN_CALL:
        LD      A,(HL)
        SUB     41h
        CP      1Ah
        JP      NC,ERR_01
        LD      E,(HL)
        INC     HL
        CALL    SYNCHK
D2788:  DEFB    28h                     ; Inline-Parameter '('
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
; >>> SB-6610: ohne Gegenstück in SB-6511
        LD      BC,0FFF6h
        ADD     HL,BC
        LD      (FNPAR_SP),HL
        POP     DE
        LD      (HL),E
        INC     HL
        POP     DE
        LD      BC,0009h
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
; <- aufgerufen von 2740h
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
D2815:  DEFW    LK2_NEW                 ; Inline-Parameter: Listenende -> neuer Eintrag
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
; <- aufgerufen von 2855h
TI_DIV0:
        XOR     A
; <- aufgerufen von 284Fh
TI_DIV: ADD     HL,DE
        JR      NC,TI_DIVEND
        INC     A
        JR      TI_DIV
TI_DIVEND:
        OR      A
        SBC     HL,DE
; <- aufgerufen von 2859h
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
; <- aufgerufen von 27FFh
ARR_STRELEM:
        LD      BC,0100h
        JR      ARR_ELEM
; <- aufgerufen von 2745h
ARR_NUMELEM:
        LD      BC,0000h
ARR_ELEM:
        INC     HL
        CALL    ARR_FIND
        JP      Z,ERR_03
        PUSH    HL
; >>> SB-6610: ohne Gegenstück in SB-6511
        LD      A,(ARR_NDIM)
        OR      A
        JR      Z,ARR_ELEM2
        LD      L,C
        LD      H,00h
        LD      C,E
        LD      E,D
        LD      B,H
        LD      D,H
ARR_ELEMOFS:
        PUSH    BC
        INC     HL
        CALL    MUL16_ERR
        POP     HL
        ADD     HL,DE
        EX      DE,HL
        LD      A,(ARR_TYPE)
        OR      A
        JR      NZ,ARR_STRPOS
        LD      HL,0009h
        CALL    MUL16_ERR
        POP     HL
        ADD     HL,DE
        LD      BC,0009h
        JR      ARR_ELEMRET
ARR_ELEM2:
        LD      H,B
        LD      L,C
        LD      B,D
        LD      C,E
        LD      DE,0000h
        JR      ARR_ELEMOFS                   ; [SB-6511: JR ARR_ELEMRET]
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
; <- aufgerufen von 21C4h, 26A8h, 2919h
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
; <- aufgerufen von 1F6Ah, 2127h, 22E2h, 2B4Dh, 2B9Dh, 2C59h, 3D0Ch
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
;               zu 89h (EVAL_EXPR, 2516h)
;  Index 12-16: + - * / ^ (keine Token, Index im Code gesetzt)
;  Index 17-36: Token A0h-B3h (LEFT$( .. POS), Einsprung 294Dh = Eintrag 17
;  Index 37-48: Token C0h-CBh (RND( .. SQR(), Einsprung D2975 = Eintrag 37
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
        DEFW    ERR_01                  ; 16: Potenz ^ – fehlt in SB-6610 -> Syntax Error
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
        DEFW    FN_RND                  ; 37: RND(
        DEFW    ERR_01                  ; 38: SIN( – fehlt in SB-6610 -> Syntax Error
        DEFW    ERR_01                  ; 39: COS( – fehlt in SB-6610 -> Syntax Error
        DEFW    ERR_01                  ; 40: TAN( – fehlt in SB-6610 -> Syntax Error
        DEFW    ERR_01                  ; 41: ATN( – fehlt in SB-6610 -> Syntax Error
        DEFW    ERR_01                  ; 42: EXP( – fehlt in SB-6610 -> Syntax Error
        DEFW    FN_INT                  ; 43: INT(
        DEFW    ERR_01                  ; 44: LOG( – fehlt in SB-6610 -> Syntax Error
        DEFW    ERR_01                  ; 45: LN( – fehlt in SB-6610 -> Syntax Error
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
; <- aufgerufen von 243Dh, 2721h, 2790h, 2997h, 2A05h, 2A0Eh, 2A1Eh, 2A3Fh (+6 weitere)
CHK_RPAR:
        CALL    SYNCHK
D29AF:  DEFB    29h                     ; Inline-Parameter ')'
        RET
; <- aufgerufen von 29A9h
RIGHT_ARGS:
        CALL    EVAL
        CALL    SKIPCOMMA
        PUSH    DE
        CALL    EVAL_BYTE
        JR      RIGHT_DO
; <- aufgerufen von 29F2h
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
        LD      HL,0000h
        LD      (USING_PTR),HL
        LD      HL,(VALSP)
        LD      DE,61B3h
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
VAL_ZERO:
        LD      HL,STR_ZERO
VAL_EVAL:
        CALL    NUMSTR_EVAL
D2A4C:  DEFW    VAL_ZERO
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
; >>> SB-6610: ohne Gegenstück in SB-6511
; <- aufgerufen von 2AF1h
RET_A:  CALL    BYTE2VAL
        JP      SKIPSP
;  BYTE2VAL – A (0-255) als ganze Zahl (E = 40h) nach (VALSP).
; <- aufgerufen von 2A62h, 2B8Eh
BYTE2VAL:
        CALL    BYTE2BCD
        PUSH    HL
        LD      HL,(VALSP)
        LD      DE,0006h
B2V_CLRLP:  LD      (HL),D
        INC     HL
        DEC     E
        JR      NZ,B2V_CLRLP
        LD      (HL),B
        INC     HL
        LD      (HL),C
        INC     HL
        LD      (HL),40h
        LD      C,09h
        LD      B,D
        POP     HL
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
; <- aufgerufen von 2A15h, 2B78h, 387Dh, 5A0Ah
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
; >>> SB-6610: ohne Gegenstück in SB-6511
        CALL    POINT_GET
        JP      RET_A
;  SIZE – freier Speicher. ERL, ERN – Fehlerzeile bzw. -nummer, außerhalb
;  des Fehlerbehandlers 0.
FN_SIZE:
        PUSH    HL
        CALL    MEMFREE
;  INT_RET – DE (0-65535) als Zahl zurückgeben (über PRTNUM/EVAL); auch für
;  ERL/ERN (ERR_VALRET: 0 außerhalb des Fehlerbehandlers).
; <- aufgerufen von 59ABh
INT_RET:
        CALL    PRTNUM
        EX      DE,HL
        CALL    EVAL
        POP     HL
        LD      A,(HL)
        RET
FN_ERL: LD      DE,(ERRCTX_LNUM)
        JR      ERR_VALRET
FN_ERN: LD      DE,(ERRNUM)
ERR_VALRET:
        PUSH    HL
        LD      A,(ONERR_FLAG)
        LD      HL,0000h
        CP      02h
        JR      NZ,INT_RET
        EX      DE,HL
        JR      INT_RET
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
D2B34:  DEFB    2Ch                     ; Inline-Parameter ','
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
;  GET_LASTKEY: Byte +1 = zuletzt von GET gelesene Taste (neu in SB-6610:
;  eine gehaltene Taste liefert nur einmal ein Zeichen, danach "" bzw. 0)
GET_LASTKEY:
        DEFB    00h,00h
;  GET var – Taste ohne Warten lesen (INKEY). String: das Zeichen oder "";
;  Zahl: Ziffernwert, sonst 0.
ST_GET: CALL    GETNAME_SN
        CALL    GETVAR
        LD      (TXTPTR),HL
        CALL    SAVEPAR1
; >>> SB-6610: ohne Gegenstück in SB-6511
        LD      A,(GET_LASTKEY+1)
        LD      B,A
        CALL    INKEY
        CP      B
        JR      Z,GET_KEY0
        LD      (GET_LASTKEY+1),A
GET_KEY0:
        JR      NZ,GET_KEYOK
        XOR     A
GET_KEYOK:
        PUSH    AF
        LD      A,(6005h)
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
D2B81:  DEFW    ERR_04
; >>> SB-6610: ohne Gegenstück in SB-6511
        JP      NEXTSTMT
GET_NUM:
        POP     AF
        SUB     30h
        CP      0Ah
        JR      C,GET_NUMVAL
        XOR     A
; <- aufgerufen von 2C67h
GET_NUMVAL:
        CALL    BYTE2VAL
        JR      GET_ASSIGN
;  USR(adresse [, var$]) – Maschinenprogramm aufrufen, zurück über
;  NEXTSTMT (liegt als Rücksprung auf dem Stack). Mit var$ liefert GETVAR
;  deren Angaben in BC/DE (B = 0); eine Zahlvariable ergibt Fehler 4.
ST_USR: CALL    EVAL_ADDR
        PUSH    DE
        CALL    CHK_CHR_ALT
D2B9A:  DEFB    2Ch                     ; Inline-Parameter ','
D2B9B:  DEFW    USR_CALL
        CALL    GETNAME_SN
        CALL    GETVAR
        LD      A,B
        OR      A
        JP      Z,ERR_04
        LD      B,00h
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
; <- aufgerufen von 2411h, 2418h, 2A0Bh, 2A82h, 2B93h, 2BC8h, 4B04h
EVAL_ADDR:
        CALL    CHK_CHR_ALT
D2BF3:  DEFB    24h                     ; Inline-Parameter '$'
D2BF4:  DEFW    ADDR_DEC
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
; <- aufgerufen von 1D47h, 1F13h, 2C2Bh, 3BB6h
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
        CALL    EVAL_BYTE               ; [SB-6511: CALL EVAL_ADDR]
        CALL    SKIPCOMMA
        LD      A,E
        LD      (INPAT_IN+1),A
        CALL    GETNAME_SN
        CALL    GETVAR
        LD      (TXTPTR),HL
        CALL    SAVEPAR1
INPAT_IN:
        IN      A,(PRN_DAT)
        JP      GET_NUMVAL
;  OUT@ port, wert – unteres Byte des Werts an den Port ausgeben (Portnummer wird in
;  den OUT-Befehl geschrieben).
ST_OUTAT:
        CALL    EVAL_BYTE               ; [SB-6511: CALL EVAL_ADDR]
        CALL    SKIPCOMMA
        LD      A,E
        LD      (OUTAT_OUT+1),A
        CALL    EVAL_BYTE               ; [SB-6511: CALL EVAL_ADDR]
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
D2C88:  DEFB    2Ch                     ; Inline-Parameter ','
D2C89:  DEFW    AUTO_START
        JR      AUTO_LINE10
AUTO_START:
        CALL    AUTO_NUM
        LD      (AUTO_LINE),DE
        CALL    CHRGET
        JR      Z,AUTO_STEP10
        CALL    CHK_CHR_ALT
D2C9C:  DEFB    2Ch                     ; Inline-Parameter ','
D2C9D:  DEFW    ERR_01
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
; <- aufgerufen von 2C8Dh, 2C9Fh
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
D2D08:  DEFB    29h                     ; Inline-Parameter ')'
        CALL    DEFKEY_SYNCHK
D2D0C:  DEFB    3Dh                     ; Inline-Parameter '='
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
        LD      HL,1221h                ; Grenze 1221h (SB-6511: FKEY_LIMIT = 1201h)
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
; <- aufgerufen von 2D05h, 2D09h
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
; <- aufgerufen von 2D0Eh
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
; ==============================================================================
;  BCD-ARITHMETIK (DOUBLE PRECISION) UND MATHEMATISCHE FUNKTIONEN
; ==============================================================================
;  Zahlformat (9 Bytes):
;    Byte 0-7  Mantisse M, 16 BCD-Ziffern, höchstwertige zuerst
;    Byte 8    Exponentbyte: Bit 7 = Vorzeichen (1 = negativ),
;              Bits 6-0 = E; Wert = M * 10^(E-40h)
;  Ganze Zahlen bis 16 Stellen stehen unnormiert mit E = 40h (1 = 00 .. 01 40),
;  sonst normiert mit führender Ziffer <> 0 (0,5 = 50 00 .. 30). Null: alle
;  9 Bytes 00h. Größter Betrag FP_MAX = 9999999999999999 * 10^3Fh.
;  Die Routinen bekommen meist Zeiger auf das Exponentbyte (Byte 8); die
;  Mantisse liegt in den 8 Bytes darunter. Grundrechenarten: (DE) = (DE) op
;  (HL). Nach jeder Rechnung bringt FP_INTFORM ganzzahlige Ergebnisse wieder
;  auf E = 40h. Überlauf: FP_MAX mit Vorzeichen, Fehler 2; Unterlauf: 0.
;  ^, SIN, COS, TAN, ATN, EXP, LOG und LN gibt es in SB-6610 nicht (Fehler 1);
;  laut Handbuch (2.4.4) stehen BASIC-Unterprogramme dafür in der Datei
;  "FUNCTION" der Systemdiskette. Zahlenbereich laut Handbuch 1E-48 bis
;  9.999999999999999E+78.
FPA_FLAG:
        DEFB    00h
FPA_SIGN:
        DEFB    00h
FPA_EXP:
        DEFB    00h
        DEFB    00h,00h,00h,00h,00h
;  FP_TMP1/FP_TMP2: normierte Kopien der Operanden (FP_NORMCOPY), bei
;  SQR Radikand bzw. Rest. NUMBUF: Ausgabetext von NUM2STR (Vorzeichen,
;  Ziffern, Punkt, E+nn, 0Dh) überlagert beide.
NUMBUF:
FP_TMP1:
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h,00h
FP_TMP2:
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h,00h
;  FP_DIG: Ziffernpuffer. MUL: 32-stelliges Produkt gepackt (FP_DIG+1 ..
;  +16); DIV und SQR: eine Ziffer je Byte; NUM2STR: entpackte Mantisse als
;  ASCII-Ziffern.
FP_DIG:
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h
FPR_EXP:
        DEFB    00h                     ; Exponent und Vorzeichen des Ergebnisses
FPR_PTR:
        DEFW    0000h                   ; Zeiger in FP_DIG bzw. das Ergebnis
;  Konstanten, 9 Bytes: Mantisse (16 BCD-Ziffern, höchstwertige zuerst),
;  dann Exponentbyte. FP_ZERO und FP_MONE überlappen.
FP_ONE: DEFB    00h,00h,00h,00h,00h,00h,00h,01h,40h     ; 1
FP_ZERO:
        DEFB    00h,00h                                 ; 0 (bis FP_MONE+6)
FP_MONE:
        DEFB    00h,00h,00h,00h,00h,00h,00h,01h,0C0h    ; -1
FP_PI:  DEFB    31h,41h,59h,26h,53h,58h,97h,93h,31h     ; 3.141592653589793
FP_MAX: DEFB    99h,99h,99h,99h,99h,99h,99h,99h,7Fh     ; größter Betrag (bei Überlauf)
;  FP_NORM – (HL) normieren (HL zeigt auf das Exponentbyte): führende
;  Null-Bytes und eine führende Null-Ziffer herausschieben, E entsprechend
;  verkleinern. Mantisse 0: Exponent 0, Z gesetzt. Unterlauf (E < 1):
;  FP_SETZERO. Sonst NZ. Die Schiebeweite steht über selbstverändernden
;  Code in FPN_MOVCNT..FPN_EXPMIN.
; <- aufgerufen von 2EC7h, 2ECEh, 3004h, 30B3h, 32EEh, 3502h, 360Eh, 367Eh
FP_NORM:
        LD      A,(HL)                  ; Exponentbyte 0: Wert ist 0
        AND     A
        JP      Z,FP_SETZERO
        PUSH    HL
        PUSH    DE
FPN_LOOP:  LD      BC,0FFF8h            ; HL -> höchstes Mantissenbyte
        ADD     HL,BC
        LD      A,(HL)
        AND     A
        JR      NZ,FPN_NIBBLE           ; höchstes Byte <> 0: nur noch Ziffern prüfen
        LD      D,H
        LD      E,L
        LD      C,00h                   ; C = Zahl der Null-Bytes
        LD      B,08h
FPN_CNTZERO:  LD      A,(HL)
        AND     A
        JR      NZ,FPN_SHBYTES
        INC     HL
        INC     C
        DJNZ    FPN_CNTZERO
        LD      (HL),00h                ; Mantisse ganz 0: Exponent 0
        XOR     A                       ; A = 0, Z
        JR      FPN_RET
FPN_SHBYTES:  LD      A,08h             ; 8 - C Bytes nach oben schieben ...
        SUB     C
        LD      (FPN_MOVCNT+1),A
        LD      A,C
        LD      (FPN_FILLCNT+1),A       ; ... C Bytes mit 0 auffüllen ...
        ADD     A,A
        LD      (FPN_EXPSUB+1),A        ; ... Exponent um 2*C verkleinern (Grenze 2*C+1)
        INC     A
        LD      (FPN_EXPMIN+1),A
        LD      B,00h
FPN_MOVCNT:  LD      C,00h
        LDIR
        EX      DE,HL
FPN_FILLCNT:  LD      B,00h
FPN_FILL:  LD      (HL),C
        INC     HL
        DJNZ    FPN_FILL
        LD      A,(HL)
        AND     7Fh
FPN_EXPMIN:  CP      00h                ; Exponent zu klein: Unterlauf
        JR      C,FPN_UNDER
        LD      A,(HL)
FPN_EXPSUB:  SUB     00h
        LD      (HL),A
        JR      FPN_LOOP                ; erneut prüfen
FPN_NIBBLE:  AND     0F0h               ; führende Ziffer <> 0: fertig
        JR      NZ,FPN_RET
        SBC     HL,BC                   ; HL wieder auf den Exponenten
        LD      A,(HL)
        AND     7Fh
        CP      02h
        JR      C,FPN_UNDER
        DEC     (HL)                    ; Exponent - 1, Mantisse eine Ziffer nach links
        LD      B,08h
        XOR     A
FPN_RLD: DEC     HL
        RLD
        DJNZ    FPN_RLD
        LD      A,01h                   ; NZ: Wert <> 0
        AND     A
FPN_RET: POP     DE
        POP     HL
        RET
FPN_UNDER: POP     DE
        POP     HL
        JP      FP_SETZERO
;  FP_NORMCOPY – beide Operanden normiert kopieren: (HL) nach FP_TMP1,
;  (DE) nach FP_TMP2 (Zeiger jeweils auf das Exponentbyte). Ergebnis:
;  DE -> FP_TMP1+8 (Kopie von HL), HL -> FP_TMP2+8 (Kopie von DE).
; <- aufgerufen von 30F4h, 346Ch
FP_NORMCOPY:
        PUSH    DE
        LD      DE,FP_TMP1+8            ; (HL) -> FP_TMP1
        PUSH    DE
        LD      BC,0009h
        LDDR
        POP     DE
        POP     HL
        PUSH    DE
        LD      DE,FP_TMP2+8            ; (DE) -> FP_TMP2
        LD      BC,0009h
        LDDR
        POP     HL
        CALL    FP_NORM                 ; beide normieren
        EX      DE,HL
        LD      HL,FP_TMP2+8
        JP      FP_NORM
;  FP_SHR1 – Mantisse von (HL) um eine Ziffer nach rechts, E + 1.
;  A = herausgeschobene Ziffer, CY = 1 wenn sie >= 5 ist (aufrunden).
; <- aufgerufen von 2F0Ch, 2F11h, 2F93h
FP_SHR1:
        INC     (HL)                    ; Exponent + 1
        LD      BC,0FFF8h
        ADD     HL,BC
        XOR     A
        LD      B,08h
FSR1_LP: RRD                            ; Ziffern von oben nach unten durchschieben, A = letzte
        INC     HL
        DJNZ    FSR1_LP
        CP      05h                     ; CY = herausgeschobene Ziffer >= 5
        CCF
        RET
;  FSRN_BYTES – Teil von FP_SHRN: Mantisse um ganze Bytes nach rechts
;  (Weite über selbstverändernden Code), CY = 1 wenn das letzte
;  herausgeschobene Byte >= 50h ist.
; <- aufgerufen von 2F2Dh
FSRN_BYTES:
        PUSH    HL
        PUSH    DE
        LD      A,(HL)
FSRB_EXPADD: ADD     A,08h              ; Exponent + 2*Bytes (Operand aus FP_SHRN)
        LD      (HL),A
        DEC     HL
        LD      D,H
        LD      E,L
FSRB_SRCOFS: LD      BC,0FFFDh          ; Quelle = Ziel - Bytes
        ADD     HL,BC
        LD      A,(HL)
        DEC     HL
FSRB_MOVCNT: LD      BC,0004h           ; 8 - Bytes Bytes verschieben
        LDDR
        EX      DE,HL
FSRB_FILLCNT: LD      B,04h             ; oben mit 0 füllen
FSRB_FILL: LD      (HL),C
        DEC     HL
        DJNZ    FSRB_FILL
        POP     DE
        POP     HL
        CP      50h                     ; CY = letztes herausgeschobenes Byte >= 50h
        CCF
        RET
;  FP_SHRN – Mantisse von (HL) um A Ziffern nach rechts, E + A (A >= 16:
;  Wert 0). Ungerade Weite zuerst eine Ziffer mit FP_SHR1, dann ganze
;  Bytes mit FSRN_BYTES. CY: aufrunden.
; <- aufgerufen von 2F71h, 3028h
FP_SHRN:
        CP      10h                     ; 16 Ziffern oder mehr: Ergebnis 0
        JP      NC,FP_SETZERO
        SRA     A                       ; A = Bytes, CY = ungerade
        JR      NZ,FSRN_BYTES1
        CALL    C,FP_SHR1               ; nur eine Ziffer
        RET
FSRN_BYTES1: PUSH    AF
        CALL    C,FP_SHR1
        POP     AF
        LD      (FSRB_FILLCNT+1),A      ; Schiebeweiten in FSRN_BYTES eintragen
        LD      C,A
        ADD     A,A
        LD      (FSRB_EXPADD+1),A
        LD      A,08h
        SUB     C
        LD      (FSRB_MOVCNT+1),A
        SUB     08h
        LD      C,A
        LD      B,0FFh
        INC     BC
        LD      (FSRB_SRCOFS+1),BC
        JP      FSRN_BYTES
;  MANT_INCNC – Mantisse unterhalb von HL um 1 - CY erhöhen (Rundung mit
;  umgekehrtem Übertrag); Überlauf der Mantisse über MANT_CARRY.
; <- aufgerufen von 321Dh, 369Ah
MANT_INCNC:
        CCF
        PUSH    HL
        LD      B,08h
MINC_LP: DEC     HL
        LD      A,(HL)
        ADC     A,00h
        DAA
        LD      (HL),A
        DJNZ    MINC_LP
        POP     HL
        RET     NC
        JP      MANT_CARRY
;  MANT_INC – Mantisse unterhalb von HL um 1 erhöhen (BCD); der Übertrag
;  läuft so weit nach oben wie nötig.
; <- aufgerufen von 2F97h, 302Bh, 3099h
MANT_INC:
        SCF
; <- aufgerufen von 2F49h
MANT_INCLP:
        DEC     HL
        LD      A,(HL)
        ADC     A,00h
        DAA
        LD      (HL),A
        RET     NC
        JP      MANT_INCLP
;  FP_INTFORM – (DE) in Ganzzahlform bringen: Ist der Wert ganz (alle
;  Ziffern hinter dem Komma 0) und passt er in 16 Stellen, wird die Mantisse
;  nach rechts geschoben, bis E = 40h ist. Sonst bleibt (DE) unverändert.
; <- aufgerufen von 306Ch, 30B7h, 3220h, 3682h
FP_INTFORM:
        LD      A,(DE)                  ; E - 40h >= 0: schon ganzzahlig (oder zu groß)
        AND     7Fh
        SUB     40h
        RET     P
        NEG                             ; Zahl der Nachkommastellen
        CP      10h                     ; 16 oder mehr: nicht ganzzahlig darstellbar
        RET     P
        LD      B,A
        LD      C,A
        LD      H,D
        LD      L,E
FIF_SCAN:  DEC     HL                   ; Nachkommastellen von unten prüfen
        LD      A,(HL)
        AND     A
        JR      Z,FIF_ZEROB
        LD      A,B
        CP      02h                     ; Byte <> 0 mit zwei Nachkommaziffern: nicht ganz
        RET     P
        LD      A,(HL)                  ; nur eine Nachkommaziffer: untere Ziffer muss 0 sein
        AND     0Fh
        RET     NZ
        JR      FIF_SHIFT
FIF_ZEROB:  DEC     B                   ; Null-Byte: zwei Ziffern weniger zu prüfen
        JR      Z,FIF_SHIFT
        DJNZ    FIF_SCAN
FIF_SHIFT:  EX      DE,HL               ; Nachkommastellen herausschieben, E = 40h
        LD      A,C
        CALL    FP_SHRN
        EX      DE,HL
        RET
;  MANT_ADD – Mantissen addieren: (BC) = (DE) + (HL), 8 Bytes BCD (alle
;  Zeiger auf das Exponentbyte). Übertrag aus der höchsten Stelle:
;  MANT_CARRY.
; <- aufgerufen von 3049h, 3068h
MANT_ADD:
        PUSH    BC
        EX      AF,AF'                  ; CY' = 0
        AND     A
        EX      AF,AF'
        LD      A,08h                   ; 8 Bytes, von unten
; <- aufgerufen von 2F86h
MADD_LP:
        EX      AF,AF'
        DEC     DE
        DEC     HL
        DEC     BC
        LD      A,(DE)                  ; Byte + Byte + Übertrag, dezimal
        ADC     A,(HL)
        DAA
        LD      (BC),A
        EX      AF,AF'
        DEC     A
        JP      NZ,MADD_LP
        EX      AF,AF'
        POP     HL                      ; HL = Ergebnis
        RET     NC                      ; kein Übertrag: fertig
;  MANT_CARRY – Übertrag aus der Mantisse (HL): E = 7Fh -> Überlauf
;  (FP_OVERFLOW); sonst eine Ziffer nach rechts (E + 1, runden) und die
;  übergelaufene 1 als führende Ziffer einsetzen.
; <- aufgerufen von 2F3Eh
MANT_CARRY:
        LD      A,(HL)                  ; Exponent 7Fh?
        OR      80h
        INC     A
        JP      Z,FP_OVERFLOW           ; ja: Überlauf
        CALL    FP_SHR1                 ; eine Ziffer nach rechts (E + 1) ...
        PUSH    HL
        CALL    C,MANT_INC              ; ... und runden
        POP     BC
        LD      HL,0FFF8h
        ADD     HL,BC
        LD      A,(HL)
        ADD     A,10h                   ; übergelaufene 1 als oberste Ziffer
        LD      (HL),A
        LD      H,B
        LD      L,C
        RET
;  MANT_SUB – Mantissen subtrahieren: (BC) = (HL) - (DE) (Zeiger vor dem
;  Tausch), 8 Bytes BCD. CY = 1: Ergebnis negativ (Zehnerkomplement).
; <- aufgerufen von 3082h
MANT_SUB:
        EX      DE,HL
        EX      AF,AF'                  ; CY' = 0
        AND     A
        EX      AF,AF'
        LD      A,08h
; <- aufgerufen von 2FB6h
MSUB_LP:
        EX      AF,AF'
        DEC     DE
        DEC     HL
        DEC     BC
        LD      A,(DE)                  ; Byte - Byte - Borger, dezimal
        SBC     A,(HL)
        DAA
        LD      (BC),A
        EX      AF,AF'
        DEC     A
        JP      NZ,MSUB_LP
        EX      AF,AF'
        RET                             ; CY = Ergebnis negativ
;  MD_EXPCHK – Exponent des Produkts/Quotienten außerhalb des Bereichs:
;  knapp darunter (ab F2h) noch runden (MD_ROUNDHL), sonst Überlauf.
; <- aufgerufen von 3217h
MD_EXPCHK:
        LD      A,C
        CP      0F2h
        JP      NC,MD_ROUNDHL
;  FP_OVERFLOW – Überlauf: (DE) = FP_MAX mit dem Vorzeichen von (DE),
;  dann Fehler 2.
; <- aufgerufen von 2F90h, 311Eh
FP_OVERFLOW:
        PUSH    DE
        LD      HL,FP_MAX+7             ; FP_MAX nach (DE) ...
        LD      A,(DE)
        OR      7Fh                     ; ... Vorzeichen bleibt, Exponent 7Fh
        LD      (DE),A
        DEC     DE
        LD      BC,0008h
        LDDR
        JP      ERR_02                  ; Überlauf
;  FP_SETZERO – (HL) = 0: die 9 Bytes unterhalb und einschließlich HL löschen.
; <- aufgerufen von 2E44h, 2EAEh, 2F05h, 2FEEh, 3123h, 367Bh
FP_SETZERO:
        PUSH    HL
        LD      B,09h
        XOR     A
FSZ_LP:  LD      (HL),A
        DEC     HL
        DJNZ    FSZ_LP
        POP     HL
        RET
;  ADD_ALIGN – Teil von OP_ADD/OP_SUB: A = Exponentdifferenz. Ab 20h
;  bestimmt der größere Operand allein das Ergebnis (ALN_TAKEBIG: kopieren, eine
;  Rücksprungebene überspringen). Sonst den kleineren Operanden um A Ziffern
;  nach rechts schieben (ALN_SMALL), bei E = 40h vorher normieren.
; <- aufgerufen von 3064h, 30CAh
ADD_ALIGN:
        CP      20h                     ; Differenz unter 20h: angleichen
        JP      C,ALN_SMALL
ALN_TAKEBIG:  INC     SP                ; sonst Rücksprung in ADD_MAG/SUB_MAG übergehen ...
        INC     SP
        LD      A,B
        AND     80h
        OR      H
        EXX
        CP      80h                     ; ... Ergebnis ist der größere Operand (0 mit Vorzeichen: echte 0)
        JR      NZ,ALN_COPY
        LD      H,B
        LD      L,C
        JP      FP_SETZERO
ALN_COPY:  LD      (BC),A
        LD      D,B
        LD      E,C
        LD      BC,0008h
        DEC     DE
        DEC     HL
        LDDR
        RET
; <- aufgerufen von 2FDEh
ALN_SMALL:
        EX      AF,AF'                  ; kleinerer Operand ganzzahlig (E = 40h)?
        LD      A,H
        CP      40h
        JR      NZ,ALS_SHIFT
        EXX
        PUSH    BC
        CALL    FP_NORM                 ; ja: erst normieren
        POP     BC
        JR      NZ,ALS_NORMED           ; er war 0: Ergebnis = größerer
        EX      DE,HL
        EXX
        LD      H,D
        JR      ALN_TAKEBIG
ALS_NORMED:  LD      A,(HL)
        EXX
        AND     7Fh
        LD      H,A
        SUB     D
        CALL    M,ADD_SWAP              ; nach dem Normieren größer: tauschen
        EX      AF,AF'
ALS_SHIFT:  EX      AF,AF'
        CP      10h                     ; 16 Ziffern oder mehr Unterschied: größerer allein
        JR      NC,ALN_TAKEBIG
        EX      AF,AF'
        LD      A,B
        AND     80h
        OR      H
        EXX
        EX      AF,AF'
        PUSH    DE
        PUSH    BC
        EX      DE,HL
        CALL    FP_SHRN                 ; kleineren nach rechts schieben ...
        CALL    C,MANT_INC              ; ... und runden
        EX      DE,HL
        POP     BC
        EX      AF,AF'
        LD      (BC),A                  ; Exponent/Vorzeichen des Ergebnisses
        POP     DE
        RET
;  OP_ADD – (DE) = (DE) + (HL), Zeiger auf die Exponentbytes. Gleiche
;  Vorzeichen: ADD_MAG, verschiedene: SUB_MAG. Der rechte Operand kann dabei
;  verändert (verschoben) werden.
; <- aufgerufen von 21F7h, 34D1h
OP_ADD: LD      B,D                     ; BC -> Ergebnis
        LD      C,E
        LD      A,(DE)
        XOR     (HL)                    ; Vorzeichen verschieden?
        JP      M,SUB_MAG               ; ja: Beträge subtrahieren
;  ADD_MAG – Beträge addieren (gleiche Vorzeichen bei +, verschiedene bei -).
;  Beide ganzzahlig (E = 40h): direkt MANT_ADD. Sonst den kleineren an den
;  größeren Exponenten angleichen (ADD_ALIGN), addieren, FP_INTFORM.
;  OPA_x/OPS_x schreiben NOP bzw. CPL nach ASW_SIGN: so bekommt das Ergebnis
;  beim Tausch der Operanden das richtige Vorzeichen.
; <- aufgerufen von 3074h
ADD_MAG:
        ADD     A,A
        LD      A,00h                   ; ASW_SIGN = NOP (kein Vorzeichenwechsel beim Tausch)
        LD      (ASW_SIGN),A
        JR      NZ,ADM_EXPS             ; Exponenten verschieden: angleichen
        LD      A,(HL)
        LD      (BC),A
        AND     7Fh                     ; beide gleich ganzzahlig (E >= 40h): direkt addieren
        CP      40h
        JP      NC,MANT_ADD
        JR      ADM_SUM
ADM_EXPS:  LD      A,(DE)               ; Exponenten der Operanden nach D' bzw. H', B' = Exponentbyte rechts
        EXX
        AND     7Fh
        LD      D,A
        EXX
        LD      A,(HL)
        EXX
        LD      B,A
        AND     7Fh
        LD      H,A
        SUB     D                       ; Differenz rechts - links
        JP      P,ADM_ALIGN             ; rechter Exponent größer oder gleich
        EX      DE,HL                   ; sonst Operanden tauschen, Differenz positiv
        NEG
        EXX
        EX      DE,HL
        EXX
; <- aufgerufen von 305Bh
ADM_ALIGN:
        CALL    ADD_ALIGN               ; kleineren Operanden angleichen
ADM_SUM:  PUSH    BC
        CALL    MANT_ADD                ; Mantissen addieren
        POP     DE
        JP      FP_INTFORM              ; ganzzahlige Ergebnisse auf E = 40h
;  OP_SUB – (DE) = (DE) - (HL), Zeiger auf die Exponentbytes. Wie OP_ADD,
;  nur umgekehrt: verschiedene Vorzeichen -> ADD_MAG, gleiche -> SUB_MAG.
; <- aufgerufen von 3584h
OP_SUB: EX      DE,HL                   ; DE <-> HL, BC -> Ergebnis
        LD      B,H
        LD      C,L
        LD      A,(DE)                  ; Vorzeichen verschieden?
        XOR     (HL)
        JP      M,ADD_MAG               ; ja: Beträge addieren
;  SUB_MAG – Beträge subtrahieren: angleichen, MANT_SUB; bei negativem
;  Ergebnis Zehnerkomplement (99h - Byte, +1) und Vorzeichen umdrehen.
;  Ergebnis 0 mit E = 40h wird zu echter 0, sonst FP_NORM und FP_INTFORM.
; <- aufgerufen von 3038h
SUB_MAG:
        ADD     A,A
        LD      A,2Fh                   ; ASW_SIGN = CPL (Vorzeichen dreht beim Tausch)
        LD      (ASW_SIGN),A
        JR      NZ,SBM_EXPS             ; Exponenten verschieden: angleichen
        LD      A,(HL)
        LD      (BC),A
SBM_DIFF:  PUSH    BC
        CALL    MANT_SUB                ; Mantissen subtrahieren
        POP     HL
        JR      NC,SBM_CHKZERO          ; nicht negativ: weiter
        LD      H,B
        LD      L,C
        LD      B,08h
        LD      C,99h                   ; negativ: Zehnerkomplement (99h - Byte) ...
SBM_COMPL:  LD      A,C
        SUB     (HL)
        LD      (HL),A
        INC     HL
        DJNZ    SBM_COMPL
        LD      A,(HL)                  ; ... Vorzeichen umdrehen ...
        XOR     80h
        LD      (HL),A
        PUSH    HL
        CALL    MANT_INC                ; ... und +1
        POP     HL
SBM_CHKZERO:  LD      A,(HL)            ; ganzzahlig (E = 40h)?
        AND     7Fh
        CP      40h
        JR      NZ,SBM_NORM
        LD      BC,0FFF8h
        ADD     HL,BC
        XOR     A
        LD      B,08h
SBM_ZEROLP:  CP      (HL)               ; Mantisse 0?
        RET     NZ
        INC     HL
        DJNZ    SBM_ZEROLP
        LD      (HL),00h                ; ja: Exponent 0 (echte 0)
        RET
SBM_NORM:  CALL    FP_NORM              ; sonst normieren und Ganzzahlform
        EX      DE,HL
        JP      FP_INTFORM
SBM_EXPS:  LD      A,(DE)               ; Exponenten wie bei ADD_MAG
        AND     7Fh
        EXX
        LD      D,A
        EXX
        LD      A,(HL)
        EXX
        LD      B,A
        AND     7Fh
        LD      H,A
        SUB     D
        CALL    M,ADD_SWAP              ; rechter größer: tauschen
        CALL    ADD_ALIGN               ; kleineren angleichen
        JR      SBM_DIFF
;  ADD_SWAP – Operanden tauschen (größerer Exponent nach vorn), Differenz
;  negieren; ASW_SIGN ist NOP oder CPL (von OP_ADD/OP_SUB gesetzt) und dreht
;  bei der Subtraktion das Vorzeichen.
; <- aufgerufen von 3015h, 30C7h
ADD_SWAP:
        EX      DE,HL                   ; Operanden tauschen
        NEG                             ; Differenz negieren
        EX      AF,AF'
        LD      A,B
ASW_SIGN:  CPL                          ; NOP oder CPL (von ADD_MAG/SUB_MAG gesetzt): Vorzeichen
        LD      B,A
        EX      AF,AF'
        EXX
        EX      DE,HL
        EXX
        RET
;  OP_MUL / OP_DIV – (DE) = (DE) * (HL) bzw. (DE) / (HL) über MULDIV
;  (CY = 0: Multiplikation, CY = 1: Division).
; <- aufgerufen von 34AFh
OP_MUL: XOR     A                       ; CY = 0: Multiplikation
        JR      MULDIV
OP_DIV: SCF                             ; CY = 1: Division
;  MULDIV – gemeinsamer Teil von OP_MUL/OP_DIV. Ist (HL) 0: bei MUL 0, bei
;  DIV Fehler 2 (Division durch 0); ist (DE) 0: Ergebnis 0.
;  Beide Operanden normiert kopieren (FP_NORMCOPY), Exponent und
;  Vorzeichen nach FPR_EXP (Bereich prüfen: Unterlauf 0, Überlauf Fehler 2).
;  DIV: Quotient Ziffer für Ziffer durch fortgesetztes Subtrahieren
;  (DIV_DIGIT ... DIV_SHIFT), Ziffern nach FP_DIG. MUL: Teilprodukte
;  Byte mal Byte (MUL_START ... MUL_ACC) über DAA in FP_DIG aufsummieren. MD_PACK packt FP_DIG in das
;  Ergebnis, MD_FINISH rundet und bringt es in Ganzzahlform.
;  Die 7 Bytes vor DIV_NEXTDIG (LD HL,FPR_EXP / INC (HL) / EXX / JR DIV_DIGIT)
;  werden nicht angesprungen.
MULDIV: EX      AF,AF'
        PUSH    DE
        CALL    FP_ISZERO               ; rechter Operand 0?
        JR      NZ,MD_CHKRIGHT
        EX      AF,AF'
        JP      NC,SET_FALSE            ; MUL: Ergebnis 0
        JP      ERR_02                  ; DIV: Division durch 0
MD_CHKRIGHT:   EX      DE,HL
        CALL    FP_ISZERO               ; linker Operand 0: Ergebnis 0
        JP      Z,SET_FALSE
        CALL    FP_NORMCOPY             ; normierte Kopien (DE -> rechts, HL -> links)
        PUSH    HL
        LD      A,(HL)
        LD      L,A                     ; L = Exponentbyte rechts, C = Exponent
        AND     7Fh
        LD      C,A
        EX      AF,AF'
        LD      B,40h                   ; MUL: E = El + Er - 40h
        JR      NC,MD_EXP
        LD      B,31h                   ; DIV: E = El - Er + 31h (C und B tauschen)
        LD      H,C
        LD      C,B
        LD      B,H
MD_EXP:   EX      AF,AF'
        LD      A,(DE)
        LD      H,A
        AND     7Fh
        ADD     A,C                     ; Exponent des Ergebnisses
        SUB     B
        JP      P,MD_SIGN               ; im Bereich: weiter
        EX      AF,AF'
        JR      C,MD_RANGEDIV
        EX      AF,AF'
        CP      0F2h                    ; MUL: knapp darunter (ab F2h) noch weiter
        JR      NC,MD_SIGN
        JR      MD_RANGE
MD_RANGEDIV:   EX      AF,AF'
MD_RANGE:   POP     BC
        POP     DE
        JP      NC,FP_OVERFLOW          ; zu groß: Überlauf, sonst 0
        PUSH    DE
; <- aufgerufen von 3310h
MD_ZERO:
        POP     HL
        JP      FP_SETZERO
; <- aufgerufen von 310Eh
MD_SIGN:
        LD      C,A
        LD      A,L                     ; Vorzeichen = Vorzeichen links XOR rechts
        XOR     H
        AND     80h
        OR      C
        LD      (FPR_EXP),A             ; Exponent und Vorzeichen nach FPR_EXP
        POP     HL
        EX      AF,AF'
        JP      NC,MUL_START            ; Multiplikation
        LD      HL,FP_TMP2+8            ; Division: Dividend (FP_TMP2) eine Stelle vor den Divisor ...
        LD      C,(HL)
        XOR     A
        LD      (HL),A
        LD      (DE),A
        LD      B,11h                   ; ... und FP_DIG löschen
        LD      DE,FP_DIG+1
DIV_CLRLP:  LD      (DE),A
        INC     DE
        DJNZ    DIV_CLRLP
        LD      C,11h                   ; 17 Ziffern
        LD      IX,FP_TMP2              ; IX -> nächstes Byte des Dividenden
        LD      DE,FP_DIG
        EXX
        LD      C,09h                   ; C' = Bytes des Divisors
        JR      DIV_DIGIT
;  nicht angesprungen (Rest einer früheren Fassung):
        LD      HL,FPR_EXP              ; nicht angesprungen
        INC     (HL)
        EXX
        JR      DIV_DIGIT
DIV_NEXTDIG:  BIT     0,C               ; nach jeder zweiten Ziffer ein Byte weiter
        EXX
        JR      Z,DIV_DIGIT
        EX      AF,AF'
        JR      NZ,DIV_NEXTBYTE
        DEC     C
DIV_NEXTBYTE:  INC     IX
DIV_DIGIT:  LD      HL,FP_TMP1+8        ; Rest 0: fertig
        CALL    FP_ISZERO
        JR      NZ,DIV_SUBINIT
        LD      DE,FP_DIG+17
        JR      MD_PACK
DIV_SUBINIT:  LD      IY,00FFh          ; IY = Ziffer - 1
DIV_SUBLP:  LD      DE,FP_TMP1+8        ; Divisor abziehen, bis negativ
        CALL    QS_PTRS2
DIV_SUB:  LD      A,(DE)
        SBC     A,(HL)
        DAA
        LD      (DE),A
        DEC     DE
        DEC     HL
        DJNZ    DIV_SUB
        INC     IY                      ; Ziffer + 1
        JR      NC,DIV_SUBLP
        LD      DE,FP_TMP1+8            ; einmal zurückaddieren
        CALL    QS_PTRS2
DIV_ADDBACK:  LD      A,(DE)
        ADC     A,(HL)
        DAA
        LD      (DE),A
        DEC     HL
        DEC     DE
        DJNZ    DIV_ADDBACK
        EX      AF,AF'
        LD      A,C
        EXX
        LD      B,A
        PUSH    IX
        POP     HL
        XOR     A
DIV_SHIFT:  RRD                         ; nächste Ziffer des Dividenden einschieben
        INC     HL
        DJNZ    DIV_SHIFT
        PUSH    IY
        POP     HL
        LD      A,L                     ; Ziffer nach FP_DIG
        INC     DE
        LD      (DE),A
        DEC     C
        JR      NZ,DIV_NEXTDIG          ; noch Ziffern übrig
;  MD_PACK – 16 Ziffern aus FP_DIG (DE zeigt hinter die letzte) gepackt in
;  das Ergebnis (Adresse auf dem Stack) schreiben, FPR_EXP als Exponent;
;  A' = nächste Ziffer (Rundung in MD_FINISH).
; <- aufgerufen von 3350h
MD_PACK:
        EX      AF,AF'
        POP     HL                      ; HL -> Exponentbyte des Ergebnisses
        PUSH    HL
        LD      B,08h
MDP_LP:  DEC     DE                     ; je zwei Ziffern zu einem Byte packen
        DEC     HL
        LD      A,(DE)
        LD      C,A
        DEC     DE
        LD      A,(DE)
        RLCA
        RLCA
        RLCA
        RLCA
        OR      C
        LD      (HL),A
        DJNZ    MDP_LP
        POP     HL
        LD      A,(FPR_EXP)             ; Exponent und Vorzeichen
        LD      (HL),A
        EX      AF,AF'
        CP      05h                     ; nächste Ziffer >= 5: aufrunden (CY = 0)
        LD      D,H
        LD      E,L
        JP      MD_FINISH
; <- aufgerufen von 3248h
MUL_SKIP0:
        LD      HL,(FPR_PTR)            ; Byte 0: nur die Stelle weiterrücken
        DEC     HL
        LD      (FPR_PTR),HL
; <- aufgerufen von 3295h, 329Ah
MUL_NEXT:
        POP     HL
        POP     BC
        DJNZ    MUL_COLLP               ; nächstes Byte des rechten Operanden
        EXX
MUL_NEXTROW:  DJNZ    MUL_ROWLP         ; nächstes Byte des linken Operanden
        OR      A
        POP     HL                      ; HL -> Anfang des Ergebnisses
        LD      BC,0008h
        SBC     HL,BC
        EX      DE,HL
        INC     BC
        LD      HL,FP_DIG+1             ; führende Null-Bytes des Produkts überspringen
        LD      B,08h
MUL_FINDNZ:  LD      A,(HL)
        OR      A
        JR      NZ,MUL_STORE
        INC     HL
        DJNZ    MUL_FINDNZ
        LDIR                            ; Produkt 0
        RET
MUL_STORE:  PUSH    BC
        LD      B,00h
        LDIR                            ; obere 8 Bytes des Produkts ins Ergebnis
        POP     BC
        SLA     B                       ; B = Exponentkorrektur (2 je übersprungenes Byte)
        CP      10h                     ; führende Ziffer 0?
        DEC     DE
        LD      A,(DE)
        JR      NC,MUL_ROUND
        DEC     B                       ; ja: eine Ziffer nach links, Korrektur - 1
        DEC     C
        RLCA
        RLCA
        RLCA
        RLCA
        PUSH    DE
        POP     HL
MUL_RLD:  DEC     HL
        RLD
        DEC     C
        JR      NZ,MUL_RLD
MUL_ROUND:  CP      50h                 ; CY': Rundung über das nächste Byte (>= 50h)
        EX      AF,AF'
        LD      A,(FPR_EXP)             ; Exponent korrigieren
        LD      C,A
        ADD     A,B
        LD      (DE),A
        XOR     C                       ; Bereich verlassen (Vorzeichen gekippt)?
        JP      M,MD_EXPCHK
; <- aufgerufen von 2FBEh
MD_ROUNDHL:
        EX      AF,AF'
        LD      H,D
        LD      L,E
;  MD_FINISH – runden (MANT_INCNC, CY aus CP 05h bzw. 50h) und FP_INTFORM.
; <- aufgerufen von 31C8h
MD_FINISH:
        CALL    MANT_INCNC
        JP      FP_INTFORM
; <- aufgerufen von 3131h
MUL_START:
        PUSH    HL                      ; IX -> Ende des rechten Operanden
        POP     IX
        LD      HL,FP_DIG+1             ; Produkt löschen
        LD      B,10h
MUL_CLRLP:  LD      (HL),A
        INC     HL
        DJNZ    MUL_CLRLP
        LD      B,08h
MUL_ROWLP:  DEC     DE                  ; Bytes des linken Operanden von unten
        DEC     HL
        LD      A,(DE)
        OR      A
        JR      Z,MUL_NEXTROW           ; Byte 0: überspringen
        EX      AF,AF'
        LD      (FPR_PTR),HL            ; FPR_PTR -> Stelle im Produkt
        EXX
        LD      B,08h
        EX      AF,AF'
        LD      C,A
        PUSH    IX
        POP     HL
MUL_COLLP:  PUSH    BC                  ; Bytes des rechten Operanden
        DEC     HL
        PUSH    HL
        LD      A,(HL)
        OR      A
        JP      Z,MUL_SKIP0             ; Byte 0: überspringen
        LD      L,A                     ; HL = Byte rechts, DE = Teilprodukt (BCD)
        XOR     A
        LD      H,A
        LD      D,A
        LD      E,A
        LD      A,C                     ; untere Ziffer links mal Byte rechts (wiederholt addieren)
        AND     0Fh
        JR      Z,MUL_HI
        LD      B,A
        XOR     A
MUL_LOLP:  ADD     A,L
        DAA
        JR      NC,MUL_LONEXT
        INC     D
MUL_LONEXT:  DJNZ    MUL_LOLP
        LD      E,A
MUL_HI:  ADD     HL,HL                  ; Byte rechts * 16 (für die obere Ziffer)
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        LD      A,C                     ; obere Ziffer links mal Byte rechts
        AND     0F0h
        JR      Z,MUL_ACC
        RLCA
        RLCA
        RLCA
        RLCA
        LD      B,A
        LD      C,A
        LD      A,E
MUL_HILP:  ADD     A,L
        DAA
        JR      NC,MUL_HINEXT
        INC     D
MUL_HINEXT:  DJNZ    MUL_HILP
        LD      E,A
        LD      B,C
        LD      A,D                     ; Zehnerübertrag zum oberen Byte
        CP      0Ah
        JR      C,MUL_HICARRY
        ADD     A,06h
MUL_HICARRY:  ADD     A,H
        DAA
        DJNZ    MUL_HICARRY
        LD      D,A
MUL_ACC: LD      B,00h                  ; Teilprodukt an FPR_PTR aufaddieren
        LD      HL,(FPR_PTR)
        LD      A,(HL)
        ADD     A,E
        DAA
        LD      (HL),A
        DEC     HL
        LD      A,(HL)
        ADC     A,D
        DAA
        LD      (HL),A
        LD      (FPR_PTR),HL
        JP      NC,MUL_NEXT             ; Übertrag ins nächste Byte
        DEC     HL
        INC     (HL)
        JP      MUL_NEXT
;  FP_ISZERO – Z, wenn (HL) Null ist: Exponent 0 oder 40h und Mantisse 0.
; <- aufgerufen von 269Bh, 30E1h, 30EEh, 3167h, 32CFh, 3420h
FP_ISZERO:
        PUSH    HL
        LD      A,(HL)
        CP      40h                     ; E = 40h oder 0: Mantisse prüfen
        JR      Z,FIZ_MANT
        OR      A
        JR      NZ,FIZ_RET              ; sonst nicht 0 (normiert)
FIZ_MANT:  XOR     A
        LD      B,08h
FIZ_LP:  DEC     HL                     ; alle 8 Mantissenbytes 0?
        CP      (HL)
        JR      NZ,FIZ_RET
        DJNZ    FIZ_LP
FIZ_RET:  POP     HL
        RET
;  FP_PTREXP – HL und DE um 8 erhöhen (vom Anfang auf das Exponentbyte).
; <- aufgerufen von 21F2h, 2670h
FP_PTREXP:
        LD      BC,0008h
        ADD     HL,BC
        EX      DE,HL
        ADD     HL,BC
        EX      DE,HL
        RET
;  QS_PTRS/QS_PTRS2 – Hilfen für die Subtraktionsschleifen von DIV und SQR:
;  DE = FPR_PTR (nur QS_PTRS), HL = FP_TMP2+8, B = C, A = 0, CY = 0.
; <- aufgerufen von 3363h, 337Ch
QS_PTRS:
        LD      DE,(FPR_PTR)
; <- aufgerufen von 3178h, 318Ah, 3357h, 33BFh
QS_PTRS2:
        LD      HL,FP_TMP2+8
        LD      B,C
        XOR     A
        RET
;  FN_SQR – SQR(x): negativ Fehler 3, 0 bleibt 0. Wurzel Ziffer für Ziffer
;  wie beim schriftlichen Wurzelziehen: Radikand nach FP_TMP1 (bei
;  ungeradem Exponent eine Ziffer nach rechts), Exponent halbieren; die
;  erste Ziffer über die Summe der ungeraden Zahlen, jede weitere durch
;  fortgesetztes Subtrahieren von (20 * bisherige Wurzel + Ziffer) * Ziffer
;  (SQR_SQUARES). Bis 17 Ziffern in FP_DIG, dann MD_PACK.
FN_SQR: EX      DE,HL
        LD      A,(HL)
        OR      A
        JP      P,SQR_POS               ; negativ: Fehler 3
        JP      ERR_03
; <- aufgerufen von 32C6h
SQR_POS:
        PUSH    HL
        LD      D,H
        LD      E,L
        CALL    FP_ISZERO               ; SQR(0) = 0
        JP      Z,SET_FALSE
        EX      DE,HL
        LD      BC,0008h
        XOR     A
        SBC     HL,BC
        INC     BC
        LD      DE,FPA_FLAG             ; Arbeitsbereich löschen
        LD      B,2Ch
SQR_CLRLP:  LD      (DE),A
        INC     DE
        DJNZ    SQR_CLRLP
        LD      DE,FP_TMP1              ; Radikand nach FP_TMP1
        LD      B,A
        LDIR
        EX      DE,HL
        DEC     HL
        CALL    FP_NORM                 ; normieren
        LD      A,(HL)
        LD      IX,FP_DIG+1
        LD      C,A
        RRCA                            ; Exponent ungerade?
        JR      NC,SQR_HALFEXP
        INC     C
        LD      HL,FP_TMP1              ; ja: Mantisse eine Ziffer nach rechts
        XOR     A
        LD      B,08h
SQR_ODDSHIFT:  RRD
        INC     HL
        DJNZ    SQR_ODDSHIFT
SQR_HALFEXP:  LD      A,C               ; Exponent halbieren: (E - 30h) / 2 + 30h
        AND     7Fh
        SRL     A
        ADD     A,18h
        JP      P,SQR_SIGN              ; Unterlauf: 0
        JP      MD_ZERO
; <- aufgerufen von 330Dh
SQR_SIGN:
        BIT     7,C
        JR      Z,SQS_SETEXP
        OR      80h
SQS_SETEXP:  LD      (FPR_EXP),A        ; Exponent des Ergebnisses
        LD      HL,FP_TMP1
        LD      A,(HL)                  ; erste Ziffer: größtes n mit n*n <= erste zwei Ziffern
        LD      C,99h
SQS_FIRSTDIG:  EX      AF,AF'           ; C = n (BCD), B = 2n+1 = nächste ungerade Zahl
        LD      A,C
        ADD     A,01h
        DAA
        LD      C,A
        SCF
        ADC     A,A
        DAA
        LD      B,A
        EX      AF,AF'
        SUB     B                       ; abziehen, solange es geht
        DAA
        JR      NC,SQS_FIRSTDIG
        ADD     A,B                     ; einmal zu viel: zurück
        DAA
        LD      (HL),A
        INC     HL
        LD      (FPR_PTR),HL            ; FPR_PTR -> nächste Stelle des Rests
        LD      A,C
        OR      A
        ADD     A,A                     ; 2 * erste Ziffer nach FP_TMP2+8
        DAA
        LD      (FP_TMP2+8),A
        LD      (IX+0),C                ; erste Ziffer nach FP_DIG+1
        DEC     HL
        LD      B,08h
        XOR     A
SQS_CHKREST:  CP      (HL)              ; Rest 0: fertig
        JR      NZ,SQS_START
        INC     HL
        DJNZ    SQS_CHKREST
; <- aufgerufen von 33F1h
SQR_DONE:
        LD      DE,FP_DIG+17            ; Ziffern packen wie bei MULDIV
        LD      A,(DE)
        JP      MD_PACK
SQS_START:  LD      A,02h               ; C = Länge der Teilwurzel in Bytes
        LD      C,A
        EX      AF,AF'
; <- aufgerufen von 3404h
SQR_DIGIT:
        CALL    QS_PTRS2                ; Teilwurzel * 10 (eine Ziffer nach links)
SQD_SHIFT:  RLD
        DEC     HL
        DJNZ    SQD_SHIFT
        LD      IY,0FFFFh               ; IY = neue Ziffer - 1
SQD_SUBLP:  CALL    QS_PTRS             ; Teilwurzel vom Rest abziehen, bis negativ
SQD_SUB:  LD      A,(DE)
        SBC     A,(HL)
        DAA
        LD      (DE),A
        JR      Z,SQD_SUBNEXT
        SET     7,C
SQD_SUBNEXT:  DEC     DE
        DEC     HL
        DJNZ    SQD_SUB
        INC     IY                      ; Ziffer + 1
        BIT     7,C
        JR      Z,SQD_ADDBACK
        RES     7,C
        JR      NC,SQD_SUBLP
SQD_ADDBACK:  CALL    QS_PTRS           ; einmal zurückaddieren
SQD_ADD:  LD      A,(DE)
        ADC     A,(HL)
        DAA
        LD      (DE),A
        DEC     DE
        DEC     HL
        DJNZ    SQD_ADD
        PUSH    IY
        POP     DE
        INC     IX                      ; Ziffer nach FP_DIG
        LD      (IX+0),E
        LD      HL,FP_TMP1
        LD      B,09h
        XOR     A
SQD_CHKREST:  CP      (HL)              ; Rest 0: fertig
        JR      NZ,SQD_CORR
        INC     HL
        DJNZ    SQD_CHKREST
        JR      SQR_DONE
SQD_CORR:  LD      A,E                  ; Ziffer 0: nichts zu korrigieren
        OR      A
        JR      Z,SQD_NEXT
        LD      HL,SQR_SQUARES          ; Ziffer² vom Rest abziehen
        ADD     HL,DE
        LD      E,(HL)
        LD      D,E
        LD      B,C
        LD      HL,(FPR_PTR)
        OR      A
SQD_CORRSUB:  LD      A,(HL)
        SBC     A,E
        DAA
        DEC     HL
        LD      E,00h
        DJNZ    SQD_CORRSUB
        JR      NC,SQD_DOUBLE           ; Rest negativ: Ziffer - 1, nochmal
        DEC     IX
        DEC     IY
        JR      SQD_ADDBACK
SQD_DOUBLE: LD      E,(IX+0)            ; Teilwurzel um 2 * Ziffer erhöhen
        CALL    QS_PTRS2
        LD      A,E
        ADD     A,A
        DAA
SQD_DBLADD: ADC     A,(HL)
        DAA
        LD      (HL),A
        DEC     HL
        LD      A,00h
        JR      NC,SQD_SQSUB
        DJNZ    SQD_DBLADD
SQD_SQSUB: LD      B,C                  ; Ziffer² ...
        LD      HL,(FPR_PTR)
        OR      A
SQD_SQSUBLP: LD      A,(HL)
        SBC     A,D
        DAA
        LD      (HL),A
        DEC     HL
        LD      D,00h
        DJNZ    SQD_SQSUBLP
SQD_NEXT: LD      DE,FP_TMP1            ; Rest um ein Byte nachrücken, wenn das oberste 0 ist
        PUSH    DE
        LD      A,(DE)
        OR      A
        JR      NZ,SQD_PTRINC
        LD      BC,0008h
        LD      H,D
        LD      L,E
        INC     HL
        LDIR
SQD_COUNT: POP     DE
        EX      AF,AF'
        CP      11h                     ; 17 Ziffern: fertig
        JP      NC,SQR_DONE
        INC     A
        EX      AF,AF'
        LD      HL,FP_TMP2              ; Länge der Teilwurzel neu bestimmen
        LD      B,09h
        XOR     A
SQD_CHKTMP2: CP      (HL)
        JR      NZ,SQD_AGAIN
        INC     HL
        DJNZ    SQD_CHKTMP2
SQD_AGAIN: LD      C,B
        INC     C
        JP      SQR_DIGIT
SQD_PTRINC: LD      HL,(FPR_PTR)
        INC     HL
        LD      (FPR_PTR),HL
        JR      SQD_COUNT
;  SQR_SQUARES: Quadrate 0-9 in BCD (für die Wurzelziffern)
SQR_SQUARES:
        DEFB    00h,01h,04h,09h,16h,25h,36h,49h
        DEFB    64h,81h
;  ABS(x) löscht das Vorzeichenbit, SGN(x) liefert -1, 0 oder 1
;  (Konstanten FP_MONE/FP_ZERO/FP_ONE über PUT_CONST).
FN_ABS: EX      DE,HL
        RES     7,(HL)                  ; Vorzeichenbit löschen
        RET
FN_SGN: PUSH    DE
        EX      DE,HL
        CALL    FP_ISZERO               ; SGN(0) = 0
        JR      Z,SET_FALSE
        LD      A,(HL)
        OR      A
        JP      M,SET_TRUE              ; negativ: -1
        LD      HL,FP_ONE+8             ; positiv: 1
        JR      PUT_CONST
;  Vergleichsoperatoren: (DE) = -1 (wahr, SET_TRUE) oder 0 (falsch,
;  SET_FALSE), über FP_CMP; OP_LT/OP_GE2 tauschen die Operanden.
OP_NE2: PUSH    DE
        CALL    FP_CMP                  ; <>: wahr, wenn nicht gleich
        JR      Z,SET_FALSE
;  SET_TRUE/SET_FALSE – Ergebnis -1 bzw. 0 nach (DE) (Adresse auf dem Stack);
;  PUT_CONST: Konstante ab HL (Exponentbyte) dorthin; COPY_VAL9: 9 Bytes von
;  (HL) abwärts nach (DE).
; <- aufgerufen von 3427h
SET_TRUE:
        LD      HL,FP_MONE+8            ; -1 = wahr
        JR      PUT_CONST
; <- aufgerufen von 30E7h, 30F1h, 32D2h
SET_FALSE:
        LD      HL,FP_ZERO+8            ; 0 = falsch
; <- aufgerufen von 3505h
PUT_CONST:
        POP     DE                      ; DE = Ziel (vom Aufrufer gesichert)
; <- aufgerufen von 3567h
COPY_VAL9:
        LD      BC,0009h                ; 9 Bytes abwärts kopieren
        LDDR
        RET
OP_GT:  PUSH    DE
        JR      CMP_IFC
OP_LT:  PUSH    DE
        EX      DE,HL                   ; < : Operanden tauschen, dann wie >
CMP_IFC:
        CALL    FP_CMP
        JR      C,SET_TRUE              ; CY: (DE) > (HL)
        JR      SET_FALSE
OP_EQ:  PUSH    DE
        CALL    FP_CMP
        JR      Z,SET_TRUE
        JR      SET_FALSE
OP_LE2: PUSH    DE
        JR      CMP_IFNC
OP_GE2: PUSH    DE
        EX      DE,HL                   ; >= : Operanden tauschen, dann wie <=
CMP_IFNC:
        CALL    FP_CMP
        JR      C,SET_FALSE
        JR      SET_TRUE
;  FP_CMP – (DE) mit (HL) vergleichen (Zeiger auf die Exponentbytes):
;  Z = gleich, CY = (DE) > (HL). Gleicher Exponent 40h: nur die Mantissen
;  vergleichen; sonst normierte Kopien (FP_NORMCOPY), erst Vorzeichen und
;  Exponent, dann die Mantisse byteweise.
; <- aufgerufen von 2208h, 221Ah, 3430h, 3449h, 3451h, 345Dh
FP_CMP: LD      A,(DE)                  ; gleiche Exponentbytes ...
        CP      (HL)
        JR      NZ,CMP_NORMED
        CP      40h                     ; ... und beide ganzzahlig: nur Mantissen vergleichen
        JR      Z,CMP_EXP
CMP_NORMED:  CALL    FP_NORMCOPY        ; sonst normierte Kopien vergleichen
        EX      DE,HL
        LD      A,(DE)
        LD      B,(HL)
        SCF                             ; Vorzeichenbit nach CY, Exponent * 2 + 1
        RLA
        JR      NC,CMP_POSL             ; links positiv
        RL      B                       ; links negativ: rechts positiv -> links kleiner (NC)
        RET     NC
        CP      B                       ; beide negativ: größerer Exponent ist kleiner
        RET     C
        JR      CMP_EXPEQ
CMP_POSL:  SCF                          ; links positiv, rechts negativ: CY (links größer)
        RL      B
        RET     C
CMP_EXP:  EX      DE,HL
        LD      A,(DE)                  ; Exponentbytes vergleichen
        CP      (HL)
CMP_EXPEQ:  RET     NZ                  ; verschieden: fertig (CY, Z)
        LD      BC,0FFF8h               ; beide auf das oberste Mantissenbyte
        ADD     HL,BC
        EX      DE,HL
        ADD     HL,BC
        EX      DE,HL
        LD      B,07h
CMP_MANTLP:  LD      A,(DE)             ; Mantissen byteweise vergleichen
        CP      (HL)
        RET     NZ
        INC     HL
        INC     DE
        DJNZ    CMP_MANTLP
        LD      A,(DE)
        CP      (HL)
        RET
;  FN_RND – RND(x): x = 0 setzt den Startwert RND_X auf RND_INIT zurück.
;  Immer RND_X = RND_X * 23 (RND_MUL); bei x < 0 kommt zusätzlich die Uhr
;  (TIMER_GET, über BYTE2BCD) dazu. Vom Ergebnis bleiben die Nachkommastellen
;  (Vorkommastellen werden gelöscht), normiert ist das die Zufallszahl.
FN_RND: PUSH    DE
        LD      A,(DE)                  ; x = 0?
        OR      A
        JR      NZ,RND_MUL23
        LD      DE,RND_X+8              ; ja: Startwert zurücksetzen
        LD      HL,RND_INIT+8
        LD      B,A
        LD      C,09h
        LDDR
RND_MUL23:  PUSH    AF
        LD      DE,RND_X+8
        LD      HL,RND_MUL+8
        CALL    OP_MUL                  ; RND_X = RND_X * 23
        POP     AF
        BIT     7,A                     ; x < 0?
        JR      Z,RND_FRAC
        CALL    TIMER_GET               ; ja: Uhr als Zufallsanteil dazu
        LD      A,B
        OR      C
        CALL    BYTE2BCD                ; Sekunden (Low-Byte) als BCD
        LD      HL,FP_TMP1              ; FP_TMP1 = 0.bbcc (Exponent 30h)
        LD      (HL),B
        INC     HL
        LD      (HL),C
        XOR     A
        LD      B,07h
RND_CLRLP:  INC     HL
        LD      (HL),A
        DJNZ    RND_CLRLP
        LD      (HL),30h
        LD      DE,RND_X+8
        CALL    OP_ADD                  ; RND_X = RND_X + FP_TMP1
RND_FRAC:  LD      HL,RND_X+8           ; Vorkommastellen löschen:
        PUSH    HL
        LD      B,(HL)
        DEC     HL
        LD      A,40h                   ; Zahl der Vorkommastellen = E - 30h, 40h - E = Nachkommastellen
        SUB     B
        CP      10h                     ; keine Vorkommastellen
        JR      NC,RND_NORM
        LD      B,08h
RND_SKIPINT:  OR      A                 ; ganze Bytes mit Nachkommastellen überspringen
        SUB     02h
        JR      C,RND_HALF
        DEC     HL
        DJNZ    RND_SKIPINT
RND_HALF:  ADD     A,02h
        BIT     0,A
        JR      Z,RND_CLRINT
        LD      C,0Fh                   ; ungerade: obere Ziffer des Bytes löschen
        LD      A,(HL)
        AND     C
        LD      (HL),A
        DEC     HL
        DEC     B
RND_CLRINT:  LD      A,B
        OR      A
        JR      Z,RND_NORM
        XOR     A
RND_CLRLP2:  LD      (HL),A             ; Bytes mit Vorkommastellen löschen
        DEC     HL
        DJNZ    RND_CLRLP2
RND_NORM:  POP     HL
        CALL    FP_NORM                 ; normieren, Ergebnis nach (DE)
        JP      PUT_CONST
;  RND_X: aktueller Startwert (0.2029882764533591), RND_MUL: Faktor 23,
;  RND_INIT: Startwert nach RND(0)
RND_X:  DEFB    20h,29h,88h,27h,64h,53h,35h,91h,30h
RND_MUL:
        DEFB    23h,00h,00h,00h,00h,00h,00h,00h,32h
RND_INIT:
        DEFB    20h,29h,88h,27h,64h,53h,35h,91h,30h
        DEFB    00h
;  BYTE2BCD – A (0-255) als BCD nach BC (Summe der Zweierpotenzen aus
;  POW2_BCD für jedes gesetzte Bit).
; <- aufgerufen von 2A68h, 34BCh
BYTE2BCD:
        LD      BC,0000h                ; Summe 0
        LD      DE,POW2_BCD
B2B_LP:  OR      A                      ; keine Bits mehr: fertig
        RET     Z
        RRA                             ; nächstes Bit
        JR      NC,B2B_NEXT
        EX      AF,AF'                  ; gesetzt: 2^n (BCD) aufaddieren
        LD      A,(DE)
        ADD     A,C
        DAA
        LD      C,A
        INC     DE
        LD      A,(DE)
        ADC     A,B
        DAA
        LD      B,A
        DEC     DE
        EX      AF,AF'
B2B_NEXT:  INC     DE
        INC     DE
        JR      B2B_LP
;  POW2_BCD: 2^0 .. 2^7 als 16-Bit-BCD (Low-Byte zuerst)
POW2_BCD:
        DEFW    0001h,0002h,0004h,0008h,0016h,0032h,0064h,0128h
;  FN_INT – INT(x): größte ganze Zahl <= x. Ziffern hinter dem Komma
;  löschen; bei negativem x mit Rest 1 abziehen (OP_SUB mit FP_ONE_N),
;  sonst INT_FINISH.
; <- aufgerufen von 1BDEh
FN_INT: PUSH    DE
        EX      DE,HL
        LD      A,(HL)
        PUSH    AF
        AND     7Fh                     ; B = Exponent
        LD      B,A
        LD      A,40h                   ; A = Nachkommastellen = 40h - E
        SUB     B
        LD      B,00h
        JR      Z,INT_DONE              ; ganzzahlig: unverändert
        JR      C,INT_DONE
        CP      10h                     ; weniger als 16 Nachkommastellen: abschneiden
        JR      C,INT_CUT
        EX      DE,HL
        LD      HL,FP_ZERO+8            ; nur Nachkommastellen: 0
        CALL    COPY_VAL9
        JR      INT_SIGN
INT_DONE:  POP     AF
        POP     DE
        RET
INT_CLRLP:  LD      (HL),B              ; ganze Bytes löschen
        SUB     02h
        JR      Z,INT_SIGN
INT_CUT:  DEC     HL
        CP      01h
        JR      NZ,INT_CLRLP
        LD      A,(HL)                  ; bei ungerader Zahl die untere Ziffer löschen
        AND     0F0h
        LD      (HL),A
INT_SIGN:  POP     AF
        POP     DE
        LD      HL,FP_ONE_N+8           ; negativ: 1 abziehen (mit Rest)
        BIT     7,A
        JP      NZ,OP_SUB
        JP      INT_FINISH              ; sonst Ganzzahlform
;  FP_ONE_N: 1 in normierter Form (0.1 * 10^1), für INT negativer Zahlen
FP_ONE_N:
        DEFB    10h,00h,00h,00h,00h,00h,00h,00h,31h
;  STR2NUM – Zahl im Text ab HL nach (DE) wandeln, DE zeigt auf das
;  Exponentbyte des Ziels; gearbeitet wird mit dem Zweitregistersatz. Ziffern werden mit S2N_PUTDIG von rechts in die
;  Mantisse geschoben (Leerzeichen überlesen, führende Nullen übergangen,
;  ab der 17. Ziffer nur noch gerundet), "." und "E[+|-]nn" setzen den
;  Exponenten. Ohne Ziffer Fehler 1, zu groß Fehler 2, zu klein 0.
;  Ergebnis normiert bzw. in Ganzzahlform (FP_INTFORM).
; <- aufgerufen von 272Dh
STR2NUM:
        PUSH    DE
        EXX                             ; Zweitregistersatz: HL' -> Ziel
        POP     HL
        LD      BC,0FFF7h               ; Ziel (9 Bytes) löschen
        ADD     HL,BC
        LD      B,09h
        XOR     A
S2N_CLR:  INC     HL
        LD      (HL),A
        DJNZ    S2N_CLR
        LD      C,B                     ; C = Merker (Bit 7 Ziffer gesehen, 5 Exponent negativ, 4 Bereich)
        EX      AF,AF'                  ; A' = Zahl der gesammelten Ziffern
S2N_LEAD0:  CALL    S2N_NEXTCH          ; führende Nullen überlesen
        CP      30h
        JR      NZ,S2N_INTDIG
        SET     7,C
        JR      S2N_LEAD0
S2N_INTDIG:  CALL    IS_DIGIT           ; Ziffern vor dem Punkt
        JR      NC,S2N_POINT
        EX      AF,AF'
        CP      10h                     ; schon 16 Ziffern?
        JR      NC,S2N_INT17
        EX      AF,AF'
        CALL    S2N_PUTDIG              ; nein: Ziffer einschieben
        SET     7,C
        EX      AF,AF'
        JR      S2N_INTNEXT
S2N_INT17:  JR      NZ,S2N_EXPINC       ; 17. Ziffer: runden, ab der 18. nur noch zählen
        EX      AF,AF'
        CP      35h
        CALL    NC,S2N_ROUND
        EX      AF,AF'
S2N_EXPINC:  INC     (HL)               ; jede zusätzliche Vorkommaziffer: Exponent + 1
S2N_INTNEXT:  INC     A
        EX      AF,AF'
        CALL    S2N_NEXTCH
        JR      S2N_INTDIG
S2N_POINT:  CP      2Eh                 ; Dezimalpunkt?
        JR      NZ,S2N_EXP
        CALL    S2N_NEXTCH
S2N_FRACDIG:  CALL    IS_DIGIT          ; Ziffern hinter dem Punkt
        JR      NC,S2N_EXP
        EX      AF,AF'
        CP      10h
        JR      NC,S2N_FRAC17
        EX      AF,AF'
        CALL    S2N_PUTDIG              ; einschieben und Exponent - 1
        SET     7,C
        DEC     (HL)
        EX      AF,AF'
        JR      S2N_FRACNEXT
S2N_FRAC17:  JR      NZ,S2N_FRACNEXT    ; ab der 17. Ziffer: runden bzw. übergehen
        EX      AF,AF'
        CP      35h
        CALL    NC,S2N_ROUND
        EX      AF,AF'
S2N_FRACNEXT: INC     A
        EX      AF,AF'
        CALL    S2N_NEXTCH
        JR      S2N_FRACDIG
S2N_EXP: BIT     7,C                    ; keine Ziffer gesehen?
        JR      NZ,S2N_CHKE
        DEC     HL                      ; dann Mantisse 1 (für "E5" o.ä.)
        LD      (HL),01h
        INC     HL
S2N_CHKE: CP      45h                   ; Exponent "E"?
        JR      NZ,S2N_BIAS
        PUSH    BC
        LD      A,(HL)                  ; Mantisse normieren (Exponent vorübergehend + 40h)
        ADD     A,40h
        LD      (HL),A
        CALL    FP_NORM
        LD      A,(HL)
        SUB     40h
        LD      (HL),A
        POP     BC
        SET     7,C
        CALL    S2N_NEXTCH
        CP      2Dh                     ; "-": negativer Exponent
        JR      NZ,S2N_EPLUS
        SET     5,C
        CALL    S2N_NEXTCH
        JR      S2N_EDIG1
S2N_EPLUS: CP      2Bh                  ; "+" überlesen
        CALL    Z,S2N_NEXTCH
S2N_EDIG1: CALL    IS_DIGIT             ; keine Ziffer: fertig (CY)
        CCF
        RET     C
        SUB     30h
        LD      B,A
S2N_EDIG2: CALL    S2N_NEXTCH           ; weitere Ziffern: Exponent = Exponent * 10 + Ziffer
        CALL    IS_DIGIT
        JR      NC,S2N_ESIGN
        SUB     30h
        PUSH    AF
        LD      A,B
        ADD     A,A
        CALL    M,S2N_OVF
        ADD     A,A
        CALL    M,S2N_OVF
        ADD     A,B
        CALL    M,S2N_OVF
        ADD     A,A
        CALL    M,S2N_OVF
        LD      B,A
        POP     AF
        ADD     A,B
        CALL    M,S2N_OVF
        LD      B,A
        JR      S2N_EDIG2
S2N_ESIGN: LD      A,B                  ; Vorzeichen anwenden
        BIT     5,C
        JR      Z,S2N_EADD
        NEG
S2N_EADD: ADD     A,(HL)                ; zum Exponenten der Mantisse addieren
        CALL    PE,S2N_OVF
        LD      (HL),A
S2N_BIAS: LD      A,(HL)                ; Bias 40h; über 7Fh: Bereichsfehler
        ADD     A,40h
        LD      (HL),A
        JP      P,S2N_CHECK
        SET     4,C
; <- aufgerufen von 3668h
S2N_CHECK:
        BIT     7,C                     ; keine Ziffer: Fehler 1
        JP      Z,ERR_01
        BIT     4,C                     ; Exponent im Bereich?
        JR      Z,S2C_DONE
        BIT     5,C                     ; zu groß: Fehler 2
        JP      Z,ERR_02
        CALL    FP_SETZERO              ; zu klein: 0
S2C_DONE:  CALL    FP_NORM              ; normieren, Ganzzahlform
        EX      DE,HL
        CALL    FP_INTFORM
        EXX                             ; HL' -> Zeichen hinter der Zahl
        DEC     HL
        LD      A,(HL)
        LD      DE,0000h                ; Rückgabe wie bei SB-6511: DE = 0, B = 9
        LD      B,09h
        RET
; <- aufgerufen von 3640h, 3644h, 3648h, 364Ch, 3652h, 3660h
S2N_OVF:
        SET     4,C
        RET
;  IS_DIGIT – CY, wenn A eine Ziffer "0"-"9" ist.
; <- aufgerufen von 35AEh, 35D9h, 362Bh, 3636h
IS_DIGIT:
        CP      3Ah
        RET     NC
        CP      30h
        CCF
        RET
; <- aufgerufen von 35C6h, 35F2h
S2N_ROUND:
        PUSH    AF
        PUSH    BC
        CALL    MANT_INCNC
        POP     BC
        POP     AF
        RET
;  S2N_PUTDIG – Ziffer A ("0"-"9") von rechts in die Mantisse unter HL
;  schieben (RLD über 8 Bytes).
; <- aufgerufen von 35B9h, 35E4h
S2N_PUTDIG:
        PUSH    BC
        PUSH    HL
        PUSH    AF
        SUB     30h
        LD      B,08h
S2P_LP:  DEC     HL
        RLD
        DJNZ    S2P_LP
        POP     AF
        POP     HL
        POP     BC
        RET
;  S2N_NEXTCH – nächstes Zeichen aus dem Text (HL'), Leerzeichen überlesen.
; <- aufgerufen von 35A3h, 35CDh, 35D6h, 35F8h, 3618h, 3621h, 3628h, 3633h
S2N_NEXTCH:
        EXX
S2X_SKIPSP:  LD      A,(HL)
        INC     HL
        CP      20h
        JR      Z,S2X_SKIPSP
        EXX
        RET
;  NUM2STR – Zahl (HL, Zeiger auf Byte 0) als Text nach NUMBUF: Vorzeichen
;  (" " oder "-"), Ziffern, ggf. Punkt; außerhalb von 16 Stellen bzw. sehr
;  klein mit Exponent ("E+nn"/"E-nn"). Die Mantisse wird dazu nach FP_DIG
;  entpackt (eine Ziffer je Byte, ASCII), Nullen am Anfang und Ende
;  übergangen. Am Ende kopiert L5350 den Text ins Ziel (DE beim Aufruf) bzw.
;  formatiert ihn für PRINT USING; A = 0, 1 (mit Exponent) oder 2 (ganze
;  Zahl) sagt L5350, welche Form vorliegt.
; <- aufgerufen von 2A2Fh, 38AEh
NUM2STR:
        PUSH    DE
        LD      BC,0008h                ; HL -> Exponentbyte
        ADD     HL,BC
        LD      A,20h                   ; Vorzeichen: " " oder "-"
        BIT     7,(HL)
        JR      Z,N2S_SIGN
        LD      A,2Dh
N2S_SIGN:  LD      DE,NUMBUF
        LD      (DE),A
        INC     DE
        PUSH    DE                      ; (SP) = Textzeiger hinter dem Vorzeichen
        EX      DE,HL
        LD      C,20h                   ; DE -> Ende des Ziffernpuffers (NUMBUF+21h)
        ADD     HL,BC
        EX      DE,HL
        PUSH    DE
        LD      A,(HL)                  ; C = E - 40h (Stellen gegenüber der Ganzzahlform), 0 bei Null
        AND     7Fh
        OR      A
        JR      Z,N2S_EXP
        SUB     40h
N2S_EXP:  LD      C,A
        LD      B,08h
N2S_UNPACK:  DEC     HL                 ; 16 Ziffern als ASCII entpacken, von hinten
        LD      A,(HL)
        AND     0Fh
        OR      30h
        LD      (DE),A
        DEC     DE
        LD      A,(HL)
        AND     0F0h
        RLCA
        RLCA
        RLCA
        RLCA
        OR      30h
        LD      (DE),A
        DEC     DE
        DJNZ    N2S_UNPACK
        INC     DE                      ; DE -> erste Ziffer
        LD      B,10h                   ; B = Zahl der Ziffern ohne führende Nullen
N2S_SKIP0:  LD      A,(DE)
        CP      30h
        JR      NZ,N2S_FORMAT
        INC     DE
        DJNZ    N2S_SKIP0
N2S_FORMAT:  LD      A,C                ; E = 40h: ganze Zahl
        AND     A
        JR      Z,N2S_TOINT
        JP      M,N2S_SMALL             ; E < 40h: mit Nachkommastellen
        ADD     A,B                     ; E > 40h: Stellenzahl über 16 -> Exponentform
        CP      11h
        JP      P,N2S_EXPFMT
N2S_TOINT:  JP      N2S_INT
; <- aufgerufen von 3701h
N2S_SMALL:
        CP      0E2h                    ; mehr als 30 Nachkommastellen: Exponentform
        JP      M,N2S_EXPFMT
        ADD     A,B                     ; C = Stellen vor dem Punkt (<= 0: keine)
        LD      C,A
        EX      DE,HL
        EX      (SP),HL
        EX      DE,HL
N2M_TRAIL0:  LD      A,(DE)             ; Nullen am Ende übergehen
        CP      30h
        JR      NZ,N2M_CHK
        DEC     DE
        DEC     B
        JR      N2M_TRAIL0
N2M_CHK:  POP     DE
        POP     HL
        LD      A,C
        OR      A
        JR      Z,N2S_LEAD0             ; keine Vorkommastellen: "0."
        JP      M,N2S_LEAD0
N2M_INTDIG:  LD      A,(DE)             ; Vorkommastellen ausgeben
        CALL    PUT_CHR
        INC     DE
        DEC     B
        JR      Z,N2L_PAD               ; Ziffern aus: mit Nullen bis zum Punkt auffüllen
        DEC     C
        JR      NZ,N2M_INTDIG
        JR      N2L_POINT
; <- aufgerufen von 3726h
N2S_LEAD0:
        CALL    PUT_ZERO                ; "0"
N2L_POINT:  LD      (HL),2Eh            ; "."
        INC     HL
        LD      A,C
        OR      A
        JR      Z,N2L_FRAC
N2L_ZEROS:  CALL    PUT_ZERO            ; führende Nullen hinter dem Punkt
        INC     C
        JR      NZ,N2L_ZEROS
N2L_FRAC:  LD      A,(DE)               ; restliche Ziffern
        INC     DE
        CALL    PUT_CHR
        DJNZ    N2L_FRAC
N2L_END:  JP      N2S_END0              ; Form 0 (normal)
N2L_PAD:  DEC     C                     ; Vorkommastellen mit "0" auffüllen
        JR      Z,N2L_END
        CALL    PUT_ZERO
        JR      N2L_PAD
; <- aufgerufen von 370Ah
N2S_INT:
        POP     AF
        POP     HL
        XOR     A
        CP      B
        JR      NZ,N2I_DIGITS           ; Wert 0: " 0"
        CALL    PUT_ZERO
        JR      N2S_END0
N2I_DIGITS:  LD      A,(DE)             ; Ziffern ...
        INC     DE
        CALL    PUT_CHR
        DJNZ    N2I_DIGITS
        LD      A,C
        OR      A
N2I_ZEROS:  JR      Z,N2S_END+1         ; ... dann C Nullen; Form 2 (ganz)
        CALL    PUT_ZERO
        DEC     C
        JR      N2I_ZEROS
; <- aufgerufen von 3707h, 370Fh
N2S_EXPFMT:
        DEC     A                       ; A' = Dezimalexponent - 1
        EX      AF,AF'
        POP     AF
        LD      C,B
        LD      B,00h
        LD      H,D
        LD      L,E
        ADD     HL,BC
        LD      B,C
        LD      A,30h
N2E_TRAIL0:  DEC     HL                 ; Nullen am Ende übergehen
        CP      (HL)
        JR      NZ,N2E_FIRST
        DJNZ    N2E_TRAIL0
N2E_FIRST:  POP     HL
        LD      A,(DE)                  ; erste Ziffer
        CALL    PUT_CHR
        DEC     B
        JR      Z,N2E_E
        LD      (HL),2Eh                ; ".", dann die übrigen Ziffern
        INC     HL
N2E_MANT:  INC     DE
        LD      A,(DE)
        CALL    PUT_CHR
        DJNZ    N2E_MANT
N2E_E:  LD      (HL),45h                ; "E"
        INC     HL
        EX      AF,AF'
        LD      C,A
        LD      B,2Bh                   ; "+" bzw. "-"
        JP      P,N2S_ESIGN
        LD      B,2Dh
; <- aufgerufen von 379Fh
N2S_ESIGN:
        LD      (HL),B
        INC     HL
        JP      P,N2S_EDIG              ; positiv
        LD      A,0F0h                  ; negativ: Betrag (der Exponent liegt als F0h - Wert vor)
        SUB     C
; <- aufgerufen von 37A6h
N2S_EDIG:
        LD      C,00h
N2D_TENS:  CP      0Ah                  ; Zehner zählen
        JP      M,N2D_OUT
        SUB     0Ah
        INC     C
        JR      N2D_TENS
; <- aufgerufen von 37B0h
N2D_OUT:  LD      B,A
        LD      A,C
        OR      A
        CALL    NZ,PUT_DIGIT            ; Zehnerziffer nur, wenn <> 0
        LD      A,B
        CALL    PUT_DIGIT               ; Einerziffer
        LD      A,01h                   ; Form 1 (mit Exponent); DEFB 01h verschluckt LD A,00h
        DEFB    01h
;  N2S_END0/N2S_END – Textende 0Dh, dann L5350 mit A = Form (siehe NUM2STR).
;  Byte-Trick: "LD A,01h / DEFB 01h" verschluckt "LD A,00h"; N2S_END+1 ist
;  "LD A,02h" (aus dem Operanden von LD BC,023Eh).
; <- aufgerufen von 374Dh
N2S_END0:
        LD      A,00h
N2S_END:
        LD      BC,023Eh
        LD      (HL),0Dh
        POP     DE
        CALL    NUM_OUT
        RET
;  PUT_ZERO/PUT_DIGIT/PUT_CHR – "0", Ziffer A bzw. Zeichen A nach (HL), HL+1.
; <- aufgerufen von 3736h, 3740h, 3753h, 375Eh, 376Eh
PUT_ZERO:
        XOR     A
; <- aufgerufen von 37BBh, 37BFh
PUT_DIGIT:
        ADD     A,30h
; <- aufgerufen von 372Ah, 3748h, 3765h, 3788h, 3793h
PUT_CHR:
        LD      (HL),A
        INC     HL
        RET
; ==============================================================================
;  PRINT / INPUT
; ==============================================================================
;  Geräteverteilung über DEV_DISPATCH und die Tabellen
;  DEVTAB_PRINT/DEVTAB_INPUT (Bildschirm, Drucker, Kassette, Diskette).
;  PRINT [/P | /T | #n[(satz)]] [USING schablone;] [ausdruck][; | ,][...]
;  – auch "?". Zuerst USING_PTR = 0 (ohne USING). /P und /T setzen FILE_NO
;  auf 82h bzw. 83h (GETDEVICE), #n auf n (FILE_RECNO liest bei
;  Satzdateien die Satznummer), sonst 80h. USING (Token 9Dh) direkt danach
;  bzw. bei /P: PR_USING.
;  Jedes Element wird mit VAL2TEXT/STR2TEXT nach INBUF gewandelt und über
;  DEVTAB_PRINT+2*15 ausgegeben; ohne ; oder , am Ende folgt der
;  Zeilenabschluss über DEVTAB_PRINT. "," springt auf dem Bildschirm zur
;  nächsten Tabulatorposition (TABPOS), beim Drucker über PRN_TABZONE.
;  TAB(n) füllt auf dem Bildschirm mit 03h, beim Drucker mit Leerzeichen
;  bis Spalte n auf; bei anderen Geräten Fehler 1.
ST_PRINT:
        XOR     A
        LD      D,A
        LD      E,A
        LD      (USING_PTR),DE
        CALL    CHK_CHR_ALT
        DEFB    2Fh                     ; Inline-Parameter '/'
        DEFW    PR_SLASH                   ; Inline-Parameter
        CALL    GETDEVICE
        LD      A,(FILE_NO)
        CP      82h
        JR      NZ,PR_LOOP
        CALL    SKIPSP
        CP      9Dh
        CALL    Z,PR_USING
        JR      PR_LOOP
PR_SLASH:
        CALL    SKIPSP
        CP      9Dh
        CALL    Z,PR_USING
PR_FILE:
        CALL    FILE_SELECT
        CALL    FILE_RECNO
PR_LOOP:
        CALL    CHRGET
        JR      NZ,PR_SEP
        LD      (TXTPTR),HL
; <- aufgerufen von 3845h
PR_EOL: LD      HL,DEVTAB_PRINT
        CALL    DEV_DISPATCH
        JP      NEXTSTMT
; <- aufgerufen von 384Eh
PR_SEP: CALL    CHK_CHR_ALT
D381A:  DEFB    3Bh                     ; Inline-Parameter ';'
D381B:  DEFW    PR_SEPDO
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
; <- aufgerufen von 383Bh
PR_ITEM:
        CP      3Bh                     ; ';'
        JR      Z,PR_ISSEP
        CP      2Ch                     ; ','
PR_ISSEP:
        JP      Z,PR_SEP
        CALL    CHK_CHR_ALT
D3854:  DEFB    0A9h                    ; Inline-Parameter
D3855:  DEFW    PR_EXPR
        CALL    EVAL_BYTE
        CALL    SYNCHK
D385D:  DEFB    29h                     ; Inline-Parameter ')'
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
; <- aufgerufen von 388Bh, 5102h
VAL2TEXT:
        PUSH    AF
        PUSH    HL
        EX      DE,HL
        LD      HL,(VALSP)
        CALL    NUM2STR
        POP     HL
        CALL    LEN_CR
        JP      TEXT_LEN
; <- aufgerufen von 388Eh, 38DEh, 5105h
STR2TEXT:
        PUSH    AF
        CALL    GETSTR
        EX      DE,HL
        CALL    BLKMOVE
        EX      DE,HL
; <- aufgerufen von 38B5h
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
;  PR_USING – PRINT [/P] USING schablone; ... : Schablone (Stringausdruck)
;  auswerten, ";" muss folgen; USING_PTR auf USING_FMT setzen, Schablone mit
;  USING_PARSE zerlegen. Danach gibt NUM2STR jede Zahl über NUM_OUT nach der
;  Schablone aus. Leere Schablone: Fehler 1.
; <- aufgerufen von 37F3h, 37FDh
PR_USING:
        CALL    EVAL_EXPR_INC
        CALL    SYNCHK
        DEFB    3Bh                     ; Inline-Parameter ';'
        PUSH    HL
        LD      HL,USING_FMT
        LD      (USING_PTR),HL
        LD      A,D
        OR      A
        JP      Z,ERR_01
        CALL    STR2TEXT
        CALL    USING_PARSE
        POP     HL
        RET
;  FILE_RECNO – nach #n: Dateieintrag holen; bei Satzdateien (FC_MODE = 2)
;  muss "(satz)" folgen, Satznummer > 0 nach REC_NO. Danach optionales ",".
; <- aufgerufen von 3803h, 3BD4h
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
D38FB:  DEFB    28h                     ; Inline-Parameter '('
        CALL    EVAL_INT
        LD      (REC_NO),DE
        LD      A,D
        OR      E
        JP      Z,ERR_03
        CALL    SYNCHK
D390B:  DEFB    29h                     ; Inline-Parameter ')'
        RET
;  FILE_FLUSH – geänderten Sektor der Satzdatei zurückschreiben, dann
;  FILE_RELBUF: Puffer 6682h freigeben.
; <- aufgerufen von 3A1Eh
FILE_FLUSH:
        LD      A,(REC_BUFOK)
        OR      A
        JP      Z,FILE_RELBUF
        PUSH    HL
        LD      HL,(6682h)
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        DEC     DE
        DEC     DE
        LD      BC,(REC_BUFSEC)
        CALL    DISK_WRITE
        POP     HL
; <- aufgerufen von 38EFh, 3911h, 3D26h
FILE_RELBUF:
        XOR     A
        LD      (REC_BUFOK),A
        PUSH    HL
        LD      HL,(6682h)
        CALL    AREA_FREE
        POP     HL
        RET
;  REC_*: Satzdateien (32-Byte-Sätze). REC_NO aktuelle Satznummer,
;  REC_BUFOK/REC_BUFSEC geladener Sektor im Puffer 6682h, REC_SEC und
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
;  Satzdatei (FC_MODE = 2): REC_PUT. Sonst Fehler 45 (SB-6511: 44). Wird
;  die Datei zu groß: Fehler 53 (SB-6511: 55).
FILE_PUT:
        LD      A,(FC_MODE)
        CP      02h
        JP      Z,REC_PUT
        CP      01h
        JP      NZ,ERR_45               ; [SB-6511: JP NZ,ERR_44]
        LD      (FPUT_SRC+1),DE
        LD      HL,(FC_B14)
        PUSH    HL
        INC     BC
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        ADD     HL,BC
        JP      C,ERR_53                ; [SB-6511: JP C,ERR_55]
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
; <- aufgerufen von 397Ah
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
; <- aufgerufen von 3972h
FPUT_NEXTSEC:
        PUSH    BC
        CALL    FILE_FIRSTSEC
        CALL    FILE_SECCNT
        CALL    FILE_SWAPSEC
        POP     BC
        RET
; <- aufgerufen von 3994h, 4249h
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
; <- aufgerufen von 398Eh, 4243h
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
; <- aufgerufen von 3991h
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
; <- aufgerufen von 39B8h
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
; <- aufgerufen von 3941h
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
; <- aufgerufen von 3CC1h
REC_NEXTNO:
        LD      HL,(REC_NO)
        INC     HL
        LD      (REC_NO),HL
        RET
; <- aufgerufen von 3A21h, 3CB0h
REC_GETBUF:
        LD      A,(REC_BUFOK)
        OR      A
        JP      Z,REC_LOADSEC
        LD      HL,(REC_BUFSEC)
        EX      DE,HL
        LD      HL,(REC_SEC)
        CALL    CPHLDE
        JP      Z,REC_BUFADR
; <- aufgerufen von 3A3Ch
REC_LOADSEC:
        CALL    SECTOR_SIZE
        LD      HL,(6682h)
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
; <- aufgerufen von 3A49h
REC_BUFADR:
        LD      HL,(6682h)
        INC     HL
        INC     HL
        RET
;  REC_LOCATE – Satznummer REC_NO-1 in Sektor (REC_SEC, über die
;  Sektortabelle bei FC_B40) und Versatz (REC_OFS = Satz * 32) zerlegen.
;  Nur für FC_TYPE = 0, sonst Fehler 1.
; <- aufgerufen von 3A0Bh, 3CADh
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
; <- aufgerufen von 3A7Ch, 3A89h, 3AB5h
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
; <- aufgerufen von 3A08h
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
; <- aufgerufen von 3AC3h
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
; <- aufgerufen von 3811h, 3894h, 3BE1h, 4153h, 4218h
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
        DEFW    CRLF                    ;  0: 80h Bildschirm
        DEFW    ERR_01                  ;  1: 81h DATA
        DEFW    PRN_CRLF                ;  2: 82h Drucker
        DEFW    DEV_NOP                 ;  3: 83h Kassette
;  INT_FINISH – Schluss von FN_INT: (DE) in Ganzzahlform; Null wird zu
;  echter 0 (kein "-0"). Steht in den unbenutzten Einträgen 4-9 von
;  DEVTAB_PRINT (Geräte 84h-89h, bei SB-6511 GP-IB/RS-232C). Nachträgliche
;  Korrektur: in der älteren Fassung (DISK26) fehlt sie.
; <- aufgerufen von 3587h
INT_FINISH:
        CALL    FP_INTFORM
        EX      DE,HL
        CALL    FP_ISZERO
        CALL    Z,FP_SETZERO
        EX      DE,HL
        RET
        DEFW    FILE_FLUSH              ; 10: Datei, Typ 0
        DEFW    FILE_FLUSH              ; 11
        DEFW    ERR_01                  ; 12
        DEFW    DEV_NOP                 ; 13
        DEFW    DEV_NOP                 ; 14
;  ab hier DEVTAB_PRINT+2*15: ein Element ausgeben
        DEFW    PRTSTR_RAW              ; 15: 80h Bildschirm
        DEFW    ERR_01                  ; 16: 81h DATA
        DEFW    PRN_TEXT                ; 17: 82h Drucker
        DEFW    TPRINT                  ; 18: 83h Kassette
        DEFW    ERR_01                  ; 19-24: 84h-89h unbenutzt
        DEFW    ERR_01
        DEFW    ERR_01
        DEFW    ERR_01
        DEFW    ERR_01
        DEFW    ERR_01
        DEFW    FILE_PUT                ; 25: Datei
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
D3B55:  DEFB    2Fh                     ; Inline-Parameter '/'
D3B56:  DEFW    IN_FILE
        CALL    GETDEVICE
        JP      IN_DEV
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
D3B78:  DEFB    3Bh                     ; Inline-Parameter ';'
        CALL    GETSTR
IN_PROMPT:
        LD      (TXTPTR),HL
; <- aufgerufen von 3BCEh
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
; <- aufgerufen von 2C33h, 3CE9h
IN_MORE:
        CALL    CRLF_IF
        LD      DE,MSG_QMARK
        JP      IN_ASK
MSG_QMARK:
        DEFB    3Fh,20h,0Dh             ; ?? |? .|
; <- aufgerufen von 3B5Bh, 3B65h
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
;  wird im Eintrag Byte 8 gesetzt (FILE_EOF, für IF EOF). Sonst Fehler 45
;  (SB-6511: 44).
FILE_GET:
        LD      A,(FC_MODE)
        CP      02h
        JP      Z,REC_GET
        OR      A
        JP      NZ,ERR_45               ; [SB-6511: JP NZ,ERR_44]
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
; <- aufgerufen von 3C28h, 3CAAh
FILE_EOF:
        LD      A,01h
        LD      BC,0000h
; <- aufgerufen von 3CC6h
FILE_SETEOF:
        LD      IX,(FC_ENTRY)
        LD      (IX+8),A
        RET
; <- aufgerufen von 3C3Dh
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
; <- aufgerufen von 3C6Fh, 41B1h
FGET_NEXTSEC:
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        CALL    FILE_SECSIZE
        PUSH    HL
        CALL    DISK_READ
        POP     HL
        RET
; <- aufgerufen von 39A3h, 3C82h, 41BEh
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
; <- aufgerufen von 3C19h
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
; <- aufgerufen von 3BC5h
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
D3CEF:  DEFB    2Ch                     ; Inline-Parameter ','
D3CF0:  DEFW    IN_STRVAL
        PUSH    HL
        LD      DE,STR_CR
        CALL    STRLIT
        POP     HL
        JR      IN_SETPTR
IN_STRVAL:
        CALL    STRLIT
; <- aufgerufen von 3D80h
IN_SETPTR:
        LD      (IN_PTR),HL
        LD      HL,IN_NEXTVAL
;  IN_ASSIGN – Wert (STRLIT-Ergebnis) der nächsten Variablen aus der
;  INPUT-Liste zuweisen; danach zurück zur Adresse auf dem Stack (nächster
;  Wert) oder am Ende der Liste NEXTSTMT.
; <- aufgerufen von 3BF3h
IN_ASSIGN:
        PUSH    HL
        CALL    SAVEPAR0
        LD      HL,(TXTPTR)
        CALL    GETNAME_SN
        CALL    GETVAR
        LD      (TXTPTR),HL
        CALL    SAVEPAR1
; <- aufgerufen von 3D4Dh
IN_ASG_DO:
        CALL    ASSIGN
D3D1B:  DEFW    IN_TONUM
        LD      HL,(TXTPTR)
        CALL    CHRGET
        JR      NZ,IN_COMMA
        POP     AF
        CALL    FILE_RELBUF
        JP      NEXTSTMT
IN_COMMA:
        CALL    SYNCHK
D3D2F:  DEFB    2Ch                     ; Inline-Parameter ','
        LD      (TXTPTR),HL
        RET
IN_TONUM:
        LD      DE,(6002h)
        CALL    GETSTR
        EX      DE,HL
        CALL    CHK_CHR_ALT
D3D3F:  DEFB    0Dh                     ; Inline-Parameter
D3D40:  DEFW    IN_TONUM2
        LD      HL,STR_0
IN_TONUM2:
        CALL    NUMSTR_EVAL
D3D48:  DEFW    ERR_04
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
; <- aufgerufen von 3CD0h, 3D6Fh
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
; <- aufgerufen von 3D61h
DATA_SEARCH:
        LD      HL,PRGTXT
DATA_SRCH_FROM:
        XOR     A
        LD      (DATA_FLAG),A
; <- aufgerufen von 3DB1h
DATA_SRCH_LINE:
        LD      A,(HL)
        INC     HL
        OR      (HL)
        INC     HL
        JP      Z,ERR_24
        INC     HL
        INC     HL
; <- aufgerufen von 3DAEh
DATA_SRCH_STMT:
        CALL    CHK_CHR_ALT
D3D96:  DEFB    80h                     ; Inline-Parameter
D3D97:  DEFW    DATA_SKIPSTMT
        CALL    CHK_CHR_ALT
D3D9C:  DEFB    81h                     ; Inline-Parameter
D3D9D:  DEFW    DATA_SKIPSTMT
        LD      (DATA_PTR),HL
        LD      A,01h
        LD      (DATA_FLAG),A
        RET
DATA_SKIPSTMT:
        CALL    SKIPSTMT
; <- aufgerufen von 3D6Ch
DATA_NEXTSTMT:
        INC     HL
        CP      3Ah                     ; ':'
        JP      Z,DATA_SRCH_STMT
        JP      DATA_SRCH_LINE
; >>> SB-6610: ohne Gegenstück in SB-6511
LOAD_MODE:
        DEFB    00h
;  LOAD [/T | dateiangabe] – BASIC-Programm (Typ BTX) laden, auch CHAIN
;  und RUN "datei" laufen hier durch. /T: von Kassette (LOAD_TAPE).
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
LOAD_GO:
        XOR     A
        LD      (CHAIN_MODE),A
        LD      (RUN_LOADFLG),A
        CALL    CHK_CHR_ALT
D3DCB:  DEFB    2Fh                     ; Inline-Parameter '/'
D3DCC:  DEFW    LOAD_FD
        CALL    SYNCHK
D3DD1:  DEFB    54h                     ; Inline-Parameter 'T'
        JP      LOAD_TAPE
; <- aufgerufen von 20C0h, 3F3Ah
LOAD_FD:
        CALL    FILESPEC
        CALL    CHK_EOS
; <- aufgerufen von 3FDCh
LOAD_TOPRG:
        LD      HL,PRGTXT
LOAD_SETDST:
        LD      (LOAD_DST),HL
        LD      HL,0000h
        LD      (LOAD_OFS),HL
        CALL    DIR_SCAN
D3DEA:  DEFW    LOAD_MATCH
        JP      ERR_40
LOAD_MATCH:
        RET     Z
        RET     M
        CALL    NAMECMP
        RET     NZ
        POP     AF
        LD      A,(HL)
; <- aufgerufen von 4010h
LOAD_ENTRY:
        LD      DE,DIRENT
        LD      BC,0020h
        LDIR
        DEC     A
        JP      Z,LOAD_OBJ
        DEC     A
        JP      NZ,ERR_63
        LD      HL,(667Ch)
        CALL    AREA_FREE
        LD      A,(CHAIN_MODE)
        OR      A
        JP      NZ,CHAIN_KEEP
; >>> SB-6610: ohne Gegenstück in SB-6511
        CALL    PROG_NEW
; <- aufgerufen von 3F4Ah
LOAD_ROOM:
        LD      BC,(DIRENT_SIZE)
        LD      HL,(LOAD_OFS)
        ADD     HL,BC
        LD      C,L
        LD      B,H
        DEC     BC
        DEC     BC
        LD      DE,PRGTXT
        CALL    MEMINS_ADJ
        LD      A,01h
        LD      (RELINK_NEW),A
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
; >>> SB-6610: ohne Gegenstück in SB-6511
        XOR     A
        LD      (RELINK_NEW),A
; <- aufgerufen von 4C64h
LOAD_RELINK:
        CALL    RELINK
LOAD_DONE:
        CALL    MOTOR_OFF
LOAD_RUN:
        LD      A,(RUN_LOADFLG)
        OR      A
        JP      Z,NEXTSTMT
        LD      HL,(PRGTXT)
        LD      A,H
        OR      L
        JP      Z,BAS_READY
        LD      HL,(68DFh)
        CALL    PRTNUM
        EX      DE,HL
        LD      A,(SWAP_ACTIVE)
        OR      A
        JP      Z,RUN_CLR
        XOR     A
        LD      (SWAP_ACTIVE),A
        JP      SWAP_RESTORE
; <- aufgerufen von 3E60h
LOAD_PART1:
        LD      BC,0FFFFh
LOAD_P1LEN:
        LD      DE,0FFFFh
        LD      HL,(LOAD_DST)
        LD      A,D
        OR      E
        RET     Z
        JP      DISK_READ
; <- aufgerufen von 3E63h
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
;  LIST_LOCK – <> 0 sperrt LIST und SAVE (CHK_DIRECT_LK). Wird von CLEARALL
;  gelöscht, aber vom BASIC nirgends gesetzt: vermutlich ein Listschutz, den
;  ein Programm per POKE setzt. Weder das Handbuch noch ein Programm auf den
;  Disketten erwähnt oder benutzt ihn.
LIST_LOCK:
        DEFB    00h,00h
;  SAVE [/T | dateiangabe] – Programm als BTX speichern (nur Direktmodus).
;  Platz suchen (SEC_ALLOC), Links relativ machen (UNLINK), Sektoren
;  schreiben, Links zurückrechnen, Verzeichniseintrag anlegen
;  (DIR_NEWFILE; vorhandener Name: Fehler 42, Verzeichnis voll: 51).
ST_SAVE:
        CALL    CHK_DIRECT_LK                   ; [SB-6511: CALL CHK_DIRECT]
        XOR     A
        LD      (RUN_LOADFLG),A
        CALL    CHK_CHR_ALT
D3EDA:  DEFB    2Fh                     ; Inline-Parameter '/'
D3EDB:  DEFW    SAVE_FD
        CALL    SYNCHK
D3EE0:  DEFB    54h                     ; Inline-Parameter 'T'
        JP      SAVE_TAPE
SAVE_FD:
        CALL    FILESPEC
        LD      A,02h
        LD      (DIRENT),A
        CALL    CHK_EOS
        LD      DE,PRGTXT
; <- aufgerufen von 3F95h
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
SAVE_RUNFLG:
        DEFB    00h
SAVE_CHAIN:
        DEFB    00h
CHAIN_MODE:
        DEFB    00h
;  CHAIN dateiangabe – Programm laden und starten, Variablen bleiben
;  erhalten (CHAIN_MODE = 1). Auch SWAP benutzt diesen Weg (CHAIN_MODE
;  2/3, CHAIN_SWAP).
ST_CHAIN:
        CALL    CHK_NODIRECT
        LD      A,01h
        LD      (CHAIN_MODE),A
        LD      (RUN_LOADFLG),A
        JP      LOAD_FD
; <- aufgerufen von 3E11h
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
;  SWAP dateiangabe – laufendes Programm samt Variablen (ab 6696h) als
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
D3F7F:  DEFW    SWAP_MATCH
        JP      ERR_40
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
        LD      DE,FNPAR_SP
        JP      SAVE_AREA
SWAP_REUSE:
        CALL    SWAP_SETENT
        LD      HL,SWAP_DIRENT
        LD      DE,DIRENT
        JR      SWAP_SAVEDIR
; <- aufgerufen von 3F1Dh
SWAP_WRITE:
        LD      (END_SWAP+1),A
        LD      A,02h
        LD      (CHAIN_MODE),A
        LD      HL,FNPAR_SP
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
; <- aufgerufen von 1F04h
SWAP_BACK:
        XOR     A
        LD      (FC_VOL),A
        CALL    FILES_RESET
        CALL    DEV_DEFAULT
        CALL    DIR_SCAN
D3FEC:  DEFW    SWAP_BMATCH
        JP      ERR_40
SWAP_BMATCH:
        RET     P
        POP     AF
        LD      A,(HL)
        CP      81h
        JP      NZ,ERR_40
        PUSH    HL
        LD      HL,FNPAR_SP
        LD      (LOAD_DST),HL
        LD      HL,0FDB9h
        LD      (LOAD_OFS),HL
        POP     HL
        LD      (SWAP_ACTIVE),A
        LD      A,03h
        LD      (CHAIN_MODE),A
        DEC     A
        JP      LOAD_ENTRY
; <- aufgerufen von 3E97h
SWAP_RESTORE:
        LD      HL,(SWAP_SIZE)
        LD      (DIRENT_SIZE),HL
        LD      HL,(SWAP_SEC)
        LD      (DIRENT_SEC),HL
        CALL    DIR_SCAN
D4022:  DEFW    SWAP_RMATCH
        JP      ERR_40
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
        CALL    MOTOR_OFF                   ; [SB-6511: CALL FD_MOTOR_OFF]
        JP      NEXTSTMT
; <- aufgerufen von 3F98h
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
; <- aufgerufen von 4038h
SWAP_FREE:
        XOR     A
        LD      (FREE_SECS+1),A
        LD      A,02h
        LD      (FREE_TYPE+1),A
        JP      DIR_WRITEENT
; <- aufgerufen von 3F79h, 3FD9h
COPY32: LD      BC,0020h
        LDIR
        RET
;  DEV_DEFAULT – Standardgerät (DEV_DEFTYPE, von DIR gesetzt) nach FC_TYPE/
;  FC_UNIT. DEV_SAVE/DEV_RESTORE sichern bzw. holen es für SWAP.
; <- aufgerufen von 3F62h, 3FE6h, 42AEh
DEV_DEFAULT:
        PUSH    HL
        LD      HL,(DEV_DEFTYPE)
        LD      (FC_TYPE),HL
        POP     HL
        RET
; <- aufgerufen von 3F5Fh
DEV_SAVE:
        PUSH    HL
        LD      HL,(FC_TYPE)
        LD      (SWAP_DEV),HL
        POP     HL
        RET
; <- aufgerufen von 3FCCh
DEV_RESTORE:
        PUSH    HL
        LD      HL,(SWAP_DEV)
        LD      (FC_TYPE),HL
        POP     HL
        RET
;  FILES_RESET – Dateitabelle leeren und alle Puffer freigeben.
; <- aufgerufen von 3F59h, 3FE3h
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
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
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
D40BF:  DEFB    2Fh                     ; Inline-Parameter '/'
D40C0:  DEFW    ROPEN_FD
        CALL    SYNCHK
D40C5:  DEFB    54h                     ; Inline-Parameter 'T'
        JP      ROPEN_TAPE
ROPEN_FD:
        LD      BC,0003h
        JR      OPEN_FD
ST_WOPEN:
        CALL    CHK_CHR_ALT
D40D1:  DEFB    2Fh                     ; Inline-Parameter '/'
D40D2:  DEFW    WOPEN_FD
        CALL    SYNCHK
D40D7:  DEFB    54h                     ; Inline-Parameter 'T'
        JP      WOPEN_TAPE
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
D4109:  DEFW    OPEN_CHKENT
        JP      OPEN_NEWENT
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
; <- aufgerufen von 410Bh
OPEN_NEWENT:
        XOR     A
        CALL    FTAB_FIND
D4141:  DEFW    ERR_64
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
D416D:  DEFW    OPEN_MATCH
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
; <- aufgerufen von 4179h, 41ABh
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
D41D4:  DEFB    2Fh                     ; Inline-Parameter '/'
D41D5:  DEFW    CLOSE_FD
        CALL    SYNCHK
D41DA:  DEFB    54h                     ; Inline-Parameter 'T'
        JP      CLOSE_TAPE
CLOSE_FD:
        CALL    CHK_NODIRECT
        CALL    GETFILENO
        LD      (TXTPTR),HL
        JP      P,CLOSE_ONE
        LD      A,7Fh
        JR      CLOSE_ALLNO
CLOSE_ALLNEXT:
        LD      A,(FILE_NO)
        DEC     A
        JP      Z,FILECMD_DONE
CLOSE_ALLNO:
        LD      (FILE_NO),A
        CALL    FTAB_FIND
D41FB:  DEFW    CLOSE_ALLNEXT
        CALL    CLOSE_ENTRY
        JR      CLOSE_ALLNEXT
; <- aufgerufen von 41E7h
CLOSE_ONE:
        CALL    FTAB_FIND
D4205:  DEFB    7Fh,14h
        CALL    CLOSE_ENTRY
        CALL    CHK_CHR_ALT_T
D420D:  DEFB    2Ch                     ; Inline-Parameter ','
D420E:  DEFW    FILECMD_DONE
        JR      CLOSE_FD
; <- aufgerufen von 41FDh, 4207h
CLOSE_ENTRY:
        CALL    FILE_LOAD
        LD      HL,CLOSETAB-2*10
        CALL    DEV_DISPATCH
        LD      HL,(FC_ENTRY)
        LD      (HL),00h
        RET
CLOSETAB:
        DEFW    CLOSE_DISK
        DEFW    ERR_01
        DEFW    ERR_01
        DEFW    DEV_NOP
        DEFW    ERR_01
; <- aufgerufen von 4237h, 424Ch
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
; <- aufgerufen von 3F26h
DIR_NEWFILE:
        CALL    DIR_SCAN
D4252:  DEFW    DIR_NEWMATCH
        JP      Z,ERR_51
        LD      (DIR_ENTPTR+1),HL
; <- aufgerufen von 429Bh
DIR_STORE:
        LD      A,(DIRENT)
        LD      (FREE_TYPE+1),A
        LD      A,01h
        LD      (FREE_SECS+1),A
        JP      DIR_WRITEENT
DIR_NEWMATCH:
        RET     M
        RET     Z
        CALL    NAMECMP
        RET     NZ
        JP      ERR_42
; <- aufgerufen von 4240h
CLOSE_REC:
        CALL    DIR_SCAN
D4274:  DEFW    CLOSE_RECMATCH
        JP      Z,ERR_51
        JP      CLOSE_RECDIR
CLOSE_RECMATCH:
        RET     M
        RET     Z
        CALL    NAMECMP
        RET     NZ
        POP     AF
; <- aufgerufen von 4279h
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
; <- aufgerufen von 42B9h
DIR_OPTS:
        XOR     A
        LD      (FC_VOL),A
        LD      (DIR_TOPRN),A
        CALL    CHK_CHR_ALT
D42E3:  DEFB    2Fh                     ; Inline-Parameter '/'
D42E4:  DEFW    DIR_GO
        CALL    CHK_CHR_ALT
D42E9:  DEFB    50h                     ; Inline-Parameter 'P'
D42EA:  DEFW    ERR_01
        LD      A,01h
        LD      (DIR_TOPRN),A
DIR_GO: CALL    CHK_EOS
        XOR     A
        OUT     (GRPH),A
        LD      HL,(FC_TYPE)
        LD      (DEV_DEFTYPE),HL
        LD      A,14h
        LD      (DIR_LINES),A
        CALL    DIR_SCAN
D4305:  DEFW    DIR_ENTRY
        JP      FILECMD_DONE
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
        LD      HL,6014h
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
        LD      DE,600Eh
        LDIR
        EX      DE,HL
        LD      A,(DIRENT_LOCK)
        OR      A
        JR      Z,DIR_OUT
        LD      (HL),2Ah
; <- aufgerufen von 43CEh
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
; <- aufgerufen von 4322h
DIR_HEADER:
        LD      DE,INBUF
        LD      A,(DIRENT_NAME)
        OR      A
        JP      Z,DIR_MASTER
        LD      L,A
        LD      H,00h
        LD      DE,6012h
        CALL    NUM2DEC
        LD      A,20h                   ; ' '
        LD      (DE),A
        LD      HL,MSG_FTYPES+15
        LD      BC,0004h
        JP      DIR_HDRTXT
; <- aufgerufen von 438Dh
DIR_MASTER:
        LD      HL,MSG_FTYPES+19
        LD      BC,0006h
; <- aufgerufen von 43A2h
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
        LD      DE,6017h
        CALL    NUM2DEC
        LD      HL,MSG_FTYPES+25
        LD      BC,000Dh
        LDIR
        JP      DIR_OUT
; <- aufgerufen von 430Ah
DIR_GETFREE:
        PUSH    HL
        PUSH    AF
        CALL    BITMAP_GET
        LD      (DIR_FREE+1),HL
        CALL    MOTOR_OFF                   ; [SB-6511: CALL FD_MOTOR_OFF]
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
; >>> SB-6610: ohne Gegenstück in SB-6511
DEL_FROM:
        DEFW    0000h                   ; DELETE: erste Zeilennummer
DEL_TO: DEFW    0000h                   ; DELETE: letzte Zeilennummer
;  ST_DELLINES – DELETE [a][-[b]]: beginnt das Argument mit einer Ziffer
;  oder "-", werden die Programmzeilen a bis b gelöscht (ohne a: ab Anfang,
;  ohne b: bis Ende; a > b: Fehler 1); sonst DELETE dateiangabe (ST_DELETE).
;  Ohne Programm passiert nichts (DL_CHKPRG).
ST_DELLINES:
        XOR     A
        EX      AF,AF'
        CALL    ISDIGIT                 ; Ziffer: DELETE a...
        JR      C,DL_FROM
        CP      2Dh                     ; weder Ziffer noch "-": Datei löschen
        JP      NZ,ST_DELETE
        EX      AF,AF'
        LD      DE,0000h                ; "-b": ab Zeile 0
        PUSH    DE
        JR      DL_TO
DL_TOEND:
        CALL    CHRGET                  ; "a-" bis Zeilenende: bis 65535
        JR      NZ,DL_ERR
        EX      AF,AF'
        CP      2Dh
        LD      DE,0FFFFh
        JR      NZ,DL_RANGE
DL_ERR: JP      ERR_01                  ; sonst Fehler 1
DL_FROM:
        CALL    GETLNUM_SN              ; erste Zeilennummer
        PUSH    DE
        CP      2Dh
        JR      NZ,DL_RANGE
DL_TO:  INC     HL
        CALL    ISDIGIT
        JR      NC,DL_TOEND
        CALL    GETLNUM_SN              ; zweite Zeilennummer
DL_RANGE:
        LD      (TXTPTR),HL
        POP     HL
        EX      DE,HL
        CALL    CPHLDE                  ; a > b: Fehler 1
        JR      C,DL_ERR
        LD      (DEL_FROM),DE
        LD      (DEL_TO),HL
        CALL    DL_CHKPRG               ; ohne Programm: nichts tun
        LD      HL,PRGTXT               ; erste Zeile >= a suchen (BC = ihre Adresse)
DL_FINDA:
        LD      B,H
        LD      C,L
        CALL    GETLINK
        JP      Z,NEXTSTMT
        PUSH    HL
        LD      HL,(DEL_FROM)
        EX      DE,HL
        CALL    CPHLDE
        POP     HL
        JR      C,DL_FINDA
DL_FINDB:
        PUSH    HL                      ; hinter die letzte Zeile <= b laufen
        POP     IX
        CALL    GETLINK
        JR      Z,DL_LAST
        PUSH    HL
        LD      HL,(DEL_TO)
        CALL    CPHLDE
        POP     HL
        JR      Z,DL_DELETE
        JR      NC,DL_FINDB
DL_LAST:
        PUSH    IX
        POP     HL
DL_DELETE:
        XOR     A                       ; Bereich BC .. HL löschen, Bereiche nachziehen
        SBC     HL,BC
        LD      D,B
        LD      E,C
        LD      B,H
        LD      C,L
        LD      A,B
        OR      C
        CALL    NZ,EDIT_DELMEM
        JP      NEXTSTMT
; <- aufgerufen von 444Fh
DL_CHKPRG:
        LD      HL,(PRGTXT)
        LD      A,H
        OR      L
        RET     NZ
        POP     HL
        JP      NEXTSTMT
;  DELETE dateiangabe – Datei löschen: nur Typ 1-4 (Fehler 63), nicht
;  gesperrt (Fehler 46), nicht geöffnet (CHK_NOTOPEN). Sektoren freigeben
;  (FREE_*), Eintrag mit Typ 0 zurückschreiben.
; <- aufgerufen von 4413h
ST_DELETE:
        CALL    FILESPEC
        LD      A,(FC_TYPE)
        CP      03h
        JP      NC,ERR_01
        CALL    CHK_EOS
        CALL    DIR_SCAN
D44A9:  DEFW    DEL_MATCH
        JP      ERR_40
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
; <- aufgerufen von 3FC9h, 4062h, 4265h
DIR_WRITEENT:
        LD      HL,DIRENT
DIR_ENTPTR:
        LD      DE,0FFFFh
        LD      BC,0020h
        LDIR
        CALL    DIR_WRITE
        LD      HL,(667Ch)
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
; <- aufgerufen von 452Eh
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
; <- aufgerufen von 4528h, 453Bh, 458Dh, 45A7h
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
; <- aufgerufen von 3E3Bh, 3EFEh, 4538h
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
; <- aufgerufen von 4292h, 457Eh
DIRENT_START:
        LD      BC,(DIRENT_SEC)
        RET
;  SECTOR_SIZE – BC = Sektorgröße der Einheit: 256 bei FC_TYPE 0, sonst
;  1024. FILE_SECCOUNT: Anzahl Sektoren für DIRENT_SIZE.
; <- aufgerufen von 3A4Ch, 3E34h, 428Dh, 4541h, 4567h, 4579h
SECTOR_SIZE:
        LD      A,(FC_TYPE)
        LD      BC,0100h
        OR      A
        RET     Z
        LD      BC,0400h
        RET
; <- aufgerufen von 3E49h, 3F12h
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
; <- aufgerufen von 45AAh
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
; <- aufgerufen von 44BEh, 46FBh
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
; <- aufgerufen von 45E3h
ST_KILL:
        CALL    GETFILENO
        LD      (TXTPTR),HL
        JP      P,KILL_ONE
        LD      A,7Fh
        JR      KILL_NO
KILL_NEXT:
        LD      A,(FILE_NO)
        DEC     A
        JP      Z,FILECMD_DONE
KILL_NO:
        LD      (FILE_NO),A
        CALL    FTAB_FIND
D45D0:  DEFW    KILL_NEXT
        LD      (HL),00h
        JR      KILL_NEXT
; <- aufgerufen von 45BCh
KILL_ONE:
        CALL    FTAB_FIND
D45D9:  DEFB    7Fh,14h
        LD      (HL),00h
        CALL    CHK_CHR_ALT_T
D45E0:  DEFB    2Ch                     ; Inline-Parameter ','
D45E1:  DEFW    FILECMD_DONE
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
D45FE:  DEFW    LOCK_MATCH
        JP      FILECMD_DONE
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
; <- aufgerufen von 470Bh
DIR_WRITEBACK:
        CALL    DIR_WRITE
;  FILECMD_DONE – Puffer aufräumen (CLOSE_ALL), weiter mit NEXTSTMT.
; <- aufgerufen von 415Dh, 41F2h, 4307h, 45C7h, 4600h
FILECMD_DONE:
        CALL    CLOSE_ALL
        JP      NEXTSTMT
UNIT_USE:
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h         ; ?? |....|
;  UNITS_CHECK – zählt in UNIT_USE, welche Einheiten noch von geöffneten
;  Dateien benutzt werden, schaltet ohne offene Datei den Motor ab und gibt
;  die Puffer unbenutzter Einheiten frei.
; <- aufgerufen von 467Ch
UNITS_CHECK:
        LD      HL,UNIT_USE
        LD      B,06h
UNITS_CLR:
        CALL    CLRWORD
        DJNZ    UNITS_CLR
        CALL    FTAB_SCAN
D4636:  DEFW    UNITS_COUNT
        LD      HL,UNIT_USE
        LD      B,04h
        XOR     A
UNITS_ANY:
        OR      (HL)
        INC     HL
        DJNZ    UNITS_ANY
        CALL    Z,MOTOR_OFF                 ; [SB-6511: CALL Z,FD_MOTOR_OFF]
        LD      HL,6664h
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
; <- aufgerufen von 4661h, 4689h
AREA_FREE_DE:
        EX      DE,HL
        JP      AREA_FREE
; <- aufgerufen von 131Ch, 14E4h, 408Ah, 4617h
CLOSE_ALL:
        CALL    UNITS_CHECK
        LD      B,04h
        LD      HL,667Ch
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
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
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
D46D2:  DEFW    RENAME_MATCH
        JP      RENAME_DO
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
; <- aufgerufen von 46D4h
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
; <- aufgerufen von 2436h, 40E7h, 41E1h, 45B6h, 4746h
GETFILENO:
        CALL    CHK_CHR_ALT
D4711:  DEFB    23h                     ; Inline-Parameter '#'
D4712:  DEFW    FILENO_DEV
        CALL    GETLNUM
D4717:  DEFW    ERR_64
        LD      A,D
        OR      A
        JP      NZ,ERR_64
        LD      A,E
        DEC     A
        CP      7Fh
        JP      NC,ERR_64
        INC     A
        JR      FILENO_SET
FILENO_DEV:
        LD      A,80h
FILENO_SET:
        LD      (FILE_NO),A
        OR      A
        RET
;  FTAB_FIND – Eintrag mit Dateinummer A in FILETAB suchen: HL = Eintrag,
;  A = Index; fehlt er, Sprung zur Inline-Adresse.
; <- aufgerufen von 2442h, 413Eh, 41F8h, 4202h, 45CDh, 45D6h, 474Eh
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
; <- aufgerufen von 3800h, 3B5Eh
FILE_SELECT:
        CALL    GETFILENO
        RET     M
; <- aufgerufen von 4212h
FILE_LOAD:
        PUSH    HL
        LD      A,(FILE_NO)
        CALL    FTAB_FIND
D4751:  DEFW    ERR_44
        LD      (FC_ENTRY),HL
        LD      DE,FC_IDX
        LD      (DE),A
        INC     DE
        LD      BC,0009h
        LDIR
        CALL    FILE_INITBUF
        POP     HL
        RET
; <- aufgerufen von 414Dh, 4760h
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
;  FILE_INITFD – Dateipuffer (320 Bytes, Bereich 6650h + 2*FC_IDX) anlegen
;  und FC_B00..FC_B13E darauf setzen, Puffer der Einheit holen.
FILE_INITFD:
        LD      A,(FC_IDX)
        LD      HL,6650h
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
; <- aufgerufen von 47DEh, 47E8h, 5FF0h
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
; <- aufgerufen von 3A52h, 44F1h, 4785h, 482Eh, 4A58h
AREA_ALLOC:
        CALL    AREA_RESIZE
        INC     HL
        INC     HL
        RET
; <- aufgerufen von 1B2Eh, 392Eh, 3E0Ah, 4657h, 4679h, 515Ah
AREA_FREE:
        PUSH    BC
        LD      BC,0000h
        CALL    AREA_RESIZE
        POP     BC
        RET
; <- aufgerufen von 4515h, 453Eh, 4597h
BITMAP_WRITE:
        LD      HL,(6682h)
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
; <- aufgerufen von 43D3h, 44F7h, 48E0h
BITMAP_GET:
        LD      HL,(6682h)
        JP      UNIT_BUFCHK
BITMAP_PTR:
        DEFB    00h,00h                 ; ?? |..|
; <- aufgerufen von 47ACh, 4880h, 4A24h, 4A4Eh
UNIT_GETBUF:
        LD      HL,6664h
        LD      A,(FC_UNIT)
        CALL    TABJUMP
; <- aufgerufen von 4800h
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
; <- aufgerufen von 4812h
UNIT_BUFNEW:
        DEC     HL
        DEC     HL
        LD      BC,0100h
        CALL    AREA_ALLOC
        LD      (HL),80h
        RET
;  DISK_READ / DISK_WRITE – DE Bytes ab Sektor BC nach/von HL. Über
;  DISKTAB nach FC_TYPE + Richtung: nur FD (FD_READ lesen, FD_WRITE schreiben).
; <- aufgerufen von 3A5Ch, 3C86h, 3EA6h, 3EB9h, 4521h, 4586h, 4822h, 4F0Eh (+1 weitere)
DISK_READ:
        XOR     A
        JR      DISK_RW
; <- aufgerufen von 3922h, 39A7h, 3F20h, 3FAEh, 4298h, 47F9h
DISK_WRITE:
        LD      A,03h
; <- aufgerufen von 4A61h
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
;  MOTOR_OFF – Sprung auf FD_MOTOR_OFF (alle Aufrufe gehen über diese Stelle).
; <- aufgerufen von 1284h, 3E73h, 403Fh, 43D9h, 4642h, 4F11h, 4F31h
MOTOR_OFF:
        JP      FD_MOTOR_OFF
DISK_PAR:
        DEFB    00h,00h,00h,00h,00h     ; ?? |.....|
DISK_ADDR:
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h             ; ?? |...|
;  BM_*: Belegungstabelle (je Sektor ein Bit). Der Bittest wird in den
;  Befehlen bei BM_SCAN_TEST bzw. BM_BITCODE zur Laufzeit zusammengesetzt.
;  Kein freier Bereich: Fehler 53.
; <- aufgerufen von 4967h
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
; <- aufgerufen von 48D5h
BM_SCAN_BYTE:
        XOR     A
        LD      (BM_SCAN_BIT+1),A
; <- aufgerufen von 48CBh
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
; <- aufgerufen von 4533h
BM_MARK:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        CALL    BITMAP_GET
        POP     DE
        POP     BC
        POP     AF
; <- aufgerufen von 495Dh
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
; <- aufgerufen von 48ECh
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
        DEFB    0CBh,0FFh               ; SMC: BIT n,(HL)   – 2. Byte wird bei 4912h gesetzt (46h+8*n)
        DEFB    0FFh,05h                ; SMC: JR Z/NZ,+5   – Opcode wird bei 491Eh gesetzt (28h/20h)
        DEFB    0D1h                    ; POP DE
        DEFB    0E1h                    ; POP HL
        DEFB    0E1h                    ; POP HL
        DEFB    0C1h                    ; POP BC
        DEFB    0C9h                    ; RET
        DEFB    0CBh,0FFh               ; SMC: SET/RES n,(HL) – 2. Byte wird bei 4931h gesetzt
        DEFB    0D1h                    ; POP DE
        DEFB    0E1h                    ; POP HL
        DEFB    0FFh                    ; SMC: INC DE / DEC DE – wird bei 4927h gesetzt (13h/1Bh)
        DEFB    72h                     ; LD (HL),D
        DEFB    2Bh                     ; DEC HL
        DEFB    73h                     ; LD (HL),E
        DEFB    0E1h                    ; POP HL
        DEFB    0C1h                    ; POP BC
        DEFB    0C9h                    ; RET
;  SEC_ALLOC – DE zusammenhängende freie Sektoren suchen und belegen,
;  BC = erster Sektor.
; <- aufgerufen von 39D9h, 3AEAh, 3F01h, 4185h
SEC_ALLOC:
        CALL    SEC_FINDRUN
        LD      HL,(BITMAP_PTR)
        LD      A,01h
        JP      BM_MARK_MODE
; <- aufgerufen von 4955h
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
; <- aufgerufen von 4964h
SFR_RESET:
        LD      HL,(SFR_LEN+1)
        LD      (SFR_COUNT+1),HL
        XOR     A
        LD      (SFR_FIRST+1),A
        RET
; <- aufgerufen von 3B0Fh, 4500h, 476Bh, 477Fh, 480Bh, 4852h, 4AA9h
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
; <- aufgerufen von 44CFh, 460Ah, 46F5h
CHK_NOTOPEN:
        CALL    FTAB_SCAN
D49B4:  DEFW    CHK_NOTOPEN_CB
        RET
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
; <- aufgerufen von 3DE7h, 3F7Ch, 3FE9h, 401Fh, 416Ah, 424Fh, 4271h, 4302h (+3 weitere)
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
; <- aufgerufen von 4A16h
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
; <- aufgerufen von 49FEh
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
; <- aufgerufen von 4A02h
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
;  den Puffer 667Ch lesen bzw. zurückschreiben.
; <- aufgerufen von 49EDh
DIR_READ:
        XOR     A
        JR      DIR_RW
; <- aufgerufen von 44E8h, 4614h
DIR_WRITE:
        LD      A,03h
DIR_RW: PUSH    AF
        CALL    UNIT_GETBUF
        LD      HL,(667Ch)
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
; <- aufgerufen von 3DF1h, 4130h, 4197h, 426Ah, 427Eh, 44B0h, 4605h, 46E2h (+3 weitere)
NAMECMP:
        LD      DE,DIRENT_NAME
; <- aufgerufen von 46DCh
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
; <- aufgerufen von 4106h, 4633h, 49B1h
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
        LD      HL,664Ch
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
        LD      HL,6650h
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
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h; ?? |........|
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
; <- aufgerufen von 3DD5h, 3EE4h, 3F5Ch, 40F3h, 4498h, 45EDh, 46A1h
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
D4AFD:  DEFB    80h                     ; Inline-Parameter
D4AFE:  DEFW    FSPEC_DEV
        CALL    SYNCHK
D4B03:  DEFB    0A0h                    ; Inline-Parameter
        CALL    EVAL_ADDR
        CALL    SYNCHK
D4B0A:  DEFB    29h                     ; Inline-Parameter ')'
        PUSH    HL
        LD      HL,FC_TYPE
        LD      (HL),03h
        INC     HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        POP     HL
        RET
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
        DEFB    46h,0C4h,0FFh,0FFh,0FFh,0FFh,00h; ?? |F......|
; <- aufgerufen von 4B28h
FSPEC_UNIT:
        AND     0Fh
        DEC     A
        CP      04h
        JP      NC,ERR_61
        LD      (FC_UNIT),A
        INC     HL
        RET
; <- aufgerufen von 4B30h
FSPEC_VOL:
        INC     HL
        CALL    GETLNUM
D4B69:  DEFW    ERR_52
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
; <- aufgerufen von 2088h, 2414h, 2990h, 29B4h, 29DBh, 29F5h, 2AB0h, 2AD9h (+16 weitere)
SKIPCOMMA:
        CALL    CHK_CHR_ALT
D4B7F:  DEFB    2Ch                     ; Inline-Parameter ','
D4B80:  DEFW    SKIPCOMMA_RET
SKIPCOMMA_RET:
        RET
;  GETDEVICE – nach "/": P -> FILE_NO 82h (Drucker), T -> 83h (Kassette).
; <- aufgerufen von 37E4h, 3B58h
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
; <- aufgerufen von 4B9Bh, 4BACh
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
; <- aufgerufen von 3DD2h
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
        JP      C,TAPE_ERR_J                 ; [SB-6511: JP C,TAPE_ERR]
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
        POP     AF
; <- aufgerufen von 4C15h
TAPE_ERR_J:
        JP      TAPE_ERR
; <- aufgerufen von 4C68h
TLV_UNDO:
        LD      DE,68DFh
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
; <- aufgerufen von 4BE1h
MSG_VERIFYING:
        LD      DE,MSG_VERIFY
        JR      TAPE_MSGNAME
; <- aufgerufen von 4C18h
MSG_FOUNDNAME:
        LD      DE,MSG_FOUND
        JR      TAPE_MSGNAME
; <- aufgerufen von 4C5Ch, 4CCEh
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
; <- aufgerufen von 4C9Eh
PRT_QUOTE:
        LD      DE,STR_QUOTE
        JP      PRTSTR
STR_QUOTE:
        DEFB    22h,0Dh                 ; ?? |".|
; <- aufgerufen von 4C3Eh
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
; <- aufgerufen von 3EE1h
SAVE_TAPE:
        LD      BC,SAVE_TAPE_GO
        PUSH    BC
;  TAPE_NAME – optional ",", dann optional "name" (1-16 Zeichen, sonst
;  Fehler 60) nach DIRENT_NAME; Typ in DIRENT.
; <- aufgerufen von 4C04h
TAPE_NAME:
        CALL    CHK_CHR_ALT
D4CED:  DEFB    2Ch                     ; Inline-Parameter ','
D4CEE:  DEFW    TAPE_NAME_GO
TAPE_NAME_GO:
        PUSH    HL
        LD      HL,DIRENT
        LD      (HL),02h
; <- aufgerufen von 4E10h, 4E5Ah
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
; <- aufgerufen von 4D3Eh, 4E13h
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
; <- aufgerufen von 4BEFh, 4C6Ch, 4CD4h, 4E60h
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
; <- aufgerufen von 40D8h
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
; <- aufgerufen von 40C6h
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
; <- aufgerufen von 41DBh
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
; <- aufgerufen von 4D80h, 4EBBh
DLY_OFF:
        PUSH    AF
        LD      A,0C9h
DLY_SET:
        LD      (DLY_LONG),A
        POP     AF
        RET
; <- aufgerufen von 4D86h, 4EC1h
DLY_ON: PUSH    AF
        LD      A,3Eh                   ; '>'
        JR      DLY_SET
;  LOAD_OBJ – Maschinenprogramm (OBJ) von Diskette an seine Ladeadresse
;  laden (unter LIMIT: Fehler 18, über MEMTOP: Fehler 6). Bei RUN "datei"
;  stattdessen RUN_OBJ.
; <- aufgerufen von 3E00h
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
        CALL    MOTOR_OFF                   ; [SB-6511: CALL FD_MOTOR_OFF]
        LD      A,(SAVE_CHAIN)
        LD      (CHAIN_MODE),A
        LD      A,(SAVE_RUNFLG)
        LD      (RUN_LOADFLG),A
        JP      NEXTSTMT
;  RUN_OBJ – OBJ-Programm erst nach PRGTXT laden, dann RUN_TRAMP mit Länge,
;  Quelle, Ziel und Startadresse füllen, nach FF10h kopieren und dort
;  ausführen: verschiebt das Programm an seine Ladeadresse (LDDR, wenn es
;  nach oben geht) und springt es an.
RUN_OBJ:
        LD      HL,PRGTXT
        LD      BC,(DIRENT_SEC)
        LD      DE,(DIRENT_SIZE)
        CALL    DISK_READ
        CALL    MOTOR_OFF                   ; [SB-6511: CALL FD_MOTOR_OFF]
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
        EX      DE,HL
        ADD     HL,BC
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
; <- aufgerufen von 1EA0h
PRN_EOLCHK:
        LD      A,(PRN_COL)
        OR      A
        RET     Z
; <- aufgerufen von 1EA6h, 4383h, 50C9h, 5197h, 51B8h
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
; <- aufgerufen von 4F9Eh
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
        JR      Z,PRN_C_WIDEW                 ; [SB-6511: JR Z,PRN_C_14]
        CP      15h
        JR      Z,PRN_C_15
        POP     AF
        INC     DE
        JR      PRN_TEXT_LP
PRN_C_FF:
        LD      A,0Ch
;  PRN_C_NORMW/PRN_C_WIDEW – Steuerzeichen, die die Schriftbreite ändern,
;  stellen zusätzlich PRN_DOTW um (neu gegenüber SB-6511).
PRN_C_NORMW:
        PUSH    HL
        LD      HL,01E0h
        LD      (PRN_DOTW),HL
        POP     HL
PRN_C_RET:
        LD      B,0FFh
        RET
PRN_C_0E:
        LD      A,0Eh
        JR      PRN_C_NORMW                   ; [SB-6511: JR PRN_C_RET]
PRN_C_11:
        CALL    PRN_ESC
        XOR     A
        LD      (PRN_LFMODE),A
        JR      PRN_C_NORMW                   ; [SB-6511: JR PRN_C_RET]
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
        JR      PRN_C_NORMW                   ; [SB-6511: JR PRN_C_RET]
PRN_C_13:
        LD      A,14h
        JR      PRN_C_NORMW                   ; [SB-6511: JR PRN_C_RET]
; >>> SB-6610: ohne Gegenstück in SB-6511
PRN_C_WIDEW:
        PUSH    HL
        LD      HL,0330h
        LD      (PRN_DOTW),HL
        POP     HL
PRN_C_14:
        LD      A,0Fh
        JR      PRN_C_RET
PRN_C_15:
        LD      A,12h
        JR      PRN_C_NORMW                   ; [SB-6511: JR PRN_C_RET]
;  PRN_LINE – Text unverändert drucken (für LIST/P, DIR/P).
; <- aufgerufen von 1EA3h, 4380h
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
; >>> SB-6610: ohne Gegenstück in SB-6511
; <- aufgerufen von 4F99h, 5058h
PRN_SETCOL:
        LD      A,(PRN_DOTW)
        CP      0E0h
        LD      C,50h
        JR      Z,PRN_COLWRAP
        LD      C,88h
PRN_COLWRAP:
        LD      A,B
        CP      C
        JR      C,PRN_COLST
        SUB     C
PRN_COLST:
        LD      (PRN_COL),A
        POP     DE
        POP     BC
        JP      PRN_CHECK
; <- aufgerufen von 4FF0h, 4FF8h
PRN_ESC_02:
        CALL    PRN_ESC
        LD      A,02h
        LD      (PRN_LFMODE),A
        RET
PRN_LFMODE:
        DEFB    02h                     ; ?? |.|
;  PRN_TABZONE – PRINT "," auf dem Drucker: Leerzeichen bis zur nächsten
;  Spalte, die durch 10 teilbar ist.
; <- aufgerufen von 3832h
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
; >>> SB-6610: ohne Gegenstück in SB-6511
; <- aufgerufen von 50A2h, 50AAh
PRN_STATUS:
        PUSH    BC
        LD      B,A
        CALL    PRN_ESC
        LD      A,B
        CALL    PRN_OUT
        CALL    PRN_WAITRDY
        IN      A,(PRN_CTL)
        RRCA
        RRCA
        POP     BC
        RET
; ==============================================================================
;  DRUCKER (Ports FEh/FFh): PRN_OUT, PAGE/P, IMAGE/P, COPY/P
; ==============================================================================
;  PRN_ESC – ESC (1Bh) senden. PRN_OUT – Byte A an Port FFh, Strobe über
;  Port FEh; wartet auf den Drucker (PRN_WAIT, Zeitüberschreitung:
;  Fehler 65).
; <- aufgerufen von 4FDDh, 503Bh, 505Dh, 50BAh, 515Dh, 51E2h, 520Bh, 521Ah
PRN_ESC:
        LD      A,1Bh
; <- aufgerufen von 4F88h, 4FA1h, 4FE8h, 4FEDh, 4FF3h, 501Ch, 504Dh, 5061h (+13 weitere)
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
; <- aufgerufen von 5064h, 5070h
PRN_WAITRDY:
        XOR     A
; <- aufgerufen von 507Ch
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
; <- aufgerufen von 4F83h, 5038h
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
;  Fehler 3). Puffer: Bereich 6680h. Ohne Argument: Zeilenvorschub.
ST_IMAGEP:
        CALL    CHRGET
        LD      (TXTPTR),HL
        JR      Z,IMAGEP_EOL
        PUSH    HL
        CALL    IMAGEP_FREE
        LD      BC,0540h
        CALL    AREA_RESIZE_CLR                   ; [SB-6511: CALL AREA_RESIZE]
        POP     HL
IMAGEP_LOOP:
        CALL    CHRGET
        LD      (TXTPTR),HL
        JR      Z,IMAGEP_SEND
        CALL    SKIPCOMMA
        CALL    CHK_CHR_ALT
D50F0:  DEFB    3Bh                     ; Inline-Parameter ';'
D50F1:  DEFW    IMAGEP_ITEM
IMAGEP_ITEM:
        CALL    EVAL_EXPR
        PUSH    HL
        LD      HL,(6680h)
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
        LD      HL,(6680h)
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
        LD      HL,(6680h)
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
; <- aufgerufen von 50D8h, 5151h
IMAGEP_FREE:
        LD      HL,(6680h)
        JP      AREA_FREE
; <- aufgerufen von 514Eh
PRN_BITIMG:
        CALL    PRN_ESC                 ; [SB-6511: CALL PRN_CHECK]
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
;  PRN_DOTW – Druckzeile in Punkten: 01E0h (480, normal, 80 Zeichen) oder
;  0330h (816, schmal, 136 Zeichen); gesetzt von PRN_C_NORMW/PRN_C_WIDEW,
;  ausgewertet von PRN_COLWRAP und dem Bitbilddruck.
PRN_DOTW:
        DEFB    0E0h,01h
;  COPY/P n – Bildschirm drucken. 1: Textbildschirm (25 Zeilen ab D000h),
;  2-4: Grafik (Ebenen über GR2_PATCH/GR2_PLANE1 gewählt, invertiert je
;  nach Darstellung PPI_A Bit 4). BREAK bricht ab.
ST_COPYP:
        CALL    CHRGET
        JP      Z,ERR_01
        INC     HL
        LD      (TXTPTR),HL
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
; <- aufgerufen von 5205h, 5214h
PRN_LFRESTORE:
        CALL    PRN_ESC
        LD      A,(PRN_LFMODE)
        JP      PRN_OUT
COPYP_BRK:
        CALL    PRN_LFRESTORE
COPYP_BRK2:
        JP      BREAK
; <- aufgerufen von 51F8h
PRN_GRAPH8:
        CALL    PRN_ESC
        LD      A,18h
        CALL    PRN_OUT
        LD      A,40h                   ; '@'
        CALL    PRN_OUT
        LD      A,01h
        JP      PRN_OUT
; <- aufgerufen von 51FCh
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
; <- aufgerufen von 51DFh
COPYP_NOINV:
        XOR     A
        DEFB    01h                     ; Trick: Opcode 01h verschluckt den folgenden Befehl
; <- aufgerufen von 51DCh
COPYP_INV:
        LD      A,2Fh                   ; '/'
        LD      (GR2_INV1),A
        LD      (GR2_INV2),A
        RET
;  GRAM_READ2 – Byte (HL) aus beiden Grafikebenen lesen und verknüpfen.
;  In GR2_PATCH wird je nach COPY/P-Art "LD B,A / LD A,C" (7947h) oder
;  "JR $+11" (0918h) eingesetzt.
; <- aufgerufen von 5238h
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
        DEFB    00h,00h,00h,00h,00h,00h,00h; ?? |.......|
COPYP_BUFEND:
        DEFB    00h                     ; ?? |.|
;  USING_PARSE – Schablone ab DE zerlegen (Variablen USG_*). Beispiele (im
;  Emulator geprüft): "###.##";-2.5 -> "  -2.50", "$#,###.##";1234.5 ->
;  "$1,234.50", "*****";42 -> "***42", "##";123 -> "%123", "**###" und
;  "$$##" -> Fehler 1. Nachkommastellen werden abgeschnitten, nicht gerundet
;  ("#.##";2.556 -> "2.55"); ohne + oder - in der Schablone kommt bei
;  negativen Zahlen eine Stelle für "-" dazu.
;    Präfix   beliebiger Text bis zum ersten Formatzeichen, nach USING_FMT
;             kopiert (Länge USG_PRELEN)
;    + -      Vorzeichen immer bzw. nur "-" (USG_SIGN, je einmal)
;    $ £ @    Währungszeichen vor der Zahl (USG_CURR, einmal; £ = 91h)
;    # *      Ziffernstelle, "*" füllt führende Stellen mit "*" (USG_FILL;
;             gemischt: Fehler 1); Zahl der Stellen vor/hinter dem Punkt in
;             USG_INTDIG/USG_FRACDIG
;    .        Dezimalpunkt (einmal, Position in USG_POINT)
;    , X      Tausendertrenner bzw. Leerstelle zwischen den Ziffern
;    Suffix   Rest der Schablone (USG_SUFPTR/USG_SUFLEN)
;  IX läuft dabei über USING_FMT, Ende in USING_PTR.
; <- aufgerufen von 38E1h
USING_PARSE:
        XOR     A                       ; USG_PRELEN .. USG_FRACDIG löschen (13 Bytes)
        LD      B,0Dh
        LD      HL,USG_PRELEN
UPA_CLR:
        LD      (HL),A
        INC     HL
        DJNZ    UPA_CLR
        LD      DE,USING_FMT            ; IX -> Ausgabeschablone USING_FMT
        PUSH    DE
        POP     IX
        LD      C,00h
UPA_PREFIX:
        LD      HL,USING_CHARS          ; Präfix bis zum ersten Formatzeichen kopieren
        CALL    USING_MATCH
        JR      Z,UPA_PREEND
        CALL    USING_PUT
        INC     DE
        INC     C
        JR      UPA_PREFIX
UPA_PREEND:  LD      (USING_PTR),IX     ; USING_PTR <> 0: USING aktiv
        LD      A,C
        OR      A
        JR      Z,UPA_FLAGS0
        LD      (USG_PRELEN),A
UPA_FLAGS0:  LD      IY,0000h           ; IY = Zahl der Ziffernstellen
UPA_FLAGS:
        LD      HL,USING_SIGNS          ; Vorzeichen-/Währungszeichen
        CALL    USING_MATCH
        JR      NZ,UPA_DIGITS
        LD      B,A
        LD      HL,USG_CURR             ; Währung nach USG_CURR ...
        CP      2Bh
        JR      Z,UPA_SIGN
        CP      2Dh
        JR      NZ,UPA_SETFLAG
UPA_SIGN:  INC     HL                   ; ... "+"/"-" nach USG_SIGN
UPA_SETFLAG:  LD      A,(HL)
        OR      A                       ; doppelt: Fehler 1
        JP      NZ,ERR_01
        LD      (HL),B
        INC     DE
        JR      UPA_FLAGS
UPA_DIGITS:
        LD      HL,USING_DIGCH          ; Ziffernstellen "#" bzw. "*"
        CALL    USING_MATCH
        JR      NZ,UPA_OTHER
        CALL    USING_PUT
        LD      HL,USG_FILL             ; gemischt: Fehler 1
        LD      B,A
        OR      (HL)
        CP      B
        JP      NZ,ERR_01
        LD      (HL),B
        INC     IY
        INC     DE
        JR      UPA_DIGITS
UPA_OTHER:
        LD      (IX+0),A                ; sonstiges Zeichen in die Schablone
        CP      2Eh
        JR      Z,UPA_POINT
        CP      2Ch
        JR      Z,UPA_NEXT
        CP      58h
        JR      Z,UPA_NEXT
        CP      0Dh
        JR      Z,UPA_END
        LD      (USG_SUFPTR),IX         ; Suffix: Rest bis 0Dh kopieren
        LD      C,00h
UPA_SUFFIX:
        LD      A,(DE)
        CALL    USING_PUT
        INC     DE
        INC     C
        CP      0Dh
        JR      NZ,UPA_SUFFIX
        LD      A,C
        LD      (USG_SUFLEN),A
        JR      UPA_END
UPA_POINT:
        LD      HL,(USG_POINT)          ; zweiter Punkt: Fehler 1
        LD      A,H
        OR      L
        JP      NZ,ERR_01
        LD      (USG_POINT),IX          ; Punkt merken, Stellen davor nach USG_INTDIG
        LD      (USG_INTDIG),IY
        LD      IY,0000h
UPA_NEXT:
        INC     IX
        INC     DE
        JR      UPA_DIGITS
UPA_END:
        LD      HL,(USG_INTDIG)         ; ohne Punkt: alle Stellen vor dem Punkt
        LD      A,H
        OR      L
        JR      NZ,UPA_FRAC
        LD      (USG_INTDIG),IY
        RET
UPA_FRAC:  LD      (USG_FRACDIG),IY
        RET
;  NUM_OUT – Ausgabe von NUM2STR (A = 0 normal, 1 mit Exponent, 2 ganz):
;  ohne USING (USING_PTR = 0) NUMBUF bis 0Dh nach (DE) kopieren. Mit USING:
;  Exponentform Fehler 1; Präfix, Vorzeichen/Währung (USING_SIGN), Ziffern
;  nach der Schablone (Füllzeichen Leerzeichen oder "*", "," und "X"
;  einfügen), Nachkommastellen (USING_DIGS), Suffix. Zu viele Stellen vor dem
;  Punkt: NOU_OVERFLOW gibt "%" und die ganze Zahl aus.
; <- aufgerufen von 37CDh
NUM_OUT:
        EX      AF,AF'
        LD      HL,(USING_PTR)          ; USING aktiv?
        LD      A,H
        OR      L
        JR      NZ,NOU_USING
        LD      HL,NUMBUF               ; nein: NUMBUF nach (DE) kopieren
NOU_COPY:
        LD      A,(HL)
        LD      (DE),A
        INC     DE
        INC     HL
        CP      0Dh
        JR      NZ,NOU_COPY
        RET
NOU_USING:
        EX      AF,AF'
        DEC     A                       ; Form 1 (Exponent): Fehler 1
        JP      Z,ERR_01
        LD      A,(USG_PRELEN)          ; Präfix ausgeben
        OR      A
        LD      C,A
        LD      HL,USING_FMT
        JR      Z,NOU_PREFIX
        LD      B,00h
        LDIR
NOU_PREFIX:  PUSH    HL
        PUSH    DE
        LD      DE,NUMBUF               ; Stellen der Zahl vor dem Punkt zählen
        INC     DE
        LD      HL,(USG_INTDIG)
NOU_CNTINT:  LD      A,(DE)
        INC     DE
        CP      0Dh
        JR      Z,NOU_FIT
        INC     C
        CP      2Eh
        JR      NZ,NOU_CNTINT
        DEC     C
NOU_FIT:  LD      A,L                   ; keine Stellen in der Schablone: Fehler 1
        OR      A
        JP      Z,ERR_01
        SUB     C                       ; B = Stellen der Schablone - Stellen der Zahl
        LD      B,A
        POP     IX
        JP      C,NOU_OVERFLOW          ; zu wenig Stellen: "%" und die ganze Zahl
        POP     HL
        EX      AF,AF'
        LD      A,(USG_FILL)            ; Füllzeichen "*" oder Leerzeichen
        CP      2Ah
        JR      Z,NOU_FILLCH
        LD      A,20h
NOU_FILLCH:  EX      AF,AF'
        JR      Z,NOU_COMMA
        EX      AF,AF'
        EX      AF,AF'
NOU_INTFILL:
        LD      A,(HL)                  ; freie Stellen vorn füllen ("," mitfüllen)
        CP      23h
        JR      Z,NOU_FILLPUT
        CP      2Ah
        JR      Z,NOU_FILLPUT
        CP      2Ch
        JR      NZ,NOD_SPACE
NOU_FILLPUT:  EX      AF,AF'
        CALL    USING_PUTINC
        EX      AF,AF'
        CP      2Ch
        JR      Z,NOU_INTFILL
        DJNZ    NOU_INTFILL
NOU_COMMA:  LD      A,(HL)              ; "," direkt vor der Zahl als Füllzeichen
        CP      2Ch
        JR      NZ,NOU_SIGNOUT
        EX      AF,AF'
        CALL    USING_PUTINC
        EX      AF,AF'
        JR      NOU_COMMA
NOU_SIGNOUT:  CALL    USING_SIGN        ; Währung/Vorzeichen
; <- aufgerufen von 541Dh
NOU_DIGITS:
        CALL    USING_DIGS              ; Ziffern vor dem Punkt
NOD_REST:  LD      A,(DE)               ; Punkt und Zeichen, die gleich bleiben, übernehmen
        CP      (HL)
        JR      NZ,NOU_FRAC
        CALL    USING_PUTINC
        INC     DE
        CP      0Dh
        JR      NZ,NOD_REST
        RET
NOD_SPACE:  LD      A,20h
        CALL    USING_PUTINC
        JR      NOU_INTFILL
NOU_FRAC:
        LD      BC,(USG_FRACDIG)        ; Nachkommastellen
        LD      A,C
        OR      A
        CALL    NZ,USING_DIGS
        LD      A,(USG_SUFLEN)          ; Suffix anhängen bzw. 0Dh
        OR      A
        JR      NZ,NOU_SUFFIX
        LD      A,0Dh
        LD      (IX+0),A
        RET
NOU_SUFFIX:
        LD      C,A
        LD      B,00h
        LD      HL,(USG_SUFPTR)
        PUSH    IX
        POP     DE
        LDIR
        RET
; <- aufgerufen von 5395h
NOU_OVERFLOW:
        NEG
        LD      B,A
        LD      A,C
        SUB     B
        LD      C,A
        LD      A,25h                   ; "%"
        CALL    USING_PUT
        CALL    USING_SIGN
NOV_LP:  LD      A,(DE)
        CALL    USING_PUT
        INC     DE
        DJNZ    NOV_LP
        POP     HL
        JP      NOU_DIGITS
;  USING_MATCH – Zeichen (DE) in der Liste ab HL (Ende 00h) suchen: Z = gefunden.
;  Listen: Formatzeichen "#*X,." 0Dh, dann Vorzeichen/Währung "+-$" 91h "@",
;  dann Ziffernzeichen "#*".
; <- aufgerufen von 52AAh, 52C8h, 52E6h
USING_MATCH:
        PUSH    BC
UMA_LP:  LD      A,(DE)                 ; Zeichen mit dem Listeneintrag vergleichen
        CP      (HL)
        INC     HL
        JR      Z,UMA_RET               ; gefunden: Z
        EX      AF,AF'
        LD      A,(HL)                  ; Listenende (00h): NZ
        OR      A
        JR      NZ,UMA_LP
        EX      AF,AF'
UMA_RET:  POP     BC
        RET
;  Zeichenlisten für USING_MATCH (je bis 00h; USING_CHARS schließt die
;  folgenden mit ein)
USING_CHARS:
        DEFB    "#*X,.",0Dh             ; Formatzeichen
USING_SIGNS:
        DEFB    "+-$",91h,"@",00h       ; Vorzeichen und Währung (91h = £)
USING_DIGCH:
        DEFB    "#*",00h                ; Ziffernstellen
;  USING_DIGS – C Stellen nach der Schablone (HL) aus NUMBUF (DE) ausgeben;
;  "," "." übernehmen, "X" als Leerzeichen, fehlende Ziffern als "0".
;  Ist das Byte 002Dh (Monitor-Bereich) <> 0, wird die Ziffer 0 als
;  Buchstabe "O" ausgegeben. Laut Handbuch (2.4.1) mit POKE $002D,1
;  einzuschalten, POKE $002D,0 schaltet zurück; das BASIC setzt 002Dh nie.
; <- aufgerufen von 53CFh, 53ECh
USING_DIGS:
        LD      B,C
UDG_LOOP:  LD      A,(002Dh)            ; Byte 002Dh <> 0: Null als "O" (Flag nach F')
        OR      A
        EX      AF,AF'
UDG_TPL:  LD      A,(HL)                ; Schablonenzeichen
        CP      2Ch
        JR      Z,UDG_COPY              ; "," und "." übernehmen
        CP      2Eh
        JR      Z,UDG_COPY
        CP      58h
        JR      Z,UDG_X                 ; "X": Leerzeichen
        LD      A,(DE)                  ; nächste Ziffer der Zahl, nach dem Ende "0"
        CP      0Dh
        JR      NZ,UDG_ZERO
        LD      A,30h
UDG_ZERO:  CP      30h
        JR      NZ,UDG_PUT
        EX      AF,AF'                  ; "0" -> "O", wenn 002Dh <> 0
        LD      A,4Fh
        JR      NZ,UDG_PUT
        EX      AF,AF'
UDG_PUT:  CALL    USING_PUTINC
        LD      A,(DE)                  ; am Textende stehen bleiben
        CP      0Dh
        JR      Z,UDG_NEXT
        INC     DE
UDG_NEXT:  DJNZ    UDG_LOOP
        RET
UDG_X:  LD      A,20h
UDG_COPY:  CALL    USING_PUTINC
        JR      UDG_TPL
;  USING_SIGN – Währungszeichen (USG_CURR) und Vorzeichen ausgeben: "-" immer,
;  "+" nur bei USG_SIGN = "+", sonst Leerzeichen bei USG_SIGN = "-".
; <- aufgerufen von 53CCh, 5412h
USING_SIGN:
        LD      A,(USG_CURR)            ; Währungszeichen
        OR      A
        CALL    NZ,USING_PUT
        LD      DE,NUMBUF               ; Vorzeichen aus NUMBUF
        LD      A,(DE)
        INC     DE
        CP      20h                     ; "-" immer ausgeben
        JR      NZ,USS_PUT
        LD      A,(USG_SIGN)            ; " ": nur bei "+"/"-" in der Schablone
        OR      A
        RET     Z
        CP      2Dh                     ; bei "-": Leerzeichen statt "+"
        JR      NZ,USS_PUT
        LD      A,20h
USS_PUT:  CALL    USING_PUT
        RET
;  USING_PUTINC: HL + 1, dann USING_PUT: A nach (IX), IX + 1.
; <- aufgerufen von 53B6h, 53C6h, 53D6h, 53E1h, 5461h, 546Fh
USING_PUTINC:
        INC     HL
; <- aufgerufen von 52AFh, 52EBh, 5317h, 540Fh, 5416h, 5478h, 548Fh
USING_PUT:
        LD      (IX+0),A
        INC     IX
        RET
USG_PRELEN:
        DEFB    00h
USG_SUFLEN:
        DEFB    00h
USG_SUFPTR:
        DEFB    00h,00h
USG_CURR:
        DEFB    00h
USG_SIGN:
        DEFB    00h
USG_POINT:
        DEFB    00h,00h
USG_FILL:
        DEFB    00h
USG_INTDIG:
        DEFB    00h,00h
USG_FRACDIG:
        DEFB    00h,00h
;  GR_POINT – POINT(x,y): Pixel in beiden Grafikebenen testen, A = 0-3
;  (Bit 1 Ebene 1, Bit 0 Ebene 0; FFh außerhalb des Bildes).
; <- aufgerufen von 5A0Eh
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
; <- aufgerufen von 54AFh, 54BAh
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
; <- aufgerufen von 57C2h
GR_RESCUR:
        LD      DE,(GR_X)
        LD      HL,(GR_Y)
GR_RESPIX:
        PUSH    AF
        LD      A,86h
        JR      GR_PIXOP2
;  Pixel setzen/löschen: GR_SETPIX (DE = x, HL = y) bzw. GR_RESPIX;
;  GR_SETCUR/GR_RESCUR an der Grafikposition GR_X/GR_Y. GR_TESTPIX testet.
; <- aufgerufen von 57C5h
GR_SETCUR:
        LD      DE,(GR_X)
        LD      HL,(GR_Y)
; <- aufgerufen von 5635h
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
; <- aufgerufen von 54C6h, 54E9h
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
; <- aufgerufen von 5509h
GR_ADDR:
        LD      A,E
        RLA
        RLA
        RLA
        AND     38h
        LD      B,A
; <- aufgerufen von 56CAh
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
;  aus GRL_PIXCALL (Bresenham). Koordinaten werden intern um 3BDAh
;  verschoben (GR_BIAS), damit Differenzen positiv bleiben; Schrittrichtung
;  über selbst eingesetzte INC/DEC (GRL_INCX/GRL_INCY).
; <- aufgerufen von 5674h
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
; <- aufgerufen von 55F1h
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
; <- aufgerufen von 558Ah, 5593h, 559Ch
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
; <- aufgerufen von 5562h, 5570h
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
; <- aufgerufen von 55DDh, 55E3h
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
; <- aufgerufen von 5548h
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
; <- aufgerufen von 5828h
LINE_SET:
        LD      HL,GR_SETPIX
        JR      LINE_GO
; <- aufgerufen von 5825h
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
; <- aufgerufen von 5998h
GR_FILL:
        LD      A,0FFh
        LD      (GR_FILLVAL+1),A
        JR      GR_FILLDO
; <- aufgerufen von 598Dh
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
; <- aufgerufen von 5904h
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
; <- aufgerufen von 56F9h, 5709h
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
; <- aufgerufen von 56FFh, 5719h, 5726h
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
D57B3:  DEFB    2Ch                     ; Inline-Parameter ','
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
; <- aufgerufen von 590Ah
CHK_X:  PUSH    HL
        LD      HL,013Fh
CHK_LIMIT:
        XOR     A
        SBC     HL,DE
        JP      C,ERR_03
        POP     HL
        RET
; <- aufgerufen von 5914h
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
        LD      BC,INBUF
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
D5802:  DEFB    2Ch                     ; Inline-Parameter ','
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
; <- aufgerufen von 57FCh, 5806h
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
; <- aufgerufen von 58ACh
ST_CONSOLE:
        CALL    CHRGET
        JP      Z,NEXTSTMT_HL
        CALL    SKIPCOMMA
        CALL    CHK_CHR_ALT
D584F:  DEFB    53h                     ; Inline-Parameter 'S'
D5850:  DEFW    CONS_COLS
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
; <- aufgerufen von 5858h, 5862h, 58E6h
CHK_ROW:
        OR      A
        JR      Z,CONS_ERR
        CP      19h
        RET     C
CONS_ERR:
        JP      ERR_03
CONS_COLS:
        CALL    CHK_CHR_ALT
D5884:  DEFB    43h                     ; Inline-Parameter 'C'
D5885:  DEFW    CONS_REV
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
CONS_REV:
        CALL    CHK_CHR_ALT
D589F:  DEFB    52h                     ; Inline-Parameter 'R'
D58A0:  DEFW    CONS_NORM
        LD      A,(PPI_A_COPY)
        RES     4,A
CONS_SETPPI:
        LD      (PPI_A_COPY),A
        OUT     (PPI_A),A
        JP      ST_CONSOLE
CONS_NORM:
        CALL    SYNCHK
D58B2:  DEFB    4Eh                     ; Inline-Parameter 'N'
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
D58C7:  DEFB    2Dh                     ; Inline-Parameter '-'
D58C8:  DEFW    PAT_UP
        PUSH    HL
        LD      HL,0009h                ; Befehlsbytes 09h,00h = ADD HL,BC / NOP
        LD      A,27h                   ; Schrittweite 39 statt 41 (PAT_STRIDE)
        JR      PAT_PATCH
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
D5930:  DEFB    49h                     ; Inline-Parameter 'I'
D5931:  DEFW    GRAPH_OUTARG
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
GRAPH_OUTARG:
        CALL    CHK_CHR_ALT
D5949:  DEFB    4Fh                     ; Inline-Parameter 'O'
D594A:  DEFW    GRAPH_C
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
GRAPH_C:
        CALL    CHK_CHR_ALT
D5989:  DEFB    43h                     ; Inline-Parameter 'C'
D598A:  DEFW    GRAPH_F
        PUSH    HL
        CALL    GR_CLEAR
GRAPH_CF_RET:
        POP     HL
        JR      GRAPH_SET
GRAPH_F:
        CALL    SYNCHK
D5996:  DEFB    46h                     ; Inline-Parameter 'F'
        PUSH    HL
        CALL    GR_FILL
        JR      GRAPH_CF_RET
;  CSRV / CSRH – Cursorzeile bzw. -spalte des Textbildschirms.
;  POSV / POSH – Grafikposition y bzw. x.
FN_CSR: CALL    CHK_CHR_ALT
D59A0:  DEFB    56h                     ; Inline-Parameter 'V'
D59A1:  DEFW    CSR_H
        LD      A,(CSR_Y)
CSR_RET:
        LD      D,00h
        LD      E,A
POS_RET:
        PUSH    HL
; >>> SB-6610: ohne Gegenstück in SB-6511
        EX      DE,HL
        JP      INT_RET
CSR_H:  CALL    SYNCHK
        DEFB    48h                     ; Inline-Parameter 'H'
        LD      A,(CSR_XY)
        JR      CSR_RET
FN_POS: CALL    CHK_CHR_ALT
        DEFB    56h                     ; Inline-Parameter 'V'
        DEFW    POS_H                   ; Inline-Parameter
        LD      DE,(GR_Y)
        JR      POS_RET
POS_H:  CALL    SYNCHK
        DEFB    48h                     ; Inline-Parameter 'H'
        LD      DE,(GR_X)
        JR      POS_RET
;  CHARACTER$(x,y) – Zeichen an Textposition x (kleiner als die
;  Zeilenbreite), y (0-24) als String; sonst Fehler 3.
FN_CHARACTER:
        CALL    EVAL_INT
        LD      A,(ADD_WIDTH+1)
        LD      (CHR_MAXX+1),A
        LD      (CHR_WIDTH+1),A
        LD      A,E
CHR_MAXX:
        CP      0FFh
CHR_ERR:
        JP      NC,ERR_03
        PUSH    AF
        CALL    SYNCHK
        DEFB    2Ch                     ; Inline-Parameter ','
        CALL    EVAL_BYTE
        CALL    SYNCHK
        DEFB    29h                     ; Inline-Parameter ')'
        LD      A,E
        CP      19h
        JR      NC,CHR_ERR
        POP     AF
        LD      C,A
        LD      B,E
        INC     B
        PUSH    HL
        LD      HL,0D000h
        LD      D,00h
CHR_WIDTH:
        LD      E,0FFh
        XOR     A
        SBC     HL,DE
CHR_MUL:
        ADD     HL,DE
        DJNZ    CHR_MUL
        ADD     HL,BC
        CALL    VRAM_RD
        POP     HL
        LD      BC,0001h
        JP      STR_FILL
;  POINT_GET – POINT(x,y) über GR_POINT, Ergebnis in A; rettet BC.
;  Nachträgliche Korrektur (ältere Fassung: CALL GR_POINT direkt).
; <- aufgerufen von 2AEEh
POINT_GET:
        PUSH    BC
        CALL    GR_POINT
        POP     HL
        RET
;  Mit "pasmo --equ NOJUNK=1" fällt der Bereich weg; der Platz steht dann
;  am Ende des Codes frei (FILL_FREE), z.B. für neue Befehle.
        IF      NOT DEFINED NOJUNK
;  5A13h-5CFFh: nicht erreicht, Speicherreste aus der Entwicklung.
;  5A13h-5B19h: Kopie von ST_GRAPH ... FN_CHARACTER (heute 5906h-5A12h)
;  aus einem älteren Stand, in dem dieser Code 10Dh weiter hinten lag; die
;  Adressen darin gelten für jenen Stand (z.B. CALL 1987h = damals
;  CHK_CHR_ALT, heute 190Dh). Bei der älteren Fassung von SB-6610 auf disketten/DISK26
;  steht hier dasselbe.
        DEFB    0BAh,57h,0CDh,7Bh,20h,0CDh,0D6h,58h
        DEFB    0D5h,0CDh,0C9h,4Eh,0CDh,7Bh,20h,0CDh
        DEFB    0E2h,58h,0EDh,53h,0AFh,58h,0D1h,0EDh
        DEFB    53h,0ADh,58h,0C3h,2Ah,1Dh,00h,00h
        DEFB    00h,0CDh,0C9h,4Eh,0FEh,0Dh,28h,44h
        DEFB    0CDh,87h,19h,49h,54h,5Ah,0CDh,5Ch
        DEFB    19h,0D2h,83h,14h,23h,0E6h,0Fh,3Dh
        DEFB    0FEh,02h,30h,0F5h,32h,32h,5Ah,18h
        DEFB    2Bh,0CDh,87h,19h,4Fh,94h,5Ah,0CDh
        DEFB    5Ch,19h,38h,03h,3Eh,00h,2Bh,23h
        DEFB    0E6h,0Fh,0FEh,03h,30h,0DBh,47h,0CDh
        DEFB    5Ch,19h,38h,03h,3Eh,00h,2Bh,23h
        DEFB    0E6h,0Fh,0FEh,03h,30h,0CBh,0B0h,0CBh
        DEFB    27h,32h,33h,5Ah,3Ah,32h,5Ah,47h
        DEFB    3Ah,33h,5Ah,0B0h,32h,31h,5Ah,0D3h
        DEFB    0F4h,0CDh,2Dh,1Bh,20h,0A3h,0C3h,2Ah
        DEFB    1Dh,0CDh,87h,19h,43h,0A1h,5Ah,0E5h
        DEFB    0CDh,9Ah,57h,0E1h,18h,0DEh,0CDh,95h
        DEFB    19h,46h,0E5h,0CDh,93h,57h,18h,0F3h
        DEFB    0CDh,87h,19h,56h,0BBh,5Ah,3Ah,0D2h
        DEFB    11h,16h,00h,5Fh,0E5h,0C3h,50h,2Ah
        DEFB    0CDh,95h,19h,48h,3Ah,0D1h,11h,18h
        DEFB    0F0h,0CDh,87h,19h,56h,0D0h,5Ah,0EDh
        DEFB    5Bh,0AFh,58h,18h,0E7h,0CDh,95h,19h
        DEFB    48h,0EDh,5Bh,0ADh,58h,18h,0DDh,0CDh
        DEFB    7Bh,20h,3Ah,6Eh,07h,32h,0E8h,5Ah
        DEFB    32h,08h,5Bh,7Bh,0FEh,0FFh,0D2h,83h
        DEFB    14h,0F5h,0CDh,95h,19h,2Ch,0CDh,9Ah
        DEFB    20h,0CDh,95h,19h,29h,7Bh,0FEh,19h
        DEFB    30h,0ECh,0F1h,4Fh,43h,04h,0E5h,21h
        DEFB    00h,0D0h,16h,00h,1Eh,0FFh,0AFh,0EDh
        DEFB    52h,19h,10h,0FDh,09h,0CDh,3Eh,0Ch
        DEFB    0E1h,01h,01h,00h,0C3h,98h,2Ah
;  5B1Ah-5BEFh: RAM-Muster (16 Bytes 00h/FFh im Wechsel), 5BF0h-5CFFh:
;  Kopie des Monitor-Arbeitsspeichers ab 1050h.
        DEFB    00h,00h,00h,00h,00h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0020h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        ENDIF
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
; <- aufgerufen von 4869h
FD_MOTOR_OFF:
        JP      FD_RESET
;  FD_SELECT – Motor einschalten (beim ersten Mal mit Anlaufzeit,
;  FD_MOTORON), Laufwerk (IX+0) wählen (Port DCh: Bit 7 Motor, Bit 2
;  Auswahl, Bit 0-1 Laufwerk), auf "bereit" warten (sonst Fehler 50);
;  beim ersten Zugriff auf das Laufwerk RESTORE (Spur 0).
; <- aufgerufen von 5E73h, 5EF9h
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
; <- aufgerufen von 5D0Dh
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
; <- aufgerufen von 5DC1h, 5E14h, 5F11h
FD_SEEK:
        LD      A,1Bh
        CALL    FD_CMDWAIT
        AND     99h
        RET
; <- aufgerufen von 5D06h, 5FA5h
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
; <- aufgerufen von 5D39h, 5EBEh, 5F6Ch
FD_RESTORE:
        LD      A,0Bh
        CALL    FD_CMDWAIT
        AND     85h
        XOR     04h
        RET     Z
        JP      FD_ERROR
;  FD_CMDWAIT – Kommando A ausgeben (FD_LASTCMD), auf "nicht beschäftigt"
;  warten, Status nach FD_STATUS.
; <- aufgerufen von 5D57h, 5D75h
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
; <- aufgerufen von 5D8Bh, 5EDFh, 5EEDh
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
; <- aufgerufen von 5D00h
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
; <- aufgerufen von 5D03h
FDW_START:
        CALL    FD_PREP
; <- aufgerufen von 5E5Ch
FDW_RETRY:
        CALL    FD_SETUP
; <- aufgerufen von 5E62h
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
        AND     0FFh
        JR      NZ,FDW_ERR
        CALL    FD_NEXTSEC
        JR      NZ,FDW_NEXTTRK
        CALL    FD_VERIFY
        JR      NC,FD_DONE
; <- aufgerufen von 5E17h
FDW_ERR:
        CALL    FD_RETRY
        JP      FDW_RETRY
FDW_NEXTTRK:
        LD      A,(IX+7)
        JP      FDW_TRACK
; <- aufgerufen von 5DFEh
FD_DONE:
        LD      A,80h
        OUT     (FDD_SEL),A
        RET
;  FD_PREP – Startspur/-sektor berechnen, 10 Versuche einstellen.
;  FD_SETUP – Laufwerk wählen, D = Anzahl Sektoren, HL = Speicheradresse.
; <- aufgerufen von 5DB8h, 5E0Bh
FD_PREP:
        CALL    FD_LOG2PHYS
        LD      A,0Ah
        LD      (FD_RETRIES),A
        RET
; <- aufgerufen von 5DBBh, 5E0Eh
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
; <- aufgerufen von 5DBEh, 5E11h, 5F0Eh
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
; <- aufgerufen von 5DC6h, 5E1Ah
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
; <- aufgerufen von 5E06h, 5E59h
FD_RETRY:
        LD      A,(FD_RETRIES)
        DEC     A
        LD      (FD_RETRIES),A
        JP      Z,FD_ERROR
        CALL    FD_RESTORE
        RET
;  FD_NEXTSEC – nach Sektor 16 auf Sektor 1 der nächsten Spur; NZ, wenn
;  noch Sektoren fehlen (D).
; <- aufgerufen von 5DFBh, 5E4Fh
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
; <- aufgerufen von 5DCCh, 5E20h, 5F25h
FD_CMDRW:
        LD      (FD_LASTCMD),A
        CPL
        OUT     (FDC_CMD),A
        LD      A,30h                   ; '0'
        LD      (FD_WB_JR),A
        CALL    FD_WAITBUSY
        RET
;  FD_FORCEINT – FORCE INTERRUPT (D8h) und auf Ende warten.
; <- aufgerufen von 5DEDh, 5E41h, 5F42h
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
; <- aufgerufen von 5E54h
FD_VERIFY:
        CALL    FD_LOG2PHYS
        LD      A,02h
        LD      (FD_VRETRIES),A
; <- aufgerufen von 5F6Fh
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
; <- aufgerufen von 5F5Eh
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
; <- aufgerufen von 5D7Dh, 5EBBh
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
; <- aufgerufen von 5D41h, 5DB5h
FD_ERRA:
        LD      (IY-1),A
        CALL    FD_RESET
        JP      (IY)
;  FD_LOG2PHYS – logischen Sektor (IX+1/+2) in Spur (= Sektor / 16) und
;  Sektor (= Rest + 1) zerlegen (IX+9/+10).
; <- aufgerufen von 5E6Ah, 5EF1h
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
;  1FE1h).
; <- aufgerufen von 5D9Ah
FD_DLY_S:
        PUSH    DE
        LD      DE,000Fh
        JP      FD_DLY_LP
; <- aufgerufen von 5D5Dh
FD_DLY_M:
        PUSH    DE
        LD      DE,00A0h
        JP      FD_DLY_LP
; <- aufgerufen von 5D1Bh, 5D4Ah, 5D8Eh
FD_DLY_L:
        PUSH    DE
        LD      DE,2026h                ; Wartezeit (Schleifenzähler, keine Adresse)
; <- aufgerufen von 5FCBh, 5FD2h
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
; >>> SB-6610: ohne Gegenstück in SB-6511
        DEFB    0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
;  AREA_RESIZE_CLR – Nachtrag am Ende des Codes: AREA_RESIZE, dann die zwei
;  Wörter hinter dem Zeiger (6680h) auf 0 setzen. Nachträgliche Korrektur
;  (ältere Fassung: CALL AREA_RESIZE direkt).
; <- aufgerufen von 50DEh
AREA_RESIZE_CLR:
        CALL    AREA_RESIZE
        LD      HL,(6680h)
        INC     HL
        INC     HL
        LD      (HL),00h
        INC     HL
        LD      (HL),00h
        RET
        DEFB    00h,00h

; ==============================================================================
;  ENDE DES CODES
; ==============================================================================
;  6000h-6FFFh: zur Laufzeit Arbeitsbereich des BASIC. Im Abbild stehen
;  Speicherreste: RAM-Muster (16 Bytes 00h/FFh im Wechsel) und Bruchstücke
;  von Assembler-Quelltext aus der Entwicklung bei Sharp.
        IF      $ > 6000h
        .ERROR  Code reicht über 6000h (Arbeitsbereich); mit NOJUNK übersetzen oder kürzen
        ENDIF
FILL_FREE:
        DEFS    6000h-$,00h             ; frei bis 6000h (im Original 0 Bytes)
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0020h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0020h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0020h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0020h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0020h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0020h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFS    0010h,00h
        DEFS    0010h,0FFh
        DEFB    45h,0Dh,3Bh,0Dh,47h,52h,44h,3Ah
        DEFB    "CALL NDE",0Dh
        DEFB    "PUSH HL",0Dh
        DEFB    "XOR A",0Dh
        DEFB    "LD HL,319",0Dh
        DEFB    "SBC HL,DE",0Dh
        DEFB    "GRD1:JP C,ER3",0Dh
        DEFB    "POP HL",0Dh
        DEFB    "PUSH DE",0Dh
        DEFB    "CALL SKPC",0Dh
        DEFB    "CALL NDE",0Dh
        DEFB    "CALL FRS9",0Dh
        DEFB    "PUSH HL",0Dh
        DEFB    "XOR A",0Dh
        DEFB    "LD HL,199",0Dh
        DEFB    "SBC HL,DE",0Dh
        DEFB    "JR C,GRD1",0Dh
        DEFB    "POP BC",0Dh
        DEFB    "EX DE,HL",0Dh
        DEFB    "POP DE",0Dh
        DEFB    "CALL POINTR",0Dh
        DEFB    "JP ASC3+1",0Dh
        DEFB    3Bh,0Dh,53h,49h,5Ah,45h,3Ah,50h
        DEFB    "USH HL",0Dh
        DEFB    "CALL LVBY0",0Dh
        DEFB    "SIZE1:ENT",0Dh
        DEFB    "CALL WASC",0Dh
        DEFB    "EX DE,HL",0Dh
        DEFB    "CALL AEXP",0Dh
        DEFB    "POP HL",0Dh
        DEFB    "LD A,(HL)",0Dh
        DEFB    52h,45h,54h,0Dh,3Bh,0Dh,3Bh,20h
        DEFB    " ERL",0Dh
        DEFB    3Bh,0Dh,45h,52h,4Ch,3Ah,4Ch,44h
        DEFB    " DE,(ERD3)",0Dh
        DEFB    "JR ERN1",0Dh
        DEFB    3Bh,0Dh,3Bh,20h,20h,45h,52h,4Eh
        DEFB    0Dh,3Bh,0Dh,45h,52h,4Eh,3Ah,4Ch
        DEFB    "D DE,(ERD1)",0Dh
        DEFB    "ERN1:PUSH HL",0Dh
        DEFB    "LD A,(ERD)",0Dh
        DEFB    "LD HL,0",0Dh
        DEFB    "CP 2",0Dh
        DEFB    "JR NZ,SIZE1",0Dh
        DEFB    "ERN2:EX DE,HL",0Dh
        DEFB    "JR SIZE1",0Dh
        DEFB    3Bh,0Dh,3Bh,20h,20h,42h,59h,45h
        DEFB    0Dh,3Bh,0Dh,42h,59h,45h,3Ah,45h
        DEFB    4Eh,54h,0Dh,4Ah,50h,20h,53h,54h
        DEFB    "MONI",0Dh
        DEFB    3Bh,0Dh,42h,4Fh,4Fh,54h,3Ah,45h
        DEFB    4Eh,54h,0Dh,4Ch,44h,20h,41h,2Ch
        DEFB    30h,36h,48h,0Dh,4Fh,55h,54h,20h
        DEFB    "(E3H),A",0Dh
        DEFB    3Bh,0Dh,43h,55h,52h,4Ch,3Ah,45h
        DEFB    4Eh,54h,0Dh,43h,41h,4Ch,4Ch,20h
        DEFB    "NDEX",0Dh
        DEFB    "LD A,(CK80)",0Dh
        DEFB    "LD (CURL1+1),A",0Dh
        DEFB    "LD A,E",0Dh
        DEFB    "CURL1:CP FFH",0Dh
        DEFB    "JP NC,ER3",0Dh
        DEFB    "PUSH AF",0Dh
        DEFB    "CALL TESTX",0Dh
        DEFB    "DEFB 2CH ;,",0Dh
        DEFB    "CALL NDEX",0Dh
        DEFB    "LD A,E",0Dh
        DEFB    "CP 25",0Dh
        DEFB    "JR NC,CURL1+2",0Dh
        DEFB    "EX DE,HL",0Dh
        DEFB    "LD H,L",0Dh
        DEFB    "POP AF",0Dh
        DEFB    "LD L,A",0Dh
        DEFB    "LD (DSPXY),HL",0Dh
        DEFB    "LD (DPRNT),A",0Dh
        DEFB    "EX DE,HL",0Dh
        DEFB    "JP PED1",0Dh
        DEFB    "SKP H",0Dh
        DEFB    3Bh,0Dh,3Bh,20h,20h,47h,45h,54h
        DEFB    0Dh,3Bh,0Dh,44h,45h,46h,53h,20h
        DEFB    32h,0Dh,47h,45h,54h,3Ah,45h,4Eh
        DEFB    54h,0Dh,43h,41h,4Ch,4Ch,20h,53h
        DEFB    "VARX",0Dh
        DEFB    "CALL LVAR",0Dh
        DEFB    "LD (RJOB),HL",0Dh
        DEFB    43h
;  7000h-7DFFh: BFh-Füllung bis zum Ende des Abbilds (wie SB-6511)
        DEFS    0E00h,0BFh

        END

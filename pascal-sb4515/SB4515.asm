;==============================================================================
;  SHARP MZ-80B  –  PASCAL-Interpreter SB-4515
;==============================================================================
;  Quelle : Datei "PASCAL" (FDOS-Typ OBJ, 25069 Bytes) von DISK18
;           (disketten-2/DISK18/PASCAL.OBJ), (C) 1981 SHARP Corp.
;           Speicherabbild ab 0000h, also die Kassettenfassung: vorn steht
;           der Monitor SB-1511, dahinter der Interpreter.
;  Handbuch: Sharp_MZ-80B_PASCAL_Language_Manual_SB4515.pdf
;
;  Reassemblierbar mit pasmo; ergibt PASCAL.OBJ bytegleich (make check).
;  tools/test_sb4515_run.py lässt den Interpreter im Emulator (z88dk-ticks)
;  Programme eingeben, prüfen und ausführen und vergleicht die Ausgabe
;  (Gleitkommafunktionen mit Python nachgerechnet, Fehlermeldungen).
;
;  Der Interpreterteil ist verschiebbar: alle Adressen stehen als Symbole,
;  echte Zahlen als Zahl (Ausnahmen in sb4515/reloc_allow.txt). make
;  reloc-check fügt an mehreren Stellen Bytes ein und lässt die verschobenen
;  Fassungen im Emulator laufen. Der Monitor (0000h-129Fh) ist fest.
;  Erzeugt von tools/dis4515.py aus sb4515/sb4515_cfg.py. Änderungen
;  bitte in der Konfiguration machen und die Quelle neu erzeugen.
;
;  Speicheraufteilung
;  ------------------
;  0000h-129Fh  Monitor SB-1511 (Quelle aus SB1511.asm). Gegenüber
;               SB1511.bin geändert:
;               - GOOUT (00AEh): JP PAS_BOOT statt JP ST; PAS_INIT macht
;                 daraus beim Start "LD BC,12FDh", danach führt GOOUT
;                 wieder zur Kommandoschleife ST (Kommando Q).
;               - Speicherreste in FILL105F, FILL10FE und IBU24.
;  12A0h-12FCh  FFh-Füllung
;  12FDh        PAS_BOOT: JP PAS_INIT
;  1300h-614Ch  Interpreter: Editor, Tokenizer, Prüfung, Ausführung,
;               Gleitkomma, Grafik, Kassette, Drucker
;  614Bh-...    Programmtext (TXT_START). Darin liegen beim Laden noch
;               FKEY_DEF (Vorgaben der Funktionstasten) und PAS_INIT; beide
;               werden nur einmal beim Start gebraucht und dann vom
;               Programmtext überschrieben.
;  RAM-Ende     Stapel (STACK_TOP), Puffer (WORKBUF, INBUF); PAS_START
;               ermittelt das RAM-Ende mit einem Speichertest.
;
;  Ablauf
;  ------
;  PAS_INIT kopiert FKEY_DEF in die Funktionstastenbelegung FARE (1200h),
;  entschärft den Sprung in GOOUT und springt nach PAS_START. PAS_START
;  sucht das RAM-Ende, gibt die Kopfmeldung aus (PAS_NEW) und landet in
;  CMD_LOOP. CMD_LOOP liest eine Zeile: "#" schaltet die Zeilennummern im
;  Listing um, "$" das Einrücken, eine Ziffer leitet eine Programmzeile ein
;  (PCMD_LINENO), ein Buchstabe A-Z wählt über CMD_TAB ein Editorkommando
;  (PCMD_A ... PCMD_Z, unbelegte Buchstaben -> ERR_40).
;
;  Programmzeilen werden beim Eingeben in Token umgesetzt (TOKENIZE,
;  KW_FIND, Schlüsselworttabelle KWTAB, Token 60h-E1h). Die Ausführung
;  (PCMD_G) läuft in zwei Schritten über den Tokentext: zuerst eine
;  Prüfung von Deklarationen und Syntax (Tabellen SYN_TAB..., Sprung über
;  TAB_JUMP), dann die eigentliche Ausführung (Tabellen RUN_TAB..., Sprung
;  über RUN_JUMP). Der Prüflauf trägt dabei die Adressen der Variablen und
;  die Sprungziele von THEN/ELSE/DO direkt in den Tokentext ein, sodass die
;  Ausführung nicht mehr suchen muss. RT_SP ist der Zeiger des
;  Auswertungsstapels zur Laufzeit; jeder Eintrag beginnt mit dem Typbyte
;  (00h REAL, 01h INTEGER, 02h CHAR, 03h BOOLEAN).
;
;  Fehler: ERR_01 ... ERR_55 laden die Fehlernummer (BCD) nach A und laufen
;  über "DEFB 01h"-Tricks zu ERROR, das "*Err nn *" und ggf. die Zeile
;  ausgibt und nach PAS_READY zurückkehrt. Die Texte stehen im Handbuch
;  (Error message table, S. 137) und hier als Kommentar an ERR_nn.
;
;  Namen
;  -----
;  Monitornamen wie in SB1511.asm. Alle Namen hier stammen aus der
;  Analyse (die Datei enthält keine Symbole). PCMD_x sind die
;  Editorkommandos, SYN_x die Prüfung und RUN_x die Ausführung zu einem
;  Schlüsselwort (aus den Sprungtabellen benannt), ERR_nn die Fehler,
;  F... die Gleitkommaroutinen. Lnnnn (Code) und Dnnnn (Daten) sind
;  automatisch erzeugte Namen für Sprungziele innerhalb von Routinen und
;  für Stellen, die nicht näher untersucht sind. "vermutlich" kennzeichnet
;  Deutungen, die nicht im Einzelnen nachgeprüft sind. "Operand wird zur
;  Laufzeit gesetzt" kennzeichnet selbstmodifizierenden Code; solche Ziele
;  erscheinen als Name+Offset.
;
;  Code und Daten wurden ab den Einsprüngen und Sprungtabellen verfolgt.
;  Codestücke, die nur über zur Laufzeit gesetzte Sprünge erreicht werden,
;  sind anhand ihres Aufbaus als Code erkannt worden; alles übrige steht
;  als DEFB/DEFW/DEFS da.
;==============================================================================


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

_PUSHR    EQU    04h     ; Konstante aus MONEQU
_DI       EQU    05h     ; Konstante aus MONEQU
FARE      EQU    1200h   ; Konstante aus MONEQU
FAREN     EQU    0A0h    ; Konstante aus MONEQU
FKEYN     EQU    14h     ; Konstante aus MONEQU
FKMAX     EQU    12A0h   ; Konstante aus MONEQU
SCRN      EQU    0D000h  ; Konstante aus MONEQU

ASCI      EQU    0583h   ; = ASC
NAME      EQU    1181h   ; = IBU1
SIZE      EQU    1192h   ; = IBU18
IBU20     EQU    1194h   ; = DTADR
IBU22     EQU    1196h   ; = EXADR

Z80KT     EQU    DLY_BITSET+1 ; Operand eines Befehls (selbstmodifizierend)
CH3979    EQU    COLCHK_MAX+1 ; Operand eines Befehls (selbstmodifizierend)
CH4080    EQU    SCR_WIDTH+1 ; Operand eines Befehls (selbstmodifizierend)

        ORG     0000h


; ==============================================================================
;  RST-VEKTOREN UND MONITOR-VARIABLEN
; ==============================================================================
;  Zwischen den JP-Befehlen liegen Variablen (SCROST/SCREND = Rollbereich,
;  REPTCT, SLOW, GATESI, SELO0 ...).
; <- aufgerufen von 0E1Bh
RESET:  JP      COLD
;  Belegung der Lücken (aus der Verwendung):
;    000Bh/000Ch SCROST/SCREND  Rollbereich: erste Zeile + 1 / letzte Zeile
;    000Dh REPTCT    Abfragen je Schritt der Tastenwiederholung (40h)
;    000Eh REPTCT+1  Schritte bis zur ersten Wiederholung (0Ch)
;    000Fh SLOW      Verzögerung je gerollter Zeile, solange die Taste in
;                    Zeile 0Bh Bit 2 gedrückt ist (SCRL_KEYCHK)
;    0013h/0014h KEYPOS  zuletzt gedrückte Taste (Spaltenbit, Zeile)
;    0015h CLICKOFF  0 = Tastenklick (BELL) bei jeder Taste in GETL
;    0016h TEMPO     MUSIC-Tempo (XTEMP)
;  GAP03, GAP1B, GAP23, GAP2B, GAP33, GATESI und SELO0 werden von keinem
;  gefundenen Codepfad benutzt.
GAP03:  DEFB    00h,00h,00h,00h,00h
        JP      REGDUMP
SCROST: DEFB    01h
SCREND: DEFB    18h
REPTCT: DEFB    40h,0Ch
SLOW:   DEFB    80h
        JP      REGDUMP
KEYPOS: DEFB    00h,00h
CLICKOFF:
        DEFB    0FFh
TEMPO:  DEFB    00h
GATESI: DEFB    00h
        JP      REGDUMP
GAP1B:  DEFB    00h,00h,00h,00h,00h

; ------------------------------------------------------------------------------
;  RST 20h -> PUSHR: Register sichern, beim Rücksprung automatisch zurückholen
; ------------------------------------------------------------------------------
; <- aufgerufen von 021Dh, 024Eh, 025Fh, 027Dh, 0286h, 046Ah, 04C2h, 04D6h (+21 weitere)
RST20:  JP      PUSHR                   ; RST 20h
GAP23:  DEFB    00h,00h,00h,00h,00h

; ------------------------------------------------------------------------------
;  RST 28h -> DI_: restliche Routine mit gesperrten Interrupts ausführen
; ------------------------------------------------------------------------------
; <- aufgerufen von 021Eh, 024Fh, 0260h, 027Eh, 0287h, 06C4h, 0747h, 086Dh (+11 weitere)
RST28:  JP      DI_                     ; RST 28h
GAP2B:  DEFB    00h,00h
SELO0:  DEFB    00h,00h,00h
        JP      REGDUMP
GAP33:  DEFB    00h,00h,00h,00h,00h
        JP      REGDUMP                   ; RST 38h / IM-1-Interrupt

; ------------------------------------------------------------------------------
;  Kaltstart: I/O-Bausteine über die Tabelle (Wert, Port) initialisieren
; ------------------------------------------------------------------------------
COLD:   LD      HL,IOTAB
COLD_LP:
        LD      A,(HL)
        INC     HL
        LD      C,(HL)
        INC     HL
        OUT     (C),A
        INC     A
        JR      Z,INIT
        JR      COLD_LP
;  IOTAB: Paare (Wert, Port) wie beim SB-1510, Ende nach Wert FFh; das 00h
;  dahinter füllt bis zum NMI-Vektor 0066h (JP REGDUMP).
IOTAB:  DEFB    02h,0E3h,34h,0E7h,74h,0E7h,0B4h,0E7h
        DEFB    00h,0E6h,00h,0E6h,02h,0E5h,00h,0E5h
        DEFB    02h,0E4h,00h,0E4h,0CFh,0E9h,00h,0E9h
        DEFB    0CFh,0EBh,0FFh,0EBh,00h
        JP      REGDUMP

; ------------------------------------------------------------------------------
;  Initialisierung: Rollbereich, Stack 1180h, 40 Zeichen, Kassette,
;  Einschaltmeldung, IM 1, Uhr starten
; ------------------------------------------------------------------------------
INIT:   LD      HL,1801h
        LD      (SCROST),HL
        LD      SP,1180h
        LD      HL,MODE
        LD      A,12h
        LD      (HL),A
        OUT     (PPI_A),A
        INC     HL
        LD      B,1Eh
        CALL    ?CLER
INIT_KINT:
        XOR     A
        LD      (KINTF),A
        CALL    CHR40
        LD      A,0Dh
        OUT     (PPI_CTL),A
        LD      A,04h
        LD      (TEMPO),A
        INC     A
        LD      (NOTE_LENGTH+1),A
        LD      DE,MSG_MONITOR
        CALL    NLMSG
        IM      1                       ; Interrupt-Modus 1
        XOR     A
        LD      D,A
        LD      E,A
        CALL    TIMST
        JR      GOOUT
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h                 ; ?? |..|

; ------------------------------------------------------------------------------
;  GOOUT / ST – Kommandoschleife mit Prompt "*"
;  J adr  M adr  D start ende  L  S  V
; ------------------------------------------------------------------------------
GOOUT:  JP      PAS_BOOT                ; SB-4515: Einsprung des Interpreters (vorher JP ST)
ST:     DI
        LD      A,0Dh
        OUT     (PPI_CTL),A
        LD      SP,1180h
        CALL    NL
        LD      A,2Ah                   ; Prompt
        CALL    PRNT
        LD      A,27h                   ; "'"
        LD      (KNUMBS),A
        CALL    GETCMD
        CP      2Ah                     ; '*'
        JR      NZ,ST
        INC     DE
        LD      A,(DE)
        LD      HL,ST                   ; Rücksprungadresse ST
        PUSH    HL
        CP      4Ah                     ; 'J'
        JP      Z,CMD_J
        CP      4Dh                     ; 'M'
        JR      Z,CMD_M
        CP      44h                     ; 'D'
        JR      Z,CMD_D
        CP      4Ch                     ; 'L'
        JR      Z,CMD_L
        CP      53h                     ; 'S'
        JR      Z,CMD_S
        CP      56h                     ; 'V'
        JR      Z,CMD_V
        RET
;  GETCMD – Zeile nach BUFER lesen; BREAK (0Bh) führt zurück nach ST.
; <- aufgerufen von 00C6h, 010Ah, 0157h, 055Eh
GETCMD: LD      DE,BUFER
        CALL    GETL
        LD      A,(DE)
        CP      0Bh
        JR      Z,ST
        RET
;  *M adr – Speicher ändern: Adresse und Inhalt zeigen, neuen Wert (2 Hex-
;  ziffern) eingeben; leere Eingabe = nächste Adresse, ungültig = neue
;  Adresse. BREAK beendet.
CMD_M:  LD      A,4Dh                   ; Kommando M adr
        CALL    IN_HEXADR
        DEC     HL
CMDM_NEXT:
        INC     HL
        CALL    PRTADR
        LD      A,(HL)
        CALL    PRTHX
        CALL    PRNTS
        CALL    GETCMD
        LD      DE,MEM_IN
        LD      A,(DE)
        CP      0Dh
        JR      Z,CMDM_NEXT
        CALL    _2HEX
        JR      C,CMD_M
        LD      (HL),A
        JR      CMDM_NEXT
;  *D – Speicher von Start- bis Endadresse hexadezimal ausgeben, 8 (40
;  Zeichen) bzw. 16 Bytes je Zeile (Operand CMDD_PERLINE, gesetzt von
;  CHR40/CHR80). BREAK beendet, die Taste mit Code FDh in Port B hält an.
CMD_D:  CALL    IN_START                   ; Kommando D start ende
        PUSH    HL
        CALL    IN_END
        EX      DE,HL
CMDD_START:
        POP     HL
CMDD_LINE:
        CALL    PRTADR
CMDD_PERLINE:
        LD      B,10h
CMDD_BYTE:
        CALL    PRNTS
        LD      A,(HL)
        CALL    PRTHX
        PUSH    HL
        XOR     A
        SBC     HL,DE
        POP     HL
        RET     Z
        INC     HL
        DJNZ    CMDD_BYTE
        CALL    BRKEY
        RET     Z
CMDD_HOLD:
        IN      A,(PIO_BD)
        CP      0FDh
        JR      Z,CMDD_HOLD
        JR      CMDD_LINE
;  *V/*L/*S: Kommando als 0/1/2 im Operanden von TAPEMODE ablegen
;  ("DEFB 01h" verschluckt jeweils den nächsten LD). *S fragt Name, Start-,
;  End- und Ausführungsadresse ab und schreibt Kopf (Typ 1) und Daten.
CMD_V:  XOR     A                       ; Kommando V
        DEFB    01h                     ; Trick: Opcode 01h verschluckt den folgenden Befehl
CMD_L:  LD      A,01h                   ; Kommando L
        DEFB    01h                     ; Trick: Opcode 01h verschluckt den folgenden Befehl
CMD_S:  LD      A,02h                   ; Kommando S
        LD      (TAPEMODE+1),A
        LD      DE,FNAMEMES
        CALL    NLMSG
        CALL    GETCMD
TAPEMODE:
        LD      A,00h
        CP      02h
        JR      NZ,CMDL_SEARCH
        LD      DE,IBUFE
        LD      A,01h
        LD      (DE),A
        INC     DE
        LD      HL,NAME_IN
        LD      BC,0010h
        LDIR
        LD      A,0Dh
        LD      (DE),A
CMDS_RANGE:
        CALL    IN_START
        LD      (DTADR),HL
        PUSH    HL
        CALL    IN_END
        POP     DE
        XOR     A
        SBC     HL,DE
        JR      C,CMDS_RANGE
        LD      (IBU18),HL
        LD      HL,ST
        LD      (EXADR),HL
        LD      A,4Ah                   ; 'J'
        LD      (ASK_PROMPT+1),A
CMDS_EXEC:
        CALL    ASK_ADR
        JR      Z,CMDS_WRITE
        CALL    HLHEX
        JR      C,CMDS_EXEC
        LD      (EXADR),HL
CMDS_WRITE:
        CALL    WRINF
        CALL    NC,WRDAT
        RET

; ------------------------------------------------------------------------------
;  Kassette: Kommandos L/S/V, Meldungen
; ------------------------------------------------------------------------------
FNAMEMES:
        DEFB    "File name:",0Dh
;  *L/*V: Kopf lesen. Ist ein Name angegeben und passt nicht ("Found
;  name"), mit SERSP über den Datenblock spulen und weitersuchen. *L lädt
;  und startet an EXADR, *V vergleicht und meldet "OK".
CMDL_SEARCH:
        CALL    RDINF
        RET     C
        LD      A,(NAME_IN)
        CP      0Dh
        CALL    NZ,CMDL_FOUND
        JR      NZ,CMDL_SEARCH
        LD      A,(TAPEMODE+1)
        DEC     A
        JR      NZ,CMDV_VERIFY
        LD      DE,LOAMES
        CALL    MSG_NAME
        CALL    RDDAT
        RET     C
        LD      HL,(EXADR)
; <- aufgerufen von 06BDh, 0E44h, 0F8Fh
.HL:    JP      (HL)
; <- aufgerufen von 01B8h
CMDL_FOUND:
        LD      DE,FOUMES
        CALL    MSG_NAME
        LD      DE,NAME_IN
        LD      HL,IBU1
        LD      B,10h
        CALL    CMPNAME
        RET     Z
        CALL    SERSP
        OR      0FFh
        RET
CMDV_VERIFY:
        LD      DE,VERMES
        CALL    MSG_NAME
        CALL    VERFY
        RET     C
        LD      DE,OKMES
        JP      NLMSG
LOAMES: DEFB    "Loading ",0Dh
VERMES: DEFB    "Verifying ",0Dh
FOUMES: DEFB    "Found ",0Dh
OKMES:  DEFB    "OK",0Dh
CMD_J:  LD      A,4Ah                   ; Kommando J adr
        CALL    IN_HEXADR
        JP      (HL)

; ------------------------------------------------------------------------------
;  Kassetten-Grundroutinen WRINF/WRDAT/RDINF/RDDAT/VERFY
; ------------------------------------------------------------------------------
;  Kassettenformat wie beim SB-1510 (gleicher Code): Bit 1 = langer Puls,
;  Bit 0 = kurzer Puls, Byte = Startbit 1 + 8 Bits (höchstes zuerst),
;  Prüfsumme = Anzahl der 1-Bits, jeder Block zweimal. Bandmarke: Kopf
;  10000 Nullen, 40 Einsen, 40 Nullen, 1; Daten 11000 Nullen, 20 Einsen,
;  20 Nullen, 1. Die Prüfsumme steht hier in den Operanden von WR_CKSUM
;  und VF_CKSUM statt in Variablen.
;  WRINF/WRDAT/RDINF/RDDAT/VERFY: D = Art (01h/02h/04h/08h), Kopf 128
;  Bytes ab IBUFE, Daten nach SIZE/DTADR (GET_SIZEADR). C bei Fehler oder
;  BREAK.
; <- aufgerufen von 019Dh
WRINF:  RST     20h
        RST     28h
        LD      D,01h
        LD      HL,IBUFE
        LD      BC,0080h
CMT_WRITE:
        CALL    CKSUM
        CALL    CMT_READY
        JR      C,CMT_STOPRET
        BIT     0,D
        JR      Z,CMT_WRBLK
        PUSH    DE
        LD      DE,WRTMES
        CALL    MSG_NAME
        POP     DE
        CALL    TSPE
CMT_WRBLK:
        CALL    WRGAP_TM
        CALL    WRBLK
        JR      C,CMT_STOPRET
        BIT     1,D
        CALL    NZ,TSPE
        JR      NZ,CMT_STOPRET
        RET
; <- aufgerufen von 01A0h
WRDAT:  RST     20h
        RST     28h
        LD      D,02h
        CALL    GET_SIZEADR
        JR      CMT_WRITE
; <- aufgerufen von 0252h, 0281h, 028Ah
GET_SIZEADR:
        LD      BC,(IBU18)
        LD      HL,(DTADR)
        RET
; <- aufgerufen von 01AFh
RDINF:  RST     20h
        RST     28h
        LD      D,04h
        LD      HL,IBUFE
        LD      BC,0080h
CMT_READ:
        CALL    CMT_READY
        CALL    NC,CMT_SEEK
        CALL    NC,RDBLK
CMT_RDDONE:
        JR      C,CMT_STOPRET
        BIT     3,D
        RET     Z
        CALL    SERSP
CMT_STOPRET:
        JP      CMT_STOPAF
; <- aufgerufen von 01C9h
RDDAT:  RST     20h
        RST     28h
        LD      D,08h
        CALL    GET_SIZEADR
        JR      CMT_READ
; <- aufgerufen von 01EFh
VERFY:  RST     20h
        RST     28h
        LD      D,08h
        CALL    GET_SIZEADR
        CALL    CKSUM
        CALL    CMT_READY
        CALL    NC,CMT_SEEK
        CALL    NC,VFBLK
        JR      CMT_RDDONE
; <- aufgerufen von 0241h
WRBLK:  LD      E,02h
WRBLK_COPY:
        PUSH    BC
        PUSH    HL
WRBLK_BYTE:
        LD      A,(HL)
        CALL    WRBYTE
        CALL    BRK
        JR      C,BLK_RET
        INC     HL
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,WRBLK_BYTE
WR_CKSUM:
        LD      HL,0000h
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
;  beide falsch: "Check sum error", A = FFh, C.
; <- aufgerufen von 026Fh
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
        LD      (WR_CKSUM+1),HL
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
        LD      HL,(WR_CKSUM+1)
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
        LD      DE,CKSMES
        CALL    NLMSG
        LD      A,0FFh
        SCF
        JR      BLK_RET
; <- aufgerufen von 0296h
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
VF_CKSUM:
        LD      HL,0000h
        CALL    RDBYTE
        CP      H
        JR      NZ,CMT_CKERR
        CALL    RDBYTE
        CP      L
        JR      NZ,CMT_CKERR
        DEC     E
        POP     HL
        POP     BC
        RET     Z
        JR      VFBLK_COPY
; <- aufgerufen von 02A0h, 02B2h, 02B6h
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
;  prüfen (1 = langer Puls), 1-Bits für die Prüfsumme zählen.
; <- aufgerufen von 02E8h, 02F7h, 02FDh, 032Bh, 033Ch, 0342h
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
        LD      HL,(WR_CKSUM+1)
        INC     HL
        LD      (WR_CKSUM+1),HL
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
; <- aufgerufen von 023Eh
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
        DEC     L
        JR      NZ,GAP_ZEROS2
        CALL    WR1BIT
POP_HL_BC_RET:
        POP     HL
        POP     BC
        RET
;  RDTMARK – Bandmarke suchen: 40 (Kopf) bzw. 20 (Daten) Einsen in Folge,
;  dann ebenso viele Nullen.
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
;  CKSUM – Anzahl der 1-Bits von BC Bytes ab HL in die Operanden von
;  WR_CKSUM und VF_CKSUM.
; <- aufgerufen von 0227h, 028Dh
CKSUM:  PUSH    BC
        PUSH    HL
        PUSH    DE
        LD      DE,0000h
CKSUM_LP:
        LD      A,B
        OR      C
        JR      NZ,CKSUM_BYTE
        EX      DE,HL
        LD      (WR_CKSUM+1),HL
        LD      (VF_CKSUM+1),HL
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
;  EDGE – auf eine Flanke des Lesesignals (PPI Port B Bit 6) warten;
;  C = BREAK gedrückt.
; <- aufgerufen von 02D0h, 031Dh, 0363h, 0380h, 03BAh, 03CCh, 03DDh
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
;  CMT_READY – Kassette eingelegt? Sonst "Set tape" und Fach öffnen; beim
;  Schreiben Schreibschutz prüfen ("Write protect"), dann PLAY (beim
;  Schreiben mit Aufnahme). Port B Bit 4: Schreibschutz, Bit 5: keine
;  Kassette.
; <- aufgerufen von 022Ah, 0269h, 0290h
CMT_READY:
        CALL    KBSET
        IN      A,(PPI_B)
        AND     20h
        JR      Z,CMTR_WPCHK
        PUSH    DE
        LD      DE,SETMES
        CALL    NLMSG
        POP     DE
        CALL    OPEN
CMTR_WAIT:
        CALL    BRK
        RET     C
        IN      A,(PPI_B)
        AND     20h
        JR      NZ,CMTR_WAIT
        CALL    DEL1M
CMTR_WPCHK:
        LD      A,03h
        AND     D
        JR      Z,CMTR_PLAY
        IN      A,(PPI_B)
        AND     10h
        JR      Z,CMTR_REC
        PUSH    DE
        LD      DE,WPRMES
        CALL    NLMSG
        POP     DE
        SCF

; ------------------------------------------------------------------------------
;  Kassettenmechanik: OPEN, SERSP, MSTOP, FFWD, Zeitschleifen
; ------------------------------------------------------------------------------
; <- aufgerufen von 0427h
OPEN:   LD      A,08h
        OUT     (PPI_CTL),A
        CALL    DEL1M
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
        LD      A,(MODE)
        SET     2,A
        JR      CMT_SETCMD
;  SERSP – stoppen, schnell vorspulen und warten, bis das Lesesignal
;  4C00h Abfragen lang kein Wechselmuster (letzte 6 Bits 2Ah/15h) mehr
;  zeigt, vermutlich also bis hinter den aktuellen Block. C = BREAK.
; <- aufgerufen von 01E3h, 0277h
SERSP:  RST     20h
        CALL    MSTOP
        CALL    FFWD
SERSP_RESET:
        LD      BC,4C00h
SERSP_LP:
        IN      A,(PPI_B)
        RLCA
        CCF
        RET     C
        RLCA
        RL      D
        LD      A,D
        AND     3Fh
        CP      2Ah                     ; '*'
        JR      Z,SERSP_HIT
        CP      15h
        JR      Z,SERSP_HIT
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,SERSP_LP
        RET
SERSP_HIT:
        INC     B
        LD      A,B
        CP      4Ch                     ; 'L'
        JR      NC,SERSP_RESET
        JR      SERSP_LP
;  Laufwerk: PPI Port A Bit 0 REW, 1 FF, 2 PLAY, 3 STOP (Flanke über BLK1
;  mit MODE), Port C über Bit-Set/Reset: Bit 4 Fach öffnen (OPEN), Bit 5
;  wird vor PLAY/FF gepulst (CMT_PREPULSE), Bit 6 Aufnahme.
; <- aufgerufen von 046Bh, 1054h
MSTOP:  LD      A,0Dh
        OUT     (PPI_CTL),A
; <- aufgerufen von 045Dh
CMT_STOPCMD:
        LD      A,(MODE)
        SET     3,A
CMT_SETCMD:
        CALL    BLK1
; <- aufgerufen von 04B5h, 04BBh
CMT_IDLE:
        LD      A,(MODE)
; <- aufgerufen von 049Eh
BLK1:   OUT     (PPI_A),A
        JR      DLY_SHORT
; <- aufgerufen von 0460h, 04B8h
CMT_PREPULSE:
        LD      A,0Bh
        CALL    PPC_OUT
        DEC     A
; <- aufgerufen von 04AAh
PPC_OUT:
        OUT     (PPI_CTL),A
        JR      DLY_SHORT
; <- aufgerufen von 046Eh
FFWD:   CALL    KBSET
        CALL    CMT_IDLE
HIGHSC: CALL    CMT_PREPULSE
        CALL    CMT_IDLE
        SET     0,A
        JR      CMT_SETCMD
;  TSPE – lange Wartezeit nach dem Schreiben (Port C Bit 7 aus). DLY_BC:
;  BC Durchläufe zu 256, DLY_SHORT: einer, DEL1M: 796h.
; <- aufgerufen von 023Bh, 0248h
TSPE:   RST     20h
        LD      A,0Eh
        OUT     (PPI_CTL),A
        LD      BC,1E56h
; <- aufgerufen von 0787h
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
        RET
DLY_SHORT:
        RST     20h
        LD      BC,0001h
        JR      DLY_BC
; <- aufgerufen von 0434h, 044Fh, 1059h
DEL1M:  RST     20h
        LD      BC,0796h
        JR      DLY_BC
;  WR0BIT / WR1BIT – kurzen bzw. langen Puls auf Port C Bit 7; die Dauer
;  steht im Operanden von DLY_A. DLY_BIT: Abtastzeitpunkt (Operand von
;  DLY_BITSET = Z80KT).
; <- aufgerufen von 02C3h, 0358h, 0396h, 03A4h
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
; <- aufgerufen von 02B9h, 0351h, 0355h, 039Eh, 03AAh
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
; <- aufgerufen von 02D5h, 0322h, 0368h, 03BFh, 03D1h
DLY_BIT:
        LD      A,H
        LD      A,L
DLY_BITSET:
        LD      A,41h                   ; 'A'
        LD      (DLY_A+1),A
; <- aufgerufen von 04EDh, 04F9h, 0508h, 0514h
DLY_A:  LD      A,0FFh
DLY_A_LP:
        DEC     A
        JP      NZ,DLY_A_LP
        RET

; ------------------------------------------------------------------------------
;  BRKEY/BRK/KBSET – BREAK-Taste
; ------------------------------------------------------------------------------
; <- aufgerufen von 013Bh
BRKEY:  CALL    KBSET
        IN      A,(PIO_BD)
        AND     80h
        JP      KINT
; <- aufgerufen von 02A3h, 042Ah, 0B8Fh
BRK:    IN      A,(PIO_BD)
        CPL
        RLCA
        RET
; <- aufgerufen von 0416h, 04B2h, 0527h, 0B8Ch
KBSET:  IN      A,(PIO_AD)
        AND     0E0h
        OR      13h
        OUT     (PIO_AD),A
        RET
;  IN_START / IN_END – Start- bzw. Endadresse abfragen (Prompt "S"/"E";
;  "DEFB 21h" verschluckt den zweiten LD). IN_HEXADR: Adresse mit Prompt
;  A, bis sie gültig ist. ASK_ADR: Prompt (Operand von ASK_PROMPT) und
;  "-adr.$" ausgeben, Zeile lesen; DE = ADR_IN, Z = leere Eingabe.
; <- aufgerufen von 011Dh, 0172h
IN_START:
        LD      A,53h                   ; 'S'
        DEFB    21h                     ; Trick: Opcode 21h verschluckt den folgenden Befehl
; <- aufgerufen von 0121h, 0179h
IN_END: LD      A,45h                   ; 'E'
; <- aufgerufen von 00FBh, 0219h
IN_HEXADR:
        LD      (ASK_PROMPT+1),A
ASKADR_RETRY:
        CALL    ASK_ADR
        CALL    HLHEX
        JR      C,ASKADR_RETRY
        RET
; <- aufgerufen von 0190h, 0547h
ASK_ADR:
        CALL    NL
ASK_PROMPT:
        LD      A,0FFh
        CALL    PRNT
        LD      DE,ADRMES
        CALL    MSG
        CALL    GETCMD
        LD      DE,ADR_IN
        LD      A,(DE)
        CP      0Dh
        RET

; ------------------------------------------------------------------------------
;  Hex-Ausgabe und -Eingabe: PRTHL, PRTHX, ASC, HEX, HLHEX, 2HEX
; ------------------------------------------------------------------------------
; <- aufgerufen von 0637h, 09B8h
PRTHL:  LD      A,H
        CALL    PRTHX
        LD      A,L
; <- aufgerufen von 0104h, 012Fh, 0569h
PRTHX:  PUSH    AF
        AND     0F0h
        RRCA
        RRCA
        RRCA
        RRCA
        CALL    ASC
        CALL    PRNT
        POP     AF
        AND     0Fh
        CALL    ASC
        JP      PRNT
; <- aufgerufen von 0574h, 057Dh
ASC:    AND     0Fh
        ADD     A,30h
        CP      3Ah                     ; ':'
        RET     C
        ADD     A,07h
        RET
;  HEX – ASCII-Zeichen in Hexziffer, C wenn ungültig. HLHEX / _2HEX –
;  4 bzw. 2 Hexziffern ab (DE) nach HL bzw. A, C bei Fehler.
; <- aufgerufen von 05B4h, 05C0h
HEX:    CP      47h                     ; 'G'
        CCF
        RET     C
        CP      41h                     ; 'A'
        JR      NC,HEX_LETTER
        CP      3Ah                     ; ':'
        CCF
        RET     C
        CP      30h                     ; '0'
        RET     C
        SUB     30h
        RET
HEX_LETTER:
        SUB     37h
        RET
; <- aufgerufen von 0195h, 054Ah
HLHEX:  PUSH    DE
        CALL    _2HEX
        JR      C,HLHEX_RET
        LD      H,A
        CALL    _2HEX
        JR      C,HLHEX_RET
        LD      L,A
HLHEX_RET:
        POP     DE
        RET
; <- aufgerufen von 0115h, 05A3h, 05A9h
_2HEX:  PUSH    BC
        LD      A,(DE)
        INC     DE
        CALL    HEX
        JR      C,HEX2_RET
        RLCA
        RLCA
        RLCA
        RLCA
        LD      C,A
        LD      A,(DE)
        INC     DE
        CALL    HEX
        JR      C,HEX2_RET
        OR      C
HEX2_RET:
        POP     BC
        RET
;  CMPNAME – Texte ab DE und HL bis 0Dh vergleichen, Z = gleich.
; <- aufgerufen von 01DFh
CMPNAME:
        RST     20h
CMPNAME_LP:
        LD      A,(DE)
        CP      (HL)
        RET     NZ
        CP      0Dh
        RET     Z
        INC     HL
        INC     DE
        JR      CMPNAME_LP

; ------------------------------------------------------------------------------
;  ?CLER/?DINT – Speicher füllen; Meldungstexte
; ------------------------------------------------------------------------------
; <- aufgerufen von 007Dh, 06CAh
?CLER:  XOR     A
?DINT:  LD      (HL),A
        INC     HL
        DJNZ    ?DINT
        RET
ADRMES: DEFB    "-adr.$",0Dh
SETMES: DEFB    "Set tape",0Dh
WRTMES: DEFB    "Writing ",0Dh
WPRMES: DEFB    "Write protect",0Dh
CKSMES: DEFB    "Check sum error",0Dh

; ------------------------------------------------------------------------------
;  GETKY – Taste holen; Zeichenausgabe PRNT/PRNTS/PRNTT, MSG, MSGX
; ------------------------------------------------------------------------------
; <- aufgerufen von 0D2Ah
GETKY:  RST     20h
        CALL    PUSHKI
        CALL    KEYSCAN
        CP      1Eh
        RET     NZ
        XOR     A
        RET
;  ROWCHK_CSR / ROWCHK – Zeile A (bzw. die Cursorzeile) gegen den
;  Rollbereich: C = außerhalb, Z = letzte Zeile (SCREND). Zeilen 0-24;
;  der Rollbereich reicht von SCROST-1 bis SCREND.
;  COLCHK: Z, wenn der Cursor in der letzten Spalte steht (A = letzte
;  Spalte, Operand von COLCHK_MAX = CH3979).
; <- aufgerufen von 07DAh, 07F0h, 0803h, 082Ah
ROWCHK_CSR:
        LD      HL,(DSPXY)
        LD      A,H
; <- aufgerufen von 0665h, 0896h
ROWCHK: RST     20h
        LD      HL,SCROST
        LD      B,(HL)
        DEC     B
        CP      B
        RET     C
        INC     HL
        CP      (HL)
        RET     Z
        CCF
        RET
; <- aufgerufen von 065Fh, 07CDh, 07E5h
COLCHK: LD      HL,(DSPXY)
COLCHK_MAX:
        LD      A,4Fh                   ; 'O'
        CP      L
        RET
; <- aufgerufen von 0100h, 0126h
PRTADR: CALL    NL
; <- aufgerufen von 09AFh
PRTHL_SP:
        CALL    PRTHL
; <- aufgerufen von 0107h, 012Bh, 0695h
PRNTS:  LD      A,20h                   ; ' '
;  PRNT – Zeichen ausgeben: unter 10h als Steuerzeichen (?DPCT), sonst ?DSP.
;  ?DSP: 1Bh = nächster Tabstopp (TABDAT), 1Ah = "00". Im Einfügemodus wird
;  eingefügt (DSP_INSERT). In der letzten Spalte wird die nächste
;  Bildschirmzeile zur Fortsetzung der logischen Zeile (MANG, höchstens
;  LLINE_MAX Fortsetzungen) und gelöscht.
; <- aufgerufen von 00BEh, 0555h, 0577h, 0CD8h
PRNT:   CP      10h
        JP      C,?DPCT
; <- aufgerufen von 0C4Eh
?DSP:   RST     20h
; <- aufgerufen von 064Ch, 08BBh
DSP_CHAR:
        CP      1Bh
        JR      Z,DSP_TAB
        CP      1Ah
        JR      NZ,DSP_PUT
        LD      A,30h                   ; '0'
        CALL    DSP_CHAR
        LD      A,30h                   ; '0'
DSP_PUT:
        LD      HL,CSR_BLINKCNT+1
        BIT     4,(HL)
        JP      NZ,DSP_INSERT
        CALL    ?PONT
        CALL    DSPW
        CALL    COLCHK
        JR      NZ,DSP_NEXT
        LD      A,H
        CALL    ROWCHK
        RET     C
        CALL    MAGA_NEXT
DSP_NEXT:
        JP      NZ,CSR_RIGHT
        DEC     HL
        LD      A,(HL)
LLINE_MAX:
        CP      03h
        JR      NC,DSP_CONT
        INC     HL
        INC     A
        LD      (HL),A
DSP_CONT:
        CALL    CSR_RIGHT
        JP      DELLN
DSP_TAB:
        LD      DE,(DSPXY)
DSP_TAB_LP:
        INC     E
        LD      A,(CH4080)
        CP      E
        RET     Z
        LD      A,E
        CALL    TAB_FIND
        JR      NZ,DSP_TAB_LP
        EX      DE,HL
        CALL    INS_OFF
        JP      CSR_SET
;  PRNTT – Leerzeichen bis zur nächsten durch 10 teilbaren Spalte (immer
;  mindestens eins).
PRNTT:  CALL    PRNTS
        LD      A,(DSPXY)
        OR      A
        RET     Z
PRNTT_LP:
        SUB     0Ah
        JR      C,PRNTT
        JR      NZ,PRNTT_LP
        RET
;  MSG_NAME – Meldung DE und Dateinamen (IBU1) ausgeben. NLMSG / MSGX /
;  MSG – Text bis 0Dh ausgeben (NLMSG mit Zeilenvorschub); MSGX über ?DSP,
;  Steuerzeichen erscheinen also als Zeichen, MSG über PRNT.
; <- aufgerufen von 01C6h, 01D4h, 01ECh, 0237h
MSG_NAME:
        CALL    NLMSG
        LD      DE,IBU1
        JR      MSGX
; <- aufgerufen von 0097h, 0154h, 0311h, 0423h, 0446h, 06A4h
NLMSG:  CALL    NL
MSGX:   RST     20h
        LD      HL,?DSP
        JR      MSG_LP
; <- aufgerufen von 055Bh
MSG:    RST     20h
        LD      HL,PRNT
MSG_LP: LD      A,(DE)
        CP      0Dh
        RET     Z
        CALL    .HL
        INC     DE
        JR      MSG_LP

; ------------------------------------------------------------------------------
;  SCRSET, KEYKEY, ?DPCT (Steuerzeichen über die Tabelle CTLTAB)
; ------------------------------------------------------------------------------
;  SCRSET – MANG löschen, VRAM-Startadresse und Länge des Rollbereichs
;  berechnen (Operanden SCR_START/SCR_LEN in SCROLL), Bildschirm löschen.
; <- aufgerufen von 0989h
SCRSET: RST     20h
        RST     28h
        LD      HL,MANG
        LD      B,1Ch
        CALL    ?CLER
        LD      HL,SCROST
        PUSH    HL
        LD      H,(HL)
        DEC     H
        LD      L,00h
        CALL    XY2VRAM
        LD      (SCR_START+1),HL
        EX      (SP),HL
        INC     HL
        LD      H,(HL)
        LD      L,00h
        CALL    XY2VRAM
        POP     DE
        OR      A
        SBC     HL,DE
        LD      (SCR_LEN+1),HL
        JP      CLS
;  KEYKEY – ist überhaupt eine Taste gedrückt (PIO Port A Bit 4 = 0,
;  vermutlich alle Zeilen zugleich)? Dann KEYSCAN, sonst NOKKEY: KYBDA = 0, KSTD = FFh
;  (keine Taste), A = 1Eh.
; <- aufgerufen von 0C20h, 0D8Bh
KEYKEY: IN      A,(PIO_AD)
        RES     4,A
        OUT     (PIO_AD),A
        IN      A,(PIO_BD)
        IN      A,(PIO_BD)
        INC     A
        PUSH    AF
        LD      B,05h
KEYKEY_DLY:
        XOR     A
KEYKEY_DLYIN:
        DEC     A
        JR      NZ,KEYKEY_DLYIN
        DJNZ    KEYKEY_DLY
        POP     AF
        JP      NZ,KEYSCAN
NOKKEY: XOR     A
        LD      HL,KYBDA
        LD      (HL),A
        DEC     A
        LD      B,0Bh
NOKKEY_LP:
        INC     HL
        LD      (HL),A
        DJNZ    NOKKEY_LP
        LD      A,1Eh
        RET
;  Steuerzeichen über CTLTAB: 00h Rest der logischen Zeile löschen,
;  01h Cursor ab (rollt), 02h auf, 03h rechts, 04h links, 05h Home,
;  06h Bildschirm löschen, 07h DEL, 08h Einfügemodus, 09h Grafikmodus,
;  0Ah Kleinschrift, 0Bh nichts, 0Ch Invers ein, 0Dh neue Zeile (LETNL),
;  0Eh Normalmodus, 0Fh Invers aus. 00h-06h beenden den Einfügemodus.
; <- aufgerufen von 0C6Eh
?DPCT:  RST     20h
        LD      HL,CTLTAB
        RLCA
        LD      C,A
        LD      B,00h
        CP      0Eh
        CALL    C,INS_OFF
        ADD     HL,BC
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        JP      (HL)
CTLTAB: DEFW    DELLN
        DEFW    CSR_DOWN
        DEFW    CSR_UP
        DEFW    CSR_RIGHT
        DEFW    CSR_LEFT
        DEFW    CSR_HOME
        DEFW    CLS
        DEFW    CTL_DEL
        DEFW    CTL_INST
        DEFW    CTL_09
        DEFW    CTL_0A
        DEFW    NOP_RET
        DEFW    CTL_0C
        DEFW    LETNL
        DEFW    CTL_0E
        DEFW    CTL_0F
;  SCRL_KEYCHK – Z, wenn die Taste Zeile 0Bh Bit 2 gedrückt ist (bremst das
;  Rollen um SLOW).
; <- aufgerufen von 077Eh
SCRL_KEYCHK:
        RST     28h
        IN      A,(PIO_AD)
        AND     0E0h
        OR      1Bh
        OUT     (PIO_AD),A
        IN      A,(PIO_BD)
        IN      A,(PIO_BD)
        AND     04h
NOP_RET:
        RET

; ------------------------------------------------------------------------------
;  NL/LETNL – neue Zeile; Bildschirmsteuerung, Rollen, Zeilen löschen
; ------------------------------------------------------------------------------
;  NL – neue Zeile, außer der Cursor steht schon am Anfang einer logischen
;  Zeile. LETNL – Cursor an den Anfang der Zeile hinter der logischen
;  Zeile; unter dem Rollbereich wird gerollt.
; <- aufgerufen von 00B9h, 0550h, 0634h, 06ACh
NL:     RST     20h
        CALL    ?PONT
        PUSH    HL
        CALL    ??TOL
        POP     DE
        OR      A
        SBC     HL,DE
        RET     Z
LETNL:  RST     20h
        CALL    ??EOL
NL_DOWN:
        CALL    INS_OFF
        LD      A,(SCREND)
        LD      HL,DSPXY1
        CP      (HL)
        RET     NC
        DEC     (HL)
        CP      (HL)
        JR      Z,SCROLL
        LD      A,(HL)
        CP      18h
        RET     Z
        INC     (HL)
        RET
; <- aufgerufen von 089Fh
SCROLL_UP:
        RST     20h
;  SCROLL – Rollbereich eine Zeile nach oben schieben, unterste Zeile
;  löschen, MANG mitschieben.
SCROLL: CALL    SCRL_KEYCHK
        LD      A,(SLOW)
        LD      C,A
        LD      B,00h
        CALL    Z,DLY_BC
        LD      HL,(DSPXY)
        LD      A,(SCROST)
        DEC     A
        LD      D,A
        LD      E,00h
        LD      (DSPXY),DE
        CALL    CLRLINE
SCR_START:
        LD      DE,0D000h
SCR_LEN:
        LD      BC,0780h
SCR_WIDTH:
        LD      HL,0050h
        ADD     HL,DE
        CALL    VRAM_LDIR
        EX      DE,HL
        LD      A,(CH4080)
        LD      B,A
        CALL    VRAM_CLR
        LD      HL,SCREND
        LD      A,(HL)
        DEC     HL
        SUB     (HL)
        ADD     A,03h
        LD      C,A
        LD      B,00h
        LD      DE,MANG
        LD      L,(HL)
        LD      H,00h
        ADD     HL,DE
        LD      D,H
        LD      E,L
        DEC     DE
        LDIR
        LD      (HL),00h
        RET
DSP_INSERT:
        CALL    INS_CHAR
;  Cursor: CSR_RIGHT (03h, am Zeilenende in die nächste Zeile), CSR_DOWN
;  (01h, rollt), CSR_LEFT (04h), CSR_UP (02h), CLS (06h), CSR_HOME (05h).
;  CSR_SET: HL nach DSPXY (L = Spalte, H = Zeile).
; <- aufgerufen von 0678h
CSR_RIGHT:
        CALL    COLCHK
        JR      Z,CSR_NEWLINE
        INC     L
        JR      CSR_SET
CSR_NEWLINE:
        LD      L,00h
        LD      (DSPXY),HL
CSR_DOWN:
        CALL    ROWCHK_CSR
        RET     C
        JR      Z,SCROLL
        INC     H
CSR_SET:
        LD      (DSPXY),HL
        RET
CSR_LEFT:
        CALL    COLCHK
        DEC     L
        JP      P,CSR_SET
        LD      L,A
        LD      (DSPXY),HL
CSR_UP: CALL    ROWCHK_CSR
        RET     C
        LD      A,(SCROST)
        DEC     A
        CP      H
        RET     Z
        DEC     H
        JR      CSR_SET
CLS:    CALL    CSR_HOME
CLS_LP: CALL    CLR_TOEOL
        CALL    ROWCHK_CSR
        JR      NC,CLS_LP
; <- aufgerufen von 07FDh
CSR_HOME:
        LD      A,(SCROST)
        DEC     A
        LD      H,A
        LD      L,00h
        JR      CSR_SET
DELLN:  LD      HL,(DSPXY)
; <- aufgerufen von 0798h
CLRLINE:
        PUSH    HL
CLRLINE_GO:
        CALL    CLR_TOEOL
CSR_RESTORE:
        POP     HL
        JR      CSR_SET
; <- aufgerufen von 0800h, 0815h
CLR_TOEOL:
        LD      A,20h                   ; ' '
        LD      (CSR_UNDER+1),A
        LD      C,0FFh
        CALL    LLINE_LENC
        LD      B,L
        EX      DE,HL
        JP      VRAM_CLR
;  CTL_DEL (07h) – Zeichen links vom Cursor löschen, Rest der logischen
;  Zeile nachziehen.
CTL_DEL:
        CALL    ROWCHK_CSR
        JR      C,DEL_GO
        LD      A,(SCROST)
        DEC     A
        CP      H
        JR      NZ,DEL_GO
        XOR     A
        OR      L
        RET     Z
DEL_GO: LD      A,L
        OR      A
        JR      NZ,DEL_SHIFT
        LD      E,H
        CALL    MAGA
        JR      NZ,DEL_SHIFT
        CALL    ?PONT
        DEC     HL
        CALL    DSPW_SPC
        JR      CSR_LEFT
DEL_SHIFT:
        LD      HL,(DSPXY)
        PUSH    HL
        CALL    LLINE_LEN
        PUSH    DE
        EX      (SP),HL
        POP     BC
        DEC     DE
        CALL    VRAM_LDIR
        DEC     HL
        CALL    DSPW_SPC
        POP     HL
        LD      (DSPXY),HL
        JR      CSR_LEFT
;  CTL_INST (08h) – Einfügemodus ein: Blinktakt 10h statt 40h im Operanden
;  von CSR_BLINKCNT, den ?DSP abfragt. INS_OFF schaltet ihn aus. Anders als
;  beim SB-1510 fügt 08h also kein Leerzeichen ein, sondern schaltet um.
CTL_INST:
        LD      A,10h
        DEFB    21h                     ; Trick: Opcode 21h verschluckt den folgenden Befehl
; <- aufgerufen von 068Fh, 071Eh, 0768h
INS_OFF:
        LD      A,40h                   ; '@'
        LD      (CSR_BLINKCNT+1),A
        RET
;  INS_CHAR – Zeichen an der Cursorposition einfügen und den Rest der
;  logischen Zeile verschieben; fällt hinten ein Zeichen heraus, wird eine
;  neue Fortsetzungszeile angelegt (höchstens LLINE_MAX).
; <- aufgerufen von 07CAh
INS_CHAR:
        RST     28h
        LD      B,A
        LD      HL,(DSPXY)
        PUSH    HL
        CALL    LLINE_LEN
        LD      C,L
        EX      DE,HL
        LD      A,B
        LD      B,C
        LD      C,0E8h
        IN      D,(C)
        SET     7,D
        OUT     (C),D
INS_SHIFT:
        LD      E,(HL)
        LD      (HL),A
        LD      A,E
        INC     HL
        DJNZ    INS_SHIFT
        RES     7,D
        OUT     (C),D
        CP      20h                     ; ' '
        JR      Z,CSR_RESTORE
        LD      C,A
        LD      A,(DSPXY1)
        DEC     A
        LD      E,A
        CALL    ROWCHK
        JP      C,CSR_RESTORE
        JP      NZ,INS_NEWROW
        CALL    SCROLL_UP
        DEC     E
        POP     HL
        DEC     H
        PUSH    HL
        INC     H
        LD      L,00h
        LD      (DSPXY),HL
INS_NEWROW:
        LD      A,(LLINE_MAX+1)
        LD      B,A
        CALL    MAGA
        CP      B
        JP      NC,CSR_RESTORE
        INC     HL
        INC     A
        LD      (HL),A
        LD      A,C
        CALL    DSP_CHAR
        JP      CLRLINE_GO
;  ??TOL – Cursor an den Anfang der logischen Zeile. ??EOL – hinter ihr
;  Ende (C Bit 0: dabei die Fortsetzungsmerker löschen). LLINE_LEN: Länge
;  von der Cursorposition bis zum Ende der logischen Zeile (HL), DE =
;  VRAM-Adresse des Cursors.
; <- aufgerufen von 075Ch, 0C7Eh
??TOL:  LD      HL,(DSPXY)
        PUSH    HL
        LD      E,H
        CALL    MAGA
        POP     HL
        NEG
        ADD     A,H
        LD      H,A
        XOR     A
        LD      L,A
        JR      EOL_SETCSR
; <- aufgerufen von 0765h
??EOL:  LD      C,00h
; <- aufgerufen von 08EEh
EOL_LP: CALL    MAGA_NEXT
        LD      D,E
        EX      DE,HL
        LD      L,A
        XOR     A
        BIT     0,C
        JR      Z,EOL_STORE
        LD      (DE),A
EOL_STORE:
        OR      L
EOL_SETCSR:
        LD      (DSPXY),HL
        JR      NZ,EOL_LP
        JR      ?PONT
; <- aufgerufen von 0850h, 0873h, 0C81h
LLINE_LEN:
        LD      C,00h
; <- aufgerufen von 0822h
LLINE_LENC:
        CALL    ?PONT
        PUSH    HL
        CALL    EOL_LP
        POP     DE
        OR      A
        SBC     HL,DE
        RET
; <- aufgerufen von 0669h, 08D4h
MAGA_NEXT:
        LD      HL,(DSPXY)
        LD      E,H
        INC     E
;  MAGA – MANG[E]: Fortsetzungsnummer von Zeile E (0 = Anfang einer
;  logischen Zeile), Z wenn 0. MAGA_NEXT: für die Zeile unter dem Cursor.
; <- aufgerufen von 083Eh, 08B0h, 08C6h
MAGA:   LD      D,00h
        LD      HL,MANG
        ADD     HL,DE
        LD      A,(HL)
        OR      A
        RET
;  ?PONT / XY2VRAM – VRAM-Adresse der Position HL (L = Spalte, H = Zeile):
;  XY_BASE + (H + 1) * Breite + L; XY_BASE = D000h - Breite (CHR40/CHR80).
; <- aufgerufen von 0659h, 0758h, 0843h, 08EAh, 0CDFh, 0D1Ah, 0D71h
?PONT:  LD      HL,(DSPXY)
; <- aufgerufen von 06D5h, 06E0h
XY2VRAM:
        PUSH    BC
        PUSH    DE
        LD      B,H
        LD      C,L
        INC     B
        LD      DE,(CH4080)
XY_BASE:
        LD      HL,0CFD8h
XY_LP:  ADD     HL,DE
        DJNZ    XY_LP
        ADD     HL,BC
        POP     DE
        POP     BC
        RET

; ------------------------------------------------------------------------------
;  DSPRED/DSPW – VRAM lesen/schreiben; CHR80/CHR40 – Zeichenbreite
; ------------------------------------------------------------------------------
;  DSPRED / DSPW / VRAM_LDIR / VRAM_CLR – Text-VRAM über PIO Port A Bit 7
;  einblenden, lesen/schreiben/kopieren/mit Leerzeichen füllen, ausblenden.
;  DSPW_SPC schreibt ein Leerzeichen.
; <- aufgerufen von 0D1Dh
DSPRED: RST     28h
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
        RET
; <- aufgerufen von 0847h, 085Bh
DSPW_SPC:
        LD      A,20h                   ; ' '
; <- aufgerufen von 065Ch, 0CE4h
DSPW:   RST     28h
        PUSH    BC
        LD      C,0E8h
        IN      B,(C)
        SET     7,B
        OUT     (C),B
        LD      (HL),A
        JR      VRAM_OFF
; <- aufgerufen von 07A5h, 0857h, 0CA0h
VRAM_LDIR:
        IN      A,(PIO_AD)
        SET     7,A
; <- aufgerufen von 0C9Bh
VRAM_LDIRA:
        RST     28h
        OUT     (PIO_AD),A
        LDIR
VRAM_OFFA:
        AND     3Fh
        OUT     (PIO_AD),A
        RET
; <- aufgerufen von 07ADh, 0983h
VRAM_CLR:
        RST     28h
        IN      A,(PIO_AD)
        SET     7,A
        OUT     (PIO_AD),A
VRAM_CLR_LP:
        LD      (HL),20h
        INC     HL
        DJNZ    VRAM_CLR_LP
        IN      A,(PIO_AD)
        JR      VRAM_OFFA
;  CHR80 / CHR40 – 80 bzw. 40 Zeichen: setzt LLINE_MAX (1/3), CMDD_PERLINE
;  (16/8), den Befehl bei CHR_MODE (SET/RES 5,A für PIO Port A Bit 5),
;  CH3979/CH4080 (letzte Spalte/Breite) und XY_BASE; löscht den VRAM
;  (8 x 256 Bytes), SCRSET, Cursor Home.
CHR80:  RST     28h
        LD      A,01h
        LD      (LLINE_MAX+1),A
        LD      A,10h
        LD      (CMDD_PERLINE+1),A
        LD      A,0EFh
        LD      (CHR_MODE+1),A
        LD      A,4Fh                   ; 'O'
        LD      HL,0CFB0h
CHR_COMMON:
        LD      (CH3979),A
        INC     A
        LD      (CH4080),A
        LD      (XY_BASE+1),HL
        IN      A,(PIO_AD)
CHR_MODE:
        SET     5,A
        OUT     (PIO_AD),A
        LD      HL,0D000h
        LD      BC,0008h
CHR_CLR:
        CALL    VRAM_CLR
        DEC     C
        JR      NZ,CHR_CLR
        CALL    SCRSET
        JP      CSR_HOME
; <- aufgerufen von 0084h
CHR40:  LD      A,03h
        LD      (LLINE_MAX+1),A
        LD      A,08h
        LD      (CMDD_PERLINE+1),A
        LD      A,0AFh
        LD      (CHR_MODE+1),A
        LD      A,27h                   ; "'"
        LD      HL,0CFD8h
        JR      CHR_COMMON

; ------------------------------------------------------------------------------
;  Registeranzeige (RST 08h-38h, NMI) – danach zurück nach ST
; ------------------------------------------------------------------------------
;  REGDUMP – Ziel von RST 08h-38h und NMI: Rücksprungadresse - 1 (= Adresse
;  des RST-Befehls), AF, BC, DE, HL, diese Adresse und SP hexadezimal
;  ausgeben, dann ST.
REGDUMP:
        EX      (SP),HL
        DEC     HL
        EX      (SP),HL
        PUSH    HL
        PUSH    DE
        PUSH    BC
        PUSH    AF
        LD      B,05h
REGDUMP_LP:
        POP     HL
        CALL    PRTHL_SP
        DJNZ    REGDUMP_LP
        LD      HL,0000h
        ADD     HL,SP
        CALL    PRTHL
        JP      ST

; ------------------------------------------------------------------------------
;  XTEMP, TIMST/TIMRD (Uhr), BELL, MELDY/RYTHM (MUSIC)
; ------------------------------------------------------------------------------
;  XTEMP – Tempo n (1-7) setzen: TEMPO = 8 - n.
XTEMP:  PUSH    AF
        AND     0Fh
        NEG
        ADD     A,08h
        LD      (TEMPO),A
        POP     AF
        RET
;  TIMST – Uhr stellen: A = 0 vormittags / 1 nachmittags, DE = Sekunden.
;  8253: Zähler 1 zählt ab A8C0h (12 Stunden in Sekunden) abwärts;
;  Zähler 0 (7A12h) liefert vermutlich den Sekundentakt, Zähler 2 zählt
;  vermutlich die Durchläufe von Zähler 1 (Stand in TIM_LAST). TIMRD – Uhr lesen: A = 0/1, DE = Sekunden.
; <- aufgerufen von 009Fh
TIMST:  RST     28h
        PUSH    BC
        LD      (TIM_PM+1),A
        LD      (TIM_START+1),DE
        LD      A,0C1h
        OUT     (PIT_C1),A
        LD      A,0A8h
        OUT     (PIT_C1),A
        LD      A,02h
        OUT     (PIT_C0),A
        XOR     A
        OUT     (PIT_C0),A
        OUT     (TMR_F0),A
TIMST_SYNC:
        LD      A,44h                   ; 'D'
        OUT     (PIT_CTL),A
        IN      A,(PIT_C1)
        LD      C,A
        IN      A,(PIT_C1)
        CP      0A8h
        JR      NZ,TIMST_SYNC
        LD      A,0C0h
        CP      C
        JR      NZ,TIMST_SYNC
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
        LD      (TIM_LAST+1),BC
        POP     BC
        RET
TIMRD:  RST     28h
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
TIM_LAST:
        LD      HL,0000h
        XOR     A
        SBC     HL,BC
        LD      A,L
        RRCA
        CALL    C,TIM_HALFDAY
        PUSH    DE
        LD      A,D
        OR      E
        JR      NZ,TIM_CALC
        LD      DE,0A8C0h
TIM_CALC:
        LD      HL,0A8C0h
        SBC     HL,DE
TIM_START:
        LD      DE,0000h
        ADD     HL,DE
        JR      C,TIM_WRAP
        PUSH    HL
        LD      DE,0A8C0h
        SBC     HL,DE
        JR      C,TIM_NOWRAP
        POP     AF
TIM_RESULT:
        EX      DE,HL
TIM_PM: LD      A,00h
        XOR     01h
        POP     HL
        LD      BC,0001h
        SBC     HL,BC
        JR      NZ,TIM_RET
        XOR     01h
TIM_RET:
        POP     HL
        POP     BC
        RET
TIM_NOWRAP:
        POP     DE
        POP     HL
        LD      A,(TIM_PM+1)
        JR      TIM_RET
TIM_WRAP:
        LD      DE,5740h
        ADD     HL,DE
        JR      TIM_RESULT
; <- aufgerufen von 0A35h
TIM_HALFDAY:
        LD      (TIM_LAST+1),BC
        LD      A,(TIM_PM+1)
        XOR     01h
        LD      (TIM_PM+1),A
        RET
;  BELL – Tastenklick (30h Perioden, Halbperiode 60h). TONE: BC Perioden
;  mit Halbperiode HL über Port C Bit 2 (Bit-Set/Reset 05h/04h); RYTHM
;  setzt den Operanden von TONE_LP für Pausen auf 04h (stumm).
; <- aufgerufen von 0C33h
BELL:   RST     20h
        LD      BC,0030h
        LD      HL,0060h
; <- aufgerufen von 0BD9h
TONE:   RST     20h
        RST     28h
TONE_LP:
        LD      A,05h
        CALL    TONE_HALF
        LD      A,04h
        CALL    TONE_HALF
        DEC     BC
        LD      A,C
        OR      B
        JR      NZ,TONE_LP
        RET
; <- aufgerufen von 0A8Bh, 0A90h
TONE_HALF:
        OUT     (PPI_CTL),A
        LD      D,H
        LD      E,L
TONE_DLY:
        DEC     DE
        LD      A,D
        OR      E
        JR      NZ,TONE_DLY
        RET
;  MELDY – Melodie aus Text DE spielen, bis 0Dh oder "*": Noten C D E F G
;  A B, R = Pause, "#" davor = erhöht, "+"/"-" davor = eine Oktave höher/
;  tiefer (nur für diese Note, OCTAVE), Ziffer 0-9 dahinter = Länge
;  (NOTE_LEN, gilt bis zur nächsten Ziffer). BREAK beendet (C).
MELDY:  RST     20h
        LD      A,02h
        LD      (OCTAVE+1),A
MELDY_LP:
        LD      A,(DE)
        CP      0Dh
        RET     Z
        CP      2Ah                     ; '*'
        RET     Z
        CP      2Dh                     ; '-'
        JR      Z,MELDY_DOWN
        CP      2Bh                     ; '+'
        JR      Z,MELDY_UP
        LD      HL,NOTE_TAB
        CP      23h                     ; '#'
        LD      A,00h
        JR      NZ,MELDY_NOTE
        LD      HL,NOTE_SHARP
        INC     A
        INC     DE
MELDY_NOTE:
        LD      (NOTE_SHFLAG+1),A
        CALL    NOTE_FIND
        JR      C,MELDY_LP
        CALL    RYTHM
        LD      A,02h
        LD      (OCTAVE+1),A
        RET     C
        JR      MELDY_LP
MELDY_DOWN:
        LD      A,03h
MELDY_OCT:
        LD      (OCTAVE+1),A
        INC     DE
        JR      MELDY_LP
MELDY_UP:
        LD      A,01h
        JR      MELDY_OCT
; <- aufgerufen von 0AC9h
NOTE_FIND:
        PUSH    BC
        LD      B,08h
        LD      A,(DE)
NOTE_FIND_LP:
        CP      (HL)
        JR      Z,NOTE_FOUND
        INC     HL
        INC     HL
        INC     HL
        DJNZ    NOTE_FIND_LP
        SCF
        INC     DE
        POP     BC
        RET
NOTE_FOUND:
        LD      A,B
        LD      (NOTE_IDX+1),A
        INC     HL
        PUSH    DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        LD      A,H
        OR      L
        JR      Z,NOTE_SETPER
OCTAVE: LD      A,00h
        DEC     A
        JR      Z,NOTE_HIGH
        DEC     A
        JR      Z,NOTE_SETPER
        ADD     HL,HL
NOTE_SETPER:
        LD      (NOTE_PERIOD+1),HL
        POP     DE
        INC     DE
        LD      A,(DE)
        LD      B,A
        AND     0F0h
        CP      30h                     ; '0'
        JR      Z,NOTE_NEWLEN
NOTE_LENGTH:
        LD      A,00h
        JR      NOTE_DUR
NOTE_NEWLEN:
        INC     DE
        LD      A,B
        AND     0Fh
        LD      (NOTE_LENGTH+1),A
NOTE_DUR:
        LD      C,A
        LD      B,00h
        LD      HL,NOTE_LEN
        ADD     HL,BC
        PUSH    DE
        LD      E,(HL)
        LD      D,B
        LD      A,(TEMPO)
        LD      B,A
        LD      H,D
        LD      L,D
NOTE_MUL:
        ADD     HL,DE
        DJNZ    NOTE_MUL
        POP     DE
        POP     BC
        LD      B,H
        LD      C,L
        XOR     A
        RET
NOTE_HIGH:
        SRL     H
        RR      L
        JR      NOTE_SETPER
;  NOTE_TAB / NOTE_SHARP: je Note Buchstabe und Halbperiode (16 Bit),
;  C D E F G A B R; NOTE_LEN: Längen 0-9 (mal TEMPO); NOTE_CYC: Perioden
;  je Zeiteinheit in umgekehrter Reihenfolge (R, B, A ... C), normal und
;  erhöht, damit die Dauer nicht von der Tonhöhe abhängt.
NOTE_TAB:
        DEFB    43h,25h,01h,44h,05h,01h,45h,0E9h
        DEFB    00h,46h,0DCh,00h,47h,0C3h,00h,41h
        DEFB    0AEh,00h,42h,9Bh,00h,52h,00h,00h
NOTE_SHARP:
        DEFB    43h,15h,01h,44h,0F6h,00h,45h,0DCh
        DEFB    00h,46h,0CFh,00h,47h,0B8h,00h,41h
        DEFB    0A4h,00h,42h,92h,00h,52h,00h,00h
NOTE_LEN:
        DEFB    01h,02h,03h,04h,06h,08h,0Ch,10h,18h,20h
NOTE_CYC:
        DEFB    08h,0Fh,0Dh,0Ch,0Bh,0Ah,09h,08h
        DEFB    10h,0Eh,0Dh,0Bh,0Bh,0Ah,08h
;  RYTHM – Note spielen: Dauer aus Länge, TEMPO und NOTE_CYC (Oktave
;  berücksichtigt), dann TONE; Pause (Halbperiode 0) als stummer Ton.
;  BREAK -> C.
; <- aufgerufen von 0ACEh
RYTHM:  CALL    KBSET
        CALL    BRK
RYTHMB: RET     C
        RST     20h
        PUSH    BC
        LD      HL,NOTE_CYC-1
NOTE_SHFLAG:
        LD      A,00h
        OR      A
        JR      Z,NOTE_IDX
        LD      BC,0007h
        ADD     HL,BC
NOTE_IDX:
        LD      A,00h
        LD      C,A
        CP      01h
        JR      NZ,RYTHM_FACT
        LD      A,02h
        LD      (OCTAVE+1),A
RYTHM_FACT:
        ADD     HL,BC
        LD      B,(HL)
        LD      A,(OCTAVE+1)
        DEC     A
        JR      Z,RYTHM_LOW
        DEC     A
        JR      Z,RYTHM_CYC
        SRL     B
        JR      RYTHM_CYC
RYTHM_LOW:
        SLA     B
RYTHM_CYC:
        POP     DE
        LD      HL,0000h
RYTHM_MUL:
        ADD     HL,DE
        DJNZ    RYTHM_MUL
        LD      B,H
        LD      C,L
        RST     28h
NOTE_PERIOD:
        LD      HL,0000h
        LD      A,H
        OR      L
        JP      NZ,TONE_LP
        PUSH    HL
        LD      A,04h
        LD      (TONE_LP+1),A
        LD      HL,0125h
        CALL    TONE
        LD      A,05h
        LD      (TONE_LP+1),A
        POP     HL
        RET
;  KNUMBS: Grenze der Eingabelänge für GETL (ST setzt 27h); KNUMBS+1:
;  zuletzt gelesene Taste (für die Wiederholung).
KNUMBS: DEFB    50h,1Eh

; ------------------------------------------------------------------------------
;  GETL – Zeileneingabe mit Bildschirmeditor; GETCRT
; ------------------------------------------------------------------------------
;  GETL – Zeile mit Bildschirmeditor nach (DE) lesen, Ende 0Dh. Erst
;  warten, bis BREAK und CR losgelassen sind; Cursor blinkt (CSR_BLINK).
;  Je Taste Klick (außer CLICKOFF), dann: 01h-06h nach Grafik-Umschaltung
;  (KEY_GRFLAG) und Zeichen ab 1Ah über ?DSP; 10h-19h Funktionstaste
;  (Text aus FKTAB, bei KYBDA Bit 2 Text 11-20; 7Fh im Text = CR);
;  0Dh: logische Zeile übernehmen (Länge auf KNUMBS - 1 begrenzt,
;  Leerzeichen am Ende entfernt); 0Bh (BREAK): 0Bh, 0Dh; sonst ?DPCT.
;  Wiederholung nach REPTCT+1 x REPTCT Abfragen, danach alle REPTCT.
;  GETCRT – logische Zeile unter dem Cursor ohne Eingabe nach (DE) holen;
;  bei D Bit 7 mit PIO Port A Bit 6 gesetzt (Bedeutung nicht geklärt).
; <- aufgerufen von 00F0h
GETL:   RST     20h
        PUSH    AF
        LD      A,(CH4080)
        LD      C,A
        LD      A,(KNUMBS)
        DEC     A
        LD      B,0FFh
GETL_ROWS:
        INC     B
        SUB     C
        JR      NC,GETL_ROWS
        LD      A,B
        LD      (LLINE_MAX+1),A
        EXX
        CALL    GETL_MAIN
        EXX
        POP     AF
        RET
; <- aufgerufen von 0BFAh
GETL_MAIN:
        RST     20h
        EXX
        PUSH    DE
        EXX
        CALL    PUSHKI
        CALL    CSR_SAVE
GETL_FLUSH:
        CALL    KEY_GET
        CP      0Bh
        JR      Z,GETL_FLUSH
        CP      0Dh
        JR      Z,GETL_FLUSH
        LD      (KNUMBS+1),A
        CP      1Eh
        JP      NZ,GETL_REPEAT
GETL_WAIT:
        CALL    CSR_BLINK
        CALL    KEYKEY
GETL_KEY:
        CP      1Eh
        JR      Z,GETL_WAIT
        LD      (KNUMBS+1),A
        EXX
        LD      C,00h
        EXX
GETL_CHAR:
        LD      C,A
        LD      A,(CLICKOFF)
        OR      A
        CALL    Z,BELL
        CALL    CSR_RESTCH
        LD      A,C
        CP      01h
        JR      C,GETL_CTRLCHK
        CP      07h
        JR      NC,GETL_CTRLCHK
        LD      HL,KEY_GRFLAG
        BIT     6,(HL)
        JR      NZ,GETL_PUT
GETL_CTRLCHK:
        LD      C,A
        CP      1Ah
        JR      C,GETL_CTRL
GETL_PUT:
        CALL    ?DSP
GETL_NEXT:
        CALL    CSR_SAVE
        EXX
        LD      A,C
        EXX
        OR      A
        JP      Z,GETL_REPEAT
        CALL    KEY_HOLD
        JR      NC,GETL_KEY
        JR      GETL_CHAR
GETL_CTRL:
        BIT     4,A
        JR      NZ,GETL_FKEY
        CP      0Dh
        JR      Z,GETL_ENTER
        CP      0Bh
        JR      Z,GETL_BREAK
        CALL    ?DPCT
        JR      GETL_NEXT
GETL_BREAK:
        POP     HL
        LD      (HL),0Bh
        INC     HL
        LD      (HL),0Dh
        JP      LETNL
GETCRT: RST     20h
        PUSH    DE
GETL_ENTER:
        CALL    ??TOL
        CALL    LLINE_LEN
        LD      A,(KNUMBS)
        DEC     A
        CP      L
        JR      NC,GETL_COPY
        LD      L,A
GETL_COPY:
        PUSH    DE
        EX      (SP),HL
        POP     BC
        POP     DE
        PUSH    BC
        BIT     7,D
        JR      Z,GETL_TEXT
        RES     7,H
        IN      A,(PIO_AD)
        OR      0C0h
        CALL    VRAM_LDIRA
        JR      GETL_TRIM
GETL_TEXT:
        CALL    VRAM_LDIR
GETL_TRIM:
        POP     BC
        LD      B,C
        EX      DE,HL
        INC     B
GETL_TRIM_LP:
        LD      (HL),0Dh
        DEC     HL
        LD      A,(HL)
        CP      20h                     ; ' '
        JR      NZ,GETL_DONE
        DJNZ    GETL_TRIM_LP
GETL_DONE:
        JP      NL_DOWN
GETL_FKEY:
        AND     0Fh
        INC     A
        LD      HL,KYBDA
        BIT     2,(HL)
        JR      Z,GETL_FKSRCH
        ADD     A,0Ah
GETL_FKSRCH:
        LD      B,A
        LD      HL,FKTAB
        LD      D,H
GETL_FKSKIP:
        LD      E,L
GETL_FKSKIPC:
        LD      A,(HL)
        INC     HL
        CP      0Dh
        JR      NZ,GETL_FKSKIPC
        DJNZ    GETL_FKSKIP
GETL_FKOUT:
        LD      A,(DE)
        CP      7Fh
        JR      Z,GETL_ENTER
        CP      0Dh
        JP      Z,GETL_NEXT
        CALL    PRNT
        INC     DE
        JR      GETL_FKOUT
;  CSR_RESTCH – Zeichen unter dem Cursor (Operand von CSR_UNDER) zurück-
;  schreiben. CSR_SAVE merkt es sich. CSR_BLINK – Blinktakt in B' (Startwert
;  CSR_BLINKCNT), Cursor 1Fh abwechselnd mit dem Zeichen (bei 1Fh mit
;  einem Leerzeichen).
; <- aufgerufen von 0C36h
CSR_RESTCH:
        PUSH    AF
        CALL    ?PONT
CSR_UNDER:
        LD      A,00h
        CALL    DSPW
        POP     AF
        RET
GETL_REPEAT:
        LD      A,(REPTCT+1)
        LD      E,A
GETL_REPLP:
        CALL    KEY_HOLD
        JP      NC,GETL_KEY
        DEC     E
        JR      NZ,GETL_REPLP
        EXX
        LD      C,01h
        EXX
        JP      GETL_CHAR
;  KEY_HOLD – C, solange dieselbe Taste REPTCT Abfragen lang gehalten wird.
; <- aufgerufen von 0C5Bh, 0CEDh
KEY_HOLD:
        PUSH    DE
        LD      A,(REPTCT)
        LD      E,A
KEY_HOLD_LP:
        CALL    KEY_SAME
        JR      NC,KEY_HOLD_RET
        DEC     E
        JR      NZ,KEY_HOLD_LP
KEY_HOLD_RET:
        POP     DE
        RET
; <- aufgerufen von 0D02h
KEY_SAME:
        CALL    KEY_GET
        PUSH    AF
        LD      A,(KNUMBS+1)
        LD      C,A
        POP     AF
        CP      C
        SCF
        RET     Z
        OR      A
        RET
; <- aufgerufen von 0C07h, 0C51h, 0D85h
CSR_SAVE:
        CALL    ?PONT
        CALL    DSPRED
        EXX
        LD      D,A
        LD      (CSR_UNDER+1),A
        JR      CSR_BLINKCNT
;  KEY_GET – neue Taste (GETKY) oder, solange die letzte Taste (KEYPOS) bei
;  unveränderten Sondertasten gehalten wird, deren Code (KNUMBS+1); sonst
;  1Eh.
; <- aufgerufen von 0C0Ah, 0D0Ch
KEY_GET:
        LD      HL,(KEYPOS)
        CALL    GETKY
        RET     NZ
        LD      (KEYPOS),HL
        LD      A,L
        OR      A
        CALL    NZ,KEY_ROWRD
        AND     L
        LD      A,1Eh
        RET     Z
        LD      A,(KYBDA)
        LD      L,A
        LD      H,0Bh
        CALL    KEY_ROWRD
        CP      L
        LD      A,1Eh
        RET     NZ
        LD      A,(KNUMBS+1)
        RET
; <- aufgerufen von 0D33h, 0D40h
KEY_ROWRD:
        IN      A,(PIO_AD)
        AND     0F0h
        OR      H
        OUT     (PIO_AD),A
        IN      A,(PIO_BD)
        IN      A,(PIO_BD)
        CPL
        RET
; <- aufgerufen von 0C1Dh, 0D88h
CSR_BLINK:
        EXX
        DEC     B
        EXX
        RET     NZ
        EXX
CSR_BLINKCNT:
        LD      B,40h
        LD      A,1Fh
        CP      D
        JR      NZ,CSR_SHOW
        LD      A,(CSR_UNDER+1)
        CP      1Fh
        JR      NZ,CSR_SHOW
        LD      B,10h
        LD      A,20h                   ; ' '
CSR_SHOW:
        LD      D,A
        EXX
        CALL    ?PONT
        JP      DSPW

; ------------------------------------------------------------------------------
;  ??KEY – auf eine Taste warten; TENTBL – Sonderfunktionen der Tastatur
; ------------------------------------------------------------------------------
;  ??KEY / KEY_WAIT – auf eine Taste warten (Cursor blinkt), Code in A.
??KEY:  RST     20h
        EXX
        CALL    KEY_WAIT
        EXX
        RET
; <- aufgerufen von 0D79h
KEY_WAIT:
        RST     20h
        CALL    PUSHKI
        CALL    KEYSCAN
        CALL    CSR_SAVE
KEY_WAIT_LP:
        CALL    CSR_BLINK
        CALL    KEYKEY
        CP      1Eh
        JR      Z,KEY_WAIT_LP
        JP      CSR_RESTCH
;  TENTBL: Funktionen der Tasten mit Index 0Ah-17h bei B Bit 2: 0Ah CHR80,
;  10h Rest der Zeile löschen, 11h Tabstopp setzen (TAB_SET), 12h Tabstopp
;  löschen, 13h alle löschen, 14h CHR40, 15h CHANGE; die übrigen nichts.
;  TAB_FIND: Z, wenn Spalte A in TABDAT steht (HL zeigt darauf).
TENTBL: DEFW    CHR80
        DEFW    NOP_RET
        DEFW    NOP_RET
        DEFW    NOP_RET
        DEFW    NOP_RET
        DEFW    NOP_RET
        DEFW    DELLN
        DEFW    TAB_SET
        DEFW    TAB_CLR
        DEFW    TAB_CLRALL
        DEFW    CHR40
        DEFW    CHANGE
        DEFW    NOP_RET
        DEFW    NOP_RET
TAB_SET:
        LD      A,(DSPXY)
        LD      C,A
        CALL    TAB_FIND
        RET     Z
        XOR     A
        CALL    TAB_FIND
        RET     NZ
        LD      (HL),C
        RET
TAB_CLR:
        LD      A,(DSPXY)
        CALL    TAB_FIND
        RET     NZ
        LD      (HL),00h
        RET
TAB_CLRALL:
        LD      B,10h
        LD      HL,TABDAT
        JP      ?CLER
; <- aufgerufen von 0689h, 0DB5h, 0DBAh, 0DC3h
TAB_FIND:
        LD      B,10h
        LD      HL,TABDAT
TAB_FIND_LP:
        CP      (HL)
        RET     Z
        INC     HL
        DJNZ    TAB_FIND_LP
        RET

; ------------------------------------------------------------------------------
;  CHANGE/?SWAP – Groß-/Kleinschreibung tauschen: vertauscht die je 7
;  Befehlsbytes bei KEY_CASE1 und KEY_CASE2 (ADD A,20h/CP 5Bh/RET C/
;  SUB 3Ah gegen ADD A,40h/CP 7Bh/RET C/SUB 5Ah) in KEYSCAN
; ------------------------------------------------------------------------------
CHANGE: RST     28h
        LD      HL,KEY_CASE1
        LD      DE,KEY_CASE2
        LD      B,07h
?SWAP:  LD      C,(HL)
        LD      A,(DE)
        LD      (HL),A
        LD      A,C
        LD      (DE),A
        INC     HL
        INC     DE
        DJNZ    ?SWAP
        XOR     A
        RET

; ------------------------------------------------------------------------------
;  PUSHR/PUSHR2 – Register sichern (Ziel von RST 20h)
; ------------------------------------------------------------------------------
;  PUSHR2: wie PUSHR, aber ohne DE.
PUSHR:  EX      (SP),IX
        PUSH    HL
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      HL,PUSHR_POP
        EX      (SP),HL
        JP      (IX)
PUSHR2: EX      (SP),IX
        PUSH    HL
        PUSH    BC
        PUSH    HL
        LD      HL,PUSHR_POP2
        EX      (SP),HL
        JP      (IX)
PUSHR_POP:
        POP     DE
PUSHR_POP2:
        POP     BC
        POP     HL
        POP     IX
        RET

; ------------------------------------------------------------------------------
;  DI_ – Interrupts sperren und Restroutine aufrufen (Ziel von RST 28h)
; ------------------------------------------------------------------------------
DI_:    PUSH    AF
        LD      A,I                     ; IFF2 -> Paritätsflag (PE = Interrupts waren frei)
        DI
        JP      PO,POP_AF_RET
        POP     AF
        EX      (SP),HL
        LD      (DI_CALL+1),HL            ; Rücksprungadresse = Fortsetzung der Routine
        POP     HL
DI_CALL:
        CALL    RESET                   ; Rest der aufrufenden Routine ausführen
        EI                              ; danach Interrupts wieder frei

; ------------------------------------------------------------------------------
;  KINT/PUSHKI/KINTON – Tastatur-Interrupt über PIO Port B
;  KINTF <> 0: Interrupt bei Tastendruck freigeschaltet (vermutlich als
;  Abbruchmöglichkeit; der Interrupt landet über IM 1 bei 0038h).
; ------------------------------------------------------------------------------
KINT:   PUSH    AF
KINT_SET:
        LD      A,(KINTF)
        OR      A
        JR      Z,POP_AF_RET
        IN      A,(PIO_AD)
        AND     0E0h
        OR      12h
        OUT     (PIO_AD),A
        LD      A,97h
        OUT     (PIO_BC),A
        XOR     A
        OUT     (PIO_BC),A
POP_AF_RET:
        POP     AF
        RET
; <- aufgerufen von 0611h, 0C04h, 0D7Fh
PUSHKI: LD      HL,KINTF
        LD      A,(HL)
        OR      A
        RET     Z
        LD      (HL),00h
        LD      A,03h
        OUT     (PIO_BC),A
        POP     HL
        CALL    .HL
KINTON: PUSH    AF
        LD      A,0FFh
        LD      (KINTF),A
        JR      KINT_SET
MSG_MONITOR:
        DEFB    "** Monitor SB-1511 **",0Dh
; <- aufgerufen von 0E7Dh, 0E83h
KEY_ROW:
        IN      A,(PIO_AD)
        AND     0F0h
        OR      D
        OUT     (PIO_AD),A
        IN      A,(PIO_BD)
        IN      A,(PIO_BD)
        RET
;  KEYSCAN – Tastaturmatrix abfragen: Zeile 0Bh (Sondertasten) nach B,
;  Zeilen 0Ah-00h prüfen, nur neu gedrückte Tasten zählen (KSTD = letzter
;  Stand je Zeile, KYBDA = Sondertasten). Nur Sondertasten geändert: je
;  nach Kombination und MODE 0Ch, 0Eh, 7Fh, 09h, 0Ah oder 0Fh, sonst 1Eh.
;  Mit Taste: Index Zeile * 8 + Spalte (KEY_CODE); B wird ergänzt aus MODE
;  (Bit 7 -> B3 invers, Bit 6 -> B0 Grafik, Bit 5 -> B1 klein, B1 -> B2).
;  Umsetzung über KEYTAB (normal), KEYTAB+1Eh (B2) bzw. KEYTAB+3Ch (Grafik,
;  Index unter 40h); Buchstaben werden bei KEY_CASE1/2 berechnet. Index
;  0Ah-17h mit B2: TENTBL; 18h: 1Bh/1Fh; 52h/53h: 05h/06h bzw. 07h/08h.
;  Mit B3 bekommen Zeichen 20h-7Eh Bit 7 (invers).
; <- aufgerufen von 0614h, 0D82h
KEYSCAN:
        RST     28h
        LD      HL,0000h
        LD      (KEYPOS),HL
        LD      HL,KSTD_LAST
        LD      D,1Bh
        CALL    KEY_ROW
        CPL
        LD      B,A
KEY_ROWLP:
        DEC     D
        CALL    KEY_ROW
        LD      E,A
        CPL
        AND     (HL)
..KEY:  LD      (HL),E
        DEC     HL
        LD      E,A
        OR      A
        JR      Z,KEY_ROWNEXT
        LD      (KEYPOS),DE
KEY_ROWNEXT:
        LD      A,D
        AND     0Fh
        JR      NZ,KEY_ROWLP
        LD      DE,(KEYPOS)
        LD      A,E
        OR      A
        JR      NZ,KEY_PRESSED
        LD      A,B
        CP      (HL)
        JR      Z,KEY_RET1E
        LD      (HL),A
        LD      HL,MODE
        CP      01h
        JR      Z,KEY_M01
        CP      02h
        JR      Z,KEY_M02
        CP      03h
        JR      Z,KEY_RET7F
        CP      05h
        JR      Z,KEY_RET09
        CP      06h
        JR      Z,KEY_RET0A
        CP      08h
        JR      Z,KEY_M08
        CP      0Ch
        JR      NZ,KEY_RET1E
        LD      A,0Ch
        RET
KEY_M01:
        BIT     6,(HL)
        JR      Z,KEY_RET1E
KEY_RET0E:
        LD      A,0Eh
        RET
KEY_M02:
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
KEY_M08:
        BIT     7,(HL)
        JR      Z,KEY_RET1E
        LD      A,0Fh
        RET
KEY_PRESSED:
        CALL    KEY_CODE
        BIT     3,B
        RET     Z
        CP      7Fh
        RET     NC
        CP      20h                     ; ' '
        RET     C
        OR      80h
        RET
; <- aufgerufen von 0EE5h
KEY_CODE:
        LD      A,E
        LD      E,00h
        OR      A
KEY_COLNUM:
        RRA
        JR      C,KEY_INDEX
        INC     E
        JR      KEY_COLNUM
KEY_INDEX:
        OR      A
        JR      NZ,KEY_RET1E
        LD      A,0Fh
        AND     D
        RLCA
        RLCA
        RLCA
        OR      E
        LD      E,A
        LD      D,00h
        LD      HL,MODE
        BIT     7,(HL)
        JR      Z,KEY_MODGR
        SET     3,B
KEY_MODGR:
        BIT     6,(HL)
        JR      Z,KEY_FLAGS
        SET     0,B
KEY_FLAGS:
        LD      HL,KEY_GRFLAG
        LD      (HL),00h
        BIT     0,B
        JR      Z,KEY_CLASS
        SET     6,(HL)
KEY_CLASS:
        CP      0Ah
        JR      C,KEY_NORMAL
        CP      18h
        JR      C,KEY_CTRL
        JR      Z,KEY_18
        CP      20h                     ; ' '
        JR      C,KEY_NORMAL
        LD      A,E
        CP      52h                     ; 'R'
        JR      Z,KEY_RS
        CP      53h                     ; 'S'
        JR      Z,KEY_RS
        LD      HL,MODE
        BIT     5,(HL)
        JR      Z,KEY_SHIFTCHK
        SET     1,B
KEY_SHIFTCHK:
        BIT     1,B
        JR      Z,KEY_SYMCHK
        SET     2,B
KEY_SYMCHK:
        CP      40h                     ; '@'
        JR      NC,KEY_SHIFTED
        BIT     0,B
        LD      HL,KEYTAB+3Ch
        JR      NZ,KEY_LOOKUP
KEY_SHIFTED:
        BIT     2,B
        JR      NZ,KEY_SHIFT
KEY_NORMAL:
        LD      HL,KEYTAB
        CP      21h                     ; '!'
        JR      C,KEY_LOOKUP
KEY_CASE1:
        ADD     A,20h
        CP      5Bh                     ; '['
        RET     C
        SUB     3Ah
        LD      E,A
KEY_LOOKUP:
        ADD     HL,DE
        LD      A,(HL)
        RET
KEY_SHIFT:
        LD      HL,KEYTAB+1Eh
        CP      21h                     ; '!'
        JR      C,KEY_LOOKUP
KEY_CASE2:
        ADD     A,40h
        CP      7Bh                     ; '{'
        RET     C
        SUB     5Ah
        LD      E,A
        JR      KEY_LOOKUP
KEY_CTRL:
        BIT     2,B
        JR      Z,KEY_NORMAL
        SUB     0Ah
        ADD     A,A
        LD      HL,TENTBL
        LD      E,A
        LD      D,00h
        ADD     HL,DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        CALL    .HL
        JP      KEY_RET1E
KEY_RS: SUB     52h
        ADD     A,A
        ADD     A,05h
        BIT     2,B
        RET     Z
        INC     A
        RET
KEY_18: BIT     2,B
        LD      A,1Bh
        RET     Z
        LD      A,1Fh
        RET
;  KEY_GRFLAG: Bit 6 = letzte Taste mit Grafik-Umschaltung (für GETL).
KEY_GRFLAG:
        DEFB    00h                     ; ?? |.|
;  CTL_09..CTL_0F – Modi in MODE setzen (Bit 5 klein, 6 Grafik, 7 invers)
;  und MODE nach PPI Port A (SETMODE).
CTL_0F: LD      HL,MODE
        RES     7,(HL)
SETMODE:
        LD      A,(HL)
        OUT     (PPI_A),A
        RET
CTL_0E: LD      HL,MODE
        RES     6,(HL)
        RES     5,(HL)
        JR      SETMODE
CTL_0C: LD      HL,MODE
        SET     7,(HL)
        RES     6,(HL)
        JR      SETMODE
CTL_0A: LD      HL,MODE
        SET     5,(HL)
        RES     6,(HL)
        JR      SETMODE
CTL_09: LD      HL,MODE
        RES     5,(HL)
        SET     6,(HL)
        RES     7,(HL)
        JR      SETMODE

; ------------------------------------------------------------------------------
;  Tastaturtabellen
; ------------------------------------------------------------------------------
;  KEYTAB: Zeichen je Tastenindex; dieselbe Tabelle dient ab +1Eh als
;  Shift- und ab +3Ch als Grafiktabelle (Indizes beginnen dort weiter
;  hinten, die Bereiche überlappen).
KEYTAB: DEFB    10h,11h,12h,13h,14h,15h,16h,17h
        DEFB    18h,19h,38h,39h,1Ah,2Eh,2Bh,2Dh
        DEFB    30h,31h,32h,33h,34h,35h,36h,37h
        DEFB    1Bh,20h,0Dh,02h,01h,04h,03h,0Bh
        DEFB    2Fh,5Eh,5Ch,3Fh,2Eh,2Ch,30h,31h
        DEFB    32h,33h,34h,35h,36h,37h,38h,39h
        DEFB    3Ah,3Bh,2Dh,40h,5Bh,1Eh,5Dh,1Eh
        DEFB    05h,07h,1Eh,1Eh,1Eh,1Eh,84h,7Eh
        DEFB    7Ch,82h,3Eh,3Ch,5Fh,21h,22h,23h
        DEFB    24h,25h,26h,27h,28h,29h,2Ah,2Bh
        DEFB    3Dh,60h,7Bh,1Eh,7Dh,1Eh,1Eh,1Eh
        DEFB    1Eh,1Eh,1Eh,1Eh,83h,98h,88h,86h
        DEFB    9Ah,9Eh,9Bh,99h,80h,89h,90h,8Dh
        DEFB    8Fh,92h,94h,8Ch,8Bh,97h,9Fh,96h
        DEFB    9Ch,8Ah,87h,95h,85h,9Dh,8Eh,5Eh
        DEFB    5Ch,81h,0FFh,91h
;  CMT_STOPAF – Laufwerk stoppen, Flags erhalten. CMT_SEEK – kurz warten,
;  dann Bandmarke suchen.
CMT_STOPAF:
        PUSH    AF
        CALL    MSTOP
        POP     AF
        RET
; <- aufgerufen von 026Ch, 0293h
CMT_SEEK:
        CALL    DEL1M
        JP      RDTMARK
;  Von der RB-Datei nicht belegt (FILL105F, FILL10FE, IBU24).
FILL105F:
;  Im PASCAL-Abbild stehen hier Speicherreste (Stand beim Sichern).
        DEFB    00h,00h,00h,80h,0FFh,0FFh,0FFh,7Fh
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h

; ==============================================================================
;  ARBEITSSPEICHER DES MONITORS
; ==============================================================================
;  TABDAT, MODE, DSPXY, MANG, FKAE, KYBDA, KSTD, KINTF, BUFER,
;  IBUFE (Kassetten-Header: NAME, SIZE, DTADR, EXADR) ...
;  TABDAT: 16 Tabulatorspalten (Vorgabe alle 5 Spalten), 0 = frei.
;  MODE: Kopie von PPI Port A (Bit 5 klein, 6 Grafik, 7 invers).
;  DSPXY/DSPXY1: Cursor Spalte/Zeile. MANG: je Bildschirmzeile Nummer der
;  Fortsetzung (0 = Anfang einer logischen Zeile).
TABDAT: DEFB    05h,0Ah,0Fh,14h,19h,1Eh,23h,28h  ; ?? |......#(|
        DEFB    2Dh,32h,37h,3Ch,41h,46h,4Bh,00h  ; ?? |-27<AFK.|
MODE:   DEFB    12h                     ; ?? |.|
DSPXY:  DEFB    00h                     ; ?? |.|
DSPXY1: DEFB    00h                     ; ?? |.|
MANG:   DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h         ; ?? |....|
;  FKAE: 1214h, vermutlich das Ende der Funktionstastentexte (FARE + 20 x
;  0Dh); kein gefundener Codepfad liest es. KYBDA: Stand der Sondertasten,
;  KSTD..KSTD_LAST: letzter Stand der Zeilen 00h-0Ah.
FKAE:   DEFB    14h,12h                 ; ?? |..|
KYBDA:  DEFB    00h                     ; ?? |.|
KSTD:   DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h                 ; ?? |..|
KSTD_LAST:
        DEFB    00h                     ; ?? |.|
KINTF:  DEFB    00h                     ; ?? |.|
FILL10FE:
;  Im PASCAL-Abbild stehen hier Speicherreste (Stand beim Sichern).
        DEFB    0FFh,0FFh
;  BUFER: Eingabepuffer des Monitors; ADR_IN, MEM_IN, NAME_IN: Positionen
;  hinter den Prompts ("x-adr.$", Adresse beim *M, "File name:").
BUFER:  DEFB    00h,00h,00h,00h,00h,00h,00h  ; ?? |.......|
ADR_IN: DEFB    00h                     ; ?? |.|
MEM_IN: DEFB    00h,00h                 ; ?? |..|
NAME_IN:
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h ; ?? |......|
;  IBUFE: Kassettenkopf (128 Bytes): Typ, NAME (17 Bytes), SIZE, DTADR,
;  EXADR, Rest.
IBUFE:  DEFB    00h                     ; ?? |.|
IBU1:   DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h  ; ?? |........|
        DEFB    00h                     ; ?? |.|
IBU18:  DEFB    00h,00h                 ; ?? |..|
DTADR:  DEFB    00h,00h                 ; ?? |..|
EXADR:  DEFB    00h,00h                 ; ?? |..|
;  Im PASCAL-Abbild stehen hier Speicherreste (Stand beim Sichern).
IBU24:  DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,23h,4Ch,49h,4Eh,45h,00h
        DEFB    06h,72h,00h,2Ah,4Eh,00h,00h,00h
        DEFB    00h,0Bh,0BEh,00h,2Eh,2Eh,4Bh,45h
        DEFB    59h,00h,0Eh,89h,03h,2Eh,41h,4Dh
        DEFB    50h,4Dh,00h,0Ah,55h,00h,2Eh,43h
        DEFB    32h,44h,41h,54h,0Ah,2Dh,00h,2Eh
        DEFB    43h,48h,23h,00h,00h,0Bh,98h,00h
        DEFB    2Eh,43h,48h,47h,31h,00h,0Fh,0Fh
        DEFB    00h,2Eh,43h,48h,47h,32h,00h,0Fh
        DEFB    33h,00h,2Eh,43h,53h,4Dh,44h,54h
        DEFB    03h,39h,00h,2Eh,44h,49h,00h,00h
        DEFB    00h,00h,05h,80h,2Eh,46h,4Ch,53h

; ------------------------------------------------------------------------------
;  FARE – Funktionstastenbelegung (FAREN = A0h Bytes)
; ------------------------------------------------------------------------------
;  FKTAB (= FARE): 20 Funktionstastentexte, je mit 0Dh abgeschlossen
;  (7Fh im Text = CR); Vorgabe leer.
FKTAB:  DEFB    0Dh,0Dh,0Dh,0Dh,0Dh,0Dh,0Dh,0Dh
        DEFB    0Dh,0Dh,0Dh,0Dh,0Dh,0Dh,0Dh,0Dh
        DEFB    0Dh,0Dh,0Dh,0Dh,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h



; ==============================================================================
;  PASCAL-INTERPRETER SB-4515
; ==============================================================================
        DEFS    93,0FFh

;  PAS_BOOT – Einsprung über GOOUT (00AEh) nach dem Laden.
PAS_BOOT:
        JP      PAS_INIT

; ------------------------------------------------------------------------------
;  PAS_START – Kaltstart: RAM-Ende suchen (ab 2FFFh in 1000h-Schritten
;  AAh/55h schreiben und lesen), Stapel dorthin, Bildschirm vorbereiten.
; ------------------------------------------------------------------------------
PAS_START:
        LD      BC,3118h                ; ohne Wirkung (BC wird gleich neu geladen)
        LD      HL,2FFFh                ; Speichertest: ab 2FFFh in 4K-Schritten
        LD      DE,1000h
        LD      BC,0AA55h
RAMTEST:
        LD      A,(HL)
        EX      AF,AF'
        LD      (HL),B
        LD      A,(HL)
        CP      B
        JR      NZ,L131D
        LD      (HL),C
        LD      A,(HL)
        CP      C
        JR      NZ,L131D
        EX      AF,AF'
        LD      (HL),A
        ADD     HL,DE
        JR      NC,RAMTEST
L131D:  XOR     A
        SBC     HL,DE
        LD      A,0FFh                  ; höchstens FFxxh
        CP      H
        JR      NC,L1326
        LD      H,A
L1326:  NOP
        LD      SP,HL
        LD      (RAM_END+1),HL
        XOR     A
        LD      D,A
        LD      E,A
        CALL    TIMST                   ; Uhr auf 0 stellen
        JP      PAS_COLD

; ------------------------------------------------------------------------------
;  PAS_READY – Warmstart nach Fehler/BREAK/Programmende: Ausgabe auf den
;  Bildschirm, Stapel neu, GETL-Patch setzen, "Ready." ausgeben.
;  CMD_LOOP – Kommandoschleife des Editors.
; ------------------------------------------------------------------------------
PAS_READY:
        LD      A,04h
        LD      (FILE_STATE+1),A
        LD      IX,TOKLEN_TAB
        LD      A,50h
        LD      (KNUMBS),A
        SUB     A
        LD      (OUT_PRT),A
        LD      HL,ARRAY_INDEX
        LD      (ARRAY_HOOK+1),HL
        LD      HL,(STACK_TOP)
        LD      SP,HL
        CALL    GETL_PATCH
        CALL    SET_BUFFERS
        LD      HL,TXT_START
        LD      (TXT_PTR),HL
        CALL    PR_INLINE
        DEFB    0Dh,"Ready.",0Dh
        DEFB    00h
        LD      HL,0000h
        LD      (LINE_NO),HL
        LD      (CUR_LINE),HL
        LD      (RUN_LINE_SAVE),HL
CMD_LOOP:
        LD      HL,(WORKBUF)
        LD      (HL),00h
        EI
        LD      BC,CMD_LOOP
        PUSH    BC
        CALL    BELL
        XOR     A
        LD      (OUT_PRT),A
        LD      (RUN_MODE),A
        LD      HL,(INBUF)
        CALL    GET_LINE
        CALL    SKIP_SPC
        CP      23h                     ; "#": Zeilennummern im Listing ein/aus
        JR      NZ,L139D
        LD      A,(PR_LINENO+1)
        CPL
        LD      (PR_LINENO+1),A
        RET
L139D:  CP      24h                     ; "$": Einrücken bei der Eingabe ein/aus
        JR      NZ,L13A9
        LD      A,(INDENT_MASK+1)
        CPL
        LD      (INDENT_MASK+1),A
        RET
L13A9:  CP      1Fh                     ; Pfeil
        JP      Z,PCMD_ARROW
        CALL    IS_DIGIT
        JR      NC,PCMD_LINENO
        CALL    IS_LETTER
        JP      C,ERR_40
        SUB     41h
        CALL    JP_INLINE_TAB           ; Buchstabe A-Z -> Kommando über CMD_TAB
CMD_TAB:
        DEFW    PCMD_A
        DEFW    PCMD_B
        DEFW    ERR_40
        DEFW    PCMD_D
        DEFW    PCMD_E
        DEFW    PCMD_F
        DEFW    PCMD_G
        DEFW    PCMD_H
        DEFW    PCMD_I
        DEFW    ERR_40
        DEFW    PCMD_K
        DEFW    PCMD_L
        DEFW    PCMD_M
        DEFW    PCMD_N
        DEFW    ERR_40
        DEFW    PCMD_P
        DEFW    PCMD_Q
        DEFW    PCMD_R
        DEFW    PCMD_S
        DEFW    PCMD_T
        DEFW    ERR_40
        DEFW    PCMD_V
        DEFW    ERR_40
        DEFW    ERR_40
        DEFW    ERR_40
        DEFW    PCMD_Z

;  LINE_GOTO – Zeiger auf Zeile HL setzen (vom Anfang aus zählen); DE bleibt
;  erhalten.
; <- aufgerufen von 140Dh, 1676h, 16BFh
LINE_GOTO:
        PUSH    HL
        CALL    PTR_TOP
        POP     HL
        PUSH    DE
        CALL    LINE_SKIP
        POP     DE
        RET

;  SKIP_DOT – Folgt ein "." (nach der Zeilennummer), überspringen.
; <- aufgerufen von 1406h, 1669h
SKIP_DOT:
        LD      A,(DE)
        CP      2Eh
        RET     NZ
        INC     DE
        RET

;  PCMD_LINENO – Zeile beginnt mit einer Nummer n: "n" allein löscht Zeile n,
;  "n Text" ersetzt Zeile n, "n" mit Pfeil (1Fh) setzt die Eingabe ab Zeile n
;  fort.
PCMD_LINENO:
        CALL    GET_DEC
        CALL    SKIP_DOT
        PUSH    DE
        CALL    SKIP_SPC
        CALL    LINE_GOTO
        LD      A,(DE)
        POP     BC
        CP      1Fh
        JP      Z,PCMD_ARROW
        LD      D,B
        LD      E,C
        CP      0Dh
        JP      NZ,L16B8
        LD      HL,0001h
        JP      DEL_LINES

;  GET_RANGE – Zeilenbereich "n", "n-m", "-m", "n-" oder leer lesen. Ergebnis:
;  Zeiger auf Zeile n, HL = Anzahl der Zeilen (4000h = bis zum Ende).
; <- aufgerufen von 1747h, 1766h
GET_RANGE:
        LD      HL,4000h
        INC     DE
        LD      BC,0000h
        CP      0Dh
        JR      Z,L1459
        CP      2Dh
        JR      Z,L1454
        DEC     DE
        CALL    IS_DIGIT
        JP      C,ERR_40
        CALL    GET_DEC
        PUSH    HL
        POP     BC
        CALL    GET_UPCHAR
        CP      0Dh
        JR      Z,L1459
        CP      2Dh
        CALL    SKIP_SPC
        CP      0Dh
        JR      NZ,L1454
        LD      HL,4000h
        JR      L1459
L1454:  PUSH    BC
        CALL    GET_NUM_EOL
        POP     BC
L1459:  OR      A
        SBC     HL,BC
        JP      C,ERR_40
        PUSH    HL
        CALL    PTR_TOP
        PUSH    BC
        POP     HL
        CALL    LINE_SKIP
        POP     HL
        RET

;  NEG_HL – HL = -HL.
; <- aufgerufen von 1956h, 2F5Ah
NEG_HL: SUB     A
        SUB     L
        LD      L,A
        LD      A,00h
        SBC     A,H
        LD      H,A
        RET

;  DIV16 – DE = DE / BC, HL = Rest (16 Bit ohne Vorzeichen).
; <- aufgerufen von 1964h
DIV16:  LD      HL,0000h
        LD      A,10h
L1477:  PUSH    AF
        EX      DE,HL
        ADD     HL,HL
        LD      A,E
        RLA
        LD      E,A
        LD      A,D
        RLA
        LDD
        EX      DE,HL
        LD      A,L
        SBC     A,C
        LD      L,A
        LD      A,H
        SBC     A,B
        LD      H,A
        JP      NC,L148D
        ADD     HL,BC
        DEC     DE
L148D:  INC     DE
        POP     AF
        DEC     A
        JP      NZ,L1477
        RET

;  GETL_INBUF – Zeile in den Eingabepuffer INBUF lesen (GETL).
; <- aufgerufen von 1A5Ch
GETL_INBUF:
        LD      DE,(INBUF)
        JP      GETL

;  LINE_DELETE – Zeile am Zeiger TXT_PTR aus dem Text entfernen (Rest
;  nachschieben). C = Zeiger am Textende.
; <- aufgerufen von 1751h
LINE_DELETE:
        LD      HL,(TXT_END)
        EX      DE,HL
        LD      HL,(TXT_PTR)
        CALL    CP_HL_DE
        CCF
        RET     C
        PUSH    DE
        PUSH    HL
        CALL    LINE_NEXT
        EX      DE,HL
        POP     HL
        LD      (TXT_PTR),HL
        LD      B,H
        LD      C,L
        POP     HL
        JP      L14BB
L14B7:  LD      A,(DE)
        LD      (BC),A
        INC     DE
        INC     BC
L14BB:  CALL    CP_HL_DE
        JP      NZ,L14B7
        LD      H,B
        LD      L,C
        LD      (TXT_END),HL
        RET

;  LINE_INSERT – BC Bytes ab HL vor der Zeile am Zeiger einfügen (Text
;  verschieben). C = kein Platz.
; <- aufgerufen von 16B1h
LINE_INSERT:
        PUSH    HL
        LD      HL,(TXT_LIMIT)
        EX      DE,HL
        LD      HL,(TXT_END)
        ADD     HL,BC
        CALL    CP_HL_DE
        POP     DE
        CCF
        RET     C
        PUSH    DE
        PUSH    BC
        LD      B,H
        LD      C,L
        EX      DE,HL
        LD      HL,(TXT_END)
        EX      DE,HL
        LD      (TXT_END),HL
        LD      HL,(TXT_PTR)
        JP      L14EC
L14E8:  DEC     DE
        DEC     BC
        LD      A,(DE)
        LD      (BC),A
L14EC:  CALL    CP_HL_DE
        JP      NZ,L14E8
        LD      H,B
        LD      L,C
        LD      (TXT_PTR),HL
        POP     BC
        POP     HL
L14F9:  LD      A,(HL)
        LD      (DE),A
        INC     HL
        INC     DE
        DEC     BC
        LD      A,B
        OR      C
        JP      NZ,L14F9
        RET

;  GET_NUM_EOL – Dezimalzahl nach HL lesen, danach muss die Zeile enden.
; <- aufgerufen von 1455h, 16FEh, 1718h
GET_NUM_EOL:
        CALL    SKIP_SPC
        CALL    GET_DEC

;  CHK_EOL – Leerzeichen überspringen; ist das nächste Zeichen nicht CR ->
;  ERR_40.
; <- aufgerufen von 151Ah, 15AFh, 162Bh, 1639h, 16C5h, 360Ch
CHK_EOL:
        CALL    SKIP_SPC
        CP      0Dh
        RET     Z
        JP      ERR_40
        DEFB    00h

;  PCMD_V – V – Verify: Kassettendatei mit dem Programm im Speicher
;  vergleichen. Teilt sich den Code mit PCMD_A (A = 0: Vergleich, A = 1:
;  Anhängen).
PCMD_V: XOR     A
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl

;  PCMD_A – A – Append: Datei vom Band suchen (Typ A0h, Name passend) und
;  hinter das Programm im Speicher laden.
PCMD_A: LD      A,01h
        OR      A
        PUSH    AF
        CALL    CHK_EOL
        CALL    GET_FILENAME
        PUSH    HL
        DI
L1522:  CALL    RDINF
        JR      C,L1560
        CALL    PR_FOUND
        LD      DE,IBUFE
        LD      A,(DE)
        CP      0A0h
        CALL    NZ,CMT_SKIPFILE
        JR      NZ,L1522
        POP     HL
        PUSH    HL
        CALL    CMP_FNAME
        CALL    NZ,CMT_SKIPFILE
        JR      NZ,L1522
        POP     HL
        LD      HL,(TXT_END)
        LD      (DTADR),HL
        LD      BC,(IBU18)
        ADD     HL,BC
        LD      DE,(TXT_LIMIT)
        CALL    CP_HL_DE
        JP      NC,ERR_39
        POP     AF
        JP      Z,CMT_VERIFY
        PUSH    HL
        CALL    PR_LOADING
        CALL    RDDAT
L1560:  JP      C,ERR_35
        POP     HL
        LD      (TXT_END),HL
        JR      L15AC

;  PCMD_S – S – Save: Programmtext als Datei vom Typ A0h auf Band schreiben.
PCMD_S: CALL    CHK_PROG
        CALL    GET_FILENAME
        PUSH    HL
        LD      HL,(TXT_END)
        LD      DE,TXT_START
        OR      A
        SBC     HL,DE
        LD      (IBU18),HL
        LD      (DTADR),DE
        LD      HL,0000h
        LD      (EXADR),HL
        LD      A,0A0h
        LD      HL,IBUFE
        LD      (HL),A
        POP     DE
        DEC     DE
        LD      B,11h
L1590:  INC     HL
L1591:  INC     DE
        LD      A,(DE)
        CP      22h
        JR      Z,L1591
        LD      (HL),A
        CP      0Dh
        JR      Z,L15A1
        DJNZ    L1590
        LD      (HL),0Dh
        DI
L15A1:  CALL    WRINF
        JR      C,L15A9
        CALL    WRDAT
L15A9:  JP      C,ERR_34
L15AC:  JP      LETNL

;  CHK_PROG – Zeilenende prüfen; ist kein Programm im Speicher -> ERR_48.
; <- aufgerufen von 1569h, 3B80h
CHK_PROG:
        CALL    CHK_EOL
        LD      HL,(TXT_END)
        LD      DE,TXT_START
        CALL    CP_HL_DE
        JP      Z,ERR_48
        RET

;  CMT_VERIFY – Band mit dem Programmtext vergleichen ("Verifying", "Verify
;  OK!").
CMT_VERIFY:
        LD      HL,TXT_START
        LD      (DTADR),HL
        LD      DE,MSG_VERIFYING
        CALL    PR_MSG_NAME
        CALL    VERFY
        JR      C,L15AC
        LD      DE,MSG_VERIFY_OK
        CALL    PR_MSG_NL
        JR      L15AC
MSG_FILENAME:
        DEFB    "Filename?",0Dh
MSG_FOUND:
        DEFB    "Found ",0Dh
MSG_LOADING:
        DEFB    "Loading ",0Dh
MSG_BREAK:
        DEFB    "*Break ",0Dh
MSG_VERIFYING:
        DEFB    "Verifying ",0Dh
MSG_VERIFY_OK:
        DEFB    "Verify OK!",0Dh

;  PCMD_I – I/ – IPL: PPI Port C Bit 3 zurücksetzen und HALT (Neustart über
;  den IPL).
PCMD_I: CALL    CHK_SLASH
        LD      A,06h
        OUT     (PPI_CTL),A
        HALT

;  PCMD_Q – Q/ – zurück in den Monitor.
PCMD_Q: CALL    CHK_SLASH
        JP      ST
OUT_PRT:
        DEFB    00h

;  PCMD_H – H – Listing auf den Drucker (sonst wie P).
PCMD_H: LD      A,01h
        LD      (OUT_PRT),A
        CALL    PR_3NL
        JP      PCMD_P

;  PCMD_Z – Z – Eingabe am Programmende fortsetzen.
PCMD_Z: INC     DE
        CALL    CHK_EOL
        CALL    PTR_TOP
        LD      HL,4000h
        CALL    LINE_SKIP
        JR      INPUT_LOOP

;  PCMD_B – B – Eingabe ab Zeile 0 (vor dem vorhandenen Programm).
PCMD_B: CALL    CHK_EOL
        CALL    PTR_TOP

;  INPUT_LOOP – Eingabeschleife: Zeilennummer zeigen, ggf. einrücken ($),
;  Zeile lesen und einfügen, bis eine leere Zeile kommt.
INPUT_LOOP:
        CALL    PRT_INIT
        CALL    PR_LINENO

;  INDENT_MASK – Operand: 00h = ohne, FFh = mit Einrückung (Kommando "$").
INDENT_MASK:
        LD      A,00h                   ; Operand wird zur Laufzeit gesetzt
        LD      HL,(WORKBUF)
        AND     (HL)
        LD      B,A
        INC     B
        JR      L1652
L164F:  CALL    PRNTS
L1652:  DJNZ    L164F
        LD      HL,(INBUF)
        PUSH    HL
        CALL    GET_LINE
        POP     DE
        CALL    SKIP_SPC
        CALL    IS_DIGIT
        JP      C,ERR_40
        PUSH    HL
        CALL    GET_DEC
        CALL    SKIP_DOT
        PUSH    DE
        LD      DE,(CUR_LINE)
        CALL    CP_HL_DE
        JR      Z,L1679
        CALL    LINE_GOTO
L1679:  POP     DE
        LD      A,(DE)
        POP     HL
        PUSH    DE
        CALL    SKIP_SPC
        POP     DE
        CP      0Dh
        RET     Z
        CALL    LINE_ENTER
        CALL    LINENO_INC
        JP      INPUT_LOOP

;  LINENO_CLR – D19E0 = 0 (Zeilennummer am Zeiger).
; <- aufgerufen von 16F1h
LINENO_CLR:
        PUSH    HL
        LD      HL,0000h
        JR      L1698

;  LINENO_INC – D19E0 um 1 erhöhen.
; <- aufgerufen von 1687h, 1711h, 1778h
LINENO_INC:
        PUSH    HL
        LD      HL,(CUR_LINE)
        INC     HL
L1698:  LD      (CUR_LINE),HL
        POP     HL
        RET

;  PCMD_ARROW – Pfeil (1Fh) am Zeilenanfang: CR allein -> Eingabe ab Zeiger,
;  sonst Zeile am Zeiger einfügen.
PCMD_ARROW:
        INC     DE
        PUSH    DE
        CALL    SKIP_SPC
        POP     DE
        CP      0Dh
        JP      Z,INPUT_LOOP

;  LINE_ENTER – Zeile ab DE in Token umsetzen (TOKENIZE) und vor der Zeile am
;  Zeiger einfügen.
; <- aufgerufen von 1684h, 16B8h
LINE_ENTER:
        CALL    TOKENIZE
        XOR     A
        SBC     HL,DE
        LD      B,H
        LD      C,L
        EX      DE,HL
        CALL    LINE_INSERT
        RET     NC
        JP      ERR_39
L16B8:  CALL    LINE_ENTER
        LD      HL,(CUR_LINE)
        INC     HL
        CALL    LINE_GOTO
        JP      LINE_DELETE

;  PCMD_M – M – freien Speicher anzeigen ("nnnnn Bytes").
PCMD_M: CALL    CHK_EOL

;  PR_FREE – Freien Speicher (D19E2 - TXT_END) dezimal mit "Bytes" ausgeben.
; <- aufgerufen von 18EDh
PR_FREE:
        LD      HL,(TXT_END)
        EX      DE,HL
        LD      HL,(TXT_LIMIT)
        XOR     A
        SBC     HL,DE
        LD      A,30h
        LD      (SM_LEADZERO+1),A
        LD      DE,2710h
        CALL    PR_DIGIT
        CALL    PR_FREE_NUM
        CALL    PR_INLINE
        DEFB    "Bytes",00h
        JP      LETNL

;  PR_FREE_NUM – HL fünfstellig ausgeben (Einsprung in PR_DEC4).
; <- aufgerufen von 16DDh
PR_FREE_NUM:
        PUSH    HL
        PUSH    HL
        JP      L1908

;  PTR_TOP – Zeiger auf Zeile 0 (TXT_START).
; <- aufgerufen von 13F3h, 1460h, 162Eh, 163Ch, 16FBh, 1738h
PTR_TOP:
        CALL    LINENO_CLR
        LD      HL,TXT_START
        LD      (TXT_PTR),HL
        RET

;  PCMD_T – T – (nicht im Handbuch) Zeiger auf den Anfang, dann wie N.
PCMD_T: CALL    PTR_TOP

;  PCMD_N – N n – Zeiger n Zeilen vorwärts, Zeile anzeigen.
PCMD_N: CALL    GET_NUM_EOL
L1701:  CALL    LINE_SKIP
        JP      Z,LIST_LINE
        RET     C

;  LINE_SKIP – Zeiger HL Zeilen vorwärts. C = Textende erreicht.
; <- aufgerufen von 13F8h, 1465h, 1634h, 1701h
LINE_SKIP:
        LD      A,H
        OR      L
        RET     Z
        PUSH    HL
        CALL    LINE_NEXT
        POP     HL
        RET     C
        CALL    LINENO_INC
        DEC     HL
        JP      LINE_SKIP

;  PCMD_L – L n – Zeiger n Zeilen zurück, Zeile anzeigen.
PCMD_L: CALL    GET_NUM_EOL
        LD      A,H
        OR      L
        JP      Z,LIST_LINE
        PUSH    HL
        LD      HL,(TXT_PTR)
        LD      DE,TXT_START
        CALL    CP_HL_DE
        POP     BC
        RET     C
        LD      HL,(CUR_LINE)
        XOR     A
        SBC     HL,BC
        JR      NC,L1737
        LD      HL,0000h
L1737:  PUSH    HL
        CALL    PTR_TOP
        POP     HL
        JP      L1701

;  PCMD_D – D n / D n-m – Zeilen löschen.
PCMD_D: CALL    SKIP_SPC
        CP      0Dh
        JP      Z,ERR_40
        CALL    GET_RANGE
        INC     HL

;  DEL_LINES – HL Zeilen am Zeiger löschen.
DEL_LINES:
        LD      A,H
        OR      L
        JP      Z,LIST_LINE
        PUSH    HL
        CALL    LINE_DELETE
        POP     HL
        RET     C
        DEC     HL
        JP      DEL_LINES

;  PRT_INIT – Port F4h = 0 (Druckerschnittstelle zurücksetzen, vermutlich).
; <- aufgerufen von 163Fh, 1760h
PRT_INIT:
        PUSH    AF
        XOR     A
        OUT     (0F4h),A
        POP     AF
        RET

;  PCMD_P – P / P n / P n-m – Listing auf den Bildschirm. Leertaste hält an,
;  BREAK bricht ab.
PCMD_P: CALL    PRT_INIT
        CALL    SKIP_SPC
        CALL    GET_RANGE
L1769:  PUSH    HL
        CALL    LIST_LINE
        POP     HL
        LD      A,H
        OR      L
        RET     Z
        DEC     HL
        PUSH    HL
        CALL    LINE_NEXT
        POP     HL
        RET     C
        CALL    LINENO_INC
        CALL    LIST_KEY
        JP      L1769

;  LIST_KEY – Taste während des Listings: BREAK -> Abbruch, Leertaste ->
;  anhalten bis zur nächsten Leertaste.
; <- aufgerufen von 177Bh
LIST_KEY:
        CALL    INKEY
        CP      0Bh
        JP      Z,BREAK_STOP
        CP      20h
        RET     NZ
L178C:  CALL    DELAY
        CALL    INKEY
        CP      20h
        JR      Z,L178C
L1796:  CALL    CHK_BREAK
        CALL    INKEY
        CP      20h
        JR      NZ,L1796

;  DELAY – Kurze Warteschleife (256 x 256 DJNZ).
; <- aufgerufen von 178Ch
DELAY:  PUSH    BC
        LD      B,00h
L17A3:  CALL    DELAY_B
        DJNZ    L17A3
        POP     BC
        RET

;  DELAY_B – Warteschleife mit B Durchläufen.
; <- aufgerufen von 17A3h
DELAY_B:
        PUSH    BC
L17AB:  DJNZ    L17AB
        POP     BC
        RET

;  LIMIT_ERR – Speichergrenze ungültig: alte Grenze zurück, ERR_13.
LIMIT_ERR:
        POP     HL
        LD      (STACK_TOP),HL
        JP      ERR_13

;  INKEY – Taste ohne Warten holen (GETKY), Register erhalten.
; <- aufgerufen von 1781h, 178Fh, 1799h, 2059h, 206Bh, 2774h
INKEY:  PUSH    HL
        PUSH    BC
        XOR     A
        CALL    NOKKEY
        CALL    GETKY
        POP     BC
        POP     HL
        RET

;  PCMD_E – E$ adr – Obergrenze des Speichers setzen (STACK_TOP); muss über
;  TXT_END + 438h und unter dem RAM-Ende liegen.
PCMD_E: CALL    SKIP_SPC
        CP      24h
        JP      NZ,ERR_37
        INC     DE
        CALL    SKIP_SPC
        CP      0Dh
        JP      Z,ERR_40
        LD      HL,(STACK_TOP)
        PUSH    HL
        LD      HL,STACK_TOP
        CALL    GET_HEX

;  RAM_END – Operand: RAM-Ende aus dem Speichertest.
RAM_END:
        LD      HL,0D000h               ; Operand wird zur Laufzeit gesetzt
        SBC     HL,BC
        JR      C,LIMIT_ERR
        LD      DE,0438h
        LD      HL,(TXT_END)
        ADD     HL,DE
        SBC     HL,BC
        JR      NC,LIMIT_ERR
        JP      PAS_READY

;  GET_HEX – Hexadezimalzahl ab DE nach BC und nach (HL) schreiben; Überlauf
;  -> ERR_13.
; <- aufgerufen von 17DAh
GET_HEX:
        PUSH    HL
        LD      HL,0000h
L17F6:  LD      A,(DE)
        CALL    IS_DIGIT
        JP      NC,L1809
        CP      41h
        JP      C,L1826
        CP      47h
        JP      NC,L1826
        SUB     07h
L1809:  SUB     30h
        PUSH    AF
        LD      A,H
        AND     0F0h
        JP      NZ,ERR_13
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        POP     AF
        ADD     A,L
        LD      L,A
        INC     DE
        JP      L17F6
        DEC     DE
        DEC     HL
        LD      (HL),00h
        INC     HL
        PUSH    HL
        CALL    GET_DEC
L1826:  LD      B,H
        LD      C,L
        POP     HL
        LD      (HL),C
        INC     HL
        LD      (HL),B
        INC     HL
        SUB     A
        RET

;  GET_DEC – Dezimalzahl ab DE nach HL; Überlauf -> ERR_13 (außer beim Lesen
;  mit Vorzeichen).
; <- aufgerufen von 1403h, 143Ah, 1507h, 1666h, 1823h, 227Bh, 290Ch, 35F0h
GET_DEC:
        LD      HL,0000h
L1832:  LD      A,(DE)
        CALL    IS_DIGIT
        RET     C
        LD      A,H
        AND     0F0h
        JP      NZ,ERR_13
        LD      B,H
        LD      C,L
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,BC
        ADD     HL,HL
        LD      A,(DE)
        INC     DE
        SUB     30h
        LD      C,A
        LD      B,00h
        ADD     HL,BC
        LD      A,H
        AND     A
        JP      P,L1832
        LD      A,(SM_NUMTYPE+1)
        OR      A
        JR      NZ,L1832
        JP      ERR_13

;  CHK_SLASH – Es muss "/" und dann das Zeilenende folgen (K/, I/, Q/), sonst
;  ERR_40.
; <- aufgerufen von 1610h, 1618h, 188Bh
CHK_SLASH:
        LD      A,(DE)
        CP      2Fh
        JP      NZ,ERR_40
        INC     DE
        JP      CHK_EOL

;  SET_BUFFERS – Puffer unterhalb von HL (= STACK_TOP) anlegen: WORKBUF = HL -
;  320h, INBUF = WORKBUF - 56h, D19E2 (Ende des Textbereichs) = INBUF - C8h.
; <- aufgerufen von 1353h, 1893h
SET_BUFFERS:
        LD      DE,0320h
        SBC     HL,DE
        LD      (WORKBUF),HL
        LD      DE,0056h
        SBC     HL,DE
        LD      (INBUF),HL
        LD      DE,00C8h
        SBC     HL,DE
        LD      (TXT_LIMIT),HL
        RET

;  PAS_COLD – Kaltstart mit HL = Stapelobergrenze: Laufzeit initialisieren,
;  dann PAS_NEW.
PAS_COLD:
        LD      (STACK_TOP),HL
        LD      SP,HL
        LD      HL,PAS_NEW
        LD      (SM_TRAN_CONT+1),HL
        CALL    TRAN_INIT
        JR      PAS_NEW

;  PCMD_K – K/ – Programm löschen (wie NEW).
PCMD_K: CALL    CHK_SLASH

;  PAS_NEW – Programm löschen, Kopfmeldung und freien Speicher ausgeben,
;  PAS_READY.
PAS_NEW:
        LD      HL,(STACK_TOP)
        LD      SP,HL
        OR      A
        CALL    SET_BUFFERS
        CALL    LETNL
        LD      HL,TXT_START
        LD      (TXT_END),HL
        CALL    PR_RULE
        CALL    PR_INLINE
        DEFB    0Dh,"  PASCAL interpreter SB-4515",0Dh
        DEFB    0Dh,"  Copyright (C) 1981 by SHARP Corp.",0Dh
        DEFB    0Dh,00h
        CALL    PR_RULE
        CALL    PR_FREE
        JP      PAS_READY

;  PR_LINENO – Zeilennummer (D19E0) vierstellig mit "." ausgeben; Operand
;  00h/FFh schaltet die Nummern beim Drucken ab (Kommando "#").
; <- aufgerufen von 1642h, 1DB2h
PR_LINENO:
        LD      A,00h                   ; Operand wird zur Laufzeit gesetzt
        AND     A
        JR      Z,L18FE
        LD      A,(OUT_PRT)
        CP      01h
        RET     Z
L18FE:  PUSH    DE
        PUSH    HL
        LD      HL,(CUR_LINE)

;  PR_DEC4 – HL dezimal vierstellig mit "." (führende Nullen als Leerzeichen);
;  Aufrufer legt HL zweimal auf den Stapel.
PR_DEC4:
        LD      A,30h
        LD      (SM_LEADZERO+1),A
L1908:  LD      DE,03E8h                ; 1000
        CALL    PR_DIGIT
        LD      DE,0064h
        CALL    PR_DIGIT
        LD      E,0Ah
        CALL    PR_DIGIT
        XOR     A
        LD      (SM_LEADZERO+1),A
        LD      E,01h
        CALL    PR_DIGIT
        LD      A,2Eh
        CALL    PR_CHAR
        POP     HL
        POP     DE
        RET

;  PR_DIGIT – Eine Dezimalstelle von HL zur Basis DE ausgeben (führende Null
;  als Leerzeichen, solange der Operand von L193D 30h ist).
; <- aufgerufen von 16DAh, 190Bh, 1911h, 1916h, 191Fh
PR_DIGIT:
        LD      A,30h
        AND     A
L192D:  SBC     HL,DE
        INC     A
        JR      NC,L192D
        DEC     A
        ADD     HL,DE
        CP      3Ah
        JP      NC,ERR_39
        CP      30h
        JR      NZ,L1946

;  SM_LEADZERO – Operand: 30h = führende Nullen als Leerzeichen ausgeben, 00h
;  = Ziffern ausgeben.
SM_LEADZERO:
        CP      00h                     ; Operand wird zur Laufzeit gesetzt
        JR      NZ,L1943
        LD      A,20h
L1943:  JP      PR_CHAR
L1946:  LD      (SM_LEADZERO+1),A
        JR      L1943
        LD      C,08h
        PUSH    DE
        LD      B,00h
        DEC     C
        LD      A,H
        AND     A
        JP      P,L195C
        CALL    NEG_HL
        LD      B,2Dh
        DEC     C
L195C:  LD      DE,000Ah
        PUSH    DE
        PUSH    BC
        LD      B,D
        LD      C,E
        EX      DE,HL
L1964:  CALL    DIV16
        LD      A,D
        OR      E
        JP      Z,L1972
        EX      (SP),HL
        DEC     L
        PUSH    HL
        JP      L1964
L1972:  POP     BC
L1973:  DEC     C
        LD      A,C
        AND     A
        JP      M,L1981
        LD      A,20h
        CALL    PR_CHAR
        JP      L1973
L1981:  LD      A,B
        CALL    PR_CHAR
        LD      E,L
L1986:  LD      A,E
        CP      0Ah
        POP     DE
        RET     Z
        ADD     A,30h
        CALL    PR_CHAR
        JP      L1986

;  PR_NEWLINE – Zeilenende ausgeben: 0Dh auf den Bildschirm, 0Ah auf den
;  Drucker.
PR_NEWLINE:
        LD      A,(OUT_PRT)
        OR      A
        JR      NZ,L199C
        LD      A,0Dh
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
L199C:  LD      A,0Ah

;  PR_CHAR – Zeichen A ausgeben: OUT_PRT = 0 Bildschirm (PRNT), sonst Drucker
;  (PRT_OUT).
; <- aufgerufen von 1924h, 197Bh, 1982h, 198Dh, 19C2h, 1A0Ah, 1DA4h
PR_CHAR:
        EX      AF,AF'
        LD      A,(OUT_PRT)
        OR      A
        JR      NZ,L19A9
        EX      AF,AF'
        JP      PRNT
L19A9:  EX      AF,AF'
        JP      PRT_OUT

;  CHK_BREAK – BREAK gedrückt -> "*Break" und PAS_READY.
; <- aufgerufen von 1796h
CHK_BREAK:
        CALL    BRKEY
        RET     NZ

;  BREAK_STOP – "*Break" ausgeben, zurück nach PAS_READY.
BREAK_STOP:
        LD      DE,MSG_BREAK
        CALL    PR_MSG_NL
L19B7:  JP      PAS_READY

;  RUN_END – Programmende: offene Datei schließen (RUN_CLOSE), PAS_READY.
RUN_END:
        CALL    RUN_CLOSE
        JR      L19B7
        LD      HL,(INBUF)
        CALL    PR_CHAR

;  GET_LINE – Zeile nach (HL) lesen (GETL); BREAK -> BREAK_STOP. DE zeigt auf
;  die Zeile.
; <- aufgerufen von 138Bh, 1658h
GET_LINE:
        PUSH    HL
        POP     DE
        CALL    GETL
        LD      A,(DE)
        CP      0Bh
        JR      Z,BREAK_STOP
        RET
        DEFB    00h,00h,00h,00h,00h,00h
LINE_NO:
        DEFB    00h,00h
RUN_LINE_SAVE:
        DEFB    00h
RUN_MODE:
        DEFB    00h
STACK_TOP:
        DEFB    00h,00h
INBUF:  DEFB    00h,00h
WORKBUF:
        DEFB    00h,00h
CUR_LINE:
        DEFB    00h,00h
TXT_LIMIT:
        DEFB    00h,00h
; <- aufgerufen von 13BBh
JP_INLINE_TAB:
        POP     HL
        JP      TAB_JUMP

;  SKIP_IDENT – Bezeichner (Buchstaben/Ziffern) überspringen.
; <- aufgerufen von 19F9h
SKIP_IDENT:
        LD      A,(DE)
        CP      0Dh
        JR      NZ,L19F0
        INC     DE
L19EE:  INC     DE
        LD      A,(DE)
L19F0:  CALL    IS_LETTER
        CALL    C,IS_DIGIT
        JR      NC,L19EE
        RET
        CALL    SKIP_IDENT
        CP      22h
        JP      Z,PR_QUOTED
        CP      27h
        RET     NZ

;  PR_QUOTED – Text bis zum Begrenzer A (" oder ') ausgeben.
PR_QUOTED:
        LD      B,A
        INC     DE
L1A06:  LD      A,(DE)
        CP      B
        INC     DE
        RET     Z
        CALL    PR_CHAR
        JR      L1A06
L1A0F:  CALL    PRT_LINE
        JP      PRT_NEWLINE

;  PR_3NL – Drei Leerzeilen (über L3310).
; <- aufgerufen von 1624h
PR_3NL: PUSH    BC
        LD      B,03h
L1A18:  PUSH    BC
        CALL    PRT_NEWLINE
        POP     BC
        DJNZ    L1A18
        POP     BC
        RET

;  PR_RULE – Trennlinie (39 x Zeichen 90h) ausgeben.
; <- aufgerufen von 189Fh, 18EAh
PR_RULE:
        LD      B,27h
L1A23:  LD      A,90h
        CALL    PRNT
        DJNZ    L1A23
        JP      LETNL

;  GETL_PATCH – GETL im Monitor umleiten: Einsprung auf ??TOL und JP in
;  GETL_DONE, damit Zeilen ab Cursorposition gelesen werden (vermutlich für
;  den Editor).
; <- aufgerufen von 1350h, 1FBDh
GETL_PATCH:
        PUSH    HL
        LD      HL,??TOL
        LD      (GETL_ENTER+1),HL
        LD      HL,GETL_DONE
        LD      (HL),0C3h
        POP     HL
        RET
L1A3B:  POP     HL
        INC     HL
        INC     HL
        INC     HL
        PUSH    HL
        LD      HL,(DSPXY)
        PUSH    HL
        CALL    ??TOL
        CALL    LLINE_LEN
        EX      (SP),HL
        LD      (DSPXY),HL
        POP     HL
        RET

;  CMT_SKIPFILE – Falsche Datei: SERSP, NZ setzen (weitersuchen).
; <- aufgerufen von 1530h, 153Ah, 27CEh, 27D9h
CMT_SKIPFILE:
        CALL    SERSP
        OR      0FFh
        RET

;  GET_FILENAME – "Filename?" ausgeben, Namen lesen; HL zeigt hinter den
;  Prompt.
; <- aufgerufen von 151Dh, 156Ch
GET_FILENAME:
        LD      DE,MSG_FILENAME
        CALL    PR_MSG_NL
        CALL    GETL_INBUF
        LD      A,(DE)
        CP      0Bh
        JP      Z,BREAK_STOP
        LD      HL,0009h
        ADD     HL,DE
        RET

; ------------------------------------------------------------------------------
;  KWTAB – Schlüsselworttabelle. Jedes Wort endet mit gesetztem Bit 7; der
;  Index ergibt das Token (erstes Wort = 60h). Ein "*" am Anfang macht ein
;  Wort unerreichbar (nicht implementiert), 80h steht für unbelegte Token.
;  Nach dem letzten Wort folgt 00h.
; ------------------------------------------------------------------------------
KWTAB_0:
        DEFB    00h
KWTAB:  DEFB    "*ROGRA",0CDh           ; 60h  *ROGRAM
        DEFB    "**TYP",0C5h            ; 61h  **TYPE
        DEFB    "VA",0D2h               ; 62h  VAR
        DEFB    "REA",0CCh              ; 63h  REAL
        DEFB    "INTEGE",0D2h           ; 64h  INTEGER
        DEFB    "CHA",0D2h              ; 65h  CHAR
        DEFB    "BOOLEA",0CEh           ; 66h  BOOLEAN
        DEFB    "**SE",0D4h             ; 67h  **SET
        DEFB    "*ACKE",0C4h            ; 68h  *ACKED
        DEFB    "BEGI",0CEh             ; 69h  BEGIN
        DEFB    "I",0C6h                ; 6Ah  IF
        DEFB    "WHIL",0C5h             ; 6Bh  WHILE
        DEFB    "REPEA",0D4h            ; 6Ch  REPEAT
        DEFB    "CAS",0C5h              ; 6Dh  CASE
        DEFB    "FO",0D2h               ; 6Eh  FOR
        DEFB    "T",0CFh                ; 6Fh  TO
        DEFB    "DOWNT",0CFh            ; 70h  DOWNTO
        DEFB    "O",0C6h                ; 71h  OF
        DEFB    "EN",0C4h               ; 72h  END
        DEFB    "UNTI",0CCh             ; 73h  UNTIL
        DEFB    "FALS",0C5h             ; 74h  FALSE
        DEFB    "TRU",0C5h              ; 75h  TRUE
        DEFB    0BBh                    ; 76h  ;
        DEFB    0AEh                    ; 77h  .
        DEFB    0ACh                    ; 78h  ,
        DEFB    ":",0BDh                ; 79h  :=
        DEFB    "**I",0CEh              ; 7Ah  **IN
        DEFB    0BCh                    ; 7Bh  <
        DEFB    "<",0BDh                ; 7Ch  <=
        DEFB    0BDh                    ; 7Dh  =
        DEFB    ">",0BDh                ; 7Eh  >=
        DEFB    0BEh                    ; 7Fh  >
        DEFB    "<",0BEh                ; 80h  <>
        DEFB    0ADh                    ; 81h  -
        DEFB    0ABh                    ; 82h  +
        DEFB    "O",0D2h                ; 83h  OR
        DEFB    "XO",0D2h               ; 84h  XOR
        DEFB    0AAh                    ; 85h  *
        DEFB    "AN",0C4h               ; 86h  AND
        DEFB    "DI",0D6h               ; 87h  DIV
        DEFB    "MO",0C4h               ; 88h  MOD
        DEFB    0AFh                    ; 89h  /
        DEFB    0A8h                    ; 8Ah  (
        DEFB    0DBh                    ; 8Bh  [
        DEFB    0DDh                    ; 8Ch  ]
        DEFB    0A9h                    ; 8Dh  )
        DEFB    "NO",0D4h               ; 8Eh  NOT
        DEFB    "READ",0A8h             ; 8Fh  READ(
        DEFB    "READLN",0A8h           ; 90h  READLN(
        DEFB    "WRITE",0A8h            ; 91h  WRITE(
        DEFB    "PWRITE",0A8h           ; 92h  PWRITE(
        DEFB    "WRITELN",0A8h          ; 93h  WRITELN(
        DEFB    "PWRITELN",0A8h         ; 94h  PWRITELN(
        DEFB    "CALL",0A8h             ; 95h  CALL(
        DEFB    "POKE",0A8h             ; 96h  POKE(
        DEFB    "COUT",0A8h             ; 97h  COUT(
        DEFB    "OUTPUT",0A8h           ; 98h  OUTPUT(
        DEFB    "TRAN",0A8h             ; 99h  TRAN(
        DEFB    "SYRE",0D4h             ; 9Ah  SYRET
        DEFB    "SYRET",0B2h            ; 9Bh  SYRET2
        DEFB    "TEMPO",0A8h            ; 9Ch  TEMPO(
        DEFB    "MUSIC",0A8h            ; 9Dh  MUSIC(
        DEFB    "RANGE",0A8h            ; 9Eh  RANGE(
        DEFB    "FKEY",0A8h             ; 9Fh  FKEY(
        DEFB    "GRAPH",0A8h            ; 0A0h  GRAPH(
        DEFB    "GSET",0A8h             ; 0A1h  GSET(
        DEFB    "GRSET",0A8h            ; 0A2h  GRSET(
        DEFB    "LINE",0A8h             ; 0A3h  LINE(
        DEFB    "BLINE",0A8h            ; 0A4h  BLINE(
        DEFB    "POSITION",0A8h         ; 0A5h  POSITION(
        DEFB    "PATTERN",0A8h          ; 0A6h  PATTERN(
        DEFB    "CURSOR",0A8h           ; 0A7h  CURSOR(
        DEFB    "FNAME",0A8h            ; 0A8h  FNAME(
        DEFB    "IMAGE",0A8h            ; 0A9h  IMAGE(
        DEFB    "COPY",0A8h             ; 0AAh  COPY(
        DEFB    "CLOS",0C5h             ; 0ABh  CLOSE
        DEFB    80h                     ; 0ACh  (frei)
        DEFB    80h                     ; 0ADh  (frei)
        DEFB    80h                     ; 0AEh  (frei)
        DEFB    80h                     ; 0AFh  (frei)
        DEFB    80h                     ; 0B0h  (frei)
        DEFB    80h                     ; 0B1h  (frei)
        DEFB    80h                     ; 0B2h  (frei)
        DEFB    "KE",0D9h               ; 0B3h  KEY
        DEFB    "REQT",0D2h             ; 0B4h  REQTR
        DEFB    "PEEK",0A8h             ; 0B5h  PEEK(
        DEFB    "CI",0CEh               ; 0B6h  CIN
        DEFB    "INPUT",0A8h            ; 0B7h  INPUT(
        DEFB    "TAN",0A8h              ; 0B8h  TAN(
        DEFB    "LOG",0A8h              ; 0B9h  LOG(
        DEFB    "RND",0A8h              ; 0BAh  RND(
        DEFB    "ABS",0A8h              ; 0BBh  ABS(
        DEFB    "ARCTAN",0A8h           ; 0BCh  ARCTAN(
        DEFB    "CHR",0A8h              ; 0BDh  CHR(
        DEFB    "COS",0A8h              ; 0BEh  COS(
        DEFB    "EXP",0A8h              ; 0BFh  EXP(
        DEFB    "LN",0A8h               ; 0C0h  LN(
        DEFB    "ODD",0A8h              ; 0C1h  ODD(
        DEFB    "ORD",0A8h              ; 0C2h  ORD(
        DEFB    "PRED",0A8h             ; 0C3h  PRED(
        DEFB    "SIN",0A8h              ; 0C4h  SIN(
        DEFB    "SQRT",0A8h             ; 0C5h  SQRT(
        DEFB    "TRUNC",0A8h            ; 0C6h  TRUNC(
        DEFB    "SUCC",0A8h             ; 0C7h  SUCC(
        DEFB    "FLOAT",0A8h            ; 0C8h  FLOAT(
        DEFB    "POINT",0A8h            ; 0C9h  POINT(
        DEFB    "POS",0C8h              ; 0CAh  POSH
        DEFB    "POS",0D6h              ; 0CBh  POSV
        DEFB    "CSR",0C8h              ; 0CCh  CSRH
        DEFB    "CSR",0D6h              ; 0CDh  CSRV
        DEFB    80h                     ; 0CEh  (frei)
        DEFB    80h                     ; 0CFh  (frei)
        DEFB    80h                     ; 0D0h  (frei)
        DEFB    80h                     ; 0D1h  (frei)
        DEFB    80h                     ; 0D2h  (frei)
        DEFB    80h                     ; 0D3h  (frei)
        DEFB    80h                     ; 0D4h  (frei)
        DEFB    80h                     ; 0D5h  (frei)
        DEFB    80h                     ; 0D6h  (frei)
        DEFB    "FIL",0C5h              ; 0D7h  FILE
        DEFB    "PROCEDUR",0C5h         ; 0D8h  PROCEDURE
        DEFB    "FUNCTIO",0CEh          ; 0D9h  FUNCTION
        DEFB    "THE",0CEh              ; 0DAh  THEN
        DEFB    "ELS",0C5h              ; 0DBh  ELSE
        DEFB    "D",0CFh                ; 0DCh  DO
        DEFB    0BAh                    ; 0DDh  :
        DEFB    0A5h                    ; 0DEh  %
        DEFB    0A7h                    ; 0DFh  '
        DEFB    0A2h                    ; 0E0h  "
        DEFB    "ARRA",0D9h             ; 0E1h  ARRAY
        DEFB    00h

;  TOKENIZE – Zeile ab DE in Token umsetzen, Ergebnis ab WORKBUF; HL = Ende.
;  Kleinbuchstaben außerhalb von Texten werden groß (UPCASE_LINE), Bezeichner
;  bekommen ein E2h-Token, Zahlen gehen über TOK_NUMBER.
; <- aufgerufen von 16A8h
TOKENIZE:
        LD      IX,TOKLEN_TAB
        LD      HL,(WORKBUF)
        PUSH    HL
        LD      B,0FFh
        DEC     DE
        CALL    UPCASE_LINE
L1C6C:  INC     DE
        LD      A,(DE)
        INC     B
        CP      20h
        JR      Z,L1C6C
        LD      (HL),B
        INC     HL
L1C75:  CALL    SKIP_SPC
        LD      (SM_KWPTR+1),DE
        CALL    IS_LETTER
        JR      C,L1CC2
L1C81:  INC     DE
        LD      A,(DE)
        CALL    IS_LETTER
        CALL    C,IS_DIGIT
        JR      NC,L1C81
        CP      28h
        JR      NZ,L1C9D
        PUSH    HL
        CALL    KW_MATCH
        POP     HL
        JR      NC,L1C99
        INC     DE
        JR      L1CBC
L1C99:  LD      A,(DE)
        AND     7Fh
        LD      (DE),A
L1C9D:  DEC     DE
        LD      A,(DE)
L1C9F:  PUSH    HL
        CALL    KW_MATCH
        INC     DE
        POP     HL
        JR      C,L1CBC
        LD      DE,(SM_KWPTR+1)
        EX      DE,HL
        XOR     A
L1CAD:  OR      (HL)
        LDI
        JP      P,L1CAD
        DEC     DE
        LD      A,(DE)
        AND     7Fh
        LD      (DE),A
        INC     DE
        EX      DE,HL
        LD      B,0E2h
L1CBC:  LD      (HL),B
        CALL    TOK_SKIP_HL
        JR      L1C75
L1CC2:  CP      0Dh
        JR      NZ,L1CCA
        POP     DE
        LD      (HL),A
        INC     HL
        RET
L1CCA:  CALL    IS_DIGIT
        JP      NC,TOK_NUMBER
        CP      22h
        JR      Z,L1D10
        CP      7Bh
        JR      Z,L1D30
        CP      3Ch
        JP      Z,L1D36
        CP      3Dh
        JP      Z,L1D46
        CP      3Eh
        JP      Z,L1D54
        CP      2Eh
        JP      Z,L1C9F
        CP      5Dh
        JR      Z,L1C9F
        CP      27h
        JP      C,ERR_45
        JR      Z,L1D14
        CP      40h
        JP      Z,ERR_45
        CP      5Ch
        JP      NC,ERR_45
        CP      3Ah
        JR      NZ,L1C9F
        INC     DE
        LD      A,(DE)
        CP      3Dh
        JR      NZ,L1C9D
        LD      (HL),79h
L1D0D:  INC     DE
        JR      L1D42
L1D10:  LD      (HL),0E0h
        JR      L1D17
L1D14:  LD      (HL),0DFh
        INC     HL
L1D17:  INC     HL
        INC     HL
        INC     HL
        EX      DE,HL
        EX      AF,AF'
        LD      A,0Dh
        EX      AF,AF'
        LDI
L1D21:  EX      AF,AF'
        CP      (HL)
        JP      Z,ERR_41
        EX      AF,AF'
        CP      (HL)
        LDI
        JR      NZ,L1D21
        EX      DE,HL
        JP      L1C75
L1D30:  LD      (HL),0DEh
        LD      A,7Dh
        JR      L1D17
L1D36:  INC     DE
        LD      A,(DE)
        CP      3Dh
        JR      Z,L1D6A
        CP      3Eh
        JR      Z,L1D66
        LD      (HL),7Bh
L1D42:  INC     HL
        JP      L1C75
L1D46:  INC     DE
        LD      A,(DE)
        CP      3Eh
        JR      Z,L1D62
        CP      3Ch
        JR      Z,L1D6A
        LD      (HL),7Dh
        JR      L1D42
L1D54:  INC     DE
        LD      A,(DE)
        CP      3Dh
        JR      Z,L1D62
        CP      3Ch
        JR      Z,L1D66
        LD      (HL),7Fh
        JR      L1D42
L1D62:  LD      (HL),7Eh
        JR      L1D0D
L1D66:  LD      (HL),80h
        JR      L1D0D
L1D6A:  LD      (HL),7Ch
        JR      L1D0D

;  KW_MATCH – Letztes Zeichen eines Worts mit Bit 7 markieren und in KWTAB
;  suchen.
; <- aufgerufen von 1C90h, 1CA0h
KW_MATCH:
        PUSH    DE
        OR      80h
        LD      (DE),A
        CALL    KW_FIND
        POP     DE
        RET

;  KW_FIND – Wort ab (Operand bei L1D7C) in KWTAB suchen. C = gefunden, B =
;  Token.
; <- aufgerufen von 1D72h
KW_FIND:
        LD      HL,KWTAB_0
        LD      B,5Fh

;  SM_KWPTR – Operand: Anfang des Worts, das KW_FIND sucht.
SM_KWPTR:
        LD      DE,0000h                ; Operand wird zur Laufzeit gesetzt
L1D7F:  PUSH    DE
        LD      A,0E7h
        INC     B
        CP      B
        JR      Z,L1D9C
L1D86:  INC     HL
        LD      A,(DE)
        INC     DE
        CP      (HL)
        JR      NZ,L1D92
        RLCA
        JR      NC,L1D86
        POP     AF
        SCF
        RET
L1D92:  LD      A,(HL)
        INC     HL
        AND     A
        JP      P,L1D92
        DEC     HL
        POP     DE
        JR      L1D7F
L1D9C:  POP     DE
        RET

;  PR_INLINE – Text hinter dem CALL bis 00h ausgeben (PR_CHAR), dahinter
;  weiter.
; <- aufgerufen von 135Ch, 16E0h, 18A2h
PR_INLINE:
        EX      (SP),HL
        LD      A,(HL)
        INC     HL
        EX      (SP),HL
        OR      A
        RET     Z
        CALL    PR_CHAR
        JR      PR_INLINE

;  RUN_ABORT – Zweimal BELL, zurück nach PAS_READY (Prozedur im Ausdruck u.
;  ä.).
RUN_ABORT:
        CALL    BELL
RUN_TE4_E4:
        CALL    BELL
        JP      PAS_READY

;  LIST_LINE – Zeile am Zeiger mit Nummer ausgeben (auf Bildschirm oder
;  Drucker).
; <- aufgerufen von 176Ah
LIST_LINE:
        CALL    PR_LINENO
        LD      DE,(TXT_END)
        LD      HL,(TXT_PTR)
        CALL    CP_HL_DE
        JP      NC,PR_NEWLINE
        CALL    DETOKENIZE
        LD      DE,LINEBUF
        LD      A,(OUT_PRT)
        OR      A
        JP      NZ,L1A0F
        CALL    MSGX
        JP      LETNL

;  DETOKENIZE – Zeile ab HL in Klartext nach 26DFh umsetzen (Einrückung,
;  Schlüsselwörter klein, Zahlen über LIST_NUMBER).
; <- aufgerufen von 1DC2h
DETOKENIZE:
        LD      IX,TOKLEN_TAB
        LD      DE,LINEBUF
        LD      A,20h
        LD      B,(HL)
        INC     HL
        INC     B
        JR      L1DE5
L1DE3:  LD      (DE),A
        INC     DE
L1DE5:  DJNZ    L1DE3
L1DE7:  LD      C,00h
        LD      A,(HL)
        LDI
        CALL    IS_LETTER
        JR      NC,L1E31
L1DF1:  CP      0Dh
        RET     Z
        CP      22h
        JR      Z,L1DFC
        CP      27h
        JR      NZ,L1E03
L1DFC:  CP      (HL)
L1DFD:  LDI
        JR      NZ,L1DFC
        JR      L1DE7
L1E03:  DEC     DE
        CP      0E6h
        JP      Z,LIST_NUMBER
        EX      DE,HL
        LD      (HL),20h
        EX      DE,HL
        PUSH    AF
        CALL    TOK_SKIP
        POP     AF
        CP      0DEh
        JP      Z,L1EA5
        JR      C,LIST_KEYWORD
        CP      0E1h
        JR      Z,LIST_KEYWORD
        JR      C,L1DE7
L1E1F:  LD      A,(HL)
        CP      8Fh
        CALL    C,KW_SPACE_AFTER
        JR      C,L1DE7
        CP      0DDh
        JR      Z,L1DE7
        LD      A,20h
        LD      (DE),A
        INC     DE
        JR      L1DE7
L1E31:  LD      A,(HL)
        LDI
        CALL    IS_LETTER
        CALL    C,IS_DIGIT
        JR      C,L1DF1
        JR      L1E31

;  LIST_KEYWORD – Token A als Schlüsselwort (klein) ausgeben, ggf. mit
;  Leerzeichen.
LIST_KEYWORD:
        PUSH    AF
        PUSH    HL
        SUB     5Fh
        LD      B,A
        LD      HL,KWTAB
        JR      L1E4E
L1E48:  XOR     A
L1E49:  OR      (HL)
        INC     HL
        JP      P,L1E49
L1E4E:  DJNZ    L1E48
L1E50:  LD      A,(HL)
        CALL    TO_LOWER
        LD      (DE),A
        INC     DE
        INC     HL
        JP      P,L1E50
        DEC     DE
        AND     7Fh
        CALL    TO_LOWER
        LD      (DE),A
        INC     DE
        POP     HL
        POP     AF
        CP      0DDh
        JP      Z,L1DE7
        CP      0D6h
        JR      NC,L1E1F
        CALL    KW_SPACE_AFTER
        JR      NC,L1E1F
        JP      L1DE7

;  KW_SPACE_AFTER – C = nach Token A kein Leerzeichen (Operatoren, Klammern,
;  Funktionen).
; <- aufgerufen von 1E22h, 1E6Dh
KW_SPACE_AFTER:
        CP      76h
        JR      C,L1EA3
        CP      7Ah
        RET     Z
        CP      83h
        RET     C
        CP      85h
        JR      Z,L1EA1
        CP      89h
        JR      C,L1EA3
        CP      8Eh
        RET     C
        CP      8Fh
        JR      C,L1EA3
        CP      0ABh
        RET     Z
        CP      0B3h
        RET     Z
        CP      0B4h
        RET     Z
        CP      0B6h
        RET     Z
        CP      0CAh
        RET     C
        CP      0CEh
        JR      C,L1EA3
L1EA1:  SCF
        RET
L1EA3:  AND     A
        RET
L1EA5:  LD      A,7Dh
        OR      A
        JP      L1DFD

;  TO_LOWER – Großbuchstaben in Kleinbuchstaben wandeln.
; <- aufgerufen von 1E51h, 1E5Dh
TO_LOWER:
        CALL    IS_LETTER
        JR      C,L1EB2
        OR      20h
L1EB2:  AND     A
        RET

;  IS_LOWER – NC = a-z.
; <- aufgerufen von 1EC5h
IS_LOWER:
        CP      61h
        RET     C
        CP      7Bh
        CCF
        RET

;  UPCASE_LINE – Kleinbuchstaben der Eingabezeile ab DE groß machen, außer in
;  Texten und Kommentaren.
; <- aufgerufen von 1C69h
UPCASE_LINE:
        CALL    CALL_SAVE
        JR      L1EC3
L1EC0:  AND     0DFh
        LD      (DE),A
L1EC3:  INC     DE
        LD      A,(DE)
        CALL    IS_LOWER
        JR      NC,L1EC0
        CP      27h
        JR      Z,L1EDD
        CP      22h
        JR      Z,L1EDD
        CP      7Bh
        JR      Z,L1EDB
        CP      0Dh
        JR      NZ,L1EC3
        RET
L1EDB:  LD      A,7Dh
L1EDD:  LD      B,A
L1EDE:  INC     DE
        LD      A,(DE)
        CP      B
        JR      Z,L1EC3
        CP      0Dh
        JR      NZ,L1EDE
        RET

;  LINE_NEXT – TXT_PTR auf die nächste Zeile (Token mit Operanden
;  überspringen). C = Textende.
; <- aufgerufen von 14A9h, 170Ch, 1773h
LINE_NEXT:
        LD      DE,(TXT_END)
        LD      HL,(TXT_PTR)
        CALL    CP_HL_DE
        CCF
        RET     C
        INC     HL
        LD      D,0Dh
        JR      L1EFE
L1EF9:  SUB     0D8h
        CALL    NC,TOK_SKIP_A
L1EFE:  LD      A,(HL)
        INC     HL
        CP      0DEh
        JR      Z,L1F15
        CP      0DFh
        JR      Z,L1F14
        CP      0E0h
        JR      Z,L1F15
        CP      0Dh
        JR      NZ,L1EF9
        LD      (TXT_PTR),HL
        RET
L1F14:  INC     HL
L1F15:  EX      DE,HL
        CALL    SET_LINK
        EX      DE,HL
        JR      L1EFE
; <- aufgerufen von 13AEh, 1434h, 165Fh, 17F7h, 1833h, 19F3h, 1C86h, 1CCAh ... (25)
IS_DIGIT:
        CP      30h
        RET     C
        CP      3Ah
        CCF
        RET
; <- aufgerufen von 13B3h, 19F0h, 1C7Ch, 1C83h, 1DECh, 1E34h, 1EABh, 3CB2h ... (16)
IS_LETTER:
        CP      41h
        RET     C
        CP      5Bh
        CCF
        RET
; <- aufgerufen von 138Eh, 140Ah, 1448h, 1504h, 150Ah, 165Ch, 167Dh, 169Fh ... (18)
SKIP_SPC:
        LD      A,(DE)
        CP      20h
        RET     NZ
        INC     DE
        JR      SKIP_SPC

;  TOK_SKIP_HL – Token (HL) holen und mit seinen Operandenbytes überspringen.
; <- aufgerufen von 1CBDh
TOK_SKIP_HL:
        LD      A,(HL)
        INC     HL

;  TOK_SKIP – Ist A ein Token ab D8h, HL um seine Operandenbytes (TOKLEN_TAB)
;  weiterstellen.
; <- aufgerufen von 1E0Eh, 3BE2h, 3F1Ch, 4467h, 576Dh
TOK_SKIP:
        SUB     0D8h
        RET     C

;  TOK_SKIP_A – Wie TOK_SKIP mit A = Token - D8h.
; <- aufgerufen von 1EFBh
TOK_SKIP_A:
        LD      (SM_TOKLEN+2),A

;  SM_TOKLEN – Operand (Displacement): Token - D8h als Index in TOKLEN_TAB.
SM_TOKLEN:
        LD      A,(IX+0)                ; Operand wird zur Laufzeit gesetzt

;  ADD_HL_A – HL = HL + A.
; <- aufgerufen von 3D99h
ADD_HL_A:
        ADD     A,L
        LD      L,A
        RET     NC
        INC     H
        RET

;  TOKLEN_TAB – Zahl der Operandenbytes hinter den Token D8h-E6h (über IX).
TOKLEN_TAB:
        DEFB    03h,04h,02h,02h,02h,02h,02h,03h
        DEFB    02h,06h,03h,03h,03h,03h,06h
; <- aufgerufen von 14A2h, 14BBh, 14D0h, 14ECh, 154Fh, 15B8h, 1671h, 1727h ... (13)
CP_HL_DE:
        LD      A,H
        CP      D
        RET     NZ
        LD      A,L
        CP      E
        RET
        DEFS    42,00h

;  ASK_FILENAME – "Filename?" ausgeben und den Namen vom Bildschirm lesen
;  (FNAME ohne Text).
; <- aufgerufen von 377Ah
ASK_FILENAME:
        LD      DE,MSG_FILENAME
        CALL    PR_MSG_NL

;  GETL_SCREEN – Zeile vom Bildschirm ab Cursor lesen (für READ von der
;  Tastatur); BREAK -> BREAK_STOP.
; <- aufgerufen von 230Fh
GETL_SCREEN:
        LD      A,0A0h
        LD      (KNUMBS),A
        LD      HL,(DSPXY)
        LD      E,H
        PUSH    HL
        CALL    MAGA
        LD      B,A
        INC     B
        POP     HL
        LD      A,(SCR_WIDTH+1)
        LD      D,A
        JR      L1F9F
L1F9C:  LD      A,D
        ADD     A,L
        LD      L,A
L1F9F:  DJNZ    L1F9C
        LD      DE,NUMBUF
        LD      H,00h
        ADD     HL,DE
        LD      (RD_PTR),HL
        PUSH    HL
        LD      HL,L1A3B
        LD      (GETL_ENTER+1),HL
        LD      HL,GETL_DONE
        LD      (HL),0C9h
        POP     HL
        CALL    GETL
        LD      A,(DE)
        CP      0Bh
        CALL    GETL_PATCH
        RET     NZ
        CALL    LETNL
        JP      BREAK_STOP

;  PR_MSG_NL – Neue Zeile (falls nötig) und Meldung DE bis 0Dh ausgeben.
; <- aufgerufen von 15D3h, 19B4h, 1A59h, 1F83h, 1FE3h, 2768h, 276Eh, 4746h
PR_MSG_NL:
        CALL    LETNL
        JP      MSGX
        DEC     DE

;  COPY_FNAME – Dateinamen ab HL+1 (ohne Anführungszeichen, max. 17 Zeichen)
;  nach DE+1 kopieren.
; <- aufgerufen von 2817h
COPY_FNAME:
        LD      B,11h
L1FD0:  INC     DE
L1FD1:  INC     HL
        LD      A,(HL)
        CP      22h
        JR      Z,L1FD1
        LD      (DE),A
        CP      0Dh
        RET     Z
        DJNZ    L1FD0
        LD      (HL),0Dh
        RET

;  PR_LOADING – "Loading" und Dateiname ausgeben.
; <- aufgerufen von 155Ah, 27DEh
PR_LOADING:
        LD      DE,MSG_LOADING

;  PR_MSG_NAME – Meldung DE und den Dateinamen aus dem Kassettenkopf ausgeben.
; <- aufgerufen von 15C8h
PR_MSG_NAME:
        CALL    PR_MSG_NL
        LD      DE,IBU1
        JP      JP_MSGX

;  PR_FOUND – "Found" und Dateiname ausgeben.
; <- aufgerufen von 1527h, 27C5h
PR_FOUND:
        LD      DE,MSG_FOUND
        JR      PR_MSG_NAME

;  CMP_FNAME – Gesuchten Namen (HL) mit dem Namen im Kopf vergleichen. Z =
;  gleich.
; <- aufgerufen von 1537h, 27D6h
CMP_FNAME:
        LD      A,(HL)
        CP      0Dh
        RET     Z
        LD      B,11h
L1FF7:  INC     DE
        LD      A,(DE)
        CP      (HL)
        RET     NZ
        INC     HL
        CP      0Dh
        RET     Z
        DJNZ    L1FF7                   ; Operand wird zur Laufzeit gesetzt
        CP      A
        RET

;  CALL_SAVE – Folgende Routine aufrufen, dabei HL, DE, BC, AF erhalten.
; <- aufgerufen von 1EBBh, 2FDFh
CALL_SAVE:
        EX      (SP),HL
        LD      (SM_CALLSAVE+1),HL
        POP     HL
        PUSH    HL
        PUSH    DE
        PUSH    BC
        PUSH    AF

;  SM_CALLSAVE – Operand: Ziel von CALL_SAVE.
SM_CALLSAVE:
        CALL    0000h                   ; Operand wird zur Laufzeit gesetzt
        POP     AF
        POP     BC
        POP     DE
        POP     HL
        RET
RUN_CIN:
        EXX
        CALL    ?PONT
        CALL    DSPRED
        LD      HL,(RT_SP)
        DEC     HL
        LD      (HL),A
        DEC     HL
        LD      (HL),02h
        LD      (RT_SP),HL
        EXX
        RET
RUN_PEEK:
        CALL    RUN_EXPR
        EXX
        LD      HL,(RT_SP)
        INC     HL
        LD      C,(HL)
        LD      (RT_SP),HL
        LD      (HL),02h
        INC     HL
        LD      B,(HL)
        LD      A,(BC)
        LD      (HL),A
        EXX
        JP      RUN_GETTOK
RUN_INPUT:
        CALL    RUN_EXPR
        EXX
        LD      HL,(RT_SP)
        INC     HL
        LD      C,(HL)
        LD      (RT_SP),HL
        LD      (HL),02h
        INC     HL
        LD      B,(HL)
        INI
        EXX
        JP      RUN_GETTOK
RUN_KEY:
        EXX
        LD      HL,(RT_SP)
        DEC     HL
        CALL    INKEY

;  SM_LASTKEY – Operand: zuletzt gelesene Taste (KEY liefert eine gehaltene
;  Taste nur einmal).
SM_LASTKEY:
        CP      00h                     ; Operand wird zur Laufzeit gesetzt
        JR      NZ,L206A
        XOR     A
L2061:  LD      (HL),A
        DEC     HL
        LD      (RT_SP),HL
        LD      (HL),02h
        EXX
        RET
L206A:  LD      B,A
        CALL    INKEY
        CP      B
        JR      NZ,L206A
        LD      (SM_LASTKEY+1),A
        JR      L2061
RUN_POKE:
        CALL    RUN_EXPR
        CALL    RUN_GETTOK
        CP      78h
        CALL    RUN_EXPR
        EXX
        LD      HL,(RT_SP)
        INC     HL
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        INC     HL
        INC     HL
        LD      A,(HL)
        INC     HL
        LD      (RT_SP),HL
        LD      (BC),A
        EXX
        JP      RUN_GETTOK
RUN_OUTPUT:
        CALL    RUN_EXPR
        CALL    RUN_GETTOK
        CP      78h
        CALL    RUN_EXPR
        EXX
        LD      HL,(RT_SP)
        INC     HL
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        INC     HL
        INC     HL
        LD      A,(HL)
        INC     HL
        LD      (RT_SP),HL
        OUT     (C),A
        EXX
        JP      RUN_GETTOK
RUN_CALL:
        CALL    RUN_EXPR
        CALL    RUN_GETTOK
        CALL    RUN_GETTOK
        CALL    VAR_ADDR
        PUSH    AF
        PUSH    DE
        PUSH    HL
        CALL    RT_PUSHVAR
        POP     HL
        CALL    RUN_GETTOK
        CALL    RUN_GETTOK
        CALL    VAR_ADDR
        PUSH    HL
        PUSH    AF
        PUSH    DE
        CALL    RT_PUSHVAR
        LD      B,03h
        LD      HL,(RT_SP)
L20DC:  INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        PUSH    DE
        DJNZ    L20DC
        LD      (RT_SP),HL
        POP     HL
        LD      (SM_USRCALL+1),HL
        POP     HL
        POP     DE

;  SM_USRCALL – Operand: Adresse des Maschinenprogramms bei CALL(.
SM_USRCALL:
        CALL    0000h                   ; Operand wird zur Laufzeit gesetzt
        PUSH    DE
        PUSH    HL
        LD      B,02h
        LD      HL,(RT_SP)
L20F7:  DEC     HL
        POP     DE
        LD      (HL),D
        DEC     HL
        LD      (HL),E
        DEC     HL
        LD      (HL),01h
        DJNZ    L20F7
        LD      (RT_SP),HL
        POP     DE
        POP     AF
        CALL    RT_POPVAR
        POP     HL
        POP     DE
        POP     AF
        PUSH    HL
        CALL    RT_POPVAR
        POP     HL
        RET
RUN_COUT:
        CALL    RUN_EXPR
        EXX
        LD      HL,(RT_SP)
        INC     HL
        LD      A,(HL)
        INC     HL
        LD      (RT_SP),HL
        CALL    ?PONT
        CALL    DSPW
        EXX
        JP      RUN_GETTOK
        PUSH    BC
        PUSH    DE
        CALL    ?PONT
        POP     DE
        POP     BC
        RET
        JP      LETNL

;  JP_PRNT – Sprungleiste zum Monitor: PRNT, MSG, MSGX.
; <- aufgerufen von 230Ch
JP_PRNT:
        JP      PRNT
        JP      MSG

;  JP_MSGX – Sprung nach MSGX.
; <- aufgerufen von 4757h, 4765h
JP_MSGX:
        JP      MSGX

;  BIN2BCD – DE binär in sechs Dezimalziffern (ASCII) ab HL wandeln.
; <- aufgerufen von 21D5h, 258Fh, 2F85h
BIN2BCD:
        PUSH    HL
        LD      HL,BCD_POW2
        LD      A,E
        AND     0Fh
        OR      A
        DAA
        RR      E
        RR      E
        RR      E
        RR      E
        LD      B,03h
L2150:  RR      E
        JR      NC,L2156
        ADD     A,(HL)
        DAA
L2156:  INC     HL
        DJNZ    L2150
        LD      C,A
        JR      NC,L215D
        INC     B
L215D:  RR      E
        JR      NC,L2169
        ADD     A,28h
        DAA
        LD      C,A
        LD      A,01h
        ADC     A,B
        LD      B,A
L2169:  LD      E,B
        LD      B,06h
L216C:  RR      D
        LD      A,(HL)
        INC     HL
        JR      NC,L2179
        ADD     A,C
        DAA
        LD      C,A
        LD      A,(HL)
        ADC     A,E
        DAA
        LD      E,A
L2179:  INC     HL
        DJNZ    L216C
        JR      NC,L217F
        INC     B
L217F:  RR      D
        JR      NC,L2192
        LD      A,84h
        ADD     A,C
        DAA
        LD      C,A
        LD      A,63h
        ADC     A,E
        DAA
        LD      E,A
        LD      A,01h
        ADC     A,B
        DAA
        LD      B,A
L2192:  POP     HL
        PUSH    HL
        CALL    PR_BCD2
        LD      B,E
        CALL    PR_BCD2
        LD      B,C
        CALL    PR_BCD2
        POP     HL
        RET

;  PR_BCD2 – BCD-Byte B als zwei ASCII-Ziffern nach (HL).
; <- aufgerufen von 2194h, 2198h, 219Ch
PR_BCD2:
        LD      A,B
        RRA
        RRA
        RRA
        RRA
        AND     0Fh
        OR      30h
        LD      (HL),A
        INC     HL
        LD      A,B
        AND     0Fh
        OR      30h
        LD      (HL),A
        INC     HL
        RET

;  BCD_POW2 – Zweierpotenzen in BCD für BIN2BCD.
BCD_POW2:
        DEFB    16h,"2dV",02h,12h,05h,24h,10h,48h,20h,96h,40h
        DEFB    92h,81h

;  LIST_NUMBER – Zahlkonstante (Token E6h) im Listing ausgeben: ganzzahlig
;  über BIN2BCD, Gleitkomma über L4CB6.
LIST_NUMBER:
        LD      A,(HL)
        CP      01h
        INC     HL
        JR      NZ,L21F0
        INC     HL
        INC     HL
        INC     HL
        PUSH    DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        LD      C,20h
        EX      (SP),HL
        PUSH    BC
        CALL    BIN2BCD
        POP     BC
        CALL    STRIP_ZEROS
        LD      E,L
        LD      D,H
        LD      B,06h
        LD      A,20h
L21E2:  CP      (HL)
        JR      Z,L21ED
        LDI
L21E7:  DJNZ    L21E2
L21E9:  POP     HL
        JP      L1E1F
L21ED:  INC     HL
        JR      L21E7
L21F0:  PUSH    DE
        LD      DE,NUMBUF
        PUSH    DE
        LD      BC,0005h
        LDIR
        POP     DE
        EX      (SP),HL
        EX      DE,HL
        PUSH    DE
        CALL    FP2STR
        POP     DE
        LD      A,(DE)
        LD      H,D
        LD      L,E
        CP      20h
        JR      NZ,L220A
        INC     HL
L220A:  XOR     A
        LD      (LST_DOTSEEN),A
        LD      A,(HL)
        CP      2Eh
        CALL    Z,LST_SETDOT
L2214:  LDI
        LD      A,(HL)
        CP      2Eh
        JR      NZ,L221E
        LD      (LST_DOTSEEN),A
L221E:  CP      0Dh
        JR      NZ,L2214
        LD      A,(LST_DOTSEEN)
        OR      A
        JR      NZ,L21E9
        LD      A,2Eh
        LD      (DE),A
        INC     DE
        CALL    LST_ZERO
        JR      L21E9
LST_DOTSEEN:
        DEFB    00h

;  LST_SETDOT – Merker "Punkt gesehen" setzen, dann "0" anhängen.
; <- aufgerufen von 2211h
LST_SETDOT:
        LD      (LST_DOTSEEN),A

;  LST_ZERO – "0" nach (DE) anhängen.
; <- aufgerufen von 222Ch
LST_ZERO:
        LD      A,30h
        LD      (DE),A
        INC     DE
        RET

;  STRIP_ZEROS – Führende Nullen der Zahl ab HL durch Leerzeichen ersetzen.
; <- aufgerufen von 21D9h
STRIP_ZEROS:
        PUSH    HL
        LD      A,30h
        LD      B,05h
L223F:  CP      (HL)
        JR      NZ,L2247
        LD      (HL),20h
        INC     HL
        DJNZ    L223F
L2247:  DEC     HL
        LD      (HL),C
        POP     HL
        RET

;  NUM_SCAN – Zahl im Quelltext ab DE prüfen: C = Gleitkomma (".", "E"), sonst
;  ganzzahlig.
; <- aufgerufen von 226Fh
NUM_SCAN:
        PUSH    DE
        DEC     DE
L224D:  INC     DE
        LD      A,(DE)
        CALL    IS_DIGIT
        JR      NC,L224D
        CP      2Eh
        JR      Z,L2269
        CP      45h
        JR      Z,L225F
L225C:  OR      A
        POP     DE
        RET
L225F:  INC     DE
        LD      A,(DE)
        CP      4Ch
        JR      Z,L225C
        CP      4Eh
        JR      Z,L225C
L2269:  SCF
        POP     DE
        RET

;  TOK_NUMBER – Zahl im Quelltext in eine Konstante (Token E6h) umsetzen.
TOK_NUMBER:
        LD      (HL),0E6h
        INC     HL
        CALL    NUM_SCAN
        JR      C,L2288
        LD      (HL),01h
        INC     HL
        INC     HL
        INC     HL
        INC     HL
        PUSH    HL
        CALL    GET_DEC
        EX      DE,HL
        EX      (SP),HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
L2283:  INC     HL
        POP     DE
        JP      L1C75
L2288:  LD      (HL),00h
        INC     HL
        PUSH    HL
        LD      HL,NUMBUF
        LD      A,(DE)
L2290:  CALL    PUT_DIGIT
        JR      NC,L2290
        CP      2Eh
        JR      NZ,L22E2
L2299:  CALL    PUT_DIGIT
        JR      NC,L2299
        CP      45h
        JR      NZ,L22CB
L22A2:  PUSH    HL
        LD      (HL),A
        INC     HL
        INC     DE
        LD      A,(DE)
        CP      2Dh
        JR      Z,L22B4
        CP      2Bh
        LD      A,0BCh
        JR      Z,L22B6
        DEC     DE
        JR      L22B6
L22B4:  LD      A,0BDh
L22B6:  LD      B,0FFh
L22B8:  INC     B
L22B9:  CALL    PUT_DIGIT
        JR      C,L22C4
        CP      30h
        JR      Z,L22B9
        JR      L22B8
L22C4:  LD      (HL),0Dh
        POP     HL
        LD      A,B
        OR      A
        JR      NZ,L22CD
L22CB:  LD      (HL),0Dh
L22CD:  EX      DE,HL
        POP     DE
        PUSH    HL
        PUSH    DE
        LD      HL,NUMBUF
        CALL    STR2FP
        LD      IX,TOKLEN_TAB
        POP     HL
        INC     HL
        INC     HL
        INC     HL
        INC     HL
        JR      L2283
L22E2:  CP      45h
        JR      Z,L22A2
        JP      ERR_32

;  PUT_DIGIT – Zeichen A nach (HL) schreiben, C = keine Ziffer.
; <- aufgerufen von 2290h, 2299h, 22B9h
PUT_DIGIT:
        LD      (HL),A
        INC     HL
        INC     DE
        LD      A,(DE)
        JP      IS_DIGIT
L22F0:  POP     DE
        POP     DE
L22F2:  POP     AF
        POP     DE
        POP     HL
        LD      HL,(READ_SPSAVE)
        LD      (RT_SP),HL

;  SM_READ_SP – Operand: Stapelzeiger für den Neubeginn von READ nach einer
;  Fehleingabe.
SM_READ_SP:
        LD      HL,0000h                ; Operand wird zur Laufzeit gesetzt
        PUSH    HL
        JR      L230A
READ_SPSAVE:
        DEFB    00h,00h
RUN_READ:
        CALL    CHK_FILEVAR
        JP      NZ,READ_FILE

;  READ_KBD – READ von der Tastatur: "?" ausgeben, Zeile vom Bildschirm holen,
;  Werte nacheinander den Variablen zuweisen (Trennzeichen ",", ERR_33).
; <- aufgerufen von 243Dh
READ_KBD:
        PUSH    HL
L230A:  LD      A,3Fh
        CALL    JP_PRNT
        CALL    GETL_SCREEN
L2312:  POP     HL
        LD      (SM_READ_SP+1),HL
        CALL    RUN_GETTOK
        CALL    VAR_ADDR
        PUSH    HL
        PUSH    DE
        PUSH    AF
        PUSH    HL
        PUSH    AF
        XOR     A
        LD      (SM_NUMTYPE+1),A
        POP     AF
        LD      HL,(RT_SP)
        LD      (READ_SPSAVE),HL
        POP     HL
        AND     0Fh
        LD      DE,(RD_PTR)
        CP      00h
        JR      Z,L238E
        CP      01h
        JR      Z,READ_INT
        EX      AF,AF'
        LD      A,(DE)
        INC     DE
        EX      AF,AF'
        LD      HL,(RT_SP)
        DEC     HL
        EX      AF,AF'
        LD      (HL),A
        DEC     HL
        LD      (HL),02h
L2348:  LD      (RT_SP),HL
L234B:  CALL    SKIP_SPC
        CP      2Ch
        JR      Z,L2359
        CP      0Dh
        JP      NZ,L22F2
        JR      L235A
L2359:  INC     DE
L235A:  LD      (RD_PTR),DE
        POP     AF
        POP     DE
        CALL    RT_POPVAR
        POP     HL
        CALL    RUN_GETTOK
        CP      78h
        RET     NZ
        PUSH    HL
        LD      HL,(RD_PTR)
        LD      A,(HL)
        CP      0Dh
        JR      NZ,L2312
        JR      L230A

;  READ_INT – Ganzzahl aus der Eingabe lesen.
READ_INT:
        EX      AF,AF'
        CALL    PARSE_INT
        PUSH    DE
        EX      DE,HL
        LD      HL,(RT_SP)
        DEC     HL
        LD      (HL),D
        DEC     HL
        LD      (HL),E
        DEC     HL
        LD      (HL),01h
        POP     DE
        JR      L2348
READ_SIGN:
        DEFB    00h
L2389:  LD      (READ_SIGN),A
        JR      L23A6
L238E:  EX      AF,AF'
        CALL    READ_NUMBER
        JR      L234B

;  READ_NUMBER – Zahl (mit Vorzeichen, Dezimalpunkt, Exponent) aus der Eingabe
;  ab DE in INTEGER oder REAL wandeln.
; <- aufgerufen von 238Fh
READ_NUMBER:
        XOR     A
        LD      (READ_SIGN),A
        CALL    SKIP_SPC
        PUSH    DE
        LD      B,0FFh
        CP      2Dh
        JR      Z,L2389
        CP      2Bh
        JR      NZ,L23AB
L23A6:  LD      A,30h
        LD      (DE),A
L23A9:  INC     DE
        LD      A,(DE)
L23AB:  INC     B
        CALL    IS_DIGIT
        JR      NC,L23A9
        CP      2Eh
        JP      NZ,L23BF
        DEC     B
L23B7:  INC     DE
        INC     B
        LD      A,(DE)
        CALL    IS_DIGIT
        JR      NC,L23B7
L23BF:  LD      C,A
        LD      A,B
        OR      A
        JP      Z,L2433
        LD      A,C
        CP      45h
        JR      NZ,L2405
        PUSH    DE
        LD      B,0FFh
        INC     DE
        LD      A,(DE)
        CP      2Dh
        JR      Z,L23F9
        CP      2Bh
        JR      Z,L23E8
        PUSH    DE
L23D8:  LD      A,(DE)
        CP      0Dh
        JR      Z,L23E2
        EX      AF,AF'
        LD      (DE),A
        INC     DE
        JR      L23D8
L23E2:  EX      AF,AF'
        LD      (DE),A
        INC     DE
        EX      AF,AF'
        LD      (DE),A
        POP     DE
L23E8:  LD      A,0BCh
L23EA:  LD      (DE),A
L23EB:  INC     B
L23EC:  INC     DE
        LD      A,(DE)
        CALL    IS_DIGIT
        JR      C,L23FD
        CP      30h
        JR      Z,L23EC
        JR      L23EB
L23F9:  LD      A,0BDh
        JR      L23EA
L23FD:  LD      A,B
        POP     BC
        OR      A
        JR      NZ,L2405
        LD      A,0Dh
        LD      (BC),A
L2405:  LD      (RD_PTR),DE

;  SM_NUMTYPE – Operand: Typ des gelesenen Werts; ungleich 0 erlaubt GET_DEC
;  Werte bis 32768.
SM_NUMTYPE:
        LD      A,00h                   ; Operand wird zur Laufzeit gesetzt
        OR      A
        LD      HL,(SM_FILE_VAR+1)
        JR      NZ,L2420
        LD      HL,(RT_SP)
        LD      DE,0006h
        OR      A
        SBC     HL,DE
        LD      (RT_SP),HL
        LD      (HL),00h
        INC     HL
L2420:  POP     DE
        PUSH    HL
        EX      DE,HL
        CALL    STR2FP
        POP     HL
        LD      A,(READ_SIGN)
        OR      A
        CALL    NZ,FP_FIXSIGN
        LD      DE,(RD_PTR)
        RET
L2433:  LD      A,(SM_NUMTYPE+1)
        OR      A
        JP      NZ,ERR_17
        JP      L22F0
RUN_READLN:
        CALL    READ_KBD
        CALL    LETNL
        RET
L2444:  CALL    EVAL_TEXT
        JP      L2537

;  EVAL_TEXT – Text "..." aus dem Programm nach 26DFh kopieren (Ausgabe von
;  Texten).
; <- aufgerufen von 2444h, 2C46h, 2E12h, 3788h, 37B6h, 3A45h, 3AB5h
EVAL_TEXT:
        LD      DE,LINEBUF
        INC     HL
        INC     HL
        LD      A,(HL)
        INC     HL
L2451:  CP      (HL)
        JR      Z,L2458
        LDI
        JR      L2451
L2458:  INC     HL
        EX      DE,HL
        LD      (HL),0Dh
        EX      DE,HL
        RET
RUN_WRITE:
        CALL    WRITE_SETUP
        LD      DE,MSG
        LD      (SM_WROUT+1),DE
        JP      L249F
; <- aufgerufen von 2478h
RUN_PWRITE:
        CALL    WRITE_SETUP
        LD      DE,PRT_TEXT
        LD      (SM_WROUT+1),DE
        JP      WRITE_ITEMS
RUN_PWRITELN:
        CALL    RUN_PWRITE
        JP      PRT_NEWLINE
RUN_WRITELN:
        CALL    WRITE_SETUP
        LD      DE,MSG
        LD      (SM_WROUT+1),DE
        CALL    WRITE_ITEMS
        JP      LETNL

;  WRITE_SETUP – Ausgaberoutine für Texte (DE) in L253B eintragen; Datei oder
;  Bildschirm.
; <- aufgerufen von 245Eh, 246Bh, 247Eh
WRITE_SETUP:
        EX      (SP),HL
        LD      (SM_WRSETUP+1),HL
        LD      HL,(SM_WROUT+1)
        EX      (SP),HL

;  SM_WRSETUP – Operand: Fortsetzung von WRITE_SETUP.
SM_WRSETUP:
        CALL    0000h                   ; Operand wird zur Laufzeit gesetzt
        POP     DE
        LD      (SM_WROUT+1),DE
        RET
L249F:  CALL    CHK_FILEVAR
        JP      NZ,WRITE_FILE

;  WRITE_ITEMS – Ausgabeliste von WRITE: Text oder Ausdruck, optional
;  ":Breite" (max. 20) und ":Nachkommastellen" (max. 9); zu wenig Platz ->
;  ERR_36.
; <- aufgerufen von 2488h
WRITE_ITEMS:
        CALL    RUN_GETTOK
        CP      0E0h
        JR      Z,L2444
        CP      8Dh
        RET     Z
        DEC     HL
        CALL    RUN_EXPR
        CALL    RUN_GETTOK
        CP      0DDh
        JP      NZ,L2548
        INC     HL
        INC     HL
        CALL    RUN_EXPR
        PUSH    HL
        LD      HL,(RT_SP)
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      A,(HL)
        OR      A
        JP      NZ,ERR_13
        INC     HL
        LD      (RT_SP),HL
        OR      E
        JP      Z,ERR_36
        CP      15h
        JP      NC,ERR_13
        LD      HL,WR_WIDTH
        LD      D,(HL)
        LD      (HL),E
        POP     HL
        PUSH    DE
        CALL    RUN_GETTOK
        CP      0DDh
        JR      NZ,L2551
        INC     HL
        INC     HL
        CALL    RUN_EXPR
        PUSH    HL
        LD      HL,(RT_SP)
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      A,(HL)
        INC     HL
        LD      (RT_SP),HL
        OR      A
        JP      NZ,ERR_13
        LD      A,E
        CP      0Ah
        JP      NC,ERR_13
L2502:  LD      (WR_DECIMALS),A
        LD      HL,LINEBUF
        PUSH    HL
        LD      A,(WR_WIDTH)
        LD      B,A
        LD      A,20h
L250F:  LD      (HL),A
        INC     HL
        DJNZ    L250F
        LD      (HL),0Dh
        LD      (RD_PTR),HL
        DEC     HL
        PUSH    HL
        LD      HL,(RT_SP)
        LD      A,(HL)
        AND     0Fh
        CP      01h
        JR      Z,L2557
        CP      00h
        JP      Z,REAL2STR
        INC     HL
        LD      A,(HL)
        INC     HL
        LD      (RT_SP),HL
        POP     HL
        LD      (HL),A
        POP     HL
L2532:  POP     HL
        POP     AF
        LD      (WR_WIDTH),A
L2537:  PUSH    HL
        LD      DE,LINEBUF

;  SM_WROUT – Operand: Ausgaberoutine für Texte bei WRITE (MSG, PRT_TEXT oder
;  Datei).
SM_WROUT:
        CALL    0000h                   ; Operand wird zur Laufzeit gesetzt
        POP     HL
        CALL    RUN_GETTOK
        CP      78h
        JP      Z,WRITE_ITEMS
        RET
L2548:  LD      A,(WR_WIDTH)
        PUSH    AF
        LD      A,0Fh
        LD      (WR_WIDTH),A
L2551:  LD      A,0FFh
        DEC     HL
        PUSH    HL
        JR      L2502
L2557:  INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        LD      (RT_SP),HL
        LD      HL,L2596
        PUSH    HL

;  INT2STR – INTEGER DE als Dezimaltext nach 26A2h ("-32768" gesondert).
; <- aufgerufen von 296Dh
INT2STR:
        LD      HL,NUMBUF
        LD      C,20h
        LD      A,D
        OR      A
        JP      P,L258E
        AND     7Fh
        JR      NZ,L2589
        OR      E
        JR      NZ,L2589
        PUSH    HL
        LD      DE,TXT_M32768
        LD      BC,0006h
        EX      DE,HL
        LDIR
        POP     HL
        LD      C,2Dh
        JR      L2593
TXT_M32768:
        DEFB    "032768"
L2589:  CALL    NEG_DE
        LD      C,2Dh
L258E:  PUSH    BC
        CALL    BIN2BCD
        POP     BC
L2593:  JP      STRIP_ZEROS
L2596:  LD      HL,NUMBUF_5
        POP     DE
        LD      BC,0006h
        LD      A,2Fh
L259F:  CP      (HL)
        JR      NC,L25B2
        LDD
        JP      PE,L259F
L25A7:  INC     DE
L25A8:  POP     HL
        OR      A
        EX      DE,HL
        SBC     HL,DE
        JP      C,ERR_36
        JR      L2532
L25B2:  LD      A,(HL)
        CP      2Dh
        JR      NZ,L25A7
        LD      (DE),A
        JR      L25A8

;  REAL2STR – REAL-Zahl mit Breite/Nachkommastellen formatieren (FP2STR).
REAL2STR:
        INC     HL
        PUSH    HL
        LD      DE,0005h
        ADD     HL,DE
        LD      (RT_SP),HL
        POP     HL
        LD      DE,NUMBUF
        PUSH    DE
        CALL    FP2STR
        LD      A,(WR_DECIMALS)
        INC     A
        JR      NZ,L2603
        POP     DE
        LD      C,0FFh
L25D4:  INC     DE
        LD      A,(DE)
        INC     C
        CALL    IS_DIGIT
        JR      NC,L25D4
        CP      2Eh
        JR      NZ,L2600
L25E0:  INC     DE
        LD      A,(DE)
        INC     C
        CALL    IS_DIGIT
        JR      NC,L25E0
        CP      45h
        JR      NZ,L2600
        INC     DE
        INC     DE
        INC     DE
        INC     C
        INC     C
        INC     C
        INC     C
L25F3:  POP     HL
        EX      DE,HL
        LD      B,00h
        LDDR
        JP      L25B2
        DEC     DE
        JP      L2532
L2600:  DEC     DE
        JR      L25F3
L2603:  LD      DE,FMT_BUF1
        LD      B,29h
        LD      A,30h
L260A:  LD      (DE),A
        INC     DE
        DJNZ    L260A
        LD      HL,FMT_BUF2
        LD      (HL),2Eh
        EX      (SP),HL
        PUSH    HL
        LD      DE,0FFFFh
        LD      C,D
        LD      A,(HL)
        EX      AF,AF'
L261B:  INC     C
        INC     HL
        LD      A,(HL)
        CALL    IS_DIGIT
        JR      NC,L261B
        CP      2Eh
        JR      NZ,L269E
L2627:  INC     D
        INC     HL
        LD      A,(HL)
        CALL    IS_DIGIT
        JR      NC,L2627
        CP      45h
        JR      NZ,L269F
        INC     HL
        LD      B,(HL)
        INC     HL
        LD      A,(HL)
        AND     0Fh
        JR      Z,L263D
        LD      A,0Ah
L263D:  INC     HL
        ADD     A,(HL)
        SUB     30h
        LD      E,A
        LD      A,2Dh
        CP      B
        JR      NZ,L2651
        LD      A,E
        CP      0Ah
        JR      C,L264E
        LD      A,0Ah
L264E:  NEG
        LD      E,A
L2651:  LD      A,C
        ADD     A,D
        LD      B,A
        LD      A,E
        ADD     A,C
        LD      E,A
        LD      D,00h
        JP      P,L265F
        LD      D,0FFh
        DEC     E
L265F:  POP     HL
        INC     HL
        EX      (SP),HL
        OR      A
        SBC     HL,DE
        POP     DE
        LD      C,2Eh
L2668:  LD      A,(HL)
        CP      C
        JR      NZ,L266D
        INC     HL
L266D:  LD      A,(DE)
        INC     DE
        CP      C
        JR      Z,L266D
        LD      (HL),A
        INC     HL
        DJNZ    L2668
        LD      HL,FMT_BUF1
        LD      A,30h
        LD      B,20h
L267D:  CP      (HL)
        JR      NZ,L2685
        LD      (HL),20h
        INC     HL
        DJNZ    L267D
L2685:  DEC     HL
        EX      AF,AF'
        LD      (HL),A
        LD      HL,FMT_BUF2
        LD      A,(WR_DECIMALS)
        ADD     A,L
        LD      L,A
        JR      NC,L2693
        INC     H
L2693:  POP     DE
        LD      A,2Ch
L2696:  CP      (HL)
        JP      NC,L25A7
        LDD
        JR      L2696
L269E:  INC     D
L269F:  INC     E
        JR      L2651
NUMBUF: DEFB    00h,00h,00h,00h,00h
NUMBUF_5:
        DEFB    00h
NUMBUF_6:
        DEFS    14,00h
FMT_BUF1:
        DEFS    20,00h
FMT_BUF2:
        DEFS    21,00h
LINEBUF:
        DEFS    49,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,0Dh
WR_WIDTH:
        DEFB    00h
WR_DECIMALS:
        DEFB    00h
RD_PTR: DEFS    26,00h

;  CMT_ERR34 – Schreibfehler im Programmlauf: "Err 34* Run*" und
;  Tastenabfrage.
; <- aufgerufen von 281Fh
CMT_ERR34:
        LD      DE,MSG_ERR34
        JR      CMT_ERRKEY

;  CMT_ERR35 – Lesefehler im Programmlauf: "Err 35* Run*" und Tastenabfrage.
; <- aufgerufen von 27BDh
CMT_ERR35:
        LD      DE,MSG_ERR35

;  CMT_ERRKEY – Meldung, "** Push key [ C)ontinue E)ditor ]": C = wiederholen,
;  E = PAS_READY.
CMT_ERRKEY:
        CALL    PR_MSG_NL
        LD      DE,MSG_PUSHKEY
        CALL    PR_MSG_NL
        CALL    LETNL
L2774:  CALL    INKEY
        CP      43h
        RET     Z
        CP      45h
        JR      NZ,L2774
        JP      PAS_READY
MSG_ERR34:
        DEFB    "Err 34* Run*",0Dh
MSG_ERR35:
        DEFB    "Err 35* Run*",0Dh
MSG_PUSHKEY:
        DEFB    "** Push key [ C)ontinue E)ditor ]",0Dh
L27BD:  CALL    CMT_ERR35

;  FILE_FIND – Datei vom Typ 03h mit dem Namen aus FNAME auf dem Band suchen,
;  "Found"/"Loading".
FILE_FIND:
        CALL    RDINF
        JR      C,L27BD
        CALL    PR_FOUND
        LD      DE,IBUFE
        LD      A,(DE)
        CP      03h
        CALL    NZ,CMT_SKIPFILE
        JR      NZ,FILE_FIND
        LD      HL,FILE_NAME
        CALL    CMP_FNAME
        CALL    NZ,CMT_SKIPFILE
        JR      NZ,FILE_FIND
        CALL    PR_LOADING
        JR      L2827

;  READ_FILE – READ aus einer Datei.
READ_FILE:
        XOR     A
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl

;  WRITE_FILE – WRITE in eine Datei; beim ersten Zugriff Dateikopf schreiben.
WRITE_FILE:
        LD      A,01h
        LD      B,A

;  FILE_STATE – Operand: Zustand der Datei.
FILE_STATE:
        LD      A,03h                   ; Operand wird zur Laufzeit gesetzt
        CP      03h
        JR      Z,L27F2
        CP      B
        JP      NZ,ERR_46
L27F2:  LD      A,B
        LD      (FILE_STATE+1),A
        CALL    DI_
        PUSH    HL
        LD      HL,L599E
        LD      (ARRAY_HOOK+1),HL
        LD      A,(FILE_NAMEFLAG)
        OR      A
        JR      NZ,L2832
        LD      A,(FILE_STATE+1)
        OR      A
        JP      Z,FILE_FIND
        LD      HL,FILE_NAME
        LD      DE,IBUFE
        LD      A,03h
        LD      (DE),A
        DEC     HL
        CALL    COPY_FNAME
        CALL    CMT_SETBLK
        JR      L2822
L281F:  CALL    CMT_ERR34
L2822:  CALL    WRINF
        JR      C,L281F
L2827:  CALL    MSTOP
        XOR     A
        LD      (SM_FILE_MODE+1),A
        INC     A
        LD      (FILE_NAMEFLAG),A
L2832:  POP     HL
        CALL    RUN_GETTOK
        CALL    VAR_ADDR
        LD      (SM_FILE_FLAG+1),A
        LD      (SM_FILE_CNT+1),BC
        LD      (SM_FILE_VAR+1),DE
        PUSH    HL
        BIT     6,A
        JR      NZ,L2862
        INC     DE
        LD      (SM_FILE_VAR+1),DE
        CALL    FILE_ITEM
L2851:  POP     HL
        CALL    RUN_GETTOK
        PUSH    HL
        CP      78h
        JR      Z,L2832
        LD      HL,ARRAY_INDEX
        LD      (ARRAY_HOOK+1),HL
        POP     HL
        RET
L2862:  CALL    TYPE_SIZE
        DEC     BC
        PUSH    BC
        POP     DE
        OR      A

;  SM_FILE_CNT – Operand: Zähler der Feldelemente bei READ/WRITE mit Dateien.
SM_FILE_CNT:
        LD      HL,0000h                ; Operand wird zur Laufzeit gesetzt
        LD      BC,0FFFFh
L286F:  INC     BC
        SBC     HL,DE
        JR      NC,L286F
L2874:  PUSH    BC
        PUSH    DE
        CALL    FILE_ITEM

;  SM_FILE_VAR – Operand: Adresse der Variablen beim Datei-Zugriff.
SM_FILE_VAR:
        LD      HL,0000h                ; Operand wird zur Laufzeit gesetzt
        POP     DE
        ADD     HL,DE
        LD      (SM_FILE_VAR+1),HL
        POP     BC
        DEC     BC
        LD      A,C
        OR      B
        JR      NZ,L2874
        JR      L2851

;  FILE_ITEM – Einen Wert aus dem Dateipuffer lesen bzw. hineinschreiben.
; <- aufgerufen von 284Eh, 2876h
FILE_ITEM:
        LD      A,(FILE_STATE+1)
        OR      A

;  SM_FILE_MODE – Operand: Richtung des Datei-Zugriffs (lesen/schreiben).
SM_FILE_MODE:
        LD      A,00h                   ; Operand wird zur Laufzeit gesetzt
        JP      NZ,L297A
        OR      A
        CALL    Z,FILE_READBLK
        LD      DE,NUMBUF

;  SM_FILE_BUFPTR – Operand: Zeiger in FILEBUF.
SM_FILE_BUFPTR:
        LD      HL,0000h                ; Operand wird zur Laufzeit gesetzt
        LD      A,(HL)
        INC     A
        JP      Z,ERR_47
        CP      1Ch
        JR      NZ,L28B0
        INC     HL
        CALL    FILE_NEXT
        JR      L28B0
L28AB:  POP     AF
        CALL    CMT_READBLK
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
L28B0:  LDI
        LD      A,(HL)
        CP      0Dh
        PUSH    AF
        CALL    FILE_PTR
        JR      NC,L28AB
        POP     AF
        JR      NZ,L28B0
        LDI
        CALL    FILE_NEXT
        LD      A,(HL)
        INC     A
        JR      Z,L28C9
        XOR     A
        DEFB    06h                     ; Trick: verschluckt den folgenden Befehl
L28C9:  INC     A
        LD      (FILE_BLKFLAG),A
        LD      (SM_FILE_BUFPTR+1),HL
        LD      HL,(SM_FILE_VAR+1)
        LD      A,01h
        LD      (SM_NUMTYPE+1),A

;  SM_FILE_FLAG – Operand: Merker des Datei-Zugriffs.
SM_FILE_FLAG:
        LD      A,00h                   ; Operand wird zur Laufzeit gesetzt
        LD      DE,NUMBUF
        AND     0Fh
        JR      Z,L28E7
        DEC     A
        JR      Z,L28EE
        LD      A,(DE)
        LD      (HL),A
        RET
L28E7:  LD      (RD_PTR),DE
        JP      READ_NUMBER
L28EE:  CALL    PARSE_INT
        EX      DE,HL
        LD      HL,(SM_FILE_VAR+1)
        LD      (HL),E
        INC     HL
        LD      (HL),D
        RET

;  PARSE_INT – Ganzzahl mit Vorzeichen ab DE nach HL.
; <- aufgerufen von 2376h, 28EEh
PARSE_INT:
        CALL    SKIP_SPC
        CP      2Dh
        PUSH    AF
        JR      Z,L2905
        CP      2Bh
        JR      NZ,L2907
L2905:  INC     DE
        LD      A,(DE)
L2907:  CALL    IS_DIGIT
        JR      C,L2914
        CALL    GET_DEC
        POP     AF
        RET     NZ
        JP      NEG_HL
L2914:  LD      A,(SM_NUMTYPE+1)
        OR      A
        JP      Z,L22F0
        JP      ERR_17

;  CMT_SETBLK – Kassettenkopf auf einen Block von 100h Bytes ab FILEBUF
;  einstellen.
; <- aufgerufen von 281Ah, 2A06h, 2A45h
CMT_SETBLK:
        LD      DE,0100h
        LD      HL,IBU18
        LD      (HL),E
        INC     HL
        LD      (HL),D
        INC     HL
        LD      DE,FILEBUF
        LD      (HL),E
        INC     HL
        LD      (HL),D
        RET

;  FILE_NEXT – Nächster Block, falls der Puffer leer/voll ist.
; <- aufgerufen von 28A6h, 28C0h, 2A23h, 2A27h, 2A2Fh
FILE_NEXT:
        CALL    FILE_PTR
        RET     C

;  CMT_READBLK – Block vom Band lesen (RDDAT); Fehler -> ERR_35.
; <- aufgerufen von 28ACh, 294Eh
CMT_READBLK:
        PUSH    DE
        LD      HL,RDDAT
        LD      (SM_CMT_IO+1),HL
        CALL    CMT_BLOCKIO
        LD      HL,FILEBUF
        POP     DE
        JP      C,ERR_35
        RET

;  FILE_PTR – Pufferzeiger prüfen/weiterstellen.
; <- aufgerufen von 28B6h, 292Fh, 29CAh
FILE_PTR:
        PUSH    HL
        LD      BC,FILEBUF2
        OR      A
        SBC     HL,BC
        POP     HL
        RET

;  FILE_READBLK – Block lesen, Pufferzeiger und Modus setzen.
; <- aufgerufen von 2893h
FILE_READBLK:
        CALL    CMT_READBLK
        LD      A,H
        LD      (SM_FILE_MODE+1),A
        LD      (SM_FILE_BUFPTR+1),HL
        RET
L2959:  PUSH    DE
        LD      DE,FILEBUF2
        PUSH    DE
        LD      BC,0005h
        LDIR
        POP     HL
        POP     DE
        CALL    FP2STR
        JR      L2970
L296A:  LD      E,(HL)
        INC     HL
        LD      D,(HL)
        CALL    INT2STR
L2970:  POP     DE
        DEC     DE
L2972:  INC     DE
        LD      A,(DE)
        CP      20h
        JR      Z,L2972
        JR      L29B5
L297A:  OR      A
        JR      NZ,L2987
        LD      HL,FILEBUF
        LD      (SM_FILE_BUFPTR+1),HL
        LD      A,H
        LD      (SM_FILE_MODE+1),A
L2987:  LD      B,20h
        XOR     A
        LD      DE,NUMBUF
        PUSH    DE
L298E:  LD      (DE),A
        INC     DE
        DJNZ    L298E
        POP     DE
        LD      HL,(SM_FILE_VAR+1)
        LD      A,(SM_FILE_FLAG+1)
        AND     0Fh
        PUSH    AF
        PUSH    DE
        JR      Z,L2959
        DEC     A
        JR      Z,L296A
        LD      A,(HL)
        CP      1Bh
        JR      Z,L29AE
        CP      0Dh
        JR      Z,L29AE
        INC     A
        JR      NZ,L29B2
L29AE:  LD      A,1Bh
        LD      (DE),A
        INC     DE
L29B2:  LDI
        POP     DE
L29B5:  LD      HL,(SM_FILE_BUFPTR+1)
        EX      DE,HL
        XOR     A
L29BA:  LDI
        CP      (HL)
        JR      NZ,L29BA
        LD      A,0Dh
        LD      (DE),A
        POP     AF
        JR      Z,L29C6
        INC     DE
L29C6:  EX      DE,HL
        LD      (SM_FILE_BUFPTR+1),HL
        CALL    FILE_PTR
        RET     C
        PUSH    HL
        CALL    CMT_WRITEBLK
        LD      BC,FILEBUF2
        OR      A
        POP     HL
        SBC     HL,BC
        PUSH    BC
        EX      (SP),HL
        POP     BC
        LD      DE,FILEBUF
        LD      A,B
        OR      C
        JR      Z,L29E5
        LDIR
L29E5:  LD      (SM_FILE_BUFPTR+1),DE
        RET

;  CMT_WRITEBLK – Block auf Band schreiben (WRDAT); Fehler -> ERR_34.
; <- aufgerufen von 29CFh
CMT_WRITEBLK:
        LD      HL,WRDAT
        LD      (SM_CMT_IO+1),HL
        CALL    CMT_BLOCKIO
        JP      C,ERR_34
        RET

;  RUN_CLOSE – CLOSE: letzten Block schreiben, Datei schließen (auch am
;  Programmende).
; <- aufgerufen von 19BAh
RUN_CLOSE:
        PUSH    HL
        LD      A,(FILE_STATE+1)
        OR      A
        JR      Z,L2A16
        DEC     A
        JR      NZ,L2A0F
        LD      HL,(SM_FILE_BUFPTR+1)
        LD      (HL),0FFh
        CALL    CMT_SETBLK
        CALL    WRDAT
        JP      C,ERR_34
L2A0F:  LD      A,04h
        LD      (FILE_STATE+1),A
        POP     HL
        RET
L2A16:  LD      HL,(SM_FILE_BUFPTR+1)
L2A19:  LD      A,(HL)
        CP      0FFh
        JR      Z,L2A0F
        CP      1Bh
        JR      NZ,L2A2B
        INC     HL
        CALL    FILE_NEXT
        INC     HL
        CALL    FILE_NEXT
L2A2A:  LD      A,(HL)
L2A2B:  CP      0Dh
        PUSH    AF
        INC     HL
        CALL    FILE_NEXT
        POP     AF
        JR      NZ,L2A2A
        JR      L2A19

;  CMT_BLOCKIO – Block über RDDAT bzw. WRDAT (Operand bei L2A48) übertragen,
;  Motor aus.
; <- aufgerufen von 293Ah, 29F0h
CMT_BLOCKIO:
        CALL    DI_
        LD      A,0C9h
        LD      (MSTOP),A
        LD      (TSPE),A
        LD      (SERSP),A
        CALL    CMT_SETBLK

;  SM_CMT_IO – Operand: RDDAT oder WRDAT.
SM_CMT_IO:
        CALL    0000h                   ; Operand wird zur Laufzeit gesetzt
        PUSH    AF
        LD      A,3Eh
        LD      (MSTOP),A
        LD      A,0E7h
        LD      (TSPE),A
        LD      (SERSP),A
        CALL    MSTOP
        POP     AF
        RET
FILE_BLKFLAG:
        DEFB    01h
FILEBUF:
        DEFS    256,00h
FILEBUF2:
        DEFS    33,00h
MUSIC_PTR:
        DEFW    MUSIC_BUF
        DEFB    00h
MUSIC_BUF:
        DEFB    00h,00h,00h,00h,00h

;  MUSIC_TEXT – Musiktext ab DE spielen (Abschnitte über MUSIC_PART).
; <- aufgerufen von 2C4Ch
MUSIC_TEXT:
        LD      A,(DE)
        CP      0Dh
        RET     Z
        INC     DE
        PUSH    HL
        PUSH    DE
        CALL    MUSIC_NOTE
        POP     DE
        POP     HL
        JR      MUSIC_TEXT

;  MUSIC_PART – Teil eines Musiktexts nach 2B83h übertragen und mit MELDY
;  spielen.
; <- aufgerufen von 2C41h
MUSIC_PART:
        LD      HL,(MUSIC_PTR)
        DEC     HL
        LD      A,(HL)
        INC     HL
        CALL    IS_NOTE_R
        JR      NC,MUSIC_PLAY
        OR      A
        JR      L2BC2

;  MUSIC_NOTE – Eine Note (mit Oktave/Länge) in den Musikpuffer übernehmen.
; <- aufgerufen von 2B8Fh, 2C35h
MUSIC_NOTE:
        CALL    MUSIC_CHK
        LD      HL,(MUSIC_PTR)
        LD      (HL),A
        DEC     HL
        LD      A,(HL)
        INC     HL
        CALL    IS_NOTE_R
        JR      C,L2BCE
        LD      A,(HL)
        CALL    IS_DIGIT
        JR      C,L2BEA
        INC     HL

;  MUSIC_PLAY – Puffer 2B83h mit MELDY spielen; BREAK -> BREAK_STOP.
; <- aufgerufen von 2BEBh
MUSIC_PLAY:
        LD      (HL),0Dh
        LD      DE,MUSIC_BUF
        CALL    MELDY
L2BC2:  LD      HL,MUSIC_BUF
        LD      (HL),0Dh
        LD      (MUSIC_PTR),HL
        JP      C,BREAK_STOP
        RET
L2BCE:  CP      23h
        LD      A,(HL)
        JR      NZ,L2BDA
        CALL    IS_NOTE
        JR      NC,L2BF3
        JR      L2BEF
L2BDA:  CALL    IS_SHARP
        JR      Z,L2BEF
        CP      52h
        JR      Z,L2BEF
        CALL    IS_DIGIT
        JR      C,L2BF3
        JR      L2BC2
L2BEA:  PUSH    AF
        CALL    MUSIC_PLAY
        POP     AF
L2BEF:  LD      HL,MUSIC_BUF
        LD      (HL),A
L2BF3:  INC     HL
        LD      (MUSIC_PTR),HL
        RET

;  MUSIC_CHK – Gültiges Zeichen eines Musiktexts? Sonst ERR_13.
; <- aufgerufen von 2BA4h
MUSIC_CHK:
        CALL    IS_NOTE_R
        CALL    C,IS_DIGIT
        CALL    C,IS_SHARP
        RET     NC
        CP      23h
        RET     Z
        JP      ERR_13

;  IS_NOTE – C = Notenbuchstabe A-G.
; <- aufgerufen von 2BD3h, 2C0Fh
IS_NOTE:
        CP      41h
        RET     C
        CP      48h
        CCF
        RET

;  IS_NOTE_R – Note oder Pause (R).
; <- aufgerufen von 2B9Ch, 2BAEh, 2BF8h
IS_NOTE_R:
        CALL    IS_NOTE
        RET     NC
        CP      52h
        RET     Z
        SCF
        RET

;  IS_SHARP – Vorzeichen "+"/"-" (Oktave) erkennen.
; <- aufgerufen von 2BDAh, 2BFEh
IS_SHARP:
        CP      2Bh
        RET     Z
        CP      2Dh
        RET     Z
        SCF
        RET
RUN_MUSIC:
        CALL    RUN_GETTOK
        CP      0E0h
        JR      Z,L2C46
        DEC     HL
        CALL    RUN_EXPR
        EXX
        LD      HL,(RT_SP)
        INC     HL
        LD      A,(HL)
        INC     HL
        LD      (RT_SP),HL
        CALL    MUSIC_NOTE
        EXX
L2C39:  CALL    RUN_GETTOK
        CP      78h
        JR      Z,RUN_MUSIC
        PUSH    HL
        CALL    MUSIC_PART
        POP     HL
        RET
L2C46:  CALL    EVAL_TEXT
        LD      DE,LINEBUF
        CALL    MUSIC_TEXT
        JR      L2C39
RUN_TEMPO:
        CALL    RUN_EXPR
        EXX
        LD      HL,(RT_SP)
        INC     HL
        LD      B,(HL)
        INC     HL
        LD      A,(HL)
        INC     HL
        LD      (RT_SP),HL
        OR      A
        JP      NZ,ERR_13
        LD      A,B
        OR      A
        JP      Z,ERR_13
        CP      08h
        JP      NC,ERR_13
        AND     0Fh
        CALL    XTEMP
        EXX
        JP      RUN_GETTOK
L2C77:  POP     HL
        CP      A
        RET

;  CHK_FILEVAR – Ist das erste Argument eine FILE-Variable? NZ = ja.
; <- aufgerufen von 2303h, 249Fh
CHK_FILEVAR:
        PUSH    HL
        CALL    RUN_GETTOK
        CP      0E2h
        JR      Z,L2C86
        CP      0E3h
        JR      NZ,L2C77
L2C86:  LD      A,(HL)
        BIT     5,A
        JR      Z,L2C77
        INC     HL
        INC     HL
        INC     HL
        BIT     6,A
        JR      NZ,L2CA0
        CALL    RUN_GETTOK
        CP      78h
        JR      Z,L2C9D
        CP      8Dh
        JR      NZ,L2C77
L2C9D:  POP     HL
        OR      A
        RET
L2CA0:  INC     HL
        LD      A,(HL)
        CP      8Ch
        JR      NZ,L2C77
        JR      L2C9D

;  RUN_SIN – SIN(x): Argument reduzieren, Quadranten über Vergleiche mit pi/2
;  und pi, FSIN.
RUN_SIN:
        CALL    TRIG_ARG
        CALL    TRIG_CMP_PI2
        JR      C,L2CBB
        CALL    TRIG_SUB_PI
        CALL    TRIG_CMP_PI2
        JR      C,L2CD8
        CALL    TRIG_SUB_PI
L2CBB:  LD      HL,(TRIG_ARGP)
        LD      A,(HL)
        AND     7Fh
        CP      41h
        CALL    Z,TRIG_CLAMP
        EX      DE,HL
        CALL    FSIN
L2CCA:  LD      HL,(TRIG_ARGP)
        LD      A,(TRIG_SIGN)
        OR      A
        CALL    P,TRIG_NEG
        LD      HL,(TRIG_TXTPTR)
        RET
L2CD8:  CALL    TRIG_NEG
        JR      L2CBB
RUN_COS:
        CALL    TRIG_ARG
        CALL    TRIG_CMP_PI
        JR      C,L2CEC
        XOR     A
        LD      (TRIG_SIGN),A
        CALL    TRIG_SUB_PI
L2CEC:  LD      HL,(TRIG_ARGP)
        INC     HL
        INC     HL
        INC     HL
        INC     HL
        LD      A,(HL)
        AND     A
        JP      P,L2D08
        LD      HL,(TRIG_ARGP)
        LD      A,(HL)
        CP      0B2h
        JR      NC,L2D11
        LD      (HL),0B2h
L2D02:  EX      DE,HL
        CALL    FCOS
        JR      L2CCA
L2D08:  LD      (HL),0FFh
        LD      HL,(TRIG_ARGP)
        LD      (HL),0B2h
        JR      L2D02
L2D11:  CP      0C2h
        CALL    Z,TRIG_CLAMP
        JR      L2D02

;  TRIG_CLAMP – Sehr kleine Exponenten begrenzen (Exponentbyte höchstens A0h).
; <- aufgerufen von 2CC3h, 2D13h
TRIG_CLAMP:
        INC     HL
        LD      A,(HL)
        CP      0A1h
        JR      C,L2D20
        LD      (HL),0A0h
L2D20:  DEC     HL
        RET
RUN_TAN:
        CALL    TRIG_ARG
L2D25:  CALL    TRIG_CMP_PI2
        JR      C,L2D3F
        CALL    TRIG_SUB_PI
        LD      HL,(TRIG_ARGP)
        LD      A,(HL)
        OR      A
        JP      M,L2D25
        CALL    FP_FIXSIGN
        LD      HL,TRIG_SIGN
        LD      A,80h
        XOR     (HL)
        LD      (HL),A
L2D3F:  LD      DE,(TRIG_ARGP)
        CALL    FTAN
        JP      L2CCA

;  TRIG_CMP_PI2 – Argument mit pi/2 vergleichen (C = kleiner).
; <- aufgerufen von 2CABh, 2CB3h, 2D25h
TRIG_CMP_PI2:
        LD      HL,FP_PI2
L2D4C:  LD      DE,TRIG_TMP
        LD      BC,0005h
        LDIR
        LD      DE,TRIG_TMP
        LD      HL,(TRIG_ARGP)
        CALL    FCMP_GE
        LD      A,(TRIG_TMP)
        RRA
        RET
TRIG_SIGN:
        DEFB    00h
TRIG_TMP:
        DEFB    00h,00h,00h,00h,00h

;  TRIG_CMP_PI – Argument mit pi vergleichen.
; <- aufgerufen von 2CE0h
TRIG_CMP_PI:
        LD      HL,FP_PI
        JR      L2D4C

;  TRIG_SUB_PI – Argument = Argument - pi.
; <- aufgerufen von 2CB0h, 2CB8h, 2CE9h, 2D2Ah
TRIG_SUB_PI:
        LD      DE,(TRIG_ARGP)
        LD      HL,FP_PI
        JP      FSUB

;  TRIG_NEG – Vorzeichen des Arguments umdrehen.
; <- aufgerufen von 2CD1h, 2CD8h
TRIG_NEG:
        LD      HL,(TRIG_ARGP)
        JP      FP_FIXSIGN

;  TRIG_ARG – Argument auswerten (RUN_EXPR) und über INT(x / 2pi) * 2pi auf
;  eine Periode reduzieren. TRIG_ARGP zeigt auf den Wert auf dem
;  Laufzeitstapel, TRIG_SIGN merkt das Vorzeichen.
; <- aufgerufen von 2CA8h, 2CDDh, 2D22h
TRIG_ARG:
        CALL    RUN_EXPR
        CALL    RUN_GETTOK
        LD      (TRIG_TXTPTR),HL
        LD      HL,(RT_SP)
        INC     HL
        LD      (TRIG_ARGP),HL
        LD      A,80h
        LD      (TRIG_SIGN),A
        LD      DE,TRIG_TMP
        LD      BC,0005h
        LDIR
        LD      DE,TRIG_TMP
        LD      HL,FP_2PI
        CALL    FDIV
        LD      DE,TRIG_TMP
        CALL    FINT
        LD      DE,TRIG_TMP
        LD      HL,FP_2PI
        CALL    FMUL
        LD      DE,(TRIG_ARGP)
        LD      HL,TRIG_TMP
        JP      FSUB
TRIG_TXTPTR:
        DEFB    00h,00h
TRIG_ARGP:
        DEFB    00h,00h
FP_PI2: DEFB    0C1h,0A1h,0DAh,0Fh,0C9h ; Gleitkomma 1.57079633
FP_PI:  DEFB    0C2h,0A1h,0DAh,0Fh,0C9h ; Gleitkomma 3.14159265
FP_2PI: DEFB    0C3h,0A1h,0DAh,0Fh,0C9h ; Gleitkomma 6.28318531
L2DCF:  CALL    SYN_SKIPCMT
        JR      L2DE7

;  SYN_STRARG – TRAN(, MUSIC(, IMAGE( prüfen.
SYN_STRARG:
        CALL    SYN_GETTOK
        CP      0E0h
        JR      Z,L2DCF
        DEC     DE
        CALL    SYN_EXPR
        LD      B,02h
        CALL    TYPE_MATCH
        CALL    SYN_GETTOK
L2DE7:  CP      78h
        JR      Z,SYN_STRARG
        CP      8Dh
        RET     Z
        JP      ERR_08
RUN_TRAN:
        CALL    RUN_GETTOK
        CP      0E0h
        JR      Z,L2E12
        DEC     HL
        CALL    RUN_EXPR
        EXX
        LD      HL,(RT_SP)
        INC     HL
        LD      A,(HL)
        INC     HL
        LD      (RT_SP),HL
        CALL    TRAN_BYTE
        EXX
L2E0A:  CALL    RUN_GETTOK
        CP      78h
        JR      Z,RUN_TRAN
        RET
L2E12:  CALL    EVAL_TEXT
        LD      DE,LINEBUF
L2E18:  LD      A,(DE)
        INC     DE
        CALL    TRAN_BYTE
        CP      0Dh
        JR      NZ,L2E18
        JR      L2E0A
RUN_REQTR:
        CALL    BRKEY
        JR      Z,L2E53
        IN      A,(0EFh)
        AND     02h
        JR      Z,RUN_REQTR
        IN      A,(0EEh)
        PUSH    AF
        LD      A,05h
        CALL    TRAN_STROBE
L2E36:  IN      A,(0EFh)
        AND     02h
        PUSH    AF
        CALL    BRKEY
        JR      Z,L2E52
        POP     AF
        JR      NZ,L2E36
        POP     AF
        EXX
        LD      HL,(RT_SP)
        DEC     HL
        LD      (HL),A
        DEC     HL
        LD      (HL),02h
        LD      (RT_SP),HL
        EXX
        RET
L2E52:  POP     AF
L2E53:  POP     AF
        CALL    TRAN_RESET
        LD      HL,BREAK_STOP
        LD      (SM_TRAN_CONT+1),HL
        CALL    TRAN_INIT
        JP      BREAK_STOP
RUN_SYRET:
        LD      DE,SYRET_CMD1
L2E66:  PUSH    HL
        CALL    TRAN_RESET
L2E6A:  LD      A,(DE)
        INC     DE
        CALL    TRAN_CHAR
        CP      0Dh
        JR      NZ,L2E6A
        POP     HL
        RET
RUN_SYRET2:
        LD      DE,SYRET_CMD2
        JR      L2E66
SYRET_CMD1:
        DEFB    "J,$13A8",0Dh
SYRET_CMD2:
        DEFB    "J,$0048",0Dh
SYRET_CMD3:
        DEFB    "J,$13F8",0Dh

;  TRAN_CHAR – Zeichen senden (für SYRET-Kommandos).
; <- aufgerufen von 2E6Ch
TRAN_CHAR:
        PUSH    AF
        JR      L2E9B

;  TRAN_BYTE – Byte A an das Farbterminal senden (Port EEh, Handshake über
;  EFh, BREAK bricht ab).
; <- aufgerufen von 2E06h, 2E1Ah
TRAN_BYTE:
        PUSH    AF
L2E96:  CALL    BRKEY
        JR      Z,L2E53
L2E9B:  IN      A,(0EFh)
        AND     01h
        JR      Z,L2E96
        POP     AF
        PUSH    AF
        OUT     (0EEh),A
        LD      A,06h
        CALL    TRAN_STROBE
L2EAA:  IN      A,(0EFh)
        AND     01h
        PUSH    AF
        CALL    BRKEY
        JR      Z,L2E52
        POP     AF
        JR      NZ,L2EAA
        POP     AF
        RET

;  TRAN_RESET – Schnittstelle EEh/EFh zurücksetzen und kurz warten.
; <- aufgerufen von 2E54h, 2E67h
TRAN_RESET:
        LD      HL,DELAY_BB8
        PUSH    HL
        LD      A,03h

;  TRAN_STROBE – Steuerwert A an Port EFh ausgeben (Strobe).
; <- aufgerufen von 2E33h, 2EA7h, 2FE6h
TRAN_STROBE:
        OUT     (0EFh),A
        NOP
        NOP
        LD      A,07h
        OUT     (0EFh),A
        RET

;  DELAY_BB8 – Warteschleife (BB8h Durchläufe).
DELAY_BB8:
        LD      HL,0BB8h
L2ECB:  DEC     HL
        LD      A,H
        OR      A
        JR      NZ,L2ECB
        RET
RUN_LOG:
        CALL    RUN_EXPR
        PUSH    HL
        LD      DE,(RT_SP)
        INC     DE
        CALL    FLOG
        JR      L2F35
RUN_LN: CALL    RUN_EXPR
        PUSH    HL
        LD      DE,(RT_SP)
        INC     DE
        CALL    FLN
        JR      L2F35
RUN_ARCTAN:
        CALL    RUN_EXPR
        PUSH    HL
        LD      DE,(RT_SP)
        INC     DE
        CALL    FATN
        JR      L2F35
RUN_RND:
        CALL    RUN_EXPR
        PUSH    HL
        LD      DE,(RT_SP)
        INC     DE
        CALL    FRND
        JR      L2F35
RUN_SQRT:
        CALL    RUN_EXPR
        PUSH    HL
        LD      DE,(RT_SP)
        INC     DE
        CALL    FSQRT
        JR      L2F35
RUN_ABS:
        CALL    RUN_EXPR
        PUSH    HL
        LD      HL,(RT_SP)
        LD      A,(HL)
        INC     HL
        OR      A
        JR      Z,L2F39
        LD      E,(HL)
        INC     HL
        LD      A,(HL)
        OR      A
        JP      P,L2F35
        CALL    CPL_A_DE
        LD      A,D
        OR      A
        JP      M,ERR_13
        LD      (HL),D
        DEC     HL
        LD      (HL),E
L2F35:  POP     HL
        JP      RUN_GETTOK
L2F39:  LD      A,80h
        OR      (HL)
        LD      (HL),A
        JR      L2F35
RUN_TRUNC:
        CALL    RUN_EXPR
        PUSH    HL
        LD      HL,(RT_SP)
        INC     HL
        PUSH    HL
        LD      DE,NUMBUF
        CALL    FP2STR
        LD      DE,NUMBUF
        LD      A,(DE)
        INC     DE
        CP      2Dh
        PUSH    AF
        CALL    STR_TRUNC
        POP     AF
        CALL    Z,NEG_HL
        EX      DE,HL
        POP     HL
        INC     HL
        INC     HL
        LD      (HL),01h
        LD      (RT_SP),HL
        INC     HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        JR      L2F35
RUN_FLOAT:
        CALL    RUN_EXPR
        PUSH    HL
        LD      HL,(RT_SP)
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        LD      A,D
        OR      A
        PUSH    AF
        CALL    M,NEG_DE
        LD      HL,NUMBUF_6
        LD      (HL),0Dh
        LD      HL,NUMBUF
        CALL    BIN2BCD
        EX      DE,HL
        LD      HL,(RT_SP)
        DEC     HL
        DEC     HL
        DEC     HL
        LD      (HL),00h
        LD      (RT_SP),HL
        INC     HL
        PUSH    HL
        EX      DE,HL
        CALL    STR2FP
        POP     HL
        POP     AF
        CALL    M,FP_FIXSIGN
        JR      L2F35

;  STR_TRUNC – Ganzzahlteil eines Zahltexts ab DE lesen (bis "."); für TRUNC.
; <- aufgerufen von 2F56h
STR_TRUNC:
        LD      A,(DE)
        CP      2Eh
        JP      NZ,GET_DEC
        LD      HL,0000h
L2FAA:  LD      A,(DE)
        INC     DE
        CP      0Dh
        RET     Z
        CP      45h
        JR      NZ,L2FAA
        LD      A,(DE)
        CP      2Dh
        RET     Z
        JP      ERR_13
RUN_EXP:
        CALL    RUN_EXPR
        PUSH    HL
        LD      DE,(RT_SP)
        INC     DE
        CALL    FEXP
        POP     HL
        JP      RUN_GETTOK

;  TRAN_INIT – Kommando "J,$13F8" an das Farbterminal senden (beim Kaltstart
;  und nach BREAK in REQTR); Fortsetzung über den Operanden bei L2FF6.
; <- aufgerufen von 1886h, 2E5Dh
TRAN_INIT:
        LD      DE,SYRET_CMD3
L2FCD:  LD      A,(DE)
        INC     DE
        CALL    TRAN_SENDCH
        CP      0Dh
        JR      NZ,L2FCD
        RET

;  TRAN_SENDCH – Zeichen A mit Handshake senden.
; <- aufgerufen von 2FCFh
TRAN_SENDCH:
        PUSH    AF
L2FD8:  IN      A,(0EFh)
        AND     01h
        JR      Z,L2FD8
        POP     AF
        CALL    CALL_SAVE
        OUT     (0EEh),A
        LD      A,06h
        CALL    TRAN_STROBE
        LD      HL,1000h
L2FEC:  IN      A,(0EFh)
        AND     01h
        RET     Z
        DEC     HL
        LD      A,L
        OR      H
        JR      NZ,L2FEC

;  SM_TRAN_CONT – Operand: Fortsetzung nach TRAN_INIT (PAS_NEW oder
;  BREAK_STOP).
SM_TRAN_CONT:
        JP      0000h                   ; Operand wird zur Laufzeit gesetzt
        DEFB    00h,00h,00h,00h,00h,00h
        DEFS    129,00h

;  GR_POINT – Grafikpunkt (GR_X/GR_Y) in allen Ebenen abfragen (POINT).
; <- aufgerufen von 3844h
GR_POINT:
        LD      A,(GATESI)
        PUSH    AF
        SET     0,A
        OUT     (0F4h),A
        CALL    GR_TESTPT
        RLCA
        LD      B,A
        POP     AF
        PUSH    AF
        RES     0,A
        OUT     (0F4h),A
        CALL    GR_TESTPT
        OR      B
        EX      AF,AF'
        POP     AF
        OUT     (0F4h),A
        EX      AF,AF'
        RET

;  GR_TESTPT – Punkt in einer Ebene abfragen (Modus 46h = BIT).
; <- aufgerufen von 3088h, 3093h
GR_TESTPT:
        LD      A,46h
        CALL    GR_PLOT
        PUSH    AF
        INC     A
        JR      Z,L30FC
        POP     AF
        LD      A,00h
        RET     Z
        INC     A
        RET

;  GR_RESET – Punkt an (X,Y) löschen (GRSET).
; <- aufgerufen von 3835h
GR_RESET:
        LD      DE,(GR_X)
        LD      HL,(GR_Y)
L30B3:  PUSH    AF
        LD      A,86h
        JR      L30C2

;  GR_SET – Punkt an (X,Y) setzen (GSET).
; <- aufgerufen von 3827h
GR_SET: LD      DE,(GR_X)
        LD      HL,(GR_Y)

;  GR_SETPT – Punkt setzen (Modus C6h = SET).
; <- aufgerufen von 3208h
GR_SETPT:
        PUSH    AF
        LD      A,0C6h
L30C2:  CALL    GR_PLOT
        POP     AF
        RET

;  GR_PLOT – Punkt setzen/löschen/abfragen (Modus A), Grafik-RAM einblenden.
; <- aufgerufen von 309Fh, 30C2h
GR_PLOT:
        LD      (SM_GR_MASK+1),A
        LD      A,D
        OR      A
        JR      Z,L30D6
        DEC     A
        JR      NZ,L30FD
        LD      A,E
        CP      40h
        JR      NC,L30FD
L30D6:  LD      A,H
        OR      A
        JR      NZ,L30FD
        LD      A,L
        CP      0C8h
        JR      NC,L30FD
        PUSH    BC
        PUSH    DE
        PUSH    HL
        CALL    GR_ADDR

;  SM_GR_MASK – Operand: Maske für die Grafikebene.
SM_GR_MASK:
        OR      0FFh                    ; Operand wird zur Laufzeit gesetzt
        LD      (SM_GR_BITOP+1),A
        DI
        IN      A,(PIO_AD)
        SET     7,A
        OUT     (PIO_AD),A

;  SM_GR_BITOP – Operand: Bitbefehl (SET/RES/BIT n) für den Punkt.
SM_GR_BITOP:
        SET     7,A                     ; Operand wird zur Laufzeit gesetzt
        RES     7,A
        OUT     (PIO_AD),A
        EI
        POP     HL
        POP     DE
        POP     BC
        RET
L30FC:  POP     AF
L30FD:  LD      A,0FFh
        RET

;  GR_ADDR – Adresse und Bitmaske des Punkts (X,Y) berechnen.
; <- aufgerufen von 30E2h
GR_ADDR:
        LD      A,E
        RLA
        RLA
        RLA
        AND     38h
        LD      B,A

;  GR_BYTEADDR – Byteadresse (X/8 + Y*Zeilenlänge) im Grafik-RAM.
; <- aufgerufen von 325Eh
GR_BYTEADDR:
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

;  GR_LINE – Linie von (DE) nach (HL) zeichnen (Bresenham-Verfahren,
;  vermutlich).
; <- aufgerufen von 38BBh
GR_LINE:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        CALL    GL_OFFSET
        PUSH    HL
        LD      B,40h
        LD      A,(GL_X0H)
        ADD     A,B
        LD      (GL_X0H),A
        LD      A,(GL_Y0H)
        ADD     A,B
        LD      (GL_Y0H),A
        POP     HL
        PUSH    DE
        EX      DE,HL
        LD      HL,(GL_Y0)
        CALL    NEG16_BC
        LD      (GL_YDIR),A
        LD      (GL_DY),HL
        POP     DE
        PUSH    HL
        LD      HL,(GL_X0)
        CALL    NEG16_BC
        LD      (GL_XDIR),A
        LD      (GL_DX),HL
        XOR     A
        POP     BC
        EX      AF,AF'
        XOR     A
        SBC     HL,BC
        SET     7,A
        JR      NC,L3178
        XOR     A
        LD      HL,GL_X0
        LD      DE,GL_TMP
        CALL    COPY5
        LD      HL,GL_Y0
        LD      DE,GL_X0
        CALL    COPY5
        LD      HL,GL_TMP
        LD      DE,GL_Y0
        CALL    COPY5
L3178:  EX      AF,AF'
        LD      A,(GL_YDIR)
        AND     A
        LD      A,23h
        JR      Z,L3183
        LD      A,2Bh
L3183:  LD      (L31C8),A
        LD      A,(GL_XDIR)
        AND     A
        LD      A,13h
        JR      Z,L3190
        LD      A,1Bh
L3190:  LD      (L31BE),A
        EXX
        LD      HL,0000h
        LD      DE,(GL_DX)
        LD      BC,(GL_DY)
        EXX
        LD      HL,(GL_Y0)
        LD      DE,(GL_X0)
        LD      BC,(GL_DX)
L31AB:  EX      AF,AF'
        AND     A
        JR      NZ,L31B6
        EX      DE,HL
        CALL    GL_STEP
        EX      DE,HL
        JR      L31B9
L31B6:  CALL    GL_STEP
L31B9:  DEC     BC
        LD      A,B
        INC     A
        JR      Z,L31CF
L31BE:  NOP
        EXX
        ADD     HL,BC
        XOR     A
        SBC     HL,DE
        JP      M,L31CB
        EXX
L31C8:  NOP
        JR      L31AB
L31CB:  ADD     HL,DE
        EXX
        JR      L31AB
L31CF:  POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

;  COPY5 – 5 Bytes kopieren (LDIR).
; <- aufgerufen von 3163h, 316Ch, 3175h
COPY5:  LD      BC,0005h
        LDIR
        RET

;  GL_...: Arbeitsvariablen von GR_LINE (Startpunkt, Differenzen, Richtungen).
GL_X0:  DEFB    00h
GL_X0H: DEFB    00h
GL_DX:  DEFB    00h,00h
GL_XDIR:
        DEFB    00h
GL_Y0:  DEFB    00h
GL_Y0H: DEFB    00h
GL_DY:  DEFB    00h,00h
GL_YDIR:
        DEFB    00h
GL_TMP: DEFB    00h,00h,00h,00h,00h

;  NEG16_BC – BC = -DE (für Linienrichtung).
; <- aufgerufen von 313Bh, 3149h
NEG16_BC:
        LD      A,D
        CPL
        LD      B,A
        LD      A,E
        CPL
        LD      C,A
        ADD     HL,BC
        JR      C,L31FA
        LD      A,L
        CPL
        LD      L,A
        LD      A,H
        CPL
        LD      H,A
        XOR     A
        RET
L31FA:  INC     HL
        LD      A,0FFh
        RET

;  GL_STEP – Einen Schritt der Linie ausführen und den Punkt zeichnen.
; <- aufgerufen von 31B0h, 31B6h
GL_STEP:
        EX      AF,AF'
        PUSH    AF
        LD      A,H
        SUB     40h
        LD      H,A
        LD      A,D
        SUB     40h
        LD      D,A

;  SM_GR_PLOTFN – Operand: Punktroutine für GR_LINE (GR_SET bei LINE, GR_RESET
;  bei BLINE).
SM_GR_PLOTFN:
        CALL    GR_SETPT                ; Operand wird zur Laufzeit gesetzt
        JR      L320E

;  GL_OFFSET – Koordinaten um 4000h verschieben (Vorzeichen für Vergleiche).
; <- aufgerufen von 3121h
GL_OFFSET:
        PUSH    AF
L320E:  LD      A,H
        ADD     A,40h
        LD      H,A
        LD      A,D
        ADD     A,40h
        LD      D,A
        POP     AF
        RET

;  GR_SELECT – Grafik einschalten/Ebene wählen.
; <- aufgerufen von 3921h
GR_SELECT:
        LD      A,0FFh
        LD      (SM_GR_FILL+1),A
        JR      L3224

;  GR_CLEAR – Grafik-RAM ab E000h löschen.
; <- aufgerufen von 3926h
GR_CLEAR:
        LD      A,00h
        LD      (SM_GR_FILL+1),A
L3224:  LD      HL,0E000h
        DI
        IN      A,(PIO_AD)
        SET     7,A
        OUT     (PIO_AD),A
        LD      DE,0E001h

;  SM_GR_FILL – Operand: Füllwert beim Löschen bzw. Füllen des Grafik-RAM.
SM_GR_FILL:
        LD      (HL),00h                ; Operand wird zur Laufzeit gesetzt
        LD      BC,1FFFh
        LDIR
        IN      A,(PIO_AD)
        RES     7,A
        OUT     (PIO_AD),A
        EI
        RET

;  GR_PATTERN – Muster (DE) in das Grafik-RAM schreiben (PATTERN).
; <- aufgerufen von 3A39h
GR_PATTERN:
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
        CALL    GR_BYTEADDR
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
L326F:  SLA     C
        DJNZ    L326F
        AND     A
        LD      A,00h
        JR      Z,L327A
        LD      A,10h
L327A:  LD      (SM_GR_JR+1),A
L327D:  EXX
        LD      E,C
        EXX

;  SM_GR_JR – Operand: Sprungweite (Variante der Füllschleife).
SM_GR_JR:
        JR      L3292                   ; Operand wird zur Laufzeit gesetzt
        XOR     A
        LD      (SM_GR_AND+1),A
        CALL    GR_PATBYTE
        LD      (SM_GR_OR+1),A
        CALL    GR_WRITEBYTE
        INC     HL
        JR      L32B6
L3292:  EXX
        LD      A,B
        EXX
        LD      B,A
        CALL    GR_PATBYTE
L3299:  RLCA
        DJNZ    L3299
        LD      B,A
        AND     C
        LD      (SM_GR_OR+1),A
        LD      A,C
        CPL
        LD      (SM_GR_AND+1),A
        CALL    GR_WRITEBYTE
        INC     HL
        LD      A,C
        LD      (SM_GR_AND+1),A
        CPL
        AND     B
        LD      (SM_GR_OR+1),A
        CALL    GR_WRITEBYTE
L32B6:  EXX
        DEC     D
        JR      Z,L32D7
        EXX
        PUSH    BC

;  SM_GR_STEP – Operand: Schrittweite (PATTERN).
SM_GR_STEP:
        LD      BC,0029h                ; Operand wird zur Laufzeit gesetzt
        XOR     A
L32C0:  SBC     HL,BC
        POP     BC
        INC     DE
        EXX
        DEC     E
        EXX
        JR      NZ,SM_GR_JR
        INC     IX
        PUSH    IX
        POP     HL
        PUSH    BC
        LD      BC,0008h
        ADD     IY,BC
        POP     BC
        JR      L327D
L32D7:  LD      (GR_X),IY
        RET

;  GR_PATBYTE – Ein Musterbyte bitweise ausgeben.
; <- aufgerufen von 3286h, 3296h
GR_PATBYTE:
        LD      A,(DE)
        EXX
        LD      L,08h
        LD      H,A
L32E1:  SRL     H
        RLA
        DEC     L
        JR      NZ,L32E1
        EXX
        RET

;  GR_WRITEBYTE – Byte in das Grafik-RAM schreiben (Maske über die Operanden
;  L32FA/L32FC).
; <- aufgerufen von 328Ch, 32A6h, 32B3h
GR_WRITEBYTE:
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

;  SM_GR_AND – Operand: UND-Maske beim Schreiben ins Grafik-RAM.
SM_GR_AND:
        AND     0FFh                    ; Operand wird zur Laufzeit gesetzt

;  SM_GR_OR – Operand: ODER-Maske beim Schreiben ins Grafik-RAM.
SM_GR_OR:
        OR      00h                     ; Operand wird zur Laufzeit gesetzt
        LD      (HL),A
        IN      A,(PIO_AD)
        RES     7,A
        OUT     (PIO_AD),A
        EI
        RET
GR_X:   DEFB    00h,00h
GR_Y:   DEFB    00h,00h

;  PRT_NL_IFCOL – Drucker: neue Zeile nur, wenn die Spalte (PRT_COLUMN) nicht
;  0 ist.
PRT_NL_IFCOL:
        LD      A,(PRT_COLUMN)
        OR      A
        RET     Z

;  PRT_NEWLINE – Drucker: Zeilenvorschub (nach Statusprüfung).
; <- aufgerufen von 1A19h, 344Fh
PRT_NEWLINE:
        CALL    PRT_STATUS
        LD      A,0Ah
        CALL    PRT_OUT
        XOR     A
        LD      (PRT_COLUMN),A
        RET
        PUSH    BC
        PUSH    DE
        LD      A,(PRT_COLUMN)
        LD      B,A
L3323:  LD      A,(DE)
        CP      0Dh
        JP      Z,L33B6
        CP      20h
        CALL    C,PRT_CTRL
        CALL    PRT_OUT
        INC     B
        INC     DE
        JR      L3323

;  PRT_CTRL – Steuerzeichen 05h-15h für den Drucker umsetzen.
; <- aufgerufen von 332Bh
PRT_CTRL:
        CP      05h
        JR      Z,L3359
        CP      06h
        JR      Z,L3373
        CP      10h
        JR      Z,L3385
        CP      11h
        JR      Z,L336A
        CP      12h
        JR      Z,L3366
        CP      13h
        JR      Z,L338A
        CP      14h
        JR      Z,L338E
        CP      15h
        JR      Z,L339A
        POP     AF
        INC     DE
        JR      L3323
L3359:  LD      A,0Ch
L335B:  PUSH    HL
        LD      HL,01E0h
        LD      (PRT_GRPTR),HL
        POP     HL
L3363:  LD      B,0FFh
        RET
L3366:  LD      A,0Eh
        JR      L335B
L336A:  CALL    PRT_ESC
        XOR     A
        LD      (PRT_ESCARG),A
        JR      L335B
L3373:  LD      A,14h
        CALL    PRT_OUT
        LD      A,12h
        CALL    PRT_OUT
        CALL    PRT_ESC2
        CALL    PRT_OUT
        JR      L3359
L3385:  CALL    PRT_ESC2
        JR      L335B
L338A:  LD      A,14h
        JR      L335B
L338E:  PUSH    HL
        LD      HL,0330h
        LD      (PRT_GRPTR),HL
        POP     HL
        LD      A,0Fh
        JR      L3363
L339A:  LD      A,12h
        JR      L335B

;  PRT_LINE – Text DE bis 0Dh auf den Drucker, dann PRT_STATUS.
; <- aufgerufen von 1A0Fh
PRT_LINE:
        CALL    PRT_TEXT
        JP      PRT_STATUS

;  PRT_TEXT – Text DE bis 0Dh auf den Drucker (Spalte mitzählen, max. 80).
; <- aufgerufen von 339Eh
PRT_TEXT:
        PUSH    BC
        PUSH    DE
        LD      A,(PRT_COLUMN)
        LD      B,A
L33AA:  LD      A,(DE)
        CP      0Dh
        JR      Z,L33B6
        CALL    PRT_OUT
        INC     DE
        INC     B
        JR      L33AA
L33B6:  LD      A,B
        CP      50h
        JR      C,L33BD
        SUB     50h
L33BD:  LD      (PRT_COLUMN),A
        POP     DE
        POP     BC
        RET

;  PRT_ESC2 – ESC-Folge mit Parameter senden.
; <- aufgerufen von 337Dh, 3385h
PRT_ESC2:
        CALL    PRT_ESC
        LD      A,02h
        LD      (PRT_ESCARG),A
        RET
PRT_ESCARG:
        DEFB    02h

;  PRT_QUERY – ESC-Kommando A senden und Status von Port FEh lesen.
; <- aufgerufen von 3412h, 341Ah
PRT_QUERY:
        LD      B,A
        CALL    PRT_ESC
        LD      A,B
        CALL    PRT_OUT
        CALL    PRT_WAIT
        IN      A,(0FEh)
        RRCA
        RRCA
        RET

;  PRT_ESC – ESC (1Bh) an den Drucker.
; <- aufgerufen von 336Ah, 33C3h, 33CEh, 3425h, 3497h, 34BDh, 34CCh
PRT_ESC:
        LD      A,1Bh

;  PRT_OUT – Zeichen A an den Drucker: warten bis bereit, Port FFh, Strobe
;  über Port FEh. Drucker aus -> ERR_42.
; <- aufgerufen von 3315h, 332Eh, 3375h, 337Ah, 3380h, 33AFh, 33D2h, 342Ah ... (16)
PRT_OUT:
        PUSH    AF
        CALL    PRT_WAIT
        POP     AF
        OUT     (0FFh),A
        LD      A,80h
        OUT     (0FEh),A
        LD      A,01h
        CALL    PRT_WAIT_A
        XOR     A
        OUT     (0FEh),A
        RET

;  PRT_WAIT – Auf den Drucker warten (Status Port FEh, Bit A); Zeitüberlauf ->
;  ERR_42.
; <- aufgerufen von 33D5h, 33E0h
PRT_WAIT:
        XOR     A

;  PRT_WAIT_A – Auf Status-Bit A an Port FEh warten; Zeitüberlauf -> ERR_42.
; <- aufgerufen von 33ECh
PRT_WAIT_A:
        PUSH    BC
        PUSH    DE
        LD      C,A
        LD      B,0Fh
        LD      DE,0000h
L33FC:  IN      A,(0FEh)
        AND     0Dh
        CP      C
        JR      Z,L340D
        DEC     DE
        LD      A,D
        OR      E
        JR      NZ,L33FC
        DJNZ    L33FC
        JP      ERR_42
L340D:  POP     DE
        POP     BC
        RET

;  PRT_STATUS – Druckerstatus prüfen: Papierende -> ERR_43, Störung -> ERR_44.
; <- aufgerufen von 3310h
PRT_STATUS:
        LD      A,03h
        CALL    PRT_QUERY
        JP      NC,ERR_43
        LD      A,04h
        CALL    PRT_QUERY
        RET     C
        JP      ERR_44
PRT_COLUMN:
        DEFB    00h

;  PRT_NL_VEC – Sprung nach PRT_NEWLINE (Sprungvektor hinter PRT_COLUMN).
PRT_NL_VEC:
        JP      PRT_NEWLINE

;  PRT_IMAGE – IMAGE: Bitmuster als Grafikzeile an den Drucker.
; <- aufgerufen von 37AAh
PRT_IMAGE:
        CALL    PRT_ESC
        LD      A,18h
        CALL    PRT_OUT
        LD      A,L
        CALL    PRT_OUT
        LD      A,H
        CALL    PRT_OUT
L3435:  LD      A,(DE)
        CALL    PRT_OUT
        INC     DE
        DEC     HL
        LD      A,H
        OR      L
        JR      NZ,L3435
        RET
PRT_GRPTR:
        DEFB    0E0h,01h

;  PRT_COPY – COPY: Bildschirm (Text bzw. Grafik) als Hardcopy drucken.
; <- aufgerufen von 37DAh
PRT_COPY:
        JR      Z,L3477
        INC     A
        JR      Z,L3473
        INC     A
        JR      Z,L3481
        LD      HL,0D000h
        LD      C,19h
L344F:  CALL    PRT_NEWLINE
        LD      A,(SCR_WIDTH+1)
        LD      B,A
L3456:  CALL    DSPRED
        OR      A
        JR      Z,L3460
        CP      0Dh
        JR      NZ,L3462
L3460:  LD      A,20h
L3462:  CALL    PRT_OUT
        CALL    BRKEY
        JR      Z,L34C9
        INC     HL
        DJNZ    L3456
        DEC     C
        JR      NZ,L344F
        JP      PRT_NEWLINE
L3473:  LD      A,0C7h
        JR      L3483
L3477:  LD      A,87h
        LD      (SM_HC_BIT+1),A
        LD      HL,7947h
        JR      L3489
L3481:  LD      A,87h
L3483:  LD      (SM_HC_BIT+1),A
        LD      HL,0918h
L3489:  LD      (L352B),HL
        LD      A,(MODE)
        BIT     4,A
        CALL    Z,HC_REVERSE
        CALL    NZ,HC_NORMAL
        CALL    PRT_ESC
        XOR     A
        CALL    PRT_OUT
        LD      HL,0DEE8h
        LD      DE,0118h
        LD      C,19h
L34A6:  CALL    BRKEY
        JR      Z,L34C6
        LD      B,28h
        CALL    PRT_GRMODE
        ADD     HL,DE
L34B1:  CALL    HC_COLUMN
        INC     HL
        DJNZ    L34B1
        DEC     C
        JR      NZ,L34A6
        CALL    PRT_ESCARG_OUT

;  PRT_ESCARG_OUT – ESC und PRT_ESCARG senden.
; <- aufgerufen von 34BAh, 34C6h
PRT_ESCARG_OUT:
        CALL    PRT_ESC
        LD      A,(PRT_ESCARG)
        JP      PRT_OUT
L34C6:  CALL    PRT_ESCARG_OUT
L34C9:  JP      BREAK_STOP

;  PRT_GRMODE – Drucker in den Grafikmodus schalten (ESC 18h 40h ...).
; <- aufgerufen von 34ADh
PRT_GRMODE:
        CALL    PRT_ESC
        LD      A,18h
        CALL    PRT_OUT
        LD      A,40h
        CALL    PRT_OUT
        LD      A,01h
        JP      PRT_OUT

;  HC_COLUMN – Eine Spalte der Hardcopy (8 Punkte) aufbauen und senden.
; <- aufgerufen von 34B1h
HC_COLUMN:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      DE,HC_BUF
        LD      B,08h
L34E6:  PUSH    BC
        LD      BC,0028h
        CALL    GR_READBYTE
        LD      (DE),A
        INC     DE
        ADD     HL,BC
        POP     BC
        DJNZ    L34E6
        LD      C,08h
L34F5:  LD      HL,HC_LINE
        LD      B,08h
        XOR     A
L34FB:  RRC     (HL)
        RLA
        DEC     HL
        DJNZ    L34FB
        CALL    PRT_OUT
        DEC     C
        JR      NZ,L34F5
        POP     HL
        POP     DE
        POP     BC
        RET

;  HC_NORMAL – Lesebefehle für normale Darstellung einstellen.
; <- aufgerufen von 3494h
HC_NORMAL:
        XOR     A
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl

;  HC_REVERSE – Lesebefehle für inverse Darstellung (CPL) einstellen.
; <- aufgerufen von 3491h
HC_REVERSE:
        LD      A,2Fh
        LD      (L3529),A
        LD      (L3533),A
        RET

;  GR_READBYTE – Byte aus dem Grafik-RAM lesen (für die Hardcopy).
; <- aufgerufen von 34EAh
GR_READBYTE:
        DI
        EXX
        IN      A,(PIO_AD)
        SET     7,A
        OUT     (PIO_AD),A
        EX      AF,AF'
        LD      A,(GATESI)
        LD      C,A

;  SM_HC_BIT – Operand: Bitbefehl beim Lesen für die Hardcopy.
SM_HC_BIT:
        RES     0,A                     ; Operand wird zur Laufzeit gesetzt
        OUT     (0F4h),A
        EXX
        LD      A,(HL)
L3529:  CPL
        EXX
L352B:  LD      B,A
        LD      A,C
        SET     0,A
        OUT     (0F4h),A
        EXX
        LD      A,(HL)
L3533:  CPL
        EXX
        OR      B
        EX      AF,AF'
        RES     7,A
        OUT     (PIO_AD),A
        EXX
        EX      AF,AF'
        EI
        RET
HC_BUF: DEFB    00h,00h,00h,00h,00h,00h,00h
HC_LINE:
        DEFS    58,00h

;  RCMD_C – RC40/RC80: 40 bzw. 80 Zeichen je Zeile.
RCMD_C: CALL    GET_DEC_BYTE
        PUSH    DE
        CP      28h
        PUSH    AF
        CALL    Z,CHR40
        POP     AF
        JR      Z,L3594
        CP      50h
        JR      NZ,L35B8
        CALL    CHR80
L3594:  POP     DE
L3595:  CALL    GET_UPCHAR
        CP      2Ch
        JR      Z,PCMD_R
        CP      0Dh
        JR      NZ,L35B8
        RET

;  PCMD_R – R – Systemkommandos: RC40/RC80, RN (normal), RR (invers), RS a,e
;  (Rollbereich).
PCMD_R: CALL    GET_UPCHAR
        CP      43h
        JR      Z,RCMD_C
        CP      4Eh
        CALL    Z,SCR_NORMAL
        JR      Z,L3595
        CP      52h
        CALL    Z,SCR_REVERSE
        JR      Z,L3595
        CP      53h
L35B8:  JP      NZ,ERR_40
        CALL    GET_DEC_BYTE
        INC     A
        JP      Z,ERR_13
        CP      19h
L35C4:  JP      NC,ERR_13
        PUSH    AF
        CALL    GET_UPCHAR
        CP      2Ch
        JR      NZ,L35B8
        CALL    GET_DEC_BYTE
        CP      19h
        JR      NC,L35C4
        POP     AF
        CP      L
        JP      NC,ERR_40
        LD      (SCROST),A
        LD      A,L
        LD      (SCREND),A
        CALL    SCRSET
        JR      L3595

;  GET_DEC_BYTE – Dezimalzahl < 256 lesen (sonst ERR_13), Kommando sonst
;  ERR_40.
; <- aufgerufen von 3580h, 35BBh, 35CFh
GET_DEC_BYTE:
        CALL    SKIP_SPC
        CALL    IS_DIGIT
        JP      C,ERR_40
        CALL    GET_DEC
        LD      A,H
        OR      A
        JP      NZ,ERR_13
        LD      A,L
        RET

;  SCR_NORMAL – Normaldarstellung (MODE Bit 7 aus, PPI Port A).
; <- aufgerufen von 35AAh, 39A4h
SCR_NORMAL:
        LD      A,(MODE)
        SET     4,A
        JR      L3606

;  SCR_REVERSE – Inversdarstellung (MODE Bit 7 an).
; <- aufgerufen von 35B1h, 39A9h
SCR_REVERSE:
        LD      A,(MODE)
        RES     4,A
L3606:  LD      (MODE),A
        OUT     (PPI_A),A
        RET

;  PCMD_F – F – Belegung der Funktionstasten anzeigen.
PCMD_F: CALL    CHK_EOL
        LD      HL,FKTAB
        LD      B,00h
        LD      DE,(INBUF)
L3618:  PUSH    DE
        LD      A,20h
        LD      (DE),A
        INC     DE
        LD      (DE),A
        INC     DE
        LD      (DE),A
        XOR     A
        LD      A,B
        INC     A
        DAA
        LD      B,A
        CP      10h
        JR      C,L3635
        AND     0F0h
        RRCA
        RRCA
        RRCA
        RRCA
        OR      30h
        LD      (DE),A
        LD      A,B
        AND     0Fh
L3635:  INC     DE
        OR      30h
        LD      (DE),A
        INC     DE
        LD      A,20h
        LD      (DE),A
        INC     DE
        PUSH    BC
L363F:  LD      A,(HL)
        LDI
        CP      0Dh
        JR      NZ,L363F
        POP     BC
        POP     DE
        CALL    LETNL
        CALL    MSGX
        LD      A,B
        CP      20h
        JR      C,L3618
        JP      LETNL

;  GET_UPCHAR – Leerzeichen überspringen, nächstes Zeichen holen.
; <- aufgerufen von 143Fh, 3595h, 35A1h, 35C8h
GET_UPCHAR:
        CALL    SKIP_SPC
        INC     DE
        RET

;  SYN_XYARGS – GSET(, GRSET(, POSITION(, CURSOR( prüfen.
SYN_XYARGS:
        CALL    SYN_INTEXPR
        CP      78h
        JP      NZ,ERR_15
        JP      SYN_TEMPO

;  SYN_LINES – LINE(, BLINE( prüfen.
SYN_LINES:
        CALL    SYN_INT_COMMA
        CP      78h
        JP      NZ,ERR_15
L366E:  CALL    SYN_INT_COMMA
        CP      78h
        JR      Z,L366E

;  SYN_RPAR – ")" muss folgen (sonst ERR_08).
; <- aufgerufen von 372Dh
SYN_RPAR:
        CP      8Dh
        RET     Z
        JP      ERR_08

;  SYN_FKEY_PAT – FKEY(, PATTERN( prüfen.
SYN_FKEY_PAT:
        CALL    SYN_INTEXPR
        CP      78h
        JP      NZ,ERR_15
        CALL    SYN_GETTOK
        CP      0E0h
        JR      Z,L3696
        DEC     DE
        LD      A,02h
        CALL    SYN_EXPR_T
L3690:  CP      78h
        JR      Z,SYN_FKEY_PAT
        JR      SYN_RPAR
L3696:  CALL    SYN_SKIPCMT
        JR      L3690

;  SYN_INT_COMMA – INTEGER-Ausdruck und "," prüfen (sonst ERR_15).
; <- aufgerufen von 3666h, 366Eh, 36FDh, 372Ah
SYN_INT_COMMA:
        CALL    SYN_INTEXPR
        CP      78h
        JP      NZ,ERR_15

;  SYN_INTEXPR – INTEGER-Ausdruck prüfen.
; <- aufgerufen von 365Bh, 367Bh, 369Bh, 36D1h, 370Ah, 374Ah
SYN_INTEXPR:
        LD      A,01h
        JP      SYN_EXPR_T
SYN_GRAPH:
        CALL    SYN_OPTION
L36AB:  JP      NZ,ERR_45
        LD      A,B
        LD      B,00h
        CP      49h
        JR      Z,L36C9
        INC     B
        CP      4Fh
        JR      Z,L36C9
        INC     B
        CP      43h
        JR      Z,L36C4
        INC     B
        CP      46h
        JR      NZ,L36AB
L36C4:  CALL    SYN_OPTARG
        JR      L36D4
L36C9:  CALL    SYN_OPTARG
        CP      78h
        JP      NZ,ERR_15
        CALL    SYN_INTEXPR
L36D4:  CP      78h
        JR      Z,SYN_GRAPH
        JR      SYN_RPAR
SYN_RANGE:
        CALL    SYN_OPTION
        JR      NZ,L36AB
        LD      A,B
        LD      B,00h
        CP      43h
        JR      Z,L3702
        INC     B
        CP      4Eh
        JR      Z,L3714
        INC     B
        CP      52h
        JR      Z,L3714
        INC     B
        CP      53h
        JR      NZ,L36AB
        CALL    SYN_OPTARG
        CP      78h
        JP      NZ,ERR_15
        CALL    SYN_INT_COMMA
        JR      L370D
L3702:  CALL    SYN_OPTARG
        CP      78h
        JP      NZ,ERR_15
        CALL    SYN_INTEXPR
L370D:  CP      78h
        JR      Z,SYN_RANGE
        JP      SYN_RPAR
L3714:  CALL    SYN_OPTARG
        JR      L370D

;  SYN_OPTION – Kennbuchstaben eines Arguments (z. B. GRAPH(I/O/C/F ...))
;  holen.
; <- aufgerufen von 36A8h, 36DAh
SYN_OPTION:
        CALL    SYN_GETTOK
        LD      B,A
        LD      A,(DE)
        INC     DE
        CP      0E2h
        RET

;  SYN_OPTARG – Option übernehmen und nächstes Token holen.
; <- aufgerufen von 36C4h, 36C9h, 36F5h, 3702h, 3714h
SYN_OPTARG:
        LD      A,B
        LD      (DE),A
        INC     DE
        INC     DE
        INC     DE
        JP      SYN_GETTOK
SYN_POINT:
        CALL    SYN_INT_COMMA
        CALL    SYN_RPAR

;  SYN_FN_POS – POSH, POSV, CSRH, CSRV prüfen (ganzzahlig, ohne Argument).
SYN_FN_POS:
        LD      A,01h
        RET
SYN_FNAME:
        CALL    SYN_GETTOK
        CP      0E0h
        JR      Z,L3745
        CP      0B3h
        JP      NZ,ERR_04
        CALL    SYN_GETTOK
L3742:  JP      SYN_RPAR
L3745:  CALL    SYN_SKIPCMT
        JR      L3742
SYN_COPY:
        CALL    SYN_INTEXPR
        JR      L3742
FILE_NAMEFLAG:
        DEFB    00h
FILE_NAME:
        DEFS    17,00h
RUN_FNAME:
        LD      A,(FILE_STATE+1)
        CP      03h
        JP      C,ERR_46
        LD      A,03h
        LD      (FILE_STATE+1),A
        XOR     A
        LD      (FILE_NAMEFLAG),A
        CALL    RUN_GETTOK
        CP      0E0h
        JR      Z,L3788
        EXX
        CALL    ASK_FILENAME
L377D:  LD      BC,0011h
        LD      DE,FILE_NAME
        LDIR
        JP      L381C
L3788:  CALL    EVAL_TEXT
        EXX
        LD      HL,LINEBUF
        JR      L377D
RUN_IMAGE:
        CALL    RUN_GETTOK
        CP      0E0h
        JR      Z,L37B6
        DEC     HL
        CALL    RUN_EXPR
        PUSH    HL
        LD      HL,(RT_SP)
        INC     HL
        INC     HL
        LD      (RT_SP),HL
        DEC     HL
        LD      DE,0001h
        EX      DE,HL
L37AA:  CALL    PRT_IMAGE
        POP     HL
        CALL    RUN_GETTOK
        CP      78h
        JR      Z,RUN_IMAGE
        RET
L37B6:  CALL    EVAL_TEXT
        PUSH    HL
        LD      HL,LINEBUF
        EX      DE,HL
        XOR     A
        SBC     HL,DE
        JR      L37AA
RUN_COPY:
        CALL    RUN_EXPR
        PUSH    HL
        CALL    RT_POPINT
        LD      (RT_SP),HL
        JP      NZ,ERR_13
        OR      B
        JP      Z,ERR_13
        SUB     05h
        JP      NC,ERR_13
        INC     A
        CALL    PRT_COPY
        JP      L382A

;  RUN_INTEXPR – INTEGER-Ausdruck auswerten.
; <- aufgerufen von 3815h, 3820h, 382Eh, 383Ah, 3897h, 38A2h, 3982h, 39D3h
RUN_INTEXPR:
        CALL    RUN_EXPR

;  RUN_NEXTEXPR – Trennzeichen überspringen, nächsten Ausdruck auswerten.
; <- aufgerufen von 392Bh, 3944h, 39AEh
RUN_NEXTEXPR:
        CALL    RUN_GETTOK
        JP      RUN_EXPR

;  RUN_XY – Zwei Koordinaten vom Stapel holen und prüfen.
; <- aufgerufen von 3819h, 3824h, 3832h, 383Eh
RUN_XY: CALL    RT_POPX
        LD      (GR_Y),DE
        CALL    RT_POPY
        LD      (GR_X),DE
        RET

;  RT_POPINT – Obersten INTEGER lesen (RT_SP bleibt): B = niederwertiges Byte,
;  A = höherwertiges, NZ wenn > 255.
; <- aufgerufen von 37C7h, 3802h, 3809h, 39D7h
RT_POPINT:
        LD      HL,(RT_SP)
        INC     HL
        LD      B,(HL)

;  RT_INTHI – Höherwertiges Byte des INTEGERs lesen, NZ wenn ungleich 0.
; <- aufgerufen von 380Eh
RT_INTHI:
        INC     HL
        LD      A,(HL)
        INC     HL
        OR      A
        RET

;  RT_POPBYTE – Wie RT_POPINT, Eintrag vom Stapel nehmen.
; <- aufgerufen von 392Fh, 3948h, 39B2h, 3A74h
RT_POPBYTE:
        CALL    RT_POPINT
        LD      (RT_SP),HL
        RET

;  RT_POP2BYTES – Zwei Byte-Werte vom Stapel (B, C).
; <- aufgerufen von 3986h
RT_POP2BYTES:
        CALL    RT_POPINT

;  RT_POP2B_2 – Zweiten Byte-Wert holen, Eintrag entfernen.
; <- aufgerufen von 39E3h
RT_POP2B_2:
        INC     HL
        LD      C,(HL)
        CALL    RT_INTHI
        LD      (RT_SP),HL
        RET
RUN_POSITION:
        CALL    RUN_INTEXPR
        EXX
        CALL    RUN_XY
L381C:  EXX
        JP      RUN_GETTOK
RUN_GSET:
        CALL    RUN_INTEXPR
        PUSH    HL
        CALL    RUN_XY
        CALL    GR_SET
L382A:  POP     HL
        JP      RUN_GETTOK
RUN_GRSET:
        CALL    RUN_INTEXPR
        PUSH    HL
        CALL    RUN_XY
        CALL    GR_RESET
        JR      L382A
RUN_POINT:
        CALL    RUN_INTEXPR
        PUSH    HL
        CALL    RUN_XY
        LD      HL,(GR_Y)
        CALL    GR_POINT
        CALL    RT_PUSHBYTE
        JR      L382A

;  RT_PUSHBYTE – Byte A als INTEGER auf den Laufzeitstapel.
; <- aufgerufen von 3847h, 3861h
RT_PUSHBYTE:
        LD      D,00h
        LD      E,A

;  RT_PUSHDE – DE als INTEGER auf den Laufzeitstapel.
; <- aufgerufen von 3870h
RT_PUSHDE:
        LD      HL,(RT_SP)
        DEC     HL
        LD      (HL),D
        DEC     HL
        LD      (HL),E
        DEC     HL
        LD      (HL),01h
        LD      (RT_SP),HL
        RET
RUN_CSRV:
        LD      A,(DSPXY1)
L3860:  EXX
        CALL    RT_PUSHBYTE
L3864:  EXX
        RET
RUN_CSRH:
        LD      A,(DSPXY)
        JR      L3860
RUN_POSH:
        EXX
        LD      DE,(GR_X)
L3870:  CALL    RT_PUSHDE
        JR      L3864
RUN_POSV:
        EXX
        LD      DE,(GR_Y)
        JR      L3870
RUN_BLINE:
        EXX
        LD      HL,L30B3
        JR      L3886
RUN_LINE:
        EXX
        LD      HL,GR_SETPT
L3886:  LD      DE,(SM_GR_PLOTFN+1)
        PUSH    DE
        LD      (SM_GR_PLOTFN+1),HL
        LD      HL,(SM_LINE_X+1)
        PUSH    HL
        LD      HL,(SM_LINE_Y+1)
        PUSH    HL
        EXX
        CALL    RUN_INTEXPR
        CALL    RUN_GETTOK
        EXX
        CALL    RUN_COORD
        EXX
L38A2:  CALL    RUN_INTEXPR
        PUSH    HL
        LD      HL,(SM_LINE_X+1)
        LD      (GL_X0),HL
        LD      HL,(SM_LINE_Y+1)
        LD      (GL_Y0),HL
        CALL    RUN_COORD

;  SM_LINE_X – Operand: X des letzten Punkts von LINE/BLINE.
SM_LINE_X:
        LD      DE,0000h                ; Operand wird zur Laufzeit gesetzt

;  SM_LINE_Y – Operand: Y des letzten Punkts von LINE/BLINE.
SM_LINE_Y:
        LD      HL,0000h                ; Operand wird zur Laufzeit gesetzt
        CALL    GR_LINE
        POP     HL
        CALL    RUN_GETTOK
        CP      78h
        JR      Z,L38A2
        EX      DE,HL
        LD      HL,(SM_LINE_X+1)
        LD      (GR_X),HL
        LD      HL,(SM_LINE_Y+1)
        LD      (GR_Y),HL
        POP     HL
        LD      (SM_LINE_Y+1),HL
        POP     HL
        LD      (SM_LINE_X+1),HL
        POP     HL
        LD      (SM_GR_PLOTFN+1),HL
        EX      DE,HL
        RET

;  RUN_COORD – Koordinate holen und prüfen.
; <- aufgerufen von 389Eh, 38B2h
RUN_COORD:
        CALL    RT_POPX
        LD      (SM_LINE_Y+1),DE
        CALL    RT_POPY
        LD      (SM_LINE_X+1),DE
        RET

;  RT_POPX – Erste Koordinate (DE) vom Stapel lesen und prüfen.
; <- aufgerufen von 37E9h, 38E1h
RT_POPX:
        LD      HL,(RT_SP)
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        INC     HL
        JP      L3903

;  RT_POPY – Nächste Koordinate (DE) vom Stapel nehmen; erlaubt ist
;  -16384..16383, sonst ERR_13.
; <- aufgerufen von 37F0h, 38E8h
RT_POPY:
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        LD      (RT_SP),HL
L3903:  LD      A,3Fh
        CP      D
        RET     NC
        LD      A,0BFh
        CP      D
        RET     C
        JP      ERR_13
GRAPH_IN:
        DEFB    00h
GRAPH_OUT:
        DEFB    00h
RUN_GRAPH:
        CALL    RUN_GETTOK
        LD      A,(HL)
        INC     HL
        INC     HL
        INC     HL
        OR      A
        JR      Z,L392B
        DEC     A
        JR      Z,L3944
        PUSH    HL
        DEC     A
        JR      Z,L3926
        CALL    GR_SELECT
        JR      L3959
L3926:  CALL    GR_CLEAR
        JR      L3959
L392B:  CALL    RUN_NEXTEXPR
        PUSH    HL
        CALL    RT_POPBYTE
        JP      NZ,ERR_13
        OR      B
        JP      Z,ERR_13
        CP      03h
        JP      NC,ERR_13
        DEC     A
        LD      (GRAPH_OUT),A
        JR      L3959
L3944:  CALL    RUN_NEXTEXPR
        PUSH    HL
        CALL    RT_POPBYTE
        JP      NZ,ERR_13
        OR      B
        CP      04h
        JP      NC,ERR_13
        SLA     A
        LD      (GRAPH_IN),A
L3959:  LD      A,(GRAPH_OUT)
        LD      B,A
        LD      A,(GRAPH_IN)
        OR      B
        LD      (GATESI),A
        OUT     (0F4h),A
        POP     HL
        CALL    RUN_GETTOK
        CP      78h
        JR      Z,RUN_GRAPH
        RET
RUN_RANGE:
        CALL    RUN_GETTOK
        LD      A,(HL)
        INC     HL
        INC     HL
        INC     HL
        OR      A
        JR      Z,L39AE
        DEC     A
        JR      Z,L39A4
        DEC     A
        JR      Z,L39A9
        CALL    RUN_GETTOK
        CALL    RUN_INTEXPR
        PUSH    HL
        CALL    RT_POP2BYTES
        JP      NZ,ERR_13
        LD      A,B
        CP      19h
        JP      NC,ERR_13
        LD      A,C
        INC     A
        CP      B
        JP      NC,ERR_13
        LD      (SCROST),A
        LD      A,B
        LD      (SCREND),A
        CALL    SCRSET
        JR      L39C5
L39A4:  CALL    SCR_NORMAL
        JR      L39C6
L39A9:  CALL    SCR_REVERSE
        JR      L39C6
L39AE:  CALL    RUN_NEXTEXPR
        PUSH    HL
        CALL    RT_POPBYTE
        JP      NZ,ERR_13
        LD      A,B
        CP      28h
        JR      Z,L39CE
        CP      50h
        JP      NZ,ERR_13
        CALL    CHR80
L39C5:  POP     HL
L39C6:  CALL    RUN_GETTOK
        CP      78h
        JR      Z,RUN_RANGE
        RET
L39CE:  CALL    CHR40
        JR      L39C5
RUN_CURSOR:
        CALL    RUN_INTEXPR
        EXX
        CALL    RT_POPINT
        JP      NZ,ERR_13
        LD      A,B
        CP      19h
        JP      NC,ERR_13
        CALL    RT_POP2B_2
        JP      NZ,ERR_13
        LD      A,(SCR_WIDTH+1)
        DEC     A
        CP      C
        JP      C,ERR_13
        LD      (DSPXY),BC
        EXX
        JP      RUN_GETTOK
RUN_PATTERN:
        CALL    RUN_EXPR
        CALL    RUN_GETTOK
        CALL    RUN_GETTOK
        CP      0E0h
        JR      Z,L3A45
        DEC     HL
        CALL    RUN_EXPR
        PUSH    HL
        LD      HL,(RT_SP)
        LD      (HL),01h
        INC     HL
        PUSH    HL
        INC     HL
L3A13:  INC     HL
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        INC     HL
        LD      (RT_SP),HL
        LD      A,B
        OR      A
        JP      M,L3A59
        LD      E,C
        LD      D,B
        LD      HL,42EDh
        LD      A,29h
L3A27:  LD      (SM_GR_STEP+1),A
        LD      (L32C0),HL
        LD      A,D
        OR      A
        JP      NZ,ERR_13
        LD      A,E
        CP      0C8h
        JP      NC,ERR_13
        POP     DE
        CALL    GR_PATTERN
        POP     HL
        CALL    RUN_GETTOK
        CP      78h
        JR      Z,RUN_PATTERN
        RET
L3A45:  CALL    EVAL_TEXT
        PUSH    HL
        LD      HL,LINEBUF
        PUSH    HL
        EX      DE,HL
        XOR     A
        SBC     HL,DE
        DEC     DE
        EX      DE,HL
        LD      (HL),E
        LD      HL,(RT_SP)
        JR      L3A13
L3A59:  LD      HL,0000h
        SBC     HL,BC
        EX      DE,HL
        LD      HL,0009h
        LD      A,27h
        JR      L3A27

;  FKEY_PTR (Anfang des Texts der Taste n in FKTAB), FKEY_FREE (freier Platz),
;  FKEY_NEXT (Text der nächsten Taste), FKEY_END (Ende aller Texte): für
;  RUN_FKEY. Die Texte stehen ab FARE (1200h) je mit 0Dh abgeschlossen und
;  dürfen bis 12FFh reichen (sonst ERR_39).
FKEY_PTR:
        DEFB    00h,00h
FKEY_FREE:
        DEFB    00h
FKEY_NEXT:
        DEFB    00h,00h
FKEY_END:
        DEFB    00h,00h
RUN_FKEY:
        CALL    RUN_EXPR
        CALL    RUN_GETTOK
        PUSH    HL
        CALL    RT_POPBYTE
        JP      NZ,ERR_13
        OR      B
        JP      Z,ERR_13
        CP      15h
        JP      NC,ERR_13
        DEC     B
        LD      C,00h
        LD      HL,FKTAB
        CALL    SKIP_LINES_B
        LD      (FKEY_PTR),HL
        CALL    LINE_LEN_CR
        LD      A,E
        LD      (FKEY_FREE),A
        INC     C
        LD      (FKEY_NEXT),HL
        LD      B,14h
        CALL    SKIP_LINES_B
        LD      (FKEY_END),HL
        XOR     A
        SUB     L
        DEC     A
        LD      L,A
        LD      A,(FKEY_FREE)
        ADD     A,L
        LD      (FKEY_FREE),A
        POP     HL
        CALL    RUN_GETTOK
        CP      0E0h
        JR      NZ,L3B0D
        CALL    EVAL_TEXT
        PUSH    HL
L3AB9:  LD      HL,LINEBUF
        EX      DE,HL
        OR      A
        SBC     HL,DE
        LD      A,(FKEY_FREE)
        CP      L
        JP      C,ERR_39
        PUSH    HL
        LD      HL,(FKEY_END)
        LD      DE,(FKEY_NEXT)
        DEC     DE
        SBC     HL,DE
        LD      B,H
        LD      C,L
        LD      HL,(FKEY_PTR)
        EX      DE,HL
        LDIR
        LD      (FKEY_END),DE
        DEC     DE
        POP     HL
        LD      A,L
        OR      H
        JR      Z,L3B09
        PUSH    HL
        ADD     HL,DE
        PUSH    HL
        LD      BC,1300h                ; Ende des Bereichs der Funktionstastentexte
        SBC     HL,BC
        JP      NC,ERR_39
        OR      A
        LD      H,D
        LD      L,E
        INC     HL
        LD      BC,(FKEY_PTR)
        SBC     HL,BC
        LD      B,H
        LD      C,L
        POP     HL
        EX      DE,HL
        LDDR
        LD      HL,LINEBUF
        LD      DE,(FKEY_PTR)
        POP     BC
        LDIR
L3B09:  POP     HL
        JP      RUN_GETTOK
L3B0D:  DEC     HL
        CALL    RUN_EXPR
        PUSH    HL
        LD      HL,(RT_SP)
        INC     HL
        LD      A,(HL)
        INC     HL
        LD      (RT_SP),HL
        CP      0Dh
        JR      NZ,L3B20
        XOR     A
L3B20:  LD      HL,LINEBUF
        LD      (HL),A
        INC     HL
        LD      (HL),0Dh
        EX      DE,HL
        JR      L3AB9

;  LINE_LEN_CR – Zeichen bis einschließlich 0Dh ab HL zählen (E).
; <- aufgerufen von 3A8Fh, 3B34h
LINE_LEN_CR:
        LD      E,00h
        LD      A,0Dh
L3B2E:  INC     E
        CP      (HL)
        INC     HL
        JR      NZ,L3B2E
        RET
L3B34:  CALL    LINE_LEN_CR
        INC     C

;  SKIP_LINES_B – Zeilen überspringen, bis C = B.
; <- aufgerufen von 3A89h, 3A9Ch
SKIP_LINES_B:
        LD      A,C
        CP      B
        JR      C,L3B34
        RET
        DEFS    67,00h

;  PCMD_G – G – Programm ausführen. Erst Prüflauf über den ganzen Text
;  (Deklarationen, Syntax, Typen), Symboltabellen anlegen; beim "." nach dem
;  Hauptblock weiter zur Ausführung (RUN_START).
PCMD_G: CALL    CHK_PROG
        XOR     A
        INC     HL
        LD      (RT_AREA0),HL
        LD      (HL),A
        INC     HL
        LD      (RT_AREA1),HL
        LD      (HL),A
        INC     HL
        LD      (RT_SP),HL
        LD      (HL),A
        INC     HL
        LD      (RT_AREA3),HL
        INC     A
        LD      (RUN_MODE),A
        LD      HL,RT_AREA0
        LD      (SM_SYMTAB+1),HL
        LD      (SM_SYMTAB_IY+2),HL
        LD      HL,SYM_GROW1
        LD      (SM_SYMGROW+1),HL
        INC     DE
        CALL    SYN_DECLS
        DEC     DE
        PUSH    DE
        CALL    SYN_GETTOK
        POP     DE
        CP      69h
        JP      Z,MAIN_BLOCK
        PUSH    DE
        CALL    PUSH_LINENO
L3BBD:  LD      HL,RT_AREA1
        LD      (SM_SYMTAB+1),HL
        LD      HL,SYM_GROW2
        LD      (SM_SYMGROW+1),HL
        LD      IX,TOKLEN_TAB
L3BCD:  CALL    SCAN_TOKEN
        CALL    PUSH_LINENO
        CP      0D8h
        JR      Z,DECL_PROC
        CP      0D9h
        JR      Z,DECL_FUNC
        POP     HL
        CP      77h
        JP      Z,L3C87
        EX      DE,HL
        CALL    TOK_SKIP
        LD      DE,(TXT_END)
        CALL    CP_HL_DE
        EX      DE,HL
        JR      C,L3BCD
        JP      ERR_01
L3BF2:  CALL    SET_LINK

;  SCAN_TOKEN – Nächstes Schlüsselwort/Token (>= 60h) im Text ab DE suchen,
;  Zeilen zählen; Textende -> ERR_01.
; <- aufgerufen von 3BCDh, 3EE1h, 3EE9h
SCAN_TOKEN:
        EX      DE,HL
        DEC     HL
L3BF7:  INC     HL
        LD      A,(HL)
        CP      0Dh
        JR      Z,L3C1C
        CP      60h
        JR      C,L3BF7
        EX      DE,HL
        LD      HL,(TXT_END)
        CALL    CP_HL_DE
        JP      C,ERR_01
        LD      A,(DE)
        INC     DE
        CP      0E0h
        JR      Z,L3BF2
        INC     DE
        CP      0DFh
        JR      Z,L3BF2
        DEC     DE
        CP      0DEh
        JR      Z,L3BF2
        RET
L3C1C:  PUSH    HL
        LD      HL,(LINE_NO)
        INC     HL
        LD      (LINE_NO),HL
        POP     HL
        INC     HL
        JR      L3BF7

;  DECL_PROC – PROCEDURE: Namen eintragen (Art E4h), Parameterliste, Rumpf
;  prüfen.
DECL_PROC:
        PUSH    DE
        PUSH    DE
        CALL    DECLARE3
        LD      (HL),0E4h
        PUSH    HL
        CALL    SYN_FORMALS
        POP     HL
        INC     HL
L3C35:  POP     BC
        PUSH    HL
        INC     HL
        INC     HL
        LD      (HL),C
        INC     HL
        LD      (HL),B
        EXX
        LD      HL,(SYM_LIST1)
        POP     DE
        LD      (HL),E
        INC     HL
        LD      (HL),D
        EXX
        POP     DE
        DEC     DE
        CALL    POP_LINENO
        CALL    SYM_LOCAL
        CALL    SYN_SUBPROG
        CALL    SYM_ENDMARK
        JP      L3BBD

;  DECL_FUNC – FUNCTION: Namen eintragen (Art E5h), Parameter, ":"
;  Ergebnistyp.
DECL_FUNC:
        PUSH    DE
        PUSH    DE
        INC     DE
        CALL    DECLARE3
        PUSH    DE
        PUSH    HL
        LD      HL,(RT_AREA0)
        CALL    SYM_FIND
        POP     HL
        POP     DE
        JP      NC,ERR_02
        LD      (HL),0E5h
        PUSH    HL
        CALL    SYN_FORMALS
        CALL    SYN_GETTOK
        CP      0DDh
        JP      NZ,ERR_03
        INC     DE
        INC     DE
        CALL    SYN_GETTOK
        CALL    TYPE_CODE
        JP      C,ERR_04
        POP     HL
        INC     HL
        LD      (HL),A
        JR      L3C35
L3C87:  CALL    POP_LINENO
        POP     DE
L3C8B:  CALL    SYN_SUBBODY
        CALL    SYN_GETTOK
        DEC     DE
        CP      69h
        JR      NZ,L3C8B

;  MAIN_BLOCK – Hauptblock prüfen; folgt "." -> RUN_START, sonst ERR_01.
MAIN_BLOCK:
        PUSH    DE
        CALL    SYN_BLOCK
        CALL    SYN_GETTOK
        CP      77h
        JP      Z,RUN_START
        JP      ERR_01

;  GET_IDENT – Bezeichner ab DE nach WORKBUF (letztes Zeichen mit Bit 7), max.
;  32 Zeichen (sonst ERR_06); kein Buchstabe -> ERR_05. BC = Länge.
; <- aufgerufen von 3D55h, 43FAh, 45CAh
GET_IDENT:
        CALL    SYN_GETTOK
        DEC     DE
        LD      HL,(WORKBUF)
        PUSH    HL
        LD      BC,0021h
        PUSH    BC
        EX      DE,HL
        CALL    IS_LETTER
        JP      C,ERR_05
L3CB8:  LDI
        JP      PO,ERR_06
        LD      A,(HL)
        CALL    IS_LETTER
        CALL    C,IS_DIGIT
        JR      NC,L3CB8
        DEC     DE
        LD      A,(DE)
        OR      80h
        LD      (DE),A
        PUSH    BC
        INC     HL
        PUSH    HL
        LD      HL,(SYM_LIST1)
        EX      (SP),HL
        LD      (SYM_LIST1),HL
        POP     BC
        LD      (HL),C
        INC     HL
        LD      (HL),B
        INC     HL
        INC     HL
        POP     BC
        EX      DE,HL
        POP     HL
        AND     A
        SBC     HL,BC
        LD      B,H
        LD      C,L
        POP     HL
        RET

;  SET_LINK – Text-/Kommentartoken: Verweis hinter das schließende Zeichen in
;  die beiden Operandenbytes eintragen.
; <- aufgerufen von 1F16h, 3BF2h, 3CFBh
SET_LINK:
        PUSH    DE
        INC     DE
        INC     DE
        LD      A,(DE)
        CP      7Bh
        JR      NZ,L3CEF
        LD      A,7Dh
L3CEF:  INC     DE
        EX      DE,HL
L3CF1:  CP      (HL)
        INC     HL
        JR      NZ,L3CF1
        POP     DE
        EX      DE,HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        RET

;  SYN_SKIPCMT – Kommentar überspringen (SET_LINK), weiter mit SYN_GETTOK.
; <- aufgerufen von 2DCFh, 3696h, 3745h, 425Bh
SYN_SKIPCMT:
        CALL    SET_LINK

;  SYN_GETTOK – Nächstes Zeichen/Token ab DE nach A (Prüflauf). Kommentare
;  werden übersprungen, bei 0Dh wird LINE_NO erhöht und die Einrückung
;  übergangen; Textende -> ERR_01.
; <- aufgerufen von 2DD4h, 2DE4h, 3683h, 3719h, 3733h, 373Fh, 3BB0h, 3C6Fh ... (63)
SYN_GETTOK:
        LD      A,(DE)
        INC     DE
        CP      0DEh
        JR      Z,SYN_SKIPCMT
        CP      0Dh
        RET     NZ
        LD      HL,(LINE_NO)
        INC     HL
        LD      (LINE_NO),HL
        INC     DE
        LD      HL,(TXT_END)
        CALL    CP_HL_DE
        JP      C,ERR_01
        JR      SYN_GETTOK

;  SYN_DECLS – Deklarationsteil: VAR-Abschnitt (SYN_VAR), dann Adressen der
;  Variablen festlegen (Größen aufsummieren).
; <- aufgerufen von 3BABh, 407Fh
SYN_DECLS:
        CALL    SYN_GETTOK
        CP      62h
        CALL    Z,SYN_VAR
        LD      HL,0000h

;  SM_SYMTAB_IY – Operand: Zeiger auf den Anfang der aktuellen Symboltabelle
;  (RT_AREA0 bzw. RT_SP).
SM_SYMTAB_IY:
        LD      IY,(0000h)              ; Operand wird zur Laufzeit gesetzt
L3D29:  LD      A,(IY+0)
        OR      A
        RET     Z
L3D2E:  BIT     7,(IY+0)
        INC     IY
        JR      Z,L3D2E
        INC     IY
        INC     IY
        INC     IY
        LD      C,(IY+0)
        LD      B,(IY+1)
        OR      0FFh
        SBC     HL,BC
        LD      (IY+0),L
        INC     IY
        LD      (IY+0),H
        INC     IY
        JR      L3D29

;  DECLARE3 – DE um 3 weiter, dann DECLARE.
; <- aufgerufen von 3C2Ah, 3C59h
DECLARE3:
        INC     DE
        INC     DE
        INC     DE

;  DECLARE – Bezeichner lesen und in die Symboltabelle (Zeiger bei L3D59)
;  eintragen; schon vorhanden -> ERR_02. Platz über die Routine bei L3D78
;  schaffen.
; <- aufgerufen von 3E62h, 400Dh
DECLARE:
        CALL    GET_IDENT
        PUSH    DE

;  SM_SYMTAB – Operand: Zeiger auf den Anfang der aktuellen Symboltabelle.
SM_SYMTAB:
        LD      HL,(0000h)              ; Operand wird zur Laufzeit gesetzt
        PUSH    BC
        CALL    SYM_FIND
        JP      NC,ERR_02
        PUSH    HL
        CALL    SYM_MAKEROOM
        POP     HL
        LD      DE,(WORKBUF)
        POP     BC
        PUSH    BC
        EX      DE,HL
        LDIR
        EX      DE,HL
        POP     BC
        PUSH    HL
        LD      A,05h
        ADD     A,C
        LD      C,A

;  SM_SYMGROW – Operand: SYM_GROW1/2/3 je nach Tabelle.
SM_SYMGROW:
        CALL    0000h                   ; Operand wird zur Laufzeit gesetzt
        EX      DE,HL
        POP     HL
        POP     DE
        RET

;  SYM_FIND – Namen aus WORKBUF in der Symboltabelle ab HL suchen. NC =
;  gefunden (HL zeigt hinter den Namen), C = nicht gefunden.
; <- aufgerufen von 3C61h, 3D5Dh, 4401h, 45BCh, 45D1h, 45DBh
SYM_FIND:
        LD      DE,(WORKBUF)
        LD      A,(HL)
        SUB     01h
        RET     C
L3D87:  LD      A,(DE)
        CP      (HL)
        JR      NZ,L3D92
        INC     DE
        INC     HL
        RLA
        JR      NC,L3D87
        AND     A
        RET
L3D92:  BIT     7,(HL)
        INC     HL
        JR      Z,L3D92
        LD      A,05h
        CALL    ADD_HL_A
        JR      SYM_FIND

;  SYM_GROW1 – RT_AREA1, RT_SP und RT_AREA3 um BC verschieben.
SYM_GROW1:
        LD      HL,(RT_AREA1)
        ADD     HL,BC
        LD      (RT_AREA1),HL

;  SYM_GROW2 – RT_SP und RT_AREA3 um BC verschieben.
SYM_GROW2:
        LD      HL,(RT_SP)
        ADD     HL,BC
        LD      (RT_SP),HL

;  SYM_GROW3 – RT_AREA3 um BC verschieben; reicht der Speicher bis WORKBUF
;  nicht -> ERR_13.
SYM_GROW3:
        LD      HL,(RT_AREA3)
        ADD     HL,BC
        LD      (RT_AREA3),HL
        PUSH    BC
        LD      BC,(WORKBUF)
        SBC     HL,BC
        POP     BC
        RET     C
        JP      ERR_13

;  SYM_MAKEROOM – Platz (BC + 5 Bytes) in der Symboltabelle schaffen (LDDR).
; <- aufgerufen von 3D64h
SYM_MAKEROOM:
        LD      A,05h
        ADD     A,C
        LD      C,A
        EX      DE,HL
        LD      HL,(RT_AREA3)
        PUSH    HL
        ADD     HL,BC
        EX      DE,HL
        LD      B,H
        LD      C,L
        POP     HL
        PUSH    HL
        AND     A
        SBC     HL,BC
        LD      B,H
        LD      C,L
        POP     HL
        DEC     HL
        DEC     DE
        LDDR
        RET

;  SYN_VAR – VAR-Abschnitt: "Name, Name : Typ ;" bis kein Bezeichner mehr
;  folgt; FILE OF (D7h, 71h) wird vermerkt.
; <- aufgerufen von 3D1Fh
SYN_VAR:
        CALL    SYN_IDLIST
        CP      0D7h
        LD      HL,DECL_FILEFLAG
        LD      (HL),00h
        JR      NZ,L3DF1
        LD      A,(DE)
        INC     DE
        CP      71h
        JP      NZ,ERR_07
        LD      (HL),20h
        CALL    SYN_GETTOK
L3DF1:  CALL    SYN_ARRAYTYPE
        CALL    DECL_SETTYPE
        CP      76h
        JP      NZ,ERR_14
        CALL    SET_TYPEPOS
        CALL    SYN_GETTOK
        DEC     DE
        CALL    IS_LETTER
        JR      NC,SYN_VAR
        INC     DE
        RET
DECL_TYPEPOS:
        DEFB    00h,00h

;  SYN_PARAMS – Formale Parameterliste "( Name : Typ ; ... )".
; <- aufgerufen von 402Fh, 40A5h
SYN_PARAMS:
        CALL    SYN_GETTOK
        LD      HL,DECL_FILEFLAG
        LD      B,00h
        LD      (HL),B
        CP      8Ah
        RET     NZ
L3E18:  CALL    SYN_IDLIST
        PUSH    BC
        CALL    SYN_SIMPLETYPE
        JP      C,ERR_04
        CALL    DECL_SETTYPE
        CALL    SET_TYPEPOS
        POP     BC
        CP      76h
        JR      Z,L3E18
        CP      8Dh
        JP      NZ,ERR_08
        CALL    SYN_GETTOK
        RET

;  SET_TYPEPOS – DE an der Stelle DECL_TYPEPOS eintragen.
; <- aufgerufen von 3DFCh, 3E25h
SET_TYPEPOS:
        LD      HL,(DECL_TYPEPOS)
        LD      (HL),E
        INC     HL
        LD      (HL),D
        RET

;  SKIP_IDENT_REF – Bezeichner überspringen; DE = Verweis aus dem folgenden
;  E2h-Token.
; <- aufgerufen von 40A0h
SKIP_IDENT_REF:
        CALL    SYN_GETTOK
        CALL    IS_LETTER
        JP      C,ERR_05
L3E46:  LD      A,(DE)
        INC     DE
        CALL    IS_LETTER
        CALL    C,IS_DIGIT
        JR      NC,L3E46
        EX      DE,HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        INC     HL
        EX      DE,HL
        RET

;  SYN_IDLIST – Liste "Name, Name, ... :" deklarieren (B = Anzahl).
; <- aufgerufen von 3DD9h, 3E18h
SYN_IDLIST:
        LD      HL,0FF00h
        LD      (SYM_LIST1),HL
        LD      (SYM_LIST2),HL
L3E61:  PUSH    BC
        CALL    DECLARE
        PUSH    HL
        LD      HL,(SYM_LIST2)
        EX      (SP),HL
        LD      (SYM_LIST2),HL
        POP     BC
        LD      (HL),C
        INC     HL
        LD      (HL),B
        CALL    SYN_GETTOK
        POP     BC
        INC     B
        CP      78h
        JR      Z,L3E61
        CP      0DDh
        JP      NZ,ERR_03
        LD      (DECL_TYPEPOS),DE
        INC     DE
        INC     DE
        CALL    SYN_GETTOK
        RET

;  TYPE_CODE – Typtoken (63h-66h) in Typcode 0-3 wandeln; C = kein einfacher
;  Typ.
; <- aufgerufen von 3C7Ch, 3E92h, 404Ah
TYPE_CODE:
        CP      67h
        JR      C,L3E8F
        SCF
        RET
L3E8F:  SUB     63h
        RET

;  SYN_SIMPLETYPE – Einfachen Typ lesen; Größe über TYPE_SIZE.
; <- aufgerufen von 3E1Ch, 3F29h
SYN_SIMPLETYPE:
        CALL    TYPE_CODE
        RET     C
        PUSH    AF
        CALL    TYPE_SIZE_X
        POP     AF
        LD      (TXT_PTR),DE
        PUSH    DE
        EXX
        LD      HL,DECL_FILEFLAG
        OR      (HL)
        POP     DE
        DEC     DE
        EXX
        RET
DECL_FILEFLAG:
        DEFB    00h

;  DECL_SETTYPE – Typ in alle eben deklarierten Namen eintragen.
; <- aufgerufen von 3DF4h, 3E22h
DECL_SETTYPE:
        LD      HL,(SYM_LIST2)
        PUSH    HL
        EXX
        POP     HL
        CALL    DECL_PUTENTRY
        LD      (HL),C
        INC     HL
        LD      (HL),B
        EXX
        LD      (SYM_LIST2),HL
        INC     H
        JR      NZ,DECL_SETTYPE
L3EBD:  LD      HL,(SYM_LIST1)
        PUSH    HL
        EXX
        POP     HL
        CALL    DECL_PUTENTRY
        EXX
        LD      (SYM_LIST1),HL
        INC     H
        JR      NZ,L3EBD
        LD      DE,(TXT_PTR)
        JP      SYN_GETTOK

;  DECL_PUTENTRY – Typ A und Verweis in einen Symboleintrag schreiben.
; <- aufgerufen von 3EB0h, 3EC3h
DECL_PUTENTRY:
        EXX
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        EXX
        LD      (HL),A
        INC     HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        INC     HL
        RET

;  SYN_FORMALS – Formale Parameter einer PROCEDURE/FUNCTION im Vorlauf prüfen.
; <- aufgerufen von 3C30h, 3C6Ch
SYN_FORMALS:
        CALL    SCAN_TOKEN
        DEC     DE
        CP      8Ah
        RET     NZ
        INC     DE
L3EE9:  CALL    SCAN_TOKEN
        CP      0E2h
        JR      Z,L3EF5
        CP      0E3h
        JP      NZ,ERR_05
L3EF5:  CALL    SCAN_NEXT
        CP      78h
        JR      Z,L3EE9
        CP      0DDh
        JP      NZ,ERR_03
        CALL    SCAN_NEXT
        CP      67h
        JP      NC,ERR_04
        CP      63h
        JP      C,ERR_04
        CALL    SCAN_NEXT
        CP      76h
        JR      Z,L3EE9
        CP      8Dh
        RET     Z
        JP      ERR_08

;  SCAN_NEXT – Token mit Operanden überspringen, nächstes Token suchen.
; <- aufgerufen von 3EF5h, 3F01h, 3F0Eh
SCAN_NEXT:
        EX      DE,HL
        CALL    TOK_SKIP
        EX      DE,HL
        JP      SCAN_TOKEN

;  TYPE_SIZE_X – TYPE_SIZE im Zweitregistersatz.
; <- aufgerufen von 3E97h, 3F9Bh, 4024h
TYPE_SIZE_X:
        EXX
        CALL    TYPE_SIZE
        EXX
        RET

;  SYN_ARRAYTYPE – ARRAY [n, m ...] OF Typ: Grenzen (ganzzahlige Konstanten)
;  lesen, Elementzahl ausrechnen; zu groß -> ERR_13.
; <- aufgerufen von 3DF1h
SYN_ARRAYTYPE:
        CALL    SYN_SIMPLETYPE
        RET     NC
        CP      0E1h
        JP      NZ,ERR_04
        PUSH    DE
        LD      A,06h
        ADD     A,E
        LD      E,A
        JR      NC,L3F3A
        INC     D
L3F3A:  CALL    SYN_GETTOK
        CP      8Bh
        JP      NZ,ERR_11
        LD      HL,ARR_COUNT
        CALL    CLR16
        INC     (HL)
        LD      B,00h
L3F4B:  CALL    SYN_GETTOK
        CP      0E6h
L3F50:  JP      NZ,ERR_12
        LD      A,(DE)
        INC     DE
        CP      01h
        JR      NZ,L3F50
        INC     DE
        INC     DE
        INC     DE
        INC     B
        PUSH    BC
        EX      DE,HL
        LD      DE,ARR_BOUND
        LDI
        LDI
        PUSH    HL
        DEC     DE
        DEC     DE
        EX      DE,HL
        CALL    INC16_CHK
        LD      DE,ARR_COUNT
        CALL    IMUL
        POP     DE
        CALL    SYN_GETTOK
        POP     BC
        CP      78h
        JR      Z,L3F4B
        CP      8Ch
        JP      NZ,ERR_10
        CALL    SYN_GETTOK
        CP      71h
        JP      NZ,ERR_07
        CALL    SYN_GETTOK
        CP      67h
        JP      NC,ERR_04
        SUB     63h
        JP      C,ERR_04
        LD      (TXT_PTR),DE
        PUSH    AF
        CALL    TYPE_SIZE_X
        EXX
        LD      A,C
        EXX
        LD      C,A
        POP     AF
        DEC     C
        OR      40h
        POP     HL
        PUSH    HL
        LD      (HL),B
        PUSH    AF
        INC     HL
        LD      (HL),C
        INC     HL
        PUSH    HL
        LD      DE,(ARR_COUNT)
        LD      (HL),E
        INC     HL
        LD      (HL),D
        INC     HL
        LD      (HL),C
        INC     HL
        LD      (HL),00h
        DEC     HL
        POP     DE
        EX      DE,HL
        CALL    IMUL
        INC     DE
        LD      A,(DE)
        CP      30h
        JP      NC,ERR_13
        LD      BC,0005h
        POP     AF
        LD      HL,DECL_FILEFLAG
        OR      (HL)
        POP     DE
        EXX
        RET

;  INC16_CHK – 16-Bit-Zähler (HL) erhöhen, Überlauf -> ERR_13.
; <- aufgerufen von 3F6Ah
INC16_CHK:
        INC     (HL)
        RET     NZ
        INC     HL
        INC     (HL)
        JP      Z,ERR_13
        JP      PE,ERR_13
        DEC     HL
        RET

;  CLR16 – (HL) = 0000h.
; <- aufgerufen von 3F45h
CLR16:  LD      (HL),00h
        INC     HL
        LD      (HL),00h
        DEC     HL
        RET

;  SYM_LOCAL – Symbolzugriffe (DECLARE, SYN_DECLS) auf die lokale Tabelle
;  umstellen.
; <- aufgerufen von 3C4Ah, 4079h
SYM_LOCAL:
        LD      HL,RT_SP
        LD      (SM_SYMTAB+1),HL
        LD      (SM_SYMTAB_IY+2),HL
        LD      HL,SYM_GROW3
        LD      (SM_SYMGROW+1),HL
        RET

;  SYN_SUBPROG – Nach PROCEDURE/FUNCTION-Kopf: Unterprogramm deklarieren.
; <- aufgerufen von 3C4Dh, 407Ch
SYN_SUBPROG:
        CALL    SYN_GETTOK
        CP      0D8h
        JP      Z,DECL_PROCHEAD
        CP      0D9h
        RET     NZ
        PUSH    IX
        PUSH    DE
        INC     DE
        INC     DE
        INC     DE
        INC     DE
        PUSH    DE
        CALL    SKIP_PARAMS
        EX      (SP),HL
        EX      DE,HL
        CALL    DECLARE
        EX      (SP),HL
        LD      IX,(SYM_LIST1)
        LD      (IX+0),L
        LD      (IX+1),H
        LD      A,(HL)
        EX      (SP),HL
        LD      (HL),A
        INC     HL
        PUSH    HL
        POP     IX
        INC     HL
        INC     HL
        CALL    TYPE_SIZE_X
        PUSH    HL
        EXX
        POP     HL
        LD      (HL),C
        INC     HL
        LD      (HL),B
        EXX
        PUSH    DE
        CALL    SYN_PARAMS
        CP      0DDh
        JP      NZ,ERR_03
        PUSH    DE
        INC     DE
        INC     DE
        CALL    SYN_GETTOK
        POP     HL
        PUSH    DE
        PUSH    AF
        PUSH    HL
        CALL    SYN_GETTOK_KL
        POP     HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        POP     AF
        POP     DE
        CALL    TYPE_CODE
        JP      C,ERR_04
        DEC     DE
        LD      (IX+0),E
        LD      (IX+1),D
        INC     DE
        EX      AF,AF'
        LD      A,B
        EX      AF,AF'
        EXX
        POP     BC
        POP     DE
        POP     HL
        POP     IX
        LD      (HL),A
        EX      AF,AF'
        INC     HL
L4064:  LD      (HL),A
        INC     HL
        LD      (HL),C
        INC     HL
        LD      (HL),B
        EX      DE,HL
        EX      AF,AF'
        LD      (HL),A
        INC     HL
        EX      AF,AF'
        LD      (HL),A
        EXX
        CALL    SYN_GETTOK
        CP      76h
        RET     Z
        JP      ERR_14

;  SYN_SUBBODY – Rumpf eines Unterprogramms prüfen: lokale Deklarationen,
;  BEGIN ... END, ";".
; <- aufgerufen von 3C8Bh
SYN_SUBBODY:
        CALL    SYM_LOCAL
        CALL    SYN_SUBPROG
        CALL    SYN_DECLS
        DEC     DE
        CALL    SYN_BLOCK
        CALL    SYM_ENDMARK
        CALL    SYN_GETTOK
        CP      76h
        RET     Z
        JP      ERR_14

;  SYM_ENDMARK – Ende der lokalen Symboltabelle markieren (00h), RT_AREA3
;  dahinter.
; <- aufgerufen von 3C50h, 4086h
SYM_ENDMARK:
        LD      HL,(RT_SP)
        LD      (HL),00h
        INC     HL
        LD      (RT_AREA3),HL
        RET

;  DECL_PROCHEAD – Kopf einer PROCEDURE: Parameterliste eintragen.
DECL_PROCHEAD:
        PUSH    DE
        INC     DE
        INC     DE
        INC     DE
        CALL    SKIP_IDENT_REF
        PUSH    HL
        PUSH    DE
        CALL    SYN_PARAMS
        DEC     DE
        LD      A,00h
        EX      AF,AF'
        LD      A,B
        EXX
        POP     BC
        POP     DE
        POP     HL
        JP      L4064

;  SYN_BLOCK – Es muss BEGIN folgen (sonst ERR_30), Block prüfen.
; <- aufgerufen von 3C97h, 4083h
SYN_BLOCK:
        CALL    SYN_GETTOK
        CP      69h
        JP      Z,SYN_BEGIN
        JP      ERR_30

;  SYN_STMTLIST – Anweisungen prüfen, solange ";" folgt; A = Token danach.
; <- aufgerufen von 4290h, 4306h
SYN_STMTLIST:
        CALL    SYN_STATEMENT
        CALL    SYN_GETTOK
        CP      76h
        RET     NZ
        JR      SYN_STMTLIST

;  SYN_STATEMENT – Eine Anweisung prüfen: Zuweisung/Prozeduraufruf
;  (Bezeichner), Token 69h-6Eh über SYN_TAB69, 8Fh-B2h über SYN_TAB8F.
; <- aufgerufen von 40BFh, 42AFh
SYN_STATEMENT:
        CALL    SYN_GETTOK
        CALL    IS_LETTER
        JP      NC,SYN_ASSIGN
        DEC     DE
        CP      8Fh
        JR      C,L40DC
        CP      0B3h
        JR      C,L40FC
L40DC:  SUB     69h
        RET     C
        CP      06h
        RET     NC
        LD      HL,SYN_TAB69

;  TAB_JUMP – Sprung über Tabelle HL mit Index A (Prüflauf); DE wird erhöht.
TAB_JUMP:
        INC     DE
        ADD     A,A
        ADD     A,L
        LD      L,A
        JR      NC,L40EC
        INC     H
L40EC:  CALL    LD_HL_IND
        JP      (HL)

;  Sprungtabellen der Prüfung, Index = Token - Basis (TAB_JUMP).
SYN_TAB69:
        DEFW    SYN_BEGIN               ; 69h  BEGIN
        DEFW    SYN_IF                  ; 6Ah  IF
        DEFW    SYN_WHILE               ; 6Bh  WHILE
        DEFW    SYN_REPEAT              ; 6Ch  REPEAT
        DEFW    SYN_CASE                ; 6Dh  CASE
        DEFW    SYN_FOR                 ; 6Eh  FOR
L40FC:  SUB     8Fh
        LD      HL,SYN_TAB8F
        JP      TAB_JUMP
SYN_TAB8F:
        DEFW    SYN_READ                ; 8Fh  READ(
        DEFW    SYN_READLN              ; 90h  READLN(
        DEFW    SYN_WRITE               ; 91h  WRITE(
        DEFW    SYN_WRITEX              ; 92h  PWRITE(
        DEFW    SYN_WRITEX              ; 93h  WRITELN(
        DEFW    SYN_WRITEX              ; 94h  PWRITELN(
        DEFW    SYN_CALL                ; 95h  CALL(
        DEFW    SYN_2ARGS               ; 96h  POKE(
        DEFW    SYN_ARG_CHAR            ; 97h  COUT(
        DEFW    SYN_2ARGS               ; 98h  OUTPUT(
        DEFW    SYN_STRARG              ; 99h  TRAN(
        DEFW    SYN_NOARGS              ; 9Ah  SYRET
        DEFW    SYN_NOARGS              ; 9Bh  SYRET2
        DEFW    SYN_TEMPO               ; 9Ch  TEMPO(
        DEFW    SYN_STRARG              ; 9Dh  MUSIC(
        DEFW    SYN_RANGE               ; 9Eh  RANGE(
        DEFW    SYN_FKEY_PAT            ; 9Fh  FKEY(
        DEFW    SYN_GRAPH               ; 0A0h  GRAPH(
        DEFW    SYN_XYARGS              ; 0A1h  GSET(
        DEFW    SYN_XYARGS              ; 0A2h  GRSET(
        DEFW    SYN_LINES               ; 0A3h  LINE(
        DEFW    SYN_LINES               ; 0A4h  BLINE(
        DEFW    SYN_XYARGS              ; 0A5h  POSITION(
        DEFW    SYN_FKEY_PAT            ; 0A6h  PATTERN(
        DEFW    SYN_XYARGS              ; 0A7h  CURSOR(
        DEFW    SYN_FNAME               ; 0A8h  FNAME(
        DEFW    SYN_STRARG              ; 0A9h  IMAGE(
        DEFW    SYN_COPY                ; 0AAh  COPY(
        DEFW    SYN_NOARGS              ; 0ABh  CLOSE

;  SYN_EXPR_T – Ausdruck vom Typ A prüfen (TYPE_MATCH), nächstes Token holen.
; <- aufgerufen von 368Dh, 416Bh, 4175h
SYN_EXPR_T:
        PUSH    AF
        CALL    SYN_EXPR
        POP     BC
        CALL    TYPE_MATCH
        JP      SYN_GETTOK
SYN_CHR:
        LD      A,01h
        CALL    SYN_ARG_RPAR
        LD      A,02h

;  SYN_NOARGS – SYRET, SYRET2, CLOSE prüfen (ohne Argumente).
SYN_NOARGS:
        RET

;  SYN_FN_REAL – TAN(, LOG(, RND(, ARCTAN(, COS(, EXP(, LN(, SIN(, SQRT(
;  prüfen: ein numerisches Argument, Ergebnis REAL.
SYN_FN_REAL:
        LD      A,00h
        CALL    SYN_ARG_RPAR
        LD      A,00h
        RET
SYN_TRUNC:
        LD      A,00h
        CALL    SYN_ARG_RPAR
        LD      A,01h
        RET
SYN_FLOAT:
        LD      A,01h
        CALL    SYN_ARG_RPAR
        LD      A,00h
        RET

;  SYN_2ARGS – POKE(, OUTPUT( prüfen: zwei ganzzahlige Argumente.
SYN_2ARGS:
        LD      A,02h
        CALL    SYN_EXPR_T
        CP      78h
        JP      NZ,ERR_15
; <- aufgerufen von 4188h, 418Eh, 41C4h
SYN_TEMPO:
        LD      A,01h

;  SYN_ARG_RPAR – Argument vom Typ A und ")" prüfen.
; <- aufgerufen von 414Bh, 4153h, 415Bh, 4163h
SYN_ARG_RPAR:
        CALL    SYN_EXPR_T
        CP      8Dh
        JP      NZ,ERR_08
        RET

;  SYN_ARG_CHAR – CHAR-Argument und ")" prüfen (u. a. COUT().
; <- aufgerufen von 4182h, 41BEh
SYN_ARG_CHAR:
        LD      A,02h
        JR      SYN_ARG_RPAR

;  SYN_PREDSUCC – PRED(, SUCC( prüfen.
SYN_PREDSUCC:
        CALL    SYN_ARG_CHAR
        LD      A,02h
        RET

;  SYN_FN_INTARG – PEEK(, INPUT( prüfen (ein ganzzahliges Argument).
SYN_FN_INTARG:
        CALL    SYN_TEMPO

;  SYN_FN_NOARG – KEY, REQTR, CIN prüfen (Funktionen ohne Argument).
SYN_FN_NOARG:
        LD      A,02h
        RET
SYN_CALL:
        CALL    SYN_TEMPO
        CALL    SYN_VARREF
        LD      B,01h
        CALL    TYPE_MATCH
        PUSH    AF
        CALL    SYN_GETTOK
        CP      78h
        JP      NZ,ERR_15
        CALL    SYN_VARREF
        POP     BC
        JP      TYPE_MATCH
SYN_ABS:
        CALL    SYN_EXPR
        AND     0Fh
        CP      02h
        JP      NC,ERR_04
        LD      B,A
        CALL    SYN_GETTOK
        CP      8Dh
        LD      A,B
        RET     Z
        JP      ERR_08
SYN_ORD:
        CALL    SYN_ARG_CHAR
        LD      A,01h
        RET
SYN_ODD:
        CALL    SYN_TEMPO
        LD      A,03h
        RET
SYN_READ:
        CALL    SYN_FILEARG
        JR      Z,SYN_READLN
L41CF:  LD      HL,SYN_ARRAYALL
        LD      (SM_ARRAY_HOOK+1),HL
L41D5:  CALL    RESOLVE_VAR
        AND     20h
        JP      Z,ERR_16
        CALL    SYN_GETTOK
        CP      78h
        JR      Z,L41D5
        JR      L41F7
SYN_READLN:
        CALL    SYN_VARREF
        AND     0Fh
        CP      03h
        JP      Z,ERR_04
        CALL    SYN_GETTOK
        CP      78h
        JR      Z,SYN_READLN
L41F7:  CP      8Dh
        RET     Z
        JP      ERR_08
L41FD:  OR      A
        POP     DE
        RET

;  SYN_FILEARG – Ist das erste Argument eine FILE-Variable (Bit 5)? NZ = ja.
; <- aufgerufen von 41CAh, 422Bh
SYN_FILEARG:
        PUSH    DE
        CALL    RESOLVE_IDENT
        JR      C,L4226
        BIT     5,A
        JR      Z,L4226
        BIT     6,A
        JR      Z,L421B
        LD      A,(DE)
        INC     DE
        CP      8Bh
        JP      NZ,ERR_11
        LD      A,(DE)
        INC     DE
        CP      8Ch
        JR      NZ,L4226
L421B:  CALL    SYN_GETTOK
        CP      78h
        JR      Z,L41FD
        CP      8Dh
        JR      Z,L41FD
L4226:  POP     DE
        LD      A,01h
        CP      A
        RET
SYN_WRITE:
        CALL    SYN_FILEARG
        JR      NZ,L41CF

;  SYN_WRITEX – PWRITE(, WRITELN(, PWRITELN( prüfen (auch Rest von WRITE().
;  Texte, INTEGER, REAL und CHAR mit ":Breite" bzw. ":Breite:Stellen"; BOOLEAN
;  ist nicht erlaubt (ERR_04).
SYN_WRITEX:
        CALL    SYN_GETTOK
        CP      0E0h
        JR      Z,L425B
        CP      8Dh
        RET     Z
        DEC     DE
        CALL    SYN_EXPR
        AND     0Fh
        CP      03h
        JP      Z,ERR_04
        CP      00h
        JR      Z,L4260
        CALL    SYN_GETTOK
L424C:  CP      0DDh
        CALL    Z,SYN_FMTARG
L4251:  CP      78h
        JR      Z,SYN_WRITEX
        CP      8Dh
        RET     Z
        JP      ERR_08
L425B:  CALL    SYN_SKIPCMT
        JR      L4251
L4260:  CALL    SYN_GETTOK
        CP      0DDh
        JR      NZ,L4251
        CALL    SYN_FMTARG
        JR      L424C

;  SYN_FMTARG – Formatangabe ":n" in WRITE prüfen (INTEGER).
; <- aufgerufen von 424Eh, 4267h
SYN_FMTARG:
        INC     DE
        INC     DE
        LD      A,01h
        JP      SYN_EXPR_T

;  SYN_ASSIGN – Zuweisung "Variable := Ausdruck" prüfen (ERR_22, ERR_17) bzw.
;  Prozeduraufruf.
SYN_ASSIGN:
        DEC     DE
        CALL    SYN_VAR_IDX
        JP      C,SYN_PROCCALL
        AND     0Fh
        PUSH    AF
        CALL    SYN_GETTOK
        CP      79h
        JP      NZ,ERR_22
        CALL    SYN_EXPR
        AND     0Fh
        POP     BC
        CP      B
        RET     Z
        JP      ERR_17
SYN_BEGIN:
        CALL    SYN_STMTLIST
        CP      72h
        RET     Z
        JP      ERR_18
SYN_IF: CALL    SYN_BOOLEXPR
        CP      0DAh
        JP      NZ,ERR_19
        CALL    SYN_LINKSTMT
        CALL    SYN_GETTOK
        DEC     DE
        CP      0DBh
        RET     NZ
        INC     DE

;  SYN_LINKSTMT – Anweisung nach THEN/ELSE/DO prüfen und ihr Ende in die
;  beiden Platzhalterbytes hinter dem Schlüsselwort eintragen (Sprungziel zur
;  Laufzeit).
; <- aufgerufen von 42A1h, 450Ah
SYN_LINKSTMT:
        PUSH    DE
        INC     DE
        INC     DE
        CALL    SYN_STATEMENT
        POP     HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        RET

;  SYN_BOOLEXPR – BOOLEAN-Ausdruck prüfen (sonst ERR_20).
; <- aufgerufen von 4299h, 42C4h, 430Eh
SYN_BOOLEXPR:
        CALL    SYN_EXPR
        AND     0Fh
        CP      03h
        JP      NZ,ERR_20
        JP      SYN_GETTOK
SYN_WHILE:
        CALL    SYN_BOOLEXPR
L42C7:  CP      0DCh
        JP      NZ,ERR_21
        JP      SYN_LINKSTMT
SYN_FOR:
        CALL    SYN_VARREF
        PUSH    AF
        AND     0Fh
        CP      01h
        JR      Z,L42DE
        CP      02h
        JP      NZ,ERR_04
L42DE:  CALL    SYN_GETTOK
        CP      79h
        JP      NZ,ERR_22
        CALL    SYN_EXPR
        POP     BC
        CALL    TYPE_MATCH
        PUSH    AF
        CALL    SYN_GETTOK
        CP      6Fh
        JR      Z,L42FA
        CP      70h
        JP      NZ,ERR_23
L42FA:  CALL    SYN_EXPR
        POP     BC
        CALL    TYPE_MATCH
        CALL    SYN_GETTOK
        JR      L42C7
SYN_REPEAT:
        CALL    SYN_STMTLIST
        CP      73h
        JP      NZ,ERR_24
        CALL    SYN_BOOLEXPR
        DEC     DE
        RET

;  SYN_EXPR – Ausdruck prüfen (mit Vergleich 7Bh-80h bzw. IN); A =
;  Ergebnistyp.
; <- aufgerufen von 2DDCh, 413Fh, 41A9h, 423Bh, 4285h, 42B7h, 42E6h, 42FAh ... (12)
SYN_EXPR:
        CALL    SYN_SIMPLE
        PUSH    AF
        CALL    SYN_GETTOK
        CP      7Ah
        JR      C,L4324
        JR      Z,L4331
        CP      81h
        JR      C,L4327
L4324:  POP     AF
        DEC     DE
        RET
L4327:  CALL    SYN_SIMPLE
        POP     BC
        CALL    TYPE_MATCH
L432E:  LD      A,03h
        RET
L4331:  POP     AF
        JP      ERR_04
        CP      00h
        JP      NZ,ERR_04
        CALL    SYN_SIMPLE
        CP      00h
        JP      NZ,ERR_04
        JR      L432E

;  SYN_SIMPLE – Einfachen Ausdruck prüfen: Vorzeichen, Terme mit + - OR XOR.
; <- aufgerufen von 4313h, 4327h, 433Ah
SYN_SIMPLE:
        CALL    SYN_GETTOK
        CP      82h
        JR      Z,L4382
        CP      81h
        JR      Z,L4382
        DEC     DE
        CALL    SYN_TERM
L4353:  PUSH    AF
L4354:  CALL    SYN_GETTOK
        CP      82h
        JR      Z,L436A
        CP      81h
        JR      Z,L436A
        CP      83h
        JR      Z,L437A
        CP      84h
        JR      Z,L437A
        POP     AF
        DEC     DE
        RET
L436A:  POP     AF
        PUSH    AF
        CALL    CHK_NUMTYPE
        POP     AF
L4370:  PUSH    AF
        CALL    SYN_TERM
        POP     BC
        CALL    TYPE_MATCH
        JR      L4353
L437A:  POP     AF
        LD      B,03h
        CALL    TYPE_MATCH
        JR      L4370
L4382:  CALL    SYN_TERM
        PUSH    AF
        CALL    CHK_NUMTYPE
        JR      L4354

;  CHK_NUMTYPE – Typ muss REAL oder INTEGER sein, sonst ERR_04.
; <- aufgerufen von 436Ch, 4386h
CHK_NUMTYPE:
        AND     0Fh
        CP      02h
        RET     C
        JP      ERR_04

;  SYN_TERM – Term prüfen: Faktoren mit * AND DIV MOD / (SYN_TAB85).
; <- aufgerufen von 4350h, 4371h, 4382h
SYN_TERM:
        CALL    SYN_FACTOR
L4396:  PUSH    AF
        CALL    SYN_GETTOK
        SUB     85h
        JR      C,L43BB
        CP      05h
        JR      NC,L43BB
        ADD     A,A
        LD      HL,SYN_TAB85
        ADD     A,L
        LD      L,A
        JR      NC,L43AB
        INC     H
L43AB:  CALL    LD_HL_IND
        POP     AF
        PUSH    AF
        JP      (HL)
SYN_TAB85:
        DEFW    SYN_MUL                 ; 85h  *
        DEFW    SYN_AND                 ; 86h  AND
        DEFW    SYN_DIV                 ; 87h  DIV
        DEFW    SYN_DIV                 ; 88h  MOD
        DEFW    SYN_RDIV                ; 89h  /
L43BB:  POP     AF
        DEC     DE
        RET
SYN_MUL:
        AND     0Fh
        CP      01h
        JR      Z,L43C9
        CP      00h
        JP      NZ,ERR_04
L43C9:  CALL    SYN_FACTOR
        POP     BC
        CALL    TYPE_MATCH
        JR      L4396
SYN_AND:
        LD      B,03h
L43D4:  CALL    TYPE_MATCH
        JR      L43C9
SYN_DIV:
        LD      B,01h
        JR      L43D4

;  SYN_RDIV – "/": beide Operanden müssen REAL sein (1/3 mit INTEGER-Werten ->
;  ERR_17).
SYN_RDIV:
        LD      B,00h
        JR      L43D4
        DEFS    15,00h

;  SYN_FACTOR – Faktor prüfen: Bezeichner (Variable, Funktion, Konstante),
;  Funktion ab B3h (SYN_TABB3), "(" Ausdruck ")", NOT, Zahl, Zeichen,
;  TRUE/FALSE.
; <- aufgerufen von 4393h, 43C9h, 444Dh
SYN_FACTOR:
        CALL    SYN_GETTOK
        DEC     DE
        CALL    IS_LETTER
        JR      C,L4426
        PUSH    DE
        CALL    GET_IDENT
        PUSH    DE
        LD      HL,(RT_AREA1)
        CALL    SYM_FIND
        JR      NC,L440F
        POP     DE
        POP     DE

;  SYN_VARREF – Variable (mit Index) prüfen; nicht deklariert -> ERR_27.
; <- aufgerufen von 4191h, 41A2h, 41E6h, 42CFh
SYN_VARREF:
        CALL    SYN_VAR_IDX
        RET     NC
        JP      ERR_27
L440F:  PUSH    HL
        LD      HL,L454B
        LD      (HL),23h
        POP     HL
        LD      A,(HL)
        CP      0E5h
        POP     DE
        EX      (SP),HL
        POP     HL
        INC     HL
        LD      A,(HL)
        PUSH    AF
        DEC     HL
        JP      Z,SYN_ACTUALS
        JP      ERR_25
L4426:  CP      0D6h
        JR      NC,L4455
        CP      0B3h
        JR      C,L4436
        SUB     0B3h
        LD      HL,SYN_TABB3
        JP      TAB_JUMP
L4436:  INC     DE
        CP      8Ah
        JR      NZ,L4449
        CALL    SYN_EXPR
        PUSH    AF
        CALL    SYN_GETTOK
        CP      8Dh
        JP      NZ,ERR_08
        POP     AF
        RET
L4449:  CP      8Eh
        JR      NZ,L4456
        CALL    SYN_FACTOR
        LD      B,03h
        JP      TYPE_MATCH
L4455:  INC     DE
L4456:  CP      0E6h
        JR      NZ,L4462
        LD      A,(DE)
        INC     DE
        INC     DE
        INC     DE
        INC     DE
        INC     DE
        INC     DE
        RET
L4462:  CP      0DFh
        JR      NZ,L4477
        EX      DE,HL
        CALL    TOK_SKIP
        EX      DE,HL
        INC     DE
        INC     DE
        LD      A,(DE)
        CP      27h
        JP      NZ,ERR_26
        LD      A,02h
        INC     DE
        RET
L4477:  CP      74h
        JR      Z,L4480
        CP      75h
        JP      NZ,ERR_25
L4480:  LD      A,03h
        RET
SYN_TABB3:
        DEFW    SYN_FN_NOARG            ; 0B3h  KEY
        DEFW    SYN_FN_NOARG            ; 0B4h  REQTR
        DEFW    SYN_FN_INTARG           ; 0B5h  PEEK(
        DEFW    SYN_FN_NOARG            ; 0B6h  CIN
        DEFW    SYN_FN_INTARG           ; 0B7h  INPUT(
        DEFW    SYN_FN_REAL             ; 0B8h  TAN(
        DEFW    SYN_FN_REAL             ; 0B9h  LOG(
        DEFW    SYN_FN_REAL             ; 0BAh  RND(
        DEFW    SYN_ABS                 ; 0BBh  ABS(
        DEFW    SYN_FN_REAL             ; 0BCh  ARCTAN(
        DEFW    SYN_CHR                 ; 0BDh  CHR(
        DEFW    SYN_FN_REAL             ; 0BEh  COS(
        DEFW    SYN_FN_REAL             ; 0BFh  EXP(
        DEFW    SYN_FN_REAL             ; 0C0h  LN(
        DEFW    SYN_ODD                 ; 0C1h  ODD(
        DEFW    SYN_ORD                 ; 0C2h  ORD(
        DEFW    SYN_PREDSUCC            ; 0C3h  PRED(
        DEFW    SYN_FN_REAL             ; 0C4h  SIN(
        DEFW    SYN_FN_REAL             ; 0C5h  SQRT(
        DEFW    SYN_TRUNC               ; 0C6h  TRUNC(
        DEFW    SYN_PREDSUCC            ; 0C7h  SUCC(
        DEFW    SYN_FLOAT               ; 0C8h  FLOAT(
        DEFW    SYN_POINT               ; 0C9h  POINT(
        DEFW    SYN_FN_POS              ; 0CAh  POSH
        DEFW    SYN_FN_POS              ; 0CBh  POSV
        DEFW    SYN_FN_POS              ; 0CCh  CSRH
        DEFW    SYN_FN_POS              ; 0CDh  CSRV
; <- aufgerufen von 40ECh, 43ABh, 4547h, 454Ch
LD_HL_IND:
        LD      A,(HL)
        INC     HL
        LD      H,(HL)
        LD      L,A
        RET

;  SYN_CASECONST – CASE-Marke (Konstante, auch mit Vorzeichen) prüfen.
; <- aufgerufen von 44E9h
SYN_CASECONST:
        CALL    SYN_GETTOK
        CP      82h
        JR      NZ,L44CA
L44C5:  CALL    SYN_GETTOK
        JR      L4456
L44CA:  CP      81h
        JR      Z,L44C5
        JR      L4456
SYN_CASE:
        CALL    SYN_EXPR
        CP      00h
        JP      Z,ERR_04
        PUSH    AF
        CALL    SYN_GETTOK
        CP      71h
        JP      NZ,ERR_07
L44E1:  CALL    SYN_GETTOK
        CP      72h
        JR      Z,L4519
        DEC     DE
        CALL    SYN_CASECONST
        CP      01h
        JR      Z,L44F9
        CP      03h
        JR      Z,L44F9
        CP      02h
        JP      NZ,ERR_04
L44F9:  POP     BC
        CALL    TYPE_MATCH
        PUSH    AF
        CALL    SYN_GETTOK
        CP      78h
        JR      Z,L44E1
        CP      0DDh
        JP      NZ,ERR_03
        CALL    SYN_LINKSTMT
        CALL    SYN_GETTOK
        CP      76h
        JR      Z,L44E1
        CP      72h
        JP      NZ,ERR_18
L4519:  POP     AF
        RET

;  SKIP_ALNUM – Buchstaben und Ziffern ab HL überspringen.
SKIP_ALNUM:
        LD      A,(HL)
        CALL    IS_LETTER
        CALL    C,IS_DIGIT
        RET     C
        INC     HL
        JR      SKIP_ALNUM

;  SYN_PROCCALL – Prozeduraufruf prüfen: Name muss eine PROCEDURE sein (sonst
;  ERR_28).
SYN_PROCCALL:
        PUSH    AF
        LD      HL,L454B
        LD      (HL),00h
        CALL    SYM_FIND_SUB
        CP      0E4h
        JP      NZ,ERR_28

;  SYN_ACTUALS – Aktuelle Parameter prüfen: Anzahl (ERR_29) und Typen
;  (ERR_17).
SYN_ACTUALS:
        PUSH    DE
        LD      DE,(SYM_LIST1)
        DEC     DE
        LDI
        LDI
        LD      A,(HL)
        INC     HL
        PUSH    HL
        LDI
        LDI
        POP     HL
        PUSH    AF
        CALL    LD_HL_IND
        INC     HL
L454B:  INC     HL
        CALL    LD_HL_IND
        EX      DE,HL
        CALL    SYN_GETTOK_KL
        POP     HL
        EX      (SP),HL
        EX      DE,HL
        PUSH    HL
        CALL    SYN_GETTOK
        POP     HL
        LD      B,00h
        DEC     DE
        CP      8Ah
        JR      NZ,L45A1
        INC     DE
L4563:  POP     AF
        AND     A
        JP      Z,ERR_29
        CP      B
        JP      Z,ERR_29
        PUSH    AF
        PUSH    BC
        PUSH    HL
        CALL    SYN_EXPR
        AND     0BFh
        EX      DE,HL
        EX      (SP),HL
        EX      DE,HL
        PUSH    AF
        CALL    SCAN_TOKEN_KL
        LD      A,(DE)
        POP     BC
        CP      B
        JP      NZ,ERR_17
        INC     DE
        INC     DE
        INC     DE
        CALL    SYN_GETTOK_KL
        CP      0DDh
        JR      NZ,L458F
        EX      DE,HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
L458F:  POP     HL
        EX      DE,HL
        POP     BC
        INC     B
        PUSH    HL
        CALL    SYN_GETTOK
        POP     HL
        CP      78h
        JR      Z,L4563
        CP      8Dh
        JP      NZ,ERR_08
L45A1:  POP     AF
        CP      B
        JP      NZ,ERR_29
        POP     AF
        RET

;  TYPE_MATCH – Typcodes in B und C vergleichen (unteres Halbbyte);
;  verschieden -> ERR_17. A = B OR C.
; <- aufgerufen von 2DE1h, 4143h, 4196h, 42EAh, 42FEh, 432Bh, 4375h, 437Dh ... (12)
TYPE_MATCH:
        LD      C,A
        PUSH    BC
        AND     0Fh
        LD      C,A
        LD      A,B
        AND     0Fh
        CP      C
        JP      NZ,ERR_17
        POP     BC
        LD      A,C
        OR      B
        RET

;  SYM_FIND_SUB – Unterprogramm in RT_AREA1 suchen; fehlt -> ERR_27.
; <- aufgerufen von 452Ch
SYM_FIND_SUB:
        PUSH    DE
        LD      HL,(RT_AREA1)
        CALL    SYM_FIND
        JP      C,ERR_27
        LD      A,(HL)
        POP     DE
        RET

;  RESOLVE_IDENT – Bezeichner erst lokal, dann global suchen und das Token
;  davor (E3h lokal, E2h global) samt Adresse in den Programmtext schreiben. C
;  = unbekannt.
; <- aufgerufen von 4201h, 4600h
RESOLVE_IDENT:
        LD      A,(DE)
        CALL    IS_LETTER
        RET     C
        CALL    GET_IDENT
        PUSH    DE
        LD      HL,(RT_SP)
        CALL    SYM_FIND
        LD      A,0E3h
        JR      NC,L45E3
        LD      HL,(RT_AREA0)
        CALL    SYM_FIND
        LD      A,0E2h
        POP     DE
        RET     C
        PUSH    DE
L45E3:  LD      DE,(SYM_LIST1)
        DEC     DE
        LD      (DE),A
        INC     DE
        LD      A,(HL)
        LDI
        PUSH    HL
        INC     HL
        INC     HL
        LDI
        LDI
        POP     HL
        POP     DE
        OR      A
        RET

;  SYN_VAR_IDX – Variable auflösen; bei Feldern Indexliste prüfen (SYN_INDEX).
; <- aufgerufen von 4274h, 4408h
SYN_VAR_IDX:
        PUSH    HL
        LD      HL,SYN_INDEX
        LD      (SM_ARRAY_HOOK+1),HL
        POP     HL

;  RESOLVE_VAR – RESOLVE_IDENT; Feld -> Sprung über den Operanden bei L4608.
; <- aufgerufen von 41D5h
RESOLVE_VAR:
        CALL    RESOLVE_IDENT
        RET     C
        PUSH    DE
        PUSH    AF
        AND     40h

;  SM_ARRAY_HOOK – Operand: Prüfung für Feldvariablen (SYN_INDEX oder
;  SYN_ARRAYALL).
SM_ARRAY_HOOK:
        JP      NZ,SYN_INDEX            ; Operand wird zur Laufzeit gesetzt
        POP     AF
        POP     DE
        AND     A
        RET

;  SYN_ARRAYALL – Ganzes Feld "[]" (für READ/WRITE mit Dateien).
SYN_ARRAYALL:
        LD      A,(DE)
        INC     DE
        CP      8Bh
        JP      NZ,ERR_11
        LD      A,(DE)
        INC     DE
        CP      8Ch
        JP      NZ,ERR_10
        JR      L464A

;  SYN_INDEX – Indexliste "[i, j ...]" prüfen: INTEGER-Ausdrücke, Anzahl =
;  Dimension (ERR_29).
SYN_INDEX:
        LD      A,(HL)
        INC     HL
        LD      H,(HL)
        LD      L,A
        LD      A,(HL)
        PUSH    AF
        LD      A,(DE)
        INC     DE
        LD      B,00h
        CP      8Bh
        JP      NZ,ERR_11
L462E:  PUSH    BC
        CALL    SYN_EXPR
        LD      B,01h
        CALL    TYPE_MATCH
        POP     BC
        INC     B
        CALL    SYN_GETTOK
        CP      78h
        JR      Z,L462E
        CP      8Ch
        JP      NZ,ERR_10
        POP     AF
        CP      B
        JP      NZ,ERR_29
L464A:  POP     AF
        POP     HL
        OR      A
        RET

;  PUSH_LINENO – LINE_NO unter die Rücksprungadresse auf den Stapel legen.
; <- aufgerufen von 3BBAh, 3BD0h, 465Eh
PUSH_LINENO:
        LD      HL,(LINE_NO)
        EX      (SP),HL
        JP      (HL)

;  SKIP_PARAMS – SKIP_IDENT_REF aufrufen, LINE_NO dabei erhalten.
; <- aufgerufen von 4008h
SKIP_PARAMS:
        LD      HL,SKIP_IDENT_REF
        JR      CALL_KEEPLINE

;  SYN_GETTOK_KL – SYN_GETTOK aufrufen, LINE_NO dabei erhalten.
; <- aufgerufen von 4041h, 4550h, 4584h
SYN_GETTOK_KL:
        LD      HL,SYN_GETTOK

;  CALL_KEEPLINE – Routine HL aufrufen und LINE_NO danach wiederherstellen.
CALL_KEEPLINE:
        LD      (SM_KEEPLINE+1),HL
        CALL    PUSH_LINENO

;  SM_KEEPLINE – Operand: Routine, die CALL_KEEPLINE aufruft.
SM_KEEPLINE:
        CALL    0000h                   ; Operand wird zur Laufzeit gesetzt
        EX      (SP),HL
        LD      (LINE_NO),HL
        POP     HL
        RET

;  POP_LINENO – LINE_NO vom Stapel zurückholen.
; <- aufgerufen von 3C47h, 3C87h
POP_LINENO:
        POP     HL
        EX      (SP),HL
        LD      (LINE_NO),HL
        RET

;  SCAN_TOKEN_KL – SCAN_TOKEN aufrufen, LINE_NO dabei erhalten.
; <- aufgerufen von 4578h
SCAN_TOKEN_KL:
        LD      HL,SCAN_TOKEN
        JR      CALL_KEEPLINE
SYM_LIST1:
        DEFB    00h,00h
SYM_LIST2:
        DEFB    00h,00h
RT_AREA0:
        DEFB    00h,00h
RT_AREA1:
        DEFB    00h,00h
RT_SP:  DEFB    00h,00h
RT_AREA3:
        DEFB    00h,00h
ARR_COUNT:
        DEFB    00h,00h
ARR_BOUND:
        DEFB    00h,00h,00h,00h

; ------------------------------------------------------------------------------
;  ERR_01 ... ERR_55 – Fehlereinsprünge. Jeder lädt die Fehlernummer (BCD)
;  nach A; das folgende DEFB 01h (LD BC,nn) überspringt die übrigen.
;  ERROR – "*Err nn *" ausgeben, im Programmlauf mit " Run*" bzw. " Line"
;  und Zeilennummer, dann zurück nach PAS_READY.
; ------------------------------------------------------------------------------
ERR_01: LD      A,01h                   ; Err 01: Programm unvollständig oder "." fehlt
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_02: LD      A,02h                   ; Err 02: Bezeichner doppelt deklariert
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_03: LD      A,03h                   ; Err 03: ":" fehlt oder falsches Zeichen statt ":"
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_04: LD      A,04h                   ; Err 04: Typ nicht erlaubt
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_05: LD      A,05h                   ; Err 05: Bezeichner erwartet
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_06: LD      A,06h                   ; Err 06: Bezeichner zu lang
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_07: LD      A,07h                   ; Err 07: OF fehlt
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_08: LD      A,08h                   ; Err 08: ")" oder "," fehlt (vermutlich; Code prüft Token 8Dh ")")
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_09: LD      A,09h                   ; Err 09: Zeichen fehlt (im Handbuch-Scan unleserlich)
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_10: LD      A,10h                   ; Err 10: "]" fehlt (Code prüft Token 8Ch "]"; Handbuch-Scan: "_ or , is omitted")
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_11: LD      A,11h                   ; Err 11: "[" fehlt (Code prüft Token 8Bh "["; der Handbuch-Scan zeigt "]")
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_12: LD      A,12h                   ; Err 12: Ganzzahl erwartet
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_13: LD      A,13h                   ; Err 13: Feldindex zu groß oder Wert außerhalb des Bereichs
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_14: LD      A,14h                   ; Err 14: ";" fehlt (vermutlich; Code prüft Token 76h ";")
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_15: LD      A,15h                   ; Err 15: "," fehlt
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_16: LD      A,16h                   ; Err 16: READ/WRITE mischt FILE-Variablen und andere
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_17: LD      A,17h                   ; Err 17: Wert vom falschen Typ zugewiesen
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_18: LD      A,18h                   ; Err 18: ";" oder END fehlt
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_19: LD      A,19h                   ; Err 19: THEN fehlt
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_20: LD      A,20h                   ; Err 20: BOOLEAN erwartet
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_21: LD      A,21h                   ; Err 21: DO fehlt
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_22: LD      A,22h                   ; Err 22: ":=" fehlt
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_23: LD      A,23h                   ; Err 23: TO oder DOWNTO fehlt
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_24: LD      A,24h                   ; Err 24: UNTIL fehlt
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_25: LD      A,25h                   ; Err 25: Variable, Funktion oder Konstante erwartet
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_26: LD      A,26h                   ; Err 26: mehr als ein Zeichen zwischen Hochkommas
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_27: LD      A,27h                   ; Err 27: Bezeichner nicht deklariert
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_28: LD      A,28h                   ; Err 28: Prozedurbezeichner erwartet
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_29: LD      A,29h                   ; Err 29: Parameter oder Felddimension passen nicht
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_30: LD      A,30h                   ; Err 30: BEGIN fehlt
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_31: LD      A,31h                   ; Err 31: Ziffer erwartet
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_32: LD      A,32h                   ; Err 32: REAL erwartet
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_33: LD      A,33h                   ; Err 33: bei der Eingabe "," oder CR erwartet
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_34: LD      A,34h                   ; Err 34: Schreibfehler oder BREAK beim Schreiben (Kassette)
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_35: LD      A,35h                   ; Err 35: Lesefehler oder BREAK beim Lesen (Kassette)
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_36: LD      A,36h                   ; Err 36: Zahl hat mehr Stellen als im WRITE angegeben
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_37: LD      A,37h                   ; Err 37: "$" fehlt
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_38: LD      A,38h                   ; Err 38: Hexadezimalzahl erwartet
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_39: LD      A,39h                   ; Err 39: Speicher zu klein
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_40: LD      A,40h                   ; Err 40: Kommandofehler
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_41: LD      A,41h                   ; Err 41: Anführungszeichen oder Klammer fehlt
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_42: LD      A,42h                   ; Err 42: Drucker aus oder nicht angeschlossen
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_43: LD      A,43h                   ; Err 43: Drucker: Papierende
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_44: LD      A,44h                   ; Err 44: Drucker: mechanische Störung
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_45: LD      A,45h                   ; Err 45: unzulässiges Zeichen
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_46: LD      A,46h                   ; Err 46: CLOSE fehlt
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_47: LD      A,47h                   ; Err 47: Datei nicht geöffnet oder FNAME fehlt
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_48: LD      A,48h                   ; Err 48: kein Programm im Speicher (nicht im Handbuch; aus CHK_PROG erschlossen)
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_49: LD      A,49h                   ; Err 49: (im Handbuch nicht beschrieben)
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_50: LD      A,50h                   ; Err 50: (im Handbuch nicht beschrieben)
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_51: LD      A,51h                   ; Err 51: (im Handbuch nicht beschrieben)
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_52: LD      A,52h                   ; Err 52: (im Handbuch nicht beschrieben)
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_53: LD      A,53h                   ; Err 53: (im Handbuch nicht beschrieben)
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_54: LD      A,54h                   ; Err 54: (im Handbuch nicht beschrieben)
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
ERR_55: LD      A,55h                   ; Err 55: (im Handbuch nicht beschrieben)
ERROR:  LD      B,A
        LD      HL,MSG_ERR_NUM
        LD      (HL),20h
        AND     0F0h
        JR      Z,L473C
        RRA
        RRA
        RRA
        RRA
        OR      30h
        LD      (HL),A
L473C:  INC     HL
        LD      A,B
        AND     0Fh
        OR      30h
        LD      (HL),A
        LD      DE,MSG_ERR
        CALL    PR_MSG_NL
        LD      A,(RUN_MODE)
        OR      A
        JP      Z,PAS_READY
        CP      01h
        JR      Z,L4762
        LD      DE,MSG_RUN
        CALL    JP_MSGX
        JP      PAS_READY

;  PR_LINENO_HL – HL vierstellig ausgeben (PR_DEC4).
; <- aufgerufen von 476Bh
PR_LINENO_HL:
        PUSH    HL
        PUSH    HL
        JP      PR_DEC4
L4762:  LD      DE,MSG_LINE
        CALL    JP_MSGX
        LD      HL,(LINE_NO)
        CALL    PR_LINENO_HL
        JP      RUN_END
MSG_ERR:
        DEFB    "*Err "
MSG_ERR_NUM:
        DEFB    "  *",0Dh
MSG_RUN:
        DEFB    " Run*",0Dh
MSG_LINE:
        DEFB    " Line",0Dh
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h,00h,00h,00h,00h,00h,00h
        DEFB    00h,00h
FP_SIGN:
        DEFB    00h
FP_RSIGN:
        DEFB    00h
FP_EXP: DEFB    00h

;  FSUB – (DE) = (DE) - (HL), Gleitkomma (Vorzeichen von (HL) umgedreht, dann
;  wie FADD).
; <- aufgerufen von 5072h, 5104h, 5220h, 536Ch, 5511h, 55B2h, 5F0Ah
FSUB:   XOR     A
        JR      L4808

;  FADD – (DE) = (DE) + (HL), Gleitkomma. Exponentenausgleich, Addition bzw.
;  Subtraktion der Mantissen, Normalisieren; Überlauf -> ERR_13, Unterlauf ->
;  0.
; <- aufgerufen von 5F28h
FADD:   LD      A,80h
L4808:  PUSH    DE
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
L4815:  PUSH    BC
        LD      B,(HL)
        RES     7,B
        LD      A,(DE)
        AND     7Fh
        CP      B
        JR      NC,L4829
        POP     BC
        EX      DE,HL
        LD      A,B
        XOR     C
        CPL
        AND     80h
        LD      B,A
        JR      L4815
L4829:  LD      C,A
        ADD     A,40h
        LD      (FP_EXP),A
        LD      A,C
        SUB     B
        POP     BC
        LD      (FP_SIGN),BC
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
        JR      Z,L485D
L4843:  CP      08h
        JR      NC,L4854
L4847:  SRL     B
        RR      C
        RR      D
        RR      E
        DEC     A
        JR      NZ,L4847
        JR      L485D
L4854:  LD      E,D
        LD      D,C
        LD      C,B
        LD      B,00h
        SUB     08h
        JR      NZ,L4843
L485D:  LD      A,(FP_SIGN)
        OR      A
        JR      Z,L489D
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
        JR      NC,L4880
        RR      B
        RR      C
        RR      D
        RR      E
        LD      HL,FP_EXP
        INC     (HL)
L4880:  LD      HL,FP_EXP
        LD      A,(HL)
        SUB     40h
        JR      C,L488F
        JP      M,ERR_13
        DEC     HL
        OR      (HL)
        JR      L4892
L488F:  CALL    FP_SETZERO
L4892:  POP     HL

;  FSTORE – A (Exponent) und Mantisse EDCB nach (HL) schreiben.
; <- aufgerufen von 4FBAh, 5064h
FSTORE: LD      (HL),A
        INC     HL
        LD      (HL),E
        INC     HL
        LD      (HL),D
        INC     HL
        LD      (HL),C
        INC     HL
        LD      (HL),B
        RET
L489D:  LD      A,(HL)
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
        CALL    C,FNEG_MANT
        OR      C
        OR      D
        JR      NZ,L48B8
        LD      A,E
        CP      3Fh
        JR      C,L488F
L48B8:  LD      HL,FP_EXP
L48BB:  LD      A,B
        OR      A
        JP      M,L4880
        JR      NZ,L48D4
        LD      A,(HL)
        SUB     08h
        JR      C,L488F
        LD      (HL),A
        LD      A,C
        OR      D
        OR      E
L48CB:  JR      Z,L488F
        LD      B,C
        LD      C,D
        LD      D,E
        LD      E,00h
        JR      L48BB
L48D4:  DEC     (HL)
L48D5:  JR      C,L488F
        SLA     E
        RL      D
        RL      C
        RL      B
        JP      P,L48D4
        JR      L4880

;  FNEG_MANT – Mantisse BCDE negieren (Zweierkomplement), Vorzeichen umdrehen.
; <- aufgerufen von 48ACh
FNEG_MANT:
        LD      HL,FP_RSIGN
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

;  FMUL – (DE) = (DE) * (HL). Überlauf (Betrag ab etwa 0.92233720E+19,
;  Handbuch) -> ERR_13.
; <- aufgerufen von 2DAFh, 4FA5h, 5382h, 5392h, 557Eh, 604Ch
FMUL:   PUSH    DE
        LD      A,(DE)
        XOR     (HL)
        CPL
        AND     80h
        LD      (FP_RSIGN),A
        LD      B,(HL)
        RES     7,B
        LD      A,(DE)
        AND     7Fh
        ADD     A,B
        JR      Z,L48CB
        DEC     A
L4913:  CP      30h
        JR      C,L48D5
        CP      0E0h
        JP      NC,ERR_13
        LD      (FP_EXP),A
        XOR     A
        LD      (FP_SIGN),A
        LD      BC,0004h
        ADD     HL,BC
        LD      A,(HL)
        OR      A
        JP      P,L488F
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
        JP      P,L488F
        LD      C,04h
L4948:  LD      A,(IY+0)
        LD      B,08h
        OR      A
        JR      Z,L49C3
L4950:  RLA
        JR      NC,L4967
        EX      AF,AF'
        EXX
        LD      A,B
        ADD     A,C
        LD      C,A
        ADC     HL,DE
        EXX
        ADC     HL,DE
        JR      NC,L4966
        LD      A,(FP_SIGN)
        INC     A
        LD      (FP_SIGN),A
L4966:  EX      AF,AF'
L4967:  SRL     D
        RR      E
        EXX
        RR      D
        RR      E
        RR      B
        EXX
        DJNZ    L4950
L4975:  DEC     IY
        DEC     C
        JR      NZ,L4948
        LD      A,(FP_SIGN)
        OR      A
        JR      Z,L4997
        LD      B,A
        LD      A,(FP_EXP)
        ADD     A,B
        LD      (FP_EXP),A
L4988:  SCF
        RR      H
        RR      L
        EXX
        RR      H
        RR      L
        RR      C
        EXX
        DJNZ    L4988
L4997:  EXX
        LD      A,C
        OR      A
        JP      P,L49BB
        LD      DE,0001h
        ADD     HL,DE
        EXX
        LD      DE,0000h
        ADC     HL,DE
        JR      NC,L49BA
        RR      H
        RR      L
        EXX
        RR      H
        RR      L
        EXX
        LD      A,(FP_EXP)
        INC     A
        LD      (FP_EXP),A
L49BA:  EXX
L49BB:  PUSH    HL
        EXX
        LD      B,H
        LD      C,L
        POP     DE
L49C0:  JP      L48B8
L49C3:  LD      A,E
        LD      E,D
        LD      D,00h
        EXX
        LD      B,E
        LD      E,D
        LD      D,A
        EXX
        JR      L4975

;  FDIV – (DE) = (DE) / (HL); Division durch 0 bzw. Überlauf -> ERR_13.
; <- aufgerufen von 2DA0h, 5015h, 517Fh, 520Bh, 52A6h, 537Ah, 541Eh, 5498h ... (9)
FDIV:   PUSH    DE
        LD      A,(DE)
        XOR     (HL)
        CPL
        AND     80h
        LD      (FP_RSIGN),A
        LD      B,(HL)
        RES     7,B
        LD      A,(DE)
        AND     7Fh
        SUB     B
        ADD     A,81h
L49E0:  CP      30h
        JP      C,L488F
        CP      0F0h
        JP      NC,ERR_13
        LD      (FP_EXP),A
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
        JP      P,ERR_13
        LD      C,04h
L4A13:  LD      B,08h
L4A15:  BIT     7,H
        JR      NZ,L4A30
        OR      A
L4A1A:  RLA
        EXX
        ADD     HL,HL
        EXX
        ADC     HL,HL
        DJNZ    L4A15
        PUSH    AF
        DEC     C
        JR      NZ,L4A13
L4A26:  POP     AF
        LD      E,A
        POP     AF
        LD      D,A
        POP     AF
        LD      C,A
        POP     AF
        LD      B,A
        JR      L49C0
L4A30:  EXX
        OR      A
        SBC     HL,DE
        EXX
        SBC     HL,DE
        CCF
        JR      C,L4A1A
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
        JR      NZ,L4A4F
        PUSH    AF
        LD      B,08h
        DEC     C
        JR      Z,L4A26
L4A4F:  EXX
        OR      A
        SBC     HL,DE
        EXX
        SBC     HL,DE
        SCF
        RLA
        DEC     B
        JR      NZ,L4A61
        PUSH    AF
        LD      B,08h
        DEC     C
        JR      Z,L4A26
L4A61:  EXX
        ADD     HL,HL
        EXX
        ADC     HL,HL
        JR      NC,L4A15
        JR      L4A4F
S2F_DIGITS:
        DEFB    00h
S2F_PTR:
        DEFB    00h,00h

;  STR2FP – Zahl im Text ab HL in Gleitkomma nach (DE) wandeln.
; <- aufgerufen von 22D4h, 2423h, 2F97h
STR2FP: LD      A,(HL)
        PUSH    HL
        POP     IX
        EX      DE,HL
        LD      (S2F_PTR),HL
        EX      AF,AF'
        XOR     A
        LD      (S2F_DIGITS),A
        LD      H,A
        LD      L,A
        EXX
        LD      H,A
        LD      L,A
        LD      B,A
        LD      C,A
        EX      AF,AF'
        CP      2Eh
        JR      Z,L4A9A
        SUB     30h
L4A88:  CALL    S2F_DIGIT
        CALL    NEXT_NONSPC_IX
        SUB     30h
        CP      0Ah
        JR      C,L4A88
        ADD     A,30h
        CP      2Eh
        JR      NZ,L4AAA
L4A9A:  CALL    NEXT_NONSPC_IX
        SUB     30h
        CP      0Ah
        JR      NC,L4AA8
        CALL    S2F_FRACDIGIT
        JR      L4A9A
L4AA8:  ADD     A,30h
L4AAA:  CP      45h
        JR      NZ,L4AF2
        EXX
        CALL    NEXT_NONSPC_IX
        LD      B,01h
        CP      0BCh
        JR      Z,L4ABE
        CP      0BDh
        JP      NZ,ERR_40
        DEC     B
L4ABE:  LD      A,B
        OR      A
        EX      AF,AF'
L4AC1:  CALL    NEXT_NONSPC_IX
        SUB     30h
        JR      Z,L4AC1
        CP      0Ah
        JR      NC,L4AE8
        LD      B,A
        CALL    NEXT_NONSPC_IX
        SUB     30h
        CP      0Ah
        JR      NC,L4AE8
        LD      C,A
        CALL    NEXT_NONSPC_IX
        SUB     30h
        CP      0Ah
L4ADE:  JP      C,ERR_13
        LD      A,B
        ADD     A,A
        ADD     A,A
        ADD     A,B
        ADD     A,A
        ADD     A,C
        LD      B,A
L4AE8:  EX      AF,AF'
        LD      A,B
        JR      NZ,L4AEE
        CPL
        INC     A
L4AEE:  LD      (S2F_DIGITS),A
        EXX
L4AF2:  PUSH    IX
        LD      A,(S2F_DIGITS)
        ADD     A,1Dh
        ADD     A,C
        LD      (S2F_DIGITS),A
        CP      30h
        JR      C,L4B07
        CP      80h
        JR      C,L4ADE
        JR      L4B58
L4B07:  LD      A,80h
        LD      (FP_RSIGN),A
        LD      A,0A0h
        LD      (FP_EXP),A
        PUSH    HL
        EXX
        POP     BC
        LD      D,H
        LD      E,L
        LD      HL,L4B21
        PUSH    HL
        LD      HL,(S2F_PTR)
        PUSH    HL
        JP      L48B8
L4B21:  LD      A,(S2F_DIGITS)
        LD      L,A
        LD      C,A
        LD      H,00h
        LD      B,H
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,BC
        LD      BC,FP_POW10_LOW
        ADD     HL,BC
        LD      DE,(S2F_PTR)
        LD      A,80h
        LD      (FP_RSIGN),A
        LD      A,20h
        ADD     A,(HL)
        LD      B,A
        LD      A,(DE)
        AND     7Fh
        ADD     A,B
        JR      C,L4ADE
        SUB     21h
        JR      NC,L4B48
        XOR     A
L4B48:  LD      BC,L4B50
        PUSH    BC
        PUSH    DE
        JP      L4913
L4B50:  POP     HL
        LD      BC,0005h
        LD      D,B
        LD      E,B
        LD      A,(HL)
        RET
L4B58:  LD      HL,L4B50
        PUSH    HL
        LD      HL,(S2F_PTR)
        PUSH    HL
        JP      L488F

;  NEXT_NONSPC_IX – IX auf das nächste Zeichen außer Leerzeichen, A = Zeichen.
; <- aufgerufen von 4A8Bh, 4A9Ah, 4AAFh, 4AC1h, 4ACDh, 4AD7h
NEXT_NONSPC_IX:
        INC     IX
        LD      A,(IX+0)
        CP      20h
        RET     NZ
        JR      NEXT_NONSPC_IX

;  S2F_DIGIT – Ziffer A in die Mantisse übernehmen (Zählung in B/C).
; <- aufgerufen von 4A88h, 4EC5h
S2F_DIGIT:
        OR      A
        JR      NZ,L4B73
        OR      B
        RET     Z
        XOR     A
L4B73:  EX      AF,AF'
        LD      A,B
        CP      09h
        JR      NZ,L4B89
        INC     C
        RET

;  S2F_FRACDIGIT – Nachkommaziffer übernehmen.
; <- aufgerufen von 4AA3h
S2F_FRACDIGIT:
        OR      A
        JR      NZ,L4B83
        DEC     C
        OR      B
        RET     Z
        INC     C
        XOR     A
L4B83:  EX      AF,AF'
        LD      A,B
        CP      09h
        RET     Z
        DEC     C
L4B89:  INC     B
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
FP_POW10_LOW:
        DEFB    0E0h,0F5h,0F7h,0D2h,0CAh,0E3h,0F3h,0B5h
        DEFB    87h,0FDh,0E7h,0B8h,0D1h,74h,9Eh,0EAh
        DEFB    25h,06h,12h,0C6h,0EDh,0AFh,87h,96h
        DEFB    0F7h,0F1h,0CDh,14h,0BEh,9Ah,0F4h,01h
        DEFB    9Ah,6Dh,0C1h,0F7h,81h,00h,0C9h,0F1h
        DEFB    0FBh,50h,0A0h,1Dh,97h
D4BD6:  DEFB    0FEh,65h,08h,0E5h,0BCh
FP_POW10:
        DEFB    01h,7Eh,4Ah,1Eh,0ECh    ; Betrag 1E-19 (Vorzeichenbit 0)
        DEFB    05h,8Fh,0EEh,92h,93h    ; Betrag 1E-18 (Vorzeichenbit 0)
        DEFB    08h,32h,0AAh,77h,0B8h   ; Betrag 1E-17 (Vorzeichenbit 0)
        DEFB    0Bh,0BFh,94h,95h,0E6h   ; Betrag 1E-16 (Vorzeichenbit 0)
        DEFB    0Fh,0F7h,7Ch,1Dh,90h    ; Betrag 1E-15 (Vorzeichenbit 0)
        DEFB    12h,35h,0DCh,24h,0B4h   ; Betrag 1E-14 (Vorzeichenbit 0)
        DEFB    15h,42h,13h,2Eh,0E1h    ; Betrag 1E-13 (Vorzeichenbit 0)
        DEFB    19h,09h,0CCh,0BCh,8Ch   ; Betrag 1E-12 (Vorzeichenbit 0)
        DEFB    1Ch,0Ch,0FFh,0EBh,0AFh  ; Betrag 1E-11 (Vorzeichenbit 0)
        DEFB    1Fh,0CFh,0FEh,0E6h,0DBh ; Betrag 1E-10 (Vorzeichenbit 0)
        DEFB    23h,41h,5Fh,70h,89h     ; Betrag 1E-9 (Vorzeichenbit 0)
        DEFB    26h,12h,77h,0CCh,0ABh   ; Betrag 1E-8 (Vorzeichenbit 0)
        DEFB    29h,0D6h,94h,0BFh,0D6h  ; Betrag 1E-7 (Vorzeichenbit 0)
        DEFB    2Dh,06h,0BDh,37h,86h    ; Betrag 1E-6 (Vorzeichenbit 0)
        DEFB    30h,47h,0ACh,0C5h,0A7h  ; Betrag 1E-5 (Vorzeichenbit 0)
        DEFB    33h,59h,17h,0B7h,0D1h   ; Betrag 1E-4 (Vorzeichenbit 0)
        DEFB    37h,98h,6Eh,12h,83h     ; Betrag 1E-3 (Vorzeichenbit 0)
        DEFB    3Ah,3Dh,0Ah,0D7h,0A3h   ; Betrag 1E-2 (Vorzeichenbit 0)
        DEFB    3Dh,0CDh,0CCh,0CCh,0CCh ; Betrag 1E-1 (Vorzeichenbit 0)
        DEFB    41h,00h,00h,00h,80h     ; Betrag 1E0 (Vorzeichenbit 0)
        DEFB    44h,00h,00h,00h,0A0h    ; Betrag 1E1 (Vorzeichenbit 0)
        DEFB    47h,00h,00h,00h,0C8h    ; Betrag 1E2 (Vorzeichenbit 0)
        DEFB    4Ah,00h,00h,00h,0FAh    ; Betrag 1E3 (Vorzeichenbit 0)
        DEFB    4Eh,00h,00h,40h,9Ch     ; Betrag 1E4 (Vorzeichenbit 0)
        DEFB    51h,00h,00h,50h,0C3h    ; Betrag 1E5 (Vorzeichenbit 0)
        DEFB    54h,00h,00h,24h,0F4h    ; Betrag 1E6 (Vorzeichenbit 0)
        DEFB    58h,00h,80h,96h,98h     ; Betrag 1E7 (Vorzeichenbit 0)
        DEFB    5Bh,00h,20h,0BCh,0BEh   ; Betrag 1E8 (Vorzeichenbit 0)
        DEFB    5Eh,00h,28h,6Bh,0EEh    ; Betrag 1E9 (Vorzeichenbit 0)
        DEFB    62h,00h,0F9h,02h,95h    ; Betrag 1E10 (Vorzeichenbit 0)
        DEFB    65h,40h,0B7h,43h,0BAh   ; Betrag 1E11 (Vorzeichenbit 0)
        DEFB    68h,10h,0A5h,0D4h,0E8h  ; Betrag 1E12 (Vorzeichenbit 0)
        DEFB    6Ch,2Ah,0E7h,84h,91h    ; Betrag 1E13 (Vorzeichenbit 0)
        DEFB    6Fh,0F5h,20h,0E6h,0B5h  ; Betrag 1E14 (Vorzeichenbit 0)
        DEFB    72h,32h,0A9h,5Fh,0E3h   ; Betrag 1E15 (Vorzeichenbit 0)
        DEFB    76h,0BFh,0C9h,1Bh,8Eh   ; Betrag 1E16 (Vorzeichenbit 0)
        DEFB    79h,2Fh,0BCh,0A2h,0B1h  ; Betrag 1E17 (Vorzeichenbit 0)
        DEFB    7Ch,3Ah,6Bh,0Bh,0DEh    ; Betrag 1E18 (Vorzeichenbit 0)
        DEFB    80h,05h,23h,0C7h,8Ah
F2S_SRC:
        DEFB    00h,00h
F2S_EXP10:
        DEFB    00h
F2S_SIGN:
        DEFB    00h
F2S_DIGITS:
        DEFB    00h
F2S_DIG2:
        DEFB    00h,00h,00h,00h,00h,00h,00h
F2S_LAST:
        DEFB    00h
F2S_END:
        DEFB    00h
F2S_EXPTXT:
        DEFB    00h
F2S_EXPBUF:
        DEFS    9,00h

;  FP2STR – Gleitkommazahl (HL) in Text wandeln (Puffer ab 4CA0h).
; <- aufgerufen von 21FEh, 25C8h, 2965h, 2F4Bh
FP2STR: PUSH    DE
        CALL    FP2STR_PREP
        LD      A,(F2S_EXP10)
        OR      A
        JP      Z,L4D5B
        JP      M,L4CCA
        CP      09h
        JR      C,L4D26
        JR      L4CCF
L4CCA:  CP      0FFh
        JP      NC,L4D56
L4CCF:  LD      A,2Eh
        LD      (F2S_DIGITS),A
        LD      HL,F2S_END
        XOR     A
L4CD8:  DEC     HL
        CP      (HL)
        JR      Z,L4CD8
        LD      A,(HL)
        CP      2Eh
        JP      Z,L4D85
        INC     HL
        LD      (HL),45h
        INC     HL
        LD      A,(F2S_EXP10)
        LD      B,2Bh
        OR      A
        JP      P,L4CF8
        CP      0EDh
        JP      C,L4D85
        LD      B,2Dh
        CPL
        INC     A
L4CF8:  LD      (HL),B
        INC     HL
        LD      BC,0FF0Ah
L4CFD:  INC     B
        SUB     C
        JR      NC,L4CFD
        ADD     A,C
        LD      (HL),B
        INC     HL
        LD      (HL),A
        INC     HL
        LD      (HL),0Dh
L4D08:  LD      HL,F2S_SIGN
L4D0B:  INC     HL
        LD      A,(HL)
        CP      0Dh
        JR      Z,L4D18
        JR      NC,L4D0B
        OR      30h
        LD      (HL),A
        JR      L4D0B
L4D18:  LD      DE,F2S_SIGN
        XOR     A
        SBC     HL,DE
        LD      B,H
        LD      C,L
        POP     HL
        EX      DE,HL
        INC     BC
        LDIR
        RET
L4D26:  LD      HL,F2S_DIG2
        LD      DE,F2S_DIGITS
        LD      B,A
        INC     B
L4D2E:  DEC     B
        JR      Z,L4D37
        LD      A,(HL)
        LD      (DE),A
        INC     HL
        INC     DE
        JR      L4D2E
L4D37:  LD      A,2Eh
        LD      (DE),A
        LD      HL,F2S_END
L4D3D:  LD      (HL),0Dh
        DEC     HL
        LD      A,(HL)
        OR      A
        JR      Z,L4D3D
        CP      2Eh
        JR      NZ,L4D4A
        LD      (HL),0Dh
L4D4A:  LD      HL,F2S_DIGITS
        LD      A,(HL)
        CP      0Dh
        JR      NZ,L4D08
        LD      (HL),00h
        JR      L4D08
L4D56:  LD      DE,F2S_EXPBUF
        JR      L4D5E
L4D5B:  LD      DE,F2S_EXPTXT
L4D5E:  LD      HL,F2S_LAST
        LD      A,0Dh
        LD      (DE),A
        PUSH    DE
        DEC     DE
        LD      BC,0008h
        LDDR
        EX      DE,HL
        LD      A,(F2S_EXP10)
        OR      A
        JR      Z,L4D75
        LD      (HL),00h
        DEC     HL
L4D75:  LD      (HL),2Eh
        DEC     HL
        LD      (HL),00h
        POP     HL
L4D7B:  DEC     HL
        LD      A,(HL)
        CP      00h
        JR      NZ,L4D08
        LD      (HL),0Dh
        JR      L4D7B
L4D85:  LD      HL,L4D8F
        LD      BC,0003h
        POP     DE
        LDIR
        RET
L4D8F:  JR      NZ,L4DC1
        DEC     C

;  FP2STR_PREP – Vorzeichen (" " oder "-") merken, Betrag bilden,
;  Zehnerexponent über FP_POW10 bestimmen.
; <- aufgerufen von 4CB7h, 4E82h
FP2STR_PREP:
        LD      (F2S_SRC),HL
        LD      A,(HL)
        LD      B,20h
        OR      A
        JP      M,L4D9E
        LD      B,2Dh
L4D9E:  AND     7Fh
        LD      (HL),A
        LD      A,B
        LD      (F2S_SIGN),A
        EX      DE,HL
        LD      HL,D4BD6
        LD      A,0ECh
        EX      AF,AF'
L4DAC:  EX      AF,AF'
        INC     A
        EX      AF,AF'
        LD      BC,0005h
        ADD     HL,BC
        PUSH    HL
        PUSH    DE
        LD      A,(DE)
        CALL    FCMP_MAG
        POP     DE
        POP     HL
        JR      NC,L4DAC
        EX      AF,AF'
        LD      (F2S_EXP10),A
L4DC1:  PUSH    DE
        LD      BC,L4DD3
        PUSH    BC
        PUSH    DE
        LD      A,80h
        LD      (FP_RSIGN),A
        LD      A,(DE)
        SUB     (HL)
        ADD     A,81h
        JP      L49E0
L4DD3:  LD      HL,F2S_DIGITS
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
        JR      NC,L4DF9
L4DEC:  SRL     H
        RR      L
        EXX
        RR      H
        RR      L
        EXX
        INC     A
        JR      NZ,L4DEC
L4DF9:  POP     BC
        LD      A,09h
L4DFC:  EX      AF,AF'
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
        JR      NZ,L4DFC
L4E22:  LD      HL,F2S_END
        LD      A,(HL)
        LD      (HL),00h
        CP      05h
        LD      C,00h
        JR      C,L4E2F
        INC     C
L4E2F:  LD      B,0Ah
L4E31:  DEC     B
        JR      Z,L4E42
        DEC     HL
        LD      A,(HL)
        ADD     A,C
        LD      (HL),A
        SUB     0Ah
        LD      C,00h
        JR      C,L4E31
        INC     C
        LD      (HL),A
        JR      L4E31
L4E42:  LD      A,(F2S_DIGITS)
        OR      A
        RET     Z
        LD      HL,F2S_LAST
        LD      DE,F2S_END
        LD      BC,0009h
        LDDR
        EX      DE,HL
        LD      (HL),00h
        LD      A,(F2S_EXP10)
        INC     A
        LD      (F2S_EXP10),A
        JR      L4E22

;  FCMP – (DE) mit (HL) vergleichen: Z = gleich, C = (DE) < (HL).
; <- aufgerufen von 4F5Eh, 4F73h, 4F7Bh, 4F87h, 547Ch
FCMP:   LD      BC,0005h
        LD      A,(DE)
        OR      A
        JP      M,FCMP_MAG
        BIT     7,(HL)
        JR      Z,L4E6C
        SCF
        RET
L4E6C:  EX      DE,HL
        LD      A,(DE)

;  FCMP_MAG – Beträge (DE) und (HL) vergleichen.
; <- aufgerufen von 4DB6h
FCMP_MAG:
        CP      (HL)
        RET     NZ
        DEC     C
        ADD     HL,BC
        EX      DE,HL
        ADD     HL,BC
        EX      DE,HL
        LD      B,03h
L4E77:  LD      A,(DE)
        CP      (HL)
        RET     NZ
        DEC     HL
        DEC     DE
        DJNZ    L4E77
        LD      A,(DE)
        CP      (HL)
        RET

;  FINT – (DE) auf die ganze Zahl abschneiden (vermutlich, wie TRUNC).
; <- aufgerufen von 2DA6h, 55A9h
FINT:   EX      DE,HL
        CALL    FP2STR_PREP
        LD      A,(F2S_SIGN)
        LD      B,80h
        CP      20h
        JR      Z,L4E90
        LD      B,00h
L4E90:  LD      A,B
        LD      (FP_RSIGN),A
        OR      A
        JR      Z,L4F15
        LD      A,(F2S_EXP10)
        DEC     A
        JP      M,L4F4B
        LD      HL,F2S_END
        LD      B,0Dh
        LD      (HL),B
        SUB     08h
        JR      NC,L4EAE
L4EA8:  LD      (HL),B
        DEC     HL
        INC     A
        JR      NZ,L4EA8
        DEC     A
L4EAE:  INC     A
        LD      (S2F_DIGITS),A
        LD      IX,F2S_DIGITS
        XOR     A
        LD      H,A
        LD      L,A
        EXX
        LD      B,A
        LD      C,A
        LD      H,A
        LD      L,A
L4EBE:  LD      A,(IX+0)
        CP      0Dh
        JR      Z,L4ECC
        CALL    S2F_DIGIT
        INC     IX
        JR      L4EBE
L4ECC:  LD      A,(S2F_DIGITS)
        ADD     A,1Dh
        ADD     A,C
        LD      (S2F_DIGITS),A
        LD      A,0A0h
        LD      (FP_EXP),A
        PUSH    HL
        EXX
        POP     BC
        LD      D,H
        LD      E,L
        LD      HL,L4EEA
        PUSH    HL
        LD      HL,(F2S_SRC)
        PUSH    HL
        JP      L48B8
L4EEA:  LD      A,(S2F_DIGITS)
        LD      C,A
        LD      L,A
        LD      H,00h
        LD      B,H
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,BC
        LD      BC,FP_POW10_LOW
        ADD     HL,BC
        LD      DE,(F2S_SRC)
        XOR     A
        LD      (FP_SIGN),A
        LD      A,20h
        ADD     A,(HL)
        LD      B,A
        LD      A,(DE)
        AND     7Fh
        ADD     A,B
        JP      C,ERR_13
        SUB     21h
        JR      NC,L4F11
        XOR     A
L4F11:  PUSH    DE
        JP      L4913
L4F15:  LD      A,(F2S_EXP10)
        DEC     A
        JP      M,L4F50
        LD      HL,F2S_END
        LD      BC,0D00h
        LD      (HL),B
        SUB     08h
        JR      NC,L4F36
        JR      L4F31
L4F29:  EX      AF,AF'
        LD      A,(HL)
        OR      A
        JR      Z,L4F2F
        INC     C
L4F2F:  LD      (HL),B
        EX      AF,AF'
L4F31:  DEC     HL
        INC     A
        JR      NZ,L4F29
        DEC     A
L4F36:  EX      AF,AF'
        LD      A,C
        OR      A
        JR      Z,L4F47
L4F3B:  LD      A,(HL)
        INC     A
        LD      (HL),A
        CP      0Ah
        JR      NZ,L4F47
        LD      (HL),00h
        DEC     HL
        JR      L4F3B
L4F47:  EX      AF,AF'
        JP      L4EAE
L4F4B:  LD      DE,FP_ZERO
        JR      L4F53
L4F50:  LD      DE,FP_MONE
L4F53:  LD      HL,(F2S_SRC)
        EX      DE,HL

;  FCOPY – 5 Bytes (HL) nach (DE) kopieren.
; <- aufgerufen von 4FC6h, 5083h, 508Ch, 5098h, 5114h, 5121h, 5129h, 5162h ... (28)
FCOPY:  LD      BC,0005h
        LDIR
        RET

;  FCMP_NE – Gleitkommavergleich, Ergebnis als BOOLEAN-Konstante (<>).
; <- aufgerufen von 5FAFh
FCMP_NE:
        PUSH    DE
        CALL    FCMP
        JR      Z,L4F68
L4F63:  LD      HL,FP_MONE
        JR      L4F6B
L4F68:  LD      HL,FP_ZERO
L4F6B:  POP     DE
        JR      FCOPY

;  FCMP_GT – Gleitkommavergleich (>).
; <- aufgerufen von 5F8Fh
FCMP_GT:
        PUSH    DE
        EX      DE,HL
        JR      L4F73

;  FCMP_LT – Gleitkommavergleich (<).
; <- aufgerufen von 5FDAh
FCMP_LT:
        PUSH    DE
L4F73:  CALL    FCMP
        JR      C,L4F63
        JR      L4F68

;  FCMP_EQ – Gleitkommavergleich (=).
; <- aufgerufen von 6024h
FCMP_EQ:
        PUSH    DE
        CALL    FCMP
        JR      Z,L4F63
        JR      L4F68

;  FCMP_LE – Gleitkommavergleich (<=).
; <- aufgerufen von 6004h
FCMP_LE:
        PUSH    DE
        EX      DE,HL
        JR      L4F87

;  FCMP_GE – Gleitkommavergleich (>=).
; <- aufgerufen von 2D5Ah, 5F69h
FCMP_GE:
        PUSH    DE
L4F87:  CALL    FCMP
        JR      C,L4F68
        JR      L4F63
RND_SEED:
        DEFB    0BEh,35h,28h,0DCh,0CFh  ; Gleitkomma 0.20298827

;  FRND – RND: neue Zufallszahl aus der vorigen (Startwert 4F8Eh, Faktor 23).
; <- aufgerufen von 2F04h
FRND:   PUSH    DE
        EX      DE,HL
        LD      A,(HL)
        LD      BC,0004h
        ADD     HL,BC
        XOR     (HL)
        JP      M,L4FBF
        LD      DE,RND_SEED
        PUSH    DE
        LD      HL,FP_23
        CALL    FMUL
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
        CALL    NC,FRND_SHIFT
        POP     HL
        PUSH    HL
        CALL    FSTORE
        JR      L4FC9
L4FBF:  LD      DE,RND_SEED
        LD      HL,RND_START
        PUSH    DE
        CALL    FCOPY
L4FC9:  POP     HL
        POP     DE
        JR      FCOPY

;  FRND_SHIFT – Mantisse um A - C0h Stellen nach links schieben
;  (Nachkommateil).
; <- aufgerufen von 4FB5h
FRND_SHIFT:
        SUB     0C0h
L4FCF:  SLA     E
        RL      D
        RL      C
        RL      B
        DEC     A
        JR      NZ,L4FCF
        LD      A,0C0h
        JP      FP_NORM
RND_START:
        DEFB    0BEh,35h,28h,0DCh,0CFh  ; Gleitkomma 0.20298827
FP_23:  DEFB    0C5h,00h,00h,00h,0B8h   ; Gleitkomma 23
FTMP1:  DEFB    00h,00h,00h,00h,00h     ; Gleitkomma 0
FTMP2:  DEFB    00h,00h,00h,00h,00h     ; Gleitkomma 0
FTMP3:  DEFB    00h,00h,00h,00h,00h     ; Gleitkomma 0
FTMP4:  DEFB    00h,00h,00h,00h,00h     ; Gleitkomma 0

;  FTMP1_ADD – FTMP1 = FTMP1 + (HL).
; <- aufgerufen von 5003h, 50B6h, 516Eh, 5185h, 5234h, 523Fh, 524Ah, 5255h ... (14)
FTMP1_ADD:
        LD      DE,FTMP1
        JP      FADD

;  FTMP1_ADDMUL – FTMP1 = (FTMP1 + (HL)) * FTMP2 (Horner-Schema der Reihen).
; <- aufgerufen von 50A4h, 50AAh, 50B0h, 53A7h, 53ADh, 54BEh, 54C4h, 54CAh ... (13)
FTMP1_ADDMUL:
        CALL    FTMP1_ADD

;  FTMP1_MUL2 – FTMP1 = FTMP1 * FTMP2.
; <- aufgerufen von 508Fh
FTMP1_MUL2:
        LD      HL,FTMP2

;  FTMP1_MUL – FTMP1 = FTMP1 * (HL).
; <- aufgerufen von 509Eh, 5168h, 51DFh, 522Eh, 5239h, 5244h, 524Fh, 525Ah ... (15)
FTMP1_MUL:
        LD      DE,FTMP1
        JP      FMUL
SIN_QUAD:
        DEFB    00h
SIN_SIGN:
        DEFB    00h

;  FSIN – Sinus (DE) über die Reihe in x/(pi/2) (Koeffizienten ab 50E2h).
; <- aufgerufen von 2CC7h, 512Eh
FSIN:   PUSH    DE
        LD      HL,SIN_COEF
        CALL    FDIV
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
        JR      C,L503E
        SUB     0C2h
L502E:  SLA     E
        RL      D
        RL      C
        RL      B
        DEC     A
        JR      NZ,L502E
        LD      A,0C2h
        CALL    FP_NORM
L503E:  LD      HL,8000h
        CP      0C2h
        JR      C,L504B
        LD      H,L
        RES     7,B
        CALL    FP_NORM
L504B:  CP      0C1h
        JR      C,L5055
        INC     L
        RES     7,B
        CALL    FP_NORM
L5055:  EX      AF,AF'
        LD      A,(SIN_SIGN)
        XOR     H
        CPL
        AND     80h
        LD      H,A
        LD      (SIN_QUAD),HL
        EX      AF,AF'
        POP     HL
        PUSH    HL
        CALL    FSTORE
        LD      A,(SIN_QUAD)
        OR      A
        JR      Z,L5075
        POP     DE
        PUSH    DE
        LD      HL,FP_PONE
        CALL    FSUB
L5075:  POP     HL
        PUSH    HL
        LD      A,(HL)
        AND     7Fh
        LD      B,A
        LD      A,(SIN_SIGN)
        OR      B
        LD      (HL),A
        LD      DE,FTMP1
        CALL    FCOPY
        LD      DE,FTMP2
        LD      HL,FTMP1
        CALL    FCOPY
        CALL    FTMP1_MUL2
        LD      DE,FTMP2
        LD      HL,FTMP1
        CALL    FCOPY
        LD      HL,D50E7
        CALL    FTMP1_MUL
        LD      HL,D50EC
        CALL    FTMP1_ADDMUL
        LD      HL,D50F1
        CALL    FTMP1_ADDMUL
        LD      HL,D50F6
        CALL    FTMP1_ADDMUL
        LD      HL,D50FB
        CALL    FTMP1_ADD
        POP     DE
        LD      HL,FTMP1
        JP      FMUL

;  FP_NORM – Mantisse BCDE normalisieren (A = Exponent); 0 -> FP_SETZERO.
; <- aufgerufen von 503Bh, 5048h, 5052h, 52D7h
FP_NORM:
        BIT     7,B
        RET     NZ
        EX      AF,AF'
        LD      A,B
        OR      C
        OR      E
        OR      D
        JR      Z,FP_SETZERO
        EX      AF,AF'
L50CB:  BIT     7,B
        RET     NZ
        SLA     E
        RL      D
        RL      C
        RL      B
        DEC     A
        JR      NZ,L50CB

;  FP_SETZERO – Ergebnis 0 (A = 80h, Mantisse 0).
; <- aufgerufen von 488Fh
FP_SETZERO:
        LD      BC,0000h
        LD      DE,0000h
        LD      A,80h
        RET
SIN_COEF:
        DEFB    0C1h,0A1h,0DAh,0Fh,0C9h ; Gleitkomma 1.57079633
D50E7:  DEFB    0B4h,0DCh,0Fh,0Ah,9Fh   ; Gleitkomma 0.0001516717
D50EC:  DEFB    39h,61h,8Fh,29h,99h     ; Gleitkomma -0.0046741438
D50F1:  DEFB    0BDh,0C8h,77h,34h,0A3h  ; Gleitkomma 0.0796899183
D50F6:  DEFB    40h,85h,0E1h,5Dh,0A5h   ; Gleitkomma -0.645963759
D50FB:  DEFB    0C1h,94h,0DAh,0Fh,0C9h  ; Gleitkomma 1.57079632

;  FCOS – Kosinus über FSIN (Argument um pi/2 verschoben, Vorzeichen
;  angepasst).
; <- aufgerufen von 2D03h, 5119h
FCOS:   PUSH    DE
        LD      HL,SIN_COEF
        CALL    FSUB
        POP     HL
        CALL    FP_FIXSIGN
        EX      DE,HL
        JP      FSIN

;  FTAN – Tangens = sin(x) / cos(x).
; <- aufgerufen von 2D43h
FTAN:   PUSH    DE
        EX      DE,HL
        LD      DE,FTMP4
        CALL    FCOPY
        POP     DE
        PUSH    DE
        CALL    FCOS
        POP     HL
        PUSH    HL
        LD      DE,FTMP3
        CALL    FCOPY
        POP     DE
        PUSH    DE
        LD      HL,FTMP4
        CALL    FCOPY
        POP     DE
        PUSH    DE
        CALL    FSIN
        POP     DE
        LD      HL,FTMP3
        JP      FDIV
SQRT_EXP:
        DEFB    00h
SQRT_FLAG:
        DEFB    00h

;  FSQRT – Quadratwurzel (DE).
; <- aufgerufen von 2F12h, 5346h
FSQRT:  LD      A,03h
        LD      (SQRT_EXP),A
        PUSH    DE
        EX      DE,HL
        LD      A,(HL)
        ADD     A,80h
        JP      NC,ERR_13
        JR      NZ,L5156
        EX      AF,AF'
        LD      BC,0004h
        ADD     HL,BC
        LD      A,(HL)
        SBC     HL,BC
        OR      A
        JP      P,L51B5
        EX      AF,AF'
L5156:  BIT     0,A
        JR      NZ,L51D0
        LD      (SQRT_FLAG),A
        LD      (HL),0C0h
        LD      DE,FTMP1
        CALL    FCOPY
        LD      HL,SQRT_C1
        CALL    FTMP1_MUL
        LD      HL,D51EC
L516E:  CALL    FTMP1_ADD
L5171:  LD      DE,FTMP2
        POP     HL
        PUSH    HL
        CALL    FCOPY
        LD      DE,FTMP2
        LD      HL,FTMP1
        CALL    FDIV
        LD      HL,FTMP2
        CALL    FTMP1_ADD
        LD      HL,FTMP1
        LD      A,(HL)
        AND     7Fh
        DEC     A
        JR      C,L51B5
        OR      80h
        LD      (HL),A
        LD      A,(SQRT_EXP)
        DEC     A
        LD      (SQRT_EXP),A
        JR      NZ,L5171
        LD      A,(SQRT_FLAG)
        CP      40h
        CALL    NZ,EXP_HALF
        LD      B,(HL)
        RES     7,B
        ADD     A,B
        SUB     40h
        JR      C,L51B5
        JP      M,ERR_13
        OR      80h
        LD      (HL),A
        JR      L51B8
L51B5:  LD      HL,FP_ZERO
L51B8:  POP     DE
        JP      FCOPY

;  EXP_HALF – Exponent für die Quadratwurzel halbieren.
; <- aufgerufen von 51A2h
EXP_HALF:
        JR      C,L51C5
        SUB     40h
        SRL     A
        ADD     A,40h
        RET
L51C5:  LD      B,A
        LD      A,40h
        SUB     B
        SRL     A
        LD      B,A
        LD      A,40h
        SUB     B
        RET
L51D0:  INC     A
        LD      (SQRT_FLAG),A
        LD      (HL),0BFh
        LD      DE,FTMP1
        CALL    FCOPY
        LD      HL,D51F1
        CALL    FTMP1_MUL
        LD      HL,D51F6
        JR      L516E
SQRT_C1:
        DEFB    0C0h,00h,00h,00h,90h    ; Gleitkomma 0.5625
D51EC:  DEFB    0BFh,00h,00h,00h,0E0h   ; Gleitkomma 0.4375
D51F1:  DEFB    0C0h,00h,00h,00h,0E0h   ; Gleitkomma 0.875
D51F6:  DEFB    0BFh,00h,00h,00h,90h    ; Gleitkomma 0.28125
EXP_INT:
        DEFB    00h
EXP_SIGN:
        DEFB    00h

;  FEXP – e hoch (DE) (Reihe ab 52FEh, ln 2 = 5326h).
; <- aufgerufen von 2FC3h, 5583h
FEXP:   PUSH    DE
        LD      A,(DE)
        AND     80h
        LD      (EXP_INT),A
        LD      A,(DE)
        OR      80h
        LD      (DE),A
        LD      HL,FP_LN2
        CALL    FDIV
        POP     HL
        PUSH    HL
        LD      A,40h
        LD      (EXP_SIGN),A
        LD      A,(HL)
        SUB     0C1h
        CALL    NC,FEXP_SCALE
        POP     DE
        PUSH    DE
        LD      HL,D5321
        CALL    FSUB
        POP     HL
        PUSH    HL
        LD      DE,FTMP1
        CALL    FCOPY
        LD      HL,EXP_COEF
        CALL    FTMP1_MUL
        LD      HL,D5303
        CALL    FTMP1_ADD
        POP     HL
        PUSH    HL
        CALL    FTMP1_MUL
        LD      HL,D5308
        CALL    FTMP1_ADD
        POP     HL
        PUSH    HL
        CALL    FTMP1_MUL
        LD      HL,D530D
        CALL    FTMP1_ADD
        POP     HL
        PUSH    HL
        CALL    FTMP1_MUL
        LD      HL,D5312
        CALL    FTMP1_ADD
        POP     HL
        PUSH    HL
        CALL    FTMP1_MUL
        LD      HL,D5317
        CALL    FTMP1_ADD
        POP     HL
        PUSH    HL
        CALL    FTMP1_MUL
        LD      HL,D531C
        CALL    FTMP1_ADD
        LD      HL,FTMP1
        LD      B,(HL)
        RES     7,B
        LD      A,(EXP_SIGN)
        ADD     A,B
        JR      C,L52F5
        SUB     3Fh
        JR      C,L52E5
        JP      M,L52F5
        OR      80h
        LD      (HL),A
        LD      A,(EXP_INT)
        OR      A
        JR      Z,L5291
        LD      HL,FTMP1
        POP     DE
        JP      FCOPY
L5291:  POP     DE
        PUSH    DE
        LD      HL,FP_PONE
        CALL    FCOPY
        POP     DE
        PUSH    DE
        LD      A,(DE)
        CP      0FCh
        PUSH    AF
        JR      C,L52A3
        DEC     A
        LD      (DE),A
L52A3:  LD      HL,FTMP1
        CALL    FDIV
        POP     AF
        POP     HL
        RET     C
        LD      A,(HL)
        DEC     A
        LD      (HL),A
        RET     M
        PUSH    HL
        JP      L488F

;  FEXP_SCALE – Exponent des Ergebnisses einrechnen.
; <- aufgerufen von 5218h
FEXP_SCALE:
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
L52C0:  SLA     E
        RL      D
        RL      C
        RL      B
        RLA
        JR      C,L52F3
        DEC     H
        JR      NZ,L52C0
        ADD     A,40h
        JR      C,L52F3
        LD      (EXP_SIGN),A
        LD      A,0C0h
        CALL    FP_NORM
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
L52E5:  LD      A,(EXP_INT)
        OR      A
        JP      Z,ERR_13
L52EC:  LD      HL,FP_ZERO
        POP     DE
        JP      FCOPY
L52F3:  POP     AF
        POP     AF
L52F5:  LD      A,(EXP_INT)
        OR      A
        JP      NZ,ERR_13
        JR      L52EC
EXP_COEF:
        DEFB    0B3h,7Ch,8Ch,90h,0E3h   ; Gleitkomma 0.000108511278
D5303:  DEFB    0B6h,1Fh,0DFh,62h,0F8h  ; Gleitkomma 0.000947518223
D5308:  DEFB    0B9h,0E2h,6Dh,0DDh,0DEh ; Gleitkomma 0.00680129876
D530D:  DEFB    0BCh,8Bh,33h,0C1h,0A0h  ; Gleitkomma 0.0392467512
D5312:  DEFB    0BEh,89h,4Ah,0F1h,0ADh  ; Gleitkomma 0.169865765
D5317:  DEFB    0BFh,34h,33h,0F2h,0FAh  ; Gleitkomma 0.490129089
D531C:  DEFB    0C0h,36h,0F3h,04h,0B5h  ; Gleitkomma 0.707106782
D5321:  DEFB    0C0h,00h,00h,00h,80h    ; Gleitkomma 0.5
FP_LN2: DEFB    0C0h,0F8h,17h,72h,0B1h  ; Gleitkomma 0.693147181
LN_EXP: DEFB    00h
LN_SIGN:
        DEFB    00h
LN_FLAG:
        DEFB    00h

;  FLN – Natürlicher Logarithmus (DE) (Konstanten ab 543Ah: sqrt(2), ln(2)/2
;  ...).
; <- aufgerufen von 2EE8h, 545Eh, 556Fh
FLN:    PUSH    DE
        LD      A,80h
        LD      (LN_SIGN),A
        LD      (LN_EXP),A
        EX      DE,HL
        LD      A,(HL)
        OR      A
        JP      P,ERR_13
        CP      8Ah
        JR      NC,L534C
        XOR     A
        LD      (LN_EXP),A
        EX      DE,HL
        CALL    FSQRT
        POP     HL
        PUSH    HL
        LD      A,(HL)
L534C:  CP      0C1h
        CALL    C,FRECIP
        LD      B,00h
        CP      0C1h
        JR      Z,L535D
        SUB     0C1h
        LD      B,A
        LD      A,0C1h
        LD      (HL),A
L535D:  LD      A,B
        LD      (LN_FLAG),A
        LD      DE,FTMP1
        CALL    FCOPY
        POP     DE
        PUSH    DE
        LD      HL,FP_SQRT2
        CALL    FSUB
        LD      HL,FP_SQRT2
        CALL    FTMP1_ADD
        POP     DE
        PUSH    DE
        LD      HL,FTMP1
        CALL    FDIV
        POP     DE
        PUSH    DE
        LD      HL,D5453
        CALL    FMUL
        POP     HL
        PUSH    HL
        LD      DE,FTMP2
        CALL    FCOPY
        POP     HL
        PUSH    HL
        LD      DE,FTMP2
        CALL    FMUL
        LD      DE,FTMP1
        LD      HL,FTMP2
        CALL    FCOPY
        LD      HL,LN_COEF
        CALL    FTMP1_MUL
        LD      HL,D543F
        CALL    FTMP1_ADDMUL
        LD      HL,D5444
        CALL    FTMP1_ADDMUL
        LD      HL,D5449
        CALL    FTMP1_ADD
        POP     HL
        PUSH    HL
        CALL    FTMP1_MUL
        LD      DE,FTMP2
        LD      HL,FTMP1
        CALL    FCOPY
        LD      A,(LN_FLAG)
        ADD     A,A
        INC     A
        LD      B,A
        LD      A,08h
L53CC:  BIT     7,B
        JR      NZ,L53D5
        SLA     B
        DEC     A
        JR      NZ,L53CC
L53D5:  ADD     A,0C0h
        LD      HL,FTMP1
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
        LD      HL,D5458
        CALL    FTMP1_MUL
        LD      HL,FTMP2
        CALL    FTMP1_ADD
        LD      HL,FTMP1
        LD      A,(LN_SIGN)
        CALL    RET_IF_NZ
        POP     DE
        PUSH    DE
        CALL    FCOPY
        POP     DE
        LD      A,(LN_EXP)
        OR      A
        RET     NZ
        LD      HL,FTMP1
        JP      FADD

;  FRECIP – (DE) = 1 / (DE) (vermutlich für FATN bei |x| > 1).
; <- aufgerufen von 534Eh
FRECIP: PUSH    HL
        LD      DE,FTMP1
        CALL    FCOPY
        POP     DE
        PUSH    DE
        LD      HL,FP_PONE
        CALL    FCOPY
        POP     DE
        PUSH    DE
        LD      HL,FTMP1
        CALL    FDIV
        POP     HL
        LD      A,(HL)
        CP      0C1h
        JR      NC,L5432
        PUSH    HL
        EX      DE,HL
        LD      HL,FP_PONE
        CALL    FCOPY
        POP     HL
        LD      A,0C1h
L5432:  EX      AF,AF'
        LD      A,00h
        LD      (LN_SIGN),A
        EX      AF,AF'
        RET
LN_COEF:
        DEFB    0ADh,0A4h,62h,0CCh,0AFh ; Gleitkomma 1.3098e-06
D543F:  DEFB    0B2h,9Fh,0E9h,47h,0F9h  ; Gleitkomma 5.94332e-05
D5444:  DEFB    0B8h,0A4h,82h,0AAh,0DCh ; Gleitkomma 0.0033670968
D5449:  DEFB    0BFh,0BFh,0CCh,0B0h,0AFh; Gleitkomma 0.34314575
FP_SQRT2:
        DEFB    0C1h,33h,0F3h,04h,0B5h  ; Gleitkomma 1.41421356
D5453:  DEFB    0C3h,99h,79h,82h,0BAh   ; Gleitkomma 5.82842712
D5458:  DEFB    0BFh,0F8h,17h,72h,0B1h  ; Gleitkomma 0.34657359

;  FLOG – Zehnerlogarithmus: LN(x) * log10(e) (5468h).
; <- aufgerufen von 2EDAh
FLOG:   PUSH    DE
        CALL    FLN
        POP     DE
        LD      HL,FP_LOG10E
        JP      FMUL
FP_LOG10E:
        DEFB    0BFh,0A9h,0D8h,5Bh,0DEh ; Gleitkomma 0.434294482
ATN_SIGN:
        DEFB    00h
ATN_FLAG:
        DEFB    00h

;  FATN – Arcustangens (DE) (Reihe ab 551Ah). Nur auf etwa 5 Stellen genau:
;  ARCTAN(1) ergibt 0.78540579 statt 0.78539816 (test_sb4515_run.py).
; <- aufgerufen von 2EF6h
FATN:   PUSH    DE
        EX      DE,HL
        LD      A,(HL)
        AND     80h
        LD      (ATN_SIGN),A
        SET     7,(HL)
        LD      DE,FP_PONE
        CALL    FCMP
        LD      A,80h
        JR      NC,L549C
        LD      DE,FTMP1
        POP     HL
        PUSH    HL
        CALL    FCOPY
        POP     DE
        PUSH    DE
        LD      HL,FP_PONE
        CALL    FCOPY
        POP     DE
        PUSH    DE
        LD      HL,FTMP1
        CALL    FDIV
        XOR     A
L549C:  LD      (ATN_FLAG),A
        POP     HL
        PUSH    HL
        LD      DE,FTMP1
        CALL    FCOPY
        POP     HL
        PUSH    HL
        CALL    FTMP1_MUL
        LD      HL,FTMP1
        LD      DE,FTMP2
        CALL    FCOPY
        LD      HL,ATN_COEF
        CALL    FTMP1_MUL
        LD      HL,D551F
        CALL    FTMP1_ADDMUL
        LD      HL,D5524
        CALL    FTMP1_ADDMUL
        LD      HL,D5529
        CALL    FTMP1_ADDMUL
        LD      HL,D552E
        CALL    FTMP1_ADDMUL
        LD      HL,D5533
        CALL    FTMP1_ADDMUL
        LD      HL,D5538
        CALL    FTMP1_ADDMUL
        LD      HL,D553D
        CALL    FTMP1_ADDMUL
        LD      HL,D5542
        CALL    FTMP1_ADDMUL
        LD      HL,FP_PONE
        CALL    FTMP1_ADD
        POP     HL
        PUSH    HL
        CALL    FTMP1_MUL
        POP     DE
        PUSH    DE
        LD      HL,FTMP1
        CALL    FCOPY
        LD      A,(ATN_FLAG)
        OR      A
        JR      NZ,L5514
        POP     DE
        PUSH    DE
        LD      HL,SIN_COEF
        CALL    FCOPY
        POP     DE
        PUSH    DE
        LD      HL,FTMP1
        CALL    FSUB
L5514:  POP     HL
        LD      A,(ATN_SIGN)
        JR      RET_IF_NZ
ATN_COEF:
        DEFB    37h,0CAh,9Ah,56h,0DEh   ; Gleitkomma -0.00169630661
D551F:  DEFB    0BAh,12h,77h,0CCh,0ABh  ; Gleitkomma 0.01048576
D5524:  DEFB    3Bh,23h,0B2h,5Eh,0F8h   ; Gleitkomma -0.030318592
D5529:  DEFB    0BCh,20h,63h,90h,0E9h   ; Gleitkomma 0.057022464
D552E:  DEFB    3Dh,0EEh,3Dh,0E0h,0AAh  ; Gleitkomma -0.08343552
D5533:  DEFB    0BDh,4Fh,1Ah,0D5h,0DFh  ; Gleitkomma 0.10929318
D5538:  DEFB    3Eh,0E3h,0AFh,03h,92h   ; Gleitkomma -0.14259219
D553D:  DEFB    0BEh,2Ah,7Bh,0C7h,0CCh  ; Gleitkomma 0.19997971
D5542:  DEFB    3Fh,17h,96h,0AAh,0AAh   ; Gleitkomma -0.33333272
ATN_TMP1:
        DEFB    00h,00h,00h,00h,00h     ; Gleitkomma 0
ATN_INV:
        DEFB    00h
ATN_TMP2:
        DEFB    00h,00h,00h,00h,00h     ; Gleitkomma 0

;  FATN_CORE – Arcustangens-Reihe für das reduzierte Argument.
FATN_CORE:
        PUSH    DE
        LD      DE,ATN_TMP2
        CALL    FCOPY
        POP     HL
        PUSH    HL
        LD      BC,0004h
        ADD     HL,BC
        LD      A,(HL)
        OR      A
        POP     HL
        PUSH    HL
        JP      P,L488F
        LD      A,(HL)
        AND     80h
        LD      (ATN_INV),A
        SET     7,(HL)
        EX      DE,HL
        CALL    FLN
        LD      A,(ATN_INV)
        OR      A
        CALL    Z,FP_FRAC
        POP     DE
        PUSH    DE
        LD      HL,ATN_TMP2
        CALL    FMUL
        POP     DE
        PUSH    DE
        CALL    FEXP
        POP     HL
        LD      A,(ATN_INV)

;  RET_IF_NZ – OR A, RET NZ.
; <- aufgerufen von 53F6h
RET_IF_NZ:
        OR      A
        RET     NZ

;  FP_FIXSIGN – Ist die Mantisse nicht normalisiert (0), nichts; sonst
;  Vorzeichen in (HL) umdrehen.
; <- aufgerufen von 242Bh, 2D35h, 2F9Ch, 5108h
FP_FIXSIGN:
        LD      BC,0004h
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

;  FP_FRAC – Nachkommateil von ATN_TMP2 bilden; negativ -> ERR_13
;  (vermutlich).
; <- aufgerufen von 5576h
FP_FRAC:
        LD      HL,ATN_TMP2
        LD      DE,ATN_TMP1
        CALL    FCOPY
        LD      DE,ATN_TMP2
        CALL    FINT
        LD      DE,ATN_TMP1
        LD      HL,ATN_TMP2
        CALL    FSUB
        LD      HL,ATN_TMP1+4
        LD      A,(HL)
        OR      A
        JP      M,ERR_13
        LD      HL,ATN_TMP2
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
        JR      C,L55DF
        JR      Z,L55DC
L55D1:  SLA     E
        RL      D
        RL      C
        RL      B
        DEC     A
        JR      NZ,L55D1
L55DC:  RL      B
        RET     C
L55DF:  LD      A,80h
        LD      (ATN_INV),A
        RET
FP_ZERO:
        DEFB    80h,00h,00h,00h,00h     ; Gleitkomma 0
FP_PONE:
        DEFB    0C1h,00h,00h,00h,80h    ; Gleitkomma 1
FP_MONE:
        DEFB    41h,00h,00h,00h,80h     ; Gleitkomma -1
        DEFS    140,00h

;  RUN_START – Ausführung beginnen: RUN_MODE = 2, globale Variablen anlegen
;  (RUN_ALLOC), Hauptblock ausführen, danach Dateien schließen und PAS_READY.
RUN_START:
        LD      A,02h
        LD      (RUN_MODE),A
        LD      IX,(INBUF)
        LD      IY,NEG_SIZE_TAB
        LD      HL,TXT_START
        INC     HL
        CALL    RUN_ALLOC
        LD      (RT_SP),IX
        POP     HL
        CALL    RUN_STMT_BRK
        JP      RUN_END

;  RUN_ALLOC – VAR-Abschnitt zur Laufzeit: Platz für jede Variable belegen (IX
;  abwärts, Größen aus NEG_SIZE_TAB), Typbyte eintragen; Felder bekommen einen
;  Kopf (Typ, Dimension, Zeiger auf die Daten in RT_AREA0).
; <- aufgerufen von 5691h, 579Ah
RUN_ALLOC:
        CALL    RUN_GETTOK
        CP      62h
        RET     NZ
        LD      B,0FFh
        JR      L56BF
L56A9:  LD      A,(HL)
        BIT     6,A
        JR      NZ,L56D3
        AND     0Fh
        LD      (SM_SIZE_IDX+2),A
        LD      A,(HL)

;  SM_SIZE_IDX – Operand (Displacement): Typcode als Index in NEG_SIZE_TAB.
SM_SIZE_IDX:
        LD      C,(IY+0)                ; Operand wird zur Laufzeit gesetzt
        ADD     IX,BC
        LD      (IX+0),A
        INC     HL
        INC     HL
        INC     HL
L56BF:  CALL    RUN_GETTOK
        CP      0E2h
        JR      Z,L56A9
        CP      78h
        JR      Z,L56BF
        CP      0DDh
        RET     NZ
        LD      A,(HL)
        INC     HL
        LD      H,(HL)
        LD      L,A
        JR      L56BF
L56D3:  LD      C,0FBh
        ADD     IX,BC
        LD      (IX+0),A
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        LD      (IX+1),E
        LD      (IX+2),D
        EXX
        LD      HL,(RT_AREA0)
        LD      (IX+3),L
        LD      (IX+4),H
        EXX
        LD      A,04h
        ADD     A,E
        LD      E,A
        JR      NC,L56F7
        INC     D
L56F7:  LD      A,(DE)
        INC     DE
        EX      AF,AF'
        LD      A,(DE)
        EXX
        LD      B,A
        EX      AF,AF'
        LD      C,A
        ADD     HL,BC
        LD      (RT_AREA0),HL
        EXX
        JR      L56BF

;  NEG_SIZE_TAB – Negative Größe je Typ (-6, -3, -2, -2).
NEG_SIZE_TAB:
        DEFB    0FAh,0FDh,0FEh,0FEh

;  RUN_NOMEM – Kein Platz mehr für den Stapel -> ERR_39.
RUN_NOMEM:
        JP      ERR_39

;  RUN_STMT_BRK – BREAK prüfen, Token holen, dann RUN_BEGIN.
; <- aufgerufen von 5699h, 57D0h
RUN_STMT_BRK:
        CALL    BRKEY
        JP      Z,BREAK_STOP
        CALL    RUN_GETTOK

;  RUN_BEGIN – BEGIN ... END: Platz prüfen (mind. 100h Bytes zwischen RT_AREA0
;  und RT_SP), Anweisungen (RUN_STATEMENT) ausführen, solange ";" folgt.
RUN_BEGIN:
        EXX
        LD      DE,0100h
        LD      HL,(RT_AREA0)
        ADD     HL,DE
        JR      C,RUN_NOMEM
        LD      DE,(RT_SP)
        SBC     HL,DE
        JR      NC,RUN_NOMEM
        EXX
L5729:  CALL    RUN_STATEMENT
        CALL    RUN_GETTOK
        CP      76h
        JR      Z,L5729
        RET

;  RUN_PCALL – Prozeduraufruf (Token E4h als Anweisung).
RUN_PCALL:
        EX      DE,HL
        LD      HL,(RT_AREA3)
        PUSH    HL
        LD      HL,(RT_SP)
        LD      (RT_AREA3),HL
        EX      DE,HL
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        CALL    RUN_CALLSUB
        POP     DE
        LD      (RT_AREA3),DE
        RET

;  RUN_CALLSUB – Unterprogramm aufrufen: aktuelle Parameter auswerten, lokale
;  Variablen anlegen, den Stapel umkopieren (DI), Rumpf ausführen und den
;  alten Zustand wiederherstellen.
; <- aufgerufen von 5745h, 5811h
RUN_CALLSUB:
        LD      A,(DE)
        AND     A
        JR      Z,L5783
        PUSH    DE
        CALL    RUN_GETTOK
L5756:  CALL    RUN_EXPR
        CALL    RUN_GETTOK
        CP      78h
        JR      Z,L5756
        EX      (SP),HL
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        INC     HL
        LD      IX,TOKLEN_TAB
        JR      L5770
L576D:  CALL    TOK_SKIP
L5770:  CALL    RUN_GETTOK
        CP      8Dh
        JR      NZ,L576D
L5777:  CALL    RUN_GETTOK
        CP      0DDh
        JR      NZ,L578C
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        JR      L578D
L5783:  PUSH    HL
        EX      DE,HL
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        JR      L5777
L578C:  EX      DE,HL
L578D:  LD      HL,(RT_AREA0)
        PUSH    HL
        LD      IX,(RT_SP)
        LD      IY,NEG_SIZE_TAB
        EX      DE,HL
        CALL    RUN_ALLOC
        DEC     HL
        EXX
        PUSH    IX
        POP     DE
        LD      HL,(RT_AREA1)
        PUSH    HL
        LD      HL,(RT_AREA3)
        LD      (RT_AREA1),HL
        DI
        XOR     A
        LD      L,A
        LD      H,A
        ADD     HL,SP
        PUSH    HL
        LD      B,H
        LD      C,L
        LD      HL,(STACK_TOP)
        PUSH    HL
        SBC     HL,BC
        INC     HL
        INC     HL
        INC     HL
        INC     HL
        LD      B,H
        LD      C,L
        EX      (SP),HL
        LD      SP,HL
        DEC     HL
        DEC     DE
        LDDR
        INC     HL
        INC     DE
        PUSH    DE
        PUSH    HL
        LD      (RT_SP),DE
        EXX
        EI
        CALL    RUN_STMT_BRK
        CALL    RUN_GETTOK
        DI
        POP     DE
        POP     HL
        LD      SP,HL
        POP     BC
        POP     IY
        LDIR
        LD      SP,IY
        LD      HL,(RT_AREA1)
        LD      (RT_SP),HL
        POP     HL
        LD      (RT_AREA1),HL
        POP     HL
        LD      (RT_AREA0),HL
        POP     HL
        EI
        RET

;  RUN_FCALL – Funktionsaufruf im Ausdruck (Token E5h): Ergebnisplatz anlegen,
;  RUN_CALLSUB.
RUN_FCALL:
        LD      A,(HL)
        INC     HL
        EX      DE,HL
        LD      HL,(RT_AREA3)
        PUSH    HL
        LD      HL,(RT_SP)
        LD      (RT_AREA3),HL
        PUSH    HL
        CALL    TYPE_SIZE
        POP     HL
        SBC     HL,BC
        LD      (RT_SP),HL
        LD      (HL),A
        PUSH    HL
        EX      DE,HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        INC     DE
        CALL    RUN_CALLSUB
        POP     DE
        LD      (RT_SP),DE
        POP     DE
        LD      (RT_AREA3),DE
        RET

;  RUN_CONST – Konstante auf den Stapel: Zeichen, Zahl (E6h) oder TRUE/FALSE.
; <- aufgerufen von 5B7Fh
RUN_CONST:
        CALL    RUN_GETTOK
L5822:  CP      0DFh
        JP      Z,L5C9E
        CP      0E6h
        JR      Z,RUN_NUMBER
        CP      74h
        LD      A,00h
        JR      Z,L5832
        INC     A
L5832:  EX      DE,HL
        LD      HL,(RT_SP)
        DEC     HL
        LD      (HL),A
        DEC     HL
        LD      (RT_SP),HL
        LD      (HL),03h
        EX      DE,HL
        RET

;  RUN_NUMBER – Zahlkonstante (E6h) auf den Laufzeitstapel legen (INTEGER oder
;  REAL).
RUN_NUMBER:
        LD      A,(HL)
        LD      B,00h
        INC     HL
        EX      DE,HL
        LD      HL,(RT_SP)
        AND     A
        JR      Z,L585C
        LD      C,03h
        SBC     HL,BC
        LD      (HL),A
        LD      (RT_SP),HL
        INC     DE
        INC     DE
        INC     DE
L5856:  DEC     C
        INC     HL
        EX      DE,HL
        LDIR
        RET
L585C:  LD      C,06h
        SBC     HL,BC
        LD      (HL),A
        LD      (RT_SP),HL
        JR      L5856

;  TYPE_SIZE – Speicherbedarf zu Typcode A (Tabelle 5873h: REAL 6, INTEGER 3,
;  CHAR 2, BOOLEAN 2 Bytes samt Typbyte) nach C.
; <- aufgerufen von 2862h, 3F24h, 5800h, 589Dh, 58B0h, 5E18h, 5E63h, 5E85h ... (14)
TYPE_SIZE:
        PUSH    AF
        AND     0Fh
        LD      HL,TYPE_SIZE_TAB
        LD      B,00h
        LD      C,A
        ADD     HL,BC
        LD      C,(HL)
        POP     AF
        RET
TYPE_SIZE_TAB:
        DEFB    06h,03h,02h,02h

;  RUN_ASSIGN_G – Zuweisung an eine globale Variable (E2h): Adresse, ":=",
;  Ausdruck, speichern.
RUN_ASSIGN_G:
        CALL    VAR_ADDR_G
L587A:  PUSH    AF
        PUSH    DE
        CALL    RUN_GETTOK
        CALL    RUN_EXPR
        POP     DE
        POP     AF
        PUSH    HL
        CALL    RT_POPVAR
        POP     HL
        RET

;  RUN_ASSIGN_L – Zuweisung an eine lokale Variable (E3h).
RUN_ASSIGN_L:
        CALL    VAR_ADDR_L
        JR      L587A

;  RUN_LOAD_G – Globale Variable (E2h) im Ausdruck auf den Stapel legen.
RUN_LOAD_G:
        CALL    VAR_ADDR_G
L5892:  PUSH    HL
        CALL    RT_PUSHVAR
        POP     HL
        RET

;  RUN_LOAD_L – Lokale Variable (E3h) auf den Stapel legen.
RUN_LOAD_L:
        CALL    VAR_ADDR_L
        JR      L5892

;  RT_POPVAR – Obersten Stapelwert in die Variable DE (Typ A) schreiben.
; <- aufgerufen von 2106h, 210Dh, 2360h, 5885h
RT_POPVAR:
        CALL    TYPE_SIZE
        LD      HL,(RT_SP)
        INC     HL
        BIT     6,A
        JR      NZ,L58A9
        INC     DE
L58A9:  DEC     BC
        LDIR
        LD      (RT_SP),HL
        RET

;  RT_PUSHVAR – Variable DE (Typ A) auf den Laufzeitstapel legen.
; <- aufgerufen von 20C4h, 20D4h, 5893h
RT_PUSHVAR:
        CALL    TYPE_SIZE
        LD      HL,(RT_SP)
        OR      A
        SBC     HL,BC
        LD      (RT_SP),HL
        PUSH    HL
        EX      DE,HL
        BIT     6,A
        JR      Z,L58C4
        INC     DE
        DEC     BC
L58C4:  LDIR
        POP     HL
        AND     0Fh
        LD      (HL),A
        RET

;  VAR_ADDR – Adresse der Variablen zum Token A (E2h global, sonst lokal): DE
;  = Adresse, A = Typ; bei Feldern Index auswerten (ARRAY_INDEX).
; <- aufgerufen von 20BEh, 20CEh, 2319h, 2836h, 5A4Eh
VAR_ADDR:
        CP      0E2h
        JR      Z,VAR_ADDR_G

;  VAR_ADDR_L – Adresse einer lokalen Variablen (Basis RT_AREA1).
; <- aufgerufen von 588Ah, 5898h
VAR_ADDR_L:
        LD      DE,(RT_AREA1)
        JR      L58D9

;  VAR_ADDR_G – Adresse einer globalen Variablen (Basis INBUF).
; <- aufgerufen von 5877h, 588Fh
VAR_ADDR_G:
        LD      DE,(INBUF)
L58D9:  LD      A,(HL)
        INC     HL
        LD      C,(HL)
        INC     HL
        LD      B,(HL)
        INC     HL
        EX      DE,HL
        ADD     HL,BC
        EX      DE,HL
        BIT     6,A
        RET     Z
        PUSH    AF
        PUSH    HL
        EX      DE,HL
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        LD      A,(HL)
        INC     HL
        LD      H,(HL)
        LD      L,A
        EX      (SP),HL

;  ARRAY_HOOK – Operand: Sprungziel der Feldindizierung (ARRAY_INDEX).
ARRAY_HOOK:
        JP      ARRAY_INDEX             ; Operand wird zur Laufzeit gesetzt

;  ARRAY_INDEX – Indizes "[i, j ...]" auswerten, gegen die Grenzen prüfen
;  (ERR_13) und die Elementadresse berechnen.
ARRAY_INDEX:
        LD      A,(DE)
        LD      B,A
        INC     DE
        LD      A,(DE)
        LD      C,A
        PUSH    BC
        PUSH    BC
        INC     DE
        INC     DE
        INC     DE
        INC     DE
        INC     DE
        PUSH    HL
        CALL    SYN_GETTOK
        POP     HL
        PUSH    DE
        JR      L590C
L5909:  PUSH    BC
        PUSH    DE
        EXX
L590C:  CALL    RUN_GETTOK
        CALL    RUN_EXPR
        EXX
        POP     DE
        CALL    SYN_GETTOK
        INC     DE
        INC     DE
        INC     DE
        INC     DE
        LD      A,(DE)
        INC     DE
        LD      C,A
        LD      A,(DE)
        INC     DE
        LD      B,A
        CALL    SYN_GETTOK
        PUSH    DE
        LD      HL,(RT_SP)
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        DEC     HL
        DEC     HL
        DEC     HL
        EX      DE,HL
        LD      A,10h
        AND     H
        JP      NZ,ERR_13
        INC     BC
        SBC     HL,BC
        JP      NC,ERR_13
        EX      DE,HL
        LD      (HL),B
        DEC     HL
        LD      (HL),C
        DEC     HL
        LD      (RT_SP),HL
        LD      (HL),01h
        POP     DE
        POP     BC
        DJNZ    L5909
        INC     HL
        INC     HL
        INC     HL
        EXX
        EX      (SP),HL
        DEC     H
        PUSH    HL
        EXX
        JR      Z,L5958
        EX      DE,HL
        INC     DE
        JR      L5966
L5958:  INC     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL
        LD      (RT_SP),HL
        POP     BC
        LD      B,C
        JR      L598B
L5964:  PUSH    BC
        DEC     DE
L5966:  LD      H,D
        LD      L,E
        INC     DE
        INC     DE
        INC     DE
        CALL    IMUL
        LD      H,D
        LD      L,E
        INC     DE
        INC     DE
        INC     DE
        LD      A,(DE)
        ADD     A,(HL)
        LD      (DE),A
        INC     HL
        INC     DE
        LD      A,(DE)
        ADC     A,(HL)
        LD      (DE),A
        POP     BC
        DJNZ    L5964
        LD      B,C
        DEC     DE
        EX      AF,AF'
        LD      A,(DE)
        INC     DE
        INC     DE
        LD      (RT_SP),DE
        LD      E,A
        EX      AF,AF'
        LD      D,A
L598B:  LD      HL,0000h
L598E:  ADD     HL,DE
        DJNZ    L598E
        EX      DE,HL
        POP     BC
        POP     HL
        ADD     HL,DE
        PUSH    HL
        LD      H,B
        LD      L,C
        CALL    RUN_GETTOK
        POP     DE
        POP     AF
        RET
L599E:  INC     DE
        INC     DE
        INC     DE
        INC     DE
        LD      A,(DE)
        LD      C,A
        INC     DE
        LD      A,(DE)
        LD      B,A
        POP     DE
        POP     AF
        INC     HL
        INC     HL
        RET

;  RUN_STATEMENT – Eine Anweisung ausführen: Token 69h-6Eh über RUN_TAB69,
;  8Fh-B2h über RUN_TAB8F, E2h-E4h über RUN_TABE2; andere Token beenden die
;  Anweisung.
; <- aufgerufen von 5729h, 5AE4h, 5BEBh, 5D92h, 5DAAh, 5DC0h
RUN_STATEMENT:
        CALL    RUN_GETTOK
        DEC     HL
        CP      69h
        RET     C
        CP      6Fh
        JR      C,L59D9
        CP      8Fh
        RET     C
        CP      0B3h
        JR      C,L59E1
        CP      0E2h
        RET     C
        CP      0E5h
        RET     NC
        EX      DE,HL
        LD      HL,RUN_TABE2
        SUB     0E2h
L59CA:  INC     DE

;  RUN_JUMP – Sprung über Tabelle HL mit Index A; DE (+1) wird als Textzeiger
;  übergeben.
RUN_JUMP:
        PUSH    DE
        ADD     A,A
        ADD     A,L
        LD      L,A
        JR      NC,L59D3
        INC     H
        OR      A
L59D3:  LD      A,(HL)
        INC     HL
        LD      H,(HL)
        LD      L,A
        EX      (SP),HL
        RET
L59D9:  EX      DE,HL
        LD      HL,RUN_TAB69
        SUB     69h
        JR      L59CA
L59E1:  EX      DE,HL
        LD      HL,RUN_TAB8F
        SUB     8Fh
        JR      L59CA

;  Sprungtabellen der Ausführung, Index = Token - Basis (RUN_JUMP).
RUN_TAB69:
        DEFW    RUN_BEGIN               ; 69h  BEGIN
        DEFW    RUN_IF                  ; 6Ah  IF
        DEFW    RUN_WHILE               ; 6Bh  WHILE
        DEFW    RUN_REPEAT              ; 6Ch  REPEAT
        DEFW    RUN_CASE                ; 6Dh  CASE
        DEFW    RUN_FOR                 ; 6Eh  FOR
RUN_TAB8F:
        DEFW    RUN_READ                ; 8Fh  READ(
        DEFW    RUN_READLN              ; 90h  READLN(
        DEFW    RUN_WRITE               ; 91h  WRITE(
        DEFW    RUN_PWRITE              ; 92h  PWRITE(
        DEFW    RUN_WRITELN             ; 93h  WRITELN(
        DEFW    RUN_PWRITELN            ; 94h  PWRITELN(
        DEFW    RUN_CALL                ; 95h  CALL(
        DEFW    RUN_POKE                ; 96h  POKE(
        DEFW    RUN_COUT                ; 97h  COUT(
        DEFW    RUN_OUTPUT              ; 98h  OUTPUT(
        DEFW    RUN_TRAN                ; 99h  TRAN(
        DEFW    RUN_SYRET               ; 9Ah  SYRET
        DEFW    RUN_SYRET2              ; 9Bh  SYRET2
        DEFW    RUN_TEMPO               ; 9Ch  TEMPO(
        DEFW    RUN_MUSIC               ; 9Dh  MUSIC(
        DEFW    RUN_RANGE               ; 9Eh  RANGE(
        DEFW    RUN_FKEY                ; 9Fh  FKEY(
        DEFW    RUN_GRAPH               ; 0A0h  GRAPH(
        DEFW    RUN_GSET                ; 0A1h  GSET(
        DEFW    RUN_GRSET               ; 0A2h  GRSET(
        DEFW    RUN_LINE                ; 0A3h  LINE(
        DEFW    RUN_BLINE               ; 0A4h  BLINE(
        DEFW    RUN_POSITION            ; 0A5h  POSITION(
        DEFW    RUN_PATTERN             ; 0A6h  PATTERN(
        DEFW    RUN_CURSOR              ; 0A7h  CURSOR(
        DEFW    RUN_FNAME               ; 0A8h  FNAME(
        DEFW    RUN_IMAGE               ; 0A9h  IMAGE(
        DEFW    RUN_COPY                ; 0AAh  COPY(
        DEFW    RUN_CLOSE               ; 0ABh  CLOSE
RUN_TABE2:
        DEFW    RUN_ASSIGN_G            ; 0E2h  <Bezeichner>
        DEFW    RUN_ASSIGN_L            ; 0E3h  <E3h>
        DEFW    RUN_PCALL               ; 0E4h  <E4h>
RUN_FOR:
        EX      DE,HL
        LD      HL,(SM_FOR_CMP+1)
        PUSH    HL
        LD      HL,(SM_FOR_STEP+1)
        PUSH    HL
        LD      HL,(SM_FOR_VAR1+1)
        PUSH    HL
        LD      A,(SM_FOR_LEN1+1)
        PUSH    AF
        LD      A,(SM_FOR_TYPE1+1)
        PUSH    AF
        EX      DE,HL
        CALL    RUN_GETTOK
        CALL    VAR_ADDR
        BIT     6,A
        JR      NZ,L5A56
        INC     DE
L5A56:  AND     0Fh
        LD      (SM_FOR_TYPE1+1),A
        LD      (SM_FOR_TYPE2+1),A
        DEC     A
        JR      Z,L5A64
        LD      A,01h
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
L5A64:  LD      A,02h
        EX      DE,HL
        CALL    FOR_SETVAR
        EX      DE,HL
        CALL    RUN_GETTOK
        CALL    RUN_EXPR
        EXX
        LD      A,(SM_FOR_LEN1+1)
        LD      DE,(SM_FOR_VAR1+1)
        LD      B,00h
        LD      C,A
        LD      HL,(RT_SP)
        INC     HL
        LDIR
        LD      (RT_SP),HL
        EXX
        CALL    RUN_GETTOK
        LD      DE,L5FB4
        LD      BC,FOR_INC
        CP      6Fh
        JR      Z,L5A99
        LD      DE,L5F6E
        LD      BC,FOR_DEC
L5A99:  LD      (SM_FOR_CMP+1),DE
        LD      (SM_FOR_STEP+1),BC
        CALL    RUN_EXPR
        CALL    RUN_GETTOK
        INC     HL
        INC     HL
        PUSH    HL
        LD      HL,(RT_SP)
L5AAD:  LD      D,H
        LD      E,L
        LD      BC,0002h
        LD      A,(HL)
        DEC     DE
        INC     HL
        DEC     A
        JR      NZ,L5ABA
        INC     HL
        INC     BC
L5ABA:  LDDR

;  SM_FOR_LEN1 – Operand: Länge der Laufvariablen.
SM_FOR_LEN1:
        LD      BC,0000h                ; Operand wird zur Laufzeit gesetzt

;  SM_FOR_VAR1 – Operand: Adresse der Laufvariablen.
SM_FOR_VAR1:
        LD      HL,0000h                ; Operand wird zur Laufzeit gesetzt
        ADD     HL,BC
        DEC     HL
        LDDR

;  SM_FOR_TYPE1 – Operand: Typ der Laufvariablen.
SM_FOR_TYPE1:
        LD      A,00h                   ; Operand wird zur Laufzeit gesetzt
        LD      (DE),A
        LD      (RT_SP),DE

;  SM_FOR_CMP – Operand: Vergleich mit dem Endwert (RUN_GT bei TO, RUN_LT bei
;  DOWNTO).
SM_FOR_CMP:
        CALL    0000h                   ; Operand wird zur Laufzeit gesetzt
        LD      HL,(RT_SP)
        INC     HL
        LD      A,(HL)
        INC     HL
        LD      (RT_SP),HL
        RRA
        POP     HL
        JR      C,L5B0F
        PUSH    HL
        CALL    BRKEY
        JP      Z,BREAK_STOP
        CALL    RUN_STATEMENT
SM_FOR_LEN2:
        LD      BC,0000h                ; Operand wird zur Laufzeit gesetzt
SM_FOR_VAR2:
        LD      HL,0000h                ; Operand wird zur Laufzeit gesetzt
        LD      DE,(RT_SP)
        DEC     DE
        ADD     HL,BC
        DEC     HL
        LDDR
SM_FOR_TYPE2:
        LD      A,00h                   ; Operand wird zur Laufzeit gesetzt
        LD      (DE),A
        LD      (RT_SP),DE

;  SM_FOR_STEP – Operand: FOR_INC bei TO, FOR_DEC bei DOWNTO.
SM_FOR_STEP:
        CALL    0000h                   ; Operand wird zur Laufzeit gesetzt
SM_FOR_LEN3:
        LD      BC,0000h                ; Operand wird zur Laufzeit gesetzt
SM_FOR_VAR3:
        LD      DE,0000h                ; Operand wird zur Laufzeit gesetzt
        LD      HL,(RT_SP)
        INC     HL
        LDIR
        JP      L5AAD
L5B0F:  POP     AF
        LD      (SM_FOR_TYPE1+1),A
        LD      (SM_FOR_TYPE2+1),A
        DEC     HL
        LD      D,(HL)
        DEC     HL
        LD      E,(HL)
        POP     AF
        POP     HL
        CALL    FOR_SETVAR
        POP     HL
        LD      (SM_FOR_STEP+1),HL
        POP     HL
        LD      (SM_FOR_CMP+1),HL
        PUSH    DE
        CALL    RT_DROP
        POP     HL
        RET

;  FOR_SETVAR – Länge und Adresse der Laufvariablen in die Befehle von RUN_FOR
;  eintragen.
; <- aufgerufen von 5A67h, 5B1Ch
FOR_SETVAR:
        LD      (SM_FOR_LEN1+1),A
        LD      (SM_FOR_LEN2+1),A
        LD      (SM_FOR_LEN3+1),A
        LD      (SM_FOR_VAR1+1),HL
        LD      (SM_FOR_VAR2+1),HL
        LD      (SM_FOR_VAR3+1),HL
        RET
L5B40:  INC     (HL)
        RET     NZ
        JR      L5B54

;  FOR_INC – Laufvariable um 1 erhöhen (TO); Überlauf -> ERR_13.
FOR_INC:
        LD      HL,(RT_SP)
        LD      A,(HL)
        DEC     A
        LD      A,01h
        INC     HL
        JR      NZ,L5B40
        INC     (HL)
        RET     NZ
        INC     HL
        ADD     A,(HL)
        LD      (HL),A
        RET     PO
L5B54:  JP      ERR_13
L5B57:  LD      A,(HL)
        SUB     B
        LD      (HL),A
        RET     NC
        JR      L5B54

;  FOR_DEC – Laufvariable um 1 erniedrigen (DOWNTO).
FOR_DEC:
        LD      HL,(RT_SP)
        LD      A,(HL)
        DEC     A
        LD      B,01h
        INC     HL
        JR      NZ,L5B57
        LD      A,(HL)
        SUB     B
        LD      (HL),A
        RET     NC
        INC     HL
        LD      A,(HL)
        SUB     B
        LD      (HL),A
        RET     PO
        JR      L5B54

;  CASE_LABEL – CASE-Marke (Konstante, auch mit Vorzeichen) auf den Stapel.
; <- aufgerufen von 5BA3h
CASE_LABEL:
        CALL    RUN_GETTOK
        CP      82h
        JP      Z,RUN_CONST
        CP      81h
        JP      NZ,L5822
        CALL    RUN_CONST
        PUSH    HL
        EX      DE,HL
        DEC     HL
        LD      D,(HL)
        DEC     HL
        LD      E,(HL)
        CALL    NEG_DE
        LD      (HL),E
        INC     HL
        LD      (HL),D
        POP     HL
        RET
RUN_CASE:
        CALL    RUN_EXPR
        CALL    RUN_GETTOK
L5B96:  CALL    RUN_GETTOK
        CP      72h
        JR      Z,L5BC4
        DEC     HL
L5B9E:  PUSH    HL
        CALL    RT_DUP
        POP     HL
        CALL    CASE_LABEL
        LD      A,03h
        CALL    RUN_COMPARE
        PUSH    HL
        CALL    RT_POPBOOL
        POP     HL
        JR      C,L5BE6
        CALL    RUN_GETTOK
        CP      78h
        JR      Z,L5B9E
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        CALL    RUN_GETTOK
        CP      72h
        JR      NZ,L5B96
L5BC4:  PUSH    HL
        CALL    RT_DROP
        POP     HL
        RET

;  CASE_SKIP – Bis zum ":" der Marke bzw. zum END des CASE weiterlesen.
; <- aufgerufen von 5BE6h, 5BF5h
CASE_SKIP:
        CALL    RUN_GETTOK
        CP      0DDh
        RET     Z
        CP      0DFh
        JR      Z,L5BE0
        CP      0E6h
        JR      Z,L5BE0
        CP      72h
        JR      NZ,CASE_SKIP
        POP     DE
        JP      L5BC4
L5BE0:  LD      DE,0006h
        ADD     HL,DE
        JR      CASE_SKIP
L5BE6:  CALL    CASE_SKIP
        INC     HL
        INC     HL
        CALL    RUN_STATEMENT
L5BEE:  CALL    RUN_GETTOK
        CP      72h
        JR      Z,L5BC4
        CALL    CASE_SKIP
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        JR      L5BEE

;  OP_PREP – Operanden für einen zweistelligen Operator angleichen (L5F40); Z
;  = beide INTEGER.
; <- aufgerufen von 5C21h, 5C5Ch, 5C95h, 5F6Eh, 5FB4h
OP_PREP:
        EX      AF,AF'
        CALL    RT_2OPS
        AND     0Fh
        CP      01h
        EX      AF,AF'
        INC     DE
        INC     HL
        EXX
        RET

;  RUN_EXPR – Ausdruck auswerten, Ergebnis auf dem Laufzeitstapel: einfacher
;  Ausdruck, ggf. Vergleich (RUN_TAB7A).
; <- aufgerufen von 2028h, 203Eh, 2076h, 207Eh, 2095h, 209Dh, 20B5h, 2112h ... (46)
RUN_EXPR:
        CALL    RUN_SIMPLE
        CALL    RUN_GETTOK
        DEC     HL
        CP      7Ah
        RET     C
        CP      81h
        RET     NC
        SUB     7Ah
        PUSH    AF
        INC     HL
        CALL    RUN_SIMPLE
        POP     AF

;  RUN_COMPARE – Vergleichsoperator A (7Ah-80h) über RUN_TAB7A ausführen.
; <- aufgerufen von 5BA8h
RUN_COMPARE:
        PUSH    HL
        CALL    OP_PREP
        LD      HL,RUN_TAB7A
        JP      RUN_JUMP
RUN_TAB7A:
        DEFW    0000h                   ; 7Ah  **IN
        DEFW    RUN_LT                  ; 7Bh  <
        DEFW    RUN_LE                  ; 7Ch  <=
        DEFW    RUN_EQ                  ; 7Dh  =
        DEFW    RUN_GE                  ; 7Eh  >=
        DEFW    RUN_GT                  ; 7Fh  >
        DEFW    RUN_NE                  ; 80h  <>

;  RUN_SIMPLE – Einfachen Ausdruck auswerten: Vorzeichen, Terme mit + - OR XOR
;  (RUN_TAB81).
; <- aufgerufen von 5C0Bh, 5C1Ch
RUN_SIMPLE:
        CALL    RUN_GETTOK
        CP      81h
        JR      Z,L5C65
        CP      82h
        JR      Z,L5C65
        DEC     HL
        CALL    RUN_TERM
        PUSH    HL
L5C48:  POP     HL
        CALL    RUN_GETTOK
        DEC     HL
        CP      81h
        RET     C
        CP      85h
        RET     NC
        INC     HL
        SUB     81h
        PUSH    AF
        CALL    RUN_TERM
L5C5A:  POP     AF
        PUSH    HL
        CALL    OP_PREP
        LD      HL,RUN_TAB81
        JP      RUN_JUMP
L5C65:  SUB     81h
        PUSH    AF
        CALL    RUN_TERM
        PUSH    HL
        CALL    RT_PUSHZERO
        CALL    RT_ROT3
        POP     HL
        JR      L5C5A
RUN_TAB81:
        DEFW    RUN_MINUS               ; 81h  -
        DEFW    RUN_PLUS                ; 82h  +
        DEFW    RUN_OR                  ; 83h  OR
        DEFW    RUN_XOR                 ; 84h  XOR

;  RUN_TERM – Term auswerten: Faktoren mit * AND DIV MOD / (RUN_TAB_MUL).
; <- aufgerufen von 5C44h, 5C57h, 5C68h
RUN_TERM:
        CALL    RUN_FACTOR
        PUSH    HL
L5C81:  POP     HL
        CALL    RUN_GETTOK
        DEC     HL
        CP      85h
        RET     C
        CP      8Ah
        RET     NC
        SUB     85h
        PUSH    AF
        INC     HL
        CALL    RUN_FACTOR
        POP     AF
        PUSH    HL
        CALL    OP_PREP
        LD      HL,RUN_TAB_MUL
        JP      RUN_JUMP
L5C9E:  INC     HL
        INC     HL
        INC     HL
        INC     HL
        EX      DE,HL
        LD      HL,(RT_SP)
        DEC     HL
        LD      A,(DE)
        LD      (HL),A
        DEC     HL
        LD      (HL),02h
        LD      (RT_SP),HL
        EX      DE,HL
        INC     HL
        INC     HL
        RET
RUN_TAB_MUL:
        DEFW    RUN_MUL
        DEFW    RUN_AND
        DEFW    RUN_DIV
        DEFW    RUN_MOD
        DEFW    RUN_RDIV
L5CBD:  XOR     A
        DEFB    01h                     ; Trick: verschluckt den folgenden Befehl
L5CBF:  LD      A,01h
        EXX
        LD      HL,(RT_SP)
        DEC     HL
        LD      (HL),A
        DEC     HL
        LD      (HL),03h
        LD      (RT_SP),HL
        EXX
        RET

;  RUN_FACTOR – Faktor auswerten: "(" Ausdruck ")", NOT, TRUE/FALSE, Zeichen,
;  Funktion (RUN_TABB3), Variable/Zahl/Funktionsaufruf (RUN_TABE2B).
; <- aufgerufen von 5C7Dh, 5C90h, 5CF9h
RUN_FACTOR:
        CALL    RUN_GETTOK
        CP      8Ah
        JR      Z,L5CF3
        CP      8Eh
        JR      Z,L5CF9
        CP      74h
        JR      Z,L5CBD
        CP      75h
        JR      Z,L5CBF
        CP      0D6h
        JR      C,L5D18
        CP      0DFh
        JR      Z,L5C9E
        SUB     0E2h
        EX      DE,HL
        LD      HL,RUN_TABE2B
        JP      RUN_JUMP
L5CF3:  CALL    RUN_EXPR
        JP      RUN_GETTOK
L5CF9:  CALL    RUN_FACTOR
        LD      DE,(RT_SP)
        INC     DE
        LD      A,(DE)
        CPL
        AND     01h
        LD      (DE),A
        RET
        INC     HL
        INC     HL
        INC     HL
        LD      DE,(RT_SP)
        DEC     DE
        LD      A,(HL)
        INC     HL
        LD      (DE),A
        DEC     DE
        LD      A,02h
        LD      (DE),A
        INC     HL
        RET
L5D18:  SUB     0B3h
        EX      DE,HL
        LD      HL,RUN_TABB3
        JP      RUN_JUMP
RUN_TABB3:
        DEFW    RUN_KEY                 ; 0B3h  KEY
        DEFW    RUN_REQTR               ; 0B4h  REQTR
        DEFW    RUN_PEEK                ; 0B5h  PEEK(
        DEFW    RUN_CIN                 ; 0B6h  CIN
        DEFW    RUN_INPUT               ; 0B7h  INPUT(
        DEFW    RUN_TAN                 ; 0B8h  TAN(
        DEFW    RUN_LOG                 ; 0B9h  LOG(
        DEFW    RUN_RND                 ; 0BAh  RND(
        DEFW    RUN_ABS                 ; 0BBh  ABS(
        DEFW    RUN_ARCTAN              ; 0BCh  ARCTAN(
        DEFW    RUN_CHR                 ; 0BDh  CHR(
        DEFW    RUN_COS                 ; 0BEh  COS(
        DEFW    RUN_EXP                 ; 0BFh  EXP(
        DEFW    RUN_LN                  ; 0C0h  LN(
        DEFW    RUN_ODD                 ; 0C1h  ODD(
        DEFW    RUN_ORD                 ; 0C2h  ORD(
        DEFW    RUN_PRED                ; 0C3h  PRED(
        DEFW    RUN_SIN                 ; 0C4h  SIN(
        DEFW    RUN_SQRT                ; 0C5h  SQRT(
        DEFW    RUN_TRUNC               ; 0C6h  TRUNC(
        DEFW    RUN_SUCC                ; 0C7h  SUCC(
        DEFW    RUN_FLOAT               ; 0C8h  FLOAT(
        DEFW    RUN_POINT               ; 0C9h  POINT(
        DEFW    RUN_POSH                ; 0CAh  POSH
        DEFW    RUN_POSV                ; 0CBh  POSV
        DEFW    RUN_CSRH                ; 0CCh  CSRH
        DEFW    RUN_CSRV                ; 0CDh  CSRV
RUN_TABE2B:
        DEFW    RUN_LOAD_G              ; 0E2h  <Bezeichner>
        DEFW    RUN_LOAD_L              ; 0E3h  <E3h>
        DEFW    RUN_TE4_E4              ; 0E4h  <E4h>
        DEFW    RUN_FCALL               ; 0E5h  <E5h>
        DEFW    RUN_NUMBER              ; 0E6h  <Zahl>

;  RUN_GETTOK – Nächstes Token (>= 60h) ab HL nach A holen; Kommentare (DEh)
;  über ihren Verweis überspringen.
; <- aufgerufen von 2079h, 2098h, 20B8h, 20BBh, 20C8h, 20CBh, 2316h, 2364h ... (71)
RUN_GETTOK:
        LD      A,5Fh
        DEC     HL
L5D64:  INC     HL
        CP      (HL)
        JR      NC,L5D64
        LD      A,(HL)
        INC     HL
        CP      0DEh
        RET     NZ
        LD      A,(HL)
        INC     HL
        LD      H,(HL)
        LD      L,A
        JR      RUN_GETTOK

;  RUN_COND – Token holen, BOOLEAN vom Stapel: C = TRUE.
; <- aufgerufen von 5D7Fh, 5DB2h
RUN_COND:
        CALL    RUN_GETTOK
        PUSH    HL
        CALL    RT_POPBOOL
        POP     HL
        RET
RUN_IF: CALL    RUN_EXPR
        CALL    RUN_COND
        JR      C,L5D90
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        CALL    RUN_GETTOK
        DEC     HL
        CP      0DBh
        RET     NZ
        INC     HL
L5D90:  INC     HL
        INC     HL
        CALL    RUN_STATEMENT
        CALL    RUN_GETTOK
        DEC     HL
        CP      0DBh
        RET     NZ
        INC     HL
L5D9D:  LD      E,(HL)
        INC     HL
        LD      D,(HL)
        EX      DE,HL
        RET
L5DA2:  CALL    BRKEY
L5DA5:  JP      Z,BREAK_STOP
        INC     HL
        INC     HL
        CALL    RUN_STATEMENT
        POP     HL
RUN_WHILE:
        PUSH    HL
        CALL    RUN_EXPR
        CALL    RUN_COND
        JR      C,L5DA2
        POP     DE
        JR      L5D9D
RUN_REPEAT:
        CALL    BRKEY
        JR      Z,L5DA5
        PUSH    HL
L5DC0:  CALL    RUN_STATEMENT
        CALL    RUN_GETTOK
        CP      76h
        JR      Z,L5DC0
        CALL    RUN_EXPR
        PUSH    HL
        CALL    RT_POPBOOL
        POP     DE
        POP     HL
        JR      NC,RUN_REPEAT
        EX      DE,HL
        RET
RUN_CHR:
        CALL    RUN_EXPR
        EXX
        LD      HL,(RT_SP)
        INC     HL
        LD      B,(HL)
        LD      (HL),02h
        LD      (RT_SP),HL
        INC     HL
        LD      A,(HL)
        LD      (HL),B
        AND     A
        JP      NZ,ERR_13
        EXX
        JP      RUN_GETTOK
RUN_PRED:
        CALL    RUN_EXPR
        EXX
        LD      HL,(RT_SP)
        INC     HL
        LD      A,(HL)
        OR      A
        JP      Z,ERR_13
        DEC     (HL)
        EXX
        JP      RUN_GETTOK
RUN_SUCC:
        CALL    RUN_EXPR
        EXX
        LD      HL,(RT_SP)
        INC     HL
        INC     (HL)
        JP      Z,ERR_13
        EXX
        JP      RUN_GETTOK

;  RT_DUP – Obersten Stapelwert verdoppeln.
; <- aufgerufen von 5B9Fh
RT_DUP: LD      HL,(RT_SP)
        LD      A,(HL)
        EX      DE,HL
        PUSH    DE
        CALL    TYPE_SIZE
        POP     HL
        XOR     A
        SBC     HL,BC
        LD      (RT_SP),HL
        EX      DE,HL
        LDIR
        RET
RUN_ODD:
        CALL    RUN_EXPR
        EXX
        LD      HL,(RT_SP)
        INC     HL
        LD      A,(HL)
        LD      (HL),03h
        LD      (RT_SP),HL
        AND     01h
        INC     HL
        LD      (HL),A
        EXX
        JP      RUN_GETTOK

;  RT_POPBOOL – BOOLEAN vom Laufzeitstapel nehmen: C = TRUE.
; <- aufgerufen von 5BACh, 5D77h, 5DCEh
RT_POPBOOL:
        LD      HL,(RT_SP)
        INC     HL
        LD      A,(HL)
        RRA
        INC     HL
        LD      (RT_SP),HL
        RET
RUN_ORD:
        CALL    RUN_EXPR
        EXX
        LD      HL,(RT_SP)
        INC     HL
        LD      A,(HL)
        LD      (HL),00h
        DEC     HL
        LD      (HL),A
        DEC     HL
        LD      (HL),01h
        LD      (RT_SP),HL
        EXX
        JP      RUN_GETTOK

;  RT_PUSHZERO – Null vom Typ des obersten Eintrags auf den Stapel (für
;  Vorzeichen "-").
; <- aufgerufen von 5C6Ch
RT_PUSHZERO:
        LD      HL,(RT_SP)
        LD      A,(HL)
        EX      DE,HL
        CALL    TYPE_SIZE
        EX      DE,HL
        AND     A
        SBC     HL,BC
        LD      (HL),A
        LD      (RT_SP),HL
        INC     HL
        AND     0Fh
        JR      NZ,L5E77
        LD      (HL),80h
        INC     HL
        DEC     C
L5E77:  LD      B,C
        XOR     A
        JR      L5E7D
L5E7B:  LD      (HL),A
        INC     HL
L5E7D:  DJNZ    L5E7B
        RET

;  RT_DROP – Obersten Stapelwert entfernen.
; <- aufgerufen von 5B28h, 5BC5h
RT_DROP:
        LD      HL,(RT_SP)
        EX      DE,HL
        LD      A,(DE)
        CALL    TYPE_SIZE
        EX      DE,HL
        ADD     HL,BC
        LD      (RT_SP),HL
        RET

;  RT_SWAP – Die beiden obersten Stapelwerte vertauschen (vermutlich).
; <- aufgerufen von 5ECFh
RT_SWAP:
        LD      HL,(RT_SP)
        LD      A,(HL)
        EX      DE,HL
        CALL    TYPE_SIZE
        EX      DE,HL
        PUSH    HL
        ADD     HL,BC
        LD      A,(HL)
        EX      DE,HL
        CALL    TYPE_SIZE
        EX      DE,HL
        ADD     HL,BC
        POP     DE
L5EA1:  DEC     DE
        DEC     HL
        LDDR
        INC     DE
        LD      (RT_SP),DE
        RET
        LD      HL,(RT_SP)
        LD      A,(HL)
        EX      DE,HL
L5EB0:  CALL    TYPE_SIZE
        EX      DE,HL
        ADD     HL,BC
        PUSH    BC
        LD      A,(HL)
        EX      DE,HL
        CALL    TYPE_SIZE
        EX      DE,HL
        ADD     HL,BC
        PUSH    BC
        LD      A,(HL)
        PUSH    HL
        CALL    TYPE_SIZE
        POP     HL
        LD      D,H
        LD      E,L
        ADD     HL,BC
        EX      DE,HL
        POP     BC
        EX      (SP),HL
        ADD     HL,BC
        EX      (SP),HL
        POP     BC
        JR      L5EA1

;  RT_ROT3 – Die drei obersten Stapelwerte umordnen.
; <- aufgerufen von 5C6Fh
RT_ROT3:
        CALL    RT_SWAP
        LD      A,(DE)
        JR      L5EB0

;  RUN_AND – AND auf dem Laufzeitstapel.
RUN_AND:
        EXX
        LD      A,(DE)
        AND     (HL)
        LD      (DE),A
        DEC     DE
        LD      (RT_SP),DE
        JP      L5C81
RUN_OR: EXX
        LD      A,(DE)
        OR      (HL)
L5EE4:  LD      (DE),A
        DEC     DE
        LD      (RT_SP),DE
        JP      L5C48
RUN_XOR:
        EXX
        LD      A,(DE)
        XOR     (HL)
        JR      L5EE4
RUN_MINUS:
        EX      AF,AF'
        EXX
        DEC     DE
        LD      (RT_SP),DE
        INC     DE
        JR      C,L5F0A
        LD      A,(DE)
        SUB     (HL)
        LD      (DE),A
        INC     HL
        INC     DE
        LD      A,(DE)
        SBC     A,(HL)
        LD      (DE),A
        JP      PO,L5C48
        JP      ERR_13
L5F0A:  CALL    FSUB
        JP      L5C48
RUN_PLUS:
        EX      AF,AF'
        EXX
        DEC     DE
        LD      (RT_SP),DE
        INC     DE
        JR      C,L5F28
        LD      A,(DE)
        ADD     A,(HL)
        INC     HL
        LD      (DE),A
        INC     DE
        LD      A,(DE)
        ADC     A,(HL)
        LD      (DE),A
        JP      PO,L5C48
        JP      ERR_13
L5F28:  CALL    FADD
        JP      L5C48

;  ICMP – INTEGER (DE) mit (HL) vergleichen (mit Vorzeichen): Z gleich, C
;  kleiner.
; <- aufgerufen von 5F57h, 5F7Bh, 5F9Dh, 5FC1h, 5FF0h, 6012h
ICMP:   LD      A,(DE)
        XOR     (HL)
        LD      A,(DE)
        JP      P,L5F39
        OR      01h
        RET     P
        SCF
        RET
L5F39:  CP      (HL)
        RET     NZ
        DEC     DE
        DEC     HL

;  BCMP – Bytes (DE) und (HL) vergleichen.
; <- aufgerufen von 5F63h, 5F89h, 5FA9h, 5FD4h, 5FFEh, 601Eh
BCMP:   LD      A,(DE)
        CP      (HL)
        RET

;  RT_2OPS – DE = zweitoberster, HL = oberster Stapelwert; A = Typ des
;  obersten.
; <- aufgerufen von 5BFFh
RT_2OPS:
        LD      DE,(RT_SP)
        LD      A,(DE)
        CALL    TYPE_SIZE
        LD      HL,(RT_SP)
        ADD     HL,BC
        EX      DE,HL
        RET
RUN_GE: EX      AF,AF'
        EXX
        JR      C,L5F68
        JR      NZ,L5F62
        INC     HL
        INC     DE
        PUSH    DE
        CALL    ICMP
L5F5A:  POP     HL
        LD      A,01h
        JR      NC,L5FCA
        XOR     A
        JR      L5FCA
L5F62:  PUSH    DE
        CALL    BCMP
        JR      L5F5A
L5F68:  PUSH    DE
        CALL    FCMP_GE
        JR      L5FDD
L5F6E:  CALL    OP_PREP
        PUSH    HL
RUN_GT: EX      AF,AF'
        EXX
        JR      C,L5F8E
        JR      NZ,L5F88
        INC     HL
        INC     DE
        PUSH    DE
        CALL    ICMP
L5F7E:  POP     HL
        LD      A,01h
        JR      Z,L5F85
        JR      NC,L5FCA
L5F85:  XOR     A
        JR      L5FCA
L5F88:  PUSH    DE
        CALL    BCMP
        JR      L5F7E
L5F8E:  PUSH    DE
        CALL    FCMP_GT
        JR      L5FDD
RUN_NE: EX      AF,AF'
        EXX
        JR      C,L5FAE
        JR      NZ,L5FA8
        INC     HL
        INC     DE
        PUSH    DE
        CALL    ICMP
L5FA0:  POP     HL
        LD      A,01h
        JR      NZ,L5FCA
        XOR     A
        JR      L5FCA
L5FA8:  PUSH    DE
        CALL    BCMP
        JR      L5FA0
L5FAE:  PUSH    DE
        CALL    FCMP_NE
        JR      L5FDD
L5FB4:  CALL    OP_PREP
        PUSH    HL
RUN_LT: EX      AF,AF'
        EXX
        JR      C,L5FD9
        JR      NZ,L5FD3
        INC     HL
        INC     DE
        PUSH    DE
        CALL    ICMP
L5FC4:  POP     HL
        LD      A,01h
        JR      C,L5FCA
        XOR     A
L5FCA:  LD      (HL),A
        DEC     HL
        LD      (HL),03h
        LD      (RT_SP),HL
        POP     HL
        RET
L5FD3:  PUSH    DE
        CALL    BCMP
        JR      L5FC4
L5FD9:  PUSH    DE
        CALL    FCMP_LT
L5FDD:  POP     HL
        LD      A,(HL)
        AND     01h
        INC     HL
        INC     HL
        INC     HL
        INC     HL
        JR      L5FCA
RUN_LE: EX      AF,AF'
        EXX
        JR      C,L6003
        JR      NZ,L5FFD
        INC     HL
        INC     DE
        PUSH    DE
        CALL    ICMP
L5FF3:  POP     HL
        LD      A,01h
        JR      C,L5FCA
        JR      Z,L5FCA
        XOR     A
        JR      L5FCA
L5FFD:  PUSH    DE
        CALL    BCMP
        JR      L5FF3
L6003:  PUSH    DE
        CALL    FCMP_LE
        JR      L5FDD
RUN_EQ: EX      AF,AF'
        EXX
        JR      C,L6023
        JR      NZ,L601D
        INC     HL
        INC     DE
        PUSH    DE
        CALL    ICMP
L6015:  POP     HL
        LD      A,01h
        JR      Z,L5FCA
        XOR     A
        JR      L5FCA
L601D:  PUSH    DE
        CALL    BCMP
        JR      L6015
L6023:  PUSH    DE
        CALL    FCMP_EQ
        JR      L5FDD

;  RUN_DIV – DIV (ganzzahlig).
RUN_DIV:
        EXX
        PUSH    DE
        CALL    IDIV
L602E:  LD      A,01h
L6030:  POP     HL
        DEC     HL
        LD      (RT_SP),HL
        LD      (HL),A
        JP      L5C81

;  RUN_MOD – MOD.
RUN_MOD:
        EXX
        PUSH    DE
        CALL    IMOD
        JR      L602E

;  RUN_MUL – * auf dem Laufzeitstapel.
RUN_MUL:
        EX      AF,AF'
        EXX
        PUSH    DE
        CP      01h
        JR      NZ,L604C
        CALL    IMUL
        JR      L602E
L604C:  CALL    FMUL
        LD      A,00h
        JR      L6030

;  RUN_RDIV – / (Ergebnis REAL).
RUN_RDIV:
        EXX
        PUSH    DE
        CALL    FDIV
        LD      A,00h
        JR      L6030

;  IDIV – INTEGER-Division (DIV); Division durch 0 -> ERR_13.
; <- aufgerufen von 602Bh
IDIV:   CALL    ISIGNS
        PUSH    AF
        CALL    UDIV16
        POP     AF
        RLA
        CALL    C,NEG_BC
        LD      A,B
        OR      C
        JR      NZ,L606F
        LD      (SM_ISIGN+1),A
L606F:  CALL    RT_STORE_BC
        JR      L6089

;  IMOD – INTEGER-Rest (MOD).
; <- aufgerufen von 603Bh
IMOD:   CALL    ISIGNS
        CALL    UDIV16
        LD      B,H
        LD      C,L
        CALL    C,NEG_BC
        CALL    RT_STORE_BC
        RET

;  IMUL – INTEGER-Multiplikation (DE) * (HL) mit Vorzeichen; Überlauf ->
;  ERR_13.
; <- aufgerufen von 3F70h, 3FBDh, 596Bh, 6047h
IMUL:   CALL    ISIGNS
        CALL    UMUL16
L6089:  LD      A,(SM_ISIGN+1)
        XOR     B
        JP      M,ERR_13
        RET
L6091:  LD      B,D
        LD      C,E
L6093:  LD      (SM_ISIGN+1),A
        JR      RT_STORE_BC

;  ISIGNS – Vorzeichen beider Operanden verknüpfen (Operand bei L60C1).
; <- aufgerufen von 605Ch, 6074h, 6083h
ISIGNS: INC     DE
        INC     HL
        LD      A,(DE)
        XOR     (HL)
        LD      (SM_ISIGN+1),A
        RET

;  UMUL16 – Vorzeichenlose 16-Bit-Multiplikation (Schieben und Addieren).
; <- aufgerufen von 6086h
UMUL16: CALL    IGETOPS
        LD      A,B
        OR      C
        JR      Z,L6093
        LD      A,D
        OR      E
        JR      Z,L6091
        CALL    RR_BC
        LD      A,0Fh
L60B0:  LD      (SM_MUL_CNT+1),A
        CALL    UMUL_STEP

;  SM_MUL_CNT – Operand: Schleifenzähler der Multiplikation.
SM_MUL_CNT:
        LD      A,00h                   ; Operand wird zur Laufzeit gesetzt
        DEC     A
        JR      NZ,L60B0
        CALL    NEG_DE
        CALL    UMUL_STEP

;  SM_ISIGN – Operand: Vorzeichen des Ergebnisses (XOR der Operanden).
SM_ISIGN:
        LD      A,00h                   ; Operand wird zur Laufzeit gesetzt
        OR      A
        JP      P,L60C8
        INC     HL
L60C8:  LD      A,H
        OR      L
        JP      NZ,ERR_13

;  RT_STORE_BC – Ergebnis BC in den Stapeleintrag schreiben.
; <- aufgerufen von 606Fh, 607Fh
RT_STORE_BC:
        PUSH    BC
        EXX
        POP     BC
        EX      DE,HL
        LD      (HL),B
        DEC     HL
        LD      (HL),C
        DEC     DE
        EX      DE,HL
        RET

;  UMUL_STEP – Ein Schritt der Multiplikation (Schieben/Addieren).
; <- aufgerufen von 60B3h, 60BEh
UMUL_STEP:
        LD      A,H
        INC     A
        DEC     A
        JR      NC,L60DE
        XOR     D
        ADD     HL,DE
L60DE:  JP      P,L60E2
        CCF
L60E2:  RR      H
        RR      L

;  RR_BC – BC eine Stelle nach rechts schieben.
; <- aufgerufen von 60ABh
RR_BC:  RR      B
        RR      C
        RET

;  NEG_DE – DE = -DE.
; <- aufgerufen von 2589h, 2F7Ah, 5B88h, 60BBh, 60FDh
NEG_DE: LD      A,D

;  CPL_A_DE – DE = -(A:E) (Einsprung in NEG_DE mit A = D).
; <- aufgerufen von 2F2Ah
CPL_A_DE:
        CPL
        LD      D,A
        LD      A,E
        CPL
        LD      E,A
        INC     DE
        RET

;  UDIV16 – Vorzeichenlose 16-Bit-Division; Divisor 0 -> ERR_13.
; <- aufgerufen von 6060h, 6077h
UDIV16: CALL    IGETOPS
        LD      A,E
        OR      D
        JP      Z,ERR_13
        LD      A,D
        RLA
        CALL    NC,NEG_DE
        LD      A,B
        RLA
        PUSH    AF
        CALL    C,NEG_BC
        RL      C
        RL      B
        RL      L
        RL      H
        AND     A
        LD      A,0Fh
L6111:  LD      (SM_DIV_CNT+1),A
        RL      C
        RL      B
        RL      L
        RL      H
        PUSH    HL
        ADD     HL,DE
        LD      A,H
        XOR     D
        RLCA
        JR      NC,L6124
        EX      (SP),HL
L6124:  POP     HL

;  SM_DIV_CNT – Operand: Schleifenzähler der Division.
SM_DIV_CNT:
        LD      A,00h                   ; Operand wird zur Laufzeit gesetzt
        DEC     A
        JR      NZ,L6111
        RL      C
        RL      B
        POP     AF
        RET

;  IGETOPS – Operanden: BC = (DE), DE = (HL) im Zweitregistersatz, HL = 0.
; <- aufgerufen von 60A0h, 60F3h
IGETOPS:
        PUSH    HL
        PUSH    DE
        EXX
        POP     HL
        LD      B,(HL)
        DEC     HL
        LD      C,(HL)
        POP     HL
        LD      D,(HL)
        DEC     HL
        LD      E,(HL)
        LD      HL,0000h
        RET

;  NEG_BC – BC = -BC.
; <- aufgerufen von 6065h, 607Ch, 6103h
NEG_BC: LD      A,B
        CPL
        LD      B,A
        LD      A,C
        CPL
        LD      C,A
        INC     BC
        RET
TXT_END:
        DEFB    00h,00h
TXT_PTR:
        DEFB    00h,00h

; ------------------------------------------------------------------------------
;  Ab TXT_START beginnt der Programmtext. Im geladenen Abbild stehen hier
;  noch die Startdaten, die vom ersten Programm überschrieben werden.
;  FKEY_DEF – Vorgaben der Funktionstasten (je mit 0Dh abgeschlossen),
;  von PAS_INIT nach FARE (1200h) kopiert.
; ------------------------------------------------------------------------------
TXT_START:
        DEFB    00h,00h
FKEY_DEF:
        DEFB    "begin ",0Dh
        DEFB    "procedure ",0Dh
        DEFB    "function ",0Dh
        DEFB    3Ah,3Dh,0Dh,"integer;",0Dh
        DEFB    "boolean;",0Dh
        DEFB    "array[",0Dh
        DEFB    "repeat ",0Dh
        DEFB    "while ",0Dh
        DEFB    "end",0Dh
        DEFB    "false",0Dh
        DEFB    "true",0Dh
        DEFB    "downto ",0Dh
        DEFB    "real;",0Dh
        DEFB    "char;",0Dh
        DEFB    "float(",0Dh
        DEFB    "trunc(",0Dh
        DEFB    "until ",0Dh
        DEFB    "then ",0Dh
        DEFB    "else ",0Dh
        DEFB    00h

;  PAS_INIT – FKEY_DEF nach FARE kopieren, GOOUT (00AEh) zu "LD BC,12FDh"
;  machen (Opcode 01h) und nach PAS_START.
PAS_INIT:
        LD      DE,FKTAB
        LD      HL,FKEY_DEF
        XOR     A
L61E0:  LDI
        CP      (HL)
        JR      NZ,L61E0
        LD      HL,GOOUT
        LD      (HL),01h
        JP      PAS_START

        END

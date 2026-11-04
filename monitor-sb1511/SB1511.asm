;==============================================================================
;  SHARP MZ-80B  –  Monitor SB-1511 (laut MONEQU auch für SB-1521)
;==============================================================================
;  Quelle : Datei "SB-1511" (FDOS-Typ 05h = RB, verschiebbarer Objektcode)
;           von DISK29.DSK (FDOS SB-7010), 1DB0h Bytes, Datum 10.05.81.
;           Die RB-Sätze legen den Code absolut ab 0000h ab (ORG 0000h).
;           Länge des Monitors: 12A0h Bytes (FKMAX).
;
;  Reassemblierbar mit pasmo; ergibt das Binärabbild SB-1511 (12A0h Bytes).
;  Die Bereiche, die die RB-Datei nicht vorbelegt (105Fh, 10FEh, 1198h),
;  stehen hier als DEFS mit 00h.
;
;  Namen
;  -----
;  Sharps Originalnamen aus der RB-Datei bzw. MONEQU.ASC ("EQU table of
;  MZ-80B monitor SB-1511/SB-1521") sind die EQUs ab _PUSHR sowie diese
;  Labels:
;    SCROST SCREND REPTCT SLOW GATESI SELO0 GOOUT ST .HL LOAMES FOUMES
;    WRINF WRDAT RDINF RDDAT VERFY OPEN SERSP MSTOP BLK1 FFWD HIGHSC TSPE
;    DEL1M BRKEY BRK KBSET PRTHL PRTHX ASC HEX HLHEX _2HEX ?CLER ?DINT
;    SETMES GETKY PRNTS PRNT ?DSP PRNTT NLMSG MSGX MSG SCRSET KEYKEY
;    NOKKEY ?DPCT NL LETNL DELLN ??TOL ??EOL MAGA ?PONT DSPRED DSPW CHR80
;    CHR40 XTEMP TIMST TIMRD BELL MELDY RYTHM RYTHMB KNUMBS GETL GETCRT
;    ??KEY TENTBL CHANGE ?SWAP PUSHR PUSHR2 DI_ KINT PUSHKI KINTON ..KEY
;    TABDAT MODE DSPXY DSPXY1 MANG FKAE KYBDA KSTD KINTF BUFER IBUFE IBU1
;    IBU18 DTADR EXADR IBU24
;  Angepasst wurden nur:
;    2HEX -> _2HEX   (Labels dürfen nicht mit einer Ziffer beginnen)
;    DI   -> DI_     (Kollision mit dem Befehl DI)
;  Alle übrigen Namen stammen aus der Analyse; die Namen der Teilroutinen
;  folgen, wo der Code gleich ist, dem SB-1510 in SB6511_RS232.asm.
;  Feste Adressen im Code (Meldungen, Notentabellen, Variablen in den
;  Lücken der RST-Vektoren) sind durch diese Namen ersetzt.
;  Z80KT, CH3979 und CH4080 bezeichnen Operanden einzelner Befehle, die
;  zur Laufzeit geändert werden (Zeitkonstante, 40/80-Zeichen-Werte).
;
;  Unterschiede zum SB-1510 (im Disk-BASIC SB-6511)
;  ------------------------------------------------
;  - Komplett neu angeordnet: nur wenige Routinen haben identischen Code.
;  - RST 20h = PUSHR (Register retten, beim RET automatisch zurückholen),
;    RST 28h = DI_ (Rest der Routine mit gesperrten Interrupts ausführen,
;    danach EI, sofern sie vorher frei waren). Fast alle Routinen beginnen
;    mit RST 20h / RST 28h.
;  - IM 1 statt IM 2. RST 08h-38h, NMI zeigen auf 09A5h: Registeranzeige
;    und zurück in die Kommandoschleife.
;  - Tastatur-Interrupt über PIO Port B (KINT/KINTON/PUSHKI, Flag KINTF).
;  - Meldungen in Kleinbuchstaben ("Loading", "Set tape" ...).
;  - Funktionstasten-Bereich FARE ab 1200h (FAREN = A0h Bytes, FKEYN = 20).
;  - Kommandos wie beim SB-1510: J, M, D, L, S, V mit Prompt "*".
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
GOOUT:  JP      ST
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
        DEFS    97,00h                  ; 97 Bytes Füllung

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
        DEFS    2,00h                   ; 2 Bytes Füllung
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
IBU24:  DEFS    104,00h                 ; 104 Bytes Füllung

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

        END

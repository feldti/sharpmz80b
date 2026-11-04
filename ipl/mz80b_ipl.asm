;==============================================================================
;  SHARP MZ-80B  –  IPL-ROM (Initial Program Loader), 2 KByte, 0000h-07FFh
;==============================================================================
;  Kommentiertes Disassembly des Boot-ROMs "IPL.rom" (2048 Bytes,
;  davon 0000h-061Fh belegt, Rest mit FFh gefüllt).
;
;  Reassemblierbar mit pasmo, ergibt ein bytegleiches Image. z88dk-z80asm
;  liefert dasselbe, wenn man die letzte Zeile (END) entfernt.
;
;  Funktion im Überblick
;  ---------------------
;  Nach dem Einschalten (bzw. "IPL RESET") blendet die Hardware dieses
;  ROM bei 0000h ein. Der 64-KByte-RAM ist dann so gemappt, dass die
;  unteren 32 KByte physikalischen RAMs bei 8000h-FFFFh liegen. Das IPL
;  lädt das Betriebssystem/BASIC von
;     - Kassette (CMT, eingebautes Laufwerk),
;     - Diskette  (MB8876-FDC, Ports D8h-DDh), oder
;     - einer externen Speicherkarte an Port F8h/F9h
;  nach 8000h (= physikalisch 0000h) und löst dann über PC1 des 8255 einen
;  "Normal Start" (NST) aus: das ROM wird ausgeblendet, die CPU zurückgesetzt
;  und das geladene Programm startet bei 0000h im RAM.
;
;  Boot-Auswahl beim Einschalten (Tastatur, Zeile 4):
;     Taste C gedrückt   -> Kassette
;     Taste / gedrückt   -> externe Speicherkarte (F8h/F9h)
;     sonst              -> Diskette, falls FDC vorhanden, sonst Kassette
;
;  Hardware-Belegung (Quelle: MAME-Treiber sharp/mz2000.cpp, Verhalten
;  im Code; Unsicheres ist im Text als "vermutlich" markiert)
;------------------------------------------------------------------------------

; --- 8255 PPI ---------------------------------------------------------------
PPI_A   EQU     0E0h    ; Port A (Ausgang): Kassettensteuerung, flankengetriggert 0->1
                        ;   Bit0 REW   Bit1 FF    Bit2 PLAY  Bit3 STOP
                        ;   Bit4 1 = normale (nicht inverse) Darstellung
                        ;   Bit5 AREW  Bit6 APLAY Bit7 APSS
PPI_B   EQU     0E1h    ; Port B (Eingang):
                        ;   Bit0 /VBLANK  Bit3 Bandende  Bit4 kein Schreibsignal
                        ;   Bit5 1 = Kassette nicht bereit (kein Band / nicht in PLAY)
                        ;   Bit6 Lesedaten vom Band
                        ;   Bit7 BREAK-Taste (0 = gedrückt)
PPI_C   EQU     0E2h    ; Port C (Ausgang):
                        ;   Bit0 Video-Gate  Bit1 0->1 = NST (RAM-Start, CPU-Reset)
                        ;   Bit2 Piezo/DAC   Bit3 1->0 = IPL-Reset
                        ;   Bit4 Kassettenfach öffnen (Eject, Impuls)
                        ;   Bit5 Kassette (Funktion unklar, wird vor PLAY/REW gepulst)
                        ;   Bit6 REC         Bit7 Schreibdaten Band
PPI_CTL EQU     0E3h    ; Steuerwort / Bit-Set-Reset für Port C

; --- Z80 PIO ----------------------------------------------------------------
PIO_AD  EQU     0E8h    ; Port A Daten (Ausgang):
                        ;   Bit0-3 Tastaturzeile, Bit4 Zeilen-Strobe
                        ;   Bit5 1 = 80 Zeichen/Zeile, 0 = 40 Zeichen
                        ;   Bit6 VRAM-Lage: 0 = D000h-FFFFh, 1 = 5000h-7FFFh
                        ;   Bit7 1 = VRAM in den Adressraum einblenden
PIO_AC  EQU     0E9h    ; Port A Control
PIO_BD  EQU     0EAh    ; Port B Daten (Eingang): Tastaturspalten, 0 = gedrückt
PIO_BC  EQU     0EBh    ; Port B Control

; --- Floppy: MB8876 (WD1791-kompatibel, invertierter Datenbus!) -------------
FDC_CMD EQU     0D8h    ; schreiben: Kommando / lesen: Status   (alles invertiert)
FDC_TRK EQU     0D9h    ; Spurregister
FDC_SEC EQU     0DAh    ; Sektorregister
FDC_DAT EQU     0DBh    ; Datenregister
FDD_SEL EQU     0DCh    ; Bit0-1 Laufwerk, Bit2 Laufwerkswahl aktiv, Bit7 Motor an
FDD_SID EQU     0DDh    ; Seitenwahl

; --- Sonstiges --------------------------------------------------------------
GRPH    EQU     0F4h    ; Grafik-VRAM: Bank / Anzeige-Maske
EXT_AH  EQU     0F8h    ; externe Speicherkarte: Adresse High (schreiben)
EXT_AL  EQU     0F9h    ; externe Speicherkarte: Adresse Low (schreiben) / Daten (lesen)
                        ; (laut MAME F8h-FAh = MZ-1R12, batteriegepufferte CMOS-RAM-Karte)

; --- Speicher ---------------------------------------------------------------
LOADADR EQU     8000h   ; Ladeadresse (= physikalisch 0000h nach dem NST)
HDRBUF  EQU     0CF00h  ; Puffer für Kassetten-Header / Disketten-Bootsektor
H_ATTR  EQU     0CF00h  ;   CMT: Dateiattribut (01h = Maschinenprogramm)
H_NAME  EQU     0CF01h  ;   CMT: Dateiname (17 Byte, angezeigt werden 16)
H_SIZE  EQU     0CF12h  ;   CMT: Programmlänge
D_NAME  EQU     0CF07h  ;   FD : Name hinter der Kennung 01h,"IPLPRO"
D_SIZE  EQU     0CF14h  ;   FD : Programmlänge in Bytes
D_START EQU     0CF1Eh  ;   FD : logische Startsektornummer
TVRAM   EQU     0D000h  ; Text-VRAM (wenn PIO-A Bit7=1, Bit6=0)

; --- Variablen oberhalb des Stacks (Stack wächst ab FFE0h abwärts) ----------
V_CHK   EQU     0FFE0h  ; CMT: Prüfsumme (Anzahl 1-Bits, 16 Bit)
                        ; FD : Parameterblock, über IY adressiert:
                        ;   IY+0 aktuelle log. Spur   IY+1 aktueller Sektor
                        ;   IY+2/3 Byteanzahl         IY+4 Startspur  IY+5 Startsektor
V_TMARK EQU     0FFE2h  ; CMT: Soll-Längen der Bandmarke (H = lang, L = kurz)
V_MOTOR EQU     0FFE6h  ; FD : 1 = Motor läuft bereits
V_RECAL EQU     0FFE7h  ; FD : 4 Flags, je Laufwerk "Restore bereits erfolgt"
V_RETRY EQU     0FFEBh  ; FD : Wiederholungszähler
V_DRIVE EQU     0FFECh  ; FD : Laufwerksnummer 0-3

        ORG     0000h

;==============================================================================
;  Einsprung nach Reset
;==============================================================================
RESET:  JR      INIT            ; Reset-Einsprung: NST-Befehl überspringen

;------------------------------------------------------------------------------
;  START_RAM – geladenes Programm starten.
;  PC1 := 1 (0->1-Flanke) löst den "Normal Start" aus: IPL-ROM wird
;  ausgeblendet, RAM liegt ab 0000h, die CPU wird zurückgesetzt und
;  beginnt bei 0000h mit dem gerade nach 8000h geladenen Programm.
;------------------------------------------------------------------------------
START_RAM:
        LD      A,03h           ; Bit-Set: PC1 = 1
        OUT     (PPI_CTL),A

;------------------------------------------------------------------------------
;  Hardware initialisieren
;------------------------------------------------------------------------------
INIT:   LD      A,82h           ; 8255: Mode 0, A = Ausgang, B = Eingang, C = Ausgang
        OUT     (PPI_CTL),A
        LD      A,0Fh           ; PIO Port A: Mode 0 (Ausgabe)
        OUT     (PIO_AC),A
        LD      A,0CFh          ; PIO Port B: Mode 3 (Bit-Modus) ...
        OUT     (PIO_BC),A
        LD      A,0FFh          ; ... alle 8 Bits als Eingang
        OUT     (PIO_BC),A
        LD      A,58h           ; Port C = 0101 1000b: PC3 (IPL) = 1, PC4 (Eject) = 1,
        OUT     (PPI_C),A       ;   PC6 (REC) = 1 -> alle inaktiv, PC1 (NST) = 0
        LD      A,12h           ; Port A = 0001 0010b: normale Darstellung,
        OUT     (PPI_A),A       ;   Kassetten-Ruhezustand
        XOR     A
        OUT     (GRPH),A        ; Grafikanzeige aus
        LD      SP,0FFE0h       ; Stack unterhalb der Variablen

; RAM D000h-FFFFh löschen. Dazu VRAM nach 5000h-7FFFh verlegen, damit hier
; der normale Arbeitsspeicher (Variablen, Stack, Header-Puffer) erreicht wird.
        LD      HL,0D000h
        LD      A,0B3h          ; PIO A: VRAM ein, Lage 5000h, 80 Zeichen, Zeile 3
        OUT     (PIO_AD),A
CLRRAM: LD      (HL),00h
        INC     HL
        LD      A,H
        OR      L
        JR      NZ,CLRRAM       ; bis HL über FFFFh nach 0000h läuft
        LD      A,13h           ; PIO A: VRAM aus, 40 Zeichen, Strobe + Zeile 3 (BREAK)
        OUT     (PIO_AD),A
        XOR     A
        LD      (V_DRIVE),A     ; Laufwerk 1 (=0) als Vorgabe
        LD      (V_MOTOR),A     ; Floppymotor gilt als aus

;------------------------------------------------------------------------------
;  Boot-Medium wählen (Tastaturzeile 4: Bit0 = "/", Bit3 = "C")
;------------------------------------------------------------------------------
        CALL    KEYROW4
        BIT     3,A             ; Taste C gedrückt?
        JR      Z,BOOT_CMT      ;   ja -> Kassette erzwingen
        BIT     0,A             ; Taste / gedrückt?
        JP      Z,BOOT_EXT      ;   ja -> externe Speicherkarte F8h/F9h
        JR      BOOT_AUTO       ; sonst: Floppy, wenn vorhanden

;------------------------------------------------------------------------------
;  KEYROW4 / KEYROW – eine Tastaturzeile lesen
;  KEYROW4: Zeile 4 mit Strobe (14h).  KEYROW: Zeilencode in B.
;  Rückgabe: A = Spaltenbits (0 = Taste gedrückt)
;  Die oberen 4 Bits von PIO-A (VRAM-/Breiten-Steuerung) bleiben erhalten.
;------------------------------------------------------------------------------
KEYROW4:
        LD      B,14h           ; Strobe (Bit4) + Zeile 4
KEYROW: IN      A,(PIO_AD)      ; aktuellen PIO-A-Zustand zurücklesen
        AND     0F0h
        OR      B               ; Zeilennummer einsetzen
        OUT     (PIO_AD),A
        IN      A,(PIO_BD)      ; Spalten einlesen
        RET

;------------------------------------------------------------------------------
;  BOOT_AUTO – Floppy-Boot, wenn ein FDC gefunden wird, sonst Kassette
;------------------------------------------------------------------------------
BOOT_AUTO:
        CALL    FDCTEST
        JP      Z,BOOT_FD       ; FDC vorhanden -> von Diskette booten
        JR      BOOT_CMT        ; sonst Kassette

;------------------------------------------------------------------------------
;  FDCTEST – Ist ein Floppy-Controller vorhanden?
;  Schreibt A5h ins Spurregister und liest es zurück.  Z = FDC vorhanden.
;------------------------------------------------------------------------------
FDCTEST:
        LD      A,0A5h
        LD      B,A
        OUT     (FDC_TRK),A
        CALL    DLY_85US
        IN      A,(FDC_TRK)
        CP      B
        RET

;==============================================================================
;  BOOT_CMT – Laden von Kassette
;==============================================================================
BOOT_CMT:
        CALL    CMT_STOP        ; Laufwerk in definierten Zustand (STOP)
        CALL    DLY_240MS
        CALL    MSG_LOOK        ; "IPL is looking for a program"
        CALL    CMT_RDHDR       ; Header (128 Byte) nach CF00h lesen
        JR      C,CMT_DONE      ; Fehler / BREAK
        CALL    MSG_LOAD        ; "IPL is loading" ...
        LD      HL,H_NAME       ; ... + Dateiname (16 Zeichen) dahinter
        LD      E,10h           ;     Spalte 16, Zeile 0
        LD      C,10h
        CALL    PRINT
        LD      A,(H_ATTR)
        CP      01h             ; Attribut 01h = Maschinenprogramm?
        JR      NZ,CMT_MODEERR
        CALL    CMT_RDDATA      ; Programm nach 8000h laden
CMT_DONE:
        PUSH    AF              ; Ergebnis (Carry = Fehler) sichern
        CALL    DLY_240MS
        CALL    CMT_REWIND      ; Band zurückspulen
        POP     AF
        JP      C,MENU          ; Fehler -> Auswahlmenü
        JP      START_RAM       ; OK -> Programm starten

CMT_MODEERR:
        LD      HL,M_MODEERR    ; "File mode error"
        LD      E,0Ah
        LD      C,0Fh
        CALL    CLSPRINT
        CALL    CMT_STOP
        SCF
        JR      CMT_DONE

;------------------------------------------------------------------------------
;  CMT_RDHDR – Header-Block von Band lesen
;  D Bit3 = 0 kennzeichnet "Header" (lange Bandmarke, Motor läuft weiter)
;  CMT_RDBLK – gemeinsamer Teil; Eingang HL = Ziel, BC = Länge, D = Typ
;  Rückgabe: Carry = Fehler oder BREAK
;------------------------------------------------------------------------------
CMT_RDHDR:
        DI
        LD      D,04h           ; Typ: Header
        LD      BC,0080h        ; 128 Bytes
        LD      HL,HDRBUF
CMT_RDBLK:
        CALL    CMT_READY       ; Kassette bereit machen, PLAY
        JR      C,CMT_RDEND
        CALL    CMT_TMARK       ; auf Bandmarke synchronisieren
        JR      C,CMT_RDEND
        CALL    CMT_BLOCK       ; Datenblock + Prüfsumme lesen
        JR      C,CMT_RDEND
        BIT     3,D             ; Header?
        JR      Z,CMT_RDRET     ;   ja: Band weiterlaufen lassen
CMT_RDEND:
        CALL    CMT_STOP        ; Daten fertig oder Fehler: Band anhalten
CMT_RDRET:
        EI
        RET

;------------------------------------------------------------------------------
;  CMT_RDDATA – Programmblock lesen: Länge aus Header, Ziel 8000h
;------------------------------------------------------------------------------
CMT_RDDATA:
        DI
        LD      D,08h           ; Typ: Daten (kurze Bandmarke)
        LD      BC,(H_SIZE)
        LD      HL,LOADADR
        JR      CMT_RDBLK

;------------------------------------------------------------------------------
;  CMT_BLOCK – BC Bytes nach (HL) lesen, danach 2 Byte Prüfsumme (High zuerst).
;  Die Prüfsumme ist die Anzahl der 1-Bits.  Jeder Block steht zweimal auf
;  dem Band; bei Prüfsummenfehler wird die zweite Kopie gelesen.
;  Rückgabe: Carry = Fehler (BREAK oder beide Kopien defekt)
;------------------------------------------------------------------------------
CMT_BLOCK:
        PUSH    DE
        PUSH    BC
        PUSH    HL
        LD      H,02h           ; 2 Versuche (Original + Kopie)
BLK_SYNC:
        CALL    CMT_BIT         ; auf das erste lange Bit (Blockbeginn) warten
        JR      C,BLK_EXIT
        JR      Z,BLK_SYNC      ; kurze Bits (Lücke) überlesen
        LD      D,H             ; D = verbleibende Versuche
        LD      HL,0000h
        LD      (V_CHK),HL      ; Prüfsumme löschen
        POP     HL              ; Ziel und Länge neu holen
        POP     BC
        PUSH    BC
        PUSH    HL
BLK_LOOP:
        CALL    CMT_BYTE
        JR      C,BLK_EXIT
        LD      (HL),A
        INC     HL
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,BLK_LOOP
        LD      HL,(V_CHK)      ; berechnete Prüfsumme
        CALL    CMT_BYTE        ; Prüfsumme vom Band, High-Byte
        JR      C,BLK_EXIT
        LD      E,A
        CALL    CMT_BYTE        ; Low-Byte
        JR      C,BLK_EXIT
        CP      L
        JR      NZ,BLK_BAD
        LD      A,E
        CP      H
        JR      Z,BLK_EXIT      ; stimmt (Z => Carry = 0) -> fertig
BLK_BAD:
        DEC     D               ; noch eine Kopie?
        JR      Z,BLK_ERR
        LD      H,D
        JR      BLK_SYNC        ; zweite Kopie lesen
BLK_ERR:
        CALL    MSG_LDERR       ; "Loading error"
        SCF
BLK_EXIT:
        POP     HL
        POP     BC
        POP     DE
        RET

;------------------------------------------------------------------------------
;  CMT_EDGE – auf steigende Flanke des Bandsignals warten (PPI-B Bit6).
;  Fragt dabei BREAK ab (PPI-B Bit7): Rückgabe Carry = BREAK gedrückt.
;------------------------------------------------------------------------------
CMT_EDGE:
        IN      A,(PPI_B)
        CPL
        RLCA                    ; Carry = BREAK gedrückt
        RET     C
        RLCA                    ; Carry = Bandsignal low
        JR      NC,CMT_EDGE     ; warten, solange Signal high ist
EDGE_LO:
        IN      A,(PPI_B)
        CPL
        RLCA
        RET     C               ; BREAK
        RLCA
        JR      C,EDGE_LO       ; warten, solange Signal low ist
        RET                     ; steigende Flanke erkannt, Carry = 0

;------------------------------------------------------------------------------
;  CMT_BYTE – ein Byte (8 Bit, MSB zuerst) lesen; 1-Bits zählen in V_CHK.
;  Danach wird das folgende Trennbit durch Warten auf die nächste Flanke
;  übersprungen.  Rückgabe: A = Byte, Carry = BREAK
;------------------------------------------------------------------------------
CMT_BYTE:
        PUSH    HL
        LD      HL,0800h        ; H = 8 Bits, L = Schieberegister
BYTE_LP:
        CALL    CMT_BIT
        JR      C,BYTE_EXIT     ; BREAK
        JR      Z,BYTE_SH       ; 0-Bit (Carry ist 0)
        PUSH    HL              ; 1-Bit: Prüfsumme erhöhen
        LD      HL,(V_CHK)
        INC     HL
        LD      (V_CHK),HL
        POP     HL
        SCF                     ; Carry = 1 einschieben
BYTE_SH:
        RL      L
        DEC     H
        JR      NZ,BYTE_LP
        CALL    CMT_EDGE        ; Trennbit überspringen
        LD      A,L
BYTE_EXIT:
        POP     HL
        RET

;------------------------------------------------------------------------------
;  CMT_TMARK – Bandmarke suchen: H lange Bits gefolgt von L kurzen Bits,
;  danach ein Bit überspringen.  Header: 40 lang/40 kurz, Daten: 20/20.
;  Jede Abweichung startet die Suche neu.  Rückgabe: Carry = BREAK
;------------------------------------------------------------------------------
CMT_TMARK:
        PUSH    HL
        LD      HL,1414h        ; Daten: 20 lange + 20 kurze Bits
        BIT     3,D
        JR      NZ,TM_SET
        ADD     HL,HL           ; Header: 40 + 40 (2828h)
TM_SET: LD      (V_TMARK),HL
TM_RST: LD      HL,(V_TMARK)    ; Zähler neu laden
TM_LONG:
        CALL    CMT_BIT
        JR      C,BYTE_EXIT     ; BREAK (gemeinsames POP HL / RET)
        JR      Z,TM_RST        ; kurzes Bit -> von vorn
        DEC     H
        JR      NZ,TM_LONG      ; bis H lange Bits in Folge
TM_SHORT:
        CALL    CMT_BIT
        JR      C,BYTE_EXIT
        JR      NZ,TM_RST       ; langes Bit -> von vorn
        DEC     L
        JR      NZ,TM_SHORT     ; bis L kurze Bits in Folge
        CALL    CMT_EDGE        ; Abschlussbit überspringen
        JR      BYTE_EXIT

;------------------------------------------------------------------------------
;  CMT_BIT – ein Bit lesen (Pulsbreitenkodierung):
;  auf steigende Flanke warten, ca. 0,18 ms warten, dann Pegel abtasten.
;  Noch high = langer Puls = 1  -> NZ;   schon low = kurzer Puls = 0 -> Z
;  Carry = BREAK.
;------------------------------------------------------------------------------
CMT_BIT:
        CALL    CMT_EDGE
        RET     C
        CALL    DLY_BIT
        IN      A,(PPI_B)
        AND     40h             ; Bandsignal (löscht Carry)
        RET

;------------------------------------------------------------------------------
;  CMT_READY – Kassette bereit machen und PLAY starten.
;  Ist keine Kassette eingelegt (PPI-B Bit5 = 1): Meldung "Make ready CMT",
;  Kassettenfach öffnen und warten, bis eine eingelegt ist (BREAK bricht ab).
;  Rückgabe: Carry = BREAK
;------------------------------------------------------------------------------
CMT_READY:
        PUSH    DE
        PUSH    BC
        PUSH    HL
        IN      A,(PPI_B)
        AND     20h             ; Kassette bereit?
        JR      Z,RDY_PLAY      ;   ja -> gleich abspielen
        LD      HL,M_MKCMT      ; "Make ready CMT"
        LD      E,0Ah
        LD      C,0Eh
        CALL    CLSPRINT
        CALL    CMT_EJECT       ; Kassettenfach öffnen
RDY_WAIT:
        IN      A,(PIO_BD)      ; Tastaturzeile 3 ist noch angewählt
        CPL
        RLCA                    ; Bit7 = BREAK -> Carry
        JR      C,RDY_EXIT      ; BREAK -> Abbruch mit Carry
        IN      A,(PPI_B)
        AND     20h
        JR      NZ,RDY_WAIT     ; warten, bis Kassette eingelegt
        CALL    MSG_LOOK
        CALL    DLY_1600MS      ; Zeit zum Schließen des Fachs
RDY_PLAY:
        CALL    CMT_PLAY
RDY_EXIT:
        POP     HL
        POP     BC
        POP     DE
        RET

;------------------------------------------------------------------------------
;  Kassetten-Motorsteuerung (Impulse auf 8255 Port A / C)
;------------------------------------------------------------------------------
CMT_STOP:                       ; Band anhalten
        LD      A,0Dh           ; Bit-Set PC6 (REC inaktiv)
        OUT     (PPI_CTL),A
        LD      A,1Ah           ; PA3 0->1 = STOP
        OUT     (PPI_A),A
        CALL    DLY_240MS
        JR      PA_IDLE         ; PA wieder auf Ruhewert 12h

CMT_EJECT:                      ; Kassettenfach öffnen: PC4-Impuls 1->0->1
        LD      A,08h           ; Bit-Reset PC4
        OUT     (PPI_CTL),A
        CALL    DLY_240MS
        LD      A,09h           ; Bit-Set PC4
        OUT     (PPI_CTL),A
        RET

MSG_LOOK:                       ; "IPL is looking for a program" (Bild löschen)
        LD      HL,M_LOOK
        LD      E,04h
        LD      C,1Ch
        CALL    CLSPRINT
        RET

CMT_PLAY:                       ; Wiedergabe starten
        CALL    PC5_PULSE
        CALL    DLY_240MS
        LD      A,16h           ; PA2 0->1 = PLAY
        OUT     (PPI_A),A
        JR      PA_IDLE

CMT_REW2:                       ; zweiter Teil von CMT_REWIND
        CALL    DLY_240MS
        CALL    PA_IDLE         ; PA = 12h (PA1 0->1)
        LD      A,13h           ; PA0 0->1 = REW
        OUT     (PPI_A),A
PA_IDLE:
        LD      A,12h           ; Ruhewert Port A
        OUT     (PPI_A),A
        RET

PC5_PULSE:                      ; PA = 12h setzen, dann PC5-Impuls 0->1->0
        LD      A,12h
PC5_PA: OUT     (PPI_A),A
        CALL    DLY_240MS
        LD      A,0Bh           ; Bit-Set PC5
        OUT     (PPI_CTL),A
        CALL    DLY_240MS
        LD      A,0Ah           ; Bit-Reset PC5
        OUT     (PPI_CTL),A
        RET

CMT_PA10:                       ; wie PC5_PULSE, aber PA = 10h (PA1 = 0)
        LD      A,10h
        JR      PC5_PA

;  CMT_REWIND – Band zurückspulen.  Ablauf: PA1 = 0, PC5-Impuls, PA1 = 1,
;  dann PA0-Impuls (REW).  Hinweis: MAME deutet PA1 als FF und PA0 als REW
;  (jeweils 0->1-Flanke); die genaue Wirkung von PA1/PC5 ist nicht sicher.
CMT_REWIND:
        CALL    CMT_PA10
        JR      CMT_REW2

;------------------------------------------------------------------------------
;  Warteschleifen (Z80 @ 4 MHz)
;------------------------------------------------------------------------------
DLY_BC: PUSH    AF              ; BC x ca. 1 ms
DLYB_1: XOR     A
DLYB_2: DEC     A
        JR      NZ,DLYB_2       ; 256 x 16 T
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,DLYB_1
        POP     AF
        POP     BC              ; BC wurde vom Aufrufer-Einsprung gesichert
        RET

DLY_240MS:                      ; ca. 0,24 s
        PUSH    BC
        LD      BC,00E9h
        JR      DLY_BC

DLY_1600MS:                     ; ca. 1,6 s
        PUSH    BC
        LD      BC,060Fh
        JR      DLY_BC

DLY_BIT:                        ; ca. 0,18 ms – Abtastzeitpunkt für ein Bandbit
        LD      A,31h
DLYBIT1:
        DEC     A
        JP      NZ,DLYBIT1
        RET

;------------------------------------------------------------------------------
;  Bildschirmausgabe
;  Text wird direkt ins Text-VRAM bei D000h kopiert (40 Zeichen/Zeile).
;  E = Bildschirmposition (Offset ab D000h), C = Länge, HL = Text.
;  Nach dem LDIR zeigt HL hinter den Text – das nutzt MENU, um mehrere
;  aufeinanderfolgende Texte ohne neues LD HL auszugeben.
;------------------------------------------------------------------------------
MSG_LOAD:                       ; "IPL is loading" links oben, Bild löschen
        LD      HL,M_LOAD
        LD      E,00h
        LD      C,0Eh
        JR      CLSPRINT

PRINT:                          ; ohne Bildschirmlöschen
        LD      A,93h           ; PIO A: VRAM ein (D000h), 40 Zeichen
        OUT     (PIO_AD),A
        JR      PRT_COPY

MSG_LDERR:                      ; "Loading error"
        LD      HL,M_LDERR
        LD      E,0Ah
        LD      C,0Dh

CLSPRINT:                       ; Bild löschen, dann ausgeben
        LD      A,93h           ; VRAM bei D000h einblenden
        OUT     (PIO_AD),A
        EXX
        LD      HL,TVRAM        ; Text- und Grafik-VRAM D000h-FFFFh löschen
CLS_LP: LD      (HL),00h
        INC     HL
        LD      A,H
        OR      L
        JR      NZ,CLS_LP
        EXX
PRT_COPY:
        XOR     A
        LD      B,A             ; BC = Länge (C)
        LD      D,0D0h          ; DE = D000h + Position
        LDIR
        LD      A,13h           ; VRAM wieder ausblenden, Tastaturzeile 3
        OUT     (PIO_AD),A
        RET

;------------------------------------------------------------------------------
;  Meldungstexte (ASCII, ohne Endekennung – Länge steht im Aufruf)
;------------------------------------------------------------------------------
M_LOAD:    DEFM "IPL is loading"                ; 0261h, 14
M_LOOK:    DEFM "IPL is looking for a program"  ; 026Fh, 28
M_MKCMT:   DEFM "Make ready CMT"                ; 028Bh, 14
M_LDERR:   DEFM "Loading error"                 ; 0299h, 13
M_MKFD:    DEFM "Make ready FD"                 ; 02A6h, 13
M_PRESS:   DEFM "Press F or C"                  ; 02B3h, 12  \
M_FLOPPY:  DEFM "F:Floppy diskette"             ; 02BFh, 17   > Menü, am Stück
M_CASS:    DEFM "C:Cassette tape"               ; 02D0h, 15  /
M_DRIVE:   DEFM "Drive No? (1-4)"               ; 02DFh, 15
M_NOMAST:  DEFM "This diskette is not master"   ; 02EEh, 27
M_PRESSS:  DEFM "Pressing S key starts the CMT" ; 0309h, 29
M_MODEERR: DEFM "File mode error"               ; 0326h, 15
IPLID:     DEFB 01h                             ; 0335h  Bootsektor-Kennung:
           DEFM "IPLPRO"                        ;        01h,"IPLPRO" (6 Byte geprüft)

;==============================================================================
;  BOOT_FD – Laden von Diskette (Laufwerk in V_DRIVE)
;  Disk-Format: 16 Sektoren à 256 Byte pro Spur, beidseitig.
;  Logischer Sektor 0 (Spur 0, Seite 0, Sektor 1) ist der Bootsektor:
;     +00h  01h,"IPLPRO"   Kennung
;     +07h  Name (10 Zeichen werden angezeigt)
;     +14h  Länge des Programms in Bytes
;     +1Eh  logischer Startsektor des Programms
;==============================================================================
BOOT_FD:
        LD      IX,HDRBUF       ; Ziel: Bootsektor nach CF00h
        XOR     A
        LD      (D_START),A     ; Startsektor 0
        LD      (D_START+1),A
        LD      IY,V_CHK        ; IY -> Parameterblock FFE0h
        LD      HL,0100h        ; 256 Bytes = 1 Sektor
        LD      (IY+2),L
        LD      (IY+3),H
        CALL    FD_READ
        LD      HL,HDRBUF       ; Kennung prüfen
        LD      DE,IPLID
        LD      B,06h
FD_CMPID:
        LD      C,(HL)
        LD      A,(DE)
        CP      C
        JP      NZ,FD_NOMAST    ; keine Systemdiskette
        INC     HL
        INC     DE
        DJNZ    FD_CMPID
        CALL    MSG_LOAD        ; "IPL is loading" + Name
        LD      HL,D_NAME
        LD      E,10h
        LD      C,0Ah
        CALL    PRINT
        LD      IX,LOADADR      ; Ziel 8000h
        LD      HL,(D_SIZE)     ; Länge aus dem Bootsektor
        LD      (IY+2),L
        LD      (IY+3),H        ; (Startsektor steht schon in CF1Eh)
        CALL    FD_READ
        CALL    FD_OFF          ; Motor aus
        JP      START_RAM       ; Programm starten

FD_NREADY:                      ; Laufwerk wird nicht bereit
        LD      HL,M_MKFD       ; "Make ready FD"
        LD      E,0Ah
        LD      C,0Dh
        CALL    CLSPRINT
        JP      FD_ABORT

;------------------------------------------------------------------------------
;  FD_SELECT – Motor einschalten (falls nötig), Laufwerk wählen, auf READY
;  warten; beim ersten Zugriff auf ein Laufwerk Restore (Spur 0) ausführen.
;------------------------------------------------------------------------------
FD_SELECT:
        LD      A,(V_MOTOR)
        RRCA
        CALL    NC,FD_MOTON     ; Motor noch aus -> einschalten
        LD      A,(V_DRIVE)
        OR      84h             ; Motor an + Laufwerkswahl aktiv + Nummer
        OUT     (FDD_SEL),A
        XOR     A
        CALL    DLY_44MS
        LD      HL,0000h        ; Timeout ca. 0,85 s
SEL_WAIT:
        DEC     HL
        LD      A,H
        OR      L
        JR      Z,FD_NREADY
        IN      A,(FDC_CMD)     ; Status
        CPL                     ; MB8876: invertiert
        RLCA                    ; Bit7 NOT READY -> Carry
        JR      C,SEL_WAIT
        LD      A,(V_DRIVE)     ; Restore schon gemacht?
        LD      C,A
        LD      HL,V_RECAL
        LD      B,00h
        ADD     HL,BC
        BIT     0,(HL)
        RET     NZ
        CALL    FD_RESTORE      ; nein: Kopf auf Spur 0
        SET     0,(HL)
        RET

FD_MOTON:                       ; Motor an, ca. 1 s Hochlaufzeit
        LD      A,80h
        OUT     (FDD_SEL),A
        LD      B,0Ah
MOT_1:  LD      HL,3C19h
MOT_2:  DEC     HL
        LD      A,L
        OR      H
        JR      NZ,MOT_2
        DJNZ    MOT_1
        LD      A,01h
        LD      (V_MOTOR),A
        RET

;  FD_SEEK – Seek auf die Spur im Datenregister.  Rückgabe NZ = Fehler
FD_SEEK:
        LD      A,1Bh           ; SEEK, Kopf laden, Steprate 3
        CPL
        OUT     (FDC_CMD),A
        CALL    FD_WAIT
        CALL    DLY_44MS        ; Kopf-Beruhigungszeit
        IN      A,(FDC_CMD)
        CPL
        AND     99h             ; NOT READY | SEEK ERROR | CRC ERROR | BUSY
        RET

;  FD_OFF – Motor aus, Laufwerkszustände vergessen
FD_OFF: CALL    DLY_850US
        XOR     A
        OUT     (FDD_SEL),A
        LD      (V_RECAL),A
        LD      (V_RECAL+1),A
        LD      (V_RECAL+2),A
        LD      (V_RECAL+3),A
        LD      (V_MOTOR),A
        RET

;  FD_RESTORE – Kopf auf Spur 0; Fehler -> "Loading error"
FD_RESTORE:
        PUSH    HL
        LD      A,0Bh           ; RESTORE, Kopf laden, Steprate 3
        CPL
        OUT     (FDC_CMD),A
        CALL    FD_WAIT
        CALL    DLY_44MS
        IN      A,(FDC_CMD)
        CPL
        AND     85h             ; NOT READY | TRACK 00 | BUSY
        XOR     04h             ; erwartet: nur TRACK 00 gesetzt
        POP     HL
        RET     Z
        JP      FD_ERROR

;  FD_WAIT – warten, bis BUSY = 0 (Timeout ca. 6 s -> FD_ERROR)
FD_WAIT:
        PUSH    DE
        PUSH    HL
        CALL    DLY_85US        ; FDC braucht etwas, bis BUSY gültig ist
        LD      E,07h
FW_1:   LD      HL,0000h
FW_2:   DEC     HL
        LD      A,H
        OR      L
        JR      Z,FW_3
        IN      A,(FDC_CMD)
        CPL
        RRCA                    ; Bit0 BUSY -> Carry
        JR      C,FW_2
        POP     HL
        POP     DE
        RET
FW_3:   DEC     E
        JR      NZ,FW_1
        JP      FD_ERROR

;------------------------------------------------------------------------------
;  FD_CALC – logischen Startsektor (CF1Eh) in Spur/Sektor umrechnen
;  und die Parameter prüfen.
;     IY+4 = Sektor DIV 16  (logische Spur = Zylinder*2 + Seite)
;     IY+5 = Sektor MOD 16 + 1
;  Gültig: Laufwerk < 4, Spur < 70, Sektor 1-16, Länge <> 0
;------------------------------------------------------------------------------
FD_CALC:
        LD      B,00h
        LD      DE,0010h
        LD      HL,(D_START)
        XOR     A               ; Carry löschen
CALC_1: SBC     HL,DE           ; Division durch wiederholte Subtraktion
        JR      C,CALC_2
        INC     B
        JR      CALC_1
CALC_2: ADD     HL,DE           ; Rest wiederherstellen
        LD      H,B
        INC     L               ; Sektoren zählen ab 1
        LD      (IY+4),H
        LD      (IY+5),L
        LD      A,(V_DRIVE)
        CP      04h
        JR      NC,CALC_ERR
        LD      A,(IY+4)
        CP      46h             ; Spur >= 70?
        JR      NC,CALC_ERR
        LD      A,(IY+5)
        OR      A
        JR      Z,CALC_ERR
        CP      11h             ; Sektor > 16?
        JR      NC,CALC_ERR
        LD      A,(IY+2)
        OR      (IY+3)
        RET     NZ              ; Länge <> 0 -> OK
CALC_ERR:
        JP      FD_ERROR

;------------------------------------------------------------------------------
;  FD_READ – (IY+2/3) Bytes ab logischem Sektor (CF1Eh) nach (IX) lesen.
;  Liest pro Spur mit "Read Sector, multiple" ab dem Startsektor bis zum
;  Spurende (Sektor 16) bzw. bis die Anzahl erreicht ist, dann nächste Spur.
;  Bis zu 10 Versuche, danach "Loading error".
;------------------------------------------------------------------------------
FD_READ:
        DI
        CALL    FD_CALC
        LD      A,0Ah
        LD      (V_RETRY),A     ; 10 Versuche
FD_RETRY:
        CALL    FD_SELECT
        LD      D,(IY+3)        ; D = Anzahl Sektoren = Länge/256, aufgerundet
        LD      A,(IY+2)
        OR      A
        JR      Z,FR_1
        INC     D
FR_1:   LD      A,(IY+5)        ; Arbeitskopie Sektor
        LD      (IY+1),A
        LD      A,(IY+4)        ; Arbeitskopie Spur
        LD      (IY+0),A
        PUSH    IX
        POP     HL              ; HL = Zieladresse
FR_TRACK:                       ; --- eine Spur lesen, A = logische Spur ---
        SRL     A               ; A = Zylinder, Carry = Seite
        CPL
        OUT     (FDC_DAT),A     ; Zielspur ins Datenregister (für SEEK)
        JR      NC,FR_SIDE0
        LD      A,01h
        JR      FR_SIDE
FR_SIDE0:
        LD      A,00h
FR_SIDE:
        CPL
        OUT     (FDD_SID),A     ; Seite wählen
        CALL    FD_SEEK
        JR      NZ,FR_FAIL
        LD      C,FDC_DAT       ; für INI
        LD      A,(IY+0)
        SRL     A
        CPL
        OUT     (FDC_TRK),A     ; Spurregister = Zylinder
        LD      A,(IY+1)
        CPL
        OUT     (FDC_SEC),A     ; Startsektor
        EXX
        LD      HL,FR_END       ; "Rücksprungadresse" für das Ende der
        PUSH    HL              ;   Übertragung (BUSY fällt ab) auf den Stack
        EXX
        LD      A,94h           ; READ SECTOR, multiple, 15 ms Kopfladeverzögerung
        CPL
        OUT     (FDC_CMD),A
        CALL    FD_WAITBSY      ; warten, bis FDC BUSY meldet
FR_SECT:
        LD      B,00h           ; 256 Bytes pro Sektor
FR_BYTE:
        IN      A,(FDC_CMD)     ; Status (Achtung: hier NICHT invertiert gelesen,
        RRCA                    ;   daher Bit = 0 bedeutet "aktiv")
        RET     C               ; BUSY weg -> Kommando beendet -> FR_END
        RRCA
        JR      C,FR_BYTE       ; kein DRQ -> weiter warten
        INI                     ; Byte holen: (HL) <- (C), HL++, B--
        JR      NZ,FR_BYTE
        INC     (IY+1)          ; nächster Sektor
        LD      A,(IY+1)
        CP      11h             ; über Sektor 16 hinaus?
        JR      Z,FR_EOT
        DEC     D               ; Restsektoren
        JR      NZ,FR_SECT      ; FDC liest im Multi-Modus weiter
        JR      FR_STOP
FR_EOT: DEC     D
FR_STOP:
        LD      A,0D8h          ; FORCE INTERRUPT (sofort)
        CPL
        OUT     (FDC_CMD),A
        CALL    FD_WAIT
FR_END: IN      A,(FDC_CMD)
        CPL
        AND     0FFh            ; irgendein Statusbit gesetzt -> Fehler
        JR      NZ,FR_FAIL
        EXX
        POP     HL              ; nicht benutzte Adresse FR_END vom Stack
        EXX
        LD      A,(IY+1)
        CP      11h             ; Spurende?
        JR      NZ,FR_NEXT
        LD      A,01h           ; ja: Sektor 1 der nächsten logischen Spur
        LD      (IY+1),A
        INC     (IY+0)
FR_NEXT:
        LD      A,D
        OR      A
        JR      NZ,FR_MORE
        LD      A,80h           ; fertig: Laufwerk abwählen, Motor läuft weiter
        OUT     (FDD_SEL),A
        RET
FR_MORE:
        LD      A,(IY+0)
        JR      FR_TRACK

FR_FAIL:                        ; Lesefehler -> Restore und neuer Versuch
        LD      A,(V_RETRY)
        DEC     A
        LD      (V_RETRY),A
        JR      Z,FD_ERROR
        CALL    FD_RESTORE
        JP      FD_RETRY        ; (Hinweis: Ein noch gestapeltes FR_END bleibt
                                ;  liegen – harmlos, SP wird später neu gesetzt)

;  FD_WAITBSY – warten, bis BUSY = 1 (Timeout ca. 7 s -> FD_ERROR)
FD_WAITBSY:
        PUSH    DE
        PUSH    HL
        CALL    DLY_85US
        LD      E,08h
WB_1:   LD      HL,0000h
WB_2:   DEC     HL
        LD      A,H
        OR      L
        JR      Z,WB_3
        IN      A,(FDC_CMD)
        CPL
        RRCA
        JR      NC,WB_2
        POP     HL
        POP     DE
        RET
WB_3:   DEC     E
        JR      NZ,WB_1
        JR      FD_ERROR

;------------------------------------------------------------------------------
;  Fehlerbehandlung Floppy und Auswahlmenü
;------------------------------------------------------------------------------
FD_NOMAST:                      ; Bootsektor ohne Kennung
        LD      HL,M_NOMAST     ; "This diskette is not master"
        LD      E,07h
        LD      C,1Bh
        CALL    CLSPRINT
        JR      FD_ABORT

FD_ERROR:
        CALL    MSG_LDERR       ; "Loading error"
FD_ABORT:
        CALL    FD_OFF
        LD      SP,0FFE0h       ; Stack zurücksetzen (Abbruch aus beliebiger Tiefe)

;  MENU – Benutzer wählt das Boot-Medium
MENU:   CALL    FDCTEST
        JR      NZ,MENU_NOFD    ; kein FDC: nur Kassette anbieten
        LD      HL,M_PRESS      ; "Press F or C"         Zeile 2, Spalte 10
        LD      E,5Ah
        LD      C,0Ch
        CALL    PRINT
        LD      E,0ABh          ; "F:Floppy diskette"    Zeile 4, Spalte 11
        LD      C,11h           ;  (HL zeigt nach LDIR schon auf den Text)
        CALL    PRINT
        LD      E,0D3h          ; "C:Cassette tape"      Zeile 5, Spalte 11
        LD      C,0Fh
        CALL    PRINT
MENU_KEY:
        CALL    KEYROW4
        BIT     3,A             ; C?
        JP      Z,BOOT_CMT
        BIT     6,A             ; F?
        JR      Z,MENU_FD
        JR      MENU_KEY

MENU_FD:
        LD      HL,M_DRIVE      ; "Drive No? (1-4)"
        LD      E,0Ah
        LD      C,0Fh
        CALL    CLSPRINT
DRV_KEY:
        LD      D,12h           ; Zeile 2: Zehnerblock 0-7
        CALL    GETDRV
        JR      NC,DRV_OK
        LD      D,18h           ; Zeile 8: Ziffernreihe 0-7
        CALL    GETDRV
        JR      NC,DRV_OK
        JR      DRV_KEY
DRV_OK: LD      A,B
        LD      (V_DRIVE),A
        JP      BOOT_FD

MENU_NOFD:
        LD      HL,M_PRESSS     ; "Pressing S key starts the CMT", Zeile 2, Sp. 4
        LD      E,54h
        LD      C,1Dh
        CALL    PRINT
        LD      B,06h           ; Zeile 6 (S = Bit3) – ohne Strobe-Bit4!
S_KEY:  CALL    KEYROW          ;  laut MAME wird dann das UND aller Zeilen
        BIT     3,A             ;  gelesen, d.h. auch C, K, S, 3, F4 ... wirken
        JP      Z,BOOT_CMT
        JR      S_KEY

;------------------------------------------------------------------------------
;  GETDRV – Tasten 1-4 der Zeile D abfragen
;  Rückgabe: NC und B = 0-3 bei gedrückter Taste, sonst Carry
;------------------------------------------------------------------------------
GETDRV: IN      A,(PIO_AD)
        AND     0F0h
        OR      D
        OUT     (PIO_AD),A
        IN      A,(PIO_BD)
        LD      B,00h
        LD      C,04h
        RRCA                    ; Bit0 (Taste 0) verwerfen
GD_1:   RRCA                    ; nächstes Bit -> Carry
        RET     NC              ; 0 = gedrückt
        INC     B
        DEC     C
        JR      NZ,GD_1
        RET                     ; keine der Tasten 1-4: Carry

;------------------------------------------------------------------------------
;  Kurze Warteschleifen (DE x 26 T)
;------------------------------------------------------------------------------
DLY_85US:
        PUSH    DE
        LD      DE,000Dh
        JP      DLY_DE
DLY_850US:
        PUSH    DE
        LD      DE,0082h
        JP      DLY_DE
DLY_44MS:
        PUSH    DE
        LD      DE,1A2Ch
DLY_DE: DEC     DE
        LD      A,E
        OR      D
        JR      NZ,DLY_DE
        POP     DE
        RET

;==============================================================================
;  BOOT_EXT – Laden von externer Speicherkarte an Port F8h/F9h
;  Adresse wird über OUT F8h (High) / OUT F9h (Low) gesetzt, das Datenbyte
;  über IN F9h gelesen.  Ist das erste Byte (Adresse 8000h) nicht 00h, gilt
;  die Karte als nicht vorhanden bzw. nicht bootfähig -> Floppy/Kassette.
;  Sonst werden 32 KByte (Adresse 8000h-FFFFh) 1:1 nach 8000h-FFFFh kopiert.
;==============================================================================
BOOT_EXT:
        LD      HL,8000h
        LD      IX,EXT_CHK
        JR      EXT_ADR

EXT_CHK:
        IN      A,(EXT_AL)      ; erstes Byte
        CP      00h
        JP      NZ,BOOT_AUTO    ; keine gültige Karte
        LD      IX,EXT_COPY
EXT_NEXT:
        JR      EXT_ADR
EXT_COPY:
        IN      A,(EXT_AL)      ; Byte von der Karte
        LD      (HL),A          ; ins RAM
        INC     HL
        LD      A,L
        OR      H
        JR      NZ,EXT_NEXT     ; bis HL = 0000h
        OUT     (EXT_AH),A      ; A = 0
        JP      START_RAM

;  EXT_ADR – Adresse HL ausgeben, kurz warten, weiter bei (IX)
EXT_ADR:
        LD      A,H
        OUT     (EXT_AH),A
        LD      A,L
        OUT     (EXT_AL),A
        LD      D,04h
EXT_DLY:
        DEC     D
        JR      NZ,EXT_DLY
        JP      (IX)

        NOP                     ; 061Fh

        DEFS    0800h-$,0FFh    ; Rest des 2-KByte-ROMs unbenutzt

        END

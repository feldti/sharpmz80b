* Sharp MZ 80-B Micro Technology CP/M
* Disassembled on Amstrad PCW using DISX3.COM
* Output compatible with XASM Coss Assembler
		OPT BIN,SYM,NOPAGE
WRMBT:
		EQU	$0000				;\
H001:
		EQU	$0001				; >Warm Boot ($4A03+b = $EE03)
H002:
		EQU	$0002				;/
IOBYTE:
		EQU	$0003				;I/O byte
DSKBYTE:
		EQU	$0004				;DSK byte
ENTRY:
		EQU	$0005				;\
H006:
		EQU	$0006				; >jump to BDOS ($E006)
H007:
		EQU	$0008				;/
H008:
		EQU	$0008				;Restart Vector 1
H009:
		EQU	$0009
H00A:
		EQU	$000A
H00C:
		EQU	$000C
H00D:
		EQU	$000D
H00E:
		EQU	$000E
H010:
		EQU	$0010				;Restart Vector 2
H011:
		EQU	$0011
H010:
		EQU	$0018				;Restart Vector 3
H01E:
		EQU	$001E
H020:
		EQU	$0020				;Restart Vector 4
H021:
		EQU	$0021
H010:
		EQU	$0028				;Restart Vector 5
H02D:
		EQU	$002D
H02E:
		EQU	$002E
H020:
		EQU	$0030				;Restart Vector 6
H036:
		EQU	$0036
H010:
		EQU	$0038				;Restart Vector 7
H040:
		EQU	$0040				;BIOS work area
H048:
		EQU	$0048				;DSPXY
H04D:
		EQU	$004D
TFCB:
		EQU	$005C				;FCB	dr	disk name
H05D:
		EQU	$005D				;FCB+1	f1	filename
H05E:
		EQU	$005E				;	f2
H05D:
		EQU	$005F				;	f3
H05E:
		EQU	$0060				;	f4
H05D:
		EQU	$0061				;	f5
H05E:
		EQU	$0062				;	f6
H05D:
		EQU	$0063				;	f7
H05E:
		EQU	$0064				;	f8
H06C:
		EQU	$0065				;FCB+9	t1	disk file type
H06D:
		EQU	$0066				;	t2
H06C:
		EQU	$0067				;	t3
H06D:
		EQU	$0068				;FCB+12	ex	file's current reel number
H06C:
		EQU	$0069				;	s1
H06D:
		EQU	$006A				;	s2
H06C:
		EQU	$006B				;FCB+15	rc	file's record count (0 to 128)
H06C:
		EQU	$006C				;	d0
H06D:
		EQU	$006D				;	d1
H06C:
		EQU	$006E				;	d2
H06D:
		EQU	$006F				;	d3
H07C:
		EQU	$0070				;	d4
H07C:
		EQU	$0071				;	d5
H07C:
		EQU	$0072				;	d6
H07C:
		EQU	$0073				;	d7
H07C:
		EQU	$0074				;	d8
H07C:
		EQU	$0075				;	d9
H07C:
		EQU	$0076
H07C:
		EQU	$0077
H07C:
		EQU	$0078
H07C:
		EQU	$0079
H07C:
		EQU	$007A
H07C:
		EQU	$007B				;	dn
H07C:
		EQU	$007C				;FCB+32	cr	current (next) record number
H07C:
		EQU	$007D				;FCB+33	r0	fcb length
H07C:
		EQU	$007E				;	r1
H07F:
		EQU	$007F				;	r2
TBUFF:
		EQU	$0080				;DBUFF
H082:
		EQU	$0082
H0CA:
		EQU	$00CA
H0E2:
		EQU	$00E2
H0EF:
		EQU	$00EF
TBASE:
		EQU	$0100				;Start of Program Area
CBASE:
		EQU	$D800				;CCP start address
V000:
		EQU	$E000				;BDOS start address
V006:
		EQU	$E006				;BDOS execute address
VE00:
		EQU	$EE00				;BIOS start address
WC00:
		EQU	$FC00				;OS routines
		ORG   $D800
******************************************************************
*                             CCP                                *
******************************************************************
CBASE:
		JP	COMMAND				;C35CDB		execute command processor (ccp)
U803:
		JP	CLEARBUF				;C358DB		entry to empty input buffer before starting ccp
*	Start of Read Buffer
*	Standard cp/m ccp input buffer. Format is (max length),
*	(actual length), (char #1), (char #2), (char #3), etc.
INBUFF:
		DEFB	$7F				;max No of charas held
INBUFF+1:
		DEFB	$08				;CCP i/p command buffer	(No of charas read)
INBUFF+2:
		DEFM	"INIT SYS        "				;1st chara in Read Buffer
		DEFM	"COPYRIGHT (C) 1979, "
		DEFM	"DIGITAL RESEARCH  "
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00
INPOINT:
		DEFB	$08,$D8				;input line pointer (INBUFF+2)
NAMEPNT:
		DEFB	$00,$00				;input line pointer used for error message.
		;Points to start of name in error
*	Routine to print A on the console. All registers used
PRINT:
		LD	E,A				;5F		setup bdos call
		LD	C,$02				;0E02		function number
		JP	ENTRY				;C30500		BDOS function 2 = Console Output
*	Routine to print A on the console and to save BC
PRINTB:
		PUSH	BC				;C5
		CALL	PRINT				;CD8CD8
		POP	BC				;C1
		RET				;C9
*	Routine to send a carriage return, line feed combination to the console
CRLF:
		LD	A,$0D				;3E0D
		CALL	PRINTB				;CD92D8
		LD	A,$0A				;3E0A
		JP	PRINTB				;C392D8
*	Routine to send one space to the console and save BC
SPACE:
		LD	A,$20				;3E20
		JP	PRINTB				;C392D8
*	Routine to print character string pointed to by BC on the console
*	It must terminate with a null byte
PLINE:
		PUSH	BC				;C5
		CALL	CRLF				;CD98D8
		POP	HL				;E1
PLINE2:
		LD	A,(HL)				;7E
		OR	A				;B7		check for zero
		RET	Z				;C8
		INC	HL				;23
		PUSH	HL				;E5
		CALL	PRINT				;CD8CD8
		POP	HL				;E1
		JP	PLINE2				;C3ACD8
*	Routine to reset the disk system
RESDSK:
		LD	C,$0D				;0E0D
		JP	ENTRY				;C30500		BDOS function 13 = Reset Disk System
*	Routine to select disk in A
DSKSEL:
		LD	E,A				;5F		;A = drive number
		LD	C,$0E				;0E0E
		JP	ENTRY				;C30500		BDOS function 14 = Select Disk
*	Routine to call bdos and save the return code
*	The zero flag is set on a return of 0ffh.
ENTRY1:
		CALL	ENTRY				;CD0500		BDOS function
		LD	(RTNCODE),A				;32EEDF		save return code
		INC	A				;3C		set zero if 0ffh returned
		RET				;C9
*	Routine to open a file. (DE) must point to the FCB
OPEN:
		LD	C,$0F				;0E0F
		JP	ENTRY1				;C3C3D8		Do BDOS function 15 = Open File + save and inc Directory Code
*	Routine to open file at (FCB)
OPENFCB:
		XOR	A				;AF		clear the record number byte at fcb+32
		LD	(FCB+32),A				;32EDDF
		LD	DE,FCB				;11CDDF
		JP	OPEN				;C3CBD8
*	Routine to close a file. (DE) points to FCB
CLOSE:
		LD	C,$10				;0E10
		JP	ENTRY1				;C3C3D8		Do BDOS function 16 = Close File + save and inc Directory Code
*	Routine to search for the first file with ambiguous name (DE)
SRCHFST:
		LD	C,$11				;0E11
		JP	ENTRY1				;C3C3D8		Do BDOS function 17 = Search for First + save and inc Directory Code
*	Routine to Search for the next ambiguous file name
SRCHNXT:
		LD	C,$12				;0E12
		JP	ENTRY1				;C3C3D8		Do BDOS function 18 = Search for Next + save and inc Directory Code
*	Search for file at (FCB)
SRCHFCB:
		LD	DE,FCB				;11CDDF		DE = FCB address = $DFCD
		JP	SRCHFST				;C3DFD8		Search for First + save and inc Directory Code
*	Routine to delete a file pointed to by (DE)
DELETE:
		LD	C,$13				;0E13
		JP	ENTRY				;C30500		BDOS function 19 = Delete File
*	Routine to call the bdos and set the zero flag if a zero status is returned
ENTRY2:
		CALL	ENTRY				;CD0500		BDOS function
		OR	A				;B7		check for zero
		RET				;C9
*	Routine to read the next record from a sequential file
*	(DE) points to the FCB
RDREC:
		LD	C,$14				;0E14
		JP	ENTRY2				;C3F4D8		BDOS function 20 = Read Sequential + check for zero
*	Routine to read file at (FCB)
READFCB:
		LD	DE,FCB				;11CDDF
		JP	RDREC				;C3F9D8
*	Routine to write the next record of a sequential file
*	(DE) points to the FCB
WRTREC:
		LD	C,$15				;0E15
		JP	ENTRY2				;C3F4D8		BDOS function 21 = Write Sequential + check for zero
*	Routine to create the file pointed to by (DE)
CREATE:
		LD	C,$16				;0E16
		JP	ENTRY1				;C3C3D8		BDOS function 22 = Make File + save and inc Directory Code
*	Routine to rename the file pointed to by (DE)
*	Note that the new name starts at (DE+16)
RENAM:
		LD	C,$17				;0E17
		JP	ENTRY				;C30500		BDOS function 23 = Rename File
*	Get the Current User Code
GETUSR:
		LD	E,$FF				;1EFF		Get User Code
*	Routne to get or set the current user code
*	If E is FF then this is a GET, else it is a SET
GETSETUC:
		LD	C,$20				;0E20
		JP	ENTRY				;C30500		BDOS function 32 = Set/Get User Code
*	Routine to set the current drive byte at (DSKBYTE)
SETCDRV:
		CALL	GETUSR				;CD13D9
		ADD	A,A				;87
		ADD	A,A				;87
		ADD	A,A				;87
		ADD	A,A				;87		shift into the upper 4 bits
		LD	HL,$DFEF				;21EFDF		add in the current drive number
		OR	(HL)				;B6
		LD	(DSKBYTE),A				;320400		and save
		RET				;C9
*	Move currently active drive down to (DSKBYTE)
MOVECD:
		LD	A,(CDRIVE)				;3AEFDF
		LD	(DSKBYTE),A				;320400
		RET				;C9
*	C h a r a c t e r  f o l d i n g
*	Routine to convert A into upper case ASCII.
*	Only letters are affected
UPPER:
		CP	$61				;FE61		is it < ASCII 'a'?
		RET	C				;D8		if it is, return to address in (SP)
		CP	$7B				;FE7B		else, is it >= ASCII '{'?
		RET	NC				;D0		if it is, return to address in (SP)
		AND	$5F				;E65F		else, convert to upper-case
		RET				;C9		return to address in (SP)
**	P a t c h  t o  r e m o v e  c h a r a c t e r  f o l d i n g
*D930		RET			;C9
*	Routine to get a line of input. We must check to see if the
*	user is in (BATCH) mode. If so, then read the input from file
*	($$$.SUB). At the end, reset to console input.
GETINP:
		LD	A,(BATCH)				;3AABDF
		OR	A				;B7		check for zero
		JP	Z,GETINP1				;CA96D9		if =0, then use console input
*	Use the submit file ($$$.sub) which is prepared by a
*	SUBMIT run. It must be on drive A and it will be deleted
*	if and error occures (like eof).
		LD	A,(CDRIVE)				;3AEFDF		select drive 0 if need be
		OR	A				;B7		check for zero
		LD	A,$00				;3E00		always use drive A for submit
		CALL	NZ,DSKSEL				;C4BDD8		select it if required
		LD	DE,BATCHFCB				;11ACDF		"$$$     SUB"
		CALL	OPEN				;CDCBD8		look for it
		JP	Z,GETINP1				;CA96D9		if not there, use normal input
		LD	A,(BATCHFCB+15)				;3ABBDF		get last record number+1
		DEC	A				;3D
		LD	(BATCHFCB+32),A				;32CCDF
		LD	DE,BATCHFCB				;11ACDF		"$$$     SUB"
		CALL	RDREC				;CDF9D8		read last record
		JP	NZ,GETINP1				;C296D9		quit on end of file
*	Move this record into input buffer.
		LD	DE,INBUFF+1				;1107D8		CCP i/p command buffer
		LD	HL,TBUFF				;218000		data was read into buffer here
		LD	B,$80				;0680		all 128 characters may be used
		CALL	HL2DE				;CD42DC		(HL) to (DE), (B) bytes.
		LD	HL,BATCHFCB+14				;21BADF		's2' byte
		LD	(HL),$00				;3600		zero it out
		INC	HL				;23
		DEC	(HL)				;35		and decrement the record count
		LD	DE,BATCHFCB				;11ACDF		"$$$     SUB"
		CALL	CLOSE				;CDDAD8		close the batch file now
		JP	Z,GETINP1				;CA96D9		quit on an error
		LD	A,(CDRIVE)				;3AEFDF		re-select previous drive if need be
		OR	A				;B7		check for zero
		CALL	NZ,DSKSEL				;C4BDD8		don't do needless selects
*	Print line just read on console.
		LD	HL,INBUFF+2				;2108D8		1st chara in Read Buffer
		CALL	PLINE2				;CDACD8
		CALL	CHKCON				;CDC2D9		check console, quit on a key
		JP	Z,GETINP2				;CAA7D9		jump if no key is pressed
*	Terminate the submit job on any keyboard input. Delete this
*	file such that it is not re-started and jump to normal keyboard
*	input section.
		CALL	DELBATCH				;CDDDD9	       delete the batch file
		JP	CMMND1				;C382DB	       and restart command input
*	Get here for normal keyboard input. Delete the submit file
*	incase there was one.
GETINP1:
		CALL	DELBATCH				;CDDDD9		delete file ($$$.sub)
		CALL	SETCDRV				;CD1AD9		reset active disk
		LD	C,$0A				;0E0A		get line from console device
		LD	DE,INBUFF				;1106D8		Start of Read Buffer
		CALL	ENTRY				;CD0500		BDOS function 10
		CALL	MOVECD				;CD29D9		reset current drive (again)
*	Convert input line to upper case.
GETINP2:
		LD	HL,INBUFF+1				;2107D8		CCP i/p command buffer
		LD	B,(HL)				;46		B = character counter.
GETINP3:
		INC	HL				;23
		LD	A,B				;78		end of the line?
		OR	A				;B7		check for zero
		JP	Z,GETINP4				;CABAD9
		LD	A,(HL)				;7E
		CALL	UPPER				;CD30D9		convert to upper case (character folding)
		LD	(HL),A				;77
		DEC	B				;05		adjust character count
		JP	GETINP3				;C3ABD9
GETINP4:
		LD	(HL),A				;77
		LD	HL,INBUFF+2				;2108D8		1st chara in Read Buffer
		LD	(INPOINT),HL				;2288D8
		RET				;C9
*	Routine to check the console for a key pressed. The zero
*	flag is set is none, else the character is returned in (A).
CHKCON:
		LD	C,$0B				;0E0B
		CALL	ENTRY				;CD0500		BDOS function 11 = Get Console Status
		OR	A				;B7		check for zero
		RET	Z				;C8		return if nothing.
		LD	C,$01				;0E01		else get character.
		CALL	ENTRY				;CD0500		BDOS function 1 = Console Input
		OR	A				;B7		clear zero flag
		RET				;C9		and return
*	Routine to get the currently active drive number
GETDSK:
		LD	C,$19				;0E19
		JP	ENTRY				;C30500		BDOS function 25 = Return Current Disk
*	Set Standard DMA address to TBUFF
STDDMA:
		LD	DE,TBUFF				;118000
*	Routine to set the dma address to (DE).
DMASET:
		LD	C,$1A				;0E1A
		JP	ENTRY				;C30500		BDOS function 26 = Set DMA address
*	Delete the batch file created by SUBMIT
DELBATCH:
		LD	HL,BATCH				;21ABDF		is batch active?
		LD	A,(HL)				;7E
		OR	A				;B7		check for zero
		RET	Z				;C8
		LD	(HL),$00				;3600		yes, de-activate it.
		XOR	A				;AF		A = $00
		CALL	DSKSEL				;CDBDD8		select drive 0 for sure
		LD	DE,BATCHFCB				;11ACDF		and delete this file "$$$     SUB"
		CALL	DELETE				;CDEFD8		Delete File
		LD	A,(CDRIVE)				;3AEFDF
		JP	DSKSEL				;C3BDD8		reset current drive.
*	Check to two strings at (PATTRN1) and (PATTRN2). They must be
*	the same or we halt....
VERIFY:
		LD	DE,PATTRN1				;1128DB		these are the serial number bytes
		LD	HL,PATTRN2				;2100E0		ditto, but how could they be different?
		LD	B,$06				;0606		6 bytes each
VERIFY1:
		LD	A,(DE)				;1A
		CP	(HL)				;BE
		JP	NZ,HALT				;C2CFDB		jump to halt routine
		INC	DE				;13
		INC	HL				;23
		DEC	B				;05
		JP	NZ,VERIFY1				;C2FDD9
		RET				;C9
*	Print back file name with a '?' to indicate a syntax error
SYNERR:
		CALL	CRLF				;CD98D8		end current line
		LD	HL,(NAMEPNT)				;2A8AD8		this points to name in error
SYNERR1:
		LD	A,(HL)				;7E		print it until a space or null is found
		CP	$20				;FE20
		JP	Z,SYNERR2				;CA22DA
		OR	A				;B7		check for zero
		JP	Z,SYNERR2				;CA22DA
		PUSH	HL				;E5
		CALL	PRINT				;CD8CD8
		POP	HL				;E1
		INC	HL				;23
		JP	SYNERR1				;C30FDA
SYNERR2:
		LD	A,$3F				;3E3F		add trailing ASCII '?'
		CALL	PRINT				;CD8CD8
		CALL	CRLF				;CD98D8
		CALL	DELBATCH				;CDDDD9
		JP	CMMND1				;C382DB
*	Check character at DE for legal command input. Note that the
*	zero flag is set if the character is a delimiter.
CHECK:
		LD	A,(DE)				;1A
		OR	A				;B7		check for zero
		RET	Z				;C8
		CP	$20				;FE20	is it >= ASCII <SPACE>?
		JP	C,SYNERR				;DA09DA
		RET	Z				;C8		check for valid delimiter
		CP	$3D				;FE3D	is it ASCII '='?
		RET	Z				;C8
		CP	$5F				;FE5F	is it ASCII '_'?
		RET	Z				;C8
		CP	$2E				;FE2E	is it ASCII '.'?
		RET	Z				;C8
		CP	$3A				;FE3A	is it ASCII ':'?
		RET	Z				;C8
		CP	$3B				;FE3B	is it ASCII ';'?
		RET	Z				;C8
		CP	$3C				;FE3C	is it ASCII '<'?
		RET	Z				;C8
		CP	$3E				;FE3E	is it ASCII '>'?
		RET	Z				;C8
		RET				;C9
*	Get the next non-blank character from DE
NONBLANK:
		LD	A,(DE)				;1A
		OR	A				;B7		string ends with a null
		RET	Z				;C8
		CP	$20				;FE20		is it ASCII <SPACE>?
		RET	NZ				;C0
		INC	DE				;13
		JP	NONBLANK				;C34FDA
*	Add HL = HL + A
ADDHL:
		ADD	A,L				;85
		LD	L,A				;6F
		RET	NC				;D0		take care of any carry
		INC	H				;24
		RET				;C9
*	Convert the first name in (FCB).
CONVFST:
		LD	A,$00				;3E00
*	Format a file name (convert * to '?', etc.). On return,
*	A = 0 is an unambigeous name was specified. Enter with A equal to
*	the position within the fcb for the name (either 0 or 16).
CONVERT:
		LD	HL,FCB				;21CDDF
		CALL	ADDHL				;CD59DA
		PUSH	HL				;E5
		PUSH	HL				;E5
		XOR	A				;AF		A = $00
		LD	(CHGDRV),A				;32F0DF		initialize drive change flag.
		LD	HL,(INPOINT)				;2A88D8		set HL as pointer into input line.
		EX	DE,HL				;EB
		CALL	NONBLANK				;CD4FDA		get next non-blank character.
		EX	DE,HL				;EB
		LD	(NAMEPNT),HL				;228AD8		save pointer here for any error message.
		EX	DE,HL				;EB
		POP	HL				;E1
		LD	A,(DE)				;1A		get first character.
		OR	A				;B7
		JP	Z,CONVRT1				;CA89DA
		SBC	A,$40				;DE40		might be a drive name, convert to binary.
		LD	B,A				;47		and save.
		INC	DE				;13
		LD	A,(DE)				;1A
		CP	$3A				;~:  FE3A	check next character for a ':'.
		JP	Z,CONVRT2				;CA90DA
		DEC	DE				;1B		nope, move pointer back to the start of the line
$CONVRT1:
		LD	A,(CDRIVE)				;3AEFDF
		LD	(HL),A				;77
		JP	CONVRT3				;C396DA
CONVRT2:
		LD	A,B				;78
		LD	(CHGDRV),A				;32F0DF		set change in drives flag
		LD	(HL),B				;70
		INC	DE				;13
*	Convert the basic file name.
CONVRT3:
		LD	B,$08				;0608
CONVRT4:
		CALL	CHECK				;CD30DA
		JP	Z,CONVRT8				;CAB9DA
		INC	HL				;23
		CP	$2A				;~*  FE2A	note that a '*' will fill the remaining field with '?'
		JP	NZ,CONVRT5				;C2A9DA
		LD	(HL),$3F				;363F		ASCII '?' ->
		JP	CONVRT6				;C3ABDA
CONVRT5:
		LD	(HL),A				;77
		INC	DE				;13
CONVRT6:
		DEC	B				;05
		JP	NZ,CONVRT4				;C298DA
CONVRT7:
		CALL	CHECK				;CD30DA
		JP	Z,GETEXT				;CAC0DA
		INC	DE				;13
		JP	CONVRT7				;C3AFDA
CONVRT8:
		INC	HL				;23
		LD	(HL),$20				;3620
		DEC	B				;05
		JP	NZ,CONVRT8				;C2B9DA
*	Get the extension and convert it.
GETEXT:
		LD	B,$03				;0603
		CP	$2E				;FE2E		ASCII '.'
		JP	NZ,GETEXT5				;C2E9DA
		INC	DE				;13
GETEXT1:
		CALL	CHECK				;CD30DA
		JP	Z,GETEXT5				;CAE9DA
		INC	HL				;23
		CP	$2A				;FE2A		ASCII '*'
		JP	NZ,GETEXT2				;C2D9DA
		LD	(HL),$3F				;363F		ASCII '?'
		JP	GETEXT3				;C3DBDA
GETEXT2:
		LD	(HL),A				;77
		INC	DE				;13
GETEXT3:
		DEC	B				;05
		JP	NZ,GETEXT1				;C2C8DA
GETEXT4:
		CALL	CHECK				;CD30DA
		JP	Z,GETEXT6				;CAF0DA
		INC	DE				;13
		JP	GETEXT4				;C3DFDA
GETEXT5:
		INC	HL				;23
		LD	(HL),$20				;3620
		DEC	B				;05
		JP	NZ,GETEXT5				;C2E9DA
GETEXT6:
		LD	B,$03				;0603
GETEXT7:
		INC	HL				;23
		LD	(HL),$00				;3600
		DEC	B				;05
		JP	NZ,GETEXT7				;C2F2DA
		EX	DE,HL				;EB
		LD	(INPOINT),HL				;2288D8		save input line pointer
		POP	HL				;E1
*	Check to see if this is an ambigeous file name specification.
*	Set the A register to non zero if it is.
		LD	BC,$000B				;010B00		set name length.
GETEXT8:
		INC	HL				;23
		LD	A,(HL)				;7E
		CP	$3F				;FE3F		any question marks?
		JP	NZ,GETEXT9				;C209DB
		INC	B				;04		count them.
GETEXT9:
		DEC	C				;0D
		JP	NZ,GETEXT8				;C201DB
		LD	A,B				;78
		OR	A				;B7
		RET				;C9
*	CP/M command table. Note commands can be either 3 or 4 characters long
CMDTBL:
		DEFM	"DIR "
		DEFM	"ERA "
		DEFM	"TYPE"
		DEFM	"SAVE"
		DEFM	"REN "
		DEFM	"USER"
*	The following six bytes must agree with those at (PATTRN2)
*	or cp/m will HALT. Why?
PATTRN1:
		DEFB	$5E,$16,$01,$00,$06,$9D
*	Search the command table for a match with what has just
*	been entered. If a match is found, then we jump to the
*	proper section. Else jump to (UNKNOWN).
*	On return, the C register is set to the command number
*	that matched (or NUMCMDS+1 if no match).
SEARCH:
		LD	HL,CMDTBL				;2110DB		Resident Commands Table
		LD	C,$00				;0E00
SEARCH1:
		LD	A,C				;79
		CP	$06				;FE06		No. of commands
		RET	NC				;D0
		LD	DE,FCB+1				;11CEDF		check this one.
		LD	B,$04				;0604		max command length.
SEARCH2:
		LD	A,(DE)				;1A
		CP	(HL)				;BE
		JP	NZ,SEARCH3				;C24FDB		not a match.
		INC	DE				;13
		INC	HL				;23
		DEC	B				;05
		JP	NZ,SEARCH2				;C23CDB
		LD	A,(DE)				;1A		allow a 3 character command to match.
		CP	$20				;FE20
		JP	NZ,SEARCH4				;C254DB
		LD	A,C				;79		set return register for this command.
		RET				;C9
SEARCH3:
		INC	HL				;23
		DEC	B				;05
		JP	NZ,SEARCH3				;C24FDB
SEARCH4:
		INC	C				;0C
		JP	SEARCH1				;C333DB
*	Set the input buffer to empty and then start the command
*	processor (ccp).
*	entry to empty input buffer before starting ccp
CLEARBUF:
		XOR	A				;AF		A = $00
		LD	(INBUFF+1),A				;3207D8	CCP i/p command buffer - second byte is actual length
**************************************************************
*
* C C P  -   C o n s o l e   C o m m a n d   P r o c e s s o r
*
**************************************************************
*	execute command processor (ccp)
COMMAND:
		LD	SP,CCPSTACK				;31ABDF		setup stack area.
		PUSH	BC				;C5		note that C should be equal to:
		LD	A,C				;79		(uuuudddd) where 'uuuu' is the user
		RRA				;1F		and 'dddd' is the drive number.
		RRA				;1F
		RRA				;1F
		RRA				;1F
		AND	$0F				;E60F		isolate the user number
		LD	E,A				;5F
		CALL	GETSETUC				;CD15D9		and set it
		CALL	RESDSK				;CDB8D8		reset the disk system
		LD	(BATCH),A				;32ABDF		clear batch mode flag
		POP	BC				;C1
		LD	A,C				;79
		AND	$0F				;E60F		isolate the drive number
		LD	(CDRIVE),A				;32EFDF		and save
		CALL	DSKSEL				;CDBDD8		...and select
		LD	A,(INBUFF+1)				;3A07D8		CCP i/p command buffer
		OR	A				;B7		anything in input buffer already?
		JP	NZ,CMMND2				;C298DB		yes, we just process it
*	Entry point to get a command line from the console.
CMMND1:
		LD	SP,CCPSTACK				;31ABDF		set stack straight.
		CALL	CRLF				;CD98D8		start a new line on the screen
		CALL	GETDSK				;CDD0D9		get current drive.
		ADD	A,$41				;C641		ASCII 'A'
		CALL	PRINT				;CD8CD8		print current drive.
		LD	A,$3E				;3E3E		ASCII '>'
		CALL	PRINT				;CD8CD8		and add prompt.
		CALL	GETINP				;CD39D9		get line from user.
CMMND2:
		LD	DE,TBUFF				;118000
		CALL	DMASET				;CDD8D9
		CALL	GETDSK				;CDD0D9
		LD	(CDRIVE),A				;32EFDF
		CALL	CONVFST				;CD5EDA
		CALL	NZ,SYNERR				;C409DA
		LD	A,(CHGDRV)				;3AF0DF
		OR	A				;B7		check zero
		JP	NZ,UNKNOWN				;C2A5DE
		CALL	SEARCH				;CD2EDB
*	Note that an unknown command returns
*	with A pointing to the last address
*	in our table which is (UNKNOWN).
		LD	HL,CMDADR				;21C1DB		now, look thru our address table for command A
		LD	E,A				;5F		set DE to command number
		LD	D,$00				;1600
		ADD	HL,DE				;19
		ADD	HL,DE				;19		HL = (CMDADR)+2*(command number)
		LD	A,(HL)				;7E		now pick out this address
		INC	HL				;23
		LD	H,(HL)				;66
		LD	L,A				;6F
		JP	(HL)				;E9		now execute it
*	CP/M command address table.
CMDADR:
		DEFB	$77,$DC				;DIRECT
		DEFB	$1F,$DD				;ERASE
		DEFB	$5D,$DD				;TYPE
		DEFB	$AD,$DD				;SAVE
		DEFB	$10,$DE				;RENAME
		DEFB	$8E,$DE				;USER
		DEFB	$A5,$DE				;UNKNOWN
*	Halt the system. Reason for this is unknown at present.
HALT:
		LD	HL,$76F3				;21F376		'DI HLT' instructions
		LD	(CBASE),HL				;2200D8
		LD	HL,CBASE				;2100D8
		JP	(HL)				;E9
*	Read error while TYPEing a file.
RDERROR:
		LD	BC,RDERR				;01DFD7
		JP	PLINE				;C3A7D4
RDERR:
		DEFM	"READ ERROR"
		DEFB	$00
*	Required file was not located.
NONE:
		LD	BC,NOFILE				;01F0DB
		JP	PLINE				;C3A7D8
NOFILE:
		DEFM	"NO FILE"
		DEFB	$00
*	Decode a command of the form 'A>filename number{ filename}.
*	Note that a drive specifier is not allowed on the first file
*	name. On return, the number is in register A. Any error
*	causes 'filename?' to be printed and the command is aborted.
DECODE:
		CALL	CONVFST				;CD5EDA		convert filename.
		LD	A,(CHGDRV)				;3AF0DF		do not allow a drive to be specified.
		OR	A				;B7		check zero
		JP	NZ,SYNERR				;C209DA
		LD	HL,FCB+1				;21CEDF		convert number now.
		LD	BC,$000B				;010B00		B = sum register, C = max digit count.
DECODE1:
		LD	A,(HL)				;7E
		CP	$20				;FE20		a space terminates the numeral.
		JP	Z,DECODE3				;CA33DC
		INC	HL				;23
		SUB	$30				;D630		make binary from ascii.
		CP	$0A				;FE0A		legal digit?
		JP	NC,SYNERR				;D209DA
		LD	D,A				;57		yes, save it in D
		LD	A,B				;78		compute B = B * 10 and check for overflow
		AND	$E0				;E6E0
		JP	NZ,SYNERR				;C209DA
		LD	A,B				;78
		RLCA				;07
		RLCA				;07
		RLCA				;07		A = B * 8
		ADD	A,B				;80		.......*9
		JP	C,SYNERR				;DA09DA
		ADD	A,B				;80		.......*10
		JP	C,SYNERR				;DA09DA
		ADD	A,D				;82		add in new digit now.
DECODE2:
		JP	C,SYNERR				;DA09DA
		LD	B,A				;47		and save result.
		DEC	C				;0D		only look at 11 digits.
		JP	NZ,DECODE1				;C208DC
		RET				;C9
DECODE3:
		LD	A,(HL)				;7E		spaces must follow (why?)
		CP	$20				;FE20
		JP	NZ,SYNERR				;C209DA
		INC	HL				;23
DECODE4:
		DEC	C				;0D
		JP	NZ,DECODE3				;C233DC		set A = the numeric value entered
		LD	A,B				;78
		RET				;C9
*	Move 3 bytes from HL to DE. Note that there is only
*	one reference to this at $A2D5
MOVE3:
		LD	B,$03				;0603
*	Move B bytes from HL to DE
HL2DE:
		LD	A,(HL)				;7E
		LD	(DE),A				;12
		INC	HL				;23
		INC	DE				;13
		DEC	B				;05
		JP	NZ,HL2DE				;C242DC
		RET				;C9
*	Compute HL = TBUFF + A + C and get the byte that's here
EXTRACT:
		LD	HL,TBUFF				;218000
		ADD	A,C				;81
		CALL	ADDHL				;CD59DA
		LD	A,(HL)				;7E
		RET				;C9
*	Check drive specified. If it means a change, then the new
*	drive will be selected. In any case, the drive byte of the
*	fcb will be set to null (means use current drive)
DSELECT:
		XOR	A				;AF		zero A
		LD	(FCB),A				;32CDDF		null out first byte of fcb.
		LD	A,(CHGDRV)				;3AF0DF		a drive change indicated?
		OR	A				;B7		check zero
		RET	Z				;C8
		DEC	A				;3D		yes, is it the same as the current drive?
		LD	HL,CDRIVE				;21EFDF
		CP	(HL)				;BE
		RET	Z				;C8
		JP	DSKSEL				;C3BDD8		no. Select it then.
*	Check the drive selection and reset it to the previous
*	drive if it was changed for the preceeding command.
RESETDR:
		LD	A,(CHGDRV)				;3AF0DF		drive change indicated?
		OR	A				;B7		check zero
		RET	Z				;C8
		DEC	A				;3D		yes, was it a different drive?
		LD	HL,CDRIVE				;21EFDF
		CP	(HL)				;BE
		RET	Z				;C8
		LD	A,(CDRIVE)				;3AEFDF		yes, re-select our old drive.
		JP	DSKSEL				;C3BDD8
**************************************************************
*
*           D I R E C T O R Y   C O M M A N D
*
**************************************************************
DIRECT:
		CALL	CONVFST				;CD5EDA		convert file name.
		CALL	DSELECT				;CD54DC		select indicated drive.
		LD	HL,FCB+1				;21CEDF		was any file indicated?
		LD	A,(HL)				;7E
		CP	$20				;FE20
		JP	NZ,DIRECT2				;C28FDC
		LD	B,$0B				;060B		no.
DIRECT1:
		LD	(HL),$3F				;363F		Fill field with 11 X '?' - same as *.*
		INC	HL				;23
		DEC	B				;05
		JP	NZ,DIRECT1				;C288DC
DIRECT2:
		LD	E,$00				;1E00		set initial cursor position.
		PUSH	DE				;D5
		CALL	SRCHFCB				;CDE9D8		get first file name.
		CALL	Z,NONE				;CCEADB		none found at all?
DIRECT3:
		JP	Z,DIRECT9				;CA1BDD		terminate if no more names.
		LD	A,(RTNCODE)				;3AEEDF		get file's position in segment (0-3).
		RRCA				;0F
		RRCA				;0F
		RRCA				;0F		A = position*32
		AND	$60				;E660		mask bits 0-4 and 7, bits 5 and 6 =
		LD	C,A				;4F
		LD	A,$0A				;3E0A
		CALL	EXTRACT				;CD4BDC		extract the tenth entry in fcb.
		RLA				;17		check system file status bit.
		JP	C,SYNERR1				;DA0FDD		we don't list them.
		POP	DE				;D1
		LD	A,E				;7B		bump name count.
		INC	E				;1C
		PUSH	DE				;D5
		AND	$03				;E603		at end of line?
		PUSH	AF				;F5
		JP	NZ,DIRECT4				;C2CCDC
		CALL	CRLF				;CD98D8		yes, end this line and start another
		PUSH	BC				;C5
		CALL	GETDSK				;CDD0D9		start line with 'A:'
		POP	BC				;C1
		ADD	A,$41				;C641
		CALL	PRINTB				;CD92D8
		LD	A,$3A				;3E3A
		CALL	PRINTB				;CD92D8
		JP	DIRECT5				;C3D4DC
DIRECT4:
		CALL	SPACE				;CDA2D8		add seperator between file names.
		LD	A,$3A				;3E3A
		CALL	PRINTB				;CD92D8
DIRECT5:
		CALL	SPACE				;CDA2D8
		LD	B,$01				;0601		'extract' each file name character at a time.
DIRECT6:
		LD	A,B				;78
		CALL	EXTRACT				;CD4BDC
		AND	$7F				;E67F		strip bit 7 (status bit).
		CP	$20				;FE20		are we at the end of the name?
		JP	NZ,DRECT65				;C2F9DC
		POP	AF				;F1		yes, don't print spaces at the end of a line.
		PUSH	AF				;F5
		CP	$03				;FE03
		JP	NZ,DRECT63				;C2F7DC
		LD	A,$09				;3E09		first check for no extension.
		CALL	EXTRACT				;CD4BDC
		AND	$7F				;E67F
		CP	$20				;FE20
		JP	Z,DIRECT7				;CA0EDD		don't print spaces.
DRECT63:
		LD	A,$20				;3E20		else print them.
DRECT65:
		CALL	PRINTB				;CD92D8
		INC	B				;04		bump to next character psoition.
		LD	A,B				;78
		CP	$0C				;FE0C		end of the name?
		JP	NC,DIRECT7				;D20EDD
		CP	$09				;FE09		nope, starting extension?
		JP	NZ,DIRECT6				;C2D9DC
		CALL	SPACE				;CDA2D8		yes, add seperating space.
		JP	DIRECT6				;C3D9DC
DIRECT7:
		POP	AF				;F1		get the next file name.
		CALL	CHKCON				;CDC2D9		first check console, quit on anything.
		JP	NZ,DIRECT9				;C21BDD
		CALL	SRCHNXT				;CDE4D8		get next name.
		JP	DIRECT3				;C398DC		and continue with our list.
DIRECT9:
		POP	DE				;D1		restore the stack and return to command level
		JP	GETBACK				;C386DF
**************************************************************
*
*                E R A S E   C O M M A N D
*
**************************************************************
ERASE:
		CALL	CONVFST				;CD5EDA		convert file name.
		CP	$0B				;FE0B		was '*.*' entered?
		JP	NZ,ERASE1				;C242DD
		LD	BC,YESNO				;0152DD		yes, ask for confirmation.
		CALL	PLINE				;CDA7D8
		CALL	GETINP				;CD39D9
		LD	HL,INBUFF+1				;2107D8		CCP i/p command buffer
		DEC	(HL)				;35		must be exactly 'y'.
		JP	NZ,CMMND1				;C282DB
		INC	HL				;23
		LD	A,(HL)				;7E
		CP	$59				;FE59
		JP	NZ,CMMND1				;C282DB
		INC	HL				;23
		LD	(INPOINT),HL				;2288D8		save input line pointer.
ERASE1:
		CALL	DSELECT				;CD54DC		select desired disk.
		LD	DE,FCB				;11CDDF
		CALL	DELETE				;CDEFD8		delete the file.Delete File
		INC	A				;3C
		CALL	Z,NONE				;CCEADB		not there?
		JP	GETBACK				;C386DF		return to command level now
YESNO:
		DEFM	"ALL (Y/N)?
		DEFB	$00
**************************************************************
*
*            T Y P E   C O M M A N D
*
**************************************************************
TYPE:
		CALL	CONVFST				;CD5EDA		convert file name.
		JP	NZ,SYNERR				;C209DA		wild cards not allowed.
		CALL	DSELECT				;CD54DC		select indicated drive.
		CALL	OPENFCB				;CDD0D8		open the file.
		JP	Z,TYPE5				;CAA7DD		not there?
		CALL	CRLF				;CD98D8		ok, start a new line on the screen.
		LD	HL,NBYTES				;21F1DF		initialize byte counter.
		LD	(HL),$FF				;36FF		set to read first sector.
TYPE1:
		LD	HL,NBYTES				;21F1DF
		LD	A,(HL)				;7E		have we written the entire sector?
		CP	$80				;FE80
		JP	C,TYPE3				;DA87DD
		PUSH	HL				;E5		yes, read in the next one.
		CALL	FCB+32				;CDFED8
		POP	HL				;E1
		JP	NZ,TYPE4				;C2A0DD		end or error?
		XOR	A				;AF		ok, clear byte counter.A = $00
		LD	(HL),A				;77
TYPE3:
		INC	(HL)				;34		count this byte.
		LD	HL,TBUFF				;218000		and get the Ath one from the buffer (TBUFF)
		CALL	ADDHL				;CD59DA
		LD	A,(HL)				;7E
		CP	$1A				;FE1A		end of file mark?
		JP	Z,GETBACK				;CA86DF
		CALL	PRINT				;CD8CD8		no, print it.
		CALL	CHKCON				;CDC2D9		check console, quit if anything ready.
		JP	NZ,GETBACK				;C286DF
		JP	TYPE1				;C374DD
*	Get here on an end of file or read error.
TYPE4:
		DEC	A				;3D
		JP	Z,GETBACK				;CA86DF
		CALL	RDERROR				;CDD9DB
TYPE5:
		CALL	RESETDR				;CD66DC
		JP	SYNERR				;C309DA
**************************************************************
*
*            S A V E   C O M M A N D
*
**************************************************************
SAVE:
		CALL	DECODE				;CDF8DB		get numeric number that follows SAVE.
		PUSH	AF				;F5		save number of pages to write.
		CALL	CONVFST				;CD5EDA		convert file name.
		JP	NZ,SYNERR				;C209DA		wild cards not allowed.
		CALL	DSELECT				;CD54DC		select specified drive.
		LD	DE,FCB				;11CDDF		now delete this file.
		PUSH	DE				;D5
		CALL	DELETE				;CDEFD8		Delete File
		POP	DE				;D1
		CALL	CREATE				;CD09D9		and create it again.
		JP	Z,SAVE3				;CAFBDD		can't create?
		XOR	A				;AF		clear record number byte.A = $00
		LD	(FCB+32),A				;32EDDF
		POP	AF				;F1		convert pages to sectors.
		LD	L,A				;6F
		LD	H,$00				;2600
		ADD	HL,HL				;29		HL = number of sectors to write.
		LD	DE,TBASE				;110001		and we start from here = TBASE
SAVE1:
		LD	A,H				;7C		done yet?
		OR	L				;B5
		JP	Z,SAVE2				;CAF1DD
		DEC	HL				;2B		nope, count this and compute the start
		PUSH	HL				;E5		of the next 128 byte sector.
		LD	HL,TBUFF				;218000
		ADD	HL,DE				;19
		PUSH	HL				;E5		save it and set the transfer address.
		CALL	DMASET				;CDD8D9
		LD	DE,FCB				;11CDDF		write out this sector now.
		CALL	WRTREC				;CD04D9
		POP	DE				;D1		reset DE to the start of the last sector
		POP	HL				;E1		restore sector count.
		JP	NZ,SAVE3				;C2FBDD		write error?
		JP	SAVE1				;C3D4DD
SAVE2:
		LD	DE,FCB				;11CDDF		now close the file
		CALL	CLOSE				;CDDAD8		Close File + save and inc Directory Code
		INC	A				;3C		did it close ok?
		JP	NZ,SAVE4				;C201DE
*	Print out error message (no space).
SAVE3:
		LD	BC,NOSPACE				;0107DE
		CALL	PLINE				;CDA7D8
SAVE4:
		CALL	STDDMA				;CDD5D9		reset the standard dma address
		JP	GETBACK				;C386DF
NOSPACE:
		DEFM	"NO SPACE"
		DEFB	$00
**************************************************************
*
*           R E N A M E   C O M M A N D
*
**************************************************************
RENAME:
		CALL	CONVFST				;CD5EDA		convert first file name.
		JP	NZ,SYNERR				;C209DA		wild cards not allowed.
		LD	A,(CHGDRV)				;3AF0DF		remember any change in drives specified.
		PUSH	AF				;F5
		CALL	DSELECT				;CD54DC		and select this drive.
		CALL	SRCHFCB				;CDE9D8		is this file present?
		JP	NZ,RENAME6				;C279DE		yes, print error message.
		LD	HL,FCB				;21CDDF		yes, move this name into second slot.
		LD	DE,FCB+16				;11DDDF		record byte in fcb
		LD	B,$10				;0610
		CALL	HL2DE				;CD42DC
		LD	HL,(INPOINT)				;2A88D8		get input pointer.
		EX	DE,HL				;EB
		CALL	NONBLANK				;CD4FDA		get next non blank character.
		CP	$3D				;FE3D		only allow an '=' or '_' seperator.
		JP	Z,RENAME1				;CA3FDE
		CP	$5F				;FE5F
		JP	NZ,RENAME5				;C273DE
RENAME1:
		EX	DE,HL				;EB
		INC	HL				;23		ok, skip seperator.
		LD	(INPOINT),HL				;2288D8		save input line pointer.
		CALL	CONVFST				;CD5EDA		convert this second file name now.
		JP	NZ,RENAME5				;C273DE		again, no wild cards.
		POP	AF				;F1		if a drive was specified, then it
		LD	B,A				;47		must be the same as before.
		LD	HL,CHGDRV				;21F0DF
		LD	A,(HL)				;7E
		OR	A				;B7		check zero
		JP	Z,RENAME2				;CA59DE
		CP	B				;B8
		LD	(HL),B				;70
		JP	NZ,RENAME5				;C273DE		they were different, error.
RENAME2:
		LD	(HL),B				;70		reset as per the first file specification
		XOR	A				;AF		A = $00
		LD	(FCB),A				;32CDDF		clear the drive byte of the fcb.
		CALL	SRCHFCB				;CDE9D8		and go look for second file.
		JP	Z,RENAME4				;CA6DDE		doesn't exist?
		LD	DE,FCB				;11CDDF
		CALL	RENAM				;CD0ED9		ok, rename the file.
		JP	GETBACK				;C386DF
*	Process rename errors here.
RENAME4:
		CALL	NONE				;CDEADB		file not there
		JP	GETBACK				;C386DF
RENAME5:
		CALL	RESETDR				;CD66DC		bad command format
		JP	SYNERR				;C309DA
RENAME6:
		LD	BC,EXISTS				;0182DE		destination file already exists
		CALL	PLINE				;CDA7D8
		JP	GETBACK				;C386DF
EXISTS:
		DEFM	"FILE EXISTS"
		DEFB	$00
**************************************************************
*
*             U S E R   C O M M A N D
*
**************************************************************
USER:
		CALL	DECODE				;CDF8DB		get numeric value following command
		CP	$10				;FE10		legal user number?
		JP	NC,SYNERR				;D209DA
		LD	E,A				;5F		yes but is there anything else?
		LD	A,(FCB+1)				;3ACEDF
		CP	$20				;FE20
		JP	Z,SYNERR				;CA09DA		yes, that is not allowed.
		CALL	GETSETUC				;CD15D9		ok, set user code.
		JP	GETBACK1				;C389DF
**************************************************************
*
*        T R A N S I E N T   P R O G R A M   C O M M A N D
*
**************************************************************
UNKNOWN:
		CALL	VERIFY				;CDF5D9		check for valid system (why?)
		LD	A,(FCB+1)				;3ACEDF		anything to execute?
		CP	$20				;FE20
		JP	NZ,UNKWN1				;C2C4DE
		LD	A,(CHGDRV)				;3AF0DF		nope, only a drive change?
		OR	A				;B7		check zero
		JP	Z,GETBACK1				;CA89DF		neither???
		DEC	A				;3D
		LD	(CDRIVE),A				;32EFDF		ok, store new drive.
		CALL	MOVECD				;CD29D9		set (TDRIVE) also.
		CALL	DSKSEL				;CDBDD8		and select this drive.
		JP	GETBACK1				;C389DF		then return.
*	Here a file name was typed. Prepare to execute it.
UNKWN1:
		LD	DE,FCB+9				;11D6DF		an extension specified?
		LD	A,(DE)				;1A
		CP	$20				;FE20
		JP	NZ,SYNERR				;C209DA		yes, not allowed.
		PUSH	DE				;D5
		CALL	DSELECT				;CD54DC		select specified drive.
		POP	DE				;D1
		LD	HL,COMFILE				;2183DF		set the extension to 'COM'
		CALL	MOVE3				;CD40DC
		CALL	OPENFCB				;CDD0D8		and open this file.
		JP	Z,UNKWN9				;CA6BDF		not present?
*	Load in the program.
		LD	HL,TBASE				;210001		store the program starting here.
UNKWN3:
		PUSH	HL				;E5
		EX	DE,HL				;EB
		CALL	DMASET				;CDD8D9		set transfer address.
		LD	DE,FCB				;11CDDF		and read the next record.
		CALL	RDREC				;CDF9D8
		JP	NZ,UNKWN4				;C201DF		end of file or read error?
		POP	HL				;E1		nope, bump pointer for next sector
		LD	DE,TBUFF				;118000
		ADD	HL,DE				;19
		LD	DE,CBASE				;1100D8		enough room for the whole file?
		LD	A,L				;7D
		SUB	E				;93
		LD	A,H				;7C
		SBC	A,D				;9A
		JP	NC,UNKWN0				;D271DF
		JP	UNKWN3				;C3E1DE
*	Get here after finished reading.
UNKWN4:
		POP	HL				;E1		normal end of file?
		DEC	A				;3D
		JP	NZ,UNKWN0				;C271DF		yes, reset previous drive.
		CALL	RESETDR				;CD66DC		convert the first file name that follows
		CALL	CONVFST				;CD5EDA		command name.
		LD	HL,CHGDRV				;21F0DF
		PUSH	HL				;E5		set drive code in default fcb.
		LD	A,(HL)				;7E
		LD	(FCB),A				;32CDDF		put second name 16 bytes later.
		LD	A,$10				;3E10		convert second file name.
		CALL	CONVERT				;CD60DA
		POP	HL				;E1		and set the drive for this second file.
		LD	A,(HL)				;7E
		LD	(FCB+16),A				;32DDDF		clear record byte in fcb.
		XOR	A				;AF		A = $00
		LD	(FCB+32),A				;32EDDF		move it into place at ($005C).
		LD	DE,TFCB				;115C00
		LD	HL,FCB				;21CDDF
		LD	B,$21				;0621		33 bytes
		CALL	HL2DE				;CD42DC		now move the remainder of the input
		LD	HL,INBUFF+2				;2108D8		line down to (0080h). Look for a non blank1st chara in Read Buffer
UNKWN5:
		LD	A,(HL)				;7E		or a null.
		OR	A				;B7		check zero
		JP	Z,UNKWN6				;CA3EDF
		CP	$20				;FE20
		JP	Z,UNKWN6				;CA3EDF
		INC	HL				;23
		JP	UNKWN5				;C330DF
*	Do the line move now. It ends in a null byte.
UNKWN6:
		LD	B,$00				;0600
		LD	DE,$0081				;118100
UNKWN7:
		LD	A,(HL)				;7E
		LD	(DE),A				;12
		OR	A				;B7		check zero
		JP	Z,$DF4F				;CA4FDF
		INC	B				;04
		INC	HL				;23
		INC	DE				;13
		JP	UNKWN7				;C343DF
UNKWN8:
		LD	A,B				;78		now store the character count
		LD	(TBUFF),A				;328000		DBUFF
		CALL	CRLF				;CD98D8		clean up the screen.
		CALL	STDDMA				;CDD5D9		set standard transfer address
		CALL	SETCDRV				;CD1AD9		reset current drive.
		CALL	TBASE				;CD0001		and execute the program.
*	Transient programs return here (or reboot).
		LD	SP,CCPSTACK				;31ABDF		set stack first off.
		CALL	MOVECD				;CD29D9		move current drive into place (TDRIVE)
		CALL	DSKSEL				;CDBDD8		and reselect it.
		JP	CMMND1				;C382DB		back to comand mode.
*	Get here if some error occured.
UNKWN9:
		CALL	RESETDR				;CD66DC		inproper format
		JP	SYNERR				;C309DA
UNKWN0:
		LD	BC,$BADLOAD				;017ADF		read error or won't fit
		CALL	PLINE				;CDA7D8
		JP	GETBACK				;C386DF
BADLOAD:
		DEFM	"BAD LOAD"
		DEFB	$00
COMFILE:
		DEFM	"COM"
*	Get here to return to command level. We will reset the
*	previous active drive and then either return to command
*	level directly or print error message and then return.
GETBACK:
		CALL	RESETDR				;CD66DC		improper format.
GETBACK1:
		CALL	CONVFST				;CD5EDA
		LD	A,(FCB+1)				;3ACEDF		read error or won't fit
		SUB	$20				;D620
		LD	HL,CHGDRV				;21F0DF
		OR	(HL)				;B6
		JP	NZ,SYNERR				;C209DA		command file extension.
		JP	CMMND1				;C382DB
*	CCP stack area.
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
CCPSTACK:
		DEFB	$00				;end of ccp stack area
*	 Batch (or SUBMIT) processing information storage.
BATCH:
		DEFB	$00				;batch mode flag (0=not active)
BATCHFCB:
		DEFB	$00
		DEFM	"$$$     SUB"
		DEFB	$00
		DEFB	$00
BATCHFCB+14:
		DEFB	$00
BATCHFCB+15:
		DEFB	$00,$00,$00.$00
		DEFB	$00,$00,$00.$00
		DEFB	$00,$00,$00.$00
		DEFB	$00,$00,$00.$00
		DEFB	$00
BATCHFCB+32:
		DEFB	$00
FCB:
		DEFB	$00
FCB+1:
		DEFB	$00,$00,$00,$00				;filename
		DEFB	$00,$00,$00,$00
FCB+9:
		DEFB	$00.$00,$00				;disk file type
		DEFB	$00,$00,$00,$00
FCB+16:
		DEFB	$00,$00,$00,$00				;record byte in fcb
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
FCB+32:
		DEFB	$00
RTNCODE:
		DEFB	$00
CDRIVE:
		DEFB	$00
CHGDRV:
		DEFB	$00
NBYTES:
		DEFB	$00.$00
*	Room for expansion?
		DEFB	$00,$00,$00.$00
		DEFB	$00,$00,$00.$00
		DEFB	$00,$00,$00.$00
		DEFB	$00
*BDOS Start
**************************************************************
*
*                    B D O S   E N T R Y
*
**************************************************************
*FBASE
PATTRN2:
		DEFB	$5E,$16,$01,$00,$06,$9D
FBASE:
		JP	FBASE1				;C311E0
*	BDOS error table.
BADSCTR:
		DEFB	$99,$E0				;ERROR1 - bad sector on read or write
BADSLCT:
		DEFB	$A5,$E0				;ERROR2 - bad disk select.
RODISK:
		DEFB	$AB,$E0				;ERROR3 - disk is read only.
ROFILE:
		DEFB	$B1,$E0				;ERROR4 - file is read only.
*	Entry into BDOS. DE or E are the parameters passed.
*	The function number desired is in register C.
FBASE1:
		EX	DE,HL				;EB
		LD	(PARAMS),HL				;2243E3
		EX	DE,HL				;EB
		LD	A,E				;7B
		LD	(EPARAM),A				;32D6ED
		LD	HL,$0000				;210000
		LD	(STATUS),HL				;2245E3
		ADD	HL,SP				;39
		LD	(USRSTACK),HL				;220FE3
		LD	SP,STKAREA				;3141E3
		XOR	A				;AF		A = $00
		LD	(AUTOFLAG),A				;32E0ED
		LD	(AUTO),A				;32DEED
		LD	HL,GOBACK				;2174ED
		PUSH	HL				;E5
		LD	A,C				;79		A = C = function No.
		CP	$29				;FE29		NFUNCTS
		RET	NC				;D0		if >= 41, return
		LD	C,E				;4B		else, C = E =
		LD	HL,FUNCTNS				;2147E0
		LD	E,A				;5F
		LD	D,$00				;1600
		ADD	HL,DE				;19
		ADD	HL,DE				;19
		LD	E,(HL)				;5E
		INC	HL				;23
		LD	D,(HL)				;56
		LD	HL,(PARAMS)				;2A43E3
		EX	DE,HL				;EB
		JP	(HL)				;E9
*	BDOS function jump table.
FUNCTNS:
		DEFB	$03,$EE				;WBOOT	  = BDOS function 0 = Warm Boot
		DEFB	$C8,$E2				;GETCON	  = BDOS function 1 = Console I/P
		DEFB	$90,$E1				;OUTCON	  = BDOS function 2 = Console O/P
		DEFB	$CE,$E2				;GETRDR	  = BDOS function 3 = Reader I/P
		DEFB	$12,$EE				;PUNCH	  = BDOS function 4 = Punch O/P
		DEFB	$0F,$EE				;LIST	  = BDOS function 5 = List O/P
		DEFB	$D4,$E2				;DIRCIO	  = BDOS function 6 = Direct Console O/P
		DEFB	$ED,$E2				;GETIOB	  = BDOS function 7 = Get I/O byte
		DEFB	$F3,$E2				;SETIOB	  = BDOS function 8 = Set I/O byte
		DEFB	$F8,$E2				;PRTSTR	  = BDOS function 9 = Print String
		DEFB	$E1,$E1				;RDBUFF	  = BDOS function 10 = Read Console Buffer
		DEFB	$FE,$E2				;GETCSTS  = BDOS function 11 = Get Console Status
		DEFB	$7E,$EC				;GETVER	  = BDOS function 12 = Return Version Number
		DEFB	$83,$EC				;RSTDSK	  = BDOS function 13 = Reset System Drive
		DEFB	$45,$EC				;SETDSK	  = BDOS function 14 = Select Drive
		DEFB	$9C,$EC				;OPENFIL  = BDOS function 15 = Open File
		DEFB	$A5,$EC				;CLOSEFIL = BDOS function 16 = Close File
		DEFB	$AB,$EC				;GETFST	  = BDOS function 17 = Search for First
		DEFB	$C8,$EC				;GETNXT	  = BDOS function 18 = Search for Next
		DEFB	$D7,$EC				;DELFILE  = BDOS function 19 = Delete File
		DEFB	$E0,$EC				;READSEQ  = BDOS function 20 = Read Sequential
		DEFB	$E6,$EC				;WRTSEQ	  = BDOS function 21 = Write Sequential
		DEFB	$EC,$EC				;FCREATE  = BDOS function 22 = Make File
		DEFB	$F5,$EC				;RENFILE  = BDOS function 23 = Rename File
		DEFB	$FE,$EC				;GETLOG	  = BDOS function 24 = Return Login Vector
		DEFB	$04,$ED				;GETCRNT  = BDOS function 25 = Return Current Drive
		DEFB	$0A,$ED				;PUTDMA	  = BDOS function 26 = Set DMA Address
		DEFB	$11,$ED				;GETALOC  = BDOS function 27 = Get ADDR (ALLOC)
		DEFB	$2C,$E5				;WRTPRTD  = BDOS function 28 = Write Protect Drive
		DEFB	$17,$ED				;GETROV	  = BDOS function 29 = Get Read/Only Vector
		DEFB	$1D,$ED				;SETATTR  = BDOS function 30 = Set File Attributes
		DEFB	$26,$ED				;GETPARM  = BDOS function 31 = Get ADDR (Disk Parms)
		DEFB	$2D,$ED				;GETUSER  = BDOS function 32 = Get/Set User Code
		DEFB	$41,$ED				;RDRANDOM = BDOS function 33 = Read Random
		DEFB	$47,$ED				;WTRANDOM = BDOS function 34 = Write Random
		DEFB	$4D,$ED				;FILESIZE = BDOS function 35 = Compute File Size
		DEFB	$0E,$EC				;SETRAN	  = BDOS function 36 = Set Random Record
		DEFB	$53,$ED				;LOGOFF	  = BDOS function 37 = Reset Drive
		DEFB	$04,$E3				;RTN	  = BDOS function 38 = Access Drive - not supported
		DEFB	$04,$E3				;RTN	  = BDOS function 39 = Free Drive - not supported
		DEFB	$9B,$ED				;WTSPECL  = BDOS function 40 = Write Random w/- fill
*	Bdos error message section.
ERROR1:
		LD	HL,BADSEC				;21CAE0		bad sector message.
		CALL	PRTERR				;CDE5E0		print it and get a 1 char responce
		CP	CNTRLC				;FE03		re-boot request (control-c)?
		JP	Z,WRMBT				;CA0000		yes.
		RET				;C9		no, return to retry i/o function.
ERROR2:
		LD	HL,BADSEL				;21D5E0		bad drive selected
		JP	ERROR5				;C3B4E0
		LD	HL,DISKRO				;21E1E0		disk is read only
		JP	ERROR5				;C3B4E0
UCB1:
		LD	HL,FILERO				;21DCE0		file is read only
ERROR5:
		CALL	PRTERR				;CDE5E0
		JP	WRMBT				;C30000		always reboot on these errors
BDOSERR:
		DEFM	"Bdos Error On "
BDOSDRV:
		DEFM	" : $"
BADSEC:
		DEFM	"Bad Sector"
		DEFM	"$"
BADSEL:
		DEFM	"Select"
		DEFM	"$"
FILERO:
		DEFM	"File "
DISKRO:
		DEFM	"R/O"
		DEFM	"$"
PRTERR:
		PUSH	HL				;E5		save second message pointer.
		CALL	OUTCRLF				;CDC9E1		send <CR><LF>
		LD	A,(ACTIVE)				;3A42E3		get active drive
		ADD	A,$41				;C641		make ASCII
		LD	(BDOSDRV),A				;32C6E0		and put in message
		LD	BC,BDOSERR				;01BAE0		and print it
		CALL	PRTMESG				;CDD3E1
		POP	BC				;C1		print second message line now
		CALL	PRTMESG				;CDD3E1
*	Get an input character. We will check our 1 character
*	buffer first. This may be set by the console status routine.
GETCHAR:
		LD	HL,CHARBUF				;210EE3		check character buffer.
		LD	A,(HL)				;7E		anything present already?
		LD	(HL),$00				;3600		...either case clear it.
		OR	A				;B7		check zero
		RET	NZ				;C0		yes, use it.
		JP	CONIN				;C309EE		nope, go get a character responce
*	Input and echo a character.
GETECHO:
		CALL	GETCHAR				;CDFBE0		input a character.
		CALL	CHKCHAR				;CD14E1		carriage control?
		RET	C				;D8		no, a regular control char so don't echo
		PUSH	AF				;F5		ok, save character now.
		LD	C,A				;4F
		CALL	OUTCON				;CD90E1		and echo it.
		POP	AF				;F1		get character
		RET				;C9		and return.
*	Check character in A. Set the zero flag on a carriage control
*	character and the carry flag on any other control character.
CHKCHAR:
		CP	CR				;FE0D		check for carriage return, , ,
		RET	Z				;C8		.
		CP	LF				;FE0A		line feed
		RET	Z				;C8
		CP	TAB				;FE09		tab
		RET	Z				;C8
		CP	BS				;FE08		or a backspace
		RET	Z				;C8
		CP	$20				;FE20		other control char? Set carry flag.
		RET				;C9
*	Check the console during output. Halt on a control-s, then
*	reboot on a control-c. If anything else is ready, clear the
*	zero flag and return (the calling routine may want to do something)
CKCONSOL:
		LD	A,(CHARBUF)				;3A0EE3		check buffer.
		OR	A				;B7		if anything, just return without checking.
		JP	NZ,CKCON2				;C245E1
		CALL	CONST				;CD06EE		nothing in buffer. Check console.
		AND	$01				;E601		look at bit 0.
		RET	Z				;C8		return if nothing.
		CALL	CONIN				;CD09EE		ok, get it.
		CP	CNTRLS				;FE13		if not control-s, return with zero cleared.
		JP	NZ,CKCON1				;C242E1
		CALL	CONIN				;CD09EE		halt processing until another char
		CP	$03				;FE03		is typed. CTRL-C?
		JP	Z,$0000				;CA0000		yes, reboot now.
		XOR	A				;AF		no, just pretend nothing was ever ready.A = $00
		RET				;C9
CKCON1:
		LD	(CHARBUF),A				;320EE3		save character in buffer for later processing.
CKCON2:
		LD	A,$01				;3E01		set A to non zero to mean something is ready
		RET				;C9
*	Output C to the screen. If the printer flip-flop flag
*	is set, we will send character to printer also. The console
*	will be checked in the process.
OUTCHAR:
		LD	A,(OUTFLAG)				;3A0AE3		check output flag.
		OR	A				;B7		anything and we won't generate output.
		JP	NZ,OUTCHR1				;C262E1
		PUSH	BC				;C5
		CALL	CKCONSOL				;CD23E1		check console (we don't care whats there).
		POP	BC				;C1
		PUSH	BC				;C5
		CALL	CONOUT				;CD0CEE		output C to the screen.
		POP	BC				;C1
		PUSH	BC				;C5
		LD	A,(PRTFLAG)				;3A0DE3		check printer toggle flag.
		OR	A				;B7		check zero
		CALL	NZ,LIST				;C40FEE		print it also if non-zero.
		POP	BC				;C1
OUTCHR1:
		LD	A,C				;79		update cursors position.
		LD	HL,CURPOS				;210CE3
		CP	DEL				;FE7F		rubouts don't do anything here.
		RET	Z				;C8
		INC	(HL)				;34		bump line pointer.
		CP	$20				;FE20		and return if a normal character.
		RET	NC				;D0
		DEC	(HL)				;35		restore and check for the start of the line.
		LD	A,(HL)				;7E
		OR	A				;B7		check zero
		RET	Z				;C8		ingnore control characters at the start of the line
		LD	A,C				;79
		CP	$08				;FE08		is it a backspace?
		JP	NZ,OUTCHR2				;C279E1
		DEC	(HL)				;35		yes, backup pointer.
		RET				;C9
OUTCHR2:
		CP	$0A				;FE0A		is it a line feed?
		RET	NZ				;C0		ignore anything else.
		LD	(HL),$00				;3600		reset pointer to start of line
		RET				;C9
*	Output A to the screen. If it is a control character
*	(other than carriage control), use ^x format.
SHOWIT:
		LD	A,C				;79		check character.
		CALL	CHKCHAR				;CD14E1		not a control, use normal output.
		JP	NC,OUTCON				;D290E1
		PUSH	AF				;F5
		LD	C,$5E				;0E5E		for a control character, preceed it with '^'
		CALL	OUTCHAR				;CD48E1
		POP	AF				;F1
		OR	$40				;F640		and then use the letter equivelant.
		LD	C,A				;4F
*	BDOS function 2 to output C to the console device and expand tabs if necessary.
OUTCON:
		LD	A,C				;79
		CP	$09				;FE09		is it a tab?
		JP	NZ,OUTCHAR				;C248E1		use regular output.
OUTCON1:
		LD	C,$20				;0E20		yes it is, use spaces instead.
		CALL	OUTCHAR				;CD48E1
		LD	A,(CURPOS)				;3A0CE3		go until the cursor is at a multiple of 8
		AND	$07				;E607
		JP	NZ,OUTCON1				;C296E1		position.
		RET				;C9
*	Echo a backspace character. Erase the prevoius character
*	on the screen.
BACKUP:
		CALL	BACKUP1				;CDACE1		backup the screen 1 place
		LD	C,$20				;0E20		then blank that character
		CALL	CONOUT				;CD0CEE
BACKUP1:
		LD	C,BS				;0E08		then back space once more
		JP	CONOUT				;C30CEE
*	Signal a deleted line. Print a '#' at the end and start
*	over.
NEWLINE:
		LD	C,$23				;0E23		ASCII '#'
		CALL	OUTCHAR				;CD48E1		print this.
		CALL	OUTCRLF				;CDC9E1		start new line.
NEWLN1:
		LD	A,(CURPOS)				;3A0CE3		move the cursor to the starting position
		LD	HL,STARTING				;210BE3
		CP	(HL)				;BE
		RET	NC				;D0		there yet?
		LD	C,$20				;0E20
		CALL	OUTCHAR				;CD48E1		nope, keep going.
		JP	NEWLN1				;C3B9E1
*	Output a <CR> <LF> to the console device (screen).
OUTCRLF:
		LD	C,CR				;0E0D
		CALL	OUTCHAR				;CD48E1
		LD	C,LF				;0E0A
		JP	OUTCHAR				;C348E1
*	Print message pointed to by BC. It will end with a '$'.
PRTMESG:
		LD	A,(BC)				;0A
		CP	$24				;FE24		check for terminating character ($).
		RET	Z				;C8
		INC	BC				;03
		PUSH	BC				;C5
		LD	C,A				;4F		otherwise, bump pointer and print it
		CALL	OUTCON				;CD90E1
		POP	BC				;C1
		JP	PRTMESG				;C3D3E1
*	BDOS function 10 to execute a buffered read.
RDBUFF:
		LD	A,(CURPOS)				;3A0CE3		use present location as starting one.
		LD	(STARTING),A				;320BE3
		LD	HL,(PARAMS)				;2A43E3		get the maximum buffer space.
		LD	C,(HL)				;4E
		INC	HL				;23		point to first available space.
		PUSH	HL				;E5		and save.
		LD	B,$00				;0600		keep a character count.
RDBUF1:
		PUSH	BC				;C5
		PUSH	HL				;E5
RDBUF2:
		CALL	GETCHAR				;CDFBE0		get the next input character.
		AND	$7F				;E67F		strip bit 7.
		POP	HL				;E1		reset registers.
		POP	BC				;C1
		CP	CR				;FE0D		end of the line?
		JP	Z,RDBUF18				;CAC1E2
		CP	LF				;FE0A
		JP	Z,RDBUF18				;CAC1E2
		CP	BS				;FE08		how about a backspace?
		JP	NZ,RDBUF4				;C216E2
RDBUF3:
		LD	A,B				;78		yes, but ignore at the beginning of the line
		OR	A				;B7		check zero
		JP	Z,RDBUF1				;CAEFE1
		DEC	B				;05		ok, update counter.
		LD	A,(CURPOS)				;3A0CE3		if we backspace to the start of the line,
		LD	(OUTFLAG),A				;320AE3		treat as a cancel (control-x).
		JP	RDBUF11				;C370E2
RDBUF4:
		CP	DEL				;FE7F		user typed a rubout?
		JP	NZ,RDBUF5				;C226E2
		LD	A,B				;78		ignore at the start of the line
		OR	A				;B7		check zero
		JP	Z,RDBUF1				;CAEFE1
		LD	A,(HL)				;7E		ok, echo the prevoius character
		DEC	B				;05		and reset pointers (counters).
		DEC	HL				;2B
		JP	RDBUF16				;C3A9E2
RDBUF5:
		CP	CNTRLE				;FE05		physical end of line?
		JP	NZ,RDBUF6				;C237E2
		PUSH	BC				;C5		yes, do it.
		PUSH	HL				;E5
		CALL	OUTCRLF				;CDC9E1
		XOR	A				;AF		and update starting position A = $00
		LD	(STARTING),A				;320BE3
		JP	RDBUF2				;C3F1E1
RDBUF6:
		CP	CNTRLP				;FE10		control-p?
		JP	NZ,RDBUF7				;C248E2
		PUSH	HL				;E5		yes, flip the print flag filp-flop byte
		LD	HL,PRTFLAG				;210DE3
		LD	A,$01				;3E01		PRTFLAG=1-PRTFLAG
		SUB	(HL)				;96
		LD	(HL),A				;77
		POP	HL				;E1
		JP	RDBUF1				;C3EFE1
RDBUF7:
		CP	CNTRLX				;FE18		control-x (cancel)?
		JP	NZ,RDBUF9				;C25FE2
		POP	HL				;E1
RDBUF8:
		LD	A,(STARTING)				;3A0BE3		yes, backup the cursor to here.
		LD	HL,CURPOS				;210CE3
		CP	(HL)				;BE
		JP	NC,RDBUFF				;D2E1E1		done yet?
		DEC	(HL)				;35		no, decrement pointer and output back up one space
		CALL	BACKUP				;CDA4E1
		JP	RDBUF8				;C34EE2
RDBUF9:
		CP	CNTRLU				;FE15		cntrol-u (cancel line)?
		JP	NZ,RDBUF10				;C26BE2
		CALL	NEWLINE				;CDB1E1		start a new line.
		POP	HL				;E1
		JP	RDBUFF				;C3E1E1
		RDBUF10				;	CP	CNTRLR		;FE12		control-r?
		JP	NZ,RDBUF15				;C2A6E2
RDBUF11:
		PUSH	BC				;C5		yes, start a new line and retype the old one
		CALL	NEWLINE				;CDB1E1
		POP	BC				;C1
		POP	HL				;E1
		PUSH	HL				;E5
		PUSH	BC				;C5
RDBUF12:
		LD	A,B				;78		done whole line yet?
		OR	A				;B7		check zero
		JP	Z,RDBUF13				;CA8AE2
		INC	HL				;23		nope, get next character.
		LD	C,(HL)				;4E
		DEC	B				;05		count it.
		PUSH	BC				;C5
		PUSH	HL				;E5
		CALL	SHOWIT				;CD7FE1		and display it.
		POP	HL				;E1
		POP	BC				;C1
		JP	RDBUF12				;C378E2
RDBUF13:
		PUSH	HL				;E5		done with line. If we were displaying
		LD	A,(OUTFLAG)				;3A0AE3		then update cursor position.
		OR	A				;B7		check zero
		JP	Z,RDBUF2				;CAF1E1
		LD	HL,CURPOS				;210CE3		because this line is shorter, we must
		SUB	(HL)				;96		back up the cursor (not the screen however)
		LD	(OUTFLAG),A				;320AE3		some number of positions.
RDBUF14:
		CALL	BACKUP				;CDA4E1		note that as long as (OUTFLAG) is non
		LD	HL,OUTFLAG				;210AE3		zero, the screen will not be changed.
		DEC	(HL)				;35
		JP	NZ,RDBUF14				;C299E2
		JP	RDBUF2				;C3F1E1		now just get the next character.
*	Just a normal character, put this in our buffer and echo.
RDBUF15:
		INC	HL				;23
		LD	(HL),A				;77		store character.
		INC	B				;04		and count it.
RDBUF16:
		PUSH	BC				;C5
		PUSH	HL				;E5
		LD	C,A				;4F		echo it now.
		CALL	SHOWIT				;CD7FE1
		POP	HL				;E1
		POP	BC				;C1
		LD	A,(HL)				;7E		was it an abort request?
		CP	CNTRLC				;FE03		control-c abort?
		LD	A,B				;78
		JP	NZ,RDBUF17				;C2BDE2
		CP	$01				;FE01		only if at start of line.
		JP	Z,WRMBT				;CA0000
RDBUF17:
		CP	C				;B9		nope, have we filled the buffer?
		JP	C,RDBUF1				;DAEFE1
RDBUF18:
		POP	HL				;E1		yes end the line and return.
		LD	(HL),B				;70
		LD	C,CR				;0E0D
		JP	OUTCHAR				;C348E1		output <CR> and return.
*	BDOS function 1 to get a character from the console device.
GETCON:
		CALL	GETECHO				;CD06E1		get and echo.
		JP	SETSTAT				;C301E3		save status and return
*	BDOS function 3 to get a character from the tape reader device.
GETRDR:
		CALL	READER				;CD15EE		get a character from reader,
		JP	SETSTAT				;C301E3		set status and return
*	BDOS function 6 to perform direct console i/o. If C contains $FF
*	then this is an input request. If C contains $FE then
*	this is a status request. Otherwise we are to output C.
DIRCIO:
		LD	A,C				;79		test for $FF
		INC	A				;3C
		JP	Z,DIRC1				;CAE0E2
		INC	A				;3C		test for $FE
		JP	Z,CONST				;CA06EE
		JP	CONOUT				;C30CEE		just output C
DIRC1:
		CALL	CONST				;CD06EE		this is an input request
		OR	A				;B7		check zero
		JP	Z,GOBACK1				;CA91ED		not ready? Just return (directly)
		CALL	CONIN				;CD09EE		yes, get character
		JP	SETSTAT				;C301E3		set status and return
*	BDOS function 7 to return the i/o byte.
GETIOB:
		LD	A,(IOBYTE)				;3A0300
		JP	SETSTAT				;C301E3
*	BDOS function 8 to set the i/o byte.
SETIOB:
		LD	HL,IOBYTE				;210300
		LD	(HL),C				;71
		RET				;C9
*	BDOS function 9 to print the character string pointed to by DE
*	on the console device. The string ends with a '$'.
PRTSTR:
		EX	DE,HL				;EB
		LD	C,L				;4D
		LD	B,H				;44		now BC points to it
		JP	PRTMESG				;C3D3E1
*	BDOS function 11 to interegate the console device.
GETCSTS:
		CALL	CKCONSOL				;CD23E1
*	Get here to set the status and return to the cleanup
*	section. Then back to the user.
SETSTAT:
		LD	(STATUS),A				;3245E3
RTN:
		RET				;C9
*	Set the status to 1 (read or write error code).
IOERR1:
		LD	A,$01				;3E01
		JP	SETSTAT				;C301E3
OUTFLAG:
		DEFB	$00				;output flag (non zero means no output)
STARTING:
		DEFB	$00				;starting position for cursor
CURPOS:
		DEFB	$00				;cursor position (0=start of line)
PRTFLAG:
		DEFB	$00				;printer flag (control-p toggle). List if non zero
CHARBUF:
		DEFB	$00				;single input character buffer
*	Stack area for BDOS calls.
USRSTACK:
		DEFB	$00,$00				;save users stack pointer here
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
*	end of stack area
STKAREA:
		DEFB	$00				;end of stack area
USERNO:
		DEFB	$00				;current user number
ACTIVE:
		DEFB	$00				;currently active drive
PARAMS:
		DEFB	$00,$00				;save DE parameters here on entry
STATUS:
		DEFB	$00,$00				;status returned from bdos function
*	Select error occured, jump to error routine.
SLCTERR:
		LD	HL,$E00B				;210BE0
*	Jump to (HL) indirectly.
JUMPHL:
		LD	E,(HL)				;5E
		INC	HL				;23
		LD	D,(HL)				;56		now DE contains the desired address
		EX	DE,HL				;EB
		JP	(HL)				;E9
*	Block move. DE to HL, C bytes total.
DE2HL:
		INC	C				;0C		is count down to zero?
DE2HL1:
		DEC	C				;0D
		RET	Z				;C8		yes, we are done.
		LD	A,(DE)				;1A		no, move one more byte
		LD	(HL),A				;77
		INC	DE				;13
		INC	HL				;23
		JP	DE2HL1				;C350E3		and repeat.
*	Select the desired drive.
SELECT:
		LD	A,(ACTIVE)				;3A42E3		get active disk
		LD	C,A				;4F
		CALL	SELDSK				;CD1BEE		select it.
		LD	A,H				;7C		valid drive?
		OR	L				;B5		valid drive?
		RET	Z				;C8		return if not.
*	Here, the BIOS returned the address of the parameter block in HL.
*	We will extract the necessary pointers and save them.
		LD	E,(HL)				;5E		yes, get address of translation table into DE
		INC	HL				;23
		LD	D,(HL)				;56
		INC	HL				;23
		LD	(SCRATCH1),HL				;22B3ED		save pointers to scratch areas.
		INC	HL				;23
		INC	HL				;23
		LD	(SCRATCH2),HL				;22B5ED		ditto.
		INC	HL				;23
		INC	HL				;23
		LD	(SCRATCH3),HL				;22B7ED		ditto.
		INC	HL				;23
		INC	HL				;23
		EX	DE,HL				;EB		now save the translation table address.
		LD	(XLATE),HL				;22D0ED
		LD	HL,DIRBUF				;21B9ED		put the next 8 bytes here.
		LD	C,$08				;0E08		they consist of the directory buffer
		CALL	DE2HL				;CD4FE3		pointer, parameter block pointer,
		LD	HL,(DISKPB)				;2ABBED		check and allocation vectors.
		EX	DE,HL				;EB
		LD	HL,SECTORS				;21C1ED		move parameter block into our ram.
		LD	C,$0F				;0E0F		it is 15 bytes long.
		CALL	DE2HL				;CD4FE3
		LD	HL,(DSKSIZE)				;2AC6ED		check disk size.
		LD	A,H				;7C		more than 256 blocks on this?
		LD	HL,BIGDISK				;21DDED
		LD	(HL),$FF				;36FF		set to samll.
		OR	A				;B7		check zero
		JP	Z,SELECT1				;CA9DE3
		LD	(HL),$00				;3600		wrong, set to large.
SELECT1:
		LD	A,$FF				;3EFF		clear the zero flag.
		OR	A				;B7		check zero
		RET				;C9
*	Routine to home the disk track head and clear pointers.
HOMEDRV:
		CALL	HOME				;CD18EE		home the head
		XOR	A				;AF		A = $00
		LD	HL,(SCRATCH2)				;2AB5ED		set our track pointer also
		LD	(HL),A				;77
		INC	HL				;23
		LD	(HL),A				;77
		LD	HL,(SCRATCH3)				;2AB7ED		and our sector pointer
		LD	(HL),A				;77
		INC	HL				;23
		LD	(HL),A				;77
		RET				;C9
		;   Do the actual disk read and check the error return status.
DOREAD:
		CALL	READ				;CD27EE
		JP	IORET				;C3BBE3
DOWRITE:
		CALL	WRITE				;CD2AEE
IORET:
		OR	A				;B7		check zero
		RET	Z				;C8		return unless an error occured
		LD	HL,BADSCTR				;2109E0		bad read/write on this sector.
		JP	JUMPHL				;C34AE3
*	Routine to select the track and sector that the desired
*	block number falls in.
TRKSEC:
		LD	HL,(FILEPOS)				;2AEAED		get position of last accessed file
		LD	C,$02				;0E02		in directory and compute sector #.
		CALL	SHIFTR				;CDEAE4		sector #=file-position/4.
		LD	(BLKNMBR),HL				;22E5ED		save this as the block number of interest
		LD	(CKSUMTBL),HL				;22ECED		what's it doing here too?
*	if the sector number has already been set (BLKNMBR), enter
*	at this point.
TRKSEC1:
		LD	HL,BLKNMBR				;21E5ED
		LD	C,(HL)				;4E		move sector number into BC
		INC	HL				;23
		LD	B,(HL)				;46
		LD	HL,(SCRATCH3)				;2AB7ED		get current sector number and
		LD	E,(HL)				;5E		move this into DE
		INC	HL				;23
		LD	D,(HL)				;56
		LD	HL,(SCRATCH2)				;2AB5ED		get current track number.
		LD	A,(HL)				;7E		and this into HL
		INC	HL				;23
		LD	H,(HL)				;66
		LD	L,A				;6F
TRKSEC2:
		LD	A,C				;79		is desired sector before current one?
		SUB	E				;93
		LD	A,B				;78
		SBC	A,D				;9A
		JP	NC,TRKSEC3				;D2FAE3
		PUSH	HL				;E5		yes, decrement sectors by one track.
		LD	HL,(SECTORS)				;2AC1ED		get sectors per track.
		LD	A,E				;7B
		SUB	L				;95
		LD	E,A				;5F
		LD	A,D				;7A
		SBC	A,H				;9C
		LD	D,A				;57		now we have backed up one full track.
		POP	HL				;E1
		DEC	HL				;2B		adjust track counter.
		JP	TRKSEC2				;C3E4E3
		desired sector is after current one.
TRKSEC3:
		PUSH	HL				;E5		get sectors per track.
		LD	HL,(SECTORS)				;2AC1ED		bump sector pointer to next track.
		ADD	HL,DE				;19
		JP	C,TRKSEC4				;DA0FE4		is desired sector now before current one?
		LD	A,C				;79
		SUB	L				;95
		LD	A,B				;78
		SBC	A,H				;9C
		JP	C,TRKSEC4				;DA0FE4		not yes, increment track counter
		EX	DE,HL				;EB		and continue until it is.
		POP	HL				;E1
		INC	HL				;23
		JP	TRKSEC3				;C3FAE3
*	here we have determined the track number that contains the
*	desired sector.
TRKSEC4:
		POP	HL				;E1		get track number HL
		PUSH	BC				;C5
		PUSH	DE				;D5
		PUSH	HL				;E5
		EX	DE,HL				;EB
		LD	HL,(OFFSET)				;2ACEED		adjust for first track offset.
		ADD	HL,DE				;19
		LD	B,H				;44
		LD	C,L				;4D
		CALL	SETTRK				;CD1EEE		select this track.
		POP	DE				;D1		reset current track pointer.
		LD	HL,(SCRATCH2)				;2AB5ED
		LD	(HL),E				;73
		INC	HL				;23
		LD	(HL),D				;72
		POP	DE				;D1
		LD	HL,(SCRATCH3)				;2AB7ED		reset the first sector on this track.
		LD	(HL),E				;73
		INC	HL				;23
		LD	(HL),D				;72
		POP	BC				;C1
		LD	A,C				;79		now subtract the desired one.
		SUB	E				;93		to make it relative (1-# sectors/track).
		LD	C,A				;4F
		LD	A,B				;78
		SBC	A,D				;9A
		LD	B,A				;47
		LD	HL,(XLATE)				;2AD0ED		translate this sector according to this table
		EX	DE,HL				;EB
		CALL	SECTRN				;CD30EE		let the bios translate it.
		LD	C,L				;4D
		LD	B,H				;44
		JP	SETSEC				;C321EE		and select it.
*	Compute block number from record number (SAVNREC) and
*	extent number (SAVEXT).
GETBLOCK:
		LD	HL,BLKSHFT				;21C3ED		get logical to physical conversion.
		LD	C,(HL)				;4E		note that this is base 2 log of ratio
		LD	A,(SAVNREC)				;3AE3ED		get record number.
GETBLK1:
		OR	A				;B7		compute A = A / 2^BLKSHFT.
		RRA				;1F
		DEC	C				;0D
		JP	NZ,GETBLK1				;C245E4
		LD	B,A				;47		save result in B
		LD	A,$08				;3E08
		SUB	(HL)				;96
		LD	C,A				;4F		compute C = 8 - BLKSHFT.
		LD	A,(SAVEXT)				;3AE2ED
GETBLK2:
		DEC	C				;0D		compute A = SAVEXT * 2^(8-BLKSHFT).
		JP	Z,GETBLK3				;CA5CE4
		OR	A				;B7		check zero
		RLA				;17
		JP	GETBLK2				;C353E4
GETBLK3:
		ADD	A,B				;80
		RET				;C9
*	Routine to extract the BC block byte from the fcb pointed
*	to by (PARAMS). If this is a big-disk, then these are 16 bit
*	block numbers, else they are 8 bit numbers
*	Number is returned in HL
EXTBLK:
		LD	HL,(PARAMS)				;2A43E3		get fcb address.
		LD	DE,$0010				;111000		block numbers start 16 bytes into fcb.
		ADD	HL,DE				;19
		ADD	HL,BC				;09
		LD	A,(BIGDISK)				;3ADDED		are we using a big-disk?
		OR	A				;B7		check zero
		JP	Z,EXTBLK1				;CA71E4
		LD	L,(HL)				;6E		no, extract an 8 bit number from the fcb
		LD	H,$00				;2600
		RET				;C9
EXTBLK1:
		ADD	HL,BC				;09		yes, extract a 16 bit number
		LD	E,(HL)				;5E
		INC	HL				;23
		LD	D,(HL)				;56
		EX	DE,HL				;EB		return in HL
		RET				;C9
*	Compute block number.
COMBLK:
		CALL	GETBLOCK				;CD3EE4
		LD	C,A				;4F
		LD	B,$00				;0600
		CALL	EXTBLK				;CD5EE4
		LD	(BLKNMBR),HL				;22E5ED
		RET				;C9
*	Check for a zero block number (unused).
CHKBLK:
		LD	HL,(BLKNMBR)				;2AE5ED
		LD	A,L				;7D		is it zero?
		OR	H				;B4
		RET				;C9
*	Adjust physical block (BLKNMBR) and convert to logical
*	sector (LOGSECT). This is the starting sector of this block.
*	The actual sector of interest is then added to this and the
*	resulting sector number is stored back in (BLKNMBR). This
*	will still have to be adjusted for the track number.
LOGICAL:
		LD	A,(BLKSHFT)				;3AC3ED		get log2(physical/logical sectors).
		LD	HL,(BLKNMBR)				;2AE5ED		get physical sector desired.
LOGICL1:
		ADD	HL,HL				;29		compute logical sector number.
		DEC	A				;3D		note logical sectors are 128 bytes long.
		JP	NZ,LOGICL1				;C290E4
		LD	(LOGSECT),HL				;22E7ED		save logical sector.
		LD	A,(BLKMASK)				;3AC4ED		get block mask.
		LD	C,A				;4F
		LD	A,(SAVNREC)				;3AE3ED		get next sector to access.
		AND	C				;A1		extract the relative position within physical block
		OR	L				;B5		and add it too logical sector.
		LD	L,A				;6F
		LD	(BLKNMBR),HL				;22E5ED		and store
		RET				;C9
*	Set (HL) to point to extent byte in fcb.
SETEXT:
		LD	HL,(PARAMS)				;2A43E3
		LD	DE,$000C				;110C00
		ADD	HL,DE				;19		it is the twelth byte
		RET				;C9
*	Set HL to point to record count byte in fcb and DE to
*	next record number byte.
SETHLDE:
		LD	HL,(PARAMS)				;2A43E3
		LD	DE,$000F				;110F00		record count byte (#15)
		ADD	HL,DE				;19
		EX	DE,HL				;EB
		LD	HL,$0011				;211100		next record number (#32)
		ADD	HL,DE				;19
		RET				;C9
*	Save current file data from fcb.
STRDATA:
		CALL	SETHLDE				;CDAEE4
		LD	A,(HL)				;7E		get and store record count byte.
		LD	(SAVNREC),A				;32E3ED
		EX	DE,HL				;EB
		LD	A,(HL)				;7E		get and store next record number byte
		LD	(SAVNXT),A				;32E1ED
		CALL	SETEXT				;CDA6E4		point to extent byte.
		LD	A,(EXTMASK)				;3AC5ED		get extent mask.
		AND	(HL)				;A6
		LD	(SAVEXT),A				;32E2ED		and save extent here.
		RET				;C9
*	Set the next record to access. If (MODE) is set to 2, then
*	the last record byte (SAVNREC) has the correct number to access.
*	For sequential access, (MODE) will be equal to 1.
SETNREC:
		CALL	SETHLDE				;CDAEE4
		LD	A,(MODE)				;3AD5ED		get sequential flag (=1).
		CP	$02				;FE02		a 2 indicates that no adder is needed.
		JP	NZ,STNREC1				;C2DEE4
		XOR	A				;AF		clear adder (random access?). A = $00
STNREC1:
		LD	C,A				;4F
		LD	A,(SAVNREC)				;3AE3ED		get last record number.
		ADD	A,C				;81		increment record count.
		LD	(HL),A				;77		and set fcb's next record byte.
		EX	DE,HL				;EB
		LD	A,(SAVNXT)				;3AE1ED		get next record byte from storage.
		LD	(HL),A				;77		and put this into fcb as number of records used
		RET				;C9
*	Shift HL right C bits.
SHIFTR:
		INC	C				;0C
SHIFTR1:
		DEC	C				;0D
		RET	Z				;C8
		LD	A,H				;7C
		OR	A				;B7		check zero
		RRA				;1F
		LD	H,A				;67
		LD	A,L				;7D
		RRA				;1F
		LD	L,A				;6F
		JP	SHIFTR1				;C3EBE4
*	Compute the check-sum for the directory buffer. Return
*	integer sum in A
CHECKSUM:
		LD	C,$80				;0E80		length of buffer.
		LD	HL,(DIRBUF)				;2AB9ED		get its location.
		XOR	A				;AF		clear summation byte - A = $00
CHKSUM1:
		ADD	A,(HL)				;86		and compute sum ignoring carries
		INC	HL				;23
		DEC	C				;0D
		JP	NZ,CHKSUM1				;C2FDE4
		RET				;C9
*	Shift HL left C bits.
SHIFTL:
		INC	C				;0C
SHIFTL1:
		DEC	C				;0D
		RET	Z				;C8
		ADD	HL,HL				;29		shift left 1 bit
		JP	SHIFTL1				;C305E5
*	Routine to set a bit in a 16 bit value contained in BC
*	The bit set depends on the current drive selection.
SETBIT:
		PUSH	BC				;C5		save 16 bit word.
		LD	A,(ACTIVE)				;3A42E3		get active drive.
		LD	C,A				;4F
		LD	HL,$0001				;210100
		CALL	SHIFTL				;CD04E5		shift bit 0 into place.
		POP	BC				;C1		now 'or' this with the original word
		LD	A,C				;79
		OR	L				;B5
		LD	L,A				;6F		low byte done, do high byte.
		LD	A,B				;78
		OR	H				;B4
		LD	H,A				;67
		RET				;C9
*	Extract the write protect status bit for the current drive.
*	The result is returned in A, bit 0.
GETWPRT:
		LD	HL,(WRTPRT)				;2AADED		get status bytes.
		LD	A,(ACTIVE)				;3A42E3		which drive is current?
		LD	C,A				;4F
		CALL	SHIFTR				;CDEAE4		shift status such that bit 0 is the
		LD	A,L				;7D		one of interest for this drive.
		AND	$01				;E601		and isolate it.
		RET				;C9
*	BDOS function 28 to write protect the current disk.
WRTPRTD:
		LD	HL,WRTPRT				;21ADED		point to status word.
		LD	C,(HL)				;4E		set BC equal to the status.
		INC	HL				;23
		LD	B,(HL)				;46
		CALL	SETBIT				;CD0BE5		and set this bit according to current drive
		LD	(WRTPRT),HL				;22ADED		then save.
		LD	HL,(DIRSIZE)				;2AC8ED		now save directory size limit.
		INC	HL				;23		remember the last one.
		EX	DE,HL				;EB
		LD	HL,(SCRATCH1)				;2AB3ED		and store it here.
		LD	(HL),E				;73		put low byte.
		INC	HL				;23
		LD	(HL),D				;72		then high byte.
		RET				;C9
*	Check for a read only file.
CHKROFL:
		CALL	FCB2HL				;CD5EE5
CKROF1:
		LD	DE,$0009				;110900		set HL to file entry in directory buffer
		ADD	HL,DE				;19		look at bit 7 of the ninth byte.
		LD	A,(HL)				;7E
		RLA				;17
		RET	NC				;D0
		LD	HL,ROFILE				;210FE0		return if ok.
		JP	JUMPHL				;C34AE3		else, print error message and terminate.
*	Check the write protect status of the active disk.
CHKWPRT:
		CALL	GETWPRT				;CD1EE5
		RET	Z				;C8		return if ok.
		LD	HL,RODISK				;210DE0		else print message and terminate
		JP	JUMPHL				;C34AE3
*	Routine to set (HL) pointing to the proper entry in the
*	directory buffer.
FCB2HL:
		LD	HL,(DIRBUF)				;2AB9ED		get address of buffer.
		LD	A,(FCBPOS)				;3AE9ED		relative position of file
*	Routine to add A to HL
ADDA2HL:
		ADD	A,L				;85
		LD	L,A				;6F
		RET	NC				;D0
		INC	H				;24
		RET				;C9		take care of any carry
*	Routine to get the 'S2' byte from the fcb supplied in
*	the initial parameter specification.
GETS2:
		LD	HL,(PARAMS)				;2A43E3		get address of fcb.
		LD	DE,$000E				;110E00		relative position of 's2'
		ADD	HL,DE				;19
		LD	A,(HL)				;7E		extract this byte.
		RET				;C9
*	Clear the 'S2' byte in the fcb.
CLEARS2:
		CALL	GETS2				;CD69E5
		LD	(HL),$00				;3600		this sets HL pointing to it
		RET				;C9		now clear it.
*	Set bit 7 in the 'S2' byte of the fcb.
SETS2B7:
		CALL	GETS2				;CD69E5		get the byte.
		OR	$80				;F680		and set bit 7
		LD	(HL),A				;77		then store.
		RET				;C9
*	Compare (FILEPOS) with (SCRATCH1) and set flags based on
*	the difference. This checks to see if there are more file
*	names in the directory. We are at (FILEPOS) and there are
*	(SCRATCH1) of them to check.
MOREFLS:
		LD	HL,(FILEPOS)				;2AEAED		we are here.
		EX	DE,HL				;EB
		LD	HL,(SCRATCH1)				;2AB3ED		and don't go past here.
		LD	A,E				;7B		compute difference but don't keep
		SUB	(HL)				;96
		INC	HL				;23
		LD	A,D				;7A
		SBC	A,(HL)				;9E		set carry if no more names.
		RET				;C9
*	Call this routine to prevent (SCRATCH1) from being greater
*	than (FILEPOS).
CHKNMBR:
		CALL	MOREFLS				;CD7FE5		SCRATCH1 too big?
		RET	C				;D8
		INC	DE				;13		yes, reset it to (FILEPOS)
		LD	(HL),D				;72
		DEC	HL				;2B
		LD	(HL),E				;73
		RET				;C9
*	Compute HL = DE - HL
SUBHL:
		LD	A,E				;7B		compute difference
		SUB	L				;95
		LD	L,A				;6F		store low byte.
		LD	A,D				;7A
		SBC	A,H				;9C
		LD	H,A				;67		and then high byte
		RET				;C9
*	Set the directory checksum byte.
SETDIR:
		LD	C,$FF				;0EFF
*	Routine to set or compare the directory checksum byte. If
*	C = 0ffh, then this will set the checksum byte. Else the byte
*	will be checked. If the check fails (the disk has been changed),
*	then this disk will be write protected.
CHECKDIR:
		LD	HL,(CKSUMTBL)				;2AECED
		EX	DE,HL				;EB
		LD	HL,(ALLOC1)				;2ACCED
		CALL	SUBHL				;CD95E5
		RET	NC				;D0		ok if (CKSUMTBL) > (ALLOC1), so return.
		PUSH	BC				;C5
		CALL	CHECKSUM				;CDF7E4		else compute checksum.
		LD	HL,(CHKVECT)				;2ABDED		get address of checksum table.
		EX	DE,HL				;EB
		LD	HL,(CKSUMTBL)				;2AECED
		ADD	HL,DE				;19		set HL to point to byte for this drive
		POP	BC				;C1
		INC	C				;0C		set or check ?
		JP	Z,CHKDIR1				;CAC4E5
		CP	(HL)				;BE		check them.
		RET	Z				;C8		return if they are the same.
		CALL	MOREFLS				;CD7FE5		not the same, do we care?
		RET	NC				;D0
		CALL	WRTPRTD				;CD2CE5		yes, mark this as write protected.
		RET				;C9
CHKDIR1:
		LD	(HL),A				;77		just set the byte
		RET				;C9
*	Do a write to the directory of the current disk.
DIRWRITE:
		CALL	SETDIR				;CD9CE5		set checksum byte.
		CALL	DIRDMA				;CDE0E5		set directory dma address.
		LD	C,$01				;0E01		tell the bios to actually write
		CALL	DOWRITE				;CDB8E3		then do the write.
		JP	DEFDMA				;C3DAE5
*	Read from the directory.
DIRREAD:
		CALL	DIRDMA				;CDE0E5		set the directory dma address
		CALL	DOREAD				;CDB2E3		and read it.
*	Routine to set the dma address to the users choice.
DEFDMA:
		LD	HL,USERDMA				;21B1ED
		JP	DIRDMA1				;C3E3E5		reset the default dma address and return
*	Routine to set the dma address for directory work.
DIRDMA:
		LD	HL,DIRBUF				;21B9ED
*	Set the dma address. On entry, HL points to
*	word containing the desired dma address.
DIRDMA1:
		LD	C,(HL)				;4E
		INC	HL				;23
		LD	B,(HL)				;46		setup BC and go to the bios to set it
		JP	SETDMA				;C324EE
*	Move the directory buffer into user's dma space.
MOVEDIR:
		LD	HL,(DIRBUF)				;2AB9ED		buffer is located here, and
		EX	DE,HL				;EB
		LD	HL,(USERDMA)				;2AB1ED		put it here.
		LD	C,$80				;0E80		this is its length.
		JP	DE2HL				;C34FE3		move it now and return.
*	Check (FILEPOS) and set the zero flag if it equals 0ffffh.
CKFILPOS:
		LD	HL,FILEPOS				;21EAED
		LD	A,(HL)				;7E
		INC	HL				;23
		CP	(HL)				;BE		are both bytes the same?
		RET	NZ				;C0
		INC	A				;3C		yes, but are they each 0ffh?
		RET				;C9
*	Set location (FILEPOS) to 0ffffh.
STFILPOS:
		LD	HL,$FFFF				;21FFFF
		LD	(FILEPOS),HL				;22EAED
		RET				;C9
*	Move on to the next file position within the current
*	directory buffer. If no more exist, set pointer to 0ffffh
*	and the calling routine will check for this. Enter with C
*	equal to 0ffh to cause the checksum byte to be set, else we
*	will check this disk and set write protect if checksums are
*	not the same (applies only if another directory sector must
*	be read)
NXENTRY:
		LD	HL,(DIRSIZE)				;2AC8ED		get directory entry size limit.
		EX	DE,HL				;EB
		LD	HL,(FILEPOS)				;2AEAED		get current count.
		INC	HL				;23		go on to the next one.
		LD	(FILEPOS),HL				;22EAED
		CALL	SUBHL				;CD95E5		HL = (DIRSIZE)-(FILEPOS)
		JP	NC,NXENT1				;D219E6		is there more room left?
		JP	STFILPOS				;C3FEE5		no. Set this flag and return
NXENT1:
		LD	A,(FILEPOS)				;3AEAED		get file position within directory
		AND	$03				;E603		only look within this sector (only 4 entries fit)
		LD	B,$05				;0605		convert to relative position (32 bytes each)
NXENT2:
		ADD	A,A				;87		note that this is not efficient code.
		DEC	B				;05		5 'ADD As would be better
		JP	NZ,NXENT2				;C220E6		save it as position of fcb
		LD	(FCBPOS),A				;32E9ED
		OR	A				;B7		check zero
		RET	NZ				;C0		return if we are within buffer
		PUSH	BC				;C5
		CALL	TRKSEC				;CDC3E3		we need the next directory sector
		CALL	DIRREAD				;CDD4E5
		POP	BC				;C1
		JP	CHECKDIR				;C39EE5
*	compute BC = BC/8.
CKBITMAP:
		LD	A,C				;79
		AND	$07				;E607		determine bit number of interest
		INC	A				;3C		compute (D = E = C and 7)+1.
		LD	E,A				;5F
		LD	D,A				;57		save particular bit number.
		LD	A,C				;79
		RRCA				;0F
		RRCA				;0F
		RRCA				;0F		now shift right 3 bits.
		AND	$1F				;E61F		and clear bits 7,6,5.
		LD	C,A				;4F
		LD	A,B				;78
		ADD	A,A				;87
		ADD	A,A				;87		now shift B into bits 7,6,5.
		ADD	A,A				;87
		ADD	A,A				;87
		ADD	A,A				;87
		OR	C				;B1
		LD	C,A				;4F		and add in C
		LD	A,B				;78		ok, C has been completed
		RRCA				;0F		is there a better way of doing this?
		RRCA				;0F
		RRCA				;0F
		AND	$1F				;E61F
		LD	B,A				;47
*	use this as an offset into the disk space allocation table
		LD	HL,(ALOCVECT)				;2ABFED		and now B is completed.
		ADD	HL,BC				;09
		LD	A,(HL)				;7E		now get correct byte.
CKBMAP1:
		RLCA				;07		get correct bit into position 0
		DEC	E				;1D
		JP	NZ,CKBMAP1				;C256E6
		RET				;C9
*	Set or clear the bit map such that block number BC will be marked
*	as used. On entry, if E = 0 then this bit will be cleared, if it equals
*	1 then it will be set (don't use any other values).
STBITMAP:
		PUSH	DE				;D5
		CALL	CKBITMAP				;CD35E6		get the byte of interest.
		AND	$FE				;E6FE		clear the affected bit.
		POP	BC				;C1
		OR	C				;B1		and now set it acording to C
*	entry to restore the original bit position and then store
*	in table. A contains the value, D contains the bit
*	position (1-8), and HL points to the address within the
*	space allocation table for this byte.
STBMAP1:
		RRCA				;0F		restore original bit position
		DEC	D				;15
		JP	NZ,STBMAP1				;C264E6
		LD	(HL),A				;77		and store byte in table.
		RET				;C9
*	Set/clear space used bits in allocation map for this file.
*	On entry, C = 1 to set the map and C = 0 to clear it.
SETFILE:
		CALL	FCB2HL				;CD5EE5		get address of fcb
		LD	DE,$0010				;111000
		ADD	HL,DE				;19		get to block number bytes.
		PUSH	BC				;C5
		LD	C,$11				;0E11		check all 17 bytes (max) of table.
SETFL1:
		POP	DE				;D1
		DEC	C				;0D		done all bytes yet?
		RET	Z				;C8
		PUSH	DE				;D5
		LD	A,(BIGDISK)				;3ADDED		check disk size for 16 bit block numbers
		OR	A				;B7		check zero
		JP	Z,SETFL2				;CA88E6
		PUSH	BC				;C5		only 8 bit numbers. set BC to this one
		PUSH	HL				;E5
		LD	C,(HL)				;4E		get low byte from table, always
		LD	B,$00				;0600		set high byte to zero.
		JP	SETFL3				;C38EE6
		for 16 bit block numbers, adjust counter
SETFL2:
		DEC	C				;0D
		PUSH	BC				;C5		now get both the low and high bytes.
		LD	C,(HL)				;4E
		INC	HL				;23
		LD	B,(HL)				;46
		PUSH	HL				;E5		block used?
SETFL3:
		LD	A,C				;79
		OR	B				;B0
		JP	Z,SETFL4				;CA9DE6		is this block number within the
		LD	HL,(DSKSIZE)				;2AC6ED		space on the disk?
		LD	A,L				;7D
		SUB	C				;91
		LD	A,H				;7C
		SBC	A,B				;98		yes, set the proper bit.
		CALL	NC,STBITMAP				;D45CE6		point to next block number in fcb.
SETFL4:
		POP	HL				;E1
		INC	HL				;23
		POP	BC				;C1
		JP	SETFL1				;C375E6
*	Construct the space used allocation bit map for the active
*	drive. If a file name starts with '$' and it is under the
*	current user number, then (STATUS) is set to minus 1. Otherwise
*	it is not set at all.
BITMAP:
		LD	HL,(DSKSIZE)				;2AC6ED		compute size of allocation table.
		LD	C,$03				;0E03
		CALL	SHIFTR				;CDEAE4		HL = HL/8.
		INC	HL				;23		at lease 1 byte.
		LD	B,H				;44
		LD	C,L				;4D
*	Initialize the bitmap for this drive. Right now,set BC to the allocation table length the first
*	two bytes are specified by the disk parameter block. However
*	a patch could be entered here if it were necessary to setup
*	this table in a special manner. For example, the bios could
*	determine locations of 'bad blocks' and set them as already
*	'used' in the map.
		LD	HL,(ALOCVECT)				;2ABFED		now zero out the table now.
BITMAP1:
		LD	(HL),$00				;3600
		INC	HL				;23
		DEC	BC				;0B
		LD	A,B				;78
		OR	C				;B1
		JP	NZ,BITMAP1				;C2B1E6
		LD	HL,(ALLOC0)				;2ACAED		get initial space used by directory
		EX	DE,HL				;EB
		LD	HL,(ALOCVECT)				;2ABFED		and put this into map.
		LD	(HL),E				;73
		INC	HL				;23
		LD	(HL),D				;72
*	End of initialization portion.
		CALL	HOMEDRV				;CDA1E3
		LD	HL,(SCRATCH1)				;2AB3ED		now home the drive.
		LD	(HL),$03				;3603
		INC	HL				;23		force next directory request to read
		LD	(HL),$00				;3600		in a sector.
		CALL	STFILPOS				;CDFEE5
BITMAP2:
		LD	C,$FF				;0EFF		clear initial file position also.
		CALL	NXENTRY				;CD05E6		read next file name in directory
		CALL	CKFILPOS				;CDF5E5		and set checksum byte.
		RET	Z				;C8		is there another file?
		CALL	FCB2HL				;CD5EE5
		LD	A,$E5				;3EE5		yes, get its address.
		CP	(HL)				;BE
		JP	Z,BITMAP2				;CAD2E6		empty file entry?
		LD	A,(STKAREA)				;3A41E3
		CP	(HL)				;BE		no, correct user number?
		JP	NZ,BITMAP3				;C2F6E6
		INC	HL				;23
		LD	A,(HL)				;7E
		SUB	$24				;D624		yes, does name start with a '$'?
		JP	NZ,BITMAP3				;C2F6E6
		DEC	A				;3D
		LD	(STATUS),A				;3245E3		yes, set atatus to minus one.
BITMAP3:
		LD	C,$01				;0E01
		CALL	SETFILE				;CD6BE6		now set this file's space as used in bit map
		CALL	CHKNMBR				;CD8CE5
		JP	BITMAP2				;C3D2E6		keep (SCRATCH1) in bounds.
*	Set the status (STATUS) and return.
STSTATUS:
		LD	A,(FNDSTAT)				;3AD4ED
		JP	SETSTAT				;C301E3
*	Check extents in A and C. Set the zero flag if they
*	are the same. The number of 16k chunks of disk space that
*	the directory extent covers is expressad is (EXTMASK+1).
*	No registers are modified.
SAMEXT:
		PUSH	BC				;C5
		PUSH	AF				;F5
		LD	A,(EXTMASK)				;3AC5ED		get extent mask and use it to
		CPL				;2F		to compare both extent numbers.
		LD	B,A				;47		save resulting mask here.
		LD	A,C				;79		mask first extent and save in C
		AND	B				;A0
		LD	C,A				;4F
		POP	AF				;F1		now mask second extent and compare
		AND	B				;A0		with the first one.
		SUB	C				;91
		AND	$1F				;E61F		(* only check buts 0-4 *)
		POP	BC				;C1		the zero flag is set if they are the same
		RET				;C9		restore BC and return.
*	Search for the first occurence of a file name. On entry,
*	register C should contain the number of bytes of the fcb
*	that must match.
FINDFST:
		LD	A,$FF				;3EFF
		LD	(FNDSTAT),A				;32D4ED
		LD	HL,COUNTER				;21D8ED		save character count.
		LD	(HL),C				;71
		LD	HL,(PARAMS)				;2A43E3		get filename to match.
		LD	(SAVEFCB),HL				;22D9ED		and save.
		CALL	STFILPOS				;CDFEE5		clear initial file position (set to 0ffffh)
		CALL	HOMEDRV				;CDA1E3		home the drive.
*	Entry to locate the next occurence of a filename within the
*	directory. The disk is not expected to have been changed. If
*	it was, then it will be write protected.
FINDNXT:
		LD	C,$00				;0E00		write protect the disk if changed.
		CALL	NXENTRY				;CD05E6		get next filename entry in directory.
		CALL	CKFILPOS				;CDF5E5		is file position = 0ffffh?
		JP	Z,FNDNXT6				;CA94E7		yes, exit now then.
		LD	HL,(SAVEFCB)				;2AD9ED		set DE pointing to filename to match.
		EX	DE,HL				;EB
		LD	A,(DE)				;1A
		CP	$E5				;FEE5		empty directory entry?
		JP	Z,FNDNXT1				;CA4AE7		(* are we trying to reserect erased entries? *)
		PUSH	DE				;D5
		CALL	MOREFLS				;CD7FE5		more files in directory?
		POP	DE				;D1
		JP	NC,FNDNXT6				;D294E7		no more. Exit now.
FNDNXT1:
		CALL	FCB2HL				;CD5EE5		get address of this fcb in directory.
		LD	A,(COUNTER)				;3AD8ED		get number of bytes (characters) to check.
		LD	C,A				;4F
		LD	B,$00				;0600		initialize byte position counter.
FNDNXT2:
		LD	A,C				;79		are we done with the compare?
		OR	A				;B7		check zero
		JP	Z,FNDNXT5				;CA83E7
		LD	A,(DE)				;1A		no, check next byte.
		CP	$3F				;FE3F		don't care about this character?
		JP	Z,FNDNXT4				;CA7CE7
		LD	A,B				;78		get bytes position in fcb.
		CP	$0D				;FE0D		don't care about the thirteenth byte either.
		JP	Z,FNDNXT4				;CA7CE7
		CP	$0C				;FE0C		extent byte?
		LD	A,(DE)				;1A
		JP	Z,FNDNXT3				;CA73E7
		SUB	(HL)				;96		otherwise compare characters.
		AND	$7F				;E67F		mask bit 7
		JP	NZ,FINDNXT				;C22DE7		not the same, check next entry.
		JP	FNDNXT4				;C37CE7		so far so good, keep checking.
		check the extent byte here.
FNDNXT3:
		PUSH	BC				;C5
		LD	C,(HL)				;4E
		CALL	SAMEXT				;CD07E7
		POP	BC				;C1		not the same, look some more.
		JP	NZ,FINDNXT				;C22DE7
*	So far the names compare. Bump pointers to the next byte
*	and continue until all C characters have been checked.
FNDNXT4:
		INC	DE				;13		bump pointers.
		INC	HL				;23
		INC	B				;04
		DEC	C				;0D		adjust character counter.
		JP	FNDNXT2				;C353E7
FNDNXT5:
		LD	A,(FILEPOS)				;3AEAED		return the position of this entry
		AND	$03				;E603
		LD	(STATUS),A				;3245E3
		LD	HL,FNDSTAT				;21D4ED
		LD	A,(HL)				;7E
		RLA				;17
		RET	NC				;D0
		XOR	A				;AF		A = $00
		LD	(HL),A				;77
		RET				;C9
*	Filename was not found. Set appropriate status.
FNDNXT6:
		CALL	STFILPOS				;CDFEE5		set (FILEPOS) to 0ffffh
		LD	A,$FF				;3EFF		say not located.
		JP	SETSTAT				;C301E3
*	Erase files from the directory. Only the first byte of the
*	fcb will be affected. It is set to $E5.
ERAFILE:
		CALL	CHKWPRT				;CD54E5		is disk write protected?
		LD	C,$0C				;0E0C		only compare file names.
		CALL	FINDFST				;CD18E7		get first file name.
ERAFIL1:
		CALL	CKFILPOS				;CDF5E5		any found?
		RET	Z				;C8		nope, we must be done.
		CALL	CHKROFL				;CD44E5		is file read only?
		CALL	FCB2HL				;CD5EE5		nope, get address of fcb and
		LD	(HL),$E5				;36E5		set first byte to 'empty'.
		LD	C,$00				;0E00		clear the space from the bit map.
		CALL	SETFILE				;CD6BE6
		CALL	DIRWRITE				;CDC6E5		now write the directory sector back out
		CALL	FINDNXT				;CD2DE7		find the next file name.
		JP	ERAFIL1				;C3A4E7		and repeat process.
*	Look through the space allocation map (bit map) for the
*	next available block. Start searching at block number (BC-1).
*	The search procedure is to look for an empty block that is
*	before the starting block. If not empty, look at a later
*	block number. In this way, we return the closest empty block
*	on either side of the 'target' block number. This will speed
*	access on random devices. For serial devices, this should be
*	changed to look in the forward direction first and then start
*	at the front and search some more.
*
*	On return, DE = block number that is empty and HL = 0
*	if no empry block was found.
FNDSPACE:
		LD	D,B				;50		set DE as the block that is checked
		LD	E,C				;59
*	Look before target block. Registers BC are used as the lower
*	pointer and DE as the upper pointer.
FNDSPA1:
		LD	A,C				;79		is block 0 specified?
		OR	B				;B0
		JP	Z,FNDSPA2				;CAD1E7
		DEC	BC				;0B		nope, check previous block
		PUSH	DE				;D5
		PUSH	BC				;C5
		CALL	CKBITMAP				;CD35E6		get the byte of interest.
		RRA				;1F
		JP	NC,FNDSPA3				;D2ECE7
*	Note that the above logic gets the first block that it finds
*	that is empty. Thus a file could be written 'backward' making
*	it very slow to access. This could be changed to look for the
*	first empty block and then continue until the start of this
*	empty space is located and then used that starting block.
*	This should help speed up access to some files especially on
*	a well used disk with lots of fairly small 'holes'.
		POP	BC				;C1
		POP	DE				;D1
FNDSPA2:
		LD	HL,(DSKSIZE)				;2AC6ED		is block DE within disk limits?
		LD	A,E				;7B
		SUB	L				;95
		LD	A,D				;7A
		SBC	A,H				;9C
		JP	NC,FNDSPA4				;D2F4E7
		INC	DE				;13		yes, move on to next one.
		PUSH	BC				;C5
		PUSH	DE				;D5
		LD	B,D				;42
		LD	C,E				;4B
		CALL	CKBITMAP				;CD35E6		check it.
		RRA				;1F		empty?
		JP	NC,FNDSPA3				;D2ECE7
		POP	DE				;D1		nope, continue searching.
		POP	BC				;C1
		JP	FNDSPA1				;C3C0E7
*	Empty block found. Set it as used and return with HL
*	pointing to it (true?).
FNDSPA3:
		RLA				;17		reset byte.
		INC	A				;3C		and set bit 0.
		CALL	STBMAP1				;CD64E6		update bit map.
		POP	HL				;E1		set return registers
		POP	DE				;D1
		RET				;C9
*	Free block was not found. If BC is not zero, then we have
*	not checked all of the disk space.
FNDSPA4:
		LD	A,C				;79
		OR	B				;B0
		JP	NZ,FNDSPA1				;C2C0E7
		LD	HL,$0000				;210000		set 'not found' status
		RET				;C9
*	Move a complete fcb entry into the directory and write it.
FCBSET:
		LD	C,$00				;0E00
		LD	E,$20				;1E20		length of each entry
*	Move E bytes from the fcb pointed to by (PARAMS) into
*	fcb in directory starting at relative byte C. This updated
*	directory buffer is then written to the disk.
UPDATE:
		PUSH	DE				;D5
		LD	B,$00				;0600		set BC to relative byte position.
		LD	HL,(PARAMS)				;2A43E3		get address of fcb.
		ADD	HL,BC				;09		compute starting byte.
		EX	DE,HL				;EB
		CALL	FCB2HL				;CD5EE5		get address of fcb to update in directory
		POP	BC				;C1		set C to number of bytes to change.
		CALL	DE2HL				;CD4FE3
UPDATE1:
		CALL	TRKSEC				;CDC3E3		determine the track and sector affected.
		JP	DIRWRITE				;C3C6E5		then write this sector out.
*	Routine to change the name of all files on the disk with a
*	specified name. The fcb contains the current name as the
*	first 12 characters and the new name 16 bytes into the fcb.
CHGNAMES:
		CALL	CHKWPRT				;CD54E5		check for a write protected disk.
		LD	C,$0C				;0E0C		match first 12 bytes of fcb only.
		CALL	FINDFST				;CD18E7		get first name.
		LD	HL,(PARAMS)				;2A43E3		get address of fcb.
		LD	A,(HL)				;7E		get user number.
		LD	DE,$0010				;111000		move over to desired name.
		ADD	HL,DE				;19
		LD	(HL),A				;77		keep same user number.
CHGNAM1:
		CALL	CKFILPOS				;CDF5E5		any matching file found?
		RET	Z				;C8		no, we must be done.
		CALL	CHKROFL				;CD44E5		check for read only file.
		LD	C,$10				;0E10		start 16 bytes into fcb.
		LD	E,$0C				;1E0C		and update the first 12 bytes of directory
		CALL	UPDATE				;CD01E8
		CALL	FINDNXT				;CD2DE7		get te next file name.
		JP	CHGNAM1				;C327E8		and continue.
*	Update a files attributes. The procedure is to search for
*	every file with the same name as shown in fcb (ignoring bit 7)
*	and then to update it (which includes bit 7). No other changes
*	are made.
SAVEATTR:
		LD	C,$0C				;0E0C		match first 12 bytes.
		CALL	FINDFST				;CD18E7		look for first filename.
SAVEATTR:
		CALL	CKFILPOS				;CDF5E5		was one found?
		RET	Z				;C8		nope, we must be done.
		LD	C,$00				;0E00		yes, update the first 12 bytes now.
		LD	E,$0C				;1E0C
		CALL	UPDATE				;CD01E8		update filename and write directory
		CALL	FINDNXT				;CD2DE7		and get the next file.
		JP	SAVEATTR				;C340E8		then continue until done.
*	Open a file (name specified in fcb).
OPENIT:
		LD	C,$0F				;0E0F		compare the first 15 bytes.
		CALL	FINDFST				;CD18E7		get the first one in directory.
		CALL	CKFILPOS				;CDF5E5		any at all?
		RET	Z				;C8
OPENIT1:
		CALL	EXTMASK				;CDA6E4		point to extent byte within users fcb.
		LD	A,(HL)				;7E		and get it.
		PUSH	AF				;F5		save it and address.
		PUSH	HL				;E5
		CALL	FCB2HL				;CD5EE5		point to fcb in directory.
		EX	DE,HL				;EB
		LD	HL,(PARAMS)				;2A43E3		this is the users copy.
		LD	C,$20				;0E20		move it into users space.
		PUSH	DE				;D5
		CALL	DE2HL				;CD4FE3
		CALL	SETS2B7				;CD78E5		set bit 7 in 's2' byte (unmodified).
		POP	DE				;D1		now get the extent byte from this fcb.
		LD	HL,$000C				;210C00
		ADD	HL,DE				;19
		LD	C,(HL)				;4E		into C
		LD	HL,$000F				;210F00		now get the record count byte into B
		ADD	HL,DE				;19
		LD	B,(HL)				;46
		POP	HL				;E1		keep the same extent as the user had originally.
		POP	AF				;F1
		LD	(HL),A				;77
		LD	A,C				;79		is it the same as in the directory fcb?
		CP	(HL)				;BE
		LD	A,B				;78		if yes, then use the same record count.
		JP	Z,OPENIT2				;CA8BE8
		LD	A,$00				;3E00		if the user specified an extent greater than
		JP	C,OPENIT2				;DA8BE8		the one in the directory, then set record count to 0
		LD	A,$80				;3E80		otherwise set to maximum.
OPENIT2:
		LD	HL,(PARAMS)				;2A43E3		set record count in users fcb to A
		LD	DE,$000F				;110F00
		ADD	HL,DE				;19		compute relative position.
		LD	(HL),A				;77		and set the record count.
		RET				;C9
*	Move two bytes from DE to HL if (and only if) HL point to a zero value (16 bit).
*	Return with zero flag set it DE was moved. Registers DE	and HL are not changed. However A is.
MOVEWORD:
		LD	A,(HL)				;7E		check for a zero word.
		INC	HL				;23
		OR	(HL)				;B6		both bytes zero?
		DEC	HL				;2B
		RET	NZ				;C0		nope, just return.
		LD	A,(DE)				;1A		yes, move two bytes from DE into
		LD	(HL),A				;77		this zero space.
		INC	DE				;13
		INC	HL				;23
		LD	A,(DE)				;1A
		LD	(HL),A				;77
		DEC	DE				;1B		don't disturb these registers.
		DEC	HL				;2B
		RET				;C9
*	Get here to close a file specified by (fcb).
CLOSEIT:
		XOR	A				;AF		clear status and file position bytes.A = $00
		LD	(STATUS),A				;3245E3
		LD	(FILEPOS),A				;32EAED
		LD	(FILEPOS+1),A				;32EBED
		CALL	GETWPRT				;CD1EE5		get write protect bit for this drive.
		RET	NZ				;C0		just return if it is set.
		CALL	GETS2				;CD69E5		else get the 's2' byte.
		AND	$80				;E680		and look at bit 7 (file unmodified?).
		RET	NZ				;C0		just return if set.
		LD	C,$0F				;0E0F		else look up this file in directory.
		CALL	FINDFST				;CD18E7
		CALL	CKFILPOS				;CDF5E5		was it found?
		RET	Z				;C8		just return if not.
		LD	BC,$0010				;011000		set HL pointing to records used section.
		CALL	FCB2HL				;CD5EE5
		ADD	HL,BC				;09
		EX	DE,HL				;EB
		LD	HL,(PARAMS)				;2A43E3		do the same for users specified fcb.
		ADD	HL,BC				;09
		LD	C,$10				;0E10		this many bytes are present in this extent.
CLOSEIT1:
		LD	A,(BIGDISK)				;3ADDED		8 or 16 bit record numbers?
		OR	A				;B7		check zero
		JP	Z,CLOSEIT4				;CAE8E8
		LD	A,(HL)				;7E		just 8 bit. Get one from users fcb.
		OR	A				;B7		check zero
		LD	A,(DE)				;1A		now get one from directory fcb.
		JP	NZ,CLOSEIT2				;C2DBE8
		LD	(HL),A				;77		users byte was zero. Update from directory.
CLOSEIT2:
		OR	A				;B7		check zero
		JP	NZ,CLOSEIT3				;C2E1E8
		LD	A,(HL)				;7E		directories byte was zero, update from users fcb.
		LD	(DE),A				;12
CLOSEIT3:
		CP	(HL)				;BE		if neither one of these bytes were zero,
		JP	NZ,CLOSEIT7				;C21FE9		then close error if they are not the same.
		JP	CLOSEIT5				;C3FDE8		ok so far, get to next byte in fcbs.
CLOSEIT4:
		CALL	MOVEWORD				;CD94E8		update users fcb if it is zero
		EX	DE,HL				;EB		update directories fcb if it is zero.
		CALL	MOVEWORD				;CD94E8
		EX	DE,HL				;EB		if these two values are no different,
		LD	A,(DE)				;1A		then a close error occured.
		CP	(HL)				;BE
		JP	NZ,CLOSEIT7				;C21FE9		check second byte.
		INC	DE				;13
		INC	HL				;23
		LD	A,(DE)				;1A
		CP	(HL)				;BE
		JP	NZ,CLOSEIT7				;C21FE9		remember 16 bit values.
		DEC	C				;0D		bump to next item in table.
CLOSEIT5:
		INC	DE				;13
		INC	HL				;23		there are 16 entries only.
		DEC	C				;0D		continue if more to do.
		JP	NZ,CLOSEIT1				;C2CDE8		backup 20 places (extent byte).
		LD	BC,$FFEC				;01ECFF
		ADD	HL,BC				;09
		EX	DE,HL				;EB
		ADD	HL,BC				;09
		LD	A,(DE)				;1A		directory's extent already greater than the
		CP	(HL)				;BE		users extent?
		JP	C,CLOSEIT6				;DA17E9		no, update directory extent.
		LD	(HL),A				;77		and update the record count byte in
		LD	BC,$0003				;010300		directories fcb.
		ADD	HL,BC				;09
		EX	DE,HL				;EB
		ADD	HL,BC				;09		get from user.
		LD	A,(HL)				;7E		and put in directory.
		LD	(DE),A				;12		set 'was open and is now closed' byte.
CLOSEIT6:
		LD	A,$FF				;3EFF
		LD	(CLOSEFLG),A				;32D2ED		update the directory now.
		JP	UPDATE1				;C310E8		set return status and then return.
CLOSEIT7:
		LD	HL,STATUS				;2145E3
		DEC	(HL)				;35
		RET				;C9
*	Routine to get the next empty space in the directory. 
*	It will then be cleared for use.
GETEMPTY:
		CALL	CHKWPRT				;CD54E5		make sure disk is not write protected.
		LD	HL,(PARAMS)				;2A43E3		save current parameters (fcb).
		PUSH	HL				;E5
		LD	HL,EMPTYFCB				;21ACED		use special one for empty space.
		LD	(PARAMS),HL				;2243E3
		LD	C,$01				;0E01		search for first empty spot in directory.
		CALL	FINDFST				;CD18E7		(* only check first byte *)
		CALL	CKFILPOS				;CDF5E5		none?
		POP	HL				;E1
		LD	(PARAMS),HL				;2243E3		restore original fcb address.
		RET	Z				;C8		return if no more space.
		EX	DE,HL				;EB
		LD	HL,$000F				;210F00		point to number of records for this file.
		ADD	HL,DE				;19
		LD	C,$11				;0E11		and clear all of this space.
		XOR	A				;AF		A = $00
GETMT1:
		LD	(HL),A				;77
		INC	HL				;23
		DEC	C				;0D
		JP	NZ,GETMT1				;C246E9
		LD	HL,$000D				;210D00		clear the 's1' byte also.
		ADD	HL,DE				;19
		LD	(HL),A				;77
		CALL	CHKNMBR				;CD8CE5		keep (SCRATCH1) within bounds.
		CALL	FCBSET				;CDFDE7		write out this fcb entry to directory.
		JP	SETS2B7				;C378E5		set 's2' byte bit 7 (unmodified at present)
GETNEXT:
		XOR	A				;AF		A = $00
		LD	(CLOSEFLG),A				;32D2ED		clear close flag.
		CALL	CLOSEIT				;CDA2E8		close this extent.
		CALL	CKFILPOS				;CDF5E5
		RET	Z				;C8		not there???
		LD	HL,(PARAMS)				;2A43E3		get extent byte.
		LD	BC,$000C				;010C00
		ADD	HL,BC				;09
		LD	A,(HL)				;7E		and increment it.
		INC	A				;3C
		AND	$1F				;E61F		keep within range 0-31.
		LD	(HL),A				;77
		JP	Z,GTNEXT1				;CA83E9		overflow?
		LD	B,A				;47		mask extent byte.
		LD	A,(EXTMASK)				;3AC5ED
		AND	B				;A0
		LD	HL,CLOSEFLG				;21D2ED		check close flag (0ffh is ok).
		AND	(HL)				;A6
		JP	Z,GTNEXT2				;CA8EE9		if zero, we must read in next extent
		JP	GTNEXT3				;C3ACE9		else, it is already in memory.
GTNEXT1:
		LD	BC,$0002				;010200		Point to the 's2' byte.
		ADD	HL,BC				;09
		INC	(HL)				;34		and bump it.
		LD	A,(HL)				;7E		too many extents?
		AND	$0F				;E60F
		JP	Z,GTNEXT5				;CAB6E9		yes, set error code.
*	Get here to open the next extent.
GTNEXT2:
		LD	C,$0F				;0E0F		set to check first 15 bytes of fcb.
		CALL	FINDFST				;CD18E7		find the first one.
		CALL	CKFILPOS				;CDF5E5		none available?
		JP	NZ,GTNEXT3				;C2ACE9
		LD	A,(RDWRTFLG)				;3AD3ED		no extent present. Can we open an empty one?
		INC	A				;3C		0ffh means reading (so not possible).
		JP	Z,GTNEXT5				;CAB6E9		or an error.
		CALL	GETEMPTY				;CD24E9		we are writing, get an empty entry.
		CALL	CKFILPOS				;CDF5E5		none?
		JP	Z,GTNEXT5				;CAB6E9		error if true.
		JP	GTNEXT4				;C3AFE9		else we are almost done.
GTNEXT3:
		CALL	OPENIT1				;CD5AE8		open this extent.
GTNEXT4:
		CALL	STRDATA				;CDBBE4		move in updated data (rec #, extent #, etc.)
		XOR	A				;AF		clear status and return. A = $00
		JP	SETSTAT				;C301E3
GTNEXT5:
		CALL	IOERR1				;CD05E3		set error code, clear bit 7 of 's2'
		JP	SETS2B7				;C378E5		so this is not written on a close.
*	Read a sequential file.
RDSEQ:
		LD	A,$01				;3E01		set sequential access mode.
		LD	(MODE),A				;32D5ED
RDSEQ1:
		LD	A,$FF				;3EFF		don't allow reading unwritten space.
		LD	(RDWRTFLG),A				;32D3ED
		CALL	STRDATA				;CDBBE4		put rec# and ext# into fcb.
		LD	A,(SAVNREC)				;3AE3ED		get next record to read.
		LD	HL,SAVNXT				;21E1ED		get number of records in extent.
		CP	(HL)				;BE		within this extent?
		JP	C,RDSEQ2				;DAE6E9
		CP	$80				;FE80		no. Is this extent fully used?
		JP	NZ,RDSEQ3				;C2FBE9		no. End-of-file.
		CALL	GETNEXT				;CD5AE9		yes, open the next one.
		XOR	A				;AF		reset next record to read.A = $00
		LD	(SAVNREC),A				;32E3ED
		LD	A,(STATUS)				;3A45E3		check on open, successful?
		OR	A				;B7		check zero
		JP	NZ,RDSEQ3				;C2FBE9		no, error.
RDSEQ2:
		CALL	COMBLK				;CD77E4		ok. compute block number to read.
		CALL	CHKBLK				;CD84E4		check it. Within bounds?
		JP	Z,RDSEQ3				;CAFBE9		no, error.
		CALL	LOGICAL				;CD8AE4		convert (BLKNMBR) to logical sector (128 byte)
		CALL	TRKSEC1				;CDD1E3		set the track and sector for this block #.
		CALL	DOREAD				;CDB2E3		and read it.
		JP	SETNREC				;C3D2E4		and set the next record to be accessed.
*	Read error occured. Set status and return
RDSEQ3:
		JP	IOERR1				;C305E3
*	Write the next sequential record
WTSEQ:
		LD	A,$01				;3E01		set sequential access mode.is disk write protected
		LD	(MODE),A				;32D5ED		?
WTSEQ1:
		LD	A,$00				;3E00		allow an addition empty extent to be opened.
		LD	(RDWRTFLG),A				;32D3ED
		CALL	CHKWPRT				;CD54E5		check write protect status.
		LD	HL,(PARAMS)				;2A43E3
		CALL	CKROF1				;CD47E5		check for read only file, (HL) already set to fcb
		CALL	STRDATA				;CDBBE4		put updated data into fcb.
		LD	A,(SAVNREC)				;3AE3ED		get record number to write.
		CP	$80				;FE80		within range?
		JP	NC,IOERR1				;D205E3		no, error(?).
		CALL	COMBLK				;CD77E4		compute block number.
		CALL	CHKBLK				;CD84E4		check number.
		LD	C,$00				;0E00		is there one to write to?
		JP	NZ,WTSEQ6				;C26EEA		yes, go do it.
		CALL	GETBLOCK				;CD3EE4		get next block number within fcb to use.
		LD	(RELBLOCK),A				;32D7ED		and save.
		LD	BC,$0000				;010000		start looking for space from the start
		OR	A				;B7		if none allocated as yet.
		JP	Z,WTSEQ2				;CA3BEA
		LD	C,A				;4F		extract previous block number from fcb
		DEC	BC				;0B		so we can be closest to it.
		CALL	EXTBLK				;CD5EE4
		LD	B,H				;44
		LD	C,L				;4D
WTSEQ2:
		CALL	FNDSPACE				;CDBEE7		find the next empty block nearest number BC
		LD	A,L				;7D		check for a zero number.
		OR	H				;B4
		JP	NZ,WTSEQ3				;C248EA
		LD	A,$02				;3E02		no more space?
		JP	SETSTAT				;C301E3
WTSEQ3:
		LD	(BLKNMBR),HL				;22E5ED		save block number to access.
		EX	DE,HL				;EB		put block number into DE
		LD	HL,(PARAMS)				;2A43E3		now we must update the fcb for this
		LD	BC,$0010				;011000		newly allocated block.
		ADD	HL,BC				;09
		LD	A,(BIGDISK)				;3ADDED		8 or 16 bit block numbers?
		OR	A				;B7		check zero
		LD	A,(RELBLOCK)				;3AD7ED		(* update this entry *)
		JP	Z,WTSEQ4				;CA64EA		zero means 16 bit ones.
		CALL	ADDA2HL				;CD64E5		HL = HL + A
		LD	(HL),E				;73		store new block number.
		JP	WTSEQ5				;C36CEA
WTSEQ4:
		LD	C,A				;4F		compute spot in this 16 bit table.
		LD	B,$00				;0600
		ADD	HL,BC				;09
		ADD	HL,BC				;09
		LD	(HL),E				;73		stuff block number DE there.
		INC	HL				;23
		LD	(HL),D				;72
WTSEQ5:
		LD	C,$02				;0E02		set C to indicate writing to un-used disk space
WTSEQ6:
		LD	A,(STATUS)				;3A45E3		are we ok so far?
		OR	A				;B7		check zero
		RET	NZ				;C0
		PUSH	BC				;C5		yes, save write flag for bios (register C).
		CALL	LOGICAL				;CD8AE4		convert (BLKNMBR) over to loical sectors.
		LD	A,(MODE)				;3AD5ED		get access mode flag (1=sequential,
		DEC	A				;3D		0=random, 2=special?).
		DEC	A				;3D
		JP	NZ,WTSEQ9				;C2BBEA
*	Special random i/o from function #40. Maybe for M/PM, but the
*	current block, if it has not been written to, will be zeroed
*	out and then written (reason?).
		POP	BC				;C1
		PUSH	BC				;C5
		LD	A,C				;79		get write status flag (2=writing unused space).
		DEC	A				;3D
		DEC	A				;3D
		JP	NZ,WTSEQ9				;C2BBEA
		PUSH	HL				;E5
		LD	HL,(DIRBUF)				;2AB9ED		zero out the directory buffer.
		LD	D,A				;57		note that (A) is zero here.
WTSEQ7:
		LD	(HL),A				;77
		INC	HL				;23
		INC	D				;14		do 128 bytes.
		JP	P,WTSEQ7				;F28CEA
		CALL	DIRDMA				;CDE0E5		tell the bios the dma address for directory acces
		LD	HL,(LOGSECT)				;2AE7ED		get sector that starts current block.
		LD	C,$02				;0E02		set 'writing to unused space' flag.
WTSEQ8:
		LD	(BLKNMBR),HL				;22E5ED		save sector to write.
		PUSH	BC				;C5
		CALL	TRKSEC1				;CDD1E3		determine its track and sector numbers.
		POP	BC				;C1
		CALL	DOWRITE				;CDB8E3		now write out 128 bytes of zeros.
		LD	HL,(BLKNMBR)				;2AE5ED		get sector number.
		LD	C,$00				;0E00		set normal write flag.
		LD	A,(BLKMASK)				;3AC4ED		determine if we have written the entire
		LD	B,A				;47		physical block.
		AND	L				;A5
		CP	B				;B8
		INC	HL				;23		prepare for the next one.
		JP	NZ,WTSEQ8				;C29AEA		continue until (BLKMASK+1) sectors written.
		POP	HL				;E1		reset next sector number.
		LD	(BLKNMBR),HL				;22E5ED
		CALL	DEFDMA				;CDDAE5		and reset dma address.
*	Normal disk write. Set the desired track and sector then
*	do the actual write.
WTSEQ9:
		CALL	TRKSEC1				;CDD1E3		determine track and sector for this write
		POP	BC				;C1		get write status flag.
		PUSH	BC				;C5
		CALL	DOWRITE				;CDB8E3		and write this out.
		POP	BC				;C1
		LD	A,(SAVNREC)				;3AE3ED		get number of records in file.
		LD	HL,SAVNXT				;21E1ED		get last record written.
		CP	(HL)				;BE
		JP	C,WTSEQ10				;DAD2EA
		LD	(HL),A				;77		we have to update record count.
		INC	(HL)				;34
		LD	C,$02				;0E02
WTSEQ10:
		DEC	C				;0D
		DEC	C				;0D
		JP	NZ,WTSEQ99				;C2DFEA
*	This is the proposed patched to correct disk update problem
*	when using blocking and de-blocking in the BIOS.
*EAD2	WTSEQ10:NOP			;00	
*EAD3		NOP			;00	
*EAD4		LD	HL,$0000	;2100D4	
*	End of patch.
		PUSH	AF				;F5
		CALL	GETS2				;CD69E5		set 'extent written to' flag.
		AND	$7F				;E67F		(* clear bit 7 *)
		LD	(HL),A				;77
		POP	AF				;F1		get record count for this extent.
WTSEQ99:
		CP	$7F				;FE7F		is it full?
		JP	NZ,$EB00				;C200EB
		LD	A,(MODE)				;3AD5ED		yes, are we in sequential mode?
		CP	$01				;FE01
		JP	NZ,WTSEQ12				;C200EB
		CALL	SETNREC				;CDD2E4		yes, set next record number.
		CALL	GETNEXT				;CD5AE9		and get next empty space in directory
		LD	HL,STATUS				;2145E3		ok?
		LD	A,(HL)				;7E
		OR	A				;B7		check zero
		JP	NZ,WTSEQ11				;C2FEEA
		DEC	A				;3D		yes, set record count to -1
		LD	(SAVNREC),A				;32E3ED
WTSEQ11:
		LD	(HL),$00				;3600		clear status.
WTSEQ12:
		JP	SETNREC				;C3D2E4		set next record to access.
*	  For random i/o, set the fcb for the desired record number
*	  based on the 'r0,r1,r2' bytes. These bytes in the fcb are
*	  used as follows:
*	       fcb+35            fcb+34            fcb+33
*	  |     'r-2'      |      'r-1'      |      'r-0'     |
*	  |7             0 | 7             0 | 7             0|
*	  |0 0 0 0 0 0 0 0 | 0 0 0 0 0 0 0 0 | 0 0 0 0 0 0 0 0|
*	  |    overflow   | | extra |  extent   |   record #  |
*	  | ______________| |_extent|__number___|_____________|
		also 's2'
*	  On entry, register C contains 0ffh if this is a read
*	  and thus we can not access unwritten disk space. Otherwise,
*	  another extent will be opened (for writing) if required.
POSITION:
		XOR	A				;AF		A = $00, set random i/o flag
		LD	(MODE),A				;32D5ED
*	Special entry (function #40). M/PM ?
POSITN1:
		PUSH	BC				;C5		save read/write flag.
		LD	HL,(PARAMS)				;2A43E3		get address of fcb.
		EX	DE,HL				;EB
		LD	HL,$0021				;212100		now get byte 'r0'.
		ADD	HL,DE				;19
		LD	A,(HL)				;7E
		AND	$7F				;E67F		keep bits 0-6 for the record number to access
		PUSH	AF				;F5
		LD	A,(HL)				;7E		now get bit 7 of 'r0' and bits 0-3 of 'r1'.
		RLA				;17
		INC	HL				;23
		LD	A,(HL)				;7E
		RLA				;17
		AND	$1F				;E61F		and save this in bits 0-4 of C
		LD	C,A				;4F		this is the extent byte.
		LD	A,(HL)				;7E		now get the extra extent byte.
		RRA				;1F
		RRA				;1F
		RRA				;1F
		RRA				;1F
		AND	$0F				;E60F
		LD	B,A				;47		and save it in B
		POP	AF				;F1		get record number back to A
		INC	HL				;23		check overflow byte 'r2'.
		LD	L,(HL)				;6E
		INC	L				;2C
		DEC	L				;2D
		LD	L,$06				;2E06		prepare for error.
		JP	NZ,POSITN5				;C28BEB		out of disk space error.
		LD	HL,$0020				;212000		store record number into fcb.
		ADD	HL,DE				;19
		LD	(HL),A				;77
		LD	HL,$000C				;210C00		and now check the extent byte.
		ADD	HL,DE				;19
		LD	A,C				;79
		SUB	(HL)				;96		same extent as before?
		JP	NZ,POSITN2				;C247EB
		LD	HL,$000E				;210E00		yes, check extra extent byte 's2' also
		ADD	HL,DE				;19
		LD	A,B				;78
		SUB	(HL)				;96
		AND	$7F				;E67F
		JP	Z,POSITN3				;CA7FEB		same, we are almost done then.
*	Get here when another extent is required.
POSITN2:
		PUSH	BC				;C5
		PUSH	DE				;D5
		CALL	CLOSEIT				;CDA2E8		close current extent.
		POP	DE				;D1
		POP	BC				;C1
		LD	L,$03				;2E03		prepare for error.
		LD	A,(STATUS)				;3A45E3
		INC	A				;3C
		JP	Z,$POSITN4				;CA84EB		close error.
		LD	HL,$000C				;210C00		put desired extent into fcb now.
		ADD	HL,DE				;19
		LD	(HL),C				;71
		LD	HL,$000E				;210E00		and store extra extent byte 's2'.
		ADD	HL,DE				;19
		LD	(HL),B				;70
		CALL	OPENIT				;CD51E8		try and get this extent.
		LD	A,(STATUS)				;3A45E3		was it there?
		INC	A				;3C
		JP	NZ,POSITN3				;C27FEB
		POP	BC				;C1		no. can we create a new one (writing?)
		PUSH	BC				;C5
		LD	L,$04				;2E04		prepare for error.
		INC	C				;0C
		JP	Z,POSITN4				;CA84EB		nope, reading unwritten space error.
		CALL	GETEMPTY				;CD24E9		yes we can, try to find space.
		LD	L,$05				;2E05		prepare for error.
		LD	A,(STATUS)				;3A45E3
		INC	A				;3C
		JP	Z,POSITN4				;CA84EB		out of space?
*	Normal return location. Clear error code and return.
POSITN3:
		POP	BC				;C1		restore stack.
		XOR	A				;AF		and clear error code byte A = $00
		JP	SETSTAT				;C301E3
*	Error. Set the 's2' byte to indicate this (why?)..
POSITN4:
		PUSH	HL				;E5
		CALL	GETS2				;CD69E5
		LD	(HL),$C0				;36C0
		POP	HL				;E1
*	Return with error code (presently in L).
POSITN5:
		POP	BC				;C1
		LD	A,L				;7D		get error code
		LD	(STATUS),A				;3245E3
		JP	SETS2B7				;C378E5
*	Read a random record.
READRAN:
		LD	C,$FF				;0EFF		set 'read' status.
		CALL	POSITION				;CD03EB		position the file to proper record.
		CALL	Z,RDSEQ1				;CCC1E9		and read it as usual (if no errors)
		RET				;C9
*	Write to a random record.
WRITERAN:
		LD	C,$00				;0E00		set 'writing' flag.
		CALL	POSITION				;CD03EB		position the file to proper record
		CALL	Z,WTSEQ1				;CC03EA		and write as usual (if no errors).
		RET				;C9
*	Compute the random record number. Enter with HL pointing
*	to a fcb and DE contains a relative location of a record
*	number. On exit, C contains the 'r0' byte, B the 'r1'
*	byte, and A the 'r2' byte.
*
*	On return, the zero flag is set if the record is within
*	bounds. Otherwise, an overflow occured.
COMPRAND:
		EX	DE,HL				;EB		save fcb pointer in DE
		ADD	HL,DE				;19		compute relative position of record #.
		LD	C,(HL)				;4E		get record number into BC
		LD	B,$00				;0600
		LD	HL,$000C				;210C00		now get extent.
		ADD	HL,DE				;19
		LD	A,(HL)				;7E		compute BC = (record #)+(extent)*128.
		RRCA				;0F		move lower bit into bit 7.
		AND	$80				;E680		and ignore all other bits.
		ADD	A,C				;81		add to our record number.
		LD	C,A				;4F
		LD	A,$00				;3E00		take care of any carry.
		ADC	A,B				;88
		LD	B,A				;47
		LD	A,(HL)				;7E		now get the upper bits of extent into
		RRCA				;0F		bit positions 0-3.
		AND	$0F				;E60F		and ignore all others.
		ADD	A,B				;80		add this in to 'r1' byte.
		LD	B,A				;47
		LD	HL,$000E				;210E00		get the 's2' byte (extra extent).
		ADD	HL,DE				;19
		LD	A,(HL)				;7E
		ADD	A,A				;87		and shift it left 4 bits (bits 4-7).
		ADD	A,A				;87
		ADD	A,A				;87
		ADD	A,A				;87
		PUSH	AF				;F5		save carry flag (bit 0 of flag byte).
		ADD	A,B				;80		now add extra extent into 'r1'.
		LD	B,A				;47
		PUSH	AF				;F5		and save carry (overflow byte 'r2').
		POP	HL				;E1		bit 0 of L is the overflow indicator
		LD	A,L				;7D
		POP	HL				;E1		and same for first carry flag.
		OR	L				;B5		either one of these set?
		AND	$01				;E601		only check the carry flags.
		RET				;C9
*	Routine to setup the fcb (bytes 'r0', 'r1', 'r2') to
*	reflect the last record used for a random (or other) file.
*	This reads the directory and looks at all extents computing
*	the largerst record number for each and keeping the maximum
*	value only. Then 'r0', 'r1', and 'r2' will reflect this
*	maximum record number. This is used to compute the space used
*	by a random file.
RANSIZE:
		LD	C,$0C				;0E0C		look thru directory for first entry with
		CALL	FINDFST				;CD18E7		this name.
		LD	HL,(PARAMS)				;2A43E3		zero out the 'r0, r1, r2' bytes.
		LD	DE,$0021				;112100
		ADD	HL,DE				;19
		PUSH	HL				;E5
		LD	(HL),D				;72		note that D = 0.
		INC	HL				;23
		LD	(HL),D				;72
		INC	HL				;23
		LD	(HL),D				;72
RANSIZ1:
		CALL	CKFILPOS				;CDF5E5		is there an extent to process?
		JP	Z,RANSIZ3				;CA0CEC		no, we are done.
		CALL	FCB2HL				;CD5EE5		set HL pointing to proper fcb in dir.
		LD	DE,$000F				;110F00		point to last record in extent.
		CALL	COMPRAND				;CDA5EB		and compute random parameters.
		POP	HL				;E1
		PUSH	HL				;E5		now check these values against those
		LD	E,A				;5F		already in fcb.
		LD	A,C				;79		the carry flag will be set if those
		SUB	(HL)				;96		in the fcb represent a larger size than
		INC	HL				;23		this extent does.
		LD	A,B				;78
		SBC	A,(HL)				;9E
		INC	HL				;23
		LD	A,E				;7B
		SBC	A,(HL)				;9E
		JP	C,RANSIZ2				;DA06EC
		LD	(HL),E				;73		we found a larger (in size) extent.
		DEC	HL				;2B		stuff these values into fcb.
		LD	(HL),B				;70
		DEC	HL				;2B
		LD	(HL),C				;71
RANSIZ2:
		CALL	FINDNXT				;CD2DE7		now get the next extent.
		JP	RANSIZ1				;C3E4EB		continue til all done.
RANSIZ3:
		POP	HL				;E1		we are done, restore the stack and
		RET				;C9		return.
*	BDOS function 36 to return the random record position of a given
*	file which has been read in sequential mode up to now.
SETRAN:
		LD	HL,(PARAMS)				;2A43E3		point to fcb.
		LD	DE,$0020				;112000		and to last used record.
		CALL	COMPRAND				;CDA5EB		compute random position.
		LD	HL,$0021				;212100		now stuff these values into fcb
		ADD	HL,DE				;19
		LD	(HL),C				;71		move 'r0'.
		INC	HL				;23
		LD	(HL),B				;70		and 'r1'.
		INC	HL				;23
		LD	(HL),A				;77		and lastly 'r2'.
		RET				;C9
*	This routine select the drive specified in (ACTIVE) and
*	update the login vector and bitmap table if this drive was
*	not already active.
LOGINDRV:
		LD	HL,(LOGIN)				;2AAFED		get the login vector.
		LD	A,(ACTIVE)				;3A42E3		get the default drive.
		LD	C,A				;4F
		CALL	SHIFTR				;CDEAE4		position active bit for this drive
		PUSH	HL				;E5		into bit 0.
		EX	DE,HL				;EB
		CALL	SELECT				;CD59E3		select this drive.
		POP	HL				;E1
		CALL	Z,SLCTERR				;CC47E3		valid drive?
		LD	A,L				;7D		is this a newly activated drive?
		RRA				;1F
		RET	C				;D8
		LD	HL,(LOGIN)				;2AAFED		yes, update the login vector.
		LD	C,L				;4D
		LD	B,H				;44
		CALL	SETBIT				;CD0BE5
		LD	(LOGIN),HL				;22AFED		and save.
		JP	BITMAP				;C3A3E6		now update the bitmap.
*	BDOS function 14 to set the active disk number.
SETDSK:
		LD	A,(EPARAM)				;3AD6ED		get parameter passed and see if this
		LD	HL,ACTIVE				;2142E3		represents a change in drives.
		CP	(HL)				;BE
		RET	Z				;C8
		LD	(HL),A				;77		yes it does, log it in.
		JP	LOGINDRV				;C321EC
*	This is the 'auto disk select' routine. The firsst byte
*	of the fcb is examined for a drive specification. If non
*	zero then the drive will be selected and loged in.
AUTOSEL:
		LD	A,$FF				;3EFF		say 'auto-select activated'.
		LD	(AUTO),A				;32DEED
		LD	HL,(PARAMS)				;2A43E3		get drive specified.
		LD	A,(HL)				;7E
		AND	$1F				;E61F		look at lower 5 bits.
		DEC	A				;3D		adjust for (1=A, 2=B) etc.
		LD	(EPARAM),A				;32D6ED		and save for the select routine.
		CP	$1E				;FE1E		check for 'no change' condition.
		JP	NC,AUTOSL1				;D275EC		yes, don't change.
		LD	A,(ACTIVE)				;3A42E3		we must change, save currently active
		LD	($EDDF),A				;32DFED		drive.
		LD	A,(HL)				;7E		and save first byte of fcb also.
		LD	(AUTOFLAG),A				;32E0ED		this must be non-zero.
		AND	$E0				;E6E0		whats this for (bits 6,7 are used for
		LD	(HL),A				;77		something)?
		CALL	SETDSK				;CD45EC		select and log in this drive.
AUTOSL1:
		LD	A,(STKAREA)				;3A41E3		move user number into fcb.
		LD	HL,(PARAMS)				;2A43E3		(* upper half of first byte *)
		OR	(HL)				;B6
		LD	(HL),A				;77
		RET				;C9		and return (all done).
*	BDOS function 12 to return the current cp/m version number.
GETVER:
		LD	A,$22				;3E22		version 2.2
		JP	SETSTAT				;C301E3
*	BDOS function 13 to reset the disk system.
RSTDSK:
		LD	HL,$0000				;210000		clear write protect status and log
		LD	(WRTPRT),HL				;22ADED		in vector.
		LD	(LOGIN),HL				;22AFED
		XOR	A				;AF		select drive 'A'. A = $00
		LD	(ACTIVE),A				;3242E3
		LD	HL,$0080				;218000		setup default dma address.
		LD	(USERDMA),HL				;22B1ED
		CALL	DEFDMA				;CDDAE5
		JP	LOGINDRV				;C321EC		now log in drive 'A'.
*	BDOS function 15 to open a specified file.
OPENFIL:
		CALL	CLEARS2				;CD72E5		clear 's2' byte.
		CALL	AUTOSEL				;CD51EC		select proper disk
		JP	OPENIT				;C351E8		and open the file.
*	BDOS function 16 to close a specified file.
CLOSEFIL:
		CALL	AUTOSEL				;CD51EC		select proper disk
		JP	CLOSEIT				;C3A2E8		and close the file
*	BDOS function 17 to return the first occurence of a specified file name.
*	If the first byte of the fcb is '?' then the name will not be checked
*	(get the first entry no matter what).
GETFS:
		LD	C,$00				;0E00		prepare for special search.
		EX	DE,HL				;EB
		LD	A,(HL)				;7E		is first byte a '?'?
		CP	$3F				;FE3F
		JP	Z,GETFST1				;CAC2EC		yes, just get very first entry (zero length match)
		CALL	EXTMASK				;CDA6E4		get the extension byte from fcb.
		LD	A,(HL)				;7E		is it '?'? if yes, then we want
		CP	$3F				;FE3F		an entry with a specific 's2' byte.
		CALL	NZ,CLEARS2				;C472E5		otherwise, look for a zero 's2' byte.
		CALL	AUTOSEL				;CD51EC		select proper drive.
		LD	C,$0F				;0E0F		compare bytes 0-14 in fcb (12&13 excluded).
GETFST1:
		CALL	FINDFST				;CD18E7		find an entry and then move it into
		JP	MOVEDIR				;C3E9E5		the users dma space.
*	BDOS function 18 to return the next occurence of a file name.
GETNXT:
		LD	HL,(SAVEFCB)				;2AD9ED		restore pointers. note that no
		LD	(PARAMS),HL				;2243E3		other dbos calls are allowed.
		CALL	AUTOSEL				;CD51EC		no error will be returned, but the
		CALL	FINDNXT				;CD2DE7		results will be wrong.
		JP	MOVEDIR				;C3E9E5
*	BDOS function 19 to delete a file by name.
DELFILE:
		CALL	AUTOSEL				;CD51EC		select proper drive.
		CALL	ERAFILE				;CD9CE7		erase the file.
		JP	STSTATUS				;C301E7		set status and return
*	BDOS function 20 to execute a sequential read of the specified record number
READSEQ:
		CALL	AUTOSEL				;CD51EC		select proper drive then read
		JP	RDSEQ				;C3BCE9
*	BDOS function 21 to write the net sequential record.
WRTSEQ:
		CALL	AUTOSEL				;CD51EC		select proper drive then write
		JP	WTSEQ				;C3FEE9
*	BDOS function 22 to create a file
FCREATE:
		CALL	CLEARS2				;CD72E5		clear the 's2' byte on all creates.
		CALL	AUTOSEL				;CD51EC		select proper drive and get the next
		JP	GETEMPTY				;C324E9		empty directory space.
*	BDOS function 23 to rename a file.
RENFILE:
		CALL	AUTOSEL				;CD51EC		select proper drive and then switch
		CALL	CHGNAMES				;CD16E8		file names.
		JP	STSTATUS				;C301E7
*	BDOS function 24 to return the login vector.
GETLOG:
		LD	HL,(LOGIN)				;2AAFED
		JP	GETPRM1				;C329ED
*	BDOS function 25 to return the current disk assignment.
GETCRNT:
		LD	A,(ACTIVE)				;3A42E3
		JP	SETSTAT				;C301E3
*	BDOS function 26 to set the dma address.
PUTDMA:
		EX	DE,HL				;EB
		LD	(USERDMA),HL				;22B1ED		save in our space and then get to
		JP	DEFDMA				;C3DAE5		the bios with this also.
*	BDOS function 27 to return the allocation vector.
GETALOC:
		LD	HL,(ALOCVECT)				;2ABFED
		JP	GETPRM1				;C329ED
*	BDOS function 29 to return the read-only status vector.
GETROV:
		LD	HL,(WRTPRT)				;2AADED
		JP	GETPRM1				;C329ED
*	BDOS function 30 to set the file attributes (read-only, system).
SETATTR:
		CALL	AUTOSEL				;CD51EC		select proper drive then save attributes
		CALL	SAVEATTR				;CD3BE8
		JP	STSTATUS				;C301E7
*	BDOS function 31 to return the address of the disk parameter block for the current drive
GETPARM:
		LD	HL,(DISKPB)				;2ABBED
GETPRM1:
		LD	(STATUS),HL				;2245E3
		RET				;C9
*	BDOS function 32 to get or set the user number. If E was $FF then this is a request
*	to return the current user number. Else set the user number from E.
GETUSER:
		LD	A,(EPARAM)				;3AD6ED		get parameter.
		CP	$FF				;FEFF		get user number?
		JP	NZ,SETUSER				;C23BED
		LD	A,(STKAREA)				;3A41E3		yes, just do it.
		JP	SETSTAT				;C301E3
SETUSER:
		AND	$1F				;E61F		no, we should set it instead. keep low
		LD	(STKAREA),A				;3241E3		bits (0-4) only.
		RET				;C9
*	BDOS function 33 to read a random record from a file.
RDRANDOM:
		CALL	AUTOSEL				;CD51EC		select proper drive and read
		JP	READRAN				;C393EB
*	BDOS function 34 to compute the file size for random files.
WTRANDOM:
		CALL	AUTOSEL				;CD51EC
		JP	$WRITERAN				;C39CEB
*	BDOS function 35 to compute the size of a random file.
FILESIZE:
		CALL	AUTOSEL				;CD51EC
		JP	RANSIZE				;C3D2EB
*	BDOS function 37. This allows a program to log off any drives.
*	On entry, set DE to contain a word with bits set for those drives that are to be logged off.
*	The log-in vector and the write protect vector will be updated.
*	This must be a M/PM special function.
LOGOFF:
		LD	HL,(PARAMS)				;2A43E3		get drives to log off.
		LD	A,L				;7D		for each bit that is set, we want
		CPL				;2F		to clear that bit in (LOGIN)
		LD	E,A				;5F		and (WRTPRT).
		LD	A,H				;7C
		CPL				;2F		invert bits
		LD	HL,(LOGIN)				;2AAFED		reset the login vector.
		AND	H				;A4
		LD	D,A				;57
		LD	A,L				;7D
		AND	E				;A3
		LD	E,A				;5F
		LD	HL,(WRTPRT)				;2AADED
		EX	DE,HL				;EB
		LD	(LOGIN),HL				;22AFED		and save.
		LD	A,L				;7D		now do the write protect vector.
		AND	E				;A3
		LD	L,A				;6F
		LD	A,H				;7C
		AND	D				;A2
		LD	H,A				;67
		LD	(WRTPRT),HL				;22ADED		and save. all done.
		RET				;C9
*	Get here to return to the user.
GOBACK:
		LD	A,(AUTO)				;3ADEED		was auto select activated?
		OR	A				;B7		check zero
		JP	Z,GOBACK1				;CA91ED
		LD	HL,(PARAMS)				;2A43E3		yes, but was a change made?
		LD	(HL),$00				;3600		(* reset first byte of fcb *)
		LD	A,(AUTOFLAG)				;3AE0ED
		OR	A				;B7		check zero
		JP	Z,GOBACK1				;CA91ED
		LD	(HL),A				;77		yes, reset first byte properly.
		LD	A,(OLDDRV)				;3ADFED		and get the old drive and select it
		LD	(EPARAM),A				;32D6ED
		CALL	SETDSK				;CD45EC
GOBACK1:
		LD	HL,(USRSTACK)				;2A0FE3		reset the users stack pointer.
		LD	SP,HL				;F9
		LD	HL,(STATUS)				;2A45E3		get return status.
		LD	A,L				;7D		force version 1.4 compatability.
		LD	B,H				;44
		RET				;C9		and go back to user.
*	BDOS function 40. This is a special entry to do random i/o.
*	For the case where we are writing to unused disk space, this space will be zeroed out first.
*	This must be a M/PM special purpose function, because why would any normal program even
*	care about the previous contents of a sector about to be written over.
WTSPECL:
		CALL	AUTOSEL				;CD51EC		select proper drive.
		LD	A,$02				;3E02		use special write mode.
		LD	(MODE),A				;32D5ED
		LD	C,$00				;0E00		set write indicator.
		CALL	POSITN1				;CD07EB		position the file.
		CALL	Z,WTSEQ1				;CC03EA		and write (if no errors)
		RET				;C9
**************************************************************
*
*	BDOS data storage pool.
*
**************************************************************
EMPTYFCB:
		DEFB	$E5				;empty directory segment indicator
WRTPRT:
		DEFB	$00,$00				;write protect status for all 16 drives
LOGIN:
		DEFB	$00,$00				;drive active word (1 bit per drive)
USERDMA:
		DEFB	$80,$00				;user's dma address (defaults to 80h)
*	Scratch areas from parameter block.
SCRATCH1:
		DEFB	$00,$00				;relative position within dir segment for file (0-3)
SCRATCH2:
		DEFB	$00,$00				;last selected track number
SCRATCH3:
		DEFB	$00,$00				;last selected sector number
*	Disk storage areas from parameter block.
DIRBUF:
		DEFB	$00,$00				;address of directory buffer to use
DISKPB:
		DEFB	$00,$00				;contains address of disk parameter block
CHKVECT:
		DEFB	$00,$00				;address of check vector
ALOCVECT:
		DEFB	$00,$00				;address of allocation vector (bit map)
*	Parameter block returned from the bios.
SECTORS:
		DEFB	$00,$00				;sectors per track from bios.
BLKSHFT:
		DEFB	$00				;block shift.
BLKMASK:
		DEFB	$00				;block mask
EXTMASK:
		DEFB	$00				;extent mask.
DSKSIZE:
		DEFB	$00,$00				;disk size from bios (number of blocks-1).
DIRSIZE:
		DEFB	$00,$00				;directory size.
ALLOC0:
		DEFB	$00,$00				;storage for first bytes of bit map (dir space used)
ALLOC1:
		DEFB	$00,$00
OFFSET:
		EFB	$00,$00				;first usable track number.
XLATE:
		DEFB	$00,$00				;sector translation table address.
CLOSEFLG:
		DEFB	$00				;close flag (=0ffh is extent written ok)
RDWRTFLG:
		DEFB	$00				;read/write flag (0ffh=read, 0=write)
FNDSTAT:
		DEFB	$00				;filename found status (0=found first entry)
MODE:
		DEFB	$00				;I/o mode select (0=random, 1=sequential, 2=special random)
EPARAM:
		DEFB	$00				;storage for register E on entry to bdos
RELBLOCK:
		DEFB	$00				;relative position within fcb of block number written
COUNTER:
		DEFB	$00				;byte counter for directory name searches
SAVEFCB:
		DEFB	$00,$00,$00,$00				;save space for address of fcb (for directory searches)
BIGDISK:
		DEFB	$00				;if =0 then disk is > 256 blocks long
AUTO:
		DEFB	$00				;if non-zero, then auto select activated
OLDDRV:
		DEFB	$00				;on auto select, storage for previous drive
AUTOFLAG:
		DEFB	$00				;if non-zero, then auto select changed drives
SAVNXT:
		DEFB	$00				;storage for next record number to access
SAVEXT:
		DEFB	$00				;storage for extent number of file
SAVNREC:
		DEFB	$00,$00				;storage for number of records in file
BLKNMBR:
		DEFB	$00,$00				;block number (physical sector) used within a file or logical sect
LOGSECT:
		DEFB	$00,$00				;starting logical (128 byte) sector of block (physical sector)
FCBPOS:
		DEFB	$00				;relative position within buffer for fcb of file of interest
FILEPOS:
		DEFB	$00				;files position within directory (0 to max entries -1)
FILEPOS+1:
		DEFB	$00
*	Disk directory buffer checksum bytes. One for each of the
*	16 possible drives.
CKSUMTBL:
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
*	Extra space ?
		DEFB	$00,$00,$00
CKSEND:
		DEFB	$00
*******************************************************************************
*                                     BIOS                                    *
*******************************************************************************
*                                $EE00 - $FBFF                                *
*******************************************************************************
*                                                                             *
*			B I O S   J U M P   T A B L E                         *
*                                                                             *
*******************************************************************************
*BIOS Entry Points
BOOT:
		JP	CBOOT				;C383EE	C O L D   B O O T
WBOOT:
		JP	WBOOT1				;C3C1EE	W A R M   B O O T
CONST:
		JP	CONST1				;C3FFEF	C O N S O L E   S T A T U S
CONIN:
		JP	CONIN1				;C33EF0	C O N I N
CONOUT:
		JP	CONOUT1				;C368F4	C O N O U T (KEYIN)
LIST:
		JP	LIST1				;C341EF	L I S T
PUNCH:
		JP	PUNCH1				;C321EF	P U N C H
READER:
		JP	READER1				;C32DEF	R E A D E R
HOME:
		JP	HOME1				;C3C8F8	H O M E
SELDSK:
		JP	SELDSK1				;C3E2F8	S E L D S K
SETTRK:
		JP	SETTRK1				;C3D3F8	S E T T R K
SETSEC:
		JP	SETSEC1				;C3D8F8	S E T S E C
SETDMA:
		JP	SETDMA1				;C3DDF8	S E T D M A
READ:
		JP	READ1				;C3FBF8	R E A D
WRITE:
		JP	WRITE1				;C30DF9	W R I T E
LISTST:
		JP	LISTST1				;C337EF	L I S T S T
SECTRAN:
		JP	SECTRAN1				;C3F8F8	S E C T R A N
*	I O B Y T E  A D D R E S S  T A B L E
		;	Logical to physical device assignment
IODEFAULT:
		DEFB	$81				;1000 0001
IOTABLE:
		DEFB	$BE,$F2				;$F2BE - Function Key Definitions
		;	LST
VE36:
		DEFB	$AB,$EF				;$EFAB - TTY O/P
		DEFB	$68,$F4				;$F468 - CRT
		DEFB	$65,$EF				;$EF65 - LPT (default)
		DEFB	$8A,$EF				;$EF8A - UL1 (MZ-80I/O2)
		;	LSTAT
VE3E:
		DEFB	$B9,$EF				;$EFB9 - TTY Status
		DEFB	$2F,$F4				;$F42F - A = 1111 1111
		DEFB	$81,$EF				;$EF81 - LPT Status
		DEFB	$9E,$EF				;$EF9E - UL1 Status
		;	RDR
VE46:
		DEFB	$CF,$EF				;$EFCF - TTY I/P = RS232 Ch B (default)
		DEFB	$DE,$EF				;$EFDE - PTP I/P = RS232 Ch A
		DEFB	$3E,$F0				;$F03E - Keyboard
		DEFB	$A8,$EF				;$EFA8 - UR2, returns ^Z (EOF)
		;	PUN
VE4E:
		DEFB	$AB,$EF				;$EFAB - TTY O/P = RS232 Ch B (default)
		DEFB	$C9,$EF				;$EFC9 - PTP O/P = RS232 Ch A
		DEFB	$68,$F4				;$F468 - CRT
		DEFB	$AA,$EF				;$EFAA - UP2
		;	MZ-8BI/O3 Ch A Control Port
VE56:
		DEFB	$10				;count
		DEFB	$B1				;Port address
		DEFB	$18				;Channel reset
		DEFB	$B1				;Port address
		DEFB	$10				;EXT/STATUS reset
		DEFB	$B1				;Port address
		DEFB	$04				;Register number
		DEFB	$B1				;Port address
		DEFB	$4C				;x64 clock mode, 8-bit sync char, 2 stop bits/char, No Parity
		;EE5E		DEFB	$44		;x64 clock mode, 8-bit sync char, 1 stop bits/char, No Parity
		DEFB	$B1				;Port address
		DEFB	$05				;Register number
		DEFB	$B1				;Port address
		DEFB	$EA				;DTR, TxDT=S, TxEN, RTS
		DEFB	$B1				;Port address
		DEFB	$03				;Register number
		DEFB	$B1				;Port address
		DEFB	$E1				;Rx8,AutoEN,RxEN
		;	MZ-8BI/O3 Ch B Control Port
		DEFB	$B3
		DEFB	$18,$B3				;Channel reset
		DEFB	$10,$B3				;EXT/STATUS reset
		DEFB	$04,$B3				;Register number
		DEFB	$4C,$B3				;x64 clock mode, 8-bit sync char, 2 stop bits/char, No Parity
		;EE6E		DEFB	$44,$B3		;x64 clock mode, 8-bit sync char, 1 stop bits/char, No Parity
		DEFB	$05,$B3				;Register number
		DEFB	$EA,$B3				;DTR, TxDT=S, TxEN, RTS
		DEFB	$03,$B3				;Register number
		DEFB	$E1				;Rx8,AutoEN,RxEN
		;EE76		DEFB	$E0		;Rx8,AutoEN,RxDIS
		;
		DEFB	$00,$00
		DEFB	$00,$00
		DEFB	$00,$00
		DEFB	$00,$00
		DEFB	$51,$F8
		DEFB	$FD,$FF
*	C O L D   B O O T
CBOOT:
		LD	SP,TBUFF				;318000		;
*	set current drive to A
		XOR	A				;AF		zero A
		LD	(DSKBYTE),A				;320400		reset current drive
*	clear area of RAM $FBA5 - $FFFD
		LD	HL,$FFFD				;21FDFF		HL = $FFFD
		LD	DE,$FBA5				;11A5FB		destination address = $FBA5
		SBC	HL,DE				;ED52		HL = HL - DE = $0458
		LD	B,H				;44
		LD	C,L				;4D		No. of bytes = HL = $0458
		LD	HL,$FBA4				;21A4FB		source address = $FBA4
		LD	(HL),A				;77		zero location at address
		LDIR				;EDB0		copy 458h bytes from $FBA4 to $FBA5
*	clear area of CP/M system variables
		LD	HL,$0040				;214000		source address
		LD	DE,$0041				;114100		destination address
		LD	BC,$000F				;010F00		No. of bytes
		LD	(HL),A				;77
		LDIR				;EDB0		copy 15 bytes from $0040 to $0041
*	I N I T I A L I S E  I O B Y T E
*	By default CON: = CRT, RDR: = TTY:, PUN: = TTY:, LST: = LPT:
*	CONSOLE field (bits 0,1) = CRT:			;offset = $02
*	READER  field (bits 2,3) = TTY:			;offset = $00
*	PUNCH   field (bits 4,5) = TTY:			;offset = $00
*	LIST    field (bits 6,7) = LPT:			;offset = $04
		LD	A,(IODEFAULT)				;3A33EE		By default A = $81 = 1000 0001
		LD	(IOBYTE),A				;320300		set I/O definition byte
		CALL	VFE3				;CDE3EF		copy from $F27E to $FBC0 and $FBFC and from $F2BA to $FC34
		CALL	W3B1				;CDB1F3
		CALL	WA1B				;CD1BFA		CLRTRKS
		CALL	W8C7				;CDC7F8
		CALL	VF55				;CD55EF		set up RS232 Registers
		CALL	COMCWB				;CD02EF
		JP	U800				;C300D8		CCP
WBOOT1:
		LD	SP,TBUFF				;318000		set up stack area
		CALL	VFFE				;CDFEEF		return
		CALL	W3F3				;CDF3F3		Initialise?
		CALL	WA25				;CD25FA		return
		CALL	W8C0				;CDC0F8		reset two flags
		CALL	VF64				;CD64EF		return
		LD	C,$00				;0E00		zero C = drive
		CALL	SELDSK				;CD1BEE		set to drive 0
		CALL	HOME1				;CDC8F8		set to track 0
		LD	B,$2C				;062C
		LD	C,$08				;0E08		BC = $2C08 =
		LD	HL,CBASE				;2100D8		HL = CCP start address
WBOOT2:
		PUSH	BC				;C5		save
		PUSH	HL				;E5		save CCP start address
		CALL	SETSEC1				;CDD8F8		set sector
		POP	BC				;C1		BC = CCP start address
		PUSH	BC				;C5		save CCP start address
		CALL	SETDMA1				;CDDDF8		set dma to CCP start address
		CALL	READ1				;CDFBF8		read sectors
		OR	A				;B7		check for zero
		JP	NZ,WBOOT				;C203EE
		POP	HL				;E1		HL = CCP start address
		LD	DE,TBUFF				;118000
		ADD	HL,DE				;19		HL = HL + DE
		POP	BC				;C1		counter
		INC	C				;0C
		DJNZ	WBOOT2				;10E6
		CALL	COMCWB				;CD02EF
		JP	U803				;C303D8		empty input buffer before starting ccp
* C O M M O N  R O U T I N E  F O R  C O L D / W A R M  B O O T
		;	initialize page zero
COMCWB:
		LD	A,$C3				;3EC3		A = jump instruction
		LD	(H000),A				;320000		for jump to WRMBT
		LD	HL,WBOOT				;2103EE		WRMBT entry point
		LD	(TBASE),HL				;220100		set Warm Boot address
		LD	(H005),A				;320500		for jump to BDOS
		LD	HL,FBASE				;2106E0		BDOS entry point
		LD	(H006),HL				;220600		address field of jump at 5 to BDOS
		LD	BC,$0080				;018000		BC = DMA address
		CALL	SETDMA1				;CDDDF8		set default DMA to $0080
		LD	A,(DSKBYTE)				;3A0400		get current drive number
		LD	C,A				;4F		send to the CCP for further processing
		RET				;C9
*	P U N C H			;punch character from C
PUNCH1:
		LD	A,(IOBYTE)				;3A0300		A = I/O definition byte
		RLCA				;07
		RLCA				;07
		RLCA				;07
		RLCA				;07		bit 5 -> 1, bit 4 -> 0
		LD	HL,VE4E				;214EEE		HL = device address
		JR	LIST2				;181C
*	R E A D E R			;read character into A
READER1:
		LD	A,(IOBYTE)				;00		A = I/O definition byte
		RRA				;1F
		RRA				;1F		bit 3 -> 1, bit 2 -> 0
		LD	HL,VE46				;2146EE		HL = device address
		JR	LIST2				;1812
*	L I S T S T			;return list status (0 if not ready, 1 if ready)
LISTST1:
		LD	A,(IOBYTE)				;3A0300		A = I/O definition byte
		RLCA				;07
		RLCA				;07		bit 7 -> 1, bit 6 -> 0
		LD	HL,VE3E				;213EEE		HL = device address
		JR	LIST2				;1808
*	L I S T				;list character from C into LPT
LIST1:
		LD	A,(IOBYTE)				;3A0300		A = I/O definition byte
		RLCA				;07
		RLCA				;07		bit 7 -> 1, bit 6 -> 0
		LD	HL,VE36				;2136EE		HL = device address
		;	get address of option set in IOBYTE
LIST2:
		AND	$03				;E603		mask bits 2 - 7
		RLCA				;07		A = A * 2
		LD	E,A				;5F		E = A = offset (0,2,4 or 6)
		LD	D,$00				;1600		D = 0
		ADD	HL,DE				;19		HL = HL + DE = device address + offset
		LD	A,(HL)				;7E		A =
		INC	HL				;23
		LD	H,(HL)				;66
		LD	L,A				;6F
		JP	(HL)				;E9		jump to it
		;	set up RS232 Registers
VF55:
		LD	HL,VE56				;2156EE		HL = base address of MZ-8BI/O3 Control Port Channel Data
		LD	B,(HL)				;46		B = byte at HL = count
		INC	B				;04
		DEC	B				;05
		RET	Z				;C8		if data byte is zero, exit
VF5C:
		INC	HL				;23		else, get next address
		LD	C,(HL)				;4E		C = byte at HL = Port address
		INC	HL				;23		next address
		LD	A,(HL)				;7E		A = byte at HL = Data to be sent
		OUT	(C),A				;ED79		send data in A to port address in C
		DJNZ	VF5C				;10F8		repeat until B = 0
VF64:
		RET				;C9
		;	LPT						driver for Sharp's compatible printer using the Sharp I/F card
VF65:
		CALL	VF81				;CD81EF		read LPT Status
		OR	A				;B7		check zero
		JR	Z,VF65				;28FA
		LD	A,C				;79
		CP	$00				;FE00
		JR	NZ,VF72				;2002
		LD	A,$00				;3E00		set strobe to active value
VF72:
		OUT	($FF),A				;D3FF		Write Sharp Printer I/F card data o/p port
		LD	A,$80				;3E80		set strobe to inactive value
		OUT	($FE),A				;D3FE		Write Sharp Printer I/F card strobe o/p port
VF78:
		IN	A,($FE)				;DBFE		Read Sharp Printer I/F card status i/p port
		RRCA				;0F		bit 0 -> carry = busy state
		JR	NC,VF78				;30FB		if busy retry
VF7D:
		XOR	A				;AF		else, zero A = strobe active value
		OUT	($FE),A				;D3FE		Write Sharp Printer I/F card strobe o/p port
		RET				;C9
		;	LPT Status
VF81:
		IN	A,($FE)				;DBFE		read Sharp Printer I/F card status i/p port
		CP	$F2				;FEF2		is it 1111 0010?
		JR	NZ,VF7D				;20F6		if not, set strobe and exit
VF87:
		LD	A,$FF				;3EFF		else, set A
		RET				;C9		and exit
		;	UL1						driver for Centronics compatible printer using the MZ-80I/O2 card
VF8A:
		CALL	VF9E				;CD9EEF		read UL1 Status
		OR	A				;B7		check for zero (strobe inactive)
		JR	Z,VF8A				;28FA
		LD	A,C				;79
		OUT	($FD),A				;D3FD		Centronics card data o/p port
		LD	A,$00				;3E00		strobe inactive value
		OUT	($FC),A				;D3FC		Centronics card strobe o/p port
		NOP				;00
VF98:
		LD	A,$80				;3E80		strobe active value
		OUT	($FC),A				;D3FC		Centronics card strobe o/p port
		XOR	A				;AF		zero A
		RET				;C9
		;	UL1 Status
VF9E:
		IN	A,($FC)				;DBFC		read Centronics card status i/p port
		AND	$03				;E603		mask bit 2 - 7 (not busy)
		CP	$00				;FE00		check for other status
		JR	Z,VF87				;28E1
		JR	VF98				;18F0
		;	UR2 = end of file bucket
VFA8:
		LD	A,$1A				;3E1A		A = ^Z
		;	UP2 = byte bucket
VFAA:
		RET				;C9
		;	Serial Interface on MZ-8BI/O3 Card
		;	TTY O/P
VFAB:
		LD	E,C				;59		E = C = character
		LD	BC,$B2B3				;01B3B2		$B2 = Ch B data, $B3 = Ch B Control
VFAF:
		CALL	VFBB				;CDBBEF
		OR	A				;B7		check zero
		JR	Z,VFAF				;28FA
		LD	C,B				;48		C = B =
		OUT	(C),E				;ED59		character output
		RET				;C9
		;	TTY Status
VFB9:
		LD	C,$B3				;0EB3		Channel B control
VFBB:
		LD	A,$10				;3E10		A = EXT/STATUS
		OUT	(C),A				;ED79		OUT ($B3),$10
		IN	A,(C)				;ED78		IN A,($B3) = read
		AND	$0C				;E60C		mask bits 0-1 and 4-7
		CP	$0C				;FE0C		test bits 2-3
		JR	Z,VF87				;28C0		if zero, set all bits
		XOR	A				;AF		else, zero A
		RET				;C9
		;	PTP O/P (Ch A)
VFC9:
		LD	E,C				;59
		LD	BC,$B0B1				;01B1B0		$B0 = Ch A data, $B1 = Ch A Control
		JR	VFAF				;18E0
		;	TTY I/P (Ch B)
VFCF:
		LD	BC,$B2B3				;01B3B2		$B2 = Ch B data, $B3 = Ch B Control
VFD2:
		IN	A,(C)				;ED78		C = $B3 = Ch B Control - receive check
		AND	$01				;E601		mask bits 1-7
		CP	$01				;FE01
		JR	NZ,VFD2				;20F8
VFDA:
		LD	C,B				;48		C = B = $B2 = Ch B data
		IN	A,(C)				;ED78		character input
		RET				;C9
		;	PTP I/P (ChA)
VFDE:
		LD	BC,$B0B1				;01B1B0		$B0 = Ch A data, $B1 = Ch A Control
		JR	VFD2				;18EF
		;copy from $F27E to $FBC0 and $FBFC and from $F2BA to $FC34
VFE3:
		LD	HL,W27E				;217EF2		source address
		LD	DE,WBC0				;11C0FB		destination address
		LD	BC,$003C				;013C00		number of bytes
		LDIR				;EDB0		copy 60 bytes from $F27E to $FBC0
		LD	HL,W27E				;217EF2		source address
		LD	BC,$0038				;013800		number of bytes
		LDIR				;EDB0		copy 56 bytes from $F27E to $FBFC
		LD	HL,W2BA				;21BAF2		source address
		LD	BC,$0004				;010400		number of bytes
		LDIR				;EDB0		copy 4 bytes from $F2BA to $FC34
VFFE:
		RET				;C9
*	C O N S O L E   S T A T U S	;return $FF if char ready else return $00
CONST1:
		LD	A,(WBB8)				;3AB8FB		get console character
		OR	A				;B7		check for zero
		JR	NZ,W035				;2030		if not zero, return $FF and end
		CALL	W08C				;CD8CF0		else, CURSOR POSITION
		LD	A,(WBBD)				;3ABDFB		CURCHR?
		LD	C,A				;4F
		LD	HL,(WBBB)				;2ABBFB		cusor position?
		CALL	W77F				;CD7FF7
		CALL	W0B2				;CDB2F0
		PUSH	AF				;F5
		LD	A,(WBBA)				;3ABAFB
		LD	C,A				;4F
		LD	HL,(WBBB)				;2ABBFB		cusor position?
		CALL	W77F				;CD7FF7
		POP	AF				;F1
W021:
		RET	C				;D8
		LD	(WBB9),A				;32B9FB
		LD	A,(WBB8)				;3AB8FB		get console character
		OR	A				;B7		check zero
		JR	NZ,W038				;200D
		LD	HL,$FBB9				;21B9FB
W02E:
		INC	A				;3C
		LD	(WBB8),A				;32B8FB		put console character
		LD	(WBB6),HL				;22B6FB
W035:
		LD	A,$FF				;3EFF
		RET				;C9
W038:
		LD	HL,(WBB6)				;2AB6FB
		DEC	HL				;2B
		JR	W02E				;18F0
*	C O N I N			;console character into A (KEYIN)
CONIN1:
		LD	A,(WBB8)				;3AB8FB		get console character
		OR	A				;B7		check for zero
		JR	Z,W051				;280D
		DEC	A				;3D
		LD	(WBB8),A				;32B8FB		put console character
		LD	HL,(WBB6)				;2AB6FB
		LD	A,(HL)				;7E
		INC	HL				;23
		LD	(WBB6),HL				;22B6FB
		RET				;C9
W051:
		LD	HL,$FFFF				;21FFFF
		LD	(WBBE),HL				;22BEFB
		CALL	W08C				;CD8CF0		CURSOR
W05A:
		LD	HL,(WBBE)				;2ABEFB
		INC	HL				;23
		LD	(WBBE),HL				;22BEFB
		LD	A,H				;7C
		AND	$03				;E603		mask bits 2-7
		OR	L				;B5
		JR	NZ,W07A				;2013
		BIT	2,H				;CB54
		JR	Z,W070				;2805
		LD	HL,$FBBA				;21BAFB
		JR	W073				;1803
W070:
		LD	HL,WBBD				;21BDFB		cursor character
W073:
		LD	C,(HL)				;4E
		LD	HL,(WBBB)				;2ABBFB
		CALL	W77F				;CD7FF7
W07A:
		CALL	W0B2				;CDB2F0
		JR	C,W05A				;38DB
		PUSH	AF				;F5
		LD	HL,(WBBB)				;2ABBFB
		LD	A,(WBBA)				;3ABAFB
		LD	C,A				;4F
		CALL	W77F				;CD7FF7
		POP	AF				;F1
		RET				;C9
		;	CURSOR POSITION
W08C:
		CALL	W7CA				;CDCAF7		?PONT
		CALL	W7AA				;CDAAF7
		LD	A,C				;79
		LD	(WBBA),A				;32BAFB
		LD	(WBBB),HL				;22BBFB
		LD	HL,WBBD				;21BDFB
		LD	(HL),A				;77
		RES	7,A				;CBBF
		CP	$20				;FE20		is it < <SPACE>?
		JR	C,W0AF				;380C
		CP	$7F				;FE7F		is it <DEL>?
		JR	Z,W0AF				;2808
		BIT	7,(HL)				;CB7E
		SET	7,(HL)				;CBFE
		RET	Z				;C8
		RES	7,(HL)				;CBBE
		RET				;C9
W0AF:
		LD	(HL),$1F				;361F
		RET				;C9
		;	set programable interval timer controller
		;	counter 1 counts its output pulses and delivers a pulse to OUT 1 every 12 hours
		;	counter 2 counts its output pulses and repeats 0 and 1, thus working as an AM/PM flag
W0B2:
		DI				;F3		disable interrupts
		LD	A,$40				;3E40		set bit 6 = select counter 1
		OUT	($E7),A				;D3E7		set programable interval timer controller
		IN	A,($E5)				;DBE5		read Counter 1 of programable interval timer controller
		LD	B,A				;47		B = A =
		IN	A,($E5)				;DBE5		read port C1 of 8253
		EI				;FB		enable interrupts
		LD	A,(WC89)				;3A89FC		counter 1
		SUB	B				;90
		CP	$1E				;FE1E		is spin time < 14 secs?
		JR	C,W0CB				;3806
		XOR	A				;AF		else, zero A
		OUT	($DC),A				;D3DC		reset Drive Control Register
		CALL	WA1B				;CD1BFA		CLRTRKS
W0CB:
		IN	A,($E8)				;DBE8		Z80A-PIO, Port A O/P Mode 3
		AND	$E0				;E6E0		mask bits 0-4
		OR	$1B				;F61B		set bits 0,1,3 and 4
		OUT	($E8),A				;D3E8		Z80A-PIO, Port A O/P Mode 3
		LD	B,A				;47
		LD	HL,$FBB3				;21B3FB
		LD	E,$58				;1E58
		IN	A,($EA)				;DBEA		Z80A-PIO, Port B O/P Mode 3
		CPL				;2F		invert bits
		LD	(WBB3),A				;32B3FB
		XOR	A				;AF		zero A
		LD	(WBA4),A				;32A4FB
		LD	(WBA5),A				;32A5FB
W0E6:
		DEC	B				;05
		LD	A,B				;78
		OUT	($E8),A				;D3E8		Z80A-PIO, Port A O/P Mode 3
		DEC	HL				;2B
		LD	A,E				;7B
		SUB	$08				;D608
		LD	E,A				;5F
		IN	A,($EA)				;DBEA		Z80A-PIO, Port B O/P Mode 3
		LD	C,A				;4F
		CPL				;2F		invert bits
		OR	A				;B7		check for zero
		JR	Z,W127				;2831
		AND	(HL)				;A6
		JR	NZ,W115				;201C
		LD	A,(WBA5)				;3AA5FB
		OR	A				;B7		check for zero
		JR	NZ,W127				;2028
		LD	A,C				;79
		CPL				;2F		invert bits
		LD	D,E				;53
W102:
		SRL	A				;CB3F
		JR	C,W109				;3803
		INC	D				;14
		JR	W102				;18F9
W109:
		LD	A,(WBA4)				;3AA4FB
		JR	Z,W10F				;2801
		INC	A				;3C
W10F:
		INC	A				;3C
W110:
		LD	(WBA4),A				;32A4FB
		JR	W127				;1812
W115:
		LD	D,E				;53
W116:
		SRL	A				;CB3F
		JR	C,W11D				;3803
		INC	D				;14
		JR	W116				;18F9
W11D:
		LD	A,(WBA5)				;3AA5FB
W120:
		JR	Z,W123				;2801
		INC	A				;3C
W123:
		INC	A				;3C
		LD	(WBA5),A				;32A5FB
W127:
		LD	(HL),C				;71
		LD	A,B				;78
		AND	$0F				;E60F		mask top nibble
		JR	NZ,W0E6				;20B9
		LD	A,(WBA5)				;3AA5FB
		CP	$01				;FE01		is it <
		JR	C,W13F				;380B
		JR	Z,W15C				;2826
W136:
		LD	HL,$0000				;210000
		LD	(WBA6),HL				;22A6FB
W13C:
		XOR	A				;AF		zero A
		SCF				;37		set carry
		RET				;C9
W13F:
		LD	A,(WBA4)				;3AA4FB
		CP	$01				;FE01
		JP	C,W22C				;DA2CF2
		JR	NZ,W136				;20ED
		LD	HL,(WBA6)				;2AA6FB
		INC	HL				;23
		LD	(WBA6),HL				;22A6FB
		LD	A,H				;7C
		AND	$FC				;E6FC		mask bits 0-1
		JR	Z,W13C				;28E7
		LD	A,L				;7D
		AND	$7F				;E67F		mask bit 7
		JR	NZ,W13C				;20E2
		JR	W162				;1806
W15C:
		LD	HL,$0000				;210000
		LD	(WBA6),HL				;22A6FB
W162:
		LD	A,(WBB5)				;3AB5FB
		LD	HL,$FBB3				;21B3FB
		OR	(HL)				;B6
		LD	(HL),A				;77
		LD	A,D				;7A
		CP	$20				;FE20		is it < 32 (control character)?
		JR	C,W1D6				;3867
		CP	$40				;FE40		is it < 64 (non-alpha)?
		JR	C,W1AC				;3839
		CP	$50				;FE50		is it < 80 (alpha)?
		JR	C,W17B				;3804
		JR	NZ,W1D2				;2059		else, if not &7F, treat as 8 bit characters
		SUB	$01				;D601
		;	alpha characters
W17B:
		SUB	$40				;D640
		BIT	2,(HL)				;CB56
		LD	BC,W391				;0191F3		Keyboard Table 5
		JR	Z,W187				;2803
		LD	BC,W3A1				;01A1F3		Keyboard Table 6
W187:
		ADD	A,C				;81
		LD	C,A				;4F
		LD	A,$00				;3E00
		ADC	A,B				;88
		LD	B,A				;47
		LD	A,(BC)				;0A
		BIT	3,(HL)				;CB5E
		JR	Z,W19C				;280A
		CP	$20				;FE20		is it <
		JR	C,W19C				;3806
		CP	$7F				;FE7F
		JR	NC,W19C				;3002
		SET	7,A				;CBFF
W19C:
		BIT	0,(HL)				;CB46
		JR	Z,W1AA				;280A
		CP	$40				;FE40		is it <
		JR	C,W13C				;3898
		CP	$5F				;FE5F
		JR	NC,W13C				;3094
		AND	$1F				;E61F		mask bits 5 - 7
W1AA:
		OR	A				;B7		check for zero
		RET				;C9
		;	non-alpha characters
W1AC:
		SUB	$20				;D620
		BIT	2,(HL)				;CB56
		LD	BC,W331				;0131F3		Keyboard Table 2
		JR	NZ,W187				;20D2
		BIT	0,(HL)				;CB46
		LD	BC,W351				;0151F3		Keyboard Table 3
		JR	NZ,W1C5				;2009
		BIT	1,(HL)				;CB4E
		JR	NZ,W187				;20C7
		LD	BC,W311				;0111F3		Keyboard Table 1
W1C3:
		JR	W187				;18C2
W1C5:
		BIT	3,(HL)				;CB5E
		JR	Z,W187				;28BE
		RES	3,(HL)				;CB9E
		RES	0,(HL)				;CB86
		LD	BC,W371				;0171F3		Keyboard Table 4
		JR	W187				;18B5
		;	8 bit characters
W1D2:
		SUB	$36				;D636		0011 0110 -
		JR	W1E8				;1812
		;	control characters
W1D6:
		CP	$18				;FE18		is it < ?
		JR	C,W1E8				;380E		yes, goto
		JR	Z,W21B				;283F		is it = ?
		CP	$1A				;FE1A		is it < or = ^Z?
		JR	C,W21F				;383F		if < goto
		JR	Z,W223				;2841		if = ^Z goto
		CP	$1F				;FE1F		is it cursor character?
		JR	Z,W227				;2841		yes, goto
		SUB	$03				;D603		else,
		;	control characters < $18
W1E8:
		BIT	2,(HL)				;CB56		is bit 2 unset?
		JR	Z,W1EE				;2802
		ADD	A,$1E				;C61E
W1EE:
		LD	HL,WBC0				;21C0FB
		ADD	A,A				;87
		ADD	A,L				;85
		LD	L,A				;6F
		LD	A,$00				;3E00
		ADC	A,H				;8C
		LD	H,A				;67
		INC	HL				;23
		LD	A,(HL)				;7E
		OR	A				;B7		check for zero
		JR	Z,W214				;2817
		DEC	HL				;2B
		LD	L,(HL)				;6E
		LD	H,A				;67
		LD	A,(HL)				;7E
		CP	$01				;FE01
		JP	C,W13C				;DA3CF1
		JR	Z,W218				;2810
		DEC	A				;3D
		INC	HL				;23
		LD	(WBB8),A				;32B8FB		put console character
		LD	A,(HL)				;7E
		INC	HL				;23
		LD	(WBB6),HL				;22B6FB
		JR	W1AA				;1896
W214:
		DEC	HL				;2B
W215:
		LD	A,(HL)				;7E
		JR	W1AA				;1892
W218:
		INC	HL				;23
		JR	W215				;18FA
		;	control character = $18
W21B:
		LD	A,$09				;3E09		<TAB>
		JR	W1AA				;188B		check for zero
		;	control character < ^Z
W21F:
		LD	A,$20				;3E20		<SPACE>
		JR	W1AA				;1887		check for zero
		;	control character = ^Z
W223:
		LD	A,$0D				;3E0D		<CR>
		JR	W1AA				;1883		check for zero
		;	control character = $1F
W227:
		LD	A,$1B				;3E1B		<ESC>
		JP	W1AA				;C3AAF1		check for zero
W22C:
		LD	HL,$FBB4				;21B4FB
		LD	A,(WBB3)				;3AB3FB
		CP	(HL)				;BE
		JP	Z,W136				;CA36F1
		LD	(HL),A				;77
		LD	HL,$FBB5				;21B5FB
		LD	C,$E0				;0EE0
		IN	B,(C)				;ED40
		CP	$01				;FE01		down cusor
		JR	Z,W263				;2821
		CP	$02				;FE02		up cursor
		JR	Z,W26F				;2829
		CP	$08				;FE08		insert
		JR	Z,W25D				;2813
		CP	$05				;FE05		home
		JR	Z,W269				;281B
		CP	$06				;FE06		clear
		JR	Z,W275				;2823
		CP	$0C				;FE0C		reverse
		JP	NZ,W136				;C236F1
		SET	3,(HL)				;CBDE		set bit 3 of
		SET	7,B				;CBF8		set bit 7 of
		JR	W279				;181C
W25D:
		RES	3,(HL)				;CB9E
		RES	7,B				;CBB8
		JR	W279				;1816
		;	down cusor
W263:
		RES	0,(HL)				;CB86
		RES	6,B				;CBB0
		JR	W279				;1810
W269:
		SET	0,(HL)				;CBC6
		SET	6,B				;CBF0
		JR	W279				;180A
		;	up cursor
W26F:
		RES	1,(HL)				;CB8E
		RES	5,B				;CBA8
		JR	W279				;1804
W275:
		SET	1,(HL)				;CBCE
		SET	5,B				;CBE8
W279:
		OUT	(C),B				;ED41
		JP	W136				;C336F1
		;$3C bytes copied to $FBC0 and $38 bytes to $FBFC
W27E:
		DEFB	$BE,$F2 = Function Key 1
		DEFB	$C6,$F2 = Function Key 2
		DEFB	$CE,$F2 = Function Key 3
		DEFB	$D6,$F2 = Function Key 4
		DEFB	$DE,$F2 = Function Key 5
		DEFB	$E6,$F2 = Function Key 6
		DEFB	$EE,$F2 = Function Key 7
		DEFB	$F6,$F2 = Function Key 8
		DEFB	$FE,$F2 = Function Key 9
		DEFB	$06,$F3 = Function Key 10
		DEFB	$38,$00
W294:
		DEFB	$39,$00
		DEFB	$0E,$F3
		DEFB	$2E,$00
		DEFB	$2B,$00
		DEFB	$2D,$00
		DEFB	$30,$00
W2A0:
		DEFB	$31,$00
		DEFB	$32,$00
		DEFB	$33,$00
		DEFB	$34,$00
		DEFB	$35,$00
		DEFB	$36,$00
		DEFB	$37,$00
		DEFB	$0B,$00
		DEFB	$0A,$00
		DEFB	$08,$00
		DEFB	$0C,$00
		DEFB	$1E,$00
		DEFB	$7F,$00
		;4 bytes copied to $FC34
W2BA:
		DEFB	$1A,$00
		DEFB	$03,$00
*	Function Key Definitions
W2BE:
		DEFB	$04		No. of characters
		DEFM	"DIR "		Function Key 1
		2C3		DEFB	$00,$00,$00	padding
		DEFB	$03		No. of characters
		DEFM	"ED "		Function Key 2
		DEFB	$00,$00,$00,$00	padding
W2CE:
		DEFB	$04		No. of characters
		DEFM	"ERA "		Function Key 3
		DEFB	$00,$00,$00	padding
		DEFB	$04		No. of characters
		DEFM	"PIP "		Function Key 4
		DEFB	$00,$00,$00	padding
		DEFB	$04		No. of characters
		DEFM	"REN "		Function Key 5
		DEFB	$00,$00,$00	padding
		DEFB	$05		No. of characters
		DEFM	"SAVE "		Function Key 6
		DEFB	$00,$00		padding
		DEFB	$05		No. of characters
		DEFM	"STAT "		Function Key 7
		DEFB	$00,$00		padding
		DEFB	$07		No. of characters
		DEFM	"SUBMIT "	Function Key 8
		DEFB	$05		No. of characters
		DEFM	"TYPE "		Function Key 9
		DEFB	$00,$00		padding
		DEFB	$05		No. of characters
		DEFM	"USER "		Function Key 10
		DEFB	$00,$00		padding
		DEFB	$02		No. of characters
		DEFM	"00"
*	Keyboard Table "Normal Mode"
W311:
		DEFM	"/"
		DEFM	"abcdefghij"
		DEFM	"klmnopqrst"
		DEFM	"uvwxyz^\?.,"
*	Keyboard Table "Shifted Mode"
W331:
		DEFB	$84				;L arrow
		DEFM	"ABCDEFGHIJ"
		DEFM	"KLMNOPQRST"
		DEFM	"UVWXYZ~|"
		DEFB	$82				;Up arrow
		DEFM	"><"
*	Keyboard Table "Caps Lock"
W351:
		DEFM	"/ABCDEFGHIJ"
		DEFM	"KLMNOPQRST"
		DEFM	"UVWXYZ^\?.,"
*	Keyboard Table "Graphic Mode"
W371:
		DEFB	$83
		DEFB	$98
		DEFB	$88
		DEFB	$86
		DEFB	$9A
		DEFB	$9E
		DEFB	$9B
		DEFB	$99
		DEFB	$80
		DEFB	$89
		DEFB	$90
		DEFB	$8D
		DEFB	$8F
		DEFB	$92
W37F:
		DEFB	$94
		DEFB	$8C
		DEFB	$8B
		DEFB	$97
		DEFB	$9F
		DEFB	$96
		DEFB	$9C
		DEFB	$8A
		DEFB	$87
		DEFB	$95
		DEFB	$85
		DEFB	$9D
		DEFB	$8E
		DEFB	$93
		RRA				;    1F
		ADD	A,C				;    81
		RST	$38				;    FF
		SUB	C				;    91
*	Keyboard Table 5
W391:
		DEFM	"0123456789"
DEFM	":
						;-@[]_"
*	Keyboard Table 6
W3A1:
		DEFM	"!"
		DEFB	$22
		DEFM	"#$%&'()*+=`{}"
W3B1:
		LD	HL,$0050				;215000		HL = $0050
		LD	(WC39),HL				;2239FC		$0050 -> $FC39-FC3A (store for cursor X and Y)
		LD	HL,$5000				;210050		VRAM start address
		LD	C,$C0				;0EC0		C = $C0
		LD	A,(WBOOT+2)				;3A05EE		A =
		CP	$80				;FE80		is it >= $80?
		JR	NC,W3C8				;3005		Yes, branch
		LD	HL,$D000				;2100D0		else, HL = $D000
		LD	C,$80				;0E80		C = $80
W3C8:
		LD	(W7D4),HL				;22D4F7		$D000 -> $F7D4-FC3A
		LD	A,C				;79		A = C = $80
		LD	(W7C8),A				;32C8F7		$80 -> $F7C8
		CALL	W3F3				;CDF3F3		Initialise?
		CALL	W61C				;CD1CF6
		LD	HL,$F825				;2125F8		HL = address of "64k CP/M vers 2.2.2.15"
		CALL	W3E2				;CDE2F3
		LD	HL,W3F3				;21F3F3		HL = $F3F3
		LD	DE,$0024				;112400		DE = $0024
		ADD	HL,DE				;19		HL = HL + DE =
W3E2:
		LD	A,(HL)				;7E
		OR	A				;B7		check for zero
		RET	Z				;C8
		BIT	7,A				;CB7F
		JR	Z,W3EA				;2801
		CPL				;2F		invert bits
W3EA:
		LD	C,A				;4F
		PUSH	HL				;E5
		CALL	CONOUT1				;CD68F4
		POP	HL				;E1
		INC	HL				;23
		JR	W3E2				;18EF
		; Initialise?
W3F3:
		LD	B,$00				;0600
		LD	C,$E8				;0EE8		BC = $0028
		LD	A,(WC39)				;3A39FC		store for cursor X and Y
		CP	$28				;FE28		40 lines?
		JR	Z,W400				;2802
		LD	B,$20				;0620
W400:
		OUT	(C),B				;ED41
		EX	(SP),HL				;E3
		EX	(SP),HL				;E3
		IN	A,(C)				;ED78
		CP	B				;B8
		RET	Z				;C8
		LD	A,$CF				;3ECF		A = 11001111
		OUT	($E9),A				;D3E9		Select VRAM address
		OUT	($EB),A				;D3EB		Set port B of Z80-PIO to mode 3
		XOR	A				;AF		zero A
		OUT	($E9),A				;D3E9		Select VRAM address
		CPL				;2F		invert bits - A = $FFFF
		OUT	($EB),A				;D3EB		handle all port B as i/p
		OUT	(C),B				;ED41
		RET				;C9
		;"Micro Technology BIOS" (inverted)
		DEFB	$B2,$96,$9C,$8D,$90,$DF,$AB,$9A,$9C,$97,$91
		DEFB	$90,$93,$90,$98,$86,$DF,$BD,$B6,$B0,$AC
		DEFB	$F2,$F5				;CR + LF (inverted)
		DEFB	$00
W42F:
		LD	A,$FF				;3EFF		A = $FF
		RET				;C9
W432:
		LD	E,C				;59
		LD	HL,(WC45)				;2A45FC
		JP	(HL)				;E9
W437:
		BIT	5,(HL)				;CB6E		test for 1 in bit 5
		JR	NZ,W432				;20F7
		RES	6,(HL)				;CBB6
		SUB	$20				;D620
		JR	C,W478				;3837
		CP	$20				;FE20		is it >=
		JR	NC,W44B				;3006
		LD	C,A				;4F
		LD	HL,W7E5				;21E5F7
		JR	W458				;180D
W44B:
		AND	$1F				;E61F		mask bits 5 - 7
		LD	C,A				;4F
		JR	W455				;1805
		;	CONTROLS
W450:
		LD	A,C				;79
		CP	$1B				;FE1B		is it <ESC>?
		JR	Z,W465				;2810
W455:
		LD	HL,WC49				;2149FC		CTRLTABL
W458:
		LD	DE,(H048)				;ED5B4800	DSPXY
		LD	B,$00				;0600
		ADD	HL,BC				;09
		ADD	HL,BC				;09
		LD	A,(HL)				;7E
		INC	HL				;23
		LD	H,(HL)				;66
		LD	L,A				;6F
		JP	(HL)				;E9
W465:
		SET	6,(HL)				;CBF6		set bit 6
		RET				;C9
*	C O N O U T			;character output from C (PRINTC)
CONOUT1:
		LD	HL,WC38				;2138FC		HL = $FC38
		BIT	6,(HL)				;CB76		test bit 6 in byte found there
		LD	A,C				;79		A = C = character
		JR	NZ,W437				;20C7
		AND	$E0				;E6E0		mask bits 0-4
		JR	Z,W450				;28DC		CONTROLS
		BIT	7,(HL)				;CB7E		test bit 7 in byte found there
		JR	NZ,W48E				;2016
W478:
		CALL	W7CA				;CDCAF7		?PONT
		CALL	W77F				;CD7FF7
		LD	DE,(H048)				;ED5B4800	DSPXY
		;	right cursor
FWRD:
		LD	A,(WC39)				;3A39FC		LLENGTH = store for cursor X and Y
		INC	E				;1C
		CP	E				;BB
		JR	Z,W497				;280E
W489:
		LD	(H048),DE				;ED534800	DSPXY
		RET				;C9
W48E:
		LD	A,C				;79
		CP	$7F				;FE7F		is it <= $7F?
		JR	NC,W478				;30E5		if it is, jump
		SET	7,C				;CBF9		else, set bit 7
		JR	W478				;18E1		and jump
		;	Carriage Return+Line Feed
CRLF:
		LD	E,$00				;1E00
LF:
		INC	D				;14
		LD	A,(WC3C)				;3A3CFC
		CP	D				;BA
		JR	NC,W489				;30E9
		LD	D,A				;57
		LD	(H048),DE				;ED534800	DSPXY
		LD	BC,(WC41)				;ED4B41FC	SROLSIZE
		LD	DE,(WC3D)				;ED5B3DFC	SCRSTART
		LD	HL,(WC39)				;2A39FC		LLENGTH = store for cursor X and Y
		ADD	HL,DE				;19		HL = LLENGTH + SCRSTART
		CALL	W79E				;CD9EF7		MOVELDIR
		LD	BC,(WC39)				;ED4B39FC	LLENGTH
		CALL	W7B2				;CDB2F7		CLEAR
		RET				;C9
		;	backspace
BKSP:
		LD	A,E				;7B
		OR	A				;B7		check for zero
		JR	Z,W4C3				;2803
		DEC	E				;1D
		JR	W489				;18C6
W4C3:
		LD	A,(WC3B)				;3A3BFC
		CP	D				;BA
		RET	Z				;C8
		LD	A,(WC39)				;3A39FC		LLENGTH = store for cursor X and Y
		LD	E,A				;5F
		DEC	E				;1D
W4CD:
		DEC	D				;15
		JR	W489				;18B9
		;	up cursor
UP:
		LD	A,(WC3B)				;3A3BFC
		CP	D				;BA
		RET	Z				;C8
		JR	W4CD				;18F6
		;	Move Cursor to Bottom of screen
BOS:
		LD	A,(WC3C)				;3A3CFC
		LD	D,A				;57
		JR	W4E1				;1804
		;	Move cursor to Home position
HOMEC:
		LD	A,(WC3B)				;3A3BFC
		LD	D,A				;57
		;	carriage return
CR:
		LD	E,$00				;1E00
		JR	W489				;18A4
		;	Clear Screen
CLRS:
		LD	DE,(WC3D)				;ED5B3DFC	SCRSTART
		LD	BC,(WC3F)				;ED4B3FFC	SCRNSIZE
		CALL	W7B2				;CDB2F7		CLEAR
		JR	W4DD				;18EB		HOMEC
		;	tab cusor to to next 8th posn
TAB:
		INC	E				;1C
		LD	A,E				;7B
		AND	$07				;E607		mask bits 0 - 1 and 4 - 7
		JR	NZ,TAB				;20FA
		DEC	E				;1D
		JR	FWRD				;1887		cursor right
		;	video normal
NORM:
		IN	A,($E0)				;DBE0		read PA of 8255
		OR	$10				;F610		set bit 4 (invert video)
		OUT	($E0),A				;D3E0		write PA of 8255
		RET				;C9
		;	video reverse
RVS:
		IN	A,($E0)				;DBE0		read PA of 8255
		AND	$EF				;E6EF		mask bit 7 (don't alter RVS LED)
		OUT	($E0),A				;D3E0		write PA of 8255
		RET				;C9
		;	Beep
BELL:
		LD	BC,$0030				;013000
		LD	HL,$0060				;216000
W50F:
		LD	A,$05				;3E05
		CALL	W51F				;CD1FF5
		LD	A,$04				;3E04
		CALL	W51F				;CD1FF5
		DEC	BC				;0B
		LD	A,B				;78
		OR	C				;B1
		JR	NZ,W50F				;20F1
		RET				;C9
W51F:
		OUT	($E3),A				;D3E3		write mode control
		LD	D,H				;54
		LD	E,L				;5D
W523:
		DEC	DE				;1B
		LD	A,D				;7A
		OR	E				;B3
		JR	NZ,W523				;20FB
		RET				;C9
		;	highlight off
HOFF:
		LD	HL,WC38				;2138FC
		SET	7,(HL)				;CBFE		set bit 7 of
		RET				;C9
		;	highlight on
HON:
		LD	HL,WC38				;2138FC
		RES	7,(HL)				;CBBE		reset bit 7 of
		RET				;C9
		;	insert character
INS:
		LD	A,(WC39)				;3A39FC		LLENGTH = store for cursor X and Y
		SUB	E				;93
		LD	C,A				;4F
		LD	B,$00				;0600
		DEC	BC				;0B
		CALL	W7CA				;CDCAF7		?PONT
		LD	E,L				;5D
		LD	D,H				;54
		INC	DE				;13
		CALL	W78B				;CD8BF7		MOVELDDR
INS1:
		LD	C,$00				;0E00
		CALL	W77F				;CD7FF7
		RET				;C9
		;	delete character
DEL:
		LD	A,(WC39)				;3A39FC		LLENGTH = store for cursor X and Y
		SUB	E				;93
		LD	C,A				;4F
		LD	B,$00				;0600
		DEC	BC				;0B
		CALL	W7CA				;CDCAF7		?PONT
		LD	E,L				;5D
		LD	D,H				;54
		INC	HL				;23
		CALL	W79E				;CD9EF7		MOVELDIR
		DEC	HL				;2B
		JR	INS1				;18E6
		;	insert line
INSL:
		LD	E,$00				;1E00
		LD	(H048),DE				;ED534800	DSPXY
		CALL	W7CA				;CDCAF7		?PONT
		PUSH	HL				;E5
		LD	HL,(WC3D)				;2A3DFC		SCRSTART
		LD	DE,(WC41)				;ED5B41FC	SROLSIZE
		ADD	HL,DE				;19
		POP	DE				;D1
		PUSH	DE				;D5
		SBC	HL,DE				;ED52
		LD	B,H				;44
		LD	C,L				;4D
		LD	HL,(WC39)				;2A39FC		LLENGTH = store for cursor X and Y
		ADD	HL,DE				;19
		EX	DE,HL				;EB
		CALL	W78B				;CD8BF7		MOVELDDR
		POP	DE				;D1
		LD	BC,(WC39)				;ED4B39FC	LLENGTH = store for cursor X and Y
		CALL	W7B2				;CDB2F7		CLEAR
		RET				;C9
		;	delete line
DELL:
		LD	E,$00				;1E00
		LD	(H048),DE				;ED534800	DSPXY
		CALL	W7CA				;CDCAF7		?PONT
		PUSH	HL				;E5
		LD	HL,(WC3D)				;2A3DFC		SCRSTART
		LD	DE,(WC41)				;ED5B41FC	SROLSIZE
		ADD	HL,DE				;19
		POP	DE				;D1
		SBC	HL,DE				;ED52
		LD	B,H				;44
		LD	C,L				;4D
		LD	HL,(WC39)				;2A39FC		LLENGTH = store for cursor X and Y
		ADD	HL,DE				;19
		CALL	W79E				;CD9EF7		MOVELDIR
		LD	BC,(WC39)				;ED4B39FC	LLENGTH = store for cursor X and Y
		CALL	W7B2				;CDB2F7		CLEAR
		RET				;C9
		;	clear end-of-line
CLEOL:
		LD	A,(WC39)				;3A39FC		LLENGTH = store for cursor X and Y
		SUB	E				;93
		LD	C,A				;4F
		LD	B,$00				;0600
		CALL	W7CA				;CDCAF7		?PONT
		LD	E,L				;5D
		LD	D,H				;54
		CALL	W7B2				;CDB2F7		CLEAR
		RET				;C9
		;	clear end-of-screen
CLEOS:
		LD	HL,(WC3D)				;2A3DFC		SCRSTART
		LD	DE,(WC3F)				;ED5B3FFC	SCRNSIZE
		ADD	HL,DE				;19
		PUSH	HL				;E5
		CALL	W7CA				;CDCAF7		?PONT
		POP	DE				;D1
		EX	DE,HL				;EB
W5CD:
		OR	A				;B7		check for zero
		SBC	HL,DE				;ED52
		LD	B,H				;44
		LD	C,L				;4D
		CALL	W7B2				;CDB2F7		CLEAR
		RET				;C9
		;	40 column
CHR40:
		LD	HL,$0028				;212800		40 column
		LD	C,$00				;0E00
		JR	W5E2				;1805
		;	80 column
CHR80:
		LD	HL,$0050				;215000		80 column
		LD	C,$20				;0E20
W5E2:
		LD	(WC39),HL				;2239FC		LLENGTH = store for cursor X and Y
		PUSH	BC				;C5
		LD	BC,$07D0				;01D007
		LD	DE,(W7D4)				;ED5BD4F7
		CALL	W7B2				;CDB2F7		CLEAR
W5F0:
		POP	BC				;C1
W5F1:
		IN	A,($E8)				;DBE8		Z80A-PIO, Port A O/P Mode 3
		AND	$DF				;E6DF		mask bit 5
		OR	C				;B1
		OUT	($E8),A				;D3E8		Z80A-PIO, Port A O/P Mode 3
W5F8:
		CALL	W4DD				;CDDDF4		HOMEC
		CALL	W7CA				;CDCAF7		?PONT
		LD	(WC3D),HL				;223DFC		SCRSTART
		LD	DE,(WC39)				;ED5B39FC	LLENGTH = store for cursor X and Y
		LD	HL,$0000				;210000
		LD	BC,(WC3B)				;ED4B3BFC
		LD	A,B				;78
		SUB	C				;91
		JR	Z,W614				;2804
W610:
		ADD	HL,DE				;19
		DEC	A				;3D
		JR	NZ,W610				;20FC
W614:
		LD	(WC41),HL				;2241FC		SROLSIZE
		ADD	HL,DE				;19
		LD	(WC3F),HL				;223FFC		SCRNSIZE
		RET				;C9
		;	Reset the Screen and Keyboard
RESET:
		LD	HL,$1800				;210018		HL = $1800
		LD	(WC3B),HL				;223BFC		$1800 ->
		CALL	CHR80				;CDDDF5		set to 80 column
		XOR	A				;AF		zero A
		LD	(WC38),A				;3238FC		reset  flag
		CALL	NORM				;CDFBF4		set video normal
		CALL	VFE3				;CDE3EF		copy from $F27E to $FBC0 and $FBFC and from $F2BA to $FC34
		LD	HL,W7E5				;21E5F7		source address = $F7E5
		LD	DE,WC49				;1149FC		destination address = $FC49 = CTRLTABL
		LD	BC,$0040				;014000		number of bytes = 64
		LDIR				;EDB0		copy 64 bytes from $F7E5 to $FC49
		RET				;C9
		;	Get Cursor Position
GETP:
		LD	HL,$2020				;212020
		ADD	HL,DE				;19
		LD	B,L				;45
		LD	C,H				;4C
		LD	(WC47),BC				;ED4347FC
		LD	A,$02				;3E02
W647:
		LD	(WBB8),A				;32B8FB		put console character
		LD	HL,$FC47				;2147FC
		LD	(WBB6),HL				;22B6FB
		RET				;C9
		;	Poke character at VLine
POKE:
		CALL	W772				;CD72F7
		LD	(WC43),DE				;ED5343FC
		CALL	W772				;CD72F7
		LD	HL,(WC43)				;2A43FC
		LD	H,E				;63
		LD	(WC43),HL				;2243FC
		CALL	W772				;CD72F7
		LD	BC,(WC43)				;ED4B43FC
		LD	A,B				;78
		SUB	$20				;D620
		LD	HL,WC39				;2139FC		LLENGTH = store for cursor X and Y
		CP	(HL)				;BE
		JR	NC,W6DD				;306B
		LD	L,A				;6F
		LD	A,C				;79
		SUB	$20				;D620
		CP	$19				;FE19
		JR	NC,W6DD				;3063
		LD	H,A				;67
		LD	C,E				;4B
		CALL	W7E0				;CDE0F7
		CALL	W77F				;CD7FF7
		JR	W6DD				;1859
		;	Peek character at VLine
PEEK:
		CALL	W772				;CD72F7
		LD	(WC43),DE				;ED5343FC
		CALL	W772				;CD72F7
		LD	A,E				;7B
		SUB	$20				;D620
		LD	HL,WC39				;2139FC		LLENGTH = store for cursor X and Y
		CP	(HL)				;BE
		LD	C,$00				;0E00
		JR	NC,W6AA				;3011
		LD	L,A				;6F
		LD	A,(WC43)				;3A43FC
		SUB	$20				;D620
		CP	$19				;FE19
		JR	NC,W6AA				;3007
		LD	H,A				;67
		CALL	W7E0				;CDE0F7
		CALL	W7AA				;CDAAF7
W6AA:
		LD	A,C				;79
		LD	(WC47),A				;3247FC
		LD	A,$01				;3E01
		CALL	W647				;CD47F6
		JR	W6DD				;1828
		;	Set the Scrolling area
SCR:
		CALL	W772				;CD72F7
		LD	(WC43),DE				;ED5343FC
		CALL	W772				;CD72F7
		LD	HL,(WC43)				;2A43FC
W6C2:
		LD	A,E				;7B
		SUB	$20				;D620
		CP	$19				;FE19
		JR	NC,W6DD				;3014
		LD	H,A				;67
		LD	A,L				;7D
		SUB	$20				;D620
		CP	$19				;FE19
		JR	NC,W6DD				;300C
		CP	H				;BC
		JR	Z,W6D6				;2802
		JR	NC,W6DD				;3007
W6D6:
		LD	L,A				;6F
		LD	(WC3B),HL				;223BFC
		CALL	W5F8				;CDF8F5
W6DD:
		LD	A,(WC38)				;3A38FC
W6E0:
		AND	$80				;E680
		LD	(WC38),A				;3238FC
W6E5:
		RET				;C9
		;	Set Cursor Position
SETP:
		CALL	W772				;CD72F7
		LD	(WC43),DE				;ED5343FC
		CALL	W772				;CD72F7
		LD	A,E				;7B
W6F1:
		SUB	$20				;D620
		LD	HL,WC39				;2139FC		LLENGTH = store for cursor X and Y
		CP	(HL)				;BE
		JR	NC,W6DD				;30E4
		LD	E,A				;5F
		LD	HL,$FC3B				;213BFC
		LD	A,(WC43)				;3A43FC
		SUB	$20				;D620
		CP	(HL)				;BE		is it <
		JR	C,W6DD				;38D8
		INC	HL				;23
		CP	(HL)				;BE
		JR	Z,W70B				;2802
		JR	NC,W6DD				;30D2
W70B:
		LD	D,A				;57
		LD	(H048),DE				;ED534800	DSPXY
		JR	W6DD				;18CB
		;	Set programmable function Key
SETK:
		CALL	W772				;CD72F7
		LD	(WC43),DE				;ED5343FC
		CALL	W772				;CD72F7
		LD	HL,(WC43)				;2A43FC
		LD	H,E				;63
		LD	(WC43),HL				;2243FC
		CALL	W772				;CD72F7
		LD	BC,(WC43)				;ED4B43FC
		LD	D,B				;50
		LD	B,$00				;0600
		LD	A,C				;79
		AND	$3F				;E63F		mask bits 6 and 7
		CP	$3C				;FE3C		00111100
W732:
		JR	NC,W6DD				;30A9
		LD	HL,WBC0				;21C0FB
		LD	C,A				;4F
		ADD	HL,BC				;09
		ADD	HL,BC				;09
W73A:
		LD	(HL),D				;72
		INC	HL				;23
		LD	(HL),E				;73
		JR	W6DD				;189E
		;	Set control code function
SETFN:
		CALL	W772				;CD72F7
		LD	(WC43),DE				;ED5343FC
		CALL	W772				;CD72F7
		LD	A,(WC43)				;3A43FC
		SUB	$20				;D620
		CP	$20				;FE20
		JR	NC,W6DD				;308B
		LD	L,A				;6F		L = A =
		LD	H,$00				;2600
		LD	BC,$FC49				;0149FC		BC = $FC49
		ADD	HL,HL				;29		HL = HL + HL =
		ADD	HL,BC				;09		HL = HL + BC =
		EX	DE,HL				;EB		DE = HL =
		LD	A,L				;7D
		SUB	$20				;D620
		CP	$20				;FE20
		JR	NC,W76F				;300D
		LD	L,A				;6F		L = A =
		LD	H,$00				;2600		H = $00
		LD	BC,W7E5				;01E5F7		BC = $F7E5
		ADD	HL,HL				;29		HL = HL + HL =
		ADD	HL,BC				;09		HL = HL + BC =
		LD	BC,$0002				;010200		No. of bytes
		LDIR				;EDB0		copy 2 bytes from HL to DE
W76F:
		JP	W6DD				;C3DDF6
W772:
		POP	HL				;E1
		LD	(WC45),HL				;2245FC
		LD	A,(WC38)				;3A38FC
		OR	$60				;F660		set bits 5 and 6
		LD	(WC38),A				;3238FC
		RET				;C9
W77F:
		CALL	W7C4				;CDC4F7
		OUT	($E8),A				;D3E8		Z80A-PIO, Port A O/P Mode 3
		LD	(HL),C				;71
W785:
		AND	$3F				;E63F		mask bits 6 and 7
		OUT	($E8),A				;D3E8		Z80A-PIO, Port A O/P Mode 3
		EI				;FB
		RET				;C9
		;	MOVELDDR
W78B:
		LD	A,B				;78
		OR	C				;B1
		RET	Z				;C8
		ADD	HL,BC				;09
		EX	DE,HL				;EB
		ADD	HL,BC				;09
		EX	DE,HL				;EB
		DEC	HL				;2B
		DEC	DE				;1B
		CALL	W7C4				;CDC4F7
		OUT	($E8),A				;D3E8		Z80A-PIO, Port A O/P Mode 3
		LDDR				;EDB8		copy BC bytes from HL to DE
		INC	HL				;23
		JR	W785				;18E7
		;	MOVELDIR
W79E:
		LD	A,B				;78
		OR	C				;B1
		RET	Z				;C8
		CALL	W7C4				;CDC4F7
		OUT	($E8),A				;D3E8		write Z80A-PIO, Port A O/P Mode 3
		LDIR				;EDB0		copy BC bytes from HL to DE
		JR	W785				;18DB
W7AA:
		CALL	W7C4				;CDC4F7
		OUT	($E8),A				;D3E8		write Z80A-PIO, Port A O/P Mode 3
		LD	C,(HL)				;4E
		JR	W785				;18D3
		;	CLEAR
W7B2:
		LD	A,B				;78
		OR	C				;B1
		RET	Z				;C8
		PUSH	BC				;C5
		LD	H,D				;62
		LD	L,E				;6B
		LD	C,$00				;0E00
		CALL	W77F				;CD7FF7
		POP	BC				;C1
		DEC	BC				;0B
		INC	DE				;13
		CALL	W79E				;CD9EF7		MOVELDIR
		RET				;C9
		; read screen column size
W7C4:
		DI				;F3		disable interrupts
		IN	A,($E8)				;DBE8		read Z80A-PIO, Port A O/P Mode 3
		OR	$00				;F600		do nothing
		RET				;C9
		;	?PONT
W7CA:
		PUSH	BC				;C5
		LD	BC,(H048)				;ED4B4800	DSPXY
W7CF:
		LD	DE,(WC39)				;ED5B39FC	LLENGTH = store for cursor X and Y
		LD	HL,$0000				;210000
		INC	B				;04
		OR	A				;B7		check for zero
		SBC	HL,DE				;ED52
W7DA:
		ADD	HL,DE				;19
		DJNZ	W7DA				;10FD
		ADD	HL,BC				;09
		POP	BC				;C1
		RET				;C9
W7E0:
		PUSH	BC				;C5
		LD	B,H				;44
		LD	C,L				;4D
		JR	W7CF				;18EA
		;64 bytes to $FC49
W7E5:
		DEFB	$8D,$F4				;$F48D = do nothing
		DEFB	$02,$F5				;$F502 = video reverse
		DEFB	$FB,$F4				;$F4FB = video normal
		DEFB	$29,$F5				;$F529 = highlight off
		DEFB	$2F,$F5				;$F52F = highlight on
		DEFB	$D6,$F5				;$F5D6 = 40 column
		DEFB	$DD,$F5				;$F5DD = 80 column
		DEFB	$09,$F5				;$F509 = Beep
		DEFB	$BC,$F4				;$F4BC = backspace
		DEFB	$F2,$F4				;$F4F2 = TAB8
		DEFB	$99,$F4				;$F499 = linefeed
		DEFB	$D0,$F4				;$F4D0 = up cursor
		DEFB	$82,$F4				;$F482 = right cursor
		DEFB	$E1,$F4				;$F4E1 = carriage return
		DEFB	$35,$F5				;$F535 = insert character
		DEFB	$60,$F5				;$F560 = insert line
		DEFB	$4C,$F5				;$F54C = delete character
		DEFB	$89,$F5				;$F589 = delete line
		DEFB	$AF,$F5				;$F5AF = clear end-of-line
		DEFB	$BF,$F5				;$F5BF = clear end-of-screen
		DEFB	$97,$F4				;$F497 = carriage return+Line Feed
		DEFB	$D7,$F4				;$F4D7 = Move Cursor to Bottom of screen
		DEFB	$3F,$F7				;$F73F = Set control code function
		DEFB	$84,$F6				;$F684 = Peek character at VLine
		DEFB	$12,$F7				;$F712 = Set programmable function Key
		DEFB	$B5,$F6				;$F6B5 = Set the Scrolling area
		DEFB	$E5,$F4				;$F4E5 = Clear Screen
		DEFB	$1C,$F6				;$F61C = Reset the Screen and Keyboard
		DEFB	$3B,$F6				;$F63B = Get Cursor Position
		DEFB	$E6,$F6				;$F6E6 = Set Cursor Position
		DEFB	$DD,$F4				;$F4DD = Move cursor to Home position
		DEFB	$51,$F6				;$F651 = Poke character at VLine
W825:
		DEFS	"64k CP/M vers 2.2.2.15"
		DEFM	$0D
		DEFM	$0A
		DEFM	$00
*	Start of Floppy Disk Routines		*
W83E:
		XOR	A				;AF		A = 0 (FD read)
		JR	W843				;1802
W841:
		LD	A,$01				;3E01		A = 1 (FD write)
W843:
		LD	DE,(TRKNO)				;ED5B95FC	Track number
		LD	BC,(DRVNO)				;ED4B93FC	Drive number
		LD	HL,IOBUFF				;2197FC		I/O buffer address
		JP	FD1				;C326FA
DPHJMP:
		DEFB	$71,$F8				;DPHA
		DEFB	$81,$F8				;DPHB
		DEFB	$91,$F8				;DPHB
		DEFB	$A1,$F8				;DPHC
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
		DEFB	$00,$00,$00,$00
*	D I S K   P A R A M E T E R   H E A D E R   T A B L E S
*	D R I V E   A
DPHA:
		DEFB	$00,$00				;XLT
		DEFB	$00,$00				; \
		DEFB	$00,$00				;  >Scratchpad
		DEFB	$00,$00				; /
		DEFB	$9F,$FE				;DIRBUF - Directory buffer
		DEFB	$B1,$F8				;DPBS - Disk parameter block
		DEFB	$1F,$FF				;CSVA - Checksum vector scratchpad area
		DEFB	$9F,$FF				;ALVA - Allocation vector scratchpad area
*	D R I V E   B
DPHB:
		DEFB	$00,$00				;XLT
		DEFB	$00,$00				; \
		DEFB	$00,$00				;  >Scratchpad
		DEFB	$00,$00				; /
		DEFB	$9F,$FE				;DIRBUF - Directory buffer
		DEFB	$B1,$F8				;DPBS - Disk parameter block
		DEFB	$3F,$FF				;CSVB - Checksum vector scratchpad area
		DEFB	$B5,$FF				;ALVB - Allocation vector scratchpad area
*	D R I V E   C
DPHC:
		DEFB	$00,$00				;XLT
		DEFB	$00,$00				; \
		DEFB	$00,$00				;  >Scratchpad
		DEFB	$00,$00				; /
		DEFB	$9F,$FE				;DIRBUF - Directory buffer
		DEFB	$B1,$F8				;DPBS - Disk parameter block
		DEFB	$5F,$FF				;CSVC - Checksum vector scratchpad area
		DEFB	$CB,$FF				;ALVC - Allocation vector scratchpad area
*	D R I V E   D
DPHD:
		DEFB	$00,$00				;XLT
		DEFB	$00,$00				; \
		DEFB	$00,$00				;  >Scratchpad
		DEFB	$00,$00				; /
		DEFB	$9F,$FE				;DIRBUF - Directory buffer
		DEFB	$B1,$F8				;DPBS - Disk parameter block
		DEFB	$7F,$FF				;CSVD - Checksum vector scratchpad area
		DEFB	$E1,$FF				;ALVD - Allocation vector scratchpad are
*	D I S K   P A R A M E T E R   B L O C K
DPB:
		DEFB	$50,$00				;SPT=50   Logical Sectors Per Track (Physically 10 SPT)
		DEFB	$04				;BSH=4    Block Shift
		DEFB	$0F				;BLM=15   Block Mask
		DEFB	$01				;EXM=1    Extent Mask
		DEFB	$A9,$00				;DSM=169
		DEFB	$7F,$00				;DRM=127  Maximum directory entry number
		DEFB	$C0				;AL0=&C0  Directory occupies
		DEFB	$00				;AL1=&00  first two blocks
		DEFB	$20,$00				;CKS=32   Size of directory checksum vector
		DEFB	$01,$00				;OFF=1    Reserved track before logical start of disk
		; reset two flags
W8C0:
		XOR	A				;AF		zero A
		LD	(WC91),A				;3291FC		zero ? flag
		LD	(WE97),A				;3297FE		zero ? flag
W8C7:
		RET				;C9
*	H O M E				;move to the Trk 0 position on current drive
HOME1:
		LD	A,(WC92)				;3A92FC
		OR	A				;B7		check for zero
		JR	NZ,HOME2				;2003		if not zero,
		LD	(WC91),A				;3291FC		else, zero ? flag
HOME2:
		LD	C,$00				;0E00		zero C
SETTRK1:
		LD	(WC8B),BC				;ED438BFC	zero current track flag
		RET				;C9
*	S E T S E C			;set sector given by C
SETSEC1:
		LD	A,C				;79		A = sector
		LD	(SECNO),A				;328DFC		store in current sector
		RET				;C9
*	S E T D M A			;set dma set by BC
SETDMA1:
		LD	(DMAADR),BC				;ED438EFC	store in current DMA
		RET				;C9
*	S E L D S K			;select disk given by C
SELDSK1:
		LD	HL,$0000				;210000		HL = $0000
		LD	A,C				;79		A = C =  drive No.
		LD	(WC8A),A				;328AFC		drive No. -> WC8A
		CP	$10				;FE10		is it >= 16?
		RET	NC				;D0		if it is, return
		LD	B,$00				;0600		else, set BC to zero
		LD	HL,DPHJMP				;2151F8		HL = DPHA
		ADD	HL,BC				;09
		ADD	HL,BC				;09		HL = DPHA + (2 * BC)
		LD	A,(HL)				;7E		A = XLT
		INC	HL				;23		HL = address of Scratchpad
		LD	H,(HL)				;66		H =
		LD	L,A				;6F		L = A =
		RET				;C9
*	S E C T R A N			;translate the sector given by BC
SECTRAN1:
		LD	H,B				;60		H = B = hi sector
		LD	L,C				;69		L = C = lo sector
		RET				;C9
*	R E A D				;perform read operation
READ1:
		XOR	A				;AF		zero A
		LD	(WE97),A				;3297FE		reset
		INC	A				;3C		A = $01
		LD	(WE9D),A				;329DFE		$01 ->
		LD	(WE9C),A				;329CFE		$01 ->
		LD	A,$02				;3E02		A = $02
		LD	(WE9E),A				;329EFE		$02 ->
		JR	W971				;1864
*	W R I T E			;perform write operation
WRITE1:
		XOR	A				;AF		zero A
		LD	(WE9D),A				;329DFE		reset
		LD	A,C				;79		A = C =
		LD	(WE9E),A				;329EFE
		CP	$02				;FE02
		JR	NZ,WRITE2				;2017
		LD	A,$10				;3E10		16 SPT
		LD	(WE97),A				;3297FE
		LD	A,(WC8A)				;3A8AFC
		LD	(WE98),A				;3298FE
		LD	HL,(WC8B)				;2A8BFC
		LD	(WE99),HL				;2299FE
		LD	A,(SECNO)				;3A8DFC		get Sector Number
		LD	(WE9B),A				;329BFE
WRITE2:
		LD	A,(WE97)				;3A97FE
		OR	A				;B7		check for zero
		JR	Z,W969				;2833
		DEC	A				;3D
		LD	(WE97),A				;3297FE
		LD	A,(WC8A)				;3A8AFC
		LD	HL,$FE98				;2198FE
		CP	(HL)				;BE
		JR	NZ,W969				;2026
		LD	HL,(WE99)				;2A99FE
		CALL	WA13				;CD13FA
		JR	NZ,W969				;201E
		LD	A,(SECNO)				;3A8DFC		get Sector Number
		LD	HL,$FE9B				;219BFE
		CP	(HL)				;BE
		JR	NZ,W969				;2015
		INC	(HL)				;34
		LD	A,(HL)				;7E
		CP	$50				;FE50		is it < 80
		JR	C,WRITE3				;3809
		LD	(HL),$00				;3600
		LD	HL,(WE99)				;2A99FE
		INC	HL				;23
		LD	(WE99),HL				;2299FE
WRITE3:
		XOR	A				;AF		zero A
		LD	(WE9C),A				;329CFE
		JR	W971				;1808
NUMATCH9:
		XOR	A				;AF		zero A
		LD	(WE97),A				;3297FE
		INC	A				;3C		A = $01
		LD	(WE9C),A				;329CFE		$01 ->
W971:
		LD	A,$40				;3E40		A = 01000000 	C0 MODE2
		OUT	($E7),A				;D3E7
		IN	A,($E5)				;DBE5		read Counter 1 of 8253
		LD	(WC89),A				;3289FC
		IN	A,($E5)				;DBE5		read Counter 1 of 8253
		LD	A,(SECNO)				;3A8DFC		get Sector Number
		SRL	A				;CB3F
		SRL	A				;CB3F
		LD	(WC90),A				;3290FC
		LD	HL,$FC91				;2191FC
		LD	A,(HL)				;7E
		LD	(HL),$01				;3601
		OR	A				;B7		check for zero
		JR	Z,W9B4				;2825
		LD	A,(WC8A)				;3A8AFC
		LD	HL,$FC93				;2193FC
		CP	(HL)				;BE
		JR	NZ,W9A9				;2011
		LD	HL,(TRKNO)				;2A95FC		get Track number
		CALL	WA13				;CD13FA
		JR	NZ,W9A9				;2009
		LD	A,(WC90)				;3A90FC
		LD	HL,$FC94				;2194FC
		CP	(HL)				;BE
		JR	Z,W9D5				;282C
W9A9:
		LD	A,(WC92)				;3A92FC
		OR	A				;B7		check for zero
		JR	Z,W9B4				;2805
		CALL	W841				;CD41F8
		JR	NZ,WA08				;2054
W9B4:
		LD	A,(WC8A)				;3A8AFC
		LD	(DRVNO),A				;3293FC		Drive number
		LD	HL,(WC8B)				;2A8BFC
		LD	(TRKNO),HL				;2295FC		Track number
		LD	A,(WC90)				;3A90FC
		LD	(WC94),A				;3294FC
		LD	A,(WE9C)				;3A9CFE
		OR	A				;B7		check for zero
		JR	Z,W9D1				;2805
		CALL	W83E				;CD3EF8		read?
		JR	NZ,WA08				;2037
W9D1:
		XOR	A				;AF		zero A
		LD	(WC92),A				;3292FC
W9D5:
		LD	A,(SECNO)				;3A8DFC		get Sector Number
		AND	$03				;E603		mask bits 2 - 7
		LD	BC,$0080				;018000		BC = $0080
		LD	HL,IOBUFF				;2197FC		HL = I/O buffer address
		JR	Z,W9E6				;2804
W9E2:
		ADD	HL,BC				;09		HL = HL + BC = $FD17
		DEC	A				;3D
		JR	NZ,W9E2				;20FC
W9E6:
		LD	DE,(DMAADR)				;ED5B8EFC	DE = current DMA address
		LD	A,(WE9D)				;3A9DFE
		OR	A				;B7		check for zero
		JR	NZ,W9F6				;2006
		EX	DE,HL				;EB
		LD	A,$01				;3E01
		LD	(WC92),A				;3292FC
W9F6:
		LDIR				;EDB0		copy BC bytes from HL to DE
		LD	A,(WE9E)				;3A9EFE
		CP	$01				;FE01
		JR	NZ,WA11				;2012
		XOR	A				;AF		zero A
		LD	(WC92),A				;3292FC
		CALL	W841				;CD41F8		write?
		JR	Z,WA11				;2809
WA08:
		XOR	A				;AF		zero A
		LD	(WC91),A				;3291FC
		LD	(WE97),A				;3297FE
		INC	A				;3C
		RET				;C9
WA11:
		XOR	A				;AF		zero A
		RET				;C9
WA13:
		LD	BC,(WC8B)				;ED4B8BFC
		OR	A				;B7		check for zero
		SBC	HL,BC				;ED42
		RET				;C9
*		CLRTRKS
WA1B:
		LD	HL,$FFF9				;21F9FF
		LD	B,$04				;0604		counter
WA20:
		LD	(HL),$FF				;36FF
		INC	HL				;23
		DJNZ	WA20				;10FB
WA25:
		RET				;C9
		; FD I/O PORT ADDRESS
		;
CR:
		EQU 0D8H				;status/command register
TR:
		EQU 0D9H				;track register
SCR:
		EQU 0DAH				;sector register
DR:
		EQU 0DBH				;data reg
DM:
		EQU 0DCH				;MOTON
HS:
		EQU 0DDH				;head/side register
		;	Status Register bits
		;b7					;Not ready
		;b6					;Protect
		;b5					;Fault
		;b4					;Record not found
		;b3					;CRC
		;b2					;Lost data
		;b1					;DREQ
		;b0					;Busy
		;
		;
FD1:
		LD	(RWFLAG),A				;32F8FF		set R/W flag
		XOR	A				;AF		zero A
		LD	(ERRCNT),A				;32F7FF		reset zero error count
FD2:
		LD	A,(DRVNO)				;3A93FC		GET DRIVE No.
		OR	$84				;F684		set bits 2 and 7
		OUT	($DC),A				;D3DC		DRIVE SELECT MOTON
		EX	(SP),HL				;E3
		EX	(SP),HL				;E3
		LD	DE,$0000				;110000
		LD	B,$0A				;060A		counter
FD3:
		IN	A,($D8)				;DBD8		GET STATUS
		OR	$7E				;F67E		set bits 1 - 6
		CP	$FF				;FEFF		check bits 0 and 7
		JR	Z,FD4				;280A
		DEC	DE				;1B
		LD	A,D				;7A
		OR	E				;B3
		JR	NZ,FD3				;20F3
		DJNZ	FD3				;10F1
		XOR	A				;AF		zero A
		INC	A				;3C		increase A by 1
		RET				;C9
FD4:
		LD	A,(DRVNO)				;3A93FC		get Drive number
		LD	C,A				;4F		C = A = Drive number
		LD	B,$00				;0600		BC = offset by drive number
		LD	HL,$FFF9				;21F9FF
		ADD	HL,BC				;09		HL = $FFF9 + offset by drive number
		LD	A,(HL)				;7E		A = contents of $FFF9 + offset by drive number
		CPL				;2F		invert bits
		OR	A				;B7		check for zero
		JR	NZ,FD5				;2011
		LD	A,$F0				;3EF0		A = 1111 0000
		CALL	DSCMDEX				;CD92FB		Execute Disk Contoller Command to end
		RET	NZ				;C0
		IN	A,($D8)				;DBD8		GET STATUS
		OR	$62				;F662		set bits 2, 5 and 6
		CP	$FB				;FEFB		check bits 0, 1, 3, 4 and 7
		JP	NZ,DISKERR				;C22BFB
		LD	A,$FF				;3EFF		A = 1111 1111
FD5:
		OUT	($D9),A				;D3D9		Write Track Register
		CPL				;2F		invert bits
		LD	B,A				;47
		LD	A,(TRKNO)				;3A95FC		A = TRKNO
		LD	(HL),A				;77		current track number ->
		CP	B				;B8
		JR	Z,FD6				;2812
		CPL				;2F		invert bits
		OUT	($DB),A				;D3DB		Write data register
		LD	A,$E0				;3EE0		A = 1110 0001
		CALL	DSCMDEX				;CD92FB		Execute Disk Contoller Command to end
		RET	NZ				;C0
		IN	A,($D8)				;DBD8		GET STATUS
		OR	$66				;F666		set bits 1, 2, 5 and 6
		CP	$FF				;FEFF		check bits 0, 3, 4 and 7
		JP	NZ,DISKERR				;C22BFB
FD6:
		LD	A,(WC94)				;3A94FC		A = current sector number
		LD	B,$01				;0601		B = 1
		CP	$0A				;FE0A		is it < 10?
		JR	C,FD7				;3802		yes,
		LD	B,$00				;0600
FD7:
		INC	A				;3C
		CPL				;2F		invert bits
		OUT	($DA),A				;D3DA		Sector Register
		LD	A,B				;78		A = B =
		OUT	($DD),A				;D3DD		Head Select Register
		LD	HL,IOBUFF				;2197FC		I/O buffer address
		LD	A,(RWFLAG)				;3AF8FF		get R/W flag (0 = read, 1 = write)
		OR	A				;B7		check for zero
		JR	NZ,WAD6				;2031
		LD	A,$7F				;3E7F		A = 0111 1111
		DI				;F3
		CALL	WB6E				;CD6EFB		Initiate Disk Controller Command
		RET	NZ				;C0
		LD	BC,$00DB				;01DB00
WAAF:
		IN	A,($D8)				;DBD8		GET STATUS
		RRCA				;0F		bit 0 -> carry = busy state
		JR	C,WB09				;3855
		RRCA				;0F		bit 0 -> carry = busy state
		JR	C,WAAF				;38F8
		INI				;EDA2
		JR	NZ,WAAF				;20F4
WABB:
		IN	A,($D8)				;DBD8		GET STATUS
		RRCA				;0F		bit 0 -> carry = busy state
		JR	C,WB09				;3849
		RRCA				;0F		bit 0 -> carry = busy state
		JR	C,WABB				;38F8
WAC3:
		INI				;EDA2
		JR	NZ,WABB				;20F4
		EI				;FB
		CALL	WB7F				;CD7FFB
		RET	NZ				;C0
		IN	A,($D8)				;DBD8		GET STATUS
		OR	$60				;F660		set bits 5 and 6
		CP	$FF				;FEFF
WAD2:
		JR	NZ,DISKERR				;2057
		JR	WB03				;182D
		;	write sector
WAD6:
		LD	A,$5F				;3E5F		A = 0101 1111
		DI				;F3
		CALL	WB6E				;CD6EFB		Initiate Disk Controller Command
		RET	NZ				;C0
		LD	BC,$00DB				;01DB00
WAE0:
		IN	A,($D8)				;DBD8		GET STATUS
		RRCA				;0F		bit 0 -> carry = busy state
		JR	C,WB25				;3840
		RRCA				;0F
		JR	C,WAE0				;38F8
		OUTI				;EDA3
		JR	NZ,WAE0				;20F4
WAEC:
		IN	A,($D8)				;DBD8		GET STATUS
		RRCA				;0F		bit 0 -> carry = busy state
		JR	C,WB25				;3834
		RRCA				;0F
		JR	C,WAEC				;38F8
		OUTI				;EDA3
		JR	NZ,WAEC				;20F4
		EI				;FB
		CALL	WB7F				;CD7FFB
		RET	NZ				;C0
		IN	A,($D8)				;DBD8		GET STATUS
		CP	$FF				;FEFF
		JR	NZ,DISKERR				;2028
WB03:
		LD	A,$80				;3E80		A = 1000 0000
		OUT	($DC),A				;D3DC		Drive Mode (drive select & MO control)
		XOR	A				;AF		zero A
		RET				;C9
WB09:
		EI				;FB
		CALL	WB62				;CD62FB
		LD	DE,$FE97				;1197FE
		EX	DE,HL				;EB
		OR	A				;B7		check for zero
		SBC	HL,DE				;ED52
		JR	Z,WB03				;28ED
		EX	DE,HL				;EB
		LD	B,D				;42
		LD	C,E				;4B
		LD	(HL),$E5				;36E5
		DEC	BC				;0B
		JR	Z,WB03				;28E5
		LD	D,H				;54
		LD	E,L				;5D
WB20:
		INC	DE				;13
		LDIR				;EDB0		copy BC bytes from HL to DE
		JR	WB03				;18DE
WB25:
		EI				;FB
		CALL	WB62				;CD62FB
		JR	WB03				;18D8
DISKERR:
		LD	HL,(H040)				;2A4000
		INC	HL				;23
		LD	(H040),HL				;224000
		LD	A,(ERRCNT)				;3AF7FF		get zero error count
		INC	A				;3C
		LD	(ERRCNT),A				;32F7FF		set zero error count
		CP	$0A				;FE0A
		JR	NZ,WB47				;200A
		LD	A,$00				;3E00
		OUT	($DC),A				;D3DC
		CALL	WA1B				;CD1BFA		CLRTRKS
		XOR	A				;AF		zero A
		INC	A				;3C
		RET				;C9
		;	retry
WB47:
		LD	A,$2F				;3E2F		A = 00101111 =
		OUT	($D8),A				;D3D8		Command Register
		LD	A,(ERRCNT)				;3AF7FF		get zero error count
		CP	$01				;FE01
		JP	Z,FD2				;CA2DFA
		LD	A,(DRVNO)				;3A93FC		get drive number
		LD	C,A				;4F
		LD	B,$00				;0600
		LD	HL,$FFF9				;21F9FF
		ADD	HL,BC				;09
		LD	(HL),$FF				;36FF
		JP	FD2				;C32DFA
WB62:
		POP	DE				;D1
		RLCA				;07
		CP	$FF				;FEFF
		JR	NZ,DISKERR				;20C3
		LD	A,B				;78
		OR	A				;B7		check for zero
		JR	NZ,DISKERR				;20BF
		PUSH	DE				;D5
		RET				;C9
		;	Initiate Disk Controller Command
WB6E:
		OUT	($D8),A				;D3D8		Command Register
		LD	B,$00				;0600
WB72:
		IN	A,($D8)				;DBD8		GET STATUS
		RRCA				;0F		bit 0 -> carry = busy state
		JR	NC,WB7D				;3006
		DEC	B				;05
		JR	NZ,WB72				;20F8
WB7A:
		XOR	A				;AF		zero A
		INC	A				;3C
		RET				;C9
WB7D:
		XOR	A				;AF		zero A
		RET				;C9
		;	Wait for completion of Disk Controller Command
WB7F:
		LD	DE,$0000				;110000
		LD	B,$04				;0604		counter
WB84:
		IN	A,($D8)				;DBD8		GET STATUS
		RRCA				;0F		bit 0 -> carry = busy state
		JR	C,WB7D				;38F4
		DEC	DE				;1B
		LD	A,D				;7A
		OR	E				;B3		check D = E
		JR	NZ,WB84				;20F6		go around loop until D = E
		DJNZ	WB84				;10F4
		JR	WB7A				;18E8
		;	Execute Disk Contoller Command to end
DSCMDEX:
		CALL	WB6E				;CD6EFB		Initiate Disk Controller Command
		CALL	Z,WB7F				;CC7FFB
		RET	NZ				;C0
		;	delay loop
		LD	DE,$1AF4				;11F41A
WB9C:
		DEC	DE				;1B
		LD	A,D				;7A
		OR	E				;B3		check D = E
		JR	NZ,WB9C				;20FB		go around loop until D = E
		RET				;C9
		DEFB	$00,$00
WBA4:
		DEFB	$00
WBA5:
		DEFB	$00
WBA6:
		DEFB	$00
		DEFB	$00
		DEFB	$00
		DEFB	$00
		DEFB	$00
		DEFB	$00
		DEFB	$00
		DEFB	$00
		DEFB	$00
		DEFB	$00
		DEFB	$00
		DEFB	$00
		DEFB	$00
WBB3:
		DEFB	$00
		WBB4				;	DEFB	$00
WBB5:
		DEFB	$00
WBB6:
		DEFB	$00,$00
WBB8:
		DEFB	$00		console character
WBB9:
		DEFB	$00
WBBA:
		DEFB	$00
WBBB:
		DEFB	$00,$00
WBBD:
		DEFB	$00				;CURCHR
WBBE:
		DEFB	$00
		DEFB	$00
		;$3C bytes copied from $F27E
WBC0:
		DEFB	$BE,$F2 = Function Key 1
		DEFB	$C6,$F2 = Function Key 2
		DEFB	$CE,$F2 = Function Key 3
		DEFB	$D6,$F2 = Function Key 4
		DEFB	$DE,$F2 = Function Key 5
		DEFB	$E6,$F2 = Function Key 6
		DEFB	$EE,$F2 = Function Key 7
		DEFB	$F6,$F2 = Function Key 8
		DEFB	$FE,$F2 = Function Key 9
		DEFB	$06,$F3 = Function Key 10
		DEFB	$38,$00
		DEFB	$39,$00
		DEFB	$0E,$F3
		DEFB	$2E,$00
		DEFB	$2B,$00
		DEFB	$2D,$00
		DEFB	$30,$00
		DEFB	$31,$00
		DEFB	$32,$00
		DEFB	$33,$00
		DEFB	$34,$00
		DEFB	$35,$00
		DEFB	$36,$00
		DEFB	$37,$00
		DEFB	$0B,$00
		DEFB	$0A,$00
		DEFB	$08,$00
		DEFB	$0C,$00
		DEFB	$1E,$00
		DEFB	$7F,$00
		;$38 bytes copied from $F27E
WBFC:
		DEFB	$BE,$F2
		DEFB	$C6,$F2
		DEFB	$CE,$F2
		DEFB	$D6,$F2
		DEFB	$DE,$F2
		DEFB	$E6,$F2
		DEFB	$EE,$F2
		DEFB	$F6,$F2
		DEFB	$FE,$F2
		DEFB	$06,$F3
		DEFB	$38,$00
		DEFB	$39,$00
		DEFB	$0E,$F3
		DEFB	$2E,$00
		DEFB	$2B,$00
		DEFB	$2D,$00
		DEFB	$30,$00
		DEFB	$31,$00
		DEFB	$32,$00
		DEFB	$33,$00
		DEFB	$34,$00
		DEFB	$35,$00
		DEFB	$36,$00
		DEFB	$37,$00
		DEFB	$0B,$00
		DEFB	$0A,$00
		DEFB	$08,$00
		DEFB	$0C,$00
		;4 bytes copied from $F2BA
WC34:
		DEFB	$1A,$00
		DEFB	$03,$00
WC38:
		DEFB	$				;store for cursor X and Y
WC39:
		DEFB	$				;LLENGTH = store for cursor X and Y
		DEFB	$
WC3B:
		DEFB	$
WC3C:
		DEFB	$
WC3D:
		DEFB	$				;SCRSTART
		DEFB	$
WC3F:
		DEFB	$				;SCRNSIZE
		DEFB	$
WC41:
		DEFB	$				;SROLSIZE
		DEFB	$
		DEFB	$
		DEFB	$
		DEFB	$
		;64 bytes copied from $F7E5
		;	CTRLTABL
WC49:
		DEFB	$8D,$F4				;$F48D = do nothing
		DEFB	$02,$F5				;$F502 = video reverse
		DEFB	$FB,$F4				;$F4FB = video normal
		DEFB	$29,$F5				;$F529 = highlight off
		DEFB	$2F,$F5				;$F52F = highlight on
		DEFB	$D6,$F5				;$F5D6 = 40 column
		DEFB	$DD,$F5				;$F5DD = 80 column
		DEFB	$09,$F5				;$F509 = Beep
		DEFB	$BC,$F4				;$F4BC = backspace
		DEFB	$F2,$F4				;$F4F2 = TAB8
		DEFB	$99,$F4				;$F499 = linefeed
		DEFB	$D0,$F4				;$F4D0 = up cursor
		DEFB	$82,$F4				;$F482 = right cursor
		DEFB	$E1,$F4				;$F4E1 = carriage return
		DEFB	$35,$F5				;$F535 = insert character
		DEFB	$60,$F5				;$F560 = insert line
		DEFB	$4C,$F5				;$F54C = delete character
		DEFB	$89,$F5				;$F589 = delete line
		DEFB	$AF,$F5				;$F5AF = clear end-of-line
		DEFB	$BF,$F5				;$F5BF = clear end-of-screen
		DEFB	$97,$F4				;$F497 = carriage return+Line Feed
		DEFB	$D7,$F4				;$F4D7 = Move Cursor to Bottom of screen
		DEFB	$3F,$F7				;$F73F = Set control code function
		DEFB	$84,$F6				;$F684 = Peek character at VLine
		DEFB	$12,$F7				;$F712 = Set programmable function Key
		DEFB	$B5,$F6				;$F6B5 = Set the Scrolling area
		DEFB	$E5,$F4				;$F4E5 = Clear Screen
		DEFB	$1C,$F6				;$F61C = Reset the Screen and Keyboard
		DEFB	$3B,$F6				;$F63B = Get Cursor Position
		DEFB	$E6,$F6				;$F6E6 = Set Cursor Position
		DEFB	$DD,$F4				;$F4DD = Move cursor to Home position
		DEFB	$51,$F6				;$F651 = Poke character at VLine
		DEFB	$00,$00
WC8A:
		DEFB	$00				;Disk
WC8B:
		DEFB	$00,$00		:Track
SECNO:
		DEFB	$00				;Sector Number
DMAADR:
		DEFB	$00,$00				;Current DMA address
WC90:
		DEFB	$00
WC91:
		DEFB	$00
WC92:
		DEFB	$00
DRVNO:
		DEFB	$00,$00				;Drive Number
TRKNO:
		DEFB	$00,$00				;Track Number
IOBUFF:
		DEFB	$00,$00				;I/O buffer address
WD17:
		DEFB	$00,$00
WE9C:
		DEFB	$00
WE9D:
		DEFB	$00
WE9E:
		DEFB	$00,$00
WEA0:
		DEFB	$00,$00
ERRCNT:
		DEFB	$00				;error count
RWFLAG:
		DEFB	$00				;R/W flag

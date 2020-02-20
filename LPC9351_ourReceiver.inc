;This code is built ontop of Jesus Calvina Fraga's provided code which can be found on canvas
;Sub-Author: Brian Ho

; LPC9351_Receiver.asm:  This program implements a simple serial port
; communication protocol to program, verify, and read SPI flash memories.  Since
; the program was developed to store wav audio files, it also allows 
; for the playback of said audio.  It is assumed that the wav sampling rate is
; 22050Hz, 8-bit, mono.
;
; Copyright (C) 2012-2019  Jesus Calvino-Fraga, jesusc (at) ece.ubc.ca
; 
; This program is free software; you can redistribute it and/or modify it
; under the terms of the GNU General Public License as published by the
; Free Software Foundation; either version 2, or (at your option) any
; later version.
; 
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
; 
; You should have received a copy of the GNU General Public License
; along with this program; if not, write to the Free Software
; Foundation, 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
; 
; Connections:
; 
; P89LPC9351  SPI_FLASH
; P2.5        Pin 6 (SPI_CLK)
; P2.2        Pin 5 (MOSI)
; P2.3        Pin 2 (MISO)
; P2.4        Pin 1 (CS/)
; GND         Pin 4
; 3.3V        Pins 3, 7, 8
;
; P0.4 is the DAC output which should be connected to the input of an amplifier (LM386 or similar)

;---------------------------------;
; Initialize ADC1/DAC1 as DAC1.   ;
; Warning, the ADC1/DAC1 can work ;
; only as ADC or DAC, not both.   ;
; The P89LPC9351 has two ADC/DAC  ;
; interfaces.  One can be used as ;
; ADC and the other can be used   ;
; as DAC.  Also configures the    ;
; pin associated with the DAC, in ;
; this case P0.4 as 'Open Drain'. ;
;---------------------------------;
InitDAC1:
    ; Configure pin P0.4 (DAC1 output pin) as open drain
	orl	P0M1,   #00010000B
	orl	P0M2,   #00010000B
    mov ADMODB, #00101000B ; Select main clock/2 for ADC/DAC.  Also enable DAC1 output (Table 25 of reference manual)
	mov	ADCON1, #00000100B ; Enable the converter
	mov AD1DAT3, #0x80     ; Start value is 3.3V/2 (zero reference for AC WAV file)
	ret

;---------------------------------;
; Initialize the SPI interface    ;
; and the pins associated to SPI. ;
;---------------------------------;
Init_SPI:
	; Configure MOSI (P2.2), CS* (P2.4), and SPICLK (P2.5) as push-pull outputs (see table 42, page 51)
	anl P2M1, #low(not(00110100B))
	orl P2M2, #00110100B
	; Configure MISO (P2.3) as input (see table 42, page 51)
	orl P2M1, #00001000B
	anl P2M2, #low(not(00001000B)) 
	; Configure SPI
	mov SPCTL, #11010000B ; Ignore /SS, Enable SPI, DORD=0, Master=1, CPOL=0, CPHA=0, clk/4
	ret

;---------------------------------;
; Sends AND receives a byte via   ;
; SPI.                            ;
;---------------------------------;
Send_SPI:
	mov SPDAT, a
Send_SPI_1:
	mov a, SPSTAT 
	jnb acc.7, Send_SPI_1 ; Check SPI Transfer Completion Flag
	mov SPSTAT, a ; Clear SPI Transfer Completion Flag
	mov a, SPDAT ; return received byte via accumulator
	ret

;---------------------------------;
; SPI flash 'write enable'        ;
; instruction.                    ;
;---------------------------------;
Enable_Write:
	clr FLASH_CE
	mov a, #WRITE_ENABLE
	lcall Send_SPI
	setb FLASH_CE
	ret

;---------------------------------;
; This function checks the 'write ;
; in progress' bit of the SPI     ;
; flash memory.                   ;
;---------------------------------;
Check_WIP:
	clr FLASH_CE
	mov a, #READ_STATUS
	lcall Send_SPI
	mov a, #0x55
	lcall Send_SPI
	setb FLASH_CE
	jb acc.0, Check_WIP ;  Check the Write in Progress bit
	ret
	
;---------------------------------;
; CRC-CCITT (XModem) Polynomial:  ;
; x^16 + x^12 + x^5 + 1 (0x1021)  ;
; CRC in [R7,R6].                 ;
; Converted to a macro to remove  ;
; the overhead of 'lcall' and     ;
; 'ret' instructions, since this  ;
; 'routine' may be executed over  ;
; 4 million times!                ;
;---------------------------------;
;crc16:
crc16 mac
	xrl	a, r7			; XOR high of CRC with byte
	mov r0, a			; Save for later use
	mov	dptr, #CRC16_TH ; dptr points to table high
	movc a, @a+dptr		; Get high part from table
	xrl	a, r6			; XOR With low byte of CRC
	mov	r7, a			; Store to high byte of CRC
	mov a, r0			; Retrieve saved accumulator
	mov	dptr, #CRC16_TL	; dptr points to table low	
	movc a, @a+dptr		; Get Low from table
	mov	r6, a			; Store to low byte of CRC
	;ret
endmac

;---------------------------------;
; High constants for CRC-CCITT    ;
; (XModem) Polynomial:            ;
; x^16 + x^12 + x^5 + 1 (0x1021)  ;
;---------------------------------;
CRC16_TH:
	db	000h, 010h, 020h, 030h, 040h, 050h, 060h, 070h
	db	081h, 091h, 0A1h, 0B1h, 0C1h, 0D1h, 0E1h, 0F1h
	db	012h, 002h, 032h, 022h, 052h, 042h, 072h, 062h
	db	093h, 083h, 0B3h, 0A3h, 0D3h, 0C3h, 0F3h, 0E3h
	db	024h, 034h, 004h, 014h, 064h, 074h, 044h, 054h
	db	0A5h, 0B5h, 085h, 095h, 0E5h, 0F5h, 0C5h, 0D5h
	db	036h, 026h, 016h, 006h, 076h, 066h, 056h, 046h
	db	0B7h, 0A7h, 097h, 087h, 0F7h, 0E7h, 0D7h, 0C7h
	db	048h, 058h, 068h, 078h, 008h, 018h, 028h, 038h
	db	0C9h, 0D9h, 0E9h, 0F9h, 089h, 099h, 0A9h, 0B9h
	db	05Ah, 04Ah, 07Ah, 06Ah, 01Ah, 00Ah, 03Ah, 02Ah
	db	0DBh, 0CBh, 0FBh, 0EBh, 09Bh, 08Bh, 0BBh, 0ABh
	db	06Ch, 07Ch, 04Ch, 05Ch, 02Ch, 03Ch, 00Ch, 01Ch
	db	0EDh, 0FDh, 0CDh, 0DDh, 0ADh, 0BDh, 08Dh, 09Dh
	db	07Eh, 06Eh, 05Eh, 04Eh, 03Eh, 02Eh, 01Eh, 00Eh
	db	0FFh, 0EFh, 0DFh, 0CFh, 0BFh, 0AFh, 09Fh, 08Fh
	db	091h, 081h, 0B1h, 0A1h, 0D1h, 0C1h, 0F1h, 0E1h
	db	010h, 000h, 030h, 020h, 050h, 040h, 070h, 060h
	db	083h, 093h, 0A3h, 0B3h, 0C3h, 0D3h, 0E3h, 0F3h
	db	002h, 012h, 022h, 032h, 042h, 052h, 062h, 072h
	db	0B5h, 0A5h, 095h, 085h, 0F5h, 0E5h, 0D5h, 0C5h
	db	034h, 024h, 014h, 004h, 074h, 064h, 054h, 044h
	db	0A7h, 0B7h, 087h, 097h, 0E7h, 0F7h, 0C7h, 0D7h
	db	026h, 036h, 006h, 016h, 066h, 076h, 046h, 056h
	db	0D9h, 0C9h, 0F9h, 0E9h, 099h, 089h, 0B9h, 0A9h
	db	058h, 048h, 078h, 068h, 018h, 008h, 038h, 028h
	db	0CBh, 0DBh, 0EBh, 0FBh, 08Bh, 09Bh, 0ABh, 0BBh
	db	04Ah, 05Ah, 06Ah, 07Ah, 00Ah, 01Ah, 02Ah, 03Ah
	db	0FDh, 0EDh, 0DDh, 0CDh, 0BDh, 0ADh, 09Dh, 08Dh
	db	07Ch, 06Ch, 05Ch, 04Ch, 03Ch, 02Ch, 01Ch, 00Ch
	db	0EFh, 0FFh, 0CFh, 0DFh, 0AFh, 0BFh, 08Fh, 09Fh
	db	06Eh, 07Eh, 04Eh, 05Eh, 02Eh, 03Eh, 00Eh, 01Eh

;---------------------------------;
; Low constants for CRC-CCITT     ;
; (XModem) Polynomial:            ;
; x^16 + x^12 + x^5 + 1 (0x1021)  ;
;---------------------------------;
CRC16_TL:
	db	000h, 021h, 042h, 063h, 084h, 0A5h, 0C6h, 0E7h
	db	008h, 029h, 04Ah, 06Bh, 08Ch, 0ADh, 0CEh, 0EFh
	db	031h, 010h, 073h, 052h, 0B5h, 094h, 0F7h, 0D6h
	db	039h, 018h, 07Bh, 05Ah, 0BDh, 09Ch, 0FFh, 0DEh
	db	062h, 043h, 020h, 001h, 0E6h, 0C7h, 0A4h, 085h
	db	06Ah, 04Bh, 028h, 009h, 0EEh, 0CFh, 0ACh, 08Dh
	db	053h, 072h, 011h, 030h, 0D7h, 0F6h, 095h, 0B4h
	db	05Bh, 07Ah, 019h, 038h, 0DFh, 0FEh, 09Dh, 0BCh
	db	0C4h, 0E5h, 086h, 0A7h, 040h, 061h, 002h, 023h
	db	0CCh, 0EDh, 08Eh, 0AFh, 048h, 069h, 00Ah, 02Bh
	db	0F5h, 0D4h, 0B7h, 096h, 071h, 050h, 033h, 012h
	db	0FDh, 0DCh, 0BFh, 09Eh, 079h, 058h, 03Bh, 01Ah
	db	0A6h, 087h, 0E4h, 0C5h, 022h, 003h, 060h, 041h
	db	0AEh, 08Fh, 0ECh, 0CDh, 02Ah, 00Bh, 068h, 049h
	db	097h, 0B6h, 0D5h, 0F4h, 013h, 032h, 051h, 070h
	db	09Fh, 0BEh, 0DDh, 0FCh, 01Bh, 03Ah, 059h, 078h
	db	088h, 0A9h, 0CAh, 0EBh, 00Ch, 02Dh, 04Eh, 06Fh
	db	080h, 0A1h, 0C2h, 0E3h, 004h, 025h, 046h, 067h
	db	0B9h, 098h, 0FBh, 0DAh, 03Dh, 01Ch, 07Fh, 05Eh
	db	0B1h, 090h, 0F3h, 0D2h, 035h, 014h, 077h, 056h
	db	0EAh, 0CBh, 0A8h, 089h, 06Eh, 04Fh, 02Ch, 00Dh
	db	0E2h, 0C3h, 0A0h, 081h, 066h, 047h, 024h, 005h
	db	0DBh, 0FAh, 099h, 0B8h, 05Fh, 07Eh, 01Dh, 03Ch
	db	0D3h, 0F2h, 091h, 0B0h, 057h, 076h, 015h, 034h
	db	04Ch, 06Dh, 00Eh, 02Fh, 0C8h, 0E9h, 08Ah, 0ABh
	db	044h, 065h, 006h, 027h, 0C0h, 0E1h, 082h, 0A3h
	db	07Dh, 05Ch, 03Fh, 01Eh, 0F9h, 0D8h, 0BBh, 09Ah
	db	075h, 054h, 037h, 016h, 0F1h, 0D0h, 0B3h, 092h
	db	02Eh, 00Fh, 06Ch, 04Dh, 0AAh, 08Bh, 0E8h, 0C9h
	db	026h, 007h, 064h, 045h, 0A2h, 083h, 0E0h, 0C1h
	db	01Fh, 03Eh, 05Dh, 07Ch, 09Bh, 0BAh, 0D9h, 0F8h
	db	017h, 036h, 055h, 074h, 093h, 0B2h, 0D1h, 0F0h

; Approximate index of sounds in file 'project1.wav'
sound_index:
    db 0x00, 0x00, 0x2d ; 0 
    db 0x00, 0x31, 0x88 ; 1 
    db 0x00, 0x6f, 0xfe ; 2 
    db 0x00, 0xad, 0x21 ; 3 
    db 0x00, 0xf1, 0x8b ; 4 
    db 0x01, 0x37, 0x8c ; 5 
    db 0x01, 0x81, 0xd2 ; 6 
    db 0x01, 0xcf, 0x06 ; 7 
    db 0x02, 0x1b, 0x0e ; 8 
    db 0x02, 0x50, 0xff ; 9 
    db 0x02, 0x98, 0xb2 ; 10 
    db 0x02, 0xdd, 0x06 ; 11 
    db 0x03, 0x2b, 0x28 ; 12 
    db 0x03, 0x78, 0x79 ; 13 
    db 0x03, 0xc8, 0x78 ; 14 
    db 0x04, 0x1f, 0xe2 ; 15 
    db 0x04, 0x73, 0xea ; 16 
    db 0x04, 0xcf, 0x6d ; 17 
    db 0x05, 0x34, 0x7b ; 18 
    db 0x05, 0x7f, 0xca ; 19 
    db 0x05, 0xdb, 0x2d ; 20 
    db 0x06, 0x27, 0xad ; 21 -->30
    db 0x06, 0x6a, 0xaf ; 22 -->40
    db 0x06, 0xb3, 0x94 ; 23 -->50
    db 0x06, 0xfb, 0x69 ; 24 -->60
    db 0x07, 0x51, 0xf3 ; 25 -->70
    db 0x07, 0xa9, 0xac ; 26 -->80
    db 0x07, 0xeb, 0x4c ; 27 -->90
    db 0x08, 0x38, 0x9c ; 28 -->hundred
    db 0x08, 0x88, 0x9d ; 29 -->presoak
    db 0x08, 0xdf, 0x61 ; 30 -->soak
    db 0x09, 0x26, 0x2e ; 31 -->prereflow
    db 0x09, 0x8b, 0x11 ; 32 -->reflow
    db 0x09, 0xda, 0x5c ; 33 -->welcome
    db 0x0a, 0x25, 0xc7 ; 34 -->to
    db 0x0a, 0x60, 0xc2 ; 35 -->the
    db 0x0a, 0x99, 0xd8 ; 36 -->show
    db 0x0a, 0xd7, 0xca ; 37 -->entering
    db 0x0b, 0x23, 0xad ; 38 -->stage
    db 0x0b, 0x72, 0xfa ; 39 -->in
    db 0x0b, 0xad, 0x07 ; 40 
    db 0x0b, 0xf3, 0x52 

; Size of each sound in 'sound_index'
Size_Length:
    db 0x00, 0x31, 0x5b ; 0 
    db 0x00, 0x3e, 0x76 ; 1 
    db 0x00, 0x3d, 0x23 ; 2 
    db 0x00, 0x44, 0x6a ; 3 
    db 0x00, 0x46, 0x01 ; 4 
    db 0x00, 0x4a, 0x46 ; 5 
    db 0x00, 0x4d, 0x34 ; 6 
    db 0x00, 0x4c, 0x08 ; 7 
    db 0x00, 0x35, 0xf1 ; 8 
    db 0x00, 0x47, 0xb3 ; 9 
    db 0x00, 0x44, 0x54 ; 10 
    db 0x00, 0x4e, 0x22 ; 11 
    db 0x00, 0x4d, 0x51 ; 12 
    db 0x00, 0x4f, 0xff ; 13 
    db 0x00, 0x57, 0x6a ; 14 
    db 0x00, 0x54, 0x08 ; 15 
    db 0x00, 0x5b, 0x83 ; 16 
    db 0x00, 0x65, 0x0e ; 17 
    db 0x00, 0x4b, 0x4f ; 18 
    db 0x00, 0x5b, 0x63 ; 19 
    db 0x00, 0x4c, 0x80 ; 20 
    db 0x00, 0x43, 0x02 ; 21 
    db 0x00, 0x48, 0xe5 ; 22 
    db 0x00, 0x47, 0xd5 ; 23 
    db 0x00, 0x56, 0x8a ; 24 
    db 0x00, 0x57, 0xb9 ; 25 
    db 0x00, 0x41, 0xa0 ; 26 
    db 0x00, 0x4d, 0x50 ; 27 
    db 0x00, 0x50, 0x01 ; 28 
    db 0x00, 0x56, 0xc4 ; 29 
    db 0x00, 0x46, 0xcd ; 30 
    db 0x00, 0x64, 0xe3 ; 31 
    db 0x00, 0x4f, 0x4b ; 32 
    db 0x00, 0x4b, 0x6b ; 33 
    db 0x00, 0x3a, 0xfb ; 34 
    db 0x00, 0x39, 0x16 ; 35 
    db 0x00, 0x3d, 0xf2 ; 36 
    db 0x00, 0x4b, 0xe3 ; 37 
    db 0x00, 0x4f, 0x4d ; 38 
    db 0x00, 0x3a, 0x0d ; 39 
    db 0x00, 0x46, 0x4b ; 40 

; The sound and its length from the two tables above is passed in the accumulator.
Play_Sound_Index:
	setb SOUND ; Turn speaker on
	clr TMOD20 ; Stop the CCU from playing previous request
	setb FLASH_CE
	
	; There are three bytes per row in our tables, so multiply index by three
	mov b, #3
	mul ab
	mov R0, a ; Make a copy of the index*3
	
	clr FLASH_CE ; Enable SPI Flash
	mov a, #READ_BYTES
	lcall Send_SPI
	; Set the initial position in memory of where to start playing
	mov dptr, #sound_index
	mov a, R0
	movc a, @a+dptr
	lcall Send_SPI
	inc dptr
	mov a, R0
	movc a, @a+dptr
	lcall Send_SPI
	inc dptr
	mov a, R0
	movc a, @a+dptr
	lcall Send_SPI
	; Now set how many bytes to play
	mov dptr, #Size_Length
	mov a, R0
	movc a, @a+dptr
	mov w+2, a
	inc dptr
	mov a, R0
	movc a, @a+dptr
	mov w+1, a
	inc dptr
	mov a, R0
	movc a, @a+dptr
	mov w+0, a
	
	mov a, #0x00 ; Request first byte to send to DAC
	lcall Send_SPI
	
	setb TMOD20 ; Start playback by enabling CCU timer
	jb TMOD20, $
	ret








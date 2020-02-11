;
; This code handlees sending tempreture data to python using RS232 SPI 
; communication
;
; Code assumes math32.inc has been included prior to including this file 

cseg 

; ------------------------------------------------------------
; configure SPI for RS232 communication  

configRS232:
	mov	BRGCON,#0x00
	mov	BRGR1,#high(BRVAL)
	mov	BRGR0,#low(BRVAL)
	mov	BRGCON,#0x03 			; Turn-on the baud rate generator
	mov	SCON,#0x52 				; Serial port in mode 1, ren, txrdy, rxempty
	
	; Make sure that TXD(P1.0) and RXD(P1.1) are configured as bidrectional I/O
	anl	P1M1,#11111100B
	anl	P1M2,#11111100B
	ret

; ------------------------------------------------------------
; used to push a byte into the serial buffer  
; byte is assumed to be in accc 

putchar:
	jbc	TI,putchar_L1
	sjmp putchar
putchar_L1:
	mov	SBUF,a
	ret

; ------------------------------------------------------------
; send a bcd value via RS232
; bcd value expected in r0 

_sendBCD mac
	push ar0
	mov r0, %0
	lcall sendBCD
	pop ar0
endmac

sendBCD:
	push acc
	; Write most significant digit
	mov a, r0
	swap a
	anl a, #0fh
	orl a, #30h
	lcall putChar
	; write least significant digit
	mov a, r0
	anl a, #0fh
	orl a, #30h
	lcall putChar
	pop acc
	ret

; ------------------------------------------------------------
; converts the tempreture value in 'total_temp' to a bcd value
; then stores it in the var 'bcd'

grabTemp:
	
	; move total_temp to x
	mov x+0, total_temp+0
	mov x+1, total_temp+1
	mov x+2, total_temp+2
	mov x+3, total_temp+3
	
	lcall hex2bcd 			; bcd = BCD(total_temp)
	
	ret 

; ------------------------------------------------------------
; sends the temp of PCB via RS232 

sendTemp:
	lcall readTemp
	lcall grabTemp
	_sendBCD(bcd+1)
	_sendBCD(bcd+0)
	mov a, #'\r'
	lcall putChar
	mov a, #'\n'
	lcall putChar

	ret

















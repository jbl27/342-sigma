;
; Code contains instructions neded to read tempreture 
; from ADC.
; 
; This file assmes the math32.inc file has been included prior to 
; including this file 
;
; This code will assume the use of the MCP3008 as the ADC
;
; This code assumes the LM335 output is connected to CH0 of ADC
; and the K-type thermocouple op-amp output is connected to CH1
; of ADC 
;
; Call 'configBB' to initlize ports for bit-banging MCP3008
;
; call the readTemp function to read the current temprture value 
; and store it in a 4-byte varaible called 'total_temp', the value
; stored is a hex representation of the PCB temp in the reflow oven 
;
; TO communicate with the MCP3008, SPI bit-banging is used 
; 'BB' hence referse to bit-bang 

cseg 

; ------------------------------------------------------------
; port declerations 

BB_SCLK equ px.x			; slave clk pin
BB_MISO equ px.x			; Master in, slave out pin
BB_MOSI equ px.x			; Master out, slave in pin
BB_CS1	equ px.x			; chip select 1 pin 

; ----------------------------------------------------------------------
; intialize prots for bit banging of MPC3008

configBB:
	setb	BB_MISO			
	clr 	BB_SCLK				; sclk is idle low 
	setb 	BB_CS1				; cs1 is idle high 
	ret 
	
	
; ----------------------------------------------------------------------
; SPI bit-bang subroutine 
; transmitted byte expected in r0
; recivend byte stored in r1

bitBang:
	push acc
	mov r1, #0		; recived byte stored in r1
	mov r2, #8		; loop counter, 8 bits 
loopBB8bitCyle:	
	mov a, r0		; byte to write in r0
	rlc a			; carry flag has bit to write
	mov r0, a
	mov BB_MOSI, c
	setb BB_SCLK	; transmit 
	mov c, BB_MISO	; read recived bit
	mov a, r1		; save recivned bit in r1 
	rlc a
	mov r1, a
	clr BB_SCLK
	djnz r2, loopBB8bitCyle
	pop acc
	ret
	
; ----------------------------------------------------------------------
; read CH0, store in cold_temp var
; read CH1, store in hot_temp 

readADC:
	clr BB_CS1
	mov R0, #0x01 			; Start bit = 1
	lcall bitBang
	mov R0, #0x80			; read CH0 (LM335)
	lcall bitBang
	mov a, R1 				; R1 contains bits 8 and 9
	anl a, #0x03 			; We need only the two least significant bits
	mov cold_temp+1, a 		; Save result high.
	mov R0, #55H 			; It doesn't matter what we transmit...
	lcall bitBang
	mov a, r1
	mov cold_temp+0, a 		; R1 contains bits 0 to 7. Save result low.
	setb BB_CS1
	
	; to sclk cycles to ensure MCP3008 regonzises new channel read 
	cpl BB_SCLK
	cpl BB_SCLK				; firs cycle 
	cpl BB_SCLK
	cpl BB_SCLK				; second cycle 
	
	clr BB_CS1
	mov R0, #0x01 			; Start bit = 1
	lcall bitBang
	mov R0, #0x90			; read CH1 (K-type thermo op-amp)
	lcall bitBang
	mov a, R1 				; R1 contains bits 8 and 9
	anl a, #0x03 			; We need only the two least significant bits
	mov hot_temp+1, a 		; Save result high.
	mov R0, #55H 			; It doesn't matter what we transmit...
	lcall bitBang
	mov a, r1
	mov hot_temp+0, a 		; R1 contains bits 0 to 7. Save result low.
	setb BB_CS1
	ret
	
; ----------------------------------------------------------------------
; calculates the tempreture of the PCB in the reflow oven 
; stores valye in 4-byte variable 'total_temp'

calcTemp:
	
	; move hot_temp to x
	mov x+0, hot_temp+0
	mov x+1, hot_temp+1
	mov x+2, #0
	mov x+3, #0
	
	; move cold_temp to y
	mov y+0, cold_temp+0
	mov y+1, cold_temp+1
	mov y+2, #0
	mov y+3, #0
	
	lcall sub32					; x = hot_temp - cold_temp 
	Load_y(410)
	lcall mul32					; x = 410*(hot_temp - cold_temp)
	Load_y(1023)
	lcall div32					; x = 410*(hot_temp - cold_temp)/1023
	Load_y(273)
	lcall sub32					; x = 410*(hot_temp - cold_temp)/1023 - 273
	
	; move x to total_temp 
	mov total_temp+0, x+0
	mov total_temp+1, x+1
	mov total_temp+2, #0
	mov total_temp+3, #0
	
	ret
	
	
; ----------------------------------------------------------------------
; read the LM335 and the K-type thermocouple op-amp, then calculate the
; the tempreture difference 
; Read temp is stored in the 4-byte var 'total_temp'

readTemp:	
	lcall readADC
	lcall calcTemp
ret 
	
	
	
	
	
	
	
	
	
	
	
	
;
; Code contains instructions neded to read tempreture 
; from ADC.
; 
; Assumes the use of the internal ADC of the P89LPC9351
;
; This file assmes the math32.inc file has been included prior to 
; including this file 
;
; temp of PCB stroed in 4-byte var 'total_temp'


cseg 

; ----------------------------------------------------------------------
; Macro to store the reflow temp to the var 'x' and the BCD version of 
; the reflow temp to the var 'bcd'

_feel_the_burn mac
	lcall readTemp
	lcall calcTemp
	mov x+0, total_temp+0	; mov reflow_temp to x
	mov x+1, total_temp+1
	mov x+2, total_temp+2
	mov x+3, total_temp+3
	lcall hex2bcd			; bcd = BCD(total_temp)
endmac

; ----------------------------------------------------------------------
; configure ADC 

InitADC0:
	; ADC0_2 is connected to P2.1
	; ADC0_3 is connected to P2.0
	
	; Configure pins P2.1, and P2.0 as inputs
    orl P2M1, #00000011b
    anl P2M2, #11111100b
	
	; Setup ADC0
	setb BURST0 		; Autoscan continuos conversion mode
	mov ADMODB,#0x20 	; ADC0 clock is 7.3728MHz/2
	mov	ADINS,#0x0c 	; Select AD02 and AD02 as channels 
	mov	ADCON0,#0x05 	; Enable the converter and start immediately
	
	; Wait for first conversion to complete
InitADC0_L1:
	mov	a,ADCON0
	jnb	acc.3,InitADC0_L1
	ret
	
; ----------------------------------------------------------------------
; read CH0, store in cold_temp var
; read CH1, store in hot_temp 

readADC:
	
	; read signal from LM335
	mov	a, AD0DAT2
	mov cold_temp, a
	
	; read signal from k-type thermo op-amp
	mov a, AD0DAT3
	mov hot_temp, a
	
	ret
	
; ----------------------------------------------------------------------
; calculates the tempreture of the PCB in the reflow oven 
; stores valye in 4-byte variable 'total_temp'

calcTemp:
	
	; move hot_temp to x
	mov x+0, hot_temp
	mov x+1, #0
	mov x+2, #0
	mov x+3, #0
	
	; move cold_temp to y
	mov y+0, cold_temp
	mov y+1, #0
	mov y+2, #0
	mov y+3, #0
	
	lcall add32					; x = hot_temp - cold_temp 
	Load_y(330)
	lcall mul32					; x = 330*(hot_temp - cold_temp)
	Load_y(255)
	lcall div32					; x = 330*(hot_temp - cold_temp)/1023
	Load_y(273)
	lcall sub32					; x = 330*(hot_temp - cold_temp)/1023 - 273
	
	; move x to total_temp 
	mov total_temp+0, x+0
	mov total_temp+1, x+1
	mov total_temp+2, x+2
	mov total_temp+3, x+3
	
	ret
	
	
; ----------------------------------------------------------------------
; read the LM335 and the K-type thermocouple op-amp, then calculate the
; the tempreture difference 
; Read temp is stored in the 4-byte var 'total_temp'

readTemp:	
	lcall readADC
	lcall calcTemp
	ret 
	
	
	
	
	
	
	
	
	
	
	
	
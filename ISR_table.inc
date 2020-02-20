;
;	code contians interrupt service routines 
;

cseg 

; ----------------------------------------------------------------------
; timer 0 ISR

timer0_ISR:
	; reload timer
	mov TH0, #high(T0_RELOAD)
	mov TL0, #low(T0_RELOAD)

	; preserve acc and psw
	push acc	
	push psw
	
	; preserve math32 varables 
	mov x_temp+0, x+0
	mov x_temp+1, x+1
	mov x_temp+2, x+2
	mov x_temp+3, x+3
	mov y_temp+0, y+0
	mov y_temp+1, y+1
	mov y_temp+2, y+2
	mov y_temp+3, y+3
	
	; increment milli second counter 
	inc count_5ms
	
incDone:
	mov a, count_5ms
	cjne a, #200, endTimer0ISR
	
	; reset milli second counter 
	mov count_5ms, #0
	
	; 1 second has passed 	
	setb seconds_flag
	lcall sendTemp
	inc total_time+0			; increment lower 8 bits first 
	mov a, total_time			; if lower 8 bits is not zero then dont increment upper 8 bits
	jnz endTimer0ISR			
	inc total_time+1			; increment upper 8 bits

endTimer0ISR:

	; restore math32 variables
	mov x+0, x_temp+0
	mov x+1, x_temp+1
	mov x+2, x_temp+2
	mov x+3, x_temp+3
	mov y+0, y_temp+0
	mov y+1, y_temp+1
	mov y+2, y_temp+2
	mov y+3, y_temp+3
	
	pop psw
	pop acc
	reti

; ----------------------------------------------------------------------
; timer 1 ISR for PWM

Timer1_ISR:

	mov TH1, #high(T1_RELOAD)
	mov TL1, #low(T1_RELOAD)
	
	push acc
	push psw 
	
	; preserve math32 varables 
	mov x_temp+0, x+0
	mov x_temp+1, x+1
	mov x_temp+2, x+2
	mov x_temp+3, x+3
	mov y_temp+0, y+0
	mov y_temp+1, y+1
	mov y_temp+2, y+2
	mov y_temp+3, y+3
	
	
inc1_done:
	clr mf 
	mov x+0, pwm_count
	mov x+1, #0
	mov x+2, #0
	mov x+3, #0
	mov y+0, timer1_count
	mov y+1, #0
	mov y+2, #0
	mov y+3, #0
	
	lcall x_gteq_y
	jbc mf, keep_pin_high
	
	; keep pin low
	clr PWM_PIN
	inc timer1_count
	mov a, timer1_count
	cjne a, #6, done_timer1_Isr
	mov timer1_count, #0
	sjmp done_timer1_Isr
	
keep_pin_high:
	setb PWM_PIN
	inc timer1_count
	
done_timer1_Isr:

	; restore math32 variables
	mov x+0, x_temp+0
	mov x+1, x_temp+1
	mov x+2, x_temp+2
	mov x+3, x_temp+3
	mov y+0, y_temp+0
	mov y+1, y_temp+1
	mov y+2, y_temp+2
	mov y+3, y_temp+3
	
	pop psw
	pop acc
	reti
	

;---------------------------------;
; ISR for CCU.  Used to playback  ;
; the WAV file stored in the SPI  ;
; flash memory.                   ;
;---------------------------------;
CCU_ISR:
	mov TIFR2, #0 ; Clear CCU Timer Overflow Interrupt Flag bit. Actually, it clears all the bits!
	setb P2.6 ; To check the interrupt rate with oscilloscope.
	
	; The registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Check if the play counter is zero.  If so, stop playing sound.
	mov a, w+0
	orl a, w+1
	orl a, w+2
	jz stop_playing
	
	; Decrement play counter 'w'.  In this implementation 'w' is a 24-bit counter.
	mov a, #0xff
	dec w+0
	cjne a, w+0, keep_playing
	dec w+1
	cjne a, w+1, keep_playing
	dec w+2
	
keep_playing:

	lcall Send_SPI ; Read the next byte from the SPI Flash...
	mov AD1DAT3, a ; and send it to the DAC
	
	sjmp CCU_ISR_Done

stop_playing:
	clr TMOD20 		; Stop CCU timer
	setb FLASH_CE  	; Disable SPI Flash
	clr SOUND		; turn off speaker 

CCU_ISR_Done:	
	pop psw
	pop acc
	reti







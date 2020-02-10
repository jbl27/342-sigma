;
;	code contians interrupt service routines 
;

cseg 

; ----------------------------------------------------------------------
; CCU ISR. sets a second flag

CCU_ISR:
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
	clr TMOD20 ; Stop CCU timer
	setb FLASH_CE  ; Disable SPI Flash
	clr SOUND ; Turn speaker off

CCU_ISR_Done:	
	pop psw
	pop acc
	clr P2.6
	reti

; ----------------------------------------------------------------------
; timer 0 ISR

timer0_ISR:
	; reload timer
	mov TH0, #high(T0_RELOAD)
	mov TL0, #low(T0_RELOAD)

	; preserve acc and psw
	push acc	
	push psw
	
	; increment milli second counter 
	inc count_5ms
	
incDone:
	mov a, count_5ms
	cjne a, #200, endTimer0ISR
	
	; reset milli second counter 
	mov count_5ms, #0
	
	; inform main to send ASCII value  
	setb seconds_flag
	lcall sendTemp

endTimer0ISR:
	pop psw
	pop acc
	reti














end 







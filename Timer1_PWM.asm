;---------------------------------------------------
;---------------------------------------------------
;---------------------------------------------------

; THINGS TO INCLUDE IN OTHER PARTS OF CODE
; enable the PWM only when in reflow soldering mode:
; 	setb TR1

;---------------------------------------------------
; Variables
;---------------------------------------------------
PWM_OUT equ ______


;---------------------------------------------------
; Setup Timer 1 for use as PWM
;---------------------------------------------------
Timer1_Init:
	mov a, 0x89
	anl a, #0x0f
	orl a, #00100000b ;software controlled, timer, PWM mode bit 1,0
	mov 0x89, a
	mov a, 0x8f
	anl a, #0x0f
	orl a, #00010000b ;PWM mode bit 2
	mov 0x8f, a
	; enable interrupts
	setb ET0
	ret
	
	
;---------------------------------------------------
; ISR for Timer 1
;---------------------------------------------------
Timer1_ISR:
	setb PWM_OUT
	jb TF1, Timer1_ISR
	reti

;---------------------------------------------------
;---------------------------------------------------
;---------------------------------------------------























;---------------------------------------------------
;---------------------------------------------------
;---------------------------------------------------

; Another PWM implementation utilizing Timer 1
; Timer 1 interrupt is configured to trigger 
; 	every 1/PWM_FREQ s, the duty cycle is determined by
;	setting PWM_DUTY: duty cycle has resolution of 1/256
;   lower PWM_DUTY = lower percentage duty cycle
;   higher PWM_DUTY = higher percentage duty cycle
; 	duty_cycle = PWM_DUTY/255
;
; To enable PWM, set PWM_flag to 1
; ***MAKE SURE TO SET PWM_DUTY, PWM_FREQ BEFORE ENABLING***

;---------------------------------------------------
; Variables
;---------------------------------------------------
CLK         EQU  
PWM_pin     EQU  ______

bseg
PWM_flag

dseg
PWM_FREQ    ds 2
PWM_DUTY    ds 1
x_temp		ds 4
y_temp		ds 4


cseg 
;---------------------------------------------------
; Initialize Timer 1
;---------------------------------------------------
Timer1_Init:
	mov a, 0x89
	anl a, #0x0f
	orl a, #00010000b ;software controlled, timer, PWM mode bit 0,1
	mov 0x89, a
	mov a, 0x8f
	anl a, #0x0f
	orl a, #00000000b ;PWM mode bit 2
	mov a, 0x8f
	; enable interrupts
	setb ET1
	; make sure timer 1 starts off
	clr TR1
	; reset PWM_flag, PWM_FREQ, PWM_DUTY
	mov PWM_FREQ, #0
	mov PWM_FREQ+1, #0
	mov PWM_DUTY, #0
	clr PWM_flag
	clr PWM_pin
	mov TH1, #0x00
	mov TL1, #0x00
	ret

	
;---------------------------------------------------
; Check the PWM_flag and enable and disable TR1
; 	This code should be in the main loop
;---------------------------------------------------
Check_PWM_flag:
	jnb PWM_flag, PWM_off
	setb TR1
	ret
PWM_off:
	clr TR1
	clr PWM_pin
	ret
	
	
;---------------------------------------------------
; ISR Timer 1
;---------------------------------------------------
Timer1_ISR:
	clr TR1 					;turn timer 1 off
	;store x and y before using them
	mov x_temp+0, x+0
	mov x_temp+1, x+1
	mov x_temp+2, x+2
	mov x_temp+3, x+3
	mov y_temp+0, y+0
	mov y_temp+1, y+1
	mov y_temp+2, y+2
	mov y_temp+3, y+3
	;for pin high duration 
Timer1_ISR_high:
	jb PWM_pin, Timer1_ISR_low	;if pin is low
	setb PWM_pin
	Load_X(PWM_DUTY)
	lcall Timer1_ISR_calculate
	ljmp Timer1_ISR_done
	
	;for pin low duration
Timer1_ISR_low:					;else: pin is high
	clr PWM_pin
	Load_X(255-PWM_DUTY)		
	lcall Timer1_ISR_calculate
	ljmp Timer1_ISR_done
	
	;calculate TH1 and TL1...
Timer1_ISR_calculate:
	Load_Y(CLK)
	lcall mul32					;CLK*PWM_DUTY
	Load_Y(PWM_FREQ)
	lcall div32					;(CLK*PWM_DUTY)/PWM_FREQ
	Load_Y(255)
	lcall div32					;(CLK*PWM_DUTY)/(PWM_FREQ*255)
	mov y+0, x+0
	mov y+1, x+1
	mov y+2, x+2
	mov y+3, x+3
	Load_X(65523)				;65523-(CLK*PWM_DUTY)/(PWM_FREQ*255)
	lcall sub32
	mov 0x8b, x+0				;store solution in TH1, TL1
	mov 0x8d, x+1
	ret
	
Timer1_ISR_done:
	;restore x and y
	;store x and y before using them
	mov x+0, x_temp+0
	mov x+1, x_temp+1
	mov x+2, x_temp+2
	mov x+3, x_temp+3
	mov y+0, y_temp+0
	mov y+1, y_temp+1
	mov y+2, y_temp+2
	mov y+3, y_temp+3
	clr TF1						;clear interrupt flag	
	setb TR1					;start timer 1
	reti

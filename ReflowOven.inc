; Copy general ISR code and setup from Timer ISR

$NOLIST
$MODLP51
$LIST

; There is a couple of typos in MODLP51 in the definition of the timer 0/1 reload
; special function registers (SFRs), so:

TIMER0_RELOAD_L DATA 0xf2
TIMER1_RELOAD_L DATA 0xf3
TIMER0_RELOAD_H DATA 0xf4
TIMER1_RELOAD_H DATA 0xf5

CLK           EQU 22118400 ; Microcontroller system crystal frequency in Hz
TIMER0_RATE   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))
TIMER2_RATE   EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/TIMER2_RATE)))

BOOT_BUTTON   equ P4.5
UP_BUTTON	  equ P2.5
SOUND_OUT     equ P3.7
UPDOWN        equ P0.0

; Reset vector
org 0x0000
    ljmp main

; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR

; External interrupt 1 vector (not used in this code)
org 0x0013
	reti

; Timer/Counter 1 overflow interrupt vector (not used in this code)
org 0x001B
	reti

; Serial port receive/transmit interrupt vector (not used in this code)
org 0x0023 
	reti
	
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

; In the 8051 we can define direct access variables starting at location 0x30 up to location 0x7F
dseg at 0x30
Count1ms:     ds 1 ; Used to determine when half second has passed
BCD_counter:  ds 1 ; The BCD counter incrememted in the ISR and displayed in the main loop

x:   ds 4
y:   ds 4
bcd: ds 5
result: ds 2

soak_time_var: ds 1
soak_temp_var: ds 1
reflow_time_var: ds 1
reflow_temp_var: ds 1
max_temp: ds 1
max_time: ds 1

row_select_1: ds 1
time_temp_select: ds 1

; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
seconds_flag: dbit 1 ; Set to one in the ISR every time 1000 ms had passed
ToD: dbit 1; Set to one in the ISR everytime hours finishes incrementing(?)
mf: dbit 1

$NOList
$include(math32.inc) ; A library of LCD related functions and utility macros
$list

cseg
; These 'equ' must match the wiring between the microcontroller and the LCD!
LCD_RS equ P1.1
LCD_RW equ P1.2
LCD_E  equ P1.3
LCD_D4 equ P3.2
LCD_D5 equ P3.3
LCD_D6 equ P3.4
LCD_D7 equ P3.5
$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

;                          1234567890123456    <- This helps determine the location of the counter
Row1_Select_screen_1:  db 'Soak', 0
Row1_Select_screen_2:  db 'Reflow', 0
Row1_Select_screen_0:  db 'Presets', 0
Row1_Select_screen_3:  db 'Accents', 0
Row2_Select_screen_1:  db 'Time:xx Temp:xxx', 0
Welcome_to_The_Show:   db 'Welcome',0

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
Timer0_Init:
	mov a, TMOD
	anl a, #0xf0 ; Clear the bits for timer 0
	orl a, #0x01 ; Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD);*********
	mov TL0, #low(TIMER0_RELOAD)
	; Set autoreload value
	mov TIMER0_RELOAD_H, #high(TIMER0_RELOAD)
	mov TIMER0_RELOAD_L, #low(TIMER0_RELOAD)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
	ret

;---------------------------------;
; ISR for timer 0.  Set to execute;
; every 1/4096Hz to generate a    ;
; 2048 Hz square wave at pin P3.7 ;
;---------------------------------;
Timer0_ISR:
	;clr TF0  ; According to the data sheet this is done for us already.
	cpl SOUND_OUT; Connect speaker to P3.7!
	reti

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 2                     ;
;---------------------------------;
Timer2_Init:
	mov T2CON, #0 ; Stop timer/counter.  Autoreload mode.
	mov TH2, #high(TIMER2_RELOAD)
	mov TL2, #low(TIMER2_RELOAD)
	; Set the reload value
	mov RCAP2H, #high(TIMER2_RELOAD)
	mov RCAP2L, #low(TIMER2_RELOAD)
	; Init One millisecond interrupt counter.  It is a 16-bit variable made with two 8-bit parts
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Enable the timer and interrupts
    setb ET2  ; Enable timer 2 interrupt
    setb TR2  ; Enable timer 2
	ret

;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in ISR
	cpl P3.6 ; To check the interrupt rate with oscilloscope. It must be precisely a 1 ms pulse.
	
	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Increment the 16-bit one mili second counter
	inc Count1ms+0    ; Increment the low 8-bits first
	mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
	jnz Inc_Done
	inc Count1ms+1

Inc_Done:
	; Check if ONE second has passed
	mov a, Count1ms+0
	cjne a, #low(1000), Timer2_ISR_done ; Warning: this instruction changes the carry flag!
	mov a, Count1ms+1
	cjne a, #high(1000), Timer2_ISR_done
	
	; 1000 milliseconds have passed.  Set a flag so the main program knows
	setb seconds_flag ; Let the main program know ONE second had passed
	;If at alarm_min and alarm_hour, beep
	;cpl TR0 ; Enable/disable timer/counter 0. This line creates a beep-silence-beep-silence sound.
	
	; Reset to zero the milli-seconds counter, it is a 16-bit variable
ResetSeconds:
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Increment the BCD counter
	mov a, BCD_counter
	jnb UPDOWN, Timer2_ISR_decrement
	inc a
	sjmp Timer2_ISR_da

Timer2_ISR_decrement:
	add a, #0x99 ; Adding the 10-complement of -1 is like subtracting 1.
Timer2_ISR_da:
	da a ; Decimal adjust instruction.  Check datasheet for more details!
Timer2_ISR_done:
	pop psw
	pop acc
	reti



;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; loop.                           ;
;---------------------------------;
main:
	; Initialization
    mov SP, #0x7F
    lcall Timer0_Init
    lcall Timer2_Init
    ; In case you decide to use the pins of P0, configure the port in bidirectional mode:
    mov P0M0, #0
    mov P0M1, #0
    setb EA   ; Enable Global interrupts
    lcall LCD_4BIT
    ; For convenience a few handy macros are included in 'LCD_4bit.inc':
    ;Setup Selection screen
    mov row_select_1, #0x00
	
	; After initialization the program stays in this 'forever' loop
loop:
;______________________;
;CODE THAT USES BUTTONS;
;______________________;

;---------
;Welcome Screen
;Welcoming message
;---------

Welcome:
	Send_Constant_String(#Welcome_to_The_Show)
	jb Swap_But_1, ?Welcome
	Wait_Milli_Seconds(#50)
	jb Swap_But_1, ?Welcome
	jnb Swap_But_1, $ ;Waits for button to be lifted
	sjmp Selection
	
;---------
;Starting sequence
;Setup mainscreen for startup; selection screen first.
;Use a variable(?) to swap between selections. Discuss with others.
;Use two buttons; one to swap between and one to select
;---------
Selection:
	jb Swap_But_1, ?Display_Row_1
	Wait_Milli_Seconds(#50)
	jb Swap_But_1, ?Display_Row_1
	jnb Swap_But_1, $ ;Waits for button to be lifted
	;row_select_1 swaps between 0 Preset, 1 Soak, 2 Reflow, 3 Accents
	mov a, row_select_1
	inc a
	da a
	cjne a, #0x04, Loop_To_0
	mov row_select_1, a
	sjmp ?Display_Row_1
	
Loop_To_0:
	mov row_select_1, 0
	
;row_select_1 swaps between 0 Preset, 1 Soak, 2 Reflow, 3 Accents

?Display_Row_1:
	Set_Cursor(1,1)
	mov a, row_select_1
	cjne a, #0x00, display_soak ;If it is not preset, have it go to soak
	Send_Constant_String(#Row1_Select_Screen_0)
	sjmp Selection_Confirm

display_soak:
	cjne a, #0x01, display_reflow ; If it is not Soak, have it go to reflow
	Send_Constant_String(#Row1_Select_Screen_1)
	sjmp Selection_Confirm
	
display_reflow:
	cjne a, #0x02, display_accents
	Send_Constant_String(#Row1_Select_Screen_2)
	sjmp Selection_Confirm

display_accents:
	Send_Constant_String(#Row1_Select_Screen_3)

;row_1_select swaps between 0 Preset, 1 Soak, 2 Reflow, 3 Accents

Selection_Confirm:
	jb Confirm_but, Selection
	Wait_Milli_Seconds(#50)
	jb Confirm_but, Selection
	jnb Confirm_but, $ ;Waits for button to be lifted
	;Confirm button has been pressed
	mov a, row_select_1
	cjne a, #0x00, Soak_Screen_Check;If row_1_select is not 0, jump to Soak_Screen_Check
	ljmp Preset_Screen

Soak_Screen_Check:
	cjne a, #0x01, Reflow_Screen_Check;If row_1_select is not 1, jump to Reflow_Screen_Check
	ljmp Soak_Screen
	
Reflow_Screen_Check:
	cjne a, #0x02, Accent_Screen_Check;If row_1_select is not 2, jump to Accent_Screen_Check
	ljmp Reflow_Screen
	
Accent_Screen_Check:
	ljmp Accent_Screen
	
	ljmp Selection ;leave it here in case we need to loop back somehow

;---------
;Soak Screen
;Selects the time and temperature you want
;Save the value they want for temperature (in CELSIUS) as a variable that we can reuse later
;Increment with one button, decrement with another, confirm with another and cancel with another. 4 Buttons.
;Variables: soak_temp_var
;---------
Soak_Screen:
	Set_Cursor(1,1)
	Display_Constant_String(#Row1_Select_screen_1)
	Set_Cursor(2,1)
	Display_Constant_String(#Row2_Select_screen_1)
	mov time_temp_select, #0x00

Soak_Screen_Wait:
	mov a, sel_flag
	jnb a, time_temp_flags
	;If sel_flag is is pressed, swap temp and time
	cpl time_temp_select
	clr sel_flag
	

time_temp_flags:
	mov a, inc_flag
	cjne a, #0x00, inc_soak_temp
	mov a, dec_flag
	cjne a, #0x00, dec_soak_temp

inc_soak_temp:
	clr inc_flag
	mov a, time_temp_select
	cjne a, #0x00, inc_soak_time
	mov a, soak_temp_var
	inc a
	da a
	cjne a, #0xAB, max_temp_hit
	mov soak_temp_var, a
	ljmp confirm_soak_values

max_temp_hit:
	mov soak_temp_var, #0xAA
	ljmp confirm_soak_values

inc_soak_time:
	mov a, soak_time_var
	inc a
	da a
	cjne a, #0x79, max_time_hit
	mov soak_time_var, a
	ljmp confirm_soak_values

max_time_hit:
	mov soak_time_var, #0x78
	ljmp confirm_soak_values

dec_soak_temp:
	clr dec_flag
	mov a, time_temp_select
	cjne a, #0x00, dec_soak_time
	mov a, soak_temp_var
	dec a
	da a
	cjne a, #0x81, max_temp_hit
	mov soak_temp_var, a
	ljmp confirm_soak_values

min_temp_hit:
	mov soak_temp_var, #0x82
	ljmp confirm_soak_values

dec_soak_time:
	mov a, soak_time_var
	dec a
	da a
	cjne a, #0x47, max_time_hit
	mov soak_time_var, a
	ljmp confirm_soak_values

min_time_hit:
	mov soak_time_var, #0x48
	ljmp confirm_soak_values



;---------
;Reflow Screen
;Selects the time and temperature you want
;Save the value they want for temperature (in CELSIUS) as a variable that we can reuse later
;Increment with one button, decrement with another, confirm with another and cancel with another. 4 Buttons.
;Variables: reflow_temp_var
;---------
Reflow_Screen:


;---------
;Soak Screen
;Selects the temperature you want
;Save the value they want for temperature (in CELSIUS) as a variable that we can reuse later
;Increment with one button, decrement with another, confirm with another and cancel with another. 4 Buttons.
;Variables: soak_temp_var
;---------
Preset_Screen:


;---------
;Soak Screen
;Selects the temperature you want
;Save the value they want for temperature (in CELSIUS) as a variable that we can reuse later
;Increment with one button, decrement with another, confirm with another and cancel with another. 4 Buttons.
;Variables: soak_temp_var
;---------
Accent_Screen:



;----------
;Start Loop
;Starts Reflow Process
;----------

Startup:
	jb Start_But, selection
	Wait_Milli_Seconds(#50)
	jb Start_But, selection
	jnb Start_But, $ ;Waits for button to be lifted
	;valid press; begin selection
	ljmp BURNBABYBURN ;Jump to reflow process; REFLOW PROCESS NEEDS STOP-SEQUENCE CODE

;----------
;STOP SEQUENCE
;Reset all temperatures, reset all timers, and return to starting sequence
;Maybe an alert to say when it's done?
;Key it to a reset button or something
;----------
Stop_Sequence:
	

	ljmp startup

;----------
;OFF SEQUENCE
;Turns off screen
;----------
OFF_Sequence:

	ljmp startup

;_______________________;
;Running Loop Proccesses;
;_______________________;


;----------
;Reflow Process
;Begin soaking, and for how long. Then begin reflowing, and for how long.
;Is a loop that regularly checks for stop sequence
;----------
BURNBABYBURN:
;Send strings that displays the base format: Temp, time, reflow proccess state
	

	lcall Temperature_Heating();consider making 'Temperature_Heating' a macro script so that it can be reused
	;check timer
	mov a, seconds_flag
	cjne a, #0x01, BURNBABYBURN;DIIISCO INFERNO
	clr seconds_flag
	dec soak_time_var
	mov a, soak_time_var
	
;----------
;BUUURN BABY BURN
;aka heating and maintaining temperature
;Heating up the temperature
;They reccomend pulse width modulation; so maybe something that turns the heat on and off around the temp they want
;Variables: Temperature
;----------
Temperature_Heating:




	ljmp loop
END

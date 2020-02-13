;
;	Main file that runs reflow code.
;	File contains vector jump tables and such 

cseg 

$NOLIST
$MOD9351
$LIST

; ------------------------------------------------------------
; Pre-processor derectives  

CLK         equ 14746000  							; Microcontroller system clock frequency in Hz

; CCU timer constants
CCU_RATE    equ 22050    						 	; 22050Hz is the sampling rate of the wav file we are playing
CCU_RELOAD  equ ((65536-((CLK/(2*CCU_RATE)))))

; timer0 constants 
T0_RATE   	equ 400     					; 200 HZ = 5 ms
T0_RELOAD 	equ ((65536-(CLK/2*T0_RATE)))

; baud rate constatns 
BAUD        equ 115200
BRVAL       equ ((CLK/BAUD)-16)						; internal RC oscilator frrquancy 

; port declrations 
Confirm_But		equ P2.6
Start_But		equ P3.0
INC_But			equ p0.2
DEC_But			equ p0.3
LCD_RS 			equ P0.5
LCD_RW 			equ P0.6
LCD_E  			equ P0.7
LCD_D4 			equ P1.2
LCD_D5 			equ P1.3
LCD_D6 			equ P1.4
LCD_D7 			equ P1.6
FLASH_CE    	equ P2.4
SOUND       	equ P2.7
PWM_pin			equ p1.7

; Commands supported by the SPI flash memory according to the datasheet
WRITE_ENABLE     EQU 0x06  ; Address:0 Dummy:0 Num:0
WRITE_DISABLE    EQU 0x04  ; Address:0 Dummy:0 Num:0
READ_STATUS      EQU 0x05  ; Address:0 Dummy:0 Num:1 to infinite
READ_BYTES       EQU 0x03  ; Address:3 Dummy:0 Num:1 to infinite
READ_SILICON_ID  EQU 0xab  ; Address:0 Dummy:3 Num:1 to infinite
FAST_READ        EQU 0x0b  ; Address:3 Dummy:1 Num:1 to infinite
WRITE_STATUS     EQU 0x01  ; Address:0 Dummy:0 Num:1
WRITE_BYTES      EQU 0x02  ; Address:3 Dummy:0 Num:1 to 256
ERASE_ALL        EQU 0xc7  ; Address:0 Dummy:0 Num:0
ERASE_BLOCK      EQU 0xd8  ; Address:3 Dummy:0 Num:0
READ_DEVICE_ID   EQU 0x9f  ; Address:0 Dummy:2 Num:1 to infinite

; ------------------------------------------------------------
; vector table 

;reset vector 
org 0x0000
	ljmp main
	
; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp timer0_ISR

; External interrupt 1 vector (not used in this code)
org 0x0013
	reti

; Timer/Counter 1 overflow interrupt vector (not used in this code)
org 0x001B
	ljmp Timer1_ISR

; Serial port receive/transmit interrupt vector (not used in this code)
org 0x0023 
	reti

; CCU interrupt vector.  Used in this code to replay the wave file.
org 0x005b 
	ljmp CCU_ISR

; ------------------------------------------------------------
; variables  

dseg at 0x30

x:					ds 4
y:					ds 4
bcd:				ds 5
cold_temp:			ds 1		; temprtrue of cold joint
hot_temp:			ds 1		; tempreture of hot joint 
total_temp:			ds 4		; total temprtue 
count_5ms:			ds 1		; counter for timer one 
soak_time_var: 		ds 1
soak_temp_var: 		ds 1
reflow_time_var: 	ds 1
reflow_temp_var: 	ds 1
row_select_1: 		ds 1
time_temp_select: 	ds 1
preset_select: 		ds 1
w:   				ds 3 		; 24-bit play counter.  Decremented in CCU ISR.
PWM_FREQ:			ds 2
PWM_DUTY:			ds 1
x_temp:				ds 4
y_temp:				ds 4
duty_cycle:			ds 1
soak_temp_save:		ds 1
soak_time_save:		ds 1
reflow_temp_save:	ds 1
reflow_time_save:   ds 1


bseg 
mf:					dbit 1		
inc_flag: 			dbit 1		
dec_flag:			dbit 1
sel_flag:			dbit 1
seconds_flag:		dbit 1
PWM_flag:			dbit 1

; ------------------------------------------------------------
; external file includes 

cseg 

$NOLIST
$include(math32.inc)
$LIST
$NOLIST
$include(ISR_table.inc)
$LIST
$NOLIST
$include(LCD_4bit.inc)
$LIST
$NOLIST
$include(ADC_temp_read.inc)
$LIST
$NOLIST
$include(SPI_RS232.inc)
$LIST
$NOLIST
$include(LPC9351_ourReceiver.inc)
$LIST
$NOLIST
$include(pushBut.inc)
$LIST
$NOLIST
$include(EEPROM_interface.inc)
$LIST

; ------------------------------------------------------------
; code used to initialization of internal and external peripherals 

conFigTimer0:
	clr TR0			; stop timer 0
	
	; configure timer0x
	mov a, TMOD
	anl a, #0xf0 	; Clear the bits for timer 0
	orl a, #0x01 	; configer timer 0, GATE0 = 0, C/T = 0, T0M0 = 0, T0M1 = 1 
	mov TMOD, a
	
	; Auxiliary mode config 
	mov a, TAMOD
	anl a, #0xf0
	mov TAMOD,a 
	
	; load timer
	mov TH0, #high(T0_RELOAD)
	mov TL0, #low(T0_RELOAD)
	
	setb ET0
    setb TR0  		; Start timer 0
	ret

; ------------------------------------------------------------
; configers timer 1 for mode 1 

Timer1_Init:
	mov a, #0x89
	anl a, #0x0f
	orl a, #00010000b
	mov 0x89, a
	mov a, #0x8f
	anl a, #0x0f
	orl a, #00000000b 
	mov a, #0x8f
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
	
	setb ET1
	
	ret

; ------------------------------------------------------------
; configers CCU timer 

config_CCU:
	mov TH2, #high(CCU_RELOAD)
	mov TL2, #low(CCU_RELOAD)
	mov TOR2H, #high(CCU_RELOAD)
	mov TOR2L, #low(CCU_RELOAD)
	mov TCR21, #10000000b 				; Latch the reload value
	mov TICR2, #10000000b 				; Enable CCU Timer Overflow Interrupt
	setb ECCU 							; Enable CCU interrupt
	setb TMOD20 						; Start CCU timer
	ret

; ----------------------------------------------------------------------
; initialzie all ports in bi-directional mode 

Ports_Init:
    ; Configure all the ports in bidirectional mode:
    mov P0M1, #00H
    mov P0M2, #00H
    mov P1M1, #00H
    mov P1M2, #00H ; WARNING: P1.2 and P1.3 need 1 kohm pull-up resistors if used as outputs!
    mov P2M1, #00H
    mov P2M2, #00H
    mov P3M1, #00H
    mov P3M2, #00H
	ret
	
; ----------------------------------------------------------------------
; double the internal rc clk rate of the P89LPC 

Double_Clk:
    mov dptr, #CLKCON
    movx a, @dptr
    orl a, #00001000B 			; double the clock speed to 14.746MHz
    movx @dptr,a
	ret

; ----------------------------------------------------------------------
; check PWM_flag then enable/disable TR1

Check_PWM_flag:
	jnb PWM_flag, PWM_off
	setb TR1
	ret
PWM_off:
	clr TR1
	clr PWM_pin
	ret

; ----------------------------------------------------------------------
; declared constats and strings 

;                          1234567890123456    <- This helps determine the location of the counter
Row1_Select_screen_1:  db 'Soak', 0
Row1_Select_screen_2:  db 'Reflow', 0
Row1_presoak:		   db 'Pre-soak',0
Row1_prereflow:		   db 'Pre-reflow',0
Row1_cooldown:		   db 'Cooldown', 0
Row1_Select_screen_0:  db 'Presets', 0
Row2_Select_screen_1:  db 'Time    Temp', 0
Row2_Preset1:		   db 'Preset', 0
Welcome_to_The_Show:   db 'Welcome',0
Powering_Down:		   db 'Powering Down',0

; ---------------------------------------------
; the following code moves a given varaible to 
; x then converts that value to bcd 

_convert_to_bcd mac 
	mov x+0, %0
	mov x+1, #0
	mov x+2, #0
	mov x+3, #0
	lcall hex2bcd 
endmac 

; ------------------------------------------------------------
; Main program 
; ------------------------------------------------------------

main:
	; Initialization
	mov SP, #0x7F
    
	; initialize internal and external peripherals 
    lcall Ports_Init
	lcall Double_Clk
	lcall LCD_4bit				
	lcall configRS232			
	lcall InitADC0	
	lcall InitDAC1
    lcall config_CCU			
	lcall conFigTimer0
	lcall Timer1_Init
	lcall Init_SPI
	
	
	mov row_select_1, #0x00		;Setup Selection screen 
	mov soak_temp_save, #30
	mov soak_time_save, #10
	mov reflow_temp_save, #30
	mov reflow_time_save, #10
	mov preset_select, #0x01
	setb EA   					; enable interrupts 

; After initialization the program stays in this 'forever' loop


;-------------------------------------------------------
;Welcome Screen
;Welcoming message
;-------------------------------------------------------
	
	
Welcome:

	lcall LCD_4bit
	Wait_Milli_Seconds(#40)
	Set_Cursor(1,1)		
	Send_Constant_String(#Welcome_to_The_Show)
	mov a, #33	
	lcall Play_sound_index
	mov a, #34
	lcall Play_sound_index
	mov a, #35
	lcall Play_sound_index
	mov a, #36
	lcall Play_sound_index
	Wait_Milli_seconds(#40)
	Set_Cursor(1,1)		; ***!!!
	Send_Constant_String(#Welcome_to_The_Show)
;--------------------------------------------------
;Starting sequence
;Setup mainscreen for startup; selection screen first.
;Use a variable(?) to swap between selections. Discuss with others.
;Use two buttons; one to swap between and one to select
;-----------------------------------------------------
Selection:
	;Check if start button is pressed
	ljmp Startup

?Startmofo:	
	jb INC_But, ?Display_Row_1
	Wait_Milli_Seconds(#50)
	jb INC_But, ?Display_Row_1
	jnb INC_But, $ ;Waits for button to be lifted
	lcall LCD_4bit
	Wait_Milli_Seconds(#50)
	;row_select_1 swaps between 0 Preset, 1 Soak, 2 Reflow
	mov a, row_select_1
	inc a
	cjne a, #0x03, INCTHATSHIT
	mov row_select_1, #0
	sjmp ?Display_Row_1
	
INCTHATSHIT:
	mov row_select_1, a
	
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
	Send_Constant_String(#Row1_Select_Screen_2)
	sjmp Selection_Confirm

;row_1_select swaps between 0 Preset, 1 Soak, 2 Reflow

Selection_Confirm:
	jb Confirm_But, Jump_Selection
	Wait_Milli_Seconds(#50)
	jb Confirm_But, Jump_Selection
	jnb Confirm_But, $ ;Waits for button to be lifted
	;Confirm button has been pressed
	mov a, row_select_1
	cjne a, #0x00, Soak_Screen_Check;If row_1_select is not 0, jump to Soak_Screen_Check
	ljmp Preset_Screen

Soak_Screen_Check:
	cjne a, #0x01, Reflow_Screen_Check;If row_1_select is not 1, jump to Reflow_Screen_Check
	ljmp Soak_Screen
	
Reflow_Screen_Check:
	ljmp Reflow_Screen

Jump_Selection:
	ljmp selection

;-----------------------------------
;Start Loop
;Starts Reflow Process
;----------------------------------

Startup:
	jb Start_But, not_starting
	Wait_Milli_Seconds(#50)
	jb Start_But, not_starting
	jnb Start_But, $ ;Waits for button to be lifted
	;valid press; begin selection
	ljmp BURNBABYBURN ;Jump to reflow process; REFLOW PROCESS NEEDS STOP-SEQUENCE CODE

not_starting:
	ljmp ?Startmofo

;--------------------------------------------------
;Soak Screen
;Selects the time and temperature you want
;Save the value they want for temperature (in CELSIUS) as a variable that we can reuse later
;Increment with one button, decrement with another, confirm with another and cancel with another. 4 Buttons.
;Variables: soak_temp_var
;---------====================================----
Soak_Screen:
	Set_Cursor(1,1)
	Send_Constant_String(#Row1_Select_screen_1)
	Set_Cursor(2,1)
	Send_Constant_String(#Row2_Select_screen_1)
	mov soak_temp_var, soak_temp_save
	mov soak_time_var, soak_time_save 
	mov time_temp_select, #0
	clr a
	ljmp display_soak_values

Soak_Screen_Wait:
	lcall pollStart
	lcall pollInc
	lcall pollDec
	jbc sel_flag, switch_soak_sel
	jbc inc_flag, inc_soak_temp
	jbc dec_flag, dec_soak_temp
	ljmp confirm_soak_values
	
switch_soak_sel:
	inc time_temp_select
	mov a, time_temp_select
	cjne a, #0x02, ?confirm_soak_values
	mov time_temp_select, #0
	ljmp confirm_soak_values
	
?confirm_soak_values:
	ljmp confirm_soak_values

inc_soak_temp:
	mov a, time_temp_select
	cjne a, #0x00, inc_soak_time
	mov a, soak_temp_var
	inc a
	cjne a, #0xAB, max_temp_hit	;if dose not meet 170 jmp!
	mov soak_temp_var, #0xAA
	ljmp display_soak_values

max_temp_hit:
	mov soak_temp_var, a
	ljmp display_soak_values

inc_soak_time:
	mov a, soak_time_var
	inc a
	cjne a, #0x4e, max_time_hit
	mov soak_time_var, #0x4e
	ljmp display_soak_values

max_time_hit:
	mov soak_time_var, a
	ljmp display_soak_values

dec_soak_temp:
	mov a, time_temp_select
	cjne a, #0x00, dec_soak_time
	mov a, soak_temp_var
	dec a
	cjne a, #0x51, min_temp_hit	;if it is NOT 81, jump and improve
	mov soak_temp_var, #0x52	;if it IS 81, increase back to 82
	ljmp display_soak_values

min_temp_hit:
	mov soak_temp_var, a
	ljmp display_soak_values

dec_soak_time:
	mov a, soak_time_var
	dec a
	cjne a, #0x2f, max_time_hit ;if it is NOT 47, jump 
	mov soak_time_var, #0x30 ;if it IS 47, move to 48
	ljmp display_soak_values

min_time_hit:
	mov soak_time_var, a
	ljmp display_soak_values

display_soak_values:
	Set_Cursor(2,6)
	_convert_to_bcd(soak_time_var)
	Display_BCD(bcd+0)
	Set_Cursor(2,14)
	_convert_to_bcd(soak_temp_var)
	lcall LCD_3BCD
	
confirm_soak_values:
	jb Confirm_but, ?Soak_Screen_Wait
	Wait_Milli_Seconds(#50)
	jb Confirm_but, ?Soak_Screen_Wait
	jnb Confirm_but, $ 					;Waits for button to be lifted
	
	;Confirm button has been pressed
	lcall LCD_4bit
	Wait_Milli_Seconds(#50)
	mov soak_temp_save, soak_temp_var
	mov soak_time_save, soak_time_var
	ljmp Selection

?Soak_Screen_Wait:
	ljmp Soak_Screen_Wait

;--------------------------------------------------
;Reflow Screen
;Selects the time and temperature you want
;Save the value they want for temperature (in CELSIUS) as a variable that we can reuse later
;Increment with one button, decrement with another, confirm with another and cancel with another. 4 Buttons.
;Variables: reflow_temp_var
;--------------------------------------------------
Reflow_Screen:
	Set_Cursor(1,1)
	Send_Constant_String(#Row1_Select_screen_2)
	Set_Cursor(2,1)
	Send_Constant_String(#Row2_Select_screen_1)
	mov reflow_temp_var, reflow_temp_save
	mov reflow_time_var, reflow_time_save
	mov time_temp_select, #0
	ljmp display_reflow_values

reflow_Screen_Wait:
	lcall pollStart
	lcall pollInc
	lcall pollDec
	jbc sel_flag, switch_reflow_sel
	jbc inc_flag, inc_reflow_temp
	jbc dec_flag, dec_reflow_temp
	ljmp confirm_reflow_values
	
switch_reflow_sel:
	inc time_temp_select
	mov a, time_temp_select
	cjne a, #0x02, ?confirm_reflow_values
	mov time_temp_select, #0
	ljmp confirm_reflow_values
	
?confirm_reflow_values:
	ljmp confirm_reflow_values

inc_reflow_temp:
	mov a, time_temp_select
	cjne a, #0x00, inc_reflow_time
	mov a, reflow_temp_var
	inc a
	cjne a, #236, max_temp_miss	;if dose not meet 170 jmp!
	mov reflow_temp_var, #235
	ljmp display_reflow_values

max_temp_miss:
	mov reflow_temp_var, a
	ljmp display_reflow_values

inc_reflow_time:
	mov a, reflow_time_var
	inc a
	cjne a, #76, max_time_miss
	mov reflow_time_var, #75
	ljmp display_reflow_values

max_time_miss:
	mov reflow_time_var, a
	ljmp display_reflow_values

dec_reflow_temp:
	mov a, time_temp_select
	cjne a, #0x00, dec_reflow_time
	mov a, reflow_temp_var
	dec a
	cjne a, #214, min_temp_miss	;if it is NOT 81, jump and improve
	mov reflow_temp_var, #215	;if it IS 81, increase back to 82
	ljmp display_reflow_values

min_temp_miss:
	mov reflow_temp_var, a
	ljmp display_reflow_values

dec_reflow_time:
	mov a, reflow_time_var
	dec a
	cjne a, #34, max_time_miss ;if it is NOT 47, jump 
	mov reflow_time_var, #35 ;if it IS 47, move to 48
	ljmp display_reflow_values

min_time_miss:
	mov reflow_time_var, a
	ljmp display_reflow_values

display_reflow_values:
	Set_Cursor(2,6)
	_convert_to_bcd(reflow_time_var)
	Display_BCD(bcd+0)
	Set_Cursor(2,14)
	_convert_to_bcd(reflow_temp_var)
	lcall LCD_3BCD
	
confirm_reflow_values:
	jb Confirm_but, ?reflow_Screen_Wait
	Wait_Milli_Seconds(#50)
	jb Confirm_but, ?reflow_Screen_Wait
	jnb Confirm_but, $ 					;Waits for button to be lifted
	
	;Confirm button has been pressed
	lcall LCD_4bit
	mov reflow_temp_save, reflow_temp_var
	mov reflow_time_save, reflow_time_var
	ljmp Selection

?reflow_Screen_Wait:
	ljmp reflow_Screen_Wait

;-------------------------------------------------
;Preset Screen
;Various presets to use.
;-------------------------------------------------
Preset_Screen:
	Set_Cursor(1,1)
	Send_Constant_String(#Row1_Select_Screen_0)
	Set_Cursor(2,1)
	Send_Constant_String(#Row2_Preset1)
	
pollPresets:
	lcall pollInc
	lcall pollDec
	jbc inc_flag, incPreset
	jbc dec_flag, decPreset
	sjmp display_presets
	
incPreset:
	inc preset_select
	mov a, preset_select
	cjne a, #0x04, display_presets
	mov preset_select, #3
	sjmp display_presets

decPreset:
	dec preset_select
	mov a, preset_select
	cjne a, #0x00, display_presets
	mov preset_select, #1
	sjmp display_presets
	
display_presets:
	Set_Cursor(2,8)
	Display_BCD(preset_select)
	
confirm_preset_values:
	jb Confirm_but, pollPresets
	Wait_Milli_Seconds(#50)
	jb Confirm_but, pollPresets
	jnb Confirm_but, $ ;Waits for button to be lifted
	;Confirm button has been pressed
	lcall LCD_4bit
	Wait_Milli_Seconds(#50)
	ljmp Selection


;-------------------------------------------------
;STOP SEQUENCE
;Reset all temperatures, reset all timers, and return to starting sequence
;Maybe an alert to say when it's done?
;Key it to a reset button or something
;----------------------------------------------------
Stop_Sequence:
	;***Set power to 0
	mov soak_time_var, soak_time_save
	mov soak_temp_var, soak_temp_save
	mov reflow_temp_var, reflow_temp_save
	mov reflow_time_var, reflow_time_save
	clr PWM_flag
	lcall Check_PWM_flag
	mov PWM_DUTY, #0
	Set_Cursor(2,1)
	Send_Constant_String(#Powering_Down)
	;***Once temperature dips below a certain value, continue
Cooldown:
	_feel_the_burn
	mov y+0, #22
	mov y+1, #0
	mov y+2, #0
	mov y+3, #0
	lcall x_lteq_y
	jnb mf, Cooldown
	clr mf 
	ljmp OFF_Sequence

;---------------------------------------------
;OFF SEQUENCE
;Turns off screen
;--------------------------------------------
OFF_Sequence:
	
	mov a, #36
	lcall Play_sound_index
	mov a, #35
	lcall Play_sound_index
	mov a, #32
	lcall Play_sound_index
	Wait_Milli_Seconds(#200)
	mov a, #36
	lcall Play_sound_index
	mov a, #35
	lcall Play_sound_index
	mov a, #32
	lcall Play_sound_index
	Wait_Milli_Seconds(#100)
	mov a, #36
	lcall Play_sound_index
	mov a, #35
	lcall Play_sound_index
	mov a, #32
	lcall Play_sound_index
	ljmp Welcome

;_______________________;
;Running Loop Proccesses;
;_______________________;


;----------
;Reflow Process
;Begin soaking, and for how long. Then begin reflowing, and for how long.
;Is a loop that regularly checks for stop sequence
;----------
BURNBABYBURN:;DIIISCO INFERNO
	
	; enable interrupts for timer 1 and timer 0
	
	;Send strings that displays the base format: Temp, time, reflow proccess state
	Set_Cursor(1,1)
	Send_Constant_String(#Row1_presoak);Displays proccess pre-soak
	;Following code is to set the duty cycle and heat
	mov PWM_FREQ, #250
	mov PWM_DUTY, #255 ;Set duty cycle to MAX POWER
	setb PWM_flag
	lcall Check_PWM_flag
	setb TR1			; enables timer 1 for pwm
	mov a, #37
	lcall Play_sound_index
	mov a, #38
	lcall Play_sound_index
	mov a, #29
	lcall Play_sound_index
	
	
presoak:
	jb Start_But, ?presoak
	Wait_Milli_Seconds(#50)
	jb Start_But, ?presoak
	jnb Start_But, $
	;Ah shit STOP STOP STOP
	ljmp Stop_Sequence
	

?presoak:
	Set_Cursor(2,14)
	_feel_the_burn
	lcall LCD_3BCD
	mov y+0, soak_temp_save
	mov y+1, #0
	mov y+2, #0
	mov y+3, #0
	lcall x_gt_y ;if x is greater than y, then mf = 1
	jnb mf, presoak
	
	;Currently in soaking
	clr mf 
	Set_Cursor(1,1)
	Send_Constant_String(#Row1_select_screen_1);Displays proccess soak
	Set_Cursor(2,1)
	Send_Constant_String(#Row2_select_screen_1)
	Set_Cursor(2,6)
	_convert_to_bcd(soak_time_save)
	Display_BCD(bcd+0)
	mov PWM_DUTY, #0;Set duty cycle to 20% ish
	mov a, #37
	lcall Play_sound_index
	mov a, #38
	lcall Play_sound_index
	mov a, #30
	lcall Play_sound_index
	mov soak_time_var, soak_time_save

soak:
	jb Start_But, ?soak
	Wait_Milli_Seconds(#50)
	jb Start_But, ?soak
	jnb Start_But, $
	;Ah shit STOP STOP STOP
	ljmp Stop_Sequence

?soak:
	;check timer
	Set_Cursor(2,14)
	_feel_the_burn
	lcall LCD_3BCD
	mov a, seconds_flag
	jnb seconds_flag, soak
	
	clr seconds_flag
	Set_Cursor(2,6)
	_convert_to_bcd(soak_time_var)
	Display_BCD(bcd+0)
	dec soak_time_var
	mov a, soak_time_var
	cjne a, #0, soak ;if soak_time_var is not 0, then send it back to soak
	
	;Soak time has reached 0; move onto next step
	lcall LCD_4bit
	Wait_Milli_Seconds(#40)
	Set_Cursor(1,1)
	Send_Constant_String(#Row1_prereflow);Displays proccess pre-reflow
	mov PWM_DUTY, #255 ;Set the duty cycle to MAX POWER
	mov a, #37
	lcall Play_sound_index
	mov a, #38
	lcall Play_sound_index
	mov a, #31
	lcall Play_sound_index
	
prereflow:
	jb Start_But, ?prereflow
	Wait_Milli_Seconds(#50)
	jb Start_But, ?prereflow
	jnb Start_But, $
	;Ah shit STOP STOP STOP
	ljmp Stop_Sequence

?prereflow:
	Set_Cursor(2,14)
	_feel_the_burn
	lcall LCD_3BCD
	mov y+0, reflow_temp_save
	mov y+1, #0
	mov y+2, #0
	mov y+3, #0
	lcall x_gt_y ;if x is greater than y, then mf = 1
	jnb mf, prereflow
	
	;in reflow
	clr mf
	Set_Cursor(1,1)
	Send_Constant_string(#Row1_select_screen_2)
	Set_Cursor(2,1)
	Send_Constant_string(#Row2_select_screen_1)
	mov PWM_DUTY, #0 							;Set duty cycle to 20%
	mov a, #37
	lcall Play_sound_index
	mov a, #38
	lcall Play_sound_index
	mov a, #32
	lcall Play_sound_index
	mov reflow_time_var, reflow_time_save
	
reflow:
	Set_Cursor(2,14)
	_feel_the_burn
	lcall LCD_3BCD
	
	;Somehow maintain temp code
	ljmp FLAMINGHOTCHEETOS
?reflow:
	jnb seconds_flag, reflow
	
	clr seconds_flag
	Set_Cursor(2,6)
	_convert_to_bcd(reflow_time_var)
	Display_BCD(bcd+0)
	dec reflow_time_var
	mov a, reflow_time_var
	cjne a, #0x00, reflow ;if soak_time_var is not 0, then send it back to soak
	
	;Reflow time has reached 0; move onto next step	
	lcall LCD_4bit;Clear screen
	Set_Cursor(1,1)
	Send_Constant_String(#Row1_cooldown)
	ljmp Stop_Sequence
	
FLAMINGHOTCHEETOS:
	clr mf
	_feel_the_burn
	mov y+0, #255
	mov Y+1, #0
	mov y+2, #0
	mov y+3, #0
	lcall x_gt_y
	jnb mf, notflaming
	;IS FLAMIN
	clr mf
	ljmp Stop_Sequence

notflaming:
	jb Start_But, ?DONTSTOPMENOW
	Wait_Milli_Seconds(#50)
	jb Start_But, ?DONTSTOPMENOW
	jnb Start_But, $
	;Ah shit STOP STOP STOP
	ljmp Stop_Sequence
?DONTSTOPMENOW:
	ljmp ?reflow
	
end 











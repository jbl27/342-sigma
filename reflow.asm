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
T0_RATE   	equ 200     					; 200 HZ = 5 ms
T0_RELOAD 	equ ((65536-(CLK/2*T0_RATE)))

T1_RATE   	equ 2000     					; 200 HZ = 5 ms
T1_RELOAD 	equ ((65536-(CLK/2*T0_RATE)))

; baud rate constatns 
BAUD        equ 115200
BRVAL       equ ((CLK/BAUD)-16)						; internal RC oscilator frrquancy 

; port declrations 
CONF_BUT		equ P2.6
SEL_BUT			equ P3.0
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
PWM_PIN			equ p1.7

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
settings_select: 	ds 1
preset_select: 		ds 1
w:   				ds 3 		; 24-bit play counter.  Decremented in CCU ISR.
x_temp:				ds 4
y_temp:				ds 4
soak_temp_save:		ds 1
soak_time_save:		ds 1
reflow_temp_save:	ds 1
reflow_time_save:   ds 1
pwm_count:			ds 1
timer1_count:		ds 1
total_time:			ds 2


bseg 
mf:					dbit 1	
mf_temp:			dbit 1	
inc_flag: 			dbit 1		
dec_flag:			dbit 1
sel_flag:			dbit 1
confirm_flag:		dbit 1
seconds_flag:		dbit 1
time_temp_select:   dbit 1

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
	
	setb TR0
	setb ET0
	
	ret

; ------------------------------------------------------------
; configers timer 1 for mode 1 

Timer1_Init:
	clr TR1		; stop timer 1
	
	; configure timer0x
	mov a, TMOD
	anl a, #0x0f 	; Clear the bits for timer 1
	orl a, #0x10 	; configer timer 1, GATE0 = 0, C/T = 0, T0M0 = 0, T0M1 = 1 
	mov TMOD, a
	
	; Auxiliary mode config 
	mov a, TAMOD
	anl a, #0xf0
	mov TAMOD,a 
	
	; load timer
	mov TH1, #high(T1_RELOAD)
	mov TL1, #low(T1_RELOAD)
	
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
; declared constats and strings 

;                          '0123456789abcdef'    <- This helps determine the location of the counter
Row1_presets:		  	db 'Presets         ', 0
Row1_soak:  			db 'Soak            ', 0
Row1_reflow:  			db 'Reflow          ', 0
Row1_presoak:		   	db 'Pre-soak        ', 0
Row1_prereflow:		   	db 'Pre-reflow      ', 0
Row1_cooldown:		   	db 'Cooldown        ', 0
Row1_Abort:				db 'Aborting process', 0
Row2_time_temp:  	   	db ' Sec     Tmp    ', 0
Row2_Preset:		   	db 'Preset          ', 0

; -------------------------------------------------------
; the following code moves a given 1 byte variable to 
; x then converts that value to bcd 

_convert_to_bcd mac 
	mov x+0, %0
	mov x+1, #0
	mov x+2, #0
	mov x+3, #0
	lcall hex2bcd 
endmac 

; ----------------------------------------------------------
; macro specifc for converintg the total_time var into a bcd 

_see_the_future mac
	mov x+0, total_time+0
	mov x+1, total_time+1
	mov x+2, #0
	mov x+3, #0
	lcall hex2bcd
endmac

; _____________________________________________________________
;
; Main program 
; ______________________________________________________________

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
	
	mov preset_select, #0x01
	lcall loadPreset 
	setb EA   						; enable interrupts 


;_________________________________________________________
;
; User interface loop process 
;_________________________________________________________


;-------------------------------------------------------
; Settings selection screen, and welcome audio 
	
Welcome:

	clr TR1
	clr ET1
	clr PWM_pin
	mov settings_select, #0x01
	_clearScreen
	
	; play welcome audio 
	mov a, #33	
	lcall Play_sound_index
	mov a, #34
	lcall Play_sound_index
	mov a, #35
	lcall Play_sound_index
	mov a, #36
	lcall Play_sound_index
	Wait_Milli_seconds(#40)
	
settings:
	
	; check if start up enganged 
	lcall checkConBut
	jnb confirm_flag, noStartUp
	clr confirm_flag
	ljmp BURNBABYBURN
	
noStartUp:
	Set_Cursor(1,1)
	lcall checkIncBut
	lcall checkDecBut
	jbc inc_flag, incSettingsSel
	jbc dec_flag, decSettingsSel
	sjmp display_presets
	
incSettingsSel:
	inc settings_select
	mov a, settings_select
	cjne a, #4, display_presets
	mov settings_select, #1
	sjmp display_presets

decSettingsSel:
	dec settings_select
	mov a, settings_select
	cjne a, #0, display_presets
	mov settings_select, #3
	
display_presets:
	mov a, settings_select
	cjne a, #1, display_soak 					; show soak select
	Send_Constant_String(#Row1_presets)
	sjmp Selection_Confirm

display_soak:
	cjne a, #2, display_reflow 					; show reflow select
	Send_Constant_String(#Row1_soak)
	sjmp Selection_Confirm
	
display_reflow:
	Send_Constant_String(#Row1_reflow)

Selection_Confirm:
	lcall checkSelBut
	jnb sel_flag, ?settings
	clr sel_flag
	
	; check which setting the user wants to alter
	mov a, settings_select
	cjne a, #1, Soak_settings_Check 
	ljmp Preset_Screen

Soak_settings_Check:
	cjne a, #2, Reflow_settings_Check
	ljmp Soak_Screen
	
Reflow_settings_Check:
	ljmp Reflow_Screen

?settings:
	ljmp settings

;--------------------------------------------------
;Soak settings screen 

Soak_Screen: 
	WriteCommand(#0x0d)
	Set_Cursor(1,1)
	Send_Constant_String(#Row1_soak)
	Set_Cursor(2,1)
	Send_Constant_String(#Row2_time_temp)
	mov soak_temp_var, soak_temp_save
	mov soak_time_var, soak_time_save 
	clr time_temp_select
	ljmp display_soak_values

Soak_Screen_Wait:
	lcall checkSelBut
	lcall checkIncBut
	lcall checkDecBut
	jbc sel_flag, switch_soak_sel
	jbc inc_flag, inc_soak_temp
	jbc dec_flag, dec_soak_temp
	ljmp highlight_soak_temp
	
switch_soak_sel:
	cpl time_temp_select
	ljmp highlight_soak_temp
	
?highlight_soak_temp:
	ljmp highlight_soak_temp

inc_soak_temp:
	jnb time_temp_select, inc_soak_time
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
	cjne a, #0x4f, max_time_hit
	mov soak_time_var, #0x4e
	ljmp display_soak_values

max_time_hit:
	mov soak_time_var, a
	ljmp display_soak_values

dec_soak_temp:
	jnb time_temp_select, dec_soak_time
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
	
highlight_soak_temp:
	jnb time_temp_select, highlight_soak_time
	Set_Cursor(2,9)
	sjmp confirm_soak_values
	
highlight_soak_time:
	Set_Cursor(2,1)
	
confirm_soak_values:
	lcall checkConBut
	jnb confirm_flag, ?Soak_Screen_Wait
	
	;Confirm button has been pressed
	clr confirm_flag
	mov soak_temp_save, soak_temp_var
	mov soak_time_save, soak_time_var
	_clearScreen
	WriteCommand(#0x0c)		;remove blinking cursor 
	lcall savePreset
	ljmp settings

?Soak_Screen_Wait:
	ljmp Soak_Screen_Wait

; --------------------------------------------------
; Reflow setting screen 

Reflow_Screen:	
	WriteCommand(#0x0d)
	Set_Cursor(1,1)
	Send_Constant_String(#Row1_reflow)
	Set_Cursor(2,1)
	Send_Constant_String(#Row2_time_temp)
	mov reflow_temp_var, reflow_temp_save
	mov reflow_time_var, reflow_time_save
	clr time_temp_select
	ljmp display_reflow_values

reflow_Screen_Wait:
	lcall checkSelBut
	lcall checkIncBut
	lcall checkDecBut
	jbc sel_flag, switch_reflow_sel
	jbc inc_flag, inc_reflow_temp
	jbc dec_flag, dec_reflow_temp
	ljmp highlight_reflow_temp
	
switch_reflow_sel:
	cpl time_temp_select
	ljmp highlight_reflow_temp
	
?highlight_reflow_temp:
	ljmp highlight_reflow_temp

inc_reflow_temp:
	jnb time_temp_select, inc_reflow_time
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
	jnb time_temp_select, dec_reflow_time
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
	cjne a, #34, min_time_miss ;if it is NOT 47, jump 
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

highlight_reflow_temp:
	jnb time_temp_select, highlight_reflow_time
	Set_Cursor(2,9)
	sjmp confirm_reflow_values
	
highlight_reflow_time:
	Set_Cursor(2,1)

confirm_reflow_values:
	lcall checkConBut
	jnb confirm_flag, ?reflow_Screen_Wait
	
	;Confirm button has been pressed
	clr confirm_flag
	mov reflow_temp_save, reflow_temp_var
	mov reflow_time_save, reflow_time_var
	WriteCommand(#0x0c)						; remove blinking cursor 
	_clearScreen
	lcall savePreset
	ljmp settings

?reflow_Screen_Wait:
	ljmp reflow_Screen_Wait

;-------------------------------------------------
;Preset Settings screen 

Preset_Screen:
	Set_Cursor(1,1)
	Send_Constant_String(#Row1_presets)
	Set_Cursor(2,1)
	Send_Constant_String(#Row2_Preset)
	
presets_screen_wait:
	lcall checkIncBut
	lcall checkDecBut
	jbc inc_flag, incPreset
	jbc dec_flag, decPreset
	sjmp display_preset_value
	
incPreset:
	inc preset_select
	mov a, preset_select
	cjne a, #0x04, display_preset_value
	mov preset_select, #3
	sjmp display_preset_value

decPreset:
	dec preset_select
	mov a, preset_select
	cjne a, #0x00, display_preset_value
	mov preset_select, #1
	
display_preset_value:
	Set_Cursor(2,8)
	Display_BCD(preset_select)
	
	; confimr preset value 
	lcall checkConBut
	jnb confirm_flag, presets_screen_wait
	
	; preset has been chosne 
	clr confirm_flag
	lcall loadPreset
	_clearScreen
	ljmp settings


;_________________________________________________________
;
; Reflow Loop Proccesses
;_________________________________________________________


;------------------------------------------------------------
; initializtion of reflow process 

BURNBABYBURN:
	
	_clearScreen
	
	; enable timer 0 and timer 1 as well as their respective interrupts
	setb TR1
	setb ET1
	
	; Audio announces entering pre-soak 
	mov a, #37
	lcall Play_sound_index
	mov a, #38
	lcall Play_sound_index
	mov a, #29
	lcall Play_sound_index
	
	; initialize lcd and variabels for presoak
	Set_Cursor(1,1)
	Send_Constant_String(#Row1_presoak)
	Set_Cursor(2,1)
	Send_Constant_String(#Row2_time_temp)
	
	mov total_time+0, #0			; start timer 
	mov total_time+1, #0
	mov pwm_count, #0x05			; duty cyle 100%

; ---------------------------------------------------------
; pre-soak sequance 

presoak:
	lcall checkConBut
	jnb confirm_flag, presoak_wait
	clr confirm_flag
	ljmp Stop_Sequence

presoak_wait:
	ljmp SLOWCOOKER			; check if pre-soak taking too long 

keep_roasting:	
	; display tempreture and time
	Set_Cursor(2,6)
	_see_the_future
	lcall LCD_3BCD
	Set_Cursor(2,14)
	_feel_the_burn
	lcall LCD_3BCD
	
	; compare tempreture 
	mov y+0, soak_temp_save
	mov y+1, #0
	mov y+2, #0
	mov y+3, #0
	lcall x_gt_y 
	jnb mf, presoak
	clr mf 
	
	; Audio annouces entering soak 
	mov a, #37
	lcall Play_sound_index
	mov a, #38
	lcall Play_sound_index
	mov a, #30
	lcall Play_sound_index
	mov soak_time_var, soak_time_save
	
	; initialize varables and lcd for soak
	Set_Cursor(1,1)
	Send_Constant_String(#Row1_soak)
	Set_Cursor(2,1)
	Send_Constant_String(#Row2_time_temp)	; clear 3 digit BCDs 
	
	mov pwm_count, #0x02	 				; duty cycle at 20%
	mov soak_time_var, soak_time_save

; ---------------------------------------------------------
; soak sequance 

soak:
	lcall checkConBut
	jnb confirm_flag, soak_wait
	clr confirm_flag
	ljmp Stop_Sequence

soak_wait:

	; display tempreture and time
	Set_Cursor(2,6)
	_convert_to_bcd(soak_time_var)
	Display_BCD(bcd+0)
	Set_Cursor(2,14)
	_feel_the_burn
	lcall LCD_3BCD
	
	; chekc if a second has passed 
	jnb seconds_flag, soak
	clr seconds_flag
	
	; 1 second has passed 
	dec soak_time_var
	mov a, soak_time_var
	jnz soak 					;if soak_time_var is not 0, then send it back to soak
	
	; Audio announces entering pre-reflow
	mov a, #37
	lcall Play_sound_index
	mov a, #38
	lcall Play_sound_index
	mov a, #31
	lcall Play_sound_index

	; initialize lcd and varables for pre-reflow
	Set_Cursor(1,1)
	Send_Constant_String(#Row1_prereflow)
	
	mov pwm_count, #0x05					; duty cycle at 100%

; ---------------------------------------------------------
; pre-reflow sequnce 

prereflow:
	lcall checkConBut
	jnb confirm_flag, prereflow_wait
	clr confirm_flag
	ljmp Stop_Sequence

prereflow_wait:

	; display tempreture and time
	Set_Cursor(2,6)
	_see_the_future
	lcall LCD_3BCD
	Set_Cursor(2,14)
	_feel_the_burn
	lcall LCD_3BCD
	
	; compare tempreture 
	mov y+0, reflow_temp_save
	mov y+1, #0
	mov y+2, #0
	mov y+3, #0
	lcall x_gt_y 
	jnb mf, prereflow
	clr mf 
	
	; Audio annouces entering reflow 
	mov a, #37
	lcall Play_sound_index
	mov a, #38
	lcall Play_sound_index
	mov a, #32
	lcall Play_sound_index
	
	; initialize variables and lcd for reflow 
	Set_Cursor(1,1)
	Send_Constant_string(#Row1_reflow)
	Set_Cursor(2,1)
	Send_Constant_string(#Row2_time_temp)
	
	mov pwm_count, #0x02					; duty cycle at 20%
	mov reflow_time_var, reflow_time_save
	
; -------------------------------------------------------------
; reflow sequnce 
	
reflow:
	lcall checkConBut
	jnb confirm_flag, reflow_wait
	clr confirm_flag
	ljmp Stop_Sequence
	
reflow_wait:
	ljmp FLAMINGHOTCHEETOs			; chekc if tmep too high 
	
not_flaming:
	; display tempreture and time
	Set_Cursor(2,6)
	_convert_to_bcd(reflow_time_var)
	Display_BCD(bcd+0)
	Set_Cursor(2,14)
	_feel_the_burn
	lcall LCD_3BCD
	
	; chekc if 1 second has passed 
	jnb seconds_flag, reflow
	clr seconds_flag
	
	; 1 second has passed 
	dec reflow_time_var
	mov a, reflow_time_var
	jnz reflow 
	
	; initialize lcd and variables for cooling 	
	Set_Cursor(1,1)
	Send_Constant_String(#Row1_cooldown)
	
	mov pwm_count, #0						; duty cycle is 0%
	clr PWM_PIN								; clear pwm pin
	clr ET1									; disable timer 1 inturrpts

;-------------------------------------------------
; cool down sequnce 

Cooldown:

	; display tempreture and time 
	Set_Cursor(2,6)
	_see_the_future
	lcall LCD_3BCD
	Set_Cursor(2,14)
	_feel_the_burn
	lcall LCD_3BCD
	
	; compare tempreture 
	mov y+0, #50
	mov y+1, #0
	mov y+2, #0
	mov y+3, #0
	lcall x_lteq_y
	jnb mf, Cooldown
	clr mf 
	ljmp welcome
	
	
; -------------------------------------------------------
; check if temp too high 

FLAMINGHOTCHEETOs:
	_feel_the_burn
	mov y+0, #255
	mov Y+1, #0
	mov y+2, #0
	mov y+3, #0
	lcall x_gt_y
	jnb mf, BAKEDCRUNCHYCHEETOS
	clr mf
	
	; tempretue too high stop reflow 
	ljmp Stop_Sequence
	
BAKEDCRUNCHYCHEETOS:
	ljmp not_flaming

; ------------------------------------------------------
; check if pre-soak is taking too long 

SLOWCOOKER:
	_see_the_future
	mov y+0, #50
	mov y+1, #0
	mov y+2, #0
	mov y+3, #0
	lcall x_gt_y
	jnb mf, SPITROAST
	clr mf 
	
	; pre-soak took too long 
	ljmp Stop_Sequence
	
SPITROAST:
	ljmp keep_roasting

; ------------------------------------------------------
; emergancy stop sequance 

Stop_Sequence:
	
	_clearScreen
	Set_Cursor(1,1)
	Send_Constant_String(#Row1_Abort)
	Wait_Milli_seconds(#255)
	Wait_Milli_seconds(#255)
	Wait_Milli_seconds(#255)
	Wait_Milli_seconds(#255)
	
	mov pwm_count, #0						; duty cycle is 0%
	clr PWM_PIN								; clear pwm pin
	clr ET1									; disable timer 1 inturrpts
	
	; clear screen initialize lcd for cooldown 
	_clearScreen
	Set_Cursor(1,1)
	Send_Constant_string(#Row1_cooldown)
	Set_Cursor(2,1)
	Send_Constant_string(#Row2_time_temp)
	
	ljmp Cooldown

end 






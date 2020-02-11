Skip to content
Search or jump to�

Pull requests
Issues
Marketplace
Explore
 
@SairentoSilv 
jbl27
/
342-sigma
1
01
 Code Issues 0 Pull requests 0 Actions Projects 0 Wiki Security Insights
342-sigma/reflow.asm
@razwell razwell main program .asm file
45a8c59 2 days ago
747 lines (607 sloc)  16.8 KB
  
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
T0_RELOAD 	equ ((65536-(CLK/T0_RATE)))

; baud rate constatns 
BAUD        equ 115200
BRVAL       equ ((CLK/BAUD)-16)						; internal RC oscilator frrquancy 

; port declrations 
Confirm_But		equ P3.0
Swap_But_1		equ P3.1
Start_But		equ P2.7
LCD_RS 			equ P1.1
LCD_RW 			equ P1.2
LCD_E  			equ P1.3
LCD_D4 			equ P3.2
LCD_D5 			equ P3.3
LCD_D6 			equ P3.4
LCD_D7 			equ P3.5

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
	reti

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
result:				ds 2
cold_temp:			ds 1		; temprtrue of cold joint
hot_temp:			ds 1		; tempreture of hot joint 
total_temp:			ds 4		; total temprtue 
count_5ms:			ds 1		; counter for timer one 
soak_time_var: 		ds 1
soak_temp_var: 		ds 1
reflow_time_var: 	ds 1
reflow_temp_var: 	ds 1
max_temp: 			ds 1
max_time: 			ds 1
row_select_1: 		ds 1
time_temp_select: 	ds 1
preset_select: 		ds 1

bseg 
nf:					dbit 1		
inc_flag: 			dbit 1		
dec_flag:			dbit 1
cancel_flag:		dbit 1
select_flag:		dbit 1
seconds_flag:		dbit 1

; ------------------------------------------------------------
; external file includes 

cseg 

$NOLIST
$include(ISR_table.inc)
$LIST
$NOLIST
$include(LCD_4bit.inc)
$LIST
$NOLIST
$include(math32.inc)
$LIST
$NOLIST
$include(ADC_temp_read.inc)
$LIST
$NOLIST
$include(SPI_RS232.inc)
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
	
	; load timer
	mov TH0, #high(T0_RELOAD)
	mov TL0, #low(T0_RELOAD)
	
	
    setb ET0  		; Enable timer 0 interrupt
    setb TR0  		; Start timer 0
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

;                          1234567890123456    <- This helps determine the location of the counter
Row1_Select_screen_1:  db 'Soak', 0
Row1_Select_screen_2:  db 'Reflow', 0
Row1_presoak:		   db 'Pre-soak',0
Row1_prereflow:		   db 'Pre-reflow',0
Row1_cooldown:		   db 'Cooldown', 0
Row1_Select_screen_0:  db 'Presets', 0
Row1_Select_screen_3:  db 'Accents', 0
Row2_Select_screen_1:  db 'Timexxx Tempxxx', 0
Row2_Preset1:		   db 'Preset 1', 0
Welcome_to_The_Show:   db 'Welcome',0
Powering_Down:		   db 'Powering Down',0

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
	
	;Setup Selection screen
    mov row_select_1, #0x00
	
	; Enable Global interrupts
	setb EA   

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
	;Check if start button is pressed
	ljmp Startup
	
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
	mov row_select_1, #0
	
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
	Send_Constant_String(#Row1_Select_screen_1)
	Set_Cursor(2,1)
	Send_Constant_String(#Row2_Select_screen_1)
	mov time_temp_select, #0x00

Soak_Screen_Wait:
	mov a, sel_flag
	cjne a, #0x01, time_temp_flags
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
	ljmp display_soak_values

max_temp_hit:
	mov soak_temp_var, #0xAA
	ljmp display_soak_values

inc_soak_time:
	mov a, soak_time_var
	inc a
	da a
	cjne a, #0x79, max_time_hit
	mov soak_time_var, a
	ljmp display_soak_values

max_time_hit:
	mov soak_time_var, #0x78
	ljmp display_soak_values

dec_soak_temp:
	clr dec_flag
	mov a, time_temp_select
	cjne a, #0x00, dec_soak_time
	mov a, soak_temp_var
	dec a
	da a
	cjne a, #0x81, max_temp_hit
	mov soak_temp_var, a
	ljmp display_soak_values

min_temp_hit:
	mov soak_temp_var, #0x82
	ljmp display_soak_values

dec_soak_time:
	mov a, soak_time_var
	dec a
	da a
	cjne a, #0x47, max_time_hit
	mov soak_time_var, a
	ljmp display_soak_values

min_time_hit:
	mov soak_time_var, #0x48
	ljmp display_soak_values

display_soak_values:
	Set_Cursor(2,5)
	Display_BCD(soak_time_var)
	Set_Cursor(2,13)
	Display_BCD(soak_temp_var)

confirm_soak_values:
	jb Confirm_but, Soak_Screen_Wait
	Wait_Milli_Seconds(#50)
	jb Confirm_but, Soak_Screen_Wait
	jnb Confirm_but, $ ;Waits for button to be lifted
	;Confirm button has been pressed
	ljmp Selection

;---------
;Reflow Screen
;Selects the time and temperature you want
;Save the value they want for temperature (in CELSIUS) as a variable that we can reuse later
;Increment with one button, decrement with another, confirm with another and cancel with another. 4 Buttons.
;Variables: reflow_temp_var
;---------
Reflow_Screen:
Set_Cursor(1,1)
	Send_Constant_String(#Row1_Select_screen_2)
	Set_Cursor(2,1)
	Send_Constant_String(#Row2_Select_screen_1)
	mov time_temp_select, #0x00

Reflow_Screen_Wait:
	mov a, sel_flag
	cjne a, #0x01, reflow_screen_flags
	;If sel_flag is is pressed, swap temp and time
	cpl time_temp_select
	clr sel_flag
	

reflow_screen_flags:
	mov a, inc_flag
	cjne a, #0x01, inc_reflow_temp
	mov a, dec_flag
	cjne a, #0x01, dec_reflow_temp

inc_reflow_temp:
	clr inc_flag
	mov a, time_temp_select
	cjne a, #0x00, inc_reflow_time
	mov a, reflow_temp_var
	inc a
	da a
	cjne a, #236, max_reflow_temp
	mov reflow_temp_var, a
	ljmp display_reflow_values

max_reflow_temp:
	mov reflow_temp_var, #235
	ljmp display_reflow_values

inc_reflow_time:
	mov a, reflow_time_var
	inc a
	da a
	cjne a, #220, max_reflow_time
	mov reflow_time_var, a
	ljmp display_reflow_values

max_reflow_time:
	mov reflow_time_var, #0x78
	ljmp display_reflow_values

dec_reflow_temp:
	clr dec_flag
	mov a, reflow_temp_select
	cjne a, #0x00, dec_reflow_time
	mov a, reflow_temp_var
	dec a
	da a
	cjne a, #0x81, max_reflow_hit
	mov reflow_temp_var, a
	ljmp display_reflow_values

min_reflow_temp:
	mov reflow_temp_var, #0x82
	ljmp display_reflow_values

dec_reflow_time:
	mov a, reflow_time_var
	dec a
	da a
	cjne a, #0x47, max_reflow_hit
	mov reflow_time_var, a
	ljmp display_reflow_values

min_reflow_time:
	mov reflow_time_var, #0x48
	ljmp display_reflow_values

display_reflow_values:
	Set_Cursor(2,5)
	Display_BCD(reflow_time_var)
	Set_Cursor(2,13)
	Display_BCD(reflow_temp_var)

confirm_reflow_values:
	jb Confirm_but, Reflow_screen_wait
	Wait_Milli_Seconds(#50)
	jb Confirm_but, Reflow_screen_wait
	jnb Confirm_but, $ ;Waits for button to be lifted
	;Confirm button has been pressed
	ljmp Selection

;---------
;Preset Screen
;Various presets to use.
;---------
Preset_Screen:
	Set_Cursor(1,1)
	Send_Constant_String(#Row1_Select_Screen_0)
	Set_Cursor(2,1)
	Send_Constant_String(#Row2_Preset1)
	mov preset_select, #0x00

preset_value:
	mov a, preset_select
	cjne a, #0x01, confirm_preset_values
	;preset 1 has values: Soak time 45, Soak temp 150, Reflow temp 220, Reflow time 30
	mov soak_time_var, #45
	mov soak_temp_var, #150
	mov reflow_temp_var, #225
	mov reflow_time_var, #30
	
confirm_preset_values:
	jb Confirm_but, preset_value
	Wait_Milli_Seconds(#50)
	jb Confirm_but, preset_value
	jnb Confirm_but, $ ;Waits for button to be lifted
	;Confirm button has been pressed
	ljmp Selection
;---------
;Accent Screen
;Selects the accent? Check their code
;Variables: soak_temp_var
;---------
Accent_Screen:



;----------
;Start Loop
;Starts Reflow Process
;----------

Startup:
	jb Start_But, no_start
	Wait_Milli_Seconds(#50)
	jb Start_But, no_start
	jnb Start_But, $ ;Waits for button to be lifted
	;valid press; begin selection
	ljmp BURNBABYBURN ;Jump to reflow process; REFLOW PROCESS NEEDS STOP-SEQUENCE CODE

no_start:
	ljmp Selection
;----------
;STOP SEQUENCE
;Reset all temperatures, reset all timers, and return to starting sequence
;Maybe an alert to say when it's done?
;Key it to a reset button or something
;----------
Stop_Sequence:
	;***Set power to 0
	mov soak_time_var, #45
	mov soak_temp_var, #150
	mov reflow_temp_var, #225
	mov reflow_time_var, #30
	clr PWM_flag
	Set_Cursor(2,1)
	Send_Constant_String(#Powering_Down)
	;***Once temperature dips below a certain value, continue
Cooldown:
	mov x, ;***currenttemp
	mov y, #50
	lcall x_lteq_y
	mov a, mf
	cjne a, #1, Cooldown
	ljmp OFF_Sequence

;----------
;OFF SEQUENCE
;Turns off screen
;----------
OFF_Sequence:
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
;Send strings that displays the base format: Temp, time, reflow proccess state
	Set_Cursor(1,1)
	Send_Constant_String(#Row1_presoak);Displays proccess pre-soak
	;Following code is to set the duty cycle and heat
	mov PWM_FREQ, #250
	mov duty_cycle, #255 ;Set duty cycle to MAX POWER
	setb PWM_flag

presoak:
	jb Start_But, ?presoak
	Wait_Milli_Seconds(#50)
	jb Start_But, ?presoak
	jnb Start_But
	;Ah shit STOP STOP STOP
	ljmp Stop_Sequence

?presoak:
	Set_Cursor(2,1)
	Display_BCD();***current temp
	mov x, ;***current temp
	mov y, soak_temp_var
	lcall x_gt_y ;if x is greater than y, then mf = 1
	mov a, mf
	cjne a, #0x01, presoak
	;Currently in soaking
	Set_Cursor(1,1)
	Send_Constant_String(#Row1_select_screen_1);Displays proccess soak
	Set_Cursor(2,1)
	Send_Constant_String(#Row2_select_screen_1)
	Set_Cursor(2,5)
	Display_BCD(soak_time_var)
	mov duty_cycle, #51;Set duty cycle to 20% ish
	
soak:
	jb Start_But, ?soak
	Wait_Milli_Seconds(#50)
	jb Start_But, ?soak
	jnb Start_But
	;Ah shit STOP STOP STOP
	ljmp Stop_Sequence

?soak:
	;check timer
	Set_Cursor(2,13)
	Display_BCD(;***current_temp)
	mov a, seconds_flag
	cjne a, #0x01, soak
	clr seconds_flag
	Set_Cursor(2,5)
	Display_BCD(soak_time_var)
	mov a, soak_time_var
	dec a
	da a
	mov soak_time_var, a
	cjne a, #0x00, soak ;if soak_time_var is not 0, then send it back to soak
	;Soak time has reached 0; move onto next step
	lcall LCD_4bit
	Set_Cursor(1,1)
	Send_Constant_String(#Row1_prereflow);Displays proccess pre-reflow
	lcall Temperature_heating(reflow_temp_var)
	mov duty_cycle, #255 ;Set the duty cycle to MAX POWER
	
prereflow:
	jb Start_But, ?prereflow
	Wait_Milli_Seconds(#50)
	jb Start_But, ?prereflow
	jnb Start_But
	;Ah shit STOP STOP STOP
	ljmp Stop_Sequence

?prereflow:
	Set_Cursor(2,13)
	Display_BCD();***current temp
	mov x, ;***current temp
	mov y, reflow_temp_var
	x_gt_y ;if x is greater than y, then mf = 1
	mov a, mf
	cjne a, #0x01, prereflow
	;in reflow
	Set_Cursor(1,1)
	Send_Constant_string(#Row1_select_screen_2)
	Set_Cursor(2,1)
	Send_Constant_string(#Row2_select_screen_1)
	mov duty_cycle, #51 ;Set duty cycle to 20%
	
reflow:
	Set_Cursor(2,13)
	Send_BCD();***current_temp
	;Somehow maintain temp code
	ljmp FLAMINGHOTCHEETOS
?reflow:
	mov a, seconds_flag
	cjne a, #0x01, reflow
	clr seconds_flag
	Set_Cursor(2,5)
	Display_BCD(reflow_time_var)
	mov a, reflow_time_var
	dec a
	da a
	mov reflow_time_var, a
	cjne a, #0x00, reflow ;if soak_time_var is not 0, then send it back to soak
	;Reflow time has reached 0; move onto next step	
	lcall LCD_4bit;Clear screen
	Set_Cursor(1,1)
	Send_Constant_String(#Row1_cooldown)
	ljmp Stop_Sequence
	
FLAMINGHOTCHEETOS:
	mov x, ;***current_temp
	mov y, #0xEB
	x_gt_y
	mov a, mf
	cjne a, #0x01, notflaming
	;IS FLAMIN
	ljmp Stop_Sequence

notflaming:
	jb Start_But, ?DONTSTOPMENOW
	Wait_Milli_Seconds(#50)
	jb Start_But, ?DONTSTOPMENOW
	jnb Start_But
	;Ah shit STOP STOP STOP
	ljmp Stop_Sequence
?DONTSTOPMENOW:
	ljmp ?reflow
	
	;just in case
	ljmp loop
	
end 
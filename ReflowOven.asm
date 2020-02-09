; Copy general ISR code and setup from Timer ISR

$NOLIST
$MODLP51
$LIST

Confirm_But		equ P3.0
Swap_But_1		equ P3.1
Start_But		equ P2.7

; Reset vector
org 0x0000
    ljmp main

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
preset_select: ds 1

; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
seconds_flag: dbit 1 ; Set to one in the ISR every time 1000 ms had passed
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
Row1_presoak:		   db 'Pre-soak',0
Row1_prereflow:		   db 'Pre-reflow',0
Row1_cooldown:		   db 'Cooldown', 0
Row1_Select_screen_0:  db 'Presets', 0
Row1_Select_screen_3:  db 'Accents', 0
Row2_Select_screen_1:  db 'Timexxx Tempxxx', 0
Row2_Preset1:		   db 'Preset 1', 0
Welcome_to_The_Show:   db 'Welcome',0
Powering_Down:		   db 'Powering Down',0

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
	Send_Constant_String(#Powering_Down)
	;***Once temperature dips below a certain value, continue
	
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
	lcall Temperature_Heating(soak_temp_var);consider making 'Temperature_Heating' a macro script so that it can be reused

presoak:
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

soak:
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

prereflow:
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
	ljmp ?reflow


	ljmp loop
END

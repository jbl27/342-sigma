;
;	Main file that runs reflow code.
;	File contains vector jump tables and such 

cseg 

$NOLIST
$MOD9351
$LIST

; ------------------------------------------------------------
; Constant derectives 

CLK 	equ 7373000							; internal RC oscilator frrquancy 

; timer constants  
T0_RATW equ 1000							; 1000 Hz = 1 ms
T0_REL	equ equ ((65536-(CLK/T0_RATE)))		; Value to put in reload register of timer 0

; baud rate gen constants 
BAUD 	equ 9600
BRG_VAL equ (0x100-(CLK/(16*BAUD)))

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
	timer0ISR

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
	reti

; ------------------------------------------------------------
; variables  

dseg at 0x30

x:				ds 4
y:				ds 4
bcd:			ds 5
cold_temp:		ds 4		; temprtrue of cold joint
hot_temp:		ds 4		; tempreture of hot joint 
count_ms0:		ds 2		; counter for timer one 
row_select_1: 	ds 1		; used  for user input of menue 

bseg 
nf:					dbit 1		
rdy_send:			dbit 1		; idiectes when data is rdy to be sent to pyton 
inc_flag: 			dbit 1		
dec_flag:			dbit 1
cancel_flag:		dbit 1
select_flag:		dbit 1

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
$include(ADC.inc)
$LIST

; ------------------------------------------------------------
; initialization of internal and external peripherals 

conFigTimer0:
	clr TR0			; stop timer 0
	
	; configure timer0x
	mov a, TMOD
	anl a, #0xf0 	; Clear the bits for timer 0
	orl a, #0x01 	; configer timer 0, GATE0 = 0, C/T = 0, T0M0 = 0, T0M1 = 1 
	
	; load timer
	mov TMOD, a
	mov TH0, #high(T0_RELOAD)
	mov TL0, #low(T0_RELOAD)
	
	; Set autoreload value
	mov RH0, #high(T0_RELOAD)
	mov RL0, #low(T0_RELOAD)
	
    setb ET0  		; Enable timer 0 interrupt
    setb TR0  		; Start timer 0
	ret
	
; ------------------------------------------------------------
; main 

main:

end 






























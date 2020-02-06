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
	reti 

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
nf:				dbit 1		
rdy_send:		dbit 1		; idiectes when data is rdy to be sent to pyton 

; ------------------------------------------------------------
; external file includes 

cseg 

$NOLIST
$include(ISRtable.inc)
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


end 






























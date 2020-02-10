;
;	Main file that runs reflow code.
;	File contains vector jump tables and such 

cseg 

$NOLIST
$MOD9351
$LIST

; ------------------------------------------------------------
; Constant derectives 

CLK         equ 14746000  							; Microcontroller system clock frequency in Hz

; CCU timer constants
CCU_RATE    equ 22050    						 	; 22050Hz is the sampling rate of the wav file we are playing
CCU_RELOAD  equ ((65536-((CLK/(2*CCU_RATE)))))

; timer0 constants 
T0_RATE   	equ 1000     					; 1000HZ = 1 ms
T0_RELOAD 	equ ((65536-(CLK/T0_RATE)))

; baud rate constatns 
BAUD        equ 115200
BRVAL       equ ((CLK/BAUD)-16)						; internal RC oscilator frrquancy 


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

x:				ds 4
y:				ds 4
bcd:			ds 5
cold_temp:		ds 1		; temprtrue of cold joint
hot_temp:		ds 1		; tempreture of hot joint 
total_temp:		ds 4		; total temprtue 
count_ms0:		ds 2		; counter for timer one 
row_select_1: 	ds 1		; used  for user input of menue 

bseg 
nf:					dbit 1		
rdy_send:			dbit 1		; idiectes when data is rdy to be sent to pyton 
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
; initialization of internal and external peripherals 

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
; double the internal rc clk rate of the P89LPC 

Double_Clk:
    mov dptr, #CLKCON
    movx a, @dptr
    orl a, #00001000B 			; double the clock speed to 14.746MHz
    movx @dptr,a
	ret

; ------------------------------------------------------------
; main 

main:

end 






























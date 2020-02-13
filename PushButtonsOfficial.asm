;-------------------------------------------------------
; PushButton FSMs
;-------------------------------------------------------
KEY1 equ ;PIN
KEY2 equ ;PIN
KEY3 equ ;PIN
KEY4 equ ;PIN

bseg
Key1_flag dbit 1
Key2_flag dbit 1
Key3_flag dbit 1
Key4_flag dbit 1


dseg
FSM1_INC: ds 1
FSM1_timer: ds 1
FSM1_state: ds 1
FSM2_INC: ds 1
FSM2_timer: ds 1
FSM2_state: ds 1
FSM3_timer: ds 1
FSM3_state: ds 1
FSM4_INC: ds 1
FSM4_timer: ds 1
FSM4_state: ds 1


cseg
; ***INCREASE/DECREASE***
;-------------------------------------------------------------------------------
; non-blocking state machine for KEY1/2 starts here
FSM1:
	mov a, FSM1_state
FSM1_state0:
	cjne a, #0, FSM1_state1
	jb KEY1, FSM1_done
	mov FSM1_timer, #0
	mov FSM1_INC, #0
	inc FSM1_state
	sjmp FSM1_done
FSM1_state1:
	cjne a, #1, FSM1_state2
	; this is the debounce state
	mov a, FSM1_timer
	cjne a, #10, FSM1_done ; 50 ms passed?
	inc FSM1_state
	sjmp FSM1_done	
FSM1_state2:
	cjne a, #2, FSM1_state3
	jb KEY1, FSM1_state2b
	inc FSM1_state
	sjmp FSM1_done	
FSM1_state2b:
	mov FSM1_state, #0
	sjmp FSM1_done
FSM1_state3:
	cjne a, #3, FSM1_state4
	jnb KEY1, FSM1_state3b
	setb Key1_flag ; Suscesfully detected a valid KEY1 press/release
	mov FSM1_state, #0
	sjmp FSM1_done
FSM1_state3b:
	mov a, FSM1_timer
	cjne a, #200, FSM1_done ; 1 second has passed
	mov FSM1_timer, #0
	inc FSM1_INC
	inc FSM1_state
	setb Key1_flag
	sjmp FSM1_done
FSM1_state4:
	cjne a, #4, FSM1_state5
	jnb KEY1, FSM1_state4b
	mov FSM1_state, #0
	sjmp FSM1_done
FSM1_state4b:
	mov a, FSM1_INC
	cjne a, #3, FSM1_state4c
	inc FSM1_state
	mov FSM1_timer, #0
	sjmp FSM1_done
FSM1_state4c:
	dec FSM1_state
	sjmp FSM1_done
FSM1_state5:
	cjne a, #5, FSM1_done
	jnb KEY1, FSM1_state5b
	mov FSM1_state, #0
	sjmp FSM1_done
FSM1_state5b:
	mov a, FSM1_timer
	cjne a, #40, FSM1_done ; 1 second has passed
	mov FSM1_timer, #0
	setb Key1_flag
	sjmp FSM1_done
FSM1_done:
	ret
;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------
; non-blocking state machine for KEY1/2 starts here
FSM2:
	mov a, FSM2_state
FSM2_state0:
	cjne a, #0, FSM2_state1
	jb KEY2, FSM2_done
	mov FSM2_timer, #0
	mov FSM2_INC, #0
	inc FSM2_state
	sjmp FSM2_done
FSM2_state1:
	cjne a, #1, FSM2_state2
	; this is the debounce state
	mov a, FSM2_timer
	cjne a, #10, FSM2_done ; 50 ms passed?
	inc FSM2_state
	sjmp FSM2_done	
FSM2_state2:
	cjne a, #2, FSM2_state3
	jb KEY2, FSM2_state2b
	inc FSM2_state
	sjmp FSM2_done	
FSM2_state2b:
	mov FSM2_state, #0
	sjmp FSM2_done
FSM2_state3:
	cjne a, #3, FSM2_state4
	jnb KEY2, FSM2_state3b
	setb Key2_flag ; Suscesfully detected a valid KEY1 press/release
	mov FSM2_state, #0
	sjmp FSM2_done
FSM2_state3b:
	mov a, FSM2_timer
	cjne a, #200, FSM2_done ; 1 second has passed
	mov FSM2_timer, #0
	inc FSM2_INC
	inc FSM2_state
	setb Key2_flag
	sjmp FSM2_done
FSM2_state4:
	cjne a, #4, FSM2_state5
	jnb KEY2, FSM2_state4b
	mov FSM2_state, #0
	sjmp FSM2_done
FSM2_state4b:
	mov a, FSM2_INC
	cjne a, #3, FSM2_state4c
	inc FSM2_state
	mov FSM2_timer, #0
	sjmp FSM2_done
FSM2_state4c:
	dec FSM2_state
	sjmp FSM2_done
FSM2_state5:
	cjne a, #5, FSM2_done
	jnb KEY2, FSM2_state5b
	mov FSM2_state, #0
	sjmp FSM2_done
FSM2_state5b:
	mov a, FSM2_timer
	cjne a, #40, FSM2_done ; 1 second has passed
	mov FSM2_timer, #0
	setb Key2_flag
	sjmp FSM2_done
FSM2_done:
	ret
;-------------------------------------------------------------------------------


; ***SELECT/CANCEL***
;-------------------------------------------------------------------------------
; non-blocking state machine for KEY3 starts here
FSM3:
	mov a, FSM3_state
FSM3_state0:
	cjne a, #0, FSM3_state1
	jb KEY3, FSM3_done
	mov FSM3_timer, #0
	inc FSM3_state
	sjmp FSM3_done
FSM3_state1:
	cjne a, #1, FSM3_state2
	; this is the debounce state
	mov a, FSM3_timer
	cjne a, #50, FSM3_done ; 50 ms passed?
	inc FSM3_state
	sjmp FSM3_done	
FSM3_state2:
	cjne a, #2, FSM3_state3
	jb KEY3, FSM3_state2b
	inc FSM3_state
	sjmp FSM3_done	
FSM3_state2b:
	mov FSM3_state, #0
	sjmp FSM3_done
FSM3_state3:
	cjne a, #3, FSM3_done
	jnb KEY3, FSM3_done
	setb Key3_flag ; Suscesfully detected a valid KEY3 press/release
	mov FSM3_state, #0	
FSM3_done:
;-------------------------------------------------------------------------------


; ***START&STOP***
;-------------------------------------------------------------------------------
; non-blocking state machine for KEY4 starts here
FSM4:
	mov a, FSM4_state
FSM4_state0:
	cjne a, #0, FSM4_state1
	jb KEY4, FSM4_done
	mov FSM4_timer, #0
	mov Key4_INC, #0
	inc FSM4_state
	sjmp FSM4_done
FSM4_state1:
	cjne a, #1, FSM4_state2
	; this is the debounce state
	mov a, FSM4_timer
	cjne a, #50, FSM4_done ; 50 ms passed?
	inc FSM4_state
	sjmp FSM4_done	
FSM4_state2:
	cjne a, #2, FSM4_state3
	jb KEY4, FSM4_state2b
	inc FSM4_state
	sjmp FSM4_done	
FSM4_state2b:
	mov FSM4_state, #0
	sjmp FSM4_done
FSM4_state3:
	cjne a, #3, FSM4_state4
	jnb KEY4, FSM4_state3b
	mov FSM4_state, #0
	sjmp FSM4_done
FSM4_state3b:
	mov a, FSM4_timer
	cjne a, #200, FSM4_done
	inc FSM4_INC
	inc FSM4_state
	mov FSM4_timer, #0
	sjmp FSM4_done
FSM4_state4:
	cjne a, #4, FSM4_done
	jnb KEY4, FSM4_state4b
	mov FSM4_state, #0
	sjmp FSM4_done
FSM4_state4b:
	mov a, Key4_INC
	cjne a, #3, FSM4_state4c
	setb Key4_flag
	mov FSM4_state, #0
	mov Key4_INC, #0
	sjmp FSM4_done
FSM4_state4c:
	dec FSM4_state
	sjmp FSM4_done
FSM4_done:
;-------------------------------------------------------------------------------


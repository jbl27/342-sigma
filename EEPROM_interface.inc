cseg

; -------------------------------------------------------
; Code for using EPROM 

; -------------------------------------------
; save the curent preset to EPROM 

savePreset:
	clr a
	clr c
	mov a, preset_select
	mov b, #4
	mul ab
	subb a, #4
	
	mov dpl, a
	mov dph, #0
	mov a, soak_time_save
	lcall EEPROM_write
	inc dptr
	mov a, soak_temp_save
	lcall EEPROM_write
	inc dptr
	mov a, reflow_time_save
	lcall EEPROM_write
	inc dptr
	mov a, reflow_temp_save
	lcall EEPROM_write
	ret

; --------------------------------------------------------------------
; load current preset 

loadPreset:
	clr a
	clr c
	mov a, preset_select
	mov b, #4
	mul ab
	subb a, #4
	
	mov dpl, a
	mov dph, #0
	lcall EEPROM_Read
	mov soak_time_save, a
	inc dptr
	lcall EEPROM_Read
	mov soak_temp_save, a
	inc dptr
	lcall EEPROM_Read
	mov reflow_time_save, a
	inc dptr
	lcall EEPROM_Read
	mov reflow_temp_save, a
	ret


; -------------------------------------------------------------------------
; write to EEPROME 

EEPROM_write:
	clr EA 				; 'Strongly recommended' in the datasheet page 133
	mov DEECON, DPH 	; ECTL1/ECTL0 (DEECON[5:4]) = ‘00’, EADR8
	mov DEEDAT, a 		; Byte to write
	mov DEEADR, DPL 	; Address to write to. This initializes the write process
	
	; Wait for write operation to complete
	EEPROM_Write_L1:
	mov a, DEECON
	jnb acc.7, EEPROM_Write_L1 ; bit 7 of DEECON is EEIF
	setb EA
	ret

; -----------------------------------------------
; read from EPROM 

EEPROM_Read:
	clr EA ; 'Strongly Recommended' in the datasheet page 133
	mov DEECON, DPH ; ECTL1/ECTL0 (DEECON[5:4]) = ‘00’, EADR8=0
	mov DEEADR, DPL ; Address to read from. This initializes the read process

; wait for read operation to complete
EEPROM_Read_L1:
	mov a, DEECON
	jnb acc.7, EEPROM_Read_L1 ; bit 7 of DEECON is EEIF
	mov a, DEEDAT
	setb EA
	ret












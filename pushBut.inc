
cseg


checkSelBut:
	jb SEL_BUT, sel_but_np
	Wait_Milli_Seconds(#50)
	jb SEL_BUT, sel_but_np
	jnb SEL_BUT, $ 			;Waits for button to be lifted
	setb sel_flag
sel_but_np:
	ret

checkIncBut:
	jb INC_BUT, inc_but_np
	Wait_Milli_Seconds(#50)
	jb INC_BUT, inc_but_np
	jnb INC_BUT, $ 			;Waits for button to be lifted
	setb inc_flag
inc_but_np:
	ret

checkDecBut:
	jb DEC_BUT, dec_but_np
	Wait_Milli_Seconds(#50)
	jb DEC_BUT, dec_but_np
	jnb DEC_BUT, $ 			;Waits for button to be lifted
	setb dec_flag
dec_but_np:
	ret

checkConBut:
	jb CONF_BUT, confirm_but_np
	Wait_Milli_Seconds(#50)
	jb CONF_BUT, confirm_but_np
	jnb CONF_BUT, $ 			;Waits for button to be lifted
	setb confirm_flag
confirm_but_np:
	ret









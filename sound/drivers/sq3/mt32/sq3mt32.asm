; vim:set ts=8:

include ../../common/midi.inc
include ../../common/mpu.inc
include ../../common/snd0.inc

seg_a		segment	byte public
		assume	cs:seg_a, ds:seg_a

		org	0

; MT32 has 8 channels + rhythm

MT32_NUM_CHANNELS               equ 10

start:
		jmp	entry

		db      00h
                dd      87654321h      ; identifier
                db      01h            ; driver type 1 = sound

		db	 5, 'mtdrv'
		db	46, 'Roland MT-32, MT-100, LAPC-1, CM-32L, or CM-64'

; Roland Exclusive Messages: these all start with (p37)
; 0F0h, 41h, [device id], [model id], Command, body, 0F7h
MT32_MANID      equ     41h         ; manufactures-id
MT32_DEVID      equ     10h
MT32_MODEL      equ     16h         ; used for 'exclusive communication' (p41)
MT32_CMD_DT1    equ     12h         ; dataset #1

; macro to generate a MT-32 command - yields 'id', 'id_header_len' (5), 'id_len' and 'id_checksum'
generate_mt32_cmd   macro id,a,b,c,d,e,f,g,h,i,j,k
id:	            db	MIDI_SYSEX_BEGIN, MT32_MANID, MT32_DEVID, MT32_MODEL, MT32_CMD_DT1
id&_header_len      equ $-offset id
                    cksum = 0
                    irp x,<a,b,c,d,e,f,g,h,i,j,k>
                        ifnb <x>
                            db  x
                            cksum = cksum + x
                        endif
                    endm ; irp
id&_len             equ $-offset id
id&_cksum           equ cksum
                    endm

; used to generate a MT-32 write command - generates _lo/_hi labels as well
generate_mt32_wr    macro id,l_prefix,addr1,addr2,addr3
id:	            db	MIDI_SYSEX_BEGIN, MT32_MANID, MT32_DEVID, MT32_MODEL, MT32_CMD_DT1
id&_hdr_len         equ $-offset id
                    db  addr1
l_prefix&_hi        db  addr2
l_prefix&_lo        db  addr3
id&_len             equ $-offset id
                    endm

; 8 values - seems to write to "MASTER VOLUME" (p43)
generate_mt32_cmd   mpu_data_1, 10h, 00h, 16h

; used by load_sound and terminate - seems to write to "MIDI CHANNEL (Part 1)" ? (p43)
generate_mt32_cmd   mt32_cmd_wr_midi_ch1, 10h, 00h, 0Dh

; command to write to "Timbre Memory", address in [timbre_mem_addr_hi] / [timbre_mem_addr_lo]
generate_mt32_wr    mt32_cmd_wr_timbre_mem, timbre_mem_addr, 08h, 00h, 00h

; command to write to "Patch Memory", address in [patch_mem_addr_lo] / [patch_mem_addr_hi]
generate_mt32_wr    mt32_cmd_wr_patch_memory, patch_mem_addr, 05h, 00h, 00h

; command to write to "Patch Temp Area", address in [patch_tmp_addr_hi] / [patch_tmp_addr_lo]
generate_mt32_wr    mt32_cmd_wr_patch_temp, patch_tmp_addr, 03h, 01h, 10h

; command to write "Partial Reserve (Part 1)"
generate_mt32_cmd    mt32_cmd_wr_sys_area, 10h, 00h, 04h

; where is the data below used?
                db      MIDI_SYSEX_BEGIN, MT32_MANID, MT32_DEVID, MT32_MODEL, MT32_CMD_DT1
		db	03h,  01h, 43h, 00h, 39h, MIDI_SYSEX_END

generate_mt32_cmd    mt32_cmd_display, 20h, 00h,  00h

; 16 bytes
generate_mt32_cmd   mpu_data_8, 52h, 00h, 0Ah, 16h, 16h, 16h, 16h, 16h, 16h, 20h, MIDI_SYSEX_END

;; ---- start of header read from patch.001 ------------------------------------
mt32_text_ready     db      20 dup (0)  ; when initialization completed
mt32_text_init      db      20 dup (0)  ; when initializating
mt32_text_goodbye   db      20 dup (0)  ; after shutting down
volume_max          dw	    0           ; maximum value of volume, as programmed into MT-32
data_19		db	0

; writes a portion somewhere in system area?
mpu_data_9	db	MIDI_SYSEX_BEGIN, MT32_MANID, MT32_DEVID, MT32_MODEL, MT32_CMD_DT1
mpu_data_9_hdr_len equ $-offset mpu_data_9
                db      10h, 00h, 01h
data_21		db	0               ; only written (?)
data_22		db	0               ; only written (?)
data_23		db	0               ; only written (?)
mpu_data_9_len equ $-offset mpu_data_9

data_24		db	11 dup (0)
data_25		db	11 dup (0)
data_26		db	11 dup (0)
;; ---- end of header read from patch.001 --------------------------------------

mpu_init_error  db	'   MPU INIT ERROR   '
mt32_chksum	db	0               ; used for checksum calculation
midi_last_byte		db	0
midi_decode_state	db	0   ; 0, 1, 2
midi_last_command	db	0
midi_next_byte	db	0
		db	0
midi_last_channel	db	0
mt32_last_cmd		db	0
debug_repeated_cmd_chan		db	0       ; debug? if 0, midi_last_command/midi_last_channel read from buffer. if 1, repeated
reset_pause_active	db	0
data_36		db	0                       ; something related to MIDI_CONTROL_UNKNOWN_50
signalval_base	dw	0                       ; value to be added to the SND_SIGNAL value
current_volume	dw	0
data_39		dw	0
data_40		dw	0
data_41		dw	0
loop_position	dw	0
midi_delay_left	dw	0                       ; set using program change to channel 15
orig_si		dw	0
prev_position	dw	0
volume_scale	dw	0                       ; contains result of 'volume_max / 15'
mpu_timed_out	dw	0                       ; 0FFFFh if the device has timed out
mpu_active_channels	dw	0

func_tab	dw	func_0                  ; func 0: get device info
                dw      initialize              ; func 2: init
                dw      terminate               ; func 4: terminate
                dw      load_sound              ; func 6: load sound
                dw      timer                   ; func 8: timer
		dw	set_volume              ; func 10: set volume
                dw      fade_out                ; func 12: fade out
                dw      stop_sound              ; func 14: stop sound
                dw      stop_sound              ; func 16: pause sound
		dw      seek_sound              ; func 18: seek sound

entry:
		pushf				; Push flags
		push	bp
		push	si
		push	di
		push	bx
		push	dx
		push	ds
		push	es
		mov	cs:orig_si,si
		mov	bx,cs:func_tab[bp]
		call	bx			;*
		pop	es
		pop	ds
		pop	dx
		pop	bx
		pop	di
		pop	si
		pop	bp
		popf				; Pop flags
		retf

mt32_update_and_send_checksum   macro
                                neg	cs:mt32_chksum
                                and	cs:mt32_chksum,7Fh
                                mov	bl,cs:mt32_chksum
                                call	mpu_write_data
                                endm


terminate       proc near
		push	bx
		call	stop_sound
		mov	bx,MPU_CMD_SYS_MSG
		call	mpu_write_cmd
		xor	di,di
		mov	cs:mt32_chksum,mt32_cmd_wr_midi_ch1_cksum
loc_2:
		mov	bl,cs:mt32_cmd_wr_midi_ch1[di]
		call	mpu_write_data
		inc	di
		cmp	di,mt32_cmd_wr_midi_ch1_len
		jl	loc_2

		mov	bx,1
loc_3:
		add	cs:mt32_chksum,bl
		call	mpu_write_data
		inc	bl
		cmp	bl,MT32_NUM_CHANNELS
		jl	loc_3

                mt32_update_and_send_checksum

		mov	bl,MIDI_SYSEX_END
		call	mpu_write_data
		mov	cx,0Fh
		call	mt32_set_volume

		mov	bx,offset mt32_text_goodbye
		call	mt32_show_text
		pop	bx
		ret
terminate       endp

load_sound	proc	near
		mov	bx,cs:orig_si
		mov	di,[bx+SND_RESPTR]
		mov	si,[di]
		mov	es,[di+2]               ; es:si = sound datas

		mov	word ptr [bx+SND_STATE],SND_STATE_VALID
		cmp	byte ptr es:[si],0
		je	loc_4
		cmp	byte ptr es:[si],2
		je	loc_4

                ; first byte must be 0 or 2
		mov	word ptr [bx+SND_STATE],SND_STATE_INVALID
		mov	ax,SND_STATE_INVALID
		ret
loc_4:
		push	cx
		mov	word ptr [bx+SND_POS],22h
		mov	word ptr [bx+SND_SIGNAL],0
                ; skip flag, initialization for channel 0
		add	si,3
		call	parse_sound_channels
		jnc	channels_set

                ; need to set the channels (si has been rewound)
		xor	di,di
		mov	cs:mt32_chksum,mt32_cmd_wr_midi_ch1_cksum
		mov	bx,MPU_CMD_SYS_MSG
		call	mpu_write_cmd
loc_5:
		mov	bl,cs:mt32_cmd_wr_midi_ch1[di]
		call	mpu_write_data
		inc	di
		cmp	di,mt32_cmd_wr_midi_ch1_len
		jl	loc_5

                ; write 8 values, one per channel
		mov	di,1                    ; channel 0
loc_6:
		inc	si
		mov	bl,es:[si]
		inc	si
		test	bl,SND_CHANBIT_MT32
		jnz	loc_7			; Jump if not zero

		mov	bl,10h                  ; OFF
		jmp	short loc_8
loc_7:
                ; map channel?
		mov	bx,di
loc_8:
		add	cs:mt32_chksum,bl
		call	mpu_write_data
		inc	di
		cmp	di,9
		jl	loc_6

                ; map this channel explicitly to 9 (rhythm) if enabled
		mov	bl,es:[si]
		test	bl,80h
		jnz	loc_9
		mov	bl,10h                  ; OFF
		jmp	short loc_10
loc_9:
		mov	bl,9
loc_10:
		add	cs:mt32_chksum,bl
		call	mpu_write_data

                mt32_update_and_send_checksum
		mov	bl,MIDI_SYSEX_END
		call	mpu_write_data

channels_set:
                ;; TODO figure out if this skips the remaining channels??
		add	si,0Fh
		mov	al,es:[si]
		and	al,0F0h                 ; al = command

		cmp	al,MIDI_CONTROL
		jne	loc_12			; Jump if not equal
		cmp	byte ptr es:[si+1],MIDI_CONTROL_UNKNOWN_50
		je	loc_13
loc_12:
		mov	bl,cs:data_36
		cmp	bl,cs:data_19
		je	loc_13
		mov	bl,cs:data_19
		call	sub_13
loc_13:
		mov	bx,cs:orig_si
		mov	cx,[bx+SND_VOLUME]
		cmp	cx,cs:current_volume
		je	loc_14

                ; volume changed - update and apply
		mov	cs:current_volume,cx
		call	mt32_set_volume
loc_14:
		mov	cs:midi_delay_left,0
		mov	cs:midi_decode_state,2
		mov	cs:mt32_last_cmd,0
		mov	cs:data_40,0
		mov	cs:data_39,8
		mov	cs:data_41,0
		mov	cs:reset_pause_active,0
		mov	cs:loop_position,22h
		mov	cs:signalval_base,7Fh
		mov	ax,SND_STATE_VALID
		pop	cx
		ret
load_sound	endp

; seems to set cf=1 if the channels need to be set (and si points back to the channels)
parse_sound_channels		proc	near
		mov	ax,1
		xor	bx,bx
		mov	cx,8

                ; construct [bx] = mask of all channels to play
locloop_15:
                ; skip channel polyphony
		inc	si
                ; check whether we need to play this chanel on MT-32
		test	byte ptr es:[si],SND_CHANBIT_MT32
		jz	loc_16
		or	bx,ax
loc_16:
		inc	si
		shl	ax,1
		loop	locloop_15

                ; channel 9
		test	byte ptr es:[si],80h
		jz	loc_17			; Jump if zero
		or	bx,ax
loc_17:
		cmp	bx,cs:mpu_active_channels
		je	loc_18

                ; reposition back to channel header
		sub	si,10h
		mov	cs:mpu_active_channels,bx
		stc
		jmp	short loc_ret_19

loc_18:         ; channels did not change, nothing to do
		clc

loc_ret_19:
		ret
parse_sound_channels		endp

; writes command [bl] to the mpu
; (this follows "A. Sending a command to the MPU-401" on page 57 reasonably well)
mpu_write_cmd	proc	near
		push	cx
		push	dx
		mov	cx,0FFFFh
		mov	dx,MPU_PORT_STATUS
loc_20:
		cmp	bp,FN_SEEK_SOUND
		je	loc_22
		cmp	cx,0
		jne	loc_21
		mov	cs:mpu_timed_out,0FFFFh
		jmp	short loc_28
		nop
loc_21:
		dec	cx
loc_22:
		in	al,dx
		test	al,MPU_STATUS_DRR
		jnz	loc_20

		cli
		mov	al,bl
		out	dx,al
		mov	cx,0FFFFh
loc_23:
		cmp	bp,FN_SEEK_SOUND
		je	loc_25
		cmp	cx,0
		jne	loc_24			; Jump if not equal
		mov	cs:mpu_timed_out,0FFFFh
		sti				; Enable interrupts
		jmp	short loc_28
		nop
loc_24:
		dec	cx
loc_25:
		in	al,dx
		rol	al,1                    ; check highest bit
		jnc	loc_26                  ; if not set, go to loc_26
		jmp	short loc_23
loc_26:
		mov	dx,MPU_PORT_DATA
		in	al,dx
		cmp	al,0FEh                 ; kkk
		je	loc_27
		mov	ax,0FFFFh
loc_27:
		sti
loc_28:
		pop	dx
		pop	cx
		ret
mpu_write_cmd	endp

; sends byte [bl] to the MPU's data port
; (this follows "B. Sending data to the MPU-401" on page 59)
mpu_write_data	proc	near
		push	ax
		push	dx
		mov	dx,MPU_PORT_STATUS
loc_29:
		in	al,dx
		test	al,MPU_STATUS_DRR
		jnz	loc_29

		mov	dx,MPU_PORT_DATA
		mov	al,bl
		out	dx,al
		pop	dx
		pop	ax
		ret
mpu_write_data	endp

; sends MIDI data to the MT-32 - [cx] is number of bytes to send
mt32_send_midi	proc	near
		push	bx
		or	al,ah                   ; ax = midi chan/cmd
		push	ax
		mov	bl,MPU_CMD_WTS
		call	mpu_write_cmd
		pop	ax
		cmp	cs:mt32_last_cmd,al
		je	loc_30

                ; command changed - need to send it. this should always have
                ; bit 7 set, so the MT-32 knows it's a command and not data
		mov	bl,al
		call	mpu_write_data
		mov	cs:mt32_last_cmd,al

loc_30:         ; first byte
		mov	bl,cs:midi_next_byte
		call	mpu_write_data
		inc	si
		cmp	cx,2
		jne	loc_31

                ; second byte
		push	dx
		mov	dl,es:[si]
		mov	cs:midi_last_byte,dl
		inc	si
		pop	dx
		mov	bl,cs:midi_last_byte
		call	mpu_write_data
loc_31:
		pop	bx
		ret
mt32_send_midi	endp

;
timer		proc	near
		cli				; Disable interrupts
		mov	bx,cs:orig_si
		mov	di,[bx+SND_RESPTR]
		mov	es,[di+2]
		mov	si,[di]                 ; es:si = sound data
		cmp	cs:midi_delay_left,0
		je	loc_34
		cmp	bp,FN_SEEK_SOUND
		jne	loc_32			; Jump if not equal
		mov	cs:midi_delay_left,0
		jmp	short timer_leave1
loc_32:         ; not in FN_SEEK_SOUND, need to handle delays properly
		dec	cs:midi_delay_left
		cmp	cs:data_40,0
		je	timer_leave1
		call	sub_14
timer_leave1:
		sti				; Enable interrupts
		ret

loc_34:         ; no more delay, need to start processing
		push	cx
		add	si,[bx+SND_POS]
		mov	cs:prev_position,si
loc_35:
		cmp	cs:midi_decode_state,1
		jne	timer_goto_state2			; Jump if not equal

                ; state = 1 -> retrieve next byte from stream
		push	dx
		mov	dl,es:[si]
		mov	cs:midi_last_byte,dl
		inc	si
		pop	dx

		cmp	cs:midi_last_byte,MIDI_END_OF_SONG
		jne	loc_36			; Jump if not equal

		call	loop_song
		jmp	loc_57
loc_36:
		cmp	cs:midi_last_byte,MIDI_DELAY_240
		jne	loc_38			; Jump if not equal

		mov	cs:midi_delay_left,0F0h
		mov	cs:midi_decode_state,1
		cmp	bp,FN_SEEK_SOUND
		jne	loc_37			; Jump if not equal
		jmp	short loc_35
		jmp	short loc_38            ; [unreachable]
loc_37:
		jmp	loc_56
loc_38:
                ; need to accumulate delay value
		push	bx
		mov	cs:midi_decode_state,2
		mov	ax,cs:midi_delay_left
		mov	bl,cs:midi_last_byte
		xor	bh,bh
		add	ax,bx
		mov	cs:midi_delay_left,ax
		pop	bx
		cmp	cs:midi_delay_left,0
		je	timer_goto_state2
		cmp	bp,FN_SEEK_SOUND
		jne	loc_39
		mov	cs:midi_delay_left,0

		jmp	short loc_40
loc_39:
		dec	cs:midi_delay_left
		cmp	cs:data_40,0
		je	loc_40
		call	sub_14
loc_40:
		jmp	loc_56
timer_goto_state2:
		mov	cs:midi_decode_state,2
		push	dx
		mov	dl,es:[si]
		mov	cs:midi_last_byte,dl
		inc	si
		pop	dx
		test	cs:midi_last_byte,80h
		jnz	loc_42                      ; jmp if (midi_last_byte & 0x80) != 0

                ; retrieve last command/channel
		push	bx
		mov	cs:debug_repeated_cmd_chan,1
		mov	ah,cs:midi_last_command
		mov	al,cs:midi_last_channel
		mov	bl,cs:midi_last_byte
		mov	cs:midi_next_byte,bl
		pop	bx
		dec	si
		jmp	short loc_43
loc_42:
		push	bx
		mov	cs:debug_repeated_cmd_chan,0
		mov	ah,cs:midi_last_byte
		and	ah,0F0h
		mov	cs:midi_last_command,ah
		mov	al,cs:midi_last_byte
		and	al,0Fh
		mov	cs:midi_last_channel,al
		mov	bl,es:[si]
		mov	cs:midi_next_byte,bl
		pop	bx
loc_43:
		cmp	ah,MIDI_PCHANGE
		jne	loc_45
		cmp	al,0Fh
		jne	loc_44
		call	pchange_ch15
		jmp	loc_55
		jmp	short loc_45
loc_44:
		jmp	mt32_send_1
loc_45:
		cmp	ah,MIDI_CONTROL
		jne	loc_48
		cmp	cs:midi_next_byte,MIDI_CONTROL_UNKNOWN_50
		jne	loc_46
		call	control_unk_50
		jmp	short loc_55
		nop
loc_46:
		cmp	cs:midi_next_byte,MIDI_CONTROL_RESET_ON_PAUSE
		jne	loc_47
		call	control_reset_pause
		jmp	short loc_55
		nop
loc_47:
		cmp	cs:midi_next_byte,MIDI_CONTROL_CUMULATIVE_CUE
		jne	loc_48
		call	update_signal
		jmp	short loc_55
		nop
loc_48:
		cmp	ah,MIDI_AFTERTOUCH
		jne	loc_49
		jmp	short mt32_send_1
		nop
loc_49:
		cmp	ah,MIDI_SYSEX_BEGIN
		jne	loc_51
		cmp	al,0Ch
		jne	loc_50

                ; MIDI_END_OF_SONG encountered
		call	loop_song
		jmp	short loc_57
		nop
		jmp	short loc_51
loc_50:
		push	dx
		mov	dl,es:[si]
		mov	cs:midi_last_byte,dl
		inc	si
		pop	dx
		cmp	cs:midi_last_byte,MIDI_SYSEX_END
		jne	loc_50
		jmp	loc_35
loc_51:
		cmp	bp,FN_SEEK_SOUND
		jne	mt32_send_2
		cmp	ah,MIDI_NOTE_ON
		jne	loc_52
		inc	si
		inc	si
		jmp	short loc_55
		nop
loc_52:
		cmp	ah,MIDI_NOTE_OFF
		jne	mt32_send_2
		inc	si
		inc	si
		jmp	short loc_55
		nop
mt32_send_2:
		mov	cx,2
		call	mt32_send_midi
		jmp	short loc_55
		nop
mt32_send_1:
		mov	cx,1
		call	mt32_send_midi
loc_55:
		mov	cs:midi_decode_state,1
		jmp	loc_35
loc_56:
		sub	si,cs:prev_position
		mov	bx,cs:orig_si
		add	[bx+SND_POS],si
loc_57:
		pop	cx
		sti
		ret
timer		endp


pchange_ch15	proc	near
		push	ax
		push	bx
		inc	si
		xor	ah,ah
		mov	al,cs:midi_next_byte
		mov	bx,cs:orig_si
		cmp	al,MIDI_PCHANGE_SET_LOOP_POINT
		jne	loc_58			; Jump if not equal
		push	si
		sub	si,cs:prev_position
		add	si,[bx+SND_POS]
		dec	si
		dec	si
		mov	cs:loop_position,si
		pop	si
		jmp	short loc_59
loc_58:
		mov	[bx+SND_SIGNAL],ax
loc_59:
		pop	bx
		pop	ax
		ret
pchange_ch15    endp

update_signal   proc	near
		push	ax
		push	bx
		inc	si
		xor	ah,ah
		mov	al,es:[si]
		mov	bx,cs:orig_si
		add	cs:signalval_base,ax
		mov	ax,cs:signalval_base
		mov	[bx+SND_SIGNAL],ax
		inc	si
		pop	bx
		pop	ax
		ret
update_signal   endp

control_reset_pause proc near
                    inc	si
                    cmp	byte ptr es:[si],0
                    jne	loc_60			; Jump if not equal
                    mov	cs:reset_pause_active,0
                    jmp	short loc_61
loc_60:
                    mov	cs:reset_pause_active,1
loc_61:
                    inc si
                    ret
control_reset_pause endp

; called once end-of-song encountered - resets song position
loop_song	proc	near
		mov	bx,cs:orig_si
		mov	word ptr [bx+SND_SIGNAL],0FFFFh
		mov	dx,cs:loop_position
		mov	[bx+SND_POS],dx
		mov	cs:midi_delay_left,0
		mov	cs:midi_decode_state,2
		ret
loop_song	endp

; input: cx = volume value (0..15)
mt32_set_volume	proc	near
		push	di
		push	bx
		push	cx
		cmp	cx,0Fh
		jl	loc_62

		mov	cx,cs:volume_max               ; if cx >= 10h, use volume_max
		jmp	short loc_63
loc_62:
		cmp	cx,0
		jle	loc_63

		push	ax
		push	dx
		xor	dx,dx
		mov	ax,cx
		mul	cs:volume_scale
		mov	cx,ax                       ; cx = volume_scale * cx
		pop	dx
		pop	ax
loc_63:
		mov	bx,MPU_CMD_SYS_MSG
		call	mpu_write_cmd
		xor	di,di
		mov	cs:mt32_chksum,mpu_data_1_cksum

loc_64:
		mov	bl,cs:mpu_data_1[di]
		call	mpu_write_data
		inc	di
		cmp	di,mpu_data_1_len
		jl	loc_64

		mov	bx,cx                       ; cx = volume value...
		add	cs:mt32_chksum,bl
		call	mpu_write_data

                ; instead of and-ing mt32_chksum, it loads it to bl and does the and...
		neg	cs:mt32_chksum
		mov	bl,cs:mt32_chksum
		and	bl,7Fh
		call	mpu_write_data

		mov	bl,MIDI_SYSEX_END
		call	mpu_write_data
		pop	cx
		pop	bx
		pop	di
		ret
mt32_set_volume	endp

control_unk_50  proc	near
		inc	si
		mov	bl,es:[si]
		inc	si
		cmp	bl,cs:data_36
		je	loc_ret_65
		call	sub_13

loc_ret_65:
		ret
control_unk_50  endp

sub_13		proc	near
		xor	bh,bh
		mov	cs:data_36,bl
		mov	cl,cs:data_24[bx]
		mov	cs:data_21,cl
		mov	cl,cs:data_25[bx]
		mov	cs:data_22,cl
		mov	cl,cs:data_26[bx]
		mov	cs:data_23,cl
		mov	bx,MPU_CMD_SYS_MSG
		call	mpu_write_cmd
		xor	di,di
loc_66:
		mov	bl,cs:mpu_data_9[di]
		call	mpu_write_data
		inc	di
		cmp	di,mpu_data_9_hdr_len
		jl	loc_66
		mov	cs:mt32_chksum,0
loc_67:
		mov	bl,cs:mpu_data_9[di]
		add	cs:mt32_chksum,bl
		call	mpu_write_data
		inc	di
		cmp	di,mpu_data_9_len
		jl	loc_67

                mt32_update_and_send_checksum
		mov	bl,MIDI_SYSEX_END
		call	mpu_write_data
		mov	cs:mt32_last_cmd,0
		ret
sub_13		endp

set_volume      proc near
		cmp	cs:data_40,0
		jne	loc_ret_68		; Jump if not equal
		push	bx
		push	cx
		mov	bx,cs:orig_si
		mov	cx,[bx+SND_VOLUME]
		mov	cs:current_volume,cx
		call	mt32_set_volume
		mov	cs:mt32_last_cmd,0
		pop	cx
		pop	bx

loc_ret_68:
		ret
set_volume      endp

; I wonder if this has something to do with volume fade?
sub_14		proc	near
		push	bx
		push	cx
		dec	cs:data_39
		cmp	cs:data_39,0
		jne	loc_70			; Jump if not equal
		dec	cs:data_40
		cmp	cs:data_40,0
		jne	loc_69			; Jump if not equal
		mov	bx,cs:orig_si
		mov	word ptr [bx+SND_UNK],0
		call	stop_sound
		call	loop_song
		jmp	short loc_70
loc_69:
		mov	cx,cs:data_40
		mov	cs:current_volume,cx
		call	mt32_set_volume
		mov	cs:data_39,8
		mov	cx,cs:data_41
		add	cs:data_39,cx
		add	cs:data_41,2
loc_70:
		pop	cx
		pop	bx
		ret
sub_14		endp

fade_out        proc near
		push	bx
		push	cx
		mov	bx,cs:orig_si
		mov	cx,[bx+SND_VOLUME]
		mov	cs:data_40,cx
		cmp	cx,0
		jne	loc_71			; Jump if not equal
		mov	word ptr [bx+SND_UNK],0
		call	stop_sound
		call	loop_song
loc_71:
		pop	cx
		pop	bx
		ret
fade_out        endp

stop_sound	proc	near
		push	cx
		mov	cs:mt32_last_cmd,0
		mov	di,1
		xor	bh,bh

stop_sound_channel:
		mov	bl,MPU_CMD_WTS
		call	mpu_write_cmd
		cmp	cs:mpu_timed_out,0FFFFh
		jne	loc_73			; Jump if not equal
		pop	cx
		ret

loc_73:
		mov	bl,MIDI_CONTROL
		add	bx,di
		call	mpu_write_data
		mov	bl,MIDI_CONTROL_ALL_NOTES_OFF
		call	mpu_write_data
		xor	bl,bl
		call	mpu_write_data

		mov	bl,MPU_CMD_WTS
		call	mpu_write_cmd
		mov	bl,MIDI_CONTROL
		add	bx,di
		call	mpu_write_data
		mov	bl,MIDI_CONTROL_DAMPER_PEDAL_ON_OFF
		call	mpu_write_data
		xor	bl,bl
		call	mpu_write_data

		mov	bl,MPU_CMD_WTS
		call	mpu_write_cmd
		mov	bl,1
		call	mpu_write_data
		xor	bl,bl
		call	mpu_write_data

		cmp	bp,FN_PAUSE_SOUND
		je	loc_74

		mov	bl,MPU_CMD_WTS
		call	mpu_write_cmd
		mov	bl,MIDI_PBEND
		add	bx,di
		call	mpu_write_data
		xor	bl,bl
		call	mpu_write_data
		mov	bl,40h			; '@'
		call	mpu_write_data
loc_74:
		inc	di
		cmp	di,MT32_NUM_CHANNELS
		jl	stop_sound_channel

		cmp	bp,FN_STOP_SOUND
		jne	loc_75			; Jump if not equal
		call	loop_song
loc_75:
		cmp	bp,FN_PAUSE_SOUND
		jne	loc_76			; Jump if not equal
		cmp	cs:reset_pause_active,0
		je	loc_76
		mov	bx,cs:orig_si
		mov	cx,cs:loop_position
		mov	[bx+SND_POS],cx
		mov	cs:midi_delay_left,0
		mov	cs:midi_decode_state,2
loc_76:
		pop	cx
		ret
stop_sound	endp

seek_sound      proc near
		cli				; Disable interrupts
		push	cx
		mov	bx,cs:orig_si
		mov	cx,[bx+SND_POS]
		push	si
		call	load_sound
		pop	si
;*		cmp	ax,1
		db	 3Dh, 01h, 00h		;  Fixup - byte match
		jnz	loc_80			; Jump if not zero
loc_77:
		push	si
		call	timer
		pop	si
		mov	bx,cs:orig_si
		cmp	cs:reset_pause_active,0
		je	loc_78
		cmp	cs:loop_position,22h
		je	loc_78
		mov	cs:midi_delay_left,0
		mov	cs:midi_decode_state,2
		mov	cx,cs:loop_position
loc_78:
		cmp	word ptr [bx+SND_SIGNAL],0FFFFh
		jne	loc_79			; Jump if not equal
		mov	cx,[bx+SND_POS]
loc_79:
		cmp	[bx+SND_POS],cx
		jb	loc_77			; Jump if below
loc_80:
		mov	cs:mt32_last_cmd,0
		pop	cx
		sti				; Enable interrupts
		ret
seek_sound      endp

; writes 20 characters from offset [bx] on the MT-32 display
mt32_show_text	proc	near
		push	di
		push	cx
		push	bx
		mov	bx,MPU_CMD_SYS_MSG
		call	mpu_write_cmd
		mov	cs:mt32_chksum,mt32_cmd_display_cksum
		xor	di,di
loc_81:
		mov	bl,cs:mt32_cmd_display[di]
		call	mpu_write_data
		inc	di
		cmp	di,mt32_cmd_display_len
		jl	loc_81

                ; loops di = 0..0x14
		pop	bx
		xor	di,di
loc_82:
		mov	cl,cs:[bx+di]
		push	bx
		mov	bl,cl
		add	cs:mt32_chksum,bl
		call	mpu_write_data
		pop	bx
		inc	di
		cmp	di,20
		jl	loc_82

                mt32_update_and_send_checksum
		mov	bl,MIDI_SYSEX_END
		call	mpu_write_data
		pop	cx
		pop	di
		ret
mt32_show_text	endp

initialize      proc    near
		mov	bx,cs:orig_si
		mov	di,[bx+SND_RESPTR]
		mov	es,[di+2]
		mov	si,[di]                 ; es:si = sound data
		;mov	cx,107
		mov	cx,offset mpu_init_error-offset mt32_text_ready
		xor	di,di

locloop_83:
		mov	bl,es:[si]
		mov	byte ptr cs:mt32_text_ready[di],bl
		inc	si
		inc	di
		loop	locloop_83		; Loop if cx > 0

		mov	bx,MPU_CMD_RESET
		call	mpu_write_cmd
		call	stop_sound
		cmp	cs:mpu_timed_out,0FFFFh
		jne	loc_84			; Jump if not equal

                ; MPU timed out somewhere
		mov	bx,offset mpu_init_error
		call	mt32_show_text

		xor	cx,cx
		mov	ax,0FFFFh               ; report init error
		ret

loc_84:         ; initialization sequence
		mov	bl,MPU_CMD_CLEAR_PLAY_MAP
		call	mpu_write_cmd
		mov	bl,MPU_CMD_CHN_REF_TAB_A_OFF
		call	mpu_write_cmd
		mov	bl,MPU_CMD_CHN_REF_TAB_B_OFF
		call	mpu_write_cmd
		mov	bl,MPU_CMD_CHN_REF_TAB_C_OFF
		call	mpu_write_cmd
		mov	bl,MPU_CMD_CHN_REF_TAB_D_OFF
		call	mpu_write_cmd

		mov	bx,offset mt32_text_init
		call	mt32_show_text
		call	mpu_delay
		call	sub_17
		call	mpu_delay
		call	sub_18
		call	mpu_delay

		mov	bx,es:[si]
		xchg	bl,bh
		inc	si
		inc	si
		cmp	bx,0ABCDh
		jne	loc_85			; Jump if not equal

		call	sub_17
		call	mpu_delay
		mov	bx,es:[si]
		xchg	bl,bh
		inc	si
		inc	si

loc_85:
		cmp	bx,0DCBAh
		jne	loc_86			; Jump if not equal
		call	sub_21
		call	mpu_delay
loc_86:
		mov	bx,offset mt32_text_ready
		call	mt32_show_text
		call	mpu_delay

		mov	bx,MPU_CMD_SYS_MSG
		call	mpu_write_cmd
		mov	cx,mpu_data_8_len
		xor	di,di

locloop_87:
		mov	bl,cs:mpu_data_8[di]
		call	mpu_write_data
		inc	di
		loop	locloop_87		; Loop if cx > 0

		xor	dx,dx
		mov	ax,cs:volume_max
		mov	bx,0Fh
		div	bx
		mov	cs:volume_scale,ax      ; volume_scale = volume_max / 15
		mov	cs:data_40,0
		mov	cs:data_36,0FFh
		mov	cs:current_volume,0FFFFh
		mov	cs:mpu_active_channels,0
		mov	bx,2
		mov	cs:func_tab[bx],terminate
		mov	ax,initialize           ; release memory after this offset
		xor	cx,cx
		ret
initialize      endp

; sends data from the patch.xxx resource (es:si)
;; I think this sends 0x180 * 8 bytes ?
sub_17		proc	near
		push	dx
		push	di
		xor	dx,dx
loc_88:
		push	bx
		mov	bx,MPU_CMD_SYS_MSG
		call	mpu_write_cmd
		mov	cs:mt32_chksum,0
		xor	di,di
loc_89:
		mov	bl,cs:mt32_cmd_wr_patch_memory[di]
		call	mpu_write_data
		inc	di
		cmp	di,mt32_cmd_wr_patch_memory_hdr_len
		jl	loc_89
loc_90:
		mov	bl,cs:mt32_cmd_wr_patch_memory[di]
		add	cs:mt32_chksum,bl
		call	mpu_write_data
		inc	di
		cmp	di,mt32_cmd_wr_patch_memory_len
		jl	loc_90
		pop	bx
		xor	di,di
loc_91:
		mov	bl,es:[si]
		add	cs:mt32_chksum,bl
		call	mpu_write_data
		inc	dx
		inc	si
		inc	di
		cmp	di,8
		jl	loc_91

                mt32_update_and_send_checksum
		mov	bl,MIDI_SYSEX_END
		call	mpu_write_data
		add	cs:patch_mem_addr_lo,8
		cmp	cs:patch_mem_addr_lo,7Fh
		jbe	loc_92			; Jump if below or =
		inc	cs:patch_mem_addr_hi
		sub	cs:patch_mem_addr_lo,80h
loc_92:
		cmp	dx,180h
		jae	loc_93			; Jump if above or =
		jmp	short loc_88
loc_93:
		pop	di
		pop	dx
		ret
sub_17		endp

sub_18		proc	near
		push	cx
		push	dx
		push	di
		mov	dl,es:[si]
		inc	si
		cmp	dl,0
		je	loc_95
		xor	cl,cl
		mov	cs:timbre_mem_addr_hi,0
		mov	cs:timbre_mem_addr_lo,0
loc_94:
		call	sub_19
		call	mpu_delay
		call	sub_20
		call	mpu_delay
		call	sub_20
		call	mpu_delay
		call	sub_20
		call	mpu_delay
		call	sub_20
		call	mpu_delay
		inc	cl
		inc	cl
		mov	cs:timbre_mem_addr_hi,cl
		mov	cs:timbre_mem_addr_lo,0
		dec	dl
		cmp	dl,0
		ja	loc_94			; Jump if above
loc_95:
		pop	di
		pop	dx
		pop	cx
		ret
sub_18		endp

sub_19		proc	near
		mov	bx,MPU_CMD_SYS_MSG
		call	mpu_write_cmd
		mov	cs:mt32_chksum,0
		xor	di,di
loc_96:
		mov	bl,cs:mt32_cmd_wr_timbre_mem[di]
		call	mpu_write_data
		inc	di
		cmp	di,mt32_cmd_wr_timbre_mem_hdr_len
		jl	loc_96
loc_97:
		mov	bl,cs:mt32_cmd_wr_timbre_mem[di]
		add	cs:mt32_chksum,bl
		call	mpu_write_data
		inc	di
		cmp	di,mt32_cmd_wr_timbre_mem_len
		jl	loc_97
		xor	di,di
loc_98:
		mov	bl,es:[si]
		add	cs:mt32_chksum,bl
		call	mpu_write_data
		inc	si
		inc	di
		cmp	di,0Eh
		jl	loc_98

                ; checksum?
                mt32_update_and_send_checksum
		mov	bl,MIDI_SYSEX_END
		call	mpu_write_data
		add	cs:timbre_mem_addr_lo,0Eh
		cmp	cs:timbre_mem_addr_lo,7Fh
		jbe	loc_ret_99		; Jump if below or =
		inc	cs:timbre_mem_addr_hi
		sub	cs:timbre_mem_addr_lo,80h

loc_ret_99:
		ret
sub_19		endp

sub_20		proc	near
		mov	bx,MPU_CMD_SYS_MSG
		call	mpu_write_cmd
		mov	cs:mt32_chksum,0
		xor	di,di
loc_100:
		mov	bl,cs:mt32_cmd_wr_timbre_mem[di]
		call	mpu_write_data
		inc	di
		cmp	di,5
		jl	loc_100
loc_101:
		mov	bl,cs:mt32_cmd_wr_timbre_mem[di]
		add	cs:mt32_chksum,bl
		call	mpu_write_data
		inc	di
		cmp	di,8
		jl	loc_101
		xor	di,di
loc_102:
		mov	bl,es:[si]
		add	cs:mt32_chksum,bl
		call	mpu_write_data
		inc	si
		inc	di
		cmp	di,3Ah
		jl	loc_102

                ; checksum?
                mt32_update_and_send_checksum
		mov	bl,MIDI_SYSEX_END
		call	mpu_write_data
		add	cs:timbre_mem_addr_lo,3Ah		; ':'
		cmp	cs:timbre_mem_addr_lo,7Fh
		jbe	loc_ret_103		; Jump if below or =
		inc	cs:timbre_mem_addr_hi
		sub	cs:timbre_mem_addr_lo,80h

loc_ret_103:
		ret
sub_20		endp

sub_21		proc	near
		push	dx
		push	di
		xor	dx,dx
loc_104:
		push	bx
		mov	bx,MPU_CMD_SYS_MSG
		call	mpu_write_cmd
		mov	cs:mt32_chksum,0
		xor	di,di
loc_105:
		mov	bl,cs:mt32_cmd_wr_patch_temp[di]
		call	mpu_write_data
		inc	di
		cmp	di,mt32_cmd_wr_patch_temp_hdr_len
		jl	loc_105
loc_106:
		mov	bl,cs:mt32_cmd_wr_patch_temp[di]
		add	cs:mt32_chksum,bl
		call	mpu_write_data
		inc	di
		cmp	di,mt32_cmd_wr_patch_temp_len
		jl	loc_106

		pop	bx
		xor	di,di
loc_107:
		mov	bl,es:[si]
		add	cs:mt32_chksum,bl
		call	mpu_write_data
		inc	dx
		inc	si
		inc	di
		cmp	di,4
		jl	loc_107

                mt32_update_and_send_checksum

		mov	bl,MIDI_SYSEX_END
		call	mpu_write_data
		add	cs:patch_tmp_addr_lo,4
		cmp	cs:patch_tmp_addr_lo,7Fh
		jbe	loc_108
		inc	cs:patch_tmp_addr_hi
		sub	cs:patch_tmp_addr_lo,80h
loc_108:
		cmp	dx,100h
		jae	loc_109
		jmp	short loc_104
loc_109:
		call	mpu_delay
		mov	bx,MPU_CMD_SYS_MSG
		call	mpu_write_cmd

		xor	di,di
		mov	cs:mt32_chksum,mt32_cmd_wr_sys_area_cksum
loc_110:
		mov	bl,cs:mt32_cmd_wr_sys_area[di]
		call	mpu_write_data
		inc	di
		cmp	di,mt32_cmd_wr_sys_area_len
		jl	loc_110

		xor	di,di
loc_111:
		mov	bl,es:[si]
		add	cs:mt32_chksum,bl
		call	mpu_write_data
		inc	di
		inc	si
		cmp	di,9
		jl	loc_111

                mt32_update_and_send_checksum
		mov	bl,MIDI_SYSEX_END
		call	mpu_write_data
		pop	di
		pop	dx
		ret
sub_21		endp

; reads the MPU status port a total of 9472 times
mpu_delay	proc	near
		push	ax
		push	dx
		push	di
		mov	dx,MPU_PORT_STATUS
		xor	di,di
loc_112:
		in	al,dx
		inc	di
		cmp	di,2500h
		jb	loc_112
		pop	di
		pop	dx
		pop	ax
		ret
mpu_delay	endp

; retrieve device info
func_0          proc near
                mov     ax,0x1              ; need patch.001
                mov     cx,0x20             ; cx = max polyphony
                ret
func_0          endp

seg_a		ends
		end	start

; vim:set ts=8:

include ../../common/midi.inc
include ../../common/mpu.inc

seg_a		segment	byte public
		assume	cs:seg_a, ds:seg_a


		org	0

NUM_CHANNELS                    equ 16

start:
		jmp	entry

                db      00h
                dd      87654321h      ; identifier
                db      01h            ; driver type 1 = sound

data_2		db	 4, 'dude'
                db      46, 'Roland MT-32, MT-100, LAPC-I, CM-32L, or CM-64'

                dd      0fedcba98h
		dw      0200h
                dw      0

; Roland Exclusive Messages: these all start with (p37)
; 0F0h, 41h, [device id], [model id], Command, body, 0F7h
MT32_MANID      equ     41h         ; manufactures-id
MT32_DEVID      equ     10h
MT32_MODEL      equ     16h         ; used for 'exclusive communication' (p41)
MT32_CMD_DT1    equ     12h         ; dataset #1

; MT-32 commands
cmd_wr_master_vol       db  09h, MIDI_SYSEX_BEGIN, MT32_MANID, MT32_DEVID, MT32_MODEL, MT32_CMD_DT1
                        db  10h, 00h, 16h
pl_master_vol           db  0

cmd_wr_reverb_mode      db  0Bh, MIDI_SYSEX_BEGIN, MT32_MANID, MT32_DEVID, MT32_MODEL, MT32_CMD_DT1
		        db      10h, 00h, 01h
pl_reverb_1             db	0
pl_reverb_2             db	0
pl_reverb_3             db	0
cmd_wr_display          db	1Ch, MIDI_SYSEX_BEGIN, MT32_MANID, MT32_DEVID, MT32_MODEL, MT32_CMD_DT1
                        db      20h, 00h, 00h
		        db	20 dup (20h)
; ??? no idea what this does
mt32_cmd_4              db	 0Fh, MIDI_SYSEX_BEGIN, MT32_MANID, MT32_DEVID, MT32_MODEL, MT32_CMD_DT1
		        db	 52h, 00h, 0Ah, 16h, 16h, 16h
		        db	 16h, 16h, 16h
		        db	20h
cmd_wr_patchmem         db	10h, MIDI_SYSEX_BEGIN, MT32_MANID, MT32_DEVID, MT32_MODEL, MT32_CMD_DT1
                        db  05h
pl_patchmem_addr_hi     db	0
pl_patchmem_addr_lo     db	0
		        db	8 dup (0)
cmd_wr_timbremem        db	0, MIDI_SYSEX_BEGIN, MT32_MANID, MT32_DEVID, MT32_MODEL, MT32_CMD_DT1
                        db  08h
pl_tibremem_addr_hi     db	0
pl_tibremem_addr_lo     db	59 dup (0)
cmd_wr_patchtemp        db	0Ch
                        db	MIDI_SYSEX_BEGIN, MT32_MANID, MT32_DEVID, MT32_MODEL, MT32_CMD_DT1
                        db      03h
pl_patchtemp_addr_lo    db	1
pl_patchtemp_addr_hi    db	10h
		    db	0, 0, 0, 0
cmd_wr_partial_reserve	db	11h			; Data table (indexed access)
		        db	 MIDI_SYSEX_BEGIN, MT32_MANID, MT32_DEVID, MT32_MODEL, MT32_CMD_DT1
                        db      10h, 00h, 04h
		        db	9 dup (0)

;; ---- start of header read from patch.001 ------------------------------------
mt32_text_ready db	20 dup (0)
mt32_text_init  db	20 dup (0)
mt32_text_bye   db	20 dup (0)
data_24		db	11 dup (0)
data_25		db	11 dup (0)
data_26		db	11 dup (0)
; used to map SCI volume levels 0..15 to MT-32 values (0..100)
volume_tab	db	0, 7, 13, 20, 27, 33, 40, 47, 53, 60, 67, 73, 80, 87, 93, 100
master_vol	db	15
reverb		db	0
data_30		db	1
ch_instrument	db	NUM_CHANNELS dup (0FFh)
ch_pbend	dw	NUM_CHANNELS dup (0FFFFh)   ; per-channel pitch bend
ch_mwl		db	NUM_CHANNELS dup (0FFh)     ; per-channel mod wheel lever (never changes)
ch_volume	db	NUM_CHANNELS dup (0FFh)     ; per-channel volume
ch_pan		db	NUM_CHANNELS dup (0FFh)     ; per-channel pan
ch_damper_pedal	db	NUM_CHANNELS dup (0FFh)     ; per-channel damper pedal
ch_note_on	db	NUM_CHANNELS dup (01h)      ; flag: whether there is note on this channel
last_midi_cmd	db	0                           ; last command sent (debug?)
mt32_chksum	db	0

func_tab        dw	dev_info                ; func 0: get device info
                dw      func_init               ; func 1: init
                dw      func_terminate          ; func 2: terminate
                dw      func_dummy              ; func 3: service
                dw      note_off                ; func 4: note off
                dw      note_on                 ; func 5: note on
                dw      func_dummy              ; func 6: poly after touch
                dw      controller              ; func 7: controller
                dw      pchange                 ; func 8: pchange
                dw      func_dummy              ; func 9: channel after touch
                dw      pbend                   ; func 10: pitch bend
                dw      set_reverb              ; func 11: set reverb
                dw      set_master_vol          ; func 12: master volume
                dw      sound_on                ; func 13: sound on
                dw      func_dummy              ; func 14: sample play
                dw      func_dummy              ; func 15: sample end
                dw      func_dummy              ; func 16: sample check
                dw      ask_driver              ; func 17: ask driver

entry           proc far
		push	dx
		shl	bp,1
		mov	dx,cs:func_tab[bp]
		call	dx
		pop	dx
		ret
entry           endp

func_dummy      proc near
		ret
func_dummy      endp

note_off        proc near
		push	ax
		mov	ah,MIDI_NOTE_ON
		mov	cl,0
		call	midi_send
		pop	ax
		retn
note_off        endp

note_on         proc near
		push	ax
		push	si
		mov	si,ax
		and	si,0FFh
		mov	byte ptr cs:ch_note_on[si],1
		mov	ah,MIDI_NOTE_ON
		call	midi_send
		pop	si
		pop	ax
		retn
note_on         endp

controller      proc near
		push	ax
		push	si
		mov	si,ax
		and	si,0FFh
		cmp	ch,MIDI_CONTROL_MOD_WHEEL_LEVER
		jne	loc_3
		cmp	cs:ch_mwl[si],cl
		je	loc_2
		mov	cs:ch_mwl[si],cl
		jmp	short loc_10
loc_2:
		jmp	short loc_11
loc_3:
		cmp	ch,MIDI_CONTROL_CH_VOLUME
		jne	loc_5
		cmp	cs:ch_volume[si],cl
		je	loc_4
		mov	cs:ch_volume[si],cl
		jmp	short loc_10
loc_4:
		jmp	short loc_11
loc_5:
		cmp	ch,MIDI_CONTROL_PAN
		jne	loc_7
		cmp	cs:ch_pan[si],cl
		je	loc_6
		mov	cs:ch_pan[si],cl
		jmp	short loc_10
loc_6:
		jmp	short loc_11
loc_7:
		cmp	ch,MIDI_CONTROL_DAMPER_PEDAL_ON_OFF
		jne	loc_9
		cmp	cs:ch_damper_pedal[si],cl
		je	loc_8
		mov	cs:ch_damper_pedal[si],cl
		jmp	short loc_10
loc_8:
		jmp	short loc_11
loc_9:
		cmp	ch,7Bh			; '{'
		jne	loc_11
		cmp	byte ptr cs:ch_note_on[si],0
		je	loc_11
		mov	byte ptr cs:ch_note_on[si],0
loc_10:
		mov	ah,MIDI_CONTROL
		call	midi_send
loc_11:
		pop	si
		pop	ax
		retn
controller      endp

pchange         proc near
		push	ax
		push	si
		mov	si,ax
		and	si,0FFh
		cmp	byte ptr cs:ch_instrument[si],cl
		je	loc_12
		mov	byte ptr cs:ch_instrument[si],cl
		mov	ah,MIDI_PCHANGE
		call	midi_send
loc_12:
		pop	si
		pop	ax
		retn
pchange         endp

pbend           proc near
		push	ax
		push	si
		mov	si,ax
		and	si,0FFh
		shl	si,1
		cmp	byte ptr cs:ch_pbend[si],cl
		jne	loc_13
		cmp	byte ptr cs:ch_pbend+1[si],ch
		jne	loc_13
		jmp	short loc_14
loc_13:
		mov	byte ptr cs:ch_pbend[si],cl
		mov	byte ptr cs:ch_pbend+1[si],ch
		mov	ah,MIDI_PBEND
		call	midi_send
loc_14:
		pop	si
		pop	ax
		retn
pbend           endp

; sends MIDI command [ah] to channel [al] with payload [ch] / [cl]
midi_send	proc	near
		push	bx
		mov	dl,al
		or	dl,ah
		cmp	dl,cs:last_midi_cmd
		mov	cs:last_midi_cmd,dl
		mov	bl,dl
		call	mpu_write_data
		cmp	ah,MIDI_PCHANGE
		je	loc_15
		cmp	ah,MIDI_AFTERTOUCH
		je	loc_15
		mov	bl,ch
		call	mpu_write_data
loc_15:
		mov	bl,cl
		call	mpu_write_data
		pop	bx
		retn
midi_send	endp

func_terminate  proc near
		mov	bx,offset mt32_text_bye
		call	mt32_show_text
		call	mpu_reset
		retn
func_terminate  endp

mpu_write_cmd	proc	near
		pushf
		cli
		push	ax
		push	cx
		push	dx
		mov	cx,0FFFFh
		mov	dx,331h
loc_16:
		in	al,dx			; port 331h ??I/O Non-standard
		test	al,40h			; '@'
		jz	loc_17
		dec	cx
		cmp	cx,0
		jne	loc_16
		jmp	short loc_20
loc_17:
		mov	al,bl
		out	dx,al			; port 331h ??I/O Non-standard
		mov	cx,0FFFFh
loc_18:
		in	al,dx			; port 331h ??I/O Non-standard
		rol	al,1
		jnc	loc_19
		dec	cx
		cmp	cx,0
		jne	loc_18
loc_19:
		mov	dx,330h
		in	al,dx			; port 330h ??I/O Non-standard
		cmp	al,0FEh
		je	loc_20
loc_20:
		pop	dx
		pop	cx
		pop	ax
		popf
		retn
mpu_write_cmd	endp


mpu_write_data	proc	near
		pushf
		cli
		push	ax
		push	cx
		push	dx
		mov	dx,331h
		mov	cx,0FFh
loc_21:
		in	al,dx			; port 331h ??I/O Non-standard
		test	al,40h			; '@'
		jz	loc_23
		dec	cx
		rol	al,1
		jc	loc_22
		mov	dx,330h
		in	al,dx			; port 330h ??I/O Non-standard
		mov	dx,331h
loc_22:
		cmp	cx,1
		jge	loc_21
		jmp	short loc_24
loc_23:
		mov	dx,330h
		mov	al,bl
		out	dx,al			; port 330h ??I/O Non-standard
loc_24:
		pop	dx
		pop	cx
		pop	ax
		popf
		retn
mpu_write_data	endp


set_master_vol	proc	near
		push	bx
		push	cx
		push	si
		mov	al,cs:master_vol
		xor	ah,ah
		cmp	cl,0FFh
		jne	loc_25
		jmp	short loc_26
loc_25:
		mov	cs:master_vol,cl
		cmp	cs:data_30,0
		je	loc_26
		push	ax
		mov	ch,0
		mov	si,cx
		mov	al,cs:volume_tab[si]
		mov	cs:pl_master_vol,al
		mov	bx,offset cmd_wr_master_vol
		call	mt32_send_cmd
		pop	ax
loc_26:
		pop	si
		pop	cx
		pop	bx
		retn
set_master_vol	endp


; sends the MT-32 command in [bx] - first byte is the length
mt32_send_cmd	proc	near
		push	bx
		push	bp
		push	di
		push	si
		mov	cs:last_midi_cmd,0
		mov	bp,bx
		mov	bl,cs:[bp]
		mov	bh,0

		mov	di,bx               ; di = bytes left
		inc	bp
		mov	cs:mt32_chksum,0
		mov	si,0
loc_27:
		mov	bl,cs:[bp]
		inc	bp
		cmp	si,5
		jb	loc_28

                ; bytes 5+ are part of the checksum, so update it
		mov	bh,cs:mt32_chksum
		add	bh,bl
		mov	cs:mt32_chksum,bh
loc_28:
		call	mpu_write_data
		dec	di
		inc	si
		cmp	di,0
		jne	loc_27

                ; data bytes sent, now send checksum
		mov	bl,cs:mt32_chksum
		neg	bl
		and	bl,7Fh
		call	mpu_write_data

                ; terminate command using SYSEX_END
		mov	bl,MIDI_SYSEX_END
		call	mpu_write_data
		pop	si
		pop	di
		pop	bp
		pop	bx
		retn
mt32_send_cmd	endp

set_reverb      proc near
		push	bx
		push	cx
		mov	al,cs:reverb
		xor	ah,ah
		cmp	cl,0FFh
		jne	loc_29
		jmp	short loc_30
loc_29:
		cmp	cl,cs:reverb
		je	loc_30

                ; reverb changed
		mov	cs:reverb,cl
		mov	bl,cl
		push	ax
		mov	bh,0
		mov	cl,cs:data_24[bx]
		mov	cs:pl_reverb_1,cl
		mov	cl,cs:data_25[bx]
		mov	cs:pl_reverb_2,cl
		mov	cl,cs:data_26[bx]
		mov	cs:pl_reverb_3,cl
		mov	bx,offset cmd_wr_reverb_mode
		call	mt32_send_cmd
		pop	ax
loc_30:
		pop	cx
		pop	bx
		retn
set_reverb      endp

sound_on        proc near
		xor	ah,ah
		mov	al,cs:data_30
		cmp	cl,0FFh
		jne	loc_31
		retn
loc_31:
		cmp	cl,0
		jne	loc_32
		mov	cs:data_30,0
		mov	cs:pl_master_vol,0
		mov	bx,offset cmd_wr_master_vol
		call	mt32_send_cmd
		retn
loc_32:
		push	ax
		mov	cs:data_30,1
		mov	ah,0
		mov	al,cs:master_vol
		mov	si,ax
		mov	al,cs:volume_tab[si]
		mov	cs:pl_master_vol,al
		mov	bx,offset cmd_wr_master_vol
		call	mt32_send_cmd
		pop	ax
		retn
sound_on        endp

; puts message at cs:[bx] on the LCD
mt32_show_text  proc	near
		push	bx
		push	cx
		push	si
		push	bp
		mov	bp,offset cmd_wr_display
		add	bp,9                ; payload
		mov	si,0
loc_33:
		mov	cl,cs:[bx+si]
		mov	cs:[bp],cl
		inc	bp
		inc	si
		cmp	si,20
		jne	loc_33

		mov	bx,offset cmd_wr_display
		call	mt32_send_cmd
		pop	bp
		pop	si
		pop	cx
		pop	bx
		retn
mt32_show_text  endp

; writes command 0FFh to the MPU
mpu_reset	proc	near
		pushf
		cli
		push	ax
		push	bx
		push	cx
		push	dx
loc_34:
		mov	cx,0FFFFh
		mov	bl,0FFh
		mov	dx,331h
loc_35:
		in	al,dx			; port 331h ??I/O Non-standard
		test	al,40h			; '@'
		jz	loc_36
		dec	cx
		cmp	cx,0
		jne	loc_35
		jmp	short loc_39
loc_36:
		mov	al,bl
		out	dx,al			; port 331h ??I/O Non-standard
		mov	cx,0FFFFh
loc_37:
		in	al,dx			; port 331h ??I/O Non-standard
		rol	al,1
		jnc	loc_38
		dec	cx
		cmp	cx,0
		jne	loc_37
loc_38:
		mov	dx,330h
		in	al,dx			; port 330h ??I/O Non-standard
		cmp	al,0FEh
		je	loc_39
		jmp	short loc_34
loc_39:
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		popf
		retn
mpu_reset	endp

ask_driver      proc near
		push	si
		mov	si,ax
		and	si,0FFh
		cmp	ah,MIDI_PBEND
		jne	loc_41

                ; ah = MIDI_PBEND
		shl	si,1
		mov	ax,cs:ch_pbend[si]
;*		cmp	ax,0FFFFh
		db	 3Dh,0FFh,0FFh
		jz	ask_driver_ret

		xchg	al,ah
		shr	ah,1
		jnc	loc_40
		or	al,80h
loc_40:
		jmp	short ask_driver_ret
loc_41:
		cmp	ah,MIDI_PCHANGE
		jne	loc_42

                ; ah = MIDI_PCHANGE
		mov	al,byte ptr cs:ch_instrument[si]
		jmp	short ask_driver_ret
loc_42:
		cmp	ah,MIDI_CONTROL
		jne	ask_driver_unknown
		cmp	ch,MIDI_CONTROL_DECAY_TIME
		je	ask_driver_unknown
		cmp	ch,MIDI_CONTROL_MOD_WHEEL_LEVER
		jne	loc_43
		mov	al,cs:ch_mwl[si]
		jmp	short ask_driver_ret
loc_43:
		cmp	ch,MIDI_CONTROL_CH_VOLUME
		jne	loc_44
		mov	al,cs:ch_volume[si]
		jmp	short ask_driver_ret
loc_44:
		cmp	ch,MIDI_CONTROL_PAN
		jne	loc_45
		mov	al,cs:ch_pan[si]
		jmp	short ask_driver_ret
loc_45:
		cmp	ch,MIDI_CONTROL_DAMPER_PEDAL_ON_OFF
		jne	ask_driver_unknown
		mov	al,cs:ch_damper_pedal[si]
		jmp	short ask_driver_ret
ask_driver_unknown:
		mov	ax,0FFFFh
ask_driver_ret:
		pop	si
		retn
ask_driver      endp

func_init       proc near
		push	si
		call	mpu_reset
		mov	si,ax
		mov	di,0
loc_48:
		mov	bl,es:[si]
		mov	cs:mt32_text_ready[di],bl
		inc	di
		inc	si
		cmp	di,3Ch
		jne	loc_48
		add	si,0Eh
		mov	di,0
loc_49:
		mov	bl,es:[si]
		mov	cs:data_24[di],bl
		add	si,0Bh
		mov	bl,es:[si]
		mov	cs:data_25[di],bl
		add	si,0Bh
		mov	bl,es:[si]
		mov	cs:data_26[di],bl
		sub	si,15h
		inc	di
		cmp	di,0Bh
		jne	loc_49
		add	si,16h

		mov	bx,0BFh                 ; oops?

		mov	bx,MPU_CMD_UART_MODE
		call	mpu_write_cmd
		call	mpu_delay
		mov	bx,MPU_CMD_UART_MODE
		call	mpu_write_cmd
		call	mpu_delay
		mov	bx,MPU_CMD_UART_MODE
		call	mpu_write_cmd
		call	mpu_delay
		call	mpu_delay

		mov	bx,offset mt32_text_init
		call	mt32_show_text
		call	mpu_delay
		call	transfer_patchmem
		call	mpu_delay
		call	transfer_all_tibremem
		call	mpu_delay
		mov	bx,es:[si]
		xchg	bl,bh
		inc	si
		inc	si
		cmp	bx,0ABCDh
		jne	loc_50
		call	transfer_patchmem
		call	mpu_delay
		mov	bx,es:[si]
		xchg	bl,bh
		inc	si
		inc	si
loc_50:
		cmp	bx,0DCBAh
		jne	loc_51
		call	transfer_patch_temp
		call	mpu_delay
loc_51:
		mov	bx,offset mt32_text_ready
		call	mt32_show_text
		call	mpu_delay

		mov	bx,offset mt32_cmd_4
		call	mt32_send_cmd
		mov	cl,0Ch
		call	set_master_vol
		mov	cs:reverb,0FFh

		mov	ax,offset func_init
		mov	cl,1
		mov	ch,8
		pop	si
		retn
func_init       endp

; writes data at es:[si] to 'patch memory'
transfer_patchmem	proc	near
		push	dx
		push	di
		mov	dx,0
loc_52:
		mov	di,offset data_2
loc_53:
		mov	bl,es:[si]
		mov	cs:cmd_wr_patchmem[di],bl
		inc	si
		inc	di
		cmp	di,11h
		jne	loc_53

		mov	bx,offset cmd_wr_patchmem
		call	mt32_send_cmd
		add	cs:pl_patchmem_addr_lo,8
		cmp	cs:pl_patchmem_addr_lo,7Fh
		jb	loc_54
		inc	cs:pl_patchmem_addr_hi
		sub	cs:pl_patchmem_addr_lo,80h
loc_54:
		inc	dx
		cmp	dx,30h
		jne	loc_52
		pop	di
		pop	dx
		retn
transfer_patchmem	endp

; transfers all tibre memory from es:[si]
transfer_all_tibremem	proc	near
		mov	dl,es:[si]
		inc	si
		mov	cs:pl_tibremem_addr_hi,0
		mov	cs:pl_tibremem_addr_lo,0
		mov	cl,0
loc_55:
		cmp	dl,0
		je	loc_ret_56
		call	transfer_tibremem1
		call	mpu_delay
		call	transfer_tibremem2
		call	mpu_delay
		call	transfer_tibremem2
		call	mpu_delay
		call	transfer_tibremem2
		call	mpu_delay
		call	transfer_tibremem2
		call	mpu_delay
		add	cl,2
		mov	cs:pl_tibremem_addr_hi,cl
		mov	cs:pl_tibremem_addr_lo,0
		dec	dl
		jmp	short loc_55

loc_ret_56:
		retn
transfer_all_tibremem	endp

; writes data at es:[si] to 'timbre memory'
transfer_tibremem1		proc	near
		push	di
		push	bx
		mov	di,offset data_2
loc_57:
		mov	bl,es:[si]
		mov	cs:cmd_wr_timbremem[di],bl
		inc	si
		inc	di
		cmp	di,17h
		jne	loc_57

		mov	cs:cmd_wr_timbremem,16h
		mov	bx,offset cmd_wr_timbremem
		call	mt32_send_cmd
		add	cs:pl_tibremem_addr_lo,0Eh
		cmp	cs:pl_tibremem_addr_lo,7Fh
		jbe	loc_58
		inc	cs:pl_tibremem_addr_hi
		sub	cs:pl_tibremem_addr_lo,80h
loc_58:
		pop	bx
		pop	di
		retn
transfer_tibremem1		endp

; writes data at es:[si] to 'timbre memory'
transfer_tibremem2	proc	near
		push	di
		push	bx
		mov	di,offset data_2
loc_59:
		mov	bl,es:[si]
		mov	cs:cmd_wr_timbremem[di],bl
		inc	si
		inc	di
		cmp	di,43h
		jne	loc_59

		mov	cs:cmd_wr_timbremem,42h		; 'B'
		mov	bx,offset cmd_wr_timbremem
		call	mt32_send_cmd
		add	cs:pl_tibremem_addr_lo,3Ah		; ':'
		cmp	cs:pl_tibremem_addr_lo,7Fh
		jbe	loc_60
		inc	cs:pl_tibremem_addr_hi
		sub	cs:pl_tibremem_addr_lo,80h
loc_60:
		pop	bx
		pop	di
		retn
transfer_tibremem2	endp

; writes data at es:[si] to 'patch temp'
transfer_patch_temp	proc	near
		push	dx
		push	di
		mov	dx,0
loc_61:
		mov	di,offset data_2
loc_62:
		mov	bl,es:[si]
		mov	cs:cmd_wr_patchtemp[di],bl
		inc	si
		inc	di
		cmp	di,0Dh
		jne	loc_62

		mov	bx,offset cmd_wr_patchtemp
		call	mt32_send_cmd
		add	cs:pl_patchtemp_addr_hi,4
		cmp	cs:pl_patchtemp_addr_hi,7Fh
		jbe	loc_63
		inc	cs:pl_patchtemp_addr_lo
		sub	cs:pl_patchtemp_addr_hi,80h
loc_63:
		inc	dx
		cmp	dx,40h
		jne	loc_61
		call	mpu_delay
		mov	di,offset data_2
loc_64:
		mov	bl,es:[si]
		mov	cs:cmd_wr_partial_reserve[di],bl
		inc	si
		inc	di
		cmp	di,12h
		jne	loc_64

		mov	bx,offset cmd_wr_partial_reserve
		call	mt32_send_cmd
		pop	di
		pop	dx
		retn
transfer_patch_temp	endp

mpu_delay	proc	near
		push	ax
		push	dx
		push	di
		mov	dx,331h
		mov	di,2500h
loc_65:
		in	al,dx			; port 331h ??I/O Non-standard
		dec	di
		cmp	di,0
		jne	loc_65
		pop	di
		pop	dx
		pop	ax
		retn
mpu_delay	endp

dev_info        proc near
                mov     ah,0x1
                mov     al,0x1              ; need patch.001
                mov     ch,0xc              ; device ID
                mov     cl,0x20             ; cl = max polyphony
                ret
dev_info        endp

seg_a		ends
		end	start

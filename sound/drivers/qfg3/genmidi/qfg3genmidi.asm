; vim:set ts=8:

include ../../common/midi.inc

seg_a		segment	byte public
		assume	cs:seg_a, ds:seg_a


		org	0

MPU_PORT_DATA   equ 330h
MPU_PORT_STATUS equ 331h
MPU_STATUS_DSR  equ 80h     ; data set ready
MPU_STATUS_DRR  equ 40h     ; data read ready

NUM_CHANNELS                    equ 16

CHAN_9          equ 9       ; channel 9

start:
		jmp	loc_1

		db      00h
                dd      87654321h      ; identifier
                db      01h            ; driver type 1 = sound

		db	4, 'dude'
		db	37, 'General MIDI for Roland MPU interface'

                dd      0fedcba98h
		dw      0200h
                dw      0
		db	 76h, 31h, 2Eh, 30h, 36h

; --- data copied from the patch.004 resource ----------------------------------
data_3		db	128 dup (0FFh)          ; read in pchange
data_5		db	128 dup (0)		; read in pchange
data_6		db	128 dup (0)             ; read in pchange
; data_7 is used in note_{on,off} for channel 9. A value of 0FFh skips the command
; the lookup is done based on the 'note' value
data_7		db	128 dup (0)
data_8		db	0                       ; copied to data_24 (unused?)
; data_9 is read in pchange
data_9		db	128 dup (0)             ; used in pchange
data_10		db	512 dup (0)             ; used in note_on
; --- end of data copied from the patch.004 resource --------------------------
PATCH_DATA_SIZE equ     $-offset data_3

master_volume	db	15                      ; volume
is_sound_on	db	1
ch_instrument	db	NUM_CHANNELS dup (0FFh)     ; per-channel instrument
ch_pbend	dw	NUM_CHANNELS dup (0FFFFh)   ; per-channel pitch bend
ch_mwl		db	NUM_CHANNELS dup (0FFh)     ; per-channel mod wheel lever (never changes)
ch_volume	db	NUM_CHANNELS dup (0FFh)     ; per-channel volume
ch_pan		db	NUM_CHANNELS dup (0FFh)     ; per-channel pan
ch_damper_pedal	db	NUM_CHANNELS dup (0FFh)     ; per-channel damper pedal
ch_note_on	db	NUM_CHANNELS dup (01h)      ; per-channel note-on flag
data_22		dw	8 dup (0)
; written by pchange, read by controller
data_23		db	9 dup (0)
data_24		db	0                       ; never read?
                db      6 dup (0)               ; unused ?
; data_25 is set by pchange (data_9[instrument] will be copied into it)
; used by note_on
data_25		db	NUM_CHANNELS dup (0)
; data_25 is set by pchange (data_3[instrument] will be copied into it)
; used by note_on / note_off
data_26		db	NUM_CHANNELS dup (0)    ; used by pchange
midi_last_cmd	db	0                       ; last MIDI command sent (debug?)
reverb		db	0                       ; unused?

func_tab	dw	dev_info                ; func 0: get device info
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
		dw	ask_driver              ; func 17: ask driver
loc_1:
		push	dx
		shl	bp,1
		mov	dx,cs:func_tab[bp]
		call	dx
		pop	dx
		retf

func_dummy      proc near
		retn
func_dummy      endp

set_reverb      proc near
		mov	al,cs:reverb
		xor	ah,ah
		cmp	cl,0FFh
		jne	loc_2
		retn
loc_2:
		mov	cs:reverb,cl
		retn
set_reverb      endp

; al = channel, cl = velocity, ch = note
note_off        proc near
		push	ax
		push	si
		push	cx
		cmp	al,CHAN_9
		jne	loc_3

                ; al = CHAN_9 - because of the xchg/and, only the note
                ; value (usually in ch) will be used
		xchg	cl,ch
		mov	si,cx
		xchg	cl,ch
		and	si,7Fh
		mov	ch,cs:data_7[si]
		cmp	ch,0FFh
		je	note_off_leave
		jmp	short loc_5

loc_3:          ; al != CHAN_9
		mov	si,ax
		and	si,0Fh
		cmp	cs:data_26[si],0FFh
		je	note_off_leave

		add	ch,byte ptr cs:data_22[si]
		mov	ah,0F4h
		cmp	byte ptr cs:data_22[si],80h
		jb	loc_4
		mov	ah,0Ch
loc_4:
		cmp	ch,80h
		jb	loc_5
		add	ch,ah
		jmp	short loc_4

loc_5:          ; ch = note
		mov	ah,MIDI_NOTE_ON
		mov	cl,0                ; velocity = 0
		call	midi_message
note_off_leave:
		pop	cx
		pop	si
		pop	ax
		retn
note_off        endp

; al = channel, cl = velocity, ch = note
note_on         proc near
		push	ax
		push	si
		push	cx
		push	di
		cmp	al,CHAN_9
		jne	loc_7

                ; al = CHAN_9
		xchg	cl,ch
		mov	si,cx
		xchg	cl,ch
		and	si,7Fh
		mov	ch,cs:data_7[si]
		cmp	ch,0FFh
		je	note_on_leave

		mov	si,ax
		and	si,0Fh
		jmp	short loc_9

loc_7:          ; al != CHAN_9
		mov	si,ax
		and	si,0Fh
		cmp	cs:data_26[si],0FFh
		je	note_on_leave

		add	ch,byte ptr cs:data_22[si]
		mov	ah,0F4h
		cmp	byte ptr cs:data_22[si],80h
		jb	loc_8
		mov	ah,0Ch
loc_8:
		cmp	ch,80h
		jb	loc_9
		add	ch,ah
		jmp	short loc_8

loc_9:
		push	ax
		mov	al,80h
		mul	cs:data_25[si]              ; ax = data_25[si] * 128
		mov	di,cx
		and	di,7Fh
		add	di,ax                       ; di = (cx & 7fh) + (data_25[si] * 128)
		pop	ax
		mov	cl,cs:data_10[di]           ; cl = velocity
		mov	byte ptr cs:ch_note_on[si],1
		mov	ah,MIDI_NOTE_ON
		call	midi_message
note_on_leave:
		pop	di
		pop	cx
		pop	si
		pop	ax
		retn
note_on         endp

; al = channel, ch = MIDI_CONTROL_xx, cl = value
controller	proc	near
		push	ax
		push	si
		mov	si,ax
		and	si,0Fh              ; si = channel
		and	cl,7Fh
		cmp	ch,MIDI_CONTROL_CH_VOLUME
		jne	loc_13

                ; ch = MIDI_CONTROL_CH_VOLUME
		mov	cs:ch_volume[si],cl
		cmp	cs:is_sound_on,0
		jne	loc_11
		jmp	short controller_leave
loc_11:
		add	cl,cs:data_23[si]
		cmp	cl,80h
		jb	loc_12
		mov	cl,7Fh
		cmp	cs:data_23[si],80h
		jb	loc_12
		mov	cl,1
loc_12:
		mov	ch,al
		mov	al,cs:master_volume
		mul	cl
		mov	cl,0Fh
		div	cl
		mov	cl,al
		mov	al,ch
		mov	ch,MIDI_CONTROL_CH_VOLUME
		or	cl,cl
		jnz	loc_16
		or	ah,ah
		jz	loc_16
		inc	cl
		jmp	short loc_16

loc_13:         ; ch != MIDI_CONTROL_CH_VOLUME
		cmp	ch,MIDI_CONTROL_PAN
		jne	loc_14
		cmp	cs:ch_pan[si],cl
		je	controller_leave
		mov	cs:ch_pan[si],cl
		jmp	short loc_16
loc_14:
		cmp	ch,MIDI_CONTROL_DAMPER_PEDAL_ON_OFF
		jne	loc_15
		cmp	cs:ch_damper_pedal[si],cl
		je	controller_leave
		mov	cs:ch_damper_pedal[si],cl
		jmp	short loc_16
loc_15:
		cmp	ch,MIDI_CONTROL_ALL_NOTES_OFF
		jne	controller_leave
		cmp	byte ptr cs:ch_note_on[si],0
		je	controller_leave
		mov	byte ptr cs:ch_note_on[si],0
loc_16:
		mov	ah,MIDI_CONTROL
		call	midi_message
controller_leave:
		pop	si
		pop	ax
		retn
controller	endp

; al = channel - if CHAN_9 or if the instrument is already active, does nothing
pchange         proc near
		push	ax
		push	si
		push	cx
		push	bx
		cmp	al,CHAN_9
		je	pchange_leave_2         ; do nothing if al = CHAN_9

		mov	si,ax
		and	si,0Fh
		cmp	cs:ch_instrument[si],cl
		je	pchange_leave_2         ; do nothing if instrument doesn't change

		mov	cs:ch_instrument[si],cl
		mov	si,cx
		and	si,7Fh                  ; si = instrument value

                ; look up patch values
		mov	cl,cs:data_3[si]
		mov	ch,cs:data_5[si]
		mov	bh,cs:data_6[si]
		mov	bl,cs:data_9[si]

		mov	si,ax
		and	si,0Fh                  ; si = channel
		mov	cs:data_25[si],bl

		xor	bl,bl
		cmp	cs:data_26[si],0FFh
		jne	loc_18
		inc	bl
loc_18:         ; bl = 1 iff data_26[si] == 0FFh, otherwise 0

		mov	cs:data_26[si],cl
		cmp	cl,0FFh
		jne	loc_20

                ; data_26[si] = 0FFh
		mov	ah,MIDI_CONTROL
		mov	ch,MIDI_CONTROL_ALL_NOTES_OFF
		xor	cl,cl
		call	midi_message
pchange_leave_2:
		jmp	short pchange_leave

loc_20:
		cmp	ch,byte ptr cs:data_22[si]
                je	loc_21

                ; data_22[si] != ch
		mov	byte ptr cs:data_22[si],ch
		push	cx
		mov	ah,MIDI_CONTROL
		mov	ch,MIDI_CONTROL_ALL_NOTES_OFF
		xor	cl,cl
		call	midi_message
		pop	cx
		inc	bl

loc_21:
		or	bl,bl
		jnz	loc_22
		cmp	bh,cs:data_23[si]
		je	loc_23
loc_22:         ; restore volume
		mov	cs:data_23[si],bh
		push	cx
		mov	cl,cs:ch_volume[si]
		mov	ch,MIDI_CONTROL_CH_VOLUME
		call	controller
		pop	cx

loc_23:
		mov	ah,MIDI_PCHANGE
		call	midi_message
		or	bl,bl
		jz	pchange_leave

                ; bl != 0 --> restore pan/pitch bend values
		mov	ah,MIDI_CONTROL
		mov	ch,MIDI_CONTROL_PAN
		mov	cl,cs:ch_pan[si]
		and	cl,7Fh
		call	midi_message
		shl	si,1
		mov	cl,byte ptr cs:ch_pbend[si]
		and	cl,7Fh
		mov	ch,byte ptr cs:ch_pbend+1[si]
		and	ch,7Fh
		mov	ah,MIDI_PBEND
		call	midi_message
pchange_leave:
		pop	bx
		pop	cx
		pop	si
		pop	ax
		retn
pchange         endp

pbend           proc near
		push	ax
		push	si
		mov	si,ax
		and	si,0Fh
		shl	si,1
		cmp	byte ptr cs:ch_pbend[si],cl
		jne	loc_25
		cmp	byte ptr cs:ch_pbend+1[si],ch
		je	loc_26
loc_25:
		mov	byte ptr cs:ch_pbend[si],cl
		mov	byte ptr cs:ch_pbend+1[si],ch
		mov	ah,MIDI_PBEND
		call	midi_message
loc_26:
		pop	si
		pop	ax
		retn
pbend           endp

; al = channel, ah = command - cx = data (2 bytes unless pchange/aftertouch)
midi_message	proc	near
		push	bx
		mov	dl,al
		or	dl,ah
		mov	cs:midi_last_cmd,dl
		mov	bl,dl
		call	mpu_write_data
		cmp	ah,MIDI_PCHANGE
		je	loc_27
		cmp	ah,MIDI_AFTERTOUCH
		je	loc_27
		mov	bl,ch
		call	mpu_write_data
loc_27:
		mov	bl,cl
		call	mpu_write_data
		pop	bx
		retn
midi_message	endp

func_terminate  proc near
		push	bx
		call	mpu_reset
		pop	bx
		retn
func_terminate  endp

; writes command [bl] to the mpu
mpu_write_cmd	proc	near
		pushf
		cli
		push	ax
		push	cx
		push	dx
		mov	cx,0FFFFh
		mov	dx,MPU_PORT_STATUS
loc_28:
		in	al,dx
		test	al,MPU_STATUS_DRR
		jz	loc_29

		dec	cx
		cmp	cx,0
		jne	loc_28
		jmp	short loc_32

loc_29:         ; send command in bl
		mov	al,bl
		out	dx,al
		mov	cx,0FFFFh
loc_30:
		in	al,dx
		rol	al,1
		jnc	loc_31
		dec	cx
		cmp	cx,0
		jne	loc_30
loc_31:
		mov	dx,MPU_PORT_DATA
		in	al,dx
		cmp	al,0FEh
		je	loc_32
loc_32:
		pop	dx
		pop	cx
		pop	ax
		popf
		retn
mpu_write_cmd	endp

; sends byte [bl] to the MPU's data port
mpu_write_data	proc	near
		pushf
		cli
		push	ax
		push	cx
		push	dx
		mov	dx,MPU_PORT_STATUS
		mov	cx,0FFh
loc_33:
		in	al,dx
		test	al,MPU_STATUS_DRR
		jz	loc_35
		dec	cx
		rol	al,1
		jc	loc_34
		mov	dx,MPU_PORT_DATA
		in	al,dx
		mov	dx,MPU_PORT_STATUS
loc_34:
		cmp	cx,1
		jge	loc_33
		jmp	short loc_36
loc_35:
		mov	dx,MPU_PORT_DATA
		mov	al,bl
		out	dx,al
loc_36:
		pop	dx
		pop	cx
		pop	ax
		popf
		retn
mpu_write_data	endp

set_master_vol  proc	near
		push	bx
		push	cx
		push	si
		mov	al,cs:master_volume
		xor	ah,ah
		cmp	cl,0FFh
		je	loc_39
		mov	cs:master_volume,cl
		cmp	cs:is_sound_on,0
		je	loc_39
		push	ax
		mov	al,1
		mov	si,1
		mov	ch,MIDI_CONTROL_CH_VOLUME
loc_37:
		mov	cl,cs:ch_volume[si]
		cmp	cl,0FFh
		je	loc_38
		call	controller
loc_38:
		inc	al
		inc	si
		cmp	al,0Ah
		jne	loc_37
		pop	ax
loc_39:
		pop	si
		pop	cx
		pop	bx
		retn
set_master_vol  endp

sound_on        proc    near
		xor	ah,ah
		mov	al,cs:is_sound_on
		cmp	cl,0FFh
		jne	loc_40
		retn
loc_40:
		push	ax
		push	cx
		cmp	cl,0
		jne	loc_42
		mov	cs:is_sound_on,0

                ; repeat from channel 1..8
		mov	al,1
		mov	ah,MIDI_CONTROL
		mov	ch,MIDI_CONTROL_CH_VOLUME
		mov	cl,0
loc_41:
		call	midi_message
		inc	al
		cmp	al,CHAN_9
		jne	loc_41

		pop	cx
		pop	ax
		retn
loc_42:
		mov	cs:is_sound_on,1
		mov	cl,cs:master_volume
		call	set_master_vol
		pop	cx
		pop	ax
		retn
sound_on        endp

mpu_reset	proc	near
		push	bx
		mov	bl,0FFh
		call	mpu_write_cmd
		pop	bx
		retn
mpu_reset	endp

; seems to retrieve a value?
ask_driver      proc near
		push	si
		mov	si,ax
		and	si,0Fh
		cmp	ah,MIDI_PBEND
		jne	loc_44

                ; ah = MIDI_PBEND
		shl	si,1
		mov	ax,cs:ch_pbend[si]
		cmp	ax,0FFFFh
		je	func_17_leave
		xchg	al,ah
		shr	ah,1
		jnc	loc_43
		or	al,80h
loc_43:
		jmp	short func_17_leave
loc_44:
		cmp	ah,MIDI_PCHANGE
		jne	loc_45
		mov	al,cs:ch_instrument[si]
		jmp	short func_17_leave
loc_45:
		cmp	ah,MIDI_CONTROL
		jne	ask_driver_error
		cmp	ch,MIDI_CONTROL_DECAY_TIME
		je	ask_driver_error
		cmp	ch,MIDI_CONTROL_MOD_WHEEL_LEVER
		jne	loc_46
		mov	al,cs:ch_mwl[si]
		jmp	short func_17_leave
loc_46:
		cmp	ch,MIDI_CONTROL_CH_VOLUME
		jne	loc_47
		mov	al,cs:ch_volume[si]
		jmp	short func_17_leave
loc_47:
		cmp	ch,MIDI_CONTROL_PAN
		jne	loc_48
		mov	al,cs:ch_pan[si]
		jmp	short func_17_leave
loc_48:
		cmp	ch,MIDI_CONTROL_DAMPER_PEDAL_ON_OFF
		jne	ask_driver_error
		mov	al,cs:ch_damper_pedal[si]
		jmp	short func_17_leave
ask_driver_error:
		mov	ax,0FFFFh
func_17_leave:
		pop	si
		retn
ask_driver      endp

func_init       proc
                push    si

                call    mpu_reset
                mov     bx,3Fh

                call    mpu_write_cmd
                call    mpu_delay
                mov     bx,03Fh
                call    mpu_write_cmd
                call    mpu_delay
                mov     bx,03Fh
                call    mpu_write_cmd
                call    mpu_delay
                call    mpu_delay

                ; copy first chunk of data (0x441 bytes)
                mov     si,ax
                mov     di,0x0
loc_51:
		mov	bl,es:[si]
		mov	cs:data_3[di],bl
		inc	di
		inc	si
		cmp	di,PATCH_DATA_SIZE
		jne	loc_51

		mov	bl,cs:data_8
		mov	cs:data_24,bl

                ; read word, this is the number of MIDI bytes to send
		mov	cl,es:[si]
		inc	si
		mov	ch,es:[si]
		inc	si
		cmp	cx,0
		je	loc_54

                ; now send [cx] bytes to the MPU
locloop_52:
		mov	bl,es:[si]
		inc	si
		call	mpu_write_data
		cmp	bl,MIDI_SYSEX_END
		jne	loc_53

                ; sysex end is followed by a delay
		call	mpu_delay
		call	mpu_delay
loc_53:
		loop	locloop_52

loc_54:         ; done with initialization
		mov	cl,0Ch
		call	set_master_vol

		mov	ax,offset func_init
		mov	cl,1
		mov	ch,8
		pop	si
		retn
func_init       endp

; reads the MPU status port a total of 29952 times
mpu_delay	proc	near
		push	ax
		push	dx
		push	di
		mov	dx,MPU_PORT_STATUS
		mov	di,7500h
loc_55:
		in	al,dx
		dec	di
		cmp	di,0
		jne	loc_55
		pop	di
		pop	dx
		pop	ax
		retn
mpu_delay	endp

; retrieve device info
dev_info        proc near
                mov     ah,0x1
                mov     al,0x4              ; need patch.004
                mov     ch,0x7              ; device ID
                mov     cl,0x20             ; cl = max polyphony
                ret
dev_info        endp

seg_a		ends
		end	start

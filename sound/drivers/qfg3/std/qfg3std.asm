; vim:set ts=8:

include ../../common/midi.inc

seg_a		segment	byte public
		assume	cs:seg_a, ds:seg_a


		org	0

start:
		jmp	entry

		db      00h
                dd      87654321h      ; identifier
                db      01h            ; driver type 1 = sound

		db	 6, 'stddrv'
		db	37, 'IBM PC or Compatible Internal Speaker'

                dd      0fedcba98h
                dw      1h, 0h
		db	'2.00'

data_3		dw	25h			; Data table (indexed access)
		db	 25h, 00h, 26h, 00h, 26h, 00h
		db	 27h, 00h, 27h, 00h, 28h, 00h
		db	 29h, 00h, 29h, 00h, 2Ah, 00h
		db	 2Ah, 00h, 2Bh, 00h, 2Ch, 00h
		db	 2Ch, 00h, 2Dh, 00h, 2Eh, 00h
		db	 2Eh, 00h, 2Fh, 00h, 30h, 00h
		db	 30h, 00h, 31h, 00h, 32h, 00h
		db	 32h, 00h, 33h, 00h, 34h, 00h
		db	 35h, 00h, 35h, 00h, 36h, 00h
		db	 37h, 00h, 38h, 00h, 39h, 00h
		db	 39h, 00h, 3Ah, 00h, 3Bh, 00h
		db	 3Ch, 00h, 3Dh, 00h, 3Eh, 00h
		db	 3Fh, 00h, 3Fh, 00h, 40h, 00h
		db	 41h, 00h, 42h, 00h, 43h, 00h
		db	 44h, 00h, 45h, 00h, 46h, 00h
		db	 47h, 00h, 48h, 00h, 49h, 00h
		db	 4Ah, 00h, 4Ch, 00h, 4Dh, 00h
		db	 4Eh, 00h, 4Fh, 00h, 50h, 00h
		db	 51h, 00h, 52h, 00h, 54h, 00h
		db	 55h, 00h, 56h, 00h, 57h, 00h
		db	 59h, 00h, 5Ah, 00h, 5Bh, 00h
		db	 5Ch, 00h, 5Eh, 00h, 5Fh, 00h
		db	 61h, 00h, 62h, 00h, 63h, 00h
		db	 65h, 00h, 66h, 00h, 68h, 00h
		db	 69h, 00h, 6Bh, 00h, 6Ch, 00h
		db	 6Eh, 00h, 70h, 00h, 71h, 00h
		db	 73h, 00h, 74h, 00h, 76h, 00h
		db	 78h, 00h, 7Ah, 00h, 7Bh, 00h
		db	 7Dh, 00h, 7Fh, 00h, 81h, 00h
		db	 83h, 00h, 85h, 00h, 87h, 00h
		db	 89h, 00h, 8Bh, 00h, 8Dh, 00h
		db	 8Fh, 00h, 91h, 00h, 93h, 00h
		db	 95h, 00h, 97h, 00h, 99h, 00h
		db	 9Ch, 00h, 9Eh, 00h,0A0h, 00h
		db	0A2h, 00h,0A5h, 00h,0A7h, 00h
		db	0AAh, 00h,0ACh, 00h,0AFh, 00h
		db	0B1h, 00h,0B4h, 00h,0B6h, 00h
		db	0B9h, 00h,0BCh, 00h,0BEh, 00h
		db	0C1h, 00h,0C4h, 00h,0C7h, 00h
		db	0CAh, 00h,0CDh, 00h,0D0h, 00h
		db	0D3h, 00h,0D6h, 00h,0D9h, 00h
		db	0DCh, 00h,0DFh, 00h,0E2h, 00h
		db	0E6h, 00h,0E9h, 00h,0ECh, 00h
		db	0F0h, 00h,0F3h, 00h,0F7h, 00h
		db	0FAh, 00h,0FEh, 00h, 02h, 01h
		db	 06h, 01h, 09h, 01h, 0Dh, 01h
		db	 11h, 01h, 15h, 01h, 19h, 01h
		db	 1Dh, 01h, 21h, 01h, 26h, 01h
		db	 2Ah, 01h, 2Eh, 01h, 33h, 01h
		db	 37h, 01h, 3Ch, 01h, 40h, 01h
		db	 45h, 01h, 4Ah, 01h, 4Eh, 01h
		db	 53h, 01h, 58h, 01h, 5Dh, 01h
		db	 62h, 01h, 67h, 01h, 6Dh, 01h
		db	 72h, 01h, 77h, 01h, 7Dh, 01h
		db	 82h, 01h, 88h, 01h, 8Eh, 01h
		db	 93h, 01h, 99h, 01h, 9Fh, 01h
		db	0A5h, 01h,0ABh, 01h,0B2h, 01h
		db	0B8h, 01h,0BEh, 01h,0C5h, 01h
		db	0CBh, 01h,0D2h, 01h,0D9h, 01h
		db	0E0h, 01h,0E7h, 01h,0EEh, 01h
		db	0F5h, 01h,0FCh, 01h, 04h, 02h
		db	 0Bh, 02h, 13h, 02h, 1Bh, 02h
		db	 22h, 02h, 2Ah, 02h, 32h, 02h
		db	 3Bh, 02h, 43h, 02h, 4Bh, 02h
		db	 54h, 02h, 5Ch, 02h, 65h, 02h
		db	 6Eh, 02h, 77h, 02h, 80h, 02h
		db	 8Ah, 02h, 93h, 02h, 9Dh, 02h
		db	0A7h, 02h,0B0h, 02h,0BAh, 02h
		db	0C5h, 02h,0CFh, 02h,0D9h, 02h
		db	0E4h, 02h,0EFh, 02h,0FAh, 02h
		db	 05h, 03h, 10h, 03h, 1Bh, 03h
		db	 27h, 03h, 33h, 03h, 3Fh, 03h
		db	 4Bh, 03h, 57h, 03h, 63h, 03h
		db	 70h, 03h, 7Dh, 03h, 8Ah, 03h
		db	 97h, 03h,0A4h, 03h,0B2h, 03h
		db	0C0h, 03h,0CEh, 03h,0DCh, 03h
		db	0EAh, 03h,0F9h, 03h, 07h, 04h
		db	 16h, 04h, 26h, 04h, 35h, 04h
		db	 45h, 04h, 55h, 04h, 65h, 04h
		db	 75h, 04h, 86h, 04h, 97h, 04h
		db	0A8h, 04h,0B9h, 04h,0CBh, 04h
		db	0DCh, 04h,0EFh, 04h, 01h, 05h
		db	 14h, 05h, 26h, 05h, 3Ah, 05h
		db	 4Dh, 05h, 61h, 05h, 75h, 05h
		db	 89h, 05h, 9Eh, 05h,0B3h, 05h
		db	0C8h, 05h,0DDh, 05h,0F3h, 05h
		db	 09h, 06h, 20h, 06h, 37h, 06h
		db	 4Eh, 06h, 65h, 06h, 7Dh, 06h
		db	 95h, 06h,0AEh, 06h,0C7h, 06h
		db	0E0h, 06h,0FAh, 06h, 14h, 07h
		db	 2Eh, 07h, 49h, 07h, 64h, 07h
		db	 7Fh, 07h, 9Bh, 07h,0B7h, 07h
		db	0D4h, 07h,0F1h, 07h, 0Fh, 08h
		db	 2Dh, 08h, 4Bh, 08h, 6Ah, 08h
		db	 8Ah, 08h,0A9h, 08h,0CAh, 08h
		db	0EAh
		db	8, 0Ch, 9, '-', 9, 'O', 9, 'r', 9
		db	 95h, 09h,0B9h, 09h,0DDh, 09h
		db	 02h, 0Ah, 27h, 0Ah, 4Dh, 0Ah
		db	 73h, 0Ah, 9Ah, 0Ah,0C2h, 0Ah
		db	0EAh, 0Ah, 12h, 0Bh, 3Ch, 0Bh
		db	 65h, 0Bh, 90h, 0Bh,0BBh, 0Bh
		db	0E7h, 0Bh, 13h, 0Ch, 40h, 0Ch
		db	 6Eh, 0Ch, 9Ch, 0Ch,0CBh, 0Ch
		db	0FAh, 0Ch, 2Bh, 0Dh, 5Ch, 0Dh
		db	 8Dh, 0Dh,0C0h, 0Dh,0F3h, 0Dh
		db	 27h, 0Eh, 5Ch, 0Eh, 91h, 0Eh
		db	0C7h, 0Eh,0FFh, 0Eh, 36h, 0Fh
		db	 6Fh, 0Fh,0A8h, 0Fh,0E3h, 0Fh
		db	 1Eh, 10h, 5Ah, 10h, 97h, 10h
		db	0D5h, 10h, 13h, 11h, 53h, 11h
		db	 93h, 11h,0D5h, 11h, 17h, 12h
		db	 5Bh, 12h, 9Fh, 12h,0E4h, 12h
		db	 2Bh, 13h, 72h, 13h,0BAh, 13h
		db	 04h, 14h, 4Eh, 14h, 9Ah, 14h
		db	0E7h, 14h, 35h, 15h, 83h, 15h
		db	0D4h, 15h, 25h, 16h, 77h, 16h
		db	0CBh, 16h, 20h, 17h, 76h, 17h
		db	0CDh, 17h, 26h, 18h, 80h, 18h
		db	0DBh, 18h, 38h, 19h, 96h, 19h
		db	0F5h, 19h, 55h, 1Ah,0B8h, 1Ah
		db	 1Bh, 1Bh, 80h, 1Bh,0E6h, 1Bh
		db	 4Eh, 1Ch,0B8h, 1Ch, 23h, 1Dh
		db	 8Fh, 1Dh,0FDh, 1Dh, 6Dh, 1Eh
		db	0DEh, 1Eh, 50h, 1Fh,0C6h, 1Fh
		db	 3Ch, 20h,0B4h, 20h, 2Eh, 21h
		db	0AAh, 21h, 26h, 22h,0A6h
		db	22h
pbend_value	dw	2000h
		db	0, 0, 0, 0
data_5		db	0               ; also used for pbend
data_6		db	0
data_7		db	0
volume		db	0Fh
sound_on	db	1
ch_volume	db	0
data_11		db	0FFh
reverb		db	0

func_tab	dw	offset dev_info
                dw      offset func_init
                dw      offset func_terminate
                dw      offset fn_dummy
                dw      offset note_off
                dw      offset note_on
                dw      offset fn_dummy
                dw      offset controller
                dw      offset fn_dummy
                dw      offset fn_dummy
                dw      offset fn_pbend
                dw      offset fn_set_reverb
                dw      offset fn_master_vol
                dw      offset fn_sound_on
                dw      offset fn_dummy
                dw      offset fn_dummy
                dw      offset fn_dummy
                dw      offset fn_ask_driver

entry           proc near
                push    dx
                shl     bp,1
                mov     dx,cs:func_tab[bp]
                call    dx
                pop     dx
                retf
fn_dummy:
                ret
entry           endp

note_off        proc near
		cmp	cs:data_7,ch
		jne	loc_ret_5
		call	speaker_off

loc_ret_5:
		retn
note_off        endp

note_on         proc near
		cmp	cs:data_11,al
		je	loc_6
		retn
loc_6:
		cmp	ch,0
		jne	loc_7
		retn
loc_7:
		push	bx
		mov	bl,ch
		xor	bh,bh
		call	speaker_off
		call	speaker_on
		pop	bx
		retn
note_on         endp

controller      proc near
		cmp	ch,MIDI_CONTROL_ALL_NOTES_OFF
		jne	loc_8
		call	speaker_off
		jmp	short loc_ret_12
loc_8:
		cmp	ch,MIDI_CONTROL_DECAY_TIME
		jne	loc_10
		cmp	cl,0
		je	loc_9
		cmp	cs:data_11,al
		je	loc_ret_12
		call	speaker_off
		mov	cs:data_11,al
		jmp	short loc_ret_12
loc_9:
		cmp	cs:data_11,al
		jne	loc_ret_12
		call	speaker_off
		mov	cs:data_11,0FFh
		jmp	short loc_ret_12
loc_10:
		cmp	ch,MIDI_CONTROL_UNKNOWN_4E
		jne	loc_11
		cmp	cl,0FFh
		je	loc_ret_12
		cmp	cs:data_11,al
		jne	loc_ret_12
		push	bx
		mov	bl,cl
		xor	bh,bh
		call	speaker_off
		call	speaker_on
		pop	bx
		jmp	short loc_ret_12
loc_11:
		cmp	ch,MIDI_CONTROL_CH_VOLUME
		jne	loc_ret_12
		mov	cs:ch_volume,1
		cmp	cl,0
		jne	loc_ret_12
		call	speaker_off
		mov	cs:ch_volume,0

loc_ret_12:
		retn
controller      endp

fn_pbend        proc near
		push	ax
		push	bx
		push	cx
		push	dx
		push	cx
		xchg	cl,ch
		shr	ch,1
		jnc	loc_13
		or	cl,80h
loc_13:
		mov	cs:pbend_value,cx
		pop	cx
		cmp	cs:data_11,al
		jne	loc_19
		mov	cs:data_6,0
		mov	ch,cl
		mov	cl,0
		shr	ch,1
		jnc	loc_14
		mov	cl,80h
loc_14:
		cmp	cx,2000h
		jne	loc_15
		mov	cs:data_5,0
		jmp	short loc_18
loc_15:
		jbe	loc_16
		mov	ax,cx
		sub	ax,2000h
		mov	cs:data_6,1
		jmp	short loc_17
loc_16:
		mov	ax,2000h
		sub	ax,cx
loc_17:
		mov	bx,0ABh
		mov	dx,0
		div	bx
		mov	cs:data_5,al
loc_18:
		cmp	cs:data_7,0
		je	loc_19
		mov	bh,0
		mov	bl,cs:data_7
		call	speaker_on
loc_19:
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		retn
fn_pbend        endp

speaker_off	proc	near
		cmp	cs:data_7,0
		je	loc_ret_20
		push	ax
		in	al,61h			; port 61h, 8255 port B, read
		and	al,0FCh
		out	61h,al			; port 61h, 8255 B - spkr, etc
						;  al = 0, speaker off
		pop	ax
		mov	cs:data_7,0

loc_ret_20:
		retn
speaker_off	endp


; bl = note to play
speaker_on	proc	near
		push	bx
		cmp	bl,18h
		jae	loc_21
		jmp	short speaker_on_leave
loc_21:
		cmp	bl,77h			; 'w'
		jbe	loc_22
		jmp	short speaker_on_leave
loc_22:         ; 18h <= bl <= 77h
		mov	cs:data_7,bl
		sub	bl,18h
		shl	bx,1
		shl	bx,1                    ; bx = (bl - 18h) * 4
		cmp	cs:data_5,0
		je	loc_23
		call	apply_pbend
loc_23:
		cmp	bx,0FFFFh
		jne	loc_24
		jmp	short speaker_on_leave
loc_24:
		shl	bx,1
		cmp	cs:volume,0
		je	speaker_on_leave
		cmp	cs:ch_volume,0
		je	speaker_on_leave
		cmp	cs:sound_on,0
		je	speaker_on_leave
		mov	al,0B6h
		out	43h,al			; port 43h, 8253 timer control
		mov	dx,14h
		mov	ax,4F38h
		mov	di,cs:data_3[bx]
		div	di                      ; ax = 1'331'000 / data_3[bx]
		out	42h,al			; port 42h, 8253 timer 2 spkr
		mov	al,ah
		out	42h,al			; port 42h, 8253 timer 2 spkr
		in	al,61h			; port 61h, 8255 port B, read
		or	al,3
		out	61h,al			; port 61h, 8255 B - spkr, etc
						;  al = 4Fh, speaker on
speaker_on_leave:
		pop	bx
		retn
speaker_on	endp

apply_pbend	proc	near
		push	cx
		mov	ch,0
		mov	cl,cs:data_5
		cmp	cs:data_6,0
		je	loc_26
		add	bx,cx
		jmp	short loc_27
loc_26:
		sub	bx,cx
loc_27:
		cmp	bx,24
		jb	loc_28
		cmp	bx,476
		ja	loc_28
		jmp	short loc_29
loc_28:         ; bx < 24 or bx > 476
		mov	bx,0FFFFh
loc_29:
		pop	cx
		retn
apply_pbend	endp

func_terminate  proc near
		call	speaker_off
		retn
func_terminate  endp

fn_master_vol   proc near
		mov	al,cs:volume
		xor	ah,ah
		cmp	al,0
		je	loc_30
		mov	al,1
loc_30:
		cmp	cl,0FFh
		jne	loc_31
		retn
loc_31:
		mov	cs:volume,cl
		cmp	cl,0
		jne	loc_ret_32
		call	speaker_off

loc_ret_32:
		retn
fn_master_vol   endp

fn_set_reverb   proc near
		mov	al,cs:reverb
		xor	ah,ah
		cmp	cl,0FFh
		jne	loc_33
		retn
loc_33:
		mov	cs:reverb,cl
		retn
fn_set_reverb   endp

fn_sound_on     proc near
		mov	al,cs:sound_on
		xor	ah,ah
		cmp	cl,0FFh
		jne	loc_34
		retn
loc_34:
		cmp	cl,0
		jne	loc_35
		mov	cs:sound_on,0
		call	speaker_off
		retn
loc_35:
		mov	cs:sound_on,1
		retn
fn_sound_on     endp

fn_ask_driver   proc near
		cmp	ah,MIDI_PBEND
		jne	loc_36
		mov	ax,cs:pbend_value
		retn
loc_36:
		cmp	ah,MIDI_CONTROL
		jne	loc_38
		cmp	ch,MIDI_CONTROL_DECAY_TIME
		jne	loc_38
		cmp	cl,0FFh
		jne	loc_38
		cmp	al,cs:data_11
		jne	loc_37
		mov	ax,1
		retn
loc_37:
		xor	ax,ax
		retn
loc_38:
		mov	ax,0FFFFh
		retn
fn_ask_driver   endp

func_init       proc near
                mov     ax,offset func_init
                mov     cl,0x0
                mov     ch,0xf
                ret
func_init       endp

dev_info        proc near
                mov     ah,0x1
                mov     al,0xff
                mov     ch,0x12
                mov     cl,0x1
                ret
dev_info        endp

seg_a		ends
		end	start

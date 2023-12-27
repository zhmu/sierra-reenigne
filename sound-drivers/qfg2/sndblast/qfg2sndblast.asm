; vim:set ts=8:

include ../../common/midi.inc
include ../../common/opl.inc
include ../../common/sb.inc

seg_a		segment	byte public
		assume	cs:seg_a, ds:seg_a

		org	0

PBEND_CENTER    equ 2000h

start:
		jmp	entry

		db      00h
                dd      87654321h      ; identifier
                db      01h            ; driver type 1 = sound

		db	 8, 'blastdrv'
		db	18, 'Sound Blaster Card'

data_2		db	0
audio_buffer_index	db	0
data_4		db	0
audio_buffer_1	dw	0, 0
data_7		dw	0
audio_buffer_0	dw	0, 0
data_10		dw	0
sb_prev_irq     dd      0
prev_irq_2	dd      0
prev_irq_3	dd      0
prev_irq_5	dd      0
prev_irq_7      dd      0
data_16		db	0
data_17		dw	0
data_18		dw	0
data_19		db	0
data_20		dw	0
data_21		dw	0
data_22		dw	0
sb_base_io	dw	220h
sb_detected_irq	db	0
data_25		dw	0
		db	0, 0
dsp_time_constant	db	0
data_27		dw	0			; segment storage
data_28		dw	0
data_29		dw	0
pic_prev_imr	db      8 dup (0)               ; previous mask for irq
block_nr	db	96 dup (0)              ; [SQ3ADL]
		db	48 dup (1)
		db	48 dup (2)
		db	48 dup (3)
		db	48 dup (4)
		db	48 dup (5)
		db	48 dup (6)
		db	48 dup (7)
		db	48 dup (8)
		db	29 dup (9)

freq_number 	dw      343, 348, 353, 358, 363, 369, 374       ; [SQ3ADL]
                dw	379, 385, 390, 396, 402, 408, 414
                dw	420, 426, 432, 438, 445, 451, 458
                dw	464, 471, 478, 485, 492, 499, 506
                dw	514, 521, 529, 536, 544, 552, 560
                dw	568, 577, 585, 594, 602, 611, 620
                dw	629, 638, 647, 656, 666, 676, 343
                dw	348, 353, 358, 363, 369, 374, 379
                dw	385, 390, 396, 402, 408, 414, 420
                dw	426, 432, 438, 445, 451, 458, 464
                dw	471, 478, 485, 492, 499, 506, 514
                dw	521, 529, 536, 544, 552, 560, 568
                dw	577, 585, 594, 602, 611, 620, 629
                dw	638, 647, 656, 666, 676, 343, 348
                dw	353, 358, 363, 369, 374, 379, 385
                dw	390, 396, 402, 408, 414, 420, 426
                dw	432, 438, 445, 451, 458, 464, 471
                dw	478, 485, 492, 499, 506, 514, 521
                dw	529, 536, 544, 552, 560, 568, 577
                dw	585, 594, 602, 611, 620, 629, 638
                dw	647, 656, 666, 676, 343, 348, 353
                dw	358, 363, 369, 374, 379, 385, 390
                dw	396, 402, 408, 414, 420, 426, 432
                dw	438, 445, 451, 458, 464, 471, 478
                dw	485, 492, 499, 506, 514, 521, 529
                dw	536, 544, 552, 560, 568, 577, 585
                dw	594, 602, 611, 620, 629, 638, 647
                dw	656, 666, 676, 343, 348, 353, 358
                dw	363, 369, 374, 379, 385, 390, 396
                dw	402, 408, 414, 420, 426, 432, 438
                dw	445, 451, 458, 464, 471, 478, 485
                dw	492, 499, 506, 514, 521, 529, 536
                dw	544, 552, 560, 568, 577, 585, 594
                dw	602, 611, 620, 629, 638, 647, 656
                dw	666, 676, 343, 348, 353, 358, 363
                dw	369, 374, 379, 385, 390, 396, 402
                dw	408, 414, 420, 426, 432, 438, 445
                dw	451, 458, 464, 471, 478, 485, 492
                dw	499, 506, 514, 521, 529, 536, 544
                dw	552, 560, 568, 577, 585, 594, 602
                dw	611, 620, 629, 638, 647, 656, 666
                dw	676, 343, 348, 353, 358, 363, 369
                dw	374, 379, 385, 390, 396, 402, 408
                dw	414, 420, 426, 432, 438, 445, 451
                dw	458, 464, 471, 478, 485, 492, 499
                dw	506, 514, 521, 529, 536, 544, 552
                dw	560, 568, 577, 585, 594, 602, 611
                dw	620, 629, 638, 647, 656, 666, 676
                dw	343, 348, 353, 358, 363, 369, 374
                dw	379, 385, 390, 396, 402, 408, 414
                dw	420, 426, 432, 438, 445, 451, 458
                dw	464, 471, 478, 485, 492, 499, 506
                dw	514, 521, 529, 536, 544, 552, 560
                dw	568, 577, 585, 594, 602, 611, 620
                dw	629, 638, 647, 656, 666, 676, 343
                dw	348, 353, 358, 363, 369, 374, 379
                dw	385, 390, 396, 402, 408, 414, 420
                dw	426, 432, 438, 445, 451, 458, 464
                dw	471, 478, 485, 492, 499, 506, 514
                dw	521, 529, 536, 544, 552, 560, 568
                dw	577, 585, 594, 602, 611, 620, 629
                dw	638, 647, 656, 666, 676, 343, 348
                dw	353, 358, 363, 369, 374, 379, 385
                dw	390, 396, 402, 408, 414, 420, 426
                dw	432, 438, 445, 451, 458, 464, 471
                dw	478, 485, 492, 499, 506, 514, 521
                dw	529, 536, 544, 552, 560, 568, 577
                dw	585, 594, 602, 611, 620, 629, 638
                dw	647, 656, 666, 676, 343, 348, 353
                dw	358, 363, 369, 374, 379, 385, 390
                dw	396, 402, 408, 414, 420, 426, 432
                dw	438, 445, 451, 458, 464, 471, 478
                dw	485, 492, 499, 506, 514

; [SQ3ADL] This could be 'data_70' but less than 1KB?
data_42		db	0			; Data table (indexed access)
		db	 10h, 14h, 18h, 1Fh
		db	'&*./2334556677888999:::::;;;;;<<'
		db	'<<<=====>>>>>>?????????????'
; used in op_2x_4x_6x_8x_e0_map[]
data_44		db	3			; Data table (indexed access)
		db	 04h, 05h, 09h, 0Ah, 0Bh, 0Fh
		db	 10h, 11h
; used in op_2x_4x_6x_8x_e0_map[]
data_45		db	0			; Data table (indexed access)
		db	 01h, 02h, 06h, 07h, 08h, 0Ch
		db	 0Dh, 0Eh

operator_group	db	0, 0, 0     ; 0/1/2  [SQ3ADL]
                db      1, 1, 1     ; 3/4/5
                db      0, 0, 0     ; 6/7/8
		db	1, 1, 1     ; 9/10/11
                db      0, 0, 0     ; 12/13/14
                db      1, 1, 1     ; 15/16/17

op_2x_4x_6x_8x_e0_map	db       0,  1,  2,  3,  4,  5,  8,  9  ; [SQ3ADL]
                        db      10, 11, 12, 13, 16, 17, 18, 19
                        db      20, 21

reg_c0_map	db	0           ;  0 - FM channel 0 [SQ3ADL]
                db      1           ;  1 - FM channel 1
                db      2           ;  2 - FM channel 2
                db      0           ;  3 - FM channel 0
                db      1           ;  4 - FM channel 1
                db      2           ;  5 - FM channel 2
                db      3           ;  6 - FM channel 3
                db      4           ;  7 - FM channel 4
		db	5           ;  8 - FM channel 5
                db      3           ;  9 - FM channel 3
                db      4           ; 10 - FM channel 4
                db      5           ; 11 - FM channel 5
                db      6           ; 12 - FM channel 6
                db      7           ; 13 - FM channel 7
                db      8           ; 14 - FM channel 8
                db      6           ; 15 - FM channel 6
		db	7           ; 16 - FM channel 7
                db      8           ; 17 - FM channel 8

operator_map 	db	 0,  3,  1,  4,  2,  5,  6,  9      ; [SQ3ADL]
                db       7, 10,  8, 11, 12, 15, 13, 16
                db      14, 17

default_operator_0      db       1, 1,  3, 15,  5,  0,  1,  3   ; [SQ3ADL]
                        db      15, 0,  0,  0,  1,  0
default_operator_1      db       0, 1,  1, 15,  7,  0,  2,  4   ; [SQ3ADL]
                        db       0, 0,  0,  1,  0,  0

; [SQ3ADL] data per operator (18*14 bytes)
ksl		db	0
freq_mult	db	0
feedback	db	0
attack_rate	db	0
sustain_level	db	0
sound_sustain	db	0
decay_rate	db	0
release_rate	db	0
output_level	db	0
apply_ampl_mod	db	0
apply_vibrato	db	0
envelope_scaling_ksr 	db	0
synthesis_type	db	0
waveform_select	db	0
                db      238 dup (0)

; [SQ3ADL] this could be data_75 - it's a copy of the patch.xxx data
data_65		db	2688 dup (0)
data_66		db	14 dup (0)
data_67		db	0
is_sound_on	db	1
data_69		db	0Fh                     ;; volume ?
data_70		db	0
data_71		db	0
data_72		db	0
data_73		db	0
data_74		db	0
data_75		dw	0
data_76		dw	0
data_77		db	0
ch_instrument	db	16 dup (0)              ; current patch
ch_volume	db	16 dup (3Fh)		;; maybe volume?
data_80		db	16 dup (0)		; Data table (indexed access)
data_81		db	16 dup (0)
ch_pbend	dw	16 dup (PBEND_CENTER)	; per-channel pitch bend
data_83		db	16 dup (0)
mch_op_map	db	11 dup (0FFh)		;; XXX think this maps the channel
data_86		db	11 dup (0FFh)           ;; XXX this could be cur_note ...
data_87		db	11 dup (0)		; Data table (indexed access)
data_88		db	11 dup (0)
data_89		dw	11 dup (0)
data_90		db      11 dup (0FFh)		; Data table (indexed access)
data_91		dw      11 dup (0)		; Data table (indexed access)
data_92		dw	11 dup (0)
data_93		dw      11 dup (0)
data_94		dw	11 dup (0)
data_95		dw	11 dup (0)
data_96		db	11 dup (0)
data_97		dw	11 dup (0)

func_tab	dw	get_driver_info         ; 0 - info
                dw      fn_init                 ; 1 - init
                dw      sub_31                  ; 2 - terminate
                dw      fn_3                    ; 3 - service
                dw      sub_1                   ; 4 - note off
                dw      fn_5                    ; 5 - note on
		dw      fn_dummy                ; 6 - poly touch
                dw      fn_controller           ; 7 - controller
                dw      fn_pchange              ; 8 - pchange
		dw      fn_dummy                ; 9 - ch after touch
		dw      fn_pbend                ; 10 - pitch bend
		dw      fn_11                   ; 11 - set reverb
		dw      fn_master_vol           ; 12 - master volume
		dw      fn_sound_on             ; 13 - sound on
		dw      fn_14                   ; 14 - play sample
		dw      fn_15                   ; 15 - end sample
		dw      fn_16                   ; 16 - check sample
		dw      fn_17                   ; 17 - driver request

entry           proc far
		push	dx
		shl	bp,1
		mov	dx,cs:func_tab[bp]
		call	dx			;*
		pop	dx
		retf
entry           endp


fn_dummy        proc near
		ret
fn_dummy        endp

sub_1		proc	near
		push	bx
		push	si
		mov	bx,0
loc_2:
		cmp	byte ptr cs:mch_op_map[bx],al
		jne	loc_4
		cmp	cs:data_86[bx],ch
		jne	loc_4
		mov	si,ax
		and	si,0FFh
		cmp	byte ptr cs:data_80[si],0
		je	loc_3
		mov	cs:data_88[bx],1
		jmp	short loc_5
		db	90h
loc_3:
		call	sub_11
		jmp	short loc_5
		db	90h
loc_4:
		inc	bx
		cmp	bx,OPL_NUM_VOICES
		jne	loc_2
loc_5:
		pop	si
		pop	bx
		retn
sub_1		endp

fn_5            proc near
		push	bx
		push	si
		cmp	ch,0Ch
		jb	loc_9
		cmp	ch,6Bh			; 'k'
		ja	loc_9
		cmp	cl,0
		jne	loc_6
		call	sub_1
		jmp	short loc_9
		db	90h
loc_6:
		shr	cl,1
		mov	bx,0
loc_7:
		cmp	byte ptr cs:mch_op_map[bx],al
		jne	loc_8
		cmp	cs:data_86[bx],ch
		jne	loc_8
		mov	cs:data_88[bx],0
		call	sub_11
		call	sub_10
		jmp	short loc_9
		db	90h
loc_8:
		inc	bx
		cmp	bx,OPL_NUM_VOICES
		jne	loc_7
		call	sub_3
		cmp	bx,0ffh ;; TODO does this make sense
		je	loc_9
		call	sub_10
loc_9:
		pop	si
		pop	bx
		retn
fn_5            endp

fn_controller   proc near
		push	bx
		cmp	ch,MIDI_CONTROL_CH_VOLUME
		jne	loc_10
		call	midi_ctrl_ch_vol
		jmp	short loc_15
		db	90h
loc_10:
		cmp	ch,MIDI_CONTROL_DAMPER_PEDAL_ON_OFF
		jne	loc_11
		call	midi_ctrl_dam_dep
		jmp	short loc_15
		db	90h
loc_11:
		cmp	ch,MIDI_CONTROL_DECAY_TIME
		jne	loc_12
		call	midi_ctrl_decay_time
		jmp	short loc_15
		db	90h
loc_12:
		cmp	ch,MIDI_CONTROL_ALL_NOTES_OFF
		jne	loc_15
		mov	bx,0
loc_13:
		cmp	byte ptr cs:mch_op_map[bx],al
		jne	loc_14
		cmp	cs:data_86[bx],0FFh
		je	loc_14

                ; data_86[bx] != 0FFh
		call	sub_11
loc_14:
		inc	bx
		cmp	bx,OPL_NUM_VOICES
		jne	loc_13
loc_15:
		pop	bx
		retn
fn_controller   endp

fn_pchange	proc	near
		push	ax
		push	si
		xor	ah,ah
		mov	si,ax
		mov	cs:ch_instrument[si],cl
		pop	si
		pop	ax
		retn
fn_pchange	endp

fn_pbend        proc near
		push	bx
		push	cx
		mov	bx,ax
		xor	bh,bh
		shl	bx,1
		xchg	cl,ch
		shr	ch,1
		jnc	loc_16
		or	cl,80h
loc_16:
		mov	cs:ch_pbend[bx],cx

                ; for bx in 0..8
		xor	bx,bx
loc_17:
		cmp	byte ptr cs:mch_op_map[bx],al
		jne	loc_18
		mov	cl,cs:data_86[bx]
		mov	dx,1
		call	sub_12
loc_18:
		inc	bx
		cmp	bx,OPL_NUM_VOICES
		jne	loc_17

		pop	cx
		pop	bx
		retn
fn_pbend        endp

fn_sound_on     proc near
		cmp	cl,0FFh
		jne	loc_19
                ; 0FFh used to return sound_on status
		mov	al,cs:is_sound_on
		xor	ah,ah
		retn
loc_19:
		mov	cs:is_sound_on,0
		cmp	cl,0
		jne	loc_20
		retn
loc_20:
		mov	cs:is_sound_on,1
		retn
fn_sound_on     endp

fn_master_vol   proc near
		push	bx
		push	dx
		cmp	cl,0FFh
		jne	loc_22
		mov	al,cs:data_69
		xor	ah,ah
		cmp	al,0Fh
		jbe	loc_21
		int	18h			; ROM basic
loc_21:
		jmp	short loc_25
		db	90h
loc_22:
		mov	cs:data_69,cl
		mov	bx,0
loc_23:
		mov	cl,cs:data_86[bx]
		cmp	cl,0FFh
		je	loc_24
		mov	dx,1
		call	sub_12
loc_24:
		inc	bx
		cmp	bx,OPL_NUM_VOICES
		jne	loc_23
loc_25:
		pop	dx
		pop	bx
		retn
fn_master_vol   endp

fn_11           proc near
		cmp	cl,0FFh
		jne	loc_26
		mov	al,cs:data_67
		xor	ah,ah
		retn
loc_26:
		mov	cs:data_67,cl
		retn
fn_11           endp

sub_3		proc	near
		push	cx
		push	dx
		push	si
		xor	dx,dx
		mov	si,ax
		and	si,0FFh
		mov	bl,cs:data_83[si]
		xor	bh,bh
		xor	ch,ch
loc_27:
		inc	bl
		cmp	bl,OPL_NUM_VOICES
		jne	loc_28
		xor	bl,bl
loc_28:
		cmp	bl,cs:data_83[si]
		jne	loc_29
		mov	ch,1
loc_29:
		cmp	byte ptr cs:mch_op_map[bx],al
		jne	loc_31
		cmp	cs:data_86[bx],0FFh
		je	loc_32
		shl	bx,1
		cmp	cs:data_89[bx],dx
		jb	loc_30
		mov	dx,cs:data_89[bx]
		mov	cl,bl
		shr	cl,1
loc_30:
		shr	bx,1
loc_31:
		cmp	ch,0
		je	loc_27
		mov	bx,0ffh ; TODO does this make sense
		cmp	dx,0
		je	loc_33
		xor	ch,ch
		mov	bx,cx
		mov	cs:data_88[bx],0
		call	sub_11
loc_32:
		mov	cs:data_83[si],bl
loc_33:
		pop	si
		pop	dx
		pop	cx
		retn
sub_3		endp


midi_ctrl_decay_time proc	near
		push	si
		push	cx
		push	dx
		xor	si,si
		xor	dx,dx
loc_34:
		cmp	byte ptr cs:mch_op_map[si],al
		jne	loc_35
		inc	dl
loc_35:
		inc	si
		cmp	si,OPL_NUM_VOICES
		jne	loc_34

		mov	si,ax
		and	si,0FFh
		add	dl,cs:data_81[si]
		cmp	dl,cl
		je	loc_37
		ja	loc_36
		sub	cl,dl
		call	sub_6
		jmp	short loc_37
		db	90h
loc_36:
		sub	dl,cl
		mov	cl,dl
		call	sub_7
		call	sub_5
loc_37:
		pop	dx
		pop	cx
		pop	si
		retn
midi_ctrl_decay_time endp

sub_5		proc	near
		push	ax
		push	cx
		push	si
		xor	cl,cl
		xor	si,si
loc_38:
		cmp	byte ptr cs:mch_op_map[si],0FFh
		jne	loc_39
		inc	cl
loc_39:
		inc	si
		cmp	si,OPL_NUM_VOICES
		jne	loc_38

		cmp	cl,0
		je	loc_43
		xor	si,si
loc_40:
		mov	ch,cs:data_81[si]
		cmp	ch,0
		je	loc_42
		cmp	ch,cl
		jae	loc_41
		sub	cl,ch
		push	cx
		mov	cl,ch
		mov	cs:data_81[si],0
		mov	ax,si
		call	sub_6
		pop	cx
		jmp	short loc_42
		db	90h
loc_41:
		sub	ch,cl
		mov	cs:data_81[si],ch
		mov	ax,si
		call	sub_6
		jmp	short loc_43
		db	90h
loc_42:
		inc	si
		cmp	si,10h
		jne	loc_40
loc_43:
		pop	si
		pop	cx
		pop	ax
		retn
sub_5		endp


sub_6		proc	near
		push	cx
		push	bx
		push	si
		xor	bx,bx
loc_44:
		cmp	byte ptr cs:mch_op_map[bx],0FFh
		jne	loc_46
		mov	byte ptr cs:mch_op_map[bx],al
		cmp	cs:data_86[bx],0FFh
		je	loc_45
		call	sub_11
loc_45:
		dec	cl
		cmp	cl,0
		je	loc_47
loc_46:
		inc	bx
		cmp	bx,OPL_NUM_VOICES
		jne	loc_44
loc_47:
		mov	si,ax
		and	si,0FFh
		add	cs:data_81[si],cl
		mov	cl,cs:ch_instrument[si]
		call	fn_pchange
		pop	si
		pop	bx
		pop	cx
		retn
sub_6		endp


sub_7		proc	near
		push	bx
		push	cx
		push	si
		mov	si,ax
		and	si,0FFh
		cmp	cs:data_81[si],cl
		jne	loc_48
		mov	cs:data_81[si],0
		jmp	short loc_54
		db	90h
loc_48:
		jc	loc_49
		sub	cs:data_81[si],cl
		jmp	short loc_54
		db	90h
loc_49:
		sub	cl,cs:data_81[si]
		mov	cs:data_81[si],0
		xor	bx,bx
loc_50:
		cmp	byte ptr cs:mch_op_map[bx],al
		jne	loc_51
		cmp	cs:data_86[bx],0FFh
		jne	loc_51
		mov	byte ptr cs:mch_op_map[bx],0FFh
		dec	cl
		cmp	cl,0
		je	loc_54
loc_51:
		inc	bx
		cmp	bx,OPL_NUM_VOICES
		jne	loc_50
		xor	bx,bx
loc_52:
		cmp	byte ptr cs:mch_op_map[bx],al
		jne	loc_53
		mov	cs:data_88[bx],0
		call	sub_11
		mov	byte ptr cs:mch_op_map[bx],0FFh
		dec	cl
		cmp	cl,0
		je	loc_54
loc_53:
		inc	bx
		cmp	bx,OPL_NUM_VOICES
		jne	loc_52
loc_54:
		pop	si
		pop	cx
		pop	bx
		retn
sub_7		endp

midi_ctrl_ch_vol proc	near
		push	bx
		push	cx
		push	dx
		push	si
		push	di
		shr	cl,1
		mov	si,ax
		and	si,0FFh
		mov	di,cx
		and	di,0FFh
		mov	cl,cs:data_42[di]
		mov	byte ptr cs:ch_volume[si],cl
		mov	si,0
loc_55:
		cmp	byte ptr cs:mch_op_map[si],al
		jne	loc_56
		cmp	cs:data_86[si],0FFh
		je	loc_56
		mov	cl,cs:data_86[si]
		mov	ch,0
		mov	bx,si
		mov	dx,1
		call	sub_12
loc_56:
		inc	si
		cmp	si,OPL_NUM_VOICES
		jne	loc_55
		pop	di
		pop	si
		pop	dx
		pop	cx
		pop	bx
		retn
midi_ctrl_ch_vol endp

midi_ctrl_dam_dep proc	near
		push	bx
		push	si
		mov	si,ax
		and	si,0FFh
		mov	byte ptr cs:data_80[si],cl
		cmp	cl,0
		jne	loc_59
		mov	bx,0
loc_57:
		cmp	byte ptr cs:mch_op_map[bx],al
		jne	loc_58
		cmp	cs:data_88[bx],0
		je	loc_58
		mov	cs:data_88[bx],0
		call	sub_11
loc_58:
		inc	bx
		cmp	bx,OPL_NUM_VOICES
		jne	loc_57
loc_59:
		pop	si
		pop	bx
		retn
midi_ctrl_dam_dep endp

sub_10		proc	near
		push	cx
		push	dx
		push	di
		push	si
		shl	bx,1
		mov	cs:data_89[bx],0
		shr	bx,1
		mov	dl,byte ptr cs:mch_op_map[bx]
		xor	dh,dh
		mov	si,dx
		mov	dl,cs:ch_instrument[si]
		cmp	dl,byte ptr cs:data_90[bx]
		je	loc_60
		cmp	cs:is_sound_on,0
		je	loc_60
		push	cx
		mov	byte ptr cs:data_90[bx],dl
		mov	cl,dl
		push	bx
		mov	bh,0
		mov	bl,cl
		mov	dl,cl
		call	sub_14
		mov	di,bx
		pop	bx
		lea	cx,[813h][di]
		call	sub_15
		pop	cx
loc_60:
		mov	byte ptr cs:data_87[bx],cl
		mov	cl,ch
		mov	dx,1
		call	sub_12
		pop	si
		pop	di
		pop	dx
		pop	cx
		retn
sub_10		endp

sub_11		proc	near
		push	cx
		push	dx
		push	si

		cmp	cs:data_88[bx],0
		jne	loc_61

                ; data_88[bx] == 0
		mov	ch,0
		mov	cl,cs:data_86[bx]
		mov	dx,0
		call	sub_12
		mov	cs:data_86[bx],0FFh
		shl	bx,1
		mov	cs:data_89[bx],0
		shr	bx,1
loc_61:
		pop	si
		pop	dx
		pop	cx
		retn
sub_11		endp

fn_3            proc near
                push    si
                mov     si,0
loc_62:
		cmp	cs:data_86[si],0FFh
		je	loc_63
		shl	si,1
		inc	cs:data_89[si]
		shr	si,1
loc_63:
		inc	si
		cmp	si,OPL_NUM_VOICES
		jne	loc_62
		pop	si
		retn
fn_3            endp

; [SQ3ADL] very similar to sub_35 in spirit ... ?
; bx = channel, dx = flag (0, 1), cl = data, ch = data
sub_12		proc	near
		push	ax
		push	si
		mov	cs:data_76,bx
		mov	cs:data_86[bx],cl
		push	di
		push	cx
		push	bx
		push	dx
		mov	ch,0
		mov	di,cx
		shl	di,1
		shl	di,1
		call	sub_13
		cmp	di,0FFFFh
		je	sub_12_leave

		mov	si,di
		shl	di,1
		mov	dx,cs:freq_number[di]
		mov	cl,dl
		add	bx,OPL_FREQ_NUMBER
		call	write_reg

		pop	dx
		pop	bx
		push	bx
		push	dx
		add	bx,OPL_KEYON_BLOCKNR_FNUM

		mov	ah,0
		mov	al,dl
		shl	al,1
		shl	al,1
		shl	al,1
		mov	ch,0
		mov	dh,0
		mov	dl,cs:block_nr[si]
		or	al,dl
		shl	al,1
		shl	al,1
		mov	dx,cs:freq_number[di]
		mov	cl,8
		shr	dx,cl
		or	ax,dx
		mov	cx,ax
		call	write_reg

                ; [SQ3ADL] This stuff below isn't part of SQ3
		push	bx
		push	dx
		push	cx
		mov	bx,cs:data_76
		push	ax
		push	si
		mov	al,byte ptr cs:mch_op_map[bx]
		xor	ah,ah
		mov	si,ax
		mov	al,byte ptr cs:ch_volume[si]
		inc	al

		mov	cl,byte ptr cs:data_87[bx]
		push	di
		mov	di,cx
		and	di,0FFh
		mov	cl,cs:data_42[di]
		pop	di
		inc	cl
		xor	ah,ah
		mul	cl

		mov	cl,6
		shr	ax,cl
		mov	cl,cs:data_69
		inc	cl
		mul	cl
		mov	cl,4
		shr	ax,cl
		dec	al
		cmp	al,3Fh			; '?'
		jbe	loc_65
		mov	al,0
loc_65:
		cmp	cs:is_sound_on,0
		jne	loc_66
		xor	al,al
loc_66:
		mov	cs:data_77,al
		shl	bx,1
		mov	cx,cs:data_92[bx]
		mul	cl
		mov	cl,3Fh			; '?'
		div	cl
		mov	cl,3Fh			; '?'
		sub	cl,al
		mov	ax,word ptr cs:data_91[bx]
		shr	bx,1
		mov	ch,al
		shl	ch,1
		shl	ch,1
		shl	ch,1
		shl	ch,1
		shl	ch,1
		shl	ch,1
		or	cl,ch
		xor	ch,ch
		push	bx
		mov	dl,cs:data_44[bx]
		mov	bl,dl
		mov	dl,cs:op_2x_4x_6x_8x_e0_map[bx]
		mov	bl,dl
		xor	bh,bh
		add	bx,OPL_KEYSCALE_OUTPUT_LEVEL
		call	write_reg
		pop	bx
		cmp	cs:data_96[bx],0
		je	loc_67
		mov	al,cs:data_77
		shl	bx,1
		mov	cx,cs:data_95[bx]
		mul	cl
		mov	cl,3Fh			; '?'
		div	cl
		mov	cl,3Fh			; '?'
		sub	cl,al
		mov	ax,cs:data_94[bx]
		shr	bx,1
		mov	ch,al
		shl	ch,1
		shl	ch,1
		shl	ch,1
		shl	ch,1
		shl	ch,1
		shl	ch,1
		or	cl,ch
		xor	ch,ch
		mov	dl,cs:data_45[bx]
		mov	bl,dl
		mov	dl,cs:op_2x_4x_6x_8x_e0_map[bx]
		mov	bl,dl
		xor	bh,bh
		add	bx,OPL_KEYSCALE_OUTPUT_LEVEL
		call	write_reg
loc_67:
		pop	si
		pop	ax
		pop	cx
		pop	dx
		pop	bx
sub_12_leave:
		pop	dx
		pop	bx
		pop	cx
		pop	di
		pop	si
		pop	ax
		retn
sub_12		endp


; input: bx = ???
; on return, di = updated pbend value (or 0FFFFh)
sub_13		proc	near
		push	ax
		push	bx
		push	cx
		push	dx
		push	si
		mov	al,byte ptr cs:mch_op_map[bx]
		xor	ah,ah
		mov	si,ax
		shl	si,1
		mov	cx,cs:ch_pbend[si]
		cmp	cx,PBEND_CENTER
		jne	loc_69
		xor	al,al
		xor	dl,dl
loc_69:
		cmp	cx,PBEND_CENTER
		jb	loc_70

                ; cx > PBEND_CENTER
		mov	ax,cx
		sub	ax,PBEND_CENTER     ; ax = cx - PBEND_CENTER
		mov	dl,1                ; dir = +1
		jmp	short loc_71
		db	90h
loc_70:
                ; cx < PBEND_CENTER
		mov	ax,PBEND_CENTER
		sub	ax,cx               ; ax = PBEND_CENTER - cx
		mov	dl,0FFh             ; dir = -1
loc_71:
		push	dx
		mov	bx,0ABh
		mov	dx,0
		div	bx                  ; ax = ax / 0ABh
		pop	dx
		xor	ch,ch
		mov	cl,al

		cmp	dl,1
		jne	loc_72

                ; dl = 1 -> add
		add	di,cx
		jmp	short loc_73
		db	90h
loc_72:         ; dl = -1 -> sub
		sub	di,cx
loc_73:
		cmp	di,1FCh
		jb	loc_74
		mov	di,0FFFFh
loc_74:
		pop	si
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		retn
sub_13		endp

sub_14		proc	near
		push	cx
		push	ax
		mov	cl,2
		shl	bx,cl
		mov	ax,bx
		shl	bx,1
		mov	cx,bx
		shl	bx,1
		add	bx,ax
		add	bx,cx
		pop	ax
		pop	cx
		retn
sub_14		endp

sub_15		proc	near
		push	ax
		push	bx
		push	cx
		push	dx
		push	si
		push	di
		mov	di,cx
		push	bx
		push	cx
		push	dx
		mov	cs:data_96[bx],1
		cmp	byte ptr cs:[di+0Ch],0
		je	loc_75
		mov	cs:data_96[bx],0
		jmp	short loc_76
loc_75:
		shl	bx,1
		mov	ah,0
		mov	al,cs:[di]
		mov	cs:data_94[bx],ax
		mov	al,3Fh			; '?'
		mov	ah,cs:[di+8]
		sub	al,ah
		mov	ah,0
		mov	cs:data_95[bx],ax
		mov	dx,0
		mov	cx,0Fh
		div	cx
		mov	cs:data_97[bx],ax
		jmp	short loc_77
loc_76:
		shl	bx,1
loc_77:
		mov	ah,0
		mov	al,cs:[di+0Dh]
		mov	word ptr cs:data_91[bx],ax
		mov	al,3Fh			; '?'
		mov	ah,cs:[di+15h]
		sub	al,ah
		mov	ah,0
		mov	cs:data_92[bx],ax
		mov	dx,0
		mov	cx,0Fh
		div	cx
		mov	cs:data_93[bx],ax
		pop	dx
		pop	cx
		pop	bx
		add	di,1Ah
		mov	al,cs:[di]
		inc	di
		xor	dh,dh
		mov	dl,cs:[di]
		mov	si,cx
		add	si,0Dh
		shl	bx,1
		mov	di,bx
		mov	bh,0
		mov	bl,cs:operator_map[di]
		push	dx
		mov	dx,ax
		call	sub_22
		pop	dx
		inc	di
		mov	bh,0
		mov	bl,cs:operator_map[di]
		mov	cx,si
		call	sub_22
		pop	di
		pop	si
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		retn
sub_15		endp


; bx = channel
opl_reset_freq	proc	near
		push	cx
		push	bx
		mov	cx,0
		add	bx,OPL_FREQ_NUMBER
		call	write_reg
		pop	bx
		push	bx
		add	bx,OPL_KEYON_BLOCKNR_FNUM
		call	write_reg
		pop	bx
		pop	cx
		retn
opl_reset_freq	endp

; opl2: write value [cl] into register [bl]
write_reg	proc	near
		push	ax
		push	dx
		mov	dx,388h
		mov	ax,bx
		out	dx,al
                repeat 6
                    in  al,dx
                endm
		inc	dx
		mov	ax,cx
		out	dx,al
		dec	dx
                repeat 37
                    in  al,dx
                endm
                pop     dx
                pop     ax
                ret
write_reg	endp

sub_18          proc near
		push	bx
		push	cx
		push	dx
		push	di
		mov	cs:data_73,bl
		mov	cs:data_74,0
		mov	di,0
loc_78:
		mov	bx,di
		mov	dx,0
		cmp	cs:operator_group[di],0
		je	loc_79

		lea	cx,ds:[default_operator_1]
		call	sub_21
		jmp	short loc_80
		db	90h
loc_79:
		lea	cx,ds:[default_operator_0]
		call	sub_21
loc_80:
		inc	di
		cmp	di,12h
		jne	loc_78
		call	sub_20
		pop	di
		pop	dx
		pop	cx
		pop	bx
		retn
sub_18  	endp

sub_19		proc	near
		push	bx
		push	di
		cmp	bx,0
		jne	loc_81
		mov	cs:data_75,0
		jmp	short loc_82
		db	90h
loc_81:
		mov	cs:data_75,20h
loc_82:
		mov	di,0
loc_83:
		mov	bh,0
		mov	bl,cs:op_2x_4x_6x_8x_e0_map[di]
		add	bx,OPL_WAVEFORM_SELECT
		mov	cx,0
		call	write_reg
		inc	di
		cmp	di,12h
		jne	loc_83

		mov	bx,OPL_TEST_WAVEFORM_SEL_ENABLE
		mov	cx,cs:data_75
		call	write_reg
		pop	di
		pop	bx
		retn
sub_19		endp

sub_20		proc	near
		push	bx
		push	cx
		mov	cx,0
		cmp	cs:data_71,0
		je	loc_84
		or	cl,80h
loc_84:
		cmp	cs:data_72,0
		je	loc_85
		or	cl,40h			; '@'
loc_85:
		or	cl,cs:data_74
		mov	bx,OPL_TRDEPTH_VIBDEPTH_PM
		call	write_reg
		pop	cx
		pop	bx
		retn
sub_20		endp

sub_21		proc	near
		push	bx
		push	cx
		push	dx
		push	di
		push	si
		mov	di,0
		mov	si,cx
		mov	ch,0
loc_86:
		mov	cl,cs:[si]
		mov	cs:data_66[di],cl
		inc	si
		inc	di
		cmp	di,0Dh
		jne	loc_86
		pop	si

		lea	cx,ds:[data_66] ; 1293
		call	sub_22
		pop	di
		pop	dx
		pop	cx
		pop	bx
		retn
sub_21		endp

sub_22		proc	near
		push	cx
		push	dx
		push	si
		push	di
		mov	si,bx

                opl_mult_by_14 si

		push	dx
		mov	di,0
loc_87:
		push	di
		mov	di,cx
		mov	dl,cs:[di]
		mov	cs:ksl[si],dl
		pop	di
		inc	si
		inc	cx
		inc	di
		cmp	di,0Dh
		jne	loc_87
		pop	dx
		and	dl,3
		mov	cs:ksl[si],dl
		push	bx
		call	sub_23
		pop	bx
		pop	di
		pop	si
		pop	dx
		pop	cx
		retn
sub_22		endp

sub_23		proc	near
		call	sub_20
		call	sub_25
		call	sub_24
		call	sub_26
		call	sub_27
		call	opl_set_sustain_release
		call	opl_set_flags
		call	opl_set_waveform
		retn
sub_23		endp

sub_24		proc	near
		push	ax
		push	bx
		push	cx
		push	di
		mov	di,bx

                opl_mult_by_14 di

		mov	ah,0
		mov	al,cs:ksl[di]
		mov	cl,6
		shl	al,cl
		mov	cx,ax
		mov	al,cs:output_level[di]
		and	al,3Fh			; '?'
		or	cl,al
		mov	bh,0
		mov	di,bx
		mov	bl,cs:op_2x_4x_6x_8x_e0_map[di]
		add	bl,OPL_KEYSCALE_OUTPUT_LEVEL
		call	write_reg
		pop	di
		pop	cx
		pop	bx
		pop	ax
		retn
sub_24		endp

sub_25		proc	near
		push	bx
		push	cx
		mov	cx,0
		cmp	cs:data_70,0
		je	loc_88
		mov	cl,OPL_KEYSCALE_OUTPUT_LEVEL
loc_88:
		mov	bx,OPL_CSW_NOTESEL
		call	write_reg
		pop	cx
		pop	bx
		retn
sub_25		endp

sub_26		proc	near
		push	bx
		push	cx
		push	di
		mov	di,bx
		cmp	cs:operator_group[di],0
		jne	loc_90

                opl_mult_by_14 di

		mov	ah,0
		mov	al,cs:feedback[di]
		shl	ax,1
		mov	cx,ax
		cmp	cs:synthesis_type[di],0
		jne	loc_89
		inc	cl
loc_89:
		mov	di,bx
		mov	bh,0
		mov	bl,cs:reg_c0_map[di]
		add	bl,OPL_FEEDBACK_SYNTHESIS
		and	cl,0Fh
		call	write_reg
loc_90:
		pop	di
		pop	cx
		pop	bx
		retn
sub_26		endp

sub_27		proc	near
		push	bx
		push	cx
		push	di
		mov	di,bx

                opl_mult_by_14 di

		mov	ah,0
		mov	al,cs:attack_rate[di]
		mov	cl,4
		shl	al,cl
		mov	cx,ax
		mov	al,cs:decay_rate[di]
		and	al,0Fh
		or	cl,al
		mov	di,bx
		mov	bh,0
		mov	bl,cs:op_2x_4x_6x_8x_e0_map[di]
		add	bl,OPL_ATTACK_DECAY_RATE
		call	write_reg
		pop	di
		pop	cx
		pop	bx
		retn
sub_27		endp

opl_set_sustain_release	proc	near
		push	bx
		push	cx
		push	di
		mov	di,bx

                opl_mult_by_14 di

		mov	ah,0
		mov	al,cs:sustain_level[di]
		mov	cl,4
		shl	al,cl
		mov	cx,ax
		mov	al,cs:release_rate[di]
		and	al,0Fh
		or	cl,al
		mov	di,bx
		mov	bh,0
		mov	bl,cs:op_2x_4x_6x_8x_e0_map[di]
		add	bl,OPL_SUSTAIN_RELEASE_RATE
		call	write_reg
		pop	di
		pop	cx
		pop	bx
		retn
opl_set_sustain_release	endp

opl_set_flags	proc	near
		push	cx
		push	di
		mov	di,bx

                opl_mult_by_14 di

		mov	ah,0
		mov	al,cs:apply_ampl_mod[di]
		mov	cx,0
		cmp	al,0
		je	loc_91
		or	cl,80h
loc_91:
		mov	al,cs:apply_vibrato[di]
		cmp	al,0
		je	loc_92
		or	cl,40h			; '@'
loc_92:
		mov	al,cs:sound_sustain[di]
		cmp	al,0
		je	loc_93
		or	cl,20h			; ' '
loc_93:
		mov	al,cs:envelope_scaling_ksr[di]
		cmp	al,0
		je	loc_94
		or	cl,10h
loc_94:
		mov	al,cs:freq_mult[di]
		and	al,0Fh
		or	cl,al
		push	bx
		mov	di,bx
		mov	bh,0
		mov	bl,cs:op_2x_4x_6x_8x_e0_map[di]
		add	bl,OPL_TR_VIB_SUS_KSR_FREQ
		call	write_reg
		pop	bx
		pop	di
		pop	cx
		retn
opl_set_flags	endp

opl_set_waveform proc	near
		push	bx
		push	cx
		push	di
		cmp	cs:data_75,0
		je	loc_95
		xor	bh,bh
		mov	di,bx

                opl_mult_by_14 di

		xor	ch,ch
		mov	cl,cs:waveform_select[di]
		mov	di,bx
		mov	bl,cs:op_2x_4x_6x_8x_e0_map[di]
		add	bl,OPL_WAVEFORM_SELECT
		call	write_reg
loc_95:
		pop	di
		pop	cx
		pop	bx
		retn
opl_set_waveform endp
; 
sub_31		proc	near
		push	bx
		push	cx
		push	dx
		mov	bx,OPL_TEST_WAVEFORM_SEL_ENABLE
		mov	cx,0
		call	write_reg
		mov	bx,0
		call	sub_18
		mov	bx,0
		mov	cx,0
		mov	dx,0
		mov	cs:data_71,bl
		mov	cs:data_72,cl
		mov	cs:data_70,dl
		call	sub_20
		call	sub_25
		mov	bx,0
loc_96:
		call	opl_reset_freq
		inc	bx
		cmp	bx,OPL_NUM_VOICES
		jne	loc_96

		mov	bx,1
		call	sub_19
		pop	bx
		pop	cx
		pop	dx
		retn
sub_31		endp

fn_14           proc near
		cmp	cl,0
		jne	loc_97
		retn
loc_97:         ; cl != 0
		cmp	cs:data_69,0
		jne	loc_98
		retn
loc_98:         ; data_69 != 0
		cmp	cs:is_sound_on,0
		jne	loc_99
		retn
loc_99:         ; is_sound_on != 0
		push	bx
		push	cx
		push	dx
		mov	cs:audio_buffer_index,ch
		mov	cs:data_4,0
		mov	bx,ax
loc_100:
		inc	bx
		cmp	byte ptr [bx],0FEh
		je	loc_100
		inc	bx
		mov	cx,[bx]
		cmp	cx,0F34h
		jae	loc_101
		mov	cs:dsp_time_constant,0
		jmp	short loc_102
		db	90h
loc_101:
		mov	dx,0Fh
		mov	ax,4240h
		div	cx                  ; dx:ax = 1'000'000
		xor	ah,ah
		sub	ah,al
		mov	cs:dsp_time_constant,ah
loc_102:
		mov	ax,[bx+2]
		mov	cx,ds
		mov	word ptr cs:audio_buffer_1+2,cx
		mov	word ptr cs:audio_buffer_0+2,cx
		mov	cx,bx
		add	cx,[bx+4]
		mov	dx,cx
		add	cx,8
		mov	cs:audio_buffer_1,cx
		mov	cx,bx
		add	cx,[bx+6]
		add	cx,8
		mov	cs:audio_buffer_0,cx
		sub	cx,8
		sub	cx,dx
		mov	cs:data_7,cx
		mov	cx,ax
		sub	cx,[bx+6]
		mov	cs:data_10,cx
		sub	ax,cx
		mov	cs:data_29,ax
		add	bx,8
		mov	cs:data_27,ds
		mov	cs:data_28,bx
		mov	cs:data_2,1
		pop	dx
		pop	cx
		pop	bx
		retn
fn_14           endp

fn_15           proc near
		mov	cs:audio_buffer_index,0
		mov	cs:data_4,1
		call	sub_50
		mov	cs:data_2,0
		retn
fn_15           endp

fn_16           proc near
		mov	cs:audio_buffer_index,ch
		cmp	cs:data_2,1
		jne	loc_103
		call	sub_49
loc_103:
		xor	al,al
		cmp	cs:data_25,0
		jne	loc_ret_104
		mov	al,1

loc_ret_104:
		retn
fn_16           endp

; write tos DSP; expects 'dx = [sb_base_io + DSP_PORT_WRBUF_R]
; returns cf=0, al=value on success
dsp_write_timeout proc	near
		mov	cx,200h
		mov	ah,al

locloop_105:
		in	al,dx			; port 22Ch ??I/O Non-standard
		or	al,al
		jns	loc_106
		loop	locloop_105

		stc
		jmp	short loc_ret_107
loc_106:
		mov	al,ah
		out	dx,al			; port 22Ch ??I/O Non-standard
		clc

loc_ret_107:
		retn
dsp_write_timeout endp

dsp_read_with_timeout proc	near
		push	dx
		mov	dx,cs:sb_base_io
		add	dl,0Eh
		mov	cx,200h

locloop_108:
		in	al,dx			; port 22Eh ??I/O Non-standard
		or	al,al
		js	loc_109
		loop	locloop_108

		stc
		jmp	short loc_110
loc_109:
		sub	dl,4
		in	al,dx			; port 22Ah ??I/O Non-standard
		clc
loc_110:
		pop	dx
		retn
dsp_read_with_timeout endp

; writes to the DSP; expects dx = [sb_base_io + DSP_PORT_WRBUF_R]
dsp_write	proc	near
		push	cx
		mov	cx,3E8h
		mov	ah,al

locloop_111:
		in	al,dx			; port 22Ch ??I/O Non-standard
		or	al,al
		jns	loc_112
		loop	locloop_111

loc_112:
		mov	al,ah
		out	dx,al			; port 22Ch ??I/O Non-standard
		pop	cx
		retn
dsp_write	endp

dsp_read	proc	near
		push	dx
		mov	dx,cs:sb_base_io
		add	dl,DSP_PORT_RDBUF_R
		xor	al,al
loc_113:
		in	al,dx			; port 22Eh ??I/O Non-standard
		or	al,al
		jns	loc_113
		sub	dl,4
		in	al,dx			; port 22Ah ??I/O Non-standard
		pop	dx
		retn
dsp_read	endp

dsp_reset	proc	near
		mov	dx,cs:sb_base_io
		add	dl,DSP_PORT_RESET_W
		mov	al,1
		out	dx,al			; port 226h ??I/O Non-standard
                repeat 8
                    in al,dx
                endm
		xor	al,al
		out	dx,al			; port 226h ??I/O Non-standard
		mov	cl,20h			; ' '
loc_114:
		call	dsp_read_with_timeout
		cmp	al,0AAh
		je	loc_115
		dec	cl
		jnz	loc_114
		mov	ax,2
		jmp	short loc_116
loc_115:
		xor	ax,ax
loc_116:
		or	ax,ax
		retn
dsp_reset	endp

dsp_sanity_check proc	near
		mov	bx,2
		mov	al,DSP_CMD_ECHO_INVERTED
		mov	dx,cs:sb_base_io
		add	dx,DSP_PORT_WRBUF_R
		call	dsp_write_timeout
		jc	loc_117
		mov	al,0AAh
		call	dsp_write_timeout
		jc	loc_117
		call	dsp_read_with_timeout
		jc	loc_117
		cmp	al,55h			; 'U'
		jne	loc_117
		xor	bx,bx
loc_117:
		mov	ax,bx
		or	ax,ax
		retn
dsp_sanity_check endp

sb_detect_irq	proc	near
		mov	al,2
		mov	dx,offset irq_detect_2
		mov	bx,offset prev_irq_2
		call	hook_irq
		mov	al,3
		mov	dx,offset irq_detect_3
		mov	bx,offset prev_irq_3
		call	hook_irq
		mov	al,5
		mov	dx,offset irq_detect_5
		mov	bx,offset prev_irq_5
		call	hook_irq
		mov	al,7
		mov	dx,offset irq_detect_7
		mov	bx,offset prev_irq_7
		call	hook_irq
		mov	dx,cs
		mov	ax,offset sb_detect_irq
		call	sub_42
		xor	cx,cx
		mov	dh,49h			; 'I'
		call	sub_41
		mov	dx,cs:sb_base_io
		add	dx,DSP_PORT_WRBUF_R
		mov	al,DSP_CMD_SET_TIME_CONSTANT
		call	dsp_write
		mov	al,64h			; 'd'
		call	dsp_write
		mov	al,DSP_CMD_OUTPUT_8BIT_SINGECYCLE_DMA
		call	dsp_write
		xor	al,al
		call	dsp_write
		xor	al,al
		call	dsp_write
		xor	ax,ax
		mov	cx,200h

locloop_118:
		cmp	cs:sb_detected_irq,0
		jne	loc_119
		loop	locloop_118

		mov	ax,3
loc_119:
		push	ax
		mov	al,2
		mov	bx,offset prev_irq_2
		call	unhook_irq
		mov	al,3
		mov	bx,offset prev_irq_3
		call	unhook_irq
		mov	al,5
		mov	bx,offset prev_irq_5
		call	unhook_irq
		mov	al,7
		mov	bx,offset prev_irq_7
		call	unhook_irq
		pop	ax
		or	ax,ax
		retn
sb_detect_irq	endp

; checks whether DSP version >= 1.01, reject (bx=0) if not
sb_check_dsp_ver proc	near
		mov	al,DSP_CMD_GET_VERSION
		mov	dx,cs:sb_base_io
		add	dl,DSP_PORT_WRBUF_R
		call	dsp_write
		call	dsp_read
		mov	ah,al
		call	dsp_read
		mov	bx,1
		cmp	ax,101h
		jb	loc_120
		xor	bx,bx
loc_120:
		mov	ax,bx
		or	ax,ax
		retn
sb_check_dsp_ver endp

sub_40		proc	near
		mov	dx,cs:sb_base_io
		add	dl,DSP_PORT_WRBUF_R
		mov	al,DSP_CMD_PAUSE_8BIT_SOUND
		call	dsp_write
loc_121:
		in	al,dx			; port 22Ch ??I/O Non-standard
		or	al,al
		js	loc_121
		retn
sub_40		endp

sub_41		proc	near
		push	bx
		mov	bx,ax
		mov	al,5
		out	0Ah,al			; port 0Ah, DMA-1 mask reg bit
		xor	al,al
		out	0Ch,al			; port 0Ch, DMA-1 clr byte ptr
		mov	al,dh
		out	0Bh,al			; port 0Bh, DMA-1 mode reg
		mov	al,bl
		out	2,al			; port 2, DMA-1 bas&add ch 1
		mov	al,bh
		out	2,al			; port 2, DMA-1 bas&add ch 1
		mov	al,cl
		out	3,al			; port 3, DMA-1 bas&cnt ch 1
		mov	al,ch
		out	3,al			; port 3, DMA-1 bas&cnt ch 1
		mov	al,dl
		out	83h,al			; port 83h, DMA page reg ch 1
		mov	al,1
		out	0Ah,al			; port 0Ah, DMA-1 mask reg bit
		pop	bx
		retn
sub_41		endp

sub_42		proc	near
		push	cx
		mov	cl,4
		rol	dx,cl
		mov	cx,dx
		and	dx,0Fh
		and	cx,0FFF0h
		add	ax,cx
		adc	dx,0
		pop	cx
		retn
sub_42		endp

; al = irq, cs:bx = old vector, cs:dx = new vector
hook_irq		proc	near
		push	bx
		push	cx
		push	dx
		pushf
		cli
		mov	cl,al
		add	al,8
		cbw
		shl	al,1
		shl	al,1
		mov	di,ax
		push	es
		xor	ax,ax
		mov	es,ax
		mov	ax,es:[di]
		mov	cs:[bx],ax
		mov	es:[di],dx
		mov	ax,es:[di+2]
		mov	cs:[bx+2],ax
		mov	es:[di+2],cs
		pop	es
		mov	ah,1
		shl	ah,cl
		not	ah
		in	al,21h			; port 21h, 8259-1 int IMR
		push	bx
		mov	bl,cl
		xor	bh,bh
		mov	cs:pic_prev_imr[bx],al
		pop	bx
		and	al,ah
		out	21h,al			; port 21h, 8259-1 int comands
		popf
		pop	dx
		pop	cx
		pop	bx
		retn
hook_irq	endp

; al = irq number, cs:bx = old vector
unhook_irq		proc	near
		pushf
		cli
		mov	cl,al
		add	al,8
		cbw
		shl	al,1
		shl	al,1
		mov	di,ax
		push	es
		xor	ax,ax
		mov	es,ax
		mov	ax,cs:[bx]
		mov	es:[di],ax
		mov	ax,cs:[bx+2]
		mov	es:[di+2],ax
		pop	es
		mov	ah,1
		shl	ah,cl
		push	bx
		mov	bl,cl
		xor	bh,bh
		mov	al,cs:pic_prev_imr[bx]
		pop	bx
		out	21h,al			; port 21h, 8259-1 int comands
		popf
		retn
unhook_irq	endp

irq_detect_2    proc
		push	dx
		push	ax
		push	dx
		mov	ax,cs
		mov	ds,ax
		mov	dx,cs:sb_base_io
		add	dx,0Eh
		in	al,dx			; port 22Eh ??I/O Non-standard
		mov	cs:sb_detected_irq,2
		mov	al,20h			; ' '
		out	20h,al			; port 20h, 8259-1 int command
						;  al = 20h, end of interrupt
		pop	dx
		pop	ax
		pop	dx
		iret
irq_detect_2    endp

irq_detect_3    proc
		push	ds
		push	ax
		push	dx
		mov	ax,cs
		mov	ds,ax
		mov	dx,cs:sb_base_io
		add	dx,0Eh
		in	al,dx			; port 22Eh ??I/O Non-standard
		mov	cs:sb_detected_irq,3
		mov	al,20h			; ' '
		out	20h,al			; port 20h, 8259-1 int command
						;  al = 20h, end of interrupt
		pop	dx
		pop	ax
		pop	dx
		iret
irq_detect_3    endp

irq_detect_5    proc
		push	ds
		push	ax
		push	dx
		mov	ax,cs
		mov	ds,ax
		mov	dx,cs:sb_base_io
		add	dx,0Eh
		in	al,dx			; port 22Eh ??I/O Non-standard
		mov	cs:sb_detected_irq,5
		mov	al,20h			; ' '
		out	20h,al			; port 20h, 8259-1 int command
						;  al = 20h, end of interrupt
		pop	dx
		pop	ax
		pop	dx
		iret
irq_detect_5    endp

irq_detect_7    proc
		push	ds
		push	ax
		push	dx
		mov	ax,cs
		mov	ds,ax
		mov	dx,cs:sb_base_io
		add	dx,0Eh
		in	al,dx			; port 22Eh ??I/O Non-standard
		mov	cs:sb_detected_irq,7
		mov	al,20h			; ' '
		out	20h,al			; port 20h, 8259-1 int command
						;  al = 20h, end of interrupt
		pop	dx
		pop	ax
		pop	dx
		iret
irq_detect_7    endp

sb_irq          proc
		push	ds
		push	es
		push	ax
		push	bx
		push	cx
		push	dx
		push	di
		push	si
		push	bp
		pushf
		cli
		cld
		mov	ax,cs
		mov	ds,ax
		mov	es,ax
		mov	al,20h			; ' '
		out	20h,al			; port 20h, 8259-1 int command
						;  al = 20h, end of interrupt
		cmp	cs:data_2,2
		jne	loc_124
		mov	ax,cs:data_20
		or	ax,ax
		jnz	loc_122
		call	sub_46
		jmp	short loc_123
loc_122:
		call	sub_45
loc_123:
		mov	dx,cs:sb_base_io
		add	dl,DSP_PORT_RDBUF_R
		in	al,dx			; port 22Eh ??I/O Non-standard
loc_124:
		popf
		pop	bp
		pop	si
		pop	di
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		pop	es
		pop	ds
		iret
sb_irq          endp

sub_45		proc	near
		mov	cx,0FFFFh
		cmp	cs:data_19,0
		jne	loc_125
		inc	cs:data_19
		mov	cx,cs:data_22
loc_125:
		sub	cx,cs:data_17
		mov	cs:data_18,cx
		inc	cx
		jz	loc_126
		sub	cs:data_20,cx
		sbb	cs:data_21,0
		jmp	short loc_127
loc_126:
		dec	cs:data_21
loc_127:
		mov	dh,49h			; 'I'
		mov	dl,cs:data_16
		mov	ax,cs:data_17
		mov	cx,cs:data_18
		call	sub_41
		dec	cs:data_19
		inc	cs:data_16
		mov	cs:data_17,0
		mov	cx,cs:data_18
		mov	dx,cs:sb_base_io
		add	dl,DSP_PORT_WRBUF_R
		mov	al,DSP_CMD_OUTPUT_8BIT_SINGECYCLE_DMA
		call	dsp_write
		mov	al,cl
		call	dsp_write
		mov	al,ch
		call	dsp_write
		retn
sub_45		endp

sub_46		proc	near
		cmp	cs:data_4,0
		je	loc_128
		jmp	short loc_131
		db	90h
loc_128:
		cmp	cs:audio_buffer_index,0
		jne	loc_130
		cmp	cs:data_10,0
		jne	loc_129
		jmp	short loc_131
		db	90h
loc_129:        ; audio_buffer_index == 0, data_10 != 0
		mov	cs:data_4,1
		push	ds
		push	ax
		push	bx
		mov	ax,cs:data_10
		mov	cs:data_29,ax
		lds	bx,dword ptr cs:audio_buffer_0
		mov	cs:data_27,ds
		mov	cs:data_28,bx
		mov	cs:data_25,0
		mov	cs:data_2,1
		pop	bx
		pop	ax
		pop	ds
		retn
loc_130:        ; audio_buffer_index != 0
		push	ds
		push	ax
		push	bx
		mov	ax,cs:data_7
		mov	cs:data_29,ax
		lds	bx,dword ptr cs:audio_buffer_1
		mov	cs:data_27,ds
		mov	cs:data_28,bx
		mov	cs:data_25,0
		mov	cs:data_2,1
		pop	bx
		pop	ax
		pop	ds
		retn
loc_131:
		mov	al,5
		out	0Ah,al			; port 0Ah, DMA-1 mask reg bit
		mov	al,cs:sb_detected_irq
		mov	bx,offset sb_prev_irq
		call	unhook_irq
		mov	cs:data_25,0
		mov	dx,cs:sb_base_io
		add	dl,0Eh
		in	al,dx			; port 22Eh ??I/O Non-standard
		retn
sub_46		endp

sb_init		proc	near
		push	ds
		push	es
		push	di
		push	si
		mov	ax,cs
		mov	ds,ax
		mov	es,ax
		call	dsp_reset
		jnz	loc_132
		call	dsp_sanity_check
		jnz	loc_132
		call	sb_check_dsp_ver
		jnz	loc_132
		call	sb_detect_irq
		jnz	loc_132

		mov	al,1
		call	sb_set_speaker
		xor	ax,ax

loc_132:
		pop	si
		pop	di
		pop	es
		pop	ds
		retn
sb_init		endp

			                        ;* No entry point to code
		push	ds
		push	es
		push	si
		push	di
		push	ax
		push	bx
		push	cx
		push	dx
		call	sb_set_speaker
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		pop	di
		pop	si
		pop	es
		pop	ds
		retn

sb_set_speaker	proc	near
		mov	dx,cs:sb_base_io
		add	dx,DSP_PORT_DATACMD_W
		mov	ah,DSP_CMD_TURN_ON_SPEAKER
		or	al,al
		jnz	loc_133
		mov	ah,DSP_CMD_TURN_OFF_SPEAKER
loc_133:
		mov	al,ah
		call	dsp_write
		xor	ax,ax
		retn
sb_set_speaker	endp

sub_49		proc	near
		push	bx
		push	cx
		push	dx
		push	ds
		push	es
		push	di
		push	si
		mov	ax,cs
		mov	ds,ax
		mov	es,ax
		cmp	cs:data_25,0
		je	loc_134
		mov	ax,1
		jmp	loc_135
loc_134:
		mov	cs:data_25,1
		mov	dx,cs:sb_base_io
		add	dl,DSP_PORT_WRBUF_R
		mov	cl,cs:dsp_time_constant
		mov	dx,cs:sb_base_io
		add	dl,DSP_PORT_WRBUF_R
		mov	al,DSP_CMD_SET_TIME_CONSTANT
		call	dsp_write
		mov	al,cl
		call	dsp_write
		mov	al,cs:sb_detected_irq
		mov	dx,offset sb_irq
		mov	bx,offset sb_prev_irq
		call	hook_irq
		mov	dx,cs:data_27
		mov	ax,cs:data_28
		call	sub_42
		mov	cs:data_16,dl
		mov	cs:data_17,ax
		mov	cx,cs:data_29
		mov	cs:data_20,cx
		mov	cs:data_21,0
		add	ax,cs:data_29
		adc	dl,0
;*		sub	ax,1
		db	 2Dh, 01h, 00h
		sbb	dl,0
		mov	cs:data_22,ax
		sub	dl,cs:data_16
		mov	cs:data_19,dl
		call	sub_45
		mov	cs:data_2,2
		xor	ax,ax
loc_135:
		pop	si
		pop	di
		pop	es
		pop	ds
		pop	dx
		pop	cx
		pop	bx
		retn
sub_49		endp

sub_50		proc	near
		push	ax
		push	bx
		push	cx
		push	dx
		push	ds
		push	es
		push	di
		push	si
		mov	ax,cs
		mov	ds,ax
		mov	es,ax
		mov	ax,1
		cmp	cs:data_25,0
		je	loc_136
		call	sub_40
		call	sub_46
		mov	cs:data_2,0
		xor	ax,ax
loc_136:
		pop	si
		pop	di
		pop	es
		pop	ds
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		retn
sub_50		endp

			                        ;* No entry point to code
		push	ds
		push	es
		push	di
		push	si
		mov	ax,cs
		mov	ds,ax
		mov	es,ax
		mov	ax,1
		cmp	cs:data_25,1
		jne	loc_137
		call	sub_40
		mov	cs:data_2,4
		xor	ax,ax
loc_137:
		pop	si
		pop	di
		pop	es
		pop	ds
		retn
			                        ;* No entry point to code
		push	ds
		push	es
		push	di
		push	di
		mov	ax,cs
		mov	ds,ax
		mov	es,ax
		mov	ax,1
		cmp	cs:data_25,1
		jne	loc_138
		mov	dx,cs:sb_base_io
		add	dl,DSP_PORT_WRBUF_R
		mov	al,DSP_CMD_CONTINUE_8BIT_SOUND
		call	dsp_write
		mov	cs:data_2,2
		xor	ax,ax
loc_138:
		pop	si
		pop	di
		pop	es
		pop	ds
		retn

fn_17           proc near
		push	si
		mov	si,ax
		and	si,0FFh
		cmp	ah,MIDI_PBEND
		jne	loc_139
		shl	si,1
		mov	ax,cs:ch_pbend[si]
		jmp	short loc_147
		db	90h
loc_139:
		cmp	ah,MIDI_PCHANGE
		jne	loc_140
		mov	al,cs:ch_instrument[si]
		jmp	short loc_147
		db	90h
loc_140:
		cmp	ah,MIDI_CONTROL
		jne	loc_146
		cmp	ch,MIDI_CONTROL_CH_VOLUME
		jne	loc_141
		mov	al,byte ptr cs:ch_volume[si]
		jmp	short loc_147
		db	90h
loc_141:
		cmp	ch,MIDI_CONTROL_DAMPER_PEDAL_ON_OFF
		jne	loc_142
		mov	al,byte ptr cs:data_80[si]
		jmp	short loc_147
		db	90h
loc_142:
		cmp	ch,MIDI_CONTROL_DECAY_TIME
		jne	loc_146
		cmp	cl,0FFh
		je	loc_143
		mov	al,cs:data_81[si]
		jmp	short loc_147
		db	90h
loc_143:
		xor	ah,ah
		xor	si,si
loc_144:
		cmp	byte ptr cs:mch_op_map[si],al
		jne	loc_145
		inc	ah
loc_145:
		inc	si
		cmp	si,OPL_NUM_VOICES
		jne	loc_144
		mov	al,ah
		jmp	short loc_147
		db	90h
loc_146:
		mov	ax,0FFFFh
loc_147:
		pop	si
		retn
fn_17           endp

fn_init         proc near
		mov	si,ax
		mov	di,0
		mov	cx,1344

locloop_148:
		mov	bl,es:[si]
		mov	cs:data_65[di],bl
		inc	si
		inc	di
		loop	locloop_148

		mov	bh,es:[si]
		inc	si
		mov	bl,es:[si]
		inc	si
		cmp	bx,0ABCDh
		jne	loc_150

                ; magic ABCDh marker found - copy the next half
		mov	cx,1344

locloop_149:
		mov	bl,es:[si]
		mov	cs:data_65[di],bl
		inc	si
		inc	di
		loop	locloop_149

loc_150:
		call	sub_31
		call	sb_init
;*		cmp	ax,0
		db	 3Dh, 00h, 00h
		jz	loc_151
		mov	ax,0FFFFh
		jmp	short loc_ret_152
loc_151:
		mov	ax,offset get_driver_info
		mov	cl,0
		mov	ch,0Fh

loc_ret_152:
		retn
fn_init         endp

get_driver_info proc near
                mov     ah,0x11
                mov     al,0x3
                mov     ch,0x0
                mov     cl,0x9
                ret
get_driver_info endp

seg_a		ends
		end	start

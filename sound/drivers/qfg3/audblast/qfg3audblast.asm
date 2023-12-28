; vim:set ts=8:

seg_a		segment	byte public
		assume	cs:seg_a, ds:seg_a

		org	0

audblast	proc	far

start:
		jmp	loc_1
		db	 00h, 21h, 43h, 65h, 87h, 02h
		db	 08h, 61h, 75h, 64h, 62h, 6Ch
data_2		db	61h
		db	 73h, 74h, 11h
		db	'CMS Sound Blaster'
		db	 98h,0BAh,0DCh,0FEh, 04h, 00h
		db	 00h, 00h

; I think this is ADPCM ?
data_3		db	0h, 01h, 02h, 03h, 06h, 0Ah, 0Fh, 15h
data_4		db	0
data_5		db	0
audio_compressed db	0
pcm_last_byte	db	0               ; used for ADPCM I think
data_8		db	0
data_9		db	0
data_10		db	0
data_11		db	0
which_buffer	db	0
data_13		db	0
in_int_0dh		db	0
in_int_74h		db	0
data_16		db	0
data_17		db	0
in_int_10h		db	0
data_19		db	0
data_20		db	0
data_21		db	0
data_22		db	0
data_23		db	0               ; unused?
data_24		db	0
data_25		db	0
data_26		db	0
data_27		db	0
data_28		db	0
data_29		db	0
audio_rotated	db	0
data_31		db	0
data_32		db	0
data_33		db	0               ; unused?
data_34		db	0
data_35		db	0
data_36		dw	0
data_37		dw	0
data_38		dw	0
data_39		dw	0
data_40		dw	0               ; some offset within audio_data_seg
audio_data_seg		dw	0
audio_data_len		dw	0
data_43		dw	0
data_44		dw	0
data_45		dw	0
data_46		dw	0
data_47		dw	0
data_48		dw	0
data_49		dw	0
data_50		dw	0
sb_io_base		dw	0
sb_freq_set		dw	0
audio_file_handle		dw	0
data_54		dw	0
data_55		dw	0
data_56		dw	0
data_57		dw	0
sb_cur_freq		dw	0
data_59		dw	0               ; read from resource.aud, offset 0bh
data_60		dw	0               ; read from resource.aud, offset 09h
data_61		dd      0
dos_crit_flag_ptr		dd	00000h
indos_flag_ptr	dd	00000h
orig_int_0dh	dd	00000h
orig_int_74h	dd	00000h
orig_int_10h	dd	0h
		db	0
TEMP_BUF_LEN    equ     2048
temp_buf	db	TEMP_BUF_LEN dup (0)

func_tab	dw	offset sub_34		;  0 initialize
                dw	offset sub_1            ;  1 status
                dw	offset sub_10           ;  2 terminate
                dw	offset sub_7            ;  3 memplay
                dw	offset sub_8            ;  4 memcheck
                dw	offset sub_9            ;  5 memstop
                dw	offset fn_rate          ;  6 rate
                dw	offset fn_pause         ;  7 pause
                dw	offset fn_resume        ;  8 resume
                dw	offset fn_select        ;  9 select
                dw	offset sub_26           ; 10 wplay
                dw	offset sub_27           ; 11 play
                dw	offset fn_stop          ; 12 stop
                dw	offset sub_32           ; 13 loc
                dw	offset sub_22           ; 14 volume
                dw	offset sub_2            ; 15 fillbuf
loc_1:
		push	ds
		mov	bx,ax
		shl	bx,1
		mov	ax,cs
		mov	ds,ax
		call	word ptr cs:func_tab[bx]	;*16 entries
		pop	ds
		or	ax,ax
		retf

audblast	endp

sub_1		proc	near
		cmp	cs:data_34,1
		je	loc_3
		cmp	cs:data_11,1
		jne	loc_3
		cmp	cs:data_24,0
		jne	loc_2
		inc	cs:data_50
		call	sub_31
loc_2:
		call	sub_28
loc_3:
		xor	ax,ax
		retn
sub_1		endp

sub_2		proc	near
		retn
sub_2		endp

fn_rate		proc	near
		mov	ax,ss:[si]
		mov	cs:sb_freq_set,ax
		call	sb_set_freq
		xor	ax,ax
		retn
fn_rate		endp

fn_pause	proc	near
		retn

		mov	cs:data_24,1
		xor	ax,ax
		retn
fn_pause	endp

fn_resume	proc	near
		mov	cs:data_24,0
		xor	ax,ax
		retn
fn_resume	endp

fn_stop		proc	near
		cmp	cs:data_34,1
		je	loc_4
		mov	cs:data_34,1
		call	sub_17
		call	sub_13
		mov	al,cs:data_20
		mov	bx,offset data_61
		call	sub_21
loc_4:
		xor	ax,ax
		retn
fn_stop		endp

sub_7		proc	near
		push	si
		call	fn_stop
		pop	si
		mov	ax,ss:[si]
		or	ah,ah
		jnz	loc_5
		mov	cs:data_22,0
		jmp	short loc_6
loc_5:
		mov	cs:data_22,1
loc_6:
		mov	ax,ss:[si+2]
		call	sb_set_freq
		mov	ax,ss:[si+4]
		mov	dx,ss:[si+6]
		call	sub_16
		mov	cs:data_4,dl
		mov	cs:data_37,ax
		mov	ax,ss:[si+8]
		mov	cs:data_36,ax
		add	ax,cs:data_37
		jnc	loc_7
		mov	cs:data_38,ax
		sub	cs:data_36,ax
		mov	cs:data_39,0
		inc	dl
		mov	cs:data_5,dl
		jmp	short loc_8
loc_7:
		mov	cs:data_38,0
loc_8:
		mov	al,cs:data_20
		mov	dx,offset sb_irq_handler
		mov	bx,offset data_61
		call	sub_20
		mov	cs:data_27,0
		mov	cs:data_11,0
		mov	cs:data_13,1
		call	sub_11
		mov	cs:data_50,0
		mov	cs:data_34,0
		mov	cs:data_21,0
		retn
sub_7		endp

sub_8		proc	near
		mov	ax,ss:[si]
		or	ah,ah
		jnz	loc_9
		mov	cs:data_22,0
		jmp	short loc_10
loc_9:
		mov	cs:data_22,1
loc_10:
		mov	al,cs:data_34
		mov	ah,cs:data_21
		mov	cs:data_21,0
		retn
sub_8		endp

sub_9		proc	near
		call	fn_stop
		retn
sub_9		endp

sub_10		proc	near
		call	fn_stop
		push	ds
		lds	dx,cs:orig_int_10h
		mov	ah,25h			; '%'
		mov	al,10h
		int	21h			; DOS Services  ah=function 25h
						;  set intrpt vector al to ds:dx
		pop	ds
		push	ds
		lds	dx,cs:orig_int_0dh
		mov	ah,25h			; '%'
		mov	al,0Dh
		int	21h			; DOS Services  ah=function 25h
						;  set intrpt vector al to ds:dx
		pop	ds
		push	ds
		lds	dx,cs:orig_int_74h
		mov	ah,25h			; '%'
		mov	al,74h			; 't'
		int	21h			; DOS Services  ah=function 25h
						;  set intrpt vector al to ds:dx
		pop	ds
		cmp	cs:audio_file_handle,0FFFFh
		je	loc_11
		mov	bx,cs:audio_file_handle
		mov	ah,3Eh
		int	21h			; DOS Services  ah=function 3Eh
						;  close file, bx=file handle
		mov	cs:audio_file_handle,0FFFFh
loc_11:
		xor	ax,ax
		retn
sub_10		endp

sub_11		proc	near
		cmp	cs:data_27,0
		jne	loc_12
		mov	dl,cs:data_4
		mov	ax,cs:data_37
		mov	cx,cs:data_36
		jmp	short loc_13
loc_12:
		mov	dl,cs:data_5
		mov	ax,cs:data_39
		mov	cx,cs:data_38
loc_13:
		mov	cs:data_48,cx
		mov	cs:data_9,dl
		mov	cs:data_49,ax
		cmp	cs:data_11,1
		jne	loc_15
		cmp	cs:data_25,1
		jne	loc_15
		cmp	cs:data_13,0
		jne	loc_14
		retn
loc_14:
		mov	cs:data_13,0
loc_15:
		call	sub_12
		retn
sub_11		endp

sub_12		proc	near
		mov	al,5
		out	0Ah,al			; port 0Ah, DMA-1 mask reg bit
		xor	al,al
		out	0Ch,al			; port 0Ch, DMA-1 clr byte ptr
		mov	ax,cs:data_49
		out	2,al			; port 2, DMA-1 bas&add ch 1
		mov	al,ah
		out	2,al			; port 2, DMA-1 bas&add ch 1
		mov	al,49h			; 'I'
		mov	cx,cs:data_48
		cmp	cs:data_11,1
		jne	loc_16
		cmp	cs:data_25,1
		jne	loc_16
		mov	al,59h			; 'Y'
		shl	cx,1
loc_16:
		mov	cs:data_47,cx
		out	0Bh,al			; port 0Bh, DMA-1 mode reg
		mov	al,cs:data_9
		out	83h,al			; port 83h, DMA page reg ch 1
		mov	ax,cx
		dec	ax
		out	3,al			; port 3, DMA-1 bas&cnt ch 1
		mov	al,ah
		out	3,al			; port 3, DMA-1 bas&cnt ch 1
		mov	al,1
		out	0Ah,al			; port 0Ah, DMA-1 mask reg bit
		mov	dx,cs:sb_io_base
		add	dl,0Ch
		cmp	cs:data_11,1
		jne	loc_17
		cmp	cs:data_25,1
		jne	loc_17
		mov	al,1Ch
		call	dsp_write
		retn
loc_17:
		mov	al,14h
		call	dsp_write
		mov	cx,cs:data_48
		dec	cx
		mov	al,cl
		call	dsp_write
		mov	al,ch
		call	dsp_write
		retn
sub_12		endp

sub_13		proc	near
		mov	al,5
		out	0Ah,al			; port 0Ah, DMA-1 mask reg bit
		mov	dx,cs:sb_io_base
		add	dl,0Eh
		in	al,dx			; port 0Eh ??I/O Non-standard
		retn
sub_13		endp

sb_irq_handler  proc
		push	ds
		push	dx
		push	ax
		push	cx
		push	bx
		push	si
		push	di
		push	es
		push	bp
		cld
		mov	ax,cs
		mov	ds,ax
		cmp	cs:data_11,1
		jne	loc_22
		cmp	cs:data_25,1
		jne	loc_19
		xor	cs:data_10,1
		jnz	loc_18
		mov	ax,cs:data_48
		shl	ax,1
		add	cs:data_44,ax
		adc	cs:data_43,0
loc_18:
		jmp	short loc_20
loc_19:
		mov	ax,cs:data_48
		add	cs:data_44,ax
		adc	cs:data_43,0
		call	sub_13
loc_20:
		cmp	cs:data_34,1
		je	loc_21
		call	sub_30
loc_21:
		jmp	short loc_25
loc_22:
		cmp	cs:data_38,0
		je	loc_23
		xor	cs:data_27,1
		jz	loc_23
		call	sub_11
		jmp	short loc_25
loc_23:
		cmp	cs:data_22,1
		jne	loc_24
		call	sub_11
		mov	cs:data_21,1
		jmp	short loc_25
loc_24:
		call	sub_9
loc_25:
		mov	dx,cs:sb_io_base
		add	dl,0Eh
		in	al,dx			; port 0Eh ??I/O Non-standard
		mov	al,20h			; ' '
		out	20h,al			; port 20h, 8259-1 int command
						;  al = 20h, end of interrupt
		pop	bp
		pop	es
		pop	di
		pop	si
		pop	bx
		pop	cx
		pop	ax
		pop	dx
		pop	ds
		iret
sb_irq_handler  endp

sb_set_freq	proc	near
		mov	cs:sb_cur_freq,ax
		mov	cx,ax
		mov	dx,0Fh
		mov	ax,4240h
		div	cx                      ; ax = 1'000'000 / sb_cur_freq
		mov	cl,al
		neg	cl
		mov	dx,cs:sb_io_base
		add	dl,0Ch
		mov	al,40h			; '@'
		call	dsp_write
		mov	al,cl
		call	dsp_write
		retn
sb_set_freq	endp

sub_15		proc	near
		push	ax
		push	cx
		push	dx
		mov	cx,ax
		mov	dx,cs:sb_io_base
		add	dl,0Ch
		mov	al,48h			; 'H'
		call	dsp_write
		mov	al,cl
		call	dsp_write
		mov	al,ch
		call	dsp_write
		pop	dx
		pop	cx
		pop	ax
		retn
sub_15		endp

sub_16		proc	near
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
sub_16		endp

sub_17		proc	near
		mov	dx,cs:sb_io_base
		add	dl,0Ch
		mov	al,0D0h
		call	dsp_write
loc_26:
		in	al,dx			; port 0Ch ??I/O Non-standard
		or	al,al
		js	loc_26
		retn
sub_17		endp

sub_18		proc	near
		mov	dx,cs:sb_io_base
		add	dl,0Ch
		mov	al,0D4h
		call	dsp_write
loc_27:
		in	al,dx			; port 0Ch ??I/O Non-standard
		or	al,al
		js	loc_27
		retn
sub_18		endp

dsp_write	proc	near
		mov	ah,al
		mov	al,0F0h
loc_28:
		in	al,dx			; port 0Ch ??I/O Non-standard
		or	al,al
		js	loc_28
		mov	al,ah
		out	dx,al			; port 0Ch, DMA-1 clr byte ptr
		retn
dsp_write	endp

sub_20		proc	near
		push	bx
		push	cx
		push	dx
		cli
		mov	cl,al
		add	al,8
		cbw
		shl	al,1
		shl	al,1
		mov	di,ax
		push	es
		sub	ax,ax
		mov	es,ax
		mov	ax,es:[di]
		mov	[bx],ax
		mov	es:[di],dx
		mov	ax,es:[di+2]
		mov	cs:[bx+2],ax
		mov	es:[di+2],cs
		pop	es
		mov	ah,1
		shl	ah,cl
		not	ah
		in	al,21h			; port 21h, 8259-1 int IMR
		mov	cs:data_29,al
		and	al,ah
		out	21h,al			; port 21h, 8259-1 int comands
		sti
		pop	dx
		pop	cx
		pop	bx
		retn
sub_20		endp

sub_21		proc	near
		cli
		add	al,8
		cbw
		shl	al,1
		shl	al,1
		mov	di,ax
		push	es
		sub	ax,ax
		mov	es,ax
		mov	ax,[bx]
		mov	es:[di],ax
		mov	ax,[bx+2]
		mov	es:[di+2],ax
		pop	es
		mov	al,cs:data_29
		out	21h,al			; port 21h, 8259-1 int comands
		sti
		retn
sub_21		endp

sub_22		proc	near
		xor	ax,ax
		retn
sub_22		endp

fn_select	proc	near
		push	si
		call	fn_stop
		pop	si
		cmp	byte ptr ss:[si+12h],0
		jne	loc_29
		mov	cs:data_19,0
		jmp	short loc_30
loc_29:
		mov	cs:data_19,1
loc_30:
		mov	al,ss:[si+13h]
		call	decode_header_flags
		mov	ax,ss:[si+8]
		mov	cs:data_60,ax
		mov	ax,ss:[si+0Ah]
		mov	cs:data_59,ax
		mov	ax,ss:[si+0Ch]
		mov	cs:data_40,ax
		mov	dx,ss:[si+0Eh]
		mov	cs:audio_data_seg,dx
		call	sub_16
		mov	cs:data_4,dl
		mov	cs:data_5,dl
		mov	cs:data_37,ax
		mov	ax,ss:[si+10h]
		shr	ax,1
		mov	cs:audio_data_len,ax
		cmp	cs:data_8,1
		jne	loc_31
		mov	cs:data_25,1
		push	ax
		mov	cs:data_10,0
		mov	di,cs:data_40
		mov	ax,cs:audio_data_seg
		mov	es,ax
		mov	cx,cs:audio_data_len
		shl	cx,1
		mov	al,80h
		rep	stosb
		pop	ax
		jmp	short loc_32
loc_31:
		mov	cs:data_25,0
loc_32:
		add	ax,cs:data_37
		mov	cs:data_39,ax
		jnc	loc_33
		inc	cs:data_5
loc_33:
		mov	ax,ss:[si]
		or	ax,ss:[si+2]
		jnz	loc_34
		mov	bx,cs:audio_file_handle
		jmp	short loc_39
loc_34:
		cmp	word ptr ss:[si+2],0FFFFh
		jne	loc_35
		mov	bx,ss:[si]
		jmp	short loc_38
loc_35:
		cmp	cs:audio_file_handle,0FFFFh
		je	loc_36
		mov	bx,cs:audio_file_handle
		mov	ah,3Eh
		int	21h			; DOS Services  ah=function 3Eh
						;  close file, bx=file handle
		mov	cs:audio_file_handle,0FFFFh
loc_36:
		push	ds
		mov	dx,ss:[si]
		mov	ax,ss:[si+2]
		mov	ds,ax
		mov	al,0
		mov	ah,3Dh
		int	21h			; DOS Services  ah=function 3Dh
						;  open file, al=mode,name@ds:dx
		pop	ds
		jnc	loc_37
		xor	ax,ax
		retn
loc_37:
		mov	bx,ax
loc_38:
		mov	cs:audio_file_handle,bx
loc_39:
		mov	dx,ss:[si+4]
		mov	cs:data_55,dx
		mov	cx,ss:[si+6]
		mov	cs:data_54,cx
		mov	al,0
		mov	ah,42h
		int	21h			; DOS Services  ah=function 42h
						;  move file ptr, bx=file handle
						;   al=method, cx,dx=offset
		jnc	loc_40
		xor	ax,ax
		retn
loc_40:
		call	init_resource_aud
		mov	cs:data_28,0
		mov	ax,cs:data_60
		mov	bx,cs:data_59
		mov	cs:data_57,ax
		mov	cs:data_56,bx
		cmp	cs:audio_compressed,1
		jne	loc_41
		shl	ax,1
		rcl	bx,1
loc_41:
		mov	cx,60
		mul	cx
		push	ax
		push	dx
		mov	ax,bx
		mul	cx
		pop	dx
		add	dx,ax
		pop	ax
		cmp	dx,cs:sb_cur_freq
		jae	loc_42
		div	cs:sb_cur_freq
		jmp	short loc_43
loc_42:
		mov	ax,0FFFEh
loc_43:
		cmp	cs:data_25,1
		jne	loc_ret_45
		push	ax
		mov	ax,cs:audio_data_len
		cmp	cs:data_59,0
		jne	loc_44
		cmp	ax,cs:data_60
		jbe	loc_44
		mov	ax,cs:data_60
loc_44:
		call	sub_15
		pop	ax

loc_ret_45:
		retn
fn_select	endp

; used to decode a flags byte from resource.aud / ???
; bit 0 -> audio_compressed
; bit 1 -> audio_rotated - determines if data must be rol1'ed
; bit 2 -> data_32
; bit 3 -> data_31
; bit 4 -> data_33 (unused?)
; bit 7 -> data_23 (unused?)
decode_header_flags		proc	near
		mov	cs:pcm_last_byte,80h
		test	al,1
		jz	loc_46
		mov	cs:audio_compressed,1
		jmp	short loc_47
loc_46:
		mov	cs:audio_compressed,0
loc_47:
		test	al,2
		jz	loc_48
		mov	cs:audio_rotated,1
		jmp	short loc_49
loc_48:
		mov	cs:audio_rotated,0
loc_49:
		test	al,4
		jz	loc_50
		mov	cs:data_32,1
		jmp	short loc_51
loc_50:
		mov	cs:data_32,0
loc_51:
		test	al,8
		jz	loc_52
		mov	cs:data_31,1
		jmp	short loc_53
loc_52:
		mov	cs:data_31,0
loc_53:
		test	al,10h
		jz	loc_54
		mov	cs:data_33,1
		jmp	short loc_55
loc_54:
		mov	cs:data_33,0
loc_55:
		test	al,80h
		jz	loc_56
		mov	cs:data_23,1
		jmp	short loc_ret_57
loc_56:
		mov	cs:data_23,0

loc_ret_57:
		retn
decode_header_flags		endp

; decodes the resource.aud header
init_resource_aud proc	near
		mov	bx,cs:audio_file_handle
		mov	cx,2
		mov	dx,cs:data_40
		mov	ax,cs:audio_data_seg
		push	ds
		mov	ds,ax
		mov	si,dx
		mov	ah,3Fh              ; dos: read file
		int	21h

		lodsb
		cmp	al,8Dh
		jne	loc_58

		lodsb
		mov	cl,al
		mov	si,dx
		mov	ah,3Fh              ; dos: read file
		int	21h

		lodsb
		cmp	al,53h			; 'S'
		jne	loc_58
		lodsb
		cmp	al,4Fh			; 'O'
		jne	loc_58
		lodsb
		cmp	al,4Ch			; 'L'
		jne	loc_58
		lodsb
		cmp	al,0
		je	loc_59
loc_58:
		pop	ds
		mov	dx,cs:data_55
		mov	cx,cs:data_54
		mov	al,0
		mov	ah,42h
		int	21h			; DOS Services  ah=function 42h
						;  move file ptr, bx=file handle
						;   al=method, cx,dx=offset
		retn
loc_59:         ; SOL\0 header checks out
		add	cx,2                    ; skip headers (8Dh+len / SOL\0)
		add	cs:data_55,cx
		adc	cs:data_54,0

		lodsb
		mov	ah,al
		lodsb
		xchg	ah,al                   ; ax

		push	ax
		lodsb
		mov	cl,al                   ; cl = flags
		lodsw
		mov	bx,ax                   ; bx
		lodsw
		mov	dx,ax                   ; dx
		pop	ax

		pop	ds
		mov	cs:data_60,bx
		mov	cs:data_59,dx
		push	ax
		mov	al,cl
		call	decode_header_flags
		pop	ax
		mov	cs:sb_freq_set,ax
		call	sb_set_freq
		retn
init_resource_aud endp

sub_26		proc	near
		mov	cs:data_28,1
		mov	cs:data_27,0FFh
		mov	cs:which_buffer,0
		call	sub_28
		call	sub_28
		xor	ax,ax
		retn
sub_26		endp

sub_27		proc	near
		mov	al,cs:data_20
		mov	dx,offset sb_irq_handler
		mov	bx,offset data_61
		call	sub_20
		mov	ax,cs:sb_freq_set
		cmp	ax,cs:sb_cur_freq
		je	loc_60
		call	sb_set_freq
loc_60:
		mov	cs:data_11,1
		mov	cs:data_26,1
		cmp	cs:data_28,1
		je	loc_61
		mov	cs:data_27,0FFh
		mov	cs:which_buffer,0
		call	sub_28
		call	sub_28
		jmp	short loc_62
loc_61:
		mov	cs:data_28,0
loc_62:
		mov	cs:data_27,1
		mov	cs:data_44,0
		mov	cs:data_43,0
		mov	cs:data_13,1
		mov	cs:data_35,0
		mov	al,cs:which_buffer
		push	ax
		mov	cs:which_buffer,0FFh
		call	sub_31
		pop	ax
		mov	cs:which_buffer,al
		mov	cs:data_24,0
		mov	cs:data_50,0
		mov	cs:data_34,0
		xor	ax,ax
		retn
sub_27		endp

sub_28		proc	near
		cmp	cs:data_17,1
		je	loc_ret_63
		mov	ax,cs:data_60
		or	ax,cs:data_59
		jz	loc_ret_63
		mov	al,cs:which_buffer
		cmp	al,cs:data_27
		je	loc_ret_63
		call	sub_33
		jz	loc_64

loc_ret_63:
		retn
loc_64:
		mov	cs:data_17,1
		pushf
		sti
		mov	cs:data_45,0
		mov	cx,cs:audio_data_len
		cmp	cs:which_buffer,0
		jne	loc_65
		mov	dx,0
		jmp	short loc_66
loc_65:
		mov	dx,cx
loc_66:
		cmp	cs:data_32,1
		jne	loc_67
		shl	cx,1
loc_67:
		cmp	cs:audio_compressed,1
		jne	loc_68
		shr	cx,1
loc_68:
		cmp	cs:data_59,0
		jne	loc_69
		cmp	cx,cs:data_60
		jbe	loc_69
		mov	cx,cs:data_60
loc_69:
		sub	cs:data_60,cx
		sbb	cs:data_59,0
		mov	di,dx
		cmp	cs:audio_compressed,1
		jne	loc_70
		add	dx,cx
loc_70:
		mov	bx,cs:audio_file_handle
		mov	ax,cs:audio_data_seg
		cmp	cs:data_32,1
		jne	loc_72
		mov	es,ax
		mov	dx,offset temp_buf
		mov	ax,ds
		cmp	cx,TEMP_BUF_LEN
		jbe	loc_71
		mov	cs:data_46,cx
		mov	cx,TEMP_BUF_LEN
		sub	cs:data_46,cx
		jmp	short loc_72
loc_71:
		mov	cs:data_46,0
loc_72:
		mov	si,dx
		push	ds
		mov	ds,ax
		mov	ah,3Fh                  ; dos: read file
		int	21h

		pop	ds
		jnc	loc_73
		mov	ax,cx
loc_73:
		cmp	cs:data_32,1
		jne	loc_77
		shr	ax,1
		push	ax
		push	si
		push	di
		mov	cx,ax

locloop_74:
		lodsw
		cmp	cs:data_31,1
		jne	loc_75
		mov	al,7Fh
		sub	al,ah
		jmp	short loc_76
loc_75:
		mov	al,ah
loc_76:
		stosb
		loop	locloop_74

		pop	di
		pop	si
		pop	ax
loc_77:
		cmp	cs:audio_rotated,1
		jne	dont_rotate_audio

		push	ax
		push	si
		push	di
		push	ds
		mov	cx,ax
		mov	ax,cs:audio_data_seg
		mov	ds,ax
		mov	es,ax

locloop_78:
		lodsb
		rol	ax,1
		stosb
		loop	locloop_78

		pop	ds
		pop	di
		pop	si
		pop	ax

dont_rotate_audio:
		cmp	cs:audio_compressed,1
		jne	loc_85

		push	ax
		push	bx
		push	dx
		push	si
		push	di
		push	ds
		mov	cx,ax
		mov	dl,cs:pcm_last_byte
		mov	ax,cs:audio_data_seg
		mov	ds,ax
		mov	es,ax
		mov	ah,dl

locloop_80:
		lodsb
		mov	dl,al
		shr	al,1
		shr	al,1
		shr	al,1
		shr	al,1
		cmp	al,8
		jl	loc_81
		mov	bx,offset data_2
		sub	bl,al
		sub	ah,cs:data_3[bx]
		jmp	short loc_82
loc_81:
		mov	bl,al
		xor	bh,bh
		add	ah,cs:data_3[bx]
loc_82:
		mov	al,ah
		stosb
		and	dl,0Fh
		cmp	dl,8
		jl	loc_83
		mov	bx,offset data_2
		sub	bl,dl
		sub	ah,cs:data_3[bx]
		jmp	short loc_84
loc_83:
		mov	bl,dl
		xor	bh,bh
		add	ah,cs:data_3[bx]
loc_84:
		mov	al,ah
		stosb
		loop	locloop_80

		pop	ds
		mov	cs:pcm_last_byte,ah
		pop	di
		pop	si
		pop	dx
		pop	bx
		pop	ax
		shl	ax,1

loc_85:         ; audio_compressed != 1, or done processing
		add	cs:data_45,ax
		cmp	cs:data_32,1
		jne	loc_86
		cmp	cs:data_46,0
		je	loc_86
		add	di,ax
		mov	cx,cs:data_46
		jmp	loc_70
loc_86:
		cmp	cs:data_19,1
		jne	loc_88
		mov	cx,cs:data_60
		or	cx,cs:data_59
		jnz	loc_88
		mov	cs:data_44,cx
		mov	cs:data_43,cx
		mov	cs:data_50,cx
		push	ax
		push	dx
		mov	dx,cs:data_55
		mov	cx,cs:data_54
		mov	al,0
		mov	ah,42h                  ; dos: seek to cx:dx
		int	21h

		pop	dx
		pop	ax
		mov	cx,cs:data_57
		mov	cs:data_60,cx
		mov	cx,cs:data_56
		mov	cs:data_59,cx
		cmp	cs:audio_compressed,1
		jne	loc_87
		mov	cs:pcm_last_byte,80h
		shr	ax,1
loc_87:
		mov	cx,cs:audio_data_len
		sub	cx,cs:data_45
		jz	loc_88
		add	dx,ax
		jmp	loc_66
loc_88:
		mov	ax,cs:data_45
		cmp	cs:which_buffer,0
		jne	loc_89
		mov	cs:data_36,ax
		jmp	short loc_90
loc_89:
		mov	cs:data_38,ax
loc_90:
		xor	cs:which_buffer,1
		mov	cs:data_17,0
		popf
		retn
sub_28		endp

clear_audio_buffer	proc	near
		cmp	cs:which_buffer,0
		jne	loc_91
                ; which_buffer = 0
		mov	di,0
		jmp	short loc_93
loc_91:
		cmp	cs:which_buffer,1
		jne	loc_ret_92
                ; which_buffer = 1
		mov	di,cs:audio_data_len
		jmp	short loc_93

loc_ret_92:
		retn
loc_93:
		mov	ax,cs:audio_data_seg
		mov	es,ax
		mov	cx,cs:audio_data_len
		mov	al,80h
		rep	stosb
		retn
clear_audio_buffer	endp

sub_30		proc	near
		mov	cs:data_26,1
		call	sub_31
		retn
sub_30		endp

sub_31		proc	near
		cmp	cs:data_16,1
		je	loc_ret_99
		cmp	cs:data_26,1
		jne	loc_ret_99
		mov	cs:data_16,1
		mov	al,cs:data_27
		xor	al,1
		cmp	al,cs:which_buffer
		jne	loc_96
		mov	ax,cs:data_60
		or	ax,cs:data_59
		jnz	loc_94
		call	fn_stop
		jmp	short loc_95
loc_94:
		cmp	cs:data_25,1
		jne	loc_95
		cmp	cs:data_35,0
		jne	loc_95
		mov	cs:data_35,1
		call	sub_17
loc_95:
		jmp	short loc_98
loc_96:
		cmp	cs:data_35,1
		jne	loc_97
		call	sub_18
		mov	cs:data_35,0
loc_97:
		mov	cs:data_26,0
		xor	cs:data_27,1
		call	sub_11
		call	clear_audio_buffer
loc_98:
		mov	cs:data_16,0

loc_ret_99:
		retn
sub_31		endp

sub_32		proc	near
		cmp	cs:data_28,1
		jne	loc_100
		mov	word ptr ss:[si],0
		mov	word ptr ss:[si+2],0
		mov	word ptr ss:[si+4],0
		xor	ax,ax
		retn
loc_100:
		cmp	cs:data_34,1
		jne	loc_101
		mov	word ptr ss:[si],0FFFFh
		mov	word ptr ss:[si+2],0FFFFh
		mov	word ptr ss:[si+4],0FFFFh
		xor	ax,ax
		retn
loc_101:
		pushf
		cli
		mov	dx,3
		in	al,dx			; port 3, DMA-1 bas&cnt ch 1
		mov	cl,al
		in	al,dx			; port 3, DMA-1 bas&cnt ch 1
		mov	ch,al
		mov	dx,cs:data_47
		mov	ax,cs:data_44
		mov	bx,cs:data_43
		popf
		sub	dx,cx
		add	ax,dx
		adc	bx,0
		cmp	cs:data_19,1
		je	loc_105
		cmp	cs:audio_compressed,1
		jne	loc_102
		shr	bx,1
		rcr	ax,1
loc_102:
		cmp	bx,cs:data_56
		jbe	loc_103
		mov	word ptr ss:[si],0FFFFh
		mov	word ptr ss:[si+2],0FFFFh
		mov	word ptr ss:[si+4],0FFFFh
		xor	ax,ax
		retn
loc_103:
		jnz	loc_104
		cmp	ax,cs:data_57
		jbe	loc_104
		mov	word ptr ss:[si],0FFFFh
		mov	word ptr ss:[si+2],0FFFFh
		mov	word ptr ss:[si+4],0FFFFh
		xor	ax,ax
		retn
loc_104:
		cmp	cs:audio_compressed,1
		jne	loc_105
		shl	ax,1
		rcl	bx,1
loc_105:
		mov	ss:[si+2],ax
		mov	ss:[si+4],bx
		mov	ax,cs:data_50
		mov	ss:[si],ax
		xor	ax,ax
		retn
sub_32		endp

sub_33		proc	near
		les	bx,cs:dos_crit_flag_ptr
		mov	al,es:[bx]
		les	bx,cs:indos_flag_ptr
		or	al,es:[bx]
		or	al,cs:in_int_10h
		or	al,cs:in_int_0dh
		or	al,cs:in_int_74h
		retn
sub_33		endp

int_10h_entry	proc	far
		mov	cs:in_int_10h,1
		pushf
		call	cs:orig_int_10h
		mov	cs:in_int_10h,0
		iret
int_10h_entry	endp

int_0Dh_entry	proc	far
		mov	cs:in_int_0dh,1
		pushf
		call	cs:orig_int_0dh
		mov	cs:in_int_0dh,0
		iret
int_0Dh_entry	endp

int_74h_entry	proc	far
		mov	cs:in_int_74h,1
		pushf
		call	cs:orig_int_74h
		mov	cs:in_int_74h,0
		iret
int_74h_entry	endp

sub_34		proc	near
		cmp	word ptr ss:[si],0
		je	loc_106
		mov	ax,ss:[si]
		mov	cs:sb_io_base,ax
		jmp	short loc_107
loc_106:
		mov	cs:sb_io_base,220h
loc_107:
		call	sub_35
		or	ax,ax
		jz	loc_108
		xor	ax,ax
		retn
loc_108:
		mov	cs:data_34,1
		cmp	byte ptr cs:must_detect_mscdex,0CDh
		jne	loc_110
		mov	ah,19h
		int	21h			; DOS Services  ah=function 19h
						;  get default drive al  (0=a:)
		xor	ah,ah
		mov	cx,ax
		mov	bx,0
		mov	ax,150Bh
		int	2Fh			; CD ROM extensions
						;*  undocumented function
		cmp	bx,0ADADh
		je	loc_109
		xor	ax,ax
		retn
loc_109:
;*		cmp	ax,0
		db	 3Dh, 00h, 00h
		jnz	loc_110
		xor	ax,ax
		retn
loc_110:
		mov	ah,35h			; '5'
		mov	al,10h
		int	21h			; DOS Services  ah=function 35h
						;  get intrpt vector al in es:bx
		mov	word ptr cs:orig_int_10h,bx
		mov	word ptr cs:orig_int_10h+2,es
		push	ds
		mov	dx,offset int_10h_entry
		mov	ax,cs
		mov	ds,ax
		mov	ah,25h			; '%'
		mov	al,10h
		int	21h			; DOS Services  ah=function 25h
						;  set intrpt vector al to ds:dx
		pop	ds
		mov	ah,35h			; '5'
		mov	al,0Dh
		int	21h			; DOS Services  ah=function 35h
						;  get intrpt vector al in es:bx
		mov	word ptr cs:orig_int_0dh,bx
		mov	word ptr cs:orig_int_0dh+2,es
		push	ds
		mov	dx,offset int_0Dh_entry
		mov	ax,cs
		mov	ds,ax
		mov	ah,25h			; '%'
		mov	al,0Dh
		int	21h			; DOS Services  ah=function 25h
						;  set intrpt vector al to ds:dx
		pop	ds
		mov	ah,35h			; '5'
		mov	al,74h			; 't'
		int	21h			; DOS Services  ah=function 35h
						;  get intrpt vector al in es:bx
		mov	word ptr cs:orig_int_74h,bx
		mov	word ptr cs:orig_int_74h+2,es
		push	ds
		mov	dx,offset int_74h_entry
		mov	ax,cs
		mov	ds,ax
		mov	ah,25h			; '%'
		mov	al,74h			; 't'
		int	21h			; DOS Services  ah=function 25h
						;  set intrpt vector al to ds:dx
		pop	ds
		mov	ah,34h              ; dos: get indos flag pointer
		int	21h

		mov	word ptr cs:indos_flag_ptr,bx
		mov	word ptr cs:indos_flag_ptr+2,es
		dec	bx
		mov	word ptr cs:dos_crit_flag_ptr,bx
		mov	word ptr cs:dos_crit_flag_ptr+2,es

		mov	ax,11025                ; 11.025kHz
		mov	cs:sb_freq_set,ax
		call	sb_set_freq
		mov	cs:data_17,0
		mov	cs:data_16,0
		mov	cs:audio_file_handle,0FFFFh
		mov	ax,13CBh
		retn
sub_34		endp

sub_35		proc	near
		call	sub_36
		jnz	loc_ret_111
		call	sub_37
		jnz	loc_ret_111
		call	sub_40
		jnz	loc_ret_111
		call	sub_43
		jnz	loc_ret_111
		call	sub_42
		xor	ax,ax

loc_ret_111:
		retn
sub_35		endp

sub_36		proc	near
		mov	dx,cs:sb_io_base
		add	dl,6
		mov	al,1
		out	dx,al			; port 6, DMA-1 bas&add ch 3
		in	al,dx			; port 6, DMA-1 bas&add ch 3
		in	al,dx			; port 6, DMA-1 bas&add ch 3
		in	al,dx			; port 6, DMA-1 bas&add ch 3
		in	al,dx			; port 6, DMA-1 bas&add ch 3
		sub	al,al
		out	dx,al			; port 6, DMA-1 bas&add ch 3
		mov	cx,20h

locloop_112:
		call	sub_39
		cmp	al,0AAh
		je	loc_113
		loop	locloop_112

		mov	ax,2
		jmp	short loc_114
loc_113:
		xor	ax,ax
loc_114:
		or	ax,ax
		retn
sub_36		endp

sub_37		proc	near
		mov	al,0E0h
		mov	dx,cs:sb_io_base
		add	dx,0Ch
		call	sub_38
		jc	loc_115
		mov	al,0AAh
		call	sub_38
		jc	loc_115
		call	sub_39
		jc	loc_115
		cmp	al,55h			; 'U'
		jne	loc_115
		xor	ax,ax
		retn
loc_115:
		mov	ax,2
		or	ax,ax
		retn
sub_37		endp

sub_38		proc	near
		mov	cx,800h
		mov	ah,al

locloop_116:
		in	al,dx			; port 0Ch ??I/O Non-standard
		or	al,al
		jns	loc_117
		loop	locloop_116

		stc
		jmp	short loc_ret_118
loc_117:
		mov	al,ah
		out	dx,al			; port 0Ch, DMA-1 clr byte ptr
		clc

loc_ret_118:
		retn
sub_38		endp

sub_39		proc	near
		push	dx
		push	cx
		mov	dx,cs:sb_io_base
		add	dl,0Eh
		mov	cx,800h

locloop_119:
		in	al,dx			; port 0Eh ??I/O Non-standard
		or	al,al
		js	loc_120
		loop	locloop_119

		stc
		jmp	short loc_121
loc_120:
		sub	dl,4
		in	al,dx			; port 0Ah ??I/O Non-standard
		clc
loc_121:
		pop	cx
		pop	dx
		retn
sub_39		endp

sub_40		proc	near
		mov	al,0E1h
		mov	dx,cs:sb_io_base
		add	dl,0Ch
		call	dsp_write
		call	sub_41
		mov	ah,al
		call	sub_41
		cmp	ax,101h
		jl	loc_124
		cmp	ax,200h
		jl	loc_122
		mov	cs:data_8,1
		jmp	short loc_123
loc_122:
		mov	cs:data_8,0
loc_123:
		xor	ax,ax
		jmp	short loc_125
loc_124:
		mov	ax,1
loc_125:
		or	ax,ax
		retn
sub_40		endp

sub_41		proc	near
		push	dx
		mov	dx,cs:sb_io_base
		add	dl,0Eh
		sub	al,al
loc_126:
		in	al,dx			; port 0Eh ??I/O Non-standard
		or	al,al
		jns	loc_126
		sub	dl,4
		in	al,dx			; port 0Ah ??I/O Non-standard
		pop	dx
		retn
sub_41		endp

sub_42		proc	near
		mov	dx,cs:sb_io_base
		add	dx,0Ch
		mov	al,0D1h
		call	dsp_write
		retn
sub_42		endp

data_89		dw	0, 0
data_90		db	0
		db	0, 0, 0
data_91		db	0
		db	0, 0, 0
data_92		db	0
		db	0, 0, 0

sub_43		proc	near
		mov	al,2
		mov	dx,167Dh
		mov	bx,offset data_89
		call	sub_20
		mov	al,3
		mov	dx,1685h
		mov	bx,offset data_90
		call	sub_20
		mov	al,5
		mov	dx,168Dh
		mov	bx,offset data_91
		call	sub_20
		mov	al,7
		mov	dx,1695h
		mov	bx,offset data_92
		call	sub_20
		mov	dx,cs
		mov	ax,9Eh
		call	sub_16
		xor	cx,cx
		mov	dh,49h			; 'I'
		call	sub_44
		mov	dx,cs:sb_io_base
		add	dx,0Ch
		mov	al,40h			; '@'
		call	dsp_write
		mov	al,64h			; 'd'
		call	dsp_write
		mov	al,14h
		call	dsp_write
		xor	al,al
		call	dsp_write
		xor	al,al
		call	dsp_write
		mov	cx,800h
		mov	cs:data_20,0

locloop_127:
		cmp	cs:data_20,0
		jne	loc_128
		loop	locloop_127

		mov	ax,3
		jmp	short loc_129
loc_128:
		xor	ax,ax
loc_129:
		push	ax
		mov	al,2
		mov	bx,offset data_89
		call	sub_21
		mov	al,3
		mov	bx,offset data_90
		call	sub_21
		mov	al,5
		mov	bx,offset data_91
		call	sub_21
		mov	al,7
		mov	bx,offset data_92
		call	sub_21
		pop	ax
		or	ax,ax
		retn
sub_43		endp

sub_44		proc	near
		push	bx
		mov	bx,ax
		mov	al,5
		out	0Ah,al			; port 0Ah, DMA-1 mask reg bit
		sub	al,al
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
sub_44		endp

			                        ;* No entry point to code
		push	dx
		mov	dl,2
		call	sub_45
		pop	dx
		iret
			                        ;* No entry point to code
		push	dx
		mov	dl,3
		call	sub_45
		pop	dx
		iret
			                        ;* No entry point to code
		push	dx
		mov	dl,5
		call	sub_45
		pop	dx
		iret
			                        ;* No entry point to code
		push	dx
		mov	dl,7
		call	sub_45
		pop	dx
		iret

sub_45		proc	near
		push	ds
		push	ax
		mov	ax,cs
		mov	ds,ax
		mov	cs:data_20,dl
		mov	dx,cs:sb_io_base
		add	dx,0Eh
		in	al,dx			; port 0Eh ??I/O Non-standard
		mov	al,20h			; ' '
		out	20h,al			; port 20h, 8259-1 int command
						;  al = 20h, end of interrupt
		pop	ax
		pop	ds
		retn
sub_45		endp

must_detect_mscdex db	0DCh

seg_a		ends
		end	start

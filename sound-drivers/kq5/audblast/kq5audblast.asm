; vim:set ts=8:

include ../../common/sb.inc
include ../../common/dma.inc

seg_a		segment	byte public
		assume	cs:seg_a, ds:seg_a

		org	0

start:
		jmp	short entry
		db	 00h, 00h, 21h, 43h, 65h, 87h
		db	 02h
		db	 8, 'a', 'u', 'd', 'b', 'l', 'a', 's', 't'
                db      17, 'CMS Sound Blaster'
		db	 98h,0BAh,0DCh,0FEh, 04h, 00h
		db	0, 0
flag_cd_audio	db	0               ; XXX guess, but seems 1 if playing audio from a file?
data_5		db	0               ; must be 1 for auto-init dma
sb_which_buffer	db	0
sb_irq		db	0
data_8		db	0
data_9		db	0
pit_imr		db	0               ; PIT interrupt mask register
playback_stopped	db	0
playback_paused		db	0       ; note: never set to non-zero
buf0_dma_page	db	0
buf1_dma_page		db	0
sb_buf_dma_page	db	0
sb_dsp_200	db	0               ; non-zero if SB DSP version is >= 2.0
data_17		db	0               ; must be 1 for auto-init dma
is_playing	db	0
data_19		db	0
buf0_dma_size	dw	0
buf0_dma_addr	dw	0
buf1_dma_size	dw	0
buf1_dma_addr	dw	0
audio_data_len	dw	0               ;; XXX I think this belongs to audio_data_seg
sb_io_base	dw	0               ; 220h
sb_buf_dma_addr	dw	0               ; current buffer
sb_buf_dma_size	dw	0               ; current buffer
sb_buf_dma_active_size	dw	0       ; how many bytes are we DMA-ing
data_29		dw	0               ;; XXX data_29 + data_30 seem to be some position/length ...
data_30		dw	0
sb_cur_freq	dw	0
sb_freq_set		dw	0
audio_file_handle	dw	0
sb_prev_irq	dd      0

data_35		dw	offset fn_init              ;  0 initialize
                dw	offset fn_status            ;  1 status
                dw	offset fn_terminate         ;  2 terminate
                dw	offset fn_play_memory       ;  3 memplay
                dw	offset fn_memcheck          ;  4 memcheck
                dw	offset fn_memstop           ;  5 memstop
                dw	offset fn_set_rate          ;  6 rate
                dw	offset fn_pause             ;  7 pause
                dw	offset fn_resume            ;  8 resume
                dw	offset fn_select            ;  9 select
                dw	offset sub_24               ; 10 wplay
                dw	offset fn_play              ; 11 play
                dw	offset stop_playing         ; 12 stop
                dw	offset fn_loc               ; 13 loc
                dw	offset fn_volume            ; 14 volume
                dw	offset fn_fillbuff          ; 15 fillbuff

entry:
		push	ds
		mov	bx,ax
		shl	bx,1
		mov	ax,cs
		mov	ds,ax
		call	word ptr cs:data_35[bx]	;*16 entries
		pop	ds
		or	ax,ax
		retf

fn_status	proc	near
		cmp	cs:playback_stopped,1
		je	loc_3

		cmp	cs:data_5,1
		jne	loc_3
		cmp	cs:playback_paused,0
		jne	loc_2
		call	sub_28
loc_2:
		call	process_audio_data
loc_3:
		xor	ax,ax
		ret
fn_status	endp

fn_fillbuff	proc	near
		ret
fn_fillbuff	endp

; ss:si = arg
; 00h    word    sample rate (Hz)
fn_set_rate     proc	near
		mov	ax,ss:[si]
		mov	cs:sb_freq_set,ax
		call	sb_set_freq
		xor	ax,ax
		ret
fn_set_rate     endp

fn_pause	proc	near
                ; I think the 'ret' is a debugging leftover...
		ret

		mov	cs:playback_paused,1
		xor	ax,ax
		ret
fn_pause        endp

fn_resume	proc	near
		mov	cs:playback_paused,0
		xor	ax,ax
		ret
fn_resume	endp


stop_playing	proc	near
		cmp	cs:playback_stopped,1
		je	loc_4
		mov	cs:playback_stopped,1

		call	sb_pause
		call	mask_dma1

		mov	al,cs:sb_irq
		mov	bx,offset sb_prev_irq
		call	unhook_irq
loc_4:
		xor	ax,ax
		ret
stop_playing	endp


; ss:si = buffer
; 00h   word    ????
; 02h   word    sample rate (Hz)
; 04h   ptr     sample data
; 08h   word    length
fn_play_memory  proc	near
		push	si
		call	stop_playing
		pop	si
		mov	ax,ss:[si]
		or	ah,ah
		jnz	loc_5
		mov	cs:data_9,0
		jmp	short loc_6
loc_5:
		mov	cs:data_9,1
loc_6:
		mov	ax,ss:[si+2]
		call	sb_set_freq
		mov	ax,ss:[si+4]
		mov	dx,ss:[si+6]
		call	dma_convert_address
		mov	cs:buf0_dma_page,dl
		mov	cs:buf0_dma_addr,ax
		mov	ax,ss:[si+8]
		mov	cs:audio_data_len,ax
		mov	cs:buf0_dma_size,ax
		mov	al,cs:sb_irq
		mov	dx,offset sb_irq_handler
		mov	bx,offset sb_prev_irq
		call	hook_irq
		mov	cs:sb_which_buffer,0
		mov	cs:data_5,0
		mov	cs:is_playing,1
		call	play_buffer
		mov	cs:playback_stopped,0
		mov	cs:data_8,0
		ret
fn_play_memory  endp

fn_memcheck	proc	near
		mov	ax,ss:[si]
		or	ah,ah
		jnz	loc_7
		mov	cs:data_9,0
		jmp	short loc_8
loc_7:
		mov	cs:data_9,1
loc_8:
		mov	al,cs:playback_stopped
		mov	ah,cs:data_8
		mov	cs:data_8,0
		ret
fn_memcheck	endp


fn_memstop	proc	near
		call	stop_playing
		ret
fn_memstop	endp

fn_terminate	proc	near
		call	stop_playing
		cmp	cs:flag_cd_audio,1
		jne	loc_9

		push	ds
		lds	dx,cs:orig_int_10h
		mov	ah,25h			; dos: set interrupt vector 10h
		mov	al,10h
		int	21h
		pop	ds

		push	ds
		lds	dx,cs:orig_int_33h
		mov	ah,25h			; dos: set interrupt vector 33h
		mov	al,33h
		int	21h
		pop	ds
		cmp	cs:audio_file_handle,0FFFFh
		je	loc_9

		mov	bx,cs:audio_file_handle
		mov	ah,3Eh                  ; dos: close file
		int	21h
		mov	cs:audio_file_handle,0FFFFh
loc_9:
		xor	ax,ax
		ret
fn_terminate	endp

; pick which buffer to play and initializes playback
play_buffer	proc	near
		cmp	cs:sb_which_buffer,0
		jne	loc_10
                ; buffer 0
		mov	dl,cs:buf0_dma_page
		mov	ax,cs:buf0_dma_addr
		mov	cx,cs:buf0_dma_size
		jmp	short loc_11
loc_10:         ; buffer 1
		mov	dl,cs:buf1_dma_page
		mov	ax,cs:buf1_dma_addr
		mov	cx,cs:buf1_dma_size
loc_11:
		mov	cs:sb_buf_dma_size,cx
		mov	cs:sb_buf_dma_page,dl
		mov	cs:sb_buf_dma_addr,ax
		cmp	cs:data_5,1
		jne	loc_13
		cmp	cs:data_17,1
		jne	loc_13
		cmp	cs:is_playing,0
		jne	loc_12
		ret
loc_12:
		mov	cs:is_playing,0
loc_13:
		call	sb_play
		ret
play_buffer	endp


; sets up DMA for sb_buf_dma_* and starts playback
sb_play		proc	near
		mov	al,5
		out	DMA_CH1_MASK1,al
		xor	al,al
		out	DMA_CH1_RESET_FF,al
		mov	ax,cs:sb_buf_dma_addr
		out	DMA_CH1_ADDR_BASE,al
		mov	al,ah
		out	DMA_CH1_ADDR_BASE,al
		mov	al,49h			; mode: ch1, write to device, single transfer, no auto-init
		mov	cx,cs:sb_buf_dma_size
		cmp	cs:data_5,1
		jne	loc_14
		cmp	cs:data_17,1
		jne	loc_14
		mov	al,59h			; mode: ch1, write to device, single transfer, auto-init
		shl	cx,1
loc_14:
		mov	cs:sb_buf_dma_active_size,cx
		out	DMA_CH1_MODE,al
		mov	al,cs:sb_buf_dma_page
		out	DMA_CH1_PAGE_ADDR,al
		mov	ax,cx
		dec	ax
		out	DMA_CH1_COUNT,al
		mov	al,ah
		out	DMA_CH1_COUNT,al
		mov	al,1
		out	DMA_CH1_MASK1,al

		mov	dx,cs:sb_io_base
		add	dl,DSP_PORT_DATACMD_W
		cmp	cs:data_5,1
		jne	loc_15
		cmp	cs:data_17,1
		jne	loc_15
		mov	al,DSP_CMD_OUTPUT_8BIT_AUTOINIT_DMA
		call	dsp_write
		ret
loc_15:
		mov	al,DSP_CMD_OUTPUT_8BIT_SINGECYCLE_DMA
		call	dsp_write
		mov	cx,cs:sb_buf_dma_size
		dec	cx
		mov	al,cl
		call	dsp_write
		mov	al,ch
		call	dsp_write
		ret
sb_play		endp

mask_dma1	proc	near
		mov	al,5                    ; mask dma1
		out	DMA_CH1_MASK1,al
		mov	dx,cs:sb_io_base
		add	dl,DSP_PORT_RDBUF_R
		in	al,dx
		ret
mask_dma1	endp

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
		cmp	cs:data_5,1
		jne	loc_20
		cmp	cs:data_17,1
		jne	loc_17
		xor	cs:data_19,1
		jnz	loc_16
		mov	ax,cs:sb_buf_dma_size
		shl	ax,1
		add	cs:data_29,ax
		adc	cs:data_30,0
loc_16:
		jmp	short loc_18
loc_17:
		mov	ax,cs:sb_buf_dma_size
		add	cs:data_29,ax
		adc	cs:data_30,0
		call	mask_dma1
loc_18:
		cmp	cs:playback_stopped,1
		je	loc_19
		call	sub_27
loc_19:
		jmp	short loc_22
loc_20:
		cmp	cs:data_9,1
		jne	loc_21
		call	play_buffer
		mov	cs:data_8,1
		jmp	short loc_22
loc_21:
		call	fn_memstop
loc_22:
		mov	dx,cs:sb_io_base
		add	dl,DSP_PORT_RDBUF_R
		in	al,dx

		mov	al,20h                  ; eoi
		out	20h,al

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
		div	cx                      ; ax = 1'000'000 / ax
		mov	cl,al
		neg	cl
		mov	dx,cs:sb_io_base
		add	dl,0Ch
		mov	al,DSP_CMD_SET_TIME_CONSTANT
		call	dsp_write
		mov	al,cl
		call	dsp_write
		ret
sb_set_freq	endp


; only used in auto-init DMA mode
sb_set_dma_transfer_size		proc	near
		push	ax
		push	cx
		push	dx
		mov	cx,ax
		mov	dx,cs:sb_io_base
		add	dl,0Ch
		mov	al,DSP_CMD_SET_BLOCK_TRANSFER_SIZE
		call	dsp_write
		mov	al,cl
		call	dsp_write
		mov	al,ch
		call	dsp_write
		pop	dx
		pop	cx
		pop	ax
		ret
sb_set_dma_transfer_size		endp


; converts pointer dx:ax to a linear address in dl:ax
dma_convert_address	proc	near
		push	cx
		mov	cl,4
		rol	dx,cl
		mov	cx,dx
		and	dx,0Fh
		and	cx,0FFF0h
		add	ax,cx
		adc	dx,0
		pop	cx
		ret
dma_convert_address	endp

; pauses 8 bit audio
sb_pause	proc	near
		mov	dx,cs:sb_io_base
		add	dl,0Ch
		mov	al,DSP_CMD_PAUSE_8BIT_SOUND
		call	dsp_write
loc_23:
		in	al,dx
		or	al,al
		js	loc_23
		ret
sb_pause	endp

; resumes 8 bit audio
sb_resume	proc	near
		mov	dx,cs:sb_io_base
		add	dl,0Ch
		mov	al,DSP_CMD_CONTINUE_8BIT_SOUND
		call	dsp_write
loc_24:
		in	al,dx
		or	al,al
		js	loc_24
		ret
sb_resume	endp

; notes: expects dx = sb_io_base + DSP_PORT_WRBUF_R (0Ch)
dsp_write	proc	near
		mov	ah,al
		mov	al,0F0h
loc_25:
		in	al,dx
		or	al,al
		js	loc_25
		mov	al,ah
		out	dx,al
		ret
dsp_write	endp

; hooks irq in [al] to cs:[dx] - old vector stored in cs:[bx] 
; IRQ will be unmasked in the PIC as well
hook_irq	proc	near
		push	bx
		push	cx
		push	dx
		cli
		mov	cl,al
		add	al,8
		cbw
		shl	al,1
		shl	al,1                    ; ax = (al + 8) * 4
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
		mov	cs:pit_imr,al
		and	al,ah
		out	21h,al			; port 21h, 8259-1 int comands
		sti
		pop	dx
		pop	cx
		pop	bx
		ret
hook_irq	endp

; restores irq [al] to vector in cs:[bx]
unhook_irq	proc	near
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
		mov	al,cs:pit_imr
		out	21h,al			; port 21h, 8259-1 int comands
		sti
		ret
unhook_irq	endp

;; ----- code/data below can be discarded after initialization (1) ------------
data_51		db	0, 01h, 02h, 03h, 06h, 0Ah, 0Fh, 15h
data_52		db	0
in_int_33h	db	0
in_int_10h	db	0
data_55		db	0
processing_audio	db	0       ; used to prevent reentrent calls to process_audio_data
data_57		db	0
audio_rotated		db	0       ; non-zero if all bytes must be rol1'ed
audio_compressed	db	0       ; non-zero if audio is compressed
data_60		db	0
data_61		db	0
data_62		db	0
audio_data_seg	dw	0
data_64		dw	0
data_65		dw	0
dos_crit_flag_ptr	dd	00000h  ; dos critical error flag pointer
indos_flag_ptr	dd	00000h          ; indos pointer
orig_int_10h	dd	00000h
orig_int_33h		dd	00000h

fn_volume	proc	near
		xor	ax,ax
		ret
fn_volume	endp


;; XXX selects the audio file to use ???
; ss:si = buffer
;   00h pointer         audio file path, or 0 to re-use current
;   04h dword           offset in audio file
;   08h uint16_t        data_65
;   0ah uint16_t        data_64
;   0ch uint16_t        audio offset ???
;   0eh uint16_t        audio_data_seg
;   10h uint16_t        audio data length
;   12h uint16_t        flag: audio_compressed
;   14h uint16_t        flag: audio_rotated
;
fn_select	proc	near
		push	si
		call	stop_playing
		pop	si
		mov	ax,ss:[si+14h]
		or	al,ah
		jz	loc_26
		mov	cs:audio_rotated,1
		jmp	short loc_27
loc_26:
		mov	cs:audio_rotated,0
loc_27:
		mov	ax,ss:[si+12h]
		or	al,ah
		jz	loc_28
		mov	cs:audio_compressed,1
		jmp	short loc_29
loc_28:
		mov	cs:audio_compressed,0
loc_29:
		mov	cs:data_60,80h
		mov	ax,ss:[si+8]
		mov	cs:data_65,ax
		mov	ax,ss:[si+0Ah]
		mov	cs:data_64,ax
		mov	ax,ss:[si+0Ch]
		mov	dx,ss:[si+0Eh]
		mov	cs:audio_data_seg,dx
		call	dma_convert_address
		mov	cs:buf0_dma_page,dl
		mov	cs:buf1_dma_page,dl
		mov	cs:buf0_dma_addr,ax
		mov	ax,ss:[si+10h]
		shr	ax,1
		mov	cs:audio_data_len,ax
		cmp	cs:sb_dsp_200,1
		jne	loc_30

                ; dsp >= 2.00
		mov	cs:data_17,1
		push	ax
		call	sb_set_dma_transfer_size
		mov	cs:data_19,0
		pop	ax
		jmp	short loc_31
loc_30:
                ; dsp < 2.00
		mov	cs:data_17,0
loc_31:
		add	ax,cs:buf0_dma_addr
		mov	cs:buf1_dma_addr,ax
		jnc	loc_32
		inc	cs:buf1_dma_page
loc_32:
		mov	ax,ss:[si]
		or	ax,ss:[si+2]            ; ss:si = pointer to file name
		jnz	loc_33
		mov	bx,cs:audio_file_handle
		jmp	short loc_36
loc_33:
		cmp	cs:audio_file_handle,0FFFFh
		je	loc_34

		mov	bx,cs:audio_file_handle
		mov	ah,3Eh                  ; dos: close handle
		int	21h
		mov	cs:audio_file_handle,0FFFFh

loc_34:
		push	ds
		mov	dx,ss:[si]
		mov	ax,ss:[si+2]
		mov	ds,ax                   ; ds:dx = filename
		mov	al,0
		mov	ah,3Dh                  ; dos: open file
		int	21h
		pop	ds
		jnc	loc_35

                ; unable to open file
		mov	ax,0FFFFh
		ret
loc_35:
		mov	bx,ax
		mov	cs:audio_file_handle,bx
loc_36:
		mov	dx,ss:[si+4]
		mov	cx,ss:[si+6]
		mov	al,0                    ; start of file
		mov	ah,42h                  ; dos: seek in file
		int	21h
		jnc	loc_37

                ; unable to seek in file
		mov	ax,0FFFFh
		ret

loc_37:         ; success
		mov	cs:data_57,0
		xor	ax,ax
		ret
fn_select	endp


sub_24		proc	near
		mov	cs:data_57,1
		mov	cs:sb_which_buffer,0FFh
		mov	cs:data_52,0

                ; call twice to fill both buffers?
		call	process_audio_data
		call	process_audio_data
		jnz	loc_38
		mov	cs:data_17,0
loc_38:
		xor	ax,ax
		ret
sub_24		endp

fn_play		proc	near
		mov	al,cs:sb_irq
		mov	dx,offset sb_irq_handler
		mov	bx,offset sb_prev_irq
		call	hook_irq

		mov	ax,cs:sb_freq_set
		cmp	ax,cs:sb_cur_freq
		je	loc_39
		call	sb_set_freq
loc_39:
		mov	cs:data_5,1
		mov	cs:data_61,1
		cmp	cs:data_57,1
		je	loc_41

		mov	cs:sb_which_buffer,0FFh
		mov	cs:data_52,0
		call	process_audio_data
		call	process_audio_data
		jnz	loc_40
		mov	cs:data_17,0
loc_40:
		jmp	short loc_42
loc_41:
		mov	cs:data_57,0
loc_42:
		mov	cs:sb_which_buffer,1
		mov	cs:data_29,0
		mov	cs:data_30,0
		mov	cs:is_playing,1
		mov	cs:data_62,0
		mov	al,cs:data_52
		push	ax
		mov	cs:data_52,0FFh
		call	sub_28
		pop	ax
		mov	cs:data_52,al
		mov	cs:playback_paused,0
		mov	cs:playback_stopped,0
		xor	ax,ax
		ret
fn_play		endp

; I wonder if this decompresses CD speech data??
process_audio_data		proc	near
		cmp	cs:processing_audio,1
		je	loc_43

		mov	ax,cs:data_65
		or	ax,cs:data_64
		jz	loc_43

		mov	al,cs:data_52
		cmp	al,cs:sb_which_buffer
		je	loc_43

		call	is_busy
		jz	loc_44
loc_43:
		xor	ax,ax
		ret

loc_44:         ; do the actual work
		mov	cs:processing_audio,1
		sti
		mov	bx,cs:audio_file_handle
		mov	ax,cs:audio_data_seg
		mov	cx,cs:audio_data_len
		cmp	cs:data_52,0
		jne	loc_45
		mov	dx,0
		jmp	short loc_46
loc_45:
		mov	dx,cx
loc_46:
		cmp	cs:audio_compressed,1
		jne	loc_47
		shr	cx,1
loc_47:
		cmp	cs:data_64,0
		jne	loc_50
		cmp	cx,cs:data_65
		jbe	loc_50
		cmp	cs:data_17,1
		jne	loc_49
		sub	cx,cs:data_65
		mov	es,ax
		mov	di,dx
		add	di,cs:data_65
		cmp	cs:audio_compressed,1
		jne	loc_48
		add	di,cs:data_65

loc_48:         ; fill buffer with 8-bit silence
		push	ax
		mov	ax,80h
		rep	stosb
		pop	ax
loc_49:
		mov	cx,cs:data_65
loc_50:
		sub	cs:data_65,cx
		sbb	cs:data_64,0
		mov	di,dx
		cmp	cs:audio_compressed,1
		jne	loc_51
		add	dx,cx
loc_51:
		mov	si,dx
		push	ds
		mov	ds,ax
		mov	ah,3Fh                  ; dos: read from file
		int	21h
		pop	ds
		jnc	loc_52
		mov	ax,cx                   ; ax = number of bytes read?
loc_52:
		cmp	cs:audio_rotated,1
		jne	loc_54

		push	ax
		push	si
		push	di
		push	ds
		mov	cx,ax
		mov	ax,cs:audio_data_seg
		mov	ds,ax
		mov	es,ax

locloop_53:
		lodsb
		rol	ax,1
		stosb
		loop	locloop_53

		pop	ds
		pop	di
		pop	si
		pop	ax
loc_54:
		cmp	cs:audio_compressed,1
		jne	loc_60

		push	ax
		push	ds
		mov	cx,ax
		mov	dl,cs:data_60
		mov	ax,cs:audio_data_seg
		mov	ds,ax
		mov	es,ax
		mov	ah,dl               ; ah = data_60 = previous pcm value?

locloop_55:
		lodsb
		mov	dl,al
		shr	al,1
		shr	al,1
		shr	al,1
		shr	al,1                ; al = result >> 4
		cmp	al,8
		jl	loc_56

                ; al > 8 ...
		mov	bx,15
		sub	bl,al
		sub	ah,cs:data_51[bx]   ; ah = data_60 - data_51[15 - al]
		jmp	short loc_57

loc_56:         ; al < 8 ...
		mov	bl,al
		xor	bh,bh
		add	ah,cs:data_51[bx]   ; ah = data_60 + data_51[al]
loc_57:
		mov	al,ah
		stosb
		and	dl,0Fh
		cmp	dl,8
		jl	loc_58

                ; (dl & 0fh) >= 8
		mov	bx,15
		sub	bl,dl
		sub	ah,cs:data_51[bx]
		jmp	short loc_59
loc_58:
                ; (dl & 0fh) < 8
		mov	bl,dl
		xor	bh,bh
		add	ah,cs:data_51[bx]
loc_59:
		mov	al,ah
		stosb
		loop	locloop_55

		pop	ds
		mov	cs:data_60,ah
		pop	ax
		shl	ax,1
loc_60:         ; data decompressed
		cmp	cs:data_52,0
		jne	loc_61
		mov	cs:buf0_dma_size,ax
		jmp	short loc_62
loc_61:
		mov	cs:buf1_dma_size,ax
loc_62:
		xor	cs:data_52,1
		mov	cs:processing_audio,0
		ret
process_audio_data		endp


sub_27		proc	near
		mov	cs:data_61,1
		call	sub_28
		ret
sub_27		endp


sub_28		proc	near
		cmp	cs:data_55,1
		je	loc_ret_68
		cmp	cs:data_61,1
		jne	loc_ret_68
		mov	cs:data_55,1
		mov	al,cs:sb_which_buffer
		xor	al,1
		cmp	al,cs:data_52
		jne	loc_65
		mov	ax,cs:data_65
		or	ax,cs:data_64
		jnz	loc_63
		call	stop_playing
		jmp	short loc_64
loc_63:
		cmp	cs:data_17,1
		jne	loc_64
		cmp	cs:data_62,0
		jne	loc_64
		mov	cs:data_62,1
		call	sb_pause
loc_64:
		jmp	short loc_67
loc_65:
		cmp	cs:data_62,1
		jne	loc_66
		call	sb_resume
		mov	cs:data_62,0
loc_66:
		mov	cs:data_61,0
		xor	cs:sb_which_buffer,1
		call	play_buffer
		mov	ax,cs:data_65
		or	ax,cs:data_64
		jnz	loc_67
		call	clear_audio_buffer
loc_67:
		mov	cs:data_55,0

loc_ret_68:
		ret
sub_28		endp


clear_audio_buffer	proc	near
		cmp	cs:data_52,0FFh
		jne	loc_69
		ret
loc_69:
		mov	cx,cs:audio_data_len
		cmp	cs:sb_which_buffer,0
		jne	loc_70
		mov	di,cx
		jmp	short loc_71
loc_70:
		mov	di,0
loc_71:
		mov	ax,cs:audio_data_seg
		mov	es,ax

		mov	ax,80h
		rep	stosb
		ret
clear_audio_buffer	endp


; ss:si = buffer
; +0    word   ticks (calculated from bytes)
; +2    dword  bytes
;
; the tick-count seems to be 60Hz
fn_loc		proc	near
		cmp	cs:data_57,1
		jne	loc_72
		mov	word ptr ss:[si],0
		mov	word ptr ss:[si+2],0
		mov	word ptr ss:[si+4],0
		xor	ax,ax
		ret
loc_72:
		cmp	cs:playback_stopped,1
		jne	loc_73
		mov	word ptr ss:[si],0FFFFh
		mov	word ptr ss:[si+2],0FFFFh
		mov	word ptr ss:[si+4],0FFFFh
		xor	ax,ax
		ret
loc_73:
		pushf
		cli
		mov	dx,DMA_CH1_COUNT
		in	al,dx
		mov	cl,al
		in	al,dx
		mov	ch,al               ; cx = dma 1 count
		mov	dx,cs:sb_buf_dma_active_size
		mov	ax,cs:data_29
		mov	bx,cs:data_30
		popf

		sub	dx,cx
		add	ax,dx
		adc	bx,0
		mov	ss:[si+2],ax
		mov	ss:[si+4],bx
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
		jae	loc_74
		div	cs:sb_cur_freq
		jmp	short loc_75
loc_74:
		mov	ax,0FFFEh
loc_75:
		mov	ss:[si],ax
		xor	ax,ax
		ret
fn_loc		endp

; checks the indos flag, critical error flag and whether we are currenly
; executing int 10h / int 33h (mouse) code
is_busy		proc	near
		les	bx,cs:dos_crit_flag_ptr
		mov	al,es:[bx]
		les	bx,cs:indos_flag_ptr
		or	al,es:[bx]
		or	al,cs:in_int_10h
		or	al,cs:in_int_33h
		ret
is_busy		endp

int_10h_entry	proc	far
		mov	cs:in_int_10h,1
		pushf
		call	cs:orig_int_10h
		mov	cs:in_int_10h,0
		iret
int_10h_entry	endp

int_33h_entry	proc	far
		mov	cs:in_int_33h,1
		pushf
		call	cs:orig_int_33h
		mov	cs:in_int_33h,0
		iret
int_33h_entry	endp

;; ----- code/data below can be discarded after initialization (2) ------------

; called with a buffer in ss:[si]:
; - uint16_t io_base = 0;
; - uint16_t flag_cd_audio = 0;
fn_init		proc	near
		cmp	word ptr ss:[si],0
		je	loc_76
		mov	ax,ss:[si]
		mov	cs:sb_io_base,ax
		jmp	short loc_77
loc_76:
		mov	cs:sb_io_base,220h
loc_77:
		cmp	word ptr ss:[si+2],0
		jne	loc_78
		mov	cs:flag_cd_audio,0
		jmp	short loc_79
loc_78:
		mov	cs:flag_cd_audio,1
loc_79:
		call	sb_init
		or	ax,ax
		jz	loc_80

                ; initialization failed
		xor	ax,ax
		ret

loc_80:         ; initialization successful
		mov	cs:playback_stopped,1
		cmp	cs:flag_cd_audio,1
		je	loc_81

                ; discard more stuff if not using CD audio
		mov	ax,offset data_51
		ret

loc_81:         ; extra initialization
		cmp	byte ptr cs:must_detect_mscdex,0CDh
		jne	loc_83

		mov	ah,19h                  ; dos: get current drive (in al)
		int	21h

		xor	ah,ah
		mov	cx,ax
		mov	bx,0
		mov	ax,150Bh                ; cdrom: drive check
		int	2Fh
		cmp	bx,0ADADh               ; mscdex signature
		je	loc_82

                ; mscdex not installed
		xor	ax,ax
		ret
loc_82:
;*		cmp	ax,0
		db	 3Dh, 00h, 00h
		jnz	loc_83

                ; drive not suported
		xor	ax,ax
		ret

loc_83:
		mov	ah,35h              ; dos: get interrupt vector 10h
		mov	al,10h
		int	21h
		mov	word ptr cs:orig_int_10h,bx
		mov	word ptr cs:orig_int_10h+2,es
		push	ds
		mov	dx,offset int_10h_entry
		mov	ax,cs
		mov	ds,ax
		mov	ah,25h              ; dos: set interrupt vector 10h
		mov	al,10h
		int	21h

		pop	ds
		mov	ah,35h              ; dos: get interrupt vector 33h
		mov	al,33h
		int	21h

		mov	word ptr cs:orig_int_33h,bx
		mov	word ptr cs:orig_int_33h+2,es
		push	ds
		mov	dx,offset int_33h_entry
		mov	ax,cs
		mov	ds,ax
		mov	ah,25h              ; dos: set interrupt vector 33h
		mov	al,33h
		int	21h

		pop	ds
		mov	ah,34h              ; dos: get indos flag pointer
		int	21h

		mov	word ptr cs:indos_flag_ptr,bx
		mov	word ptr cs:indos_flag_ptr+2,es
		dec	bx
		mov	word ptr cs:dos_crit_flag_ptr,bx
		mov	word ptr cs:dos_crit_flag_ptr+2,es

                ;
		mov	ax,11025                ; 11025Hz
		mov	cs:sb_freq_set,ax
		call	sb_set_freq
		mov	cs:processing_audio,0
		mov	cs:data_55,0
		mov	cs:audio_file_handle,0FFFFh
		mov	ax,offset fn_init
		ret
fn_init		endp

; on success, zf=1 ax=0 otherwise zf=0 and ax contains an error code
sb_init		proc	near
		call	dsp_reset
		jnz	loc_ret_84
		call	dsp_sanity_check
		jnz	loc_ret_84
		call	sb_check_dsp_ver
		jnz	loc_ret_84
		call	sb_detect_irq
		jnz	loc_ret_84
		call	sb_speaker_on
		xor	ax,ax

loc_ret_84:
		ret
sb_init		endp

; returns zf=1 on success
dsp_reset	proc	near
		mov	dx,cs:sb_io_base
		add	dl,DSP_PORT_RESET_W
		mov	al,1
		out	dx,al
		in	al,dx
		in	al,dx
		in	al,dx
		in	al,dx
		sub	al,al
		out	dx,al
		mov	cx,20h

locloop_85:
		call	dsp_read_with_timeout
		cmp	al,0AAh
		je	loc_86
		loop	locloop_85

		mov	ax,2
		jmp	short loc_87
loc_86:
		xor	ax,ax
loc_87:
		or	ax,ax
		ret
dsp_reset	endp

; uses the DSP_CMD_ECHO_INVERTED command to check if the DSP is sane
dsp_sanity_check		proc	near
		mov	al,DSP_CMD_ECHO_INVERTED
		mov	dx,cs:sb_io_base
		add	dx,0Ch
		call	dsp_write_with_timeout
		jc	loc_88
		mov	al,0AAh
		call	dsp_write_with_timeout
		jc	loc_88
		call	dsp_read_with_timeout
		jc	loc_88
		cmp	al,55h			; 'U'
		jne	loc_88
		xor	ax,ax
		ret
loc_88:
		mov	ax,2
		or	ax,ax
		ret
dsp_sanity_check		endp


; writes [al] to the dsp, ; returns cf=0 on success
; expects dx = sb_io_base + DSP_PORT_WRBUF_R
dsp_write_with_timeout		proc	near
		mov	cx,800h
		mov	ah,al

locloop_89:
		in	al,dx			; port 0Ch ??I/O Non-standard
		or	al,al
		jns	loc_90
		loop	locloop_89

		stc
		jmp	short loc_ret_91
loc_90:
		mov	al,ah
		out	dx,al			; port 0Ch, DMA-1 clr byte ptr
		clc

loc_ret_91:
		ret
dsp_write_with_timeout		endp

; returns cf=1 on error, otherwise [al] = byte read
dsp_read_with_timeout		proc	near
		push	dx
		push	cx
		mov	dx,cs:sb_io_base
		add	dl,DSP_PORT_RDBUF_R
		mov	cx,800h

locloop_92:
		in	al,dx			; port 0Eh ??I/O Non-standard
		or	al,al
		js	loc_93
		loop	locloop_92

		stc
		jmp	short loc_94
loc_93:
		sub	dl,4                    ; dx = sb_io_base + DSP_PORT_DATA_R
		in	al,dx
		clc
loc_94:
		pop	cx
		pop	dx
		ret
dsp_read_with_timeout		endp


sb_check_dsp_ver	proc	near
		mov	al,DSP_CMD_GET_VERSION
		mov	dx,cs:sb_io_base
		add	dl,DSP_PORT_DATACMD_W
		call	dsp_write
		call	dsp_read
		mov	ah,al
		call	dsp_read            ; ah = dsp ver hi, al = dsp ver lo
		cmp	ax,101h
		jl	loc_97
		cmp	ax,200h
		jl	loc_95
                ; dsp > 2.0
		mov	cs:sb_dsp_200,1
		jmp	short loc_96
loc_95:
		mov	cs:sb_dsp_200,0
loc_96:
		xor	ax,ax
		jmp	short loc_98
loc_97:         ; dsp version < 1.1
		mov	ax,1
loc_98:
		or	ax,ax
		ret
sb_check_dsp_ver	endp

; reads from the dsp
dsp_read	proc	near
		push	dx
		mov	dx,cs:sb_io_base
		add	dl,DSP_PORT_RDBUF_R
		sub	al,al
loc_99:
		in	al,dx
		or	al,al
		jns	loc_99
		sub	dl,4                    ; dx = sb_io_base + DSP_PORT_DATA_R
		in	al,dx
		pop	dx
		ret
dsp_read	endp

sb_speaker_on	proc	near
		mov	dx,cs:sb_io_base
		add	dx,DSP_PORT_DATACMD_W
		mov	al,DSP_CMD_TURN_ON_SPEAKER
		call	dsp_write
		ret
sb_speaker_on	endp

prev_irq_2	dd      0
prev_irq_3	dd      0
prev_irq_5	dd      0
prev_irq_7	dd      0

; auto-detects the soundblaster IRQ, returns zf=0 on failure (status in ax)
sb_detect_irq	proc	near
		mov	al,2
		mov	dx,offset sb_irq_2
		mov	bx,offset prev_irq_2
		call	hook_irq
		mov	al,3
		mov	dx,offset sb_irq_3
		mov	bx,offset prev_irq_3
		call	hook_irq
		mov	al,5
		mov	dx,offset sb_irq_5
		mov	bx,offset prev_irq_5
		call	hook_irq
		mov	al,7
		mov	dx,offset sb_irq_7
		mov	bx,offset prev_irq_7
		call	hook_irq

		mov	dx,cs
		mov	ax,offset sb_detect_irq
		call	dma_convert_address     ; returns in dl:ax
		xor	cx,cx                   ; transfer length
		mov	dh,49h
		call	setup_dma_for_irq_detection

		mov	dx,cs:sb_io_base
		add	dx,DSP_PORT_DATACMD_W
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
		mov	cx,800h
		mov	cs:sb_irq,0

locloop_100:
		cmp	cs:sb_irq,0
		jne	loc_101
		loop	locloop_100

                ; no irq triggered
		mov	ax,3
		jmp	short loc_102
loc_101:
		xor	ax,ax
loc_102:
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
		ret
sb_detect_irq	endp

; does DMA stuff
; called with dh=49h, dl:ax = linear address
setup_dma_for_irq_detection	proc	near
		push	bx
		mov	bx,ax
		mov	al,5
		out	0Ah,al			; outb(0ah, 5)
		sub	al,al
		out	0Ch,al			; outb(0ch, 0x0)
		mov	al,dh
		out	0Bh,al			; outb(0bh, dh)
		mov	al,bl
		out	2,al			; outb(2, al)
		mov	al,bh
		out	2,al			; outb(2, ah)
		mov	al,cl
		out	3,al			; outb(3, cl)
		mov	al,ch
		out	3,al			; outb(3, ch)
		mov	al,dl
		out	83h,al			; outb(83h, dl)
		mov	al,1
		out	0Ah,al			; outb(0ah, 1)
		pop	bx
		ret
setup_dma_for_irq_detection	endp

sb_irq_2:
		push	dx
		mov	dl,2
		call	sb_handle_irq
		pop	dx
		iret

sb_irq_3:
		push	dx
		mov	dl,3
		call	sb_handle_irq
		pop	dx
		iret
sb_irq_5:
		push	dx
		mov	dl,5
		call	sb_handle_irq
		pop	dx
		iret

sb_irq_7:
		push	dx
		mov	dl,7
		call	sb_handle_irq
		pop	dx
		iret

; expects [dl] = IRQ number
sb_handle_irq	proc	near
		push	ds
		push	ax
		mov	ax,cs
		mov	ds,ax
		mov	cs:sb_irq,dl
		mov	dx,cs:sb_io_base
		add	dx,0Eh
		in	al,dx			; port 0Eh ??I/O Non-standard

		mov	al,20h			; eoi
		out	20h,al
		pop	ax
		pop	ds
		ret
sb_handle_irq	endp

; I think this was used for easier debugging to disable CD audio?
must_detect_mscdex db	0DCh                ; 0CDh to detect, otherwise skip

seg_a		ends
		end	start

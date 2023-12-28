; https://en.wikipedia.org/wiki/Yamaha_OPL
;
; Nine channel, two operator synthesizer (total of 18 operators)
;
; For the whole channel:
; - Main frequency (10 bits)
; - Octave (3 bits)
; - Note on/off;
; - Synthesis mode (FM, additive)
; - Feedback (0..7, the modulator modulating itself)
; For each of the two oscillators:
; - Frequency multiply (0.5, 1..10, 12, 15)
; - Waveform (sine, half-sine, absolute-sine, pseudo-sawtooth)
; - Volume (0..63)
; - Attack, decay, sustain, release (4 bits each)
; - Tremolo, vibrato, sustain (on/off)
; - Envelope scaling per key (on/off)
; - Volume scaling per key (0..3)

; https://moddingwiki.shikadi.net/wiki/OPL_chip

OPL_TEST_WAVEFORM_SEL_ENABLE    equ 001h
OPL_CSW_NOTESEL                 equ 008h
OPL_TR_VIB_SUS_KSR_FREQ         equ 020h
OPL_KEYSCALE_OUTPUT_LEVEL       equ 040h
OPL_ATTACK_DECAY_RATE           equ 060h
OPL_SUSTAIN_RELEASE_RATE        equ 080h
OPL_FREQ_NUMBER                 equ 0A0h
OPL_KEYON_BLOCKNR_FNUM          equ 0B0h
OPL_TRDEPTH_VIBDEPTH_PM         equ 0BDh
OPL_FEEDBACK_SYNTHESIS          equ 0C0h
OPL_WAVEFORM_SELECT             equ 0E0h

OPL_NUM_VOICES                  equ 9
OPL_NUM_OPERATORS               equ 18
; 2
; 16 ???

; multiplies the passed register by 14 (this is the size of a single
; OPL operator)
opl_mult_by_14  macro reg
		push	ax
		push	bx
		push	cx
		mov	ax,reg
		shl	ax,1
		mov	bx,ax
		shl	ax,1
		mov	cx,ax
		shl	ax,1
		add	ax,bx
		add	ax,cx
		mov	reg,ax                   ; di = di * 14
		pop	cx
		pop	bx
		pop	ax
        endm

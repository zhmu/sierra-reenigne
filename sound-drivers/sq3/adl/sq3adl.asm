; vim:set ts=8:

include ../../common/midi.inc
include ../../common/opl.inc
include ../../common/snd0.inc
include ../../common/sb.inc

seg_a		segment	byte public
		assume	cs:seg_a, ds:seg_a

		org	0

PBEND_CENTER                   equ 2000h

; TODO these do not match midi.inc ??
CONTROL_SUSTAIN_PEDAL           equ 40h
CONTROL_MAP_CHANNEL             equ 4Bh

start:
		jmp	entry

		db      00h
                dd      87654321h      ; identifier
                db      01h            ; driver type 1 = sound

                db       6, 'adldrv'   ; driver identifier
                db      28, 'AdLib Music Synthesizer Card' ; driver description

; only modified by load_sound and control_map_ch
mch_op_map	db	OPL_NUM_VOICES dup (0)          ; per OPL voice, which MIDI channel uses it (0ffh means none)


mch_num_opl_voices	db	16 dup (0)      ; per MIDI channel, number of OPL voices mapped to it (should 0..2 ?)
mch_instrument	db	16 dup (0)      ; current instrument for this midi channel
data_5		db	16 dup (0)      ; set by note_on
sust_pdl_act	db	16 dup (0)      ; sustain pedal active (0, 1)
unk_4e		db	16 dup (0)      ; set by control command 4Eh
; I wonder if note_sustain_value is used correctly - it never seems to be read in a meaningful way (?)
note_sustain_value	db	OPL_NUM_VOICES dup (0)          ; used to sustain note for hold pedal (default 0FFh)
data_9		db	OPL_NUM_VOICES dup (0)          ; I wonder if this overrides KSL ... ?
sound_channel_init_count		db	0
midi_last_byte	db	0
midi_decode_state		db	0               ; some sort of state: 0, 1 or 2 (after load) ...
midi_next_byte	db	0
midi_last_command	db	0
midi_last_channel	db	0
debug_repeated_cmd_chan		db	0               ; debug? if 0, midi_last_command/midi_last_channel read from buffer. if 1, repeated
reset_pause_active		db	0
signalval_base	dw	0               ; value to be added to SND_SIGNAL value
volume_override_delay		dw	0               ; set to 20 in load_sound and handle_volume_override
volume_override	dw	0               ; XXX wild guess
midi_delay_left	dw	0
orig_si		dw	0
prev_position	dw	0
loop_position	dw	0               ; set using program change to channel 15
sound_chaninit_offset	dw	0       ; set by load_sound, contains the offset to the channel initialization data (offset 1 in sound file)
op2_ksl		dw      11 dup (0)
op2_amplitude	dw	11 dup (0)
op1_ksl		dw	11 dup (0)      ; this will be the KSL (set by pchange)
op1_amplitude	dw	11 dup (0)
op1_modulates_op2	dw	11 dup (0)      ; 0 (both in synthesis) or 0FFFFh (op1 modulates op2)
cur_note	db	11 dup (0)      ; seems to be the current MIDI note played (MIDI command 9x value)
data_33		db	11 dup (0)      ; flag, set using sub_35 (dl)
pbend_dir	db	11 dup (0)      ; 0 = centered, 1 = add delta, -1 = subtract delta
pbend_delta	db	11 dup (0)
; default operator data (type 1), 14 values
default_operator_0      db       1, 1,  3, 15,  5,  0,  1,  3
                        db      15, 0,  0,  0,  1,  0
; default operator data (type 2), 14 values
default_operator_1      db       0, 1,  1, 15,  7,  0,  2,  4
                        db       0, 0,  0,  1,  0,  0

; total of 18*14 (one OPL operator is 14 bytes)
; hence information for all possible OPL operators
ksl		        db	0               ; 0 - key scaling
freq_multiplication	db	0               ; 1 - frequency modulation
feedback		db	0               ; 2 - channel feedback
attack_rate		db	0               ; 3 - attack rate
sustain_level		db	0               ; 4 - sustain level
sound_sustain		db	0               ; 5 - envelope generator (flag)
decay_rate		db	0               ; 6 - decay rate
release_rate		db	0               ; 7 - release rate
output_level		db	0               ; 8 - amplitude (???)
apply_ampl_mod		db	0               ; 9 - amplitude modulation (flag)
apply_vibrato		db	0               ; A - vibrato (flag)
envelope_scaling_ksr	db	0               ; B - keyboard scaling
synthesis_type		db	0               ; C - algorithm (reversed)
waveform_select		db	0               ; D - waveform
                        db      238 dup (0)

;
freq_vibrato_onoff	db	0               ; always 0 (bit 6 reg 8 - KEY SPL)
tremolo_depth		db	0               ; always 0 (bit 7 reg BD - AM DEP)
vibrato_depth		db	0               ; always 0 (bit 6 red BD - VIB DEP)

; contains the operator numbers, 2 per channel (18 values for 9 channels)
operator_map	db	 0,  3,  1,  4,  2,  5,  6,  9
                db       7, 10,  8, 11, 12, 15, 13, 16
                db      14, 17

; maps an operator number to the appropriate register (18 values)
op_2x_4x_6x_8x_e0_map	db       0,  1,  2,  3,  4,  5,  8,  9
                        db      10, 11, 12, 13, 16, 17, 18, 19
                        db      20, 21

; 18 values - indices whether the operator is either Operator 1 (value 0)
; or Operator 2 (value 0) for the given channel.
;
; This is used by opl_load_default_operators / opl_set_feedback_syn
; to propertly initialize the operator
operator_group	db	0, 0, 0     ; 0/1/2
                db      1, 1, 1     ; 3/4/5
                db      0, 0, 0     ; 6/7/8
		db	1, 1, 1     ; 9/10/11
                db      0, 0, 0     ; 12/13/14
                db      1, 1, 1     ; 15/16/17

; used to map an index to a Cx register (18 values) - only used by opl_set_feedback_syn
reg_c0_map	db	0           ;  0 - FM channel 0
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

; used to program register OPL_TEST_WAVEFORM_SEL_ENABLE (1) to enable/disable

; registers E0-F5 (Waveform Select)
waveform_sel_enable		dw      0
; seems to be used as a temporary buffer in load_operator_from_copy
data_59	                	db	14 dup (0)

; Block Number as in command B0..B8
; (total of 509 entries)
block_nr	db	96 dup (0)
		db	48 dup (1)
		db	48 dup (2)
		db	48 dup (3)
		db	48 dup (4)
		db	48 dup (5)
		db	48 dup (6)
		db	48 dup (7)
		db	48 dup (8)
		db	29 dup (9)

; Frequency number - high byte is used in B0..B8, low byte in A0..A8
; (total of 509 entries)
freq_number	dw      343, 348, 353, 358, 363, 369, 374
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

; 1kb - indexes with 'volume << 6', so I'm expecting 64 values to look up per volume leven?
; note: all code seems to do 3Fh - <value from this table>
; used by sub_40 and sub_43
data_70		db	67 dup (0)
		db	1, 1, 1, 2, 2, 2
		db	2, 3, 3, 3, 3, 4
		db	4, 4, 4, 5, 5, 5
		db	6, 6, 6, 6, 7, 7
		db	7, 7
		db	8, 8, 8, 8, 9, 9, 9, 0Ah, 0Ah, 0Ah
		db	0Ah
		db	 0Bh, 0Bh, 0Bh, 0Bh, 0Ch, 0Ch
		db	 0Ch, 0Ch, 0Dh, 0Dh, 0Dh, 0Eh
		db	 0Eh, 0Eh, 0Eh, 0Fh, 0Fh, 0Fh
		db	 0Fh, 10h, 10h, 10h, 10h, 11h
		db	 00h, 00h, 01h, 01h, 01h, 02h
		db	 02h, 02h, 03h, 03h, 03h, 04h
		db	 04h, 04h, 05h, 05h, 05h, 06h
		db	 06h, 06h, 07h, 07h, 07h
		db	8, 8, 8, 9, 9, 9, 0Ah, 0Ah, 0Ah
		db	 0Bh, 0Bh, 0Bh, 0Ch, 0Ch, 0Ch
		db	 0Dh, 0Dh, 0Dh, 0Eh, 0Eh, 0Eh
		db	 0Fh, 0Fh, 0Fh, 10h, 10h, 10h
		db	 11h, 11h, 11h, 12h, 12h, 12h
		db	 13h, 13h, 13h, 14h, 14h, 14h
		db	 15h, 15h, 00h, 00h, 01h, 01h
		db	 02h, 02h, 02h, 03h, 03h, 04h
		db	 04h, 04h, 05h, 05h, 06h, 06h
		db	 06h, 07h, 07h
		db	8, 8, 8, 9, 9, 0Ah, 0Ah, 0Ah
		db	 0Bh, 0Bh, 0Ch, 0Ch, 0Ch, 0Dh
		db	 0Dh, 0Eh, 0Eh, 0Eh, 0Fh, 0Fh
		db	 10h, 10h, 10h, 11h, 11h, 12h
		db	 12h, 12h, 13h, 13h, 14h, 14h
		db	 14h, 15h, 15h, 16h, 16h, 16h
		db	 17h, 17h, 18h, 18h, 18h, 19h
		db	 19h, 00h, 00h, 01h, 01h, 02h
		db	 02h, 03h, 03h, 04h, 04h, 05h
		db	 05h, 06h, 06h, 06h, 07h, 07h
		db	 08h, 08h, 09h, 09h, 0Ah, 0Ah
		db	 0Bh, 0Bh, 0Ch, 0Ch, 0Dh, 0Dh
		db	 0Dh, 0Eh, 0Eh, 0Fh, 0Fh, 10h
		db	 10h, 11h, 11h, 12h, 12h, 13h
		db	 13h, 14h, 14h, 14h, 15h, 15h
		db	 16h, 16h, 17h, 17h, 18h, 18h
		db	 19h, 19h, 1Ah, 1Ah, 1Bh, 1Bh
		db	 1Bh, 1Ch, 1Ch, 1Dh, 1Dh, 00h
		db	 00h, 01h, 02h, 02h, 03h, 03h
		db	 04h, 04h, 05h, 05h, 06h, 06h
		db	 07h, 07h, 08h, 08h, 09h, 0Ah
		db	 0Ah, 0Bh, 0Bh, 0Ch, 0Ch, 0Dh
		db	 0Dh, 0Eh, 0Eh, 0Fh, 0Fh, 10h
		db	 10h, 11h, 12h, 12h, 13h, 13h
		db	 14h, 14h, 15h, 15h, 16h, 16h
		db	 17h, 17h, 18h, 18h, 19h, 1Ah
		db	 1Ah, 1Bh, 1Bh, 1Ch, 1Ch, 1Dh
		db	 1Dh, 1Eh, 1Eh, 1Fh, 1Fh, 20h
		db	 20h, 21h, 22h, 00h, 01h, 01h
		db	 02h, 02h, 03h, 04h, 04h, 05h
		db	 05h, 06h, 07h, 07h, 08h, 08h
		db	 09h, 0Ah, 0Ah, 0Bh, 0Bh, 0Ch
		db	 0Dh, 0Dh, 0Eh, 0Eh, 0Fh, 10h
		db	 10h, 11h, 11h, 12h, 13h, 13h
		db	 14h, 14h, 15h, 16h, 16h, 17h
		db	 17h, 18h, 19h, 19h, 1Ah, 1Ah
		db	 1Bh, 1Ch, 1Ch, 1Dh, 1Dh, 1Eh
		db	 1Fh, 1Fh
		db	'  !""##$'
		db	'%%&'
		db	 00h, 01h, 01h, 02h, 03h, 03h
		db	 04h, 05h, 05h, 06h, 07h, 07h
		db	 08h, 09h, 09h, 0Ah, 0Bh, 0Bh
		db	 0Ch, 0Dh, 0Dh, 0Eh, 0Fh, 0Fh
		db	 10h, 11h, 11h, 12h, 13h, 13h
		db	 14h, 15h, 15h, 16h, 17h, 17h
		db	 18h, 19h, 19h, 1Ah, 1Bh, 1Bh
		db	 1Ch, 1Dh, 1Dh, 1Eh, 1Fh, 1Fh
		db	' !!"##$'
		db	'%%&', 27h, 27h, '())*'
		db	 00h, 01h, 01h, 02h, 03h, 04h
		db	 04h, 05h, 06h, 07h, 07h, 08h
		db	 09h, 09h, 0Ah, 0Bh, 0Ch, 0Ch
		db	 0Dh, 0Eh, 0Fh, 0Fh, 10h, 11h
		db	 12h, 12h, 13h, 14h, 14h, 15h
		db	 16h, 17h, 17h, 18h, 19h, 1Ah
		db	 1Ah, 1Bh, 1Ch, 1Dh, 1Dh, 1Eh
		db	 1Fh, 1Fh
		db	' !""#$'
		db	'%%&', 27h, '(()**+,--.'
		db	 00h, 01h, 02h, 02h, 03h, 04h
		db	 05h, 06h, 06h, 07h, 08h, 09h
		db	 0Ah, 0Ah, 0Bh, 0Ch, 0Dh, 0Eh
		db	 0Eh, 0Fh, 10h, 11h, 12h, 12h
		db	 13h, 14h, 15h, 16h, 16h, 17h
		db	 18h, 19h, 1Ah, 1Ah, 1Bh, 1Ch
		db	 1Dh, 1Eh, 1Eh, 1Fh
		db	' !""#$'
		db	'%&&', 27h, '()**+,-../0122'
		db	 00h, 01h, 02h, 03h, 03h, 04h
		db	 05h, 06h, 07h, 08h, 09h, 09h
		db	 0Ah, 0Bh, 0Ch, 0Dh, 0Eh, 0Fh
		db	 10h, 10h, 11h, 12h, 13h, 14h
		db	 15h, 16h, 16h, 17h, 18h, 19h
		db	 1Ah, 1Bh, 1Ch, 1Dh, 1Dh, 1Eh
		db	 1Fh
		db	' !"##$'
		db	'%&', 27h, '()**+,-./001234567'
		db	 00h, 01h, 02h, 03h, 04h, 05h
		db	 06h, 06h, 07h, 08h, 09h, 0Ah
		db	 0Bh, 0Ch, 0Dh, 0Eh, 0Fh, 10h
		db	 11h, 12h, 13h, 14h, 14h, 15h
		db	 16h, 17h, 18h, 19h, 1Ah, 1Bh
		db	 1Ch, 1Dh, 1Eh, 1Fh
		db	' !""#$'
		db	'%&', 27h, '()*+,-./00123456789:;'
		db	 00h, 01h, 02h, 03h, 04h, 05h
		db	 06h, 07h, 08h, 09h, 0Ah, 0Bh
		db	 0Ch, 0Dh, 0Eh, 0Fh, 10h, 11h
		db	 12h, 13h, 14h, 15h, 16h, 17h
		db	 18h, 19h, 1Ah, 1Bh, 1Ch, 1Dh
		db	 1Eh, 1Fh
		db	' !"#$'
		db	'%&', 27h, '()*+,-./0123456789:;<'
		db	'=>?', 0
		db	 01h, 02h, 03h, 04h, 05h, 06h
		db	 07h, 08h, 09h, 0Ah, 0Bh, 0Ch
		db	 0Dh, 0Eh, 0Fh, 10h, 11h, 12h
		db	 13h, 14h, 15h, 16h, 17h, 18h
		db	 19h, 1Ah, 1Bh, 1Ch, 1Dh, 1Eh
		db	 1Fh
		db	' !"#$'
		db	'%&', 27h, '()*+,-./0123456789:;<'
		db	'=>?', 0
		db	 01h, 02h, 03h, 04h, 05h, 06h
		db	 07h, 08h, 09h, 0Ah, 0Bh, 0Ch
		db	 0Dh, 0Eh, 0Fh, 10h, 11h, 12h
		db	 13h, 14h, 15h, 16h, 17h, 18h
		db	 19h, 1Ah, 1Bh, 1Ch, 1Dh, 1Eh
		db	 1Fh
		db	' !"#$'
		db	'%&', 27h, '()*+,-./0123456789:;<'
		db	'=>?', 0
		db	 01h, 02h, 03h, 04h, 05h, 06h
		db	 07h, 08h, 09h, 0Ah, 0Bh, 0Ch
		db	 0Dh, 0Eh, 0Fh, 10h, 11h, 12h
		db	 13h, 14h, 15h, 16h, 17h, 18h
		db	 19h, 1Ah, 1Bh, 1Ch, 1Dh, 1Eh
		db	 1Fh
		db	' !"#$'
		db	'%&', 27h, '()*+,-./0123456789:;<'
		db	'=>?'

; holds data in records of 28 bytes... ?
; only used by 'program change' and 'control_map_ch' (channel mapping) commands
;
; see http://www.rarefied.org/sci/adlib.txt for more info
;
data_75		db	2*48*28 dup (0)		; Data table (indexed access)

;
func_tab	dw	func_0                  ; func 0: get device info
                dw      func_2                  ; func 2: init
                dw      terminate               ; func 4: terminate
                dw      load_sound              ; func 6: load sound
                dw      timer                   ; func 8: timer
                dw      set_volume              ; func 10: set volume
                dw      fade_out                ; func 12: fade out
                dw      terminate               ; func 14: stop sound
                dw      pause_sound             ; func 16: pause sound
                dw      seek_sound              ; func 18: seek sound

; main routine, handles driver function in [bp]
entry           proc far
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
		ret
entry           endp

load_sound	proc	near
		mov	bx,cs:orig_si
		mov	di,[bx+SND_RESPTR]
		mov	si,[di]
		mov	es,[di+2]               ; es:di = sound data
		mov	word ptr [bx+SND_STATE],SND_STATE_VALID
		mov	cs:sound_channel_init_count,10h

                ; if the first byte is 2, it means there will be digital sample
                ; data present and the initializer of channel 16 is actually an
                ; offset to the channel (and hence, must be skipped)
		cmp	byte ptr es:[si],0
		je	loc_3			; Jump if equal
		cmp	byte ptr es:[si],2
		je	loc_2			; Jump if equal

		mov	word ptr [bx+SND_STATE],SND_STATE_INVALID
		mov	ax,3
		retn
		db	0EBh, 05h
loc_2:
		dec	cs:sound_channel_init_count
loc_3:
		push	cx
		mov	word ptr [bx+SND_SIGNAL],0
		mov	word ptr [bx+SND_POS],22h
		inc	si
		xor	di,di			; Zero register

		mov	cx,OPL_NUM_VOICES

locloop_4:
		mov	byte ptr cs:mch_op_map[di],0FFh
		mov	cs:mch_num_opl_voices[di],0
		mov	cs:mch_instrument[di],0Dh
		mov	cs:data_5[di],0
		mov	cs:sust_pdl_act[di],0
		mov	cs:note_sustain_value[di],0FFh
		mov	cs:unk_4e[di],0
		mov	cs:data_9[di],0
		mov	cs:cur_note[di],0
		mov	cs:data_33[di],0
		mov	cs:pbend_dir[di],0
		mov	cs:pbend_delta[di],0
		shl	di,1			; Shift w/zeros fill
		mov	cs:op1_ksl[di],0
		mov	cs:op2_ksl[di],0
		mov	cs:op1_modulates_op2[di],0
		shr	di,1			; Shift w/zeros fill
		inc	di
		loop	locloop_4		; Loop if cx > 0

		mov	cx,2

locloop_5:
		mov	cs:mch_num_opl_voices[di],0
		mov	cs:mch_instrument[di],0Dh
		mov	cs:data_5[di],0
		mov	cs:sust_pdl_act[di],0
		mov	cs:unk_4e[di],0
                ; doesn't reset data_9[] here ?
		mov	cs:cur_note[di],0
		mov	cs:data_33[di],0
		mov	cs:pbend_dir[di],0
		mov	cs:pbend_delta[di],0
		shl	di,1			; Shift w/zeros fill
		mov	cs:op1_ksl[di],0
		mov	cs:op2_ksl[di],0
		mov	cs:op1_modulates_op2[di],0
		shr	di,1			; Shift w/zeros fill
		inc	di
		loop	locloop_5		; Loop if cx > 0

		mov	cx,5

locloop_6:
		mov	cs:mch_num_opl_voices[di],0
		mov	cs:mch_instrument[di],0Dh
		mov	cs:data_5[di],0
		mov	cs:sust_pdl_act[di],0
		mov	cs:unk_4e[di],0
		inc	di
		loop	locloop_6		; Loop if cx > 0

		mov	cs:sound_chaninit_offset,si
		xor	di,di
		xor	al,al

                ; done resetting all MIDI channel data. read channel
                ; initialization values from sound header.
                ; - es:si = sound header channel initialization
                ; - al = midi channel#
                ; - di = opl channel
process_channel_initialization:
		mov	ch,es:[si]
		and	ch,7Fh                  ; ch = number of voices for this channel
		inc	si
		mov	cl,es:[si]              ; cl = get channel bitmask
		test	cl,SND_CHANBIT_ADLIB
		jz	skip_channel            ; bit 4 must be set
		cmp	ch,0
		jle	skip_channel
		xor	bl,bl

assign_adlib_operators:
		mov	byte ptr cs:mch_op_map[di],al       ; map the channel
		push	di
		xor	dh,dh
		mov	dl,al
		mov	di,dx                   ; di = midi channel
		inc	cs:mch_num_opl_voices[di]       ; channel has one extra adlib operator mapped to it
		pop	di
		inc	di
		inc	bl
		cmp	bl,ch
		jl	assign_adlib_operators

skip_channel:
		inc	si
		inc	al
		cmp	al,cs:sound_channel_init_count
		jl	process_channel_initialization

		mov	cs:midi_delay_left,0
		mov	cs:midi_decode_state,2
		mov	cs:reset_pause_active,0
		mov	cs:volume_override,0
		mov	cx,8
		add	cx,2
		shl	cx,1
		mov	cs:volume_override_delay,cx           ; volume_override_delay = 20
		mov	cs:loop_position,22h
		mov	cs:signalval_base,7Fh
		mov	ax,1
		pop	cx
		retn
load_sound	endp

; periodically called (60Hz) to decode the next MIDI command, as needed
timer		proc	near
		mov	bx,cs:orig_si
		mov	di,[bx+SND_RESPTR]
		mov	es,[di+2]
		mov	si,[di]                 ; es:si = sound data
		cmp	cs:midi_delay_left,0
		je	timer_handle_next_byte

                ; check if we got here using the SEEK SOUND command
		cmp	bp,FN_SEEK_SOUND
		jne	loc_10			; Jump if not equal
		mov	cs:midi_delay_left,0
		jmp	short loc_ret_11
loc_10:
		dec	cs:midi_delay_left
		cmp	cs:volume_override,0
		je	loc_ret_11		; Jump if equal
		call	handle_volume_override

loc_ret_11:
		retn

timer_handle_next_byte:
		cli
		push	cx
		add	si,[bx+SND_POS]
		mov	cs:prev_position,si
loc_13:
		cmp	cs:midi_decode_state,1
		jne	loc_19			; Jump if not equal

                ; decode_state = 1, fetch next byte from midi data
		push	dx
		mov	dl,es:[si]
		mov	cs:midi_last_byte,dl
		inc	si
		pop	dx

		cmp	cs:midi_last_byte,MIDI_END_OF_SONG
		jne	loc_14			; Jump if not equal
		call	stop_song
		jmp	timer_leave
loc_14:
		cmp	cs:midi_last_byte,MIDI_DELAY_240
		jne	loc_16			; Jump if not equal
		mov	cs:midi_delay_left,0F0h
		mov	cs:midi_decode_state,1

		cmp	bp,FN_SEEK_SOUND
		jne	loc_15			; Jump if not equal
		jmp	short loc_13
		jmp	short loc_16
loc_15:
		jmp	timer_update_pos_and_leave
loc_16:
		push	bx
		mov	cs:midi_decode_state,2

                ; increase delay using byte read
		mov	ax,cs:midi_delay_left
		mov	bl,cs:midi_last_byte
		xor	bh,bh
		add	ax,bx
		mov	cs:midi_delay_left,ax
		pop	bx
		cmp	cs:midi_delay_left,0
		je	loc_19			; Jump if equal
		cmp	bp,FN_SEEK_SOUND
		jne	loc_17			; Jump if not equal
		mov	cs:midi_delay_left,0
		jmp	short loc_18
loc_17:
		dec	cs:midi_delay_left
		cmp	cs:volume_override,0
		je	loc_18			; Jump if equal
		call	handle_volume_override
loc_18:
		jmp	timer_update_pos_and_leave

loc_19:
		mov	cs:midi_decode_state,2
		push	dx
		mov	dl,es:[si]
		mov	cs:midi_last_byte,dl
		inc	si
		pop	dx
		test	cs:midi_last_byte,80h
		jnz	loc_20			; Jump if not zero

                ; retrieve last command/channel
		push	bx
		mov	cs:debug_repeated_cmd_chan,1
		mov	ah,cs:midi_last_command
		mov	al,cs:midi_last_channel
		mov	bl,cs:midi_last_byte
		mov	cs:midi_next_byte,bl
		pop	bx
		dec	si
		jmp	short loc_21
loc_20:
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
loc_21:
                ; ah = command
                ; al = channel
		cmp	ah,MIDI_PCHANGE
		jne	loc_24			; Jump if not equal
		cmp	al,0Fh
		jne	loc_22			; Jump if not equal
		call	pchange_ch15
		jmp	short loc_23
loc_22:
		call	pchange
loc_23:
		jmp	pchange_done
loc_24:
		cmp	ah,MIDI_CONTROL
		jne	loc_30			; Jump if not equal
		cmp	cs:midi_next_byte,CONTROL_MAP_CHANNEL
		jne	loc_25			; Jump if not equal
		call	control_map_ch
		jmp	timer_skip2
loc_25:
		cmp	cs:midi_next_byte,CONTROL_SUSTAIN_PEDAL
		jne	loc_26			; Jump if not equal
		call	control_sustainpedal
		jmp	short timer_skip2
		nop
loc_26:
		cmp	cs:midi_next_byte,MIDI_CONTROL_RESET_ON_PAUSE
		jne	loc_27			; Jump if not equal
		call	control_reset_pause
		jmp	short timer_skip2
		nop
loc_27:
		cmp	cs:midi_next_byte,MIDI_CONTROL_CUMULATIVE_CUE
		jne	loc_28			; Jump if not equal
		call	update_signal
		jmp	short timer_skip2
		nop
loc_28:
		cmp	cs:midi_next_byte,MIDI_CONTROL_UNKNOWN_4E
		jne	loc_29			; Jump if not equal
		call	control_unk_4e
loc_29:
		jmp	short timer_skip2
		nop
loc_30:
		cmp	ah,MIDI_SYSEX_BEGIN
		jne	loc_32
		cmp	al,0Ch
		jne	sysex_skip_bytes

                ; not sysex-begin, but MIDI_END_OF_SONG...
		call	stop_song
		jmp	short timer_leave
		nop

sysex_skip_bytes:
                ; 'handle' sysex by just skipping bytes until MIDI_SYSEX_END is encountered...
		push	dx
		mov	dl,es:[si]
		mov	cs:midi_last_byte,dl
		inc	si
		pop	dx
		cmp	cs:midi_last_byte,MIDI_SYSEX_END
		jne	sysex_skip_bytes

		jmp	loc_13
loc_32:
		cmp	bp,FN_SEEK_SOUND
		je	loc_34			; skip note-on/note-off if seeking ...

		cmp	ah,MIDI_NOTE_ON
		jne	loc_33			; Jump if not equal
		call	note_on
		jmp	short timer_skip2
		nop
loc_33:
		cmp	ah,MIDI_NOTE_OFF
		jne	loc_34			; Jump if not equal
		call	note_off
		jmp	short timer_skip2
		nop
loc_34:
		cmp	ah,MIDI_PBEND
		jne	loc_35			; Jump if not equal
		call	pbend
		jmp	short timer_skip2
		nop
loc_35:
		cmp	ah,MIDI_AFTERTOUCH      ; ignored ?
		jne	timer_skip2

                ; unrecognized command byte, just skip it
		jmp	short timer_skip1
		nop
timer_skip2:
		inc	si
timer_skip1:
		inc	si
pchange_done:
		mov	cs:midi_decode_state,1
		jmp	loc_13
timer_update_pos_and_leave:
		sub	si,cs:prev_position
		mov	bx,cs:orig_si
		add	[bx+SND_POS],si
timer_leave:
		pop	cx
		sti				; Enable interrupts
		retn
timer		endp

control_reset_pause proc	near
		cmp	byte ptr es:[si+1],0
		jne	loc_41			; Jump if not equal
		mov	cs:reset_pause_active,0
		jmp	short loc_ret_42
loc_41:
		mov	cs:reset_pause_active,1

loc_ret_42:
		retn
control_reset_pause		endp


update_signal	proc	near
		push	ax
		push	bx
		xor	ah,ah			; Zero register
		mov	al,es:[si+1]
		mov	bx,cs:orig_si
		add	cs:signalval_base,ax
		mov	ax,cs:signalval_base
		mov	[bx+SND_SIGNAL],ax
		pop	bx
		pop	ax
		retn
update_signal	endp

control_unk_4e  proc	near
		push	ax
		push	bx
		xor	bh,bh			; Zero register
		mov	bl,al
		mov	al,es:[si+1]            ; al = midi data
		mov	cs:unk_4e[bx],al
		or	al,al			; Zero ?
		jnz	loc_44			; Jump if not zero

		push	cx
		mov	cx,OPL_NUM_VOICES
		xor	bl,bl
locloop_43:
		mov	cs:data_9[bx],0
		inc	bl
		loop	locloop_43		; Loop if cx > 0

		pop	cx
loc_44:
		pop	bx
		pop	ax
		retn
control_unk_4e  endp


; called if MIDI_END_OF_SONG is encountered
stop_song	proc	near
		mov	bx,cs:orig_si
		mov	word ptr [bx+SND_SIGNAL],0FFFFh
		mov	ax,cs:loop_position
		mov	[bx+SND_POS],ax         ; return to loop position
		mov	cs:midi_decode_state,2
		mov	cs:midi_delay_left,0
		call	pause_sound
		retn
stop_song	endp


; program change (C0) command for channel 15
pchange_ch15	proc	near
		push	bx
		push	cx
		inc	si
		xor	ch,ch			; Zero register
		mov	cl,cs:midi_next_byte
		mov	bx,cs:orig_si
		cmp	cl,MIDI_PCHANGE_SET_LOOP_POINT
		jne	loc_45			; Jump if not equal
		push	si
		sub	si,cs:prev_position
		add	si,[bx+SND_POS]
		dec	si
		dec	si
		mov	cs:loop_position,si
		pop	si
		jmp	short loc_46
loc_45:
		mov	[bx+SND_SIGNAL],cx
loc_46:
		pop	cx
		pop	bx
		retn
pchange_ch15	endp


; program change (C0) command for channels other than 15
; al = channel
pchange         proc	near
		push	bx
		push	cx
		xor	bh,bh
		mov	bl,cs:midi_next_byte    ; instrument value
		call	multiply_bx_by_28

		push	di
		mov	di,bx
		lea	cx,[data_75][di]        ; cx = &data_75[instrument * 28]

                ; update current instrument value
		push	ax
		xor	bh,bh
		mov	bl,al
		mov	al,cs:midi_next_byte
		mov	cs:mch_instrument[bx],al
		pop	ax

                ; loop: bx = [ 0 .. OPL_NUM_VOICES ]
		xor	bx,bx
loc_47:
		cmp	byte ptr cs:mch_op_map[bx],al
		jne	loc_48

		call	sub_20
		push	cx
		call	sub_39
		pop	cx
loc_48:
		inc	bx
		cmp	bx,OPL_NUM_VOICES
		jl	loc_47			; Jump if <

		inc	si
		pop	di
		pop	cx
		pop	bx
		ret
pchange         endp

; returns: bx = bx * 28
multiply_bx_by_28		proc	near
		push	cx
		push	ax
		mov	cl,2
		shl	bx,cl			; Shift w/zeros fill
		mov	ax,bx
		shl	bx,1			; Shift w/zeros fill
		mov	cx,bx
		shl	bx,1			; Shift w/zeros fill
		add	bx,ax
		add	bx,cx
		pop	ax
		pop	cx
		retn
multiply_bx_by_28		endp


; handles note-on command. note value cl must be 0ch <= cl <= 0x6b
; ah = command, al = channel
note_on		proc	near
		push	bx
		push	cx
		push	dx
		push	di
		xor	ch,ch
		mov	cl,cs:midi_next_byte    ; cl = note
		cmp	cl,0Ch
		jge	loc_49
		jmp	note_on_ret
loc_49:
		cmp	cl,6Bh			; 'k'
		jle	loc_50
		jmp	note_on_ret
loc_50:
		xor	dh,dh
		mov	dl,es:[si+1]            ; dl = velocity
		or	dl,dl
		jnz	loc_51

                ; velocity of zero switches the note off...
		call	note_off
		jmp	note_on_ret
loc_51:
		xor	bx,bx			; Zero register
		mov	di,ax
		and	di,0FFh
loc_52:
		cmp	byte ptr cs:mch_op_map[bx],al
		jne	loc_53

                ; channel [bx] is mapped to midi channel [al]

		cmp	cs:data_33[bx],0
		jne	loc_53

                ; data_33[bx] == 0
		call	sub_11
		mov	cs:note_sustain_value[bx],0FFh
		call	sub_21
		jmp	short loc_58
		nop
loc_53:
		inc	bx
		cmp	bx,OPL_NUM_VOICES
		jl	loc_52			; Jump if <
		xor	bh,bh			; Zero register
		mov	bl,cs:data_5[di]
loc_54:
		cmp	byte ptr cs:mch_op_map[bx],al
		jne	loc_55			; Jump if not equal
		mov	cs:note_sustain_value[bx],0FFh
		call	sub_22
		call	sub_11
		call	sub_21
		jmp	short loc_58
		nop
loc_55:
		inc	bx
		cmp	bx,OPL_NUM_VOICES
		jl	loc_54			; Jump if <
		xor	bl,bl			; Zero register
loc_56:
		cmp	byte ptr cs:mch_op_map[bx],al
		jne	loc_57			; Jump if not equal
		mov	cs:note_sustain_value[bx],0FFh
		call	sub_22
		call	sub_11
		call	sub_21
		jmp	short loc_58
		nop
loc_57:
		inc	bl
		cmp	bl,cs:data_5[di]
		jl	loc_56			; Jump if <
loc_58:
		inc	bl
		cmp	bl,OPL_NUM_VOICES
		jl	loc_59			; Jump if <
		xor	bl,bl			; Zero register
loc_59:
		mov	cs:data_5[di],bl
note_on_ret:
		pop	di
		pop	dx
		pop	cx
		pop	bx
		retn
note_on		endp


; does something, but only if unk_4e is non-zero - only place that sets data_9[bx] to non-zero?
; expects dl to be note velocity
sub_11		proc	near
		xchg	bl,al
		cmp	cs:unk_4e[bx],0
		xchg	bl,al
		jz	loc_61			; Jump if zero

		push	ax
		push	bx
		push	cx
		push	di
		mov	cs:data_9[bx],dl
		shl	bx,1
		shr	dl,1
		call	sub_43
		call	sub_42
		call	sub_44
		pop	di
		pop	cx
		pop	bx
		pop	ax
		jmp	short loc_ret_62
loc_61:
		mov	cs:data_9[bx],0

loc_ret_62:
		retn
sub_11		endp

note_off	proc	near
		push	bx
		push	cx
		xor	bx,bx
		mov	cl,cs:midi_next_byte                ; cl = note
loc_63:
		cmp	byte ptr cs:mch_op_map[bx],al
		jne	loc_66
		cmp	cs:cur_note[bx],cl
		jne	loc_66

                ; cur_note[bx] == note value (cl)
		push	di
		mov	di,ax
		and	di,0FFh
		cmp	cs:sust_pdl_act[di],1
		jne	loc_64
		mov	cs:note_sustain_value[bx],cl
		jmp	short loc_65
loc_64:
		mov	cs:note_sustain_value[bx],0FFh
		call	sub_22
loc_65:
		pop	di
		jmp	short loc_67
		nop
loc_66:
		inc	bx
		cmp	bx,OPL_NUM_VOICES
		jl	loc_63			; Jump if <
loc_67:
		pop	cx
		pop	bx
		retn
note_off	endp

pbend           proc	near
		push	bx
		push	cx
		push	dx
		push	di
		xor	cl,cl
		mov	ch,es:[si+1]
		shr	cx,1
		or	cl,cs:midi_next_byte    ; cx = pitch wheel value
		xor	di,di
loc_68:
		cmp	byte ptr cs:mch_op_map[di],al
		jne	loc_74

		push	ax
		cmp	cx,PBEND_CENTER
		jne	loc_69

                ; pitch wheel is centered
		xor	al,al
		mov	cs:pbend_dir[di],0
		jmp	short loc_72
loc_69:
		cmp	cx,PBEND_CENTER
		jle	loc_70

                ; cx > PBEND_CENTER, hence ax will be positive...
		mov	ax,cx
		sub	ax,PBEND_CENTER        ; ax = pitch wheel value - PBEND_CENTER
		mov	cs:pbend_dir[di],1
		jmp	short loc_71
loc_70:
		mov	ax,PBEND_CENTER
		sub	ax,cx                   ; ax = PBEND_CENTER - pitch wheel value
		mov	cs:pbend_dir[di],0FFh
loc_71:
		mov	bx,0ABh
		xor	dx,dx
		div	bx			; ax = ax / 0xab
loc_72:
		mov	cs:pbend_delta[di],al
		cmp	cs:data_33[di],0
		je	loc_73			; Jump if equal

		push	cx
		mov	bx,di
		xor	ch,ch
		mov	cl,cs:cur_note[di]       ; loaded to avoid changing it
		mov	dx,1
		call    sub_35
		pop	cx
loc_73:
		pop	ax
loc_74:
		inc	di
		cmp	di,OPL_NUM_VOICES
		jl	loc_68			; Jump if <

		pop	di
		pop	dx
		pop	cx
		pop	bx
		retn
pbend           endp

; al = channel
; "This tells the driver how many notes it will be playing at once and
; therefore how many hardware channels it occupies"
; (NUMNOTES in SCI)
control_map_ch	proc	near
		push	bx
		xor	bh,bh
		mov	bl,al
		shl	bl,1
		inc	bl
		add	bx,cs:sound_chaninit_offset     ; bx = sound_chaninit_offset + (channel + 1) * 2

                ; verify whether this channel is to be played on ADLIB
		test	byte ptr es:[bx],SND_CHANBIT_ADLIB
		pop	bx
		jnz	loc_75			; Jump if not zero
		retn

loc_75:         ; this channel should be played on this hardware
		push	ax
		push	bx
		push	cx
		push	di
		xor	ah,ah
		mov	di,ax                   ; di = MIDI channel

		mov	cl,es:[si+1]            ; cl = number of voices on this channel
		mov	ch,cs:mch_num_opl_voices[di]

                ; if number of voices equals to what is mapped, done
		cmp	ch,cl
		jz	cmap_ret

		xor	di,di
		cmp	ch,cl
		jge	cmap_unmap
		sub	cl,ch
		xor	ch,ch                   ; cx = number of voices to add

loc_77:
		cmp	byte ptr cs:mch_op_map[di],0FFh
		jne	loc_78

                ; OPL voice [di] is unavailable - claim it

                ; copies pbend value for channel [al]
		call	copy_pbend_values
		mov	byte ptr cs:mch_op_map[di],al
		mov	bx,ax

		inc	cs:mch_num_opl_voices[bx]
		push	cx
		xor	ch,ch
		mov	cl,cs:mch_instrument[bx]
		mov	bx,cx
		call	multiply_bx_by_28
		lea	cx,[data_75][bx]	 ; Load effective addr
		mov	bx,di
		call	sub_22
		call	sub_20
		call	sub_39
		pop	cx
		dec	cx
		or	cx,cx			; Zero ?
		jz	cmap_ret			; Jump if zero
loc_78:
		inc	di
		cmp	di,OPL_NUM_VOICES
		jl	loc_77			; Jump if <
		jmp	short cmap_ret
cmap_unmap:
		sub	ch,cl
		mov	cl,ch
		xor	ch,ch			; cx = number of voices to unmap
loc_80:
		cmp	byte ptr cs:mch_op_map[di],al
		jne	loc_81			; Jump if not equal

                ; unmaps the channel
		mov	byte ptr cs:mch_op_map[di],0FFh
		mov	cs:pbend_dir[di],0
		mov	cs:pbend_delta[di],0
		mov	bx,ax
		dec	cs:mch_num_opl_voices[bx]
		mov	bx,di
		call	sub_22
		dec	cx
		or	cx,cx
		jz	cmap_ret
loc_81:
		inc	di
		cmp	di,OPL_NUM_VOICES
		jl	loc_80			; Jump if <
cmap_ret:
		pop	di
		pop	cx
		pop	bx
		pop	ax
		retn
control_map_ch	endp

control_sustainpedal proc	near
		push	bx
		xor	bh,bh			; Zero register
		mov	bl,al
		cmp	byte ptr es:[si+1],0
		jne	loc_85			; Jump if not equal
		push	cx
		mov	cs:sust_pdl_act[bx],0
		xor	bl,bl			; Zero register
		mov	cx,OPL_NUM_VOICES

locloop_83:
		cmp	byte ptr cs:mch_op_map[bx],al
		jne	loc_84			; Jump if not equal
		cmp	cs:note_sustain_value[bx],0FFh
		je	loc_84			; Jump if equal
		mov	cs:note_sustain_value[bx],0FFh
		call	sub_22
loc_84:
		inc	bl
		loop	locloop_83		; Loop if cx > 0

		pop	cx
		jmp	short loc_86
loc_85:
		mov	cs:sust_pdl_act[bx],1
loc_86:
		pop	bx
		retn
control_sustainpedal endp

; copyies pbend_dir / pbend_delta for MIDI channel [al] to pbend_dir/delta [di]
copy_pbend_values proc	near
		push	ax
		push	bx
		xor	bx,bx			; Zero register
loc_87:
		cmp	byte ptr cs:mch_op_map[bx],al
		jne	loc_88

                ; copies pbend_dir/pbend_delta[bx] -> data_{34,35}[di]
		mov	al,cs:pbend_dir[bx]
		mov	cs:pbend_dir[di],al
		mov	al,cs:pbend_delta[bx]
		mov	cs:pbend_delta[di],al
		jmp	short loc_89
		nop
loc_88:
		inc	bx
		cmp	bx,OPL_NUM_VOICES
		jl	loc_87			; Jump if <
loc_89:
		pop	bx
		pop	ax
		retn
copy_pbend_values endp

; resets all operators
opl_reset	proc	near
		push	bx
		push	cx
		push	dx
		mov	bx,OPL_TEST_WAVEFORM_SEL_ENABLE
		xor	cx,cx			; Zero register
		call	write_reg
		xor	bx,bx			; Zero register
		call	opl_reset_operators
		xor	bx,bx			; Zero register
		xor	cx,cx			; Zero register
		xor	dx,dx			; Zero register
		mov	cs:tremolo_depth,bl
		mov	cs:vibrato_depth,cl
		mov	cs:freq_vibrato_onoff,dl
		call	opl_set_trem_vib_depth
		call	opl_set_freq_vibrato

		xor	bx,bx
loc_90:
		call	opl_reset_freq
		inc	bx
		cmp	bx,OPL_NUM_VOICES
		jl	loc_90			; Jump if <

		mov	bx,1
		call	set_waveform_select
		pop	dx
		pop	cx
		pop	bx
		retn
opl_reset	endp

opl_reset_operators	proc	near
		call	opl_load_default_operators
		call	opl_set_trem_vib_depth
		retn
opl_reset_operators	endp

set_waveform_select		proc	near
		or	bx,bx			; Zero ?
		jnz	loc_91			; Jump if not zero
		mov	word ptr cs:waveform_sel_enable,0
		jmp	short loc_92
loc_91:
		mov	word ptr cs:waveform_sel_enable,20h
loc_92:
		push	bx
		push	di
		xor	di,di			; Zero register
loc_93:
		xor	bh,bh			; Zero register
		mov	bl,cs:op_2x_4x_6x_8x_e0_map[di]
		add	bx,OPL_WAVEFORM_SELECT
		xor	cx,cx			; Zero register
		call	write_reg
		inc	di
		cmp	di,12h
		jl	loc_93			; Jump if <
		pop	di

		mov	bx,OPL_TEST_WAVEFORM_SEL_ENABLE
		mov	cx,word ptr cs:waveform_sel_enable
		call	write_reg
		pop	bx
		retn
set_waveform_select		endp

; called by pchange and control_map_ch
; bl = channel
; cx = data source (some offset within data_75)
;
; this loads: op1_ksl, op1_amplitude, op2_ksl, op2_amplitude
sub_20		proc	near
		push	ax
		push	bx
		push	cx
		push	dx
		push	si
		push	di
		mov	di,cx

		push	bx
		push	cx
		shl	bx,1
		mov	cl,4
		cmp	byte ptr cs:[di+12],0   ; check algorithm
		je	loc_94

                ; only performed is [di+12] != 0 (operator 1 modulates operator 2)
		mov	cs:op1_modulates_op2[bx],0FFFFh
		jmp	short loc_95
loc_94:
                ; only performed is [di+12] == 0 (both operators are in synthesis)
		xor	ah,ah
		mov	al,cs:[di]              ; op1 key scaling
		mov	cs:op1_ksl[bx],ax

		mov	al,3Fh
		mov	ah,cs:[di+8]            ; op1 amplitude
		sub	al,ah
		xor	ah,ah
		mov	cs:op1_amplitude[bx],ax

loc_95:
		xor	ah,ah
		mov	al,cs:[di+0Dh]          ; op2 key scaling
		mov	cs:op2_ksl[bx],ax
		mov	al,3Fh
		mov	ah,cs:[di+15h]          ; op2 amplitude
		sub	al,ah
		xor	ah,ah
		mov	cs:op2_amplitude[bx],ax
		pop	cx
		pop	bx

		add	di,1Ah
		mov	al,cs:[di]              ; op1_waveform
		inc	di
		xor	dh,dh
		mov	dl,cs:[di]              ; op2_waveform
		mov	si,cx
		add	si,0Dh
		shl	bx,1
		mov	di,bx
		xor	bh,bh
		mov	bl,cs:operator_map[di]
		push	dx
		mov	dx,ax
		call	load_operator
		pop	dx
		inc	di
		xor	bh,bh			; Zero register
		mov	bl,cs:operator_map[di]
		mov	cx,si
		call	load_operator

		pop	di
		pop	si
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		retn
sub_20		endp


; calls sub_35 with dx=1
sub_21		proc	near
		push	bx
		push	cx
		push	dx
		push	di
		mov	dx,1
		call	sub_35
		pop	di
		pop	dx
		pop	cx
		pop	bx
		retn
sub_21		endp

; calls sub_35 with dx=0, cl = cur_note[bx]
sub_22		proc	near
		push	bx
		push	cx
		push	dx
		push	di
		xor	ch,ch
		mov	cl,cs:cur_note[bx]       ; to avoid changing it
		xor	dx,dx
		call	sub_35
		pop	di
		pop	dx
		pop	cx
		pop	bx
		retn
sub_22		endp

opl_load_default_operators		proc	near
		push	bx
		push	cx
		push	dx
		push	di
		xor	di,di			; Zero register
loc_96:
		mov	bx,di
		xor	dx,dx			; Zero register
		cmp	cs:operator_group[di],0
		je	loc_97			; Jump if equal

		lea	cx,ds:[default_operator_1]	; Load effective addr
		call	load_operator_from_copy
		jmp	short loc_98
loc_97:
		lea	cx,ds:[default_operator_0]	; Load effective addr
		call	load_operator_from_copy
loc_98:
		inc	di
		cmp	di,OPL_NUM_OPERATORS
		jl	loc_96			; Jump if <
		pop	di
		pop	dx
		pop	cx
		pop	bx
		retn
opl_load_default_operators		endp

; copies OPL operator information from cs:[cx] to operator [bx]
; then calls opl_set_all to program the values in the OPL registers
load_operator	proc	near
		push	cx
		push	dx
		push	si
		push	di
		mov	si,bx

                opl_mult_by_14 si

		push	dx
		xor	di,di			; Zero register
loc_99:
		push	di
		mov	di,cx
		mov	dl,cs:[di]
		mov	cs:ksl[si],dl
		pop	di
		inc	si
		inc	cx
		inc	di
		cmp	di,13
		jl	loc_99
		pop	dx

                ; last byte is explicitly masked (it should be the waveform type)
		and	dl,3
		mov	cs:ksl[si],dl
		push	bx
		call	opl_set_all
		pop	bx
		pop	di
		pop	si
		pop	dx
		pop	cx
		retn
load_operator	endp

load_operator_from_copy		proc	near
		push	bx
		push	cx
		push	dx
		push	di

		push	si
		xor	di,di
		mov	si,cx
		xor	ch,ch
loc_100:
		mov	cl,cs:[si]
		mov	cs:data_59[di],cl
		inc	si
		inc	di
		cmp	di,13
		jl	loc_100			; Jump if <
		pop	si

		lea	cx,[data_59]		; Load effective addr
		call	load_operator
		pop	di
		pop	dx
		pop	cx
		pop	bx
		retn
load_operator_from_copy		endp

opl_set_all	proc	near
		call	opl_set_trem_vib_depth
		call	opl_set_freq_vibrato
		call	opl_set_ksl_outputlevel
		call	opl_set_feedback_syn
		call	opl_set_attack_decay_rate
		call	opl_set_sustain_release
		call	opl_set_flags
		call	opl_set_waveform
		retn
opl_set_all	endp


opl_set_ksl_outputlevel		proc	near
		push	ax
		push	bx
		push	cx
		push	di
		mov	di,bx

                opl_mult_by_14 di

		xor	ah,ah
		mov	al,cs:ksl[di]
		mov	cl,6
		shl	al,cl
		mov	cx,ax                   ; cx = ksl[di] << 6
		mov	al,cs:output_level[di]
		and	al,3Fh
		or	cl,al                   ; cl = (ksl[di] << 6) | (output_level[di] & 0x3f)

		xor	bh,bh
		mov	di,bx
		mov	bl,cs:op_2x_4x_6x_8x_e0_map[di]
		add	bl,OPL_KEYSCALE_OUTPUT_LEVEL
		call	write_reg
		pop	di
		pop	cx
		pop	bx
		pop	ax
		retn
opl_set_ksl_outputlevel		endp

; this will always clear the "CSM sel" bit, which selects FM music mode
opl_set_freq_vibrato		proc	near
		push	bx
		push	cx
		xor	cx,cx			; Zero register
		cmp	cs:freq_vibrato_onoff,0
		je	loc_101			; Jump if equal
		mov	cl,40h			; '@'
loc_101:
		mov	bx,OPL_CSW_NOTESEL
		call	write_reg
		pop	cx
		pop	bx
		retn
opl_set_freq_vibrato		endp

; bx = fm channel
opl_set_feedback_syn		proc	near
		push	bx
		push	cx
		push	di
		mov	di,bx
		cmp	cs:operator_group[di],0
		jne	loc_103			; Jump if not equal

                ; operator belongs to group 1 - set the feedback/algorithm flags
                opl_mult_by_14 di

		xor	ah,ah			; Zero register
		mov	al,cs:feedback[di]
		shl	ax,1
		mov	cx,ax                   ; cx = feedback[di] << 1
		cmp	cs:synthesis_type[di],0
		jne	loc_102

                ; adlib_sb.txt: if set to 0, operator 1 modulates operator 2
                ; (and only operator 2 produces sound). otherwise, both operators
                ; produce sound directly
		inc	cl                      ; set synthesis type bit (inverted!)
loc_102:
		mov	di,bx
		xor	bh,bh
		mov	bl,cs:reg_c0_map[di]
		add	bl,OPL_FEEDBACK_SYNTHESIS
		and	cl,0Fh
		call	write_reg
loc_103:
		pop	di
		pop	cx
		pop	bx
		retn
opl_set_feedback_syn		endp

opl_set_attack_decay_rate		proc	near
		push	bx
		push	cx
		push	di
		mov	di,bx

                opl_mult_by_14 di

		xor	ah,ah
		mov	al,cs:attack_rate[di]
		mov	cl,4
		shl	al,cl
		mov	cx,ax                   ; cl = attack_rate[di] << 4
		mov	al,cs:decay_rate[di]
		and	al,0Fh
		or	cl,al                   ; cl = (decay_rate[di] & 0xf) | (attack_rate[di] << 4)
		mov	di,bx
		xor	bh,bh
		mov	bl,cs:op_2x_4x_6x_8x_e0_map[di]
		add	bl,OPL_ATTACK_DECAY_RATE
		call	write_reg
		pop	di
		pop	cx
		pop	bx
		retn
opl_set_attack_decay_rate		endp

opl_set_sustain_release		proc	near
		push	bx
		push	cx

		push	di
		mov	di,bx

                opl_mult_by_14 di

		xor	ah,ah
		mov	al,cs:sustain_level[di]
		mov	cl,4
		shl	al,cl
		mov	cx,ax                   ; cl = sustain_level[di] << 4
		mov	al,cs:release_rate[di]
		and	al,0Fh
		or	cl,al                   ; cl = (sustain_level[di] << 4) | (release_rate[di] & 0xf)
		mov	di,bx
		xor	bh,bh			; Zero register
		mov	bl,cs:op_2x_4x_6x_8x_e0_map[di]
		add	bl,OPL_SUSTAIN_RELEASE_RATE
		call	write_reg
		pop	di
		pop	cx
		pop	bx
		retn
opl_set_sustain_release		endp

opl_set_flags		proc	near
		push	cx
		push	di
		mov	di,bx

                opl_mult_by_14 di

		xor	ah,ah			; Zero register
		mov	al,cs:apply_ampl_mod[di]
		xor	cx,cx			; Zero register
		or	al,al			; Zero ?
		jz	loc_104			; Jump if zero
		or	cl,80h
loc_104:
		mov	al,cs:apply_vibrato[di]
		or	al,al			; Zero ?
		jz	loc_105			; Jump if zero
		or	cl,40h			; '@'
loc_105:
		mov	al,cs:sound_sustain[di]
		or	al,al			; Zero ?
		jz	loc_106			; Jump if zero
		or	cl,20h			; ' '
loc_106:
		mov	al,cs:envelope_scaling_ksr[di]
		or	al,al			; Zero ?
		jz	loc_107			; Jump if zero
		or	cl,10h
loc_107:
		mov	al,cs:freq_multiplication[di]
		and	al,0Fh
		or	cl,al

		push	bx
		mov	di,bx
		xor	bh,bh			; Zero register
		mov	bl,cs:op_2x_4x_6x_8x_e0_map[di]
		add	bl,OPL_TR_VIB_SUS_KSR_FREQ
		call	write_reg
		pop	bx
		pop	di
		pop	cx
		retn
opl_set_flags		endp


; note: tremolo_depth is always 0, vibrato_depth is always 0
opl_set_trem_vib_depth		proc	near
		push	bx
		push	cx
		xor	cx,cx			; Zero register
		cmp	cs:tremolo_depth,0
		je	loc_108			; Jump if equal
		or	cl,80h
loc_108:
		cmp	cs:vibrato_depth,0
		je	loc_109			; Jump if equal
		or	cl,40h			; '@'
loc_109:
		mov	bx,OPL_TRDEPTH_VIBDEPTH_PM
		call	write_reg
		pop	cx
		pop	bx
		retn
opl_set_trem_vib_depth		endp

opl_set_waveform		proc	near
		cmp	word ptr cs:waveform_sel_enable,0
		je	loc_ret_110		; Jump if equal
		push	bx
		push	cx
		push	di
		xor	bh,bh			; Zero register
		mov	di,bx

                opl_mult_by_14 di

		xor	ch,ch			; Zero register
		mov	cl,cs:waveform_select[di]
		mov	di,bx
		mov	bl,cs:op_2x_4x_6x_8x_e0_map[di]
		add	bl,OPL_WAVEFORM_SELECT
		call	write_reg
		pop	di
		pop	cx
		pop	bx

loc_ret_110:
		retn
opl_set_waveform		endp

;; TODO I think this will update the note to the given one ...
; called with dx=0 and dx=1 ... - bx is the FM channel
; some users supply 'cl = cur_note[bx]' to avoid changing it ...
sub_35		proc	near
		push	ax
		push	si
		mov	cs:data_33[bx],dl
		mov	cs:cur_note[bx],cl
		cmp	bp,FN_TERMINATE
		je	loc_111
		push	bx
		mov	bx,cs:orig_si

                ; if the volume was zero, do not do anything
		cmp	word ptr [bx+SND_VOLUME],0
		pop	bx
		jnz	loc_111
		pop	si
		pop	ax
		retn
loc_111:
		push	di
		push	cx
		push	bx
		push	dx
		xor	ch,ch			; Zero register
		mov	di,cx
		shl	di,1
		shl	di,1                    ; di = note << 2
		cmp	cs:pbend_dir[bx],0
		je	loc_112                 ; skip pbend delta if needed
		call	apply_pbend_delta
loc_112:
		cmp	di,0FFFFh
		jne	loc_113
		jmp	short loc_114
		nop

loc_113:        ; di != 0FFFFh, note is okay?
		mov	si,di
		shl	di,1			; Shift w/zeros fill
		mov	dx,cs:freq_number[di]
		mov	cl,dl
		add	bx,OPL_FREQ_NUMBER
		call	write_reg
		pop	dx
		pop	bx
		push	bx
		push	dx
		add	bx,OPL_KEYON_BLOCKNR_FNUM

		xor	ah,ah
		mov	al,dl
		shl	al,1
		shl	al,1
		shl	al,1                    ; al = dl << 3
		xor	ch,ch
		xor	dh,dh
		mov	dl,cs:block_nr[si]
		or	al,dl                   ; al = (orig_dl << 3) | block_nr[si]
		shl	al,1
		shl	al,1                    ; al = (orig_dl << 5) | block_nr[si] << 2
		mov	dx,cs:freq_number[di]
		mov	cl,8
		shr	dx,cl
		or	ax,dx                   ; ax = (freq_number[di] >> 8) | (orig_dl << 5) | block_nr[si] << 2
                ; B0-B8: Key On / Block Number / F-Number(hi bits)
                ; Block Number = block_nr[si]
                ; Frequency Num = high byte of freq_number[di] (must be 0..3)
                ; Note On = orig_dl
		mov	cx,ax
		call	write_reg
loc_114:
		pop	dx
		pop	bx
		pop	cx
		pop	di
		pop	si
		pop	ax
		retn
sub_35		endp

; writes zero to frequency, key-on, blocknr and f-num, efficiently silencing FM channel [bx]
opl_reset_freq	proc	near
		push	cx
		push	bx
		xor	cx,cx			; Zero register
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


;
; adlib: write value [cl] into register [bl]
;
write_reg	proc	near
		push	ax
		push	dx
		mov	dx,388h
		mov	ax,bx
		out	dx,al			; port 388h, comm 8273 command
		push	cx
		mov	cx,6

locloop_115:
		in	al,dx			; port 388h, comm 8273 status
		loop	locloop_115		; Loop if cx > 0

		pop	cx
		inc	dx
		mov	ax,cx
		out	dx,al			; port 389h, comm 8273 parametr
		dec	dx
		push	cx
		mov	cx,25h

locloop_116:
		in	al,dx			; port 388h, comm 8273 status
		loop	locloop_116		; Loop if cx > 0

		pop	cx
		pop	dx
		pop	ax
		retn
write_reg	endp

; input: di = value, updates value based on pbend_delta/pbend_dir (clips to 0ffffh)
apply_pbend_delta proc	near
		push	cx
		xor	ch,ch
		mov	cl,cs:pbend_delta[bx]
		cmp	cs:pbend_dir[bx],1
		jne	loc_117

                ; pbend_dir[bx] = 1 --> di += pbend_delta[bx]
		add	di,cx
		jmp	short loc_118
loc_117:

                ; pbend_dir[bx] = -1 --> di -= pbend_delta[bx]
		sub	di,cx

loc_118:
		cmp	di,0
		jge	loc_119
		mov	di,0FFFFh
		jmp	short loc_120
loc_119:
		cmp	di,1FCh
		jle	loc_120
		mov	di,0FFFFh
loc_120:
		pop	cx
		retn
apply_pbend_delta endp

; if bx=0ffffh, processes all channels - otherwise just channel bx
; pchange / control_map_ch specify a channel
; ??? I wonder if this applies volume change... ???
sub_39		proc	near
		push	ax
		push	bx
		push	dx
		push	di
		push	si
		cmp	bx,0FFFFh
		jne	loc_121
		mov	si,OPL_NUM_VOICES
		xor	bx,bx
		jmp	short loc_122
loc_121:
		mov	si,1
loc_122:
		push	bx
		shl	bx,1			; Shift w/zeros fill
		cmp	cs:op1_modulates_op2[bx],0FFFFh
		je	loc_123			; Jump if equal
		call	sub_40
loc_123:
		call	sub_41
		pop	bx
		inc	bx
		cmp	bx,si
		jl	loc_122			; Jump if <

		pop	si
		pop	di
		pop	dx
		pop	bx
		pop	ax
		retn
sub_39		endp


; only called if op1_modulates_op2 == 0, which means both operators are in synthesis
; (seems to program op1_ksl with the appropriate output volume from data_70)
sub_40		proc	near
		push	ax
		push	bx
		push	cx
		mov	dx,cs:op1_ksl[bx]
		mov	cl,6
		shl	dl,cl			; dl = op1_ksl[bx] << 6 (this is ksl)
		pop	cx
		push	dx
		shr	bx,1
		cmp	cs:data_9[bx],0
		je	loc_124			; Jump if equal

                ; used if data_9[bx] != 0
		xor	dh,dh
		mov	dl,cs:data_9[bx]
		shr	dl,1                    ; dl = data_9[bx] >> 1
		shl	bx,1
		jmp	short loc_125
loc_124:
                ; used if data_9[bx] == 0
		shl	bx,1
		mov	dx,cs:op1_amplitude[bx]       ; dx = op1_amplitude[bx]
loc_125:
		push	di
		cmp	cs:volume_override,0
		je	loc_126			; Jump if equal
		mov	di,cs:volume_override
		jmp	short loc_127
loc_126:
		push	bx
		mov	bx,cs:orig_si
		mov	di,[bx+SND_VOLUME]
		pop	bx
loc_127:        ; now, di = volume (SND_VOLUME or volume_override)
		shl	di,1
		shl	di,1
		shl	di,1
		shl	di,1
		shl	di,1
		shl	di,1
		add	di,dx                   ; di = volume << 6 + dx (data_9[bx] >> 1, or op1_amplitude[bx])
		mov	al,3Fh
		mov	dl,cs:data_70[di]
		sub	al,dl                   ; al = 63 - data_70[volume << 6 + dx]
		pop	di
		pop	dx
		or	dl,al                   ; dx = (cs:op1_ksl[bx] << 6) | (63 - ...)

		push	cx
		xor	ch,ch			; Zero register
		mov	cl,cs:operator_map[bx]
		mov	di,cx                   ; di = operator_map[bx]
		mov	bl,cs:op_2x_4x_6x_8x_e0_map[di]
		add	bl,OPL_KEYSCALE_OUTPUT_LEVEL
		mov	cx,dx
		call	write_reg
		pop	cx
		pop	bx
		pop	ax
		retn
sub_40		endp

; seems to program operator2
sub_41		proc	near
		push	ax
		push	bx
		call	sub_42
		push	dx
		shr	bx,1			; Shift w/zeros fill
		cmp	cs:data_9[bx],0
		je	loc_128			; Jump if equal

                ; data_9[bx] != 0 --> dx = data_9[bx] >> 1
		xor	dh,dh			; Zero register
		mov	dl,cs:data_9[bx]
		shr	dl,1
		shl	bx,1
		jmp	short loc_129
loc_128:
                ; data_9[bx] -- 0 --> dx = op2_amplitude[bx]
		shl	bx,1
		mov	dx,cs:op2_amplitude[bx]
loc_129:
		call	sub_43
		pop	dx
		call	sub_44
		pop	bx
		pop	ax
		retn
sub_41		endp


; returns dl = op2_ksl[bx] << 6
sub_42		proc	near
		push	cx
		mov	dx,cs:op2_ksl[bx]
		mov	cl,6
		shl	dl,cl			; Shift w/zeros fill
		pop	cx
		retn
sub_42		endp


; seems to do something with volume? expects a parameter in dx
; returns 63 - data_70[volume >> 6 + dx]
sub_43		proc	near
		push	di
		cmp	cs:volume_override,0
		je	loc_130			; Jump if equal
		mov	di,cs:volume_override
		jmp	short loc_131
loc_130:
		push	bx
		mov	bx,cs:orig_si
		mov	di,[bx+SND_VOLUME]
		pop	bx
loc_131:
		shl	di,1
		shl	di,1
		shl	di,1
		shl	di,1
		shl	di,1
		shl	di,1
		add	di,dx                   ; di = volume >> 6 + dx
		mov	al,3Fh
		mov	dl,cs:data_70[di]       ; dl = data_70[volume >> 6 + dx]
		sub	al,dl
		pop	di
		retn
sub_43		endp

sub_44		proc	near
		push	cx
		or	dl,al
		inc	bx
		xor	ch,ch			; Zero register
		mov	cl,cs:operator_map[bx]
		mov	di,cx
		mov	bl,cs:op_2x_4x_6x_8x_e0_map[di]
		add	bl,OPL_KEYSCALE_OUTPUT_LEVEL
		mov	cx,dx
		call	write_reg
		pop	cx
		retn
sub_44		endp

set_volume      proc    near
		cmp	cs:volume_override,0
		jne	loc_ret_132		; Jump if not equal
		push	bx
		push	cx
		mov	bx,0FFFFh
		call	sub_39
		pop	cx
		pop	bx

loc_ret_132:
		retn
set_volume      endp

; only calles if volume_override>0
handle_volume_override		proc	near
		push	bx
		push	cx
		dec	cs:volume_override_delay
		cmp	cs:volume_override_delay,0
		jne	loc_134

		dec	cs:volume_override
		cmp	cs:volume_override,0
		jne	loc_133

                ; volume overriden to zero - stop the sound and mark as finished
		call	terminate
		mov	word ptr [bx+SND_UNK],0
		mov	word ptr [bx+SND_SIGNAL],0FFFFh
		jmp	short loc_134

loc_133:        ; next step of volume_override
		mov	bx,0FFFFh
		call	sub_39
		mov	cx,8
		add	cx,2
		shl	cx,1
		mov	cs:volume_override_delay,cx           ; volume_override_delay = 20
loc_134:
		pop	cx
		pop	bx
		retn
handle_volume_override		endp

fade_out        proc    near
		push	bx
		push	cx
		mov	bx,cs:orig_si
		mov	cx,[bx+SND_VOLUME]
		mov	cs:volume_override,cx
		or	cx,cx			; Zero ?
		jnz	loc_135			; Jump if not zero
		call	terminate
		mov	word ptr [bx+SND_UNK],0
		mov	word ptr [bx+SND_SIGNAL],0FFFFh
loc_135:
		pop	cx
		pop	bx
		ret
fade_out        endp

; func 4: cleans up the driver
terminate	proc	near
		cli				; Disable interrupts
		call	pause_sound
		mov	bx,cs:orig_si
		mov	word ptr [bx+SND_SIGNAL],0FFFFh
		sti				; Enable interrupts
		retn
terminate	endp

pause_sound	proc	near
		push	di
		push	bx
		xor	di,di			; Zero register
loc_136:
		mov	bx,di
		call	sub_22
		inc	di
		cmp	di,OPL_NUM_VOICES
		jl	loc_136

                ; skip further processing if not pause_sound command
		cmp	bp,FN_PAUSE_SOUND
		jne	loc_137

		cmp	cs:reset_pause_active,0
		je	loc_137
		mov	bx,cs:orig_si
		mov	di,cs:loop_position
		mov	[bx+SND_POS],di
		mov	cs:midi_delay_left,0
		mov	cs:midi_decode_state,2
loc_137:
		pop	bx
		pop	di
		retn
pause_sound	endp

seek_sound      proc    near
		cli				; Disable interrupts
		mov	bx,cs:orig_si
		mov	ax,[bx+SND_VOLUME]
		mov	word ptr [bx+SND_VOLUME],0
		mov	cx,[bx+SND_POS]
		push	ax
		push	cx
		push	si
		call	load_sound
		pop	si
                ; check if load succeeded (SND_STATE_VALID = 1)
;*		cmp	ax,1
		db	 3Dh, 01h, 00h		;  Fixup - byte match
		jnz	loc_141			; Jump if not zero
loc_138:
		push	si
		call	timer
		pop	si
		cmp	cs:reset_pause_active,0
		je	loc_139			; Jump if equal
		cmp	cs:loop_position,22h
		je	loc_139			; Jump if equal
		mov	cx,cs:loop_position
loc_139:
		mov	bx,cs:orig_si
		cmp	word ptr [bx+SND_SIGNAL],0FFFFh
		jne	loc_140			; Jump if not equal
		mov	cx,[bx+SND_POS]
loc_140:
		cmp	[bx+SND_POS],cx
		jb	loc_138			; Jump if below
loc_141:
		pop	cx
		pop	ax
		mov	[bx+SND_VOLUME],ax
		or	ax,ax			; Zero ?
		jz	loc_142			; Jump if zero
		mov	bx,0FFFFh
		call	sub_39
loc_142:
		sti				; Enable interrupts
		ret
seek_sound      endp
			                        ;* No entry point to code

; get device info
func_0          proc    near
		mov	ax,3                    ; patch.003
		mov	cx,OPL_NUM_VOICES       ; maximum polyphony
                ret
func_0          endp

; initialization - this copies the supplied patch.003 data to data_75
func_2          proc near
		mov	bx,cs:orig_si
		mov	di,[bx+SND_RESPTR]
		mov	es,[di+2]
		mov	si,[di]                 ; es:si = patch data
		xor	di,di

		mov	cx,48*28                ; first half of data_75
locloop_143:
		mov	bl,es:[si]
		mov	byte ptr cs:data_75[di],bl
		inc	si
		inc	di
		loop	locloop_143

                ; fetch word at offset 0x540 - if it is 0xabcd, 48*28 more bytes
                ; will be copied
		mov	bh,es:[si]
		inc	si
		mov	bl,es:[si]
		inc	si
		cmp	bx,0ABCDh
		jne	loc_145

		mov	cx,48*28                ; second half of data_75
locloop_144:
		mov	bl,es:[si]
		mov	byte ptr cs:data_75[di],bl
		inc	si
		inc	di
		loop	locloop_144

loc_145:        ; reset OPL to a silent state
		call	opl_reset
		mov	cs:volume_override,0

                ; change init function to terminate
		mov	bx,2
		mov	cs:func_tab[bx],terminate
		mov	ax,func_0
		xor	cx,cx
		ret
func_2          endp

seg_a		ends
		end	start

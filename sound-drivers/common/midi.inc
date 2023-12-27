MIDI_NOTE_ON                    equ 090h
MIDI_NOTE_OFF                   equ 080h
MIDI_CONTROL                    equ 0B0h
MIDI_PCHANGE                    equ 0C0h
MIDI_AFTERTOUCH                 equ 0D0h
MIDI_PBEND                      equ 0E0h
MIDI_SYSEX_BEGIN                equ 0F0h
MIDI_SYSEX_END                  equ 0F7h
MIDI_DELAY_240                  equ 0F8h
MIDI_END_OF_SONG                equ 0FCh

; https://www.midi.org/specifications-old/item/table-3-control-change-messages-data-bytes-2
MIDI_CONTROL_MOD_WHEEL_LEVER        equ 01h
MIDI_CONTROL_CH_VOLUME              equ 07h
MIDI_CONTROL_PAN                    equ 0ah
MIDI_CONTROL_DAMPER_PEDAL_ON_OFF    equ 40h
MIDI_CONTROL_DECAY_TIME             equ 4Bh     ; sound controler 6 (MMA RP-021)
MIDI_CONTROL_RESET_ON_PAUSE         equ 4Ch
MIDI_CONTROL_UNKNOWN_4E             equ 4Eh
MIDI_CONTROL_UNKNOWN_50             equ 50h
MIDI_CONTROL_CUMULATIVE_CUE         equ 60h
MIDI_CONTROL_ALL_NOTES_OFF          equ 07Bh

MIDI_PCHANGE_SET_LOOP_POINT         equ 7Fh

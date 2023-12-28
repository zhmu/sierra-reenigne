; bit used in channels to filter device support
SND_CHANBIT_MT32                equ 01h
SND_CHANBIT_ADLIB               equ 04h

SND_RESPTR                      equ 8
SND_UNK                         equ 0ah
SND_POS                         equ 0ch
SND_STATE                       equ 10h
SND_STATE_VALID                 equ 1
SND_STATE_INVALID               equ 3
SND_SIGNAL                      equ 16h
SND_VOLUME                      equ 18h

FN_TERMINATE                    equ 04h
FN_STOP_SOUND                   equ 0eh
FN_PAUSE_SOUND                  equ 10h
FN_SEEK_SOUND                   equ 12h

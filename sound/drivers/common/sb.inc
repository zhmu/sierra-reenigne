DSP_PORT_RESET_W    equ     06h
DSP_PORT_DATA_R     equ     0ah
DSP_PORT_DATACMD_W  equ     0ch
DSP_PORT_WRBUF_R    equ     0ch
DSP_PORT_RDBUF_R    equ     0eh

DSP_CMD_OUTPUT_8BIT_SINGECYCLE_DMA  equ 14h
DSP_CMD_OUTPUT_8BIT_AUTOINIT_DMA    equ 1Ch
DSP_CMD_SET_TIME_CONSTANT           equ 40h ; p99
DSP_CMD_SET_BLOCK_TRANSFER_SIZE     equ 48h ; p101
DSP_CMD_PAUSE_8BIT_SOUND            equ 0d0h ; p109
DSP_CMD_TURN_ON_SPEAKER             equ 0d1h ; p110
DSP_CMD_TURN_OFF_SPEAKER            equ 0d3h ; p111
DSP_CMD_CONTINUE_8BIT_SOUND         equ 0d4h ; p111
DSP_CMD_ECHO_INVERTED               equ 0e0h ; undocumented?
DSP_CMD_GET_VERSION                 equ 0e1h ; p114


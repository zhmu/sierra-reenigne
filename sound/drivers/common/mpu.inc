MPU_PORT_DATA                   equ 330h
MPU_PORT_STATUS                 equ 331h

MPU_STATUS_DSR                  equ 80h     ; data set ready
MPU_STATUS_DRR                  equ 40h     ; data read ready

MPU_CMD_UART_MODE               equ 03Fh
MPU_CMD_CLEAR_PLAY_MAP          equ 0B9h        ; 5.7 (p31)
MPU_CMD_CHN_REF_TAB_A_OFF       equ 098h        ; p28
MPU_CMD_CHN_REF_TAB_B_OFF       equ 09Ah        ; p28
MPU_CMD_CHN_REF_TAB_C_OFF       equ 09Ch        ; p28
MPU_CMD_CHN_REF_TAB_D_OFF       equ 09Eh        ; p28
MPU_CMD_WTS                     equ 0D0h        ; want to send data (5.9, p33)
MPU_CMD_SYS_MSG                 equ 0DFh        ; want to send system message
MPU_CMD_RESET                   equ 0FFh

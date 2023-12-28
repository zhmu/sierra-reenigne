                    extern _timer_tick: dword
                    extern d_service_: proc

dgroup              group       _bss

_bss                segment public byte 'bss'
_bss                ends

_text               segment public byte 'code'
                    assume cs:_text, ds:dgroup

timer_irq           proc
                    push    ax
                    push    ds
                    push    es

                    mov     ax,seg DGROUP
                    mov     ds,ax
                    mov     es,ax

                    call    d_service_

timer_tick:
                    inc     word ptr [_timer_tick]
                    jnz     timer_skip_hi
                    inc     word ptr [_timer_tick+2]
timer_skip_hi:

                    mov     al,20h              ; pit: eoi
                    out     20h,al

                    pop     es
                    pop     ds
                    pop     ax
                    iret
timer_irq           endp

timer_irq_prev      dw      0, 0

public timer_hook_
timer_hook_         proc    near
                    push    ds
                    push    es
                    push    bx
                    push    dx

                    ; get old irq handler
                    mov     ax,3508h            ; dos: get interrupt vector (IRQ0)
                    int     21h
                    mov     word ptr cs:timer_irq_prev,bx
                    mov     word ptr cs:timer_irq_prev+2,es

                    ; set new irq handler
                    mov     ax,2508h            ; dos: set interrupt vector (IRQ0)
                    push    cs
                    pop     ds
                    mov     dx,offset timer_irq
                    int     21h

                    pop     dx
                    pop     bx
                    pop     es
                    pop     ds
                    ret
timer_hook_         endp

public timer_unhook_
timer_unhook_       proc    near
                    push    dx
                    mov     dx,word ptr cs:timer_irq_prev
                    mov     ax,word ptr cs:timer_irq_prev+2
                    push    ds
                    mov     ds,ax

                    ; re-program pit to what the bios likely uses
                    cli
                    mov     al,34h
                    out     43h,al              ; pit channel 0: mode 2 (rate generator), set lo/hi counter
                    xor     al,al               ; set counter to 65536
                    out     40h,al
                    out     40h,al
                    sti

                    mov     ax,2508h            ; dos: set interrupt vector (IRQ0)
                    int     21h

                    pop     ds
                    pop     dx
                    ret
timer_unhook_       endp

_text               ends
                    end

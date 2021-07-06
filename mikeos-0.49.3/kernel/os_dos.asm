; =================================================================
; MikeOS -- The Mike Operating System kernel
; Copyright (C) 2006, 2007 MikeOS Developers -- see LICENSE.TXT
;
; DOS COMPATIBILITY INTERRUPT HANDLERS
; NOTE: Most DOS calls are unimplemented; in the meantime we use
; filler values -- eg returning a failure flag for all disk operations
; =================================================================


; -----------------------------------------------------------------
; Interrupt call parsers

os_compat_int00:				; Division by 0 error handler
        cmp byte [now_run_a_program], 0		; The program or the OS generated
        jz .restartos
        call os_print_newline
        mov si, .msg1
        call os_print_string
        jmp os_compat_int20

.restartos:					; If the OS then restart
        call os_print_newline
        mov si, .msg2
        call os_print_string
	call os_wait_for_key
	jmp os_int_reboot

        .msg1 db 'Divide by zero error! The program exited.', 10, 13, 0
        .msg2 db 'Fatal error! Divide by zero error. Press any key to reboot', 10, 13, 0


os_compat_int06:			; Invalid opcode handler
	mov ax, 3			; Set to normal (80x25 text) video mode
	int 10h

	mov si, .msg
	call os_print_string
	call os_wait_for_key
	jmp os_main

	.msg db 10, 13, 10, 13, 'Bad opcode - restarting MikeOS', 10, 13, 0


os_compat_int1B:                                   ; CTRL+BREAK handler
        pusha                                      ; NOT work
        cmp byte [now_run_a_program], 0            ; Program run or OS
        jz .return                                 ; if the OS, do nothing
        mov byte [dos_break_pressed], 1            ; else set break to 1
.return:
        mov si, .msg
        call os_print_string
        popa
        iret                                       ; return

        .msg db 'Control + break pressed', 10, 13, 0


os_compat_int20:                                   ; Exit app handler
        call os_print_newline
        mov sp,[os_program_load.mainstack]          ; restore os stack
        push cs                                    ; Set the return address
        push word os_program_load.end_the_program   ; cs:end_the_program
        iret                                       ; return to os


os_compat_int33:			; Mouse interrupt handler
	mov ax, 0			; Just say mouse not installed
	ret

	cmp ax, 0
	je near dos_mouse_init

	mov si, .msg
	call os_print_string
	call os_wait_for_key
	jmp os_int_reboot

	.msg db 10, 13, 10, 13, 'Unimplemented DOS mouse call - rebooting', 10, 13, 0


os_compat_int21:			; General DOS call handler

        cmp byte [dos_break_pressed], 1	; Check for Ctrl+C before doing anything
        je near dos_handle_break

	cmp ah, 0h
	je near dos_exit_program

	cmp ah, 1h
	je near dos_read_echo_char

	cmp ah, 2h
	je near dos_print_char

	cmp ah, 3h
	je near dos_receive_char

	cmp ah, 4h
	je near	dos_send_char

        cmp ah, 5h
        je near dos_printer_char

	cmp ah, 6h
	je near dos_direct_console

	cmp ah, 7h
	je near dos_read_char

	cmp ah, 8h
	je near dos_read_char_no_echo

	cmp ah, 9h
	je near dos_print_string

	cmp ah, 1Ah
	je near dos_set_dta

	cmp ah, 0Ah
	je near dos_input_string

	cmp ah, 0Bh
	je near dos_input_status

	cmp ah, 0Ch
	je near dos_flush_and_read

        cmp ah,0Dh
        je near dos_reset_disk

        cmp ah, 0Eh
        je near dos_set_current_drive

        cmp ah, 18h
        je near dos_cpm_compat

        cmp ah, 19h
        je near dos_get_current_drive

        cmp ah, 1Dh
        je near dos_cpm_compat

        cmp ah, 1Eh
        je near dos_cpm_compat

        cmp ah, 20h
        je near dos_cpm_compat

	cmp ah, 25h
	je near dos_set_vector

	cmp ah, 2Ah
	je near dos_get_date

        cmp ah, 2Bh
        je near dos_set_date

        cmp ah, 2Ch
        je near dos_get_time

	cmp ah, 30h
	je near dos_get_version

	cmp ah, 39h
	je near dos_mkdir

	cmp ah, 3Ah
	je near dos_rmdir

	cmp ah, 3Bh
	je near dos_chdir

	cmp ah, 3Ch
	je near dos_creat

	cmp ah, 3Dh
	je near dos_open

	cmp ah, 3Eh
	je near dos_close

	cmp ah, 41h
	je near dos_unlink

	cmp ah, 4Ch
	je near dos_stop_program

	mov al, ah			; If not handled, print message about it
	xor ah, ah			; Get call number (AH) for conversion

	push ax
	mov ax, 3			; Set to normal (80x25 text) video mode
	int 10h
	pop ax

        call ByteToHexStr
        mov [.int_num], ax
        mov si, .msg_notify
        call os_print_string

        xor ax,ax
        jmp near dos_stop_program       ; The program call the interrupt
                                        ; and not the interrupt the program


        .msg_notify     db 'DOS compat: int 21h called.',10,13
                        db 'Function '
        .int_num        dw  0
                        db 'h unimplemented.',10,13
                        db 'Program halted.', 10,13,0


; -----------------------------------------------------------------
; DOS exit program (int 21h, AH = 0h)

dos_exit_program:
        jmp os_compat_int20


; -----------------------------------------------------------------
; DOS read and echo character (int 21h, AH = 1h)

dos_read_echo_char:
	pusha

	call os_wait_for_key

	mov [.tmp], al

	mov ah, 0Eh		; Echo to screen
	int 10

	popa

	mov al, [.tmp]
	iret


	.tmp db 0


; -----------------------------------------------------------------
; DOS print character (int 21h, AH = 2h)

dos_print_char:
	pusha

	mov al, dl
	mov ah, 0Eh		; int 10h teletype function
	int 10h

	mov [.tmp], dl

	popa			; DOS expects AL = DL on exit

	mov al, [.tmp]
	iret


	.tmp db 0


; -----------------------------------------------------------------
; DOS read character from STDAUX (int 21h, AH = 3h)

dos_receive_char:

.notready:
	push dx
	push ax
        cmp byte [dos_ctrl_c_flag],0 ; Need check Ctrl+C
        jz .recv
	call iskeypressed ; Do not call OS routine. It returns only AL
	cmp ax,0
	jz .recv
	cmp ax,0x2E03	  ; CTRL+C ?
	jnz .recv	  ;
	pop ax		  ; Yes. Quit.
	pop dx
	iret
.recv:
	pop ax
   	mov  dx,[comport]
   	add  dx,0x05
   	in   al,dx
   	and  al,00000001b ; Data ready?
	jz .notready	  ;
   	mov  dx,[comport]
   	in   al,dx        ; Read RBR
	pop  dx
	iret


; -----------------------------------------------------------------
; DOS write character to STDAUX (int 21h, AH = 4h)

dos_send_char:
	pusha
   	mov ah,dl	  ; DL = Character to write
   	mov dx,[comport]
   	add dx,0x05	  ; Line Status Register
.wait:
	push ax
        cmp byte [dos_ctrl_c_flag],0 ; Need check Ctrl+C
        jz .send
	call iskeypressed ; Do not call OS routine. It returns only AL
	jz .send
	cmp ax,0x2E03	  ; CTRL+C ?
	jnz .send
	pop ax
	popa
	iret
.send
	pop ax
   	in  al,dx
   	and al,00100000b  ; Port is
        jz  .wait         ; busy?
   	sub dx,5
   	mov al,ah
   	out dx,al
	popa
	iret


; -----------------------------------------------------------------
; DOS print character via printer (int 21h, AH = 05h)

dos_printer_char:

        push ax
        push dx

.printit:
        xor ax,ax
        mov al,dl             ; AL = chararcter to print
        xor dx,dx             ; Printer number 0
        int 17h               ; print it
        push ax

        and al,00001000b      ; I/O Error
        jnz .IOError

        pop ax
        push ax

        and al,00100000b      ; No Paper
        jnz .NoPaper

        pop ax
        push ax

        and al,10000000b      ; NOT Busy
        jz .busy
        pop ax

.return:
        mov byte [.probes],0  ; Restore probes
        pop dx
        pop ax
        iret

.IOError:
        pop ax
        mov si,.IOmsg
        call os_print_string
        jmp .return

.NoPaper:
        pop ax
        mov si,.Papermsg
        call os_print_string
        jmp .return

.busy:                          ; If busy, DOS wait
        pop ax                  ; It was at 1980
        inc byte [.probes]      ; Now, we not have time :)
        cmp byte [.probes],3    ; Only 3 probe, and we go away.
        jnz  .printit           ;
        mov si, .busymsg        ;
        call os_print_string    ;
        jmp .return             ;

        .probes   db 0
        .IOmsg    db 'I/O Error while printing. Please verify printer',10,13,0
        .Papermsg db 'No Paper. Please verify printer',10,13,0
        .busymsg  db 'Printer is busy. Please probe later',10,13,0


; -----------------------------------------------------------------
; DOS direct console input/output (int 21h, AH = 6h)

dos_direct_console:
	pusha

	cmp dl, 255
	je .input_mode

	mov al, dl		; Output mode
	mov ah, 0Eh
	int 10h

	mov [.tmp], dl
	jmp .output_done


.input_mode:
	call os_check_for_key
	cmp al, 0		; Sets zero flag if nothing, as DOS requires
	iret


.output_done:
	popa

	mov al, [.tmp]
	iret


	.tmp db 0

; -----------------------------------------------------------------
; DOS read character (int 21h, AH = 7h)

dos_read_char:
	pusha

	call os_wait_for_key

	mov [.tmp], al

	popa

	mov al, [.tmp]
	iret


	.tmp db 0


; -----------------------------------------------------------------
; DOS read character without echo (int 21h, AH = 8h)

dos_read_char_no_echo:
	call os_wait_for_key
	xor ah, ah
	iret


; -----------------------------------------------------------------
; DOS print string (int 21h, AH = 9h)

dos_print_string:
	pusha

	mov si, dx
	mov ah, 0Eh		; int 10h teletype function

.repeat:
	lodsb			; Get char from string
	cmp al, '$'
	je .done		; If char is '$' character, end of string
	int 10h			; Otherwise, print it
	jmp .repeat

.done:
	popa
	iret


; -----------------------------------------------------------------
; DOS input string (int 21h, AH = 0Ah)

dos_input_string:
	pusha

	mov di, dx

	inc di			; Skip first byte (buffer size)
	inc di			; Skip second byte (chars entered)

	mov cx, 0		; Counter for characters entered

.more:
	call os_wait_for_key
	cmp al, 13		; Quit if enter pressed
	je .done

	mov [di], al		; Otherwise store entered char
	inc di			; And move on in the string
	inc cx
	jmp .more

.done:
	mov di, dx		; Starting point of string
	mov byte [di], 1	; Buffer size
	inc di
	mov [di], cx		; Chars read

	popa
	iret


; -----------------------------------------------------------------
; DOS input status (int 21h, AH = 0Bh)

dos_input_status:
        mov ax,0100h
	int 16h			; Check for keyboard buffer
	jz .nokey		; If nothing, blank AX
	mov al, 0FFh		; If something, set for DOS
	iret

.nokey:
	xor ax, ax
        iret


; -----------------------------------------------------------------
; DOS flush buffer and read standard input (int 21h, AH = 0Ch)
; Here, input AL = input function to execute after flushing buffer

dos_flush_and_read:
        push ax

.flush:				; Flush the keyboard buffer
        call iskeypressed	;
        cmp ax, 0		; and continue if empty
        jnz .flush		;

        pop ax

	cmp al, 01h
	je dos_read_echo_char

	cmp al, 06h
	je dos_direct_console

	cmp al, 07h
	je dos_read_char

	cmp al, 08h
	je dos_read_char_no_echo

	cmp al, 0Ah
	je dos_input_string

        iret    ; XXX -- Will we ever reach this? Yes! We will! :)


; -----------------------------------------------------------------
; DOS reset disk (int 21h, AH = 0Dh)
dos_reset_disk:
        pusha

        xor ax,ax
        mov dl, [dos_current_drive]
        int 0x13

        popa
        iret


; -----------------------------------------------------------------
; DOS set current drive (int 21h, AH = 0Eh)

dos_set_current_drive:
        mov al,1   ; In AL return the maximum drives
        cmp dh,0
        jnz .return
        mov [dos_current_drive],dh
.return:
        iret


; -----------------------------------------------------------------
; DOS set disk transfer area (int 21h, AH = 1Ah)

dos_set_dta:
	iret			; XXX -- Bail out -- not supported yet


; -----------------------------------------------------------------
; DOS null function for compatibility (int 21h, AH = 18h)

dos_cpm_compat:
	xor al,al  ; return al = 0
	iret


; -----------------------------------------------------------------
; DOS get current drive (int 21h, AH = 19h)

dos_get_current_drive:
        mov al, [dos_current_drive]
        iret


; -----------------------------------------------------------------
; DOS set interrupt vector (int 21h, AH = 25h)

dos_set_vector:
	pusha
	xor cx, cx
	mov cl, al
	mov si, dx
	call os_modify_int_handler
	popa
	iret


; -----------------------------------------------------------------
; DOS get date (int 21h, AH = 2Ah)

dos_get_date:
        mov ax,0400h      ; Get Date from BIOS
        int 1ah

        push dx           ; Conver date from BCD to binary
        mov dx,1000
        mov ax,cx
        and ax,0f000h
        shr ax,12
        mul dx
        mov [year],ax

        mov ax,cx
        and ax,0f00h
        shr ax,8
        mov dx,100
        mul dx
        add [year],ax

        mov ax,cx
        and ax,00f0h
        shr ax,4
        mov dx,10
        mul dx
        add [year],ax

        and cx,0fh
        add [year],cx
        xor bx,bx
        pop dx

        xor ax,ax
        mov al,dh
        mov cx,10
        and al,0f0h
        shr al,4
        push dx
        mul cx
        pop dx
        mov bh,al
        and dh,0fh
        add bh,dh

        mov al,dl
        mov cx,10
        and al,0f0h
        shr al,4
        push dx
        mul cx
        pop dx
        mov bl,al
        and dl,0fh
        add bl,dl

        mov dh,bh        ; set up registers
        mov dl,bl        ; and return from
        mov cx,[year]    ; interrupt
        mov al,0         ;

        clc
        iret

        year  dw 1        ; Must be store temporary
	month dw 1
	day   dw 1


; -----------------------------------------------------------------
; DOS set date (int 21h, AH = 2Bh)

dos_set_date:
	pusha

	xor ax,ax
                        ; Convert date from binary to BCD
	mov al,dl	; Calculate Day
	call ToBCD
	mov dl,al

	mov al,dh	; Calculate Month
	call ToBCD
	mov dh,al

        push bx         ; Calculate year and century
        push dx         ; if You can write this shorter
        mov ax,cx       ; please rewrite it. It is to long

	push ax
        shr ax,12
	and ax,0fh
	mov dx,1000
	mul dx
	mov bx,ax

	pop ax
	push ax
        shr ax,8
	and ax,0fh
	mov dx,100
	mul dx
	add bx,ax

	pop ax
	push ax
        shr ax,4
	and ax,0fh
	mov dx,10
	mul dx
	add bx,ax

	pop ax
	and ax,0fh
	add bx,ax
	pop dx
        pop bx

	mov cx,ax

        mov ah,05h      ; Set date (BIOS)
        int 1Ah         ; We not have self dos timer, because
        popa            ; we not need it

	iret

; -----------------------------------------------------------------
; DOS get time (int 21h, AH = 2Ch)

dos_get_time:
        mov ax,0x0200
        int 0x1A          ; Get Time from BIOS

                          ; And convert to binary. | Who was this idiot
        mov al,ch         ; Hour                   | by the Microsoft???
        call FromBCD      ;                        | It is good in BCD. No?
        mov ch,al

        mov al,cl         ; Min
        call FromBCD
        mov cl,al

        mov al,dh         ; Sec
        call FromBCD
        mov dh,al

        xor dl,dl         ;1/100 sec DOS (always) return 0

        iret


; -----------------------------------------------------------------
; DOS set time (int 21h, AH = 2Dh)

dos_set_time:

        pusha

        mov al,ch
        call ToBCD      ; Hour
        mov ch,al

        mov al,cl
        call ToBCD      ; Minutes
        mov cl,al

        mov al,dh
        call ToBCD      ; Seconds
        mov dh,al

        xor dl,dl       ; Midnight flag

        mov ax,0x0300
        int 0x1A        ; Set time with BIOS interrupt

        popa
        xor al,al       ; Al=0 -> Set time ok

        iret

; -----------------------------------------------------------------
; DOS get version (int 21h, AH = 30h)

dos_get_version:
	mov al, 1		; Major version number
	mov ah, 0		; Minor
	mov bl, 0		; Serial part 1
	mov cx, 0		; Serial part 2
	mov bh, 0		; Flags
	iret


; -----------------------------------------------------------------
; DOS make directory (int 21h, AH = 39h)

dos_mkdir:
	mov ax, 03h		; XXX - This always fails with AX = error number
	stc			; Carry flag = fail
	iret


; -----------------------------------------------------------------
; DOS remove directory (int 21h, AH = 3Ah)

dos_rmdir:
	mov ax, 03h		; XXX - This always fails with AX = error number
	stc			; Carry flag = fail
	iret


; -----------------------------------------------------------------
; DOS change directory (int 21h, AH = 3Bh)

dos_chdir:
	mov ax, 03h		; XXX - This always fails with AX = error number
	stc			; Carry flag = fail
	iret


; -----------------------------------------------------------------
; DOS create file (int 21h, AH = 3Ch)

dos_creat:
	mov ax, 03h		; XXX - This always fails with AX = error number
	stc			; Carry flag = fail
	iret


; -----------------------------------------------------------------
; DOS open file (int 21h, AH = 3Dh)

dos_open:
	mov ax, 03h		; XXX - This always fails with AX = error number
	stc			; Carry flag = fail
	iret


; -----------------------------------------------------------------
; DOS close file (int 21h, AH = 3Eh)

dos_close:
	mov ax, 03h		; XXX - This always fails with AX = error number
	stc			; Carry flag = fail
	iret


; -----------------------------------------------------------------
; DOS delete file (int 21h, AH = 41h)

dos_unlink:
	mov ax, 03h		; XXX - This always fails with AX = error number
	stc			; Carry flag = fail
	iret


; -----------------------------------------------------------------
; DOS stop program (int 21h, AH = 4Ch)

dos_stop_program:
	cmp al,0
	jz os_compat_int20

	call os_print_newline
	mov si,.msg
	call os_print_string

	jmp os_compat_int20

	.msg db 'DOS program exited with error.', 10, 13, 0


; -----------------------------------------------------------------
; DOS mouse initialisation (int 33h, AH = 0h)

dos_mouse_init:
	; XXX - This just tells the calling program that the mouse
	; is not available. Should be updated when MikeOS supports mice :-)
	mov ax, 0
	iret


; =================================================================
; Non-interrupt routines (other handlers)

; -----------------------------------------------------------------
; DOS initialization - setting up flags, ports, etc...

dos_init:

        pusha

.init_serialports:        ; Set Up Serial Ports and Modems

	push ds		  ; Save Data Segment
	mov bx,0x0040	  ; Set data segment to
	mov ds,bx	  ; 0x0040 (CMOS Data)
	xor bx,bx	  ; COM1 address at 0x0040:0000
        mov dx,[bx]       ; Move to dx the serialport
        pop ds            ; Restore ds

	cmp dx,0	  ; if 0 then we have not com port
	jz .not_have_serialports

   	mov [comport],dx  ; Save COM1 adrress for the DOS interrupt
	in  al,dx	  ; Read Port
	mov al,0x03	  ;
	and al,01111111b  ;
	add dx,0x3	  ; Line Control Register (LCR)
	out dx,al	  ;
	inc dx            ; Modem Control Register (MCR)
        in  al,dx         ;
        and al,$01        ;
        or  al,$0a        ;
	out dx,al         ; Set MCR
        mov dx,[comport]  ;
	in  al,dx         ; Read Receive Buffer Register (RBR)
        add dx,0x06       ;
	in  al,dx         ; Read Modem Status Register (MSR)
        dec dx            ;
	in  al,dx         ; Read Line Status Register (LSR)
        sub dx,3          ;
	in  al,dx         ; Read Interrupt Identification Register
   	mov dx,[comport]  ; Set COM port Speed to 9600 bps
   	add dx,0x03	  ; LCR
        in  al,dx         ;
        or  al,10000000b  ;
        out dx,al         ;
        mov bl,al         ;
        sub dx,0x03       ;
        mov ax,12         ; Modem speed 9600 BPS
        out dx,ax         ;
        add dx,0x03       ;
        mov al,bl         ;
        and al,01111111b  ;
   	out dx,al	  ; Port set up!

.not_have_serialports:
        popa
        ret


; -----------------------------------------------------------------
; DOS CTRL+BREAK handler routine

dos_handle_break:
        mov byte [dos_break_pressed],0   ; Clear flag
        call iskeypressed                ; Check keyboaed buffer
        cmp ax,0
        jz .empty                        ; if empty then continue
        mov ax,0100h                     ; else now will empty
        int 16h
        jmp dos_handle_break             ; if more than 1 char in buffer

.empty:
        call os_print_newline
        mov si,.msg                      ; print message
        call os_print_string
        jmp near os_compat_int20         ; return to os process

        .msg db 'CTRL break pressed. Program terminated',10,13,0


; =================================================================
; Common helper routines

; -----------------------------------------------------------------
; Keypressed - return ax

iskeypressed:
	mov ax,0x0100
	int 16h
	jz .nokey
	xor ax,ax
	int 0x16
	ret
.nokey:
	xor ax,ax
	ret


; -----------------------------------------------------------------
; ToBCD - byte to BCD converter - in AL, out AL

ToBCD:
	push cx
	push dx
	xor ah,ah
	mov cx,ax
	shr ax,4
	mov dx,10
	mul dx
	and cx,000fh
	add ax,cx
	pop dx
	pop cx
	ret


; -----------------------------------------------------------------
; FromBCD - BCD to byte converter - in AL, out AX

FromBCD:
	push bx
	push cx
	push dx

        and ax,00f0h
        shr ax,4
        mov dx,10
        mul dx
        mov bx,ax

        and ax,0fh
        add bx,ax

	mov ax,bx

	pop dx
	pop cx
	pop bx
	ret


; -----------------------------------------------------------------
; ByteToHexStr - Byte to hex string converter - input AL, output AX

ByteToHexStr:
	push bx
	push dx
	push ax
	and ax,0x0f
	mov bx,Hexs
	add bx,ax
	mov dh,[bx]
	pop ax
	and ax,00f0h
	shr ax,4
	mov bx,Hexs
	add bx,ax
	mov al,[bx]
	mov ah,dh
	pop dx
	pop bx
	ret


; =================================================================
; DOS variables and constants

Hexs db '0123456789ABCDEF'

dos_break_pressed  db 0 ; Ctrl+C pressed?
dos_ctrl_c_flag    db 1 ; Check ctrl+c or no
dos_verify_flag    db 0 ; Disk write verify flag
dos_current_drive  db 0 ; Current drive. (Now only A:(0) is valid)
comport            dw 0 ; Serial Port for use


; =================================================================


; =================================================================
; MikeOS -- The Mike Operating System kernel
; Copyright (C) 2006, 2007 MikeOS Developers -- see LICENSE.TXT
;
; This is loaded from floppy, by MIKEBOOT.BIN, as MIKEKERN.BIN.
; First section is 32K of empty space for program data (which we
; can load from disk and execute). Then we have the system call
; vectors, which start at a static point for programs to jump to.
; Following that is the main kernel code and system calls.
; =================================================================


	BITS 16
	%DEFINE MIKEOS_VER '0.49.4'


; -----------------------------------------------------------------
; Program data section -- Pad out for app space (DO NOT CHANGE)

os_app_data:
	db 0xCD, 0x20   ; PSP: CD 20 = 'int 20h', return to DOS -- XXX
	db 0xA0, 0x00	; PSP: Always A000h for COM executables

	times 32768-($-$$)	db 0		; 32K of program space


; -----------------------------------------------------------------
; API version -- For programs to check (at 0x8000) -- DO NOT MOVE!

os_api_version:
	db	'M01'			; MUST BE 3 BYTES


; -----------------------------------------------------------------
; OS call vectors -- Static location for system calls
; NOTE: THIS CANNOT BE MOVED, or it'll break the calls!
; Comments show exact locations of instructions in this section.

os_call_vectors:
	jmp os_main			; 0x8003 -- Called from bootloader

	call os_print_string		; 0x8006
	ret

	call os_move_cursor		; 0x800A
	ret

	call os_clear_screen		; 0x800E
	ret

	call os_print_horiz_line	; 0x8012
	ret

	call os_print_newline		; 0x8016
	ret

	call os_wait_for_key		; 0x801A
	ret

	call os_check_for_key		; 0x801E
	ret

	call os_int_to_string		; 0x8022
	ret

	call os_speaker_tone		; 0x8026
	ret

	call os_speaker_off		; 0x802A
	ret

	call os_program_load		; 0x802E
	ret

	call os_pause			; 0x8032
	ret

	call os_fatal_error		; 0x8036
	ret

	call os_draw_background		; 0x803A
	ret

	call os_string_length		; 0x803E
	ret

	call os_string_uppercase	; 0x8042
	ret

	call os_string_lowercase	; 0x8046
	ret

	call os_input_string		; 0x804A
	ret

	call os_string_copy		; 0x804E
	ret

	call os_dialog_box		; 0x8052
	ret

	call os_string_join		; 0x8056
	ret

	call os_modify_int_handler	; 0x805A
	ret

	call os_get_file_list		; 0x805E
	ret

	call os_string_compare		; 0x8062
	ret

	call os_string_chomp		; 0x8066
	ret

	call os_string_strip		; 0x806A
	ret

	call os_string_truncate		; 0x806E
	ret

	call os_bcd_to_int		; 0x8072
	ret

	call os_get_time_string		; 0x8076
	ret


; =================================================================
; START OF KERNEL CODE

os_main:
	cli
	mov ax, 0
	mov ss, ax			; Set stack segment and pointer
	mov sp, 0xF000
	sti

        mov cx, 00h                     ; Divide by 0 error handler
        mov si, os_compat_int00
	call os_modify_int_handler

	mov cx, 20h			; Set up DOS compatibility
	mov si, os_compat_int20
	call os_modify_int_handler

	mov cx, 21h
	mov si, os_compat_int21
	call os_modify_int_handler

	mov ax, 0x2000
	mov ds, ax			; Set data segment to where we loaded

	mov ax, 3			; Set to normal (80x25 text) video mode
	int 10h

	mov ch, 0			; Set cursor to solid block
	mov cl, 7
	mov ah, 1
	mov al, 3			; Must be video mode for buggy BIOSes!
	int 10h

	mov ax, 1003h			; Disable text blinking
	mov bx, 0
	int 10h

	mov ax, .os_init_msg		; Set up screen
	mov bx, .os_version_msg
	mov cx, 10011111b		; White text on light blue
	call os_draw_background

	mov ax, .dialog_string_1	; Ask if user wants GUI or CLI
	mov bx, .dialog_string_2
	mov cx, .dialog_string_3
	mov dx, 1

;	call os_dialog_box
; XXX -- Straight to GUI
mov ax, 0

	cmp ax, 0			; If OK selected, start GUI
	je near gui_mode

	call os_command_line		; Otherwise jump to CLI
	jmp os_int_reboot		; Should never reach this!


	.os_init_msg		db 'Welcome to MikeOS', 0
	.os_version_msg		db 'Version ', MIKEOS_VER, 0

	.dialog_string_1	db 'Thanks for trying out MikeOS!', 0
	.dialog_string_2	db 'Contact okachi@gmail.com for more info.', 0
	.dialog_string_3	db 'OK for GUI, Cancel for command-line.', 0


gui_mode:
	call gui_init			; Set video mode and clear screen

	mov si, menustring		; Display menu bar
	call gui_display_menubar

	mov bx, timestring		; Display clock
	call os_get_time_string

	mov cx, 576
	mov dx, 3
	mov si, timestring
	call gui_print_string

	mov ax, helpstring		; Display help bar at bottom
	call gui_draw_helpbox

	mov word [mouse_x], 320		; Initial mouse position
	mov word [mouse_y], 240

	call gui_mouse_init		; Start mouse control

	mov cx, 74h			; Install mouse interrupt handler
	mov si, os_mouse_handler
	call os_modify_int_handler

;	mov cx, 08h			; Install timer interrupt handler
;	mov si, os_timer_handler
;	call os_modify_int_handler



	call gui_file_selector

retry:
	hlt				; Don't max out the CPU!

	mov al, [mouse_status]
	test al, 01h
	jz nomouse

	mov ax, 1
	mov si, menustring
	mov cx, [mouse_x]
	mov dx, [mouse_y]
	call gui_print_string

nomouse:
	jmp retry


	menustring:	db 'MikeOS ', MIKEOS_VER, 0
	helpstring:	db 'Select a program to run, or Cancel to reboot.', 0
	timestring:	times 6 db 0


; =================================================================
; INTERRUPT HANDLERS -- For timer and keyboard

; -----------------------------------------------------------------
; PIT timer handler -- XXX broken?

os_timer_handler:			; We use this to draw the clock
	pusha

	xor bx, bx
	mov byte bl, [.counter]
	inc bl
	cmp bl, 255			; Don't draw too often
	jne .nowt

	call gui_draw_clock

	mov bl, 0

.nowt:
	mov byte [.counter], bl

	mov al, 20h			; Tell PIC we're done
	out 20h, al

	popa
	iret


	.counter db 0


; -----------------------------------------------------------------
; Mouse interrupt handler

os_mouse_handler:
	pusha

	call gui_mouse_get_byte

	cmp bl, 1
	je near .waskeyboard

	mov [mouse_status], al

	call gui_mouse_get_byte
	mov [x_moved], al

	call gui_mouse_get_byte
	mov [y_moved], al

	mov byte [x_moved_n], 0

	mov al, [mouse_status]
	test al, 10h			; X sign bit set?
	jz .xispos
	mov byte [x_moved_n], 1

.xispos:
	mov byte [y_moved_n], 0
	mov al, [mouse_status]
	test al, 20h			; Y sign bit set?
	jz .yispos
	mov byte [y_moved_n], 1

.yispos:
	mov al, [x_moved_n]
	or al, al
	jnz .xisneg

	xor bx, bx
	mov word ax, [mouse_x]
	mov byte bl, [x_moved]
	add ax, bx
	cmp ax, 632			; Don't update past screen edge
	jge .biggerx

	mov word [mouse_x], ax
	jmp .whateverx

.biggerx:
	mov word [mouse_x], 632
	jmp .whateverx

.xisneg:
	xor ax, ax
	xor bx, bx
	mov al, [x_moved]
	mov bl, al
	dec bl
	mov al, 255
	sub al, bl
	mov [x_moved], al

	xor bx, bx
	mov word ax, [mouse_x]
	mov bl, [x_moved]
	sub ax, bx
	cmp ax, 0
	jle .smallerx
	mov word [mouse_x], ax
	jmp .whateverx

.smallerx:
	mov word [mouse_x], 0

.whateverx:
	mov al, [y_moved_n]
	or al, al
	jnz .yisneg

	xor bx, bx
	mov ax, [mouse_y]
	mov bl, [y_moved]
	sub ax, bx
	cmp ax, 0
	jle .smallery
	mov [mouse_y], ax
	jmp .whatevery

.smallery:
	mov word [mouse_y], 0
	jmp .whatevery

.yisneg:
	mov al, [y_moved]
	mov bl, al
	dec bl
	mov al, 255
	sub al, bl
	mov [y_moved], al

	xor bx, bx
	mov ax, [mouse_y]
	mov bl, [y_moved]
	add ax, bx
	cmp ax, 466
	jge .biggery
	mov [mouse_y], ax
	jmp .whatevery

.biggery:
	mov word [mouse_y], 466

.whatevery:
	call gui_draw_mousecursor

	mov ax, [mouse_x]
	mov bx, [mouse_y]
	mov [old_mouse_x], ax
	mov [old_mouse_y], bx

.waskeyboard:
	mov al, 20h			; Tell PIC we're done
	out 0A0h, al
	out 20h, al

	popa
	iret


	mouse_x 	dw 0		; Current mouse position
	mouse_y 	dw 0
	old_mouse_x 	dw 0		; Previous position
	old_mouse_y 	dw 0

	mouse_status 	db 0		; Status (eg buttons pressed)

	x_moved		db 0		; How much mouse moved by
	y_moved		db 0
	x_moved_n	db 0		; Sign bit of move data
	y_moved_n	db 0


; =================================================================
; SYSTEM CALL SECTION -- Accessible to user programs


        %INCLUDE "syscalls.asm"


; =================================================================
; COMMAND LINE INTERFACE


	%INCLUDE "os_cli.asm"


; =================================================================
; DOS COMPATIBILITY INTERRUPT HANDLERS


	%INCLUDE "os_dos.asm"


; =================================================================
; FONT AND GRAPHICS FOR GUI


	%INCLUDE "term14g.asm"
	%INCLUDE "graphics.asm"


; =================================================================
; END OF KERNEL

	times 57344-($-$$)	db 0		; Pad up to 56K

os_buffer:
	times 8192		db 0		; Last 8K is generic buffer


; =================================================================


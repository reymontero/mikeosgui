; -----------------------------------------------------------------
; Hardware list -- demo app to show hardware info from BIOS
; -----------------------------------------------------------------


	BITS 16
	%INCLUDE "../mikedev.inc"

	ORG 100h


list_hardware:
	call os_clear_screen

	mov ax, hwlist_title_msg	; Set up screen
	mov bx, hwlist_footer_msg
	mov cx, RED_ON_LIGHT_GREEN
	call os_draw_background

	call os_print_newline


	int 11h			; Get hardware info word into AX

	bt ax, 2		; Bit 2 = do we have a mouse?
	jc .mouse_ok

	mov si, no_mouse_msg
	call os_print_string
	jmp .gameport

.mouse_ok:
	mov si, mouse_ok_msg
	call os_print_string


.gameport:
	bt ax,12		; Bit 12 = do we have a gamepad?
	jc .gameport_ok

	mov si, no_gameport_msg
	call os_print_string
	jmp .math

.gameport_ok:
	mov si, gameport_ok_msg
	call os_print_string


.math:
	bt ax, 1		; Bit 2 = do we have a math co-processor?
	jc .math_ok

	mov si, no_math_msg
	call os_print_string
	call os_wait_for_key

	jmp os_main

.math_ok:
	mov si, math_ok_msg
	call os_print_string
	call os_wait_for_key

	call os_clear_screen

	ret			; Back to OS


	hwlist_title_msg	db 'MikeOS hardware detection tool', 0
	hwlist_footer_msg	db 'Press any key to exit', 0

	no_mouse_msg	db 'No mouse present', 13, 10, 0
	mouse_ok_msg	db 'Mouse detected', 13, 10, 0

	no_gameport_msg	db 'No game port present', 13, 10, 0
	gameport_ok_msg	db 'Game port detected', 13, 10, 0

	no_math_msg	db 'No math co-processor', 13, 10, 0
	math_ok_msg	db 'Math co-processor OK', 13, 10, 0


; -----------------------------------------------------------------


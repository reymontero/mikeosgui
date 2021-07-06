; -----------------------------------------------------------------
; Hello World for MikeOS
; -----------------------------------------------------------------


	BITS 16
	%INCLUDE "../mikedev.inc"

	ORG 100h


start:
	mov si, message
	call os_print_string

	call os_wait_for_key

	ret


	message	db 'Hello, world! Press a key to exit...', 13, 10, 0


; -----------------------------------------------------------------


; -----------------------------------------------------------------
; Graphics demo -- bounce colour-cycling pixel around the screen
; -----------------------------------------------------------------


	BITS 16
	%INCLUDE "../mikedev.inc"

	ORG 100h


graphics_demo:
	mov ax, 13h		; Set VGA mode
	int 10h

	mov word [xadder], 1	; Added to X and Y
	mov word [yadder], 1

        mov cx, 0		; X position
        mov dx, 0		; Y position
        mov al, 0		; Colour


.restart:
        mov ah, 0Ch		; Plot pixel
        int 10h

	add cx, [xadder]	; Change position
	add dx, [yadder]

	cmp cx, 318		; X = far right?
	jne .noxrev
	mov word [xadder], -1	; If so, start adding -1 to X

.noxrev:
	cmp dx, 198		; Y = bottom?
	jne .noyrev
	mov word [yadder], -1	; If so, start adding -1 to X

.noyrev:
	cmp cx, 0
	jne .noxfwd
	mov word [xadder], 1

.noxfwd:
	cmp dx, 0
	jne .noyfwd
	mov word [yadder], 1

.noyfwd:
	inc al
	cmp al, 255		; Up to colour 255?
	je .reset_colour

	mov bx, ax		; Store, as we're already using it!
	call os_check_for_key
	cmp al, 'q'		; Q key pressed?
	je .end			; If so, quit demo
	cmp al, 'Q'
	je .end
	mov ax, bx

	jmp .restart

.reset_colour:			; If so, reset to 12 (looks funky!)
	mov al, 12
	jmp .restart


.end:

	mov ax, 3		; Normal video mode
	int 10h

	ret			; Back to OS


	xadder 	dw 1		; X and Y update variables
	yadder	dw 1


; -----------------------------------------------------------------


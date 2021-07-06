; Very simple DOS program -- works under DOS/Windows and MikeOS

	ORG 100h

start:
	xor ax, ax

	mov dx, message
	mov ah, 9		; Print text
	int 21h			; Call DOS
        xor ax,ax
        xor dx,dx
        div dx
        mov ax,4C01h
        int 21h                 ; Exit app

        message db 'Hello from DOS. I divide by zero :)$'


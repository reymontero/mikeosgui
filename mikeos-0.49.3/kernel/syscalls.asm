; =================================================================
; MikeOS -- The Mike Operating System kernel
; Copyright (C) 2006, 2007 MikeOS Developers -- see LICENSE.TXT
;
; SYSTEM CALL SECTION -- Accessible to user programs
; =================================================================


; -----------------------------------------------------------------
; gui_init -- Starts the GUI and clears the screen
; IN/OUT: Nothing (registers preserved)

gui_init:
	pusha

	xor ax, ax			; Set VGA (640x480x2) video mode
	mov al, 11h
	int 10h

	call gui_clear_screen

	popa
	ret


; -----------------------------------------------------------------
; gui_draw_mousecursor -- Render mouse pointer, and buffer pixels beneath
; IN/OUT: Nothing (registers preserved)

gui_draw_mousecursor:
	pusha

	cmp byte [.firstrun], 0		; Don't overwrite if first mouse call
	je .storenew

	mov ax, [old_mouse_y]		; First, restore old screen data
	mov bx, 80
	mul bx

	mov di, ax

	mov ax, [old_mouse_x]
	mov bx, 8
	div bx

	add di, ax			; DI = start block of data to write

	mov ax, 0A000h
	mov es, ax			; ES = video memory

	mov si, .screen_buffer
	xor bx, bx			; Counter


.moreredraw:				; Place data into video RAM
	mov byte al, [si]
	mov byte [es:di], al
	inc si
	inc di
	mov byte al, [si]		; Two bytes...
	mov byte [es:di], al
	inc si
	inc bl
	dec di
	add di, 80			; ...and then next row
	cmp bl, 16
	jl .moreredraw


.storenew:
	mov byte [.firstrun], 1

	mov dx, 0

	mov ax, [mouse_y]		; Next, store new screen data
	mov bx, 80
	mul bx

	mov di, ax

	mov ax, [mouse_x]
	mov bx, 8
	div bx

	add di, ax			; DI = start block of data to store

	mov si, .screen_buffer
	xor bx, bx			; Counter


.morestore:				; Place data into screen buffer
	mov byte al, [es:di]
	mov byte [si], al
	inc si
	inc di
	mov byte al, [es:di]
	mov byte [si], al		; Two bytes...
	inc si
	inc bl
	dec di
	add di, 80			; ...and then next row
	cmp bl, 16
	jl .morestore

	mov cx, [mouse_x]		; Finally, draw our mouse cursor
	mov dx, [mouse_y]
	mov bx, mouse_cursor
	call gui_print_graphic

	popa
	ret


	.screen_buffer	times 32 db 0
	.firstrun db 0


; -----------------------------------------------------------------
; gui_plot_pixel
; IN: AL = colour (1 = black, 0 = white), CX/DX = X/Y position
;
;  38,400 8-dot 'blocks' on the screen
;  80 columns of those 8-dot blocks
;
;  So, mul Y by 80 to get row
;  Divide X by 8 to get block, and remainder to set pixel

gui_plot_pixel:
	pusha

	xor ah, ah
	mov si, ax			; Store colour

	mov ax, dx			; Get row
	mov bx, 80
	mul bx

	mov di, ax

	mov ax, cx			; Get block
	mov bx, 8
	div bx

	add di, ax

	mov ax, 0A000h
	mov es, ax			; ES = video memory

	xor ax, ax
	mov byte al, [es:di]		; Get black dot data at that area


	cmp si, 0			; Draw in black or white
	je .white


	cmp dx, 0
	jne .1
	btr ax, 7
	jmp .done
.1:
	cmp dx, 1
	jne .2
	btr ax, 6
	jmp .done
.2:
	cmp dx, 2
	jne .3
	btr ax, 5
	jmp .done
.3:
	cmp dx, 3
	jne .4
	btr ax, 4
	jmp .done
.4:
	cmp dx, 4
	jne .5
	btr ax, 3
	jmp .done
.5:
	cmp dx, 5
	jne .6
	btr ax, 2
	jmp .done
.6:
	cmp dx, 6
	jne .7
	btr ax, 1
	jmp .done
.7:
	btr ax, 0
	jmp .done



.white:
	cmp dx, 0
	jne .w1
	bts ax, 7
	jmp .done
.w1:
	cmp dx, 1
	jne .w2
	bts ax, 6
	jmp .done
.w2:
	cmp dx, 2
	jne .w3
	bts ax, 5
	jmp .done
.w3:
	cmp dx, 3
	jne .w4
	bts ax, 4
	jmp .done
.w4:
	cmp dx, 4
	jne .w5
	bts ax, 3
	jmp .done
.w5:
	cmp dx, 5
	jne .w6
	bts ax, 2
	jmp .done
.w6:
	cmp dx, 6
	jne .w7
	bts ax, 1
	jmp .done
.w7:
	bts ax, 0
	jmp .done



.done:
	mov byte [es:di], al

	popa
	ret


; -----------------------------------------------------------------
; gui_display_menubar -- Show menu bar at top of screen
; IN: SI = location of string to display

gui_display_menubar:
	pusha

	push si

	mov cx, 0
	mov dx, 0
	mov si, 639
	mov di, 20
	mov al, 0
	call gui_draw_block

	mov cx, 0
	mov dx, 20
	mov si, 639
	mov di, 21
	mov al, 1
	call gui_draw_block

	mov ax, 0
	mov cx, 5
	mov dx, 3

	pop si

	call gui_print_string

	popa
	ret


; -----------------------------------------------------------------
; gui_clear_screen -- Clear the screen with a pattern
; IN/OUT: Nothing (registers preserved)

gui_clear_screen:
	pusha

	mov ax, 0A000h
	mov es, ax			; ES = video memory

	mov cx, 0			; Column counter
	mov bl, 10101010b		; Pattern to draw
	mov dx, 0			; Line counter
	mov di, 0			; Video RAM position

.loop:
	mov [es:di], bl			; Store pattern in video RAM
	inc cx				; Move on to next column
	inc di
	cmp cx, 80			; At last column?
	je .doneline
	jmp .loop			; Otherwise keep going

.doneline:
	mov cx, 0			; Reset to first column
	not bl				; Invert our pattern
	inc dx				; Keep counting lines...
	cmp dx, 480
	je .finished
	jmp .loop

.finished:
	popa
	ret


; -----------------------------------------------------------------
; gui_draw_block -- Draw solid block of specified colour
; IN: AL = colour, CX/DX = start X/Y, SI/DI = end X/Y position
; OUT: Nothing (registers preserved)

gui_draw_block:
	pusha

	mov bx, cx		; Store X position of box start

	mov ah, 0Ch		; Draw pixel BIOS code

.loop:
	call gui_plot_pixel

	cmp cx, si		; Drawn to far right?
	jne .more
	mov cx, bx		; If so, restore X position of box start
	dec cx
	inc dx

.more:
	cmp dx, di
	je .finished
	inc cx
	jmp .loop

.finished:
	popa
	ret


; -----------------------------------------------------------------
; gui_draw_clock -- Render time string in menu bar (top-right)
; IN/OUT: Nothing

gui_draw_clock:
	pusha

	mov ax, 0
	mov cx, 576
	mov dx, 3
	mov si, 639
	mov di, 20
	call gui_draw_block

	mov bx, timestring
	call os_get_time_string

	mov cx, 576
	mov dx, 3
	mov si, timestring
	call gui_print_string

	popa
	ret


; -----------------------------------------------------------------
; gui_draw_helpbox -- Render help text bar along bottom of screen
; IN: AX = help string location

gui_draw_helpbox:
	pusha

	push ax

	mov al, 1
	mov cx, 9
	mov dx, 450
	mov si, 631
	mov di, 473
	call gui_draw_block

	mov al, 0
	mov cx, 10
	mov dx, 451
	mov si, 630
	mov di, 472
	call gui_draw_block

	mov al, 1
	mov cx, 11
	mov dx, 452
	mov si, 629
	mov di, 471
	call gui_draw_block

	mov al, 0
	mov cx, 12
	mov dx, 453
	mov si, 628
	mov di, 470
	call gui_draw_block

	pop ax

	mov si, ax
	mov cx, 20
	mov dx, 454

	mov al, 00000000b

	call gui_print_string

	popa
	ret


; -----------------------------------------------------------------
; gui_draw_button_box -- Draw box with bevel
; IN: CX/DX = start X/Y, SI/DI = end X/Y

gui_draw_button_box:
	pusha

	mov bx, cx			; Store start position

	mov al, 1
	call gui_draw_block

	add cx, 4
	add dx, 4
	sub si, 4
	sub di, 4
	mov al, 0
	call gui_draw_block

	sub cx, 3
	sub dx, 3
	add si, 4
	add di, 2

.more1:
	cmp cx, si
	je .done1
	mov al, 0
	call gui_plot_pixel

	inc cx
	cmp cx, si
	je .done1

	mov al, 1
	call gui_plot_pixel
	inc cx
	jmp .more1


.done1:
	mov cx, bx
	add cx, 1
	inc dx


.more2:
	cmp cx, si
	je .done2
	mov al, 1
	call gui_plot_pixel

	inc cx
	cmp cx, si
	je .done2

	mov al, 0
	call gui_plot_pixel
	inc cx
	jmp .more2


.done2:
	inc dx
	mov cx, bx
	inc cx


.leftside:
	mov al, 0
	call gui_plot_pixel

	inc dx
	cmp dx, di
	je .finished
	inc cx
	call gui_plot_pixel
	dec cx
	inc dx
	cmp dx, di
	je .finished
	jmp .leftside


.finished:
	popa
	ret


; -----------------------------------------------------------------
; gui_draw_button
; IN: AX = string location, CX/DX = X/Y position

gui_draw_button:
	pusha

	mov [.tmp], ax		; String

	push dx
	call os_string_length
	mov bx, 12
	mul bx			; AX now has width of box
	pop dx

	push cx
	add cx, ax
	mov si, cx
	add si, 18		; Right-hand edge of button box
	pop cx

	mov ax, dx
	add ax, 20
	mov di, ax
	add di, 7
	call gui_draw_button_box

	mov ax, [.tmp]
	mov si, ax
	add dx, 5
	add cx, 9
	call gui_print_string

	popa
	ret


	.tmp	dw	0


; -----------------------------------------------------------------
; gui_draw_box -- Draw outline box (black) at specified position
; IN: CX/DX = start X/Y, SI/DI = end X/Y position

gui_draw_box:
	pusha

	mov bx, cx
	mov [.tmp], cx

	mov al, 1		; Colour

.moretopline:
	cmp cx, si
	je .finishtopline
	call gui_plot_pixel
	inc cx
	jmp .moretopline

.finishtopline:
	mov cx, bx

	mov bx, dx

	mov dx, di


.morebottomline:
	cmp cx, si
	je .finishbottomline
	call gui_plot_pixel
	inc cx
	jmp .morebottomline

.finishbottomline:
	mov dx, bx

	mov cx, [.tmp]


.moreleftline:
	cmp dx, di
	jg .finishleftline
	call gui_plot_pixel
	inc dx
	jmp .moreleftline
.finishleftline:


	mov cx, si
	mov dx, bx

.morerightline:
	cmp dx, di
	jg .finishrightline
	call gui_plot_pixel
	inc dx
	jmp .morerightline
.finishrightline:

	popa
	ret


	.tmp	dw 0


; -----------------------------------------------------------------
; gui_print_string -- Output string at specified position
; IN: AX = 1 for bold, SI = string location, CX/DX = X/Y position

gui_print_string:
	pusha

	xor bx, bx

.more:
	cmp byte [si], 0	; If char is null, end of string
	je .finish
	cmp cx, 628		; If we're at right-edge of screen, don't print
	jge .finish

	mov bl, [si]		; Otherwise print it
	call gui_print_char

	cmp ax, 1		; Printing in bold?
	je .drawbold

	inc si			; Move on in string
	add cx, 12		; And move right on screen
	jmp .more

.drawbold:
	add cx, 1
	call gui_print_char	; Print char again, 1 pixel to the right

	inc si			; Move on in string
	add cx, 11		; And move right on screen
	jmp .more


.finish:
	popa
	ret


; -----------------------------------------------------------------
; gui_print_char -- Output character at specified position
; IN: BL = ASCII character, CX/DX = X/Y position
; OUT: Nothing (registers preserved)

gui_print_char:
	pusha

	sub bl, 32		; Change ASCII code to fit our charset

	push dx			; Affected by next offset calculation

	push ax			; Get offset of char in font table
	mov ax, 30		; 30 bytes per char
	mul bx
	mov bx, ax
	mov ax, ascii_font	; Add multiplication to start of font table
	add ax, bx
	mov bx, ax		; And store in BX
	pop ax

	pop dx


	mov byte [.counter], 0	; Row counter
	mov [.rowleft], cx	; Left-hand position of row

	xor ax, ax
	mov ah, 0Ch		; BIOS routine: draw pixel

	mov si, bx		; Store first row in SI


.nextrow:
	mov bh, [si]		; Get contents of row into BX
	inc si
	mov bl, [si]

	mov di, 0		; DI = bit counter
.more:
	push bx			; Store BX before AND
	and bx, 2048		; Is highest bit set?
	jz .nopixel
	int 10h			; If so, draw pixel
.nopixel:
	pop bx			; Get BX back to before AND
	shl bx, 1		; Move all bits left
	inc cx
	inc di
	cmp di, 12		; Do this for 12 bits
	je .finishrow
	jmp .more
.finishrow:
	mov cx, [.rowleft]	; When row is done, move left...
	mov di, 0
	inc dx			; ...and down, to display next row
	inc si			; Get position of next row

	inc byte [.counter]	; Done the 15 rows?
	cmp byte [.counter], 15
	je .finishchar

	jmp .nextrow		; If not, move on to the next one

.finishchar:
	popa
	ret


	.rowleft	dw 0
	.counter	db 0


; -----------------------------------------------------------------
; gui_print_graphic -- Display icon at specified position
; IN: BX = graphic location, CX/DX = X/Y position
; OUT: Nothing (registers preserved)

gui_print_graphic:
	pusha

	mov [.rowleft], cx	; Left-hand position of row
	add cx, 16
	mov [.rowright], cx
	sub cx, 16

	mov si, bx		; Store first row in SI
	mov di, 0


.more:
	mov bh, [si]
	cmp bh, 1
	je .black
	cmp bh, 2
	je .doneplot
	jmp .white

.black:
	mov al, 1
	call gui_plot_pixel
	jmp .doneplot

.white:
	mov al, 0
	call gui_plot_pixel

.doneplot:
	inc si
	inc cx
	cmp cx, [.rowright]
	je .doneline
	jmp .more

.doneline:
	inc dx
	mov cx, [.rowleft]
	inc di
	cmp di, 16
	je .finished
	jmp .more


.finished:
	popa
	ret


	.rowleft	dw 0
	.rowright	dw 0


; -----------------------------------------------------------------
; gui_file_selector

; IN: AL = colour, CX/DX = start X/Y, SI/DI = end X/Y position

gui_file_selector:
	pusha

	mov ax, .title_string		; Draw window
	mov cx, 140
	mov dx, 50
	mov si, 500
	mov di, 430
	call gui_draw_window

	mov cx, 154			; Draw box to contain file list
	mov dx, 84
	mov si, 486
	mov di, 370
	call gui_draw_box

	mov ax, .file_list		; Get list of files on disk
	call os_get_file_list

	mov si, ax			; File list now pointed to by SI

	mov cx, 160			; Initial location of file list
	mov dx, 88

	mov bx, 0
	mov di, 0			; Counter for filename dots

.files_more:
	mov byte bl, [si]		; Display files on disk
	cmp bl, ','
	je .files_newline
	cmp bl, 0
	je .files_done
	cmp bl, ' '
	je .files_noprint
	call gui_print_char
	add cx, 12			; Move right after every char printed
.files_noprint:
	inc si
	inc di
	cmp di, 8
	je .files_printdot
	jmp .files_more

.files_newline:
	inc si
	mov cx, 160
	add dx, 16			; Jump down a line
	mov di, 0			; Reset filename dot counter
	jmp .files_more

.files_printdot:			; Show dot in filename
	mov bl, '.'
	call gui_print_char
	add cx, 12
	mov di, 0
	jmp .files_more


.files_done:
	mov ax, .open_button_text	; Open button
	mov cx, 200
	mov dx, 386
	call gui_draw_button

	mov ax, .cancel_button_text	; Cancel button
	mov cx, 350
	mov dx, 386
	call gui_draw_button

	popa
	ret


	.title_string db 'Select a file...', 0
	.file_list times 255 db 0

	.open_button_text db ' Open ', 0
	.cancel_button_text db 'Cancel', 0


; -----------------------------------------------------------------
; gui_draw_window -- Draw window with shadow
; IN: AX = title string location, CX/DX = start X/Y, SI/DI = end X/Y position
; OUT: Nothing (registers preserved)

gui_draw_window:
	pusha

	mov al, 1			; Initial window area
	call gui_draw_block

	add cx, 4			; Shadow
	add dx, 4
	add si, 4
	add di, 4
	call gui_draw_block

	mov al, 0
	sub cx, 3			; White inside of window
	sub dx, 3
	sub si, 5
	sub di, 5
	call gui_draw_block

	popa				; Get original values back
	pusha				; Store again for title string

	mov di, dx
	add dx, 20
	call gui_draw_box

	popa				; Get original values back
	pusha				; Store again for routine exit

	mov si, ax
	mov ax, 1			; Bold!
	add cx, 5			; String a bit further right
	add dx, 3
	call gui_print_string

	popa
	ret


; -----------------------------------------------------------------
; os_print_string -- Displays text
; IN: SI = message location (zero-terminated string)
; OUT: Nothing (registers preserved)

os_print_string:
	pusha

	mov ah, 0Eh		; int 10h teletype function

.repeat:
	lodsb			; Get char from string
	cmp al, 0
	je .done		; If char is zero, end of string
	int 10h			; Otherwise, print it
	jmp .repeat

.done:
	popa
	ret


; -----------------------------------------------------------------
; os_move_cursor -- Moves cursor in text mode
; IN: DH, DL = row, column, OUT: Nothing (registers preserved)

os_move_cursor:
	pusha

	xor bh, bh
	mov ah, 2
	int 10h

	popa
	ret


; -----------------------------------------------------------------
; os_show_cursor -- Turns on cursor in text mode
; IN/OUT: Nothing!

os_show_cursor:
	pusha

	mov ch, 0			; Set cursor to solid block
	mov cl, 7
	mov ah, 1
	mov al, 3			; Must be video mode for buggy BIOSes!
	int 10h

	popa
	ret


; -----------------------------------------------------------------
; os_hide_cursor -- Turns off cursor in text mode
; IN/OUT: Nothing!

os_hide_cursor:
	pusha

	mov ch, 32
	mov ah, 1
	mov al, 3			; Must be video mode for buggy BIOSes!
	int 10h

	popa
	ret


; -----------------------------------------------------------------
; os_draw_background -- Clear screen with white top and bottom bars,
; containing text, and a coloured middle section.
; IN: AX + BX = top and bottom strings locations, CX = colour

os_draw_background:
	pusha

	push ax				; Store params to pop out later
	push bx
	push cx

	call os_clear_screen

	mov ah, 09h			; Draw white bar at top
	xor bh, bh
	mov cx, 80
	mov bl, 01110000b
	mov al, ' '
	int 10h

	mov dh, 1
	mov dl, 0
	call os_move_cursor

	mov ah, 09h			; Draw colour section
	xor bh, bh
	mov cx, 1840
	pop bx				; Get colour param (originally in CX)
	xor bh, bh
	mov al, ' '
	int 10h

	mov dh, 24
	mov dl, 0
	call os_move_cursor

	mov ah, 09h			; Draw white bar at bottom
	xor bh, bh
	mov cx, 80
	mov bl, 01110000b
	mov al, ' '
	int 10h

	mov dh, 24
	mov dl, 1
	call os_move_cursor
	pop bx				; Get bottom string param
	mov si, bx
	call os_print_string

	mov dh, 0
	mov dl, 1
	call os_move_cursor
	pop ax				; Get top string param
	mov si, ax
	call os_print_string

	mov dh, 1			; Ready for app text
	mov dl, 0
	call os_move_cursor

	popa
	ret


; -----------------------------------------------------------------
; os_clear_screen -- Clears the screen
; IN/OUT: Nothing (registers preserved)

os_clear_screen:
	pusha

	mov dx, 0			; Position cursor at top-left
	call os_move_cursor

	mov ah, 6			; Scroll full-screen
	mov al, 0			; Normal white on black
	mov bh, 7			; Upper-left corner of screen
	mov cx, 0			; Bottom-right
	mov dh, 24
	mov dl, 79
	int 10h

	popa
	ret


; -----------------------------------------------------------------
; os_bcd_to_int -- Converts binary coded decimal number to an integer
; IN: AL = BCD number, OUT: AX = integer value

os_bcd_to_int:
	pusha

	xor bx, bx
	mov bl, al			; Store for now

	and ax, 0xF			; Zero-out high bits
	mov cl, al			; CL = lower BCD number

	mov al, bl			; Get original number back
	shr ax, 4			; Rotate higher BCD number into lower bits
	and ax, 0xF			; Zero-out high bits

	mov dx, 10			; Multiply by 10 (as it's the higher BCD)
	mul dx

	add ax, cx			; Add it to the lower BCD
	mov [.tmp], ax

	popa
	mov ax, [.tmp]			; And return it in AX!
	ret


	.tmp	dw 0


; -----------------------------------------------------------------
; os_get_time_string -- Get current time in a string (eg '20:25')
; IN/OUT: BX = string location

os_get_time_string:
	pusha

	push bx				; Store string location for now

        mov ax,0x0200
        int 0x1A			; Get time data from BIOS in BCD format

        mov al,	ch			; Hour
	call os_bcd_to_int
        mov ch, al

        mov al, cl			; Minute
	call os_bcd_to_int
        mov cl, al

	xor ax, ax

	mov al, ch			; Convert hour to string
	mov bx, .tmp_string1
	call os_int_to_string

	mov al, cl
	mov bx, .tmp_string2		; Convert minute to string
	call os_int_to_string

	mov ax, .tmp_string2		; Just one number in minutes string?
	call os_string_length
	cmp ax, 1
	jne .twochars

	mov ax, .zero_string		; If so, add '0' char before it
	mov bx, .tmp_string2
	mov cx, .tmp_string3
	call os_string_join

	mov si, .tmp_string3		; And copy string back into old minutes string
	mov di, .tmp_string2
	call os_string_copy

.twochars:
	pop bx				; Get original string location back

	mov cx, bx			; Add hour and separator character to it
	mov ax, .tmp_string1
	mov bx, .separator
	call os_string_join

	mov ax, cx			; And add the minutes
	mov bx, .tmp_string2
	call os_string_join

	popa
	ret


	.tmp_string1 	times 3 db 0
	.tmp_string2 	times 3 db 0
	.tmp_string3	times 3 db 0
	.zero_string	db '0', 0
	.separator	db ':', 0


; -----------------------------------------------------------------
; os_print_horiz_line -- Draw a horizontal line on the screen
; IN: AX = line type (1 for double, otherwise single)
; OUT: Nothing (registers preserved)

os_print_horiz_line:
	pusha

	mov cx, ax			; Store line type param
	mov al, 196			; Default is single-line code

	cmp cx, 1			; Was double-line specified in AX?
	jne .ready
	mov al, 205			; If so, here's the code

.ready:
	mov cx, 0			; Counter
	mov ah, 0Eh			; BIOS output char routine

.restart:
	int 10h
	inc cx
	cmp cx, 80			; Drawn 80 chars yet?
	je .done
	jmp .restart

.done:
	popa
	ret


; -----------------------------------------------------------------
; os_print_newline -- Reset cursor to start of next line
; IN/OUT: Nothing (registers preserved)

os_print_newline:
	pusha

	mov ah, 0Eh			; BIOS output char code

	mov al, 13
	int 10h
	mov al, 10
	int 10h

	popa
	ret


; -----------------------------------------------------------------
; os_wait_for_key -- Waits for keypress and returns key
; IN: Nothing, OUT: AX = key pressed, other regs preserved

os_wait_for_key:
	pusha

	xor ax, ax
	mov ah, 00			; BIOS call to wait for key
	int 16h

	mov [.tmp_buf], ax		; Store resulting keypress

	popa				; But restore all other regs
	mov ax, [.tmp_buf]
	ret


	.tmp_buf	dw 0


; -----------------------------------------------------------------
; os_check_for_key -- Scans keyboard for input, but doesn't wait
; IN: Nothing, OUT: AL = 0 if no key pressed, otherwise ASCII code

os_check_for_key:
	pusha

	xor ax, ax
	mov ah, 01			; BIOS call to check for key
	int 16h

	jz .nokey			; If no key, skip to end

	xor ax, ax			; Otherwise get it from buffer
	mov ah, 00
	int 16h

	mov [.tmp_buf], al		; Store resulting keypress

	popa				; But restore all other regs
	mov al, [.tmp_buf]
	ret

.nokey:
	popa
	mov al, 0			; Zero result if no key pressed
	ret


	.tmp_buf	db 0


; -----------------------------------------------------------------
; os_int_to_string -- Convert value in AX to string
; IN: AX = integer, BX = location of string
; OUT: BX = location of converted string (other regs preserved)
;
; NOTE: Based on public domain code

os_int_to_string:
	pusha

	mov di, bx

	mov byte [.zerow], 0x00
	mov word [.varbuff], ax
	xor ax, ax
	xor cx, cx
	xor dx, dx
 	mov bx, 10000
	mov word [.deel], bx

.mainl:
	mov bx, word [.deel]
	mov ax, word [.varbuff]
	xor dx, dx
	xor cx, cx
	div bx
	mov word [.varbuff], dx

.vdisp:
	cmp ax, 0
	je .firstzero
	jmp .ydisp

.firstzero:
	cmp byte [.zerow], 0x00
	je .nodisp

.ydisp:
	add al, 48                              ; Make it numeric (0123456789)
	mov [di], al
	inc di
	mov byte [.zerow], 0x01
	jmp .yydis

.nodisp:
.yydis:
	xor dx, dx
	xor cx, cx
	xor bx, bx
	mov ax, word [.deel]
	cmp ax, 1
	je .bver
	cmp ax, 0
	je .bver
	mov bx, 10
	div bx
	mov word [.deel], ax
	jmp .mainl

.bver:
	mov byte [di], 0

	popa
	ret


	.deel		dw 0x0000
	.varbuff	dw 0x0000
	.zerow		db 0x00


; -----------------------------------------------------------------
; os_speaker_tone -- Generate PC speaker tone (call os_speaker_off after)
; IN: AX = note frequency, OUT: Nothing (registers preserved)

os_speaker_tone:
	pusha

	mov cx, ax		; Store note value for now

	mov al, 182
	out 43h, al
	mov ax, cx		; Set up frequency
	out 42h, al
	mov al, ah
	out 42h, al

	in al, 61h		; Switch PC speaker on
	or al, 03h
	out 61h, al

	popa
	ret


; -----------------------------------------------------------------
; os_speaker_off -- Turn off PC speaker
; IN/OUT: Nothing (registers preserved)

os_speaker_off:
	pusha

	in al, 61h		; Switch PC speaker off
	and al, 0FCh
	out 61h, al

	popa
	ret


; -----------------------------------------------------------------
; os_dialog_box -- Print dialog box in middle of screen, with button(s)
; IN: AX, BX, CX = string locations (set registers to 0 for no display)
; IN: DX = 0 for single 'OK' dialog, 1 for two-button 'OK' and 'Cancel'
; OUT: If two-button mode, AX = 0 for OK and 1 for cancel
; NOTE: Each string is limited to 40 characters

os_dialog_box:
	pusha

	mov [.tmp], dx

	push ax				; Store first string location...
	call os_string_length		; ...because this converts AX to a number
	cmp ax, 40			; Check to see if it's less than 30 chars
	jg .string_too_long

	mov ax, bx			; Check second string length
	call os_string_length
	cmp ax, 40
	jg .string_too_long

	mov ax, cx			; Check third string length
	call os_string_length
	cmp ax, 40
	jg .string_too_long

	pop ax				; Get first string location back
	jmp .strings_ok			; All string lengths OK, so let's move on


.string_too_long:
	pop ax				; We pushed this before
	mov ax, .err_msg_string_length
	call os_fatal_error


.strings_ok:
	call os_hide_cursor

	mov dh, 9			; First, draw red background box
	mov dl, 19

.redbox:				; Loop to draw all lines of box
	call os_move_cursor

	pusha
	mov ah, 09h
	xor bh, bh
	mov cx, 42
	mov bl, 01001111b		; White on red
	mov al, ' '
	int 10h
	popa

	inc dh
	cmp dh, 16
	je .boxdone
	jmp .redbox


.boxdone:
	cmp ax, 0			; Skip string params if zero
	je .no_first_string
	mov dl, 20
	mov dh, 10
	call os_move_cursor

	mov si, ax			; First string
	call os_print_string

.no_first_string:
	cmp bx, 0
	je .no_second_string
	mov dl, 20
	mov dh, 11
	call os_move_cursor

	mov si, bx			; Second string
	call os_print_string

.no_second_string:
	cmp cx, 0
	je .no_third_string
	mov dl, 20
	mov dh, 12
	call os_move_cursor

	mov si, cx			; Third string
	call os_print_string

.no_third_string:
	mov dx, [.tmp]
	cmp dx, 0
	je .one_button
	cmp dx, 1
	je .two_button


.one_button:
	mov dl, 35			; OK button, centered at bottom of box
	mov dh, 14
	call os_move_cursor
	mov si, .ok_button_string
	call os_print_string

	jmp .one_button_wait


.two_button:
	mov dl, 27			; OK button
	mov dh, 14
	call os_move_cursor
	mov si, .ok_button_string
	call os_print_string

	mov dl, 42			; Cancel button
	mov dh, 14
	call os_move_cursor
	mov si, .cancel_button_noselect
	call os_print_string

	mov cx, 0			; Default button = 0
	jmp .two_button_wait



.one_button_wait:
	call os_wait_for_key
	cmp al, 13			; Wait for enter key (13) to be pressed
	jne .one_button_wait

	call os_show_cursor

	popa
	ret


.two_button_wait:
	call os_wait_for_key

	cmp ah, 75			; Left cursor key pressed?
	jne .noleft

	mov dl, 27			; If so, change printed buttons
	mov dh, 14
	call os_move_cursor
	mov si, .ok_button_string
	call os_print_string

	mov dl, 42			; Cancel button
	mov dh, 14
	call os_move_cursor
	mov si, .cancel_button_noselect
	call os_print_string

	mov cx, 0			; And update result we'll return
	jmp .two_button_wait


.noleft:
	cmp ah, 77			; Right cursor key pressed?
	jne .noright

	mov dl, 27			; If so, change printed buttons
	mov dh, 14
	call os_move_cursor
	mov si, .ok_button_noselect
	call os_print_string

	mov dl, 42			; Cancel button
	mov dh, 14
	call os_move_cursor
	mov si, .cancel_button_string
	call os_print_string

	mov cx, 1			; And update result we'll return
	jmp .two_button_wait


.noright:
	cmp al, 13			; Wait for enter key (13) to be pressed
	jne .two_button_wait

	call os_show_cursor

	mov [.tmp], cx			; Keep result after restoring all regs
	popa
	mov ax, [.tmp]

	ret


	.err_msg_string_length	db 'os_dialog_box: Supplied string too long', 0
	.ok_button_string	db '[= OK =]', 0
	.cancel_button_string	db '[= Cancel =]', 0
	.ok_button_noselect	db '   OK   ', 0
	.cancel_button_noselect	db '   Cancel   ', 0

	.tmp dw 0


; -----------------------------------------------------------------
; os_input_string -- Take string from keyboard entry
; IN/OUT: AX = location of string, other regs preserved

os_input_string:
	pusha

	mov bx, ax			; Store location into BX

	mov ax, 0x2000			; Segment
	mov ds, ax
	mov es, ax

	mov di, bx			; DI is where we'll store input
	mov cx, 0			; Counter for chars entered

	mov ax, 0                       ; First, clear string to 0s

.loop_blank:
	stosb

	cmp byte [di], 0		; Reached zero (end of line) in string?
	je .blank_done

	jmp .loop_blank

.blank_done:
	mov di, bx
	mov cx, 0


.more:					; Now onto string getting
	call os_wait_for_key

	cmp al, 13			; If Enter key pressed, finish
	je .done

	cmp al, 8			; Backspace pressed?
	je .backspace			; If not, skip following checks

	cmp al, 32			; In ASCII range (32 - 126)?
	jl .more

	cmp al, 126
	jg .more

	jmp .nobackspace


.backspace:
	cmp cx, 0			; Backspaced at start of line?
	je .more

	pusha
	mov ah, 0Eh			; If not, write space and move cursor back
	mov al, 8
	int 10h				; Backspace twice, to clear space
	mov al, 32
	int 10h
	mov al, 8
	int 10h
	popa

	mov byte [di], 0		; Zero out what may have been entered here

	dec cx				; Step back in counter
	dec di

	jmp .more


.nobackspace:
	pusha
	mov ah, 0Eh			; Output entered char
	int 10h
	popa

	inc cx
	cmp cx, 250			; Make sure we don't exhaust buffer
	je near .done

	stosb				; Store

	jmp near .more


.done:
	popa
	ret


; -----------------------------------------------------------------
; os_string_length -- Return length of a string
; IN: AX = string location, OUT AX = length (other regs preserved)

os_string_length:
	pusha

	mov bx, ax		; Location of string now in BX
	mov cx, 0

.more:
	cmp byte [bx], 0	; Zero (end of string) yet?
	je .done
	inc bx			; If not, keep adding
	inc cx
	jmp .more


.done:
	mov word [.tmp_counter], cx
	popa
	mov ax, [.tmp_counter]
	ret


	.tmp_counter	dw 0


; -----------------------------------------------------------------
; os_string_uppercase -- Convert zero-terminated string to uppercase
; IN/OUT: AX = string location

os_string_uppercase:
	pusha

.more:
	cmp byte [si], 0		; Zero-termination of string?
	je .done			; If so, quit

	cmp byte [si], 97		; In the uppercase A to Z range?
	jl .noatoz
	cmp byte [si], 122
	jg .noatoz

	sub byte [si], 20h		; If so, convert input char to lowercase

	inc si
	jmp .more

.noatoz:
	inc si
	jmp .more

.done:
	popa
	ret


; -----------------------------------------------------------------
; os_string_lowercase -- Convert zero-terminated string to lowercase
; IN/OUT: AX = string location

os_string_lowercase:
	pusha

.more:
	cmp byte [si], 0		; Zero-termination of string?
	je .done			; If so, quit

	cmp byte [si], 65		; In the lowercase A to Z range?
	jl .noatoz
	cmp byte [si], 90
	jg .noatoz

	add byte [si], 20h		; If so, convert input char to uppercase

	inc si
	jmp .more

.noatoz:
	inc si
	jmp .more

.done:
	popa
	ret


; -----------------------------------------------------------------
; os_string_copy -- Copy one string into another
; IN/OUT: SI = source, DI = destination

os_string_copy:
	pusha

.more:
	cmp byte [si], 0	; If source string is empty, quit out
	je .done
	mov al, [si]		; Transfer contents
	mov [di], al
	inc si
	inc di
	jmp .more

.done:
	mov byte [di], 0	; Write terminating zero

	popa
	ret


; -----------------------------------------------------------------
; os_string_truncate -- Chop string down to specified number of characters
; IN: SI = string location, AX = number of characters
; OUT: SI = string location

os_string_truncate:
	pusha

	add si, ax
	mov byte [si], 0

	popa
	ret


; -----------------------------------------------------------------
; os_string_join -- Join two strings into a third string
; IN/OUT: AX = string one, BX = string two, CX = destination string

os_string_join:
	pusha

	mov si, ax		; Put first string into CX
	mov di, cx
	call os_string_copy

	call os_string_length	; Get length of first string

	add cx, ax		; Position at end of first string

	mov si, bx		; Add second string onto it
	mov di, cx
	call os_string_copy

	popa
	ret


; -----------------------------------------------------------------
; os_string_chomp -- Strip leading and trailing spaces from a string
; IN: AX = string location

os_string_chomp:
	pusha

	push ax				; Store string location

	mov di, ax			; Put location into DI
	xor bx, bx

.keepcounting:				; Get number of leading spaces into BX
	cmp byte [di], ' '
	jne .counted
	inc bx
	inc di
	jmp .keepcounting

.counted:
	pop ax				; Get string location back
	push ax

	mov di, ax			; DI = original string start

	mov si, ax
	add si, bx			; SI = first non-space char in string

.keep_copying:
	mov ax, [si]			; Copy SI into DI (original string start)
	mov [di], ax
	cmp ax, 0
	je .finished_copy
	inc si
	inc di
	jmp .keep_copying

.finished_copy:
	pop ax
	mov si, ax

	call os_string_length

	add si, ax			; Move to end of string

.more:
	dec si
	cmp byte [si], ' '
	jne .done
	mov byte [si], 0
	jmp .more

.done:
	popa
	ret


; -----------------------------------------------------------------
; os_string_strip -- Removes specified character from a string
; IN: SI = string location, AX = character to remove

os_string_strip:
	pusha

	mov dx, si			; Store string location for later

	mov di, os_buffer

.more:
	mov bx, [si]

	cmp bx, 0
	je .done

	inc si
	cmp bl, al
	je .more

	mov [di], bl
	inc di
	jmp .more

.done:
	mov [di], bl

	mov si, os_buffer
	mov di, dx
	call os_string_copy

	popa
	ret


; -----------------------------------------------------------------
; os_string_compare -- See if two strings match
; IN: SI = string one, DI = string two; OUT: carry set if same

os_string_compare:
	pusha

.more:
	mov ax, [si]			; Store string contents
	mov bx, [di]

	cmp byte [si], 0		; End of first string?
	je .terminated

	cmp ax, bx
	jne .not_same

	inc si
	inc di
	jmp .more


.not_same:
	popa
	clc
	ret


.terminated:
	cmp byte [di], 0		; End of second string?
	jne .not_same

	popa
	stc
	ret


; -----------------------------------------------------------------
; os_pause -- Delay execution for specified microseconds
; IN: CX:DX = number of microseconds to wait

os_pause:
	pusha

	mov ah, 86h
	int 15h

	popa
	ret


; -----------------------------------------------------------------
; os_modify_int_handler -- Change location of interrupt handler
; IN: CX = int number, SI = handler location

os_modify_int_handler:
	pusha

	mov dx, es                      ; Store original ES

	xor ax, ax                      ; Clear AX for new ES value
	mov es, ax

	mov al, cl                      ; Move supplied int into AL

	mov bl, 4h                      ; Multiply by four to get position
	mul bl                          ; (Interrupt table = 4 byte sections)
	mov bx, ax

	mov [es:bx], si                 ; First store offset
	add bx, 2

	mov ax, 0x2000                  ; Then segment of our handler
	mov [es:bx], ax

	mov es, dx                      ; Finally, restore data segment

	popa
	ret


; -----------------------------------------------------------------
; os_fatal_error -- Display error message, take keypress, and restart OS
; IN: AX = error message string location

os_fatal_error:
	mov bx, ax			; Store string location for now

	mov dh, 0
	mov dl, 0
	call os_move_cursor

	pusha
	mov ah, 09h			; Draw red bar at top
	xor bh, bh
	mov cx, 240
	mov bl, 01001111b
	mov al, ' '
	int 10h
	popa

	mov dh, 0
	mov dl, 0
	call os_move_cursor

	mov si, .msg_inform		; Inform of fatal error
	call os_print_string

	mov si, bx			; Program-supplied error message
	call os_print_string

	mov si, .msg_newline
	call os_print_string

	mov si, .msg_prompt		; Restart prompt
	call os_print_string

	xor ax, ax
	mov ah, 00			; BIOS call to wait for key
	int 16h

	jmp os_int_reboot


	.msg_inform		db '>>> FATAL OPERATING SYSTEM ERROR', 13, 10, 0
	.msg_newline		db 13, 10, 0
	.msg_prompt		db 'Press a key to restart MikeOS...', 0


; -----------------------------------------------------------------
; os_get_file_list -- Generate comma-separated string of files on floppy
; IN/OUT: AX = location of string to store filenames

os_get_file_list:
	pusha

	mov word [.file_list_tmp], ax	; Store string location

	xor eax, eax			; Needed for some older BIOSes

	call os_int_reset_floppy
	jnc .floppy_ok			; Did the floppy reset OK?

	mov ax, .err_msg_floppy_reset	; If not, bail out
	jmp os_fatal_error


.floppy_ok:				; Ready to read first block of data
	mov ax, 19			; Root dir starts at logical sector 19
	call os_int_l2hts

	lea si, [os_buffer]		; ES:BX should point to our buffer
	mov bx, ds
	mov es, bx
	mov bx, si

	mov ah, 0x02			; Params for int 13h: read floppy sectors
	mov al, 14			; And read 14 of them

	clc				; Prepare to enter loop
	pusha


.read_first_sector:
	popa

	pusha
	int 13h				; Read sectors
	call os_int_reset_floppy	; Check we've read them OK
	jc .read_first_sector		; If not, just keep trying
	popa

	xor ax, ax
	mov cx, 0
	mov bx, os_buffer+64		; Start of filenames
	mov di, os_buffer+64		; Data reader from start of filenames

	mov word dx, [.file_list_tmp]


.showdir:
	mov ax, [di]
	cmp al, 229			; If we read 229 = deleted filename
	je .skip
	cmp al, 0
	je .done

	inc di

	push di
	mov di, dx			; DX = where we're storing string
	stosb
	inc dx
	pop di

	inc cx
	cmp cx, 11			; Done 11 char filename?
	je .gotfilename
	jmp .showdir


.gotfilename:				; Got a filename
	push di
	mov di, dx			; DX = where we're storing string
	mov ax, ','			; Use comma to separate for next file
	stosb
	inc dx
	pop di


.skip:
	mov cx, 0			; Reset char counter

	add bx, 64			; Shift to next 64 bytes (next filename)
	mov di, bx			; And update our DI with that
	jmp .showdir


.done:
	mov di, dx			; Zero-terminate string
	dec di				; Don't want to store last comma!
	mov ax, 0
	stosb

	popa
	ret


	.file_list_tmp	dw 0
	.err_msg_floppy_reset	db 'os_get_file_list: Floppy failed to reset', 0


; -----------------------------------------------------------------
; os_program_load -- Load and execute program (must be 32K or less)
; IN: AX = location of filename, BX = 1 if loader should clear screen
; OUT: Carry set if program not found on the disk
; NOTE: Based on free bootloader code by E Dehling.

os_program_load:
	mov [.filename_loc], ax		; Store filename location
	mov [.clear_screen], bx

	xor eax, eax			; Needed for some older BIOSes

	call os_int_reset_floppy
	jnc .floppy_ok			; Did the floppy reset OK?

	mov ax, .err_msg_floppy_reset	; If not, bail out
	jmp os_fatal_error


.floppy_ok:				; Ready to read first block of data
	mov ax, 19			; Root dir starts at logical sector 19
	call os_int_l2hts

	lea si, [os_buffer]		; ES:BX should point to our buffer
	mov bx, ds
	mov es, bx
	mov bx, si

	mov ah, 0x02			; Params for int 13h: read floppy sectors
	mov al, 14			; And read 14 of them

	clc				; Prepare to enter loop
	pusha


.read_first_sector:
	popa
	pusha

	int 13h				; Read sectors

	call os_int_reset_floppy	; Check we've read them OK
	jc .read_first_sector		; If not, just keep trying

	popa

	mov ax, ds			; ES:DI = root directory
	mov es, ax
	lea di, [os_buffer]
	mov cx, word 244		; Search all entries in root dir
	mov ax, 0			; Searching offset 0 in root dir


.next_root_entry:
	xchg cx, dx			; We use CX in the inner loop...

	mov si, [.filename_loc]		; DS:SI = location of filename to load

	mov cx, 11			; Length of filename, for comparison
	rep cmpsb
	je .found_file_to_load

	add ax, 32			; Bump searched entries by 1 (offset + 32 bytes)

	lea di, [os_buffer]		; Point root-dir at next entry
	add di, ax

	xchg dx, cx			; Swap, as we need the 'outer' CX
	loop .next_root_entry

	stc				; If file never found, return with carry set
	ret


.found_file_to_load:			; Now fetch cluster and load FAT into RAM
	mov ax, word [es:di+0x0F]
	mov word [.cluster], ax

	mov ax, 1			; Sector 1 = first sector of first FAT
	call os_int_l2hts

	lea di, [os_buffer]		; ES:BX points to our buffer
	mov bx, di

	mov ah, 0x02			; int 13h params: read sectors
	mov al, 0x09			; And read 9 of them :-)

	clc				; In case not cleared in reading sector
	pusha

.read_fat:
	popa				; In case regs altered by int 13h
	pusha

	int 13h

	jnc .read_fat_ok

	call os_int_reset_floppy

	jmp .read_fat


.read_fat_ok:
	popa

	mov ax, 0x2000			; Where we'll load the file
	mov es, ax
	xor bx, bx

	mov ah, 0x02			; int 13h floppy read params
	mov al, 0x01

	push ax				; Save in case we (or int calls) lose it


	mov word [.pointer], 100h	; Entry point for apps


.load_file_sector:
	mov ax, word [.cluster]		; Convert sector to logical
	add ax, 31

	call os_int_l2hts		; Make appropriate params for int 13h

	mov ax, 0x2000			; Set buffer past what we've already read
	mov es, ax
	mov bx, word [.pointer]

	pop ax				; Save in case we (or int calls) lose it
	push ax

	int 13h

	jnc .calculate_next_cluster	; If there's no error...

	call os_int_reset_floppy	; Otherwise, reset floppy and retry
	jmp .load_file_sector


.calculate_next_cluster:
	mov ax, [.cluster]
	xor dx, dx
	mov bx, 2
	div bx				; DX = [CLUSTER] mod 2

	or dx, dx			; If DX = 0 [CLUSTER] = even, if DX = 1 then odd

	jz .even			; If [CLUSTER] = even, drop last 4 bits of word
					; with next cluster; if odd, drop first 4 bits

.odd:
	mov ax, [.cluster]
	mov bx, 3
	mul bx
	mov bx, 2
	div bx				; AX = address of word in FAT for the 12 bits

	lea si, [os_buffer]
	add si, ax
	mov ax, word [ds:si]

	shr ax, 4			; Shift out first 4 bits (belong to another entry)

	mov word [.cluster], ax

	cmp ax, 0x0FF8
	jae .end

	add word [.pointer], 512
	jmp .load_file_sector		; Onto next sector!

.even:
	mov ax, [.cluster]
	mov bx, 3
	mul bx
	mov bx, 2
	div bx

	lea si, [os_buffer]		; AX = word in FAT for the 12 bits
	add si, ax
	mov ax, word [ds:si]
	and ax, 0x0FFF			; Mask out last 4 bits
	mov word [.cluster], ax		; Store cluster

	cmp ax, 0x0FF8
	jae .end

	add word [.pointer], 512	; Increase buffer pointer
	jmp .load_file_sector


.end:
	pop ax				; Clear stack

	mov bx, [.clear_screen]
	cmp bx, 1
	jne .run_program

	call os_clear_screen

.run_program:
        pusha                           ; Save all register,
        push ds                         ; segment register
        push es                         ; es, ds and the
        mov [.mainstack],sp             ; save stack pointer
        xor ax,ax                       ; Clear registers
        xor bx,bx                       ; DOS cleared this
        xor cx,cx                       ; and we want be DOS
        xor dx,dx                       ; compatible
        xor si,si                       ;
        xor di,di                       ;
        xor bp,bp                       ;
        mov byte [now_run_a_program],1

	call 0x0100			; Jump to newly-loaded program!

.end_the_program:                       ; Here is the end of the program run
        mov byte [now_run_a_program],0
        mov sp,[.mainstack]             ; restore stack and
        pop es                          ; segment
        pop ds                          ; registers and
        popa                            ; the common registers
        clc                             ;
        ret                             ; return to the os

.notvalidfile:
	mov ax, .err_msg_invalid_file
	call os_fatal_error


	.bootd		db 0 		; Boot device number
	.cluster	dw 0 		; Cluster of the file we want to load
	.pointer	dw 0 		; Pointer into os_buffer, for loading 'file2load'

	.filename_loc	dw 0		; Temporary store of filename location
	.clear_screen	dw 0		; Setting for whether we clear the screen

	.err_msg_invalid_file	db 'os_program_load: Not a MikeOS executable (no MOS header bytes)', 0
	.err_msg_floppy_reset	db 'os_program_load: Floppy failed to reset', 0
        .mainstack dw 0

         now_run_a_program db 0



; =================================================================
; INTERNAL OS ROUTINES -- Not accessible to user programs

; -----------------------------------------------------------------
; Reboot machine via keyboard controller

os_int_reboot:
	; XXX -- We should check that keyboard buffer is empty first
	mov al, 0xFE
	out 0x64, al


; -----------------------------------------------------------------
; Reset floppy drive

os_int_reset_floppy:
	push ax
	push dx
	xor ax, ax
	mov dl, 0
	int 13h
	pop dx
	pop ax
	ret


; -----------------------------------------------------------------
; Convert floppy sector from logical to physical

os_int_l2hts:		; Calculate head, track and sector settings for int 13h
			; IN: AX = logical sector, OUT: correct regs for int 13h
	push bx
	push ax

	mov bx, ax			; Save logical sector

	xor dx, dx			; First the sector
	div word [.sectors_per_track]
	add dl, 01h			; Physical sectors start at 1
	mov cl, dl			; Sectors belong in CL for int 13h
	mov ax, bx

	xor dx, dx			; Now calculate the head
	div word [.sectors_per_track]
	xor dx, dx
	div word [.sides]
	mov dh, dl			; Head/side
	mov ch, al			; Track

	pop ax
	pop bx

	mov dl, 0			; Boot device = 0

	ret


	.sectors_per_track	dw 18	; Floppy disc info
	.sides			dw 2


; =================================================================
; MOUSE ROUTINES

gui_mouse_init:
	pusha

	call int_mouse_check_port

	xor ax, ax
	mov al, 0xA8			; Bit 5 = enable mouse port
	out 0x64, al			; Write to keyboard controller

	call int_mouse_check_port

	mov al, 0xF4			; Stream mode
	out 0x60, al			; Activate mouse

	call gui_mouse_get_byte		; Pull ACK from buffer

	mov al, 0x20			; Enable interrupts
	out 0x64, al
	call int_mouse_check_port
	in al, 0x60
	or al, 2
	xor cx, cx
	mov cl, al
	mov al, 0x60
	out 0x64, al
	mov al, cl
	out 0x60, al

	popa
	ret


gui_mouse_get_byte:
	call int_mouse_check_byte

	cmp bl, 1
	je .waskeyboard

	mov al, 0xAD			; Disable Keyboard
	out 0x64, al
	call int_mouse_check_port

	xor ax, ax			; Get data
	in al, 0x60
	mov dl, al

	mov al, 0xAE			; Enable Keyboard
	out 0x64, al
	call int_mouse_check_port

	mov al, dl
.waskeyboard:
	ret


int_mouse_check_byte:
.retry:
	in al, 0x64			; Read from keyboard controller
	test al, 1
	jz .retry
	test al, 0x20
	jz .iskeyboard			; Is it keyboard data?
	ret

.iskeyboard:				; XXX -- DO SOMETHING WITH IT!
	mov bl, 1			; Tells calling routine no mouse stuff
	; Apparently, here we should 'in al, 60h' to get the key that was pressed
	in al, 60h
	ret


int_mouse_check_port:
.again:
	in al, 0x64			; Read from keyboard controller
	test al, 2			; Processing data?
	jz .ok
	jmp .again			; If so, keep trying
.ok:
	ret


int_mouse_write:
	mov al, 0xD4			; We want mouse, not keyboard
	out 0x64, al			; Write to keyboard controller
	call int_mouse_check_byte
	ret


; =================================================================


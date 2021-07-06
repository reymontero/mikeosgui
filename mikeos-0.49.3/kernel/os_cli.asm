; =================================================================
; MikeOS -- The Mike Operating System kernel
; Copyright (C) 2006, 2007 MikeOS Developers -- see LICENSE.TXT
;
; COMMAND LINE INTERFACE
; =================================================================


	%DEFINE CLI_VER '1.0.2'


os_command_line:
	call os_clear_screen

	mov si, .default_prompt			; Set up default prompt
	mov di, .prompt
	call os_string_copy

	mov si, .help_text
	call os_print_string

.more:
	mov si, .prompt				; Prompt for input
	call os_print_string

	mov ax, .input				; Get string from user
	call os_input_string

	mov si, .newline
	call os_print_string

	mov ax, .input				; Remove trailing spaces
	call os_string_chomp

	mov si, .input				; Remove any full-stops
	mov ax, '.'
	call os_string_strip

	mov si, .input				; If just enter pressed, prompt again
	cmp byte [si], 0
	je .more



	mov si, .input				; Convert to uppercase for comparison
	call os_string_uppercase



	mov si, .input				; 'REBOOT' entered?
	mov di, .reboot_string
	call os_string_compare
	jc near .reboot

	mov si, .input				; 'HELP' entered?
	mov di, .help_string
	call os_string_compare
	jc near .print_help

	mov si, .input				; 'CLS' entered?
	mov di, .cls_string
	call os_string_compare
	jc near .clear_screen

	mov si, .input				; 'DIR' entered?
	mov di, .dir_string
	call os_string_compare
	jc near .list_directory

	mov si, .input				; 'PROMPT' entered?
	mov di, .chprompt_string
	call os_string_compare
	jc near .change_prompt

	mov si, .input				; 'VER' entered?
	mov di, .ver_string
	call os_string_compare
	jc near .print_ver



	mov ax, .input				; User entered full 11-char filename?
	call os_string_length

	cmp ax, 11
	jge .full_name

	mov si, .input				; If not, pad with spaces and 'BIN'
	add si, ax

.bitmore:
	cmp ax, 8
	jge .suffix
	mov byte [si], ' '
	inc si
	inc ax
	jmp .bitmore


.suffix:
	mov byte [si], 'B'
	inc si
	mov byte [si], 'I'
	inc si
	mov byte [si], 'N'
	inc si
	mov byte [si], 0			; Zero-terminate string


.full_name:
	mov ax, .input
	call os_program_load

	jnc .more

	mov si, .not_found_msg
	call os_print_string

	jmp .more



.change_prompt:
	mov si, .chprompt_msg
	call os_print_string

	mov ax, .prompt
	call os_input_string

	mov si, .newline
	call os_print_string

	jmp .more


.print_help:
	mov si, .help_text
	call os_print_string
	jmp .more


.clear_screen:
	call os_clear_screen
	jmp .more


.print_ver:
	mov si, .version_msg
	call os_print_string
	jmp .more


.list_directory:
	mov cx,	0				; Counter

	mov ax, .dirlist			; Get list of files on disk
	call os_get_file_list


	mov si, .dirlist
	mov ah, 0Eh				; BIOS teletype function

.repeat:
	lodsb					; Start printing filenames
	cmp al, 0				; Quit if end of string
	je .done

	inc cx					; 9 characters into filename?
	cmp cx, 9
	jne .nodot

	pusha					; If so, print a dot
	mov al, '.'
	int 10h
	popa

.nodot:
	cmp cx, 12				; Counter done a full filename?
	jne .noresetcounter
	mov cx, 0				; If so, reset it

.noresetcounter:
	cmp al, ','				; If comma in list string, don't print it
	jne .nonewline
	pusha
	mov si, .newline			; But print a newline instead
	call os_print_string
	popa
	jmp .repeat

.nonewline:
	cmp al, ' '				; Avoid printing spaces
	jne .notspace
	jmp .repeat

.notspace:
	int 10h
	jmp .repeat

.done:
	mov si, .newline
	call os_print_string
	jmp .more

.reboot:
	jmp os_int_reboot


	.input		times 255 db 0
	.dirlist	times 255 db 0
	.prompt		times 255 db 0

	.default_prompt		db '> ', 0
	.newline		db 13, 10, 0
	.help_text		db 'MikeOS CLI version ', CLI_VER, 13, 10, 'Inbuilt commands: DIR, CLS, HELP, PROMPT, VER, REBOOT', 13, 10, 0
	.not_found_msg		db 'No such command or program', 13, 10, 0
	.chprompt_msg		db 'Enter a new prompt:', 13, 10, 0
	.version_msg		db 'MikeOS ', MIKEOS_VER, ', CLI version ', CLI_VER, 13, 10, 0

	.reboot_string		db 'REBOOT', 0
	.help_string		db 'HELP', 0
	.cls_string		db 'CLS', 0
	.dir_string		db 'DIR', 0
	.chprompt_string	db 'PROMPT', 0
	.ver_string		db 'VER', 0


; =================================================================


; -----------------------------------------------------------------
; Include file for MikeOS program development
; -----------------------------------------------------------------

; -----------------------------------------------------------------
; IMPORTANT LOCATIONS

os_api_version		equ	0x8000	; Three-byte string of API version
os_main			equ	0x8003	; Jump here to completely restart OS
os_buffer		equ	0xE000	; 8K scratchpad space


; -----------------------------------------------------------------
; SYSTEM CALLS

os_print_string		equ	0x8006	; SI = zero-terminated string location
os_move_cursor		equ	0x800A	; DH, DL = row, column
os_clear_screen		equ	0x800E	; (Nothing used)
os_print_horiz_line	equ	0x8012	; AX = 1 for double line, else single
os_print_newline	equ	0x8016	; (Nothing used)
os_wait_for_key		equ	0x801A	; Returns AL = key pressed
os_check_for_key	equ	0x801E	; Returns AL = key pressed
os_int_to_string	equ	0x8022	; AX = integer, BX = string location
os_speaker_tone		equ	0x8026	; AX = note frequency
os_speaker_off		equ	0x802A	; (Nothing used)
os_program_load		equ	0x802E	; AX = filename string location
os_pause		equ	0x8032	; AX = 18ths of a second to wait
os_fatal_error		equ	0x8036	; AX = error string location
os_draw_background	equ	0x803A	; AX, BX = strings, CX = colour
os_string_length	equ	0x803E	; AX = string loc, returns AX = length
os_string_uppercase	equ	0x8042	; SI = zero-terminated string
os_string_lowercase	equ	0x8046	; SI = zero-terminated string
os_input_string		equ	0x804A	; AX = string location
os_string_copy		equ	0x804E	; SI = source, DI = dest strings
os_dialog_box		equ	0x8052	; AX, BX, CX = strings, DX = type
os_string_join		equ	0x8056  ; AX, BX = source strings, CX = dest
os_modify_int_handler	equ	0x805A	; CX = int number, SI = handler loc
os_get_file_list	equ	0x805E	; AX = string to store filenames
os_string_compare	equ	0x8062	; SI, DI = strings, carry set if same
os_string_chomp		equ	0x8066	; AX = string location
os_string_strip		equ	0x806A	; SI = string, AX = char to remove
os_string_truncate	equ	0x806E	; SI = string, AX = number of chars
os_bcd_to_int		equ	0x8072	; AL = BCD number, returns AX = integer
os_get_time_string	equ	0x8076	; BX = string location for eg '20:41'


; -----------------------------------------------------------------
; COLOURS

%DEFINE WHITE_ON_LIGHT_RED	11001111b	; Colours for os_dialog_box
%DEFINE RED_ON_LIGHT_GREEN	10100100b


; -----------------------------------------------------------------


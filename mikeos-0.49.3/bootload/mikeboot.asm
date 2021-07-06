; =================================================================
; MikeOSBoot 1.0 -- The Mike Operating System bootloader
; Copyright (C) 2006, 2007 MikeOS Developers -- see LICENSE.TXT
;
; Based on a free boot loader by E Dehling. Scans the FAT12
; floppy for MIKEKERN.BIN (the kernel), loads it and executes it.
; This must stay in 512 bytes, with the final two bytes being the
; boot signature (0xAA55). Assemble with NASM and write to floppy.
;
; NOTE: only checks first 16 root dir entries for MIKEKERN.BIN!
; Fixed by Peter Nemeth.
; =================================================================


	BITS 16

        jmp short bootloader_start    ; Jump past disk description section
        nop                           ; nop -> It is a practice


; -----------------------------------------------------------------
; Disk description table, to make it a valid floppy
; Note: some of these values are hard-coded in the source!

OEMlabel		db "MIKEBOOT" 	; Disk label
BytesPerSector		dw 512        	; Bytes per sector
SectorsPerCluster	db 1          	; Sectors per cluster
ReservedForBoot		dw 1          	; Reserved sectors for boot record
NumberOfFats		db 2          	; Number of copies of the FAT
RootDirEntries		dw 224        	; Number of entries in root dir
					; (224 * 32 = 7168 = 14 sectors to read)
LogicalSectors		dw 2880       	; Number of logical sectors
MediumByte		db 0xF0       	; Medium descriptor byte
SectorsPerFat		dw 9          	; Sectors per FAT
SectorsPerTrack		dw 18         	; Sectors per track/cylinder
Sides			dw 2          	; Number of sides/heads
HiddenSectors           dd 0            ; Number of hidden sectors
LargeSectors            dd 0            ; Number of LBA sectors
DriveNo                 dw 0            ; Drive No -> 0
Signature               db 41           ; Drive signature -> 41 for floppy
VolumeID                dd 0x00000000   ; Volume ID -> It's any number
VolumeLabel             db 'MIKEOS     '; Volume Label -> Any 11 chars
FileSystem              db 'FAT12   '   ; File system type -> not change


; -----------------------------------------------------------------
; Main bootloader code

bootloader_start:
	mov ax, 0x07C0			; Set up 4K of stack space
	add ax, 512
	mov ss, ax
	mov sp, 4096

	mov ax, 0x07C0
	mov ds, ax

	mov byte [bootdev], dl		; Save boot device number


	xor eax, eax			; Needed for some older BIOSes

	call reset_floppy
	jnc floppy_ok			; Did the floppy reset OK?

        mov si, disk_error              ; If not, print error message and reboot
	call print_string
        jmp reboot

floppy_ok:				; Ready to read first block of data
	mov ax, 19			; Root dir starts at logical sector 19
	call l2hts

	lea si, [buffer]		; Set ES:BX to point to our buffer
	mov bx, ds
	mov es, bx
	mov bx, si

	mov ah, 0x02			; Params for int 13h: read floppy sectors
	mov al, 14			; And read 14 of them

	clc				; Prepare to enter loop
	pusha


read_first_sector:
	popa
	pusha

	int 13h				; Read sectors

	call reset_floppy		; Check we've read them OK
	jc read_first_sector		; If not, keep trying

	popa


	mov ax, ds			; Root dir is now in [buffer]
	mov es, ax			; Set DI to this info
	lea di, [buffer]

	mov cx, word [RootDirEntries]	; Search all entries
        xor ax, ax                       ; Searching at offset 0


next_root_entry:
	xchg cx, dx			; We use CX in the inner loop...

	lea si, [kern_filename]		; Start searching for kernel filename
	mov cx, 11
	rep cmpsb
	je found_file_to_load

	add ax, 32			; Bump searched entries by 1 (offset + 32 bytes)

	lea di, [buffer]		; Point to next entry
	add di, ax

	xchg dx, cx			; Get the original CX back
	loop next_root_entry

	mov si, file_not_found		; If kernel not found, bail out
	call print_string
        jmp reboot

found_file_to_load:			; Fetch cluster and load FAT into RAM
	mov ax, word [es:di+0x0F]
	mov word [cluster], ax

	mov ax, 1			; Sector 1 = first sector of first FAT
	call l2hts

	lea di, [buffer]		; ES:BX points to our buffer
	mov bx, di

	mov ah, 0x02			; int 13h params: read sectors
	mov al, 0x09			; And read 9 of them

	clc				; In case not cleared in reading sector
	pusha


read_fat:
	popa				; In case regs altered by int 13h
	pusha

	int 13h

	jnc read_fat_ok

	call reset_floppy

	jmp read_fat


read_fat_ok:
	popa

	mov ax, 0x2000			; Where we'll load the kernel
	mov es, ax
	xor bx, bx

	mov ah, 0x02			; int 13h floppy read params
	mov al, 0x01

	push ax				; Save in case we (or int calls) lose it

load_file_sector:
	mov ax, word [cluster]		; Convert sector to logical
	add ax, 31

	call l2hts			; Make appropriate params for int 13h

	mov ax, 0x2000			; Set buffer past what we've already read
	mov es, ax
	mov bx, word [pointer]

	pop ax				; Save in case we (or int calls) lose it
	push ax

	int 13h

	jnc calculate_next_cluster	; If there's no error...

	call reset_floppy		; Otherwise, reset floppy and retry
	jmp load_file_sector


calculate_next_cluster:
	mov ax, [cluster]
	xor dx, dx
	mov bx, 2
	div bx				; DX = [CLUSTER] mod 2

	or dx, dx			; If DX = 0 [CLUSTER] = even, if DX = 1 then odd

	jz even				; If [CLUSTER] = even, drop last 4 bits of word
					; with next cluster; if odd, drop first 4 bits

odd:
	mov ax, [cluster]
	mov bx, 3
	mul bx
	mov bx, 2
	div bx				; AX = address of word in FAT for the 12 bits

	lea si, [buffer]
	add si, ax
	mov ax, word [ds:si]

	shr ax, 4			; Shift out first 4 bits (belong to another entry)

	mov word [cluster], ax

	cmp ax, 0x0FF8
	jae end

	add word [pointer], 512
	jmp load_file_sector		; Onto next sector


even:
	mov ax, [cluster]
	mov bx, 3
	mul bx
	mov bx, 2
	div bx

	lea si, [buffer]
	add si, ax			; AX = word in FAT for the 12 bits
	mov ax, word [ds:si]
	and ax, 0x0FFF			; Mask out last 4 bits
	mov word [cluster], ax		; Store cluster

        cmp ax, 0x0FF8                  ; 0x0FF8 -> End of file marker in FAT12
	jae end

	add word [pointer], 512		; Increase buffer pointer
	jmp load_file_sector


end:
	pop ax				; Clear stack
	mov dl, byte [bootdev]		; Provide kernel with boot device info

	jmp 0x2000:0x8003		; Jump to entry point of loaded kernel!
					; Kernel loaded at 0x2000:0x0000, but the
					; first 32K is blank (app space). We also
					; skip the three OS version bytes


; -----------------------------------------------------------------
; Subroutines

reboot:
        xor ax,ax
        int 0x16                        ; Wait for keystroke
        xor ax,ax
        int 0x19                        ; reboot the system


print_string:			; Output string in SI to screen
	pusha

	mov ah, 0Eh		; int 10h teletype function

.repeat:
	lodsb			; Get char from string
	cmp al, 0
	je .done		; If char is zero, end of string
	int 10h			; Otherwise, print it
        jmp short .repeat

.done:
	popa
	ret


reset_floppy:		; IN: BOOTD = boot device / OUT: CF = set on error
	push ax
	push dx
	xor ax, ax
	mov dl, byte [bootdev]
	int 13h
	pop dx
	pop ax
	ret


l2hts:			; Calculate head, track and sector settings for int 13h
			; IN: logical sector in AX / OUT: correct registers for int 13h
	push bx
	push ax

	mov bx, ax			; Save logical sector

	xor dx, dx			; First the sector
	div word [SectorsPerTrack]
	add dl, 01h			; Physical sectors start at 1
	mov cl, dl			; Sectors belong in CL for int 13h
	mov ax, bx

	xor dx, dx			; Now calculate the head
	div word [SectorsPerTrack]
	xor dx, dx
	div word [Sides]
	mov dh, dl			; Head/side
	mov ch, al			; Track

	pop ax
	pop bx

	mov dl, byte [bootdev]		; Set correct device

	ret


; -----------------------------------------------------------------
; Strings and variables

	kern_filename	db 'MIKEKERNBIN'	; MikeOS kernel filename

        disk_error      db 'Floppy error! Press any key...', 0
        file_not_found  db 'MIKEKERN.BIN not found!', 0

	bootdev		db 0 	; Boot device number
	cluster		dw 0 	; Cluster of the file we want to load
	pointer		dw 0 	; Pointer into Buffer, for loading 'file2load'


; -----------------------------------------------------------------
; Remainder of boot sector

	times 510-($-$$) db 0   ; Pad remainder of MBR sector with 0s
	dw 0xAA55		; Boot signature (DO NOT CHANGE!)


buffer:				; Disk buffer begins (8k after this, stack starts)


; =================================================================


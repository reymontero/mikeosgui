! 1 
! 1 /* IF NO C CODE USED:
! 2 
! 3 
! 4 +    void 
! 5 +  memsetb(seg,offset,value,count)
! 6 +    Bit16u seg;
! 7 +    Bit16u offset;
! 8 +    Bit16u value;
! 9 +    Bit16u count;
! 10 +  {
! 11 +  #asm
! 12 +    push bp
! 13 +    mov  bp, sp
! 14 +  
! 15 +      push ax
! 16 +      push cx
! 17 +      push es
! 18 +      push di
! 19 +  
! 20 +      mov  cx, 10[bp] ; count
! 21 +      cmp  cx, #0x00
! 22 +      je   memsetb_end
! 23 +      mov  ax, 4[bp] ; segment
! 24 +      mov  es, ax
! 25 +      mov  ax, 6[bp] ; offset
! 26 +      mov  di, ax
! 27 +      mov  al, 8[bp] ; value
! 28 +      cld
! 29 +      rep
! 30 +       stosb
! 31 +  
! 32 +  memsetb_end:
! 33 +      pop di
! 34 +      pop es
! 35 +      pop cx
! 36 +      pop ax
! 37 +  
! 38 +    pop bp
! 39 +  #endasm
! 40 +  } */
! 41 
! 42 
! 43 
! 44 
! 45 /* bcc foo.c -0 -S && as86 -0 foo.s -o foo.o && ld86 -d foo.o -o main.bin */
! 46 
! 47 void putc(c);
!BCC_EOS
! 48 void putsy(s);
!BCC_EOS
! 49 
! 50 int main()
! 51 {
export	_main
_main:
! 52 	int y;
!BCC_EOS
! 53 
! 54 /*
! 55 	int x;
! 56 
! 57 	for (x = 0; x < 10; x++)
! 58 		putc('M');
! 59 */
! 60 
! 61 	char *silly = "Wowzers";
push	bp
mov	bp,sp
push	di
push	si
add	sp,*-4
! Debug: eq [8] char = .1+0 to * char silly = [S+$A-$A] (used reg = )
mov	bx,#.1
mov	-8[bp],bx
!BCC_EOS
! 62 
! 63 	for (y = 0; y != 400; y++)
! Debug: eq int = const 0 to int y = [S+$A-8] (used reg = )
xor	ax,ax
mov	-6[bp],ax
!BCC_EOS
!BCC_EOS
! 64 		putc(silly[y]);
jmp .4
.5:
! Debug: ptradd int y = [S+$A-8] to * char silly = [S+$A-$A] (used reg = )
mov	ax,-6[bp]
add	ax,-8[bp]
mov	bx,ax
! Debug: list char = [bx+0] (used reg = )
mov	al,[bx]
xor	ah,ah
push	ax
! Debug: func () void = putc+0 (used reg = )
call	_putc
inc	sp
inc	sp
!BCC_EOS
! 65 
! 66 	putc('E');
.3:
! Debug: postinc int y = [S+$A-8] (used reg = )
mov	ax,-6[bp]
inc	ax
mov	-6[bp],ax
.4:
! Debug: ne int = const $190 to int y = [S+$A-8] (used reg = )
mov	ax,-6[bp]
cmp	ax,#$190
jne	.5
.6:
.2:
! Debug: list int = const $45 (used reg = )
mov	ax,*$45
push	ax
! Debug: func () void = putc+0 (used reg = )
call	_putc
inc	sp
inc	sp
!BCC_EOS
! 67 	putc('G');
! Debug: list int = const $47 (used reg = )
mov	ax,*$47
push	ax
! Debug: func () void = putc+0 (used reg = )
call	_putc
inc	sp
inc	sp
!BCC_EOS
! 68 	putc('G');
! Debug: list int = const $47 (used reg = )
mov	ax,*$47
push	ax
! Debug: func () void = putc+0 (used reg = )
call	_putc
inc	sp
inc	sp
!BCC_EOS
! 69 }
add	sp,*4
pop	si
pop	di
pop	bp
ret
! 70 
! 71 
! 72 void putsy(s)
! 73 	char *s;
export	_putsy
_putsy:
!BCC_EOS
! 74 {
! 75 	int x;
!BCC_EOS
! 76 
! 77 	for(x = 0; x != 200; x++)
push	bp
mov	bp,sp
push	di
push	si
dec	sp
dec	sp
! Debug: eq int = const 0 to int x = [S+8-8] (used reg = )
xor	ax,ax
mov	-6[bp],ax
!BCC_EOS
!BCC_EOS
! 78 		putc(s[x]);
jmp .9
.A:
! Debug: ptradd int x = [S+8-8] to * char s = [S+8+2] (used reg = )
mov	ax,-6[bp]
add	ax,4[bp]
mov	bx,ax
! Debug: list char = [bx+0] (used reg = )
mov	al,[bx]
xor	ah,ah
push	ax
! Debug: func () void = putc+0 (used reg = )
call	_putc
inc	sp
inc	sp
!BCC_EOS
! 79 }
.8:
! Debug: postinc int x = [S+8-8] (used reg = )
mov	ax,-6[bp]
inc	ax
mov	-6[bp],ax
.9:
! Debug: ne int = const $C8 to int x = [S+8-8] (used reg = )
mov	ax,-6[bp]
cmp	ax,#$C8
jne	.A
.B:
.7:
inc	sp
inc	sp
pop	si
pop	di
pop	bp
ret
! 80 
! 81 
! 82 void putc(c)
! 83 	char c;
export	_putc
_putc:
!BCC_EOS
! 84 {
! 85 #asm
!BCC_ASM
_putc.c	set	2
	push bp
	mov bp, sp

	pusha

	mov ax, 4[bp]
	cmp al, #0
	je noprint
	mov ah, #0x0E
	int #0x10

noprint:
	popa

	pop bp
! 101 endasm
!BCC_ENDASM
! 102 }
ret
! 103 
! 104 
.data
.1:
.C:
.ascii	"Wowzers"
.byte	0
.bss

! 0 errors detected

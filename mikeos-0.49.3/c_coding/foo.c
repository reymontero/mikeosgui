/* Test for compiling C programs for MikeOS */
/* BCC and I seem to disagree on the calling convention with pointers! */
/* Hence I can't get putsy to work here */

/* Compile with: */
/* bcc foo.c -0 -S && as86 -0 foo.s -o foo.o && ld86 -d foo.o -o main.bin */

void putc(c);
void putsy(s);

int main()
{
	int y;

/*
	int x;

	for (x = 0; x < 10; x++)
		putc('M');
*/

	char *silly = "Wowzers";

	for (y = 0; y != 400; y++)
		putc(silly[y]);

	putc('E');
	putc('G');
	putc('G');
}


void putsy(s)
	char *s;
{
	int x;

	for(x = 0; x != 200; x++)
		putc(s[x]);
}


void putc(c)
	char c;
{
#asm
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
#endasm
}


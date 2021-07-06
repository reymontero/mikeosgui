Rem Build script for DOS users
@echo off
echo Assembling bootloader...
nasm -f bin -o .\bootload\mikeboot.bin .\bootload\mikeboot.asm
echo Assembling MikeOS kernel...
cd kernel
nasm -f bin -o mikekern.bin os_main.asm
cd ..
echo Assembling programs...
cd programs
 for %%i in (*.asm) do nasm -fbin %%i
 for %%i in (*.bin) do del %%i
 for %%i in (*.) do ren %%i %%i.bin
cd ..
echo Done!
 

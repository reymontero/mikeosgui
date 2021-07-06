===================================================================
MikeOS -- Open source 16-bit operating system for x86 PCs
Copyright (C) 2006, 2007 MikeOS Developers -- see LICENSE.TXT
===================================================================

This is a small and simple operating system for x86 PCs. It is not
intended to develop into a fully-fledged OS -- it's a system for
learning basic OS design and x86 assembler. Contributors are welcome
to add system calls, example programs and other features, providing
they remain in 16-bit real-mode assembler.

There is a basic API (see mikedev.inc and examples in the programs/ 
directory), along with rudimentary support for small DOS COM programs.
On startup MikeOS offers a menu-based program selector and a simple
command-line shell.


Running MikeOS
--------------

See the 'disk-images' directory for floppy disk and CD-ROM images
you can use. If you have the QEMU PC emulator, you can run them with
'qemu -fda mikeos.flp' or 'qemu -cdrom mikeos.iso'. A UNIX 'test'
script is provided which starts QEMU with the virtual floppy image.

For testing on a real PC, write the mikeos.flp file to a floppy
disk, or mikeos.iso to a CD-R, and boot your PC from it. Note that
you have to write the files to the media as disk images -- you can't
just copy them over. On Linux, for example, use 'cdrecord' to write
MikeOS to a CD-R.


Building MikeOS
---------------

See the 'build' script for details -- this script assembles the
bootloader, kernel and example programs. To write them to the
floppy disk image, use the 'make_disks' script, which also
generates a CD-ROM ISO image in the disk-images/ directory.
Note that the 'make_disks' script is written for Linux systems,
and needs to be run as root for the loopback floppy disk
image mounting.


Credits
-------

Mike Saunders: main OS code, original DOS support, CLI, text-mode
GUI, system calls

Peter Nemeth: many DOS support routines, system calls, bugfixes

E Dehling: wrote a bootloader on which the original MikeOS FAT12
routines are based


Further information
-------------------

For information on modifying MikeOS, see the DEVEL.TXT file. The
MikeOS code is released under a BSD-style license -- see the
LICENSE.TXT file. You can find the latest version and news at
http://mikeos.sourceforge.net

Contact me if you want to get involved, and have fun!


 -- Mike Saunders (okachi@gmail.com) 16/01/07


===================================================================


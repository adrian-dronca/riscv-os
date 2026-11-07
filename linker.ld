ENTRY(_start)

SECTIONS
{
    . = 0x80000000; # Place the program starting at address 0x80000000. This is the start of RAM on QEMU's RISC-V virt platform

    .text : { # code instructions 
        *(.text)
        *(.text.*)
    }

    .data : { # variables
        *(.data)
        *(.data.*)
    }

    .bss : ALIGN(8) { # zero-initialized variables
        _bss_start = .;
        *(.bss)
        *(.bss.*)
        _bss_end = .;
    }
    # stack area start here
    . = ALIGN(16); # top is 16-byte aligned
    . += 32K; # let`s take 32kbytes as stack memory size 
    _stack_top = .;
    # stack area stops here, _stack_top points to maximum and normally stack starts after bss section grows until it reaches _stack_top
}

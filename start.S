
.global _start

.equ UART_BASE_ADDRESS, 0x10000000 # Base address of the UART peripheral in QEMUvirt

.macro PUSH reg
    addi sp, sp, -16
    sd \reg, 8(sp)
.endm
.macro POP reg
    ld \reg, 8(sp)
    addi sp, sp, 16
.endm

.text
_start:
    # init the stack pointer
    la sp, _stack_top

    # init RAM with zero
    jal ra, init_ram

    # Configure M-mode trap_handler
    la t0, trap_handler
    csrw mtvec, t0 # 0x305 mtvec MRW Machine Trap-Handler Base Address

    # Start firmware    
    # Send data via a0 register using a function
    la a0, _msg # Load the starting address of the string into a0
    jal ra, uart_putstring # Jump/Call the function and return the address to ra register

    # intentional error to force a trap
    ebreak 
stop:
    j stop

init_ram:
    # t0 - current address
    # t1 - end address
    la t0, _bss_start
    la t1, _bss_end

_bss_loop:
    bgeu t0, t1, init_ram_end
    # Store 8 bytes of zero
    sd zero, 0(t0)
    addi t0,t0,8 # increment to the next address. because on our RV64 machine we can conveniently clear 64 bits at a time.
    j _bss_loop
init_ram_end:
    ret

uart_putstring:
    # Implementation for writting a string via UART
    # a0: pointer to the string
    # t0: temporary register to hold the character
    # t1: loop index
    PUSH ra # Save the return address onto the stack
    sd s0, 0(sp) # Save the s0 register onto the stack
    mv s0, a0 # Use s0 as pointer and preserve a0 as original value

_loop_string:
    lb a0, 0(s0) # Load the first byte of the string into a0 to keep the caracter 
    beqz a0, uart_putstring_end # if the byte is zero it means end of string    
    jal ra, uart_putchar # Call the function to send the character
    addi s0, s0, 1 # Move to the next character in the string
    
    j _loop_string # Loop through all string 

uart_putstring_end:
    # end of the string return from function
    ld s0, 0(sp) # Restore the s0 register from the stack
    POP ra # Restore the return address from the stack
    ret

uart_putchar:
    li t0, UART_BASE_ADDRESS
    sb a0, 0(t0)

    ret # jalr x0, 0(ra)
    
_msg:
    .asciz "Hello World!\n"

trap_handler:

    #On RV64, each register is 8 bytes:
    addi sp, sp, -48 # Allocate 6 x 8 bytes
    sd ra,  0(sp)
    sd t0,  8(sp)
    sd t1, 16(sp)
    sd t2, 24(sp)
    sd a0, 32(sp)
    sd a1, 40(sp)

    
    csrr t0, mcause # Read the cause of the trap into t0
    csrr t1, mepc   # Read the program counter, it provides the address of the fault instruction
    csrr t2, mtval  # Read the trap value, may provide additional fault information

    # Distinguish exceptions from interrupts using mcause
    # bit 63 -> 1 for interrupts, 0 for exceptions
    # bit 62 .. 0 -> cause 
    # bit 63                                      bits 62..0
    #   ↓                                             ↓
    #  ---+---------------------------------------------+
    #  |  I  |                 cause code               |
    # +---+---------------------------------------------+
    bltz t0, trap_interrupt # 1 bit is negative meaning an interrupt occurd

trap_exception: # in case the jump did no occur we are in exception mode  
    
    # this ebreak exception has 4 bytes in normal and 2 bytes in compressed instruction so lets skip it
    addi t1, t1, 2
    csrw mepc, t1 # Control and Status Register Write pc+2 bytes (ebreak compressed)

    j trap_restore

trap_interrupt: 
# 3 - M-mode; 
# 7 - Machine Timer Interrrupt;
# 11 - Machine External Interrupt;
# 12 - Supervisor Software Interrupt;
# 15 - Supervisor Timer Interrupt; 
# 19 - Supervisor External Interrupt

trap_interrupt_stop:
    # do nothing for now
    j trap_interrupt_stop

trap_restore:
    # recover the registers
    #On RV64, each register is 8 bytes:
    ld ra,  0(sp)
    ld t0,  8(sp)
    ld t1, 16(sp)
    ld t2, 24(sp)
    ld a0, 32(sp)
    ld a1, 40(sp)
    addi sp, sp, 48 # Deallocate 6 x 8 bytes

    mret # Return from trap

# stop the program
trap_stop:
    j trap_stop

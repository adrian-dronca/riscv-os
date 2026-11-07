
.global _start

.equ UART_BASE_ADDRESS, 0x10000000 # Base address of the UART peripheral in QEMUvirt
/*
    QEMUvirt specific memory addresses for CLI (Core Local Interruptor) /
     ACLINT (Advanced Core Local Interruptor) timer hardware
*/
.equ ACLINT_BASE,    0x02000000
.equ MTIMECMP,       0x02004000 # address where we store start time used to compare with the current time to generate interrupt
.equ MTIME,          0x0200BFF8 # address of hardware timer where it stores the current time 

# trap_interrupt: 
# 1  = Supervisor software interrupt
# 3  = Machine software interrupt
# 5  = Supervisor timer interrupt
# 7  = Machine timer interrupt
# 9  = Supervisor external interrupt
# 11 = Machine external interrupt
.equ TRAP_INT_SOFTWARE, 3
.equ TRAP_INT_MACHINE_TIMER, 7
.equ TRAP_INT_MACHINE_EXTERNAL, 11


.equ TRAP_EXCEPTION_ILLEGAL_INSTRUCTION, 2
.equ TRAP_EXCEPTION_BREAKPOINT,          3
.equ TRAP_EXCEPTION_M_ECALL,            11

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

    # Test Machine Timer Interrupts
    # config next timer interrupt
    jal ra, timer_set_next_interrupt # ra overwritten by new call

    # Enable Machine Timer Interrupts
    li t0, 0x80 # bit 7 in 32bit register is the MIE (Machine Interrupt Enable) bit
    csrs mie, t0 # CSR (Control and Status Register) Read and Set command
    # Enable global interrupts in M-mode
    li t0, 0x8 # bit 3 is mstatus.MIE 
    csrs mstatus, t0 # Set mstatus.MIE = 1 to enable global interrupts 

    # Start firmware    
    # Send data via a0 register using a function
    la a0, _msg # Load the starting address of the string into a0
    jal ra, uart_putstring # Jump/Call the function and return the address to ra register

    #j stop #comment disabled to test the exception

    # Test Exception Handling
    ebreak # breakpoint

    j stop

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
    addi sp, sp, -64 # Allocate 8 x 8 bytes
    sd ra,  0(sp)
    sd t0,  8(sp)
    sd t1, 16(sp)
    sd t2, 24(sp)
    sd a0, 32(sp)
    sd a1, 40(sp)
    sd t3, 48(sp)
    sd t4, 56(sp)

    
    csrr t0, mcause # Read the cause of the trap into t0
    csrr t1, mepc   # Read the program counter, it provides the address of the fault instruction
    csrr t2, mtval  # Read the trap value, may provide additional fault information

    # Distinguish exceptions from interrupts using mcause
    # bit 63 -> 1 for interrupts, 0 for exceptions
    # bit 62:5 -> always 0
    # bit 4:0 -> cause 
    # bit 63                                      bits 62..0
    #   ↓                                             ↓
    #  ---+---------------------------------------------+
    #  |  I  |                 cause code               |
    # +---+---------------------------------------------+
    bltz t0, trap_interrupt # 1 bit is negative meaning an interrupt occurd

trap_exception: # in case the jump did no occur we are in exception mode  
    /* 
    Register mcause bits[4:0] root-cause of the exception
    2: Illegal instruction
    3: Breakpoint
    11: MCALL
    */
    # bit 63 is 0 because its exception

    # Test for illegal instruction exception
    li t3, TRAP_EXCEPTION_ILLEGAL_INSTRUCTION
    beq t0, t3, trap_exception_illegal_instruction

    # Test for breakpoint exception
    li t3, TRAP_EXCEPTION_BREAKPOINT
    beq t0, t3, trap_exception_breakpoint

    # Test for mcall exception
    li t3, TRAP_EXCEPTION_M_ECALL
    beq t0, t3, trap_exception_m_ecall

    j trap_exception_unknown

trap_instruction_32bit:
    addi t1, t1, 4
    csrw mepc, t1 # Control and Status Register Write pc+4 bytes (ebreak uncompressed)

    j trap_restore


trap_exception_illegal_instruction:
    j trap_exception_illegal_instruction

trap_exception_breakpoint:
    # Instruction lenght detection compressed or normal 64bit instruction
    # Read first 16 bits of instruction located at mepc.
    #
    # Instruction encoding bits [1:0]:
    #   00 -> 16-bit compressed
    #   01 -> 16-bit compressed
    #   10 -> 16-bit compressed
    #   11 -> longer than 16 bits
    lhu t3, 0(t1) # load half word from mepc which is same as t1 register now into t3 for comparison
    andi t4, t3, 0x3 # mask reg & 11 => 11 if instruction is not compressed
    xori t4, t4, 0x3 # xor reg & 11 => 00 if instruction is not compressed
    beqz t4, trap_instruction_32bit
    # if jump did not occur then the instruction is compressed
    addi t1, t1, 2
    csrw mepc, t1 # Control and Status Register Write pc+2 bytes (ebreak compressed)

    j trap_restore

trap_exception_m_ecall:
    j trap_exception_m_ecall

trap_exception_unknown:
    j trap_exception_unknown

trap_interrupt: 
    # 1  = Supervisor software interrupt
    # 3  = Machine software interrupt
    # 5  = Supervisor timer interrupt
    # 7  = Machine timer interrupt
    # 9  = Supervisor external interrupt
    # 11 = Machine external interrupt

    # t3 register contains root-cause
    slli t3, t0, 1 # Shift Left Immediate to remove bit 63 and isolate the root cause
    srli t3, t3, 1 # Shift Right Immediate to comeback to 64bit system and place the lower bits in the right position
    
    # Test Machine Timer Interrupt
    li t4, TRAP_INT_MACHINE_TIMER  # beq requires register-to-register comparison
    beq t3, t4, trap_interrupt_timer # if root-cause is 7 then its a timer interrupt

    # Interrupt occured but source is unknown
    j trap_interrupt_unknown

trap_interrupt_unknown:
    j trap_interrupt_unknown    

trap_interrupt_timer:
    # config next timer interrupt
    jal ra, timer_set_next_interrupt # ra overwritten by new call
    j trap_restore

timer_set_next_interrupt:
    /* Interrupt M-Mode Timer config */
    li t0, MTIME
    ld a0, 0(t0)

    li t2, 100000 # addi only has 12-bit, pseudo li used to hold upper bits, however a 3rd register is needed
    add t1, a0, t2

    li t0, MTIMECMP
    sd t1, 0(t0)

    ret

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
    ld t3, 48(sp)
    ld t4, 56(sp)
    addi sp, sp, 64 # Deallocate 8 x 8 bytes as it needs to be 16bytes aligned

    mret # Return from trap

# stop the program
trap_stop:
    j trap_stop

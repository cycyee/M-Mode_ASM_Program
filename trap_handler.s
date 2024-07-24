##
# Copyright (c) 1990-2023 James R. Larus.
# Copyright (c) 2023 LupLab.
#
# SPDX-License-Identifier: AGPL-3.0-only
##

# This a modified version of the default system code for VRV.

# It contains three parts:

# 1. The machine boot code, starting from global label
#    `__mstart`. This boot code sets up the trap vector, and jumps to
#    label `__user_bootstrap` in user mode.

# 2. The trap handler, which is called upon an exception (interrupts
#    are not enabled by default).
	
# 3. The small user bootstrap code, starting from global label
#    `__user_bootstrap`. This bootstrap code calls `main`, which is expected to
#     be defined by the user program. If main returns, the bootstrap code exits
#     with the value returned by main.

# You will need to modify the trap handler to:

# a) Save all registers

# b) Examine the cause to determine if it is a misaligned load word.

# c) If it IS a misaligned load word, it should patch up the
# result and resume execution at the next instruction.

# d) Otherwise, it should jump to the terminate operation
# which is the default printing routine from VRV's default
# system file.

	## Constants
.equ    PRINT_DEC  0
.equ    PRINT_HEX   1
.equ    PRINT_CHR   3
.equ    PRINT_STR   4
.equ    EXIT        20

.equ    NEWLN_CHR   '\n'
.equ    SPACE_CHR   ' '

.equ 	KSTACK_SIZE 4096
	
# YOU can add more constants here, and you probably will want to!

## System data
    .kdata
__m_exc:    .string "  Exception"
__m_int:    .string "  Interrupt"

__m_mcause: .string "\n    MCAUSE: "
__m_mepc:   .string "\n    MEPC:   "
__m_mtval:  .string "\n    MTVAL:  "

__e0:   .string " [Misaligned instruction address]"
__e1:   .string " [Instruction access fault]"
__e2:   .string " [Illegal instruction]"
__e3:   .string " [Breakpoint]"
__e4:   .string " [Misaligned load address]"
__e5:   .string " [Load access fault]"
__e6:   .string " [Misaligned store address]"
__e7:   .string " [Store access fault]"
__e8:   .string " [User-mode ecall]"
__e11:  .string " [Machine-mode ecall]"

__i3:   .string " [Software]"
__i7:   .string " [Timer]"
__i11:  .string " [External]"

__evec: .word __e0, __e1, __e2, __e3, __e4, __e5, __e6, __e7, __e8, 0, 0, __e11
__ivec: .word 0, 0, 0, __i3, 0, 0, 0, __i7, 0, 0, 0, __i11

	.align 2

	# A small stack for kernel data
kstack:  .zero   KSTACK_SIZE

## System code
    .ktext
### Boot code
    .globl __mstart
__mstart:
    la      t0, __mtrap
    csrw    mtvec, t0

	la      t0, __user_bootstrap
	csrw    mepc, t0

	# Allocates space so the trap handler has a
	# small stack and can therefore call functions
	# itself.
	la 	t0, kstack
	li	t1, KSTACK_SIZE
	add 	t0 t0 t1
	csrw   	mscratch, t0
	mret    # Enter user bootstrap

### Trap handler

### You will need to write your own trap handler functionality here.
__mtrap:
    # preamble (Save Registers)
    csrrw sp, mscratch, sp #cssrw 

    addi sp, sp, -128
    sw x1, 0(sp)   # Save ra
    sw x2, 4(sp)   # Save sp
    sw x3, 8(sp)   # Save gp
    sw x4, 16(sp)   # Save tp
    sw x5, 20(sp)   # Save t0
    sw x6, 24(sp)   # Save t1
    sw x7, 28(sp)   # Save t2
    sw x8, 32(sp)    # Save s0
    sw x9, 36(sp)    # Save s1
    sw x10, 40(sp)   # Save a0
    sw x11, 44(sp)   # Save a1
    sw x12, 48(sp)   # Save a2
    sw x13, 52(sp)   # Save a3
    sw x14, 56(sp)   # Save a4
    sw x15, 60(sp)   # Save a5
    sw x16, 64(sp)   # Save a6
    sw x17, 68(sp)   # Save a7
    sw x18, 72(sp)   # Save s2
    sw x19, 76(sp)   # Save s3
    sw x20, 80(sp)   # Save s4
    sw x21, 84(sp)   # Save s5
    sw x22, 88(sp)   # Save s6
    sw x23, 92(sp)   # Save s7
    sw x24, 96(sp)   # Save s8
    sw x25, 100(sp)   # Save s9
    sw x26, 104(sp)   # Save s10
    sw x27, 108(sp)   # Save s11
    sw x28, 112(sp)   # Save t3
    sw x29, 116(sp)   # Save t4
    sw x30, 120(sp)    # Save t5
    sw x31, 124(sp)    # Save t6
    
    #get mcause and check for misaligned load 
    csrr t0, mcause
    li t1, 0x4
    beq t0, t1, check_mepc #if not load, terminate
    j terminate
    #mask for opcode
    check_mepc:
        csrr t2, mepc
        csrr t4, mtval
        srli s2, t2, 2               # Shift mepc right by 2 bits
        srli s1, t4, 2               # Shift mtval right by 2 bits
        beq s1, s2, terminate


        lw t3, 0(t2) #load the instruction word into t3
        andi t4, t3, 0x7F #mask for opcode t4 has opcode
        li t1, 0x03 #opcode for load is 0000011
        bne t4, t1, terminate
        srli t4, t3, 12 #shift opcode to the right to put funct 3 for masking
        andi t4, t4, 0x7 #lowest 3 bit
        li t1, 0x2 #funct3 for load is 010
        bne t4, t1, terminate
        
    #check mtval

    csrr t4, mtval                # Read the faulting address into t4

    # Load the aligned word from memory
    lbu t6, 0(t4)                  # Load the first byte
    lbu a0, 1(t4)                 # Load the second byte
    slli a0, a0, 8                # Shift it left by 8 bits
    or t6, t6, a0                 # Combine it with the first byte

    lbu a0, 2(t4)                 # Load the third byte
    slli a0, a0, 16               # Shift it left by 16 bits
    or t6, t6, a0                 # Combine it with the previous bytes

    lbu a0, 3(t4)                 # Load the fourth byte
    slli a0, a0, 24               # Shift it left by 24 bits
    or t6, t6, a0
    
    # Write the extracted bytes to the destination register
    write_to_register:
        # Extract the destination register from the instruction
        srli t2, t3, 7              
        andi t2, t2, 0x1F           # Mask to get the 5-bit rd field   t2 is the 

        # Calculate the address on the stack where the result will be stored
        slli t2, t2, 2              # Multiply the rd value by 4 (size of word) to get the correct offset
        #csrr s2, mscratch           # Read the stack pointer into s2
        add t2, t2, sp             # Add the offset to the stack pointer to get the correct address

        # Store the result at the calculated address
        sw t6, 0(t2)                # Store the word in t6 to the stack at the calculated address

        csrr t0, mepc               # Read the address of the instruction into t0
        addi t0, t0, 4              # Increment mepc to point to the next instruction
        csrw mepc, t0               # Write the incremented address back to mepc

    postamble:
    lw x1, 0(sp)   # Save ra
    lw x2, 4(sp)   # Save sp
    lw x3, 8(sp)   # Save gp
    lw x4, 16(sp)   # Save tp
    lw x5, 20(sp)   # Save t0
    lw x6, 24(sp)   # Save t1
    lw x7, 28(sp)   # Save t2
    lw x8, 32(sp)    # Save s0
    lw x9, 36(sp)    # Save s1
    lw x10, 40(sp)   # Save a0
    lw x11, 44(sp)   # Save a1
    lw x12, 48(sp)   # Save a2
    lw x13, 52(sp)   # Save a3
    lw x14, 56(sp)   # Save a4
    lw x15, 60(sp)   # Save a5
    lw x16, 64(sp)   # Save a6
    lw x17, 68(sp)   # Save a7
    lw x18, 72(sp)   # Save s2
    lw x19, 76(sp)   # Save s3
    lw x20, 80(sp)   # Save s4
    lw x21, 84(sp)   # Save s5
    lw x22, 88(sp)   # Save s6
    lw x23, 92(sp)   # Save s7
    lw x24, 96(sp)   # Save s8
    lw x25, 100(sp)   # Save s9
    lw x26, 104(sp)   # Save s10
    lw x27, 108(sp)   # Save s11
    lw x28, 112(sp)   # Save t3
    lw x29, 116(sp)   # Save t4
    lw x30, 120(sp)    # Save t5
    lw x31, 124(sp)    # Save t6
    addi sp, sp, 128
    csrrw sp, mscratch, sp
    # Adjust stack pointer
    mret
	


#  DO NOT MODIFY THE CODE BELOW THIS LINE
# This code is taken from the default VRV system code.  It prints out
# a message indicating the cause of an unhandled exception.  We are
# keeping this in this form to make it easier for you to debug.

# It is allowed to trash registers (unlike the normal trap handler)
# because it never returns	
terminate:
    csrr    t0, mcause      # Get mcause CSR
    li      t1, 0x80000000
    and     t1, t0, t1      # mcause & 0x80000000
    beqz    t1, ____not_interrupt   # mcause has bit 31 set for an interrupt

    # 2a. Interrupt
    la      a0, __m_int     # Interrupt header message
    xor     t0, t0, t1      # Isolate interrupt code
    la      t1, __ivec      # Interrupt vector
    j       ____print_trap_message

    # 2b. Exception
____not_interrupt:
    la      a0, __m_exc     # Exception header message
    la      t1, __evec      # Isolate exception code

    # 3. Print header message
____print_trap_message:
    li      a7, PRINT_STR
    ecall

    # 4. Print vector entry for this exception/interrupt
    slli    a0, t0, 2       # mcause * 4
    add     a0, t1, a0      # Index in vector
    lw      a0, (a0)        # Entry from vector
    ecall

    # 5. Print mcause
    la      a0, __m_mcause
    ecall
    csrr    a0, mcause
    li      a7, PRINT_HEX
    ecall

    # 6. Print mepc
    la      a0, __m_mepc
    li      a7, PRINT_STR
    ecall
    csrr    a0, mepc
    li      a7, PRINT_HEX
    ecall

    # 7. Print mtval
    la      a0, __m_mtval
    li      a7, PRINT_STR
    ecall
    csrr    a0, mtval
    li      a7, PRINT_HEX
    ecall
    li      a0, NEWLN_CHR
    li      a7, PRINT_CHR
    ecall

    # Exit with code -1
    li      a0, -1
    li      a7, EXIT
    ecall



## User boot code
    .text
__user_bootstrap:
    # exit(main())
    jal     main
    li      a7, EXIT
    ecall

# Useful utility function
kprintstr:
	li a7, PRINT_STR
	ecall
	ret

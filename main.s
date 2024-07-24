	# Constants for system calling, for the print functions
	# and the like 
	.equ PRINT_DEC 0
	.equ PRINT_STR 4
	.equ PRINT_HEX 1
	.equ READ_HEX 11
	.equ EXIT 20

	# Data section messages.
	.data
welcome:   .asciz "Welcome to Trap Handler Testing\n"
donestring: .asciz "Done with testing\n"
	## Code section
	.text
	.globl main

main:
	# Preamble for main:
	# s0 = argc
	# s1 = argv
	# s2 = loop index i
	# s3 = A callee saved temporary
	# that is used to cross some call boundaries
	addi sp sp -20
	sw ra 0(sp)
	sw s0 4(sp)
	sw s1 8(sp)
	sw s2 12(sp)
	sw s3 16(sp)

	mv s0 a0
	mv s1 a1
	
	# Print the welcome message
	la a0 welcome
	call printstr

	call traptest

	li a0 donestring
	call printstr
	# Return 0
	li a0 0
	lw ra 0(sp)
	lw s0 4(sp)
	lw s1 8(sp)
	lw s2 12(sp)
	lw s3 16(sp)
	addi sp sp 20
	ret

traptest:
	addi sp sp -12
	sw ra 0(sp)
	sw s0 4(sp)
	sw s1 8(sp)

	li a0 8
	call malloc
	mv s0 a0

	li a0 0x04030201
	li a1 0x08070605

	sw a0 0(s0)
	sw a1 4(s0)

	lw a0 2(s0)
	li a1 0x06050403
	call assert
	
	lw ra 0(sp)
	lw s0 4(sp)
	lw s1 8(sp)
	addi sp sp 12
	ret
	

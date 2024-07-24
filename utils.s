	# This file contains multiple utility functions:

	# In particular, it contains functions for printing
	# (printstr/printhex) a malloc implementation, strcmp, and
	# frathouse/campground functionality.

	# The malloc implementation is very naive but it includes some
        # significant checking: it records the size of each block
        # allocated, initializes all the data with garbage (as malloc
        # is defined as not returning zeroed memory), and it has a
        # final check function that makes sure that there were no
        # out-of-bound writes that occurred.

	# The campground/frathouse functionality is to enforce calling
	# conventions.  frathouse overwrites all caller-saved
	# registers (t0-t7, a1-a7) except for a0 and ra, and then
	# executes a return.  All the functions in this library
	# include frathouse functionality on return, to ensure that
	# whatever calls these functions has to follow the calling
	# convention.

	# campground is a similar operation.  It accepts function
	# arguments on a0-a6, and has a function to invoke passed in
	# on a7 (allowing it to work with any function that takes 7 or
	# fewer arguments).  It saves all the saved registers and puts
	# known values in the saved registers, invokes the function,
	# and then checks that all the saved registers and stack
	# pointer are properly maintained.

	
	# Constants for system calling, for the print functions
	# and the like 
	.equ PRINT_DEC 0
	.equ PRINT_STR 4
	.equ PRINT_HEX 1
	.equ READ_HEX 11
	.equ EXIT 20

	# We don't want the memory space to be too big, otherwise it
	# really slows down vrv.  We don't have a syscall in vrv to
	# gain a block of unallocated memory, so we just statically
	# grab it.
	
	.equ MEMCAPACITY 32768

	# A constant so that if you look at malloc's memory, it is
	# full of the string "Hash".
	.equ MALLOCCONST 0x68736148
	
	# Data section messages.
	.data
invalid:   .asciz "Invalid Hex"
mallocstring: .asciz "... Malloc starting\n"
mteststr: .asciz	" ... Returned\n"
teststr1: .asciz "aaaaaaa"
teststr2: .asciz "aaaaaab"
steststr: .asciz	" ... Returned for strcmp\n"

mallocfailed: .asciz "Malloc detected corrupted memory!\n"
trashed: .asciz "Campgound reports a trashed saved register!\n"

problemstring1: .asciz "assertion failed: "
problemstring2:  .asciz " (a0) != "
problemstring3:  .asciz " (a1)\n"
	
	# A big block of global stuff for malloc, we specify it as
	# word aligned, and prezeroed (but we will overwrite that
	# later on
	
	.align 4
mallocstart:	.zero 4 # An int to zero
mallocblock:	.zero MEMCAPACITY


	## Code section

	# These are the exported labels.
	
	.text
	.globl printstr
	.globl parsehex
	.globl printhex
	.globl malloc
	.globl malloctest
	.globl malloccheck
	.globl strcmp
	.globl strcmptest
	.globl frathouse
	.globl campground
	.globl assert

	# A test of the malloc function below.
	# This was developed incrementally with the malloc
	# function itself, and is included as a reference.
	
malloctest:
	addi sp sp -8
	sw ra 0(sp)
	sw s0 4(sp)		# Only use s0

	li a0 10		# malloc 10.  Make sure that
	jal malloc		# malloc startup only happens once
	jal printhex		# and that the result allocates 12
	la a0 mteststr
	jal printstr

	
	li a0 12		# Now allocate 12 and get the address
	jal malloc
	li t0 0xFFFFFFFF	# And write 0xFFFFFFFF into the last
	sw t0 8(a0)		# word of the allocated data
	jal printhex		# and print the address given
	la a0 mteststr
	jal printstr


	li a0 16		# Now allocate 16 and get the address.
	jal malloc
	mv s0 a0
	jal printhex
	la a0 mteststr
	jal printstr

	lw a0 0(s0)		
	jal printhex
	la a0 mteststr
	jal printstr

	lw a0 -4(s0)		# And that one-minus is not zero
	jal printhex
	la a0 mteststr
	jal printstr

	lw ra 0(sp)
	lw s0 4(sp)
	addi sp sp 8
	ret



	# A very, VERY simple malloc implementation.

	# This implementation, although naive, does include a lot of
	# testing.  Each allocated block includes both the size of the
	# block at location -8, and in front and back of each block is a known string
	# to check for buffer overflows.
	
malloc:
	addi sp sp -24
	sw ra 0(sp)
	sw s0 4(sp)
	sw s1 8(sp)
	sw s2 12(sp)
	sw s3 16(sp)
	sw s4 20(sp)

	mv s0 a0  			# s0 = argument
	
	la t0 mallocstart		# Load the global pointer for
					# the malloc's space
	lw t1 0(t0)
	bnez t1 malloc_init_done	# If it is non-zero we've already
					# been initialized


	# For initializing malloc, we first make our global pointer
	# mallocstart point to the start of the block of memory.
	
	la t1 mallocblock
	sw t1 0(t0)
	
	la a0 mallocblock
	li a1 MEMCAPACITY
	li a2 0
	li a3 MALLOCCONST

	# Set all the memory to the pattern "Hash".  This serves
	# multiple purposes: allowing one to easily see allocations in
	# vrv where they occur, check that functions calling malloc properly zero out memory,
	# and detect out of bounds writes to memory.
	j malloc_init_data_check
malloc_init_data:
	add a4 a2 a0
	sw a3 0(a4)
	addi a2 a2 4
malloc_init_data_check:
	bge a1 a2 malloc_init_data

	
malloc_init_done:	
	# First ensure that the argument is aligned, and if not add to it
	# so that it is.  
	andi t0 s0 0x3
	beqz t0 is_aligned
	
	# Immediates sign extend, so this is set all but the last 2
        # bits
	
	andi s0 s0 0xFFC  
	addi s0 s0 4
	
is_aligned:
	
	# Now a very simple allocator.  It allocates x + 12 bytes, at
	# the start it has the size, then untouched, then the return
	# block, and leaving a last 4 bytes untouched at the end.  and
	# then updates the pointer on where to get the next allocation
	# from.
	
	la t0 mallocstart
	lw a0 0(t0)
	add t1 a0 s0
	addi t1 t1 12
	sw t1 0(t0)
	sw s0 0(a0)
	addi a0 a0 8
malloc_ret:
	lw ra 0(sp)
	lw s0 4(sp)
	lw s1 8(sp)
	lw s2 12(sp)
	lw s3 16(sp)
	lw s4 20(sp)
	addi sp sp 24
	j frathouse
	ret


# A function to make sure that the memory is allocated right.
malloccheck:
	addi sp sp -4
	sw ra 0(sp)
	la t0 mallocblock
	li t1 MALLOCCONST

	# The loop is load the size information.  If it is the default
	# initialized pattern we are at the end.  Otherwise, make sure
	# that the word immediately after is untouched, increment the
	# index, and make sure the word before the new index location
	# is untouched.
	
malloccheckloop:
	lw t2 0(t0)
	beq t2 t1 mallocok
	lw t3 4(t0)
	bne t3 t1 mallocbad
	add t0 t0 t2
	addi t0 t0 12
	lw t3 -4(t0)
	bne t3 t1 mallocbad
	j malloccheckloop
mallocbad:
	# Print error message
	la a0 mallocfailed
	jal printstr
mallocok:
	lw ra 0(sp)
	addi sp sp 4
	ret
	
	# Function for parsing a hexidecimal string given as a string.
	# In C its declaration would be uint32_t parsehex(char * str)

	# We need this because although the simulator has
	# a built in "read number in hex", THAT is reading
	# from the console and we want to read from the command line.

	# This is not a leaf function becaues it will print an error
	# if the item is not well formed.
parsehex:
	addi sp sp -12
	sw ra 0(sp) # We need some saved variables
	sw s0 4(sp) # str
	sw s1 8(sp) # the return value
	mv s0 a0    # Save str in s0
	li s1 0     # Return value starts at 0
	li t1 '0'   # Temporary values for ASCII character
	li t2 '9'   # constants that are compared against.
	li t3 'A'
	li t4 'F'
	li t5 'a'
	li t6 'f'

	# This takes advantage that "0-9" < "A-F" < "a-f" so
	# we can add/subtract the values and compare on the
	# range

	# while (*str) != 0
parsehex_loop:       
	lbu t0 0(s0) 		     # t0 = *str
	beqz t0 parsehex_exit
	
	blt t0 t1 parsehex_error     # if(*str < '0') -> error
	bgt t0 t2 parsehex_not_digit # if(*str > '9') -> not digit
	sub t0 t0 t1                 # to = *str - '0'
	j parsehex_loop_end

parsehex_not_digit:
	blt t0 t3 parsehex_error     # if(*str < 'A') -> error
	bgt t0 t4 parsehex_lower     # if(*str > 'F') -> not upper
	sub t0 t0 t3                 # t0 = *str - 'A' + 10
	addi t0 t0 10
	j parsehex_loop_end

parsehex_lower:
	blt t0 t5 parsehex_error     # if(*str < 'a') -> error
	bgt t0 t6 parsehex_error     # if(*str > 'f') -> error
	sub t0 t0 t5                 # to = *str - 'a' + 10
	addi t0 t0 10

parsehex_loop_end:
	slli s1 s1 4                 # ret = ret << 4 | t0
	or s1 s1 t0
	addi s0 s0 1                 # str++
	j parsehex_loop

parsehex_error:
	la a0 invalid
	jal printstr
	li s0 0xFFFFFFFF
	j parsehex_exit
	
parsehex_exit:
	mv a0 s1                     # set return value and cleanup
	lw ra 0(sp)
	lw s0 4(sp)
	lw s1 8(sp)
	addi sp sp 12
	j frathouse
	ret

	# This is an example of using ecall to call
	# one of the built-in system routines
printhex:	
	li a7 PRINT_HEX
	ecall
	ret
	
printstr:
	li a7 PRINT_STR
	ecall
	ret

	# Simple strcmp, returns -1, 0, 1 depending
	# -1 if a < b
	# +1 i a > b
	# 0 if equal
strcmp: j strcmp_loop_body
strcmp_loop:
	addi a0 a0 1
	addi a1 a1 1
	
strcmp_loop_body:
	lbu t0 0(a0)
	lbu t1 0(a1)
	beq t0 t1 strcmp_is_equal
	blt t0 t1 a0_less
	li a0 1
	j frathouse
	ret
a0_less:
	li a0 -1
	j frathouse
	ret
strcmp_is_equal:
	bnez t0 strcmp_loop
	li a0 0
	j frathouse
	ret

strcmptest:
	addi sp sp -4
	sw ra 0(sp)

	la a0 teststr1
	la a1 teststr2
	jal strcmp
	jal printhex
	la  a0 steststr
	jal printstr

	la a1 teststr1
	la a0 teststr2
	jal strcmp
	jal printhex
	la  a0 steststr
	jal printstr

	la a0 teststr1
	la a1 teststr1
	jal strcmp
	jal printhex
	la  a0 steststr
	jal printstr

	
	lw ra 0(sp)
	addi sp sp 4
	ret

	# The frathouse operation: Trashes
	# all caller saved registers EXCEPT a0 and ra, and
	# returns to ra.  j frathouse can replace the ret in
	# library functions to make sure things are correct with
	# respect to the caller saved registers.
frathouse:
	li t0 0x1337d00d
	li t1 0x1337d00d
	li t2 0x1337d00d
	li t3 0x1337d00d
	li t4 0x1337d00d
	li t5 0x1337d00d
	li t6 0x1337d00d
	li a1 0x1337d00d
	li a2 0x1337d00d
	li a3 0x1337d00d
	li a4 0x1337d00d
	li a5 0x1337d00d
	li a6 0x1337d00d
	li a7 0x1337d00d
	ret

	# This function sets up the "Campground" of callee saved
	# registers, and then calls the value at a7 (allowing this to
	# be used for testing any function that calls less than 8
	# arguments) It saves the stack pointer in s0, and all the
	# other saved registers are initialized to known test values.
campground:
	addi sp sp -52
	sw ra 0(sp)
	sw s0 4(sp)
	sw s1 8(sp)
	sw s2 12(sp)
	sw s3 16(sp)
	sw s4 20(sp)
	sw s5 24(sp)
	sw s6 28(sp)
	sw s7 32(sp)
	sw s8 36(sp)
	sw s9 40(sp)
	sw s10 44(sp)
	sw s11 48(sp)

	li s0 0x01020304
	li s1 0x01020304
	li s2 0x01020304
	li s3 0x01020304
	li s4 0x01020304
	li s5 0x01020304
	li s6 0x01020304
	li s7 0x01020304
	li s8 0x01020304
	li s9 0x01020304
	li s10 0x01020304
	mv s11 sp

	jalr ra 0(a7)

	li t0 0x01020304
	bne t0 s0 dirtycamp
	bne t0 s1 dirtycamp
	bne t0 s2 dirtycamp
	bne t0 s3 dirtycamp
	bne t0 s4 dirtycamp
	bne t0 s5 dirtycamp
	bne t0 s6 dirtycamp
	bne t0 s7 dirtycamp
	bne t0 s8 dirtycamp
	bne t0 s9 dirtycamp
	bne t0 s10 dirtycamp
	bne sp s11 dirtycamp
	j campground_return
dirtycamp:
	la a0 trashed
	jal printstr
	
	
campground_return:	
	lw ra 0(sp)
	lw s0 4(sp)
	lw s1 8(sp)
	lw s2 12(sp)
	lw s3 16(sp)
	lw s4 20(sp)
	lw s5 24(sp)
	lw s6 28(sp)
	lw s7 32(sp)
	lw s8 36(sp)
	lw s9 40(sp)
	lw s10 44(sp)
	lw s11 48(sp)
	addi sp sp 52		
	ret


assert:
        bne a0 a1 problem
        ret
problem:
        addi sp sp -12
        sw ra 0(sp)
        sw s0 4(sp)
        sw s1 8(sp)
        mv s0 a0
        mv s1 a1
        li a0 problemstring1
        call printstr
        mv a0 s0
        call printhex
        li a0 problemstring2
        call printstr
        mv a0 s1
        call printhex
        li a0 problemstring3
        call printstr
        mv a0 s0
        mv a1 s1
        lw ra 0(sp)
        lw s0 4(sp)
        lw s1 8(sp)
        addi sp sp 12
        ret

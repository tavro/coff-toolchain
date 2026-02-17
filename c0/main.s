#
# source code written by tyson horvath (tavro)
# for the c0 programming language (RISC-V implementation)
#

.include "constants.s"
.include "token.s"

.section .text.init

.global _start
_start:
    # set up stack pointer
    # QEMU virt machine loads at 0x80000000
    # we will put stack at end of first 64MB
    li      sp, 0x84000000

    call    _uart_init

    la      a0, _start_message
    call    _put_string

    call    _lexer

    la      a0, _lexer_done_message
    call    _put_string

    call    _program

    li      a0, 0
    call    _exit

.section .rodata
_start_message:         .string "[c0 compiler starting]\n"
_lexer_done_message:    .string "[lexer done]\n"

.text
    # should never reach here
1:
    wfi
    j       1b

.text

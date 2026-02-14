#
# source code written by tyson horvath (tavro)
# for the c0 programming language (RISC-V implementation)
#
# this provides _start, UART I/O and calls main
#

.equ UART_BASE,     0x10000000
.equ UART_THR,      0x00
.equ UART_LSR,      0x05
.equ UART_LSR_THRE, 0x20

.section .text.init

.global _start
_start:
    li      sp, 0x84000000

    li      t0, UART_BASE
    li      t1, 0x03
    sb      t1, 0x03(t0)
    li      t1, 0xC1
    sb      t1, 0x02(t0)

    call    main

    mv      s0, a0

    la      a0, result_message
    call    _put_string

    mv      a0, s0
    call    _put_number

    li      a0, ']'
    call    _uart_put_character
    li      a0, '\n'
    call    _uart_put_character
1:
    wfi
    j       1b

# void _uart_put_character(int c)
_uart_put_character:
    li      t0, UART_BASE
1:
    lbu     t1, UART_LSR(t0)
    andi    t1, t1, UART_LSR_THRE
    beqz    t1, 1b
    sb      a0, UART_THR(t0)
    ret

# void _put_string(const char *s)
_put_string:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    mv      s0, a0
1:
    lbu     a0, 0(s0)
    beqz    a0, 2f
    call    _uart_put_character
    addi    s0, s0, 1
    j       1b
2:
    lw      ra, 12(sp)
    lw      s0, 8(sp)
    addi    sp, sp, 16
    ret

# void _put_number(int x)
_put_number:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    mv      s0, a0
    li      s1, 0

    # handle negative
    bgez    s0, 1f
    li      a0, '-'
    call    _uart_put_character
    neg     s0, s0
1:
    # handle zero
    bnez    s0, 2f
    li      a0, '0'
    call    _uart_put_character
    j       4f

2:
    li      t0, 10
3:
    beqz    s0, 3f
    rem     t1, s0, t0
    addi    t2, sp, 0
    add     t2, t2, s1
    sb      t1, 0(t2)
    div     s0, s0, t0
    addi    s1, s1, 1
    j       3b
3:
    # print digits in reverse
    addi    s1, s1, -1
    addi    t2, sp, 0
    add     t2, t2, s1
    lbu     a0, 0(t2)
    addi    a0, a0, '0'
    call    _uart_put_character
    bnez    s1, 3b

4:
    lw      ra, 28(sp)
    lw      s0, 24(sp)
    lw      s1, 20(sp)
    addi    sp, sp, 32
    ret

.section .rodata
result_message: .string "[result: "

.text

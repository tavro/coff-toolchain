#
# source code written by tyson horvath (tavro)
# for the c0 programming language (RISC-V implementation)
#
# this is a runtime library for UART I/O and utility functions
#

.include "constants.s"

.equ READ_BUFFER_SIZE,  512
.equ WRITE_BUFFER_SIZE, 512

.data

.comm read_buffer, READ_BUFFER_SIZE, 1
read_buffer_beging: .word 0
read_buffer_end:    .word 0

.comm write_buffer, WRITE_BUFFER_SIZE, 1
write_buffer_index: .word 0

eof_flag: .word 0

got_data_flag: .word 0

.text

#########################
# UART driver functions #
#########################

# void _uart_init(void)
.global _uart_init
_uart_init:
    li      t0, UART_BASE
    sb      zero, UART_IER(t0)

    # enable FIFO, clear TX only, 14-byte threshold
    # FCR bits:
    # [7:6]=trigger level (11=14), [2]=clear TX, [1]=clear RX, [0]=enable
    # 0xC5 = 11000101 = enable FIFO + clear TX + 14-byte trigger
    li      t1, 0xC5
    sb      t1, UART_FCR(t0)

    # set baud rate (not really needed for QEMU, but good practice)
    # enable DLAB
    li      t1, 0x80
    sb      t1, UART_LCR(t0)

    # set divisor low byte
    li      t1, 0x03
    sb      t1, UART_THR(t0)    # DLL

    # set divisor high byte
    sb      zero, UART_IER(t0)  # DLM

    # 8 bits, no parity, one stop bit, disable DLAB
    li      t1, 0x03
    sb      t1, UART_LCR(t0)

    # enable FIFO (do not clear RX), 14-byte threshold
    li      t1, 0xC1
    sb      t1, UART_FCR(t0)

    # enable received data available interrupt
    li      t1, 0x01
    sb      t1, UART_IER(t0)

    ret

# int _uart_get_character_nonblock(void)
# non-blocking read from UART. returns -1 if no data available.
.global _uart_get_character_nonblock
_uart_get_character_nonblock:
    li      t0, UART_BASE
    lbu     t1, UART_LSR(t0)
    andi    t1, t1, UART_LSR_DR         # check DR bit
    beqz    t1, 1f                      # no data available

    lbu     a0, UART_RBR(t0)            # read data
    ret
1:
    li      a0, -1
    ret

# void _uart_put_character(int c)
# blocking write to UART
_uart_put_character:
    li      t0, UART_BASE
1:
    lbu     t1, UART_LSR(t0)
    andi    t1, t1, UART_LSR_THRE       # check THR empty bit
    beqz    t1, 1b                      # wait until ready

    sb      a0, UART_THR(t0)            # write character
    ret

##########################
# buffered I/O functions #
##########################

# void _flush(void)
# flush write buffer to UART
.global _flush
_flush:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    sw      s1, 4(sp)
    addi    s0, sp, 16

    la      t0, write_buffer_index
    lw      t1, 0(t0)
    beqz    t1, 2f      # buffer is empty

    # output all characters in buffer
    la      s1, write_buffer
    li      t2, 0        # counter
1:
    bge     t2, t1, 2f
    add     t3, s1, t2
    lbu     a0, 0(t3)
    sw      t1, 0(sp)   # save t1
    sw      t2, -4(sp)  # save t2
    call    _uart_put_character
    lw      t1, 0(sp)
    lw      t2, -4(sp)
    addi    t2, t2, 1
    j       1b
2:
    # reset buffer index
    la      t0, write_buffer_index
    sw      zero, 0(t0)

    lw      ra, 12(sp)
    lw      s0, 8(sp)
    lw      s1, 4(sp)
    addi    sp, sp, 16
    ret

# int _get_character(void)
# read one character (blocking)
.global _get_character
_get_character:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    addi    s0, sp, 16

    # check EOF flag
    la      t0, eof_flag
    lw      t1, 0(t0)
    bnez    t1, _get_character_eof

    # check if data in buffer
    la      t0, read_buffer_begin
    lw      t1, 0(t0)   # t1 = read_buffer_begin
    la      t2, read_buffer_end
    lw      t3, 0(t2)   # t3 = read_buffer_end
    bne     t1, t3, _get_character_from_buffer

    # buffer empty, try to read from UART
    # reset buffer pointers
    la      t0, read_buffer_begin
    sw      zero, 0(t0)
    la      t2, read_buffer_end
    sw      zero, 0(t2)

    # try to read characters into buffer
    la      s0, read_buffer
    li      t4, 0       # bytes read
_get_character_fill:
    call    _uart_get_character_nonblock
    li      t0, -1
    beq     a0, t0, _get_character_fill_done

    # check for EOF
    li      t0, 0x04
    beq     a0, t0, _get_character_set_eof

    # mark that we have received data
    la      t1, got_data_flag
    li      t2, 1
    sw      t2, 0(t1)

    # store character in buffer
    la      t1, read_buffer_end
    lw      t4, 0(t1)
    la      t2, read_buffer
    add     t2, t2, t4
    sb      a0, 0(t2)
    addi    t4, t4, 1
    sw      t4, 0(t1)

    # if buffer full or got new line, stop filling
    li      t0, READ_BUFFER_SIZE
    bge     t4, t0, _get_character_fill_done
    li      t0, '\n'
    beq     a0, t0, _get_character_fill_done
    j       _get_character_fill

_get_character_set_eof:
    la      t0, eof_flag
    li      t1, 1
    sw      t1, 0(t0)
    # fall through to check if we have buffered data

_get_character_fill_done:
    # check if we got any data
    la      t0, read_buffer_end
    lw      t1, 0(t0)
    beqz    t1, _get_character_wait # no data yet, wait more

    # mark that we have received data
    la      t0, got_data_flag
    li      t2, 1
    sw      t2, 0(t0)

    li      t1, 0 # read_buffer_begin = 0

_get_character_from_buffer:
    la      t4, read_buffer
    add     t4, t4, t1  # read_buffer + read_buffer_begin
    lbu     a0, 0(t4)   # load byte

    addi    t1, t1, 1   # read_buffer_begin++
    la      t0, read_buffer_begin
    sw      t1, 0(t0)

    lw      ra, 12(sp)
    lw      s0, 8(sp)
    addi    sp, sp, 16
    ret

_get_character_wait:
    # check EOF flag
    la      t0, eof_flag
    lw      t1, 0(t0)
    bnez    t1, _get_character_eof

    # check if we have already received data
    la      t0, got_data_flag
    lw      t1, 0(t0)
    bnez    t1, _get_character_wait_short # already got data, use short timeout

    # first time waiting -> use very long timeout (QEMU has latency)
    # this handles the delay before piped input arrives
    li      t5, 50000000 # ~5+ seconds of polling at QEMU speed
    j       _get_character_wait_loop

_get_character_wait_short:
    # already received data, use short timeout for EOF detection
    li      t5, 100000 # short timeout for inter-character gaps

_get_character_wait_loop:
    # busy wait for UART data
    call    _uart_get_character_nonblock
    li      t0, -1
    bne     a0, t0, _get_character_wait_got_character

    # no data -> decrement timeout
    addi    t5, t5, -1
    bnez    t5, _get_character_wait_loop

    # timeout expired -> check if we ever got data
    la      t0, got_data_flag
    lw      t1, 0(t0)
    bnez    t1, _get_character_set_eof2 # we got data before, this is EOF

    # never got data and timeout expired -> still EOF (nothing to read)
    j       _get_character_set_eof2

_get_character_wait_got_character:
    # mark that we have received data
    la      t1, got_data_flag
    li      t2, 1
    sw      t2, 0(t1)

    # check for EOF
    li      t0, 0x04
    beq     a0, t0, _get_character_set_eof2

    # got a character, return it
    lw      ra, 12(sp)
    lw      s0, 8(sp)
    addi    sp, sp, 16
    ret

_get_character_set_eof2:
    la      t0, eof_flag
    li      t1, 1
    sw      t1, 0(t0)

_get_character_eof:
    li      a0, EOF
    lw      ra, 12(sp)
    lw      s0, 8(sp)
    addi    sp, sp, 16
    ret

# int _next_character(void)
# peek next character without consuming (blocking)
.global _next_character
_next_character:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    addi    s0, sp, 16

    # check EOF flag
    la      t0, eof_flag
    lw      t1, 0(t0)
    bnez    t1, _next_character_eof

    # check if data in buffer
    la      t0, read_buffer_begin
    lw      t1, 0(t0)           # t1 = read_buffer_begin
    la      t2, read_buffer_end
    lw      t3, 0(t2)           # t3 = read_buffer_end
    bne     t1, t3, _next_character_from_buffer

    # buffer empty, need to fill
    la      t0, read_buffer_begin
    sw      zero, 0(t0)
    la      t2, read_buffer_end
    sw      zero, 0(t2)

_next_character_wait:
    # check if we have already received data
    la      t0, got_data_flag
    lw      t1, 0(t0)
    bnez    t1, _next_character_wait_short # already got data, short timeout

    # first time waiting -> use very long timeout (QEMU has latency)
    li      t5, 50000000 # ~5+ seconds of polling at QEMU speed
    j       _next_character_wait_loop

_next_character_wait_short:
    # already received data, use short timeout for EOF detection
    li      t5, 100000 # short timeout for inter-character gaps

_next_character_wait_loop:
    # wait for UART data
    call    _uart_get_character_nonblock
    li      t0, -1
    bne     a0, t0, _next_character_got_character

    # no data -> decrement timeout
    addi    t5, t5, -1
    bnez    t5, _next_character_wait_loop

    # timeout -> check if we ever got data
    la      t0, got_data_flag
    lw      t1, 0(t0)
    bnez    t1, _next_character_set_eof # got data before, this is EOF

    # never got data and timeout expired -> still EOF
    j       _next_character_set_eof

_next_character_got_character:
    # check for EOF
    li      t0, 0x04
    beq     a0, t0, _next_character_set_eof

    # mark that we have received data
    la      t1, got_data_flag
    li      t2, 1
    sw      t2, 0(t1)

    # store character in buffer
    la      t1, read_buffer_end
    lw      t4, 0(t1)
    la      t2, read_buffer
    add     t2, t2, t4
    sb      a0, 0(t2)
    addi    t4, t4, 1
    sw      t4, 0(t1)
    li      t1, 0

_next_character_from_buffer:
    # peek character from buffer (do not increment begin)
    la      t4, read_buffer
    add     t4, t4, t1
    lbu     a0, 0(t4)

    lw      ra, 12(sp)
    lw      s0, 8(sp)
    addi    sp, sp, 16
    ret

_next_character_set_eof:
    la      t0, eof_flag
    li      t1, 1
    sw      t1, 0(t0)

_next_character_eof:
    li      a0, EOF
    lw      ra, 12(sp)
    lw      s0, 8(sp)
    addi    sp, sp, 16
    ret

# int _put_character(int c)
# write one character to output buffer
.global _put_character
_put_character:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    sw      a0, 4(sp)   # save c
    addi    s0, sp, 16

    la      t0, write_buffer_index
    lw      t1, 0(t0)   # t1 = write_buffer_index
    la      t2, write_buffer
    add     t2, t2, t1  # write_buffer + write_buffer_index
    sb      a0, 0(t2)   # write_buffer[write_buffer_index] = c

    addi    t1, t1, 1
    sw      t1, 0(t0)   # write_buffer_index++

    li      t3, WRITE_BUFFER_SIZE
    beq     t1, t3, 1f  # buffer full, flush

    li      t3, '\n'
    lw      t4, 4(sp)
    beq     t4, t3, 1f  # new line, flush

    j       2f
1:
    call    _flush
2:
    lw      ra, 12(sp)
    lw      s0, 8(sp)
    addi    sp, sp, 16
    ret

# void _put_string(const char *s1)
# write string to output
.global _put_string
_put_string:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    addi    s0, sp, 32

    mv      s1, a0
1:
    lbu     t0, 0(s1)   # load byte
    beqz    t0, 2f      # end of string

    mv      a0, t0
    call    _put_character

    addi    s1, s1, 1
    j       1b
2:
    lw      ra, 28(sp)
    lw      s0, 24(sp)
    lw      s1, 20(sp)
    addi    sp, sp, 32
    ret

.comm put_number_digits, 12, 1

# void _put_number(int s1)
# write decimal number to output
.global _put_number
_put_number:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)
    addi    s0, sp, 32

    mv      s1, a0
    li      s2, 0       # s2 = digit count

    # handle negative numbers
    bgez    s1, 1f
    li      a0, '-'
    call    _put_character
    neg     s1, s1
1:
    la      t0, put_number_digits
2:
    li      t1, 10
    rem     t2, s1, t1  # t2 = x % 10
    div     s1, s1, t1  # x = x / 10

    add     t3, t0, s2
    sb      t2, 0(t3)   # put_number_digits[count] = digit
    addi    s2, s2, 1

    bnez    s1, 2b
3:
    addi    s2, s2, -1
    la      t0, put_number_digits
    add     t0, t0, s2
    lbu     a0, 0(t0)
    addi    a0, a0, '0' # convert to ASCII
    call    _put_character

    bnez    s2, 3b

    lw      ra, 28(sp)
    lw      s0, 24(sp)
    lw      s1, 20(sp)
    lw      s2, 16(sp)
    addi    sp, sp, 32
    ret

############################
# string utility functions #
############################

# int _str_length(const char *t0)
.global _string_length
_string_length:
    li      a1, 0
    mv      t0, a0
1:
    lbu     t1, 0(t0)
    beqz    t1, 2f
    addi    t0, t0, 1
    addi    a1, a1, 1
    j       1b
2:
    mv      a0, a1
    ret

# void _string_copy(char *a0, const char *a1)
.global _string_copy
_string_copy:
1:
    lbu     t0, 0(a1)
    sb      t0, 0(a0)
    beqz    t0, 2f
    addi    a0, a0, 1
    addi    a1, a1, 1
    j       1b
2:
    ret

# int _string_compare(const char *a0, const char *a2)
# returns 1 if equal, 0 if not equal
.global _string_compare
_string_compare:
1:
    lbu     t0, 0(a0)
    lbu     t1, 0(a1)
    bne     t0, t1, 2f
    beqz    t0, 3f
    addi    a0, a0, 1
    addi    a1, a1, 1
    j       1b
2:
    li      a0, 0
    ret
3:
    li      a0, 1
    ret

########
# exit #
########

# void _exit(int status)
.global _exit
_exit:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      a0, 8(sp)

    call    _flush

    la      a0, exit_message
    call    _put_string
    lw      a0, 8(sp)
    call    _put_number
    li      a0, '\n'
    call    _put_character
    call    _flush
1:
    wfi
    j       1b

.section .rodata
exit_message: .string "\n[Exit with code: "

.text

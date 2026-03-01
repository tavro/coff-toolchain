#
# source code written by tyson horvath (tavro)
# for the c0 programming language (RISC-V implementation)
#
# this is a parser and code emitter
#

.include "constants.s"
.include "token.s"

.data

.equ STRING_BUFFER_LENGTH, 32768
.comm string_buffer, STRING_BUFFER_LENGTH, 1
string_offset:  .word 0
string_buffer_length: .word 0

.section .rodata
string_literals_text: .string "_string_literals"
string_overflow_message:  .string "ERROR: too many string literals\n"
.text

###########################
# string literal handling #
###########################

# calculate string length with escapes
_string_length_with_escape:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)

    mv      s0, a0      # s0 = string pointer
    li      a0, 0       # length = 0
1:
    lbu     t0, 0(s0)
    beqz    t0, 2f

    li      t1, '\\'
    beq     t0, t1, 3f

    addi    s0, s0, 1
    addi    a0, a0, 1
    j       1b
3:
    addi    a0, a0, 1   # count the escaped char
    addi    s0, s0, 2   # skip both \ and escaped char
    j       1b
2:
    lw      ra, 12(sp)
    lw      s0, 8(sp)
    addi    sp, sp, 16
    ret

# push a string literal to buffer
_push_string:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)
    mv      s0, a0      # s0 = string pointer

    # update string_offset by length with escapes
    mv      a0, s0
    call    _string_length_with_escape
    addi    a0, a0, -1          # skip opening quote
    la      t0, string_offset
    lw      t1, 0(t0)
    add     t1, t1, a0
    sw      t1, 0(t0)

    # get string length without escapes
    mv      a0, s0
    call    _string_length
    addi    a0, a0, -1          # skip opening quote

    # check buffer space
    la      t0, string_buffer_length
    lw      t1, 0(t0)
    add     t2, t1, a0
    li      t3, STRING_BUFFER_LENGTH
    bgt     t2, t3, _push_string_overflow

    # copy string to buffer (skip first quote)
    la      t0, string_buffer
    add     s1, t0, t1          # dst = string_buffer + string_buffer_length
    addi    s2, s0, 1           # src = string + 1 (skip opening quote)
1:
    lbu     t0, 0(s2)
    sb      t0, 0(s1)
    beqz    t0, 2f
    addi    s1, s1, 1
    addi    s2, s2, 1
    j       1b
2:
    # null-terminate (overwrite closing quote)
    la      t0, string_buffer_length
    lw      t1, 0(t0)
    add     t1, t1, a0
    sw      t1, 0(t0)

    la      t0, string_buffer
    add     t0, t0, t1
    addi    t0, t0, -1
    sb      zero, 0(t0)         # overwrite closing quote with null

    lw      ra, 28(sp)
    lw      s0, 24(sp)
    lw      s1, 20(sp)
    lw      s2, 16(sp)
    addi    sp, sp, 32
    ret

_push_string_overflow:
    call    _flush
    la      a0, string_overflow_message
    call    _put_string
    call    _flush
    li      a0, 1
    call    _exit

# output string literal address
_put_string_address:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    la      a0, string_literals_text
    call    _put_string
    li      a0, '+'
    call    _put_character
    la      t0, string_offset
    lw      a0, 0(t0)
    call    _put_number

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# generate string literals section
_generate_string_literals:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)

    la      t0, string_buffer_length
    lw      t1, 0(t0)
    beqz    t1, 4f              # no strings to emit

    call    _enter_rodata_area

    la      a0, string_literals_text
    call    _put_string
    li      a0, ':'
    call    _put_character
    call    _new_line

    # emit strings
    la      s0, string_buffer
    li      s1, 0               # counter
    la      t0, string_buffer_length
    lw      s2, 0(t0)           # total length

    call    _dot_string
    li      a0, '"'
    call    _put_character

1:
    bge     s1, s2, 2f

    add     t0, s0, s1
    lbu     a0, 0(t0)

    beqz    a0, 3f              # null terminator - start new string

    call    _put_character
    addi    s1, s1, 1
    j       1b

3:
    # check if more strings follow
    addi    s1, s1, 1
    bge     s1, s2, 2f

    li      a0, '"'
    call    _put_character
    call    _new_line
    call    _dot_string
    li      a0, '"'
    call    _put_character
    j       1b

2:
    li      a0, '"'
    call    _put_character
    call    _new_line

4:
    lw      ra, 28(sp)
    lw      s0, 24(sp)
    lw      s1, 20(sp)
    lw      s2, 16(sp)
    addi    sp, sp, 32
    ret

######################
# main program entry #
######################

.global _program
_program:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _enter_text_area

    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, T_END
    beq     t1, t2, 1f

_program_loop:
    call    _external_item
    call    _lexer

    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, T_END
    beq     t1, t2, 1f

    # allow ; as separator (optional)
    li      t2, ';'
    bne     t1, t2, 3f
    # skip the semicolon
    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, T_END
    beq     t1, t2, 1f
    j       _program_loop

3:
    # not a semicolon. check if it could start a new item
    # valid starters: identifier, keyword, variable, parameter, deref, etc.
    # if it is a valid token, continue the loop without requiring ;
    li      t2, T_IDENTIFIER
    beq     t1, t2, _program_loop
    li      t2, T_MACRO
    beq     t1, t2, _program_loop
    li      t2, T_VARIABLE
    beq     t1, t2, _program_loop
    li      t2, T_PARAMETER
    beq     t1, t2, _program_loop
    li      t2, '*'
    beq     t1, t2, _program_loop
    li      t2, T_IF
    beq     t1, t2, _program_loop
    li      t2, T_WHILE
    beq     t1, t2, _program_loop
    li      t2, T_GOTO
    beq     t1, t2, _program_loop
    li      t2, T_LABEL
    beq     t1, t2, _program_loop
    li      t2, T_RETURN
    beq     t1, t2, _program_loop
    li      t2, T_EXPORT
    beq     t1, t2, _program_loop
    li      t2, T_SYSTEM_CALL
    beq     t1, t2, _program_loop
    li      t2, T_ALLOCATE
    beq     t1, t2, _program_loop
    li      t2, T_WRITE
    beq     t1, t2, _program_loop
    li      t2, T_INCLUDE
    beq     t1, t2, _program_loop
    # unknown token, syntax error
    call    _syntax_error

1:
    call    _generate_string_literals

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_external_item:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    call    _item
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

############################
# item (statement) parsing #
############################

.global _item
_item:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    la      t0, token_tag
    lw      t1, 0(t0)

    li      t2, T_GOTO
    beq     t1, t2, _item_goto

    li      t2, T_LABEL
    beq     t1, t2, _item_label

    li      t2, T_RETURN
    beq     t1, t2, _item_return

    li      t2, T_SYSTEM_CALL
    beq     t1, t2, _item_syscall

    li      t2, T_EXPORT
    beq     t1, t2, _item_export

    li      t2, T_IF
    beq     t1, t2, _item_if

    li      t2, T_ALLOCATE
    beq     t1, t2, _item_allocate

    li      t2, T_WHILE
    beq     t1, t2, _item_while

    li      t2, T_WRITE
    beq     t1, t2, _item_write

    li      t2, T_INCLUDE
    beq     t1, t2, _item_include

    # default: toplevel expression
    call    _top_level_expression

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# goto expression
_item_goto:
    call    _lexer
    call    _or_expression

    # emit: jr a0
    call    _jr
    call    _a0
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# label identifier
_item_label:
    call    _lexer
    call    _identifier

    la      a0, token_text
    call    _put_string
    li      a0, ':'
    call    _put_character
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# return [expr]
_item_return:
    call    _lexer

    la      t0, token_tag
    lw      t1, 0(t0)

    li      t2, ';'
    beq     t1, t2, _item_return_void
    li      t2, '}'
    beq     t1, t2, _item_return_void

    call    _or_expression
    call    _end_frame

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_item_return_void:
    call    _lexer_unput
    call    _end_frame

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# syscall(args...)
_item_syscall:
    call    _syscall

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# export identifier
_item_export:
    call    _dot_global
    call    _lexer

    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, '('
    beq     t1, t2, _item_export_list

    call    _identifier
    la      a0, token_text
    call    _put_string
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_item_export_list:
    call    _identifier_list

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# if (cond) block [else block]
_item_if:
    # first, restore ra from _item's frame and clean it up
    lw      ra, 12(sp)
    addi    sp, sp, 16
    # now create our own frame
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)

    call    _new_label_id
    mv      s0, a0              # s0 = else/end label

    call    _lexer
    li      a0, '('
    call    _symbol

    call    _lexer
    call    _or_expression

    call    _lexer
    li      a0, ')'
    call    _symbol

    # emit: beqz a0, label
    call    _beqz
    call    _a0
    call    _comma
    mv      a0, s0
    call    _label
    call    _new_line

    call    _lexer
    call    _block

    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, T_ELSE
    bne     t1, t2, _item_if_end

    # has else clause
    call    _new_label_id
    mv      s1, a0              # s1 = end label

    # emit: j end_label
    call    _j
    mv      a0, s1
    call    _label
    call    _new_line

    # emit else label
    mv      a0, s0
    call    _label_definition
    call    _new_line

    call    _lexer
    call    _block

    # emit end label
    mv      a0, s1
    call    _label_definition
    call    _new_line

    j       _item_if_done

_item_if_end:
    call    _lexer_unput

    # emit end label
    mv      a0, s0
    call    _label_definition
    call    _new_line

_item_if_done:
    lw      ra, 28(sp)
    lw      s0, 24(sp)
    lw      s1, 20(sp)
    addi    sp, sp, 32
    ret

# allocate expression
_item_allocate:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _lexer
    call    _simple_item

    # emit: slli a0, a0, 2 (multiply by 4)
    la      a0, slli_text
    call    _put_string
    call    _a0
    call    _comma
    call    _a0
    call    _comma
    li      a0, 2
    call    _put_number
    call    _new_line

    # emit: sub sp, sp, a0
    call    _sub
    call    _sp
    call    _comma
    call    _sp
    call    _comma
    call    _a0
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

.section .rodata
slli_text: .string "\tslli "
.text

# while (cond) block
_item_while:
    # first, restore ra from _item's frame and clean it up
    lw      ra, 12(sp)
    addi    sp, sp, 16
    # now create our own frame
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)

    call    _new_label_id
    mv      s0, a0              # s0 = loop label
    call    _new_label_id
    mv      s1, a0              # s1 = end label

    # emit loop label
    mv      a0, s0
    call    _label_definition
    call    _new_line

    call    _lexer
    li      a0, '('
    call    _symbol

    call    _lexer
    call    _or_expression

    call    _lexer
    li      a0, ')'
    call    _symbol

    # emit: beqz a0, end_label
    call    _beqz
    call    _a0
    call    _comma
    mv      a0, s1
    call    _label
    call    _new_line

    call    _lexer
    call    _block

    # emit: j loop_label
    call    _j
    mv      a0, s0
    call    _label
    call    _new_line

    # emit end label
    mv      a0, s1
    call    _label_definition
    call    _new_line

    lw      ra, 28(sp)
    lw      s0, 24(sp)
    lw      s1, 20(sp)
    addi    sp, sp, 32
    ret

# write(arr, idx, val), write character
_item_write:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _lexer
    li      a0, '('
    call    _symbol

    call    _lexer
    call    _or_expression
    call    _push_a0

    call    _lexer
    li      a0, ','
    call    _symbol

    call    _lexer
    call    _or_expression
    call    _pop_t0

    # emit: add a0, t0, a0
    call    _add
    call    _a0
    call    _comma
    call    _t0
    call    _comma
    call    _a0
    call    _new_line

    call    _push_a0

    call    _lexer
    li      a0, ','
    call    _symbol

    call    _lexer
    call    _or_expression
    call    _pop_t0

    # emit: sb a0, 0(t0)
    call    _sb
    call    _a0
    call    _comma
    li      a0, '0'
    call    _put_character
    li      a0, '('
    call    _put_character
    call    _t0
    li      a0, ')'
    call    _put_character
    call    _new_line

    call    _lexer
    li      a0, ')'
    call    _symbol

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# include identifier
_item_include:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, '('
    beq     t1, t2, _item_include_list

    call    _identifier
    call    _dot_include
    la      a0, token_text
    call    _put_file
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_item_include_list:
    call    _file_list

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

####################
# helper functions #
####################

# parse identifier list: (id1, id2, ...)
_identifier_list:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _lexer
1:
    call    _identifier
    la      a0, token_text
    call    _put_string

    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, ','
    bne     t1, t2, 2f

    li      a0, ','
    call    _put_character
    call    _lexer
    j       1b

2:
    li      a0, ')'
    call    _symbol
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# parse file list: (file1, file2, ...)
_file_list:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _lexer
1:
    call    _identifier
    call    _dot_include
    la      a0, token_text
    call    _put_file
    call    _new_line

    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, ','
    bne     t1, t2, 2f

    call    _lexer
    j       1b

2:
    li      a0, ')'
    call    _symbol

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# output filename: "name.s"
_put_file:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      a0, 8(sp)

    li      a0, '"'
    call    _put_character
    lw      a0, 8(sp)
    call    _put_string
    li      a0, '.'
    call    _put_character
    li      a0, 's'
    call    _put_character
    li      a0, '"'
    call    _put_character

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# syscall(num, args...)
_syscall:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)

    call    _lexer
    call    _args
    mv      s0, a0      # s0 = number of arguments

    # pop arguments into a7, a0, a1, ... (syscall number in a7, args in a0-a5)
    # arguments are pushed in order, so we pop in reverse

    li      t0, 7
    blt     s0, t0, 1f
    call    _pop_to_a5
1:
    li      t0, 6
    blt     s0, t0, 2f
    call    _pop_to_a4
2:
    li      t0, 5
    blt     s0, t0, 3f
    call    _pop_to_a3
3:
    li      t0, 4
    blt     s0, t0, 4f
    call    _pop_to_a2
4:
    li      t0, 3
    blt     s0, t0, 5f
    call    _pop_to_a1
5:
    li      t0, 2
    blt     s0, t0, 6f
    call    _pop_to_a0
6:
    li      t0, 1
    blt     s0, t0, 7f
    call    _pop_to_a7
7:
    # emit ecall
    call    _ecall
    call    _new_line

    lw      ra, 28(sp)
    lw      s0, 24(sp)
    addi    sp, sp, 32
    ret

# pop helpers for syscall
_pop_to_a7:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    call    _lw
    call    _a7
    call    _comma
    li      a0, '0'
    call    _put_character
    li      a0, '('
    call    _put_character
    call    _sp
    li      a0, ')'
    call    _put_character
    call    _new_line
    call    _addi
    call    _sp
    call    _comma
    call    _sp
    call    _comma
    li      a0, 4
    call    _put_number
    call    _new_line
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_pop_to_a0:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    call    _lw
    call    _a0
    call    _comma
    li      a0, '0'
    call    _put_character
    li      a0, '('
    call    _put_character
    call    _sp
    li      a0, ')'
    call    _put_character
    call    _new_line
    call    _addi
    call    _sp
    call    _comma
    call    _sp
    call    _comma
    li      a0, 4
    call    _put_number
    call    _new_line
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_pop_to_a1:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    call    _lw
    call    _a1
    call    _comma
    li      a0, '0'
    call    _put_character
    li      a0, '('
    call    _put_character
    call    _sp
    li      a0, ')'
    call    _put_character
    call    _new_line
    call    _addi
    call    _sp
    call    _comma
    call    _sp
    call    _comma
    li      a0, 4
    call    _put_number
    call    _new_line
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_pop_to_a2:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    call    _lw
    call    _a2
    call    _comma
    li      a0, '0'
    call    _put_character
    li      a0, '('
    call    _put_character
    call    _sp
    li      a0, ')'
    call    _put_character
    call    _new_line
    call    _addi
    call    _sp
    call    _comma
    call    _sp
    call    _comma
    li      a0, 4
    call    _put_number
    call    _new_line
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_pop_to_a3:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    call    _lw
    call    _a3
    call    _comma
    li      a0, '0'
    call    _put_character
    li      a0, '('
    call    _put_character
    call    _sp
    li      a0, ')'
    call    _put_character
    call    _new_line
    call    _addi
    call    _sp
    call    _comma
    call    _sp
    call    _comma
    li      a0, 4
    call    _put_number
    call    _new_line
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_pop_to_a4:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    call    _lw
    call    _a4
    call    _comma
    li      a0, '0'
    call    _put_character
    li      a0, '('
    call    _put_character
    call    _sp
    li      a0, ')'
    call    _put_character
    call    _new_line
    call    _addi
    call    _sp
    call    _comma
    call    _sp
    call    _comma
    li      a0, 4
    call    _put_number
    call    _new_line
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_pop_to_a5:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    call    _lw
    call    _a5
    call    _comma
    li      a0, '0'
    call    _put_character
    li      a0, '('
    call    _put_character
    call    _sp
    li      a0, ')'
    call    _put_character
    call    _new_line
    call    _addi
    call    _sp
    call    _comma
    call    _sp
    call    _comma
    li      a0, 4
    call    _put_number
    call    _new_line
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# parse arguments: (expr, expr, ...)
# returns number of arguments in a0
# arguments are pushed onto stack
_args:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)

    li      s0, 0               # argument count

    li      a0, '('
    call    _symbol

    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, ')'
    beq     t1, t2, _args_done

_args_loop:
    addi    s0, s0, 1
    call    _or_expression
    call    _push_a0

    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, ','
    bne     t1, t2, _args_done

    call    _lexer
    j       _args_loop

_args_done:
    li      a0, ')'
    call    _symbol

    mv      a0, s0

    lw      ra, 28(sp)
    lw      s0, 24(sp)
    addi    sp, sp, 32
    ret

#######################
# toplevel expression #
#######################

_top_level_expression:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    la      t0, token_tag
    lw      t1, 0(t0)

    li      t2, T_IDENTIFIER
    beq     t1, t2, _top_level_identifier
    li      t2, T_MACRO
    beq     t1, t2, _top_level_identifier
    li      t2, T_VARIABLE
    beq     t1, t2, _top_level_variable
    li      t2, T_PARAMETER
    beq     t1, t2, _top_level_parameter
    li      t2, '*'
    beq     t1, t2, _top_level_dereference

    # array index assignment: simple_item[idx] = val
    call    _simple_item
    j       _top_level_array_assign

_top_level_identifier:
    # push identifier
    la      a0, token_text
    call    _push_identifier

    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)

    li      t2, ':'
    beq     t1, t2, _top_level_declaration
    li      t2, '='
    beq     t1, t2, _top_level_assign
    li      t2, '('
    beq     t1, t2, _top_level_funtion_call
    li      t2, '['
    beq     t1, t2, _top_level_array_assign2
    li      t2, T_ARROW
    beq     t1, t2, _top_level_macro_definition

    call    _syntax_error

# identifier declaration: name : ...
_top_level_declaration:
    call    _lexer
    call    _declaration

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# assignment: name = expr
_top_level_assign:
    call    _lexer
    call    _or_expression

    # emit: la t0, name; sw a0, 0(t0)
    call    _la
    call    _t0
    call    _comma
    li      a0, 0
    call    _get_nth_identifier
    call    _put_string
    call    _new_line

    call    _sw
    call    _a0
    call    _comma
    li      a0, '0'
    call    _put_character
    li      a0, '('
    call    _put_character
    call    _t0
    li      a0, ')'
    call    _put_character
    call    _new_line

    call    _pop_identifier

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# function call: name(args...)
_top_level_funtion_call:
    call    _function_call

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# array assignment: name[idx] = val
_top_level_array_assign2:
    # load array base address
    call    _la
    call    _a0
    call    _comma
    li      a0, 0
    call    _get_nth_identifier
    call    _put_string
    call    _new_line
    call    _pop_identifier

_top_level_array_assign:
    call    _push_a0

    call    _lexer
    call    _or_expression
    call    _push_a0

    call    _lexer
    li      a0, ']'
    call    _symbol

    call    _lexer
    li      a0, '='
    call    _symbol

    call    _lexer
    call    _or_expression

    # stack: [base, index], a0 = value
    call    _pop_t0             # t0 = index
    call    _pop_t1             # t1 = base

    # emit: slli t0, t0, 2 (index * 4)
    la      a0, slli_text
    call    _put_string
    call    _t0
    call    _comma
    call    _t0
    call    _comma
    li      a0, 2
    call    _put_number
    call    _new_line

    # emit: add t0, t1, t0
    call    _add
    call    _t0
    call    _comma
    call    _t1
    call    _comma
    call    _t0
    call    _new_line

    # emit: sw a0, 0(t0)
    call    _sw
    call    _a0
    call    _comma
    li      a0, '0'
    call    _put_character
    li      a0, '('
    call    _put_character
    call    _t0
    li      a0, ')'
    call    _put_character
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# macro definition: NAME => value
_top_level_macro_definition:
    call    _dot_equ
    li      a0, 0
    call    _get_nth_identifier
    call    _put_string
    call    _pop_identifier
    call    _comma

    call    _lexer

    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, '-'
    beq     t1, t2, _top_level_macro_neg

    li      t2, T_INTEGER
    beq     t1, t2, _top_level_macro_val
    li      t2, T_IDENTIFIER
    beq     t1, t2, _top_level_macro_val

    call    _syntax_error

_top_level_macro_neg:
    li      a0, '-'
    call    _put_character
    call    _lexer

_top_level_macro_val:
    la      a0, token_text
    call    _put_string
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# dereference assignment: *expr = val
_top_level_dereference:
    call    _lexer
    call    _prefix_expression
    call    _push_a0

    call    _lexer
    li      a0, '='
    call    _symbol

    call    _lexer
    call    _or_expression
    call    _pop_t0

    # emit: sw a0, 0(t0)
    call    _sw
    call    _a0
    call    _comma
    li      a0, '0'
    call    _put_character
    li      a0, '('
    call    _put_character
    call    _t0
    li      a0, ')'
    call    _put_character
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# local variable assignment: xN = expr or xN[idx] = val
_top_level_variable:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)

    la      t0, token_value
    lw      s0, 0(t0)           # s0 = variable number

    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)

    li      t2, '='
    beq     t1, t2, _top_level_variable_assign
    li      t2, '['
    beq     t1, t2, _top_level_variable_array
    li      t2, '('
    beq     t1, t2, _top_level_variable_call

    call    _syntax_error

_top_level_variable_assign:
    call    _lexer
    call    _or_expression

    # emit: sw a0, -offset(s0)
    call    _sw
    call    _a0
    call    _comma
    mv      a0, s0
    call    _variable
    call    _new_line

    lw      ra, 12(sp)
    lw      s0, 8(sp)
    addi    sp, sp, 16
    ret

_top_level_variable_array:
    # load variable value (array base)
    call    _lw
    call    _a0
    call    _comma
    mv      a0, s0
    call    _variable
    call    _new_line

    j       _top_level_array_assign

_top_level_variable_call:
    # load function pointer
    call    _lw
    call    _a0
    call    _comma
    mv      a0, s0
    call    _variable
    call    _new_line

    call    _indirect_call

    lw      ra, 12(sp)
    lw      s0, 8(sp)
    addi    sp, sp, 16
    ret

# parameter variable assignment: pN = expr
_top_level_parameter:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)

    la      t0, token_value
    lw      s0, 0(t0)

    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)

    li      t2, '='
    beq     t1, t2, _top_level_parameter_assign
    li      t2, '['
    beq     t1, t2, _top_level_parameter_array
    li      t2, '('
    beq     t1, t2, _top_level_parameter_call

    call    _syntax_error

_top_level_parameter_assign:
    call    _lexer
    call    _or_expression

    # emit: sw a0, offset(s0)
    call    _sw
    call    _a0
    call    _comma
    mv      a0, s0
    call    _parameter
    call    _new_line

    lw      ra, 12(sp)
    lw      s0, 8(sp)
    addi    sp, sp, 16
    ret

_top_level_parameter_array:
    call    _lw
    call    _a0
    call    _comma
    mv      a0, s0
    call    _parameter
    call    _new_line

    j       _top_level_array_assign

_top_level_parameter_call:
    call    _lw
    call    _a0
    call    _comma
    mv      a0, s0
    call    _parameter
    call    _new_line

    call    _indirect_call

    lw      ra, 12(sp)
    lw      s0, 8(sp)
    addi    sp, sp, 16
    ret

######################
# expression parsing #
######################

# or expression: xor_expr (| xor_expr)*
_or_expression:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _xor_expression

_or_expression_loop:
    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, '|'
    bne     t1, t2, _or_expression_done

    call    _push_a0
    call    _lexer
    call    _xor_expression
    call    _pop_t0

    # emit: or a0, t0, a0
    call    _or
    call    _a0
    call    _comma
    call    _t0
    call    _comma
    call    _a0
    call    _new_line

    j       _or_expression_loop

_or_expression_done:
    call    _lexer_unput

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# xor expression: and_expr (^ and_expr)*
_xor_expression:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _and_expression

_xor_expression_loop:
    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, '^'
    bne     t1, t2, _xor_expression_done

    call    _push_a0
    call    _lexer
    call    _and_expression
    call    _pop_t0

    # emit: xor a0, t0, a0
    call    _xor
    call    _a0
    call    _comma
    call    _t0
    call    _comma
    call    _a0
    call    _new_line

    j       _xor_expression_loop

_xor_expression_done:
    call    _lexer_unput

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# and expression: equality_expr (& equality_expr)*
_and_expression:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _equality_expression

_and_expression_loop:
    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, '&'
    bne     t1, t2, _and_expression_done

    call    _push_a0
    call    _lexer
    call    _equality_expression
    call    _pop_t0

    # emit: and a0, t0, a0
    call    _and
    call    _a0
    call    _comma
    call    _t0
    call    _comma
    call    _a0
    call    _new_line

    j       _and_expression_loop

_and_expression_done:
    call    _lexer_unput

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# equality expression: rel_expr (== rel_expr | != rel_expr)*
_equality_expression:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _relational_expression

_equality_expression_loop:
    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)

    li      t2, T_EQ
    beq     t1, t2, _equality_eq
    li      t2, T_NE
    beq     t1, t2, _equality_ne

    call    _lexer_unput
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_equality_eq:
    call    _push_a0
    call    _lexer
    call    _relational_expression
    call    _pop_t0

    # emit: sub a0, t0, a0; seqz a0, a0
    call    _sub
    call    _a0
    call    _comma
    call    _t0
    call    _comma
    call    _a0
    call    _new_line

    call    _seqz
    call    _a0
    call    _comma
    call    _a0
    call    _new_line

    j       _equality_expression_loop

_equality_ne:
    call    _push_a0
    call    _lexer
    call    _relational_expression
    call    _pop_t0

    # emit: sub a0, t0, a0; snez a0, a0
    call    _sub
    call    _a0
    call    _comma
    call    _t0
    call    _comma
    call    _a0
    call    _new_line

    call    _snez
    call    _a0
    call    _comma
    call    _a0
    call    _new_line

    j       _equality_expression_loop

# relational expression: additive_expr (< | > | <= | >= additive_expr)*
_relational_expression:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _additive_expression

_relational_loop:
    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)

    li      t2, '<'
    beq     t1, t2, _relational_lt
    li      t2, '>'
    beq     t1, t2, _relational_gt
    li      t2, T_LE
    beq     t1, t2, _relational_le
    li      t2, T_GE
    beq     t1, t2, _relational_ge

    call    _lexer_unput
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_relational_lt:
    call    _push_a0
    call    _lexer
    call    _additive_expression
    call    _pop_t0

    # emit: slt a0, t0, a0
    call    _slt
    call    _a0
    call    _comma
    call    _t0
    call    _comma
    call    _a0
    call    _new_line

    j       _relational_loop

_relational_gt:
    call    _push_a0
    call    _lexer
    call    _additive_expression
    call    _pop_t0

    # emit: slt a0, a0, t0 (swap operands)
    call    _slt
    call    _a0
    call    _comma
    call    _a0
    call    _comma
    call    _t0
    call    _new_line

    j       _relational_loop

_relational_le:
    call    _push_a0
    call    _lexer
    call    _additive_expression
    call    _pop_t0

    # emit: slt a0, a0, t0; xori a0, a0, 1 (not greater)
    call    _slt
    call    _a0
    call    _comma
    call    _a0
    call    _comma
    call    _t0
    call    _new_line

    la      a0, xori_text
    call    _put_string
    call    _a0
    call    _comma
    call    _a0
    call    _comma
    li      a0, 1
    call    _put_number
    call    _new_line

    j       _relational_loop

_relational_ge:
    call    _push_a0
    call    _lexer
    call    _additive_expression
    call    _pop_t0

    # emit: slt a0, t0, a0; xori a0, a0, 1 (not less)
    call    _slt
    call    _a0
    call    _comma
    call    _t0
    call    _comma
    call    _a0
    call    _new_line

    la      a0, xori_text
    call    _put_string
    call    _a0
    call    _comma
    call    _a0
    call    _comma
    li      a0, 1
    call    _put_number
    call    _new_line

    j       _relational_loop

.section .rodata
xori_text: .string "\txori "
.text

# additive expression: multiplicative_expr (+ | - multiplicative_expr)*
_additive_expression:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _multiplicative_expression

_additive_loop:
    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)

    li      t2, '+'
    beq     t1, t2, _additive_add
    li      t2, '-'
    beq     t1, t2, _additive_sub

    call    _lexer_unput
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_additive_add:
    call    _push_a0
    call    _lexer
    call    _multiplicative_expression
    call    _pop_t0

    # emit: add a0, t0, a0
    call    _add
    call    _a0
    call    _comma
    call    _t0
    call    _comma
    call    _a0
    call    _new_line

    j       _additive_loop

_additive_sub:
    call    _push_a0
    call    _lexer
    call    _multiplicative_expression
    call    _pop_t0

    # emit: sub a0, t0, a0
    call    _sub
    call    _a0
    call    _comma
    call    _t0
    call    _comma
    call    _a0
    call    _new_line

    j       _additive_loop

# multiplicative expression: prefix_expr (* | / | % prefix_expr)*
_multiplicative_expression:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _prefix_expression

_mult_loop:
    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)

    li      t2, '*'
    beq     t1, t2, _mult_mul
    li      t2, '/'
    beq     t1, t2, _mult_div
    li      t2, '%'
    beq     t1, t2, _mult_rem

    call    _lexer_unput
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_mult_mul:
    call    _push_a0
    call    _lexer
    call    _prefix_expression
    call    _pop_t0

    # emit: mul a0, t0, a0
    call    _mul
    call    _a0
    call    _comma
    call    _t0
    call    _comma
    call    _a0
    call    _new_line

    j       _mult_loop

_mult_div:
    call    _push_a0
    call    _lexer
    call    _prefix_expression
    call    _pop_t0

    # emit: div a0, t0, a0
    call    _div
    call    _a0
    call    _comma
    call    _t0
    call    _comma
    call    _a0
    call    _new_line

    j       _mult_loop

_mult_rem:
    call    _push_a0
    call    _lexer
    call    _prefix_expression
    call    _pop_t0

    # emit: rem a0, t0, a0
    call    _rem
    call    _a0
    call    _comma
    call    _t0
    call    _comma
    call    _a0
    call    _new_line

    j       _mult_loop

# prefix expression: [+ | - | * | & | ~] simple_item
_prefix_expression:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    la      t0, token_tag
    lw      t1, 0(t0)

    li      t2, '+'
    beq     t1, t2, _prefix_plus
    li      t2, '-'
    beq     t1, t2, _prefix_neg
    li      t2, '*'
    beq     t1, t2, _prefix_dereference
    li      t2, '&'
    beq     t1, t2, _prefix_address
    li      t2, '~'
    beq     t1, t2, _prefix_not

    call    _simple_item

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_prefix_plus:
    call    _lexer
    call    _simple_item
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_prefix_neg:
    call    _lexer
    call    _simple_item

    # emit: neg a0, a0
    call    _neg
    call    _a0
    call    _comma
    call    _a0
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_prefix_dereference:
    call    _lexer
    call    _simple_item

    # emit: lw a0, 0(a0)
    call    _lw
    call    _a0
    call    _comma
    li      a0, '0'
    call    _put_character
    li      a0, '('
    call    _put_character
    call    _a0
    li      a0, ')'
    call    _put_character
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_prefix_address:
    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)

    li      t2, T_IDENTIFIER
    beq     t1, t2, _prefix_address_identifier
    li      t2, T_PARAMETER
    beq     t1, t2, _prefix_address_parameter
    li      t2, T_VARIABLE
    beq     t1, t2, _prefix_address_variable

    call    _syntax_error

_prefix_address_identifier:
    # emit: la a0, name
    call    _la
    call    _a0
    call    _comma
    la      a0, token_text
    call    _put_string
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_prefix_address_parameter:
    # emit: addi a0, s0, offset
    la      t0, token_value
    lw      t1, 0(t0)
    addi    t1, t1, 2
    slli    t1, t1, 2

    call    _addi
    call    _a0
    call    _comma
    call    _s0
    call    _comma
    mv      a0, t1
    call    _put_number
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_prefix_address_variable:
    # emit: addi a0, s0, -offset
    la      t0, token_value
    lw      t1, 0(t0)
    addi    t1, t1, 1
    slli    t1, t1, 2
    neg     t1, t1

    call    _addi
    call    _a0
    call    _comma
    call    _s0
    call    _comma
    mv      a0, t1
    call    _put_number
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_prefix_not:
    call    _lexer
    call    _simple_item

    # emit: not a0, a0
    call    _not
    call    _a0
    call    _comma
    call    _a0
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# simple item: identifier | constant | (expr) | array | block | call
_simple_item:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    la      t0, token_tag
    lw      t1, 0(t0)

    li      t2, T_IDENTIFIER
    beq     t1, t2, _simple_identifier
    li      t2, T_VARIABLE
    beq     t1, t2, _simple_variable
    li      t2, T_VARIABLE
    beq     t1, t2, _simple_parameter
    li      t2, '('
    beq     t1, t2, _simple_paren
    li      t2, T_READ
    beq     t1, t2, _simple_read
    li      t2, T_MACRO
    beq     t1, t2, _simple_macro
    li      t2, T_SYSTEM_CALL
    beq     t1, t2, _simple_syscall

    call    _constant
    j       _simple_item_suffix

_simple_identifier:
    la      a0, token_text
    call    _push_identifier

    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, '('
    beq     t1, t2, _simple_identifier_call

    call    _lexer_unput

    # load identifier value
    call    _la
    call    _a0
    call    _comma
    li      a0, 0
    call    _get_nth_identifier
    call    _put_string
    call    _new_line

    call    _lw
    call    _a0
    call    _comma
    li      a0, '0'
    call    _put_character
    li      a0, '('
    call    _put_character
    call    _a0
    li      a0, ')'
    call    _put_character
    call    _new_line

    call    _pop_identifier

    j       _simple_item_suffix

_simple_identifier_call:
    call    _function_call
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_simple_variable:
    la      t0, token_value
    lw      a0, 0(t0)

    # emit: lw a0, offset(s0)
    call    _lw
    call    _a0
    call    _comma
    la      t0, token_value
    lw      a0, 0(t0)
    call    _variable
    call    _new_line

    j       _simple_item_suffix

_simple_parameter:
    la      t0, token_value
    lw      a0, 0(t0)

    # emit: lw a0, offset(s0)
    call    _lw
    call    _a0
    call    _comma
    la      t0, token_value
    lw      a0, 0(t0)
    call    _parameter
    call    _new_line

    j       _simple_item_suffix

_simple_paren:
    call    _lexer
    call    _or_expression

    call    _lexer
    li      a0, ')'
    call    _symbol

    j       _simple_item_suffix

_simple_read:
    # rch(arr, idx) - read character
    call    _lexer
    li      a0, '('
    call    _symbol

    call    _lexer
    call    _or_expression
    call    _push_a0

    call    _lexer
    li      a0, ','
    call    _symbol

    call    _lexer
    call    _or_expression
    call    _pop_t0

    # emit: add a0, t0, a0; lb a0, 0(a0)
    call    _add
    call    _a0
    call    _comma
    call    _t0
    call    _comma
    call    _a0
    call    _new_line

    call    _lb
    call    _a0
    call    _comma
    li      a0, '0'
    call    _put_character
    li      a0, '('
    call    _put_character
    call    _a0
    li      a0, ')'
    call    _put_character
    call    _new_line

    call    _lexer
    li      a0, ')'
    call    _symbol

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_simple_macro:
    # load macro value
    call    _li
    call    _a0
    call    _comma
    la      a0, token_text
    call    _put_string
    call    _new_line

    j       _simple_item_suffix

_simple_syscall:
    call    _syscall
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_simple_item_suffix:
    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)

    li      t2, '['
    beq     t1, t2, _simple_array_ref
    li      t2, '('
    beq     t1, t2, _simple_indirect_call

    call    _lexer_unput
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_simple_array_ref:
    call    _array_ref
    j       _simple_item_suffix

_simple_indirect_call:
    call    _indirect_call
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# array reference: [index]
_array_ref:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _push_a0

    call    _lexer
    call    _or_expression

    call    _lexer
    li      a0, ']'
    call    _symbol

    call    _pop_t0

    # emit: slli a0, a0, 2; add a0, t0, a0; lw a0, 0(a0)
    la      a0, slli_text
    call    _put_string
    call    _a0
    call    _comma
    call    _a0
    call    _comma
    li      a0, 2
    call    _put_number
    call    _new_line

    call    _add
    call    _a0
    call    _comma
    call    _t0
    call    _comma
    call    _a0
    call    _new_line

    call    _lw
    call    _a0
    call    _comma
    li      a0, '0'
    call    _put_character
    li      a0, '('
    call    _put_character
    call    _a0
    li      a0, ')'
    call    _put_character
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_function_call:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)

    call    _args
    mv      s0, a0              # s0 = number of args

    # pop arguments to a0-a7
    beqz    s0, _function_call_call

    mv      s1, s0
_function_call_pop:
    addi    s1, s1, -1
    bltz    s1, _function_call_call

    # pop to appropriate register
    li      t0, 0
    beq     s1, t0, _function_call_pop_a0
    li      t0, 1
    beq     s1, t0, _function_call_pop_a1
    li      t0, 2
    beq     s1, t0, _function_call_pop_a2
    li      t0, 3
    beq     s1, t0, _function_call_pop_a3
    li      t0, 4
    beq     s1, t0, _function_call_pop_a4
    li      t0, 5
    beq     s1, t0, _function_call_pop_a5
    li      t0, 6
    beq     s1, t0, _function_call_pop_a6
    li      t0, 7
    beq     s1, t0, _function_call_pop_a7

    # more than 8 args: leave on stack
    j       _function_call_pop

_function_call_pop_a0:
    call    _pop_to_a0
    j       _function_call_pop
_function_call_pop_a1:
    call    _pop_to_a1
    j       _function_call_pop
_function_call_pop_a2:
    call    _pop_to_a2
    j       _function_call_pop
_function_call_pop_a3:
    call    _pop_to_a3
    j       _function_call_pop
_function_call_pop_a4:
    call    _pop_to_a4
    j       _function_call_pop
_function_call_pop_a5:
    call    _pop_to_a5
    j       _function_call_pop
_function_call_pop_a6:
    call    _lw
    call    _a6
    call    _comma
    li      a0, '0'
    call    _put_character
    li      a0, '('
    call    _put_character
    call    _sp
    li      a0, ')'
    call    _put_character
    call    _new_line
    call    _addi
    call    _sp
    call    _comma
    call    _sp
    call    _comma
    li      a0, 4
    call    _put_number
    call    _new_line
    j       _function_call_pop
_function_call_pop_a7:
    call    _pop_to_a7
    j       _function_call_pop

_function_call_call:
    # emit: call name
    call    _call
    li      a0, 0
    call    _get_nth_identifier
    call    _put_string
    call    _new_line

    call    _pop_identifier

    lw      ra, 28(sp)
    lw      s0, 24(sp)
    lw      s1, 20(sp)
    addi    sp, sp, 32
    ret

# indirect call: value in a0 is function pointer
_indirect_call:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)

    call    _push_a0            # save function pointer

    call    _args
    mv      s0, a0

    # pop arguments
    beqz    s0, _indirect_call_call

    mv      s1, s0
_indirect_call_pop:
    addi    s1, s1, -1
    bltz    s1, _indirect_call_call

    li      t0, 0
    beq     s1, t0, _indirect_call_pop_a0
    li      t0, 1
    beq     s1, t0, _indirect_call_pop_a1
    li      t0, 2
    beq     s1, t0, _indirect_call_pop_a2
    li      t0, 3
    beq     s1, t0, _indirect_call_pop_a3
    li      t0, 4
    beq     s1, t0, _indirect_call_pop_a4
    li      t0, 5
    beq     s1, t0, _indirect_call_pop_a5

    j       _indirect_call_pop

_indirect_call_pop_a0:
    call    _pop_to_a0
    j       _indirect_call_pop
_indirect_call_pop_a1:
    call    _pop_to_a1
    j       _indirect_call_pop
_indirect_call_pop_a2:
    call    _pop_to_a2
    j       _indirect_call_pop
_indirect_call_pop_a3:
    call    _pop_to_a3
    j       _indirect_call_pop
_indirect_call_pop_a4:
    call    _pop_to_a4
    j       _indirect_call_pop
_indirect_call_pop_a5:
    call    _pop_to_a5
    j       _indirect_call_pop

_indirect_call_call:
    # pop function pointer to t0
    call    _pop_t0

    # Emit: jalr ra, t0, 0
    call    _jalr
    call    _ra
    call    _comma
    call    _t0
    call    _comma
    li      a0, 0
    call    _put_number
    call    _new_line

    lw      ra, 28(sp)
    lw      s0, 24(sp)
    lw      s1, 20(sp)
    addi    sp, sp, 32
    ret

# constant: integer | string
_constant:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    la      t0, token_tag
    lw      t1, 0(t0)

    li      t2, T_INTEGER
    beq     t1, t2, _constant_int
    li      t2, T_STRING
    beq     t1, t2, _constant_string

    call    _syntax_error

_constant_int:
    # Emit: li a0, value
    call    _li
    call    _a0
    call    _comma
    la      t0, token_value
    lw      a0, 0(t0)
    call    _put_number
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_constant_string:
    # Emit: la a0, string_literals+offset
    call    _la
    call    _a0
    call    _comma
    call    _put_string_address
    call    _new_line

    la      a0, token_text
    call    _push_string

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

#######################
# declaration parsing #
#######################

_declaration:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    la      t0, token_tag
    lw      t1, 0(t0)

    li      t2, '['
    beq     t1, t2, _decl_array
    li      t2, '('
    beq     t1, t2, _decl_func
    li      t2, T_INTEGER_TYPE
    beq     t1, t2, _decl_int_array
    li      t2, T_CHARACTER_TYPE
    beq     t1, t2, _decl_char_array

    # Simple value declaration
    call    _enter_data_area
    li      a0, 0
    call    _get_nth_identifier
    call    _put_string
    call    _pop_identifier
    li      a0, ':'
    call    _put_character
    call    _space

    call    _dot_word
    call    _space
    call    _simple_value
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_decl_array:
    call    _enter_data_area
    li      a0, 0
    call    _get_nth_identifier
    call    _put_string
    call    _pop_identifier
    li      a0, ':'
    call    _put_character
    call    _space
    call    _array

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_decl_func:
    call    _enter_text_area
    # Emit .global funcname
    call    _dot_global
    li      a0, 0
    call    _get_nth_identifier
    call    _put_string
    call    _new_line
    # Emit funcname:
    li      a0, 0
    call    _get_nth_identifier
    call    _put_string
    call    _pop_identifier
    li      a0, ':'
    call    _put_character
    call    _new_line
    call    _fundecl

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_decl_int_array:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)

    call    _enter_data_area
    li      a0, 0
    call    _get_nth_identifier
    call    _put_string
    call    _pop_identifier
    li      a0, ':'
    call    _put_character
    call    _space

    call    _dot_word
    call    _new_label_id
    mv      s0, a0
    call    _label
    call    _new_line

    call    _lexer
    li      a0, '['
    call    _symbol

    call    _dot_comm
    mv      a0, s0
    call    _label
    call    _comma

    call    _lexer
    call    _simple_value
    li      a0, '*'
    call    _put_character
    li      a0, 4
    call    _put_number
    call    _new_line

    call    _lexer
    li      a0, ']'
    call    _symbol

    lw      ra, 12(sp)
    lw      s0, 8(sp)
    addi    sp, sp, 16
    ret

_decl_char_array:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)

    call    _enter_data_area
    li      a0, 0
    call    _get_nth_identifier
    call    _put_string
    call    _pop_identifier
    li      a0, ':'
    call    _put_character
    call    _space

    call    _dot_word
    call    _new_label_id
    mv      s0, a0
    call    _label
    call    _new_line

    call    _lexer
    li      a0, '['
    call    _symbol

    call    _dot_comm
    mv      a0, s0
    call    _label
    call    _comma

    call    _lexer
    call    _simple_value
    call    _new_line

    call    _lexer
    li      a0, ']'
    call    _symbol

    lw      ra, 12(sp)
    lw      s0, 8(sp)
    addi    sp, sp, 16
    ret

# Array literal: [val, val, ...]
_array:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)

    call    _space
    call    _dot_word
    call    _space

    call    _new_label_id
    mv      s0, a0
    call    _label
    call    _new_line

    mv      a0, s0
    call    _label_definition
    call    _space
    call    _dot_word
    call    _space

    call    _lexer
1:
    call    _simple_value

    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, ']'
    beq     t1, t2, 2f

    li      a0, ','
    call    _symbol
    call    _comma

    call    _lexer
    j       1b

2:
    call    _new_line

    lw      ra, 12(sp)
    lw      s0, 8(sp)
    addi    sp, sp, 16
    ret

# Function declaration: (params) { body }
_fundecl:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _params
    call    _set_frame

    call    _lexer
    call    _block

    call    _end_frame

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# Parameters: (p0, p1, ...)
_params:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)

    li      s0, 0               # parameter count

    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, ')'
    beq     t1, t2, _params_done

1:
    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, T_PARAMETER
    bne     t1, t2, _params_error

    la      t0, token_value
    lw      t1, 0(t0)
    bne     t1, s0, _params_error

    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, ','
    bne     t1, t2, _params_done

    addi    s0, s0, 1
    call    _lexer
    j       1b

_params_error:
    call    _syntax_error

_params_done:
    li      a0, ')'
    call    _symbol

    lw      ra, 12(sp)
    lw      s0, 8(sp)
    addi    sp, sp, 16
    ret

# Block: { items }
_block:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    li      a0, '{'
    call    _symbol

    call    _lexer

_block_loop:
    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, ';'
    bne     t1, t2, 1f
    call    _lexer
1:
    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, '}'
    beq     t1, t2, _block_done

    call    _item

    call    _lexer
    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, ';'
    bne     t1, t2, _block_done

    call    _lexer
    j       _block_loop

_block_done:
    li      a0, '}'
    call    _symbol

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# simple value: integer | identifier | string | -value | MACRO
_simple_value:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    la      t0, token_tag
    lw      t1, 0(t0)

    li      t2, T_INTEGER
    beq     t1, t2, _simple_value_integer
    li      t2, T_IDENTIFIER
    beq     t1, t2, _simple_value_identifier
    li      t2, T_STRING
    beq     t1, t2, _simple_value_string
    li      t2, '-'
    beq     t1, t2, _simple_value_neg
    li      t2, T_MACRO
    beq     t1, t2, _simple_value_identifier

    call    _syntax_error

_simple_value_integer:
    la      t0, token_value
    lw      a0, 0(t0)
    call    _put_number
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_simple_value_identifier:
    la      a0, token_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_simple_value_string:
    call    _put_string_address
    la      a0, token_text
    call    _push_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_simple_value_neg:
    li      a0, '-'
    call    _put_character
    call    _lexer
    j       _simple_value


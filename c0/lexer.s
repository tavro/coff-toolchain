#
# source code written by tyson horvath (tavro)
# for the c0 programming language (RISC-V implementation)
#
# this tokenizes input into tokens
#

.include "constants.s"
.include "token.s"

#
# character groups for lexer state machine:
#
# C_NULL          : \0
# C_INVALID       : invalid characters
# C_SPACES        : [\t\r ]
# C_NEW_LINE      : '\n'
# C_ZERO          : 0
# C_NONZERO       : [1-9]
# C_NORMAL        : [A-Za-z_] except special chars
# C_SPECIAL       : [abfrtv]
# C_N             : n
# C_P_OR_X        : p|x
# C_SINGLE_QUOTE  : \'
# C_DOUBLE_QUOTE  : \"
# C_BACKSLASH     : \\
# C_QUESTION_MARK : \?
# C_SYMBOL        : other characters
#

.equ C_NULL,            0
.equ C_INVALID,         1
.equ C_SPACES,          2
.equ C_ZERO,            3
.equ C_NONZERO,         4
.equ C_NORMAL,          5
.equ C_SPECIAL,         6
.equ C_N,               7
.equ C_SINGLE_QUOTE,    8
.equ C_DOUBLE_QUOTE,    9
.equ C_BACKSLASH,       10
.equ C_QUESTION_MARK,   11
.equ C_SYMBOL,          12
.equ C_NEW_LINE,        13
.equ C_P_OR_X,          14

.section .rodata

# lookup table
lexer_character_group:
    .word  0,  1,  1,  1,  1,  1,  1,  1,  1,  2, 13,  1,  1,  2,  1,  1
    .word  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1
    .word  2, 12,  9, 12, 12, 12, 12,  8, 12, 12, 12, 12, 12, 12, 12, 12  # (space, !, ", #, etc)
    .word  3,  4,  4,  4,  4,  4,  4,  4,  4,  4, 12, 12, 12, 12, 12, 11  # (0-9, :, ;, <, =, >, ?)
    .word 12,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5  # (@, A-O)
    .word  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5, 12, 10, 12, 12,  5  # (P-Z, [, \, ], ^, _)
    .word 12,  6,  6,  5,  5,  5,  6,  5,  5,  5,  5,  5,  5,  5,  7,  5  # (`, a-o)
    .word 14,  5,  6,  5,  6,  5,  6,  5, 14,  5,  5, 12, 12, 12, 12,  1  # (p-z, {, |, }, ~, DEL)
    # 0x80-0xFF are all invalid
    .word  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1
    .word  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1
    .word  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1
    .word  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1
    .word  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1
    .word  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1
    .word  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1
    .word  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1

# escape sequence values (indexed from '"' = 34)
character_2_escape:
    #    \"                \'                               \0
    .word 34, 0, 0, 0, 0, 39, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    #                        \?
    .word 0, 0, 0, 0, 0, 0, 63, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    #                                       \\             \a \b           \f
    .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92, 0, 0, 0, 0, 7, 8, 0, 0, 0, 12, 0
    #                        \n           \r    \t     \v
    .word 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 13, 0, 9, 0, 11

reserved_words:
    .word if_text, else_text, while_text, goto_text, label_text
    .word return_text, sysall_text, export_text, allocate_text
    .word include_text, write_text, read_text, integer_text, character_text, 0

if_text:        .string "if"
else_text:      .string "else"
while_text:     .string "while"
goto_text:      .string "goto"
label_text:     .string "label"
return_text:    .string "return"
syscall_text:   .string "syscall"
export_text:    .string "export"
allocate_text:  .string "allocate"
include_text:   .string "include"
write_text:     .string "write"
read_text:      .string "read"
integer_text:   .string "integer"
character_text: .string "character"

undefined_message:          .string "ERROR: undefined token\n"
too_long_message:           .string "ERROR: too long token\n"
unclosed_message:           .string "ERROR: unclosed comment\n"
identifier_stack_overflow:  .string "ERROR: identifier stack overflow\n"
identifier_stack_empty:     .string "ERROR: identifier stack is empty\n"
unput_error_message:        .string "ERROR: try to unput two or more tokens\n"

.data

.comm token_text, MAX_TOKEN_LENGTH, 1
.global token_tag, token_length, token_value
token_tag:    .word 0
token_length: .word 0
token_value:  .word 0

unput: .word 0

.global source_line_number
source_line_number: .word 1

.equ IDENTIFIER_STACK_LENGTH, 16
.comm identifier_stack, MAX_TOKEN_LENGTH*IDENTIFIER_STACK_LENGTH, 1
identifier_stack_depth: .word 0

.text

##############################
# identifier stack functions #
##############################

# void _push_identifier(const char *id)
.global _push_identifier
_push_identifier:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    sw      a0, 4(sp)
    addi    s0, sp, 16

    la      t0, identifier_stack_depth
    lw      t1, 0(t0)
    li      t2, IDENTIFIER_STACK_LENGTH
    beq     t1, t2, _push_identifier_overflow

    # calculate destination: identifier_stack + depth * MAX_TOKEN_LENGTH
    li      t2, MAX_TOKEN_LENGTH
    mul     t3, t1, t2
    la      t4, identifier_stack
    add     a0, t4, t3                  # dst

    lw      a1, 4(sp)                   # src
    call    _string_copy

    # increment depth
    la      t0, identifier_stack_depth
    lw      t1, 0(t0)
    addi    t1, t1, 1
    sw      t1, 0(t0)

    lw      ra, 12(sp)
    lw      s0, 8(sp)
    addi    sp, sp, 16
    ret

_push_identifier_overflow:
    call    _flush
    la      a0, identifier_stack_overflow
    call    _put_string
    call    _flush
    li      a0, 1
    call    _exit

# void _pop_identifier(void)
.global _pop_identifier
_pop_identifier:
    la      t0, identifier_stack_depth
    lw      t1, 0(t0)
    beqz    t1, _pop_identifier_empty

    addi    t1, t1, -1
    sw      t1, 0(t0)
    ret

_pop_identifier_empty:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _flush
    la      a0, identifier_stack_empty
    call    _put_string
    call    _flush
    li      a0, 1
    call    _exit

# char* _get_nth_identifier(int n)
# returns pointer to n-th identifier from top of stack
.global _get_nth_identifier
_get_nth_identifier:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    addi    s0, sp, 16

    la      t0, identifier_stack_depth
    lw      t1, 0(t0)
    bge     a0, t1, _get_nth_overflow

    # index = depth - n - 1
    sub     t2, t1, a0
    addi    t2, t2, -1

    li      t3, MAX_TOKEN_LENGTH
    mul     t2, t2, t3
    la      t4, identifier_stack
    add     a0, t4, t2

    lw      ra, 12(sp)
    lw      s0, 8(sp)
    addi    sp, sp, 16
    ret

_get_nth_overflow:
    call    _flush
    la      a0, identifier_stack_overflow
    call    _put_string
    call    _flush
    li      a0, 1
    call    _exit

#########################
# lexer error functions #
#########################

_undefined_token:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _flush
    la      t0, source_line_number
    lw      a0, 0(t0)
    call    _put_number
    li      a0, ':'
    call    _put_character
    la      a0, undefined_message
    call    _put_string
    call    _flush
    li      a0, 1
    call    _exit

_too_long_token:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _flush
    la      t0, source_line_number
    lw      a0, 0(t0)
    call    _put_number
    li      a0, ':'
    call    _put_character
    la      a0, too_long_message
    call    _put_string
    call    _flush
    li      a0, 1
    call    _exit

_unclosed_comment:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _flush
    la      t0, source_line_number
    lw      a0, 0(t0)
    call    _put_number
    li      a0, ':'
    call    _put_character
    la      a0, unclosed_message
    call    _put_string
    call    _flush
    li      a0, 1
    call    _exit

##########################
# lexer helper functions #
##########################

# int _lexer_lookahead(void)
# returns character group of next character
_lexer_lookahead:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _next_character
    li      t0, EOF
    beq     a0, t0, 1f

    # look up character group
    la      t0, lexer_character_group
    slli    t1, a0, 2           # * 4 for word offset
    add     t0, t0, t1
    lw      a0, 0(t0)

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret
1:
    li      a0, C_NULL
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# void _lexer_consume(void)
# consume character and add to token_text
_lexer_consume:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)

    call    _get_character
    mv      s0, a0              # save character

    # check for new line
    li      t0, '\n'
    bne     a0, t0, 1f
    la      t1, source_line_number
    lw      t2, 0(t1)
    addi    t2, t2, 1
    sw      t2, 0(t1)
1:
    # add to token_text
    la      t0, token_length
    lw      t1, 0(t0)
    li      t2, MAX_TOKEN_LENGTH-1
    bge     t1, t2, _too_long_token

    la      t3, token_text
    add     t3, t3, t1
    sb      s0, 0(t3)
    addi    t1, t1, 1
    sb      zero, 1(t3)         # null terminate
    sw      t1, 0(t0)

    mv      a0, s0              # return character

    lw      ra, 12(sp)
    lw      s0, 8(sp)
    addi    sp, sp, 16
    ret

# void _lexer_skip(void)
# consume character without adding to token
_lexer_skip:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _get_character

    # check for new line
    li      t0, '\n'
    bne     a0, t0, 1f
    la      t1, source_line_number
    lw      t2, 0(t1)
    addi    t2, t2, 1
    sw      t2, 0(t1)
1:
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

##################
# unput function #
##################

# void _lexer_unput(void)
.global _lexer_unput
_lexer_unput:
    la      t0, unput
    lw      t1, 0(t0)
    bnez    t1, _lexer_unput_error

    li      t1, 1
    sw      t1, 0(t0)
    ret

_lexer_unput_error:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    la      a0, unput_error_message
    call    _put_string
    li      a0, 1
    call    _exit

#######################
# main lexer function #
#######################

# int _lexer(void)
# read one token, return token code
.global _lexer
_lexer:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)
    sw      s3, 12(sp)
    addi    s0, sp, 32

    # check if we have an unput token
    la      t0, unput
    lw      t1, 0(t0)
    bnez    t1, _lexer_return_unput

_lexer_s0:
    # reset token
    la      t0, token_length
    sw      zero, 0(t0)
    la      t0, token_value
    sw      zero, 0(t0)

    call    _lexer_lookahead
    mv      s1, a0              # s1 = character group

    # dispatch based on character group
    li      t0, C_NULL
    beq     s1, t0, _lexer_s14  # EOF

    li      t0, C_INVALID
    beq     s1, t0, _lexer_s15  # error

    li      t0, C_SPACES
    beq     s1, t0, _lexer_s13  # skip whitespace

    li      t0, C_NEW_LINE
    beq     s1, t0, _lexer_s13  # skip newline

    li      t0, C_ZERO
    beq     s1, t0, _lexer_s1   # integer starting with 0

    li      t0, C_NONZERO
    beq     s1, t0, _lexer_s2   # integer

    li      t0, C_NORMAL
    beq     s1, t0, _lexer_s3   # identifier

    li      t0, C_SPECIAL
    beq     s1, t0, _lexer_s3   # identifier

    li      t0, C_N
    beq     s1, t0, _lexer_s3   # identifier

    li      t0, C_SINGLE_QUOTE
    beq     s1, t0, _lexer_s4   # character literal

    li      t0, C_DOUBLE_QUOTE
    beq     s1, t0, _lexer_s9   # string literal

    li      t0, C_P_OR_X
    beq     s1, t0, _lexer_s19  # p/x variable

    # default: symbol
    j       _lexer_s12

# state 1: integer literal starting with 0
_lexer_s1:
    call    _lexer_consume
    la      t0, token_tag
    li      t1, TOK_INTEGER
    sw      t1, 0(t0)
    la      t0, token_value
    sw      zero, 0(t0)
    j       _lexer_s16

# state 2: integer literal
_lexer_s2:
    call    _lexer_consume
    mv      s2, a0              # s2 = digit character

    # convert to value: token_val = token_val * 10 + (digit - '0')
    la      t0, token_value
    lw      t1, 0(t0)
    li      t2, 10
    mul     t1, t1, t2
    addi    s2, s2, -'0'
    add     t1, t1, s2
    sw      t1, 0(t0)

    la      t0, token_tag
    li      t1, TOK_INTEGER
    sw      t1, 0(t0)

    call    _lexer_lookahead
    li      t0, C_ZERO
    beq     a0, t0, _lexer_s2
    li      t0, C_NONZERO
    beq     a0, t0, _lexer_s2

    j       _lexer_s16

# state 3: identifier
_lexer_s3:
    call    _lexer_consume

    la      t0, token_tag
    li      t1, TOK_IDENTIFIER
    sw      t1, 0(t0)

    call    _lexer_lookahead
    li      t0, C_NORMAL
    beq     a0, t0, _lexer_s3
    li      t0, C_SPECIAL
    beq     a0, t0, _lexer_s3
    li      t0, C_N
    beq     a0, t0, _lexer_s3
    li      t0, C_P_OR_X
    beq     a0, t0, _lexer_s3
    li      t0, C_ZERO
    beq     a0, t0, _lexer_s3
    li      t0, C_NONZERO
    beq     a0, t0, _lexer_s3

    # check for reserved words
    j       _lexer_s17

# state 4: character literal start (')
_lexer_s4:
    call    _lexer_consume      # consume '
    call    _lexer_lookahead

    li      t0, C_BACKSLASH
    beq     a0, t0, _lexer_s7   # escape sequence
    li      t0, C_SINGLE_QUOTE
    beq     a0, t0, _lexer_s15  # empty char literal is error
    li      t0, C_NEW_LINE
    beq     a0, t0, _lexer_s15  # new line in char literal is error

    j       _lexer_s5           # normal character

# state 5: character in character literal
_lexer_s5:
    call    _lexer_consume
    la      t0, token_value
    sw      a0, 0(t0)           # store character value

    call    _lexer_lookahead
    li      t0, C_SINGLE_QUOTE
    bne     a0, t0, _lexer_s15  # must end with '
    j       _lexer_s6

# state 6: end of character literal
_lexer_s6:
    call    _lexer_consume      # consume closing '
    la      t0, token_tag
    li      t1, TOK_INTEGER
    sw      t1, 0(t0)
    j       _lexer_s16

# state 7: escape sequence in character literal
_lexer_s7:
    call    _lexer_consume      # consume backslash
    call    _lexer_lookahead

    # check for valid escape characters
    li      t0, C_DOUBLE_QUOTE
    beq     a0, t0, _lexer_s8
    li      t0, C_SINGLE_QUOTE
    beq     a0, t0, _lexer_s8
    li      t0, C_QUESTION_MARK
    beq     a0, t0, _lexer_s8
    li      t0, C_BACKSLASH
    beq     a0, t0, _lexer_s8
    li      t0, C_SPECIAL
    beq     a0, t0, _lexer_s8
    li      t0, C_N
    beq     a0, t0, _lexer_s8
    li      t0, C_ZERO
    beq     a0, t0, _lexer_s8

    j       _lexer_s15          # invalid escape

# state 8: escaped character value
_lexer_s8:
    call    _lexer_consume
    mv      s2, a0              # s2 = escaped char

    # look up escape value
    addi    s2, s2, -'"'        # offset from '"'
    la      t0, character_2_escape
    slli    t1, s2, 2
    add     t0, t0, t1
    lw      t1, 0(t0)

    la      t0, token_value
    sw      t1, 0(t0)

    call    _lexer_lookahead
    li      t0, C_SINGLE_QUOTE
    beq     a0, t0, _lexer_s6
    j       _lexer_s15

# state 9: string literal
_lexer_s9:
    call    _lexer_consume      # consume opening "

_lexer_s9_loop:
    call    _lexer_lookahead

    li      t0, C_DQUOTE
    beq     a0, t0, _lexer_s10  # end of string
    li      t0, C_BACKSLASH
    beq     a0, t0, _lexer_s11  # escape sequence
    li      t0, C_NEW_LINE
    beq     a0, t0, _lexer_s15  # error: new line in string
    li      t0, C_NULL
    beq     a0, t0, _lexer_s15  # error: EOF in string

    call    _lexer_consume      # normal character
    j       _lexer_s9_loop

# state 10: end of string literal
_lexer_s10:
    call    _lexer_consume      # consume closing "
    la      t0, token_tag
    li      t1, T_STRING
    sw      t1, 0(t0)
    j       _lexer_s16

# state 11: escape in string literal
_lexer_s11:
    call    _lexer_consume      # consume backslash
    call    _lexer_lookahead

    # check valid escapes
    li      t0, C_DOUBLE_QUOTE
    beq     a0, t0, _lexer_s11_consume
    li      t0, C_SINGLE_QUOTE
    beq     a0, t0, _lexer_s11_consume
    li      t0, C_QUESTION_MARK
    beq     a0, t0, _lexer_s11_consume
    li      t0, C_BACKSLASH
    beq     a0, t0, _lexer_s11_consume
    li      t0, C_SPECIAL
    beq     a0, t0, _lexer_s11_consume
    li      t0, C_N
    beq     a0, t0, _lexer_s11_consume
    li      t0, C_ZERO
    beq     a0, t0, _lexer_s11_consume

    j       _lexer_s15

_lexer_s11_consume:
    call    _lexer_consume
    j       _lexer_s9_loop

# state 12: symbol
_lexer_s12:
    call    _lexer_consume
    mv      s2, a0              # s2 = symbol character

    la      t0, token_tag
    sw      s2, 0(t0)           # token tag is the character itself

    # check for two-character operators
    li      t0, '='
    beq     s2, t0, _lexer_check_eq

    li      t0, '!'
    beq     s2, t0, _lexer_check_ne

    li      t0, '<'
    beq     s2, t0, _lexer_check_le

    li      t0, '>'
    beq     s2, t0, _lexer_check_ge

    li      t0, '('
    beq     s2, t0, _lexer_check_comment

    j       _lexer_s16

_lexer_check_eq:
    call    _next_character
    li      t0, '='
    beq     a0, t0, _lexer_eq_eq
    li      t0, '>'
    beq     a0, t0, _lexer_arrow
    j       _lexer_s16

_lexer_eq_eq:
    call    _lexer_consume
    la      t0, token_tag
    li      t1, T_EQ
    sw      t1, 0(t0)
    j       _lexer_s16

_lexer_arrow:
    call    _lexer_consume
    la      t0, token_tag
    li      t1, T_ARROW
    sw      t1, 0(t0)
    j       _lexer_s16

_lexer_check_ne:
    call    _next_character
    li      t0, '='
    bne     a0, t0, _lexer_s16
    call    _lexer_consume
    la      t0, token_tag
    li      t1, T_NE
    sw      t1, 0(t0)
    j       _lexer_s16

_lexer_check_le:
    call    _next_character
    li      t0, '='
    bne     a0, t0, _lexer_s16
    call    _lexer_consume
    la      t0, token_tag
    li      t1, T_LE
    sw      t1, 0(t0)
    j       _lexer_s16

_lexer_check_ge:
    call    _next_character
    li      t0, '='
    bne     a0, t0, _lexer_s16
    call    _lexer_consume
    la      t0, token_tag
    li      t1, T_GE
    sw      t1, 0(t0)
    j       _lexer_s16

# check for comment: (# ... #)
_lexer_check_comment:
    call    _next_character
    li      t0, '#'
    bne     a0, t0, _lexer_s16

    # it is a comment, skip it
    call    _lexer_skip # skip #
_lexer_comment_loop:
    call    _next_character
    li      t0, EOF
    beq     a0, t0, _unclosed_comment
    li      t0, '#'
    beq     a0, t0, _lexer_comment_hash
    call    _lexer_skip
    j       _lexer_comment_loop

_lexer_comment_hash:
    call    _lexer_skip # skip #
    call    _next_character
    li      t0, ')'
    beq     a0, t0, _lexer_comment_end
    li      t0, '#'
    beq     a0, t0, _lexer_comment_hash
    li      t0, EOF
    beq     a0, t0, _unclosed_comment
    call    _lexer_skip
    j       _lexer_comment_loop

_lexer_comment_end:
    call    _lexer_skip # skip )
    # check for trailing ;
    call    _next_character
    li      t0, ';'
    bne     a0, t0, _lexer_s0
    call    _lexer_skip
    j       _lexer_s0

# state 13: skip whitespace
_lexer_s13:
    call    _lexer_skip
    j       _lexer_s0

# state 14: EOF
_lexer_s14:
    la      t0, token_tag
    li      t1, T_END
    sw      t1, 0(t0)
    j       _lexer_s16

# state 15: error
_lexer_s15:
    call    _undefined_token

# state 16: accept token
_lexer_s16:
    call    _check_macro

    la      t0, token_tag
    lw      a0, 0(t0)

    lw      ra, 28(sp)
    lw      s0, 24(sp)
    lw      s1, 20(sp)
    lw      s2, 16(sp)
    lw      s3, 12(sp)
    addi    sp, sp, 32
    ret

# state 17: check reserved words
_lexer_s17:
    la      s2, reserved_words
    li      s3, 0               # index

_lexer_s17_loop:
    slli    t0, s3, 2
    add     t0, s2, t0
    lw      t1, 0(t0)           # load word pointer
    beqz    t1, _lexer_s17_not_reserved

    # compare with token_text
    la      a0, token_text
    mv      a1, t1
    call    _string_compare
    li      t0, 1
    beq     a0, t0, _lexer_s17_found

    addi    s3, s3, 1
    j       _lexer_s17_loop

_lexer_s17_found:
    # token_tag = RESERVED_WORDS_ID_BEGIN + index
    addi    s3, s3, RESERVED_WORDS_ID_BEGIN
    la      t0, token_tag
    sw      s3, 0(t0)
    j       _lexer_s16

_lexer_s17_not_reserved:
    la      t0, token_tag
    li      t1, T_IDENTIFIER
    sw      t1, 0(t0)
    j       _lexer_s16

# state 19: p or x variable
_lexer_s19:
    call    _lexer_consume
    mv      s2, a0              # s2 = 'p' or 'x'

    # check what type of variable
    li      t0, 'p'
    beq     s2, t0, _lexer_s19_parameter
    # must be 'x'
    la      t0, token_tag
    li      t1, T_VARIABLE
    sw      t1, 0(t0)
    j       _lexer_s19_continue

_lexer_s19_parameter:
    la      t0, token_tag
    li      t1, T_PARAMETER
    sw      t1, 0(t0)

_lexer_s19_continue:
    la      t0, token_value
    sw      zero, 0(t0)

    call    _lexer_lookahead
    li      t0, C_ZERO
    beq     a0, t0, _lexer_s20
    li      t0, C_NONZERO
    beq     a0, t0, _lexer_s20

    # not a variable, it is an identifier
    j       _lexer_s3

# state 20: variable number
_lexer_s20:
    call    _lexer_consume
    mv      s2, a0

    # token_value = token_value * 10 + (digit - '0')
    la      t0, token_value
    lw      t1, 0(t0)
    li      t2, 10
    mul     t1, t1, t2
    addi    s2, s2, -'0'
    add     t1, t1, s2
    sw      t1, 0(t0)

    call    _lexer_lookahead
    li      t0, C_ZERO
    beq     a0, t0, _lexer_s20
    li      t0, C_NONZERO
    beq     a0, t0, _lexer_s20

    # check if followed by letter (would be identifier)
    li      t0, C_NORMAL
    beq     a0, t0, _lexer_s3
    li      t0, C_SPECIAL
    beq     a0, t0, _lexer_s3
    li      t0, C_N
    beq     a0, t0, _lexer_s3
    li      t0, C_P_OR_X
    beq     a0, t0, _lexer_s3

    j       _lexer_s16

_lexer_return_unput:
    la      t0, unput
    sw      zero, 0(t0)
    la      t0, token_tag
    lw      a0, 0(t0)

    lw      ra, 28(sp)
    lw      s0, 24(sp)
    lw      s1, 20(sp)
    lw      s2, 16(sp)
    lw      s3, 12(sp)
    addi    sp, sp, 32
    ret

# check if identifier is a macro (uppercase)
_check_macro:
    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, T_IDENTIFIER
    bne     t1, t2, 1f

    # check first character
    la      t0, token_text
    lbu     t1, 0(t0)
    li      t2, 'Z'
    bgt     t1, t2, 1f          # > 'Z', not uppercase
    li      t2, 'A'
    blt     t1, t2, 1f          # < 'A', not uppercase

    # it is a macro
    la      t0, token_tag
    li      t1, T_MACRO
    sw      t1, 0(t0)
1:
    ret


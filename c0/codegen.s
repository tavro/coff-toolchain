#
# source code written by tyson horvath (tavro)
# for the c0 programming language (RISC-V implementation)
#
# this emits RISC-V assembly output
#

.include "constants.s"
.include "token.s"

.data

.equ DATA_AREA,   0
.equ RODATA_AREA, 1
.equ TEXT_AREA,   2

area: .word TEXT_AREA

label_id_generation: .word 0

.section .rodata

area_text: .word data_text, rodata_text, text_text
data_text:    .string ".data\n"
rodata_text:  .string ".section .rodata\n"
text_text:    .string ".text\n"

global_text:  .string ".global "
comm_text:    .string ".comm "
word_text:    .string ".word "
string_text:  .string ".string "
equ_text:     .string ".equ "
include_text: .string ".include "

ret_text:     .string "\tret"
li_text:      .string "\tli "
la_text:      .string "\tla "
mv_text:      .string "\tmv "
lw_text:      .string "\tlw "
sw_text:      .string "\tsw "
lb_text:      .string "\tlb "
sb_text:      .string "\tsb "
add_text:     .string "\tadd "
addi_text:    .string "\taddi "
sub_text:     .string "\tsub "
mul_text:     .string "\tmul "
div_text:     .string "\tdiv "
rem_text:     .string "\trem "
neg_text:     .string "\tneg "
and_text:     .string "\tand "
or_text:      .string "\tor "
xor_text:     .string "\txor "
not_text:     .string "\tnot "
slt_text:     .string "\tslt "
sltu_text:    .string "\tsltu "
seqz_text:    .string "\tseqz "
snez_text:    .string "\tsnez "
call_text:    .string "\tcall "
j_text:       .string "\tj "
jr_text:      .string "\tjr "
beqz_text:    .string "\tbeqz "
bnez_text:    .string "\tbnez "
beq_text:     .string "\tbeq "
bne_text:     .string "\tbne "
blt_text:     .string "\tblt "
bge_text:     .string "\tbge "
ecall_text:   .string "\tecall"
jalr_text:    .string "\tjalr "

a0_text:      .string "a0"
a1_text:      .string "a1"
a2_text:      .string "a2"
a3_text:      .string "a3"
a4_text:      .string "a4"
a5_text:      .string "a5"
a6_text:      .string "a6"
a7_text:      .string "a7"
t0_text:      .string "t0"
t1_text:      .string "t1"
t2_text:      .string "t2"
t3_text:      .string "t3"
t4_text:      .string "t4"
t5_text:      .string "t5"
t6_text:      .string "t6"
s0_text:      .string "s0"
s1_text:      .string "s1"
s2_text:      .string "s2"
s3_text:      .string "s3"
sp_text:      .string "sp"
ra_text:      .string "ra"
zero_text:    .string "zero"

lbl_text:     .string "_lbl"

.text

#######################
# label id generation #
#######################

# int _new_label_id(void)
.global _new_label_id
_new_label_id:
    la      t0, label_id_generation
    lw      a0, 0(t0)
    addi    t1, a0, 1
    sw      t1, 0(t0)
    ret

###################
# area management #
###################

# void _change_area(int area)
_change_area:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    sw      a0, 4(sp)
    addi    s0, sp, 16

    la      t0, area
    lw      t1, 0(t0)
    beq     a0, t1, 1f  # already in this area

    sw      a0, 0(t0)   # update current area

    # print area directive
    la      t0, area_text
    slli    t1, a0, 2
    add     t0, t0, t1
    lw      a0, 0(t0)
    call    _put_string

1:
    lw      ra, 12(sp)
    lw      s0, 8(sp)
    addi    sp, sp, 16
    ret

.global _enter_data_area, _enter_rodata_area, _enter_text_area

_enter_data_area:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    li      a0, DATA_AREA
    call    _change_area
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_enter_rodata_area:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    li      a0, RODATA_AREA
    call    _change_area
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_enter_text_area:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    li      a0, TEXT_AREA
    call    _change_area
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

##################################
# symbol and identifier checking #
##################################

.section .rodata
error_message: .string "ERROR: syntax error\n"
.text

# void _symbol(int expected)
# check that current token matches expected symbol
.global _symbol
_symbol:
    la      t0, token_tag
    lw      t1, 0(t0)
    beq     a0, t1, 1f
    j       _syntax_error
1:
    ret

# void _identifier(void)
# check that current token is an identifier
.global _identifier
_identifier:
    la      t0, token_tag
    lw      t1, 0(t0)
    li      t2, T_IDENTIFIER
    beq     t1, t2, 1f
    j       _syntax_error
1:
    ret

# void _syntax_error(void)
.global _syntax_error
_syntax_error:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _flush
    la      t0, source_line_number
    lw      a0, 0(t0)
    call    _put_number
    li      a0, ':'
    call    _put_character
    la      a0, error_message
    call    _put_string
    call    _flush
    li      a0, 1
    call    _exit

######################################
# stack operations (push/pop via sp) #
######################################

# void _push_a0(void)
# emit: addi sp, sp, -4; sw a0, 0(sp)
.global _push_a0
_push_a0:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    la      a0, addi_text
    call    _put_string
    la      a0, sp_text
    call    _put_string
    call    _comma
    la      a0, sp_text
    call    _put_string
    call    _comma
    li      a0, '-'
    call    _put_character
    li      a0, 4
    call    _put_number
    call    _new_line

    la      a0, sw_text
    call    _put_string
    la      a0, a0_text
    call    _put_string
    call    _comma
    li      a0, '0'
    call    _put_character
    li      a0, '('
    call    _put_character
    la      a0, sp_text
    call    _put_string
    li      a0, ')'
    call    _put_character
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# void _pop_t0(void)
# emit: lw t0, 0(sp); addi sp, sp, 4
.global _pop_t0
_pop_t0:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    la      a0, lw_text
    call    _put_string
    la      a0, t0_text
    call    _put_string
    call    _comma
    li      a0, '0'
    call    _put_character
    li      a0, '('
    call    _put_character
    la      a0, sp_text
    call    _put_string
    li      a0, ')'
    call    _put_character
    call    _new_line

    la      a0, addi_text
    call    _put_string
    la      a0, sp_text
    call    _put_string
    call    _comma
    la      a0, sp_text
    call    _put_string
    call    _comma
    li      a0, 4
    call    _put_number
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# void _pop_t1(void)
.global _pop_t1
_pop_t1:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    la      a0, lw_text
    call    _put_string
    la      a0, t1_text
    call    _put_string
    call    _comma
    li      a0, '0'
    call    _put_character
    li      a0, '('
    call    _put_character
    la      a0, sp_text
    call    _put_string
    li      a0, ')'
    call    _put_character
    call    _new_line

    la      a0, addi_text
    call    _put_string
    la      a0, sp_text
    call    _put_string
    call    _comma
    la      a0, sp_text
    call    _put_string
    call    _comma
    li      a0, 4
    call    _put_number
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

################
# instructions #
################

.global _li, _la, _mv, _lw, _sw, _lb, _sb
.global _add, _addi, _sub, _mul, _div, _rem, _neg
.global _and, _or, _xor, _not
.global _slt, _sltu, _seqz, _snez
.global _call, _j, _jr, _beqz, _bnez, _beq, _bne, _blt, _bge
.global _ret, _ecall, _jalr

_li:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, li_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_la:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, la_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_mv:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, mv_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_lw:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, lw_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_sw:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, sw_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_lb:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, lb_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_sb:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, sb_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_add:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, add_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_addi:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, addi_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_sub:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, sub_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_mul:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, mul_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_div:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, div_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_rem:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, rem_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_neg:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, neg_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_and:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, and_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_or:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, or_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_xor:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, xor_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_not:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, not_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_slt:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, slt_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_sltu:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, sltu_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_seqz:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, seqz_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_snez:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, snez_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_call:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, call_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_j:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, j_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_jr:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, jr_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_beqz:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, beqz_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_bnez:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, bnez_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_beq:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, beq_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_bne:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, bne_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_blt:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, blt_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_bge:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, bge_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_ret:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, ret_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_ecall:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, ecall_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_jalr:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, jalr_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

##################
# register names #
##################

.global _a0, _a1, _a2, _a3, _a4, _a5, _a6, _a7
.global _t0, _t1, _t2, _t3, _t4, _t5, _t6
.global _s0, _s1, _s2, _s3, _sp, _ra, _zero

_a0:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, a0_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_a1:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, a1_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_a2:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, a2_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_a3:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, a3_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_a4:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, a4_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_a5:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, a5_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_a6:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, a6_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_a7:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, a7_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_t0:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, t0_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_t1:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, t1_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_t2:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, t2_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_t3:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, t3_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_t4:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, t4_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_t5:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, t5_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_t6:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, t6_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_s0:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, s0_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_s1:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, s1_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_s2:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, s2_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_s3:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, s3_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_sp:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, sp_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_ra:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, ra_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_zero:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, zero_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

##############################
# function prologue/epilogue #
##############################

# void _set_frame(void)
# emit function prologue: save ra, s0 and argument registers
# frame layout (96 bytes total):
#   92(sp) = ra
#   88(sp) = s0 (old frame pointer)
#   84(sp) = saved a0 (p0)   -> 8(s0)
#   80(sp) = saved a1 (p1)   -> 12(s0)
#   76(sp) = saved a2 (p2)   -> 16(s0)
#   72(sp) = saved a3 (p3)   -> 20(s0)
#   68(sp) = saved a4 (p4)   -> 24(s0)
#   64(sp) = saved a5 (p5)   -> 28(s0)
#   60(sp) = saved a6 (p6)   -> 32(s0)
#   56(sp) = saved a7 (p7)   -> 36(s0)
#   52(sp) to 0(sp) = local variables (x0 to x12)
# s0 points to sp+96, so positive offsets access saved args
# formula for pvar(n): (n+2)*4(s0) -> p0=8(s0), p1=12(s0), etc.
.global _set_frame
_set_frame:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    # addi sp, sp, -96
    call    _addi
    call    _sp
    call    _comma
    call    _sp
    call    _comma
    li      a0, '-'
    call    _put_character
    li      a0, 96
    call    _put_number
    call    _new_line

    # sw ra, 92(sp)
    call    _sw
    call    _ra
    call    _comma
    li      a0, 92
    call    _put_number
    li      a0, '('
    call    _put_character
    call    _sp
    li      a0, ')'
    call    _put_character
    call    _new_line

    # sw s0, 88(sp)
    call    _sw
    call    _s0
    call    _comma
    li      a0, 88
    call    _put_number
    li      a0, '('
    call    _put_character
    call    _sp
    li      a0, ')'
    call    _put_character
    call    _new_line

    # addi s0, sp, 96
    call    _addi
    call    _s0
    call    _comma
    call    _sp
    call    _comma
    li      a0, 96
    call    _put_number
    call    _new_line

    # sw a0, -12(s0) -> parameter p0
    call    _sw
    call    _a0
    call    _comma
    li      a0, '-'
    call    _put_character
    li      a0, 12
    call    _put_number
    li      a0, '('
    call    _put_character
    call    _s0
    li      a0, ')'
    call    _put_character
    call    _new_line

    # sw a1, -16(s0) -> parameter p1
    call    _sw
    call    _a1
    call    _comma
    li      a0, '-'
    call    _put_character
    li      a0, 16
    call    _put_number
    li      a0, '('
    call    _put_character
    call    _s0
    li      a0, ')'
    call    _put_character
    call    _new_line

    # sw a2, -20(s0) -> parameter p2
    call    _sw
    call    _a2
    call    _comma
    li      a0, '-'
    call    _put_character
    li      a0, 20
    call    _put_number
    li      a0, '('
    call    _put_character
    call    _s0
    li      a0, ')'
    call    _put_character
    call    _new_line

    # sw a3, -24(s0) -> parameter p3
    call    _sw
    call    _a3
    call    _comma
    li      a0, '-'
    call    _put_character
    li      a0, 24
    call    _put_number
    li      a0, '('
    call    _put_character
    call    _s0
    li      a0, ')'
    call    _put_character
    call    _new_line

    # sw a4, -28(s0) -> parameter p4
    call    _sw
    call    _a4
    call    _comma
    li      a0, '-'
    call    _put_character
    li      a0, 28
    call    _put_number
    li      a0, '('
    call    _put_character
    call    _s0
    li      a0, ')'
    call    _put_character
    call    _new_line

    # sw a5, -32(s0) -> parameter p5
    call    _sw
    call    _a5
    call    _comma
    li      a0, '-'
    call    _put_character
    li      a0, 32
    call    _put_number
    li      a0, '('
    call    _put_character
    call    _s0
    li      a0, ')'
    call    _put_character
    call    _new_line

    # sw a6, -36(s0) -> parameter p6
    call    _sw
    call    _a6
    call    _comma
    li      a0, '-'
    call    _put_character
    li      a0, 36
    call    _put_number
    li      a0, '('
    call    _put_character
    call    _s0
    li      a0, ')'
    call    _put_character
    call    _new_line

    # sw a7, -40(s0) -> parameter p7
    call    _sw
    call    _a7
    call    _comma
    li      a0, '-'
    call    _put_character
    li      a0, 40
    call    _put_number
    li      a0, '('
    call    _put_character
    call    _s0
    li      a0, ')'
    call    _put_character
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# void _end_frame(void)
# emit function epilogue: restore ra and s0
.global _end_frame
_end_frame:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    # lw ra, 92(sp)
    call    _lw
    call    _ra
    call    _comma
    li      a0, 92
    call    _put_number
    li      a0, '('
    call    _put_character
    call    _sp
    li      a0, ')'
    call    _put_character
    call    _new_line

    # lw s0, 88(sp)
    call    _lw
    call    _s0
    call    _comma
    li      a0, 88
    call    _put_number
    li      a0, '('
    call    _put_character
    call    _sp
    li      a0, ')'
    call    _put_character
    call    _new_line

    # addi sp, sp, 96
    call    _addi
    call    _sp
    call    _comma
    call    _sp
    call    _comma
    li      a0, 96
    call    _put_number
    call    _new_line

    # ret
    call    _ret
    call    _new_line

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

#############
# variables #
#############

# void _xvar(int n)
# Eemit reference to local variable: offset(s0)
# frame layout: ra at -4(s0), saved s0 at -8(s0), params p0-p7 at -12 to -40(s0)
# locals start at -44(s0): x0 at -44(s0), x1 at -48(s0), etc.
.global _xvar
_xvar:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      a0, 8(sp)

    # negative offset from s0: -((n+11)*4)
    # this skips over ra (-4), saved s0 (-8), and 8 params (-12 to -40)
    lw      t0, 8(sp)
    addi    t0, t0, 11
    li      t1, 4
    mul     t0, t0, t1
    neg     t0, t0

    mv      a0, t0
    call    _put_number
    li      a0, '('
    call    _put_character
    call    _s0
    li      a0, ')'
    call    _put_character

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# void _pvar(int n)
# emit reference to parameter variable
# parameters are saved at negative offsets from s0:
# p0 at -12(s0), p1 at -16(s0), etc.
# formula: -((n+3)*4)
.global _pvar
_pvar:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      a0, 8(sp)

    # negative offset from s0: -((n+3)*4)
    lw      t0, 8(sp)
    addi    t0, t0, 3
    li      t1, 4
    mul     t0, t0, t1
    neg     t0, t0

    mv      a0, t0
    call    _put_number
    li      a0, '('
    call    _put_character
    call    _s0
    li      a0, ')'
    call    _put_character

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

#############
# constants #
#############

# void _integer(int n)
# emit integer constant
.global _integer
_integer:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    _put_number

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

##########
# labels #
##########

# void _label(int id)
# emit label reference: _lblN
.global _label
_label:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      a0, 8(sp)

    la      a0, lbl_text
    call    _put_string
    lw      a0, 8(sp)
    call    _put_number

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# void _label_definition(int id)
# emit label definition: _lblN:
.global _label_definition
_label_definition:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      a0, 8(sp)

    lw      a0, 8(sp)
    call    _label
    li      a0, ':'
    call    _put_character

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# void _label_address(int id)
# emit label address
.global _label_address
_label_address:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      a0, 8(sp)

    lw      a0, 8(sp)
    call    _label

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

##############
# directives #
##############

.global _dot_word, _dot_string, _dot_global, _dot_comm, _dot_equ, _dot_include

_dot_word:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, word_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_dot_string:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, string_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_dot_global:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, global_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_dot_comm:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, comm_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_dot_equ:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, equ_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_dot_include:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a0, include_text
    call    _put_string
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

######################
# formatting helpers #
######################

.global _comma, _space, _tab, _new_line

_comma:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    li      a0, ','
    call    _put_character
    li      a0, ' '
    call    _put_character
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_space:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    li      a0, ' '
    call    _put_character
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_tab:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    li      a0, '\t'
    call    _put_character
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

_new_line:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    li      a0, '\n'
    call    _put_character
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret


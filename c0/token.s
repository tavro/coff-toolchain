#
# source code written by tyson horvath (tavro)
# for the c0 programming language (RISC-V implementation)
#

.equ T_INTEGER,        256
.equ T_STRING,         257

.equ T_IDENTIFIER,     258
.equ T_MACRO,          259
.equ T_VARIABLE,       260
.equ T_PARAM,          261

.equ T_IF,             262
.equ T_ELSE,           263
.equ T_WHILE,          264

.equ T_GOTO,           265
.equ T_LABEL,          266

.equ T_RETURN,         267
.equ T_SYSTEM_CALL,    268

.equ T_EXPORT,         269
.equ T_ALLOCATE,       270
.equ T_INCLUDE,        271

.equ T_WRITE,          272
.equ T_READ,           273

.equ T_INTEGER_TYPE,   274
.equ T_CHARACTER_TYPE, 275

.equ T_EQ,             276
.equ T_NE,             277
.equ T_LE,             278
.equ T_GE,             279

.equ T_ARROW,          280

.equ T_END,            281

.equ MAX_TOKEN_LENGTH, 512


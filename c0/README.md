# the c0 programming language

c0 is a minimal programming language implemented in RISC-V assembly. it compiles c0 source code to RISC-V assembly and it is designed to run on QEMU's virt machine without any operating system (although, it is no coincidence that both moonshot and c0 are targeting RISC-V, i plan to use this to write parts of the kernel for my operating system moonshot).

this is a stage-0 bootstrap compiler, the lowest level of a self-hosting compiler chain. it is inspired by [rowl0](https://github.com/nineties/amber/tree/master/rowl0) but targets RISC-V instead of x86.

## language overview

### basic syntax

```
# function definition
main: (p0, p1) {
    x0 = p0 + p1;
    return x0
}

# variable declaration with initial value
counter: 0

# array declaration
buffer: [1, 2, 3, 4, 5]

# dynamic array
data: integer[100]

# character array
text: character[256]
```

### variables

c0 uses positional variable names:

- **parameters**: `p0`, `p1`, `p2`, ... (function arguments)
- **locals**: `x0`, `x1`, `x2`, ... (local variables, stack-allocated)
- **globals**: named identifiers (e.g., `counter`, `buffer`)
- **macros**: UPPERCASE identifiers are compile-time constants

```
add: (p0, p1) {
    x0 = p0 + p1; # x0 is a local variable
    return x0
}

MAX_SIZE => 1024 # macro definition
```

### data types

c0 is untyped at runtime, everything is a machine word. the type annotations `integer` and `character` only affect array allocation size.

- `integer[N]` allocates Nx4 bytes
- `character[N]` allocates N bytes

### operators

| precedence | operators | description |
|------------|-----------|-------------|
| highest | `()`, `[]` | grouping, array index |
| | `*` (prefix) | dereference |
| | `&` | address of |
| | `-`, `+`, `~` | unary minus, plus, bitwise NOT |
| | `*`, `/`, `%` | multiply, divide, modulo |
| | `+`, `-` | add, subtract |
| | `<`, `>`, `<=`, `>=` | relational |
| | `==`, `!=` | equality |
| | `&` | bitwise AND |
| | `^` | bitwise XOR |
| lowest | `\|` | bitwise OR |

### control flow

```
# if statement
if (condition) {
    # then branch
}

# if-else
if (condition) {
    # then branch
} else {
    # else branch
}

# while loop
while (condition) {
    # loop body
}

# labels and goto
label myloop;
# ... code ...
goto myloop
```

### functions

```
# definition
factorial: (p0) {
    if (p0 <= 1) {
        return 1
    };
    x0 = p0 - 1;
    x1 = factorial(x0);
    return p0 * x1
}

# call
result = factorial(5)
```

### memory Operations

```
# array access
arr: [10, 20, 30]
x0 = arr[1]          # x0 = 20
arr[2] = 100         # arr[2] = 100

# pointer dereference
x0 = *ptr            # read from pointer
*ptr = 42            # write to pointer

# address of
ptr = &variable      # get address of variable
ptr = &p0            # get address of parameter

# character read/write (byte operations)
ch = rch(buffer, 0)  # read byte at buffer+0
wch(buffer, 0, 65)   # write byte 65 ('A') at buffer+0
```

### special statements

```
# export symbol (make globally visible)
export myfunction

# export multiple symbols
export(func1, func2, func3)

# stack allocation
allocate 100         # allocate 100 words on stack

# include another source file
include otherfile    # includes "otherfile.s"
```

### syscalls

syscalls will not work unless you implement a handler. the c0 compiler itself uses UART for I/O instead.


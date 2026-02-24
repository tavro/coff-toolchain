/*
 * source code written by tyson horvath (tavro)
 * for the c0 programming language (RISC-V implementation)
 */

OUTPUT_ARCH(riscv)
ENTRY(_start)

/* QEMU virt machine RAM starts at 0x80000000 */
MEMORY
{
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 64M
}

SECTIONS
{
    . = 0x80000000;

    .text : {
        *(.text.init)
        *(.text .text.*)
    } > RAM

    . = ALIGN(4);

    .rodata : {
        *(.rodata .rodata.*)
    } > RAM

    . = ALIGN(4);

    .data : {
        *(.data .data.*)
    } > RAM

    . = ALIGN(4);

    .bss : {
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        __bss_end = .;
    } > RAM

    . = ALIGN(4);

    /* stack grows down from end of allocated space */
    __stack_top = ORIGIN(RAM) + LENGTH(RAM);

    /DISCARD/ : {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
}


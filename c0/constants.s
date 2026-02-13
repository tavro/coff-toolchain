#
# source code written by tyson horvath (tavro)
# for the c0 programming language (RISC-V implementation)
#

.equ UART_BASE,     0x10000000  # QEMU virt machine UART base address

.equ UART_THR,      0x00        # THR = Transmit Holding Register (write)
.equ UART_RBR,      0x00        # RBR = Receive Buffer Register (read)
.equ UART_IER,      0x01        # IER = Interrupt Enable Register
.equ UART_FCR,      0x02        # FCR = FIFO Control Register (write)
.equ UART_ISR,      0x02        # ISR = Interrupt Status Register (read)
.equ UART_LCR,      0x03        # LCR = Line Control Register
.equ UART_MCR,      0x04        # MCR = Modem Control Register
.equ UART_LSR,      0x05        # LSR = Line Status Register
.equ UART_MSR,      0x06        # MSR = Modem Status Register
.equ UART_SCR,      0x07        # SCR = Scratch Register

.equ UART_LSR_DR,   0x01        # DR = Data Ready
.equ UART_LSR_THRE, 0x20        # THRE = Transmit Holding Register Empty

.equ RAM_BASE,      0x80000000
.equ STACK_SIZE,    0x10000     # 64KB stack

.equ NULL,          0
.equ EOF,           (-1)


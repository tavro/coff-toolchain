CROSS = riscv64-unknown-elf-

AS = $(CROSS)as
LD = $(CROSS)ld
OBJCOPY = $(CROSS)objcopy
OBJDUMP = $(CROSS)objdump

QEMU = qemu-system-riscv32

ASFLAGS = -march=rv32im -mabi=ilp32

LDFLAGS = -m elf32lriscv -T linker.ld -nostdlib

SRCS = main.s library/runtime.s lexer.s compiler.s codegen.s
OBJS = $(SRCS:.s=.o)

TARGET = c0c
TARGET_BIN = $(TARGET).bin

.PHONY: all clean run debug dump

all: $(TARGET) $(TARGET_BIN)

$(TARGET): $(OBJS) linker.ld
	$(LD) $(LDFLAGS) $(OBJS) -o $@

$(TARGET_BIN): $(TARGET)
	$(OBJCOPY) -O binary $< $@

main.o: main.s constants.s token.s
	$(AS) $(ASFLAGS) $< -o $@

library/runtime.o: library/runtime.s constants.s
	$(AS) $(ASFLAGS) $< -o $@

lexer.o: lexer.s constants.s token.s
	$(AS) $(ASFLAGS) $< -o $@

compiler.o: compiler.s constants.s token.s
	$(AS) $(ASFLAGS) $< -o $@

codegen.o: codegen.s constants.s token.s
	$(AS) $(ASFLAGS) $< -o $@

# use: (echo ""; cat your_code.c0) | make run
# or: make run < input.c0 (after adding leading newline to file)
# note: -serial stdio -display none works better than -nographic for piped input
# IMPORTANT: QEMU drops the first character from piped stdin. prefix input with a newline!
run: $(TARGET)
	$(QEMU) -machine virt -serial stdio -display none -bios none -kernel $<

debug: $(TARGET)
	$(QEMU) -machine virt -nographic -bios none -kernel $< -s -S

dump: $(TARGET)
	$(OBJDUMP) -d $< | less

clean:
	rm -f $(OBJS) $(TARGET) $(TARGET_BIN)

test: $(TARGET)
	@(echo ""; echo 'main: () { return 42 }') | $(QEMU) -machine virt -serial stdio -display none -bios none -kernel $<

# Определяем архитектуру системы автоматически
ARCH := $(shell uname -m)

ifeq ($(ARCH),x86_64)
    # Настройки для 64-битной системы
    ASM_FLAGS := -f elf64
    LD_FLAGS  := 
else
    # Настройки для 32-битной системы (i386, i686)
    ASM_FLAGS := -f elf32
    LD_FLAGS  := -m elf_i386
endif

all:
	nasm $(ASM_FLAGS) calc.asm -o calc.o
	ld $(LD_FLAGS) calc.o -o calc

clean:
	rm -f calc.o calc

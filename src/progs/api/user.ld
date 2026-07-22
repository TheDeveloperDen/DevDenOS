ENTRY(_start)

SECTIONS
{
  . = 0x4000000;

  .text : ALIGN(4096)
  {
    *(.text._start)
    *(.text*)
  }

  .rodata : ALIGN(4096)
  {
    *(.rodata*)
  }

  .data : ALIGN(4096)
  {
    *(.data*)
  }

  .bss : ALIGN(4096)
  {
    *(.bss*)
    *(COMMON)
  }
}

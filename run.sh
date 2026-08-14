set -e
mkdir -p out

WIN_BUILD=0
USE_CLANG=0

for arg in "$@"; do
if [[ "$arg" == "-win" ]]; then
WIN_BUILD=1
elif [[ "$arg" == "--clang" ]]; then
USE_CLANG=1
elif [[ "$arg" == "--gcc" ]]; then
USE_CLANG=0
fi
done

if [[ $USE_CLANG -eq 1 ]]; then
echo "Using Clang toolchain"
CC="clang --target=x86_64-unknown-elf -masm=intel -Wa,--noexecstack"
if command -v x86_64-elf-ld >/dev/null 2>&1; then
LD="x86_64-elf-ld -z noexecstack"
elif command -v ld.lld >/dev/null 2>&1; then
LD="ld.lld -m elf_x86_64 -z noexecstack"
else
LD="ld -m elf_x86_64 -z noexecstack"
fi
else
echo "Using GCC toolchain"
CC="x86_64-elf-gcc -Wa,--noexecstack"
LD="x86_64-elf-ld -z noexecstack"
fi

> src/kernel/globals.asm

nasm -I src/ -I out/ -e src/kernel/kernel.asm > out/processed.asm

tr -d '\r' < out/processed.asm | \
grep -o -E '^[a-zA-Z_][a-zA-Z0-9_]*(:|\s+(db|dw|dd|dq|resb|resw|resd|resq)\b)' | \
    sed -E 's/[:[:space:]].*//' | \
    sort -u | \
    awk '{print "global " $1}' > src/kernel/globals.asm


nasm -I src/ -fbin src/bootloader/bootloader.asm -o out/bootloader.bin
nasm -I src/ -fbin src/bootloader/2ndStage.asm -o out/2ndStage.bin

nasm -I src/ -fbin src/kernel/kernel.asm -o out/KERNEL.BIN

if [[ $WIN_BUILD -eq 1 ]]; then
# for windbg symbols
nasm -I src/ -f win64 -g -F cv8 src/kernel/kernel.asm -o out/kernel.obj

VS_DIR="/c/Program Files/Microsoft Visual Studio/18/Community"
MSVC_DIR=$(ls -d "${VS_DIR}/VC/Tools/MSVC"/* | tail -n 1)
MSVC_LINK="${MSVC_DIR}/bin/Hostx64/x64/link.exe"

MSYS2_ARG_CONV_EXCL="*" "$MSVC_LINK" /subsystem:native /entry:entry /base:0xF0000 /align:65536 /nodefaultlib /ignore:4108 /ignore:4281 /LARGEADDRESSAWARE:NO /out:out/KERNEL.EXE /debug /pdb:out/KERNEL.pdb out/kernel.obj

objcopy -O binary out/KERNEL.EXE out/KERNEL.BIN
fi

gcc -O2 tools/elf2dde.c -o out/elf2dde
nasm -f elf64 src/progs/api/crt0.asm -o out/crt0.o
$CC -c -g -ffreestanding -fno-pie -fno-stack-protector -m64 -I src/progs/api/ src/progs/api/devden.c -o out/devden.o

# programs
PROGRAMS=()
for prog_dir in src/progs/*/; do
if [[ -d "$prog_dir" ]]; then

prog_name=$(basename "$prog_dir")

if [[ "$prog_name" == "api" ]]; then
continue
fi

prog_asm="${prog_dir}${prog_name}.asm"
prog_c="${prog_dir}${prog_name}.c"

if [[ -f "$prog_asm" ]]; then

echo "Building program: $prog_name"

> "${prog_dir}globals.asm"
nasm -I "src/progs/$prog_name" -I out/ -I "$prog_dir" -e "$prog_asm" > "out/${prog_name}_processed.asm"

tr -d '\r' < "out/${prog_name}_processed.asm" | \
grep -o -E '^[a-zA-Z_][a-zA-Z0-9_]*(:|\s+(db|dw|dd|dq|resb|resw|resd|resq)\b)' | \
    sed -E 's/[:[:space:]].*//' | \
    sort -u | \
    awk '{print "global " $1}' > "${prog_dir}globals.asm"

nasm -I "src/progs/$prog_name" -I out/ -I "$prog_dir" -fbin "$prog_asm" -o "out/${prog_name}.dde"

if [[ $WIN_BUILD -eq 1 ]]; then
nasm -I "src/progs/$prog_name" -I out/ -I "$prog_dir" -f win64 -g -F cv8 "$prog_asm" -o "out/${prog_name}.obj"
MSYS2_ARG_CONV_EXCL="*" "$MSVC_LINK" /subsystem:native /entry:header /base:0x3Ff0000 /align:65536 /nodefaultlib /ignore:4108 /ignore:4281 /LARGEADDRESSAWARE:NO /out:"out/${prog_name}.exe" /debug /pdb:"out/${prog_name}.pdb" "out/${prog_name}.obj"
fi

PROGRAMS+=("$prog_name")

elif [[ -f "$prog_c" ]]; then

echo "Building C program: $prog_name"

$CC -c -g -ffreestanding -fno-pie -fno-stack-protector -m64 -I src/progs/api/ "$prog_c" -o "out/${prog_name}_c.o"
$LD -T src/progs/api/user.ld out/crt0.o out/devden.o "out/${prog_name}_c.o" -o "out/${prog_name}.elf"
./out/elf2dde "out/${prog_name}.elf" "out/${prog_name}.dde"

PROGRAMS+=("$prog_name")

fi
fi
done


# drivers
DRIVERS=()
for drv_dir in src/drivers/*/; do
if [[ -d "$drv_dir" ]]; then

drv_name=$(basename "$drv_dir")

if [[ "$drv_name" == "ata" ]]; then
continue
fi

drv_asm="${drv_dir}${drv_name}.asm"
if [[ -f "$drv_asm" ]]; then

echo "Building driver: $drv_name"

> "${drv_dir}globals.asm"

nasm -I "src/drivers/$drv_name" -I out/ -I "$drv_dir" -e "$drv_asm" > "out/${drv_name}_processed.asm"

tr -d '\r' < "out/${drv_name}_processed.asm" | \
grep -o -E '^[a-zA-Z_][a-zA-Z0-9_]*(:|\s+(db|dw|dd|dq|resb|resw|resd|resq)\b)' | \
    sed -E 's/[:[:space:]].*//' | \
    sort -u | \
    awk '{print "global " $1}' > "${drv_dir}globals.asm"

nasm -I "src/drivers/$drv_name" -I out/ -I "$drv_dir" -fbin "$drv_asm" -o "out/${drv_name}.dde"

if [[ $WIN_BUILD -eq 1 ]]; then
nasm -I "src/drivers/$drv_name" -I out/ -I "$drv_dir" -f win64 -g -F cv8 "$drv_asm" -o "out/${drv_name}.obj"
MSYS2_ARG_CONV_EXCL="*" "$MSVC_LINK" /subsystem:native /entry:header /base:0xF0000 /align:65536 /nodefaultlib /ignore:4108 /ignore:4281 /LARGEADDRESSAWARE:NO /out:"out/${drv_name}.exe" /debug /pdb:"out/${drv_name}.pdb" "out/${drv_name}.obj"
fi

DRIVERS+=("$drv_name")

fi
fi
done

# shared libs
SLIBS=()
for sh_libs in src/libs/*/; do
if [[ -d "$sh_libs" ]]; then
slib_name=$(basename "$sh_libs")
slib_asm="${sh_libs}${slib_name}.asm"

if [[ -f "$slib_asm" ]]; then
echo "Building shared library: $slib_name"

> "${sh_libs}globals.asm"
nasm -I "src/libs/$slib_name" -I out/ -I "$sh_libs" -e "$slib_asm" > "out/${slib_name}_processed.asm"

tr -d '\r' < "out/${slib_name}_processed.asm" | \
grep -o -E '^[a-zA-Z_][a-zA-Z0-9_]*(:|\s+(db|dw|dd|dq|resb|resw|resd|resq)\b)' | \
    sed -E 's/[:[:space:]].*//' | \
    sort -u | \
    awk '{print "global " $1}' > "${sh_libs}globals.asm"
nasm -I "src/libs/$slib_name" -I out/ -I "$sh_libs" -fbin "$slib_asm" -o "out/${slib_name}.dde"

if [[ $WIN_BUILD -eq 1 ]]; then
nasm -I "src/libs/$slib_name" -I out/ -I "$sh_libs" -f win64 -g -F cv8 "$slib_asm" -o "out/${slib_name}.obj"
MSYS2_ARG_CONV_EXCL="*" "$MSVC_LINK" /subsystem:native /entry:header /base:0xF0000 /align:65536 /nodefaultlib /ignore:4108 /ignore:4281 /LARGEADDRESSAWARE:NO /out:"out/${slib_name}.exe" /debug /pdb:"out/${slib_name}.pdb" "out/${slib_name}.obj"
fi

SLIBS+=("$slib_name")

fi
fi
done

dd if=/dev/zero of=out/devdenOS.img bs=1M count=48
mkfs.fat -F 32 out/devdenOS.img

mmd -i out/devdenOS.img ::/den
mmd -i out/devdenOS.img ::/den/cursors
mmd -i out/devdenOS.img ::/den/bin
mmd -i out/devdenOS.img ::/den/libs
mmd -i out/devdenOS.img ::/den/drivers

mcopy -i out/devdenOS.img out/KERNEL.BIN ::/KERNEL.BIN

# programs cpy
for prog_name in "${PROGRAMS[@]}"; do
mcopy -i out/devdenOS.img "out/$prog_name.dde" "::/den/bin/$prog_name.dde"
done

# drivers cpy
for drv_name in "${DRIVERS[@]}"; do
mcopy -i out/devdenOS.img "out/$drv_name.dde" "::/den/drivers/$drv_name.dde"
done

# shared libs cpy
for slib_name in "${SLIBS[@]}"; do
mcopy -i out/devdenOS.img "out/$slib_name.dde" "::/den/libs/$slib_name.dde"
done

# images cpy
mcopy -i out/devdenOS.img img/cursors/cursor.tga ::/den/cursors/cursor.tga
mcopy -i out/devdenOS.img img/cursors/icursor.tga ::/den/cursors/icursor.tga
mcopy -i out/devdenOS.img img/manul.tga ::/den/manul.tga

# configs cpy
mcopy -i out/devdenOS.img disp.cfg ::/den/disp.cfg

dd if=out/bootloader.bin of=out/devdenOS.img bs=1 count=3 conv=notrunc
dd if=out/bootloader.bin of=out/devdenOS.img bs=1 skip=93 seek=93 count=417 conv=notrunc

dd if=out/2ndStage.bin of=out/devdenOS.img bs=512 seek=2 conv=notrunc


qemu-system-x86_64 -m 2.5G -drive format=raw,file=out/devdenOS.img -display gtk -accel kvm -cpu host -serial stdio

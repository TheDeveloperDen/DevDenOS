set -e
mkdir -p out

nasm -I src/ -fbin src/bootloader/bootloader.asm -o out/bootloader.bin
nasm -I src/ -fbin src/bootloader/2ndStage.asm -o out/2ndStage.bin
nasm -I src/ -fbin src/kernel/kernel.asm -o out/KERNEL.BIN

# programs
PROGRAMS=()
for prog_dir in src/progs/*/; do
prog_asm="${prog_dir}$(basename "$prog_dir").asm"

if [[ -f "$prog_asm" ]]; then
prog_name=$(basename "$prog_asm" .asm)
nasm -I "src/progs/$prog_name" -fbin "$prog_asm" -o "out/$prog_name.dde"
PROGRAMS+=("$prog_name")
fi
done

# drivers
DRIVERS=()
for drv_dir in src/drivers/*/; do
drv_asm="${drv_dir}$(basename "$drv_dir").asm"

if [[ -f "$drv_asm" ]]; then
drv_name=$(basename "$drv_asm" .asm)
nasm -I "src/drivers/$drv_name" -fbin "$drv_asm" -o "out/$drv_name.dde"
DRIVERS+=("$drv_name")
fi
done

# shared libs
SLIBS=()
for sh_libs in src/libs/*/; do
slib_asm="${sh_libs}$(basename "$sh_libs").asm"

if [[ -f "$slib_asm" ]]; then
slib_name=$(basename "$slib_asm" .asm)
nasm -I "src/libs/$slib_name" -fbin "$slib_asm" -o "out/$slib_name.dde"
SLIBS+=("$slib_name")
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

dd if=out/bootloader.bin of=out/devdenOS.img bs=1 count=3 conv=notrunc
dd if=out/bootloader.bin of=out/devdenOS.img bs=1 skip=93 seek=93 count=417 conv=notrunc

dd if=out/2ndStage.bin of=out/devdenOS.img bs=512 seek=1 conv=notrunc


qemu-system-x86_64 -m 2.5G -drive format=raw,file=out/devdenOS.img -d int,cpu_reset -no-reboot -D qemu_crash.log

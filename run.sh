nasm -I src/ -fbin src/bootloader/bootloader.asm -o out/bootloader.bin
nasm -I src/ -fbin src/bootloader/2ndStage.asm -o out/2ndStage.bin

nasm -fbin src/kernel/kernel.asm -o out/KERNEL.BIN

dd if=/dev/zero of=out/devdenOS.img bs=1M count=48
mkfs.fat -F 32 out/devdenOS.img

mcopy -i out/devdenOS.img out/KERNEL.BIN ::/KERNEL.BIN

dd if=out/bootloader.bin of=out/devdenOS.img bs=1 count=3 conv=notrunc
dd if=out/bootloader.bin of=out/devdenOS.img bs=1 skip=93 seek=93 count=417 conv=notrunc

dd if=out/2ndStage.bin of=out/devdenOS.img bs=512 seek=1 conv=notrunc


qemu-system-x86_64 -m 128 -drive format=raw,file=out/devdenOS.img

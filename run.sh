nasm -fbin src/bootloader/bootloader.asm -o out/bootloader.bin

dd if=/dev/zero of=out/devdenOS.img bs=1M count=48
mkfs.fat -F 32 out/devdenOS.img

dd if=out/bootloader.bin of=out/devdenOS.img bs=1 count=3 conv=notrunc
dd if=out/bootloader.bin of=out/devdenOS.img bs=1 skip=93 seek=93 count=417 conv=notrunc

qemu-system-x86_64 -m 64 -drive format=raw,file=out/devdenOS.img

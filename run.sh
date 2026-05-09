nasm -I src/ -fbin src/bootloader/bootloader.asm -o out/bootloader.bin
nasm -I src/ -fbin src/bootloader/2ndStage.asm -o out/2ndStage.bin

nasm -I src/ -fbin src/kernel/kernel.asm -o out/KERNEL.BIN

nasm -fbin src/progs/example/example_prog.asm -o out/example.dde
nasm -fbin src/drivers/bga/bga.asm -o out/bga.dde

dd if=/dev/zero of=out/devdenOS.img bs=1M count=48
mkfs.fat -F 32 out/devdenOS.img

mcopy -i out/devdenOS.img out/KERNEL.BIN ::/KERNEL.BIN
mcopy -i out/devdenOS.img out/example.dde ::/example.dde

mcopy -i out/devdenOS.img out/bga.dde ::/bga.dde

dd if=out/bootloader.bin of=out/devdenOS.img bs=1 count=3 conv=notrunc
dd if=out/bootloader.bin of=out/devdenOS.img bs=1 skip=93 seek=93 count=417 conv=notrunc

dd if=out/2ndStage.bin of=out/devdenOS.img bs=512 seek=1 conv=notrunc


qemu-system-x86_64 -m 2.5G -drive format=raw,file=out/devdenOS.img -d int,cpu_reset -no-reboot -D qemu_crash.log

#ifndef DEVDEN_H
#define DEVDEN_H


#include <stddef.h>
#include <stdint.h>

void sys_exit(int status);
long sys_write(int fd, const void *buf, size_t count);
void *sys_mmap(void *addr, size_t num_pages, int prot, int flags);
long sys_unmap(void *addr, size_t num_pages);
long sys_get_driver(const char *name);
long sys_driver_invoke(long handle, long func, void *in, void *out);
long sys_load_driver(const char *filename);
long sys_read_file(const char *filename, void *buf);
long sys_write_file(const char *filename, const void *buf, size_t size);
long sys_spawn(const char *filename, int argc, char **argv);
void *sys_load_shlib(const char *filename);
void sys_get_cursor(uint64_t *x, uint64_t *y);
uint64_t sys_get_tid(void);
long sys_send_msg(uint64_t target_tid, const void *buf, size_t len);
long sys_recv_msg(uint64_t *sender_tid, void *dest_buf, size_t max_len);


#endif

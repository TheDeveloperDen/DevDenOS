#include "devden.h"

#if defined(__clang__)
#define ASM_START
#define ASM_END
#else
#define ASM_START ".intel_syntax noprefix\n\t"
#define ASM_END "\n\t.att_syntax prefix"
#endif

void sys_exit(int status) {
  asm volatile(
    ASM_START
    "mov rax, 1\n\t"
    "mov rdi, %q0\n\t"
    "int 0x81"
    ASM_END
    :
    : "r" ((long)status)
    : "rax", "rdi"
  );
  while (1);
}

long sys_write(int fd, const void *buf, size_t count) {
  long ret;
  asm volatile(
    ASM_START
    "mov rax, 2\n\t"
    "mov rdi, %q1\n\t"
    "mov rsi, %q2\n\t"
    "mov rdx, %q3\n\t"
    "int 0x81\n\t"
    "mov %q0, rax"
    ASM_END
    : "=r" (ret)
    : "r" ((long)fd), "r" (buf), "r" ((long)count)
    : "rax", "rdi", "rsi", "rdx"
  );
  return ret;
}

void *sys_mmap(void *addr, size_t num_pages, int prot, int flags) {
  void *ret;
  register void *r10 asm("r10") = (void *)(uintptr_t)flags;
  asm volatile(
    ASM_START
    "mov rax, 3\n\t"
    "mov rdi, %q1\n\t"
    "mov rsi, %q2\n\t"
    "mov rdx, %q3\n\t"
    "int 0x81\n\t"
    "mov %q0, rax"
    ASM_END
    : "=r" (ret)
    : "r" (addr), "r" ((long)num_pages), "r" ((long)prot), "r" (r10)
    : "rax", "rdi", "rsi", "rdx"
  );
  return ret;
}

long sys_unmap(void *addr, size_t num_pages) {
  long ret;
  asm volatile(
    ASM_START
    "mov rax, 4\n\t"
    "mov rdi, %q1\n\t"
    "mov rsi, %q2\n\t"
    "int 0x81\n\t"
    "mov %q0, rax"
    ASM_END
    : "=r" (ret)
    : "r" (addr), "r" ((long)num_pages)
    : "rax", "rdi", "rsi"
  );
  return ret;
}

long sys_get_driver(const char *name) {
  long ret;
  asm volatile(
    ASM_START
    "mov rax, 5\n\t"
    "mov rdi, %q1\n\t"
    "int 0x81\n\t"
    "mov %q0, rax"
    ASM_END
    : "=r" (ret)
    : "r" (name)
    : "rax", "rdi"
  );
  return ret;
}

long sys_driver_invoke(long handle, long func, void *in, void *out) {
  long ret;
  register void *r10 asm("r10") = out;
  asm volatile(
    ASM_START
    "mov rax, 6\n\t"
    "mov rdi, %q1\n\t"
    "mov rsi, %q2\n\t"
    "mov rdx, %q3\n\t"
    "int 0x81\n\t"
    "mov %q0, rax"
    ASM_END
    : "=r" (ret)
    : "r" (handle), "r" (func), "r" (in), "r" (r10)
    : "rax", "rdi", "rsi", "rdx"
  );
  return ret;
}

long sys_load_driver(const char *filename) {
  long ret;
  asm volatile(
    ASM_START
    "mov rax, 7\n\t"
    "mov rdi, %q1\n\t"
    "int 0x81\n\t"
    "mov %q0, rax"
    ASM_END
    : "=r" (ret)
    : "r" (filename)
    : "rax", "rdi"
  );
  return ret;
}

long sys_read_file(const char *filename, void *buf) {
  long ret;
  asm volatile(
    ASM_START
    "mov rax, 8\n\t"
    "mov rdi, %q1\n\t"
    "mov rsi, %q2\n\t"
    "int 0x81\n\t"
    "mov %q0, rax"
    ASM_END
    : "=r" (ret)
    : "r" (filename), "r" (buf)
    : "rax", "rdi", "rsi"
  );
  return ret;
}

long sys_write_file(const char *filename, const void *buf, size_t size) {
  long ret;
  asm volatile(
    ASM_START
    "mov rax, 9\n\t"
    "mov rdi, %q1\n\t"
    "mov rsi, %q2\n\t"
    "mov rdx, %q3\n\t"
    "int 0x81\n\t"
    "mov %q0, rax"
    ASM_END
    : "=r" (ret)
    : "r" (filename), "r" (buf), "r" ((long)size)
    : "rax", "rdi", "rsi", "rdx"
  );
  return ret;
}

long sys_spawn(const char *filename, int argc, char **argv) {
  long ret;
  asm volatile(
    ASM_START
    "mov rax, 10\n\t"
    "mov rdi, %q1\n\t"
    "mov rsi, %q2\n\t"
    "mov rdx, %q3\n\t"
    "int 0x81\n\t"
    "mov %q0, rax"
    ASM_END
    : "=r" (ret)
    : "r" (filename), "r" ((long)argc), "r" (argv)
    : "rax", "rdi", "rsi", "rdx"
  );
  return ret;
}

void *sys_load_shlib(const char *filename) {
  void *ret;
  asm volatile(
    ASM_START
    "mov rax, 11\n\t"
    "mov rdi, %q1\n\t"
    "int 0x81\n\t"
    "mov %q0, rax"
    ASM_END
    : "=r" (ret)
    : "r" (filename)
    : "rax", "rdi"
  );
  return ret;
}

void sys_get_cursor(uint64_t *x, uint64_t *y) {
  uint64_t rx, ry;
  asm volatile(
    ASM_START
    "mov rax, 12\n\t"
    "int 0x81\n\t"
    "mov %q0, rax\n\t"
    "mov %q1, rdx"
    ASM_END
    : "=r" (rx), "=r" (ry)
    :
    : "rax", "rdx"
  );
  if (x) *x = rx;
  if (y) *y = ry;
}

uint64_t sys_get_tid(void) {
  uint64_t ret;
  asm volatile(
    ASM_START
    "mov rax, 13\n\t"
    "int 0x81\n\t"
    "mov %q0, rax"
    ASM_END
    : "=r" (ret)
    :
    : "rax"
  );
  return ret;
}

long sys_send_msg(uint64_t target_tid, const void *buf, size_t len) {
  long ret;
  asm volatile(
    ASM_START
    "mov rax, 14\n\t"
    "mov rdi, %q1\n\t"
    "mov rsi, %q2\n\t"
    "mov rdx, %q3\n\t"
    "int 0x81\n\t"
    "mov %q0, rax"
    ASM_END
    : "=r" (ret)
    : "r" (target_tid), "r" (buf), "r" ((long)len)
    : "rax", "rdi", "rsi", "rdx"
  );
  return ret;
}

long sys_recv_msg(uint64_t *sender_tid, void *dest_buf, size_t max_len) {
  long ret;
  asm volatile(
    ASM_START
    "mov rax, 15\n\t"
    "mov rdi, %q1\n\t"
    "mov rsi, %q2\n\t"
    "mov rdx, %q3\n\t"
    "int 0x81\n\t"
    "mov %q0, rax"
    ASM_END
    : "=r" (ret)
    : "r" (sender_tid), "r" (dest_buf), "r" ((long)max_len)
    : "rax", "rdi", "rsi", "rdx"
  );
  return ret;
}


int ReadConIn(void *out_buf) {
  static long ps2_handle = -1;
  if (ps2_handle < 0) {
    ps2_handle = sys_get_driver("ps2");
    if (ps2_handle < 0) {
      ps2_handle = sys_load_driver("den/drivers/ps2.dde");
      if (ps2_handle < 0) return -1;
    }
  }

  key_event_t ev;
  while (1) {
    long res = sys_driver_invoke(ps2_handle, 4, NULL, &ev);
    if (res > 0) {
      if (out_buf) *(key_event_t *)out_buf = ev;

      if (ev.flags & 1) {
        if (ev.ascii != 0) return (int)(unsigned char)ev.ascii;

        return (int)ev.scancode | 0x100;
      }
    }
    asm volatile (
      ASM_START
      "int 0x80\n\t"
      ASM_END
      ::: "memory"
    );
  }
}

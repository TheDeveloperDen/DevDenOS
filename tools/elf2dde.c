#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ELF_MAGIC 0x464C457F
#define PT_LOAD 1

typedef struct {
  uint8_t e_ident[16];
  uint16_t e_type;
  uint16_t e_machine;
  uint32_t e_version;
  uint64_t e_entry;
  uint64_t e_phoff;
  uint64_t e_shoff;
  uint32_t e_flags;
  uint16_t e_ehsize;
  uint16_t e_phentsize;
  uint16_t e_phnum;
  uint16_t e_shentsize;
  uint16_t e_shnum;
  uint16_t e_shstrndx;
} Elf64_Ehdr;

typedef struct {
  uint32_t p_type;
  uint32_t p_flags;
  uint64_t p_offset;
  uint64_t p_vaddr;
  uint64_t p_paddr;
  uint64_t p_filesz;
  uint64_t p_memsz;
  uint64_t p_align;
} Elf64_Phdr;

#pragma pack(push, 1)
typedef struct {
  uint32_t magic;
  uint8_t major_ver;
  uint8_t minor_ver;
  uint16_t flags;
  uint64_t entry_point;
  uint64_t base_address;
  uint64_t image_size;
  uint32_t section_offset;
  uint16_t section_count;
  uint32_t optional_hdr_offset;
  uint32_t optional_hdr_size;
  uint16_t header_size;
  uint16_t arch;
  uint8_t reserved[14];
} DdeHeader;

typedef struct {
  uint64_t vaddr;
  uint64_t memsz;
  uint64_t file_offset;
  uint64_t filesz;
} DdeSection;
#pragma pack(pop)

int main(int argc, char **argv) {
  if (argc < 3) {
    fprintf(stderr, "Usage: %s <input.elf> <output.dde>\n", argv[0]);
    return 1;
  }

  FILE *in = fopen(argv[1], "rb");
  if (!in) {
    perror("Failed to open input ELF");
    return 1;
  }

  Elf64_Ehdr ehdr;
  if (fread(&ehdr, sizeof(ehdr), 1, in) != 1) {
    fprintf(stderr, "Failed to read ELF header\n");
    fclose(in);
    return 1;
  }

  if (*(uint32_t *)ehdr.e_ident != ELF_MAGIC || ehdr.e_ident[4] != 2) {
    fprintf(stderr, "Invalid ELF64 header\n");
    fclose(in);
    return 1;
  }

  fseek(in, ehdr.e_phoff, SEEK_SET);
  Elf64_Phdr *phdrs = malloc(sizeof(Elf64_Phdr) * ehdr.e_phnum);
  if (!phdrs ||
      fread(phdrs, sizeof(Elf64_Phdr), ehdr.e_phnum, in) != ehdr.e_phnum) {
    fprintf(stderr, "Failed to read program headers\n");
    fclose(in);
    free(phdrs);
    return 1;
  }

  uint16_t load_count = 0;
  uint64_t base_addr = UINT64_MAX;
  uint64_t max_addr = 0;

  for (uint16_t i = 0; i < ehdr.e_phnum; i++) {
    if (phdrs[i].p_type == PT_LOAD && phdrs[i].p_memsz > 0) {
      load_count++;
      if (phdrs[i].p_vaddr < base_addr)
        base_addr = phdrs[i].p_vaddr;
      uint64_t end = phdrs[i].p_vaddr + phdrs[i].p_memsz;
      if (end > max_addr)
        max_addr = end;
    }
  }

  if (load_count == 0) {
    fprintf(stderr, "No loadable segments found\n");
    fclose(in);
    free(phdrs);
    return 1;
  }

  uint64_t image_size = max_addr - base_addr;

  DdeHeader header;
  memset(&header, 0, sizeof(header));
  header.magic = 0x4E445644;
  header.major_ver = 1;
  header.minor_ver = 0;
  header.flags = 0;
  header.entry_point = ehdr.e_entry;
  header.base_address = base_addr;
  header.image_size = image_size;
  header.section_offset = sizeof(DdeHeader);
  header.section_count = load_count;
  header.header_size = sizeof(DdeHeader);
  header.arch = 0x8664;

  DdeSection *sections = malloc(sizeof(DdeSection) * load_count);
  uint64_t current_payload_offset =
      sizeof(DdeHeader) + (sizeof(DdeSection) * load_count);

  uint16_t s_idx = 0;
  for (uint16_t i = 0; i < ehdr.e_phnum; i++) {
    if (phdrs[i].p_type == PT_LOAD && phdrs[i].p_memsz > 0) {
      sections[s_idx].vaddr = phdrs[i].p_vaddr;
      sections[s_idx].memsz = phdrs[i].p_memsz;
      sections[s_idx].file_offset = current_payload_offset;
      sections[s_idx].filesz = phdrs[i].p_filesz;
      current_payload_offset += phdrs[i].p_filesz;
      s_idx++;
    }
  }

  FILE *out = fopen(argv[2], "wb");
  if (!out) {
    perror("Failed to open output file");
    fclose(in);
    free(phdrs);
    free(sections);
    return 1;
  }

  fwrite(&header, sizeof(header), 1, out);
  fwrite(sections, sizeof(DdeSection), load_count, out);

  s_idx = 0;
  for (uint16_t i = 0; i < ehdr.e_phnum; i++) {
    if (phdrs[i].p_type == PT_LOAD && phdrs[i].p_memsz > 0) {
      if (phdrs[i].p_filesz > 0) {
        uint8_t *buf = malloc(phdrs[i].p_filesz);
        fseek(in, phdrs[i].p_offset, SEEK_SET);
        fread(buf, 1, phdrs[i].p_filesz, in);
        fwrite(buf, 1, phdrs[i].p_filesz, out);
        free(buf);
      }
      s_idx++;
    }
  }

  fclose(in);
  fclose(out);
  free(phdrs);
  free(sections);
  return 0;
}

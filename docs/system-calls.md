# DevDenOS System Calls
DevDenOS provides the `int 81h` interrupt as a way to call the kernel to perform
certain operations. These range from process manipulation, driver tools, I/O,
memory management, and library tools.

Following is a table of all system calls, and information about each system call
in RAX order.

## System call Table
|    Syscall    | RAX |      RDI        |      RSI        |      RDX      |   R10    |
| ------------- | --- | --------------- | --------------- | ------------- | -------- |
| exit          | 1   | N/A             | N/A             | N/A           | N/A      |
| write         | 2   | fd              | buffer          | len           | N/A      |
| mmap          | 3   | virtual address | number of pages | prot          | flags    |
| unmap         | 4   | virtual address | number of pages | N/A           | N/A      |
| get_driver    | 5   | driver name     | N/A             | N/A           | N/A      |
| driver_invoke | 6   | handle          | function        | in buff       | out buff |
| load_driver   | 7   | filename        | N/A             | N/A           | N/A      |
| read_file     | 8   | filename        | buffer          | N/A           | N/A      |
| write_file    | 9   | filename        | buffer          | size          | N/A      |
| spawn         | 10  | filename        | argc            | argv          | N/A      |
| load_shlib    | 11  | filename        | N/A             | N/A           | N/A      |
| get_tid       | 13  | N/A             | N/A             | N/A           | N/A      |
| send_msg      | 14  | target tid      | msg buffer      | msg len       | N/A      |
| recv_msg      | 15  | ptr to store tid| dest buffer     | bytes to read | N/A      |

## 1 - exit
`void exit()`

`exit` destroys a process. It unmaps it's memory from RAM, and frees the virtual
memory associated with the program, preparing for another process to take the
space for itself.

When your program has completed, you must call `exit` for the OS to clean up
your program and continue functioning properly. If you do not call `exit`, the
OS will most likely crash. (Segmentation faults are WIP).

## 2 - write
> IMPORTANT! This function will change in the near future. Details below.

`void write(uint64_t fd, uint8_t* buffer, uint64_t len)`

`write` currently allows the programmer to print characters to the terminal. For
future compatibility, PLEASE use only `fd = 1`. The `buffer` parameter refers to
a pointer to a string of bytes read as ASCII. Ending the string with a newline
is encouraged. `len` is the count of bytes that write should print.

`write` will gain support for writing to files in the near future, as file
descriptors are introduced to the OS. Currently, it ignores the `fd` parameter,
but in the future a file descriptor of one will be equal to STDOUT, so it is
important to use `fd = 1` when printing to the terminal, lest your program break
an update or two from now.

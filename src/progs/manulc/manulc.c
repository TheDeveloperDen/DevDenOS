#include <devden.h>

int main(int argc, char **argv){
  for(unsigned long long i = 0; i < 44; i++){
    sys_write(0, "MANUL\n", 6);
  }

  //*(volatile long long*)0 = 5;

  return 0;
}

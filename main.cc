#include "libone_public_header.h"
#include "libtwo_public_header.h"

int main(int argc, char** argv) {
    const wchar_t *const format = libtwo_result();
    int magic_number = libone_result();
    wprintf(format, magic_number); 
}

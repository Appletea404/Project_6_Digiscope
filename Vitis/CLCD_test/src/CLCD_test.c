

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "CLCD.h"

int main()
{
    init_platform();

    clcd_init();



    while (1) {
        clcd_display();
    }


    cleanup_platform();
    return 0;
}

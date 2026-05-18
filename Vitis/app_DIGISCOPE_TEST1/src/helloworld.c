#include "def.h"
#include "app_digiscope.h"

int main(void)
{
    init_platform();

    App_Init();

    while (1)
    {
        App_Task();
    }

    cleanup_platform();

    return 0;
}
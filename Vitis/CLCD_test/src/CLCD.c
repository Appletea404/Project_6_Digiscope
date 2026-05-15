
#include "CLCD.h"

volatile unsigned int *clcd_cntr = (volatile unsigned int*) XPAR_CLCD_0_BASEADDR;

static void clcd_send(uint8_t data, uint8_t rs)
{
    clcd_cntr[1] = ((rs << 8) | data);

    clcd_cntr[0] = CLCD_SLAVE_ADDR;
    usleep(100);

    clcd_cntr[0] = (CLCD_SLAVE_ADDR | 0x80);   // send 상승 에지 트리거
    usleep(2000);

    clcd_cntr[0] = CLCD_SLAVE_ADDR;
}

void clcd_cmd(uint8_t cmd)
{
    clcd_send(cmd, 0);
}

void clcd_data(uint8_t data)
{
    clcd_send(data, 1);
}

void clcd_init(void)
{

    usleep(50000);                      // 전원 안정화 50ms


    clcd_cmd(0x33);          
    clcd_cmd(0x32);          // 초기화
    // 여기서부터 4bit
    clcd_cmd(0x28);          // Function Set: 4bit, 2줄, 5x8
    clcd_cmd(0x08);          // Display OFF
    clcd_cmd(0x01);          // Clear Display
    clcd_cmd(0x06);          // Entry Mode set : I/D = 1 S = 0
    clcd_cmd(0x0C);          // Display ON, 커서 OFF
}

void clcd_clear(void)
{
        clcd_cmd(0x01); 
}

void clcd_print(const char *str)
{
    while (*str)
        clcd_data((uint8_t)*str++);
}

void clcd_set_cursor(uint8_t row, uint8_t col)
{
    uint8_t addr = (row == 0) ? (0x80 | col) : (0xC0 | col);
    clcd_cmd(addr);
}

void clcd_display(void)
{
    int a = 20;
    int b = 30;
    char buf[16];
    
    clcd_set_cursor(0, 0);
    clcd_clear();
    sprintf(buf, "a = %d b = %d", a, b);
    clcd_print(buf);
    clcd_set_cursor(1, 0);
    sprintf(buf, "a + b = %d", a + b);
    clcd_print(buf);

    sleep(5);

    clcd_set_cursor(0, 0);
    clcd_clear();

    clcd_print("HELLO");
    clcd_set_cursor(1, 0);
    clcd_print("HI CLCD");

    sleep(5);
}
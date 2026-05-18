
#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "sleep.h"

#define CLCD_SLAVE_ADDR (0x4E >> 1)
#define CLCD_BASEADDR   XPAR_CLCD_0_BASEADDR

void clcd_init(void);                                // 초기화 함수
void clcd_cmd(uint8_t cmd);                          // lcd 커맨드 함수
void clcd_data(uint8_t data);                        // lcd 데이터 함수
void clcd_print(const char *str);                    // lcd 출력 함수
void clcd_set_cursor(uint8_t row, uint8_t col);      // lcd 커서 함수
void clcd_clear(void);                               // lcd 초기화 함수
void clcd_display(void);                             // sprint buf[16]활용하여 정수형도 출력
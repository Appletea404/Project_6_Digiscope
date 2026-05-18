#ifndef PWM_H
#define PWM_H

#include "def.h"

//======================================================
// Clock 설정
//======================================================
#define PWM_CLK_FREQ_HZ     100000000U
#define PWM_COUNT_PER_US    100U

//======================================================
// AXI Register Map
//
// 현재 AXI wrapper 기준
//   reg0 : period_count write/read
//   reg1 : duty_count write/read
//   reg2 : current_period_count read-back
//   reg3 : current_duty_count read-back
//   reg4 : measured_period_count read
//   reg5 : measured_high_count read
//======================================================
#define REG_PERIOD_COUNT        0
#define REG_DUTY_COUNT          1
#define REG_CURRENT_PERIOD      2
#define REG_CURRENT_DUTY        3
#define REG_MEASURED_PERIOD     4
#define REG_MEASURED_HIGH       5

#define PWM_UART_BUF_SIZE       32

typedef struct {
    volatile u32 *regs;

    unsigned int period_us;
    unsigned int duty_percent;

    char uart_buf[PWM_UART_BUF_SIZE];
    unsigned int uart_idx;
} PWM_Handle;

void PWM_Init(PWM_Handle *pwm, UINTPTR baseaddr);
void PWM_ApplySetting(PWM_Handle *pwm);

int PWM_SetPeriodUs(PWM_Handle *pwm, unsigned int period_us);
int PWM_SetDutyPercent(PWM_Handle *pwm, unsigned int duty_percent);

void PWM_PrintSetting(PWM_Handle *pwm);
void PWM_PrintMeasured(PWM_Handle *pwm);
void PWM_PrintHelp(void);

void PWM_ProcessCommand(PWM_Handle *pwm, char *cmd);
void PWM_UartPolling(PWM_Handle *pwm, UINTPTR uart_baseaddr);

#endif
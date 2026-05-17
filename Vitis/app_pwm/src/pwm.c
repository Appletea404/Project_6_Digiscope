#include "pwm.h"

//======================================================
// 내부 함수: 문자열이 숫자인지 확인
//======================================================
static int is_decimal_string(const char *s)
{
    if (s == NULL || *s == '\0')
        return 0;

    while (*s) {
        if (*s < '0' || *s > '9')
            return 0;
        s++;
    }

    return 1;
}

//======================================================
// PWM 초기화
//======================================================
void PWM_Init(PWM_Handle *pwm, UINTPTR baseaddr)
{
    pwm->regs = (volatile u32 *)baseaddr;

    pwm->period_us = 1000;      // 기본값: 1000us = 1ms
    pwm->duty_percent = 50;     // 기본값: 50%

    pwm->uart_idx = 0;
    pwm->uart_buf[0] = '\0';

    PWM_ApplySetting(pwm);
}

//======================================================
// 현재 period_us, duty_percent 값을 바탕으로
// AXI register에 period_count, duty_count write
//======================================================
void PWM_ApplySetting(PWM_Handle *pwm)
{
    unsigned int period_count;
    unsigned int duty_count;

    period_count = pwm->period_us * PWM_COUNT_PER_US;
    duty_count = ((uint64_t)period_count * pwm->duty_percent) / 100U;

    pwm->regs[REG_PERIOD_COUNT] = period_count;
    pwm->regs[REG_DUTY_COUNT] = duty_count;

    PWM_PrintSetting(pwm);
}

//======================================================
// 주기 설정
//
// 입력 단위: us
// 예: p1000 → period_us = 1000
//======================================================
int PWM_SetPeriodUs(PWM_Handle *pwm, unsigned int period_us)
{
    if (period_us == 0) {
        xil_printf("\r\nPeriod must be greater than 0 us.\r\n");
        return -1;
    }

    pwm->period_us = period_us;
    PWM_ApplySetting(pwm);

    return 0;
}

//======================================================
// Duty 설정
//
// 입력 단위: percent
// 예: d50 → duty_percent = 50
//======================================================
int PWM_SetDutyPercent(PWM_Handle *pwm, unsigned int duty_percent)
{
    if (duty_percent > 100) {
        xil_printf("\r\nDuty range is 0 ~ 100.\r\n");
        return -1;
    }

    pwm->duty_percent = duty_percent;
    PWM_ApplySetting(pwm);

    return 0;
}

//======================================================
// 현재 설정값 출력
//======================================================
void PWM_PrintSetting(PWM_Handle *pwm)
{
    unsigned int period_count;
    unsigned int duty_count;

    period_count = pwm->regs[REG_PERIOD_COUNT];
    duty_count = pwm->regs[REG_DUTY_COUNT];

    xil_printf("\r\n[SETTING]\r\n");
    xil_printf("period_us                     = %u us\r\n", pwm->period_us);
    xil_printf("duty_percent                  = %u %%\r\n", pwm->duty_percent);

    xil_printf("readback slv_reg0 period_count = %u\r\n", period_count);
    xil_printf("readback slv_reg1 duty_count   = %u\r\n", duty_count);

    xil_printf("current_period_cnt_out         = %u\r\n",
               pwm->regs[REG_CURRENT_PERIOD]);
    xil_printf("current_duty_cnt_out           = %u\r\n",
               pwm->regs[REG_CURRENT_DUTY]);
}

//======================================================
// 측정값 출력
//
// Verilog에서는 period_count, high_count만 측정하고,
// duty, frequency 계산은 Vitis에서 처리
//======================================================
void PWM_PrintMeasured(PWM_Handle *pwm)
{
    unsigned int measured_period;
    unsigned int measured_high;

    unsigned int measured_period_us;
    unsigned int measured_high_us;
    unsigned int measured_duty;
    unsigned int measured_freq_hz;

    measured_period = pwm->regs[REG_MEASURED_PERIOD];
    measured_high = pwm->regs[REG_MEASURED_HIGH];

    measured_period_us = measured_period / PWM_COUNT_PER_US;
    measured_high_us = measured_high / PWM_COUNT_PER_US;

    if (measured_period != 0) {
        measured_duty = ((uint64_t)measured_high * 100U) / measured_period;
        measured_freq_hz = PWM_CLK_FREQ_HZ / measured_period;
    }
    else {
        measured_duty = 0;
        measured_freq_hz = 0;
    }

    xil_printf("\r\n[MEASURED]\r\n");
    xil_printf("period_count = %u\r\n", measured_period);
    xil_printf("high_count   = %u\r\n", measured_high);
    xil_printf("period       = %u us\r\n", measured_period_us);
    xil_printf("high         = %u us\r\n", measured_high_us);
    xil_printf("duty         = %u %%\r\n", measured_duty);
    xil_printf("frequency    = %u Hz\r\n", measured_freq_hz);
}

//======================================================
// 도움말 출력
//======================================================
void PWM_PrintHelp(void)
{
    xil_printf("\r\nCommands:\r\n");
    xil_printf("  p1000  : set period to 1000 us\r\n");
    xil_printf("  d50    : set duty to 50 %%\r\n");
    xil_printf("  s      : show measured values\r\n");
    xil_printf("  help   : show command list\r\n");
    xil_printf("\r\n");
    xil_printf("Note:\r\n");
    xil_printf("  sw[0] controls PWM enable.\r\n");
    xil_printf("  sw[0] = 1 : waveform output ON\r\n");
    xil_printf("  sw[0] = 0 : waveform output OFF\r\n");
}

//======================================================
// UART 명령 처리
//
// d50
// p1000
// s
// help
//======================================================
void PWM_ProcessCommand(PWM_Handle *pwm, char *cmd)
{
    unsigned int value;

    if (cmd == NULL || cmd[0] == '\0')
        return;

    if (cmd[0] == 'd' || cmd[0] == 'D') {
        if (!is_decimal_string(&cmd[1])) {
            xil_printf("\r\nInvalid duty command. Example: d50\r\n");
            return;
        }

        value = (unsigned int)strtoul(&cmd[1], NULL, 10);
        PWM_SetDutyPercent(pwm, value);
    }
    else if (cmd[0] == 'p' || cmd[0] == 'P') {
        if (!is_decimal_string(&cmd[1])) {
            xil_printf("\r\nInvalid period command. Example: p1000\r\n");
            return;
        }

        value = (unsigned int)strtoul(&cmd[1], NULL, 10);
        PWM_SetPeriodUs(pwm, value);
    }
    else if (cmd[0] == 's' || cmd[0] == 'S') {
        PWM_PrintMeasured(pwm);
    }
    else if (strcmp(cmd, "help") == 0 || strcmp(cmd, "HELP") == 0) {
        PWM_PrintHelp();
    }
    else {
        xil_printf("\r\nUnknown command: %s\r\n", cmd);
        xil_printf("Type help\r\n");
    }
}

//======================================================
// UART polling
//
// interrupt 없이 UART 수신 FIFO를 확인해서
// 문자가 들어오면 command buffer에 저장
//======================================================
void PWM_UartPolling(PWM_Handle *pwm, UINTPTR uart_baseaddr)
{
    while (!XUartLite_IsReceiveEmpty(uart_baseaddr)) {
        char c;

        c = XUartLite_RecvByte(uart_baseaddr);

        //--------------------------------------------------
        // moserial에서 Enter 입력 시 '\r' 또는 '\n' 수신
        //--------------------------------------------------
        if (c == '\r' || c == '\n') {
            if (pwm->uart_idx > 0) {
                pwm->uart_buf[pwm->uart_idx] = '\0';
                PWM_ProcessCommand(pwm, pwm->uart_buf);
                pwm->uart_idx = 0;
            }
        }
        //--------------------------------------------------
        // Backspace 처리
        //--------------------------------------------------
        else if (c == '\b' || c == 0x7F) {
            if (pwm->uart_idx > 0)
                pwm->uart_idx--;
        }
        //--------------------------------------------------
        // 일반 문자 저장
        //--------------------------------------------------
        else {
            if (pwm->uart_idx < PWM_UART_BUF_SIZE - 1) {
                pwm->uart_buf[pwm->uart_idx] = c;
                pwm->uart_idx++;
            }
            else {
                pwm->uart_idx = 0;
                pwm->uart_buf[0] = '\0';
                xil_printf("\r\nCommand too long. Buffer cleared.\r\n");
            }
        }
    }
}
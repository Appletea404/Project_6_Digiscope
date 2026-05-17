/******************************************************************************
* Copyright (C) 2023 Advanced Micro Devices, Inc. All Rights Reserved.
* SPDX-License-Identifier: MIT
******************************************************************************/
/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <stdio.h>

#include "platform.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "sleep.h"

#include "pwm.h"

//======================================================
// Base Address 설정
//
// xparameters.h에서 실제 이름 확인 필요
// 이름이 다르면 아래 define을 수정해야 함
//======================================================
#define PWM_BASEADDR    XPAR_MYIP_PWM_0_BASEADDR
#define UART_BASEADDR   XPAR_AXI_UARTLITE_0_BASEADDR

int main()
{
    PWM_Handle pwm;
    unsigned int loop_count;

    init_platform();

    loop_count = 0;

    xil_printf("\r\n========================================\r\n");
    xil_printf("PWM UART Control Start\r\n");
    xil_printf("Commands: d50, p1000, s, help\r\n");
    xil_printf("Enable waveform with sw[0].\r\n");
    xil_printf("========================================\r\n");

    PWM_Init(&pwm, PWM_BASEADDR);
    PWM_PrintHelp();

    while (1) {
        //--------------------------------------------------
        // UART polling
        //--------------------------------------------------
        PWM_UartPolling(&pwm, UART_BASEADDR);

        //--------------------------------------------------
        // 약 1초마다 측정값 자동 출력
        //
        // 출력이 너무 많으면 moserial이 복잡해지므로
        // 필요 없으면 이 부분을 주석 처리해도 됨
        //--------------------------------------------------
        if (loop_count >= 100) {
            PWM_PrintMeasured(&pwm);
            loop_count = 0;
        }

        loop_count++;
        usleep(10000);     // 10ms
    }

    cleanup_platform();
    return 0;
}
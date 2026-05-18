#ifndef TFT_LCD_H
#define TFT_LCD_H

#include "def.h"

/******************************************************************************
* TFT Logical Screen
*
* LCD 실제 방향  : 240 x 320
* SW 논리 방향   : 320 x 240
*
* Vitis에서는 320x240 가로 화면처럼 사용한다.
******************************************************************************/
#define TFT_WIDTH          320
#define TFT_HEIGHT         240

/******************************************************************************
* TFT AXI Register Map
******************************************************************************/
#define TFT_ADDR           XPAR_MYIP_TFT_LCD_CNTR_0_BASEADDR

#define TFT_REG_CTRL       0x00
#define TFT_REG_CMD        0x04
#define TFT_REG_X          0x08
#define TFT_REG_Y          0x0C
#define TFT_REG_COLOR      0x10

/******************************************************************************
* TFT Command
******************************************************************************/
#define TFT_CMD_FILL       1
#define TFT_CMD_PIXEL      2

/******************************************************************************
* TFT Status Bit
******************************************************************************/
#define TFT_BUSY_MASK      0x02
#define TFT_INIT_MASK      0x08

/******************************************************************************
* RGB565 Color
******************************************************************************/
#define TFT_RED            0xF800
#define TFT_GREEN          0x07E0
#define TFT_BLUE           0x001F

#define TFT_WHITE          0xFFFF
#define TFT_BLACK          0x0000

#define TFT_GRAY_DARK      0x4208
#define TFT_GRAY_LIGHT     0xC618

/******************************************************************************
* Oscilloscope Voltage Scale
******************************************************************************/
#define TFT_VDIV_1V        0
#define TFT_VDIV_3V3       1
#define TFT_VDIV_5V        2

/******************************************************************************
* Oscilloscope Time Scale
******************************************************************************/
#define TFT_TDIV_1MS       0
#define TFT_TDIV_2MS       1
#define TFT_TDIV_5MS       2

/******************************************************************************
* Basic TFT API
******************************************************************************/
void TFT_Init(void);

void TFT_Fill(u32 color);

void TFT_DrawPixel(
        u32 x,
        u32 y,
        u32 color);

void TFT_DrawHLine(
        u32 x,
        u32 y,
        u32 w,
        u32 color);

void TFT_DrawVLine(
        u32 x,
        u32 y,
        u32 h,
        u32 color);

void TFT_DrawRect(
        u32 x,
        u32 y,
        u32 w,
        u32 h,
        u32 color);

/******************************************************************************
* Oscilloscope UI API
******************************************************************************/
void TFT_DrawGrid(
        u32 bg_color,
        u32 grid_color,
        u32 axis_color);

void TFT_DrawScopeWave(
        u32 volt_div,
        u32 time_div,
        u32 wave_color,
        u32 zero_color);

#endif
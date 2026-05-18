#include "tft_lcd.h"

/******************************************************************************
* Scope Area
******************************************************************************/
#define SCOPE_X            10
#define SCOPE_Y            40
#define SCOPE_W            300
#define SCOPE_H            160

#define SCOPE_X_DIV        10
#define SCOPE_Y_DIV        8

#define SCOPE_X_PX_DIV     (SCOPE_W / SCOPE_X_DIV)
#define SCOPE_Y_PX_DIV     (SCOPE_H / SCOPE_Y_DIV)

/******************************************************************************
* Fixed Test Wave
******************************************************************************/
#define WAVE_HIGH_MV       3300
#define WAVE_LOW_MV        0
#define WAVE_PERIOD_US     10000
#define WAVE_DUTY          50

/******************************************************************************
* Internal Function
******************************************************************************/
static void TFT_WaitInit(void);
static void TFT_WaitBusy(void);
static void TFT_Start(void);

static u32 TFT_MvDiv(u32 div);
static u32 TFT_UsDiv(u32 div);
static u32 TFT_ZeroY(void);

static u32 TFT_VoltToY(s32 mv, u32 mv_div);
static u32 TFT_TimeToPx(u32 us, u32 us_div);

/******************************************************************************
* AXI Wait / Start
******************************************************************************/
static void TFT_WaitInit(void)
{
    while ((Xil_In32(TFT_ADDR + TFT_REG_CTRL) & TFT_INIT_MASK) == 0)
    {
        usleep(1000);
    }
}

static void TFT_WaitBusy(void)
{
    while (Xil_In32(TFT_ADDR + TFT_REG_CTRL) & TFT_BUSY_MASK)
    {
        usleep(100);
    }
}

static void TFT_Start(void)
{
    Xil_Out32(TFT_ADDR + TFT_REG_CTRL, 0);
    usleep(10);

    Xil_Out32(TFT_ADDR + TFT_REG_CTRL, 1);
    usleep(10);

    Xil_Out32(TFT_ADDR + TFT_REG_CTRL, 0);
    usleep(10);
}

/******************************************************************************
* TFT Basic
******************************************************************************/
void TFT_Init(void)
{
    TFT_WaitInit();
    TFT_WaitBusy();
}

void TFT_Fill(u32 color)
{
    TFT_WaitBusy();

    Xil_Out32(TFT_ADDR + TFT_REG_CMD, TFT_CMD_FILL);
    Xil_Out32(TFT_ADDR + TFT_REG_COLOR, color);

    TFT_Start();
    TFT_WaitBusy();
}

void TFT_DrawPixel(u32 x, u32 y, u32 color)
{
    u32 real_x;
    u32 real_y;

    if (x >= TFT_WIDTH || y >= TFT_HEIGHT)
        return;

    /*
     * 논리 320x240 -> 실제 240x320 회전 변환
     */
    real_x = y;
    real_y = (TFT_WIDTH - 1) - x;

    TFT_WaitBusy();

    Xil_Out32(TFT_ADDR + TFT_REG_CMD, TFT_CMD_PIXEL);
    Xil_Out32(TFT_ADDR + TFT_REG_X, real_x);
    Xil_Out32(TFT_ADDR + TFT_REG_Y, real_y);
    Xil_Out32(TFT_ADDR + TFT_REG_COLOR, color);

    TFT_Start();
    TFT_WaitBusy();
}

void TFT_DrawHLine(u32 x, u32 y, u32 w, u32 color)
{
    u32 i;

    for (i = 0; i < w; i++)
    {
        TFT_DrawPixel(x + i, y, color);
    }
}

void TFT_DrawVLine(u32 x, u32 y, u32 h, u32 color)
{
    u32 i;

    for (i = 0; i < h; i++)
    {
        TFT_DrawPixel(x, y + i, color);
    }
}

void TFT_DrawRect(u32 x, u32 y, u32 w, u32 h, u32 color)
{
    TFT_DrawHLine(x,         y,         w, color);
    TFT_DrawHLine(x,         y + h - 1, w, color);
    TFT_DrawVLine(x,         y,         h, color);
    TFT_DrawVLine(x + w - 1, y,         h, color);
}

/******************************************************************************
* Scope Scale
******************************************************************************/
static u32 TFT_MvDiv(u32 div)
{
    if (div == TFT_VDIV_1V)
        return 1000;

    if (div == TFT_VDIV_3V3)
        return 3300;

    return 5000;
}

static u32 TFT_UsDiv(u32 div)
{
    if (div == TFT_TDIV_1MS)
        return 1000;

    if (div == TFT_TDIV_2MS)
        return 2000;

    return 5000;
}

static u32 TFT_ZeroY(void)
{
    return SCOPE_Y + (SCOPE_H / 2);
}

static u32 TFT_VoltToY(s32 mv, u32 mv_div)
{
    s32 y;

    y = (s32)TFT_ZeroY();
    y -= (mv * SCOPE_Y_PX_DIV) / (s32)mv_div;

    if (y < SCOPE_Y)
        y = SCOPE_Y;

    if (y > SCOPE_Y + SCOPE_H - 1)
        y = SCOPE_Y + SCOPE_H - 1;

    return (u32)y;
}

static u32 TFT_TimeToPx(u32 us, u32 us_div)
{
    return (us * SCOPE_X_PX_DIV) / us_div;
}

/******************************************************************************
* Scope Grid
******************************************************************************/
void TFT_DrawGrid(u32 bg_color, u32 grid_color, u32 axis_color)
{
    u32 i;
    u32 x;
    u32 y;

    TFT_Fill(bg_color);

    TFT_DrawRect(
            SCOPE_X,
            SCOPE_Y,
            SCOPE_W,
            SCOPE_H,
            axis_color);

    for (i = 1; i < SCOPE_X_DIV; i++)
    {
        x = SCOPE_X + (i * SCOPE_X_PX_DIV);

        TFT_DrawVLine(
                x,
                SCOPE_Y,
                SCOPE_H,
                grid_color);
    }

    for (i = 1; i < SCOPE_Y_DIV; i++)
    {
        y = SCOPE_Y + (i * SCOPE_Y_PX_DIV);

        TFT_DrawHLine(
                SCOPE_X,
                y,
                SCOPE_W,
                grid_color);
    }
}

/******************************************************************************
* Scope Wave
******************************************************************************/
void TFT_DrawScopeWave(
        u32 volt_div,
        u32 time_div,
        u32 wave_color,
        u32 zero_color)
{
    u32 mv_div;
    u32 us_div;

    u32 high_y;
    u32 low_y;
    u32 zero_y;

    u32 period_px;
    u32 high_px;

    u32 x;
    u32 x0;
    u32 x1;
    u32 right;

    mv_div = TFT_MvDiv(volt_div);
    us_div = TFT_UsDiv(time_div);

    zero_y = TFT_ZeroY();

    high_y = TFT_VoltToY(WAVE_HIGH_MV, mv_div);
    low_y  = TFT_VoltToY(WAVE_LOW_MV,  mv_div);

    period_px = TFT_TimeToPx(WAVE_PERIOD_US, us_div);
    high_px   = (period_px * WAVE_DUTY) / 100;

    if (period_px == 0)
        return;

    if (high_px == 0)
        high_px = 1;

    TFT_DrawHLine(
            SCOPE_X,
            zero_y,
            SCOPE_W,
            zero_color);

    right = SCOPE_X + SCOPE_W;
    x = SCOPE_X;

    while (x < right)
    {
        /*
         * HIGH 구간
         */
        x0 = x;
        x1 = x + high_px;

        if (x1 > right)
            x1 = right;

        TFT_DrawHLine(x0, high_y, x1 - x0, wave_color);

        if (x1 < right)
            TFT_DrawVLine(x1, high_y, low_y - high_y, wave_color);

        /*
         * LOW 구간
         */
        x0 = x1;
        x1 = x + period_px;

        if (x1 > right)
            x1 = right;

        TFT_DrawHLine(x0, low_y, x1 - x0, wave_color);

        if (x1 < right)
            TFT_DrawVLine(x1, high_y, low_y - high_y, wave_color);

        x += period_px;
    }
}
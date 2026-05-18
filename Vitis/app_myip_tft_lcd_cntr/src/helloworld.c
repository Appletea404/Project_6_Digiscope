#include "def.h"
#include "tft_lcd.h"

#define BTN_ADDR        XPAR_AXI_GPIO_0_BASEADDR

/******************************************************************************
* Theme
******************************************************************************/
#define THEME_DARK      0
#define THEME_WHITE     1

/******************************************************************************
* Button Bit
******************************************************************************/
#define BTN_V_SCALE     0x1
#define BTN_T_SCALE     0x2
#define BTN_RUN_STOP    0x4
#define BTN_THEME       0x8

/******************************************************************************
* Scope State
******************************************************************************/
typedef struct
{
    u32 volt_div;
    u32 time_div;
    u32 run;
    u32 theme;
} ScopeState;

/******************************************************************************
* Scope Color
******************************************************************************/
typedef struct
{
    u32 bg;
    u32 grid;
    u32 axis;
    u32 wave_run;
    u32 wave_stop;
} ScopeColor;

/******************************************************************************
* 내부 함수 선언
******************************************************************************/
static ScopeColor Scope_GetColor(u32 theme);
static void Scope_PrintStatus(const ScopeState *s);
static void Scope_DrawScreen(const ScopeState *s);

static void Scope_NextVoltDiv(ScopeState *s);
static void Scope_NextTimeDiv(ScopeState *s);
static void Scope_ToggleRun(ScopeState *s);
static void Scope_ToggleTheme(ScopeState *s);

static void Scope_HandleButton(ScopeState *s, u32 btn_edge);

/******************************************************************************
* Theme Color 선택
******************************************************************************/
static ScopeColor Scope_GetColor(u32 theme)
{
    ScopeColor c;

    if (theme == THEME_DARK)
    {
        c.bg        = TFT_BLACK;
        c.grid      = TFT_GRAY_DARK;
        c.axis      = TFT_WHITE;
        c.wave_run  = TFT_GREEN;
        c.wave_stop = TFT_RED;
    }
    else
    {
        c.bg        = TFT_WHITE;
        c.grid      = TFT_GRAY_LIGHT;
        c.axis      = TFT_BLACK;
        c.wave_run  = TFT_RED;
        c.wave_stop = TFT_BLUE;
    }

    return c;
}

/******************************************************************************
* 현재 상태 UART 출력
******************************************************************************/
static void Scope_PrintStatus(const ScopeState *s)
{
    xil_printf("\r\n");

    if (s->volt_div == TFT_VDIV_1V)
        xil_printf("V SCALE : 1V/div\r\n");
    else if (s->volt_div == TFT_VDIV_3V3)
        xil_printf("V SCALE : 3.3V/div\r\n");
    else
        xil_printf("V SCALE : 5V/div\r\n");

    if (s->time_div == TFT_TDIV_1MS)
        xil_printf("T SCALE : 1ms/div\r\n");
    else if (s->time_div == TFT_TDIV_2MS)
        xil_printf("T SCALE : 2ms/div\r\n");
    else
        xil_printf("T SCALE : 5ms/div\r\n");

    xil_printf("MODE    : %s\r\n", s->run ? "RUN" : "STOP");
    xil_printf("THEME   : %s\r\n", s->theme == THEME_DARK ? "DARK" : "WHITE");
}

/******************************************************************************
* 화면 전체 갱신
*
* - Grid 먼저 그림
* - RUN이면 정상 파형 색상
* - STOP이면 정지 상태용 색상으로 파형 표시
******************************************************************************/
static void Scope_DrawScreen(const ScopeState *s)
{
    ScopeColor c;

    c = Scope_GetColor(s->theme);

    TFT_DrawGrid(
            c.bg,
            c.grid,
            c.axis);

    TFT_DrawScopeWave(
            s->volt_div,
            s->time_div,
            s->run ? c.wave_run : c.wave_stop,
            c.axis);

    Scope_PrintStatus(s);
}

/******************************************************************************
* V/div 변경
******************************************************************************/
static void Scope_NextVoltDiv(ScopeState *s)
{
    s->volt_div++;

    if (s->volt_div > TFT_VDIV_5V)
        s->volt_div = TFT_VDIV_1V;
}

/******************************************************************************
* ms/div 변경
******************************************************************************/
static void Scope_NextTimeDiv(ScopeState *s)
{
    s->time_div++;

    if (s->time_div > TFT_TDIV_5MS)
        s->time_div = TFT_TDIV_1MS;
}

/******************************************************************************
* RUN / STOP 변경
******************************************************************************/
static void Scope_ToggleRun(ScopeState *s)
{
    s->run = !s->run;
}

/******************************************************************************
* DARK / WHITE 변경
******************************************************************************/
static void Scope_ToggleTheme(ScopeState *s)
{
    s->theme = !s->theme;
}

/******************************************************************************
* 버튼 처리
*
* BTN0 : V/div 변경
* BTN1 : ms/div 변경
* BTN2 : RUN / STOP
* BTN3 : DARK / WHITE
******************************************************************************/
static void Scope_HandleButton(ScopeState *s, u32 btn_edge)
{
    if (btn_edge & BTN_V_SCALE)
        Scope_NextVoltDiv(s);

    if (btn_edge & BTN_T_SCALE)
        Scope_NextTimeDiv(s);

    if (btn_edge & BTN_RUN_STOP)
        Scope_ToggleRun(s);

    if (btn_edge & BTN_THEME)
        Scope_ToggleTheme(s);

    if (btn_edge)
        Scope_DrawScreen(s);
}

/******************************************************************************
* MAIN
******************************************************************************/
int main(void)
{
    ScopeState scope;

    u32 btn_now;
    u32 btn_prev;
    u32 btn_edge;

    init_platform();

    xil_printf("================================\r\n");
    xil_printf(" TFT Scope Start\r\n");
    xil_printf(" Fixed Wave : 3.3V, Duty 50%%\r\n");
    xil_printf(" Zero Level : Center Line\r\n");
    xil_printf("================================\r\n");

    TFT_Init();

    /*
     * 초기 상태
     */
    scope.volt_div = TFT_VDIV_1V;
    scope.time_div = TFT_TDIV_2MS;
    scope.run      = 1;
    scope.theme    = THEME_DARK;

    btn_prev = 0;

    Scope_DrawScreen(&scope);

    while (1)
    {
        btn_now = Xil_In32(BTN_ADDR);

        /*
         * Rising Edge 검출
         */
        btn_edge = btn_now & ~btn_prev;
        btn_prev = btn_now;

        Scope_HandleButton(&scope, btn_edge);

        /*
         * 간단한 디바운스
         *
         * 현재 TFT 출력 자체가 busy-wait 기반이므로
         * 여기서는 구조를 단순하게 유지한다.
         */
        usleep(50000);
    }

    cleanup_platform();

    return 0;
}
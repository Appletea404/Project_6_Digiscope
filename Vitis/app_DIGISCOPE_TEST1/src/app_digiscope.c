#include "app_digiscope.h"

#include "tft_lcd.h"        
#include "pwm.h"             
#include "CLCD.h"
#include <xparameters.h>

/******************************************************************************
* Base Address
******************************************************************************/
#define PWM_BASEADDR       XPAR_MYIP_PWM_0_BASEADDR         // PWM IP 제어/측정
#define BTN_ADDR           XPAR_AXI_GPIO_0_BASEADDR         // 버튼 GPIO 읽기
#define UART_BASEADDR      XPAR_AXI_UARTLITE_0_BASEADDR     // UART 명령 수신

/******************************************************************************
* Theme
******************************************************************************/
#define THEME_DARK         0
#define THEME_WHITE        1

/******************************************************************************
* Button Bit
******************************************************************************/
#define BTN_V_SCALE        0x1
#define BTN_T_SCALE        0x2
#define BTN_RUN_STOP       0x4
#define BTN_THEME          0x8

/******************************************************************************
* PWM Wave Voltage
******************************************************************************/
#define PWM_HIGH_MV        3300
#define PWM_LOW_MV         0

/******************************************************************************
* Timing
******************************************************************************/
#define APP_TICK_US        1000
#define TFT_REFRESH_MS     1500
#define CLCD_REFRESH_MS    500
#define BTN_DEBOUNCE_MS    20

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
    u32 bg;         // 배경
    u32 grid;       // 그리드
    u32 axis;       // 중심축
    u32 wave_run;   // 파형
    u32 wave_stop;  // STOP 파형

} ScopeColor;

/******************************************************************************
* PWM Measured Data
******************************************************************************/
typedef struct
{
    u32 period_count;       // PWM 주기 count
    u32 high_count;         // High count

    u32 period_us;          // PWM 주기(us)
    u32 high_us;            // High 시간(us)

    u32 duty_percent;       // Duty (%)
    u32 freq_hz;            // Frequency (Hz)

} PwmMeasured;

/******************************************************************************
* Button State
******************************************************************************/
typedef struct
{
    u32 raw;            // 현재 버튼 raw 입력
    u32 last_raw;       // 이전 raw 입력
    u32 stable;         // 디바운싱 완료 입력
    u32 prev_stable;    // 이전 안정 입력
    u32 cnt;            // 디바운스 카운트

} ButtonState;

/******************************************************************************
* Global State
******************************************************************************/
static PWM_Handle   g_pwm;
static ScopeState   g_scope;
static PwmMeasured  g_meas;
static ButtonState  g_btn;

static u32 g_tft_cnt;
static u32 g_clcd_cnt;
static u32 g_tft_redraw;
static u32 g_clcd_redraw;

/******************************************************************************
* Internal Function
******************************************************************************/
static ScopeColor App_GetColor(u32 theme);

static void App_ButtonInit(ButtonState *b);
static u32  App_ButtonUpdate(ButtonState *b);

static void App_NextVoltDiv(void);
static void App_NextTimeDiv(void);
static void App_ToggleRun(void);
static void App_ToggleTheme(void);

static u32  App_HandleButton(u32 edge);

static void App_ReadPwm(void);
static void App_DrawTft(void);
static void App_DrawClcd(void);

static const char *App_TimeText(u32 div);
static const char *App_VoltText(u32 div);
static void App_FreqText(u32 freq_hz, char *buf);

/******************************************************************************
* Color
******************************************************************************/
static ScopeColor App_GetColor(u32 theme)
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
        c.wave_run  = TFT_BLUE;
        c.wave_stop = TFT_RED;
    }

    return c;
}

/******************************************************************************
* Button
******************************************************************************/
static void App_ButtonInit(ButtonState *b)
{
    b->raw = 0;
    b->last_raw = 0;
    b->stable = 0;
    b->prev_stable = 0;
    b->cnt = 0;
}

static u32 App_ButtonUpdate(ButtonState *b)
{
    u32 edge;

    edge = 0;
    b->raw = Xil_In32(BTN_ADDR) & 0xF;

    /*
     * raw 값이 바뀌면 디바운싱 다시 시작
     */
    if (b->raw != b->last_raw)
    {
        b->last_raw = b->raw;
        b->cnt = 0;
        return 0;
    }

    /*
     * 같은 값이 BTN_DEBOUNCE_MS 동안 유지되면 안정 입력으로 인정
     */
    if (b->cnt < BTN_DEBOUNCE_MS)
    {
        b->cnt++;
        return 0;
    }

    /*
     * stable 값이 바뀐 순간에만 rising edge 생성
     */
    if (b->stable != b->raw)
    {
        b->stable = b->raw;

        edge = b->stable & ~b->prev_stable;
        b->prev_stable = b->stable;
    }

    return edge;
}

/******************************************************************************
* Scope Control
******************************************************************************/
static void App_NextVoltDiv(void)
{
    g_scope.volt_div++;

    if (g_scope.volt_div > TFT_VDIV_5V)
        g_scope.volt_div = TFT_VDIV_1V;
}

static void App_NextTimeDiv(void)
{
    g_scope.time_div++;

    if (g_scope.time_div > TFT_TDIV_5MS)
        g_scope.time_div = TFT_TDIV_100US;
}

static void App_ToggleRun(void)
{
    g_scope.run = !g_scope.run;
}

static void App_ToggleTheme(void)
{
    g_scope.theme = !g_scope.theme;
}

static u32 App_HandleButton(u32 edge)
{
    if (edge & BTN_V_SCALE)
        App_NextVoltDiv();

    if (edge & BTN_T_SCALE)
        App_NextTimeDiv();

    if (edge & BTN_RUN_STOP)
        App_ToggleRun();

    if (edge & BTN_THEME)
        App_ToggleTheme();

    if (edge)
        return 1;

    return 0;
}

/******************************************************************************
* PWM Measure
******************************************************************************/
static void App_ReadPwm(void)
{
    g_meas.period_count = g_pwm.regs[REG_MEASURED_PERIOD];
    g_meas.high_count   = g_pwm.regs[REG_MEASURED_HIGH];

    g_meas.period_us = g_meas.period_count / PWM_COUNT_PER_US;
    g_meas.high_us   = g_meas.high_count   / PWM_COUNT_PER_US;

    if (g_meas.period_count != 0)
    {
        g_meas.duty_percent =
            ((u64)g_meas.high_count * 100U) / g_meas.period_count;

        g_meas.freq_hz =
            PWM_CLK_FREQ_HZ / g_meas.period_count;
    }
    else
    {
        g_meas.duty_percent = 0;
        g_meas.freq_hz = 0;
    }

    /*
     * 입력 미연결 또는 측정 초기 보호
     */
    if (g_meas.period_us == 0)
    {
        g_meas.period_us = 1000;
        g_meas.high_us = 0;
    }

    if (g_meas.high_us > g_meas.period_us)
        g_meas.high_us = g_meas.period_us;
}

/******************************************************************************
* TFT Draw
******************************************************************************/
static void App_DrawTft(void)
{
    ScopeColor c;
    u32 wave_color;

    c = App_GetColor(g_scope.theme);

    if (g_scope.run)
        wave_color = c.wave_run;
    else
        wave_color = c.wave_stop;

    TFT_DrawGrid(
            c.bg,
            c.grid,
            c.axis);

    TFT_DrawPwmWave(
            g_scope.volt_div,
            g_scope.time_div,
            PWM_HIGH_MV,
            PWM_LOW_MV,
            g_meas.period_us,
            g_meas.high_us,
            wave_color,
            c.axis);
}

/******************************************************************************
* CLCD Text Helper
******************************************************************************/
static const char *App_TimeText(u32 div)
{
    if (div == TFT_TDIV_100US)
        return "100u";

    if (div == TFT_TDIV_500US)
        return "500u";

    if (div == TFT_TDIV_1MS)
        return "1ms";

    return "5ms";
}

static const char *App_VoltText(u32 div)
{
    if (div == TFT_VDIV_1V)
        return "1V";

    if (div == TFT_VDIV_3V3)
        return "3.3V";

    return "5V";
}

static void App_FreqText(u32 freq_hz, char *buf)
{
    /*
     * CLCD 16칸에 맞추기 위해 주파수 문자열을 짧게 만든다.
     *
     * 예:
     * 1000Hz  -> 1.0k
     * 500Hz   -> 500
     * 12000Hz -> 12k
     */
    if (freq_hz >= 10000)
    {
        sprintf(buf, "%uk", freq_hz / 1000);
    }
    else if (freq_hz >= 1000)
    {
        sprintf(buf, "%u.%uk",
                freq_hz / 1000,
                (freq_hz % 1000) / 100);
    }
    else
    {
        sprintf(buf, "%u", freq_hz);
    }
}

/******************************************************************************
* CLCD Draw
*
* 16x2 표시 형식:
*
* [R] H:500u V:1V
* [D] F:1.0k D:50%
******************************************************************************/
static void App_DrawClcd(void)
{
    char line1[17];
    char line2[17];
    char freq[8];

    App_FreqText(g_meas.freq_hz, freq);

    /*
     * 16칸 고정 표시를 위해 %-16s로 공백 채움
     */
    sprintf(line1,
            "[%c] H:%s V:%s",
            g_scope.run ? 'R' : 'S',
            App_TimeText(g_scope.time_div),
            App_VoltText(g_scope.volt_div));

    sprintf(line2,
            "[%c] F:%s D:%u%%",
            g_scope.theme == THEME_DARK ? 'D' : 'W',
            freq,
            g_meas.duty_percent);

    line1[16] = '\0';
    line2[16] = '\0';

    clcd_set_cursor(0, 0);
    clcd_print("                ");
    clcd_set_cursor(0, 0);
    clcd_print(line1);

    clcd_set_cursor(1, 0);
    clcd_print("                ");
    clcd_set_cursor(1, 0);
    clcd_print(line2);
}

/******************************************************************************
* App Init
******************************************************************************/
void App_Init(void)
{
    xil_printf("\r\n================================\r\n");
    xil_printf(" DIGISCOPE Start\r\n");
    xil_printf(" PWM IN -> TFT LCD Scope\r\n");
    xil_printf("================================\r\n");

    TFT_Init();
    clcd_init();

    PWM_Init(&g_pwm, PWM_BASEADDR);
    PWM_PrintHelp();

    g_scope.volt_div = TFT_VDIV_1V;
    g_scope.time_div = TFT_TDIV_500US;
    g_scope.run      = 1;
    g_scope.theme    = THEME_DARK;

    App_ButtonInit(&g_btn);

    g_tft_cnt = 0;
    g_clcd_cnt = 0;
    g_tft_redraw = 1;
    g_clcd_redraw = 1;

    App_ReadPwm();

    App_DrawTft();
    App_DrawClcd();
}

/******************************************************************************
* App Task
******************************************************************************/
void App_Task(void)
{
    u32 edge;

    /*
     * UART 명령 처리
     * p1000, d50, s, help
     */
    PWM_UartPolling(&g_pwm, UART_BASEADDR);

    /*
     * 버튼 입력 처리
     */
    edge = App_ButtonUpdate(&g_btn);

    if (App_HandleButton(edge))
    {
        g_tft_redraw = 1;
        g_clcd_redraw = 1;
        g_tft_cnt = 0;
        g_clcd_cnt = 0;
    }

    /*
     * PWM 측정값 갱신
     */
    App_ReadPwm();

    /*
     * CLCD는 가볍기 때문에 비교적 자주 갱신
     */
    g_clcd_cnt++;

    if (g_clcd_cnt >= CLCD_REFRESH_MS)
    {
        g_clcd_cnt = 0;
        g_clcd_redraw = 1;
    }

    /*
     * TFT는 느리므로 RUN 상태에서만 느리게 갱신
     */
    if (g_scope.run)
    {
        g_tft_cnt++;

        if (g_tft_cnt >= TFT_REFRESH_MS)
        {
            g_tft_cnt = 0;
            g_tft_redraw = 1;
        }
    }

    /*
     * CLCD 갱신
     */
    if (g_clcd_redraw)
    {
        App_DrawClcd();
        g_clcd_redraw = 0;
    }

    /*
     * TFT 갱신
     */
    if (g_tft_redraw)
    {
        App_DrawTft();
        g_tft_redraw = 0;
    }

    /*
     * 1ms app tick
     */
    usleep(APP_TICK_US);
}
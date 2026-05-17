`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/14/2026 05:49:59 PM
// Design Name: 
// Module Name: PWM_Generator_ver2
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



//======================================================
// Top Module
//
// IP화 기준 포트 구성
//
// pwm_duty_count:
// - Vitis에서 계산해서 AXI register로 넣을 duty count 값
// - 현재 50% duty로 쓰려면 Vitis에서 period_count / 2 값을 넣으면 됨
//
// period_count_to_reg:
// - GPIO로 다시 입력받은 PWM의 측정 주기 count
// - Vitis에서 읽어서 주파수 계산 가능
//
// vertical_scale_to_reg:
// - btnU / btnD로 조절한 vertical scale 값
// - Vitis에서 읽어서 Graphic LCD 세로 스케일에 사용 가능
//======================================================
module pwm_wave_top(
    input clk,                  // Basys3 100MHz clock
    input [0:0] sw,             // sw[0] = enable

    input btnL,                 // 주파수 증가 버튼
    input btnR,                 // 주파수 감소 버튼
    input btnU,                 // vertical scale 증가 버튼
    input btnD,                 // vertical scale 감소 버튼

    input pwm_in,               // GPIO로 다시 입력받는 PWM 파형
    output pwm_out,             // GPIO로 출력하는 PWM 파형
    output [15:0] led,          // 상태 확인용 LED

    output [31:0] current_period_cnt_out,       // AXI register에 연결할 현재 주기값
    input [31:0] pwm_duty_cnt_in,               // AXI register에서 들어올 duty_count
    output [31:0] measured_period_cnt_out,      // AXI register에 연결할 측정 주기값
    output [2:0] vertical_scale_out             // AXI register에 연결할 vertical scale 값
);

    //--------------------------------------------------
    // [0] Enable / 비동기 Reset
    //
    // sw[0] = 1 → 동작
    // sw[0] = 0 → reset
    //--------------------------------------------------
    wire enable  = sw[0];
    wire reset_p = ~enable;


    //--------------------------------------------------
    // [1] 버튼 디바운스 + 원펄스
    //--------------------------------------------------
    wire btnL_pulse;
    wire btnR_pulse;
    wire btnU_pulse;
    wire btnD_pulse;

    button_onepulse u_btnL (
        .clk(clk),
        .reset_p(reset_p),
        .btn(btnL),
        .pulse(btnL_pulse)
    );

    button_onepulse u_btnR (
        .clk(clk),
        .reset_p(reset_p),
        .btn(btnR),
        .pulse(btnR_pulse)
    );

    button_onepulse u_btnU (
        .clk(clk),
        .reset_p(reset_p),
        .btn(btnU),
        .pulse(btnU_pulse)
    );

    button_onepulse u_btnD (
        .clk(clk),
        .reset_p(reset_p),
        .btn(btnD),
        .pulse(btnD_pulse)
    );


    //--------------------------------------------------
    // [2] PWM 주기 단계 선택
    //
    // freq_sel 값 의미
    // 0 : 0.2ms, 5kHz
    // 1 : 0.5ms, 2kHz
    // 2 : 1ms,   1kHz
    // 3 : 2ms,   500Hz
    // 4 : 5ms,   200Hz
    //
    // 기본값: 1ms, freq_sel = 2
    //--------------------------------------------------
    wire [2:0] freq_sel;
    wire [31:0] pwm_period_count;

    freq_step_controller u_freq_ctrl (
        .clk(clk),
        .reset_p(reset_p),

        .btn_freq_up(btnL_pulse),
        .btn_freq_down(btnR_pulse),

        .freq_sel(freq_sel),
        .period_count(pwm_period_count)
    );


    //--------------------------------------------------
    // [3] Vertical Scale Controller
    //
    // btnU: vertical scale 증가
    // btnD: vertical scale 감소
    //
    // 범위: 0 ~ 4
    // 기본값: 2
    //--------------------------------------------------
    wire [2:0] vertical_scale;

    vertical_scale_controller u_vscale_ctrl (
        .clk(clk),
        .reset_p(reset_p),

        .btn_scale_up(btnU_pulse),
        .btn_scale_down(btnD_pulse),

        .vertical_scale(vertical_scale)
    );


    //--------------------------------------------------
    // [4] PWM Generator
    //
    // 변경점:
    // duty_count를 top input으로 받음
    //
    // 즉, Verilog 내부에서
    // period_count * duty_percent / 100
    // 계산을 하지 않음.
    //
    // Vitis에서 예:
    // duty_count = period_count * 50 / 100;
    // 또는
    // duty_count = period_count / 2;
    //
    // 계산 후 AXI register를 통해 pwm_duty_count로 입력
    //--------------------------------------------------
    pwm_generator_count u_pwm_gen (
        .clk(clk),
        .reset_p(reset_p),
        .pwm_enable(enable),

        .period_count(pwm_period_count),
        .duty_count(pwm_duty_count),

        .pwm_out(pwm_out)
    );


    //--------------------------------------------------
    // [5] GPIO 입력 동기화 + Edge 검출
    //
    // pwm_out 핀에서 나온 신호를 점퍼선으로 pwm_in에 연결
    //--------------------------------------------------
    wire pwm_in_sync;
    wire pwm_in_rising;
    wire pwm_in_falling;

    pwm_input_sync u_input_sync (
        .clk(clk),
        .reset_p(reset_p),

        .pwm_in(pwm_in),

        .pwm_sync(pwm_in_sync),
        .rising_edge(pwm_in_rising),
        .falling_edge(pwm_in_falling)
    );


    //--------------------------------------------------
    // [6] 입력 PWM 주기 측정
    //
    // rising edge와 다음 rising edge 사이의 clock count 측정
    //
    // 이 값은 period_count_to_reg로 출력해서
    // AXI register에 연결 가능
    //--------------------------------------------------
    wire [31:0] measured_period_count;
    wire period_valid;

    pwm_period_measure u_period_measure (
        .clk(clk),
        .reset_p(reset_p),

        .rising_edge(pwm_in_rising),

        .period_count(measured_period_count),
        .period_valid(period_valid)
    );


    //--------------------------------------------------
    // [7] AXI Register 연결용 출력
    //--------------------------------------------------
    assign current_period_cnt_out = pwm_period_count;           // AXI register에 연결할 현재 주기값
    assign pwm_duty_cnt_in = pwm_duty_count;                    // AXI register에서 들어올 duty_count
    assign measured_period_cnt_out = measured_period_count;     // AXI register에 연결할 측정 주기값
    assign vertical_scale_out = vertical_scale;                 // AXI register에 연결할 vertical scale 값


    //--------------------------------------------------
    // [8] LED 표시
    //
    // led[0] : enable
    //
    // 주파수 단계 표시
    // 큰 주파수부터 led[5] → led[1]
    //
    // led[5] : 0.2ms, 5kHz
    // led[4] : 0.5ms, 2kHz
    // led[3] : 1ms,   1kHz
    // led[2] : 2ms,   500Hz
    // led[1] : 5ms,   200Hz
    //
    // vertical scale 표시, 요청대로 반전 매칭
    // led[10] : scale 0
    // led[9]  : scale 1
    // led[8]  : scale 2
    // led[7]  : scale 3
    // led[6]  : scale 4
    //
    // led[15:11] : 측정된 period_count 대략 확인
    //--------------------------------------------------

    assign led[0] = enable;

    // Frequency step LED
    assign led[5] = (freq_sel == 3'd0);    // 0.2ms, 5kHz
    assign led[4] = (freq_sel == 3'd1);    // 0.5ms, 2kHz
    assign led[3] = (freq_sel == 3'd2);    // 1ms, 1kHz
    assign led[2] = (freq_sel == 3'd3);    // 2ms, 500Hz
    assign led[1] = (freq_sel == 3'd4);    // 5ms, 200Hz

    // Vertical scale LED, 반전 매칭
    assign led[10] = (vertical_scale == 3'd0);
    assign led[9]  = (vertical_scale == 3'd1);
    assign led[8]  = (vertical_scale == 3'd2);
    assign led[7]  = (vertical_scale == 3'd3);
    assign led[6]  = (vertical_scale == 3'd4);

    // Measured period count rough monitor
    assign led[15:11] = measured_period_count[18:14];

endmodule



//======================================================
// Button Debounce + One Pulse Module
//======================================================
module button_onepulse(
    input clk,
    input reset_p,
    input btn,
    output reg pulse
);

    //--------------------------------------------------
    // 100MHz 기준
    // 1,000,000 clock = 10ms
    //--------------------------------------------------
    parameter DEBOUNCE_COUNT = 1_000_000;

    reg btn_sync_0;
    reg btn_sync_1;

    reg btn_stable;
    reg btn_stable_d;

    reg [20:0] debounce_cnt;


    //--------------------------------------------------
    // 버튼 입력 동기화
    //--------------------------------------------------
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            btn_sync_0 <= 1'b0;
            btn_sync_1 <= 1'b0;
        end
        else begin
            btn_sync_0 <= btn;
            btn_sync_1 <= btn_sync_0;
        end
    end


    //--------------------------------------------------
    // 디바운싱
    //--------------------------------------------------
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            debounce_cnt <= 0;
            btn_stable <= 1'b0;
        end
        else begin
            if (btn_sync_1 != btn_stable) begin
                if (debounce_cnt >= DEBOUNCE_COUNT - 1) begin
                    debounce_cnt <= 0;
                    btn_stable <= btn_sync_1;
                end
                else begin
                    debounce_cnt <= debounce_cnt + 1;
                end
            end
            else begin
                debounce_cnt <= 0;
            end
        end
    end


    //--------------------------------------------------
    // 상승엣지 원펄스 생성
    //--------------------------------------------------
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            btn_stable_d <= 1'b0;
            pulse <= 1'b0;
        end
        else begin
            btn_stable_d <= btn_stable;

            if (btn_stable == 1'b1 && btn_stable_d == 1'b0)
                pulse <= 1'b1;
            else
                pulse <= 1'b0;
        end
    end

endmodule



//======================================================
// Frequency Step Controller
//======================================================
module freq_step_controller(
    input clk,
    input reset_p,

    input btn_freq_up,
    input btn_freq_down,

    output reg [2:0] freq_sel,
    output reg [31:0] period_count
);

    //--------------------------------------------------
    // freq_sel 단계
    //
    // 0 : 주기 0.2ms  → 주파수 5kHz
    // 1 : 주기 0.5ms  → 주파수 2kHz
    // 2 : 주기 1ms    → 주파수 1kHz
    // 3 : 주기 2ms    → 주파수 500Hz
    // 4 : 주기 5ms    → 주파수 200Hz
    //
    // 기본값은 1ms, 즉 freq_sel = 2
    //--------------------------------------------------

    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            freq_sel <= 3'd2;
        end
        else begin
            //--------------------------------------------------
            // btnL: 주파수 증가
            // 주파수 증가 = 주기 감소
            //--------------------------------------------------
            if (btn_freq_up) begin
                if (freq_sel > 3'd0)
                    freq_sel <= freq_sel - 1;
            end

            //--------------------------------------------------
            // btnR: 주파수 감소
            // 주파수 감소 = 주기 증가
            //--------------------------------------------------
            else if (btn_freq_down) begin
                if (freq_sel < 3'd4)
                    freq_sel <= freq_sel + 1;
            end
        end
    end


    //--------------------------------------------------
    // 100MHz clock 기준 period_count
    //
    // 0.2ms = 20,000 clock
    // 0.5ms = 50,000 clock
    // 1ms   = 100,000 clock
    // 2ms   = 200,000 clock
    // 5ms   = 500,000 clock
    //--------------------------------------------------
    always @(*) begin
        case (freq_sel)
            3'd0: period_count = 32'd20_000;    // 0.2ms, 5kHz
            3'd1: period_count = 32'd50_000;    // 0.5ms, 2kHz
            3'd2: period_count = 32'd100_000;   // 1ms, 1kHz
            3'd3: period_count = 32'd200_000;   // 2ms, 500Hz
            3'd4: period_count = 32'd500_000;   // 5ms, 200Hz
            default: period_count = 32'd100_000;
        endcase
    end

endmodule



//======================================================
// Vertical Scale Controller
//======================================================
module vertical_scale_controller(
    input clk,
    input reset_p,

    input btn_scale_up,
    input btn_scale_down,

    output reg [2:0] vertical_scale
);

    //--------------------------------------------------
    // vertical_scale 값
    //
    // 기본값: 2
    // 최솟값: 0
    // 최댓값: 4
    //--------------------------------------------------
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            vertical_scale <= 3'd2;
        end
        else begin
            //--------------------------------------------------
            // btnU: vertical scale 증가
            //--------------------------------------------------
            if (btn_scale_up) begin
                if (vertical_scale < 3'd4)
                    vertical_scale <= vertical_scale + 1;
            end

            //--------------------------------------------------
            // btnD: vertical scale 감소
            //--------------------------------------------------
            else if (btn_scale_down) begin
                if (vertical_scale > 3'd0)
                    vertical_scale <= vertical_scale - 1;
            end
        end
    end

endmodule



//======================================================
// PWM Generator with Direct Duty Count
//
// Verilog 내부에서 duty_percent 계산 없음.
// Vitis에서 duty_count를 계산해서 pwm_duty_count로 넣는 구조.
//
// period_count = 전체 주기 count
// duty_count   = HIGH 구간 count
//
// 예:
// period_count = 100000
// duty_count   = 50000
// → 1ms 주기, 50% duty
//======================================================
module pwm_generator_count(
    input clk,
    input reset_p,
    input pwm_enable,

    input [31:0] period_count,
    input [31:0] duty_count,

    output reg pwm_out
);

    reg [31:0] cnt;

    //--------------------------------------------------
    // duty_count 보호
    //
    // duty_count가 period_count보다 크면 100% duty로 제한
    //--------------------------------------------------
    wire [31:0] duty_limited;

    assign duty_limited = (duty_count > period_count) ? period_count : duty_count;


    //--------------------------------------------------
    // PWM 생성
    //--------------------------------------------------
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            cnt <= 32'd0;
            pwm_out <= 1'b0;
        end
        else begin
            if (!pwm_enable || period_count == 32'd0) begin
                cnt <= 32'd0;
                pwm_out <= 1'b0;
            end
            else begin
                if (cnt >= period_count - 1) begin
                    cnt <= 32'd0;
                end
                else begin
                    cnt <= cnt + 1;
                end

                if (cnt < duty_limited)
                    pwm_out <= 1'b1;
                else
                    pwm_out <= 1'b0;
            end
        end
    end

endmodule



//======================================================
// PWM Input Synchronizer + Edge Detector
//======================================================
module pwm_input_sync(
    input clk,
    input reset_p,

    input pwm_in,

    output pwm_sync,
    output rising_edge,
    output falling_edge
);

    reg pwm_in_d0;
    reg pwm_in_d1;
    reg pwm_in_prev;

    //--------------------------------------------------
    // GPIO 입력 동기화
    //--------------------------------------------------
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            pwm_in_d0   <= 1'b0;
            pwm_in_d1   <= 1'b0;
            pwm_in_prev <= 1'b0;
        end
        else begin
            pwm_in_d0   <= pwm_in;
            pwm_in_d1   <= pwm_in_d0;
            pwm_in_prev <= pwm_in_d1;
        end
    end

    //--------------------------------------------------
    // 동기화된 입력값과 edge 검출
    //--------------------------------------------------
    assign pwm_sync     = pwm_in_d1;
    assign rising_edge  =  pwm_in_d1 & ~pwm_in_prev;
    assign falling_edge = ~pwm_in_d1 &  pwm_in_prev;

endmodule



//======================================================
// PWM Period Measure
//======================================================
module pwm_period_measure(
    input clk,
    input reset_p,

    input rising_edge,

    output reg [31:0] period_count,
    output reg period_valid
);

    reg [31:0] period_cnt;
    reg measuring_started;

    //--------------------------------------------------
    // rising edge와 다음 rising edge 사이의 clock count 측정
    //--------------------------------------------------
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            period_cnt <= 32'd0;
            period_count <= 32'd0;
            period_valid <= 1'b0;
            measuring_started <= 1'b0;
        end
        else begin
            period_valid <= 1'b0;

            //--------------------------------------------------
            // rising edge가 들어오면 한 주기 측정 완료
            //--------------------------------------------------
            if (rising_edge) begin
                if (measuring_started) begin
                    period_count <= period_cnt;
                    period_valid <= 1'b1;
                end

                //--------------------------------------------------
                // 새 주기 측정 시작
                // 현재 rising edge clock을 새 주기의 첫 clock으로 포함
                //--------------------------------------------------
                period_cnt <= 32'd1;
                measuring_started <= 1'b1;
            end

            //--------------------------------------------------
            // 첫 rising edge 이후부터 주기 카운트 진행
            //--------------------------------------------------
            else begin
                if (measuring_started)
                    period_cnt <= period_cnt + 1;
            end
        end
    end

endmodule
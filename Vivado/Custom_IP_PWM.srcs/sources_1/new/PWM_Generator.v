`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/14/2026 01:33:56 PM
// Design Name: 
// Module Name: PWM_Generator
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


module square_wave_top(
    input clk,              // Basys3 100MHz clock
    input [0:0] sw,         // sw[0] = enable
    input btnL,             // frequency up
    input btnR,             // frequency down
    input square_in,        // 새로 추가: GPIO 입력

    output square_out,      // GPIO로 내보낼 사각파 출력
    output [15:0] led        // 현재 주기 단계 표시용 5 -> 15
);

    //--------------------------------------------------
    // [0] Enable / Reset
    //--------------------------------------------------
    wire enable  = sw[0];

    // sw0이 꺼져 있으면 내부 로직 초기화
    wire reset_p = ~enable;


    //--------------------------------------------------
    // [1] 버튼 디바운스 + 원펄스
    //--------------------------------------------------
    wire btnL_pulse;
    wire btnR_pulse;

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


    //--------------------------------------------------
    // [2] 주파수 단계 선택
    //--------------------------------------------------
    wire [2:0] freq_sel;
    wire [31:0] half_period_count;

    freq_step_controller u_freq_ctrl (
        .clk(clk),
        .reset_p(reset_p),
        .btn_freq_up(btnL_pulse),
        .btn_freq_down(btnR_pulse),
        .freq_sel(freq_sel),
        .half_period_count(half_period_count)
    );


    //--------------------------------------------------
    // [3] 50% Duty 사각파 생성기
    //--------------------------------------------------
    square_wave_generator u_square_gen (
        .clk(clk),
        .reset_p(reset_p),
        .enable(enable),
        .half_period_count(half_period_count),
        .square_out(square_out)
    );


    //--------------------------------------------------
    // [4] GPIO 입력 동기화
    //--------------------------------------------------
    reg square_in_d0;
    reg square_in_d1;
    reg square_in_prev;

    wire square_in_sync;
    wire square_in_rising;
    wire square_in_falling;

    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            square_in_d0   <= 1'b0;
            square_in_d1   <= 1'b0;
            square_in_prev <= 1'b0;
        end
        else begin
            square_in_d0   <= square_in;
            square_in_d1   <= square_in_d0;
            square_in_prev <= square_in_d1;
        end
    end

    // 동기화된 입력 신호
    assign square_in_sync = square_in_d1;

    // 엣지 검출
    assign square_in_rising  =  square_in_sync & ~square_in_prev;
    assign square_in_falling = ~square_in_sync &  square_in_prev;


    //--------------------------------------------------
    // [5] GPIO 입력 확인용 엣지 카운터
    //--------------------------------------------------
    reg [31:0] input_edge_count;

    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            input_edge_count <= 32'd0;
        end
        else begin
            if (square_in_rising) begin
                input_edge_count <= input_edge_count + 1;
            end
        end
    end


    //--------------------------------------------------
    // [6] LED 표시
    //--------------------------------------------------
    // led[0] : enable 상태
    assign led[0] = enable;

    // led[1]~led[5] : 현재 주기 단계 표시
    assign led[5] = (freq_sel == 3'd0);    // 0.2ms, 5kHz
    assign led[4] = (freq_sel == 3'd1);    // 0.5ms, 2kHz
    assign led[3] = (freq_sel == 3'd2);    // 1ms, 1kHz
    assign led[2] = (freq_sel == 3'd3);    // 2ms, 500Hz
    assign led[1] = (freq_sel == 3'd4);    // 5ms, 200Hz

    // led[6] : GPIO 입력값 확인
    // 주파수가 높으면 눈에는 희미하거나 계속 켜진 것처럼 보일 수 있음
    assign led[6] = square_in_sync;

    wire [31:0] period_count;
    wire [31:0] high_count;
    wire [31:0] low_count;
    wire measure_valid;
    
    square_measure u_measure (
        .clk(clk),
        .reset_p(reset_p),
    
        .square_sync(square_in_sync),
        .rising_edge(square_in_rising),
        .falling_edge(square_in_falling),
    
        .period_count(period_count),
        .high_count(high_count),
        .low_count(low_count),
        .measure_valid(measure_valid)
    );

    // led[15:7] : 입력 rising edge가 들어올 때마다 변화
    // 이 부분이 계속 변하면 square_in으로 신호가 정상 입력되는 것
    assign led[15:7] = period_count[18:10];

endmodule



module square_measure(
    input clk,
    input reset_p,

    input square_sync,
    input rising_edge,
    input falling_edge,

    output reg [31:0] period_count,
    output reg [31:0] high_count,
    output reg [31:0] low_count,
    output reg measure_valid
);

    reg [31:0] period_cnt;
    reg [31:0] high_cnt;
    reg [31:0] low_cnt;

    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            period_cnt    <= 32'd0;
            high_cnt      <= 32'd0;
            low_cnt       <= 32'd0;

            period_count  <= 32'd0;
            high_count    <= 32'd0;
            low_count     <= 32'd0;
            measure_valid <= 1'b0;
        end
        else begin
            measure_valid <= 1'b0;

            // 전체 주기 카운터
            period_cnt <= period_cnt + 1;

            // HIGH / LOW 시간 카운터
            if (square_sync)
                high_cnt <= high_cnt + 1;
            else
                low_cnt <= low_cnt + 1;

            // rising edge가 오면 한 주기 측정 완료
            if (rising_edge) begin
                period_count  <= period_cnt;
                high_count    <= high_cnt;
                low_count     <= low_cnt;
                measure_valid <= 1'b1;

                period_cnt <= 32'd1;
                high_cnt   <= 32'd1;
                low_cnt    <= 32'd0;
            end
        end
    end

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
    output reg [31:0] half_period_count
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
            freq_sel <= 3'd2;   // 기본값: 1ms
        end
        else begin
            //--------------------------------------------------
            // 왼쪽 버튼: 주파수 증가
            // 주파수 증가 = 주기 감소
            //--------------------------------------------------
            if (btn_freq_up) begin
                if (freq_sel > 3'd0)
                    freq_sel <= freq_sel - 1;
                else
                    freq_sel <= freq_sel;
            end

            //--------------------------------------------------
            // 오른쪽 버튼: 주파수 감소
            // 주파수 감소 = 주기 증가
            //--------------------------------------------------
            else if (btn_freq_down) begin
                if (freq_sel < 3'd4)
                    freq_sel <= freq_sel + 1;
                else
                    freq_sel <= freq_sel;
            end
        end
    end


    //--------------------------------------------------
    // 100MHz clock 기준 half period count 계산
    //
    // 100MHz = 10ns per clock
    //
    // 0.2ms full period = 20,000 clock
    // half period       = 10,000 clock
    //
    // 0.5ms full period = 50,000 clock
    // half period       = 25,000 clock
    //
    // 1ms full period   = 100,000 clock
    // half period       = 50,000 clock
    //
    // 2ms full period   = 200,000 clock
    // half period       = 100,000 clock
    //
    // 5ms full period   = 500,000 clock
    // half period       = 250,000 clock
    //--------------------------------------------------
    always @(*) begin
        case (freq_sel)
            3'd0: half_period_count = 32'd10_000;   // 0.2ms period, 5kHz
            3'd1: half_period_count = 32'd25_000;   // 0.5ms period, 2kHz
            3'd2: half_period_count = 32'd50_000;   // 1ms period, 1kHz
            3'd3: half_period_count = 32'd100_000;  // 2ms period, 500Hz
            3'd4: half_period_count = 32'd250_000;  // 5ms period, 200Hz
            default: half_period_count = 32'd50_000;
        endcase
    end

endmodule



//======================================================
// 50% Duty Square Wave Generator
//======================================================
module square_wave_generator(
    input clk,
    input reset_p,
    input enable,
    input [31:0] half_period_count,

    output reg square_out
);

    reg [31:0] cnt;

    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            cnt <= 0;
            square_out <= 1'b0;
        end
        else begin
            if (!enable) begin
                cnt <= 0;
                square_out <= 1'b0;
            end
            else begin
                if (cnt >= half_period_count - 1) begin
                    cnt <= 0;
                    square_out <= ~square_out;
                end
                else begin
                    cnt <= cnt + 1;
                end
            end
        end
    end

endmodule
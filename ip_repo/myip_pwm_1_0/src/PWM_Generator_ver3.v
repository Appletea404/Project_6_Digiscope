`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/17/2026 12:54:14 PM
// Design Name: 
// Module Name: PWM_Generator_ver3
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
// 변경된 구조
// - 버튼으로 주기/스케일을 변경하지 않음
// - sw[0]으로 PWM 파형 ON/OFF 제어
// - Vitis에서 AXI register에 duty_count, period_count를 write
// - Verilog는 register 값을 받아 PWM 파형 생성
// - pwm_out을 GPIO/PMOD로 출력
// - pwm_in으로 다시 입력받아 rising/falling edge 검출
// - 측정된 period count, high count를 register로 전달
//
// 중요 변경점
// - Verilog 내부에서 duty percent 계산을 하지 않음
// - 나눗셈 연산은 Vitis C 코드에서 처리
// - Verilog는 측정값만 저장해서 AXI register로 내보냄
//
// 100MHz clock 기준
// - 1us = 100 clock count
// - p1000 명령을 Vitis에서 받으면 period_count = 1000 * 100 = 100000
// - d50 명령을 Vitis에서 받으면 duty_count = period_count * 50 / 100 = 50000
//
// 권장 AXI register 연결 예시
// - slv_reg0    : pwm_duty_cnt_in
// - slv_reg1    : pwm_period_cnt_in
// - read 0x00   : duty_count read-back
// - read 0x04   : period_count read-back
// - read 0x08   : measured_period_cnt_out
// - read 0x0C   : measured_high_cnt_out
//
// Vitis에서 계산할 값
// - measured_period_us = measured_period_cnt_out / 100
// - measured_high_us   = measured_high_cnt_out / 100
// - measured_duty      = measured_high_cnt_out * 100 / measured_period_cnt_out
//
// sw[0]
// - 1 : PWM 동작
// - 0 : PWM 정지
//
// reset_p
// - BTNC/AXI reset과 연결되는 전체 reset
// - sw[0]과 reset_p는 분리해서 사용
//======================================================
module pwm_wave_top(
    input clk,                              // Basys3 100MHz clock
    input reset_p,                          // active-high reset, AXI resetn을 반전해서 연결 권장
    input [0:0] sw,                         // sw[0] = PWM enable

    input [31:0] pwm_duty_cnt_in,           // AXI register에서 들어오는 duty count 값
    input [31:0] pwm_period_cnt_in,         // AXI register에서 들어오는 period count 값

    input pwm_in,                           // GPIO/PMOD로 다시 입력받는 PWM 파형
    output pwm_out,                         // GPIO/PMOD로 출력하는 PWM 파형
    output [15:0] led,                      // 상태 확인용 LED

    output [31:0] current_period_cnt_out,   // 현재 설정된 period count
    output [31:0] current_duty_cnt_out,     // 현재 설정된 duty count
    output [31:0] measured_period_cnt_out,  // 측정된 period count
    output [31:0] measured_high_cnt_out     // 측정된 HIGH 구간 count
);

    //--------------------------------------------------
    // [0] Enable / Reset 신호 분리
    //
    // reset_p
    // - BTNC 또는 AXI reset에서 들어오는 전체 reset
    // - 전체 초기화가 필요할 때만 사용
    //
    // enable
    // - sw[0]에서 들어오는 PWM ON/OFF 제어 신호
    // - reset_p와 직접 OR하지 않음
    // - sw[0]을 내린다고 BTNC reset을 누른 것처럼 만들지 않기 위함
    //--------------------------------------------------
    wire enable;

    assign enable = sw[0];


    //--------------------------------------------------
    // [1] 현재 설정값 AXI read-back용 출력
    //
    // Vitis에서 register에 write한 값이 실제 top까지
    // 들어왔는지 확인할 때 사용
    //--------------------------------------------------
    assign current_period_cnt_out = pwm_period_cnt_in;
    assign current_duty_cnt_out   = pwm_duty_cnt_in;


    //--------------------------------------------------
    // [2] PWM Generator
    //
    // period_count = 전체 주기 count
    // duty_count   = HIGH 구간 count
    //
    // 예시:
    // period_count = 100000
    // duty_count   = 50000
    // → 100MHz 기준 1ms 주기, 50% duty
    //--------------------------------------------------
    pwm_generator_count u_pwm_gen (
        .clk(clk),
        .reset_p(reset_p),
        .pwm_enable(enable),
        .period_count(pwm_period_cnt_in),
        .duty_count(pwm_duty_cnt_in),
        .pwm_out(pwm_out)
    );


    //--------------------------------------------------
    // [3] GPIO 입력 동기화 + Edge 검출
    //
    // pwm_out에서 나온 신호를 점퍼선으로 pwm_in에 연결하면
    // 이 모듈에서 clk 기준으로 동기화한 뒤
    // rising edge와 falling edge를 1 clock pulse로 생성
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
    // [4] 입력 PWM period / high count 측정
    //
    // period count:
    // - rising edge부터 다음 rising edge까지의 clock count
    //
    // high count:
    // - rising edge부터 falling edge까지의 clock count
    //
    // duty percent 계산은 여기서 하지 않고 Vitis에서 수행
    //--------------------------------------------------
    pwm_period_high_measure u_period_high_measure (
        .clk(clk),
        .reset_p(reset_p),
        .measure_enable(enable),
        .rising_edge(pwm_in_rising),
        .falling_edge(pwm_in_falling),
        .period_count(measured_period_cnt_out),
        .high_count(measured_high_cnt_out)
    );


    //--------------------------------------------------
    // [5] LED 표시
    //
    // led[0]
    // - PWM enable 상태 표시
    // - sw[0]이 1이면 led[0] ON
    // - sw[0]이 0이면 led[0] OFF
    //
    // led[15:1]
    // - 현재 설정된 period_count의 대략적인 크기 표시
    // - 하위 비트는 너무 작아서 LED로 보기 어렵기 때문에 [18:4] 사용
    // - 표시 범위가 마음에 안 들면 [19:5], [20:6] 등으로 조절 가능
    //--------------------------------------------------
    assign led[0]    = enable;
    assign led[15:1] = pwm_period_cnt_in[18:4];

endmodule



//======================================================
// PWM Generator with Direct Duty Count
//
// Verilog 내부에서 duty percent를 계산하지 않음.
// Vitis에서 UART 명령을 해석한 뒤 duty_count를 계산해서
// AXI register를 통해 이 모듈로 넣는 구조.
//
// period_count = 전체 주기 count
// duty_count   = HIGH 구간 count
//
// 예시:
// period_count = 100000
// duty_count   = 50000
// → 100MHz 기준 1ms 주기, 50% duty
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
    // duty_count가 period_count보다 크면
    // duty_limited를 period_count로 제한해서 100% duty로 동작
    //--------------------------------------------------
    wire [31:0] duty_limited;

    assign duty_limited = (duty_count > period_count) ? period_count : duty_count;


    //--------------------------------------------------
    // PWM 생성 동작
    //
    // 1. enable이 0이거나 period_count가 0이면 출력 0
    // 2. cnt는 0부터 period_count - 1까지 증가
    // 3. cnt < duty_limited 구간에서는 pwm_out = 1
    // 4. 나머지 구간에서는 pwm_out = 0
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
                if (cnt >= period_count - 1)
                    cnt <= 32'd0;
                else
                    cnt <= cnt + 1;

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
//
// 외부 GPIO/PMOD에서 들어오는 pwm_in은 clk와 완전히
// 동기화된 신호가 아닐 수 있으므로 2단 FF로 동기화한다.
//
// 이후 이전 clock의 값과 현재 값을 비교해서
// rising_edge, falling_edge를 각각 1 clock pulse로 만든다.
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
    //
    // rising_edge  : 0 → 1 변화 검출
    // falling_edge : 1 → 0 변화 검출
    //--------------------------------------------------
    assign pwm_sync     = pwm_in_d1;
    assign rising_edge  =  pwm_in_d1 & ~pwm_in_prev;
    assign falling_edge = ~pwm_in_d1 &  pwm_in_prev;

endmodule



//======================================================
// PWM Period / High Count Measure
//
// rising edge와 falling edge를 이용해서 입력 PWM의
// period count와 high count만 측정한다.
//
// period_count:
// - rising edge부터 다음 rising edge까지의 clock count
//
// high_count:
// - rising edge부터 falling edge까지의 clock count
//
// duty percent 계산은 Verilog에서 하지 않는다.
// measured_high_cnt_out과 measured_period_cnt_out을
// AXI register로 내보낸 뒤 Vitis에서 계산한다.
//
// 주의:
// - duty가 0%이면 rising/falling edge가 거의 발생하지 않음
// - duty가 100%이면 falling edge가 발생하지 않음
// - 따라서 0%, 100% 근처에서는 edge 기반 측정값이 갱신되지 않을 수 있음
//======================================================
module pwm_period_high_measure(
    input clk,
    input reset_p,
    input measure_enable,

    input rising_edge,
    input falling_edge,

    output reg [31:0] period_count,
    output reg [31:0] high_count
);

    reg [31:0] period_cnt;
    reg [31:0] high_cnt;
    reg [31:0] high_cnt_latched;

    reg measuring_started;
    reg high_measuring;

    //--------------------------------------------------
    // Period / High width 측정
    //--------------------------------------------------
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            period_cnt        <= 32'd0;
            high_cnt          <= 32'd0;
            high_cnt_latched  <= 32'd0;
            period_count      <= 32'd0;
            high_count        <= 32'd0;
            measuring_started <= 1'b0;
            high_measuring    <= 1'b0;
        end
        else begin
            if (!measure_enable) begin
                period_cnt        <= 32'd0;
                high_cnt          <= 32'd0;
                high_cnt_latched  <= 32'd0;
                period_count      <= 32'd0;
                high_count        <= 32'd0;
                measuring_started <= 1'b0;
                high_measuring    <= 1'b0;
            end
            else begin
                //--------------------------------------------------
                // 첫 rising edge 이후부터 period counter 증가
                //--------------------------------------------------
                if (measuring_started)
                    period_cnt <= period_cnt + 1;

                //--------------------------------------------------
                // HIGH 구간 측정 중이면 high counter 증가
                //--------------------------------------------------
                if (high_measuring)
                    high_cnt <= high_cnt + 1;

                //--------------------------------------------------
                // falling edge가 들어오면 HIGH 구간 측정 완료
                // 이때 high_cnt 값을 high_cnt_latched에 저장해둔다.
                //--------------------------------------------------
                if (falling_edge && high_measuring) begin
                    high_cnt_latched <= high_cnt;
                    high_measuring <= 1'b0;
                end

                //--------------------------------------------------
                // rising edge가 들어오면 한 주기 측정 완료
                // period_count와 high_count만 저장하고,
                // duty percent 계산은 하지 않는다.
                //--------------------------------------------------
                if (rising_edge) begin
                    if (measuring_started) begin
                        period_count <= period_cnt;
                        high_count <= high_cnt_latched;
                    end

                    //--------------------------------------------------
                    // 새 주기 측정 시작
                    // 현재 rising edge clock을 첫 count로 포함하기 위해 1부터 시작
                    //--------------------------------------------------
                    period_cnt <= 32'd1;
                    high_cnt <= 32'd0;
                    high_cnt_latched <= 32'd0;
                    measuring_started <= 1'b1;
                    high_measuring <= 1'b1;
                end
            end
        end
    end

endmodule

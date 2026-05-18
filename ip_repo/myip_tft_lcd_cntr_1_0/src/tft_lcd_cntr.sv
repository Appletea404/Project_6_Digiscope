`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// ILI9341 TFT LCD Controller for AXI IP
//
// 역할
// 1. 전원 인가 후 LCD 자동 초기화
// 2. 초기화 완료 후 명령 대기
// 3. 외부 register/AXI에서 명령 입력
// 4. Fill Screen 또는 Draw Pixel 실행
//
// 명령 구조:
// cmd_code = 1 : 전체 화면 색 채우기
// cmd_code = 2 : 특정 좌표 1픽셀 출력
//
// tft_lcd_spi_tx는 기존 검증 완료 코드 그대로 사용
//////////////////////////////////////////////////////////////////////////////////

module tft_lcd_cntr(
    input clk,
    input reset_p,

    ////////////////////////////////////////////////////////////
    // 외부 제어 입력
    // AXI Register에서 연결할 신호
    ////////////////////////////////////////////////////////////
    input        cmd_start,     // 명령 시작 pulse 또는 start bit
    input [3:0]  cmd_code,      // 1=Fill Screen, 2=Draw Pixel
    input [8:0]  cmd_x,         // X 좌표: 0~239
    input [8:0]  cmd_y,         // Y 좌표: 0~319
    input [15:0] cmd_color,     // RGB565 색상

    ////////////////////////////////////////////////////////////
    // 상태 출력
    // AXI Register에서 읽을 신호
    ////////////////////////////////////////////////////////////
    output reg busy,
    output reg done,
    output reg init_done,

    ////////////////////////////////////////////////////////////
    // TFT LCD SPI 핀
    ////////////////////////////////////////////////////////////
    input  tft_sdo,             // 현재 미사용
    output tft_sck,
    output tft_sdi,
    output tft_dc,
    output reg tft_reset,
    output tft_cs
);

    ////////////////////////////////////////////////////////////
    // Command 정의
    ////////////////////////////////////////////////////////////
    localparam CMD_NONE        = 4'd0;
    localparam CMD_FILL_SCREEN = 4'd1;
    localparam CMD_DRAW_PIXEL  = 4'd2;

    ////////////////////////////////////////////////////////////
    // LCD 해상도
    ////////////////////////////////////////////////////////////
    localparam LCD_WIDTH      = 240;
    localparam LCD_HEIGHT     = 320;
    localparam TOTAL_PIXELS   = LCD_WIDTH * LCD_HEIGHT;

    ////////////////////////////////////////////////////////////
    // SPI TX 연결
    ////////////////////////////////////////////////////////////
    reg [8:0] spiData;
    reg spiDataSet;
    wire spiIdle;

    tft_lcd_spi_tx spi_tx(
        .clk(clk),
        .reset_p(reset_p),
        .data(spiData),
        .dataAvailable(spiDataSet),
        .tft_sck(tft_sck),
        .tft_sdi(tft_sdi),
        .tft_dc(tft_dc),
        .tft_cs(tft_cs),
        .idle(spiIdle)
    );

    wire unused_tft_sdo = tft_sdo;

    ////////////////////////////////////////////////////////////
    // cmd_start edge detect
    //
    // AXI start bit가 여러 클럭 동안 1이어도
    // 한 번만 명령을 실행하기 위해 rising edge 검출
    ////////////////////////////////////////////////////////////
    reg cmd_start_d;
    wire cmd_start_edge = cmd_start & ~cmd_start_d;

    always @(posedge clk or posedge reset_p) begin
        if (reset_p)
            cmd_start_d <= 1'b0;
        else
            cmd_start_d <= cmd_start;
    end

    ////////////////////////////////////////////////////////////
    // ILI9341 초기화 시퀀스
    //
    // 0x11 Sleep Out, 0x29 Display ON은 delay가 필요해서
    // 별도 FSM 상태에서 전송
    ////////////////////////////////////////////////////////////
    parameter INIT_SEQ_LEN = 52;

    reg [5:0] initSeqCounter;

    reg [8:0] INIT_SEQ [0:INIT_SEQ_LEN-1] = '{
        // Display OFF
        {1'b0, 8'h28},

        // Extended / module-specific init
        {1'b0, 8'hCF}, {1'b1, 8'h00}, {1'b1, 8'h83}, {1'b1, 8'h30},
        {1'b0, 8'hED}, {1'b1, 8'h64}, {1'b1, 8'h03},
        {1'b1, 8'h12}, {1'b1, 8'h81},
        {1'b0, 8'hE8}, {1'b1, 8'h85}, {1'b1, 8'h01}, {1'b1, 8'h79},
        {1'b0, 8'hCB}, {1'b1, 8'h39}, {1'b1, 8'h2C},
        {1'b1, 8'h00}, {1'b1, 8'h34}, {1'b1, 8'h02},
        {1'b0, 8'hF7}, {1'b1, 8'h20},
        {1'b0, 8'hEA}, {1'b1, 8'h00}, {1'b1, 8'h00},

        // Power Control
        {1'b0, 8'hC0}, {1'b1, 8'h26},
        {1'b0, 8'hC1}, {1'b1, 8'h11},

        // VCOM Control
        {1'b0, 8'hC5}, {1'b1, 8'h35}, {1'b1, 8'h3E},
        {1'b0, 8'hC7}, {1'b1, 8'hBE},

        // Memory Access Control
        {1'b0, 8'h36}, {1'b1, 8'h48},

        // Pixel Format Set: 0x55 = RGB565
        {1'b0, 8'h3A}, {1'b1, 8'h55},

        // Frame Rate
        {1'b0, 8'hB1}, {1'b1, 8'h00}, {1'b1, 8'h1B},

        // Display Function Control
        {1'b0, 8'hB6}, {1'b1, 8'h0A}, {1'b1, 8'h82},
        {1'b1, 8'h27}, {1'b1, 8'h00},

        // 3Gamma Function Disable
        {1'b0, 8'hF2}, {1'b1, 8'h00},

        // Gamma Set
        {1'b0, 8'h26}, {1'b1, 8'h01},

        // Brightness
        {1'b0, 8'h51}, {1'b1, 8'hFF}
    };

    ////////////////////////////////////////////////////////////
    // Draw/Fill용 내부 좌표와 색상
    ////////////////////////////////////////////////////////////
    reg [8:0] x_start;
    reg [8:0] x_end;
    reg [8:0] y_start;
    reg [8:0] y_end;

    reg [15:0] drawColor;

    reg [16:0] pixelCounter;
    reg frameBufferLowByte;

    ////////////////////////////////////////////////////////////
    // Window Sequence Counter
    //
    // 0~10:
    // 0x2A + X start/end + 0x2B + Y start/end + 0x2C
    ////////////////////////////////////////////////////////////
    reg [3:0] windowSeqCounter;

    ////////////////////////////////////////////////////////////
    // Delay Counter
    //
    // 100MHz 기준:
    // 1,000,000  = 10ms
    // 15,000,000 = 150ms
    // 12,000,000 = 120ms
    // 2,000,000  = 20ms
    ////////////////////////////////////////////////////////////
    reg [23:0] remainingDelayTicks;

    ////////////////////////////////////////////////////////////
    // FSM 상태
    ////////////////////////////////////////////////////////////
    localparam START              = 5'd0;
    localparam HOLD_RESET         = 5'd1;
    localparam WAIT_FOR_POWERUP   = 5'd2;
    localparam SEND_INIT_SEQ      = 5'd3;
    localparam SEND_SLEEP_OUT     = 5'd4;
    localparam WAIT_SLEEP_OUT     = 5'd5;
    localparam SEND_DISPLAY_ON    = 5'd6;
    localparam WAIT_DISPLAY_ON    = 5'd7;
    localparam IDLE               = 5'd8;
    localparam SET_WINDOW         = 5'd9;
    localparam SEND_COLOR_HIGH    = 5'd10;
    localparam SEND_COLOR_LOW     = 5'd11;

    reg [4:0] state;

    ////////////////////////////////////////////////////////////
    // Window 명령 생성 함수 역할
    //
    // ILI9341 주소 설정 순서:
    // 0x2A, XS_H, XS_L, XE_H, XE_L
    // 0x2B, YS_H, YS_L, YE_H, YE_L
    // 0x2C
    ////////////////////////////////////////////////////////////
    reg [8:0] windowData;

    always @(*) begin
        case (windowSeqCounter)
            4'd0:  windowData = {1'b0, 8'h2A};

            4'd1:  windowData = {1'b1, 7'd0, x_start[8]};
            4'd2:  windowData = {1'b1, x_start[7:0]};
            4'd3:  windowData = {1'b1, 7'd0, x_end[8]};
            4'd4:  windowData = {1'b1, x_end[7:0]};

            4'd5:  windowData = {1'b0, 8'h2B};

            4'd6:  windowData = {1'b1, 7'd0, y_start[8]};
            4'd7:  windowData = {1'b1, y_start[7:0]};
            4'd8:  windowData = {1'b1, 7'd0, y_end[8]};
            4'd9:  windowData = {1'b1, y_end[7:0]};

            4'd10: windowData = {1'b0, 8'h2C};

            default: windowData = 9'd0;
        endcase
    end

    ////////////////////////////////////////////////////////////
    // Main FSM
    ////////////////////////////////////////////////////////////
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            state               <= START;
            remainingDelayTicks <= 24'd0;

            spiData             <= 9'd0;
            spiDataSet          <= 1'b0;

            initSeqCounter      <= 6'd0;
            windowSeqCounter    <= 4'd0;

            x_start             <= 9'd0;
            x_end               <= 9'd0;
            y_start             <= 9'd0;
            y_end               <= 9'd0;

            drawColor           <= 16'd0;
            pixelCounter        <= 17'd0;
            frameBufferLowByte  <= 1'b0;

            busy                <= 1'b1;
            done                <= 1'b0;
            init_done           <= 1'b0;

            tft_reset           <= 1'b1;
        end
        else begin
            // SPI start는 항상 1clk pulse
            spiDataSet <= 1'b0;

            // done은 1clk pulse
            done <= 1'b0;

            ////////////////////////////////////////////////////
            // Delay 처리
            ////////////////////////////////////////////////////
            if (remainingDelayTicks > 0) begin
                remainingDelayTicks <= remainingDelayTicks - 1'b1;
            end

            ////////////////////////////////////////////////////
            // SPI가 idle일 때만 다음 byte 전송
            ////////////////////////////////////////////////////
            else if (spiIdle && !spiDataSet) begin
                case (state)

                    //////////////////////////////////////////////////
                    // LCD RESET Low
                    //////////////////////////////////////////////////
                    START: begin
                        busy <= 1'b1;
                        tft_reset <= 1'b0;
                        remainingDelayTicks <= 24'd1000000;    // 10ms
                        state <= HOLD_RESET;
                    end

                    //////////////////////////////////////////////////
                    // RESET 해제 후 전원 안정화 대기
                    //////////////////////////////////////////////////
                    HOLD_RESET: begin
                        tft_reset <= 1'b1;
                        remainingDelayTicks <= 24'd15000000;   // 150ms
                        state <= WAIT_FOR_POWERUP;
                    end

                    //////////////////////////////////////////////////
                    // INIT 전송 준비
                    //////////////////////////////////////////////////
                    WAIT_FOR_POWERUP: begin
                        initSeqCounter <= 6'd0;
                        state <= SEND_INIT_SEQ;
                    end

                    //////////////////////////////////////////////////
                    // INIT_SEQ 전송
                    //////////////////////////////////////////////////
                    SEND_INIT_SEQ: begin
                        if (initSeqCounter < INIT_SEQ_LEN) begin
                            spiData <= INIT_SEQ[initSeqCounter];
                            spiDataSet <= 1'b1;
                            initSeqCounter <= initSeqCounter + 1'b1;
                        end
                        else begin
                            state <= SEND_SLEEP_OUT;
                        end
                    end

                    //////////////////////////////////////////////////
                    // Sleep Out 명령 전송
                    //////////////////////////////////////////////////
                    SEND_SLEEP_OUT: begin
                        spiData <= {1'b0, 8'h11};
                        spiDataSet <= 1'b1;
                        remainingDelayTicks <= 24'd12000000;   // 120ms
                        state <= SEND_DISPLAY_ON;
                    end

                    //////////////////////////////////////////////////
                    // Sleep Out 이후 대기 완료 후 Display ON 전송
                    //////////////////////////////////////////////////
                    SEND_DISPLAY_ON: begin
                        spiData <= {1'b0, 8'h29};
                        spiDataSet <= 1'b1;
                        remainingDelayTicks <= 24'd2000000;    // 20ms
                        state <= IDLE;
                    end

                    //////////////////////////////////////////////////
                    // 명령 대기 상태
                    //////////////////////////////////////////////////
                    IDLE: begin
                        busy <= 1'b0;
                        init_done <= 1'b1;

                        if (cmd_start_edge) begin
                            busy <= 1'b1;

                            drawColor <= cmd_color;
                            windowSeqCounter <= 4'd0;
                            frameBufferLowByte <= 1'b0;

                            if (cmd_code == CMD_FILL_SCREEN) begin
                                x_start <= 9'd0;
                                x_end   <= 9'd239;
                                y_start <= 9'd0;
                                y_end   <= 9'd319;
                                pixelCounter <= 17'd76800;
                                state <= SET_WINDOW;
                            end
                            else if (cmd_code == CMD_DRAW_PIXEL) begin
                                x_start <= cmd_x;
                                x_end   <= cmd_x;
                                y_start <= cmd_y;
                                y_end   <= cmd_y;
                                pixelCounter <= 17'd1;
                                state <= SET_WINDOW;
                            end
                            else begin
                                busy <= 1'b0;
                            end
                        end
                    end

                    //////////////////////////////////////////////////
                    // 주소 Window 설정
                    //////////////////////////////////////////////////
                    SET_WINDOW: begin
                        if (windowSeqCounter < 4'd11) begin
                            spiData <= windowData;
                            spiDataSet <= 1'b1;
                            windowSeqCounter <= windowSeqCounter + 1'b1;
                        end
                        else begin
                            frameBufferLowByte <= 1'b0;
                            state <= SEND_COLOR_HIGH;
                        end
                    end

                    //////////////////////////////////////////////////
                    // RGB565 상위 byte 전송
                    //////////////////////////////////////////////////
                    SEND_COLOR_HIGH: begin
                        if (pixelCounter != 17'd0) begin
                            spiData <= {1'b1, drawColor[15:8]};
                            spiDataSet <= 1'b1;
                            state <= SEND_COLOR_LOW;
                        end
                        else begin
                            busy <= 1'b0;
                            done <= 1'b1;
                            state <= IDLE;
                        end
                    end

                    //////////////////////////////////////////////////
                    // RGB565 하위 byte 전송
                    //////////////////////////////////////////////////
                    SEND_COLOR_LOW: begin
                        spiData <= {1'b1, drawColor[7:0]};
                        spiDataSet <= 1'b1;
                        pixelCounter <= pixelCounter - 1'b1;
                        state <= SEND_COLOR_HIGH;
                    end

                    default: begin
                        state <= START;
                    end

                endcase
            end
        end
    end

endmodule
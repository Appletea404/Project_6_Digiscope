`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// ILI9341 TFT LCD SPI 1-byte transmitter
//
// 수정 핵심:
// - 기존 이름 최대 유지
// - SPI mode 0: SCK idle low
// - MSB first
// - 마지막 bit0까지 SCK rising edge 발생 후 CS 해제
// - 100MHz 기준 약 1MHz SCK
//////////////////////////////////////////////////////////////////////////////////

module tft_lcd_spi_tx(
    input clk, reset_p,

    input [8:0] data,
    input dataAvailable,

    output tft_sck,
    output reg tft_sdi, tft_dc,
    output tft_cs,

    output reg idle
);

    reg internalSck, cs;
    reg [2:0] counter;
    reg [8:0] internalData;

    wire dataDc = internalData[8];
    wire [7:0] dataShift = internalData[7:0];

    localparam SPI_DIV = 8'd50;
    reg [7:0] clkDiv;

    localparam SPI_IDLE = 3'd0;
    localparam SPI_PREP = 3'd1;
    localparam SPI_HIGH = 3'd2;
    localparam SPI_LOW  = 3'd3;
    localparam SPI_GAP  = 3'd4;

    reg [2:0] spiState;

    assign tft_sck = internalSck & cs;
    assign tft_cs  = !cs;

    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            internalSck  <= 1'b0;
            cs           <= 1'b0;
            counter      <= 3'd0;
            internalData <= 9'd0;
            clkDiv       <= 8'd0;
            spiState     <= SPI_IDLE;

            tft_sdi      <= 1'b0;
            tft_dc       <= 1'b0;
            idle         <= 1'b1;
        end
        else begin
            case (spiState)

                SPI_IDLE: begin
                    internalSck <= 1'b0;
                    cs          <= 1'b0;
                    clkDiv      <= 8'd0;
                    counter     <= 3'd0;
                    idle        <= 1'b1;

                    if (dataAvailable) begin
                        internalData <= data;

                        // 첫 rising edge 전에 DC/MOSI/CS 안정화
                        tft_dc       <= data[8];
                        tft_sdi      <= data[7];   // bit7 먼저
                        cs           <= 1'b1;
                        idle         <= 1'b0;
                        spiState     <= SPI_PREP;
                    end
                end

                SPI_PREP: begin
                    internalSck <= 1'b0;
                    cs          <= 1'b1;
                    idle        <= 1'b0;

                    if (clkDiv == SPI_DIV - 1'b1) begin
                        clkDiv      <= 8'd0;
                        internalSck <= 1'b1;      // bit7 rising edge
                        spiState    <= SPI_HIGH;
                    end
                    else begin
                        clkDiv <= clkDiv + 1'b1;
                    end
                end

                SPI_HIGH: begin
                    internalSck <= 1'b1;
                    cs          <= 1'b1;
                    idle        <= 1'b0;

                    if (clkDiv == SPI_DIV - 1'b1) begin
                        clkDiv      <= 8'd0;
                        internalSck <= 1'b0;      // falling edge

                        if (counter == 3'd7) begin
                            // 여기서 종료해야 bit0 rising edge까지 이미 발생한 상태
                            spiState <= SPI_GAP;
                        end
                        else begin
                            // 다음 bit 준비
                            // counter=0이면 다음은 bit6
                            tft_sdi  <= dataShift[6 - counter];
                            counter  <= counter + 1'b1;
                            spiState <= SPI_LOW;
                        end
                    end
                    else begin
                        clkDiv <= clkDiv + 1'b1;
                    end
                end

                SPI_LOW: begin
                    internalSck <= 1'b0;
                    cs          <= 1'b1;
                    idle        <= 1'b0;

                    if (clkDiv == SPI_DIV - 1'b1) begin
                        clkDiv      <= 8'd0;
                        internalSck <= 1'b1;      // 다음 bit rising edge
                        spiState    <= SPI_HIGH;
                    end
                    else begin
                        clkDiv <= clkDiv + 1'b1;
                    end
                end

                SPI_GAP: begin
                    // byte 완료 후 CS high gap 확보
                    internalSck <= 1'b0;
                    cs          <= 1'b0;
                    idle        <= 1'b0;

                    if (clkDiv == SPI_DIV - 1'b1) begin
                        clkDiv   <= 8'd0;
                        idle     <= 1'b1;
                        spiState <= SPI_IDLE;
                    end
                    else begin
                        clkDiv <= clkDiv + 1'b1;
                    end
                end

                default: begin
                    spiState <= SPI_IDLE;
                end

            endcase
        end
    end

endmodule
`timescale 1ns / 1ps


module I2C_master(
    input clk, reset_p,
    input [6:0] addr,
    input [7:0] data,
    input rd_wr, comm_start,
    output reg scl, sda,
    output reg busy
    );

    localparam IDLE         = 7'b000_0001;
    localparam COMM_START   = 7'b000_0010;
    localparam SEND_ADDR    = 7'b000_0100;
    localparam RD_ACK       = 7'b000_1000;
    localparam SEND_DATA    = 7'b001_0000;
    localparam SCL_STOP     = 7'b010_0000;
    localparam COMM_STOP    = 7'b100_0000;

    wire clk_usec_nedge;
    clock_usec usec_clk(.clk(clk), .reset_p(reset_p), 
                        .clk_usec_nedge(clk_usec_nedge));

    wire comm_start_pedge;
    edge_detector_p ed_start(.clk(clk), .reset_p(reset_p),
                       .cp(comm_start), .p_edge(comm_start_pedge));
                       
    wire scl_pedge, scl_nedge;
    edge_detector_p ed_scl(.clk(clk), .reset_p(reset_p),
                       .cp(scl), .p_edge(scl_pedge),
                       .n_edge(scl_nedge));
    
    reg [2:0] count_usec5;
    reg scl_e;
    always @(posedge clk, posedge reset_p)begin
        if(reset_p)begin
            count_usec5 = 0;
            scl = 1;
        end
        else if(scl_e)begin
            if(clk_usec_nedge)begin
                if(count_usec5 >= 4)begin
                    count_usec5 = 0;
                    scl = ~scl;
                end
                else count_usec5 = count_usec5 + 1;
            end
        end
        else if(!scl_e)begin
            count_usec5 = 0;
            scl = 1;
        end
    end
    
    reg [6:0] state, next_state;
    always @(negedge clk, posedge reset_p)begin
        if(reset_p)state = IDLE;
        else state = next_state;
    end

    wire [7:0] addr_rw;
    assign addr_rw = {addr, rd_wr};
    reg [2:0] cnt_bit;
    reg stop_flag;
    always @(posedge clk, posedge reset_p)begin
        if(reset_p)begin
            next_state = IDLE;
            scl_e = 0;
            sda = 0;
            cnt_bit = 7;
            stop_flag = 0;
            busy = 0;
        end
        else begin
            case(state)
                IDLE      :begin
                    busy = 0;
                    scl_e = 0;
                    sda = 1;
                    if(comm_start_pedge)next_state = COMM_START;
                end
                COMM_START:begin
                    busy = 1;
                    sda = 0;
                    next_state = SEND_ADDR;
                end
                SEND_ADDR :begin
                    scl_e = 1;
                    if(scl_nedge)sda = addr_rw[cnt_bit];
                    if(scl_pedge)begin
                        if(cnt_bit == 0)begin
                            cnt_bit =7;
                            next_state = RD_ACK;
                        end
                        else cnt_bit = cnt_bit - 1;
                    end
                end
                RD_ACK    :begin
                    if(scl_nedge)sda = 'bz;
                    if(scl_pedge)begin
                        if(stop_flag)begin
                            stop_flag = 0;
                            next_state = SCL_STOP;
                        end
                        else begin
                            stop_flag = 1;
                            next_state = SEND_DATA;
                        end
                    end
                end
                SEND_DATA :begin
                    if(scl_nedge)sda = data[cnt_bit];
                    if(scl_pedge)begin
                        if(cnt_bit == 0)begin
                            cnt_bit =7;
                            next_state = RD_ACK;
                        end
                        else cnt_bit = cnt_bit - 1;
                    end
                end
                SCL_STOP  :begin
                    if(scl_nedge)sda = 0;
                    if(scl_pedge)next_state = COMM_STOP;
                end
                COMM_STOP :begin
                    if(count_usec5 >= 3)begin
                        scl_e = 0;
                        sda = 1;
                        next_state = IDLE;
                    end
                end
                default   :next_state = IDLE;
            endcase
        end
    end
endmodule

module i2c_lcd_send_byte(
    input clk, reset_p,
    input [6:0] addr, 
    input [7:0] send_buffer,
    input send, rs,
    output scl, sda,
    output reg busy
    );

    localparam IDLE                     = 6'b00_0001;
    localparam SEND_HIGH_NIBBLE_DISABLE = 6'b00_0010;
    localparam SEND_HIGH_NIBBLE_ENABLE  = 6'b00_0100;
    localparam SEND_LOW_NIBBLE_DISABLE  = 6'b00_1000;
    localparam SEND_LOW_NIBBLE_ENABLE   = 6'b01_0000;
    localparam SEND_DISABLE             = 6'b10_0000;
    
    wire clk_usec_nedge;
    clock_usec usec_clk(.clk(clk), .reset_p(reset_p), 
                        .clk_usec_nedge(clk_usec_nedge));
    wire send_pedge;
    edge_detector_p ed_start(.clk(clk), .reset_p(reset_p),
                       .cp(send), .p_edge(send_pedge));
                       
    reg [21:0] count_usec;
    reg count_usec_e;
    always @(negedge clk, posedge reset_p)begin
        if(reset_p)count_usec = 0;
        else if(clk_usec_nedge && count_usec_e)count_usec = count_usec + 1;
        else if(!count_usec_e)count_usec = 0;
    end 
                     
    reg [7:0] data;
    reg comm_start;
    wire i2c_busy;
    I2C_master master(clk, reset_p, addr, data, 1'b0, 
                                comm_start, scl, sda, i2c_busy);                   
    
    reg [5:0] state, next_state;
    always @(negedge clk, posedge reset_p)begin
        if(reset_p)state = IDLE;
        else state = next_state;
    end
    
    always @(posedge clk, posedge reset_p)begin
        if(reset_p)begin
            next_state = IDLE;
            comm_start = 0;
            count_usec_e = 0;
            data = 0;
            busy = 0;
        end
        else begin
            case(state)
                IDLE                    :begin
                    busy = 0;
                    if(send_pedge)begin
                        busy = 1;
                        next_state = SEND_HIGH_NIBBLE_DISABLE;
                    end
                end
                SEND_HIGH_NIBBLE_DISABLE:begin
                    if(count_usec >= 22'd200)begin
                        comm_start = 0;
                        next_state =  SEND_HIGH_NIBBLE_ENABLE;
                        count_usec_e = 0;
                    end
                    else begin
                              //d7 d6 d5 d4  BL en, rw, rs    
                        data = {send_buffer[7:4], 3'b100, rs};
                        comm_start = 1;
                        count_usec_e = 1;
                    end
                end
                SEND_HIGH_NIBBLE_ENABLE :begin
                    if(count_usec >= 22'd200)begin
                        comm_start = 0;
                        next_state = SEND_LOW_NIBBLE_DISABLE;
                        count_usec_e = 0;
                    end
                    else begin
                        data = {send_buffer[7:4], 3'b110, rs};
                        comm_start = 1;
                        count_usec_e = 1;
                    end
                end
                SEND_LOW_NIBBLE_DISABLE :begin
                    if(count_usec >= 22'd200)begin
                        comm_start = 0;
                        next_state =  SEND_LOW_NIBBLE_ENABLE;
                        count_usec_e = 0;
                    end
                    else begin
                        data = {send_buffer[3:0], 3'b100, rs};
                        comm_start = 1;
                        count_usec_e = 1;
                    end
                end
                SEND_LOW_NIBBLE_ENABLE  :begin
                    if(count_usec >= 22'd200)begin
                        comm_start = 0;
                        next_state = SEND_DISABLE;
                        count_usec_e = 0;
                    end
                    else begin
                        data = {send_buffer[3:0], 3'b110, rs};
                        comm_start = 1;
                        count_usec_e = 1;
                    end
                end
                SEND_DISABLE            :begin
                    if(count_usec >= 22'd200)begin
                        comm_start = 0;
                        next_state = IDLE;
                        count_usec_e = 0;
                    end
                    else begin
                        data = {send_buffer[3:0], 3'b100, rs};
                        comm_start = 1;
                        count_usec_e = 1;
                    end
                end
                default: next_state = IDLE;
            endcase
        end
    end
                       
endmodule





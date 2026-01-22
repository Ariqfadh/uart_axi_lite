`timescale 1ns / 1ps
module uart_tx #(
    parameter DATA_WIDTH = 8
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire [DATA_WIDTH-1:0]  tx_data,
    input  wire                   tx_start,
    input  wire [15:0]            prescale,
    output reg                    txd,
    output reg                    busy
);

    // Register 11-bit: [Stop(1) | Parity(1) | Data(8) | Start(0)]
    reg [10:0] shift_reg; 
    reg [18:0] timer;
    reg [3:0]  bit_cnt;
    reg [15:0] prescale_latched;

    always @(posedge clk) begin
        if (rst) begin
            txd <= 1; 
            busy <= 0; 
            timer <= 0; 
            bit_cnt <= 0;
            prescale_latched <= 0;
            shift_reg <= 11'h7FF; // Idle high
        end else begin
            if (!busy) begin
                txd <= 1;
                if (tx_start) begin
                    busy <= 1;
                    prescale_latched <= prescale;
                    // Latch data and count parity
                    shift_reg <= {1'b1, ^tx_data, tx_data, 1'b0};
                    bit_cnt <= 11;
                    // Send Start Bit
                    timer <= (prescale - 1);
                end
            end else begin
                if (timer > 0) begin
                    timer <= timer - 1;
                end else begin
                    if (bit_cnt > 0) begin
                        txd <= shift_reg[0];
                        shift_reg <= {1'b1, shift_reg[10:1]};
                        bit_cnt <= bit_cnt - 1;
                        timer <= prescale_latched - 1;
                    end else begin
                        busy <= 0;
                    end
                end
            end
        end
    end
endmodule
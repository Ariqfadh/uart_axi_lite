`timescale 1ns / 1ps

module uart_tx #(
    parameter DATA_WIDTH = 8
)(
    input  wire                  clk,
    input  wire                  rst,

    input  wire [DATA_WIDTH-1:0] tx_data,
    input  wire                  tx_start,
    output reg                   tx_busy,
    output reg                   tx_done,

    output reg                   txd,

    input  wire [15:0]           prescale
);

    // FSM states
    localparam TX_IDLE  = 2'd0;
    localparam TX_START = 2'd1;
    localparam TX_DATA  = 2'd2;
    localparam TX_STOP  = 2'd3;

    reg [1:0] tx_state;

    reg [DATA_WIDTH-1:0] data_shifter;
    reg [3:0]            bit_cnt;
    reg [15:0]           timer;
    reg [15:0]           prescale_latched;

    always @(posedge clk) begin
        if (rst) begin
            tx_state <= TX_IDLE;
            txd      <= 1'b1;
            tx_busy  <= 1'b0;
            tx_done  <= 1'b0;

            data_shifter     <= 0;
            bit_cnt          <= 0;
            timer            <= 0;
            prescale_latched <= 0;
        end else begin
            tx_done <= 1'b0;

            case (tx_state)
                TX_IDLE: begin
                    txd     <= 1'b1;
                    tx_busy <= 1'b0;

                    if (tx_start) begin
                        prescale_latched <= prescale;
                        data_shifter     <= tx_data;
                        timer            <= prescale - 1;
                        bit_cnt          <= 0;

                        txd      <= 1'b0;   // start bit
                        tx_busy <= 1'b1;
                        tx_state <= TX_START;
                    end
                end

                TX_START: begin
                    if (timer != 0) begin
                        timer <= timer - 1;
                    end else begin
                        timer    <= prescale_latched - 1;
                        txd      <= data_shifter[0];
                        data_shifter <= data_shifter >> 1;
                        bit_cnt  <= 1;
                        tx_state <= TX_DATA;
                    end
                end

                TX_DATA: begin
                    if (timer != 0) begin
                        timer <= timer - 1;
                    end else begin
                        timer <= prescale_latched - 1;

                        if (bit_cnt < DATA_WIDTH) begin
                            txd <= data_shifter[0];
                            data_shifter <= data_shifter >> 1;
                            bit_cnt <= bit_cnt + 1;
                        end else begin
                            txd <= 1'b1; // stop bit
                            tx_state <= TX_STOP;
                        end
                    end
                end

                TX_STOP: begin
                    if (timer != 0) begin
                        timer <= timer - 1;
                    end else begin
                        tx_state <= TX_IDLE;
                        tx_done  <= 1'b1;
                    end
                end

                default: tx_state <= TX_IDLE;
            endcase
        end
    end

endmodule

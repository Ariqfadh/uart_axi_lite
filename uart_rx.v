`timescale 1ns/1ps

module uart_rx #(
    parameter DATA_WIDTH = 8
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   rxd,
    input  wire [15:0]            prescale,

    output wire [DATA_WIDTH-1:0]  rx_data,
    output wire                   rx_ready,
    input  wire                   rx_ack,

    output wire                   busy,
    output reg                    overrun_error,
    output reg                    framing_error
);

    // ------------------------------------------------------------
    // Synchronizer
    // ------------------------------------------------------------
    reg rxd_ff0, rxd_ff1;

    // ------------------------------------------------------------
    // FIFO
    // ------------------------------------------------------------
    reg  fifo_wr_en;
    wire fifo_full, fifo_empty;
    wire [DATA_WIDTH-1:0] fifo_rd_data;

    // ------------------------------------------------------------
    // RX core
    // ------------------------------------------------------------
    reg [DATA_WIDTH-1:0] shifter;
    reg [15:0] timer;
    reg [3:0]  bit_cnt;
    reg [15:0] prescale_latched;

    // ------------------------------------------------------------
    // FSM
    // ------------------------------------------------------------
    localparam RX_IDLE  = 2'd0;
    localparam RX_START = 2'd1;
    localparam RX_DATA  = 2'd2;
    localparam RX_STOP  = 2'd3;

    reg [1:0] state;

    assign busy     = (state != RX_IDLE);
    assign rx_ready = !fifo_empty;
    assign rx_data  = fifo_rd_data;

    // ------------------------------------------------------------
    // FIFO instance
    // ------------------------------------------------------------
    rx_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(4)
    ) fifo (
        .clk     (clk),
        .rst     (rst),
        .wr_en   (fifo_wr_en),
        .wr_data (shifter),
        .full    (fifo_full),
        .rd_en   (rx_ack),
        .rd_data (fifo_rd_data),
        .empty   (fifo_empty)
    );

    // ------------------------------------------------------------
    // RX logic
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            rxd_ff0 <= 1'b1;
            rxd_ff1 <= 1'b1;

            state   <= RX_IDLE;
            timer   <= 0;
            bit_cnt <= 0;
            shifter <= 0;

            fifo_wr_en     <= 1'b0;
            overrun_error  <= 1'b0;
            framing_error  <= 1'b0;
        end else begin
            rxd_ff0 <= rxd;
            rxd_ff1 <= rxd_ff0;

            fifo_wr_en <= 1'b0;

            case (state)
                RX_IDLE: begin
                    bit_cnt <= 0;
                    if (!rxd_ff1) begin
                        prescale_latched <= prescale;
                        timer <= (prescale >> 1) - 1;
                        state <= RX_START;
                    end
                end

                RX_START: begin
                    if (timer != 0)
                        timer <= timer - 1;
                    else if (!rxd_ff1) begin
                        timer <= prescale_latched - 1;
                        state <= RX_DATA;
                    end else
                        state <= RX_IDLE;
                end

                RX_DATA: begin
                    if (timer != 0)
                        timer <= timer - 1;
                    else begin
                        shifter <= {rxd_ff1, shifter[DATA_WIDTH-1:1]};
                        timer   <= prescale_latched - 1;

                        if (bit_cnt == DATA_WIDTH-1)
                            state <= RX_STOP;
                        else
                            bit_cnt <= bit_cnt + 1;
                    end
                end

                RX_STOP: begin
                    if (timer != 0)
                        timer <= timer - 1;
                    else begin
                        if (rxd_ff1) begin
                            if (!fifo_full)
                                fifo_wr_en <= 1'b1;
                            else
                                overrun_error <= 1'b1;
                        end else
                            framing_error <= 1'b1;

                        state <= RX_IDLE;
                    end
                end
            endcase
        end
    end
endmodule

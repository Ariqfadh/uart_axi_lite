`timescale 1ns / 1ps
module uart_rx #(
    parameter DATA_WIDTH = 8
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   rxd,
    input  wire [15:0]            prescale,
    output reg  [DATA_WIDTH-1:0]  rx_data,
    output reg                    rx_ready,
    output reg                    busy
);

    reg rxd_sync_0, rxd_sync_1, rxd_reg;
    reg parity_received;
    reg parity_error;

    // Logic internal
    reg [DATA_WIDTH-1:0] data_shifter;
    reg [18:0] timer;
    reg [3:0]  bit_cnt;

    reg [15:0] prescale_latched;
    always @(posedge clk) begin
        if (busy && timer == 0) begin
        $display("TCK: %0t | Bit: %0d | Next Timer: %0d", $time, bit_cnt, prescale_latched);
        end
        if (timer > 1000000) begin // Kita naikin dikit limitnya biar aman
            $display("WARNING: Timer overflow at %0t! Value: %0d", $time, timer);
        end
        if (rst) begin
            rxd_sync_0 <= 1;
            rxd_sync_1 <= 1;
            rxd_reg <= 1;
            rx_ready <= 0;
            busy <= 0;
            timer <= 0;
            bit_cnt <= 0;
            prescale_latched <= 0;
        end else begin
            // Input synchronization
            rxd_sync_0 <= rxd;
            rxd_sync_1 <= rxd_sync_0;
            rxd_reg    <= rxd_sync_1;

            rx_ready <= 0; // Default pulse

        if (!busy) begin
                if (rxd_reg == 0) begin // Start bit detected
                    busy <= 1;
                    prescale_latched <= prescale;
                    timer <= (prescale >> 1) - 1; 
                    bit_cnt <= 0;
                end
            end else begin
                if (timer > 0) begin
                    timer <= timer - 1;
                end else begin
                    timer <= prescale_latched - 1; 

                    case (bit_cnt)
                        0: begin // Sample Start Bit
                            if (rxd_reg == 0) bit_cnt <= 1;
                            else busy <= 0; // Glitch filter
                        end
                        1,2,3,4,5,6,7,8: begin // Sample Data Bits
                            data_shifter <= {rxd_reg, data_shifter[7:1]};
                            bit_cnt <= bit_cnt + 1;
                        end
                        9: begin // Sample Parity
                            parity_received <= rxd_reg;
                            bit_cnt <= bit_cnt + 1;
                        end
                        10: begin // Sample Stop Bit
                            if (rxd_reg == 1 && (parity_received == ^data_shifter)) begin
                                rx_data <= data_shifter;
                                rx_ready <= 1;
                            end
                            busy <= 0;
                            bit_cnt <= 0;
                        end
                    endcase
                end
            end
        end
    end
endmodule
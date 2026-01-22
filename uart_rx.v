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
                // Start bit Detection
                if (rxd_reg == 0) begin 
                    busy <= 1;
                    prescale_latched <= prescale;
                    timer <= (prescale * 4) - 1;
                    bit_cnt <= 11;
                    data_shifter <= 0;
                end
            end else begin
                if (timer > 0) begin
                    timer <= timer - 1;
                end else begin
                    // Recheck Start Bit
                    if (bit_cnt == 11) begin
                        if (rxd_reg == 0) begin
                            // Start bit valid, wait for middle of first data bit
                            timer <= (prescale_latched * 8) - 1;
                            bit_cnt <= 10; // DATA_WIDTH + 2
                        end else begin
                            // Tnoise/glitch, abort reception
                            busy <= 0;
                        end
                    end
                    // bit_cnt 10 to 3: Data Bits
                    else if (bit_cnt > 2) begin
                        data_shifter <= {rxd_reg, data_shifter[DATA_WIDTH-1:1]};
                        bit_cnt <= bit_cnt - 1;
                        timer <= (prescale_latched * 8) - 1;
                    end 
                    // Parity Bit
                    else if (bit_cnt == 2) begin
                        parity_received <= rxd_reg;
                        bit_cnt <= bit_cnt - 1;
                        timer <= (prescale_latched * 8) - 1;
                    end 
                    // Check Stop Bit
                    else if (bit_cnt == 1) begin
                        if (rxd_reg == 1) begin
                            if (parity_received == ^data_shifter) begin
                                rx_data <= data_shifter;
                                rx_ready <= 1;
                            end
                        end
                        busy <= 0;
                        bit_cnt <= 0;
                    end
                end
            end
        end
    end
endmodule
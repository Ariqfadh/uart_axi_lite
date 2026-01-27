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
    input  wire                   rx_ack, 
    output wire                   busy,
    output reg                    overrun_error,
    output reg                    framing_error
);

    // Synchronizer (3-stage untuk mencegah metastability)
    reg rxd_sync_0, rxd_sync_1, rxd_reg;

    // RX core registers
    reg [DATA_WIDTH-1:0] data_shifter;
    reg [15:0]           timer;
    reg [3:0]            bit_cnt;
    reg [15:0]           prescale_latched;

    // FSM States
    localparam RX_IDLE  = 3'd0;
    localparam RX_START = 3'd1;
    localparam RX_DATA  = 3'd2;
    localparam RX_STOP  = 3'd3;

    reg [2:0] rx_state;

    // Busy aktif jika tidak di IDLE
    assign busy = (rx_state != RX_IDLE);

    always @(posedge clk) begin
        if (rst) begin
            rx_state <= RX_IDLE;
            rx_ready <= 1'b0;
            
            rxd_sync_0 <= 1'b1;
            rxd_sync_1 <= 1'b1;
            rxd_reg    <= 1'b1;

            timer            <= 0;
            bit_cnt          <= 0;
            prescale_latched <= 0;
            data_shifter     <= 0;
            rx_data          <= 0;

            overrun_error <= 1'b0;
            framing_error <= 1'b0;
        end else begin
            // CDC - 3-stage synchronizer
            rxd_sync_0 <= rxd;
            rxd_sync_1 <= rxd_sync_0;
            rxd_reg    <= rxd_sync_1;

            // Mekanisme Handshake untuk rx_ready
            if (rx_ack) begin
                rx_ready <= 1'b0;
            end

            case (rx_state)
                RX_IDLE: begin
                    bit_cnt <= 0;
                    // Reset error flags saat mulai menerima data baru (opsional)
                    // Atau biarkan sampai ada data sukses berikutnya
                    
                    if (!rxd_reg) begin // Start bit terdeteksi (falling edge)
                        prescale_latched <= prescale;
                        // Tunggu 1.5x prescale untuk sample di tengah bit DATA pertama
                        // Atau 0.5x untuk sample di tengah START bit
                        timer    <= (prescale >> 1) - 1;
                        rx_state <= RX_START;
                    end
                end

                RX_START: begin
                    if (timer != 0) begin
                        timer <= timer - 1;
                    end else begin
                        if (!rxd_reg) begin
                            // Start bit valid, set timer untuk 1 full bit period
                            timer    <= prescale_latched - 1;
                            bit_cnt  <= 0;
                            rx_state <= RX_DATA;
                        end else begin
                            // False start (glitch), balik ke IDLE
                            rx_state <= RX_IDLE;
                        end
                    end
                end

                RX_DATA: begin
                    if (timer != 0) begin
                        timer <= timer - 1;
                    end else begin
                        // Sample bit di tengah-tengah periode
                        data_shifter <= {rxd_reg, data_shifter[DATA_WIDTH-1:1]};
                        timer        <= prescale_latched - 1;
                        
                        if (bit_cnt == DATA_WIDTH-1) begin
                            rx_state <= RX_STOP;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end
                end

                RX_STOP: begin
                    if (timer != 0) begin
                        timer <= timer - 1;
                    end else begin
                        // Sample stop bit (harus bernilai HIGH)
                        if (rxd_reg) begin
                            if (rx_ready) begin
                                // Data sebelumnya belum di-ack tapi data baru sudah datang
                                overrun_error <= 1'b1;
                            end
                            
                            rx_data       <= data_shifter;
                            rx_ready      <= 1'b1;
                            framing_error <= 1'b0; // Valid stop bit
                        end else begin
                            // Stop bit LOW berarti Framing Error
                            framing_error <= 1'b1;
                        end
                        
                        rx_state <= RX_IDLE;
                    end
                end
                
                default: rx_state <= RX_IDLE;
            endcase
        end
    end

endmodule
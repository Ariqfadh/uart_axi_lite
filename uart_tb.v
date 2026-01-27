`timescale 1ns/1ps

module tb_uart;

    // ------------------------------------------------------------
    // Clock config (100 MHz)
    // ------------------------------------------------------------
    localparam CLK_FREQ   = 100_000_000;
    localparam CLK_PERIOD = 10;   // ns

    reg clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ------------------------------------------------------------
    // DUT signals
    // ------------------------------------------------------------
    reg rst;

    reg  rxd;
    wire txd;

    wire [7:0] rx_data;
    wire       rx_ready;
    reg        rx_ack;
    wire       rx_busy;

    wire rx_overrun_error;
    wire rx_framing_error;

    reg  [15:0] prescale;

    // TX not used
    reg  [7:0] tx_data  = 0;
    reg        tx_start = 0;
    wire       tx_busy;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    uart_top #(
        .DATA_WIDTH(8),
        .DEFAULT_PRESCALE(16'd868)
    ) dut (
        .clk(clk),
        .rst(rst),

        .tx_data(tx_data),
        .tx_start(tx_start),
        .tx_busy(tx_busy),

        .rx_data(rx_data),
        .rx_ready(rx_ready),
        .rx_ack(rx_ack),
        .rx_busy(rx_busy),

        .rx_overrun_error(rx_overrun_error),
        .rx_framing_error(rx_framing_error),

        .rxd(rxd),
        .txd(txd),

        .prescale(prescale)
    );

    // ------------------------------------------------------------
    // UART RX stimulus (CLOCK + PRESCALE SYNC)
    // ------------------------------------------------------------
    task uart_send_byte;
        input [7:0] data;
        integer bit_time;
        integer i;
        begin
            bit_time = prescale * CLK_PERIOD;

            @(posedge clk);

            // start bit
            rxd <= 1'b0;
            #(bit_time);

            // data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                rxd <= data[i];
                #(bit_time);
            end

            // stop bit
            rxd <= 1'b1;
            #(bit_time);
        end
    endtask

    // ------------------------------------------------------------
    // Test sequence
    // ------------------------------------------------------------
    initial begin
        // init
        rxd      = 1'b1;
        rst      = 1'b1;
        rx_ack  = 1'b0;
        prescale = 0;

        repeat (10) @(posedge clk);
        rst = 0;

        // ========================================================
        // TEST 1 : 9600 baud
        // ========================================================
        prescale = CLK_FREQ / 9600; // 10416
        $display("\n[TEST] RX @9600 baud | prescale=%0d", prescale);

        uart_send_byte(8'h55);

        wait (rx_ready);
        repeat (2) @(posedge clk);

        $display("RX_DATA = 0x%02X (expect 0x55)", rx_data);

        rx_ack <= 1'b1;
        @(posedge clk);
        rx_ack <= 1'b0;

        repeat (2000) @(posedge clk);

        // ========================================================
        // TEST 2 : 115200 baud
        // ========================================================
        prescale = CLK_FREQ / 115200; // 868
        $display("\n[TEST] RX @115200 baud | prescale=%0d", prescale);

        uart_send_byte(8'hA3);

        wait (rx_ready);
        repeat (2) @(posedge clk);

        $display("RX_DATA = 0x%02X (expect 0xA3)", rx_data);

        rx_ack <= 1'b1;
        @(posedge clk);
        rx_ack <= 1'b0;

        // ========================================================
        // DONE
        // ========================================================
        repeat (5000) @(posedge clk);
        $display("\nAll UART RX tests completed.");
        $finish;
    end

endmodule

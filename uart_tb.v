`timescale 1ns/1ps

module uart_top_tb;

    // --- Parameter Simulasi (100 MHz) ---
    parameter DATA_WIDTH = 8;
    parameter CLK_PERIOD = 10; 

    parameter BAUD_115200 = 16'd868;
    parameter BAUD_9600   = 16'd10417;

    // --- Sinyal ---
    reg  clk, rst;
    reg  [DATA_WIDTH-1:0] tx_data;
    reg  tx_start;
    wire tx_busy;
    wire [DATA_WIDTH-1:0] rx_data;
    wire rx_ready;
    reg  rx_ack;
    wire rx_busy, rx_overrun_error, rx_framing_error;
    wire txd_out;
    reg  rxd_in;
    reg  [15:0] prescale;

    // Statistik
    integer errors = 0;
    integer tests  = 0;

    // --- Jalur Loopback ---
    wire uart_line;
    reg  loopback_en;
    assign uart_line = loopback_en ? txd_out : rxd_in;

    // --- Instansiasi DUT ---
    uart_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEFAULT_PRESCALE(BAUD_115200)
    ) dut (
        .clk(clk), .rst(rst),
        .tx_data(tx_data), .tx_start(tx_start), .tx_busy(tx_busy),
        .rx_data(rx_data), .rx_ready(rx_ready), .rx_ack(rx_ack),
        .rx_busy(rx_busy), .rx_overrun_error(rx_overrun_error), .rx_framing_error(rx_framing_error),
        .rxd(uart_line), .txd(txd_out), .prescale(prescale)
    );

    // --- Clock Generator ---
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Helper Tasks ---
    
    task print_header(input [127:0] msg);
    begin
        $display("\n-------------------------------------------------------");
        $display(" %0s", msg);
        $display("-------------------------------------------------------");
    end
    endtask

    task send_byte(input [7:0] data);
    begin
        wait(!tx_busy);
        @(posedge clk);
        tx_data = data;
        tx_start = 1'b1;
        @(posedge clk);
        tx_start = 1'b0;
        wait(tx_busy);
        wait(!tx_busy);
        $display("[TIME: %0t] [TX] Sent: 0x%h", $time, data);
    end
    endtask

    task check_byte(input [7:0] expected);
    begin
        tests = tests + 1;
        fork : timeout_block
            begin
                wait(rx_ready);
                disable timeout_block;
            end
            begin
                #(CLK_PERIOD * prescale * 15);
                $display("[TIME: %0t] [RX] [FAIL] Timeout waiting for 0x%h", $time, expected);
                errors = errors + 1;
                disable timeout_block;
            end
        join

        if (rx_ready) begin
            if (rx_data === expected)
                $display("[TIME: %0t] [RX] [PASS] Received: 0x%h", $time, rx_data);
            else begin
                $display("[TIME: %0t] [RX] [FAIL] Received: 0x%h (Expected: 0x%h)", $time, rx_data, expected);
                errors = errors + 1;
            end
            @(posedge clk);
            rx_ack = 1'b1;
            @(posedge clk);
            rx_ack = 1'b0;
        end
    end
    endtask

    // --- Main Simulation ---
    initial begin
        clk = 0; rst= 1; tx_data = 0; tx_start = 0; rx_ack = 0;
        rxd_in = 1'b1; prescale = BAUD_115200; loopback_en = 1;

        $display("\n=======================================================");
        $display("   UART CORE VERIFICATION DASHBOARD (100 MHz)");
        $display("=======================================================");

        #(CLK_PERIOD*10); rst = 0; #(CLK_PERIOD*10);

        print_header("TEST 1: BURST TRANSFER (115200 BAUD)");
        fork
            begin
                send_byte(8'hDE); send_byte(8'hAD); 
                send_byte(8'hBE); send_byte(8'hEF);
            end
            begin
                check_byte(8'hDE); check_byte(8'hAD); 
                check_byte(8'hBE); check_byte(8'hEF);
            end
        join

        print_header("TEST 2: LOW SPEED PRECISION (9600 BAUD)");
        prescale = BAUD_9600;
        #(CLK_PERIOD*100);
        fork
            send_byte(8'h5A);
            check_byte(8'h5A);
        join

        print_header("TEST 3: FIFO OVERRUN PROTECTION");
        prescale = 16'd100; // Fast baud for testing
        tests = tests + 1;
        
        send_byte(8'h01); send_byte(8'h02);
        send_byte(8'h03); send_byte(8'h04);
        send_byte(8'h05); // Overflow trigger

        #(CLK_PERIOD*50);
        if (rx_overrun_error)
            $display("[STATUS] Overrun Flag: [PASS] Detected correctly");
        else begin
            $display("[STATUS] Overrun Flag: [FAIL] Not detected");
            errors = errors + 1;
        end

        $display("\n=======================================================");
        $display("              SIMULATION FINAL REPORT");
        $display("=======================================================");
        $display(" Total Tests Conducted : %0d", tests);
        $display(" Total Errors Found     : %0d", errors);
        if (errors == 0)
            $display(" Final Status           : [SUCCESS]");
        else
            $display(" Final Status           : [FAILED]");
        $display("=======================================================\n");

        #(CLK_PERIOD*100);
        $finish;
    end

endmodule
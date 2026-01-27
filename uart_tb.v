`timescale 1ns/1ps

module uart_tb;

    // --- Signals ---
    reg clk;
    reg rst;
    reg rxd;
    reg rx_ack;
    reg [15:0] prescale;

    wire [7:0] rx_data;
    wire rx_ready;
    wire busy;
    wire overrun_error;
    wire framing_error;

    // --- Device Under Test (DUT) ---
    uart_rx dut (
        .clk     (clk),
        .rst     (rst),
        .rxd     (rxd),
        .prescale(prescale),
        .rx_data (rx_data),
        .rx_ready(rx_ready),
        .rx_ack  (rx_ack),
        .busy    (busy),
        .overrun_error(overrun_error),
        .framing_error(framing_error)
    );

    // --- Clock Generator (100 MHz) ---
    initial clk = 0;
    always #5 clk = ~clk;

    // --- Professional UI Task: Send UART Frame ---
    task uart_send;
        input [7:0] data;
        integer i;
        begin
            $display("  [TX] Sending: 0x%02x ...", data);
            rxd = 0; // Start bit
            repeat (prescale) @(posedge clk);

            for (i = 0; i < 8; i = i + 1) begin
                rxd = data[i]; // LSB First
                repeat (prescale) @(posedge clk);
            end

            rxd = 1; // Stop bit
            repeat (prescale) @(posedge clk);
        end
    endtask

    // --- Professional UI Task: Read & Verify FIFO ---
    task read_fifo;
        input [7:0] expected;
        begin
            wait(rx_ready);
            // In FWFT FIFO, data is already stable on the bus
            if (rx_data === expected)
                $display("  [RX] Data: 0x%02x | Status: [  OK  ]", rx_data);
            else
                $display("  [RX] Data: 0x%02x | Status: [FAILED] (Expected: 0x%02x)", rx_data, expected);

            // Acknowledge pulse
            @(posedge clk);
            rx_ack <= 1;
            @(posedge clk);
            rx_ack <= 0;
            @(posedge clk); // Allow FIFO to update count
        end
    endtask

    // --- Main Simulation Sequence ---
    initial begin
        // Reset Phase
        rxd = 1; rx_ack = 0; rst = 1; prescale = 0;
        #100;
        @(posedge clk);
        rst = 0;
        #50;

        $display("\n=======================================================");
        $display("   STARTING UART RX CORE FUNCTIONAL VERIFICATION");
        $display("=======================================================");

        // --- TEST CASE 1: 115200 BAUD BURST ---
        prescale = 868; // 100MHz / 115200
        $display("\n[TEST 1] High Speed (115200 Baud) - FIFO Burst Test");
        $display("-------------------------------------------------------");
        
        uart_send(8'hDE);
        uart_send(8'hAD);
        uart_send(8'hBE);
        uart_send(8'hEF);

        $display("\n  Retrieving from FIFO:");
        read_fifo(8'hDE);
        read_fifo(8'hAD);
        read_fifo(8'hBE);
        read_fifo(8'hEF);

        // --- TEST CASE 2: 9600 BAUD ACCURACY ---
        #2000;
        prescale = 10417; // 100MHz / 9600
        $display("\n[TEST 2] Low Speed (9600 Baud) - Precision Test");
        $display("-------------------------------------------------------");
        
        uart_send(8'h5A);
        read_fifo(8'h5A);

        // --- TEST CASE 3: OVERRUN PROTECTION ---
        #2000;
        prescale = 868; 
        $display("\n[TEST 3] FIFO Buffer Overflow (Overrun) Test");
        $display("-------------------------------------------------------");
        
        $display("  [SYS] Filling FIFO with 5 bytes (Capacity: 4)...");
        uart_send(8'h01);
        uart_send(8'h02);
        uart_send(8'h03);
        uart_send(8'h04);
        uart_send(8'h05); // Should trigger overrun

        #100;
        if (overrun_error) 
            $display("  [STATUS] Overrun Detected: YES [PASSED]");
        else               
            $display("  [STATUS] Overrun Detected: NO  [FAILED]");

        // Clean up
        $display("\n=======================================================");
        $display("            SIMULATION COMPLETED SUCCESSFULLY");
        $display("=======================================================");
        #500;
        $finish;
    end

endmodule
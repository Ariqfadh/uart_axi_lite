`timescale 1ns / 1ps

module uart_multi_baud_tb();
    reg clk;
    reg rst;
    
    // Signals
    reg [7:0] tx_data;
    reg tx_start;
    reg [15:0] current_baud_div;
    wire tx_busy, uart_line, rx_done;
    wire [7:0] rx_data;
    
    // Clock 100 MHz
    always #5 clk = ~clk;

    // Unit Under Test (UUT)
    uart_top dut (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_busy(tx_busy),
        .rx_data(rx_data),
        .rx_ready(rx_ready),
        .rx_busy(rx_busy),
        .rxd(uart_line),
        .txd(uart_line),
        .prescale(current_baud_div)
    );

    task send_and_check(input [7:0] data, input [15:0] div_val);
        begin
            current_baud_div = div_val;
            tx_data = data;
            #100;
            tx_start = 1;
            #10 tx_start = 0;
            
            wait(rx_done);
            if (rx_data == data)
                $display("[SUCCESS] BaudDiv: %0d | Sent: %h | Received: %h", div_val, data, rx_data);
            else
                $display("[FAILED]  BaudDiv: %0d | Sent: %h | Received: %h", div_val, data, rx_data);
            #5000; // Jeda antar transfer
        end
    endtask

    initial begin
        clk = 0;
        rst = 1;
        tx_start = 0;
        current_baud_div = 868; // Default 115200
        
        #20 rst = 0;
        #100;

        $display("--- Starting Multi-Baud Rate Test ---");

        // Test 1: 115200 Baud (Div = 868 @ 100MHz)
        send_and_check(8'hA5, 868);

        // Test 2: 9600 Baud (Div = 10416 @ 100MHz)
        send_and_check(8'h3C, 10416);

        // Test 3: Custom High Speed (misal 1 Mbaud, Div = 100)
        send_and_check(8'hFF, 100);

        $display("--- All Tests Completed ---");
        #1000 $finish;
    end
endmodule
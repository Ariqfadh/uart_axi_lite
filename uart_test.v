//`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Reference Book: FPGA Prototyping By Verilog Examples Xilinx Spartan-3 Version
//// Authored by: Dr. Pong P. Chu
//// Published by: Wiley
////
//// Adapted for the Basys 3 Artix-7 FPGA by David J. Marion
////
//// UART System Verification Circuit
////
//// Comments:
//// - Many of the variable names have been changed for clarity
////////////////////////////////////////////////////////////////////////////////////

//module uart_test(
//    input clk_100MHz,       // basys 3 FPGA clock signal
//    input reset,            // btnR    
//    input rx,               // USB-RS232 Rx
//    input btn,              // btnL (read and write FIFO operation)
//    output tx,              // USB-RS232 Tx
//    output [3:0] an,        // 7 segment display digits
//    output [0:6] seg,       // 7 segment display segments
//    output [7:0] LED        // data byte display
//    );
    
//    // Connection Signals
//    wire rx_full, rx_empty, btn_tick;
//    wire [7:0] rec_data, rec_data1;
    
//    // Complete UART Core
//    uart_top UART_UNIT
//        (
//            .clk_100MHz(clk_100MHz),
//            .reset(reset),
//            .read_uart(btn_tick),
//            .write_uart(btn_tick),
//            .rx(rx),
//            .write_data(rec_data1),
//            .rx_full(rx_full),
//            .rx_empty(rx_empty),
//            .read_data(rec_data),
//            .tx(tx)
//        );
    
//    // Button Debouncer
//    debounce_explicit BUTTON_DEBOUNCER
//        (
//            .clk_100MHz(clk_100MHz),
//            .reset(reset),
//            .btn(btn),         
//            .db_level(),  
//            .db_tick(btn_tick)
//        );
    
//    // Signal Logic    
//    assign rec_data1 = rec_data;    // add 1 to ascii value of received data (to transmit)
    
//    // Output Logic
//    assign LED = rec_data;              // data byte received displayed on LEDs
//    assign an = 4'b1110;                // using only one 7 segment digit 
//    assign seg = {~rx_full, 2'b11, ~rx_empty, 3'b111};
//endmodule

`timescale 1ns / 1ps

module uart_axi_monitor_v1_0 #
(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 4
)
(
    // Physical Ports (Basys 3)
    input  wire rx,
    output wire tx,
    output wire [7:0] LED,       // Menampilkan data RX terakhir
    output wire [3:0] an,        // Digit 7-seg
    output wire [0:6] seg,       // Segment 7-seg
    
    // AXI4-Lite Ports
    input  wire  S_AXI_ACLK,
    input  wire  S_AXI_ARESETN,
    input  wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    input  wire  S_AXI_AWVALID,
    output wire  S_AXI_AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    input  wire  S_AXI_WVALID,
    output wire  S_AXI_WREADY,
    output wire [1 : 0] S_AXI_BRESP,
    output wire  S_AXI_BVALID,
    input  wire  S_AXI_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    input  wire  S_AXI_ARVALID,
    output wire  S_AXI_ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    output wire [1 : 0] S_AXI_RRESP,
    output wire  S_AXI_RVALID,
    input  wire  S_AXI_RREADY
);

    // Internal Signals
    wire [7:0] read_data;
    wire rx_empty, rx_full;
    reg  read_uart, write_uart;
    wire reset_high = ~S_AXI_ARESETN;

    // Register untuk menahan data terakhir agar LED tetap menyala
    reg [7:0] last_rx_data;

    // AXI Registers
    reg [31:0] slv_reg0; // TX Data
    reg axi_awready, axi_wready, axi_arready, axi_rvalid, axi_bvalid;

    // Assignment Physical Ports (Sesuai logic uart_test Anda)
    assign LED = last_rx_data;
    assign an  = 4'b1110; 
    assign seg = {~rx_full, 2'b11, ~rx_empty, 3'b111}; // Indikator Full & Empty

    // --- AXI Write Logic (Kirim ke UART) ---
    always @(posedge S_AXI_ACLK) begin
        if (reset_high) begin
            axi_awready <= 1'b0;
            axi_wready  <= 1'b0;
            write_uart  <= 1'b0;
            slv_reg0    <= 32'b0;
        end else begin
            if (S_AXI_AWVALID && S_AXI_WVALID && !axi_awready) begin
                axi_awready <= 1'b1;
                axi_wready  <= 1'b1;
                if (S_AXI_AWADDR[3:2] == 2'b00) begin
                    slv_reg0   <= S_AXI_WDATA;
                    write_uart <= 1'b1; // Trigger TX FIFO
                end
            end else begin
                axi_awready <= 1'b0;
                axi_wready  <= 1'b0;
                write_uart  <= 1'b0;
            end
        end
    end
    
    assign S_AXI_BVALID = axi_bvalid;
    assign S_AXI_BRESP  = 2'b00;
    always @(posedge S_AXI_ACLK) begin
        if (reset_high) axi_bvalid <= 1'b0;
        else if (axi_awready && axi_wready) axi_bvalid <= 1'b1;
        else if (S_AXI_BREADY) axi_bvalid <= 1'b0;
    end

    // --- AXI Read Logic (Ambil dari UART) ---
    reg [31:0] reg_data_out;
    assign S_AXI_RDATA = reg_data_out;

    always @(posedge S_AXI_ACLK) begin
        if (reset_high) begin
            axi_arready <= 1'b0;
            axi_rvalid  <= 1'b0;
            read_uart   <= 1'b0;
            last_rx_data <= 8'b0;
        end else begin
            if (S_AXI_ARVALID && !axi_arready) begin
                axi_arready <= 1'b1;
                axi_rvalid  <= 1'b1;
                case (S_AXI_ARADDR[3:2])
                    2'b00: begin 
                        reg_data_out <= {24'b0, read_data};
                        read_uart    <= 1'b1;        // Trigger RX FIFO Read
                        last_rx_data <= read_data;   // Update LED
                    end
                    2'b01: reg_data_out <= {30'b0, rx_full, rx_empty};
                    default: reg_data_out <= 32'b0;
                endcase
            end else begin
                axi_arready <= 1'b0;
                read_uart   <= 1'b0;
                if (S_AXI_RREADY && axi_rvalid) axi_rvalid <= 1'b0;
            end
        end
    end

    assign S_AXI_RRESP = 2'b00;

    // --- UART Top Instance ---
    uart_top #(
        .BR_LIMIT(651), // 9600 Baud
        .BR_BITS(10),
        .FIFO_EXP(4)
    ) UART_CORE (
        .clk_100MHz(S_AXI_ACLK),
        .reset(reset_high),
        .read_uart(read_uart),
        .write_uart(write_uart),
        .rx(rx),
        .write_data(slv_reg0[7:0]),
        .rx_full(rx_full),
        .rx_empty(rx_empty),
        .tx(tx),
        .read_data(read_data)
    );

endmodule
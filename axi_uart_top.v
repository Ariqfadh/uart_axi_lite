`timescale 1ns / 1ps

module axi_uart_top (
    // Pins Fisik
    input  wire rx,
    output wire tx,
    output wire [7:0] LED,
    output wire [3:0] an,
    output wire [0:6] seg,
    
    // Interface untuk VIO (Dicolok di Block Design)
    output wire [7:0] monitor_read_data,
    output wire monitor_rx_empty,
    output wire monitor_rx_full,
    input  wire [7:0] vio_write_data,
    input  wire vio_write_uart,
    input  wire vio_read_uart,

    // Interface AXI4-Lite
    input  wire  S_AXI_ACLK,
    input  wire  S_AXI_ARESETN,
    input  wire [3:0] S_AXI_AWADDR,
    input  wire  S_AXI_AWVALID,
    output wire  S_AXI_AWREADY,
    input  wire [31:0] S_AXI_WDATA,
    input  wire  S_AXI_WVALID,
    output wire  S_AXI_WREADY,
    output wire [1:0] S_AXI_BRESP,
    output wire  S_AXI_BVALID,
    input  wire  S_AXI_BREADY,
    input  wire [3:0] S_AXI_ARADDR,
    input  wire  S_AXI_ARVALID,
    output wire  S_AXI_ARREADY,
    output wire [31:0] S_AXI_RDATA,
    output wire [1:0] S_AXI_RRESP,
    output wire  S_AXI_RVALID,
    input  wire  S_AXI_RREADY
);

    wire axi_wr, axi_rd, rx_empty, rx_full;
    wire [7:0] axi_wdata, uart_rdata;
    reg  [7:0] last_rx_data;

    // Logic Gabungan (AXI OR VIO)
    wire final_wr = axi_wr | vio_write_uart;
    wire final_rd = axi_rd | vio_read_uart;
    wire [7:0] final_wdata = (axi_wr) ? axi_wdata : vio_write_data;

    // Monitor Output
    assign LED = last_rx_data;
    assign an  = 4'b1110;
    assign seg = {~rx_full, 2'b11, ~rx_empty, 3'b111};
    assign monitor_read_data = uart_rdata;
    assign monitor_rx_empty  = rx_empty;
    assign monitor_rx_full   = rx_full;

    always @(posedge S_AXI_ACLK) if(axi_rd) last_rx_data <= uart_rdata;

    // Instansiasi Modul AXI Slave
    uart_axi_slave AXI_BUS_HANDLER (
        .S_AXI_ACLK(S_AXI_ACLK), .S_AXI_ARESETN(S_AXI_ARESETN),
        .axi_wr_pulse(axi_wr), .axi_rd_pulse(axi_rd),
        .axi_wdata(axi_wdata), .axi_rdata(uart_rdata),
        .uart_status({rx_full, rx_empty}),
        .S_AXI_AWADDR(S_AXI_AWADDR), .S_AXI_AWVALID(S_AXI_AWVALID), .S_AXI_AWREADY(S_AXI_AWREADY),
        .S_AXI_WDATA(S_AXI_WDATA), .S_AXI_WVALID(S_AXI_WVALID), .S_AXI_WREADY(S_AXI_WREADY),
        .S_AXI_BRESP(S_AXI_BRESP), .S_AXI_BVALID(S_AXI_BVALID), .S_AXI_BREADY(S_AXI_BREADY),
        .S_AXI_ARADDR(S_AXI_ARADDR), .S_AXI_ARVALID(S_AXI_ARVALID), .S_AXI_ARREADY(S_AXI_ARREADY),
        .S_AXI_RDATA(S_AXI_RDATA), .S_AXI_RRESP(S_AXI_RRESP), .S_AXI_RVALID(S_AXI_RVALID), .S_AXI_RREADY(S_AXI_RREADY)
    );

    // Instansiasi Modul UART Core (Pastikan file uart_top.v sudah ada)
    uart_top #( .BR_LIMIT(651) ) UART_LOGIC (
        .clk_100MHz(S_AXI_ACLK), .reset(~S_AXI_ARESETN),
        .read_uart(final_rd), .write_uart(final_wr),
        .rx(rx), .write_data(final_wdata),
        .rx_full(rx_full), .rx_empty(rx_empty),
        .tx(tx), .read_data(uart_rdata)
    );

endmodule
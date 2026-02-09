`timescale 1ns / 1ps

module uart_axi_slave #
(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 4
)
(
    // Interface ke Logic UART
    output reg  axi_wr_pulse,
    output reg  axi_rd_pulse,
    output wire [7:0] axi_wdata,
    input  wire [7:0] axi_rdata,
    input  wire [1:0] uart_status, // [1]=full, [0]=empty

    // Ports AXI4-Lite
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

    reg [31:0] slv_reg0; 
    reg axi_awready, axi_wready, axi_arready, axi_rvalid, axi_bvalid;
    reg [31:0] rdata_buf;

    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = rdata_buf;
    assign S_AXI_RVALID  = axi_rvalid;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_BRESP = 2'b00; assign S_AXI_RRESP = 2'b00;
    assign axi_wdata = slv_reg0[7:0];

    // Write Logic
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_awready <= 0; axi_wready <= 0; axi_bvalid <= 0; axi_wr_pulse <= 0;
        end else begin
            if (S_AXI_AWVALID && S_AXI_WVALID && !axi_awready) begin
                axi_awready <= 1; axi_wready <= 1;
                if (S_AXI_AWADDR[3:2] == 2'b00) begin
                    slv_reg0 <= S_AXI_WDATA;
                    axi_wr_pulse <= 1;
                end
            end else begin
                axi_awready <= 0; axi_wready <= 0; axi_wr_pulse <= 0;
            end
            if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 0;
            else if (axi_awready && axi_wready) axi_bvalid <= 1;
        end
    end

    // Read Logic
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_arready <= 0; axi_rvalid <= 0; axi_rd_pulse <= 0;
        end else begin
            if (S_AXI_ARVALID && !axi_arready) begin
                axi_arready <= 1; axi_rvalid <= 1;
                case (S_AXI_ARADDR[3:2])
                    2'b00: begin rdata_buf <= {24'b0, axi_rdata}; axi_rd_pulse <= 1; end
                    2'b01: rdata_buf <= {30'b0, uart_status};
                    default: rdata_buf <= 0;
                endcase
            end else begin
                axi_arready <= 0; axi_rd_pulse <= 0;
                if (S_AXI_RREADY && axi_rvalid) axi_rvalid <= 0;
            end
        end
    end
endmodule
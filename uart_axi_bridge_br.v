module uart_axi_bridge (
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready,
    output reg  [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,
    output reg  [31:0] s_axi_rdata,
    output reg  [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,

    input  wire        uart_rx,
    output wire        uart_tx
);

    reg  [15:0] reg_br_limit;
    reg         write_uart_reg, read_uart_reg;
    reg  [7:0]  write_data_reg;
    wire [7:0]  read_data_wire;
    wire        rx_full_wire, rx_empty_wire, reset_sync;

    assign reset_sync = ~s_axi_aresetn;

    // --- WRITE LOGIC ---
    always @(posedge s_axi_aclk) begin
        if (reset_sync) begin
            s_axi_awready  <= 0; s_axi_wready <= 0; s_axi_bvalid <= 0;
            write_uart_reg <= 0; read_uart_reg <= 0;
            reg_br_limit   <= 16'd651; // Default: 9600 Baud @ 100MHz
        end else begin
            if (!s_axi_awready && s_axi_awvalid && s_axi_wvalid) begin
                s_axi_awready <= 1; s_axi_wready <= 1;
                case (s_axi_awaddr[4:0])
                    5'h00: begin write_data_reg <= s_axi_wdata[7:0]; write_uart_reg <= 1; end
                    5'h0C: begin read_uart_reg  <= s_axi_wdata[0]; end
                    5'h10: begin reg_br_limit   <= s_axi_wdata[15:0]; end
                endcase
            end else begin
                s_axi_awready <= 0; s_axi_wready <= 0;
                write_uart_reg <= 0; read_uart_reg <= 0;
            end

            if (s_axi_awready && s_axi_wready) begin
                s_axi_bvalid <= 1; s_axi_bresp <= 2'b00;
            end else if (s_axi_bready && s_axi_bvalid) begin
                s_axi_bvalid <= 0;
            end
        end
    end

    // --- READ LOGIC ---
    always @(posedge s_axi_aclk) begin
        if (reset_sync) begin
            s_axi_arready <= 0; s_axi_rvalid <= 0;
        end else begin
            if (!s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1; s_axi_rvalid <= 1;
                case (s_axi_araddr[7:0])
                    5'h04: s_axi_rdata <= {24'b0, read_data_wire};
                    5'h08: s_axi_rdata <= {30'b0, rx_full_wire, rx_empty_wire};
                    5'h10: s_axi_rdata <= {16'b0, reg_br_limit};
                    default: s_axi_rdata <= 32'hDEADBEEF;
                endcase
            end else begin
                s_axi_arready <= 0;
                if (s_axi_rready && s_axi_rvalid) s_axi_rvalid <= 0;
            end
        end
    end

    uart_top my_uart_core (
        .clk_100MHz(s_axi_aclk), .reset(reset_sync),
        .read_uart(read_uart_reg), .write_uart(write_uart_reg),
        .rx(uart_rx), .tx(uart_tx),
        .br_limit_in(reg_br_limit),
        .write_data(write_data_reg), .read_data(read_data_wire),
        .rx_full(rx_full_wire), .rx_empty(rx_empty_wire)
    );

endmodule
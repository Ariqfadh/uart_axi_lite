module top_axi_uart_fpga (
    input  wire clk,
    input  wire rst_n,
    input  wire rx,
    output wire tx
);

    wire vio_start;
    wire [7:0] vio_wdata;

    reg  [5:0] awaddr;
    reg        awvalid;
    wire       awready;
    reg  [31:0] wdata;
    reg        wvalid;
    wire       wready;
    wire       bvalid;
    reg        bready;

    reg [1:0] state;
    localparam IDLE=0, AW_W=1, WAIT_B=2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=IDLE; awvalid<=0; wvalid<=0; bready<=0;
        end else begin
            case (state)
            IDLE: if (vio_start) begin
                    awaddr<=6'h00;
                    wdata<={24'h0,vio_wdata};
                    awvalid<=1; wvalid<=1;
                    state<=AW_W;
                  end
            AW_W: if (awready && wready) begin
                    awvalid<=0; wvalid<=0; bready<=1;
                    state<=WAIT_B;
                  end
            WAIT_B: if (bvalid) begin
                    bready<=0; state<=IDLE;
                  end
            endcase
        end
    end

    axi_uart_lite dut (
        .clk(clk), .rst_n(rst_n),
        .s_axi_awaddr(awaddr),
        .s_axi_awvalid(awvalid),
        .s_axi_awready(awready),
        .s_axi_wdata(wdata),
        .s_axi_wstrb(4'b0001),
        .s_axi_wvalid(wvalid),
        .s_axi_wready(wready),
        .s_axi_bresp(),
        .s_axi_bvalid(bvalid),
        .s_axi_bready(bready),
        .s_axi_araddr(6'd0),
        .s_axi_arvalid(1'b0),
        .s_axi_arready(),
        .s_axi_rdata(),
        .s_axi_rresp(),
        .s_axi_rvalid(),
        .s_axi_rready(1'b0),
        .write_uart(),
        .write_data(),
        .read_uart(),
        .read_data(),
        .tx_empty(1'b1),
        .rx_empty(1'b1),
        .rx_full(1'b0)
    );

    vio_uart vio (.clk(clk), .vio_start(vio_start), .vio_wdata(vio_wdata));
endmodule
//YANG INI JALAN CUI
module uart_axi_bridge (
    // AXI4-Lite Interface
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,
    
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready,
    
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
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

    // Physical UART Pins
    input  wire        uart_rx,
    output wire        uart_tx
);

    // Internal Signals to UART Top
    reg         write_uart_reg;
    reg         read_uart_reg;
    reg  [7:0]  write_data_reg;
    wire [7:0]  read_data_wire;
    wire        rx_full_wire;
    wire        rx_empty_wire;
    wire        reset_sync;

    // AXI Reset is Active Low, UART Top Reset is Active High
    assign reset_sync = ~s_axi_aresetn;

    // --- AXI WRITE LOGIC ---
    always @(posedge s_axi_aclk) begin
        if (reset_sync) begin
            s_axi_awready  <= 1'b0;
            s_axi_wready   <= 1'b0;
            s_axi_bvalid   <= 1'b0;
            write_uart_reg <= 1'b0;
            read_uart_reg  <= 1'b0;
        end else begin
            // Write Transaction Handshake
            if (!s_axi_awready && s_axi_awvalid && s_axi_wvalid) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                
                case (s_axi_awaddr[3:0])
                    4'h0: begin // Alamat 0x00: Write Data
                        write_data_reg <= s_axi_wdata[7:0];
                        write_uart_reg <= 1'b1;
                    end
                    4'hC: begin // Alamat 0x0C: Control (Pop RX FIFO)
                        read_uart_reg  <= s_axi_wdata[0];
                    end
                endcase
            end else begin
                s_axi_awready  <= 1'b0;
                s_axi_wready   <= 1'b0;
                write_uart_reg <= 1'b0;
                read_uart_reg  <= 1'b0;
            end

            // Write Response
            if (s_axi_awready && s_axi_wready) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00; // OKAY
            end else if (s_axi_bready && s_axi_bvalid) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // --- AXI READ LOGIC ---
    always @(posedge s_axi_aclk) begin
        if (reset_sync) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= 32'b0;
        end else begin
            if (!s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid  <= 1'b1;
                s_axi_rresp   <= 2'b00;
                
                case (s_axi_araddr[3:0])
                    4'h4: s_axi_rdata <= {24'b0, read_data_wire}; // Baca data dari RX FIFO
                    4'h8: s_axi_rdata <= {30'b0, rx_full_wire, rx_empty_wire}; // Status
                    default: s_axi_rdata <= 32'hDEADBEEF;
                endcase
            end else begin
                s_axi_arready <= 1'b0;
                if (s_axi_rready && s_axi_rvalid) begin
                    s_axi_rvalid <= 1'b0;
                end
            end
        end
    end

    // --- INSTANTIATE YOUR UART TOP ---
    uart_top #(
        .DBITS(8),
        .SB_TICK(16),
        .BR_LIMIT(651), // 9600 Baud
        .BR_BITS(10),
        .FIFO_EXP(2)
    ) my_uart_core (
        .clk_100MHz(s_axi_aclk),
        .reset(reset_sync),
        .read_uart(read_uart_reg),
        .write_uart(write_uart_reg),
        .rx(uart_rx),
        .write_data(write_data_reg),
        .rx_full(rx_full_wire),
        .rx_empty(rx_empty_wire),
        .tx(uart_tx),
        .read_data(read_data_wire)
    );

endmodule
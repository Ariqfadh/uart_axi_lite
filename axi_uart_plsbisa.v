module uart_axi_lite_slave (
    // AXI4-Lite Interface
    input  wire        S_AXI_ACLK,
    input  wire        S_AXI_ARESETN,
    
    // Write Address Channel
    input  wire [31:0] S_AXI_AWADDR,
    input  wire        S_AXI_AWVALID,
    output reg         S_AXI_AWREADY,
    
    // Write Data Channel
    input  wire [31:0] S_AXI_WDATA,
    input  wire [3:0]  S_AXI_WSTRB,
    input  wire        S_AXI_WVALID,
    output reg         S_AXI_WREADY,
    
    // Write Response Channel
    output reg  [1:0]  S_AXI_BRESP,
    output reg         S_AXI_BVALID,
    input  wire        S_AXI_BREADY,
    
    // Read Address Channel
    input  wire [31:0] S_AXI_ARADDR,
    input  wire        S_AXI_ARVALID,
    output reg         S_AXI_ARREADY,
    
    // Read Data Channel
    output reg  [31:0] S_AXI_RDATA,
    output reg  [1:0]  S_AXI_RRESP,
    output reg         S_AXI_RVALID,
    input  wire        S_AXI_RREADY,

    // UART Signals (Connect to your core)
    output reg  [7:0]  uart_tx_data,
    output reg         uart_tx_en,
    input  wire        uart_busy
);

    // Internal signals
    reg [31:0] reg_status;

    // --- WRITE LOGIC ---
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
            S_AXI_BVALID  <= 1'b0;
            uart_tx_en    <= 1'b0;
        end else begin
            // Handshake Address & Data
            if (!S_AXI_AWREADY && S_AXI_AWVALID && S_AXI_WVALID) begin
                S_AXI_AWREADY <= 1'b1;
                S_AXI_WREADY  <= 1'b1;
                
                // Jika alamat 0, kirim data ke core UART
                if (S_AXI_AWADDR[3:0] == 4'h0) begin
                    uart_tx_data <= S_AXI_WDATA[7:0];
                    uart_tx_en   <= 1'b1;
                end
            end else begin
                S_AXI_AWREADY <= 1'b0;
                S_AXI_WREADY  <= 1'b0;
                uart_tx_en    <= 1'b0;
            end

            // Write Response
            if (S_AXI_AWREADY && S_AXI_AWVALID && S_AXI_WREADY && S_AXI_WVALID) begin
                S_AXI_BVALID <= 1'b1;
                S_AXI_BRESP  <= 2'b00; // OKAY
            end else if (S_AXI_BREADY && S_AXI_BVALID) begin
                S_AXI_BVALID <= 1'b0;
            end
        end
    end

    // --- READ LOGIC ---
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_ARREADY <= 1'b0;
            S_AXI_RVALID  <= 1'b0;
        end else begin
            if (!S_AXI_ARREADY && S_AXI_ARVALID) begin
                S_AXI_ARREADY <= 1'b1;
                S_AXI_RVALID  <= 1'b1;
                S_AXI_RRESP   <= 2'b00; // OKAY
                
                // Baca status UART di alamat 0x4
                if (S_AXI_ARADDR[3:0] == 4'h4)
                    S_AXI_RDATA <= {31'b0, uart_busy};
                else
                    S_AXI_RDATA <= 32'hDEADBEEF; // Alamat salah
            end else begin
                S_AXI_ARREADY <= 1'b0;
                if (S_AXI_RREADY && S_AXI_RVALID) begin
                    S_AXI_RVALID <= 1'b0;
                end
            end
        end
    end

endmodule
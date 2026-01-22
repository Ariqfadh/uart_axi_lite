module uart_top #(
    parameter DATA_WIDTH = 8,
    parameter DEFAULT_PRESCALE = 16'd434 
)(
    input  wire                   clk,
    input  wire                   rst,
    
    // TX Interface
    input  wire [DATA_WIDTH-1:0]  tx_data,
    input  wire                   tx_start,
    output wire                   tx_busy,
    
    // RX Interface
    output wire [DATA_WIDTH-1:0]  rx_data,
    output wire                   rx_ready,
    output wire                   rx_busy,
    
    // UART Physical Interface
    input  wire                   rxd,
    output wire                   txd,
    
    // Configuration
    input  wire [15:0]            prescale
);

    // Internal prescale with default value
    wire [15:0] prescale_internal;
    assign prescale_internal = (prescale == 16'd0) ? DEFAULT_PRESCALE : prescale;

    // Instantiate UART Transmitter
    uart_tx #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_uart_tx (
        .clk(clk),
        .rst(rst),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .prescale(prescale_internal),
        .txd(txd),
        .busy(tx_busy)
    );

    // Instantiate UART Receiver
    uart_rx #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_uart_rx (
        .clk(clk),
        .rst(rst),
        .rxd(rxd),
        .prescale(prescale_internal),
        .rx_data(rx_data),
        .rx_ready(rx_ready),
        .busy(rx_busy)
    );

endmodule
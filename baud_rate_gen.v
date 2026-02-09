module baud_rate_generator (
    input  wire        clk_100MHz,
    input  wire        reset,
    input  wire [15:0] M,      // Input dinamis dari AXI
    output wire        tick
);
    reg  [15:0] r_reg;
    wire [15:0] r_next;

    always @(posedge clk_100MHz or posedge reset) begin
        if (reset)
            r_reg <= 0;
        else
            r_reg <= r_next;
    end

    // Menggunakan nilai M dari register AXI
    assign r_next = (r_reg == (M - 1)) ? 0 : r_reg + 1;
    assign tick   = (r_reg == (M - 1));

endmodule
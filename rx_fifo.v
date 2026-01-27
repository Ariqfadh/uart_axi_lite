module rx_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 4
)(
    input  wire                   clk,
    input  wire                   rst,

    // write side
    input  wire                   wr_en,
    input  wire [DATA_WIDTH-1:0]  wr_data,
    output wire                   full,

    // read side
    input  wire                   rd_en,
    output wire [DATA_WIDTH-1:0]  rd_data, // Changed to wire
    output wire                   empty
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [2:0] wr_ptr, rd_ptr; // Menggunakan 3-bit untuk DEPTH 4 agar mudah cek full/empty
    reg [2:0] count;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);
    
    // Continuous assignment: Data tersedia secara instan (Asynchronous Read)
    assign rd_data = mem[rd_ptr[1:0]]; 

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count  <= 0;
        end else begin
            // Write Logic
            if (wr_en && !full) begin
                mem[wr_ptr[1:0]] <= wr_data;
                wr_ptr <= wr_ptr + 1;
                // Proteksi jika read dan write terjadi bersamaan
                if (!(rd_en && !empty)) 
                    count <= count + 1;
            end

            // Read Logic
            if (rd_en && !empty) begin
                rd_ptr <= rd_ptr + 1;
                if (!(wr_en && !full))
                    count <= count - 1;
            end
        end
    end
endmodule
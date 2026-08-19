module data_memory(
    input wire clk,
    input wire we,
    input wire re,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    output wire [31:0] rdata
);

    wire [31:0] douta;
    wire [7:0] bram_addr = addr[9:2];  // Word aligned

    blk_mem_gen_2 data_mem (
        .clka(clk),
        .wea(we),
        .addra(bram_addr),
        .dina(wdata),
        .douta(douta)
    );

    // Read data gated by re - assumes asynchronous read from BRAM
    assign rdata = (re) ? douta : 32'b0;

endmodule
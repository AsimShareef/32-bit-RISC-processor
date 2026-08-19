`timescale 1ns / 1ps

module instruction_memory (
    input wire clk,
    input wire [31:0] addr,
    output reg [31:0] insn
);
    // Internal wires
    wire [31:0] douta;
    wire [7:0] bram_addr = addr[9:2]; // word-aligned: divide by 4

    // Instantiate Block Memory Generator IP (configured as ROM)
    blk_mem_gen_1 inst_mem (
        .clka(clk),
        .addra(bram_addr),
        .douta(douta)
    );

    // Synchronous read: one-cycle latency
    always @(posedge clk) begin
        insn <= douta;
        $display("[%0t] IMEM read addr=%h (bram=%h) -> data=%h",
                 $time, addr, bram_addr, douta);
    end

endmodule

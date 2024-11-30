`include "riscv/src/const.v"
module ICache (
    input wire clk_in, // clock signal
    input wire rst_in, // reset signal when high
    input wire rdy_in, // ready signal, pause cpu when low

    input wire [31:0] inst_addr,
    input wire we, // write enable
    input wire [`ICACHE_BLOCK_BIT - 1 : 0] block, 

    output wire hit,
    output wire [31:0] inst_out
);
    // only read, no write, so only need to deal with read miss
    reg valid [0 : `ICACHE_INDEX_BIT - 1];
    reg [`ICACHE_TAG_BIT - 1 : 0] tags [0 : `ICACHE_INDEX_BIT - 1];
    reg [`ICACHE_BLOCK_BIT - 1 : 0] data [0 : `ICACHE_INDEX_BIT - 1];
    
    wire [`ICACHE_TAG_BIT - 1 : 0] tag = inst_addr[16 : 16 - `ICACHE_TAG_BIT + 1];
    wire [`ICACHE_INDEX_BIT - 1 : 0] index = inst_addr[16 - `ICACHE_TAG_BIT : 16 - `ICACHE_TAG_BIT - `ICACHE_INDEX_BIT + 1];
    wire [`ICACHE_OFFSET_BIT - 1 : 0] offset = inst_addr[`ICACHE_OFFSET_BIT - 1 : 0];

    assign hit = valid[index] && tags[index] == tag;
    assign inst_out = data[index][offset + 31 -: 32];

    always @(posedge clk_in) begin
        if (rst_in) begin: reset
            // reset
            integer i;
            for (i = 0; i < `ICACHE_INDEX_BIT; i = i + 1) begin
                valid[i] <= 0;
                tags[i] <= 0;
                data[i] <= 0;
            end
        end
        else if (!rdy_in) begin
            // do nothing
        end 
        else if (we) begin
            valid[index] <= 1;
            tags[index] <= tag;
            data[index] <= block;
        end
    end
endmodule
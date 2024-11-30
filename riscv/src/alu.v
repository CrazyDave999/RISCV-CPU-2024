`include "riscv/src/const.v"
module ArithmeticLogicUnit (
    input wire clk_in, // clock signal
    input wire rst_in, // reset signal when high
    input wire rdy_in, // ready signal, pause cpu when low

    input wire [`TYPE_BIT-1:0] inst_type, // instruction type
    input wire req,
    input wire [31: 0] r1,
    input wire [31:0] r2,
    input wire [`ROB_INDEX_BIT-1:0] rob_id_in,

    output reg ready,
    output reg [`ROB_INDEX_BIT-1:0] rob_id_out,
    output reg [31:0] result
    
);
    always @(posedge clk_in) begin
        if (rst_in) begin
            // reset
            ready <= 0;
            rob_id_out <= 0;
            result <= 0;
        end else if (!rdy_in) begin
            // do nothing
        end else if (!req) begin
            ready <= 0;
        end else begin
            ready <= 1;
            case (inst_type)
                `ADD: result <= r1 + r2; 
                `SUB: result <= r1 - r2;
                `SLL: result <= r1 << r2;
                `SLT: result <= r1 < r2;
                `SLTU: result <= $unsigned(r1) < $unsigned(r2);
                `XOR: result <= r1 ^ r2;
                `SRL: result <= r1 >> r2;
                `SRA: result <= r1 >>> r2;
                `OR: result <= r1 | r2;
                `AND: result <= r1 & r2;
                `BEQ: result <= r1 == r2;
                `BNE: result <= r1 != r2;
                `BLT: result <= r1 < r2;
                `BLTU: result <= $unsigned(r1) < $unsigned(r2);
                `BGE: result <= r1 >= r2;
                `BGEU: result <= $unsigned(r1) >= $unsigned(r2);
                `JALR: result <= (r1 + r2) & ~1;
            endcase
        end
    end
endmodule
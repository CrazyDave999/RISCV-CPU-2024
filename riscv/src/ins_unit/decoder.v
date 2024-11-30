`include "riscv/src/const.v"
module Decoder (
    input wire clk_in, // clock signal

    input wire inst_req,
    input wire [31:0] inst,

    output reg ready_out,
    output reg [`TYPE_BIT-1:0] type_out,
    output reg [4:0] rs1_out,
    output reg [4:0] rs2_out,
    output reg [4:0] rd_out,
    output reg [31:0] imm_out
);
  wire [  6:0] opcode = inst[6:0];
  wire [  2:0] funct3 = inst[14:12];
  wire [  7:0] funct7 = inst[31:25];

  wire [  4:0] rd = inst[11:7];
  wire [  4:0] rs1 = inst[19:15];
  wire [  4:0] rs2 = inst[24:20];
  wire [31:0] immU = {inst[31:12], 12'b0};
  wire [31:0] immJ = $signed({inst[31], inst[19:12], inst[20], inst[30:21], 1'b0});
  wire [31:0] immI = $signed(inst[31:20]);
  wire [31:0] immB = $signed({inst[31], inst[7], inst[30:25], inst[11:8], 1'b0});
  wire [31:0] immS = $signed({inst[31:25], inst[11:7]});
  wire [31:0] shamt = $unsigned(inst[24:20]);

  always @(posedge clk_in) begin
    rs1_out <= rs1;
    rs2_out <= rs2;
    rd_out <= rd;
    ready_out <= inst_req;
    case (opcode)
      7'b0110111: begin
        type_out <= `LUI;
        imm_out <= immU;
      end
      7'b0010111: begin
        type_out <= `AUIPC;
        imm_out <= immU;
      end
      7'b1101111: begin
        type_out <= `JAL;
        imm_out <= immJ;
      end
      7'b1100111: begin
        type_out <= `JALR;
        imm_out <= immI;
      end
      7'b1100011: begin
        case (funct3)
          3'b000: begin
            type_out <= `BEQ;
            imm_out <= immB;
          end
          3'b001: begin
            type_out <= `BNE;
            imm_out <= immB;
          end
          3'b100: begin
            type_out <= `BLT;
            imm_out <= immB;
          end
          3'b101: begin
            type_out <= `BGE;
            imm_out <= immB;
          end
          3'b110: begin
            type_out <= `BLTU;
            imm_out <= immB;
          end
          3'b111: begin
            type_out <= `BGEU;
            imm_out <= immB;
          end
        endcase
      end
      7'b0000011: begin
        case (funct3)
          3'b000: begin
            type_out <= `LB;
            imm_out <= immI;
          end
          3'b001: begin
            type_out <= `LH;
            imm_out <= immI;
          end
          3'b010: begin
            type_out <= `LW;
            imm_out <= immI;
          end
          3'b100: begin
            type_out <= `LBU;
            imm_out <= immI;
          end
          3'b101: begin
            type_out <= `LHU;
            imm_out <= immI;
          end
        endcase
      end
      7'b0100011: begin
        case (funct3)
          3'b000: begin
            type_out <= `SB;
            imm_out <= immS;
          end
          3'b001: begin
            type_out <= `SH;
            imm_out <= immS;
          end
          3'b010: begin
            type_out <= `SW;
            imm_out <= immS;
          end
        endcase
      end
      7'b0010011: begin
        case (funct3)
          3'b000: begin
            type_out <= `ADDI;
            imm_out <= immI;
          end
          3'b010: begin
            type_out <= `SLTI;
            imm_out <= immI;
          end
          3'b011: begin
            type_out <= `SLTIU;
            imm_out <= immI;
          end
          3'b100: begin
            type_out <= `XORI;
            imm_out <= immI;
          end
          3'b110: begin
            type_out <= `ORI;
            imm_out <= immI;
          end
          3'b111: begin
            type_out <= `ANDI;
            imm_out <= immI;
          end
          3'b001: begin
            type_out <= `SLLI;
            imm_out <= shamt;
          end
          3'b101: begin
            case (funct7)
              7'b0000000: begin
                type_out <= `SRLI;
                imm_out <= shamt;
              end
              7'b0100000: begin
                type_out <= `SRAI;
                imm_out <= shamt;
              end
            endcase
          end
        endcase
      end
      7'b0110011: begin
        case (funct3)
          3'b000: begin
            case (funct7)
              7'b0000000: begin
                type_out <= `ADD;
              end
              7'b0100000: begin
                type_out <= `SUB;
              end
            endcase
          end
          3'b001: begin
            type_out <= `SLL;
          end
          3'b010: begin
            type_out <= `SLT;
          end
          3'b011: begin
            type_out <= `SLTU;
          end
          3'b100: begin
            type_out <= `XOR;
          end
          3'b101: begin
            case (funct7)
              7'b0000000: begin
                type_out <= `SRL;
              end
              7'b0100000: begin
                type_out <= `SRA;
              end
            endcase
          end
          3'b110: begin
            type_out <= `OR;
          end
          3'b111: begin
            type_out <= `AND;
          end
        endcase
      end
    endcase
  end
endmodule

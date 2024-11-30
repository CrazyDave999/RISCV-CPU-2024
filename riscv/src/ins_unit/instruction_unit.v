`include "riscv/src/const.v"
`include "riscv/src/ins_unit/decoder.v"
`include "riscv/src/ins_unit/predictor.v"
module InstructionUnit (
    input wire clk_in, // clock signal
    input wire rst_in, // reset signal when high
    input wire rdy_in, // ready signal, pause cpu when low

    // from rob
    input wire [`ROB_INDEX_BIT-1:0] rob_tail,
    input wire rob_full,
    input wire stall_end, // i.e. jalr_ready
    input wire [31:0] jalr_addr,

    input wire br_req,
    input wire br_correct,
    input wire [31:0] br_res,
    input wire [`PRED_TABLE_BIT-1:0] br_g_ind,
    input wire [`PRED_TABLE_BIT-1:0] br_l_ind,

    input wire clear,
    input wire [31:0] clear_pc,

    // from rs
    input wire rs_full,

    // from lsb
    input wire lsb_full,

    // from memory_unit
    input wire inst_ready,
    input wire [31:0] inst,

    output wire [31:0] pc_out,
    output wire stall_out,

    // to rob, rs, lsb, for issue
    output reg [1:0] issue_ready, // 0: no issue, 1: rs, 2: lsb
    output reg [`TYPE_BIT-1:0] issue_type,
    output reg [4:0] issue_rd,
    output reg [31:0] issue_val1,
    output reg [31:0] issue_val2,
    output reg [`ROB_INDEX_BIT-1:0] issue_dep1,
    output reg [`ROB_INDEX_BIT-1:0] issue_dep2,
    output reg issue_has_dep1,
    output reg issue_has_dep2,
    output reg [31:0] issue_addr, // for branch and jalr only
    output reg [31:0] issue_pred, 
    output reg [`PRED_TABLE_BIT-1:0] issue_g_ind,
    output reg [`PRED_TABLE_BIT-1:0] issue_l_ind,
    output reg [31:0] issue_imm, // for load/store and branch only

    // to rf
    output wire [4:0] req_id1_out,
    input wire [31:0] val1_in,
    input wire [`ROB_INDEX_BIT-1:0] dep1_in,
    input wire has_dep1_in,
    output wire [4:0] req_id2_out,
    input wire [31:0] val2_in,
    input wire [`ROB_INDEX_BIT-1:0] dep2_in,
    input wire has_dep2_in,

    output wire [4:0] set_dep_id_out,
    output wire [`ROB_INDEX_BIT-1:0] set_dep_out,
    // to memory_unit
    output wire inst_req
);
    reg [31:0] pc;
    assign pc_out = pc;
    reg stall;
    assign stall_out = stall;


    // from decoder
    wire [`TYPE_BIT-1:0] type;
    wire [4:0] rs1, rs2, rd;
    wire [31:0] imm;
    wire dec_ready;

    // If an instruciton modifies pc, then the current pc value is wrong, which is the result of +4 operation last cycle. 
    // To fix this, if the inst this cycle modifies pc, then this inst should not be decoded.
    wire is_br = type == `BEQ || type == `BNE || type == `BLT || type == `BGE || type == `BLTU || type == `BGEU;
    wire modify_pc = type == `JAL || (is_br && pred);

    Decoder decoder (
        .clk_in(clk_in),
        .inst_req(inst_ready && !modify_pc),
        .inst(inst),
        .ready_out(dec_ready),
        .type_out(type),
        .rs1_out(rs1),
        .rs2_out(rs2),
        .rd_out(rd),
        .imm_out(imm)
    );
    wire [31:0] dec_addr = pc - 4; // the address of the instruction decoder return in this cycle

    // from predictor
    wire [31:0] pred;
    wire [`PRED_TABLE_BIT-1:0] g_ind, l_ind;
    Predictor predictor (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),
        .inst_req(dec_ready),
        .inst_addr(dec_addr),
        .br_req(br_req),
        .br_correct(br_correct),
        .br_res(br_res),
        .br_g_ind(br_g_ind),
        .br_l_ind(br_l_ind),
        .pred_out(pred),
        .g_ind_out(g_ind),
        .l_ind_out(l_ind)
    );

    wire will_issue = !rob_full && !rs_full && !lsb_full && dec_ready && !stall;
    assign req_id1_out = rs1;
    assign req_id2_out = rs2;
    assign set_dep_id_out = will_issue ? rd : 0;
    assign set_dep_out = rob_tail;

    assign inst_req = !stall;

    always @(posedge clk_in) begin
        if (rst_in || clear) begin
            // reset
            if (clear) begin
                pc <= clear_pc;
            end else begin
                pc <= 0;
            end
            stall <= 0;
            issue_ready <= 0;
        end
        else if (!rdy_in) begin
            // do nothing
        end 
        else if (!stall) begin
            // issue
            if (will_issue) begin
                issue_rd <= rd;
                case(type)
                    `JAL: begin
                        pc <= pc + imm;
                        issue_ready <= 1;
                        issue_type <= `ADD;
                        issue_val1 <= 0;
                        issue_val2 <= dec_addr + 4;
                        // issue_dep1 <= 0;
                        // issue_dep2 <= 0;
                        issue_has_dep1 <= 0;
                        issue_has_dep2 <= 0;
                    end
                    `LUI: begin
                        pc <= pc + 4;
                        issue_ready <= 1;
                        issue_type <= `ADD;
                        issue_val1 <= 0;
                        issue_val2 <= imm;
                        issue_has_dep1 <= 0;
                        issue_has_dep2 <= 0;
                    end
                    `AUIPC: begin
                        pc <= pc + 4;
                        issue_ready <= 1;
                        issue_type <= `ADD;
                        issue_val1 <= 0;
                        issue_val2 <= dec_addr + imm;
                        issue_has_dep1 <= 0;
                        issue_has_dep2 <= 0;
                    end
                    `LB, `LH, `LW, `LBU, `LHU, `SB, `SH, `SW: begin
                        pc <= pc + 4;
                        issue_ready <= 2;
                        issue_type <= type;
                        issue_imm <= imm;
                        issue_val1 <= val1_in;
                        issue_val2 <= val2_in;
                        issue_has_dep1 <= has_dep1_in;
                        issue_has_dep2 <= has_dep2_in;
                        issue_dep1 <= dep1_in;
                        issue_dep2 <= dep2_in;
                    end
                    `ADD, `SUB, `SLL, `SLT, `SLTU, `XOR, `SRL, `SRA, `OR, `AND: begin
                        pc <= pc + 4;
                        issue_ready <= 1;
                        issue_type <= type;
                        issue_val1 <= val1_in;
                        issue_val2 <= val2_in;
                        issue_has_dep1 <= has_dep1_in;
                        issue_has_dep2 <= has_dep2_in;
                        issue_dep1 <= dep1_in;
                        issue_dep2 <= dep2_in;
                    end
                    `ADDI, `SLTI, `SLTIU, `XORI, `ORI, `ANDI, `SLLI, `SRLI, `SRAI, `JALR: begin
                        pc <= pc + 4;
                        issue_ready <= 1;
                        case (type)
                            `ADDI: issue_type <= `ADD;
                            `SLTI: issue_type <= `SLT;
                            `SLTIU: issue_type <= `SLTU;
                            `XORI: issue_type <= `XOR;
                            `ORI: issue_type <= `OR;
                            `ANDI: issue_type <= `AND;
                            `SLLI: issue_type <= `SLL;
                            `SRLI: issue_type <= `SRL;
                            `SRAI: issue_type <= `SRA;
                        endcase
                        issue_val1 <= val1_in;
                        issue_val2 <= imm;
                        issue_has_dep1 <= has_dep1_in;
                        issue_has_dep2 <= 0;
                        issue_dep1 <= dep1_in;
                        issue_dep2 <= 0;
                        if (type == `JALR) begin
                            issue_addr <= dec_addr;
                            stall <= 1;
                        end
                    end
                    `BEQ, `BNE, `BLT, `BGE, `BLTU, `BGEU: begin
                        if (pred) begin
                            pc <= pc + imm;
                        end else begin
                            pc <= pc + 4;
                        end
                        issue_ready <= 1;
                        issue_type <= type;
                        issue_imm <= imm;
                        issue_val1 <= val1_in;
                        issue_val2 <= val2_in;
                        issue_has_dep1 <= has_dep1_in;
                        issue_has_dep2 <= has_dep2_in;
                        issue_dep1 <= dep1_in;
                        issue_dep2 <= dep2_in;
                        issue_addr <= dec_addr;
                        issue_pred <= pred;
                        issue_g_ind <= g_ind;
                        issue_l_ind <= l_ind;
                    end
                endcase
            end else begin
                issue_ready <= 0;
            end
        end else if (stall_end) begin
            stall <= 0;
            pc <= jalr_addr;
        end
    end
endmodule
`include "riscv/src/const.v"
`include "riscv/src/alu.v"
module ReservationStation(
    input wire clk_in, // clock signal
    input wire rst_in, // reset signal when high
    input wire rdy_in, // ready signal, pause cpu when low

    // from instruction unit
    input wire [1:0] inst_req,
    input wire [`TYPE_BIT-1:0] inst_type,
    input wire [`ROB_INDEX_BIT-1:0] inst_rob_id, // from rob
    input wire [31:0] inst_val1,
    input wire [31:0] inst_val2,
    input wire [`ROB_INDEX_BIT-1:0] inst_dep1,
    input wire [`ROB_INDEX_BIT-1:0] inst_dep2,
    input wire inst_has_dep1,
    input wire inst_has_dep2,

    // cdb, from rob, for commit
    input wire cdb_req,
    input wire [31:0] cdb_val,
    input wire [`ROB_INDEX_BIT-1:0] cdb_rob_id,

    input wire clear,

    output reg full,

    //  to rob, for write back
    output wire rs_ready,
    output wire [`ROB_INDEX_BIT-1:0] rs_rob_id,
    output wire [31:0] rs_result
);
    reg busy [0 : `RS_CAP-1];
    reg [`TYPE_BIT-1:0] type [0 : `RS_CAP-1];
    reg [`ROB_INDEX_BIT-1:0] rob_id [0 : `RS_CAP-1];
    reg [31:0] v1 [0 : `RS_CAP-1];
    reg [31:0] v2 [0 : `RS_CAP-1];
    reg has_dep1 [0 : `RS_CAP-1];
    reg has_dep2 [0 : `RS_CAP-1];
    reg [`ROB_INDEX_BIT-1:0] dep1 [0 : `RS_CAP-1];
    reg [`ROB_INDEX_BIT-1:0] dep2 [0 : `RS_CAP-1];
    reg [31:0] size;



    wire executable [0 : `RS_CAP-1];
    wire [`RS_CAP_BIT-1:0] exec_pos;
    wire [`RS_CAP_BIT-1:0] empty_pos;

    // segment tree to find the first executable slot and the first empty slot    
    genvar i;
    generate
        wire has_exec [0 : `RS_CAP * 2 - 1];
        wire [`RS_CAP_BIT-1:0] first_exec [0 : `RS_CAP * 2 - 1];
        wire has_empty [0 : `RS_CAP * 2 - 1];   
        wire [`RS_CAP_BIT-1:0] first_empty [0 : `RS_CAP * 2 - 1];
        for (i = 0; i < `RS_CAP; i = i + 1) begin: rs
            assign executable[i] = busy[i] && !has_dep1[i] && !has_dep2[i];
            assign has_exec[i+`RS_CAP] = executable[i];
            assign first_exec[i+`RS_CAP] = i;
            assign has_empty[i+`RS_CAP] = ~busy[i];
            assign first_empty[i+`RS_CAP] = i;
        end
        for (i = 1; i < `RS_CAP; i = i + 1) begin: seg
            assign has_exec[i] = has_exec[i<<1] | has_exec[i<<1|1];
            assign first_exec[i] = has_exec[i<<1] ? first_exec[i<<1] : first_exec[i<<1|1];
            assign has_empty[i] = has_empty[i<<1] | has_empty[i<<1|1];
            assign first_empty[i] = has_empty[i<<1] ? first_empty[i<<1] : first_empty[i<<1|1];
        end
        assign exec_pos = first_exec[1];
        assign empty_pos = first_empty[1];
    endgenerate



    // instantiate alu here since we can calculate the result immediately
    ArithmeticLogicUnit alu(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),
        .inst_type(type[exec_pos]),
        .req(executable[exec_pos]),
        .r1(v1[exec_pos]),
        .r2(v2[exec_pos]),
        .rob_id_in(rob_id[exec_pos]),
        .ready(rs_ready),
        .rob_id_out(rs_rob_id),
        .result(rs_result)
    );

    wire next_size = inst_req == 1 ? (has_exec[1] ? size : size + 1) : (has_exec[1] ? size -1 : size);
    wire next_full = next_size == `RS_CAP;
    

    always @(posedge clk_in) begin: ReservationStation
        integer i;
        if (rst_in || clear) begin
            // reset
            for (i = 0; i < `RS_CAP; i = i + 1) begin
                busy[i] <= 0;
                type[i] <= 0;
                rob_id[i] <= 0;
                v1[i] <= 0;
                v2[i] <= 0;
                has_dep1[i] <= 0;
                has_dep2[i] <= 0;
                dep1[i] <= 0;
                dep2[i] <= 0;
            end
            size <= 0;
            full <= 0;
        end else if (!rdy_in) begin
            // do nothing
        end else begin
            // insert a new instruction
            if (inst_req == 1) begin
                busy[empty_pos] <= 1;
                rob_id[empty_pos] <= inst_rob_id;
                v1[empty_pos] <= inst_val1;
                v2[empty_pos] <= inst_val2;
                has_dep1[empty_pos] <= inst_has_dep1;
                has_dep2[empty_pos] <= inst_has_dep2;
                dep1[empty_pos] <= inst_dep1;
                dep2[empty_pos] <= inst_dep2;
            end

            // udpate the dep and value
            if (cdb_req) begin
                for (i = 0; i < `RS_CAP; i = i + 1) begin
                    if (busy[i]) begin
                        if (cdb_rob_id == dep1[i]) begin
                            has_dep1[i] <= 0;
                            v1[i] <= cdb_val;
                        end
                        if (cdb_rob_id == dep2[i]) begin
                            has_dep2[i] <= 0;
                            v2[i] <= cdb_val;
                        end
                    end
                end
            end
            
            // execute an instruction
            if (has_exec[1]) begin
                busy[exec_pos] <= 0;
            end
            full <= next_full;
            size <= next_size;
        end
    end
endmodule
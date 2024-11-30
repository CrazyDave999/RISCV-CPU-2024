`include "riscv/src/const.v"
/*
    Only two operations will modify rf.
    1. When ROB commit an instruction.
        Set the value of rd. If dep is still this inst, set has_dep to 0.
    2. When an instruction be issued.
        Set the dep of rd.
*/
module RegisterFile(
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low
    
    input clear,

    // from instrution unit
    input wire [4:0] req_id1, 
    output wire [31:0] val1,
    output wire [`ROB_INDEX_BIT-1:0] dep1,
    output wire has_dep1,

    input wire [4:0] req_id2,
    output wire [31:0] val2,
    output wire [`ROB_INDEX_BIT-1:0] dep2,
    output wire has_dep2,

    input wire [4:0] set_dep_id,
    input wire [`ROB_INDEX_BIT-1:0] set_dep, // the instruction issued this cycle

    // from rob
    input wire [4:0] set_value_id,
    input wire [31:0] set_value,
    input wire [`ROB_INDEX_BIT-1:0] set_value_rob_id // the rob_id of instruction commited this cycle

);
    reg [31 : 0] rf [0:31];
    reg [`ROB_INDEX_BIT-1:0] dep [0 : 31];
    reg has_dep [0 : 31];
    assign val1 = rf[req_id1];
    assign val2 = rf[req_id2];
    assign dep1 = dep[req_id1];
    assign dep2 = dep[req_id2];
    assign has_dep1 = has_dep[req_id1];
    assign has_dep2 = has_dep[req_id2];

    always @(posedge clk_in) begin: RegisterFile
        integer i;
        if (rst_in) begin
            for (i = 0; i < 32; i = i + 1) begin
                rf[i] <= 0;
                dep[i] <= 0;
                has_dep[i] <= 0;
            end
        end else if (!rdy_in) begin
            // do nothing
        end else if (clear) begin
            for (i = 0; i < 32; i = i + 1) begin
                dep[i] <= 0;
                has_dep[i] <= 0;
            end
        end else begin
            if (set_value_id) begin
                rf[set_value_id] <= set_value;
                if (set_dep_id != set_value_id && dep[set_value_id] == set_value_rob_id) begin
                    dep[set_value_id] <= 0;
                    has_dep[set_value_id] <= 0;
                end
            end
            if (set_dep_id) begin
                dep[set_dep_id] <= set_dep;
                has_dep[set_dep_id] <= 1;
            end
        end
    end
endmodule
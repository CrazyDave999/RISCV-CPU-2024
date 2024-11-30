`include "riscv/src/const.v"
module LoadStoreBuffer (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low


    // from instruction unit
    input wire [                 1:0] inst_req,
    input wire [     `TYPE_BIT-1:0] inst_type,
    input wire [                31:0] inst_imm,
    input wire [                31:0] inst_val1,
    input wire [                 4:0] inst_dep1,
    input wire                        inst_has_dep1,
    input wire [                31:0] inst_val2,
    input wire [                 4:0] inst_dep2,
    input wire                        inst_has_dep2,
    input wire [                 4:0] inst_rd,
    input wire [`ROB_INDEX_BIT-1:0] inst_rob_id,

    // cdb, from rob
    input wire                        cdb_req,
    input wire [                31:0] cdb_val,
    input wire [`ROB_INDEX_BIT-1:0] cdb_rob_id,
    input wire [`ROB_INDEX_BIT-1:0] rob_head,
    
    input wire clear,

    // from memory unit
    input wire                    mem_finished,
    input wire [            31:0] mem_val,
    input wire [`LSB_CAP_BIT-1:0] mem_pos,
    input wire                    mem_busy,

    output reg full,

    // to memory unit
    output reg                    req_out,
    output reg [`LSB_CAP_BIT-1:0] pos_out,
    output reg                    ls_out, // i.e. data_we
    output reg [             1:0] len_out,
    output reg [            31:0] addr_out,
    output reg [            31:0] val_out,

    // to rob, for write back
    output reg                        ready,
    output reg [`ROB_INDEX_BIT-1:0] rob_id_out,
    output reg [                31:0] result
);
  reg busy[0 : `LSB_CAP-1];
  reg ls[0 : `LSB_CAP-1];  // 0: load, 1: store
  reg [2:0] len[0 : `LSB_CAP-1];  // x00: byte, x01: half word, x10: word. 0xx:unsigned, 1xx:signed.
  reg [31:0] imm[0 : `LSB_CAP-1];
  reg [31:0] val1[0 : `LSB_CAP-1];
  reg [31:0] val2[0 : `LSB_CAP-1];
  reg [`ROB_INDEX_BIT-1:0] dep1[0 : `LSB_CAP-1];
  reg [`ROB_INDEX_BIT-1:0] dep2[0 : `LSB_CAP-1];
  reg has_dep1[0 : `LSB_CAP-1];
  reg has_dep2[0 : `LSB_CAP-1];
  reg [`ROB_INDEX_BIT-1:0] rob_id[0 : `LSB_CAP-1];
  reg complete[0 : `LSB_CAP-1];
  reg [31:0] res[0 : `LSB_CAP-1];
  reg [`LSB_CAP_BIT-1:0] head, tail;
  reg [31:0] size;


  wire next_head = complete[head] ? (head + 1) % `LSB_CAP : head;
  wire next_tail = inst_req == 2 ? (tail + 1) % `LSB_CAP : tail;
  wire next_size = inst_req == 2 ? (complete[head] ? size : size + 1) : (complete[head] ? size - 1 : size); 
  wire next_full = next_size == `LSB_CAP;

  wire head_store_exec = busy[head] && ls[head] && !complete[head] && !has_dep1[head] && !has_dep2[head] && rob_head == rob_id[head];
  // segment tree to find the first executable load instruction
  wire executable[0 : `LSB_CAP-1];
  wire [`LSB_CAP_BIT-1:0] exec_pos;
  genvar i;
  generate
    wire has_exec[0 : `LSB_CAP * 2 - 1];
    wire [`LSB_CAP_BIT-1:0] first_exec[0 : `LSB_CAP * 2 - 1];
    for (i = 0; i < `LSB_CAP; i = i + 1) begin : lsb
      assign executable[i] = busy[i] && !complete[i] && !ls[i] && !has_dep1[i] && !has_dep2[i];
      assign has_exec[i+`LSB_CAP] = executable[i];
      assign first_exec[i+`LSB_CAP] = i;
    end
    for (i = 1; i < `LSB_CAP; i = i + 1) begin : seg
      assign has_exec[i]   = has_exec[i<<1] | has_exec[i<<1|1];
      assign first_exec[i] = has_exec[i<<1] ? first_exec[i<<1] : first_exec[i<<1|1];
    end
    assign exec_pos = head_store_exec ? head : first_exec[1];  // first executable load instruction
  endgenerate

  wire [31:0] addr[0 : `LSB_CAP-1];
  wire [31:0] addr_end[0 : `LSB_CAP-1];
  generate
    for (i = 0; i < `LSB_CAP; i = i + 1) begin : addr_gen
      assign addr[i] = imm[i] + val1[i];
      assign addr_end[i] = addr[i] + len[i][1:0] - 1;
    end
  endgenerate


  wire req = head_store_exec || has_exec[1]; // If true, send request to memory unit if it is not busy.
  always @(posedge clk_in) begin : LoadStoreBuffer
    integer i;
    if (rst_in || clear) begin
      // reset
      for (i = 0; i < `LSB_CAP; i = i + 1) begin
        busy[i] <= 0;
        ls[i] <= 0;
        len[i] <= 3'b000;
        imm[i] <= 0;
        val1[i] <= 0;
        val2[i] <= 0;
        dep1[i] <= 0;
        dep2[i] <= 0;
        has_dep1[i] <= 0;
        has_dep2[i] <= 0;
        rob_id[i] <= 0;
        complete[i] <= 0;
        res[i] <= 0;
      end
      head <= 0;
      tail <= 0;
      size <= 0;
      full <= 0;
      req_out <= 0;
      ready <= 0;
    end else if (!rdy_in) begin
      // do nothing
    end else begin
      // check issue
      if (inst_req == 2) begin
        busy[tail] <= 1;

        imm[tail] <= inst_imm;

        // Note that load inst has no rs2.
        val1[tail] <= inst_val1;
        dep1[tail] <= inst_dep1;
        has_dep1[tail] <= inst_has_dep1;
        val2[tail] <= inst_val2;
        dep2[tail] <= inst_dep2;

        rob_id[tail] <= inst_rob_id;
        complete[tail] <= 0;
        case (inst_type)
          `LB: begin
            ls[tail] <= 0;
            len[tail] <= 3'b000;
            has_dep2[tail] <= 0;
          end
          `LH: begin
            ls[tail] <= 0;
            len[tail] <= 3'b001;
            has_dep2[tail] <= 0;
          end
          `LW: begin
            ls[tail] <= 0;
            len[tail] <= 3'b010;
            has_dep2[tail] <= 0;
          end
          `LBU: begin
            ls[tail] <= 0;
            len[tail] <= 3'b100;
            has_dep2[tail] <= 0;
          end
          `LHU: begin
            ls[tail] <= 0;
            len[tail] <= 3'b101;
            has_dep2[tail] <= 0;
          end
          `SB: begin
            ls[tail] <= 1;
            len[tail] <= 3'b000;
            has_dep2[tail] <= inst_has_dep2;
          end
          `SH: begin
            ls[tail] <= 1;
            len[tail] <= 3'b001;
            has_dep2[tail] <= inst_has_dep2;
          end
          `SW: begin
            ls[tail] <= 1;
            len[tail] <= 3'b010;
            has_dep2[tail] <= inst_has_dep2;
          end
        endcase
      end

      // monitor the cdb. modify the dep and value of the instructions accordingly
      if (cdb_req) begin
        for (i = 0; i < `LSB_CAP; i = i + 1) begin
          if (busy[i]) begin
            if (has_dep1[i] && dep1[i] == cdb_rob_id) begin
              has_dep1[i] <= 0;
              val1[i] <= cdb_val;
            end
            if (has_dep2[i] && dep2[i] == cdb_rob_id) begin
              has_dep2[i] <= 0;
              val2[i] <= cdb_val;
            end
          end
        end
      end

      // receive message for load finish came from memory unit
      if (mem_finished) begin
        complete[mem_pos] <= 1;
        case (len[mem_pos])
          3'b000: res[mem_pos] <= $unsigned(mem_val[7:0]);
          3'b001: res[mem_pos] <= $unsigned(mem_val[15:0]);
          3'b010: res[mem_pos] <= $unsigned(mem_val[31:0]);
          3'b100: res[mem_pos] <= $signed(mem_val[7:0]);
          3'b101: res[mem_pos] <= $signed(mem_val[15:0]);
        endcase
      end

      // if memory unit is not busy, find an instruction that operands have been ready. send it to memory.
      if (!mem_busy && req) begin
        req_out  <= 1;
        pos_out  <= exec_pos;
        ls_out   <= ls[exec_pos];
        len_out  <= len[exec_pos][1:0];
        addr_out <= imm[exec_pos] + val1[exec_pos];
        val_out  <= val2[exec_pos];
      end else begin
        req_out <= 0;
      end

      // check if the head is complete. if so, commit it.
      if (complete[head]) begin
        ready <= 1;
        rob_id_out <= rob_id[head];
        result <= res[head];
        busy[head] <= 0;
        // If the head is a store instruction, check if there is some following load instructions have been complete.
        // If there are some, mark them incomplete.
        if (ls[head]) begin
          for (i = 0; i < `LSB_CAP; i = i + 1) begin
            if (busy[i] && complete[i] && !ls[i] && addr[head] <= addr_end[i] && addr_end[head] >= addr[i]) begin
              complete[i] <= 0;
            end
          end
        end
      end else begin
        ready <= 0;
      end

      size <= next_size;
      full <= next_full;
      head <= next_head;
      tail <= next_tail;
    end
  end
endmodule

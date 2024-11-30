`include "riscv/src/const.v"
/*
    A simple Tournament Predictor, which consists of three parts:
    1. Global Predictors
    2. Local Predictors
    3. Selector
*/
module Predictor (
    input wire clk_in,  // clock signal
    input wire rst_in,  // reset signal when high
    input wire rdy_in,  // ready signal, pause cpu when low

    // from instruction unit
    input wire inst_req,
    input wire [31:0] inst_addr,

    // from rob
    input wire br_req,  // high when last branch instruction commited
    input wire br_correct,
    input wire [31:0] br_res,  // last actual result
    input wire [`PRED_TABLE_BIT-1:0] br_g_ind,  // global index of last branch instruction
    input wire [`PRED_TABLE_BIT-1:0] br_l_ind,  // local index of last branch instruction

    // to instruciton unit. all deliver to rob
    output wire [31:0] pred_out,  // 0: not taken, 1: taken
    output wire [`PRED_TABLE_BIT-1:0] g_ind_out,
    output wire [`PRED_TABLE_BIT-1:0] l_ind_out
);
  reg [`PRED_TABLE_BIT - 1 : 0] br_his;  // branch history
  reg [1:0] g_tab[0 : `PRED_TABLE_SIZE - 1];  // global table
  reg [1:0] l_tab[0 : `PRED_TABLE_SIZE - 1];  // local table
  reg [1:0] sel[0 : `PRED_TABLE_SIZE - 1];  // selector. 00, 01 for local, 10, 11 for global
  wire [`PRED_TABLE_BIT - 1 : 0] hash = inst_addr[`PRED_TABLE_BIT + 1: 2]; // addr[7:2], which is also the index of local table and selector
  wire [31:0] g_taken = $unsigned(g_tab[br_his] >= 2'b10);
  wire [31:0] l_taken = $unsigned(l_tab[hash] >= 2'b10);

  assign pred_out  = sel[hash] >= 2'b10 ? g_taken : l_taken;
  assign g_ind_out = br_his;
  assign l_ind_out = hash;

  always @(posedge clk_in) begin : pred
    integer i;
    if (rst_in) begin
      // reset
      br_his <= 0;
      for (i = 0; i < `PRED_TABLE_SIZE; i = i + 1) begin
        g_tab[i] <= 2'b01;
        l_tab[i] <= 2'b01;
        sel[i]   <= 2'b00;
      end

    end else if (!rdy_in) begin
      // do nothing
    end else begin
      if (br_req) begin
        // update
        br_his <= br_his << 1 | br_res;
        // global and local table
        if (br_res) begin
          if (g_tab[br_g_ind] < 2'b11) begin
            g_tab[br_g_ind] <= g_tab[br_g_ind] + 1;
          end
          if (l_tab[br_l_ind] < 2'b11) begin
            l_tab[br_l_ind] <= l_tab[br_l_ind] + 1;
          end
        end else begin
          if (g_tab[br_g_ind] > 2'b00) begin
            g_tab[br_g_ind] <= g_tab[br_g_ind] - 1;
          end
          if (l_tab[br_l_ind] > 2'b00) begin
            l_tab[br_l_ind] <= l_tab[br_l_ind] - 1;
          end
        end
        // selector
        if (br_correct) begin
          case (sel[br_l_ind])
            2'b01: sel[br_l_ind] <= 2'b00;
            2'b10: sel[br_l_ind] <= 2'b11;
          endcase
        end else begin
          if (sel[br_l_ind] <= 2'b01) begin
            sel[br_l_ind] <= sel[br_l_ind] + 1;
          end else begin
            sel[br_l_ind] <= sel[br_l_ind] - 1;
          end
        end
      end
    end
  end
endmodule

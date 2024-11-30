`include "riscv/src/const.v"
`include "riscv/src/memory/icache.v"
module MemoryUnit (
    input wire clk_in,  // system clock signal
    input wire rst_in,  // reset signal
    input wire rdy_in,  // ready signal, pause cpu when low

    input  wire [ 7:0] mem_din,   // data input bus
    output wire [ 7:0] mem_dout,  // data output bus
    output wire [31:0] mem_a,     // address bus (only 17:0 is used)
    output wire        mem_wr,    // write/read signal (1 for write)

    input wire io_buffer_full,  // 1 if uart buffer is full

    // from instruction unit
    input wire [31:0] pc,
    input wire inst_req,
    output wire inst_ready,
    output wire [31:0] inst_res,

    // from lsb
    input wire data_req,
    input wire [`LSB_CAP_BIT-1:0] data_pos,
    input wire data_we,  // 1 for write
    input wire [1:0] data_size,  // 0 for byte, 1 for half word, 2 for word
    input wire [31:0] data_addr,
    input wire [31:0] data_in,

    output wire data_ready,
    output wire [31:0] data_out,
    output wire [`LSB_CAP_BIT-1:0] data_pos_out,

    output reg busy
);
  // for instruction fetching, if not hit, sequencially read 8 instructions from memory
  // for data fetching, directly read from memory
  reg [`ICACHE_BLOCK_BIT - 1 : 0] buffer;

  reg i_we;

  ICache icache (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .rdy_in(rdy_in),
      .inst_addr(pc),
      .we(i_we),
      .block(buffer),
      .hit(inst_ready),
      .inst_out(inst_res)
  );

  wire inst_need_work = inst_req && !inst_ready;

  reg req_type;  // 0 for ins, 1 for data
  reg [`LSB_CAP_BIT-1:0] lsb_pos;
  reg [31:0] state;
  reg [31:0] target;
  reg [31:0] high_bit;
  reg [31:0] addr;
  reg [31:0] data;
  reg wr;
  reg ready;

  wire need_work = inst_need_work || data_req;
  wire use_inner = !(state == 0 && need_work);
  wire [31:0] block_addr = {pc[31:`ICACHE_OFFSET_BIT], `ICACHE_OFFSET_BIT'b0};
  // Whether use inner addr and data.
  // Since initially the value of inner addr and data is wrong, we should use input of this module directly.
  wire current_type = use_inner ? req_type : data_req;
  wire current_addr = use_inner ? addr : (current_type ? data_addr : block_addr);
  wire current_wr = use_inner ? wr : (current_type ? data_we : 0);

  assign mem_a = current_addr;
  assign mem_wr = current_wr;
  assign data_out = buffer[31:0];
  assign data_ready = ready;
  assign data_pos_out = lsb_pos;


  always @(posedge clk_in) begin
    if (rst_in) begin
      // reset
      busy <= 0;
      i_we <= 0;
      wr <= 0;
      ready <= 0;
    end else if (!rdy_in) begin
      // do nothing
    end else if (!busy) begin
      if (data_req) begin
        busy <= 1;
        lsb_pos <= data_pos;
        req_type <= 1;
        addr <= data_addr + 1;
        state <= 1;
        target <= 1 << data_size;
        high_bit <= 7;
        wr <= data_we;
      end else if (inst_need_work) begin
        busy <= 1;
        req_type <= 0;
        addr <= pc + 1;
        state <= 1;
        target <= `ICACHE_BLOCK_BIT >> 3;
        high_bit <= 7;
      end
      ready <= 0;
    end else begin
      // working
      if (req_type) begin
        // data request
        buffer[high_bit-:8] <= mem_din;
        if (state == target) begin
          busy  <= 0;
          ready <= 1;
          state <= 0;
          wr <= 0;
        end else begin
          addr <= addr + 1;
          state <= state + 1;
          high_bit <= high_bit + 8;
        end
      end else begin
        // instruction request
        if (state == target) begin
          busy  <= 0;
          state <= 0;
          i_we  <= 1;
        end else begin
          i_we <= 0;
        end
      end
    end
  end
endmodule

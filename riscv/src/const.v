`define ROB_CAP 32
`define ROB_INDEX_BIT 5
`define ROB_STAT_BIT 2

`define ICACHE_TAG_BIT 9
`define ICACHE_INDEX_BIT 3
`define ICACHE_OFFSET_BIT 5
`define ICACHE_BLOCK_BIT 256 // 32*(2^3)

`define TYPE_BIT 7

`define LUI 0
`define AUIPC 1
`define JAL 2
`define JALR 3

`define BEQ 4
`define BNE 5
`define BLT 6
`define BGE 7
`define BLTU 8
`define BGEU 9

`define LB 10
`define LH 11
`define LW 12
`define LBU 13
`define LHU 14

`define SB 15
`define SH 16
`define SW 17

`define ADDI 18
`define SLTI 19
`define SLTIU 20
`define XORI 21
`define ORI 22
`define ANDI 23
`define SLLI 24
`define SRLI 25
`define SRAI 26

`define ADD 27
`define SUB 28
`define SLL 29
`define SLT 30
`define SLTU 31
`define XOR 32
`define SRL 33
`define SRA 34
`define OR 35
`define AND 36

`define RS_CAP 16
`define RS_CAP_BIT 4

`define LSB_CAP 16
`define LSB_CAP_BIT 4

`define PRED_TABLE_BIT 5
`define PRED_TABLE_SIZE 32
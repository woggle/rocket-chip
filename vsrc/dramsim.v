extern "A" void make_mm
(
  output reg [63:0] mm_ptr
);

extern "A" void memory_tick
(
  input  reg [63:0]               mm_ptr,

  input  reg                      ar_valid,
  output reg                      ar_ready,
  input  reg [`MEM_ADDR_BITS-1:0] ar_addr,
  input  reg [`MEM_ID_BITS-1:0]   ar_id,
  input  reg [2:0]                ar_size,
  input  reg [7:0]                ar_len,

  input  reg                      aw_valid,
  output reg                      aw_ready,
  input  reg [`MEM_ADDR_BITS-1:0] aw_addr,
  input  reg [`MEM_ID_BITS-1:0]   aw_id,
  input  reg [2:0]                aw_size,
  input  reg [7:0]                aw_len,

  input  reg                      w_valid,
  output reg                      w_ready,
  input  reg [`MEM_STRB_BITS-1:0] w_strb,
  input  reg [`MEM_DATA_BITS-1:0] w_data,
  input  reg                      w_last,

  output reg                      r_valid,
  input  reg                      r_ready,
  output reg [1:0]                r_resp,
  output reg [`MEM_ID_BITS-1:0]   r_id,
  output reg [`MEM_DATA_BITS-1:0] r_data,
  output reg                      r_last,

  output reg                      b_valid,
  input  reg                      b_ready,
  output reg [1:0]                b_resp,
  output reg [`MEM_ID_BITS-1:0]   b_id
);

module DRAMSimBlackBox (
  input                       clock,

  input                       io_mem_ar_valid,
  output                      io_mem_ar_ready,
  input  [`MEM_ADDR_BITS-1:0] io_mem_ar_bits_addr,
  input  [`MEM_ID_BITS-1:0]   io_mem_ar_bits_id,
  input  [2:0]                io_mem_ar_bits_size,
  input  [7:0]                io_mem_ar_bits_len,
  input  [1:0]                io_mem_ar_bits_burst,
  input                       io_mem_ar_bits_lock,
  input  [3:0]                io_mem_ar_bits_cache,
  input  [2:0]                io_mem_ar_bits_prot,
  input  [3:0]                io_mem_ar_bits_qos,
  input  [3:0]                io_mem_ar_bits_region,
  input  [0:0]                io_mem_ar_bits_user,

  input                       io_mem_aw_valid,
  output                      io_mem_aw_ready,
  input  [`MEM_ADDR_BITS-1:0] io_mem_aw_bits_addr,
  input  [`MEM_ID_BITS-1:0]   io_mem_aw_bits_id,
  input  [2:0]                io_mem_aw_bits_size,
  input  [7:0]                io_mem_aw_bits_len,
  input  [1:0]                io_mem_aw_bits_burst,
  input                       io_mem_aw_bits_lock,
  input  [3:0]                io_mem_aw_bits_cache,
  input  [2:0]                io_mem_aw_bits_prot,
  input  [3:0]                io_mem_aw_bits_qos,
  input  [3:0]                io_mem_aw_bits_region,
  input  [0:0]                io_mem_aw_bits_user,

  input                       io_mem_w_valid,
  output                      io_mem_w_ready,
  input  [`MEM_STRB_BITS-1:0] io_mem_w_bits_strb,
  input  [`MEM_DATA_BITS-1:0] io_mem_w_bits_data,
  input                       io_mem_w_bits_last,
  input  [0:0]                io_mem_w_bits_user,

  output                      io_mem_r_valid,
  input                       io_mem_r_ready,
  output [1:0]                io_mem_r_bits_resp,
  output [`MEM_ID_BITS-1:0]   io_mem_r_bits_id,
  output [`MEM_DATA_BITS-1:0] io_mem_r_bits_data,
  output                      io_mem_r_bits_last,
  input  [0:0]                io_mem_r_bits_user,

  output                      io_mem_b_valid,
  input                       io_mem_b_ready,
  output [1:0]                io_mem_b_bits_resp,
  output [`MEM_ID_BITS-1:0]   io_mem_b_bits_id,
  input  [0:0]                io_mem_b_bits_user
);

  reg [63:0] mm_ptr;

  initial begin
    make_mm(mm_ptr);
  end

  reg                      ar_valid;
  reg                      ar_ready;
  reg [`MEM_ADDR_BITS-1:0] ar_addr;
  reg [`MEM_ID_BITS-1:0]   ar_id;
  reg [2:0]                ar_size;
  reg [7:0]                ar_len;

  reg                      aw_valid;
  reg                      aw_ready;
  reg [`MEM_ADDR_BITS-1:0] aw_addr;
  reg [`MEM_ID_BITS-1:0]   aw_id;
  reg [2:0]                aw_size;
  reg [7:0]                aw_len;

  reg                      w_valid;
  reg                      w_ready;
  reg [`MEM_STRB_BITS-1:0] w_strb;
  reg [`MEM_DATA_BITS-1:0] w_data;
  reg                      w_last;

  reg                      r_valid;
  reg                      r_ready;
  reg [1:0]                r_resp;
  reg [`MEM_ID_BITS-1:0]   r_id;
  reg [`MEM_DATA_BITS-1:0] r_data;
  reg                      r_last;

  reg                      b_valid;
  reg                      b_ready;
  reg [1:0]                b_resp;
  reg [`MEM_ID_BITS-1:0]   b_id;

  assign io_mem_ar_ready    = ar_ready;
  assign io_mem_aw_ready    = aw_ready;
  assign io_mem_w_ready     = w_ready;
  assign io_mem_r_valid     = r_valid;
  assign io_mem_r_bits_resp = r_resp;
  assign io_mem_r_bits_id   = r_id;
  assign io_mem_r_bits_data = r_data;
  assign io_mem_r_bits_last = r_last;
  assign io_mem_r_bits_user = 1'b0;
  assign io_mem_b_bits_resp = r_resp;
  assign io_mem_b_bits_id   = r_id;
  assign io_mem_b_bits_user = 1'b0;

  always @(posedge clock) begin
    ar_valid <= io_mem_ar_valid;
    ar_addr <= io_mem_ar_bits_addr;
    ar_id <= io_mem_ar_bits_id;
    ar_size <= io_mem_ar_bits_size;
    ar_len <= io_mem_ar_bits_len;

    aw_valid <= io_mem_ar_valid;
    aw_addr <= io_mem_aw_bits_addr;
    aw_id <= io_mem_aw_bits_id;
    aw_size <= io_mem_aw_bits_size;
    aw_len <= io_mem_aw_bits_len;

    w_valid <= io_mem_w_valid;
    w_strb <= io_mem_w_bits_strb;
    w_data <= io_mem_w_bits_data;
    w_last <= io_mem_w_bits_last;

    r_ready <= io_mem_r_ready;
    b_ready <= io_mem_b_ready;

    memory_tick(
      mm_ptr,

      ar_valid,
      ar_ready,
      ar_addr,
      ar_id,
      ar_size,
      ar_len,

      aw_valid,
      aw_ready,
      aw_addr,
      aw_id,
      aw_size,
      aw_len,

      w_valid,
      w_ready,
      w_strb,
      w_data,
      w_last,

      r_valid,
      r_ready,
      r_resp,
      r_id,
      r_data,
      r_last,

      b_valid,
      b_ready,
      b_resp,
      b_id
    );
  end

endmodule

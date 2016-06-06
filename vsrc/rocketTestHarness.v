// See LICENSE for license details.

extern "A" void htif_fini(input reg failure);

extern "A" void htif_tick
(
  output reg                    htif_in_valid,
  input  reg                    htif_in_ready,
  output reg  [`HTIF_WIDTH-1:0] htif_in_bits,

  input  reg                    htif_out_valid,
  output reg                    htif_out_ready,
  input  reg  [`HTIF_WIDTH-1:0] htif_out_bits,

  output reg  [31:0]            exit
);

module rocketTestHarness;

  reg [31:0] seed;
  initial seed = $get_initial_random_seed();

  //-----------------------------------------------
  // Instantiate the processor

  reg clk   = 1'b0;
  reg reset = 1'b1;
  reg r_reset;
  reg start = 1'b0;

  always #`CLOCK_PERIOD clk = ~clk;

  reg [  31:0] n_mem_channel = `N_MEM_CHANNELS;
  reg [  31:0] htif_width = `HTIF_WIDTH;
  reg [  31:0] mem_width = `MEM_DATA_BITS;
  reg [  63:0] max_cycles = 0;
  reg [  63:0] trace_count = 0;
  reg [1023:0] loadmem = 0;
  reg [1023:0] vcdplusfile = 0;
  reg [1023:0] vcdfile = 0;
  reg          verbose = 0;
  wire         printf_cond = verbose && !reset;
  integer      stderr = 32'h80000002;

  reg htif_out_ready;
  wire htif_in_valid;
  wire [`HTIF_WIDTH-1:0] htif_in_bits;
  wire htif_in_ready, htif_out_valid;
  wire [`HTIF_WIDTH-1:0] htif_out_bits;

  always @(posedge clk)
  begin
    r_reset <= reset;
  end

  wire htif_clk;
  wire htif_in_valid_delay;
  wire htif_in_ready_delay;
  wire [`HTIF_WIDTH-1:0] htif_in_bits_delay;

  wire htif_out_valid_delay;
  wire htif_out_ready_delay;
  wire [`HTIF_WIDTH-1:0] htif_out_bits_delay;

  assign #0.1 htif_in_valid_delay = htif_in_valid;
  assign #0.1 htif_in_ready = htif_in_ready_delay;
  assign #0.1 htif_in_bits_delay = htif_in_bits;

  assign #0.1 htif_out_valid = htif_out_valid_delay;
  assign #0.1 htif_out_ready_delay = htif_out_ready;
  assign #0.1 htif_out_bits = htif_out_bits_delay;

`ifdef FPGA
  assign htif_clk = clk;
`endif

`include `TBVFRAG

  reg htif_in_valid_premux;
  reg [`HTIF_WIDTH-1:0] htif_in_bits_premux;
  assign htif_in_bits = htif_in_bits_premux;
  assign htif_in_valid = htif_in_valid_premux;
  wire htif_in_ready_premux = htif_in_ready;
  reg [31:0] exit = 0;

  always @(posedge htif_clk)
  begin
    if (reset || r_reset)
    begin
      htif_in_valid_premux <= 0;
      htif_out_ready <= 0;
      exit <= 0;
    end
    else
    begin
      htif_tick
      (
        htif_in_valid_premux,
        htif_in_ready_premux,
        htif_in_bits_premux,
        htif_out_valid,
        htif_out_ready,
        htif_out_bits,
        exit
      );
    end
  end

  //-----------------------------------------------
  // Start the simulation

  // Read input arguments and initialize
  initial
  begin
    $value$plusargs("max-cycles=%d", max_cycles);
`ifdef MEM_BACKUP_EN
    $value$plusargs("loadmem=%s", loadmem);
    if (loadmem)
      $readmemh(loadmem, mem.ram);
`endif
    verbose = $test$plusargs("verbose");
`ifdef DEBUG
    if ($value$plusargs("vcdplusfile=%s", vcdplusfile))
    begin
      $vcdplusfile(vcdplusfile);
      $vcdpluson(0);
      $vcdplusmemon(0);
    end

    if ($value$plusargs("vcdfile=%s", vcdfile))
    begin
      $dumpfile(vcdfile);
      $dumpvars(0, dut);
      $dumpon;
    end
`define VCDPLUSCLOSE $vcdplusclose; $dumpoff;
`else
`define VCDPLUSCLOSE
`endif

    // Strobe reset
    #777.7 reset = 0;

  end

  reg [255:0] reason = 0;
  always @(posedge clk)
  begin
    if (max_cycles > 0 && trace_count > max_cycles)
      reason = "timeout";
    if (exit > 1)
      $sformat(reason, "tohost = %d", exit >> 1);

    if (reason)
    begin
      $fdisplay(stderr, "*** FAILED *** (%s) after %d simulation cycles", reason, trace_count);
      `VCDPLUSCLOSE
      htif_fini(1'b1);
    end

    if (exit == 1)
    begin
      `VCDPLUSCLOSE
      htif_fini(1'b0);
    end
  end

  always @(posedge clk)
  begin
    trace_count = trace_count + 1;
`ifdef GATE_LEVEL
    if (verbose)
    begin
      $fdisplay(stderr, "C: %10d", trace_count-1);
    end
`endif
  end

endmodule

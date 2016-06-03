// See LICENSE for license details.

#include "htif_emulator.h"
#include "emulator.h"
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define MEM_SIZE_BITS 3
#define MEM_LEN_BITS 8
#define MEM_RESP_BITS 2

htif_emulator_t* htif;
void handle_sigterm(int sig)
{
  htif->stop();
}

int main(int argc, char** argv)
{
  unsigned random_seed = (unsigned)time(NULL) ^ (unsigned)getpid();
  uint64_t max_cycles = -1;
  uint64_t trace_count = 0;
  uint64_t start = 0;
  int ret = 0;
  const char* vcd = NULL;
  const char* loadmem = NULL;
  FILE *vcdfile = NULL;
  bool log = false;
  bool print_cycles = false;

  for (int i = 1; i < argc; i++)
  {
    std::string arg = argv[i];
    if (arg.substr(0, 2) == "-v")
      vcd = argv[i]+2;
    else if (arg.substr(0, 2) == "-s")
      random_seed = atoi(argv[i]+2);
    else if (arg == "+verbose")
      log = true;
    else if (arg.substr(0, 12) == "+max-cycles=")
      max_cycles = atoll(argv[i]+12);
    else if (arg.substr(0, 7) == "+start=")
      start = atoll(argv[i]+7);
    else if (arg.substr(0, 12) == "+cycle-count")
      print_cycles = true;
  }

  const int disasm_len = 24;
  if (vcd)
  {
    // Create a VCD file
    vcdfile = strcmp(vcd, "-") == 0 ? stdout : fopen(vcd, "w");
    assert(vcdfile);
    fprintf(vcdfile, "$scope module Testbench $end\n");
    fprintf(vcdfile, "$var reg %d NDISASM_WB wb_instruction $end\n", disasm_len*8);
    fprintf(vcdfile, "$var reg 64 NCYCLE cycle $end\n");
    fprintf(vcdfile, "$upscope $end\n");
  }

  // The chisel generated code
  Top_t *tile = new Top_t;
  srand(random_seed);
  tile->init(random_seed);

  // Instantiate HTIF
  htif = new htif_emulator_t(std::vector<std::string>(argv + 1, argv + argc));
  int htif_bits = tile->Top__io_host_in_bits.width();
  assert(htif_bits % 8 == 0 && htif_bits <= val_n_bits());

  signal(SIGTERM, handle_sigterm);

  // reset for one host_clk cycle to handle pipelined reset
  tile->Top__io_host_in_valid = LIT<1>(0);
  tile->Top__io_host_out_ready = LIT<1>(0);
  for (int i = 0; i < 3; i += tile->Top__io_host_clk_edge.to_bool())
  {
    tile->clock_lo(LIT<1>(1));
    tile->clock_hi(LIT<1>(1));
  }

  tile->Top__io_debug_req_valid = LIT<1>(0);
  tile->Top__io_debug_resp_ready = LIT<1>(0);

#include TBFRAG

  while (!htif->done() && trace_count < max_cycles && ret == 0)
  {
    try {
      tile->clock_lo(LIT<1>(0));
    } catch (std::runtime_error& e) {
      max_cycles = trace_count; // terminate cleanly after this cycle
      ret = 1;
      std::cerr << e.what() << std::endl;
    }

    if (tile->Top__io_host_clk_edge.to_bool())
    {
      static bool htif_in_valid = false;
      static val_t htif_in_bits;
      if (tile->Top__io_host_in_ready.to_bool() || !htif_in_valid)
        htif_in_valid = htif->recv_nonblocking(&htif_in_bits, htif_bits/8);
      tile->Top__io_host_in_valid = LIT<1>(htif_in_valid);
      tile->Top__io_host_in_bits = LIT<64>(htif_in_bits);

      if (tile->Top__io_host_out_valid.to_bool())
        htif->send(tile->Top__io_host_out_bits.values, htif_bits/8);
      tile->Top__io_host_out_ready = LIT<1>(1);
    }

    if (log && trace_count >= start)
      tile->print(stderr);

    // make sure we dump on cycle 0 to get dump_init
    if (vcd && (trace_count == 0 || trace_count >= start))
      tile->dump(vcdfile, trace_count);

    tile->clock_hi(LIT<1>(0));
    trace_count++;
  }

  if (vcd)
    fclose(vcdfile);

  if (htif->exit_code())
  {
    fprintf(stderr, "*** FAILED *** (code = %d, seed %d) after %ld cycles\n", htif->exit_code(), random_seed, trace_count);
    ret = htif->exit_code();
  }
  else if (trace_count == max_cycles)
  {
    fprintf(stderr, "*** FAILED *** (timeout, seed %d) after %ld cycles\n", random_seed, trace_count);
    ret = 2;
  }
  else if (log || print_cycles)
  {
    fprintf(stderr, "Completed after %ld cycles\n", trace_count);
  }

  delete htif;
  delete tile;

  return ret;
}

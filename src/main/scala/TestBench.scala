// See LICENSE for license details.

package rocketchip

import Chisel._
import cde.Parameters
import uncore.{DbBusConsts, DMKey}

object TestBenchGeneration extends FileSystemUtilities {
  def generateVerilogFragment(
      topModuleName: String, configClassName: String, p: Parameters) = {
    val nMemChannel = p(NMemoryChannels)
    // YUNSUP:
    // I originally wrote this using a 2d wire array, but of course Synopsys'
    // DirectC implementation totally chokes on it when the 2d array is
    // referenced by the first dimension: the wire shows up as a contiguous
    // bit collection on the DirectC side.  I had to individually define the
    // wires.

    val interrupts = (0 until p(NExtInterrupts)) map { i => s"""
    .io_interrupts_$i (1'b0),
""" } mkString

    val daw = p(DMKey).nDebugBusAddrSize
    val dow = DbBusConsts.dbOpSize
    val ddw = DbBusConsts.dbDataSize
    val debug_bus = s"""
  .io_debug_req_ready( ),
  .io_debug_req_valid(1'b0),
  .io_debug_req_bits_addr($daw'b0),
  .io_debug_req_bits_op($dow'b0),
  .io_debug_req_bits_data($ddw'b0),
  .io_debug_resp_ready(1'b0),
  .io_debug_resp_valid( ),
  .io_debug_resp_bits_resp( ),
  .io_debug_resp_bits_data( ),
"""


    val instantiation = s"""
  Top dut
  (
    .clk(clk),
    .reset(reset),

    $interrupts

    $debug_bus

`ifndef FPGA
    .io_host_clk(htif_clk),
    .io_host_clk_edge(),
`else
    .io_host_clk (),
    .io_host_clk_edge (),
`endif // FPGA

    .io_host_in_valid(htif_in_valid_delay),
    .io_host_in_ready(htif_in_ready_delay),
    .io_host_in_bits(htif_in_bits_delay),
    .io_host_out_valid(htif_out_valid_delay),
    .io_host_out_ready(htif_out_ready_delay),
    .io_host_out_bits(htif_out_bits_delay)
  );
"""

    val f = createOutputFile(s"$topModuleName.$configClassName.tb.vfrag")
    f.write(instantiation)
    f.close
  }

  def generateCPPFragment(
      topModuleName: String, configClassName: String, p: Parameters) = {
    val nMemChannel = p(NMemoryChannels)

    val interrupts = (0 until p(NExtInterrupts)) map { i => s"""
      tile->Top__io_interrupts_$i = LIT<1>(0);
""" } mkString

    val f = createOutputFile(s"$topModuleName.$configClassName.tb.cpp")
    f.write(interrupts)
    f.close
  }
}

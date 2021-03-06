// See LICENSE for license details.

package uncore.tilelink2

import Chisel._
import chisel3.internal.sourceinfo.SourceInfo

// Acks Hints for managers that don't support them or Acks all Hints if !passthrough
class TLHintHandler(supportManagers: Boolean = true, supportClients: Boolean = false, passthrough: Boolean = true) extends LazyModule
{
  val node = TLAdapterNode(
    clientFn  = { case Seq(c) => if (supportClients)  c.copy(clients  = c.clients .map(_.copy(supportsHint = true))) else c },
    managerFn = { case Seq(m) => if (supportManagers) m.copy(managers = m.managers.map(_.copy(supportsHint = true))) else m })

  lazy val module = new LazyModuleImp(this) {
    val io = new Bundle {
      val in  = node.bundleIn
      val out = node.bundleOut
    }

    val in  = io.in(0)
    val out = io.out(0)
    val edgeIn  = node.edgesIn(0)
    val edgeOut = node.edgesOut(0)

    // Don't add support for clients if there is no BCE channel
    val bce = edgeOut.manager.anySupportAcquire && edgeIn.client.anySupportProbe
    require (!supportClients || bce)

    if (supportManagers) {
      val handleA = if (passthrough) !edgeOut.manager.supportsHint(edgeIn.address(in.a.bits)) else Bool(true)
      val bypassD = handleA && in.a.bits.opcode === TLMessages.Hint

      // Prioritize existing D traffic over HintAck
      in.d.valid  := out.d.valid || (bypassD && in.a.valid)
      out.d.ready := in.d.ready
      in.d.bits   := Mux(out.d.valid, out.d.bits, edgeIn.HintAck(in.a.bits))

      in.a.ready  := Mux(bypassD, in.d.ready && !out.d.valid, out.a.ready)
      out.a.valid := in.a.valid && !bypassD
      out.a.bits  := in.a.bits
    } else {
      out.a.valid := in.a.valid
      in.a.ready := out.a.ready
      out.a.bits := in.a.bits

      in.d.valid := out.d.valid
      out.d.ready := in.d.ready
      in.d.bits := out.d.bits
    }

    if (supportClients) {
      val handleB = if (passthrough) !edgeIn.client.supportsHint(out.b.bits.source) else Bool(true)
      val bypassC = handleB && out.b.bits.opcode === TLMessages.Hint

      // Prioritize existing C traffic over HintAck
      out.c.valid := in.c.valid || (bypassC && in.b.valid)
      in.c.ready  := out.c.ready
      out.c.bits  := Mux(in.c.valid, in.c.bits, edgeOut.HintAck(out.b.bits))

      out.b.ready := Mux(bypassC, out.c.ready && !in.c.valid, in.b.ready)
      in.b.valid  := out.b.valid && !bypassC
      in.b.bits   := out.b.bits
    } else if (bce) {
      in.b.valid := out.b.valid
      out.b.ready := in.b.ready
      in.b.bits := out.b.bits

      out.c.valid := in.c.valid
      in.c.ready := out.c.ready
      out.c.bits := in.c.bits
    } else {
      in.b.valid := Bool(false)
      in.c.ready := Bool(true)
      out.b.ready := Bool(true)
      out.c.valid := Bool(false)
    }

    if (bce) {
      // Pass E through unchanged
      out.e.valid := in.e.valid
      in.e.ready := out.e.ready
      out.e.bits := in.e.bits
    } else {
      in.e.ready := Bool(true)
      out.e.valid := Bool(false)
    }
  }
}

object TLHintHandler
{
  // applied to the TL source node; y.node := TLHintHandler(x.node)
  def apply(x: TLBaseNode, supportManagers: Boolean = true, supportClients: Boolean = false, passthrough: Boolean = true)(implicit sourceInfo: SourceInfo): TLBaseNode = {
    val hints = LazyModule(new TLHintHandler(supportManagers, supportClients, passthrough))
    hints.node := x
    hints.node
  }
}

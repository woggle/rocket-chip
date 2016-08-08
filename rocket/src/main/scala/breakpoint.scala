// See LICENSE for license details.

package rocket

import Chisel._
import Util._
import cde.Parameters



class TDRSelect(implicit p: Parameters) extends CoreBundle()(p) {
  val tdrmode = Bool()
  val reserved = UInt(width = xLen - 1 - log2Up(nTDR))
  val tdrindex = UInt(width = log2Up(nTDR))

  def nTDR = p(NBreakpoints)
}

object TDRType extends scala.Enumeration {
  type TDRType = Value
  val None = Value(0)
  val Legacy = Value(1)
  val Match = Value(2)
  val Unavailable = Value(15)
}
import TDRType._

object TDRSelect extends scala.Enumeration {
  type TDRSelect = Value
  val Address = Value(0)
  val Data = Value(1)
}
import TDRSelect._

object TDRAction extends scala.Enumeration {
  type TDRAction = Value
  val None = Value(0)
  val DebugException = Value(1)
  val DebugMode = Value(2)
  val StartTrace = Value(3)
  val StopTrace = Value(4)
  val EmitTrace = Value(5)
}
import TDRAction._

//Chain is too simple.

object TDRMatch extends scala.Enumeration {
  type Match = Value
  val EQ = Value(0)
  val NAPOT = Value(1)
  val GEQ = Value(2)
  val LT = Value(3)
  val LOWER = Value(4)
  val UPPER = Value(5)
}
import TDRMatch._


class BPControl(implicit p: Parameters) extends CoreBundle()(p) {
  val tdrtype = UInt(width = 4)
  val bpmaskmax = UInt(width = 6)
  val reserved = UInt(width = xLen-30)
  val bpselect = Bool()
  val bpaction = UInt(width = 7)
  val bpchain = Bool()
  val bpmatch = UInt(width = 4)
  val m = Bool()
  val h = Bool()
  val s = Bool()
  val u = Bool()
  val x = Bool()
  val w = Bool()
  val r = Bool()

  def tdrType = UInt(TDRType.Match.id)
  def bpMaskMax = 4
  def enabled(mstatus: MStatus) = Cat(m, h, s, u)(mstatus.prv)
}

class BP(implicit p: Parameters) extends CoreBundle()(p) {
  val control = new BPControl
  val address = UInt(width = vaddrBits)
  val r = Bool()
  val w = Bool()

  def mask(dummy: Int = 0) = {
    var mask: UInt = (control.bpmatch === UInt(TDRMatch.NAPOT.id))
    for (i <- 1 until control.bpMaskMax)
      mask = Cat(mask(i-1) && address(i-1), mask)
    mask
  }

  def napotMatch(x: UInt) =
    (~x | mask()) === (~address | mask())


  def supportedMatch(x : UInt) =
    ((control.bpmatch === UInt(TDRMatch.EQ.id))    && (x === address)) ||
    ((control.bpmatch === UInt(TDRMatch.NAPOT.id)) &&  napotMatch(x))  ||
    ((control.bpmatch === UInt(TDRMatch.GEQ.id))   && (x >= address))  ||
    ((control.bpmatch === UInt(TDRMatch.LT.id))    && (x <  address))

    // Other match types are not supported
}

class TriggerInfo extends Bundle {
  val x = Bool()
  val w = Bool()
  val r = Bool()
  val chain = Bool()
}

object TriggerInfo {
  def apply () : TriggerInfo = {
    val t = Wire ( new TriggerInfo() )
    t.x := false
    t.w := false
    t.r := false
    t.chain := false
    t
  }
}


class BreakpointUnit(implicit p: Parameters) extends CoreModule()(p) {
  val io = new Bundle {
    val status = new MStatus().asInput
    val bp = Vec(p(NBreakpoints), new BP).asInput
    val pc = UInt(INPUT, vaddrBits)
    val ea = UInt(INPUT, vaddrBits)
    val r = Bool(INPUT)
    val w = Bool(INPUT)
    val xcpt_if = Bool(OUTPUT)
    val xcpt_ld = Bool(OUTPUT)
    val xcpt_st = Bool(OUTPUT)
  }


  //----------------------------------------------------
  // Match Calculation

  val triggers = Wire (Vec(p(NBreakpoints), new TriggerInfo))
  triggers := Vec.fill(p(NBreakpoints)) { TriggerInfo() }
  
  // First, check without chaining.
  for ((bp, trigger) <- io.bp zip triggers) {
    when (bp.control.enabled(io.status)) {
      trigger.x     :=         bp.control.x && bp.supportedMatch(io.pc)
      trigger.w     := bp.w && bp.control.w && bp.supportedMatch(io.ea)
      trigger.r     := bp.r && bp.control.r && bp.supportedMatch(io.ea)
      trigger.chain := bp.control.bpchain
    }
  }

  // Now combine triggers with chaining.
  // We do not support chaning more than 2.
  // Therefore, start at the end to avoid
  // cascading effect
  for ((curr, prev) <- triggers.reverse zip triggers.reverse.tail) {
    when (curr.chain & ~(prev.x | prev.w | prev.r)) {
      curr.x := false
      curr.w := false
      curr.r := false
    }
  }

  //----------------------------------------------------
  // Take Action

  io.xcpt_if := false
  io.xcpt_ld := false
  io.xcpt_st := false

  for ((bp, trigger) <- io.bp zip triggers) {
    when (bp.control.bpaction === UInt(TDRAction.DebugException.id)) {
      when (trigger.x) {io.xcpt_if := true}
      when (trigger.w) {io.xcpt_st := true}
      when (trigger.r) {io.xcpt_ld := true}
    }
    // No Other Actions are Supported.
  }
}

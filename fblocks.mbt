///| IEC 61131-3 标准功能块 (Function Blocks) 实现

///| TON: 通电延时定时器 (Timer On-Delay)
pub(all) struct TonTimer {
  mut in_state : Bool
  mut pt : Int64      // 预置延时 (ms)
  mut et : Int64      // 已用时间 (ms)
  mut q : Bool        // 输出
} derive(Debug)

pub fn TonTimer::new() -> TonTimer {
  { in_state: false, pt: 0L, et: 0L, q: false }
}

///| TON 周期步进刷新
pub fn TonTimer::tick(self : TonTimer, in_val : Bool, pt_val : Int64, delta_ms : Int64) -> Unit {
  self.in_state = in_val
  self.pt = pt_val

  if self.in_state {
    if self.et < self.pt {
      self.et = self.et + delta_ms
      if self.et > self.pt {
        self.et = self.pt
      }
    }
    self.q = self.et >= self.pt
  } else {
    self.et = 0L
    self.q = false
  }
}

///| TOF: 断电延时定时器 (Timer Off-Delay)
pub(all) struct TofTimer {
  mut in_state : Bool
  mut pt : Int64
  mut et : Int64
  mut q : Bool
} derive(Debug)

pub fn TofTimer::new() -> TofTimer {
  { in_state: false, pt: 0L, et: 0L, q: false }
}

///| TOF 周期步进刷新
pub fn TofTimer::tick(self : TofTimer, in_val : Bool, pt_val : Int64, delta_ms : Int64) -> Unit {
  self.in_state = in_val
  self.pt = pt_val

  if self.in_state {
    self.q = true
    self.et = 0L
  } else {
    if self.q {
      self.et = self.et + delta_ms
      if self.et >= self.pt {
        self.et = self.pt
        self.q = false
      }
    } else {
      self.et = 0L
    }
  }
}

///| TP: 脉冲定时器 (Timer Pulse)
pub(all) struct TpTimer {
  mut in_prev : Bool
  mut active : Bool
  mut pt : Int64
  mut et : Int64
  mut q : Bool
} derive(Debug)

pub fn TpTimer::new() -> TpTimer {
  { in_prev: false, active: false, pt: 0L, et: 0L, q: false }
}

///| TP 周期步进刷新
pub fn TpTimer::tick(self : TpTimer, in_val : Bool, pt_val : Int64, delta_ms : Int64) -> Unit {
  self.pt = pt_val
  let rising_edge = in_val && !self.in_prev
  self.in_prev = in_val

  if rising_edge && !self.active {
    self.active = true
    self.q = true
    self.et = 0L
  }

  if self.active {
    self.et = self.et + delta_ms
    if self.et >= self.pt {
      self.active = false
      self.q = false
      self.et = self.pt
    }
  } else {
    self.q = false
  }
}

///| TONR: 保持型通电延时定时器 (Retentive On-Delay Timer)
pub(all) struct TonrTimer {
  mut in_state : Bool
  mut pt : Int64
  mut et : Int64
  mut q : Bool
} derive(Debug)

pub fn TonrTimer::new() -> TonrTimer {
  { in_state: false, pt: 0L, et: 0L, q: false }
}

pub fn TonrTimer::tick(self : TonrTimer, in_val : Bool, reset_val : Bool, pt_val : Int64, delta_ms : Int64) -> Unit {
  self.pt = pt_val
  self.in_state = in_val

  if reset_val {
    self.et = 0L
    self.q = false
  } else {
    if self.in_state && self.et < self.pt {
      self.et = self.et + delta_ms
      if self.et > self.pt {
        self.et = self.pt
      }
    }
    self.q = self.et >= self.pt
  }
}

///| CTU: 增计数器 (Count Up)
pub(all) struct CtuCounter {
  mut cu_prev : Bool
  mut pv : Int        // 预置计数值
  mut cv : Int        // 当前计数值
  mut q : Bool        // 达到计数值输出
} derive(Debug)

pub fn CtuCounter::new() -> CtuCounter {
  { cu_prev: false, pv: 0, cv: 0, q: false }
}

///| CTU 步进计算
pub fn CtuCounter::tick(self : CtuCounter, cu_val : Bool, reset_val : Bool, pv_val : Int) -> Unit {
  self.pv = pv_val
  let rising_edge = cu_val && !self.cu_prev
  self.cu_prev = cu_val

  if reset_val {
    self.cv = 0
    self.q = false
  } else {
    if rising_edge && self.cv < 32767 {
      self.cv = self.cv + 1
    }
    self.q = self.cv >= self.pv
  }
}

///| CTUD: 增减双向计数器 (Count Up/Down)
pub(all) struct CtudCounter {
  mut cu_prev : Bool
  mut cd_prev : Bool
  mut pv : Int
  mut cv : Int
  mut qu : Bool
  mut qd : Bool
} derive(Debug)

pub fn CtudCounter::new() -> CtudCounter {
  { cu_prev: false, cd_prev: false, pv: 0, cv: 0, qu: false, qd: false }
}

pub fn CtudCounter::tick(self : CtudCounter, cu_val : Bool, cd_val : Bool, r_val : Bool, ld_val : Bool, pv_val : Int) -> Unit {
  self.pv = pv_val
  let cu_edge = cu_val && !self.cu_prev
  let cd_edge = cd_val && !self.cd_prev
  self.cu_prev = cu_val
  self.cd_prev = cd_val

  if r_val {
    self.cv = 0
  } else if ld_val {
    self.cv = self.pv
  } else {
    if cu_edge && !cd_edge && self.cv < 32767 {
      self.cv = self.cv + 1
    } else if cd_edge && !cu_edge && self.cv > -32768 {
      self.cv = self.cv - 1
    }
  }

  self.qu = self.cv >= self.pv
  self.qd = self.cv <= 0
}

///| SR: 置位优先双稳态触发器 (Set-Dominant Bistable)
pub(all) struct SrFlipFlop {
  mut q1 : Bool
} derive(Debug)

pub fn SrFlipFlop::new() -> SrFlipFlop {
  { q1: false }
}

pub fn SrFlipFlop::tick(self : SrFlipFlop, s1_val : Bool, r_val : Bool) -> Bool {
  self.q1 = s1_val || (!r_val && self.q1)
  self.q1
}

///| RS: 复位优先双稳态触发器 (Reset-Dominant Bistable)
pub(all) struct RsFlipFlop {
  mut q1 : Bool
} derive(Debug)

pub fn RsFlipFlop::new() -> RsFlipFlop {
  { q1: false }
}

pub fn RsFlipFlop::tick(self : RsFlipFlop, s_val : Bool, r1_val : Bool) -> Bool {
  self.q1 = !r1_val && (s_val || self.q1)
  self.q1
}

///| R_TRIG: 上升沿检测触发器 (Rising Edge Detector)
pub(all) struct RTrig {
  mut clk_prev : Bool
  mut q : Bool
} derive(Debug)

pub fn RTrig::new() -> RTrig {
  { clk_prev: false, q: false }
}

pub fn RTrig::tick(self : RTrig, clk_val : Bool) -> Bool {
  self.q = clk_val && !self.clk_prev
  self.clk_prev = clk_val
  self.q
}

///| F_TRIG: 下降沿检测触发器 (Falling Edge Detector)
pub(all) struct FTrig {
  mut clk_prev : Bool
  mut q : Bool
} derive(Debug)

pub fn FTrig::new() -> FTrig {
  { clk_prev: false, q: false }
}

pub fn FTrig::tick(self : FTrig, clk_val : Bool) -> Bool {
  self.q = !clk_val && self.clk_prev
  self.clk_prev = clk_val
  self.q
}

///| 通用功能块实例封装
pub(all) enum FbInstance {
  Ton(TonTimer)
  Tof(TofTimer)
  Tp(TpTimer)
  Tonr(TonrTimer)
  Ctu(CtuCounter)
  Ctud(CtudCounter)
  Sr(SrFlipFlop)
  Rs(RsFlipFlop)
  Rtrig(RTrig)
  Ftrig(FTrig)
} derive(Debug)

///| 获取功能块内部字段值 (如 Timer1.Q 或 Counter1.CV)
pub fn FbInstance::get_field(self : FbInstance, field : String) -> PlcValue {
  let f = field
  match self {
    FbInstance::Ton(t) => {
      if f == "Q" || f == "q" { PlcValue::Bool(t.q) }
      else if f == "ET" || f == "et" { PlcValue::Time(t.et) }
      else { PlcValue::Null }
    }
    FbInstance::Tof(t) => {
      if f == "Q" || f == "q" { PlcValue::Bool(t.q) }
      else if f == "ET" || f == "et" { PlcValue::Time(t.et) }
      else { PlcValue::Null }
    }
    FbInstance::Tp(t) => {
      if f == "Q" || f == "q" { PlcValue::Bool(t.q) }
      else if f == "ET" || f == "et" { PlcValue::Time(t.et) }
      else { PlcValue::Null }
    }
    FbInstance::Tonr(t) => {
      if f == "Q" || f == "q" { PlcValue::Bool(t.q) }
      else if f == "ET" || f == "et" { PlcValue::Time(t.et) }
      else { PlcValue::Null }
    }
    FbInstance::Ctu(c) => {
      if f == "Q" || f == "q" { PlcValue::Bool(c.q) }
      else if f == "CV" || f == "cv" { PlcValue::Int(c.cv) }
      else { PlcValue::Null }
    }
    FbInstance::Ctud(c) => {
      if f == "QU" || f == "qu" { PlcValue::Bool(c.qu) }
      else if f == "QD" || f == "qd" { PlcValue::Bool(c.qd) }
      else if f == "CV" || f == "cv" { PlcValue::Int(c.cv) }
      else { PlcValue::Null }
    }
    FbInstance::Sr(s) => {
      if f == "Q1" || f == "q1" || f == "Q" || f == "q" { PlcValue::Bool(s.q1) }
      else { PlcValue::Null }
    }
    FbInstance::Rs(r) => {
      if f == "Q1" || f == "q1" || f == "Q" || f == "q" { PlcValue::Bool(r.q1) }
      else { PlcValue::Null }
    }
    FbInstance::Rtrig(r) => {
      if f == "Q" || f == "q" { PlcValue::Bool(r.q) }
      else { PlcValue::Null }
    }
    FbInstance::Ftrig(f_inst) => {
      if f == "Q" || f == "q" { PlcValue::Bool(f_inst.q) }
      else { PlcValue::Null }
    }
  }
}

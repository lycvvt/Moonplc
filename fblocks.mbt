///| IEC 61131-3 标准功能块 (Function Blocks) 实现

///|
/// TON: 通电延时定时器 (Timer On-Delay)
pub(all) struct TonTimer {
  mut in_state : Bool
  mut pt : Int64 // 预置延时 (ms)
  mut et : Int64 // 已用时间 (ms)
  mut q : Bool // 输出
} derive(Debug)

///|
pub fn TonTimer::new() -> TonTimer {
  { in_state: false, pt: 0L, et: 0L, q: false, }
}

///|
/// TON 周期步进刷新
pub fn TonTimer::tick(
  self : TonTimer,
  in_val : Bool,
  pt_val : Int64,
  delta_ms : Int64,
) -> Unit {
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

///|
/// TOF: 断电延时定时器 (Timer Off-Delay)
pub(all) struct TofTimer {
  mut in_state : Bool
  mut pt : Int64
  mut et : Int64
  mut q : Bool
} derive(Debug)

///|
pub fn TofTimer::new() -> TofTimer {
  { in_state: false, pt: 0L, et: 0L, q: false, }
}

///|
/// TOF 周期步进刷新
pub fn TofTimer::tick(
  self : TofTimer,
  in_val : Bool,
  pt_val : Int64,
  delta_ms : Int64,
) -> Unit {
  self.in_state = in_val
  self.pt = pt_val

  if self.in_state {
    self.q = true
    self.et = 0L
  } else if self.q {
    self.et = self.et + delta_ms
    if self.et >= self.pt {
      self.et = self.pt
      self.q = false
    }
  } else {
    self.et = 0L
  }
}

///|
/// TP: 脉冲定时器 (Timer Pulse)
pub(all) struct TpTimer {
  mut in_prev : Bool
  mut active : Bool
  mut pt : Int64
  mut et : Int64
  mut q : Bool
} derive(Debug)

///|
pub fn TpTimer::new() -> TpTimer {
  { in_prev: false, active: false, pt: 0L, et: 0L, q: false, }
}

///|
/// TP 周期步进刷新
pub fn TpTimer::tick(
  self : TpTimer,
  in_val : Bool,
  pt_val : Int64,
  delta_ms : Int64,
) -> Unit {
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

///|
/// CTU: 增计数器 (Count Up)
pub(all) struct CtuCounter {
  mut cu_prev : Bool
  mut pv : Int // 预置计数值
  mut cv : Int // 当前计数值
  mut q : Bool // 达到计数值输出
} derive(Debug)

///|
pub fn CtuCounter::new() -> CtuCounter {
  { cu_prev: false, pv: 0, cv: 0, q: false, }
}

///|
/// CTU 步进计算
pub fn CtuCounter::tick(
  self : CtuCounter,
  cu_val : Bool,
  reset_val : Bool,
  pv_val : Int,
) -> Unit {
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

///|
/// 通用功能块实例封装
pub(all) enum FbInstance {
  Ton(TonTimer)
  Tof(TofTimer)
  Tp(TpTimer)
  Ctu(CtuCounter)
} derive(Debug)

///|
/// 获取功能块内部字段值 (如 Timer1.Q 或 Counter1.CV)
pub fn FbInstance::get_field(self : FbInstance, field : String) -> PlcValue {
  match self {
    FbInstance::Ton(t) =>
      if field == "Q" || field == "q" {
        PlcValue::Bool(t.q)
      } else if field == "ET" || field == "et" {
        PlcValue::Time(t.et)
      } else {
        PlcValue::Null
      }
    FbInstance::Tof(t) =>
      if field == "Q" || field == "q" {
        PlcValue::Bool(t.q)
      } else if field == "ET" || field == "et" {
        PlcValue::Time(t.et)
      } else {
        PlcValue::Null
      }
    FbInstance::Tp(t) =>
      if field == "Q" || field == "q" {
        PlcValue::Bool(t.q)
      } else if field == "ET" || field == "et" {
        PlcValue::Time(t.et)
      } else {
        PlcValue::Null
      }
    FbInstance::Ctu(c) =>
      if field == "Q" || field == "q" {
        PlcValue::Bool(c.q)
      } else if field == "CV" || field == "cv" {
        PlcValue::Int(c.cv)
      } else {
        PlcValue::Null
      }
  }
}

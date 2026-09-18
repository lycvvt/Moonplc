///| 工业闭环控制算法：PID 控制器功能块 (PID Controller)

///| 工业 PID 控制器结构
pub(all) struct PidController {
  // 调节参数
  mut kp : Double           // 比例增益 (Proportional Gain)
  mut ti_ms : Double        // 积分时间 (Integral Time Constant in ms)
  mut td_ms : Double        // 微分时间 (Derivative Time Constant in ms)
  mut out_min : Double      // 控制量下限限幅
  mut out_max : Double      // 控制量上限限幅
  mut deadband : Double     // 误差死区

  // 状态变量
  mut integral_acc : Double // 积分累加量
  mut prev_pv : Double      // 上周期被控量 (用于微分先行)
  mut prev_error : Double   // 上周期误差
  mut manual : Bool         // 手/自动模式切换 (true=手动, false=自动)
  mut manual_val : Double   // 手动开度给定

  // 输出
  mut output : Double       // 当前计算控制输出 (MV - Manipulated Variable)
} derive(Debug)

///| 创建默认工业 PID 控制器
pub fn PidController::new(kp : Double, ti_ms : Double, td_ms : Double) -> PidController {
  {
    kp,
    ti_ms,
    td_ms,
    out_min: 0.0,
    out_max: 100.0, // 默认 0% ~ 100% 阀门开度
    deadband: 0.0,
    integral_acc: 0.0,
    prev_pv: 0.0,
    prev_error: 0.0,
    manual: false,
    manual_val: 0.0,
    output: 0.0,
  }
}

///| 设置输出限幅区间
pub fn PidController::set_limits(self : PidController, min_val : Double, max_val : Double) -> Unit {
  self.out_min = min_val
  self.out_max = max_val
}

///| 设置误差死区
pub fn PidController::set_deadband(self : PidController, db : Double) -> Unit {
  self.deadband = db
}

///| 手动/自动模式无扰切换 (Bumpless Transfer)
pub fn PidController::set_manual(self : PidController, manual_mode : Bool, man_val : Double) -> Unit {
  self.manual = manual_mode
  self.manual_val = man_val
  if self.manual {
    // 手动模式下，反向跟踪积分器以确保切回自动时无扰动
    self.integral_acc = man_val
    self.output = man_val
  }
}

///| PID 周期执行计算 (按采样周期 dt 毫秒计算输出)
pub fn PidController::compute(self : PidController, sp : Double, pv : Double, dt_ms : Double) -> Double {
  if self.manual {
    self.output = self.manual_val
    return self.output
  }

  let dt = if dt_ms <= 0.0 { 1.0 } else { dt_ms }
  let mut error = sp - pv

  // 1. 死区滤波
  if self.deadband > 0.0 {
    let abs_err = if error < 0.0 { -error } else { error }
    if abs_err < self.deadband {
      error = 0.0
    }
  }

  // 2. 比例项 (P)
  let p_term = self.kp * error

  // 3. 积分项 (I) 带抗积分饱和 (Anti-Windup)
  if self.ti_ms > 0.0 {
    let delta_i = (self.kp * (dt / self.ti_ms)) * error
    // 只有在输出未饱和或反向纠偏时才累加积分
    let next_i = self.integral_acc + delta_i
    if next_i >= self.out_min && next_i <= self.out_max {
      self.integral_acc = next_i
    }
  }

  // 4. 微分项 (D) 采用微分先行 (Derivative on PV)，防止给定值 SP 阶跃产生突变冲击
  let mut d_term = 0.0
  if self.td_ms > 0.0 {
    let delta_pv = pv - self.prev_pv
    d_term = -self.kp * (self.td_ms / dt) * delta_pv
  }

  // 5. PID 输出合成
  let raw_output = p_term + self.integral_acc + d_term

  // 6. 输出限幅与状态更新
  let clamped = if raw_output > self.out_max {
    self.out_max
  } else if raw_output < self.out_min {
    self.out_min
  } else {
    raw_output
  }

  self.prev_pv = pv
  self.prev_error = error
  self.output = clamped
  self.output
}

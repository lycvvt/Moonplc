///| 测试工业 PID 控制器闭环调节与收敛特性

test "pid proportional response and limits" {
  let pid = PidController::new(2.0, 0.0, 0.0) // 纯 P 调节, Kp=2.0
  pid.set_limits(0.0, 100.0)

  // SP = 50, PV = 40 -> Error = 10 -> Output = 2.0 * 10 = 20.0
  let out1 = pid.compute(50.0, 40.0, 100.0)
  assert_eq(out1, 20.0)

  // 极大误差产生饱和: SP = 100, PV = 10 -> Error = 90 -> Raw = 180 -> Clamped to 100.0
  let out_sat = pid.compute(100.0, 10.0, 100.0)
  assert_eq(out_sat, 100.0)
}

test "pid deadband suppression" {
  let pid = PidController::new(2.0, 0.0, 0.0)
  pid.set_deadband(1.5) // 死区 1.5

  // 误差 1.0 小于死区 1.5，输出应当被抑制为 0
  let out = pid.compute(50.0, 49.0, 100.0)
  assert_eq(out, 0.0)

  // 误差 2.0 大于死区，正常输出
  let out2 = pid.compute(50.0, 48.0, 100.0)
  assert_eq(out2, 4.0)
}

test "pid manual mode bumpless transfer" {
  let pid = PidController::new(1.0, 1000.0, 0.0)
  pid.set_manual(true, 45.0)

  // 手动模式下输出严格等于给定值
  let out_man = pid.compute(100.0, 20.0, 50.0)
  assert_eq(out_man, 45.0)

  // 切回自动模式
  pid.set_manual(false, 0.0)
  assert_eq(pid.integral_acc, 45.0)
}

test "pid closed loop temperature tank convergence simulation" {
  // 模拟一阶惯性加热水箱: 一阶延迟 + 散热
  // PV(t) = PV(t-1) + (Heater_Power * 0.05) - (PV(t-1) - 20.0) * 0.02
  let pid = PidController::new(2.5, 800.0, 50.0) // 经典 PID
  pid.set_limits(0.0, 100.0)

  let sp = 60.0 // 目标水温 60°C
  let mut pv = 20.0 // 初始室温 20°C
  let dt_ms = 50.0

  // 模拟运行 200 个控制周期 (10 秒)
  let mut cycle = 0
  while cycle < 200 {
    let heater_power = pid.compute(sp, pv, dt_ms)
    // 物理环境热量动态演化方程
    let heating = heater_power * 0.04
    let cooling = (pv - 20.0) * 0.015
    pv = pv + heating - cooling
    cycle = cycle + 1
  }

  // 验证闭环收敛: 稳态温度与 60°C 误差小于 1.0°C
  let steady_error = if sp > pv { sp - pv } else { pv - sp }
  assert_eq(steady_error < 1.0, true)
}

///| 测试 IEC 61131-3 标准与扩展功能块

test "fblocks ton timer timing" {
  let ton = TonTimer::new()

  // 1. IN = false 时，Q 为 false，ET = 0
  ton.tick(false, 1000L, 50L)
  assert_eq(ton.q, false)
  assert_eq(ton.et, 0L)

  // 2. IN = true，延时步进 500ms (未达到 1000ms)
  ton.tick(true, 1000L, 500L)
  assert_eq(ton.q, false)
  assert_eq(ton.et, 500L)

  // 3. 再次步进 600ms (累计 1100ms >= 1000ms)
  ton.tick(true, 1000L, 600L)
  assert_eq(ton.q, true)
  assert_eq(ton.et, 1000L)

  // 4. IN 变为 false，立即复位
  ton.tick(false, 1000L, 50L)
  assert_eq(ton.q, false)
  assert_eq(ton.et, 0L)
}

test "fblocks ctu counter pulse counting" {
  let ctu = CtuCounter::new()

  // 第一次脉冲上升沿
  ctu.tick(true, false, 3)
  assert_eq(ctu.cv, 1)
  assert_eq(ctu.q, false)

  // 保持高电平，计数值不变
  ctu.tick(true, false, 3)
  assert_eq(ctu.cv, 1)

  // 下降沿
  ctu.tick(false, false, 3)
  assert_eq(ctu.cv, 1)

  // 第二次脉冲
  ctu.tick(true, false, 3)
  assert_eq(ctu.cv, 2)
  assert_eq(ctu.q, false)

  // 第三次脉冲 (达到预设值 3)
  ctu.tick(false, false, 3)
  ctu.tick(true, false, 3)
  assert_eq(ctu.cv, 3)
  assert_eq(ctu.q, true)

  // 复位
  ctu.tick(false, true, 3)
  assert_eq(ctu.cv, 0)
  assert_eq(ctu.q, false)
}

test "fblocks sr and rs flip-flops" {
  let sr = SrFlipFlop::new()
  // 置位优先: S1=true, R=true 时 Q 应为 true
  let q_sr = sr.tick(true, true)
  assert_eq(q_sr, true)

  // 复位: S1=false, R=true
  let q_sr_rst = sr.tick(false, true)
  assert_eq(q_sr_rst, false)

  let rs = RsFlipFlop::new()
  // 复位优先: S=true, R1=true 时 Q 应为 false
  let q_rs = rs.tick(true, true)
  assert_eq(q_rs, false)

  // 单独置位: S=true, R1=false
  let q_rs_set = rs.tick(true, false)
  assert_eq(q_rs_set, true)
}

test "fblocks r_trig and f_trig edge detectors" {
  let rtrig = RTrig::new()
  // 低电平
  assert_eq(rtrig.tick(false), false)
  // 上升沿触发
  assert_eq(rtrig.tick(true), true)
  // 保持高电平，脉冲消失
  assert_eq(rtrig.tick(true), false)
  // 变低
  assert_eq(rtrig.tick(false), false)

  let ftrig = FTrig::new()
  // 从低变高，不触发
  assert_eq(ftrig.tick(true), false)
  // 保持高
  assert_eq(ftrig.tick(true), false)
  // 下降沿触发
  assert_eq(ftrig.tick(false), true)
  // 保持低
  assert_eq(ftrig.tick(false), false)
}

test "fblocks ctud bidirectional counter" {
  let ctud = CtudCounter::new()
  // 初始状态
  assert_eq(ctud.cv, 0)
  assert_eq(ctud.qd, true) // cv <= 0

  // 向上计数脉冲
  ctud.tick(true, false, false, false, 5)
  assert_eq(ctud.cv, 1)
  assert_eq(ctud.qd, false)

  // 向下计数脉冲
  ctud.tick(false, true, false, false, 5)
  assert_eq(ctud.cv, 0)
  assert_eq(ctud.qd, true)
}

test "fblocks tonr retentive timer" {
  let tonr = TonrTimer::new()
  // 累积计时 200ms
  tonr.tick(true, false, 500L, 200L)
  assert_eq(tonr.et, 200L)
  assert_eq(tonr.q, false)

  // 输入信号变低，但不复位 (保持 200ms)
  tonr.tick(false, false, 500L, 100L)
  assert_eq(tonr.et, 200L)
  assert_eq(tonr.q, false)

  // 再次使能，累积步进 350ms (总计 550ms >= 500ms)
  tonr.tick(true, false, 500L, 350L)
  assert_eq(tonr.et, 500L)
  assert_eq(tonr.q, true)

  // 复位
  tonr.tick(false, true, 500L, 10L)
  assert_eq(tonr.et, 0L)
  assert_eq(tonr.q, false)
}

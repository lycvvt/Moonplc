///|
/// 测试 IEC 61131-3 标准功能块
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

///|
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

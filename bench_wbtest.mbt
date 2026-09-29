///|
/// 高频扫描周期与高负载基准压力测试 (High-Frequency Scan Cycle Benchmark Suite)

///|
test "benchmark high-frequency scan cycles (50,000 cycles)" {
  let rt = PlcRuntime::new()

  // 构建带自锁和停止按钮的电机控制逻辑
  let branch1 = LadderNode::Leaf(Contact::NormallyOpen("Start_Btn"))
  let branch2 = LadderNode::Leaf(Contact::NormallyOpen("Motor_Run"))
  let parallel_start = LadderNode::Parallel([branch1, branch2])
  let stop_contact = LadderNode::Leaf(Contact::NormallyClosed("Stop_Btn"))
  let full_condition = LadderNode::Series([parallel_start, stop_contact])

  let rung = Rung::new(1, "高频压力测试梯形图", full_condition, [
    Coil::Normal("Motor_Run"),
  ])
  let ld = LadderDiagram::new("BenchLadder")
  ld.add_rung(rung)
  rt.load_program(ld.to_program())

  // 初始启动
  rt.mem.set_var("Start_Btn", PlcValue::Bool(true))
  rt.mem.set_var("Stop_Btn", PlcValue::Bool(false))
  rt.step_cycle(1L)
  assert_eq(rt.mem.get_var("Motor_Run").is_true(), true)

  // 释放启动按钮，自锁保持
  rt.mem.set_var("Start_Btn", PlcValue::Bool(false))

  // 执行 50,000 次连续扫描周期 (模拟 50 秒持续运行，步长 1ms)
  let total_cycles = 50000
  let mut i = 1
  while i < total_cycles {
    rt.step_cycle(1L)
    i = i + 1
  }

  // 验证 50,000 周期后的自锁状态与扫描统计
  assert_eq(rt.cycle_count, 50000L)
  assert_eq(rt.current_time_ms, 50000L)
  assert_eq(rt.mem.get_var("Motor_Run").is_true(), true)

  // 触发停机
  rt.mem.set_var("Stop_Btn", PlcValue::Bool(true))
  rt.step_cycle(1L)
  assert_eq(rt.cycle_count, 50001L)
  assert_eq(rt.mem.get_var("Motor_Run").is_true(), false)
}

///|
test "benchmark pid closed-loop process regulation (1,000 cycles)" {
  // 测试闭环 PID 调节器在 1,000 个采样周期下的收敛与数值稳定性
  let pid = PidController::new(2.5, 200.0, 20.0)

  let setpoint = 60.0
  let mut process_var = 15.0 // 初始温度 / 压力 15.0
  let dt_ms = 10.0 // 10ms 采样周期

  let mut cycle = 0
  while cycle < 1000 {
    let output = pid.compute(setpoint, process_var, dt_ms)
    // 简易一阶惯性滞后受控对象模型
    let plant_gain = 0.02
    process_var = process_var +
      (output * plant_gain - (process_var - 15.0) * 0.01)
    cycle = cycle + 1
  }

  // 验证闭环调节后过程量已成功逼近设定值 60.0
  let diff = if process_var > setpoint {
    process_var - setpoint
  } else {
    setpoint - process_var
  }
  assert_eq(diff < 2.0, true)
}

///|
test "benchmark ST-to-IL compiler and VM bytecode execution (10,000 cycles)" {
  let src =
    #|counter := counter + 1;
    #|IF counter >= 100 THEN
    #|  counter := 0;
    #|END_IF;
  let parser = Parser::from_source(src)
  let stmts = parser.parse_statement_list()
  let prog : Program = { name: "BenchVM", variables: [], statements: stmts, }

  let bytecode = compile_st_program(prog)

  let mem = PlcMemory::new()
  mem.set_var("counter", PlcValue::Int(0))

  let vm = PlcVm::new(mem)
  vm.load_instructions(bytecode)

  // 连续执行 10,000 个虚拟扫描周期
  let mut iter = 0
  while iter < 10000 {
    vm.reset()
    vm.run(100)
    iter = iter + 1
  }

  // 10,000 次累加并逢 100 清零，最终 counter 应在预期合理区间 [0, 99]
  let final_val = mem.get_var("counter").to_int()
  assert_eq(final_val >= 0 && final_val < 100, true)
}

///|
test "benchmark modbus rtu frame generation and crc throughput (5,000 frames)" {
  let mut frame_count = 0
  let mut valid_count = 0

  while frame_count < 5000 {
    let slave_id = frame_count % 247 + 1
    let register_val = frame_count % 65535

    let frame = encode_rtu_request(slave_id, 3, 0, register_val)
    match parse_rtu_frame(frame) {
      Some(req) =>
        if req.slave_id == slave_id && req.quantity == register_val {
          valid_count = valid_count + 1
        }
      None => ()
    }
    frame_count = frame_count + 1
  }

  assert_eq(frame_count, 5000)
  assert_eq(valid_count, 5000)
}

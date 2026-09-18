///|
/// 测试 PLC 扫描周期引擎与程序逻辑执行
test "runtime motor self-hold control cycles" {
  let rt = PlcRuntime::new()

  // 构建电机自锁梯形图并加载
  let branch1 = LadderNode::Leaf(Contact::NormallyOpen("Start_Btn"))
  let branch2 = LadderNode::Leaf(Contact::NormallyOpen("Motor_Run"))
  let parallel_start = LadderNode::Parallel([branch1, branch2])
  let stop_contact = LadderNode::Leaf(Contact::NormallyClosed("Stop_Btn"))
  let full_condition = LadderNode::Series([parallel_start, stop_contact])

  let rung = Rung::new(1, "电机自锁控制", full_condition, [
    Coil::Normal("Motor_Run"),
  ])
  let ld = LadderDiagram::new("MotorSystem")
  ld.add_rung(rung)

  let prog = ld.to_program()
  rt.load_program(prog)

  // 周期 1: 没有任何按钮按下
  rt.mem.set_var("Start_Btn", PlcValue::Bool(false))
  rt.mem.set_var("Stop_Btn", PlcValue::Bool(false))
  rt.step_cycle(10L)
  assert_eq(rt.mem.get_var("Motor_Run").is_true(), false)

  // 周期 2: 按下启动按钮
  rt.mem.set_var("Start_Btn", PlcValue::Bool(true))
  rt.step_cycle(10L)
  assert_eq(rt.mem.get_var("Motor_Run").is_true(), true)

  // 周期 3: 松开启动按钮 (自锁电路应当保持运行)
  rt.mem.set_var("Start_Btn", PlcValue::Bool(false))
  rt.step_cycle(10L)
  assert_eq(rt.mem.get_var("Motor_Run").is_true(), true)

  // 周期 4: 按下停止按钮
  rt.mem.set_var("Stop_Btn", PlcValue::Bool(true))
  rt.step_cycle(10L)
  assert_eq(rt.mem.get_var("Motor_Run").is_true(), false)

  // 周期 5: 松开停止按钮 (电机应保持停止)
  rt.mem.set_var("Stop_Btn", PlcValue::Bool(false))
  rt.step_cycle(10L)
  assert_eq(rt.mem.get_var("Motor_Run").is_true(), false)
}

///|
test "runtime st program with TON timer delay" {
  let rt = PlcRuntime::new()
  let src =
    #|PROGRAM TimerDelayTest
    #|VAR
    #|  Trigger AT %IX0.0 : BOOL := FALSE;
    #|  Lamp    AT %QX0.0 : BOOL := FALSE;
    #|  T1 : TON;
    #|END_VAR
    #|
    #|T1(IN := Trigger, PT := T#200ms);
    #|Lamp := T1.Q;
    #|END_PROGRAM
  let parser = Parser::from_source(src)
  let prog = parser.parse_program()
  rt.load_program(prog)

  // 周期 1: 未触发
  rt.step_cycle(50L)
  assert_eq(rt.mem.get_output_bool("%QX0.0"), false)

  // 触发使能，周期步进 100ms (累计 100ms < 200ms)
  rt.mem.set_input_bool("%IX0.0", true)
  rt.step_cycle(100L)
  assert_eq(rt.mem.get_output_bool("%QX0.0"), false)

  // 再次步进 150ms (累计 250ms >= 200ms)
  rt.step_cycle(150L)
  assert_eq(rt.mem.get_output_bool("%QX0.0"), true)
}

///|
test "runtime for loop summation" {
  let rt = PlcRuntime::new()
  let src =
    #|sum := 0;
    #|FOR i := 1 TO 5 DO
    #|  sum := sum + i;
    #|END_FOR;
  let parser = Parser::from_source(src)
  let stmts = parser.parse_statement_list()
  let prog : Program = { name: "SumTest", variables: [], statements: stmts, }
  rt.load_program(prog)

  rt.step_cycle(10L)
  // 1 + 2 + 3 + 4 + 5 = 15
  assert_eq(rt.mem.get_var("sum").to_int(), 15)
}

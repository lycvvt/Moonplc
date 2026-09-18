///| 测试 IL 指令表虚拟机与字节码执行

test "vm boolean accumulator operations" {
  let mem = PlcMemory::new()
  mem.set_var("Start", PlcValue::Bool(true))
  mem.set_var("SafetyOk", PlcValue::Bool(true))
  mem.set_var("EmergencyStop", PlcValue::Bool(false))

  let vm = PlcVm::new(mem)

  // IL:
  // LD Start
  // AND SafetyOk
  // ANDN EmergencyStop
  // ST Motor
  let instrs = [
    IlInstruction::with_var(IlOpcode::Ld, "Start"),
    IlInstruction::with_var(IlOpcode::And, "SafetyOk"),
    IlInstruction::with_var(IlOpcode::Andn, "EmergencyStop"),
    IlInstruction::with_var(IlOpcode::St, "Motor"),
    IlInstruction::new(IlOpcode::Halt),
  ]

  vm.load_instructions(instrs)
  vm.run(100)

  assert_eq(mem.get_var("Motor").is_true(), true)
}

test "vm arithmetic accumulator operations" {
  let mem = PlcMemory::new()
  let vm = PlcVm::new(mem)

  // (10 + 20) * 3 / 2 = 45
  let instrs = [
    IlInstruction::with_val(IlOpcode::Ld, PlcValue::Int(10)),
    IlInstruction::with_val(IlOpcode::Add, PlcValue::Int(20)),
    IlInstruction::with_val(IlOpcode::Mul, PlcValue::Int(3)),
    IlInstruction::with_val(IlOpcode::Div, PlcValue::Int(2)),
    IlInstruction::with_var(IlOpcode::St, "CalcResult"),
    IlInstruction::new(IlOpcode::Halt),
  ]

  vm.load_instructions(instrs)
  vm.run(100)

  assert_eq(mem.get_var("CalcResult").to_int(), 45)
}

test "vm conditional jump logic" {
  let mem = PlcMemory::new()
  mem.set_var("Condition", PlcValue::Bool(true))
  mem.set_var("Target", PlcValue::Int(0))

  let vm = PlcVm::new(mem)

  // LD Condition
  // JMPC 4 (跳到指令 4)
  // LD 100
  // ST Target
  // 指令 4: LD 200
  // ST Target
  // HALT
  let instrs = [
    IlInstruction::with_var(IlOpcode::Ld, "Condition"),
    IlInstruction::new(IlOpcode::Jmpc(4)),
    IlInstruction::with_val(IlOpcode::Ld, PlcValue::Int(100)),
    IlInstruction::with_var(IlOpcode::St, "Target"),
    IlInstruction::with_val(IlOpcode::Ld, PlcValue::Int(200)),
    IlInstruction::with_var(IlOpcode::St, "Target"),
    IlInstruction::new(IlOpcode::Halt),
  ]

  vm.load_instructions(instrs)
  vm.run(100)

  // 因为 Condition 为 true，直接跳转到了指令 4，写入了 200 而不是 100
  assert_eq(mem.get_var("Target").to_int(), 200)
}

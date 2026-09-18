///|
/// 测试 PLC 存储区与变量绑定
test "plc memory address write and read" {
  let mem = PlcMemory::new()

  // 写入输入位
  mem.set_input_bool("%IX0.2", true)
  let addr_i = parse_plc_address("%IX0.2").unwrap()
  assert_eq(mem.get_address_val(addr_i).is_true(), true)

  // 绑定变量到输出位
  let addr_q = parse_plc_address("%QX1.0").unwrap()
  mem.bind_variable("Pump_Motor", addr_q)
  mem.set_var("Pump_Motor", PlcValue::Bool(true))

  // 检验变量和物理输出均被设置
  assert_eq(mem.get_var("Pump_Motor").is_true(), true)
  assert_eq(mem.get_output_bool("%QX1.0"), true)

  // 写入内部整型变量
  mem.set_var("Step_Index", PlcValue::Int(42))
  assert_eq(mem.get_var("Step_Index").to_int(), 42)
}

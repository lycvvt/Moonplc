///|
/// 测试 ST 到 IL 字节码编译器与 VM 联动执行
test "compiler st assign and arithmetic to il" {
  let mem = PlcMemory::new()
  mem.set_var("InputVal", PlcValue::Int(10))

  let src =
    #|CalcOut := InputVal + 25;
  let parser = Parser::from_source(src)
  let stmts = parser.parse_statement_list()
  let prog : Program = { name: "TestProg", variables: [], statements: stmts, }

  let bytecode = compile_st_program(prog)

  let vm = PlcVm::new(mem)
  vm.load_instructions(bytecode)
  vm.run(100)

  // 10 + 25 = 35
  assert_eq(mem.get_var("CalcOut").to_int(), 35)
}

///|
test "compiler st boolean logic to il" {
  let mem = PlcMemory::new()
  mem.set_var("Start", PlcValue::Bool(true))
  mem.set_var("Safety", PlcValue::Bool(true))

  let src =
    #|MotorRun := Start AND Safety;
  let parser = Parser::from_source(src)
  let stmts = parser.parse_statement_list()
  let prog : Program = { name: "MotorLogic", variables: [], statements: stmts, }

  let bytecode = compile_st_program(prog)

  let vm = PlcVm::new(mem)
  vm.load_instructions(bytecode)
  vm.run(100)

  assert_eq(mem.get_var("MotorRun").is_true(), true)
}

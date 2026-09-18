///| 测试 Modbus 现场总线协议处理与 PLC 过程映像映射

test "modbus write and read single coil" {
  let mem = PlcMemory::new()
  let server = PlcModbusServer::new(mem, 1)

  // 1. 写线圈 0 地址 (映射 %QX0.0) 为 ON
  let req_write = ModbusRequest::new(1, ModbusFunction::WriteSingleCoil, 0, 1)
  let resp_write = server.handle_request(req_write)
  assert_eq(resp_write.is_error, false)
  assert_eq(mem.get_output_bool("%QX0.0"), true)

  // 2. 读线圈 0 地址 (FC 0x01, 数量 1)
  let req_read = ModbusRequest::new(1, ModbusFunction::ReadCoils, 0, 1)
  let resp_read = server.handle_request(req_read)
  assert_eq(resp_read.is_error, false)
  assert_eq(resp_read.data[0], 1)
}

test "modbus read discrete inputs" {
  let mem = PlcMemory::new()
  let server = PlcModbusServer::new(mem, 1)

  // 模拟外部输入点触发: %IX0.1 为 true
  mem.set_input_bool("%IX0.1", true)

  // 读离散输入 0 ~ 2 (FC 0x02, 起始地址 0, 数量 3)
  let req = ModbusRequest::new(1, ModbusFunction::ReadDiscreteInputs, 0, 3)
  let resp = server.handle_request(req)

  assert_eq(resp.is_error, false)
  assert_eq(resp.data[0], 0) // %IX0.0 为 false
  assert_eq(resp.data[1], 1) // %IX0.1 为 true
  assert_eq(resp.data[2], 0) // %IX0.2 为 false
}

test "modbus write and read holding registers" {
  let mem = PlcMemory::new()
  let server = PlcModbusServer::new(mem, 1)

  // 写保持寄存器 4 (FC 0x06, 地址 4, 数值 1234)
  let req_write = ModbusRequest::new(1, ModbusFunction::WriteSingleRegister, 4, 1234)
  let resp_write = server.handle_request(req_write)
  assert_eq(resp_write.is_error, false)

  // 读保持寄存器 4 (FC 0x03, 地址 4, 数量 1)
  let req_read = ModbusRequest::new(1, ModbusFunction::ReadHoldingRegisters, 4, 1)
  let resp_read = server.handle_request(req_read)
  assert_eq(resp_read.is_error, false)
  assert_eq(resp_read.data[0], 1234)
}

test "modbus illegal function exception" {
  let mem = PlcMemory::new()
  let server = PlcModbusServer::new(mem, 1)

  let req_bad = ModbusRequest::new(1, ModbusFunction::Unknown(99), 0, 1)
  let resp_bad = server.handle_request(req_bad)
  assert_eq(resp_bad.is_error, true)
  match resp_bad.exception_code {
    Some(ModbusException::IllegalFunction) => ()
    _ => abort("expected IllegalFunction")
  }
}

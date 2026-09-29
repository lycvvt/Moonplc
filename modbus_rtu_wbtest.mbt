///|
/// 测试 Modbus RTU 物理帧编码、解码与 CRC16 校验
test "modbus rtu crc16 standard calculation" {
  // 标准 Modbus 测例: [0x01, 0x03, 0x00, 0x00, 0x00, 0x0A]
  // 计算得到的 CRC16 值为 0xCDC5
  let test_frame = [0x01, 0x03, 0x00, 0x00, 0x00, 0x0A]
  let crc = crc16_modbus(test_frame)
  assert_eq(crc, 0xCDC5)
}

///|
test "modbus rtu encode and decode request" {
  // 编码读保持寄存器请求: 从机 1, FC 0x03, 起始地址 10, 数量 2
  let raw_bytes = encode_rtu_request(1, 3, 10, 2)
  assert_eq(raw_bytes.length(), 8) // 6 字节数据 + 2 字节 CRC

  // 解码
  let parsed = parse_rtu_frame(raw_bytes)
  match parsed {
    Some(req) => {
      assert_eq(req.slave_id, 1)
      assert_eq(req.function_code, ModbusFunction::ReadHoldingRegisters)
      assert_eq(req.address, 10)
      assert_eq(req.quantity, 2)
    }
    None => abort("expected successful RTU frame parse")
  }
}

///|
test "modbus rtu corrupted crc frame rejection" {
  let raw_bytes = encode_rtu_request(1, 3, 10, 2)
  // 篡改 CRC 校验位
  raw_bytes[7] = raw_bytes[7] ^ 0xFF

  let parsed = parse_rtu_frame(raw_bytes)
  // 校验失败应当返回 None
  match parsed {
    Some(_) => abort("expected corrupted frame rejection")
    None => ()
  }
}

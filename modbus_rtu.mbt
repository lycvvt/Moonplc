///| 工业现场总线：Modbus RTU 二进制物理帧与 CRC16 校验器

///|
/// 计算 Modbus RTU 16 位循环冗余校验码 (CRC-16/MODBUS, 多项式 0xA001)
pub fn crc16_modbus(bytes : Array[Int]) -> Int {
  let mut crc = 0xFFFF
  let mut i = 0
  while i < bytes.length() {
    let b = bytes[i] & 0xFF
    crc = crc ^ b
    let mut j = 0
    while j < 8 {
      if (crc & 0x0001) != 0 {
        crc = (crc >> 1) ^ 0xA001
      } else {
        crc = crc >> 1
      }
      j = j + 1
    }
    i = i + 1
  }
  crc & 0xFFFF
}

///|
/// 将 Modbus 请求编码为带有 CRC16 校验的 RTU 物理字节帧
pub fn encode_rtu_request(
  slave_id : Int,
  fc : Int,
  addr : Int,
  qty_or_val : Int,
) -> Array[Int] {
  let frame = [
    slave_id & 0xFF,
    fc & 0xFF,
    (addr >> 8) & 0xFF,
    addr & 0xFF,
    (qty_or_val >> 8) & 0xFF,
    qty_or_val & 0xFF,
  ]
  let crc = crc16_modbus(frame)
  frame.push(crc & 0xFF) // CRC 低位在前
  frame.push((crc >> 8) & 0xFF) // CRC 高位在后
  frame
}

///|
/// 解析 RTU 二进制数据帧 (校验长度与 CRC)
pub fn parse_rtu_frame(bytes : Array[Int]) -> ModbusRequest? {
  if bytes.length() < 4 {
    return None
  }

  // 校验 CRC
  let payload_len = bytes.length() - 2
  let payload = []
  let mut i = 0
  while i < payload_len {
    payload.push(bytes[i])
    i = i + 1
  }
  let calculated_crc = crc16_modbus(payload)
  let received_crc = (bytes[payload_len] & 0xFF) |
    ((bytes[payload_len + 1] & 0xFF) << 8)

  if calculated_crc != received_crc {
    return None
  }

  let slave_id = bytes[0]
  let fc_code = bytes[1]
  let fc = ModbusFunction::from_int(fc_code)
  let addr = ((bytes[2] & 0xFF) << 8) | (bytes[3] & 0xFF)
  let qty = if bytes.length() >= 6 {
    ((bytes[4] & 0xFF) << 8) | (bytes[5] & 0xFF)
  } else {
    0
  }

  Some({
    slave_id,
    function_code: fc,
    address: addr,
    quantity: qty,
    values: [],
  })
}

///|
/// 将 ModbusResponse 编码为带有 CRC16 的二进制 RTU 响应帧
pub fn encode_rtu_response(resp : ModbusResponse) -> Array[Int] {
  let frame = [resp.slave_id & 0xFF, resp.function_code.to_int() & 0xFF]
  if resp.is_error {
    // 异常响应: 功能码最高位置 1 (fc | 0x80)
    frame[1] = (resp.function_code.to_int() | 0x80) & 0xFF
    let ex_code = match resp.exception_code {
      Some(ModbusException::IllegalFunction) => 1
      Some(ModbusException::IllegalDataAddress) => 2
      Some(ModbusException::IllegalDataValue) => 3
      Some(ModbusException::SlaveDeviceFailure) => 4
      None => 1
    }
    frame.push(ex_code)
  } else {
    frame.push(resp.byte_count & 0xFF)
    for d in resp.data {
      frame.push((d >> 8) & 0xFF)
      frame.push(d & 0xFF)
    }
  }

  let crc = crc16_modbus(frame)
  frame.push(crc & 0xFF)
  frame.push((crc >> 8) & 0xFF)
  frame
}

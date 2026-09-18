///| 工业现场总线协议：Modbus 协议栈与 PLC 映像映射层

///| Modbus 标准功能码定义
pub(all) enum ModbusFunction {
  ReadCoils                // 0x01: 读线圈状态 (映射 %QX)
  ReadDiscreteInputs       // 0x02: 读离散输入 (映射 %IX)
  ReadHoldingRegisters     // 0x03: 读保持寄存器 (映射 %MW)
  ReadInputRegisters       // 0x04: 读输入寄存器 (映射 %IW)
  WriteSingleCoil          // 0x05: 写单个线圈
  WriteSingleRegister      // 0x06: 写单个保持寄存器
  WriteMultipleRegisters   // 0x10: 写多个保持寄存器
  Unknown(Int)
} derive(Debug, Eq)

pub fn ModbusFunction::from_int(code : Int) -> ModbusFunction {
  match code {
    1 => ModbusFunction::ReadCoils
    2 => ModbusFunction::ReadDiscreteInputs
    3 => ModbusFunction::ReadHoldingRegisters
    4 => ModbusFunction::ReadInputRegisters
    5 => ModbusFunction::WriteSingleCoil
    6 => ModbusFunction::WriteSingleRegister
    16 => ModbusFunction::WriteMultipleRegisters
    c => ModbusFunction::Unknown(c)
  }
}

pub fn ModbusFunction::to_int(self : ModbusFunction) -> Int {
  match self {
    ModbusFunction::ReadCoils => 1
    ModbusFunction::ReadDiscreteInputs => 2
    ModbusFunction::ReadHoldingRegisters => 3
    ModbusFunction::ReadInputRegisters => 4
    ModbusFunction::WriteSingleCoil => 5
    ModbusFunction::WriteSingleRegister => 6
    ModbusFunction::WriteMultipleRegisters => 16
    ModbusFunction::Unknown(c) => c
  }
}

///| Modbus 异常码 (Exception Codes)
pub(all) enum ModbusException {
  IllegalFunction     // 0x01
  IllegalDataAddress  // 0x02
  IllegalDataValue    // 0x03
  SlaveDeviceFailure  // 0x04
} derive(Debug, Eq)

///| Modbus 请求数据包 (PDU - Protocol Data Unit)
pub(all) struct ModbusRequest {
  slave_id : Int
  function_code : ModbusFunction
  address : Int
  quantity : Int
  values : Array[Int]
} derive(Debug)

pub fn ModbusRequest::new(slave_id : Int, fc : ModbusFunction, address : Int, quantity : Int) -> ModbusRequest {
  { slave_id, function_code: fc, address, quantity, values: [] }
}

///| Modbus 响应数据包
pub(all) struct ModbusResponse {
  slave_id : Int
  function_code : ModbusFunction
  is_error : Bool
  exception_code : Option[ModbusException]
  byte_count : Int
  data : Array[Int]
} derive(Debug)

///| PLC Modbus 服务端适配器
pub(all) struct PlcModbusServer {
  mem : PlcMemory
  slave_id : Int
} derive(Debug)

pub fn PlcModbusServer::new(mem : PlcMemory, slave_id : Int) -> PlcModbusServer {
  { mem, slave_id }
}

///| 处理 Modbus 请求并生成响应
pub fn PlcModbusServer::handle_request(self : PlcModbusServer, req : ModbusRequest) -> ModbusResponse {
  // 从机地址不匹配
  if req.slave_id != self.slave_id && req.slave_id != 0 {
    return {
      slave_id: req.slave_id,
      function_code: req.function_code,
      is_error: true,
      exception_code: Some(ModbusException::SlaveDeviceFailure),
      byte_count: 0,
      data: [],
    }
  }

  match req.function_code {
    // 0x01: 读线圈 (输出 %QX)
    ModbusFunction::ReadCoils => {
      let res_bits = []
      let mut i = 0
      while i < req.quantity {
        let addr_idx = req.address + i
        let byte_offset = addr_idx / 8
        let bit_offset = addr_idx % 8
        let key = "%QX\{byte_offset}.\{bit_offset}"
        let bit_val = self.mem.get_output_bool(key)
        res_bits.push(if bit_val { 1 } else { 0 })
        i = i + 1
      }
      {
        slave_id: self.slave_id,
        function_code: req.function_code,
        is_error: false,
        exception_code: None,
        byte_count: (req.quantity + 7) / 8,
        data: res_bits,
      }
    }

    // 0x02: 读离散输入 (%IX)
    ModbusFunction::ReadDiscreteInputs => {
      let res_bits = []
      let mut i = 0
      while i < req.quantity {
        let addr_idx = req.address + i
        let byte_offset = addr_idx / 8
        let bit_offset = addr_idx % 8
        let key = "%IX\{byte_offset}.\{bit_offset}"
        let addr = match parse_plc_address(key) {
          Some(a) => a
          None => { area: PlcArea::Input, size: PlcDataSize::Bit, byte_offset, bit_offset }
        }
        let bit_val = self.mem.get_address_val(addr).is_true()
        res_bits.push(if bit_val { 1 } else { 0 })
        i = i + 1
      }
      {
        slave_id: self.slave_id,
        function_code: req.function_code,
        is_error: false,
        exception_code: None,
        byte_count: (req.quantity + 7) / 8,
        data: res_bits,
      }
    }

    // 0x03: 读保持寄存器 (%MW)
    ModbusFunction::ReadHoldingRegisters => {
      let res_words = []
      let mut i = 0
      while i < req.quantity {
        let reg_addr = req.address + i
        let key = "%MW\{reg_addr}"
        let val = match self.mem.flags.get(key) {
          Some(v) => v.to_int()
          None => 0
        }
        res_words.push(val)
        i = i + 1
      }
      {
        slave_id: self.slave_id,
        function_code: req.function_code,
        is_error: false,
        exception_code: None,
        byte_count: req.quantity * 2,
        data: res_words,
      }
    }

    // 0x05: 写单个线圈
    ModbusFunction::WriteSingleCoil => {
      let byte_offset = req.address / 8
      let bit_offset = req.address % 8
      let is_on = req.quantity == 0xFF00 || req.quantity == 1
      let key = "%QX\{byte_offset}.\{bit_offset}"
      let addr = match parse_plc_address(key) {
        Some(a) => a
        None => { area: PlcArea::Output, size: PlcDataSize::Bit, byte_offset, bit_offset }
      }
      self.mem.set_address_val(addr, PlcValue::Bool(is_on))
      {
        slave_id: self.slave_id,
        function_code: req.function_code,
        is_error: false,
        exception_code: None,
        byte_count: 2,
        data: [req.address, req.quantity],
      }
    }

    // 0x06: 写单个保持寄存器
    ModbusFunction::WriteSingleRegister => {
      let key = "%MW\{req.address}"
      let addr = match parse_plc_address(key) {
        Some(a) => a
        None => { area: PlcArea::Memory, size: PlcDataSize::Word, byte_offset: req.address, bit_offset: 0 }
      }
      self.mem.set_address_val(addr, PlcValue::Int(req.quantity))
      {
        slave_id: self.slave_id,
        function_code: req.function_code,
        is_error: false,
        exception_code: None,
        byte_count: 2,
        data: [req.address, req.quantity],
      }
    }

    _ => {
      {
        slave_id: self.slave_id,
        function_code: req.function_code,
        is_error: true,
        exception_code: Some(ModbusException::IllegalFunction),
        byte_count: 0,
        data: [],
      }
    }
  }
}

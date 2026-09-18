///| PLC 工业过程映像存储区 (Process Image Memory) 与符号映射

///|
/// 格式化 PlcAddress 为紧凑键值 (如 "%IX0.1")
pub fn PlcAddress::to_key(self : PlcAddress) -> String {
  let area_str = match self.area {
    PlcArea::Input => "I"
    PlcArea::Output => "Q"
    PlcArea::Memory => "M"
  }
  let size_str = match self.size {
    PlcDataSize::Bit => "X"
    PlcDataSize::Byte => "B"
    PlcDataSize::Word => "W"
    PlcDataSize::DWord => "D"
  }
  if self.size == PlcDataSize::Bit {
    "%\{area_str}\{size_str}\{self.byte_offset}.\{self.bit_offset}"
  } else {
    "%\{area_str}\{size_str}\{self.byte_offset}"
  }
}

///|
/// PLC 存储区管理
pub(all) struct PlcMemory {
  // 物理地址映像区存储
  inputs : Map[String, PlcValue] // %I 映像
  outputs : Map[String, PlcValue] // %Q 映像
  flags : Map[String, PlcValue] // %M 内部标志映像

  // 变量名表与物理绑定
  vars : Map[String, PlcValue]
  var_bindings : Map[String, PlcAddress]
} derive(Debug)

///|
/// 创建新存储区
pub fn PlcMemory::new() -> PlcMemory {
  { inputs: {}, outputs: {}, flags: {}, vars: {}, var_bindings: {}, }
}

///|
/// 重置所有存储区为初始 0 / FALSE
pub fn PlcMemory::reset(self : PlcMemory) -> Unit {
  self.inputs.clear()
  self.outputs.clear()
  self.flags.clear()
  self.vars.clear()
}

///|
/// 绑定变量名到物理地址
pub fn PlcMemory::bind_variable(
  self : PlcMemory,
  name : String,
  addr : PlcAddress,
) -> Unit {
  self.var_bindings[name] = addr
}

///|
/// 设置物理直接地址的值
pub fn PlcMemory::set_address_val(
  self : PlcMemory,
  addr : PlcAddress,
  val : PlcValue,
) -> Unit {
  let key = addr.to_key()
  match addr.area {
    PlcArea::Input => self.inputs[key] = val
    PlcArea::Output => self.outputs[key] = val
    PlcArea::Memory => self.flags[key] = val
  }
}

///|
/// 获取物理直接地址的值
pub fn PlcMemory::get_address_val(
  self : PlcMemory,
  addr : PlcAddress,
) -> PlcValue {
  let key = addr.to_key()
  match addr.area {
    PlcArea::Input => self.inputs.get(key).unwrap_or(PlcValue::Bool(false))
    PlcArea::Output => self.outputs.get(key).unwrap_or(PlcValue::Bool(false))
    PlcArea::Memory => self.flags.get(key).unwrap_or(PlcValue::Int(0))
  }
}

///|
/// 设置变量值 (若绑定了物理地址，自动同步写入物理映像区)
pub fn PlcMemory::set_var(
  self : PlcMemory,
  name : String,
  val : PlcValue,
) -> Unit {
  self.vars[name] = val
  match self.var_bindings.get(name) {
    Some(addr) => self.set_address_val(addr, val)
    None => ()
  }
}

///|
/// 获取变量值 (若绑定了物理地址，优先从物理映像区读取)
pub fn PlcMemory::get_var(self : PlcMemory, name : String) -> PlcValue {
  match self.var_bindings.get(name) {
    Some(addr) => self.get_address_val(addr)
    None => self.vars.get(name).unwrap_or(PlcValue::Null)
  }
}

///|
/// 外部输入写入便捷方法 (模拟硬件传感器或外设触发)
pub fn PlcMemory::set_input_bool(
  self : PlcMemory,
  addr_str : String,
  val : Bool,
) -> Unit {
  match parse_plc_address(addr_str) {
    Some(addr) => self.set_address_val(addr, PlcValue::Bool(val))
    None => ()
  }
}

///|
/// 外部输出读取便捷方法 (驱动虚拟执行机构或仿真 UI)
pub fn PlcMemory::get_output_bool(self : PlcMemory, addr_str : String) -> Bool {
  match parse_plc_address(addr_str) {
    Some(addr) => self.get_address_val(addr).is_true()
    None => false
  }
}

///|
/// 打印当前 I/O 状态汇总
pub fn PlcMemory::dump_io(self : PlcMemory) -> String {
  let mut s = "--- PLC I/O Process Image ---\n"
  s = s + "[Inputs %I]:\n"
  for k, v in self.inputs {
    s = s + "  \{k} = \{v.to_string_repr()}\n"
  }
  s = s + "[Outputs %Q]:\n"
  for k, v in self.outputs {
    s = s + "  \{k} = \{v.to_string_repr()}\n"
  }
  s = s + "[Variables]:\n"
  for k, v in self.vars {
    s = s + "  \{k} = \{v.to_string_repr()}\n"
  }
  s
}

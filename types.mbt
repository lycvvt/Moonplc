///| IEC 61131-3 基础数据类型与 PLC 值表示

///|
pub(all) enum PlcValue {
  Bool(Bool)
  Int(Int)
  Real(Double)
  Time(Int64) // 毫秒数 (ms)
  String(String)
  Null
} derive(Debug)

///|
pub fn PlcValue::is_true(self : PlcValue) -> Bool {
  match self {
    PlcValue::Bool(b) => b
    PlcValue::Int(i) => i != 0
    PlcValue::Real(r) => r != 0.0
    PlcValue::Time(t) => t > 0L
    _ => false
  }
}

///|
pub fn PlcValue::to_int(self : PlcValue) -> Int {
  match self {
    PlcValue::Bool(b) => if b { 1 } else { 0 }
    PlcValue::Int(i) => i
    PlcValue::Real(r) => r.to_int()
    PlcValue::Time(t) => t.to_int()
    _ => 0
  }
}

///|
pub fn PlcValue::to_double(self : PlcValue) -> Double {
  match self {
    PlcValue::Bool(b) => if b { 1.0 } else { 0.0 }
    PlcValue::Int(i) => i.to_double()
    PlcValue::Real(r) => r
    PlcValue::Time(t) => t.to_double()
    _ => 0.0
  }
}

///|
pub fn PlcValue::to_string_repr(self : PlcValue) -> String {
  match self {
    PlcValue::Bool(b) => if b { "TRUE" } else { "FALSE" }
    PlcValue::Int(i) => i.to_string()
    PlcValue::Real(r) => r.to_string()
    PlcValue::Time(t) => "T#\{t}ms"
    PlcValue::String(s) => s
    PlcValue::Null => "NULL"
  }
}

///|
/// 比较相等性
pub fn PlcValue::eq(self : PlcValue, other : PlcValue) -> Bool {
  match (self, other) {
    (PlcValue::Bool(a), PlcValue::Bool(b)) => a == b
    (PlcValue::Int(a), PlcValue::Int(b)) => a == b
    (PlcValue::Real(a), PlcValue::Real(b)) => a == b
    (PlcValue::Time(a), PlcValue::Time(b)) => a == b
    (PlcValue::String(a), PlcValue::String(b)) => a == b
    (PlcValue::Null, PlcValue::Null) => true
    _ => false
  }
}

///|
/// 比较大小 (<)
pub fn PlcValue::lt(self : PlcValue, other : PlcValue) -> Bool {
  match (self, other) {
    (PlcValue::Int(a), PlcValue::Int(b)) => a < b
    (PlcValue::Real(a), PlcValue::Real(b)) => a < b
    (PlcValue::Time(a), PlcValue::Time(b)) => a < b
    _ => false
  }
}

///|
/// 比较大小 (<=)
pub fn PlcValue::lte(self : PlcValue, other : PlcValue) -> Bool {
  self.eq(other) || self.lt(other)
}

///|
/// 加法运算
pub fn PlcValue::add(self : PlcValue, other : PlcValue) -> PlcValue {
  match (self, other) {
    (PlcValue::Int(a), PlcValue::Int(b)) => PlcValue::Int(a + b)
    (PlcValue::Real(a), PlcValue::Real(b)) => PlcValue::Real(a + b)
    (PlcValue::Time(a), PlcValue::Time(b)) => PlcValue::Time(a + b)
    (PlcValue::String(a), PlcValue::String(b)) => PlcValue::String(a + b)
    _ => PlcValue::Null
  }
}

///|
/// 减法运算
pub fn PlcValue::sub(self : PlcValue, other : PlcValue) -> PlcValue {
  match (self, other) {
    (PlcValue::Int(a), PlcValue::Int(b)) => PlcValue::Int(a - b)
    (PlcValue::Real(a), PlcValue::Real(b)) => PlcValue::Real(a - b)
    (PlcValue::Time(a), PlcValue::Time(b)) => PlcValue::Time(a - b)
    _ => PlcValue::Null
  }
}

///|
/// 乘法运算
pub fn PlcValue::mul(self : PlcValue, other : PlcValue) -> PlcValue {
  match (self, other) {
    (PlcValue::Int(a), PlcValue::Int(b)) => PlcValue::Int(a * b)
    (PlcValue::Real(a), PlcValue::Real(b)) => PlcValue::Real(a * b)
    _ => PlcValue::Null
  }
}

///|
/// 除法运算
pub fn PlcValue::div(self : PlcValue, other : PlcValue) -> PlcValue {
  match (self, other) {
    (PlcValue::Int(a), PlcValue::Int(b)) =>
      if b == 0 {
        PlcValue::Null
      } else {
        PlcValue::Int(a / b)
      }
    (PlcValue::Real(a), PlcValue::Real(b)) =>
      if b == 0.0 {
        PlcValue::Null
      } else {
        PlcValue::Real(a / b)
      }
    _ => PlcValue::Null
  }
}

///|
/// 取模运算
pub fn PlcValue::modulo(self : PlcValue, other : PlcValue) -> PlcValue {
  match (self, other) {
    (PlcValue::Int(a), PlcValue::Int(b)) =>
      if b == 0 {
        PlcValue::Null
      } else {
        PlcValue::Int(a % b)
      }
    _ => PlcValue::Null
  }
}

///|
/// PLC 物理/逻辑存储区
pub(all) enum PlcArea {
  Input // %I 输入映像区
  Output // %Q 输出映像区
  Memory // %M 内部标志寄存器区
} derive(Debug, Eq)

///|
/// 寻址大小
pub(all) enum PlcDataSize {
  Bit // X (1 bit)
  Byte // B (8 bits)
  Word // W (16 bits)
  DWord // D (32 bits)
} derive(Debug, Eq)

///|
/// PLC 统一地址定义 (例如 %IX0.0, %QX1.2, %MW10)
pub(all) struct PlcAddress {
  area : PlcArea
  size : PlcDataSize
  byte_offset : Int
  bit_offset : Int
} derive(Debug, Eq)

///|
/// 纯 MoonBit 实现的轻量非负整数解析
pub fn parse_uint_simple(s : String) -> Int {
  let mut res = 0
  let mut i = 0
  while i < s.length() {
    let c = s[i]
    if c >= '0' && c <= '9' {
      let digit = c.to_int() - '0'.to_int()
      res = res * 10 + digit
    }
    i = i + 1
  }
  res
}

///|
/// 将 IEC 61131-3 地址字符串 (如 "%IX0.1", "%QX0.0", "%MW10") 解析为 PlcAddress
pub fn parse_plc_address(addr : String) -> PlcAddress? {
  if !addr.has_prefix("%") || addr.length() < 3 {
    return None
  }
  let area = match addr[1] {
    'I' | 'i' => PlcArea::Input
    'Q' | 'q' => PlcArea::Output
    'M' | 'm' => PlcArea::Memory
    _ => return None
  }
  let mut idx = 2
  let size = match addr[idx] {
    'X' | 'x' => {
      idx = idx + 1
      PlcDataSize::Bit
    }
    'B' | 'b' => {
      idx = idx + 1
      PlcDataSize::Byte
    }
    'W' | 'w' => {
      idx = idx + 1
      PlcDataSize::Word
    }
    'D' | 'd' => {
      idx = idx + 1
      PlcDataSize::DWord
    }
    _ => PlcDataSize::Bit // 默认位寻址
  }

  // 提取数字偏移 byte.bit
  let rem = addr[idx:].to_owned()
  let mut dot_pos = -1
  let mut i = 0
  while i < rem.length() {
    if rem[i] == '.' {
      dot_pos = i
      break
    }
    i = i + 1
  }

  if dot_pos >= 0 {
    let byte_str = rem[0:dot_pos].to_owned()
    let bit_str = rem[dot_pos + 1:].to_owned()
    let byte_val = parse_uint_simple(byte_str)
    let bit_val = parse_uint_simple(bit_str)
    Some({ area, size, byte_offset: byte_val, bit_offset: bit_val, })
  } else {
    let byte_val = parse_uint_simple(rem)
    Some({ area, size, byte_offset: byte_val, bit_offset: 0, })
  }
}

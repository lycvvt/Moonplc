///| MoonPLC 统一对外核心接口 (Facade API)

///|
/// 微型软 PLC 控制器实例
pub(all) struct MoonPlc {
  runtime : PlcRuntime
  name : String
} derive(Debug)

///|
/// 创建新 PLC 实例
pub fn MoonPlc::new(name : String) -> MoonPlc {
  { runtime: PlcRuntime::new(), name, }
}

///|
/// 从 IEC 61131-3 结构化文本 (ST) 源代码加载程序
pub fn MoonPlc::load_st(self : MoonPlc, source : String) -> Unit {
  let parser = Parser::from_source(source)
  let prog = parser.parse_program()
  self.runtime.load_program(prog)
}

///|
/// 从梯形图 (LD) 对象加载程序
pub fn MoonPlc::load_ladder(self : MoonPlc, ld : LadderDiagram) -> Unit {
  let prog = ld.to_program()
  self.runtime.load_program(prog)
}

///|
/// 设置物理数字输入点 (例如 "%IX0.0", true)
pub fn MoonPlc::set_input_bool(
  self : MoonPlc,
  addr : String,
  val : Bool,
) -> Unit {
  self.runtime.mem.set_input_bool(addr, val)
}

///|
/// 读取物理数字输出点 (例如 "%QX0.0")
pub fn MoonPlc::get_output_bool(self : MoonPlc, addr : String) -> Bool {
  self.runtime.mem.get_output_bool(addr)
}

///|
/// 设置内部或命名变量
pub fn MoonPlc::set_var(self : MoonPlc, name : String, val : PlcValue) -> Unit {
  self.runtime.mem.set_var(name, val)
}

///|
/// 读取内部或命名变量
pub fn MoonPlc::get_var(self : MoonPlc, name : String) -> PlcValue {
  self.runtime.mem.get_var(name)
}

///|
/// 执行单个扫描周期 (毫秒步进)
pub fn MoonPlc::cycle(self : MoonPlc, delta_ms : Int64) -> Unit {
  self.runtime.step_cycle(delta_ms)
}

///|
/// 批量运行多个扫描周期
pub fn MoonPlc::run_cycles(
  self : MoonPlc,
  count : Int,
  delta_ms : Int64,
) -> Unit {
  let mut i = 0
  while i < count {
    self.cycle(delta_ms)
    i = i + 1
  }
}

///|
/// 获取当前累计周期数
pub fn MoonPlc::cycle_count(self : MoonPlc) -> Int64 {
  self.runtime.cycle_count
}

///|
/// 获取仿真当前时间 (ms)
pub fn MoonPlc::current_time_ms(self : MoonPlc) -> Int64 {
  self.runtime.current_time_ms
}

///|
/// 打印控制器当前状态与 I/O 摘要
pub fn MoonPlc::dump_status(self : MoonPlc) -> String {
  let mut s = "========================================\n"
  s = s + "  MoonPLC Controller [\{self.name}]\n"
  s = s +
    "  Cycles: \{self.cycle_count()} | Time: \{self.current_time_ms()} ms\n"
  s = s + "========================================\n"
  s = s + self.runtime.mem.dump_io()
  s
}

///|
/// 版本信息
pub fn version() -> String {
  "0.1.0"
}

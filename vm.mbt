///| IEC 61131-3 指令表 (Instruction List, IL) 虚拟机与字节码执行引擎

///| IL 指令操作码定义
pub(all) enum IlOpcode {
  Ld       // 加载到累加器
  Ldn      // 取反后加载到累加器
  St       // 累加器保存至变量
  And      // 逻辑与
  Andn     // 逻辑与非
  Or       // 逻辑或
  Orn      // 逻辑或非
  Xor      // 逻辑异或
  Add      // 算术加
  Sub      // 算术减
  Mul      // 算术乘
  Div      // 算术除
  Eq       // 等于比较
  Ne       // 不等于比较
  Gt       // 大于比较
  Lt       // 小于比较
  Jmp(Int) // 无条件跳转到指令索引
  Jmpc(Int)// 条件跳转 (累加器为 TRUE 时)
  Halt     // 停机
} derive(Debug, Eq)

///| 单条 IL 虚拟机指令
pub(all) struct IlInstruction {
  opcode : IlOpcode
  operand_val : Option[PlcValue]
  operand_var : Option[String]
} derive(Debug)

pub fn IlInstruction::new(op : IlOpcode) -> IlInstruction {
  { opcode: op, operand_val: None, operand_var: None }
}

pub fn IlInstruction::with_val(op : IlOpcode, val : PlcValue) -> IlInstruction {
  { opcode: op, operand_val: Some(val), operand_var: None }
}

pub fn IlInstruction::with_var(op : IlOpcode, var_name : String) -> IlInstruction {
  { opcode: op, operand_val: None, operand_var: Some(var_name) }
}

///| 虚拟机状态
pub(all) struct PlcVm {
  mut instructions : Array[IlInstruction]
  mem : PlcMemory
  mut pc : Int
  mut acc : PlcValue // Current Result (CR) 累加器
  mut halted : Bool
} derive(Debug)

pub fn PlcVm::new(mem : PlcMemory) -> PlcVm {
  {
    instructions: [],
    mem,
    pc: 0,
    acc: PlcValue::Bool(false),
    halted: false,
  }
}

pub fn PlcVm::load_instructions(self : PlcVm, instrs : Array[IlInstruction]) -> Unit {
  self.instructions = instrs
  self.pc = 0
  self.halted = false
}

///| 获取操作数的值 (字面量或从内存读取)
fn PlcVm::fetch_operand(self : PlcVm, inst : IlInstruction) -> PlcValue {
  match inst.operand_val {
    Some(v) => v
    None => {
      match inst.operand_var {
        Some(name) => self.mem.get_var(name)
        None => PlcValue::Null
      }
    }
  }
}

///| 单步执行一条指令
pub fn PlcVm::step(self : PlcVm) -> Bool {
  if self.halted || self.pc < 0 || self.pc >= self.instructions.length() {
    self.halted = true
    return false
  }

  let inst = self.instructions[self.pc]
  self.pc = self.pc + 1

  match inst.opcode {
    IlOpcode::Ld => {
      self.acc = self.fetch_operand(inst)
    }
    IlOpcode::Ldn => {
      let v = self.fetch_operand(inst)
      self.acc = PlcValue::Bool(!v.is_true())
    }
    IlOpcode::St => {
      match inst.operand_var {
        Some(name) => self.mem.set_var(name, self.acc)
        None => ()
      }
    }
    IlOpcode::And => {
      let v = self.fetch_operand(inst)
      self.acc = PlcValue::Bool(self.acc.is_true() && v.is_true())
    }
    IlOpcode::Andn => {
      let v = self.fetch_operand(inst)
      self.acc = PlcValue::Bool(self.acc.is_true() && !v.is_true())
    }
    IlOpcode::Or => {
      let v = self.fetch_operand(inst)
      self.acc = PlcValue::Bool(self.acc.is_true() || v.is_true())
    }
    IlOpcode::Orn => {
      let v = self.fetch_operand(inst)
      self.acc = PlcValue::Bool(self.acc.is_true() || !v.is_true())
    }
    IlOpcode::Xor => {
      let v = self.fetch_operand(inst)
      self.acc = PlcValue::Bool(self.acc.is_true() != v.is_true())
    }
    IlOpcode::Add => {
      let v = self.fetch_operand(inst)
      self.acc = self.acc.add(v)
    }
    IlOpcode::Sub => {
      let v = self.fetch_operand(inst)
      self.acc = self.acc.sub(v)
    }
    IlOpcode::Mul => {
      let v = self.fetch_operand(inst)
      self.acc = self.acc.mul(v)
    }
    IlOpcode::Div => {
      let v = self.fetch_operand(inst)
      self.acc = self.acc.div(v)
    }
    IlOpcode::Eq => {
      let v = self.fetch_operand(inst)
      self.acc = PlcValue::Bool(self.acc.eq(v))
    }
    IlOpcode::Ne => {
      let v = self.fetch_operand(inst)
      self.acc = PlcValue::Bool(!self.acc.eq(v))
    }
    IlOpcode::Gt => {
      let v = self.fetch_operand(inst)
      self.acc = PlcValue::Bool(!self.acc.lte(v))
    }
    IlOpcode::Lt => {
      let v = self.fetch_operand(inst)
      self.acc = PlcValue::Bool(self.acc.lt(v))
    }
    IlOpcode::Jmp(target) => {
      self.pc = target
    }
    IlOpcode::Jmpc(target) => {
      if self.acc.is_true() {
        self.pc = target
      }
    }
    IlOpcode::Halt => {
      self.halted = true
      return false
    }
  }

  true
}

///| 连续执行指令序列直到停机或达到最大周期指令上限
pub fn PlcVm::run(self : PlcVm, max_steps : Int) -> Unit {
  let mut steps = 0
  while !self.halted && steps < max_steps {
    let continued = self.step()
    if !continued {
      break
    }
    steps = steps + 1
  }
}

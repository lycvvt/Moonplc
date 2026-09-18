///| PLC 运行时执行引擎与扫描周期调度器 (Scan Cycle Scheduler)

///| 运行时执行环境
pub(all) struct PlcRuntime {
  mem : PlcMemory
  fb_instances : Map[String, FbInstance]
  mut program : Option[Program]

  // 扫描周期状态统计
  mut cycle_count : Int64
  mut current_time_ms : Int64
  mut scan_time_us : Int64
  mut watchdog_ms : Int64
  mut is_running : Bool
} derive(Debug)

///| 创建 PLC 运行时
pub fn PlcRuntime::new() -> PlcRuntime {
  {
    mem: PlcMemory::new(),
    fb_instances: {},
    program: None,
    cycle_count: 0L,
    current_time_ms: 0L,
    scan_time_us: 0L,
    watchdog_ms: 500L, // 默认 500ms 看门狗超时上限
    is_running: true,
  }
}

///| 加载程序 (POU) 并初始化变量
pub fn PlcRuntime::load_program(self : PlcRuntime, prog : Program) -> Unit {
  self.program = Some(prog)

  // 初始化变量声明
  for v in prog.variables {
    match v.located_at {
      Some(addr) => self.mem.bind_variable(v.name, addr)
      None => ()
    }

    match v.init_val {
      Some(val) => self.mem.set_var(v.name, val)
      None => {
        // 默认零值
        if v.var_type == "BOOL" {
          self.mem.set_var(v.name, PlcValue::Bool(false))
        } else if v.var_type == "INT" {
          self.mem.set_var(v.name, PlcValue::Int(0))
        } else if v.var_type == "REAL" {
          self.mem.set_var(v.name, PlcValue::Real(0.0))
        } else if v.var_type == "TIME" {
          self.mem.set_var(v.name, PlcValue::Time(0L))
        } else if v.var_type == "TON" {
          self.fb_instances[v.name] = FbInstance::Ton(TonTimer::new())
        } else if v.var_type == "TOF" {
          self.fb_instances[v.name] = FbInstance::Tof(TofTimer::new())
        } else if v.var_type == "TP" {
          self.fb_instances[v.name] = FbInstance::Tp(TpTimer::new())
        } else if v.var_type == "TONR" {
          self.fb_instances[v.name] = FbInstance::Tonr(TonrTimer::new())
        } else if v.var_type == "CTU" {
          self.fb_instances[v.name] = FbInstance::Ctu(CtuCounter::new())
        } else if v.var_type == "CTUD" {
          self.fb_instances[v.name] = FbInstance::Ctud(CtudCounter::new())
        } else if v.var_type == "SR" {
          self.fb_instances[v.name] = FbInstance::Sr(SrFlipFlop::new())
        } else if v.var_type == "RS" {
          self.fb_instances[v.name] = FbInstance::Rs(RsFlipFlop::new())
        } else if v.var_type == "R_TRIG" {
          self.fb_instances[v.name] = FbInstance::Rtrig(RTrig::new())
        } else if v.var_type == "F_TRIG" {
          self.fb_instances[v.name] = FbInstance::Ftrig(FTrig::new())
        }
      }
    }
  }
}

// ------------------- 表达式求值器 -------------------

///| 计算表达式的值
pub fn PlcRuntime::eval_expr(self : PlcRuntime, expr : Expr) -> PlcValue {
  match expr {
    Expr::Literal(v) => v
    Expr::Variable(name) => self.mem.get_var(name)
    Expr::DirectAddress(addr) => self.mem.get_address_val(addr)
    Expr::FieldAccess(inst_name, field) => {
      match self.fb_instances.get(inst_name) {
        Some(fb) => fb.get_field(field)
        None => self.mem.get_var("\{inst_name}.\{field}")
      }
    }
    Expr::Unary(op, sub_expr) => {
      let v = self.eval_expr(sub_expr)
      match op {
        UnaryOp::Not => PlcValue::Bool(!v.is_true())
        UnaryOp::Neg => {
          match v {
            PlcValue::Int(i) => PlcValue::Int(-i)
            PlcValue::Real(r) => PlcValue::Real(-r)
            _ => PlcValue::Null
          }
        }
      }
    }
    Expr::Binary(left, op, right) => {
      let lv = self.eval_expr(left)
      if op == BinaryOp::And && !lv.is_true() {
        return PlcValue::Bool(false)
      }
      if op == BinaryOp::Or && lv.is_true() {
        return PlcValue::Bool(true)
      }

      let rv = self.eval_expr(right)
      match op {
        BinaryOp::Add => lv.add(rv)
        BinaryOp::Sub => lv.sub(rv)
        BinaryOp::Mul => lv.mul(rv)
        BinaryOp::Div => lv.div(rv)
        BinaryOp::Mod => lv.modulo(rv)
        BinaryOp::Eq => PlcValue::Bool(lv.eq(rv))
        BinaryOp::Neq => PlcValue::Bool(!lv.eq(rv))
        BinaryOp::Lt => PlcValue::Bool(lv.lt(rv))
        BinaryOp::Lte => PlcValue::Bool(lv.lte(rv))
        BinaryOp::Gt => PlcValue::Bool(!lv.lte(rv))
        BinaryOp::Gte => PlcValue::Bool(!lv.lt(rv))
        BinaryOp::And => PlcValue::Bool(lv.is_true() && rv.is_true())
        BinaryOp::Or => PlcValue::Bool(lv.is_true() || rv.is_true())
        BinaryOp::Xor => PlcValue::Bool(lv.is_true() != rv.is_true())
      }
    }
  }
}

// ------------------- 语句执行器 -------------------

///| 执行单个语句
pub fn PlcRuntime::execute_statement(self : PlcRuntime, stmt : Stmt, delta_ms : Int64) -> Unit {
  match stmt {
    Stmt::Assign(var_name, expr) => {
      let val = self.eval_expr(expr)
      self.mem.set_var(var_name, val)
    }
    Stmt::AssignAddress(addr, expr) => {
      let val = self.eval_expr(expr)
      self.mem.set_address_val(addr, val)
    }
    Stmt::AssignField(inst_name, field, expr) => {
      let val = self.eval_expr(expr)
      self.mem.set_var("\{inst_name}.\{field}", val)
    }
    Stmt::If(cond, then_stmts, elsifs, else_stmts) => {
      if self.eval_expr(cond).is_true() {
        self.execute_statement_list(then_stmts, delta_ms)
        return
      }
      for pair in elsifs {
        let (e_cond, e_stmts) = pair
        if self.eval_expr(e_cond).is_true() {
          self.execute_statement_list(e_stmts, delta_ms)
          return
        }
      }
      self.execute_statement_list(else_stmts, delta_ms)
    }
    Stmt::While(cond, body) => {
      let mut loops = 0
      while self.eval_expr(cond).is_true() && loops < 10000 {
        self.execute_statement_list(body, delta_ms)
        loops = loops + 1
      }
    }
    Stmt::For(var_name, start_expr, end_expr, step_expr, body) => {
      let start_v = self.eval_expr(start_expr).to_int()
      let end_v = self.eval_expr(end_expr).to_int()
      let step_v = match step_expr {
        Some(s) => self.eval_expr(s).to_int()
        None => 1
      }
      let mut cur = start_v
      let mut loops = 0
      while cur <= end_v && loops < 10000 {
        self.mem.set_var(var_name, PlcValue::Int(cur))
        self.execute_statement_list(body, delta_ms)
        cur = cur + step_v
        loops = loops + 1
      }
    }
    Stmt::FbCall(inst_name, _, args) => {
      if !self.fb_instances.contains(inst_name) {
        self.fb_instances[inst_name] = FbInstance::Ton(TonTimer::new())
      }

      match self.fb_instances.get(inst_name) {
        Some(fb) => {
          match fb {
            FbInstance::Ton(ton) => {
              let mut in_val = false
              let mut pt_val = 0L
              for pair in args {
                let (k, expr) = pair
                if k == "IN" || k == "in" {
                  in_val = self.eval_expr(expr).is_true()
                } else if k == "PT" || k == "pt" {
                  match self.eval_expr(expr) {
                    PlcValue::Time(t) => pt_val = t
                    PlcValue::Int(i) => pt_val = i.to_int64()
                    _ => ()
                  }
                }
              }
              ton.tick(in_val, pt_val, delta_ms)
              self.mem.set_var("\{inst_name}.Q", PlcValue::Bool(ton.q))
              self.mem.set_var("\{inst_name}.ET", PlcValue::Time(ton.et))
            }
            FbInstance::Tof(tof) => {
              let mut in_val = false
              let mut pt_val = 0L
              for pair in args {
                let (k, expr) = pair
                if k == "IN" || k == "in" {
                  in_val = self.eval_expr(expr).is_true()
                } else if k == "PT" || k == "pt" {
                  match self.eval_expr(expr) {
                    PlcValue::Time(t) => pt_val = t
                    PlcValue::Int(i) => pt_val = i.to_int64()
                    _ => ()
                  }
                }
              }
              tof.tick(in_val, pt_val, delta_ms)
              self.mem.set_var("\{inst_name}.Q", PlcValue::Bool(tof.q))
              self.mem.set_var("\{inst_name}.ET", PlcValue::Time(tof.et))
            }
            FbInstance::Tp(tp) => {
              let mut in_val = false
              let mut pt_val = 0L
              for pair in args {
                let (k, expr) = pair
                if k == "IN" || k == "in" {
                  in_val = self.eval_expr(expr).is_true()
                } else if k == "PT" || k == "pt" {
                  match self.eval_expr(expr) {
                    PlcValue::Time(t) => pt_val = t
                    PlcValue::Int(i) => pt_val = i.to_int64()
                    _ => ()
                  }
                }
              }
              tp.tick(in_val, pt_val, delta_ms)
              self.mem.set_var("\{inst_name}.Q", PlcValue::Bool(tp.q))
              self.mem.set_var("\{inst_name}.ET", PlcValue::Time(tp.et))
            }
            FbInstance::Tonr(tonr) => {
              let mut in_val = false
              let mut reset_val = false
              let mut pt_val = 0L
              for pair in args {
                let (k, expr) = pair
                if k == "IN" || k == "in" {
                  in_val = self.eval_expr(expr).is_true()
                } else if k == "RESET" || k == "reset" || k == "R" || k == "r" {
                  reset_val = self.eval_expr(expr).is_true()
                } else if k == "PT" || k == "pt" {
                  match self.eval_expr(expr) {
                    PlcValue::Time(t) => pt_val = t
                    PlcValue::Int(i) => pt_val = i.to_int64()
                    _ => ()
                  }
                }
              }
              tonr.tick(in_val, reset_val, pt_val, delta_ms)
              self.mem.set_var("\{inst_name}.Q", PlcValue::Bool(tonr.q))
              self.mem.set_var("\{inst_name}.ET", PlcValue::Time(tonr.et))
            }
            FbInstance::Ctu(ctu) => {
              let mut cu_val = false
              let mut r_val = false
              let mut pv_val = 0
              for pair in args {
                let (k, expr) = pair
                if k == "CU" || k == "cu" {
                  cu_val = self.eval_expr(expr).is_true()
                } else if k == "R" || k == "r" {
                  r_val = self.eval_expr(expr).is_true()
                } else if k == "PV" || k == "pv" {
                  pv_val = self.eval_expr(expr).to_int()
                }
              }
              ctu.tick(cu_val, r_val, pv_val)
              self.mem.set_var("\{inst_name}.Q", PlcValue::Bool(ctu.q))
              self.mem.set_var("\{inst_name}.CV", PlcValue::Int(ctu.cv))
            }
            FbInstance::Ctud(ctud) => {
              let mut cu_val = false
              let mut cd_val = false
              let mut r_val = false
              let mut ld_val = false
              let mut pv_val = 0
              for pair in args {
                let (k, expr) = pair
                if k == "CU" || k == "cu" { cu_val = self.eval_expr(expr).is_true() }
                else if k == "CD" || k == "cd" { cd_val = self.eval_expr(expr).is_true() }
                else if k == "R" || k == "r" { r_val = self.eval_expr(expr).is_true() }
                else if k == "LD" || k == "ld" { ld_val = self.eval_expr(expr).is_true() }
                else if k == "PV" || k == "pv" { pv_val = self.eval_expr(expr).to_int() }
              }
              ctud.tick(cu_val, cd_val, r_val, ld_val, pv_val)
              self.mem.set_var("\{inst_name}.QU", PlcValue::Bool(ctud.qu))
              self.mem.set_var("\{inst_name}.QD", PlcValue::Bool(ctud.qd))
              self.mem.set_var("\{inst_name}.CV", PlcValue::Int(ctud.cv))
            }
            FbInstance::Sr(sr) => {
              let mut s1 = false
              let mut r = false
              for pair in args {
                let (k, expr) = pair
                if k == "S1" || k == "s1" || k == "S" || k == "s" { s1 = self.eval_expr(expr).is_true() }
                else if k == "R" || k == "r" { r = self.eval_expr(expr).is_true() }
              }
              let q = sr.tick(s1, r)
              self.mem.set_var("\{inst_name}.Q1", PlcValue::Bool(q))
              self.mem.set_var("\{inst_name}.Q", PlcValue::Bool(q))
            }
            FbInstance::Rs(rs) => {
              let mut s = false
              let mut r1 = false
              for pair in args {
                let (k, expr) = pair
                if k == "S" || k == "s" { s = self.eval_expr(expr).is_true() }
                else if k == "R1" || k == "r1" || k == "R" || k == "r" { r1 = self.eval_expr(expr).is_true() }
              }
              let q = rs.tick(s, r1)
              self.mem.set_var("\{inst_name}.Q1", PlcValue::Bool(q))
              self.mem.set_var("\{inst_name}.Q", PlcValue::Bool(q))
            }
            FbInstance::Rtrig(rtrig) => {
              let mut clk = false
              for pair in args {
                let (k, expr) = pair
                if k == "CLK" || k == "clk" { clk = self.eval_expr(expr).is_true() }
              }
              let q = rtrig.tick(clk)
              self.mem.set_var("\{inst_name}.Q", PlcValue::Bool(q))
            }
            FbInstance::Ftrig(ftrig) => {
              let mut clk = false
              for pair in args {
                let (k, expr) = pair
                if k == "CLK" || k == "clk" { clk = self.eval_expr(expr).is_true() }
              }
              let q = ftrig.tick(clk)
              self.mem.set_var("\{inst_name}.Q", PlcValue::Bool(q))
            }
          }
        }
        None => ()
      }
    }
    Stmt::Empty => ()
  }
}

///| 执行语句序列
pub fn PlcRuntime::execute_statement_list(self : PlcRuntime, stmts : Array[Stmt], delta_ms : Int64) -> Unit {
  for s in stmts {
    self.execute_statement(s, delta_ms)
  }
}

// ------------------- 扫描周期调度器 -------------------

///| 执行一个完整的扫描周期 (Scan Cycle)
pub fn PlcRuntime::step_cycle(self : PlcRuntime, delta_ms : Int64) -> Unit {
  if !self.is_running {
    return
  }

  // 阶段 1: 输入采样已在周期前写入内存

  // 阶段 2: 程序执行
  match self.program {
    Some(prog) => self.execute_statement_list(prog.statements, delta_ms)
    None => ()
  }

  // 阶段 3: 输出刷新已同步至 memory.outputs

  // 周期计时推进
  self.cycle_count = self.cycle_count + 1L
  self.current_time_ms = self.current_time_ms + delta_ms
}

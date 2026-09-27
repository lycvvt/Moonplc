///| IEC 61131-3 结构化文本 (ST) 到指令表 (IL) 字节码编译器

///|
/// 将 ST 表达式编译为 IL 累加器指令序列
pub fn compile_expr(expr : Expr, instrs : Array[IlInstruction]) -> Unit {
  match expr {
    Expr::Literal(val) =>
      instrs.push(IlInstruction::with_val(IlOpcode::Ld, val))
    Expr::Variable(name) =>
      instrs.push(IlInstruction::with_var(IlOpcode::Ld, name))
    Expr::DirectAddress(addr) =>
      instrs.push(IlInstruction::with_var(IlOpcode::Ld, addr.to_key()))
    Expr::FieldAccess(inst, field) =>
      instrs.push(IlInstruction::with_var(IlOpcode::Ld, "\{inst}.\{field}"))
    Expr::Unary(op, sub) =>
      match op {
        UnaryOp::Not =>
          match sub {
            Expr::Variable(name) =>
              instrs.push(IlInstruction::with_var(IlOpcode::Ldn, name))
            Expr::DirectAddress(addr) =>
              instrs.push(IlInstruction::with_var(IlOpcode::Ldn, addr.to_key()))
            _ => {
              compile_expr(sub, instrs)
              // 累加器取反: Xor TRUE
              instrs.push(
                IlInstruction::with_val(IlOpcode::Xor, PlcValue::Bool(true)),
              )
            }
          }
        UnaryOp::Neg => {
          compile_expr(sub, instrs)
          // 0 - acc
          instrs.push(IlInstruction::with_val(IlOpcode::Mul, PlcValue::Int(-1)))
        }
      }
    Expr::Binary(left, op, right) => {
      // 先编译左表达式加载到累加器
      compile_expr(left, instrs)

      // 根据右表达式的类型与运算符发射二元操作指令
      match right {
        Expr::Literal(val) => {
          let il_op = match op {
            BinaryOp::Add => IlOpcode::Add
            BinaryOp::Sub => IlOpcode::Sub
            BinaryOp::Mul => IlOpcode::Mul
            BinaryOp::Div => IlOpcode::Div
            BinaryOp::Mod => IlOpcode::Mod
            BinaryOp::Eq => IlOpcode::Eq
            BinaryOp::Neq => IlOpcode::Ne
            BinaryOp::Gt => IlOpcode::Gt
            BinaryOp::Lt => IlOpcode::Lt
            BinaryOp::Gte => IlOpcode::Ge
            BinaryOp::Lte => IlOpcode::Le
            BinaryOp::And => IlOpcode::And
            BinaryOp::Or => IlOpcode::Or
            BinaryOp::Xor => IlOpcode::Xor
          }
          instrs.push(IlInstruction::with_val(il_op, val))
        }
        Expr::Variable(name) => {
          let il_op = match op {
            BinaryOp::Add => IlOpcode::Add
            BinaryOp::Sub => IlOpcode::Sub
            BinaryOp::Mul => IlOpcode::Mul
            BinaryOp::Div => IlOpcode::Div
            BinaryOp::Mod => IlOpcode::Mod
            BinaryOp::Eq => IlOpcode::Eq
            BinaryOp::Neq => IlOpcode::Ne
            BinaryOp::Gt => IlOpcode::Gt
            BinaryOp::Lt => IlOpcode::Lt
            BinaryOp::Gte => IlOpcode::Ge
            BinaryOp::Lte => IlOpcode::Le
            BinaryOp::And => IlOpcode::And
            BinaryOp::Or => IlOpcode::Or
            BinaryOp::Xor => IlOpcode::Xor
          }
          instrs.push(IlInstruction::with_var(il_op, name))
        }
        _ => {
          // 针对更复杂的右子树表达式，先存储中间值
          let temp_name = "__temp_st_right"
          compile_expr(right, instrs)
          instrs.push(IlInstruction::with_var(IlOpcode::St, temp_name))
          compile_expr(left, instrs)
          instrs.push(IlInstruction::with_var(IlOpcode::And, temp_name))
        }
      }
    }
  }
}

///|
/// 将 ST 语句编译为 IL 字节码
pub fn compile_statement(stmt : Stmt, instrs : Array[IlInstruction]) -> Unit {
  match stmt {
    Stmt::Assign(var_name, expr) => {
      compile_expr(expr, instrs)
      instrs.push(IlInstruction::with_var(IlOpcode::St, var_name))
    }
    Stmt::AssignAddress(addr, expr) => {
      compile_expr(expr, instrs)
      instrs.push(IlInstruction::with_var(IlOpcode::St, addr.to_key()))
    }
    Stmt::AssignField(inst, field, expr) => {
      compile_expr(expr, instrs)
      instrs.push(IlInstruction::with_var(IlOpcode::St, "\{inst}.\{field}"))
    }
    Stmt::If(cond, then_stmts, _, else_stmts) => {
      compile_expr(cond, instrs)
      // 若累加器为 FALSE 则跳转至 else 分支，此处记录跳转指令索引
      let jmp_idx = instrs.length()
      instrs.push(IlInstruction::new(IlOpcode::Jmpcn(0))) // 占位符

      // 编译 then 分支
      for s in then_stmts {
        compile_statement(s, instrs)
      }

      // 如果有 else 分支
      if else_stmts.length() > 0 {
        let skip_else_idx = instrs.length()
        instrs.push(IlInstruction::new(IlOpcode::Jmp(0))) // 跳过 else 占位

        // 回填条件跳转地址
        instrs[jmp_idx] = IlInstruction::new(IlOpcode::Jmpcn(skip_else_idx + 1))

        for s in else_stmts {
          compile_statement(s, instrs)
        }
        let end_idx = instrs.length()
        instrs[skip_else_idx] = IlInstruction::new(IlOpcode::Jmp(end_idx))
      } else {
        let end_idx = instrs.length()
        instrs[jmp_idx] = IlInstruction::new(IlOpcode::Jmpcn(end_idx))
      }
    }
    Stmt::While(cond, body) => {
      let loop_start = instrs.length()
      compile_expr(cond, instrs)
      let exit_jump_idx = instrs.length()
      instrs.push(IlInstruction::new(IlOpcode::Jmpcn(0)))

      for s in body {
        compile_statement(s, instrs)
      }
      instrs.push(IlInstruction::new(IlOpcode::Jmp(loop_start)))

      let loop_end = instrs.length()
      instrs[exit_jump_idx] = IlInstruction::new(IlOpcode::Jmpcn(loop_end))
    }
    _ => ()
  }
}

///|
/// 完整 ST 程序向 IL 指令流的编译入口
pub fn compile_st_program(prog : Program) -> Array[IlInstruction] {
  let instrs = []
  for s in prog.statements {
    compile_statement(s, instrs)
  }
  instrs.push(IlInstruction::new(IlOpcode::Halt))
  instrs
}

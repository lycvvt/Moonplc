///|
/// 测试梯形图 (LD) 及其编译器
test "ladder motor start-stop self-hold circuit" {
  // 构建经典电机自锁电路: (Start OR Motor) AND NOT Stop -> Coil(Motor)
  let branch1 = LadderNode::Leaf(Contact::NormallyOpen("Start_Btn"))
  let branch2 = LadderNode::Leaf(Contact::NormallyOpen("Motor_Run"))
  let parallel_start = LadderNode::Parallel([branch1, branch2])
  let stop_contact = LadderNode::Leaf(Contact::NormallyClosed("Stop_Btn"))
  let full_condition = LadderNode::Series([parallel_start, stop_contact])

  let rung = Rung::new(1, "电机自锁起保停控制", full_condition, [
    Coil::Normal("Motor_Run"),
  ])

  let ld = LadderDiagram::new("MotorControl")
  ld.add_rung(rung)

  let prog = ld.to_program()
  assert_eq(prog.name, "MotorControl")
  assert_eq(prog.statements.length(), 1)

  // 验证生成的语句是 Motor_Run := (Start_Btn OR Motor_Run) AND NOT Stop_Btn;
  match prog.statements[0] {
    Stmt::Assign(target, expr) => {
      assert_eq(target, "Motor_Run")
      match expr {
        Expr::Binary(left, BinaryOp::And, right) => {
          match left {
            Expr::Binary(_, BinaryOp::Or, _) => ()
            _ => abort("expected OR in parallel branch")
          }
          match right {
            Expr::Unary(UnaryOp::Not, Expr::Variable(v)) =>
              assert_eq(v, "Stop_Btn")
            _ => abort("expected NOT Stop_Btn")
          }
        }
        _ => abort("expected Binary And at root")
      }
    }
    _ => abort("expected Assign stmt")
  }
}

///|
test "ladder set and reset coils" {
  let rung_set = Rung::new(
    1,
    "置位报警",
    LadderNode::Leaf(Contact::NormallyOpen("Alarm_Trigger")),
    [Coil::Set("Alarm_Active")],
  )

  let rung_rst = Rung::new(
    2,
    "复位报警",
    LadderNode::Leaf(Contact::NormallyOpen("Reset_Btn")),
    [Coil::Reset("Alarm_Active")],
  )

  let ld = LadderDiagram::new("AlarmSystem")
  ld.add_rung(rung_set)
  ld.add_rung(rung_rst)

  let prog = ld.to_program()
  assert_eq(prog.statements.length(), 2)

  match prog.statements[0] {
    Stmt::If(cond, then_stmts, _, _) => {
      match cond {
        Expr::Variable(v) => assert_eq(v, "Alarm_Trigger")
        _ => abort("expected Alarm_Trigger")
      }
      match then_stmts[0] {
        Stmt::Assign(v, Expr::Literal(PlcValue::Bool(b))) => {
          assert_eq(v, "Alarm_Active")
          assert_eq(b, true)
        }
        _ => abort("expected Assign true")
      }
    }
    _ => abort("expected If stmt for Set coil")
  }
}

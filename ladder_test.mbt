///| 测试梯形图 (LD) 及其高级编译器

test "ladder motor start-stop self-hold circuit" {
  let branch1 = LadderNode::Leaf(Contact::NormallyOpen("Start_Btn"))
  let branch2 = LadderNode::Leaf(Contact::NormallyOpen("Motor_Run"))
  let parallel_start = LadderNode::Parallel([branch1, branch2])
  let stop_contact = LadderNode::Leaf(Contact::NormallyClosed("Stop_Btn"))
  let full_condition = LadderNode::Series([parallel_start, stop_contact])

  let rung = Rung::new(
    1,
    "电机自锁起保停控制",
    full_condition,
    [Coil::Normal("Motor_Run")],
  )

  let ld = LadderDiagram::new("MotorControl")
  ld.add_rung(rung)

  let prog = ld.to_program()
  assert_eq(prog.name, "MotorControl")
  assert_eq(prog.statements.length(), 1)

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
            Expr::Unary(UnaryOp::Not, Expr::Variable(v)) => assert_eq(v, "Stop_Btn")
            _ => abort("expected NOT Stop_Btn")
          }
        }
        _ => abort("expected Binary And at root")
      }
    }
    _ => abort("expected Assign stmt")
  }
}

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

test "ladder comparison contact" {
  // 梯级: 当 Package_Count >= 50 时点亮报警灯
  let cmp_contact = Contact::CompareContact("Package_Count", BinaryOp::Gte, 50)
  let rung = Rung::new(
    1,
    "满箱报警",
    LadderNode::Leaf(cmp_contact),
    [Coil::Normal("Box_Full_Led")],
  )

  let ld = LadderDiagram::new("PackagingLine")
  ld.add_rung(rung)
  let prog = ld.to_program()

  match prog.statements[0] {
    Stmt::Assign(target, Expr::Binary(Expr::Variable(v), BinaryOp::Gte, Expr::Literal(PlcValue::Int(threshold)))) => {
      assert_eq(target, "Box_Full_Led")
      assert_eq(v, "Package_Count")
      assert_eq(threshold, 50)
    }
    _ => abort("expected comparison assign")
  }
}

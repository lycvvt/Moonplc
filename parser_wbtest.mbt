///|
/// 测试 ST 语法分析器
test "parser expressions and precedence" {
  let src = "x := a + b * c > 10 AND NOT flag;"
  let parser = Parser::from_source(src)
  let stmt = parser.parse_statement()

  match stmt {
    Stmt::Assign(name, expr) => {
      assert_eq(name, "x")
      match expr {
        Expr::Binary(left, BinaryOp::And, right) => {
          // left 应当是 (a + b * c > 10)
          match left {
            Expr::Binary(_, BinaryOp::Gt, _) => ()
            _ => abort("expected Gt on left of AND")
          }
          // right 应当是 (NOT flag)
          match right {
            Expr::Unary(UnaryOp::Not, Expr::Variable(v)) => assert_eq(v, "flag")
            _ => abort("expected Unary Not")
          }
        }
        _ => abort("expected Binary And at root of expr")
      }
    }
    _ => abort("expected Assign statement")
  }
}

///|
test "parser if-then-else and fb call" {
  let src =
    #|IF Start_Btn THEN
    #|  Timer1(IN := TRUE, PT := T#3s);
    #|  Motor := Timer1.Q;
    #|ELSE
    #|  Motor := FALSE;
    #|END_IF;
  let parser = Parser::from_source(src)
  let stmt = parser.parse_statement()

  match stmt {
    Stmt::If(cond, then_stmts, elsifs, else_stmts) => {
      match cond {
        Expr::Variable(v) => assert_eq(v, "Start_Btn")
        _ => abort("expected Start_Btn condition")
      }
      assert_eq(then_stmts.length(), 2)
      assert_eq(elsifs.length(), 0)
      assert_eq(else_stmts.length(), 1)

      // 验证第一个 then_stmt 是 FbCall
      match then_stmts[0] {
        Stmt::FbCall(name, _, args) => {
          assert_eq(name, "Timer1")
          assert_eq(args.length(), 2)
          assert_eq(args[0].0, "IN")
          assert_eq(args[1].0, "PT")
        }
        _ => abort("expected FbCall")
      }

      // 验证第二个 then_stmt 是 FieldAccess
      match then_stmts[1] {
        Stmt::Assign(target, Expr::FieldAccess(inst, field)) => {
          assert_eq(target, "Motor")
          assert_eq(inst, "Timer1")
          assert_eq(field, "Q")
        }
        _ => abort("expected FieldAccess assign")
      }
    }
    _ => abort("expected If statement")
  }
}

///|
test "parser full program with var decls" {
  let src =
    #|PROGRAM TrafficControl
    #|VAR
    #|  Sensor_Car AT %IX0.0 : BOOL := FALSE;
    #|  Light_Red  AT %QX0.0 : BOOL := TRUE;
    #|  Light_Green AT %QX0.1 : BOOL := FALSE;
    #|  Step_Count : INT := 1;
    #|END_VAR
    #|
    #|IF Sensor_Car THEN
    #|  Light_Green := TRUE;
    #|  Light_Red := FALSE;
    #|END_IF;
    #|END_PROGRAM
  let parser = Parser::from_source(src)
  let prog = parser.parse_program()

  assert_eq(prog.name, "TrafficControl")
  assert_eq(prog.variables.length(), 4)

  assert_eq(prog.variables[0].name, "Sensor_Car")
  assert_eq(prog.variables[0].var_type, "BOOL")
  match prog.variables[0].located_at {
    Some(addr) => {
      assert_eq(addr.area, PlcArea::Input)
      assert_eq(addr.byte_offset, 0)
      assert_eq(addr.bit_offset, 0)
    }
    None => abort("expected located address")
  }

  assert_eq(prog.statements.length(), 1)
}

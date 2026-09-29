///|
/// 测试 ST 词法分析器
test "lexer basic tokens and case insensitivity" {
  let code =
    #|// 单行注释
    #|(* 块注释 *)
    #|PROGRAM Main
    #|VAR
    #|  Start_Btn AT %IX0.0 : BOOL;
    #|  Motor_Out AT %QX0.1 : BOOL;
    #|  Count : INT := 10;
    #|  Delay : TIME := T#5s;
    #|END_VAR
    #|
    #|IF Start_Btn AND NOT Motor_Out THEN
    #|  Motor_Out := TRUE;
    #|END_IF;
    #|END_PROGRAM
  let lex = Lexer::new(code)
  let tokens = lex.tokenize()

  // 验证关键字与标识符
  assert_eq(tokens[0], Token::KwProgram)
  assert_eq(tokens[1], Token::Ident("Main"))
  assert_eq(tokens[2], Token::KwVar)
  assert_eq(tokens[3], Token::Ident("Start_Btn"))
  assert_eq(tokens[4], Token::KwAt)

  // 验证地址解析
  match tokens[5] {
    Token::DirectAddr(addr) => {
      assert_eq(addr.area, PlcArea::Input)
      assert_eq(addr.byte_offset, 0)
      assert_eq(addr.bit_offset, 0)
    }
    _ => abort("expected DirectAddr")
  }

  // 验证时间字面量
  let mut found_time = false
  for tok in tokens {
    match tok {
      Token::TimeLit(ms) => if ms == 5000L { found_time = true }
      _ => ()
    }
  }
  assert_eq(found_time, true)
}

///|
test "lexer operators and time variants" {
  let code = "a := 1 + 2 * 3; b := T#500ms; c := TIME#1m; d := a <> 0;"
  let lex = Lexer::new(code)
  let tokens = lex.tokenize()

  assert_eq(tokens[0], Token::Ident("a"))
  assert_eq(tokens[1], Token::Assign)
  assert_eq(tokens[2], Token::IntLit(1))
  assert_eq(tokens[3], Token::Plus)
  assert_eq(tokens[4], Token::IntLit(2))
  assert_eq(tokens[5], Token::Star)
  assert_eq(tokens[6], Token::IntLit(3))
  assert_eq(tokens[7], Token::Semicolon)

  // T#500ms
  assert_eq(tokens[10], Token::TimeLit(500L))
  // TIME#1m
  assert_eq(tokens[14], Token::TimeLit(60000L))
}

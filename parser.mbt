///| IEC 61131-3 结构化文本 (ST) 语法分析器 (Parser)

///|
/// Parser 状态
pub(all) struct Parser {
  tokens : Array[Token]
  len : Int
  mut pos : Int
} derive(Debug)

///|
/// 创建 Parser
pub fn Parser::new(tokens : Array[Token]) -> Parser {
  { tokens, len: tokens.length(), pos: 0, }
}

///|
/// 从源代码直接创建 Parser
pub fn Parser::from_source(src : String) -> Parser {
  let lexer = Lexer::new(src)
  Parser::new(lexer.tokenize())
}

///|
/// 查看当前 Token
fn Parser::peek(self : Parser) -> Token {
  if self.pos < self.len {
    self.tokens[self.pos]
  } else {
    Token::EOF
  }
}

///|
/// 查看下一个 Token
pub fn Parser::peek_next(self : Parser) -> Token {
  if self.pos + 1 < self.len {
    self.tokens[self.pos + 1]
  } else {
    Token::EOF
  }
}

///|
/// 消耗当前 Token
fn Parser::advance(self : Parser) -> Token {
  let tok = self.peek()
  self.pos = self.pos + 1
  tok
}

///|
/// 检查当前 Token 是否匹配预期
fn Parser::check(self : Parser, tok : Token) -> Bool {
  self.peek() == tok
}

///|
/// 消耗指定类型的 Token，否则返回 false
fn Parser::match_token(self : Parser, tok : Token) -> Bool {
  if self.check(tok) {
    let _ = self.advance()
    true
  } else {
    false
  }
}

// ------------------- 表达式解析 -------------------

///|
/// 解析原子表达式
fn Parser::parse_primary(self : Parser) -> Expr {
  match self.peek() {
    Token::BoolLit(b) => {
      let _ = self.advance()
      Expr::Literal(PlcValue::Bool(b))
    }
    Token::IntLit(i) => {
      let _ = self.advance()
      Expr::Literal(PlcValue::Int(i))
    }
    Token::RealLit(r) => {
      let _ = self.advance()
      Expr::Literal(PlcValue::Real(r))
    }
    Token::TimeLit(t) => {
      let _ = self.advance()
      Expr::Literal(PlcValue::Time(t))
    }
    Token::StringLit(s) => {
      let _ = self.advance()
      Expr::Literal(PlcValue::String(s))
    }
    Token::DirectAddr(addr) => {
      let _ = self.advance()
      Expr::DirectAddress(addr)
    }
    Token::Ident(name) => {
      let _ = self.advance()
      // 检查是否是结构体/功能块属性访问 name.field
      if self.check(Token::Dot) {
        let _ = self.advance()
        match self.peek() {
          Token::Ident(field) => {
            let _ = self.advance()
            Expr::FieldAccess(name, field)
          }
          _ => Expr::Variable(name)
        }
      } else {
        Expr::Variable(name)
      }
    }
    Token::LParen => {
      let _ = self.advance()
      let expr = self.parse_expr()
      let _ = self.match_token(Token::RParen)
      expr
    }
    _ => {
      let _ = self.advance()
      Expr::Literal(PlcValue::Null)
    }
  }
}

///|
/// 解析一元表达式 (NOT, -)
fn Parser::parse_unary(self : Parser) -> Expr {
  if self.match_token(Token::KwNot) {
    let expr = self.parse_unary()
    return Expr::Unary(UnaryOp::Not, expr)
  }
  if self.match_token(Token::Minus) {
    let expr = self.parse_unary()
    return Expr::Unary(UnaryOp::Neg, expr)
  }
  self.parse_primary()
}

///|
/// 解析乘除模 (*, /, MOD)
fn Parser::parse_multiplicative(self : Parser) -> Expr {
  let mut left = self.parse_unary()
  while true {
    if self.match_token(Token::Star) {
      let right = self.parse_unary()
      left = Expr::Binary(left, BinaryOp::Mul, right)
    } else if self.match_token(Token::Slash) {
      let right = self.parse_unary()
      left = Expr::Binary(left, BinaryOp::Div, right)
    } else if self.match_token(Token::KwMod) {
      let right = self.parse_unary()
      left = Expr::Binary(left, BinaryOp::Mod, right)
    } else {
      break
    }
  }
  left
}

///|
/// 解析加减 (+, -)
fn Parser::parse_additive(self : Parser) -> Expr {
  let mut left = self.parse_multiplicative()
  while true {
    if self.match_token(Token::Plus) {
      let right = self.parse_multiplicative()
      left = Expr::Binary(left, BinaryOp::Add, right)
    } else if self.match_token(Token::Minus) {
      let right = self.parse_multiplicative()
      left = Expr::Binary(left, BinaryOp::Sub, right)
    } else {
      break
    }
  }
  left
}

///|
/// 解析比较运算 (=, <>, <, <=, >, >=)
fn Parser::parse_comparison(self : Parser) -> Expr {
  let mut left = self.parse_additive()
  while true {
    if self.match_token(Token::Equal) {
      let right = self.parse_additive()
      left = Expr::Binary(left, BinaryOp::Eq, right)
    } else if self.match_token(Token::NotEqual) {
      let right = self.parse_additive()
      left = Expr::Binary(left, BinaryOp::Neq, right)
    } else if self.match_token(Token::LessThan) {
      let right = self.parse_additive()
      left = Expr::Binary(left, BinaryOp::Lt, right)
    } else if self.match_token(Token::LessThanEqual) {
      let right = self.parse_additive()
      left = Expr::Binary(left, BinaryOp::Lte, right)
    } else if self.match_token(Token::GreaterThan) {
      let right = self.parse_additive()
      left = Expr::Binary(left, BinaryOp::Gt, right)
    } else if self.match_token(Token::GreaterThanEqual) {
      let right = self.parse_additive()
      left = Expr::Binary(left, BinaryOp::Gte, right)
    } else {
      break
    }
  }
  left
}

///|
/// 解析逻辑与 (AND)
fn Parser::parse_logical_and(self : Parser) -> Expr {
  let mut left = self.parse_comparison()
  while self.match_token(Token::KwAnd) {
    let right = self.parse_comparison()
    left = Expr::Binary(left, BinaryOp::And, right)
  }
  left
}

///|
/// 解析逻辑或/异或 (OR, XOR)
fn Parser::parse_logical_or(self : Parser) -> Expr {
  let mut left = self.parse_logical_and()
  while true {
    if self.match_token(Token::KwOr) {
      let right = self.parse_logical_and()
      left = Expr::Binary(left, BinaryOp::Or, right)
    } else if self.match_token(Token::KwXor) {
      let right = self.parse_logical_and()
      left = Expr::Binary(left, BinaryOp::Xor, right)
    } else {
      break
    }
  }
  left
}

///|
/// 表达式解析入口
pub fn Parser::parse_expr(self : Parser) -> Expr {
  self.parse_logical_or()
}

// ------------------- 语句解析 -------------------

///|
/// 解析单个语句
pub fn Parser::parse_statement(self : Parser) -> Stmt {
  // IF 语句
  if self.match_token(Token::KwIf) {
    let cond = self.parse_expr()
    let _ = self.match_token(Token::KwThen)
    let then_stmts = self.parse_statement_list()

    let elsifs = []
    while self.match_token(Token::KwElsif) {
      let elsif_cond = self.parse_expr()
      let _ = self.match_token(Token::KwThen)
      let elsif_stmts = self.parse_statement_list()
      elsifs.push((elsif_cond, elsif_stmts))
    }

    let else_stmts = if self.match_token(Token::KwElse) {
      self.parse_statement_list()
    } else {
      []
    }

    let _ = self.match_token(Token::KwEndIf)
    let _ = self.match_token(Token::Semicolon)
    return Stmt::If(cond, then_stmts, elsifs, else_stmts)
  }

  // WHILE 语句
  if self.match_token(Token::KwWhile) {
    let cond = self.parse_expr()
    let _ = self.match_token(Token::KwDo)
    let body = self.parse_statement_list()
    let _ = self.match_token(Token::KwEndWhile)
    let _ = self.match_token(Token::Semicolon)
    return Stmt::While(cond, body)
  }

  // FOR 语句
  if self.match_token(Token::KwFor) {
    let var_name = match self.peek() {
      Token::Ident(name) => {
        let _ = self.advance()
        name
      }
      _ => "i"
    }
    let _ = self.match_token(Token::Assign)
    let start_expr = self.parse_expr()
    let _ = self.match_token(Token::KwTo)
    let end_expr = self.parse_expr()
    let step_expr = if self.match_token(Token::KwBy) {
      Some(self.parse_expr())
    } else {
      None
    }
    let _ = self.match_token(Token::KwDo)
    let body = self.parse_statement_list()
    let _ = self.match_token(Token::KwEndFor)
    let _ = self.match_token(Token::Semicolon)
    return Stmt::For(var_name, start_expr, end_expr, step_expr, body)
  }

  // 直接物理地址赋值 %QX0.0 := expr;
  match self.peek() {
    Token::DirectAddr(addr) => {
      let _ = self.advance()
      if self.match_token(Token::Assign) {
        let expr = self.parse_expr()
        let _ = self.match_token(Token::Semicolon)
        return Stmt::AssignAddress(addr, expr)
      }
      return Stmt::Empty
    }
    _ => ()
  }

  // 标识符开头：可能是变量赋值、结构体字段赋值或功能块调用
  match self.peek() {
    Token::Ident(name) => {
      let _ = self.advance()

      // 1. 结构体/功能块字段赋值 name.field := expr;
      if self.match_token(Token::Dot) {
        match self.peek() {
          Token::Ident(field) => {
            let _ = self.advance()
            if self.match_token(Token::Assign) {
              let expr = self.parse_expr()
              let _ = self.match_token(Token::Semicolon)
              return Stmt::AssignField(name, field, expr)
            }
          }
          _ => ()
        }
      }

      // 2. 普通变量赋值 name := expr;
      if self.match_token(Token::Assign) {
        let expr = self.parse_expr()
        let _ = self.match_token(Token::Semicolon)
        return Stmt::Assign(name, expr)
      }

      // 3. 功能块调用 name(IN := expr, PT := expr);
      if self.match_token(Token::LParen) {
        let args = []
        while !self.check(Token::RParen) && !self.check(Token::EOF) {
          match self.peek() {
            Token::Ident(arg_name) => {
              let _ = self.advance()
              if self.match_token(Token::Assign) {
                let arg_val = self.parse_expr()
                args.push((arg_name, arg_val))
              }
            }
            _ => {
              let _ = self.advance()
              ()
            }
          }
          let _ = self.match_token(Token::Comma)
        }
        let _ = self.match_token(Token::RParen)
        let _ = self.match_token(Token::Semicolon)
        return Stmt::FbCall(name, "", args)
      }

      let _ = self.match_token(Token::Semicolon)
      return Stmt::Empty
    }
    _ => ()
  }

  // 跳过其他无用标记或空语句
  if self.match_token(Token::Semicolon) {
    return Stmt::Empty
  }
  let _ = self.advance()
  Stmt::Empty
}

///|
/// 解析语句列表 (直到遇到 END_*, ELSE, ELSIF, EOF)
pub fn Parser::parse_statement_list(self : Parser) -> Array[Stmt] {
  let stmts = []
  while true {
    let tok = self.peek()
    if tok == Token::EOF ||
      tok == Token::KwEndIf ||
      tok == Token::KwElse ||
      tok == Token::KwElsif ||
      tok == Token::KwEndWhile ||
      tok == Token::KwEndFor ||
      tok == Token::KwEndProgram {
      break
    }
    let s = self.parse_statement()
    match s {
      Stmt::Empty => ()
      _ => stmts.push(s)
    }
  }
  stmts
}

// ------------------- 变量声明段与完整 POU -------------------

///|
/// 解析 VAR ... END_VAR 块
pub fn Parser::parse_var_block(self : Parser) -> Array[VarDecl] {
  let decls = []
  let _ = self.advance() // 吃掉 VAR / VAR_INPUT / VAR_OUTPUT

  while !self.check(Token::KwEndVar) && !self.check(Token::EOF) {
    let name = match self.peek() {
      Token::Ident(n) => {
        let _ = self.advance()
        n
      }
      _ => {
        let _ = self.advance()
        continue
      }
    }

    // 可选：AT %IX0.0
    let located_at = if self.match_token(Token::KwAt) {
      match self.peek() {
        Token::DirectAddr(addr) => {
          let _ = self.advance()
          Some(addr)
        }
        _ => None
      }
    } else {
      None
    }

    // 冒号与类型
    let _ = self.match_token(Token::Colon)
    let var_type = match self.peek() {
      Token::Ident(t) => {
        let _ = self.advance()
        t
      }
      _ => "BOOL"
    }

    // 可选：初始值 := ...
    let init_val = if self.match_token(Token::Assign) {
      match self.peek() {
        Token::BoolLit(b) => {
          let _ = self.advance()
          Some(PlcValue::Bool(b))
        }
        Token::IntLit(i) => {
          let _ = self.advance()
          Some(PlcValue::Int(i))
        }
        Token::RealLit(r) => {
          let _ = self.advance()
          Some(PlcValue::Real(r))
        }
        Token::TimeLit(t) => {
          let _ = self.advance()
          Some(PlcValue::Time(t))
        }
        Token::StringLit(s) => {
          let _ = self.advance()
          Some(PlcValue::String(s))
        }
        _ => {
          let _ = self.advance()
          None
        }
      }
    } else {
      None
    }

    let _ = self.match_token(Token::Semicolon)
    decls.push({ name, var_type, init_val, located_at, })
  }

  let _ = self.match_token(Token::KwEndVar)
  decls
}

///|
/// 解析完整 PROGRAM 程序
pub fn Parser::parse_program(self : Parser) -> Program {
  let mut prog_name = "Main"
  if self.match_token(Token::KwProgram) {
    match self.peek() {
      Token::Ident(n) => {
        let _ = self.advance()
        prog_name = n
      }
      _ => ()
    }
  }

  let variables = []
  while self.check(Token::KwVar) ||
        self.check(Token::KwVarInput) ||
        self.check(Token::KwVarOutput) {
    let block = self.parse_var_block()
    for v in block {
      variables.push(v)
    }
  }

  let statements = self.parse_statement_list()
  let _ = self.match_token(Token::KwEndProgram)

  { name: prog_name, variables, statements, }
}

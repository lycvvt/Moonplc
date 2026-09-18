///| IEC 61131-3 结构化文本 (ST) 词法分析器 (Lexer)

///|
/// Token 类型定义
pub(all) enum Token {
  // 关键字
  KwProgram
  KwEndProgram
  KwVar
  KwEndVar
  KwVarInput
  KwVarOutput
  KwAt
  KwIf
  KwThen
  KwElsif
  KwElse
  KwEndIf
  KwWhile
  KwEndWhile
  KwDo
  KwFor
  KwTo
  KwBy
  KwEndFor
  KwAnd
  KwOr
  KwNot
  KwXor
  KwMod

  // 标点与运算符
  Assign // :=
  Equal // =
  NotEqual // <>
  LessThan // <
  LessThanEqual // <=
  GreaterThan // >
  GreaterThanEqual // >=
  Plus // +
  Minus // -
  Star // *
  Slash // /
  LParen // (
  RParen // )
  Comma // ,
  Semicolon // ;
  Colon // :
  Dot // .

  // 字面量与标识符
  Ident(String)
  BoolLit(Bool)
  IntLit(Int)
  RealLit(Double)
  TimeLit(Int64) // 毫秒
  StringLit(String)
  DirectAddr(PlcAddress)
  EOF
} derive(Debug, Eq)

///|
/// 辅助：将字符转为大写
fn to_upper_char(c : Char) -> Char {
  if c >= 'a' && c <= 'z' {
    let diff = 'a'.to_int() - 'A'.to_int()
    (c.to_int() - diff).unsafe_to_char()
  } else {
    c
  }
}

///|
/// 辅助：将字符串转为全大写（用于关键字不区分大小写匹配）
fn to_upper_string(s : String) -> String {
  let mut buf = ""
  let chars : Array[Char] = s.iter().collect()
  let mut i = 0
  while i < chars.length() {
    let uc = to_upper_char(chars[i])
    buf = buf + uc.to_string()
    i = i + 1
  }
  buf
}

///|
/// 辅助：解析时间字面量如 "T#500MS", "T#5S", "T#2M"
fn parse_time_literal(s : String) -> Int64 {
  let upper = to_upper_string(s)
  let mut start_idx = 2
  if upper.has_prefix("TIME#") {
    start_idx = 5
  }

  let body = upper[start_idx:].to_owned()
  let chars : Array[Char] = body.iter().collect()
  let mut total_ms = 0L
  let mut curr_num = 0L
  let mut i = 0

  while i < chars.length() {
    let c = chars[i]
    if c >= '0' && c <= '9' {
      let d = (c.to_int() - '0'.to_int()).to_int64()
      curr_num = curr_num * 10L + d
      i = i + 1
    } else if c == 'M' && i + 1 < chars.length() && chars[i + 1] == 'S' {
      total_ms = total_ms + curr_num
      curr_num = 0L
      i = i + 2
    } else if c == 'S' {
      total_ms = total_ms + curr_num * 1000L
      curr_num = 0L
      i = i + 1
    } else if c == 'M' {
      total_ms = total_ms + curr_num * 60000L
      curr_num = 0L
      i = i + 1
    } else if c == 'H' {
      total_ms = total_ms + curr_num * 3600000L
      curr_num = 0L
      i = i + 1
    } else if c == 'D' {
      total_ms = total_ms + curr_num * 86400000L
      curr_num = 0L
      i = i + 1
    } else {
      i = i + 1
    }
  }

  if curr_num > 0L && total_ms == 0L {
    curr_num
  } else {
    total_ms
  }
}

///|
/// 词法分析器状态
pub(all) struct Lexer {
  chars : Array[Char]
  len : Int
  mut pos : Int
} derive(Debug)

///|
/// 创建 Lexer
pub fn Lexer::new(src : String) -> Lexer {
  let chars : Array[Char] = src.iter().collect()
  { chars, len: chars.length(), pos: 0, }
}

///|
/// 查看当前字符
fn Lexer::peek(self : Lexer) -> Char {
  if self.pos < self.len {
    self.chars[self.pos]
  } else {
    '\u0000'
  }
}

///|
/// 查看下一个字符
fn Lexer::peek_next(self : Lexer) -> Char {
  if self.pos + 1 < self.len {
    self.chars[self.pos + 1]
  } else {
    '\u0000'
  }
}

///|
/// 消耗当前字符
fn Lexer::advance(self : Lexer) -> Char {
  let c = self.peek()
  self.pos = self.pos + 1
  c
}

///|
/// 辅助：截取字符数组转换为 String
fn chars_slice_to_string(chars : Array[Char], start : Int, end : Int) -> String {
  let mut s = ""
  let mut i = start
  while i < end && i < chars.length() {
    s = s + chars[i].to_string()
    i = i + 1
  }
  s
}

///|
/// 跳过空白与注释
fn Lexer::skip_whitespace_and_comments(self : Lexer) -> Unit {
  while self.pos < self.len {
    let c = self.peek()
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      let _ = self.advance()
      continue
    }

    // 单行注释 //
    if c == '/' && self.peek_next() == '/' {
      let _ = self.advance()
      let _ = self.advance()
      while self.pos < self.len && self.peek() != '\n' {
        let _ = self.advance()
      }
      continue
    }

    // 块注释 (* ... *)
    if c == '(' && self.peek_next() == '*' {
      let _ = self.advance()
      let _ = self.advance()
      while self.pos < self.len {
        if self.peek() == '*' && self.peek_next() == ')' {
          let _ = self.advance()
          let _ = self.advance()
          break
        }
        let _ = self.advance()
      }
      continue
    }

    break
  }
}

///|
/// 读取下一个 Token
pub fn Lexer::next_token(self : Lexer) -> Token {
  self.skip_whitespace_and_comments()

  if self.pos >= self.len {
    return Token::EOF
  }

  let c = self.peek()

  // PLC 直接物理地址 %IX0.0, %QX1.2, %MW10
  if c == '%' {
    let start = self.pos
    let _ = self.advance()
    while self.pos < self.len {
      let ch = self.peek()
      if (ch >= 'A' && ch <= 'Z') ||
        (ch >= 'a' && ch <= 'z') ||
        (ch >= '0' && ch <= '9') ||
        ch == '.' {
        let _ = self.advance()
      } else {
        break
      }
    }
    let raw = chars_slice_to_string(self.chars, start, self.pos)
    match parse_plc_address(raw) {
      Some(addr) => return Token::DirectAddr(addr)
      None => return Token::Ident(raw)
    }
  }

  // 标点符号与运算符
  if c == ':' {
    let _ = self.advance()
    if self.peek() == '=' {
      let _ = self.advance()
      return Token::Assign
    }
    return Token::Colon
  }

  if c == '<' {
    let _ = self.advance()
    if self.peek() == '>' {
      let _ = self.advance()
      return Token::NotEqual
    }
    if self.peek() == '=' {
      let _ = self.advance()
      return Token::LessThanEqual
    }
    return Token::LessThan
  }

  if c == '>' {
    let _ = self.advance()
    if self.peek() == '=' {
      let _ = self.advance()
      return Token::GreaterThanEqual
    }
    return Token::GreaterThan
  }

  if c == '=' {
    let _ = self.advance()
    return Token::Equal
  }

  if c == '+' {
    let _ = self.advance()
    return Token::Plus
  }
  if c == '-' {
    let _ = self.advance()
    return Token::Minus
  }
  if c == '*' {
    let _ = self.advance()
    return Token::Star
  }
  if c == '/' {
    let _ = self.advance()
    return Token::Slash
  }
  if c == '(' {
    let _ = self.advance()
    return Token::LParen
  }
  if c == ')' {
    let _ = self.advance()
    return Token::RParen
  }
  if c == ',' {
    let _ = self.advance()
    return Token::Comma
  }
  if c == ';' {
    let _ = self.advance()
    return Token::Semicolon
  }
  if c == '.' {
    let _ = self.advance()
    return Token::Dot
  }

  // 字符串字面量 '...'
  if c == '\'' {
    let _ = self.advance()
    let start = self.pos
    while self.pos < self.len && self.peek() != '\'' {
      let _ = self.advance()
    }
    let str_val = chars_slice_to_string(self.chars, start, self.pos)
    if self.peek() == '\'' {
      let _ = self.advance()
    }
    return Token::StringLit(str_val)
  }

  // 数字字面量 (整数或浮点数)
  if c >= '0' && c <= '9' {
    let start = self.pos
    let mut is_real = false
    while self.pos < self.len {
      let ch = self.peek()
      if ch >= '0' && ch <= '9' {
        let _ = self.advance()
      } else if ch == '.' && self.peek_next() >= '0' && self.peek_next() <= '9' {
        is_real = true
        let _ = self.advance()
      } else {
        break
      }
    }
    let num_str = chars_slice_to_string(self.chars, start, self.pos)
    if is_real {
      return Token::RealLit(parse_uint_simple(num_str).to_double())
    } else {
      return Token::IntLit(parse_uint_simple(num_str))
    }
  }

  // 标识符、关键字、时间字面量 T#...
  if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' {
    let start = self.pos
    while self.pos < self.len {
      let ch = self.peek()
      if (ch >= 'a' && ch <= 'z') ||
        (ch >= 'A' && ch <= 'Z') ||
        (ch >= '0' && ch <= '9') ||
        ch == '_' {
        let _ = self.advance()
      } else if ch == '#' {
        let prefix = to_upper_string(
          chars_slice_to_string(self.chars, start, self.pos),
        )
        if prefix == "T" || prefix == "TIME" {
          let _ = self.advance() // 吃掉 '#'
          while self.pos < self.len {
            let tc = self.peek()
            if (tc >= 'a' && tc <= 'z') ||
              (tc >= 'A' && tc <= 'Z') ||
              (tc >= '0' && tc <= '9') ||
              tc == '_' {
              let _ = self.advance()
            } else {
              break
            }
          }
          let time_raw = chars_slice_to_string(self.chars, start, self.pos)
          return Token::TimeLit(parse_time_literal(time_raw))
        } else {
          break
        }
      } else {
        break
      }
    }

    let raw = chars_slice_to_string(self.chars, start, self.pos)
    let upper = to_upper_string(raw)

    if upper == "PROGRAM" {
      return Token::KwProgram
    }
    if upper == "END_PROGRAM" {
      return Token::KwEndProgram
    }
    if upper == "VAR" {
      return Token::KwVar
    }
    if upper == "END_VAR" {
      return Token::KwEndVar
    }
    if upper == "VAR_INPUT" {
      return Token::KwVarInput
    }
    if upper == "VAR_OUTPUT" {
      return Token::KwVarOutput
    }
    if upper == "AT" {
      return Token::KwAt
    }
    if upper == "IF" {
      return Token::KwIf
    }
    if upper == "THEN" {
      return Token::KwThen
    }
    if upper == "ELSIF" {
      return Token::KwElsif
    }
    if upper == "ELSE" {
      return Token::KwElse
    }
    if upper == "END_IF" {
      return Token::KwEndIf
    }
    if upper == "WHILE" {
      return Token::KwWhile
    }
    if upper == "END_WHILE" {
      return Token::KwEndWhile
    }
    if upper == "DO" {
      return Token::KwDo
    }
    if upper == "FOR" {
      return Token::KwFor
    }
    if upper == "TO" {
      return Token::KwTo
    }
    if upper == "BY" {
      return Token::KwBy
    }
    if upper == "END_FOR" {
      return Token::KwEndFor
    }
    if upper == "AND" {
      return Token::KwAnd
    }
    if upper == "OR" {
      return Token::KwOr
    }
    if upper == "NOT" {
      return Token::KwNot
    }
    if upper == "XOR" {
      return Token::KwXor
    }
    if upper == "MOD" {
      return Token::KwMod
    }
    if upper == "TRUE" {
      return Token::BoolLit(true)
    }
    if upper == "FALSE" {
      return Token::BoolLit(false)
    }

    return Token::Ident(raw)
  }

  // 无法识别字符，跳过
  let _ = self.advance()
  self.next_token()
}

///|
/// 解析全部 Token 到数组
pub fn Lexer::tokenize(self : Lexer) -> Array[Token] {
  let tokens = []
  while true {
    let tok = self.next_token()
    tokens.push(tok)
    if tok == Token::EOF {
      break
    }
  }
  tokens
}

///| IEC 61131-3 结构化文本 (ST) 抽象语法树 (AST)

///|
/// 二元运算符
pub(all) enum BinaryOp {
  Add
  Sub
  Mul
  Div
  Mod
  Eq
  Neq
  Lt
  Lte
  Gt
  Gte
  And
  Or
  Xor
} derive(Debug, Eq)

///|
/// 一元运算符
pub(all) enum UnaryOp {
  Not
  Neg
} derive(Debug, Eq)

///|
/// ST 表达式
pub(all) enum Expr {
  Literal(PlcValue)
  Variable(String)
  DirectAddress(PlcAddress)
  Binary(Expr, BinaryOp, Expr)
  Unary(UnaryOp, Expr)
  FieldAccess(String, String) // 如 Timer1.Q 或 Counter1.CV
} derive(Debug)

///|
/// ST 语句
pub(all) enum Stmt {
  Assign(String, Expr) // 变量名 := 表达式
  AssignAddress(PlcAddress, Expr) // %QX0.0 := 表达式
  AssignField(String, String, Expr) // Block.Field := 表达式
  If(Expr, Array[Stmt], Array[(Expr, Array[Stmt])], Array[Stmt]) // IF-THEN-ELSIF-ELSE
  While(Expr, Array[Stmt]) // WHILE ... DO ... END_WHILE
  For(String, Expr, Expr, Expr?, Array[Stmt]) // FOR i := 1 TO 10 BY 1 DO ... END_FOR
  FbCall(String, String, Array[(String, Expr)]) // Timer1(IN := Run, PT := T#5s)
  Empty
} derive(Debug)

///|
/// 变量声明
pub(all) struct VarDecl {
  name : String
  var_type : String // BOOL, INT, REAL, TIME, TON, CTU 等
  init_val : PlcValue?
  located_at : PlcAddress? // AT %IX0.0 物理绑定
} derive(Debug)

///|
/// 完整 ST 程序单元 (POU - Program Organization Unit)
pub(all) struct Program {
  name : String
  variables : Array[VarDecl]
  statements : Array[Stmt]
} derive(Debug)

///|
/// 创建空程序
pub fn Program::new(name : String) -> Program {
  { name, variables: [], statements: [], }
}

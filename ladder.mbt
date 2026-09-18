///| IEC 61131-3 梯形图 (Ladder Diagram, LD) 数据结构与编译器

///|
/// 触点类型
pub(all) enum Contact {
  NormallyOpen(String) // 常开触点 --| |-- (为 TRUE 时导通)
  NormallyClosed(String) // 常闭触点 --|/|-- (为 FALSE 时导通)
  DirectNO(PlcAddress) // 直接物理地址常开触点
  DirectNC(PlcAddress) // 直接物理地址常闭触点
} derive(Debug, Eq)

///|
/// 输出线圈类型
pub(all) enum Coil {
  Normal(String) // 普通输出线圈 --( )--
  Set(String) // 置位线圈 --(S)-- (导通时置 TRUE，保持)
  Reset(String) // 复位线圈 --(R)-- (导通时置 FALSE，保持)
  DirectCoil(PlcAddress) // 直接物理地址线圈
} derive(Debug, Eq)

///|
/// 梯形图逻辑节点 (支持任意深度的串并联布尔网络)
pub(all) enum LadderNode {
  Leaf(Contact)
  Series(Array[LadderNode]) // 串联逻辑 (AND)
  Parallel(Array[LadderNode]) // 并联逻辑 (OR)
} derive(Debug, Eq)

///|
/// 梯级 (Rung)：从左母线流经触点逻辑网络，驱动末端线圈
pub(all) struct Rung {
  id : Int
  comment : String
  condition : LadderNode
  coils : Array[Coil]
} derive(Debug)

///|
/// 创建梯级
pub fn Rung::new(
  id : Int,
  comment : String,
  condition : LadderNode,
  coils : Array[Coil],
) -> Rung {
  { id, comment, condition, coils, }
}

///|
/// 完整梯形图程序
pub(all) struct LadderDiagram {
  name : String
  rungs : Array[Rung]
} derive(Debug)

///|
/// 创建梯形图
pub fn LadderDiagram::new(name : String) -> LadderDiagram {
  { name, rungs: [], }
}

///|
/// 添加梯级
pub fn LadderDiagram::add_rung(self : LadderDiagram, rung : Rung) -> Unit {
  self.rungs.push(rung)
}

// ------------------- 核心编译引擎：LD -> AST / ST -------------------

///|
/// 将 LadderNode 编译为布尔表达式 (Expr)
pub fn ladder_node_to_expr(node : LadderNode) -> Expr {
  match node {
    LadderNode::Leaf(contact) =>
      match contact {
        Contact::NormallyOpen(v) => Expr::Variable(v)
        Contact::NormallyClosed(v) =>
          Expr::Unary(UnaryOp::Not, Expr::Variable(v))
        Contact::DirectNO(addr) => Expr::DirectAddress(addr)
        Contact::DirectNC(addr) =>
          Expr::Unary(UnaryOp::Not, Expr::DirectAddress(addr))
      }
    LadderNode::Series(nodes) => {
      if nodes.length() == 0 {
        return Expr::Literal(PlcValue::Bool(true))
      }
      let mut expr = ladder_node_to_expr(nodes[0])
      let mut i = 1
      while i < nodes.length() {
        let next_expr = ladder_node_to_expr(nodes[i])
        expr = Expr::Binary(expr, BinaryOp::And, next_expr)
        i = i + 1
      }
      expr
    }
    LadderNode::Parallel(nodes) => {
      if nodes.length() == 0 {
        return Expr::Literal(PlcValue::Bool(false))
      }
      let mut expr = ladder_node_to_expr(nodes[0])
      let mut i = 1
      while i < nodes.length() {
        let next_expr = ladder_node_to_expr(nodes[i])
        expr = Expr::Binary(expr, BinaryOp::Or, next_expr)
        i = i + 1
      }
      expr
    }
  }
}

///|
/// 将单个梯级编译为对应的 ST 语句数组 (Stmt)
pub fn rung_to_stmts(rung : Rung) -> Array[Stmt] {
  let stmts = []
  let cond_expr = ladder_node_to_expr(rung.condition)

  for coil in rung.coils {
    match coil {
      Coil::Normal(var_name) =>
        // 普通线圈：直接赋值 var := cond;
        stmts.push(Stmt::Assign(var_name, cond_expr))
      Coil::DirectCoil(addr) => stmts.push(Stmt::AssignAddress(addr, cond_expr))
      Coil::Set(var_name) => {
        // 置位线圈：IF cond THEN var := TRUE; END_IF;
        let then_part = [
          Stmt::Assign(var_name, Expr::Literal(PlcValue::Bool(true))),
        ]
        stmts.push(Stmt::If(cond_expr, then_part, [], []))
      }
      Coil::Reset(var_name) => {
        // 复位线圈：IF cond THEN var := FALSE; END_IF;
        let then_part = [
          Stmt::Assign(var_name, Expr::Literal(PlcValue::Bool(false))),
        ]
        stmts.push(Stmt::If(cond_expr, then_part, [], []))
      }
    }
  }

  stmts
}

///|
/// 将整套梯形图编译为 ST 抽象语法树 (Program)
pub fn LadderDiagram::to_program(self : LadderDiagram) -> Program {
  let stmts = []
  for rung in self.rungs {
    let r_stmts = rung_to_stmts(rung)
    for s in r_stmts {
      stmts.push(s)
    }
  }
  { name: self.name, variables: [], statements: stmts, }
}

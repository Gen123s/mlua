// AST nodes for the Lua 5.4 subset supported by mlua.

pub enum BinOp {
  Add
  Sub
  Mul
  Div
  Mod
  Pow
  Concat
  Eq
  Neq
  Lt
  Le
  Gt
  Ge
  And
  Or
}

pub enum UnOp {
  Neg
  Not
  Len
}

pub enum Expr {
  Nil
  Bool(Bool)
  IntLit(Int)
  FloatLit(Double)
  StrLit(String)
  Var(String)
  Index(Expr, Expr)      // table[key]
  Field(Expr, String)    // table.name
  Bin(BinOp, Expr, Expr)
  Un(UnOp, Expr)
  Call(Expr, Array[Expr])
  MethodCall(Expr, String, Array[Expr])
  Func(Array[String], Block)
  TableCons(Array[(Expr, Expr)]) // (key, value); key=Nil means array item
}

pub enum Stat {
  Assign(Array[Expr], Array[Expr])
  LocalDecl(Array[String], Array[Expr])
  If(Expr, Block, Block)      // cond, then, else
  While(Expr, Block)
  Do(Block)
  ForNum(String, Expr, Expr, Expr?, Block) // var, start, stop, step?, body
  ForIn(Array[String], Array[Expr], Block)
  Return(Array[Expr])
  Break
  ExprStat(Expr)
}

pub type Block = Array[Stat]

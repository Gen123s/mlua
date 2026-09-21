// Recursive-descent parser for the Lua 5.4 subset.
// Parse errors panic -- this is a prototype; the CLI reports the message.

struct Parser {
  toks : Array[Token]
  mut pos : Int
}

fn Parser::peek(self : Parser) -> TokenKind raise  {
  self.toks[self.pos].kind
}

fn Parser::peek_kind(self : Parser, k : TokenKind) -> Bool raise  {
  self.peek() == k
}

fn Parser::peek_at(self : Parser, n : Int) -> TokenKind raise  {
  let i = self.pos + n
  if i < self.toks.length() {
    self.toks[i].kind
  } else {
    Eof
  }
}

fn Parser::advance(self : Parser) -> TokenKind raise  {
  let k = self.peek()
  self.pos += 1
  k
}

fn Parser::expect(self : Parser, k : TokenKind, what : String) -> Unit raise  {
  if self.peek_kind(k) {
    let _ = self.advance()
  } else {
    fail("expected \{what}, got \{Repr(self.peek())} at line \{self.toks[self.pos].line}")
  }
}

fn is_binop(k : TokenKind) -> Bool raise  {
  match k {
    OpAdd | OpSub | OpMul | OpDiv | OpMod | OpPow | OpConcat | OpEq |
    OpNeq | OpLt | OpLe | OpGt | OpGe | KwAnd | KwOr => true
    _ => false
  }
}

fn binop_prec(k : TokenKind) -> Int raise  {
  match k {
    KwOr => 1
    KwAnd => 2
    OpEq | OpNeq | OpLt | OpLe | OpGt | OpGe => 3
    OpConcat => 4
    OpAdd | OpSub => 5
    OpMul | OpDiv | OpMod => 6
    OpPow => 8
    _ => 0
  }
}

fn to_binop(k : TokenKind) -> BinOp raise  {
  match k {
    OpAdd => Add
    OpSub => Sub
    OpMul => Mul
    OpDiv => Div
    OpMod => Mod
    OpPow => Pow
    OpConcat => Concat
    OpEq => Eq
    OpNeq => Neq
    OpLt => Lt
    OpLe => Le
    OpGt => Gt
    OpGe => Ge
    KwAnd => And
    KwOr => Or
    _ => fail("not a binop")
  }
}

fn Parser::parse_expr(self : Parser) -> Expr raise  {
  self.parse_binop(0)
}

fn Parser::parse_binop(self : Parser, limit : Int) -> Expr raise  {
  let mut left = self.parse_unary()
  while is_binop(self.peek()) && binop_prec(self.peek()) > limit {
    let op = self.advance()
    let right = self.parse_binop(binop_prec(op))
    left = Bin(to_binop(op), left, right)
  }
  left
}

fn Parser::parse_unary(self : Parser) -> Expr raise  {
  match self.peek() {
    OpSub => {
      let _ = self.advance()
      Un(Neg, self.parse_unary())
    }
    KwNot => {
      let _ = self.advance()
      Un(Not, self.parse_unary())
    }
    OpLen => {
      let _ = self.advance()
      Un(Len, self.parse_unary())
    }
    _ => self.parse_postfix()
  }
}

fn Parser::parse_postfix(self : Parser) -> Expr raise  {
  let mut e = self.parse_primary()
  while true {
    match self.peek() {
      Dot => {
        let _ = self.advance()
        match self.advance() {
          Name(n) => e = Field(e, n)
          _ => fail("expected field name after .")
        }
      }
      LBracket => {
        let _ = self.advance()
        let idx = self.parse_expr()
        self.expect(RBracket, "]")
        e = Index(e, idx)
      }
      Colon => {
        let _ = self.advance()
        let method =
          match self.advance() {
            Name(n) => n
            _ => fail("expected method name")
          }
        let args = self.parse_call_args()
        e = MethodCall(e, method, args)
      }
      LParen | LBrace | LStr(_) | Name(_) => {
        let args = self.parse_call_args()
        e = Call(e, args)
      }
      _ => break
    }
  }
  e
}

fn Parser::parse_call_args(self : Parser) -> Array[Expr] raise  {
  match self.peek() {
    LParen => {
      let _ = self.advance()
      let args : Array[Expr] = []
      if !self.peek_kind(RParen) {
        for ;; {
          args.push(self.parse_expr())
          if self.peek_kind(Comma) {
            let _ = self.advance()
          } else {
            break
          }
        }
      }
      self.expect(RParen, ")")
      args
    }
    LBrace => [self.parse_table()]
    LStr(s) => {
      let _ = self.advance()
      [StrLit(s)]
    }
    Name(n) => {
      let _ = self.advance()
      [StrLit(n)]
    }
    _ => fail("expected function call arguments")
  }
}

fn Parser::parse_primary(self : Parser) -> Expr raise  {
  match self.peek() {
    KwNil => {
      let _ = self.advance()
      Nil
    }
    KwTrue => {
      let _ = self.advance()
      Bool(true)
    }
    KwFalse => {
      let _ = self.advance()
      Bool(false)
    }
    LInt(n) => {
      let _ = self.advance()
      IntLit(n)
    }
    LFloat(n) => {
      let _ = self.advance()
      FloatLit(n)
    }
    LStr(s) => {
      let _ = self.advance()
      StrLit(s)
    }
    Name(n) => {
      let _ = self.advance()
      Var(n)
    }
    LParen => {
      let _ = self.advance()
      let e = self.parse_expr()
      self.expect(RParen, ")")
      e
    }
    LBrace => self.parse_table()
    KwFunction => {
      let _ = self.advance()
      self.expect(LParen, "(")
      let params : Array[String] = []
      if !self.peek_kind(RParen) {
        for ;; {
          match self.advance() {
            Name(n) => params.push(n)
            _ => fail("expected parameter name")
          }
          if self.peek_kind(Comma) {
            let _ = self.advance()
          } else {
            break
          }
        }
      }
      self.expect(RParen, ")")
      let body = self.parse_block_until(KwEnd)
      Func(params, body)
    }
    other => fail("unexpected token in expression: \{Repr(other)}")
  }
}

fn Parser::parse_table(self : Parser) -> Expr raise  {
  self.expect(LBrace, "{")
  let fields : Array[(Expr, Expr)] = []
  while !self.peek_kind(RBrace) && !self.peek_kind(Eof) {
    if self.peek_kind(LBracket) {
      let _ = self.advance()
      let key = self.parse_expr()
      self.expect(RBracket, "]")
      self.expect(OpAssign, "=")
      let val = self.parse_expr()
      fields.push((key, val))
    } else if self.peek() is Name(_) && self.peek_at(1) == OpAssign {
      let name =
        match self.advance() {
          Name(n) => n
          _ => fail("unreachable")
        }
      let _ = self.advance() // =
      let val = self.parse_expr()
      fields.push((StrLit(name), val))
    } else {
      let val = self.parse_expr()
      fields.push((Nil, val))
    }
    if self.peek_kind(Comma) || self.peek_kind(Semicolon) {
      let _ = self.advance()
    } else {
      break
    }
  }
  self.expect(RBrace, "}")
  TableCons(fields)
}

// ---- statements ----

fn Parser::parse_block_until(self : Parser, terminator : TokenKind) -> Block raise  {
  let block : Block = []
  while !self.peek_kind(terminator) && !self.peek_kind(Eof) {
    if self.peek_kind(Semicolon) {
      let _ = self.advance()
      continue
    }
    let s = self.parse_stat()
    match s {
      Some(st) => block.push(st)
      None => break
    }
  }
  if self.peek_kind(terminator) {
    let _ = self.advance()
  }
  block
}

fn Parser::parse_stat(self : Parser) -> Stat? raise  {
  match self.peek() {
    KwLocal => self.parse_local()
    KwIf => self.parse_if()
    KwWhile => self.parse_while()
    KwFor => self.parse_for()
    KwBreak => {
      let _ = self.advance()
      Some(Break)
    }
    KwReturn => {
      let _ = self.advance()
      let exprs : Array[Expr] = []
      let is_terminator =
        self.peek_kind(KwEnd) || self.peek_kind(KwElse) || self.peek_kind(KwElseif) ||
        self.peek_kind(KwUntil) || self.peek_kind(Semicolon) || self.peek_kind(Eof)
      if !is_terminator {
        for ;; {
          exprs.push(self.parse_expr())
          if self.peek_kind(Comma) {
            let _ = self.advance()
          } else {
            break
          }
        }
      }
      if self.peek_kind(Semicolon) {
        let _ = self.advance()
      }
      Some(Return(exprs))
    }
    _ => self.parse_expr_stat()
  }
}

fn Parser::parse_local(self : Parser) -> Stat? raise  {
  let _ = self.advance() // local
  if self.peek_kind(KwFunction) {
    // local function name(params) body end
    let _ = self.advance() // function
    let name =
      match self.advance() {
        Name(n) => n
        _ => fail("expected function name after local function")
      }
    self.expect(LParen, "(")
    let params : Array[String] = []
    if !self.peek_kind(RParen) {
      for ;; {
        match self.advance() {
          Name(n) => params.push(n)
          _ => fail("expected parameter name")
        }
        if self.peek_kind(Comma) {
          let _ = self.advance()
        } else {
          break
        }
      }
    }
    self.expect(RParen, ")")
    let body = self.parse_block_until(KwEnd)
    Some(LocalDecl([name], [Func(params, body)]))
  } else {
    let names : Array[String] = []
    for ;; {
      match self.advance() {
        Name(n) => names.push(n)
        _ => fail("expected variable name after local")
      }
      if self.peek_kind(Comma) {
        let _ = self.advance()
      } else {
        break
      }
    }
    let values : Array[Expr] = []
    if self.peek_kind(OpAssign) {
      let _ = self.advance()
      for ;; {
        values.push(self.parse_expr())
        if self.peek_kind(Comma) {
          let _ = self.advance()
        } else {
          break
        }
      }
    }
    Some(LocalDecl(names, values))
  }
}

fn Parser::parse_if(self : Parser) -> Stat? raise  {
  let _ = self.advance() // if
  let cond = self.parse_expr()
  self.expect(KwThen, "then")
  let then_block = self.parse_block_until(KwElseif)
  let else_block : Block =
    if self.peek_kind(KwElseif) {
      match self.parse_if() {
        Some(If(c, t, e)) => [If(c, t, e)]
        _ => []
      }
    } else if self.peek_kind(KwElse) {
      let _ = self.advance()
      self.parse_block_until(KwEnd)
    } else {
      self.expect(KwEnd, "end")
      []
    }
  Some(If(cond, then_block, else_block))
}

fn Parser::parse_while(self : Parser) -> Stat? raise  {
  let _ = self.advance() // while
  let cond = self.parse_expr()
  self.expect(KwDo, "do")
  let body = self.parse_block_until(KwEnd)
  Some(While(cond, body))
}

fn Parser::parse_for(self : Parser) -> Stat? raise  {
  let _ = self.advance() // for
  match self.advance() {
    Name(first) => {
      if self.peek_kind(OpAssign) {
        let _ = self.advance()
        let start = self.parse_expr()
        self.expect(Comma, ",")
        let stop = self.parse_expr()
        let step =
          if self.peek_kind(Comma) {
            let _ = self.advance()
            Some(self.parse_expr())
          } else {
            None
          }
        self.expect(KwDo, "do")
        let body = self.parse_block_until(KwEnd)
        Some(ForNum(first, start, stop, step, body))
      } else {
        let names : Array[String] = [first]
        while self.peek_kind(Comma) {
          let _ = self.advance()
          match self.advance() {
            Name(n) => names.push(n)
            _ => fail("expected name in for-in")
          }
        }
        self.expect(KwIn, "in")
        let exprs : Array[Expr] = []
        for ;; {
          exprs.push(self.parse_expr())
          if self.peek_kind(Comma) {
            let _ = self.advance()
          } else {
            break
          }
        }
        self.expect(KwDo, "do")
        let body = self.parse_block_until(KwEnd)
        Some(ForIn(names, exprs, body))
      }
    }
    _ => fail("expected variable after for")
  }
}

fn Parser::parse_expr_stat(self : Parser) -> Stat? raise  {
  let e = self.parse_postfix()
  match self.peek() {
    OpAssign | Comma => {
      let targets : Array[Expr] = [e]
      while self.peek_kind(Comma) {
        let _ = self.advance()
        targets.push(self.parse_postfix())
      }
      let _ = self.advance() // =
      let values : Array[Expr] = []
      for ;; {
        values.push(self.parse_expr())
        if self.peek_kind(Comma) {
          let _ = self.advance()
        } else {
          break
        }
      }
      Some(Assign(targets, values))
    }
    _ => Some(ExprStat(e))
  }
}

/// Parse a whole chunk.
pub fn parse(src : String) -> Block raise  {
  let toks = Lexer::new(src).tokenize()
  let toks =
    match toks {
      Ok(t) => t
      Err(e) => fail(e)
    }
  let p = Parser::{ toks, pos: 0 }
  let block : Block = []
  while !p.peek_kind(Eof) {
    if p.peek_kind(Semicolon) {
      let _ = p.advance()
      continue
    }
    match p.parse_stat() {
      Some(st) => block.push(st)
      None => ()
    }
  }
  block
}

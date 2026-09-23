// Tree-walking interpreter for mlua.

// Control flow signal returned by statement execution.
enum Ctrl {
  Normal
  Break
  Return(Array[LuaValue])
}

/// Evaluate an expression in the given environment.
fn eval(env : Ref[Env], e : Expr) -> LuaValue raise  {
  match e {
    Nil => Nil
    Bool(b) => Boolean(b)
    IntLit(n) => Number(Double::from_int(n))
    FloatLit(n) => Number(n)
    StrLit(s) => Str(s)
    Var(name) => env.val.get(name)
    Field(obj, name) => {
      let v = eval(env, obj)
      match v {
        Table(t) => t.get(Str(name))
        _ => fail("attempt to index a \{v.typename()} value")
      }
    }
    Index(obj, key) => {
      let t = eval(env, obj)
      let k = eval(env, key)
      match t {
        Table(tbl) => tbl.get(k)
        _ => fail("attempt to index a \{t.typename()} value")
      }
    }
    Bin(op, l, r) => eval_binop(env, op, l, r)
    Un(op, e) => eval_unop(env, op, e)
    Func(params, body) => Closure(Closure::new(params, body, env))
    Call(fn_expr, args) => {
      let fv = eval(env, fn_expr)
      let evaluated = args.map(fn(a) { eval(env, a) })
      call_value(fv, evaluated)
    }
    MethodCall(obj, method, args) => {
      let self_v = eval(env, obj)
      match self_v {
        Table(t) => {
          let fv = t.get(Str(method))
          let evaluated = args.map(fn(a) { eval(env, a) })
          let all : Array[LuaValue] = [self_v]
          for v in evaluated {
            all.push(v)
          }
          call_value(fv, all)
        }
        _ => fail("attempt to call method on a non-table value")
      }
    }
    TableCons(fields) => {
      let t = Table::new()
      for pair in fields {
        let (k, v) = pair
        let kv =
          match k {
            Nil => {
              // array item: assign to next integer index
              Number(Double::from_int(t.length()) + 1.0)
            }
            _ => eval(env, k)
          }
        let val = eval(env, v)
        t.set(kv, val)
      }
      Table(t)
    }
  }
}

fn eval_binop(env : Ref[Env], op : BinOp, l : Expr, r : Expr) -> LuaValue raise  {
  // and/or short-circuit
  match op {
    And => {
      let lv = eval(env, l)
      if lv.is_truthy() {
        eval(env, r)
      } else {
        lv
      }
    }
    Or => {
      let lv = eval(env, l)
      if lv.is_truthy() {
        lv
      } else {
        eval(env, r)
      }
    }
    _ => {
      let lv = eval(env, l)
      let rv = eval(env, r)
      match op {
        Add | Sub | Mul | Div | Mod | Pow => {
          let a =
            match lv.coerce_number() {
              Some(x) => x
              None => fail("attempt to perform arithmetic on a \{lv.typename()} value")
            }
          let b =
            match rv.coerce_number() {
              Some(x) => x
              None => fail("attempt to perform arithmetic on a \{rv.typename()} value")
            }
          let res =
            match op {
              Add => a + b
              Sub => a - b
              Mul => a * b
              Div => a / b
              Mod => a - (a / b).floor() * b
              Pow => a.pow(b)
              _ => 0.0
            }
          Number(res)
        }
        Concat => {
          let a = value_to_string(lv)
          let b = value_to_string(rv)
          Str(a + b)
        }
        Eq => Boolean(lua_eq(lv, rv))
        Neq => Boolean(!lua_eq(lv, rv))
        Lt => Boolean(compare(lv, rv) < 0)
        Le => Boolean(compare(lv, rv) <= 0)
        Gt => Boolean(compare(lv, rv) > 0)
        Ge => Boolean(compare(lv, rv) >= 0)
        _ => fail("bad binop")
      }
    }
  }
}

fn eval_unop(env : Ref[Env], op : UnOp, e : Expr) -> LuaValue raise  {
  let v = eval(env, e)
  match op {
    Neg => {
      let n =
        match v.coerce_number() {
          Some(x) => x
          None => fail("attempt to negate a \{v.typename()} value")
        }
      Number(-n)
    }
    Not => Boolean(!v.is_truthy())
    Len =>
      match v {
        Str(s) => Number(Double::from_int(s.length()))
        Table(t) => Number(Double::from_int(t.length()))
        _ => fail("attempt to get length of a \{v.typename()} value")
      }
  }
}

fn lua_eq(a : LuaValue, b : LuaValue) -> Bool raise  {
  match a {
    Nil =>
      match b {
        Nil => true
        _ => false
      }
    Boolean(x) =>
      match b {
        Boolean(y) => x == y
        _ => false
      }
    Number(x) =>
      match b {
        Number(y) => x == y
        _ => false
      }
    Str(x) =>
      match b {
        Str(y) => x == y
        _ => false
      }
    Table(x) =>
      match b {
        Table(y) => x.id == y.id
        _ => false
      }
    Closure(x) =>
      match b {
        Closure(_) => false
        _ => false
      }
    NativeFn(n, _) =>
      match b {
        NativeFn(m, _) => n == m
        _ => false
      }
  }
}

fn compare(a : LuaValue, b : LuaValue) -> Int raise  {
  let an = a.coerce_number()
  let bn = b.coerce_number()
  match (an, bn) {
    (Some(x), Some(y)) =>
      if x < y { -1 } else if x > y { 1 } else { 0 }
    _ =>
      match (a, b) {
        (Str(x), Str(y)) =>
          if x < y { -1 } else if x > y { 1 } else { 0 }
        _ => fail("attempt to compare values")
      }
  }
}

/// Convert a Lua value to its string representation (Lua's tostring).
pub fn value_to_string(v : LuaValue) -> String {
  match v {
    Nil => "nil"
    Boolean(b) =>
      if b { "true" } else { "false" }
    Number(n) => {
      if n == Double::from_int(n.to_int()) {
        n.to_int().to_string()
      } else {
        n.to_string()
      }
    }
    Str(s) => s
    Table(_) => "table: 0x..."
    Closure(_) => "function: 0x..."
    NativeFn(name, _) => "function: native \{name}"
  }
}

fn call_value(fv : LuaValue, args : Array[LuaValue]) -> LuaValue raise  {
  match fv {
    Closure(c) => {
      let child = Env::new(Some(c.env))
      for i in 0..<c.params.length() {
        let v =
          if i < args.length() {
            args[i]
          } else {
            Nil
          }
        child.declare_local(c.params[i], v)
      }
      let child_ref = child.boxed()
      let ctrl = exec_block(child_ref, c.body)
      match ctrl {
        Return(rs) =>
          if rs.length() > 0 {
            rs[0]
          } else {
            Nil
          }
        _ => Nil
      }
    }
    NativeFn(_, f) => f(args)
    _ => fail("attempt to call a \{fv.typename()} value")
  }
}

/// Execute a block, returning the first control-flow signal encountered.
fn exec_block(env : Ref[Env], block : Block) -> Ctrl raise  {
  for s in block {
    let ctrl = exec_stat(env, s)
    match ctrl {
      Normal => ()
      _ => return ctrl
    }
  }
  Normal
}

fn exec_stat(env : Ref[Env], s : Stat) -> Ctrl raise  {
  match s {
    Assign(targets, values) => {
      let evaluated = values.map(fn(v) { eval(env, v) })
      for i in 0..<targets.length() {
        let val =
          if i < evaluated.length() {
            evaluated[i]
          } else {
            Nil
          }
        let t = targets[i]
        match t {
          Var(name) => env.val.assign(name, val)
          Field(obj, name) => {
            let o = eval(env, obj)
            match o {
              Table(tbl) => tbl.set(Str(name), val)
              _ => fail("attempt to index a non-table value")
            }
          }
          Index(obj, key) => {
            let o = eval(env, obj)
            let k = eval(env, key)
            match o {
              Table(tbl) => tbl.set(k, val)
              _ => fail("attempt to index a non-table value")
            }
          }
          _ => fail("invalid assignment target")
        }
      }
      Normal
    }
    LocalDecl(names, values) => {
      let evaluated = values.map(fn(v) { eval(env, v) })
      for i in 0..<names.length() {
        let val =
          if i < evaluated.length() {
            evaluated[i]
          } else {
            Nil
          }
        env.val.declare_local(names[i], val)
      }
      Normal
    }
    If(cond, then_b, else_b) => {
      let c = eval(env, cond)
      if c.is_truthy() {
        exec_block(env, then_b)
      } else {
        exec_block(env, else_b)
      }
    }
    While(cond, body) => {
      while eval(env, cond).is_truthy() {
        let ctrl = exec_block(env, body)
        match ctrl {
          Break => break
          Return(_) => return ctrl
          Normal => ()
        }
      }
      Normal
    }
    ForNum(var_name, start, stop, step, body) => {
      let s =
        match eval(env, start).coerce_number() {
          Some(x) => x
          None => fail("'for' initial value must be a number")
        }
      let e =
        match eval(env, stop).coerce_number() {
          Some(x) => x
          None => fail("'for' limit must be a number")
        }
      let step_v =
        match step {
          Some(st) =>
            match eval(env, st).coerce_number() {
              Some(x) => x
              None => fail("'for' step must be a number")
            }
          None => 1.0
        }
      let child = Env::new(Some(env))
      let child_ref = child.boxed()
      let mut i = s
      while (step_v > 0.0 && i <= e) || (step_v < 0.0 && i >= e) {
        child_ref.val.declare_local(var_name, Number(i))
        let ctrl = exec_block(child_ref, body)
        match ctrl {
          Break => break
          Return(_) => return ctrl
          Normal => ()
        }
        i += step_v
      }
      Normal
    }
    ForIn(names, exprs, body) => {
      // Simplified: support only the iterator result as a table array.
      let it_vals = exprs.map(fn(x) { eval(env, x) })
      // For now, treat first expr as a table and iterate its array part.
      match it_vals[0] {
        Table(t) => {
          let child = Env::new(Some(env))
          let child_ref = child.boxed()
          for i in 0..<t.length() {
            if names.length() >= 1 {
              child_ref.val.declare_local(names[0], Number(Double::from_int(i + 1)))
            }
            if names.length() >= 2 {
              child_ref.val.declare_local(names[1], t.get_int(i + 1))
            }
            let ctrl = exec_block(child_ref, body)
            match ctrl {
              Break => break
              Return(_) => return ctrl
              Normal => ()
            }
          }
          Normal
        }
        _ => fail("generic for requires a table iterator")
      }
    }
    Do(b) => {
      let child = Env::new(Some(env))
      exec_block(child.boxed(), b)
    }
    Return(exprs) => {
      let vals = exprs.map(fn(e) { eval(env, e) })
      Return(vals)
    }
    Break => Break
    ExprStat(e) => {
      let _ = eval(env, e)
      Normal
    }
  }
}

/// Build the global environment with standard library functions.
pub fn make_global() -> Ref[Env] raise  {
  let g = Env::new(None)
  // print(...)
  g.declare_local(
    "print",
    NativeFn(
      "print",
      fn(args) {
        let parts : Array[String] = []
        for a in args {
          parts.push(value_to_string(a))
        }
        println(parts.join("\t"))
        Nil
      },
    ),
  )
  // type(x)
  g.declare_local(
    "type",
    NativeFn(
      "type",
      fn(args) {
        if args.length() >= 1 {
          Str(args[0].typename())
        } else {
          Nil
        }
      },
    ),
  )
  // tostring(x)
  g.declare_local(
    "tostring",
    NativeFn(
      "tostring",
      fn(args) {
        if args.length() >= 1 {
          Str(value_to_string(args[0]))
        } else {
          Str("")
        }
      },
    ),
  )
  // tonumber(x)
  g.declare_local(
    "tonumber",
    NativeFn(
      "tonumber",
      fn(args) {
        if args.length() >= 1 {
          match args[0].coerce_number() {
            Some(n) => Number(n)
            None => Nil
          }
        } else {
          Nil
        }
      },
    ),
  )
  // pairs(t): simplified -> just returns t (we iterate arrays directly)
  g.declare_local(
    "pairs",
    NativeFn(
      "pairs",
      fn(args) {
        if args.length() >= 1 {
          args[0]
        } else {
          Nil
        }
      },
    ),
  )
  // ipairs(t)
  g.declare_local(
    "ipairs",
    NativeFn(
      "ipairs",
      fn(args) {
        if args.length() >= 1 {
          args[0]
        } else {
          Nil
        }
      },
    ),
  )
  // math library
  let math_t = Table::new()
  math_t.set(
    Str("floor"),
    NativeFn(
      "math.floor",
      fn(args) {
        if args.length() >= 1 {
          match args[0].coerce_number() {
            Some(n) => Number(n.floor())
            None => Nil
          }
        } else {
          Nil
        }
      },
    ),
  )
  math_t.set(
    Str("max"),
    NativeFn(
      "math.max",
      fn(args) {
        if args.length() == 0 {
          Nil
        } else {
          let mut best = args[0].coerce_number()
          for a in args {
            let n = a.coerce_number()
            match (best, n) {
              (Some(b), Some(x)) =>
                if x > b {
                  best = Some(x)
                }
              _ => ()
            }
          }
          match best {
            Some(n) => Number(n)
            None => Nil
          }
        }
      },
    ),
  )
  math_t.set(
    Str("min"),
    NativeFn(
      "math.min",
      fn(args) {
        if args.length() == 0 {
          Nil
        } else {
          let mut best = args[0].coerce_number()
          for a in args {
            let n = a.coerce_number()
            match (best, n) {
              (Some(b), Some(x)) =>
                if x < b {
                  best = Some(x)
                }
              _ => ()
            }
          }
          match best {
            Some(n) => Number(n)
            None => Nil
          }
        }
      },
    ),
  )
  math_t.set(Str("pi"), Number(3.141592653589793))
  math_t.set(Str("huge"), Number(Double::inf(0)))
  g.declare_local("math", Table(math_t))
  // string library (minimal)
  let str_t = Table::new()
  str_t.set(
    Str("len"),
    NativeFn(
      "string.len",
      fn(args) {
        if args.length() >= 1 {
          match args[0] {
            Str(s) => Number(Double::from_int(s.length()))
            _ => Nil
          }
        } else {
          Nil
        }
      },
    ),
  )
  str_t.set(
    Str("sub"),
    NativeFn(
      "string.sub",
      fn(args) {
        if args.length() >= 3 {
          match args[0] {
            Str(s) => {
              let i1 = args[1].coerce_number()
              let i2 = args[2].coerce_number()
              match (i1, i2) {
                (Some(a), Some(b)) =>
                  Str(s[(a.to_int() - 1):b.to_int()].to_string())
                _ => Nil
              }
            }
            _ => Nil
          }
        } else {
          Nil
        }
      },
    ),
  )
  str_t.set(
    Str("rep"),
    NativeFn(
      "string.rep",
      fn(args) {
        if args.length() >= 2 {
          match (args[0], args[1].coerce_number()) {
            (Str(s), Some(n)) => {
              let mut out = ""
              for _ in 0..<n.to_int() {
                out = out + s
              }
              Str(out)
            }
            _ => Nil
          }
        } else {
          Nil
        }
      },
    ),
  )
  g.declare_local("string", Table(str_t))
  g.boxed()
}

/// Run a chunk of Lua source and return the result value (last expression).
pub fn run(src : String) -> LuaValue raise  {
  let block = parse(src)
  let env = make_global()
  match exec_block(env, block) {
    Return(rs) =>
      if rs.length() > 0 {
        rs[0]
      } else {
        Nil
      }
    _ => Nil
  }
}

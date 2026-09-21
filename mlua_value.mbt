// Runtime values for mlua.

/// A Lua table: array part + hash part, by reference.
pub struct Table {
  id : Int
  arr : Array[LuaValue]
  map : Map[String, LuaValue]
}

pub fn Table::new() -> Table {
  {{ id: next_table_id(), arr: [], map: Map([]) }}
}

fn try_int_of(s : String) -> Int? {
  try {
    Some(@string.parse_int(s, base=10))
  } catch {
    _ => None
  }
}

pub fn Table::get(self : Table, key : LuaValue) -> LuaValue {
  match key {
    Str(s) =>
      match self.map.get(s) {
        Some(v) => v
        None =>
          match try_int_of(s) {
            Some(i) => self.get_int(i)
            None => Nil
          }
      }
    Number(n) => self.get_int(n.to_int())
    _ => Nil
  }
}

fn Table::get_int(self : Table, i : Int) -> LuaValue {
  if i >= 1 && i <= self.arr.length() {
    self.arr[i - 1]
  } else {
    Nil
  }
}

pub fn Table::set(self : Table, key : LuaValue, val : LuaValue) -> Unit {
  match key {
    Str(s) =>
      match try_int_of(s) {
        Some(i) if i >= 1 => self.set_int(i, val)
        _ => self.map[s] = val
      }
    Number(n) => self.set_int(n.to_int(), val)
    _ => ()
  }
}

fn Table::set_int(self : Table, i : Int, val : LuaValue) -> Unit {
  while self.arr.length() < i {
    self.arr.push(Nil)
  }
  if i <= self.arr.length() {
    self.arr[i - 1] = val
  }
}

pub fn Table::length(self : Table) -> Int {
  self.arr.length()
}

/// A Lua function closure: parameters, body, captured upvalue environment.
pub struct Closure {
  params : Array[String]
  body : Block
  env : Ref[Env]
}

pub fn Closure::new(params : Array[String], body : Block, env : Ref[Env]) -> Closure {
  { params, body, env }
}

/// A runtime Lua value.
pub enum LuaValue {
  Nil
  Boolean(Bool)
  Number(Double)
  Str(String)
  Table(Table)
  Closure(Closure)
  /// A native host function callable from Lua (print, etc.)
  NativeFn(String, (Array[LuaValue]) -> LuaValue)
}

pub fn LuaValue::typename(self : LuaValue) -> String {
  match self {
    Nil => "nil"
    Boolean(_) => "boolean"
    Number(_) => "number"
    Str(_) => "string"
    Table(_) => "table"
    Closure(_) => "function"
    NativeFn(_, _) => "function"
  }
}

pub fn LuaValue::is_truthy(self : LuaValue) -> Bool {
  match self {
    Nil => false
    Boolean(b) => b
    _ => true
  }
}

/// Convert a value to a Lua-style number, coercing numeric strings.
pub fn LuaValue::coerce_number(self : LuaValue) -> Double? {
  match self {
    Number(n) => Some(n)
    Str(s) => {
      try {
        Some(@string.parse_double(s))
      } catch {
        _ => None
      }
    }
    _ => None
  }
}

// Simple global counter for table identity.
let table_counter : Ref[Int] = Ref::{ val: 0 }

fn next_table_id() -> Int {
  table_counter.val += 1
  table_counter.val
}

// Scoped environment for the interpreter.

pub struct Env {
  vars : Map[String, LuaValue]
  parent : Ref[Env]?
}

pub fn Env::new(parent : Ref[Env]?) -> Env {
  { vars: Map([]), parent }
}

/// Box an env into a reference for use as a parent.
pub fn Env::boxed(self : Env) -> Ref[Env] {
  Ref::{ val: self }
}

pub fn Env::get(self : Env, name : String) -> LuaValue {
  match self.vars.get(name) {
    Some(v) => v
    None =>
      match self.parent {
        Some(p) => p.val.get(name)
        None => Nil
      }
  }
}

/// Assign to an existing variable (Lua's plain `x = v`): walk the chain.
/// If not found, set it on the global (outermost) scope.
pub fn Env::assign(self : Env, name : String, val : LuaValue) -> Unit {
  if self.vars.contains(name) {
    self.vars[name] = val
  } else {
    match self.parent {
      Some(p) => p.val.assign(name, val)
      None => self.vars[name] = val
    }
  }
}

/// Declare a new local in this scope.
pub fn Env::declare_local(self : Env, name : String, val : LuaValue) -> Unit {
  self.vars[name] = val
}

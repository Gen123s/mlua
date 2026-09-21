///|
/// mlua - a Lua 5.4 subset interpreter written in pure MoonBit.
fn main raise {
  println("mlua 0.1.0 - Lua 5.4 subset in MoonBit")
  let v = @lib.run("return 1 + 2 * 3")
  println("1 + 2*3 = \{@lib.value_to_string(v)}")
  let v2 = @lib.run("local x = 10; local y = 20; return x + y")
  println("local x=10, y=20; x+y = \{@lib.value_to_string(v2)}")
}

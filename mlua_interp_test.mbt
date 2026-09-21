test "run arithmetic and print" {
  // We can't capture stdout easily, so we test return values via a global.
  let v = @mlua.run("local x = 1 + 2 * 3; return x")
  inspect(value_to_string(v), content="7")
}

test "run functions and closures" {
  let code =
    "local function add(a, b)\n" +
    "  return a + b\n" +
    "end\n" +
    "return add(3, 4)"
  let v = @mlua.run(code)
  inspect(value_to_string(v), content="7")
}

test "run table and loops" {
  let code =
    "local t = {10, 20, 30}\n" +
    "local sum = 0\n" +
    "for i = 1, 3 do\n" +
    "  sum = sum + t[i]\n" +
    "end\n" +
    "return sum"
  let v = @mlua.run(code)
  inspect(value_to_string(v), content="60")
}

test "run string concat" {
  let v = @mlua.run("return \"a\" .. \"b\" .. \"c\"")
  inspect(value_to_string(v), content="abc")
}

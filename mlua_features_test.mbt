// Additional blackbox tests: language features and stdlib coverage.
// Several of these initially exposed real parser bugs (if/elseif parsing,
// statement gluing, missing do-blocks); see commit history.

test "if with else" {
  let v = @mlua.run("local x = 3\nif x > 2 then return 'big' else return 'small' end")
  inspect(@mlua.value_to_string(v), content="big")
  let v2 = @mlua.run("local x = 1\nif x > 2 then return 'big' else return 'small' end")
  inspect(@mlua.value_to_string(v2), content="small")
}

test "elseif chain" {
  let v = @mlua.run(
    "local x = 7\n" +
    "if x < 5 then return 'low'\n" +
    "elseif x < 10 then return 'mid'\n" +
    "else return 'high' end")
  inspect(@mlua.value_to_string(v), content="mid")
}

test "while with break and running sum" {
  let v = @mlua.run(
    "local i = 1\n" +
    "local s = 0\n" +
    "while true do\n" +
    "  if i > 10 then break end\n" +
    "  s = s + i\n" +
    "  i = i + 1\n" +
    "end\n" +
    "return s")
  inspect(@mlua.value_to_string(v), content="55")
}

test "do block scopes locals" {
  let v = @mlua.run("local x = 1\ndo local x = 2 end\nreturn x")
  inspect(@mlua.value_to_string(v), content="1")
}

test "numeric for with step and negative step" {
  let up = @mlua.run("local s = 0 for i = 1, 10, 3 do s = s + i end return s")
  inspect(@mlua.value_to_string(up), content="22")
  let down = @mlua.run("local s = 0 for i = 5, 1, -2 do s = s + i end return s")
  inspect(@mlua.value_to_string(down), content="9")
}

test "generic for yields index and value" {
  let code =
    "local t = {4, 5, 6}\n" +
    "local s = 0\n" +
    "for i, v in t do s = s + i * v end\n" +
    "return s"
  let v = @mlua.run(code)
  inspect(@mlua.value_to_string(v), content="32")
}

test "closure counter mutates captured upvalue" {
  let code =
    "local function make()\n" +
    "  local n = 0\n" +
    "  return function() n = n + 1 return n end\n" +
    "end\n" +
    "local c = make()\n" +
    "c()\n" +
    "c()\n" +
    "return c()"
  inspect(@mlua.value_to_string(@mlua.run(code)), content="3")
}

test "method call with colon syntax" {
  let code =
    "local t = {x = 5}\n" +
    "t.get = function(self) return self.x * 2 end\n" +
    "return t:get()"
  inspect(@mlua.value_to_string(@mlua.run(code)), content="10")
}

test "length operator on string and table" {
  let s = @mlua.run("return #'hello'")
  inspect(@mlua.value_to_string(s), content="5")
  let t = @mlua.run("local t = {1, 2, 3} return #t")
  inspect(@mlua.value_to_string(t), content="3")
}

test "arithmetic operators incl modulo and power" {
  inspect(@mlua.value_to_string(@mlua.run("return 7 % 3")), content="1")
  inspect(@mlua.value_to_string(@mlua.run("return 2 ^ 10")), content="1024")
  inspect(@mlua.value_to_string(@mlua.run("return 7 / 2")), content="3.5")
  inspect(@mlua.value_to_string(@mlua.run("return -5 + 2")), content="-3")
}

test "comparison and logic operators" {
  inspect(@mlua.value_to_string(@mlua.run("return 1 < 2")), content="true")
  inspect(@mlua.value_to_string(@mlua.run("return 'a' == 'a'")), content="true")
  inspect(@mlua.value_to_string(@mlua.run("return nil or 'fallback'")), content="fallback")
  inspect(@mlua.value_to_string(@mlua.run("return false and 1")), content="false")
  inspect(@mlua.value_to_string(@mlua.run("return not nil")), content="true")
}

test "nested tables and index assignment" {
  let code =
    "local grid = {}\n" +
    "grid[1] = {10, 20}\n" +
    "grid[2] = {30, 40}\n" +
    "return grid[2][1] + grid[1][2]"
  inspect(@mlua.value_to_string(@mlua.run(code)), content="50")
}

test "string library sub rep len" {
  inspect(@mlua.value_to_string(@mlua.run("return string.sub('hello', 2, 4)")), content="ell")
  inspect(@mlua.value_to_string(@mlua.run("return string.rep('ab', 3)")), content="ababab")
  inspect(@mlua.value_to_string(@mlua.run("return string.len('hello')")), content="5")
}

test "math library floor max min pi" {
  inspect(@mlua.value_to_string(@mlua.run("return math.floor(3.7)")), content="3")
  inspect(@mlua.value_to_string(@mlua.run("return math.max(2, 9, 4)")), content="9")
  inspect(@mlua.value_to_string(@mlua.run("return math.min(2, 9, 4)")), content="2")
  inspect(@mlua.value_to_string(@mlua.run("return math.pi > 3.14")), content="true")
}

test "tonumber and tostring coercion" {
  inspect(@mlua.value_to_string(@mlua.run("return tonumber('42') + 1")), content="43")
  inspect(@mlua.value_to_string(@mlua.run("return tostring(12) .. '!'")), content="12!")
  inspect(@mlua.value_to_string(@mlua.run("return type(tonumber('nope'))")), content="nil")
}

test "function values can be stored and passed" {
  let code =
    "local function apply(f, x) return f(x) end\n" +
    "return apply(function(n) return n * n end, 9)"
  inspect(@mlua.value_to_string(@mlua.run(code)), content="81")
}

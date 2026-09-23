# mlua

[![CI](https://github.com/Gen123s/mlua/actions/workflows/ci.yml/badge.svg)](https://github.com/Gen123s/mlua/actions/workflows/ci.yml)

[English](README.md) | [简体中文](README.zh.md)

A Lua 5.4 subset interpreter written in pure [MoonBit](https://www.moonbitlang.com/).

## What it does

mlua implements a tree-walking interpreter for a useful subset of Lua 5.4:

- Lexer (comments, long strings, number literals with hex/exponents, escape sequences)
- Parser (recursive descent, operator precedence, `local function`, tables, methods)
- Tree-walking VM with closures, lexical scoping, tables, and a minimal stdlib
- Standard library: `print`, `type`, `tostring`, `tonumber`, `pairs`, `ipairs`, `math.*`, `string.*`

## Quick start

```bash
moon run cmd/main   # run the built-in demo
moon test           # run the test suite
```

## Example

```lua
local function fib(n)
  if n < 2 then return n end
  return fib(n - 1) + fib(n - 2)
end

local t = {10, 20, 30}
local sum = 0
for i = 1, #t do
  sum = sum + t[i]
end
print("fib(10) =", fib(10))
```

## Status

Supported: numbers, strings, booleans, nil, tables, closures, `if`/`elseif`/`else`/`while`/`do` blocks/numeric `for` (with step)/generic `for`, `return`/`break`, `local function`, method calls, a small stdlib.

Not yet: metatables, `goto`, `repeat`/`until`, varargs, modules, coroutines.

## Layout

```
mlua_lexer.mbt     Tokenizer
mlua_ast.mbt       AST nodes
mlua_parser.mbt    Recursive-descent parser
mlua_value.mbt     Runtime values
mlua_env.mbt       Lexical environment chain
mlua_interp.mbt    Tree-walking interpreter + stdlib
mlua_features_test.mbt  Feature-level tests
cmd/main/main.mbt  CLI demo
```

## License

Apache-2.0.

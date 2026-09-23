# mlua

[![CI](https://github.com/Gen123s/mlua/actions/workflows/ci.yml/badge.svg)](https://github.com/Gen123s/mlua/actions/workflows/ci.yml)

[English](README.md) | [简体中文](README.zh.md)

一个用纯 [MoonBit](https://www.moonbitlang.com/) 编写的 Lua 5.4 子集解释器。

## 项目简介

mlua 实现了一个树遍历（tree-walking）解释器，支持 Lua 5.4 的一个实用子集：

- **词法分析器**：注释、长字符串、十六进制/指数数字字面量、转义序列
- **语法分析器**：递归下降、运算符优先级、`local function`、表、方法调用
- **解释器**：树遍历虚拟机，支持闭包、词法作用域、表，以及一个精简标准库
- **标准库**：`print`、`type`、`tostring`、`tonumber`、`pairs`、`ipairs`、`math.*`、`string.*`

## 快速开始

```bash
moon run cmd/main   # 运行内置示例
moon test           # 运行测试套件
```

## 示例

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

## 支持情况

已支持：数字、字符串、布尔值、nil、表、闭包、`if`/`elseif`/`else`/`while`/`do` 块/数值 `for`（含步长）/泛型 `for`、`return`/`break`、`local function`、方法调用、精简标准库。

暂不支持：metatable、`goto`、`repeat`/`until`、变长参数、模块系统、协程。

## 代码结构

```
mlua_lexer.mbt     词法分析器
mlua_ast.mbt       AST 节点
mlua_parser.mbt    递归下降语法分析器
mlua_value.mbt     运行时值
mlua_env.mbt       词法环境链
mlua_interp.mbt    树遍历解释器 + 标准库
mlua_features_test.mbt  特性级测试
cmd/main/main.mbt  命令行示例
```

## 开源许可

Apache-2.0。

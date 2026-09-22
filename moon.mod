// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html

name = "Gen123s/mlua"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/Gen123s/mlua"

license = "Apache-2.0"

keywords = ["lua", "interpreter", "scripting", "language", "parser"]

preferred_target = "wasm"

description = "A Lua 5.4 subset interpreter written in pure MoonBit (tree-walking, no FFI)"

import {
  "moonbitlang/x@0.5.5",
}

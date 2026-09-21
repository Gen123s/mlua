test "lexer basics" {
  let src = "local x = 1 + 2 * 3 -- comment\nprint(\"hi\")"
  let toks = @mlua.Lexer::new(src).tokenize()
  match toks {
    Ok(arr) => {
      inspect(arr.length(), content="13")
    }
    Err(e) => fail(e)
  }
}

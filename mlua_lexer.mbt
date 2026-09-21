// Lua lexer: turns source text into a flat token stream.
// String is indexed by UTF-16 code units (UInt16); we compare by ASCII codes.

/// Token kind produced by the lexer.
pub enum TokenKind {
  Name(String)
  LInt(Int)
  LFloat(Double)
  LStr(String)
  KwAnd
  KwBreak
  KwDo
  KwElse
  KwElseif
  KwEnd
  KwFalse
  KwFor
  KwFunction
  KwIf
  KwIn
  KwLocal
  KwNil
  KwNot
  KwOr
  KwRepeat
  KwReturn
  KwThen
  KwTrue
  KwUntil
  KwWhile
  OpAdd
  OpSub
  OpMul
  OpDiv
  OpMod
  OpPow
  OpLen
  OpEq
  OpNeq
  OpLe
  OpGe
  OpLt
  OpGt
  OpAssign
  OpConcat
  OpDots
  LParen
  RParen
  LBrace
  RBrace
  LBracket
  RBracket
  Semicolon
  Colon
  DoubleColon
  Comma
  Dot
  Eof
} derive(Eq, Debug)

pub struct Token {
  kind : TokenKind
  line : Int
}

struct Lexer {
  src : String
  mut pos : Int
  mut line : Int
}

pub fn Lexer::new(src : String) -> Lexer {
  { src, pos: 0, line: 1 }
}

fn Lexer::eof(self : Lexer) -> Bool {
  self.pos >= self.src.length()
}

fn Lexer::peek(self : Lexer) -> UInt16 {
  if self.eof() { 0 } else { self.src[self.pos] }
}

fn Lexer::peek_at(self : Lexer, n : Int) -> UInt16 {
  if self.pos + n >= self.src.length() { 0 } else { self.src[self.pos + n] }
}

fn Lexer::advance(self : Lexer) -> UInt16 {
  let c = self.peek()
  if c == 10 {
    self.line += 1
  }
  self.pos += 1
  c
}

fn is_digit(c : UInt16) -> Bool {
  c >= 48 && c <= 57 // '0'..'9'
}

fn is_hex_digit(c : UInt16) -> Bool {
  (c >= 48 && c <= 57) || (c >= 97 && c <= 102) || (c >= 65 && c <= 70)
}

fn is_alpha(c : UInt16) -> Bool {
  (c >= 97 && c <= 122) || (c >= 65 && c <= 90) || c == 95 // _
}

fn is_word(c : UInt16) -> Bool {
  is_alpha(c) || is_digit(c)
}

fn Lexer::skip_trivia(self : Lexer) -> Unit {
  while !self.eof() {
    let c = self.peek()
    if c == 32 || c == 9 || c == 13 || c == 10 {
      let _ = self.advance()
    } else if c == 45 && self.peek_at(1) == 45 { // --
      let _ = self.advance()
      let _ = self.advance()
      let level = self.try_long_bracket()
      if level >= 0 {
        self.consume_long(level)
      } else {
        while !self.eof() && self.peek() != 10 {
          let _ = self.advance()
        }
      }
    } else {
      break
    }
  }
}

fn Lexer::try_long_bracket(self : Lexer) -> Int {
  if self.peek() != 91 { // [
    -1
  } else {
    let mut i = 1
    while self.peek_at(i) == 61 { // =
      i += 1
    }
    if self.peek_at(i) == 91 { // [
      i - 1
    } else {
      -1
    }
  }
}

fn Lexer::consume_long(self : Lexer, level : Int) -> Unit {
  let _ = self.advance() // [
  for _ in 0..<level {
    let _ = self.advance()
  }
  let _ = self.advance() // [
  let close_len = level + 2
  while !self.eof() {
    let c = self.peek()
    if c == 93 { // ]
      let mut i = 1
      while self.peek_at(i) == 61 {
        i += 1
      }
      if i - 1 == level && self.peek_at(i) == 93 {
        for _ in 0..<close_len {
          let _ = self.advance()
        }
        return
      }
    }
    let _ = self.advance()
  }
}

fn Lexer::read_long_string(self : Lexer, level : Int) -> String {
  let start = self.pos
  self.consume_long(level)
  let open_len = 2 + level
  let close_len = 2 + level
  let content_start = start + open_len
  let content_end = self.pos - close_len
  self.src[content_start:content_end].to_owned()
}

fn Lexer::read_name(self : Lexer) -> String {
  let start = self.pos
  while !self.eof() && is_word(self.peek()) {
    let _ = self.advance()
  }
  self.src[start:self.pos].to_owned()
}

fn Lexer::read_number(self : Lexer) -> TokenKind {
  let start = self.pos
  let mut is_float = false
  let mut base = 10
  if self.peek() == 48 && (self.peek_at(1) == 120 || self.peek_at(1) == 88) {
    base = 16
    let _ = self.advance()
    let _ = self.advance()
    while is_hex_digit(self.peek()) {
      let _ = self.advance()
    }
    if self.peek() == 46 { // .
      is_float = true
      let _ = self.advance()
      while is_hex_digit(self.peek()) {
        let _ = self.advance()
      }
    }
    if self.peek() == 112 || self.peek() == 80 {
      is_float = true
      let _ = self.advance()
      if self.peek() == 43 || self.peek() == 45 {
        let _ = self.advance()
      }
      while is_digit(self.peek()) {
        let _ = self.advance()
      }
    }
  } else {
    while is_digit(self.peek()) {
      let _ = self.advance()
    }
    if self.peek() == 46 {
      is_float = true
      let _ = self.advance()
      while is_digit(self.peek()) {
        let _ = self.advance()
      }
    }
    if self.peek() == 101 || self.peek() == 69 {
      is_float = true
      let _ = self.advance()
      if self.peek() == 43 || self.peek() == 45 {
        let _ = self.advance()
      }
      while is_digit(self.peek()) {
        let _ = self.advance()
      }
    }
  }
  let view = self.src[start:self.pos]
  if is_float {
    let v =
      try {
        @string.parse_double(view)
      } catch {
        _ => 0.0
      }
    LFloat(v)
  } else {
    let v =
      try {
        @string.parse_int(view, base=base)
      } catch {
        _ => 0
      }
    LInt(v)
  }
}

fn Lexer::read_string(self : Lexer, quote : UInt16) -> Result[String, String] {
  let _ = self.advance()
  let mut buf = ""
  while !self.eof() {
    let c = self.peek()
    if c == quote {
      let _ = self.advance()
      return Ok(buf)
    }
    if c == 10 {
      return Err("unfinished string")
    }
    if c == 92 { // backslash
      let _ = self.advance()
      let e = self.advance()
      buf = buf + decode_escape(e, self)
    } else {
      buf = buf + c.to_int().to_char().unwrap().to_string()
      let _ = self.advance()
    }
  }
  Err("unfinished string")
}

fn decode_escape(e : UInt16, lex : Lexer) -> String {
  match e {
    110 => "\n"   // n
    116 => "\t"   // t
    114 => "\r"   // r
    92 => "\\"    // \
    34 => "\""    // "
    39 => "'"     // '
    48 => {
      // \ddd decimal escape, up to 3 digits
      let mut n = 0
      for _ in 0..<2 {
        if is_digit(lex.peek()) {
          n = n * 10 + (lex.advance().to_int() - 48)
        } else {
          break
        }
      }
      (n % 256).to_char().unwrap().to_string()
    }
    120 => { // x
      let h1 = lex.advance()
      let h2 = lex.advance()
      let v = hex_val(h1) * 16 + hex_val(h2)
      (v % 256).to_char().unwrap().to_string()
    }
    other => other.to_int().to_char().unwrap().to_string()
  }
}

fn hex_val(c : UInt16) -> Int {
  if c >= 48 && c <= 57 {
    (c.to_int() - 48)
  } else if c >= 97 && c <= 102 {
    (c.to_int() - 97) + 10
  } else {
    (c.to_int() - 65) + 10
  }
}

fn keyword_kind(word : String) -> TokenKind? {
  match word {
    "and" => Some(KwAnd)
    "break" => Some(KwBreak)
    "do" => Some(KwDo)
    "else" => Some(KwElse)
    "elseif" => Some(KwElseif)
    "end" => Some(KwEnd)
    "false" => Some(KwFalse)
    "for" => Some(KwFor)
    "function" => Some(KwFunction)
    "if" => Some(KwIf)
    "in" => Some(KwIn)
    "local" => Some(KwLocal)
    "nil" => Some(KwNil)
    "not" => Some(KwNot)
    "or" => Some(KwOr)
    "repeat" => Some(KwRepeat)
    "return" => Some(KwReturn)
    "then" => Some(KwThen)
    "true" => Some(KwTrue)
    "until" => Some(KwUntil)
    "while" => Some(KwWhile)
    _ => None
  }
}

pub fn Lexer::tokenize(self : Lexer) -> Result[Array[Token], String] {
  let out : Array[Token] = []
  for ;; {
    self.skip_trivia()
    let line = self.line
    if self.eof() {
      out.push({ kind: Eof, line })
      return Ok(out)
    }
    let c = self.peek()
    let kind =
      if is_alpha(c) {
        let name = self.read_name()
        match keyword_kind(name) {
          Some(k) => k
          None => Name(name)
        }
      } else if is_digit(c) || (c == 46 && is_digit(self.peek_at(1))) {
        self.read_number()
      } else if c == 34 || c == 39 {
        match self.read_string(c) {
          Ok(s) => LStr(s)
          Err(e) => return Err(e)
        }
      } else if c == 91 && self.try_long_bracket() >= 0 {
        let lv = self.try_long_bracket()
        LStr(self.read_long_string(lv))
      } else {
        let _ = self.advance()
        match c {
          43 => OpAdd       // +
          45 => OpSub       // -
          42 => OpMul       // *
          47 => OpDiv       // /
          37 => OpMod       // %
          94 => OpPow       // ^
          35 => OpLen       // #
          40 => LParen      // (
          41 => RParen      // )
          123 => LBrace     // {
          125 => RBrace     // }
          91 => LBracket    // [
          93 => RBracket    // ]
          59 => Semicolon   // ;
          44 => Comma       // ,
          58 =>
            if self.peek() == 58 {
              let _ = self.advance()
              DoubleColon
            } else {
              Colon
            }
          61 =>
            if self.peek() == 61 {
              let _ = self.advance()
              OpEq
            } else {
              OpAssign
            }
          126 =>
            if self.peek() == 61 {
              let _ = self.advance()
              OpNeq
            } else {
              return Err("unexpected ~")
            }
          60 =>
            if self.peek() == 61 {
              let _ = self.advance()
              OpLe
            } else {
              OpLt
            }
          62 =>
            if self.peek() == 61 {
              let _ = self.advance()
              OpGe
            } else {
              OpGt
            }
          46 =>
            if self.peek() == 46 {
              let _ = self.advance()
              if self.peek() == 46 {
                let _ = self.advance()
                OpDots
              } else {
                OpConcat
              }
            } else {
              Dot
            }
          other => return Err("unexpected char code: \{other}")
        }
      }
    out.push({ kind, line })
  }
}

/// Codegen module.
module qdc.codegen;

import qdc.visitor;
import std.stdio;


/// Uncomment SSA.
/// Params:
///   s = a SSA code.
/// Returns:
///   the uncommented SSA code.
@safe string uncomment(string s) {
  import std.algorithm : filter, map;
  import std.string : join, lineSplitter, stripRight;
  return s.lineSplitter
      .map!(x => x.stripRight)
      .filter!(x => x != "" && x[0] != '#')
      .join("\n");
}

///
@safe unittest {
  assert(uncomment("#foo") == "", "Uncomment one line.");
  assert(uncomment("#foo\nbar") == "bar", "Uncomment two lines.");
  assert(`#INFO: object@
export function w $main(){
@start
  ret 0
}
#INFO: _d_cmain!()@test_main.d(1)
`.uncomment == `export function w $main(){
@start
  ret 0
}`, "Uncomment example.");
}

/// Generates QBE ssa from D.
/// Params:
///   dcode = a D code.
///   name = a module name.
/// Returns:
///   a generated QBE SSA code.
string codegen(string dcode, string name = "") {
  import dparse.lexer : getTokensForParser, LexerConfig, str, StringCache;
  import dparse.parser : parseModule;
  import dparse.rollback_allocator : RollbackAllocator;

  // Keep these for ownerships of tokens.
  scope RollbackAllocator rba;
  scope cache = StringCache(StringCache.defaultBucketCount);

  LexerConfig config;
  auto tokens = getTokensForParser(dcode, config, &cache);
  auto m = parseModule(tokens, name, &rba);

  auto visitor = new QbeVisitor;
  visitor.visit(m);
  return visitor.generate();
}

/// return 0 main
@system unittest {
  const actual = codegen(q{ int main() { return 0; } }, "test_main0.d");
  // writeln(actual);
  assert(actual.uncomment ==
`export function w $main(){
@start
  ret 0
}`, "main returns 0 codegen failed");
}

/// return 1 main
@system unittest {
  assert(codegen(q{ int main() { return 1; } }, "test_main1.d").uncomment ==
`export function w $main(){
@start
  ret 1
}`, "main returns 1 codegen failed");
}

/// return 1 + 2 main (CTFE)
@system unittest {
  assert(codegen(q{ int main() { return 1 + 2; } },
                 "test_main1_2.d").uncomment ==
`export function w $main(){
@start
  ret 3
}`, "main returns 1 + 2 codegen failed");
}

/// add a + b
@system unittest {
  const actual = codegen(
      q{ int add(int a, int b) { int c = a + b; return c; } }, "add.d");
  // writeln(actual);
  assert(actual.uncomment ==
`export function w $add(w %a, w %b){
@start
  %c =w add %a, %b
  ret %c
}`, "add codegen failed");
}

/// hello world
@system unittest {
  const actual = codegen(q{
      import core.stdc.stdio;

      int main()
      {
        printf("hello world\n");
        return 0;
      }
    }, "test_hello.d");
  const expected = `export function w $main(){
@start
  call $printf(l $str0, ...)
  ret 0
}
data $str0 = { b "hello world\n", b 0 }`;
  assert(actual.uncomment == expected, "hello world codegen failed.");
}

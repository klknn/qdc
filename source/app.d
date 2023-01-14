/// Main entry point.
module app;

import qdc.codegen : codegen;

import std.file : readText;
import std.stdio : writeln;


/// Main func.
/// Params:
///   args = command line args.
/// Returns:
///   an exit status code.
int main(string[] args)
{
  // parse args
  if (args.length != 2)
  {
    writeln("usage: ", args[0], " <input.d>");
    return 1;
  }
  string srcPath = args[1];
  writeln(codegen(readText(srcPath), srcPath));
  return 0;
}

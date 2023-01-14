/// Visitor module.
module qdc.visitor;

import dparse.ast;
import dparse.lexer;
import std.conv : to;
import std.range : empty;
import std.stdio : writeln;

/// QBE SSA generator.
class QbeVisitor : ASTVisitor {
  alias visit = ASTVisitor.visit;

  override void visit(const Token token) {
    switch (token.type) {
      case tok!"intLiteral":
        ssa ~= token.text;
        return;
      case tok!"stringLiteral":
        ssa ~= "l $str" ~ this.strData.length.to!string;
        this.strData ~= token.text;
        return;
      case tok!"identifier":
        ssa ~= (this.funcname ? "$" : "%") ~ token.text;
        return;
      default:
        assert(false, "Unknown token: " ~ str(token.type));
    }
  }

  override void visit(const AddExpression addExpression) {
    // Run CTFE for int + int if possible.
    if (auto left = cast(UnaryExpression) addExpression.left) {
      if (auto right = cast(UnaryExpression) addExpression.right) {
        auto lp = left.primaryExpression;
        auto rp = right.primaryExpression;
        if (lp !is null && lp.primary.type == tok!"intLiteral" &&
            rp !is null && rp.primary.type == tok!"intLiteral") {
          ssa ~= to!string(lp.primary.text.to!int + rp.primary.text.to!int);
          return;
        }
      }
    }

    ssa ~= "add ";
    visit(addExpression.left);
    ssa ~= ", ";
    visit(addExpression.right);
  }

  /// Converts builtin type to QBE type.
  override void visit(const Type2 type2) {
    switch (type2.builtinType) {
    case tok!"int":
      ssa ~= "w";
      return;
    default:
      assert(false, "Not implemented: " ~ str(type2.builtinType));
    }
  }

  // e.g. call $printf(l $str0, ...)
  override void visit(const FunctionCallExpression callExpression) {
    ssa ~= "  call ";
    this.funcname = true;
    visit(callExpression.unaryExpression);
    this.funcname = false;
    ssa ~= "(";
    visit(callExpression.arguments);
    // TODO: detect varargs.
    ssa ~= ", ...)";
    ssa ~= "\n";
  }

  override void visit(const ReturnStatement returnStatement) {
    ssa ~= "  ret ";
    visit(returnStatement.expression);
    ssa ~= "\n";
  }

  override void visit(const Parameter parameter) {
    assert(!parameter.vararg, "Vararg is not implemented.");
    visit(parameter.type);
    ssa ~= " ";
    visit(parameter.name);
  }

  override void visit(const Parameters parameters) {
    assert(!parameters.hasVarargs, "Varargs is not implemented.");
    ssa ~= "(";
    foreach (i, param; parameters.parameters) {
      visit(param);
      if (i + 1 != parameters.parameters.length) {
        ssa ~= ", ";
      }
    }
    ssa ~= ")";
  }

  override void visit(const ImportDeclaration importDeclaration) {
    // TODO
  }

  override void visit(const VariableDeclaration variableDeclaration) {
    foreach (decl; variableDeclaration.declarators) {
      ssa ~= "  ";
      visit(decl.name);
      ssa ~= " =";
      visit(variableDeclaration.type);
      ssa ~= " ";
      visit(decl.initializer);
      ssa ~= "\n";
    }
  }

  override void visit(const FunctionBody functionBody) {
    ssa ~= "{\n@start\n";
    functionBody.accept(this);
    ssa ~= "}";
  }

  override void visit(const FunctionDeclaration functionDeclaration) {
    ssa ~= "export function ";
    visit(functionDeclaration.returnType);
    ssa ~= " $" ~ functionDeclaration.name.text;
    visit(functionDeclaration.parameters);
    visit(functionDeclaration.functionBody);
  }

  /// Generates QBE SSA code.
  string generate() {
    string dataSection;
    foreach (i, str; strData) {
      dataSection ~= "data $str" ~ i.to!string
          ~ " = { b " ~ escape(str) ~ ", b 0 }";
    }
    return ssa ~ "\n" ~ dataSection;
  }

 private:
  string ssa;
  bool funcname = false;
  string[] strData;
}

/// Escapes control chars from string.
/// Params:
///   s = an input string.
/// Returns:
///   an escaped string.
nothrow pure @safe
string escape(string s) {
  import std.ascii : ControlChar, isControl;
  import std.string : replace;
  // TODO: support all control chars
  foreach (c; s) {
    if (isControl(c)) {
      switch (c) {
        case ControlChar.lf:
          break;
        default:
          assert(false, "unsupported control char: " ~ s);
      }
    }
  }
  return s.replace("\n", "\\n");
}

///
@safe unittest {
  assert(escape("hello\n") == "hello\\n", "\\n escape failed.");
}

# converts tokens into an AST

include("./lexer.jl")

using CombinedParsers

code = """
10 INPUT"YES OR NO";A\$
20 IF A\$ = "YES" THEN 50
30 IF A\$ = "NO" THEN 60 40 PRINT"YOU MUST ENTER YES OR NO.":GOTO 10
50 PRINT"GREAT!":END
60 PRINT"WHY NOT?":END
"""

for tok in Lex(code)
    println(tok)
end

#=
Grammar:

Program = Linelabel + Statement + (":" Statement)* + "\n"

Statement =
    | Assignment
    | Jump
    | "END"

Assignment = "LET"? Identifier "=" Expression

Jump = "GO" ("SUB" | "TO") Number

# Expressions with precedence
Expression = 
    | "(" Expression ")"
    | Function
    | Expr7

# yeah, 7 function calls just to parse a literal is definitely inefficient,
# but this method is simple, and inlining should help with performance

Expr7 = Expr6 ("OR" Expr6)?

Expr6 = Expr5 ("AND" Expr5)?

Expr5 = "NOT"? Expr4

Expr4 = Expr3 (("=" | "<>" | "<" | "<=" | ">" | ">=") Expr3)*

Expr3 = Expr2 (("+" | "-") Expr2)*

Expr2 = Expr1 (("*" | "/" | "^") Expr1)*

Expr1 = ("-" | "+")? Literal

Literal = Number | String

Function = Identifier Args? # covers function calls, array accesses, and variables

Args = "(" (Expression ",")* ")"

=#



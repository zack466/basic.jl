# converts tokens into an AST
#
include("./lexer.jl")
using .Lexing

code = """
10 PRINT "Hello, world!"
"""

for tok in Lex(code)
    println(tok)
end

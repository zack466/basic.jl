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

abstract type ASTNode end

struct BinOp <: ASTNode
    left::ASTNode
    right::ASTNode
    op::Symbol
end

struct Assignment <: ASTNode
    identifier
    value
end

struct Jump <: ASTNode
    linelabel
end

struct Program
    map::Dict{Int, ASTNode}
end

struct End <: ASTNode end

struct Print <: ASTNode
    expr
end

#=
Grammar:

Program = Linelabel + Statement + (":" Statement)* + "\n"

Linelabel = Number

Statement =
    | Assignment
    | Jump
    | "PRINT" Expression
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

struct ErrorStatus
    msg
end

mutable struct ParseState
    tokens::Vector{Token}
    pos::Int = 1
end

function next(state::ParseState)::Union{Token, Nothing}
    if state.pos > length(state.tokens)
        return nothing
    else
        tok = state.tokens[state.pos]
        state.pos += 1
        return tok
    end
end

function peek(state::ParseState)::Union{Token, Nothing}
    if state.pos > length(state.tokens)
        return nothing
    else
        return state.tokens[state.pos]
    end
end

function peek(state::ParseState, type::Symbol)::Bool
    next = peek(state)
    return next != nothing && next.token_type == type
end

function expect(state::ParseState, type::Symbol)::Union{Token, Nothing}
    if state.pos > length(state.tokens)
        error("Ran out of tokens, expected $type")
    else
        tok = state.tokens[state.pos]
        if tok.token_type != type
            error("Unexpected token $tok, expected $type")
        else
            return next(state)
        end
    end
end

function parse_program(tokens)::Program
    map = Dict{Int, ASTNode}()
    state = ParseState(tokens)

    return Program(map)
end

function parse_linelabel(state::ParseState)
    tok = expect(state, :Number)
    return tok.value
end

function parse_statement(state)
    tok = peek(state)
    if tok.token_type == :END
        next(state)
        return End()
    elseif tok.token_type == :PRINT
        next(state)
        expr = parse_expression(state)
        return Print(expr)
    else
        error("Not implemented yet (or error)")
    end
end

function parse_expression(state)
    tok = peek(state)
    if tok.token_type == Symbol("(")
        next(state)
        expr = parse_expression(state)
        expect(state, Symbol(")"))
        return expr
    elseif tok.token_type == :IDENTIFIER
        expr = parse_function(state)
        return expr
    else
        expr = parse_expr7(state)
        return expr
    end
    error("Error parsing expression")
end

function parse_expr7(state)
    expr = parse_expr6(state)
    while peek(state, :OR)
        right = parse_expr6(state)
        expr = BinOp(expr, right, :OR)
    end
    return expr
end

function parse_expr6(state)
    expr = parse_expr5(state)
    while peek(state, :AND)
        right = parse_expr5(state)
        expr = BinOp(expr, right, :AND)
    end
    return expr
end

function parse_expr5(state)
end

function parse_expr4(state)
end

function parse_expr3(state)
end

function parse_expr2(state)
end

function parse_expr1(state)
end

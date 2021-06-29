using Logging

regexes = [
    (r"^\+\+", :CONCAT),
    (r"^&&", :AND),
    (r"^\|\|", :OR),
    (r"^\+", :PLUS),
    (r"^-", :MINUS),
    (r"^!", :NOT),
    (r"^\*", :TIMES),
    (r"^/", :DIVIDE),
    (r"^==", :EQUALS),
    (r"^=", :EQUAL),
    (r"^\)", :RPAREN),
    (r"^\(", :LPAREN),
    (r"^([0-9]+)", :INT),
    (r"^(([\"'`])(?:[\s\S])*?(?:(?<!\\)\2))", :STRING),
    (r"^#t", :TRUE),
    (r"^#f", :FALSE),
    (r"^\n", :NEWLINE),
    (r"^\\(?![a-zA-Z])", :BACKSLASH),
    (r"^IF(?![a-zA-Z])", :IF),
    (r"^THEN(?![a-zA-Z])", :THEN),
    (r"^ELSE(?![a-zA-Z])", :ELSE),
    (r"^PRINT(?![a-zA-Z])", :PRINT),
    (r"^GOTO(?![a-zA-Z])", :GOTO),
    (r"^EXIT(?![a-zA-Z])", :EXIT),
    (r"^LET(?![a-zA-Z])", :LET),
    (r"^([a-zA-Z]+)", :IDENTIFIER),
]

const whitespace = r"^ +"

struct Token
    token_type
    match::Union{Nothing, SubString{String}}
end

function lex(str)
    for (r, s) in regexes
        m = match(r, str);
        if m != nothing
            if length(m.captures) != 0
                return Token(s, m.captures[1]), length(m.match)
            else
                return Token(s, nothing), length(m.match)
            end
        end
    end
    return nothing, 0
end

function ignore_whitespace(str)
    m = match(whitespace, str)
    if (m == nothing)
        return str;
    else
        return str[length(m.match) + 1:end]
    end
end

function tokenize(str)
    curr = str
    tokens::Vector{Token} = []
    while length(curr) != 0
        token, l = lex(curr)
        if l == 0
            break
        end
        push!(tokens, token)
        curr = curr[l+1:end]
        curr = ignore_whitespace(curr)
    end
    return tokens
end

# line# = int
# statement = 
#   | PRINT expr
#   | IF expr THEN expr (ELSE expr)?
#   | GOTO line#
#   | LET identifier = expr

function expect(token_type, tokens)
    @debug "Expect: ", token_type, tokens
    if length(tokens) == 0
        error("Expected $token_type, ran out of tokens")
    end
    if token_type != tokens[1].token_type
        error("Expected $token_type, got $tokens[1]")
    end
    return tokens[1], tokens[2:end]
end

# primary =
#   | identifier
#   | string
#   | int
#   | boolean
#   | ( expr )

function parse_primary(tokens)
    tok = tokens[1]
    if tok.token_type == :IDENTIFIER
        name = String(tok.match)
        return Symbol(name), tokens[2:end]
    elseif tok.token_type == :STRING
        return String(tok.match[2:end-1]), tokens[2:end]
    elseif tok.token_type == :INT
        return parse(Int, tok.match), tokens[2:end]
    elseif tok.token_type == :TRUE
        return true, tokens[2:end]
    elseif tok.token_type == :FALSE
        return false, tokens[2:end]
    elseif tok.token_type == :LPAREN
        expr, tokens = parse_expr(tokens[2:end])
        tok, tokens = expect(:RPAREN, tokens)
        return expr, tokens
    else
        error("Unable to parse $tok")
    end
end

# unary = 
#   | - primary
#   | ! primary
#   | primary
function parse_unary(tokens)
    @debug "Unary: ", tokens
    if tokens[1].token_type == :MINUS
        tokens = tokens[2:end]
        expr, tokens = parse_primary(tokens)
        return Meta.Expr(:call, :-, expr), tokens
    elseif tokens[1].token_type == :NOT
        tokens = tokens[2:end]
        expr, tokens = parse_primary(tokens)
        return Meta.Expr(:call, :!, expr), tokens
    else
        expr, tokens = parse_primary(tokens)
        return expr, tokens
    end
end

# expr =
#   | unary ((+ | - | * | / | ++) unary)*

function parse_expr(tokens)
    @debug "Expr: ", tokens
    expr, tokens = parse_unary(tokens)
    if length(tokens) == 0
        return expr, tokens
    end
    if tokens[1].token_type == :PLUS
        tokens = tokens[2:end]
        expr2, tokens = parse_expr(tokens)
        return Meta.Expr(:call, :+, expr, expr2), tokens
    elseif tokens[1].token_type == :MINUS
        tokens = tokens[2:end]
        expr2, tokens = parse_expr(tokens)
        return Meta.Expr(:call, :-, expr, expr2), tokens
    elseif tokens[1].token_type == :TIMES
        tokens = tokens[2:end]
        expr2, tokens = parse_expr(tokens)
        return Meta.Expr(:call, :*, expr, expr2), tokens
    elseif tokens[1].token_type == :DIVIDE
        tokens = tokens[2:end]
        expr2, tokens = parse_expr(tokens)
        return Meta.Expr(:call, :/, expr, expr2), tokens
    elseif tokens[1].token_type == :CONCAT
        tokens = tokens[2:end]
        expr2, tokens = parse_expr(tokens)
        return Meta.Expr(:call, :*, expr, expr2), tokens
    end
    return expr, tokens
end

# comparison = expr ((< | > | == | !=) expr)*

function parse_comparision()
end

function parse_statement(tokens)
    if length(tokens) == 0
        error("Ran out of tokens while parsing statement")
    end
    @debug "Statement: ", tokens
    if tokens[1].token_type == :PRINT
        expr, tokens = parse_expr(tokens[2:end])
        print_expr = Meta.Expr(:call, print, expr, "\n")
        return print_expr, tokens
    elseif tokens[1].token_type == :LET
        tok, tokens = expect(:IDENTIFIER, tokens[2:end])
        identifier = Symbol(tok.match)
        _, tokens = expect(:EQUAL, tokens)
        expr, tokens = parse_expr(tokens)
        assignment_expr = Meta.Expr(:(=), identifier, expr)
        return assignment_expr, tokens
    elseif tokens[1].token_type == :IF
    elseif tokens[1].token_type == :GOTO
        tok, tokens = expect(:INT, tokens[2:end])
        line = parse(Int, tok.match)
        expr = Meta.Expr(:call, :setIP, line)
        return expr, tokens
    elseif tokens[1].token_type == :EXIT
        expr = Meta.Expr(:call, :setIP, -1)
        return expr, tokens[2:end]
    end
end

# line = line_label statement (BACKSLASH statement)* newline

function parse_line(tokens)
    tok, tokens = expect(:INT, tokens)
    line_number = parse(Int, tok.match)
    total_expr, tokens = parse_statement(tokens)
    while tokens[1].token_type == :BACKSLASH
        expr, tokens = parse_statement(tokens[2:end])
        total_expr = Meta.Expr(:block, total_expr, expr)
    end
    _, tokens = expect(:NEWLINE, tokens)
    return line_number, total_expr, tokens
end

function parse_program(tokens)
    curr = tokens;
    program::Vector{Tuple{Union{Int, String}, Expr}} = [];
    mapping::Dict{Union{Int, String}, Int} = Dict(); # maps line number/label to index of expr
    entry = nothing;
    while length(curr) > 0
        line, expr, curr = parse_line(curr)
        if entry == nothing
            entry = line
        end
        push!(program, (line, expr))
        mapping[line] = length(program)
    end
    mapping[-1] = length(program) + 1 # GOTO -1 to quit
    return entry, program, mapping
end

IP = nothing

function setIP(x)
    global IP = x;
end

function interpret(str)
    tokens = tokenize(str)
    @debug tokens
    entry, program, mapping = parse_program(tokens)
    global IP = entry # initial instruction pointer
    program_idx = mapping[IP]
    while program_idx <= length(program)
        IP = nothing;
        line, expr = program[program_idx]
        @debug "Line: ", line, expr
        eval(expr)
        if IP == nothing # not a GOTO
            program_idx += 1
        else
            program_idx = mapping[IP]
        end
    end
end

function run(str)
    open(str) do f
        interpret(read(f, String))
    end
end

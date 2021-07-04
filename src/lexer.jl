# use parser combinators for clean and modular lexing

using CombinedParsers
using CombinedParsers.Regexp

struct LexOptions
    # Requires spaces between keywords
    # True in ANSI BASIC spec, but not Vintage BASIC
    require_spaces::Bool
    caseless_keywords::Bool
end

struct Token
    token_type::Symbol
    value::Any
end

@syntax parseNumber = map(Numeric(Float64)) do num
    Token(:Number, num)
end

@syntax parseString = map(Sequence(
    CharIn("\""),
    !Repeat(CharNotIn("\"")),
    CharIn("\""),
)) do str
    Token(:String, str[2])
end

@syntax parseIdentifier = map(!Sequence(
    Repeat( CharIn('a':'z', 'A':'Z', '0':'9'), min=1),
    Either("\$", "%", "") # type declaration: $ = string, % = integer
)) do id
    Token(:Identifier, id)
end

# each keyword corresponds with a symbol :UPPER
keywords = [
    "INPUT",
    "IF",
    "THEN",
    "PRINT",
    "GOTO",
    "END",
    "(",
    ")",
    ",",
    ":",
    ";",
    "-",
    "+",
    "*",
    "^", # exp
    "/",
    "=", # equality test
    "<>", # inequality test
    "<=",
    ">=",
    "<",
    ">",
    "NOT",
    "AND",
    "OR",
]

# uppercase keywords only, does not require whitespace after keyword
@syntax parseKeywordSpacelessUpper = map(!Either(keywords)) do kw
    Token(Symbol(kw), nothing)
end
# case insensitive keywords, does not require whitespace after keyword
@syntax parseKeywordSpacelessCaseless = map(
    !mapreduce(caseless, |, keywords)
) do kw
    Token(Symbol(uppercase(kw)), nothing)
end

# uppercase keywords only, requires whitespace after keyword
@syntax parseKeywordUpper = map(Sequence(!Either(keywords), PositiveLookahead(re"\s"))) do kw
    Token(Symbol(kw[1]), nothing)
end

# case insensitive keywords, requires whitespace after keyword
@syntax parseKeywordCaseless = map(
    Sequence(!mapreduce(caseless, |, keywords), PositiveLookahead(re"\s"))
) do kw
    Token(Symbol(uppercase(kw[1])), nothing)
end

@syntax parseToken = map(Sequence(Optional(whitespace_newline), Either(parseNumber, parseString, parseKeywordSpacelessCaseless, parseIdentifier))) do r
    r[2]
end

mutable struct Lex
    source::String
end

function Base.iterate(lex::Lex)
    if length(lex.source) == 0
        return nothing
    end
    res = tryparse_pos(parseToken, lex.source)
    if res == nothing
        error("Invalid token at $(lex.source)")
    else
        return res
    end
end

function Base.iterate(lex::Lex, idx::Int64)
    if idx > length(lex.source)
        return nothing
    end
    res = tryparse_pos(parseToken, @view lex.source[idx:end])
    if res == nothing
        error("Invalid token at $(lex.source[idx:end])")
    else
        tok, len = res
        return tok, len + idx - 1
    end
end

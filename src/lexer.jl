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
    "NOT",
    "AND",
    "OR",
]

operators = [
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
]

# spaceless: does not require whitespace after word
# caseless: keywords are space-insensitive
function parseWords(words; spaceless=true, caseless=true)
    if spaceless && caseless
        p = map(
            !mapreduce(caseless, |, words)
        ) do kw
            Token(Symbol(uppercase(kw)), nothing)
        end
    elseif spaceless && !caseless
        p = map(!Either(words)) do kw
            Token(Symbol(kw), nothing)
        end
    elseif !spaceless && caseless
        p = map(
            Sequence(!mapreduce(caseless, |, words), PositiveLookahead(re"\s"))
        ) do kw
            Token(Symbol(uppercase(kw[1])), nothing)
        end
    else
        p = map(Sequence(!Either(words), PositiveLookahead(re"\s"))) do kw
            Token(Symbol(kw[1]), nothing)
        end
    end
end

@syntax parseNewline = map(whitespace_newline) do n
    Token(:Newline, nothing)
end

@syntax parseToken = map(Sequence(
    Optional(Regexp.whitespace_horizontal),
    Either(
        parseNewline,
        parseNumber,
        parseString,
        parseWords(keywords, spaceless=false, caseless=false),
        parseWords(operators, spaceless=true, caseless=false),
        parseIdentifier
    ))) do r
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

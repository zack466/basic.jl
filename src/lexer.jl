# use parser combinators for clean and modular lexing

using CombinedParsers
using CombinedParsers.Regexp

struct LexOptions
    # Requires spaces between keywords
    # True in ANSI BASIC spec, but not Vintage BASIC
    require_spaces::Bool
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
    Repeat( CharIn('a':'z', 'A':'Z', '0':'9')),
    Either("\$", "%", "") # type declaration: $ = string, % = integer
)) do id
    Token(:Identifier, id)
end

keywords = [
    "INPUT",
    "IF",
    "THEN",
    "PRINT",
    "GOTO",
    "END",
]

@syntax parseKeyword = map(!Either(keywords)) do kw
    Token(Symbol(kw), nothing)
end


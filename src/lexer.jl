# use parser combinators for clean and modular lexing

using CombinedParsers

struct LexOptions
    # Requires spaces between keywords
    # True in ANSI BASIC spec, but not Vintage BASIC
    require_spaces::Boolean 
end

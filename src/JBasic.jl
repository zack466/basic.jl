module JBasic

include("./parse.jl")

IP = nothing
function setIP(x)
    global IP = x;
end

# a clean namespace to evaluate Exprs in
# (with the exception of setIP, but that's ok)
module BASIC

import ..JBasic: setIP
basic_eval(e) = eval(e);

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
        BASIC.basic_eval(expr)
        if IP == nothing # not a GOTO
            program_idx += 1
        else
            program_idx = mapping[IP]
        end
    end
end

macro basic_str(program::String)
    interpret(program)
end

function runfile(str)
    open(str) do f
        interpret(read(f, String))
    end
end

export BASIC
export @basic_str
export runfile

end # module

# A BASIC implemented in Julia

# Stage 1 (Complete):
- Uses a simple regex parser and a recursive descent parser to build up a Julia AST 
- Ex: `PRINT (2 + 2)` is transpiled into `Meta.Expr(:call, :print, Meta.expr(:call, :+, 2, 2))`
- The Julia Exprs are then `eval`ed line by line
- All of the code can be found in `src/basic1.jl`

# Stage 2 (In Progress):
- Uses parser combinators for "cleaner" lexing, along with a recursive descent parser
- Builds up a concrete Abstract Syntax Tree (AST) using structs instead of Julia's built-in AST
- Then, the AST will simply be tree-walked to execute the code

# Stage 3 (In Progress):
- Instead of interpreting the AST, bytecode will be emitted for a more efficient representation of the BASIC code, to be interpreted by a VM

## Inspiration
- [Crafting Interpreters](https://craftinginterpreters.com/) by Bob Nystrom

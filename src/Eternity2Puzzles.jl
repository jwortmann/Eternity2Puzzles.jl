module Eternity2Puzzles

import DelimitedFiles
import PNGFiles
import Random
using BitIntegers: UInt256
using Colors: @colorant_str
using Colors: distinguishable_colors
using Colors: RGBA
using FixedPointNumbers: N0f8
using FixedSizeArrays
using PrecompileTools: @compile_workload
using Printf: @printf
using Quadmath: Float128
using Scratch: @get_scratch!
using ZeroOrigin: @origin

export Eternity2Puzzle
export Eternity2Solver
export SimpleBacktrackingSearch
export E2BacktrackingSearch
export E2BacktrackingSearch2x2
export estimate_solutions
export play!
export preview
export solve!
export reset!
export load!
export save


const BOARD_BACKGROUND_IMG = PNGFiles.load(normpath("$(@__FILE__)/../../assets/textures/board.png"))
const COLOR_PATTERNS_IMG = PNGFiles.load(normpath("$(@__FILE__)/../../assets/textures/colors.png"))


include("core.jl")
include("solvers/simple_backtracking.jl")
include("solvers/e2_backtracking.jl")
include("solvers/e2_backtracking_2x2.jl")
include("gui.jl")


"""
    solve!(puzzle::Eternity2Puzzle)
    solve!(puzzle::Eternity2Puzzle; alg::Eternity2Solver)

Start to search for a solution of the given [`Eternity2Puzzle`](@ref).

# Examples

```julia-repl
julia> puzzle = Eternity2Puzzle()

julia> solve!(puzzle)
```
"""
function solve!(
    puzzle::Eternity2Puzzle;
    alg::Union{Eternity2Solver, Nothing} = nothing
)
    t0 = time()

    if isnothing(alg)
        seed = floor(Int, 1000 * t0)
        alg = if size(puzzle) == (16, 16) && puzzle["I8"] == (139, 2)
            E2BacktrackingSearch(target_score=460, seed=seed)
        else
            SimpleBacktrackingSearch(seed=seed)
        end
    end

    try
        @time solve!(puzzle, alg)
        return puzzle
    catch ex
        elapsed_time = round(time() - t0, digits=1)
        if ex isa InterruptException
            println("Search aborted after $elapsed_time seconds")
        else
            showerror(stdout, ex, catch_backtrace())
        end
    end
    nothing
end


@compile_workload begin
    puzzle = Eternity2Puzzle(3, 3)
    estimate_solutions(puzzle)
end

end

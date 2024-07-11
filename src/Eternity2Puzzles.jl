module Eternity2Puzzles

using Colors
import DelimitedFiles
import GameZero
import PNGFiles
using Random
using Scratch: @get_scratch!

export Eternity2Puzzle
export Eternity2Solver
export BacktrackingSearch
export BacktrackingSearchRecursive
export initialize_pieces
export generate_pieces
export play
export preview
export solve!
export reset!
export load!
export save


include("core.jl")
include("solvers/backtracking.jl")
include("solvers/backtracking_recursive.jl")


"""
    play()

Start the interactive game.
"""
function play(puzzle::Eternity2Puzzle = Eternity2Puzzle(16, 16))
    save(puzzle, joinpath(@get_scratch!("eternity2"), "board.et2"))
    _project = Base.active_project()
    Base.set_active_project(abspath(@__DIR__, "..", "Project.toml"))
    GameZero.rungame(joinpath(@__DIR__, "eternity2.jl"))
    Base.set_active_project(_project)
    nothing
end


"""
    solve!(puzzle::Eternity2Puzzle)
    solve!(puzzle::Eternity2Puzzle; alg::Eternity2Solver)

Start to search for a solution of the given [`Eternity2Puzzle`](@ref).

# Examples

```julia
julia> puzzle = Eternity2Puzzle(16, 16)

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
        alg = if size(puzzle) == (16, 16) && puzzle[9, 8] == (STARTER_PIECE, 2)
            # BacktrackingSearch(target_score=471, seed=seed)
            BacktrackingSearch(target_score=460, seed=seed)
        else
            BacktrackingSearchRecursive(seed)
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

end

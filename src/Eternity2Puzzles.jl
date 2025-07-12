module Eternity2Puzzles

using Colors
import DelimitedFiles
using FixedSizeArrays
import GameZero
import NativeFileDialog
import OffsetArrays
import PNGFiles
using Printf: @printf
using Quadmath: Float128
import Random
using Scratch: @get_scratch!

export Eternity2Puzzle
export Eternity2Solver
export SimpleBacktrackingSearch
export HeuristicBacktrackingSearch
export estimate_solutions
export play
export preview
export solve!
export reset!
export load!
export save


include("core.jl")
include("solvers/simple_backtracking.jl")
include("solvers/heuristic_backtracking.jl")


"""
    play()
    play(:clue1)
    play(:clue2)
    play(:clue4)

Start the interactive game.
"""
function play(puzzle::Eternity2Puzzle)
    nrows, ncols = size(puzzle.board)
    @assert (nrows, ncols) in ((16, 16), (6, 12), (6, 6)) "Incompatible board size"
    @assert size(puzzle.pieces, 1) == nrows * ncols "Wrong number of pieces"
    cache_path = @get_scratch!("eternity2")
    save(puzzle, joinpath(cache_path, "board.et2"))
    open(joinpath(cache_path, "pieces.txt"), "w") do file
        write(file, join([join([col for col in row], " ") for row in eachrow(puzzle.pieces)], "\n") * "\n")
    end
    _project = Base.active_project()
    Base.set_active_project(abspath(@__DIR__, "..", "Project.toml"))
    GameZero.rungame(joinpath(@__DIR__, "eternity2.jl"))
    Base.set_active_project(_project)
    nothing
end

play() = play(Eternity2Puzzle())
play(puzzle::Symbol) = play(Eternity2Puzzle(puzzle))


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
        alg = if size(puzzle) == (16, 16) && puzzle[9, 8] == (STARTER_PIECE, 2)
            HeuristicBacktrackingSearch(target_score=460, seed=seed)
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

end

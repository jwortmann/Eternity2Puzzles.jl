"""
    SimpleBacktrackingSearch()
    SimpleBacktrackingSearch(; seed::Int=1, exhaustive_search::Bool=false)

A simple backtracking search that can be used with arbitrary board sizes. Pre-placed pieces
on the board are considered to be additional constraints for a valid solution. This search
algorithm places pieces one after another onto the board and backtracks if no more matching
piece can be placed. Pieces are only placed if all edges match exactly. The algorithm stops
when a solution is found, or if the entire search space is exhausted.

# Examples

```julia-repl
julia> puzzle = Eternity2Puzzle(:clue1)
6×6 Eternity2Puzzle with 0 pieces:
...

julia> solve!(puzzle; alg=SimpleBacktrackingSearch())
6×6 Eternity2Puzzle with 36 pieces, 60 matching edges and 0 errors:
  26/1  28/1  31/1  10/1  13/1  14/2
  12/0   4/3  29/2   2/2  24/1   7/2
  18/0   8/2   5/2  32/0   1/3  11/2
  16/0  27/1  33/0  30/2   3/1  21/2
  20/0  35/1   6/2  19/3   9/2  25/2
  34/0  15/3  17/3  23/3  22/3  36/3

julia> preview(puzzle)
```
"""
@kwdef struct SimpleBacktrackingSearch <: Eternity2Solver
    seed::Int = 1
    exhaustive_search::Bool = false
end


function solve!(puzzle::Eternity2Puzzle, solver::SimpleBacktrackingSearch)
    @info "Parameters" solver.seed
    Random.seed!(solver.seed)

    nrows, ncols = size(puzzle)
    npieces = size(puzzle.pieces, 1)
    ncolors = border_color = length(unique(puzzle.pieces))
    maxdepth = nrows * ncols

    @assert npieces >= nrows * ncols "Number of pieces is incompatible with the board dimensions"

    pieces, frame_colors_range, inner_colors_range = remap_piece_colors(puzzle)

    frame_colors = length(frame_colors_range)
    inner_colors = length(inner_colors_range)

    fixed_pieces = count(!iszero, puzzle.board)
    symmetries = symmetry_factor(puzzle)

    @info "Properties" frame_colors inner_colors fixed_pieces symmetries

    colors = FixedSizeMatrix{UInt8}(undef, npieces << 2 | 3, 2)
    colors[0x0001, :] .= border_color
    colors[0x0002, :] .= border_color + 1

    for (piece, piece_colors) in enumerate(eachrow(pieces)), rotation = 0:3, side = 1:2
        colors[piece << 2 | rotation, side] = piece_colors[mod1(side - rotation, 4)]
    end

    available = FixedSizeVector{Bool}(undef, npieces)
    fill!(available, true)
    available[filter(!iszero, puzzle.board .>> 2)] .= false

    constraints = NTuple{2, UInt8}[(0x00, 0x00)]
    rowcol = FixedSizeVector{NTuple{3, Int}}(undef, maxdepth)
    depth = fixed_pieces + 1
    for row = nrows:-1:1, col = 1:ncols
        iszero(puzzle.board[row, col]) || continue
        top = 0x00
        right = 0x00
        if row > 1
            piece, rotation = puzzle[row-1, col]
            if !iszero(piece)
                top = pieces[piece, mod1(3 - rotation, 4)]
            end
        end
        if col < ncols
            piece, rotation = puzzle[row, col+1]
            if !iszero(piece)
                right = pieces[piece, 4 - rotation]
            end
        end
        constraint = findfirst(isequal((top, right)), constraints)
        if isnothing(constraint)
            push!(constraints, (top, right))
            constraint = length(constraints)
        end
        rowcol[depth] = (row, col+1, constraint)
        depth += 1
    end
    nconstraints = length(constraints)

    _candidates = [UInt16[] for _ in 1:ncolors+1, _ in 1:ncolors+1, _ in 1:nconstraints]
    for (piece, piece_colors) in enumerate(eachrow(pieces)), rotation = 0:3
        top, right, bottom, left = circshift(piece_colors, rotation)
        for (constraint, (t, r)) in enumerate(constraints)
            if (t == 0 || t == top) && (r == 0 || r == right)
                push!(_candidates[bottom, left, constraint], piece << 2 | rotation)
            end
        end
    end
    for idx in eachindex(_candidates)
        if length(_candidates[idx]) > 1
            Random.shuffle!(_candidates[idx])
        end
    end
    candidates = FixedSizeVector{UInt16}(undef, mapreduce(length, +, _candidates))
    index_table = FixedSizeArray{UnitRange{Int}}(undef, ncolors+1, ncolors+1, nconstraints)
    idx = 1
    for constraint = 1:nconstraints, left = 1:ncolors+1, bottom = 1:ncolors+1
        start_idx = idx
        for candidate in _candidates[bottom, left, constraint]
            candidates[idx] = candidate
            idx += 1
        end
        end_idx = idx - 1
        index_table[bottom, left, constraint] = start_idx:end_idx
    end

    board = FixedSizeMatrix{UInt16}(undef, nrows+1, ncols+1)
    fill!(board, 0x0002)
    board[2:end-2, 1] .= 0x0001
    board[end, 3:end-1] .= 0x0001
    board[1:end-1, 2:end] = puzzle.board

    idx_range = FixedSizeVector{UnitRange{Int}}(undef, maxdepth)

    depth = fixed_pieces + 1
    best_depth = fixed_pieces
    row, col, constraint = rowcol[depth]
    _idx_range = index_table[colors[board[row+1, col], 1], colors[board[row, col-1], 2], constraint]

    iters = 0
    solutions = 0

    _print_progress(puzzle; clear=false)

    @inbounds while true
        @label next
        for idx in _idx_range
            candidate = candidates[idx]
            available[candidate >> 2] || continue
            board[row, col] = candidate
            iters += 1
            if depth > best_depth
                best_depth = depth
                puzzle.board[:, :] = board[1:end-1, 2:end]
                _print_progress(puzzle, iters)
                if depth == maxdepth
                    if solver.exhaustive_search
                        best_depth -= 1
                        solutions += 1
                        _print_progress(puzzle, iters, 0, solutions; clear=false)
                        continue
                    else
                        @info "Solution found after $iters iterations"
                        return
                    end
                end
            end
            available[candidate >> 2] = false
            idx_range[depth] = idx+1:_idx_range.stop
            depth += 1
            row, col, constraint = rowcol[depth]
            bottom = colors[board[row+1, col], 1]
            left = colors[board[row, col-1], 2]
            _idx_range = index_table[bottom, left, constraint]
            @goto next
        end
        depth -= 1
        if depth == fixed_pieces
            if solver.exhaustive_search
                @info "Search finished after $iters iterations with $solutions solutions"
            else
                @warn "Search finished after $iters iterations with no valid solution found"
            end
            return
        end
        row, col = rowcol[depth]
        available[board[row, col] >> 2] = true
        _idx_range = idx_range[depth]
    end
end
